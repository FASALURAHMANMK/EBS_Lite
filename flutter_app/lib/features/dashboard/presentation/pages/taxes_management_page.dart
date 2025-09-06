import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/taxes_repository.dart';

class TaxesManagementPage extends ConsumerStatefulWidget {
  const TaxesManagementPage({super.key});

  @override
  ConsumerState<TaxesManagementPage> createState() => _TaxesManagementPageState();
}

class _TaxesManagementPageState extends ConsumerState<TaxesManagementPage> {
  bool _loading = true;
  List<TaxDto> _taxes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(taxesRepositoryProvider).getTaxes();
      if (!mounted) return;
      setState(() => _taxes = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Taxes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _taxes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final t = _taxes[i];
                  return Card(
                    elevation: 0,
                    child: ListTile(
                      leading: const Icon(Icons.percent_rounded),
                      title: Text(t.name),
                      subtitle: Text('${t.percentage.toStringAsFixed(2)} %'
                          '${t.isCompound ? ' • Compound' : ''}'
                          '${t.isActive ? '' : ' • Inactive'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openEditor(context, initial: t),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Delete Tax'),
                                      content: Text('Delete tax "${t.name}"?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel')),
                                        FilledButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Delete')),
                                      ],
                                    ),
                                  ) ??
                                  false;
                              if (!ok) return;
                              try {
                                await ref.read(taxesRepositoryProvider).deleteTax(t.taxId);
                                _load();
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
            ),
    );
  }

  Future<void> _openEditor(BuildContext context, {TaxDto? initial}) async {
    final name = TextEditingController(text: initial?.name ?? '');
    final percent = TextEditingController(text: initial?.percentage.toString() ?? '0');
    bool isCompound = initial?.isCompound ?? false;
    bool isActive = initial?.isActive ?? true;

    final res = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: Text(initial == null ? 'Add Tax' : 'Edit Tax'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: percent,
                  decoration: const InputDecoration(labelText: 'Percentage'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: isCompound,
                  onChanged: (v) => setInner(() => isCompound = v),
                  title: const Text('Compound tax'),
                ),
                SwitchListTile(
                  value: isActive,
                  onChanged: (v) => setInner(() => isActive = v),
                  title: const Text('Active'),
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
      final repo = ref.read(taxesRepositoryProvider);
      final p = double.tryParse(percent.text.trim()) ?? 0;
      if (initial == null) {
        await repo.createTax(name: name.text.trim(), percentage: p, isCompound: isCompound, isActive: isActive);
      } else {
        await repo.updateTax(taxId: initial.taxId, name: name.text.trim(), percentage: p, isCompound: isCompound, isActive: isActive);
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}

