import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../data/models.dart';
import '../../data/promotions_repository.dart';

class PromotionsPage extends ConsumerStatefulWidget {
  const PromotionsPage({super.key});

  @override
  ConsumerState<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends ConsumerState<PromotionsPage> {
  bool _loading = true;
  bool _activeOnly = false;
  List<PromotionDto> _promotions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(promotionsRepositoryProvider);
      final list = await repo.getPromotions(activeOnly: _activeOnly);
      if (mounted) setState(() => _promotions = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _openEditor({PromotionDto? initial}) async {
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    final descCtrl = TextEditingController(text: initial?.description ?? '');
    final valueCtrl = TextEditingController(
        text: initial?.value != null ? initial!.value!.toString() : '');
    final minCtrl = TextEditingController(
        text: initial?.minAmount != null ? initial!.minAmount!.toString() : '');
    final condCtrl = TextEditingController(
        text:
            initial?.conditions != null ? jsonEncode(initial!.conditions) : '');

    DateTime? startDate = initial?.startDate;
    DateTime? endDate = initial?.endDate;
    String discountType = initial?.discountType ?? '';
    String applicableTo = initial?.applicableTo ?? 'ALL';
    bool isActive = initial?.isActive ?? true;

    final repo = ref.read(promotionsRepositoryProvider);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> pickDate(bool isStart) async {
              final now = DateTime.now();
              final initialDate = (isStart ? startDate : endDate) ?? now;
              final picked = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(now.year - 3, 1, 1),
                lastDate: DateTime(now.year + 5, 12, 31),
              );
              if (picked != null) {
                setStateDialog(() {
                  if (isStart) {
                    startDate = picked;
                    endDate ??= picked.add(const Duration(days: 30));
                  } else {
                    endDate = picked;
                  }
                });
              }
            }

            return AlertDialog(
              title: Text(initial == null ? 'New Promotion' : 'Edit Promotion'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: discountType,
                        decoration: const InputDecoration(
                          labelText: 'Discount Type',
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('None')),
                          DropdownMenuItem(
                              value: 'PERCENTAGE', child: Text('Percentage')),
                          DropdownMenuItem(
                              value: 'FIXED', child: Text('Fixed Amount')),
                          DropdownMenuItem(
                              value: 'BUY_X_GET_Y', child: Text('Buy X Get Y')),
                        ],
                        onChanged: (v) =>
                            setStateDialog(() => discountType = v ?? ''),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: valueCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration:
                                  const InputDecoration(labelText: 'Value'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: minCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'Min Amount'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Start Date'),
                              subtitle: Text(startDate != null
                                  ? _fmtDate(startDate!)
                                  : 'Select'),
                              trailing:
                                  const Icon(Icons.calendar_month_rounded),
                              onTap: () => pickDate(true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('End Date'),
                              subtitle: Text(endDate != null
                                  ? _fmtDate(endDate!)
                                  : 'Select'),
                              trailing:
                                  const Icon(Icons.calendar_month_rounded),
                              onTap: () => pickDate(false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: applicableTo,
                        decoration: const InputDecoration(
                          labelText: 'Applicable To',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All')),
                          DropdownMenuItem(
                              value: 'PRODUCTS', child: Text('Products')),
                          DropdownMenuItem(
                              value: 'CATEGORIES', child: Text('Categories')),
                          DropdownMenuItem(
                              value: 'CUSTOMERS', child: Text('Customers')),
                        ],
                        onChanged: (v) =>
                            setStateDialog(() => applicableTo = v ?? 'ALL'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: condCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Conditions (JSON)',
                          hintText: '{"product_ids":[1,2]}',
                        ),
                      ),
                      if (initial != null) ...[
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: isActive,
                          title: const Text('Active'),
                          onChanged: (v) => setStateDialog(() => isActive = v),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Name is required')),
                            );
                            return;
                          }
                          if (startDate == null || endDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Start and end dates required')),
                            );
                            return;
                          }
                          if (endDate!.isBefore(startDate!)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('End date must be after start')),
                            );
                            return;
                          }
                          Map<String, dynamic>? conditions;
                          final condRaw = condCtrl.text.trim();
                          if (condRaw.isNotEmpty) {
                            try {
                              final decoded = jsonDecode(condRaw);
                              if (decoded is Map) {
                                conditions = Map<String, dynamic>.from(decoded);
                              } else {
                                throw const FormatException(
                                    'Conditions must be a JSON object');
                              }
                            } catch (_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Invalid conditions JSON')),
                              );
                              return;
                            }
                          }

                          final value = double.tryParse(valueCtrl.text.trim());
                          final minAmount =
                              double.tryParse(minCtrl.text.trim());

                          setStateDialog(() => saving = true);
                          try {
                            if (initial == null) {
                              await repo.createPromotion(
                                name: name,
                                description: descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                                discountType:
                                    discountType.isEmpty ? null : discountType,
                                value: value,
                                minAmount: minAmount,
                                startDate: startDate!,
                                endDate: endDate!,
                                applicableTo: applicableTo,
                                conditions: conditions,
                              );
                            } else {
                              await repo.updatePromotion(
                                initial.promotionId,
                                name: name,
                                description: descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                                discountType:
                                    discountType.isEmpty ? null : discountType,
                                value: value,
                                minAmount: minAmount,
                                startDate: startDate!,
                                endDate: endDate!,
                                applicableTo: applicableTo,
                                conditions: conditions,
                                isActive: isActive,
                              );
                            }
                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop(true);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ErrorHandler.message(e))),
                            );
                          } finally {
                            if (context.mounted) {
                              setStateDialog(() => saving = false);
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _deletePromotion(PromotionDto promo) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Promotion'),
        content: Text('Delete "${promo.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (confirmed != true) return;
    try {
      await ref
          .read(promotionsRepositoryProvider)
          .deletePromotion(promo.promotionId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Promotions'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            SwitchListTile(
              value: _activeOnly,
              title: const Text('Show active only'),
              onChanged: (v) async {
                setState(() => _activeOnly = v);
                await _load();
              },
            ),
            Expanded(
              child: _promotions.isEmpty
                  ? const Center(child: Text('No promotions'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _promotions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final p = _promotions[i];
                        final typeLabel = (p.discountType ?? 'N/A');
                        final valueLabel =
                            p.value != null ? p.value!.toStringAsFixed(2) : '—';
                        final subtitle = [
                          'Type: $typeLabel',
                          'Value: $valueLabel',
                          'Dates: ${_fmtDate(p.startDate)} → ${_fmtDate(p.endDate)}',
                          if (p.applicableTo != null)
                            'Applies to: ${p.applicableTo}',
                        ].join(' · ');
                        return Card(
                          elevation: 0,
                          child: ListTile(
                            leading: Icon(
                              p.isActive
                                  ? Icons.local_offer_rounded
                                  : Icons.local_offer_outlined,
                              color:
                                  p.isActive ? theme.colorScheme.primary : null,
                            ),
                            title: Text(p.name),
                            subtitle: Text(subtitle),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'Promotion actions',
                              onSelected: (v) async {
                                if (v == 'edit') {
                                  await _openEditor(initial: p);
                                } else if (v == 'toggle') {
                                  try {
                                    await ref
                                        .read(promotionsRepositoryProvider)
                                        .updatePromotion(
                                          p.promotionId,
                                          isActive: !p.isActive,
                                        );
                                    await _load();
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content:
                                                Text(ErrorHandler.message(e))));
                                  }
                                } else if (v == 'delete') {
                                  await _deletePromotion(p);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(
                                      p.isActive ? 'Deactivate' : 'Activate'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
