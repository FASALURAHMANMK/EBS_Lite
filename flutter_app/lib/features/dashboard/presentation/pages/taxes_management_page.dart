import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../data/taxes_repository.dart';

class TaxesManagementPage extends ConsumerStatefulWidget {
  const TaxesManagementPage({super.key});

  @override
  ConsumerState<TaxesManagementPage> createState() =>
      _TaxesManagementPageState();
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
                      subtitle: Text(_taxSubtitle(t)),
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
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel')),
                                        FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Delete')),
                                      ],
                                    ),
                                  ) ??
                                  false;
                              if (!ok) return;
                              try {
                                await ref
                                    .read(taxesRepositoryProvider)
                                    .deleteTax(t.taxId);
                                _load();
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(SnackBar(
                                      content: Text(ErrorHandler.message(e))));
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

  String _taxSubtitle(TaxDto t) {
    final base = '${t.percentage.toStringAsFixed(2)} %';
    final comps = t.components
        .where((c) => c.name.trim().isNotEmpty && c.percentage != 0)
        .toList(growable: false);
    final breakdown = comps.isEmpty
        ? ''
        : ' • ${comps.map((c) => '${c.name.trim()} ${c.percentage.toStringAsFixed(2)}').join(' + ')}';
    final compound = t.isCompound ? ' • Compound' : '';
    final active = t.isActive ? '' : ' • Inactive';
    return '$base$breakdown$compound$active';
  }

  Future<void> _openEditor(BuildContext context, {TaxDto? initial}) async {
    final name = TextEditingController(text: initial?.name ?? '');
    final percent =
        TextEditingController(text: initial?.percentage.toString() ?? '0');
    bool isCompound = initial?.isCompound ?? false;
    bool isActive = initial?.isActive ?? true;

    final componentNameCtrls = <TextEditingController>[];
    final componentPctCtrls = <TextEditingController>[];
    final deferredDisposeCtrls = <TextEditingController>[];
    void addComponent({String n = '', String p = ''}) {
      componentNameCtrls.add(TextEditingController(text: n));
      componentPctCtrls.add(TextEditingController(text: p));
    }

    final initialComponents = (initial?.components ?? const [])
        .where((c) => c.name.trim().isNotEmpty)
        .toList(growable: false);
    for (final c in initialComponents) {
      addComponent(n: c.name, p: c.percentage.toString());
    }
    bool breakdownEnabled = initialComponents.isNotEmpty;

    double computeComponentsTotal() {
      var total = 0.0;
      for (final c in componentPctCtrls) {
        total += double.tryParse(c.text.trim()) ?? 0;
      }
      return total;
    }

    final res = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: Text(initial == null ? 'Add Tax' : 'Edit Tax'),
          scrollable: true,
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
                SwitchListTile(
                  value: breakdownEnabled,
                  onChanged: (v) => setInner(() {
                    breakdownEnabled = v;
                    if (breakdownEnabled && componentNameCtrls.isEmpty) {
                      addComponent();
                    }
                  }),
                  title: const Text('Tax breakdown'),
                  subtitle:
                      const Text('Split tax into components (e.g., CGST/SGST)'),
                  contentPadding: EdgeInsets.zero,
                ),
                if (!breakdownEnabled)
                  TextField(
                    controller: percent,
                    decoration:
                        const InputDecoration(labelText: 'Total percentage'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  )
                else ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Components (total: ${computeComponentsTotal().toStringAsFixed(2)} %)',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < componentNameCtrls.length; i++) ...[
                    KeyedSubtree(
                      key: ValueKey(componentNameCtrls[i]),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: componentNameCtrls[i],
                              decoration: InputDecoration(
                                labelText: i == 0 ? 'Component name' : null,
                                hintText: 'e.g., CGST',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: componentPctCtrls[i],
                              decoration: InputDecoration(
                                labelText: i == 0 ? 'Percent' : null,
                                hintText: 'e.g., 9',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              onChanged: (_) => setInner(() {}),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: componentNameCtrls.length <= 1
                                ? null
                                : () => setInner(() {
                                      final removedName =
                                          componentNameCtrls.removeAt(i);
                                      final removedPct =
                                          componentPctCtrls.removeAt(i);
                                      deferredDisposeCtrls.add(removedName);
                                      deferredDisposeCtrls.add(removedPct);
                                    }),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setInner(() => addComponent()),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add component'),
                    ),
                  ),
                ],
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
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (res != true) {
      name.dispose();
      percent.dispose();
      for (final c in componentNameCtrls) {
        c.dispose();
      }
      for (final c in componentPctCtrls) {
        c.dispose();
      }
      for (final c in deferredDisposeCtrls) {
        c.dispose();
      }
      return;
    }
    try {
      final repo = ref.read(taxesRepositoryProvider);
      final trimmedName = name.text.trim();
      if (trimmedName.isEmpty) {
        throw Exception('Name is required');
      }

      double p = double.tryParse(percent.text.trim()) ?? 0;
      List<TaxComponentDto>? comps;
      if (breakdownEnabled) {
        comps = <TaxComponentDto>[];
        for (var i = 0; i < componentNameCtrls.length; i++) {
          final cn = componentNameCtrls[i].text.trim();
          if (cn.isEmpty) continue;
          final cp = double.tryParse(componentPctCtrls[i].text.trim()) ?? 0;
          comps.add(TaxComponentDto(name: cn, percentage: cp, sortOrder: i));
        }
        if (comps.isEmpty) {
          throw Exception('Add at least one component');
        }
        p = comps.fold<double>(0, (sum, c) => sum + c.percentage);
      }
      if (initial == null) {
        await repo.createTax(
          name: trimmedName,
          percentage: p,
          components: comps,
          isCompound: isCompound,
          isActive: isActive,
        );
      } else {
        await repo.updateTax(
            taxId: initial.taxId,
            name: trimmedName,
            percentage: p,
            components: comps,
            isCompound: isCompound,
            isActive: isActive);
      }
      _load();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      name.dispose();
      percent.dispose();
      for (final c in componentNameCtrls) {
        c.dispose();
      }
      for (final c in componentPctCtrls) {
        c.dispose();
      }
      for (final c in deferredDisposeCtrls) {
        c.dispose();
      }
    }
  }
}
