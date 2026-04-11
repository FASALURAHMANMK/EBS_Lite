import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../core/outbox/outbox_notifier.dart';
import '../../data/customer_repository.dart';

class CustomerCollectionSheet extends ConsumerStatefulWidget {
  const CustomerCollectionSheet({
    super.key,
    required this.customerId,
    required this.onDone,
  });

  final int customerId;
  final VoidCallback onDone;

  @override
  ConsumerState<CustomerCollectionSheet> createState() =>
      _CustomerCollectionSheetState();
}

class _CustomerCollectionSheetState
    extends ConsumerState<CustomerCollectionSheet> {
  final _amount = TextEditingController();
  final _date = ValueNotifier<DateTime>(DateTime.now());
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  bool _invoiceMode = false;
  bool _saving = false;
  List<Map<String, dynamic>> _methods = const [];
  int? _methodId;
  String? _methodName;
  List<Map<String, dynamic>> _invoices = const [];
  final Map<int, TextEditingController> _alloc = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    for (final c in _alloc.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final repo = ref.read(customerRepositoryProvider);
      final methods = await repo.getPaymentMethods();
      if (!mounted) return;
      setState(() {
        _methods = methods;
        _methodId = methods.isNotEmpty
            ? (methods.first['method_id'] as int? ??
                methods.first['id'] as int?)
            : null;
        _methodName = methods.isNotEmpty
            ? ((methods.first['name'] ?? methods.first['method'])?.toString())
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      _showError(context, e);
    }
  }

  Future<void> _loadInvoices() async {
    try {
      final repo = ref.read(customerRepositoryProvider);
      final list =
          await repo.getOutstandingInvoices(customerId: widget.customerId);
      if (!mounted) return;
      final invoices = list
          .where((e) =>
              ((e['total_amount'] ?? 0) as num).toDouble() -
                  ((e['paid_amount'] ?? 0) as num).toDouble() >
              0.0)
          .toList();
      setState(() {
        _invoices = invoices;
        for (final inv in invoices) {
          final id = inv['sale_id'] as int?;
          if (id != null && !_alloc.containsKey(id)) {
            _alloc[id] = TextEditingController();
          }
        }
      });
      if (_invoiceMode) _autoAllocate();
    } catch (e) {
      if (!mounted) return;
      _showError(context, e);
    }
  }

  double get _amountVal => double.tryParse(_amount.text.trim()) ?? 0;

  double _invoiceOutstanding(Map<String, dynamic> inv) {
    final total = (inv['total_amount'] as num?)?.toDouble() ?? 0;
    final paid = (inv['paid_amount'] as num?)?.toDouble() ?? 0;
    return (total - paid).clamp(0, double.infinity);
  }

  void _autoAllocate() {
    var remaining = _amountVal;
    for (final inv in _invoices) {
      final id = inv['sale_id'] as int;
      final out = _invoiceOutstanding(inv);
      if (remaining <= 0) {
        _alloc[id]?.text = '';
        continue;
      }
      final alloc = remaining >= out ? out : remaining;
      _alloc[id]?.text = alloc > 0 ? alloc.toStringAsFixed(2) : '';
      remaining -= alloc;
    }
    setState(() {});
  }

  Future<void> _submit() async {
    final amt = _amountVal;
    if (amt <= 0) {
      _showInfo(context, 'Enter a valid amount');
      return;
    }
    List<Map<String, dynamic>>? invoices;
    if (_invoiceMode) {
      final lines = <Map<String, dynamic>>[];
      double sum = 0;
      for (final inv in _invoices) {
        final id = inv['sale_id'] as int;
        final txt = _alloc[id]?.text.trim() ?? '';
        if (txt.isEmpty) continue;
        final val = double.tryParse(txt) ?? 0;
        if (val <= 0) continue;
        final out = _invoiceOutstanding(inv);
        if (val > out) {
          _showInfo(context,
              'Allocation for ${inv['sale_number']} exceeds outstanding');
          return;
        }
        lines.add({'sale_id': id, 'amount': val});
        sum += val;
      }
      if (lines.isEmpty) {
        _showInfo(context, 'Allocate amount to at least one invoice');
        return;
      }
      if ((sum - amt).abs() > 0.009) {
        _showInfo(context,
            'Allocated total (${sum.toStringAsFixed(2)}) must equal amount (${amt.toStringAsFixed(2)})');
        return;
      }
      invoices = lines;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(customerRepositoryProvider);
      await repo.createCollection(
        customerId: widget.customerId,
        amount: amt,
        paymentMethodId: _methodId,
        receivedDate: _date.value,
        reference:
            _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        invoices: invoices,
        skipAutoAllocation: !_invoiceMode,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDone();
      _showInfo(context, 'Collection recorded');
    } on OutboxQueuedException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDone();
      _showInfo(context, e.message);
    } catch (e) {
      if (!mounted) return;
      _showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.payments_rounded),
                  const SizedBox(width: 8),
                  const Text('Record Collection',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Row(
                    children: [
                      Switch(
                        value: _invoiceMode,
                        onChanged: (v) async {
                          setState(() => _invoiceMode = v);
                          if (v && _invoices.isEmpty) {
                            await _loadInvoices();
                          } else if (v) {
                            _autoAllocate();
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      const Text('Apply to invoices'),
                    ],
                  ),
                  const Spacer(),
                  ValueListenableBuilder<DateTime>(
                    valueListenable: _date,
                    builder: (context, d, _) => InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: d,
                          firstDate: DateTime(now.year - 5),
                          lastDate: DateTime(now.year + 5),
                        );
                        if (picked != null) _date.value = picked;
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 6.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text('${d.toLocal()}'.split(' ').first),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
                onChanged: (_) {
                  if (_invoiceMode) _autoAllocate();
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Payment Method'),
                subtitle: Text(_methodName ?? 'Select'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _methods.isEmpty
                    ? null
                    : () async {
                        final picked = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Select Payment Method'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: RadioGroup<int>(
                                groupValue: _methodId ?? -1,
                                onChanged: (value) {
                                  if (value == null) return;
                                  final selected = _methods.firstWhere(
                                    (m) =>
                                        ((m['method_id'] as int?) ??
                                            (m['id'] as int?)) ==
                                        value,
                                    orElse: () => const {},
                                  );
                                  final name = (selected['name'] ??
                                          selected['method'] ??
                                          '')
                                      .toString();
                                  Navigator.of(ctx)
                                      .pop({'id': value, 'name': name});
                                },
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _methods.length,
                                  itemBuilder: (_, i) {
                                    final m = _methods[i];
                                    final id = (m['method_id'] as int?) ??
                                        (m['id'] as int?);
                                    final name =
                                        (m['name'] ?? m['method'] ?? '')
                                            .toString();
                                    return RadioListTile<int>(
                                      value: id ?? -1,
                                      title: Text(name),
                                    );
                                  },
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Cancel')),
                            ],
                          ),
                        );
                        if (picked != null) {
                          setState(() {
                            _methodId = picked['id'] as int?;
                            _methodName = picked['name'] as String?;
                          });
                        }
                      },
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: _reference,
                  decoration: const InputDecoration(labelText: 'Reference')),
              const SizedBox(height: 8),
              TextField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'Notes')),
              const SizedBox(height: 8),
              if (_invoiceMode) ...[
                Row(
                  children: [
                    const Text('Outstanding Invoices',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton.icon(
                        onPressed: _autoAllocate,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Auto allocate')),
                  ],
                ),
                const SizedBox(height: 4),
                ..._invoices.map((inv) {
                  final saleNo = (inv['sale_number'] ?? '').toString();
                  final out = _invoiceOutstanding(inv);
                  final id = inv['sale_id'] as int;
                  return ListTile(
                    title: Text(saleNo),
                    subtitle: Text('Outstanding: ${out.toStringAsFixed(2)}'),
                    trailing: SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _alloc[id],
                        decoration: const InputDecoration(hintText: 'Amount'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Saving...' : 'Record Collection'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

void _showError(BuildContext context, Object e) {
  final msg = ErrorHandler.message(e);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

void _showInfo(BuildContext context, String m) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
}
