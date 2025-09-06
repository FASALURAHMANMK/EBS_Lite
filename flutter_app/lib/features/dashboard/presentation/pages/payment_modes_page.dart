import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/payment_methods_repository.dart';
import '../../data/currency_repository.dart';

class PaymentModesPage extends ConsumerStatefulWidget {
  const PaymentModesPage({super.key});

  @override
  ConsumerState<PaymentModesPage> createState() => _PaymentModesPageState();
}

class _PaymentModesPageState extends ConsumerState<PaymentModesPage> {
  bool _loading = true;
  List<PaymentMethodDto> _methods = const [];
  List<CurrencyDto> _currencies = const [];
  Map<int, List<Map<String, dynamic>>> _methodCurrencies = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pmRepo = ref.read(paymentMethodsRepositoryProvider);
      final curRepo = ref.read(currencyRepositoryProvider);
      final results = await Future.wait([
        pmRepo.getMethods(),
        curRepo.getCurrencies(),
        pmRepo.getMethodCurrencies(),
      ]);
      if (!mounted) return;
      setState(() {
        _methods = results[0] as List<PaymentMethodDto>;
        _currencies = results[1] as List<CurrencyDto>;
        _methodCurrencies = results[2] as Map<int, List<Map<String, dynamic>>>;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Modes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _methods.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final m = _methods[i];
                final list = _methodCurrencies[m.methodId] ?? const [];
                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet_rounded),
                    title: Text(m.name),
                    subtitle: Text('${m.type}${m.isActive ? '' : ' • Inactive'}' + (list.isEmpty ? '' : ' • ${list.length} currencies')),
                    onTap: () => _openCurrencies(context, m),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openEditor(context, initial: m),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Delete Payment Mode'),
                                    content: Text('Delete "${m.name}"?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                    ],
                                  ),
                                ) ??
                                false;
                            if (!ok) return;
                            try {
                              await ref.read(paymentMethodsRepositoryProvider).deleteMethod(m.methodId);
                              setState(() {
                                _methods = _methods.where((x) => x.methodId != m.methodId).toList();
                                _methodCurrencies.remove(m.methodId);
                              });
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(SnackBar(content: Text('Failed: $e')));
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _openEditor(BuildContext context, {PaymentMethodDto? initial}) async {
    final name = TextEditingController(text: initial?.name ?? '');
    String type = initial?.type ?? 'CASH';
    bool isActive = initial?.isActive ?? true;
    const types = ['CASH', 'CARD', 'ONLINE', 'UPI', 'CHEQUE', 'CREDIT'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: Text(initial == null ? 'Add Payment Mode' : 'Edit Payment Mode'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Type'),
                  value: type,
                  items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setInner(() => type = v ?? type),
                ),
                const SizedBox(height: 8),
                SwitchListTile(value: isActive, onChanged: (v) => setInner(() => isActive = v), title: const Text('Active')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final repo = ref.read(paymentMethodsRepositoryProvider);
      if (initial == null) {
        final created = await repo.createMethod(name: name.text.trim(), type: type, isActive: isActive);
        setState(() => _methods = [..._methods, created]);
      } else {
        await repo.updateMethod(id: initial.methodId, name: name.text.trim(), type: type, isActive: isActive);
        _load();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _openCurrencies(BuildContext context, PaymentMethodDto m) async {
    // Editable selection with rates (default from global currencies)
    final selected = Map<int, double>.fromEntries(
      (_methodCurrencies[m.methodId] ?? const [])
          .map((e) => MapEntry(e['currency_id'] as int, (e['rate'] as num?)?.toDouble() ?? 0)),
    );
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: Text('Currencies for ${m.name}'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _currencies.length,
                    itemBuilder: (context, i) {
                      final c = _currencies[i];
                      final enabled = selected.containsKey(c.currencyId);
                      final controller = TextEditingController(
                        text: enabled ? selected[c.currencyId]?.toString() ?? '' : '',
                      );
                      return CheckboxListTile(
                        value: enabled,
                        onChanged: (v) {
                          setInner(() {
                            if (v == true) {
                              selected[c.currencyId] = selected[c.currencyId] ?? 1.0;
                            } else {
                              selected.remove(c.currencyId);
                            }
                          });
                        },
                        title: Text('${c.code} – ${c.name}'),
                        subtitle: enabled
                            ? Row(
                                children: [
                                  const Text('Exchange rate:'),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller: controller,
                                      onChanged: (v) => selected[c.currencyId] = double.tryParse(v.trim()) ?? 0,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(isDense: true, labelText: 'Rate'),
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (res != true) return;
    try {
      final mapping = Map<int, List<Map<String, dynamic>>>.from(_methodCurrencies);
      mapping[m.methodId] = selected.entries
          .map((e) => {
                'currency_id': e.key,
                'rate': e.value,
              })
          .toList();
      await ref.read(paymentMethodsRepositoryProvider).setMethodCurrencies(mapping);
      setState(() => _methodCurrencies = mapping);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}

