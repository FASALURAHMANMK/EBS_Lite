import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/error_handler.dart';
import '../../../../core/locale_preferences.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/data/models.dart';
import '../../../loyalty/data/loyalty_repository.dart';
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
  bool _importing = false;

  List<PromotionDto> _promotions = const [];
  List<CouponSeriesDto> _couponSeries = const [];
  List<RaffleDefinitionDto> _raffleDefinitions = const [];
  List<LoyaltyTierDto> _tiers = const [];
  PromotionImportResultDto? _lastImportResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmtDate(DateTime date) {
    final localePrefs = ref.read(localePreferencesProvider);
    return AppDateTime.formatDate(context, localePrefs, date);
  }

  List<int> _parseIdCsv(String raw) {
    return raw
        .split(',')
        .map((item) => int.tryParse(item.trim()))
        .whereType<int>()
        .toList(growable: false);
  }

  String _formatNullableDouble(double? value) {
    if (value == null) return '—';
    return value.toStringAsFixed(2);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showError(Object error) {
    _showMessage(ErrorHandler.message(error));
  }

  Future<DateTime?> _pickDate(DateTime? initialDate) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(promotionsRepositoryProvider);
      final loyaltyRepo = ref.read(loyaltyRepositoryProvider);
      final promotions = await repo.getPromotions(activeOnly: _activeOnly);
      final couponSeries = await repo.getCouponSeries(activeOnly: _activeOnly);
      final raffles = await repo.getRaffleDefinitions(activeOnly: _activeOnly);
      final tiers = await loyaltyRepo.getTiers();

      if (!mounted) return;
      setState(() {
        _promotions = promotions;
        _couponSeries = couponSeries;
        _raffleDefinitions = raffles;
        _tiers = tiers.where((item) => item.isActive).toList(growable: false);
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _deletePromotion(PromotionDto promotion) async {
    final confirmed = await _confirm(
      title: 'Delete Campaign',
      message: 'Delete "${promotion.name}"?',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await ref
          .read(promotionsRepositoryProvider)
          .deletePromotion(promotion.promotionId);
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteCouponSeries(CouponSeriesDto series) async {
    final confirmed = await _confirm(
      title: 'Delete Coupon Series',
      message: 'Delete "${series.name}"? Existing codes stay in history.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await ref
          .read(promotionsRepositoryProvider)
          .deleteCouponSeries(series.couponSeriesId);
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteRaffleDefinition(RaffleDefinitionDto definition) async {
    final confirmed = await _confirm(
      title: 'Delete Raffle Definition',
      message: 'Delete "${definition.name}"?',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await ref
          .read(promotionsRepositoryProvider)
          .deleteRaffleDefinition(definition.raffleDefinitionId);
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _togglePromotion(PromotionDto promotion) async {
    try {
      await ref.read(promotionsRepositoryProvider).updatePromotion(
            promotion.promotionId,
            isActive: !promotion.isActive,
          );
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleCouponSeries(CouponSeriesDto series) async {
    try {
      await ref.read(promotionsRepositoryProvider).updateCouponSeries(
            series.couponSeriesId,
            isActive: !series.isActive,
          );
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleRaffleDefinition(RaffleDefinitionDto definition) async {
    try {
      await ref.read(promotionsRepositoryProvider).updateRaffleDefinition(
            definition.raffleDefinitionId,
            isActive: !definition.isActive,
          );
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<PromotionProductRuleDto?> _openPromotionRuleEditor({
    PromotionProductRuleDto? initial,
  }) async {
    final searchCtrl = TextEditingController();
    final valueCtrl =
        TextEditingController(text: initial?.value.toStringAsFixed(2) ?? '');
    final minQtyCtrl = TextEditingController(
      text: initial != null && initial.minQty > 0
          ? initial.minQty.toStringAsFixed(2)
          : '',
    );

    final inventoryRepo = ref.read(inventoryRepositoryProvider);
    InventoryListItem? selectedProduct;
    if (initial != null) {
      selectedProduct = InventoryListItem(
        productId: initial.productId,
        barcodeId: initial.barcodeId,
        name: initial.productName ?? 'Product #${initial.productId}',
        reorderLevel: 0,
        stock: 0,
        isLowStock: false,
      );
    }
    var discountType = initial?.discountType ?? 'PERCENTAGE';
    var searching = false;
    var results = <InventoryListItem>[];

    final saved = await showDialog<PromotionProductRuleDto>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> runSearch() async {
              final query = searchCtrl.text.trim();
              if (query.length < 2) return;
              setStateDialog(() => searching = true);
              try {
                final list = await inventoryRepo.searchProducts(
                  query,
                  includeComboProducts: false,
                );
                setStateDialog(() => results = list);
              } catch (error) {
                _showError(error);
              } finally {
                setStateDialog(() => searching = false);
              }
            }

            return AlertDialog(
              title: Text(
                  initial == null ? 'Add Product Rule' : 'Edit Product Rule'),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SearchBar(
                        controller: searchCtrl,
                        hintText: 'Search products by name, SKU or barcode',
                        trailing: [
                          if (searching)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.search_rounded),
                              onPressed: runSearch,
                            ),
                        ],
                        onSubmitted: (_) => runSearch(),
                      ),
                      const SizedBox(height: 12),
                      if (selectedProduct != null)
                        Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: const Icon(Icons.inventory_2_rounded),
                            title: Text(selectedProduct!.name),
                            subtitle: Text([
                              if ((selectedProduct!.variantName ?? '')
                                  .trim()
                                  .isNotEmpty)
                                selectedProduct!.variantName!,
                              if ((selectedProduct!.categoryName ?? '')
                                  .trim()
                                  .isNotEmpty)
                                selectedProduct!.categoryName!,
                              if ((selectedProduct!.primaryStorage ?? '')
                                  .trim()
                                  .isNotEmpty)
                                selectedProduct!.primaryStorage!,
                            ].join(' • ')),
                          ),
                        ),
                      if (results.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = results[index];
                              return ListTile(
                                dense: true,
                                title: Text(item.name),
                                subtitle: Text([
                                  if ((item.variantName ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    item.variantName!,
                                  if ((item.categoryName ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    item.categoryName!,
                                  if ((item.primaryStorage ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    item.primaryStorage!,
                                ].join(' • ')),
                                onTap: () {
                                  setStateDialog(() => selectedProduct = item);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: discountType,
                        decoration:
                            const InputDecoration(labelText: 'Discount Type'),
                        items: const [
                          DropdownMenuItem(
                            value: 'PERCENTAGE',
                            child: Text('Percentage'),
                          ),
                          DropdownMenuItem(
                            value: 'FIXED',
                            child: Text('Fixed Amount'),
                          ),
                          DropdownMenuItem(
                            value: 'FIXED_PRICE',
                            child: Text('Fixed Price'),
                          ),
                        ],
                        onChanged: (value) {
                          setStateDialog(
                            () => discountType = value ?? 'PERCENTAGE',
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: valueCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Value',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: minQtyCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Min Qty',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (selectedProduct == null) {
                      _showMessage('Select a product for this rule');
                      return;
                    }
                    final value = double.tryParse(valueCtrl.text.trim());
                    if (value == null || value < 0) {
                      _showMessage('Enter a valid rule value');
                      return;
                    }
                    final minQty =
                        double.tryParse(minQtyCtrl.text.trim()) ?? 0.0;
                    Navigator.of(ctx).pop(
                      PromotionProductRuleDto(
                        promotionRuleId: initial?.promotionRuleId ?? 0,
                        promotionId: initial?.promotionId ?? 0,
                        productId: selectedProduct!.productId,
                        barcodeId: selectedProduct!.barcodeId,
                        discountType: discountType,
                        value: value,
                        minQty: minQty,
                        productName: selectedProduct!.name,
                        barcode: null,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    return saved;
  }

  Future<void> _openPromotionEditor({PromotionDto? initial}) async {
    final repo = ref.read(promotionsRepositoryProvider);
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    final descCtrl = TextEditingController(text: initial?.description ?? '');
    final valueCtrl = TextEditingController(
      text: initial?.value != null ? initial!.value!.toStringAsFixed(2) : '',
    );
    final minAmountCtrl = TextEditingController(
      text: initial?.minAmount != null
          ? initial!.minAmount!.toStringAsFixed(2)
          : '',
    );
    final priorityCtrl =
        TextEditingController(text: (initial?.priority ?? 0).toString());
    final customerIdsCtrl =
        TextEditingController(text: initial?.customerIds.join(', ') ?? '');
    final productIdsCtrl =
        TextEditingController(text: initial?.productIds.join(', ') ?? '');
    final categoryIdsCtrl =
        TextEditingController(text: initial?.categoryIds.join(', ') ?? '');

    var startDate = initial?.startDate ?? DateTime.now();
    var endDate =
        initial?.endDate ?? DateTime.now().add(const Duration(days: 30));
    var discountType = initial?.discountType ?? 'PERCENTAGE';
    var discountScope = initial?.discountScope ?? 'ORDER';
    var applicableTo = initial?.applicableTo ?? 'ALL';
    var isActive = initial?.isActive ?? true;
    var selectedTierIds = [...(initial?.loyaltyTierIds ?? const <int>[])];
    var productRules = [
      ...(initial?.productRules ?? const <PromotionProductRuleDto>[])
    ];

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        var saving = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> pickStartDate() async {
              final picked = await _pickDate(startDate);
              if (picked == null) return;
              setStateDialog(() {
                startDate = picked;
                if (endDate.isBefore(startDate)) {
                  endDate = startDate;
                }
              });
            }

            Future<void> pickEndDate() async {
              final picked = await _pickDate(endDate);
              if (picked == null) return;
              setStateDialog(() => endDate = picked);
            }

            Future<void> addRule() async {
              final rule = await _openPromotionRuleEditor();
              if (rule == null) return;
              setStateDialog(() => productRules = [...productRules, rule]);
            }

            Future<void> editRule(int index) async {
              final rule = await _openPromotionRuleEditor(
                initial: productRules[index],
              );
              if (rule == null) return;
              setStateDialog(() {
                final updated = [...productRules];
                updated[index] = rule;
                productRules = updated;
              });
            }

            return AlertDialog(
              title: Text(initial == null ? 'New Campaign' : 'Edit Campaign'),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Campaign Name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: discountScope,
                              decoration: const InputDecoration(
                                labelText: 'Discount Scope',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'ORDER',
                                  child: Text('Order'),
                                ),
                                DropdownMenuItem(
                                  value: 'ITEM',
                                  child: Text('Item'),
                                ),
                              ],
                              onChanged: (value) {
                                setStateDialog(
                                  () => discountScope = value ?? 'ORDER',
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: applicableTo,
                              decoration: const InputDecoration(
                                labelText: 'Applicable To',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'ALL',
                                  child: Text('All'),
                                ),
                                DropdownMenuItem(
                                  value: 'PRODUCTS',
                                  child: Text('Products'),
                                ),
                                DropdownMenuItem(
                                  value: 'CATEGORIES',
                                  child: Text('Categories'),
                                ),
                                DropdownMenuItem(
                                  value: 'CUSTOMERS',
                                  child: Text('Customers'),
                                ),
                              ],
                              onChanged: (value) {
                                setStateDialog(
                                  () => applicableTo = value ?? 'ALL',
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: discountType,
                              decoration: const InputDecoration(
                                labelText: 'Discount Type',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'PERCENTAGE',
                                  child: Text('Percentage'),
                                ),
                                DropdownMenuItem(
                                  value: 'FIXED',
                                  child: Text('Fixed Amount'),
                                ),
                                DropdownMenuItem(
                                  value: 'FIXED_PRICE',
                                  child: Text('Fixed Price'),
                                ),
                                DropdownMenuItem(
                                  value: 'BUY_X_GET_Y',
                                  child: Text('Buy X Get Y'),
                                ),
                              ],
                              onChanged: (value) {
                                setStateDialog(
                                  () => discountType = value ?? 'PERCENTAGE',
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: valueCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Discount Value',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: minAmountCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Min Bill Amount',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Start Date'),
                              subtitle: Text(_fmtDate(startDate)),
                              trailing:
                                  const Icon(Icons.calendar_month_rounded),
                              onTap: pickStartDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('End Date'),
                              subtitle: Text(_fmtDate(endDate)),
                              trailing:
                                  const Icon(Icons.calendar_month_rounded),
                              onTap: pickEndDate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priorityCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          helperText:
                              'Higher priority campaigns are evaluated later.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Loyalty Tiers',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      if (_tiers.isEmpty)
                        const Text(
                          'No loyalty tiers configured. Campaign applies to all tiers.',
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _tiers
                              .map(
                                (tier) => FilterChip(
                                  label: Text(tier.name),
                                  selected:
                                      selectedTierIds.contains(tier.tierId),
                                  onSelected: (selected) {
                                    setStateDialog(() {
                                      if (selected) {
                                        selectedTierIds = [
                                          ...selectedTierIds,
                                          tier.tierId,
                                        ];
                                      } else {
                                        selectedTierIds = selectedTierIds
                                            .where((id) => id != tier.tierId)
                                            .toList(growable: false);
                                      }
                                    });
                                  },
                                ),
                              )
                              .toList(growable: false),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: customerIdsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Customer IDs',
                          hintText: '1, 2, 3',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: productIdsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Condition Product IDs',
                          hintText: 'Optional extra product filter',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: categoryIdsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Category IDs',
                          hintText: '10, 20',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Product Rules',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          TextButton.icon(
                            onPressed: addRule,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add Rule'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (productRules.isEmpty)
                        const Text(
                          'No product-specific rules. Use campaign discount type/value for order-level offers.',
                        )
                      else
                        Column(
                          children: productRules.asMap().entries.map((entry) {
                            final index = entry.key;
                            final rule = entry.value;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.sell_rounded),
                                title: Text(
                                  rule.productName ??
                                      'Product #${rule.productId}',
                                ),
                                subtitle: Text(
                                  '${rule.discountType} • ${rule.value.toStringAsFixed(2)}'
                                  '${rule.minQty > 0 ? ' • Min qty ${rule.minQty.toStringAsFixed(2)}' : ''}',
                                ),
                                trailing: Wrap(
                                  spacing: 4,
                                  children: [
                                    IconButton(
                                      tooltip: 'Edit rule',
                                      onPressed: () => editRule(index),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove rule',
                                      onPressed: () {
                                        setStateDialog(() {
                                          final updated = [...productRules];
                                          updated.removeAt(index);
                                          productRules = updated;
                                        });
                                      },
                                      icon: const Icon(
                                          Icons.delete_outline_rounded),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(growable: false),
                        ),
                      if (initial != null) ...[
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: isActive,
                          title: const Text('Active'),
                          onChanged: (value) {
                            setStateDialog(() => isActive = value);
                          },
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
                            _showMessage('Campaign name is required');
                            return;
                          }
                          if (endDate.isBefore(startDate)) {
                            _showMessage(
                              'End date must be on or after start date',
                            );
                            return;
                          }
                          final priority =
                              int.tryParse(priorityCtrl.text.trim()) ?? 0;
                          final value = double.tryParse(valueCtrl.text.trim());
                          final minAmount =
                              double.tryParse(minAmountCtrl.text.trim());
                          final hasRules = productRules.isNotEmpty;
                          if (!hasRules && (value == null || value < 0)) {
                            _showMessage(
                              'Enter a campaign discount value or define product rules',
                            );
                            return;
                          }

                          final conditions = <String, dynamic>{};
                          final customerIds = _parseIdCsv(customerIdsCtrl.text);
                          final conditionProductIds =
                              _parseIdCsv(productIdsCtrl.text);
                          final categoryIds = _parseIdCsv(categoryIdsCtrl.text);
                          if (selectedTierIds.isNotEmpty) {
                            conditions['loyalty_tier_ids'] = selectedTierIds;
                          }
                          if (customerIds.isNotEmpty) {
                            conditions['customer_ids'] = customerIds;
                          }
                          if (conditionProductIds.isNotEmpty) {
                            conditions['product_ids'] = conditionProductIds;
                          }
                          if (categoryIds.isNotEmpty) {
                            conditions['category_ids'] = categoryIds;
                          }

                          setStateDialog(() => saving = true);
                          try {
                            final effectiveScope =
                                hasRules ? 'ITEM' : discountScope;
                            final effectiveApplicableTo =
                                hasRules ? 'PRODUCTS' : applicableTo;
                            if (initial == null) {
                              await repo.createPromotion(
                                name: name,
                                description: descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                                discountType: hasRules ? null : discountType,
                                discountScope: effectiveScope,
                                value: hasRules ? null : value,
                                minAmount: minAmount,
                                startDate: startDate,
                                endDate: endDate,
                                applicableTo: effectiveApplicableTo,
                                conditions:
                                    conditions.isEmpty ? null : conditions,
                                priority: priority,
                                productRules: productRules,
                              );
                            } else {
                              await repo.updatePromotion(
                                initial.promotionId,
                                name: name,
                                description: descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                                discountType: hasRules ? null : discountType,
                                discountScope: effectiveScope,
                                value: hasRules ? null : value,
                                minAmount: minAmount,
                                startDate: startDate,
                                endDate: endDate,
                                applicableTo: effectiveApplicableTo,
                                conditions:
                                    conditions.isEmpty ? null : conditions,
                                priority: priority,
                                productRules: productRules,
                                isActive: isActive,
                              );
                            }
                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop(true);
                          } catch (error) {
                            _showError(error);
                          } finally {
                            if (ctx.mounted) {
                              setStateDialog(() => saving = false);
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
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

  Future<void> _openCouponSeriesEditor({CouponSeriesDto? initial}) async {
    final repo = ref.read(promotionsRepositoryProvider);
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    final descCtrl = TextEditingController(text: initial?.description ?? '');
    final prefixCtrl = TextEditingController(text: initial?.prefix ?? '');
    final codeLengthCtrl = TextEditingController(
      text: (initial?.codeLength ?? 8).toString(),
    );
    final discountValueCtrl = TextEditingController(
      text: initial?.discountValue.toStringAsFixed(2) ?? '',
    );
    final minPurchaseCtrl = TextEditingController(
      text: initial?.minPurchaseAmount.toStringAsFixed(2) ?? '0.00',
    );
    final maxDiscountCtrl = TextEditingController(
      text: initial?.maxDiscountAmount?.toStringAsFixed(2) ?? '',
    );
    final totalCouponsCtrl = TextEditingController(
      text: (initial?.totalCoupons ?? 100).toString(),
    );
    final usageLimitPerCouponCtrl = TextEditingController(
      text: (initial?.usageLimitPerCoupon ?? 1).toString(),
    );
    final usageLimitPerCustomerCtrl = TextEditingController(
      text: (initial?.usageLimitPerCustomer ?? 1).toString(),
    );

    var startDate = initial?.startDate ?? DateTime.now();
    var endDate =
        initial?.endDate ?? DateTime.now().add(const Duration(days: 30));
    var discountType = initial?.discountType ?? 'PERCENTAGE';
    var isActive = initial?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        var saving = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                initial == null ? 'New Coupon Series' : 'Edit Coupon Series',
              ),
              content: SizedBox(
                width: 640,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        minLines: 2,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: prefixCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'Prefix'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: codeLengthCtrl,
                              keyboardType: TextInputType.number,
                              enabled: initial == null,
                              decoration: const InputDecoration(
                                labelText: 'Code Length',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: discountType,
                              decoration: const InputDecoration(
                                labelText: 'Discount Type',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'PERCENTAGE',
                                  child: Text('Percentage'),
                                ),
                                DropdownMenuItem(
                                  value: 'FIXED_AMOUNT',
                                  child: Text('Fixed Amount'),
                                ),
                              ],
                              onChanged: (value) {
                                setStateDialog(
                                  () => discountType = value ?? 'PERCENTAGE',
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: discountValueCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Discount Value',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: minPurchaseCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Minimum Purchase',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: maxDiscountCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Max Discount',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Start Date'),
                              subtitle: Text(_fmtDate(startDate)),
                              trailing:
                                  const Icon(Icons.calendar_month_rounded),
                              onTap: () async {
                                final picked = await _pickDate(startDate);
                                if (picked == null) return;
                                setStateDialog(() => startDate = picked);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('End Date'),
                              subtitle: Text(_fmtDate(endDate)),
                              trailing:
                                  const Icon(Icons.calendar_month_rounded),
                              onTap: () async {
                                final picked = await _pickDate(endDate);
                                if (picked == null) return;
                                setStateDialog(() => endDate = picked);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: totalCouponsCtrl,
                              enabled: initial == null,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Total Coupons',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: usageLimitPerCouponCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Usage Limit / Coupon',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: usageLimitPerCustomerCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Usage Limit / Customer',
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (initial != null) ...[
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: isActive,
                          title: const Text('Active'),
                          onChanged: (value) {
                            setStateDialog(() => isActive = value);
                          },
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
                          final prefix = prefixCtrl.text.trim().toUpperCase();
                          final codeLength =
                              int.tryParse(codeLengthCtrl.text.trim());
                          final discountValue =
                              double.tryParse(discountValueCtrl.text.trim());
                          final minPurchase =
                              double.tryParse(minPurchaseCtrl.text.trim()) ?? 0;
                          final maxDiscount =
                              double.tryParse(maxDiscountCtrl.text.trim());
                          final totalCoupons =
                              int.tryParse(totalCouponsCtrl.text.trim());
                          final usageLimitPerCoupon = int.tryParse(
                                usageLimitPerCouponCtrl.text.trim(),
                              ) ??
                              1;
                          final usageLimitPerCustomer = int.tryParse(
                                usageLimitPerCustomerCtrl.text.trim(),
                              ) ??
                              1;

                          if (name.isEmpty || prefix.isEmpty) {
                            _showMessage('Name and prefix are required');
                            return;
                          }
                          if (endDate.isBefore(startDate)) {
                            _showMessage(
                              'End date must be on or after start date',
                            );
                            return;
                          }
                          if (codeLength == null || codeLength < 6) {
                            _showMessage('Code length must be at least 6');
                            return;
                          }
                          if (discountValue == null || discountValue <= 0) {
                            _showMessage('Enter a valid discount value');
                            return;
                          }
                          if (initial == null &&
                              (totalCoupons == null || totalCoupons < 1)) {
                            _showMessage(
                                'Enter the number of coupons to generate');
                            return;
                          }

                          setStateDialog(() => saving = true);
                          try {
                            if (initial == null) {
                              await repo.createCouponSeries(
                                name: name,
                                description: descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                                prefix: prefix,
                                codeLength: codeLength,
                                discountType: discountType,
                                discountValue: discountValue,
                                minPurchaseAmount: minPurchase,
                                maxDiscountAmount: maxDiscount,
                                startDate: startDate,
                                endDate: endDate,
                                totalCoupons: totalCoupons!,
                                usageLimitPerCoupon: usageLimitPerCoupon,
                                usageLimitPerCustomer: usageLimitPerCustomer,
                                isActive: true,
                              );
                            } else {
                              await repo.updateCouponSeries(
                                initial.couponSeriesId,
                                name: name,
                                description: descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                                prefix: prefix,
                                codeLength: codeLength,
                                discountType: discountType,
                                discountValue: discountValue,
                                minPurchaseAmount: minPurchase,
                                maxDiscountAmount: maxDiscount,
                                startDate: startDate,
                                endDate: endDate,
                                usageLimitPerCoupon: usageLimitPerCoupon,
                                usageLimitPerCustomer: usageLimitPerCustomer,
                                isActive: isActive,
                              );
                            }
                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop(true);
                          } catch (error) {
                            _showError(error);
                          } finally {
                            if (ctx.mounted) {
                              setStateDialog(() => saving = false);
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
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

  Future<void> _showCouponCodes(CouponSeriesDto series) async {
    try {
      final codes = await ref
          .read(promotionsRepositoryProvider)
          .getCouponCodes(series.couponSeriesId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Codes • ${series.name}'),
          content: SizedBox(
            width: 640,
            child: codes.isEmpty
                ? const Text('No coupon codes generated.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: codes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final code = codes[index];
                      return ListTile(
                        dense: true,
                        title: Text(code.code),
                        subtitle: Text(
                          '${code.status} • Redeemed ${code.redeemCount} time(s)',
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openRaffleEditor({RaffleDefinitionDto? initial}) async {
    final repo = ref.read(promotionsRepositoryProvider);
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    final descCtrl = TextEditingController(text: initial?.description ?? '');
    final prefixCtrl = TextEditingController(text: initial?.prefix ?? '');
    final codeLengthCtrl = TextEditingController(
      text: (initial?.codeLength ?? 8).toString(),
    );
    final triggerAmountCtrl = TextEditingController(
      text: initial?.triggerAmount.toStringAsFixed(2) ?? '',
    );
    final couponsPerTriggerCtrl = TextEditingController(
      text: (initial?.couponsPerTrigger ?? 1).toString(),
    );
    final maxCouponsCtrl = TextEditingController(
      text: initial?.maxCouponsPerSale?.toString() ?? '',
    );

    var startDate = initial?.startDate ?? DateTime.now();
    var endDate =
        initial?.endDate ?? DateTime.now().add(const Duration(days: 30));
    var defaultAutoFill = initial?.defaultAutoFillCustomerData ?? true;
    var printAfterInvoice = initial?.printAfterInvoice ?? true;
    var isActive = initial?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        var saving = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                initial == null
                    ? 'New Raffle Definition'
                    : 'Edit Raffle Definition',
              ),
              content: SizedBox(
                width: 640,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        minLines: 2,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: prefixCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'Prefix'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: codeLengthCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Code Length',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: triggerAmountCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Trigger Amount',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: couponsPerTriggerCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Coupons Per Trigger',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: maxCouponsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Max Coupons / Sale',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Start Date'),
                              subtitle: Text(_fmtDate(startDate)),
                              trailing:
                                  const Icon(Icons.calendar_month_rounded),
                              onTap: () async {
                                final picked = await _pickDate(startDate);
                                if (picked == null) return;
                                setStateDialog(() => startDate = picked);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('End Date'),
                              subtitle: Text(_fmtDate(endDate)),
                              trailing:
                                  const Icon(Icons.calendar_month_rounded),
                              onTap: () async {
                                final picked = await _pickDate(endDate);
                                if (picked == null) return;
                                setStateDialog(() => endDate = picked);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: defaultAutoFill,
                        title: const Text('Default auto-fill customer details'),
                        subtitle: const Text(
                          'Pre-fill raffle slip customer details after invoice when a customer is selected.',
                        ),
                        onChanged: (value) {
                          setStateDialog(() => defaultAutoFill = value);
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: printAfterInvoice,
                        title: const Text('Print after invoice'),
                        subtitle: const Text(
                          'Append raffle coupons to the invoice print/share output.',
                        ),
                        onChanged: (value) {
                          setStateDialog(() => printAfterInvoice = value);
                        },
                      ),
                      if (initial != null)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: isActive,
                          title: const Text('Active'),
                          onChanged: (value) {
                            setStateDialog(() => isActive = value);
                          },
                        ),
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
                          final prefix = prefixCtrl.text.trim().toUpperCase();
                          final codeLength =
                              int.tryParse(codeLengthCtrl.text.trim());
                          final triggerAmount =
                              double.tryParse(triggerAmountCtrl.text.trim());
                          final couponsPerTrigger =
                              int.tryParse(couponsPerTriggerCtrl.text.trim());
                          final maxCoupons =
                              int.tryParse(maxCouponsCtrl.text.trim());

                          if (name.isEmpty || prefix.isEmpty) {
                            _showMessage('Name and prefix are required');
                            return;
                          }
                          if (endDate.isBefore(startDate)) {
                            _showMessage(
                              'End date must be on or after start date',
                            );
                            return;
                          }
                          if (codeLength == null || codeLength < 6) {
                            _showMessage('Code length must be at least 6');
                            return;
                          }
                          if (triggerAmount == null || triggerAmount <= 0) {
                            _showMessage('Enter a valid trigger amount');
                            return;
                          }
                          if (couponsPerTrigger == null ||
                              couponsPerTrigger < 1) {
                            _showMessage(
                              'Coupons per trigger must be at least 1',
                            );
                            return;
                          }

                          setStateDialog(() => saving = true);
                          try {
                            if (initial == null) {
                              await repo.createRaffleDefinition(
                                name: name,
                                description: descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                                prefix: prefix,
                                codeLength: codeLength,
                                startDate: startDate,
                                endDate: endDate,
                                triggerAmount: triggerAmount,
                                couponsPerTrigger: couponsPerTrigger,
                                maxCouponsPerSale: maxCoupons,
                                defaultAutoFillCustomerData: defaultAutoFill,
                                printAfterInvoice: printAfterInvoice,
                                isActive: true,
                              );
                            } else {
                              await repo.updateRaffleDefinition(
                                initial.raffleDefinitionId,
                                name: name,
                                description: descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                                prefix: prefix,
                                codeLength: codeLength,
                                startDate: startDate,
                                endDate: endDate,
                                triggerAmount: triggerAmount,
                                couponsPerTrigger: couponsPerTrigger,
                                maxCouponsPerSale: maxCoupons,
                                defaultAutoFillCustomerData: defaultAutoFill,
                                printAfterInvoice: printAfterInvoice,
                                isActive: isActive,
                              );
                            }
                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop(true);
                          } catch (error) {
                            _showError(error);
                          } finally {
                            if (ctx.mounted) {
                              setStateDialog(() => saving = false);
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
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

  Future<void> _markRaffleWinner(RaffleCouponDto coupon) async {
    final winnerNameCtrl = TextEditingController(text: coupon.winnerName ?? '');
    final winnerNotesCtrl =
        TextEditingController(text: coupon.winnerNotes ?? '');
    final repo = ref.read(promotionsRepositoryProvider);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        var saving = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: Text('Mark Winner • ${coupon.couponCode}'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: winnerNameCtrl,
                    decoration: const InputDecoration(labelText: 'Winner Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: winnerNotesCtrl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                ],
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
                        final winnerName = winnerNameCtrl.text.trim();
                        if (winnerName.isEmpty) {
                          _showMessage('Winner name is required');
                          return;
                        }
                        setStateDialog(() => saving = true);
                        try {
                          await repo.markRaffleWinner(
                            coupon.raffleCouponId,
                            winnerName: winnerName,
                            winnerNotes: winnerNotesCtrl.text.trim().isEmpty
                                ? null
                                : winnerNotesCtrl.text.trim(),
                          );
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop(true);
                        } catch (error) {
                          _showError(error);
                        } finally {
                          if (ctx.mounted) {
                            setStateDialog(() => saving = false);
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _showRaffleCoupons(RaffleDefinitionDto definition) async {
    try {
      final coupons = await ref
          .read(promotionsRepositoryProvider)
          .getRaffleCoupons(definition.raffleDefinitionId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Issued Coupons • ${definition.name}'),
          content: SizedBox(
            width: 760,
            child: coupons.isEmpty
                ? const Text('No raffle coupons issued yet.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: coupons.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final coupon = coupons[index];
                      return ListTile(
                        dense: true,
                        title: Text(coupon.couponCode),
                        subtitle: Text([
                          coupon.status,
                          if ((coupon.saleNumber ?? '').trim().isNotEmpty)
                            'Sale ${coupon.saleNumber}',
                          if ((coupon.customerName ?? '').trim().isNotEmpty)
                            coupon.customerName!,
                          _fmtDate(coupon.issuedAt),
                        ].join(' • ')),
                        trailing: coupon.status == 'WINNER'
                            ? const Chip(label: Text('Winner'))
                            : TextButton(
                                onPressed: () async {
                                  Navigator.of(ctx).pop();
                                  await _markRaffleWinner(coupon);
                                  await _showRaffleCoupons(definition);
                                },
                                child: const Text('Mark Winner'),
                              ),
                      );
                    },
                  ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _importPromotionRules() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    final file = result?.files.single;
    final path = file?.path;
    if (file == null || path == null || path.isEmpty) return;

    setState(() => _importing = true);
    try {
      final importResult =
          await ref.read(promotionsRepositoryProvider).importPromotions(
                filePath: path,
                filename: file.name,
              );
      if (!mounted) return;
      setState(() => _lastImportResult = importResult);
      await _load();
      _showMessage(
        'Import completed. Created ${importResult.created}, skipped ${importResult.skipped}.',
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Widget _buildHeader({
    required String title,
    required String subtitle,
    required List<Widget> actions,
  }) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionsTab() {
    return ListView(
      children: [
        _buildHeader(
          title: 'Campaigns',
          subtitle:
              'Manage order-level offers, loyalty tier campaigns, and product-specific pricing rules.',
          actions: [
            FilledButton.icon(
              onPressed: () => _openPromotionEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Campaign'),
            ),
          ],
        ),
        if (_promotions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No campaigns configured')),
          )
        else
          ..._promotions.map((promotion) {
            final tierNames = _tiers
                .where((tier) => promotion.loyaltyTierIds.contains(tier.tierId))
                .map((tier) => tier.name)
                .toList(growable: false);
            return Card(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                promotion.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if ((promotion.description ?? '')
                                  .trim()
                                  .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(promotion.description!),
                                ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            switch (value) {
                              case 'edit':
                                await _openPromotionEditor(initial: promotion);
                                break;
                              case 'toggle':
                                await _togglePromotion(promotion);
                                break;
                              case 'delete':
                                await _deletePromotion(promotion);
                                break;
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
                                promotion.isActive ? 'Deactivate' : 'Activate',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            '${promotion.discountScope} • ${promotion.discountType ?? 'ITEM_RULES'}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            'Value ${_formatNullableDouble(promotion.value)}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            '${_fmtDate(promotion.startDate)} to ${_fmtDate(promotion.endDate)}',
                          ),
                        ),
                        Chip(label: Text('Priority ${promotion.priority}')),
                        Chip(
                          label: Text(
                            promotion.isActive ? 'Active' : 'Inactive',
                          ),
                        ),
                        if ((promotion.applicableTo ?? '').trim().isNotEmpty)
                          Chip(
                              label:
                                  Text('Applies to ${promotion.applicableTo}')),
                        if (promotion.productRules.isNotEmpty)
                          Chip(
                            label: Text(
                              '${promotion.productRules.length} product rule(s)',
                            ),
                          ),
                        if (promotion.minAmount != null)
                          Chip(
                            label: Text(
                              'Min ${promotion.minAmount!.toStringAsFixed(2)}',
                            ),
                          ),
                      ],
                    ),
                    if (tierNames.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Tiers: ${tierNames.join(', ')}'),
                    ],
                    if (promotion.productRules.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...promotion.productRules.take(4).map(
                            (rule) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• ${rule.productName ?? 'Product #${rule.productId}'}'
                                ' • ${rule.discountType} ${rule.value.toStringAsFixed(2)}'
                                '${rule.minQty > 0 ? ' • Min qty ${rule.minQty.toStringAsFixed(2)}' : ''}',
                              ),
                            ),
                          ),
                      if (promotion.productRules.length > 4)
                        Text(
                          '+ ${promotion.productRules.length - 4} more rule(s)',
                        ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCouponSeriesTab() {
    return ListView(
      children: [
        _buildHeader(
          title: 'Coupon Series',
          subtitle:
              'Define coupon batches for use at the payment page, including reusable discount codes and usage limits.',
          actions: [
            FilledButton.icon(
              onPressed: () => _openCouponSeriesEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Series'),
            ),
          ],
        ),
        if (_couponSeries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No coupon series configured')),
          )
        else
          ..._couponSeries.map((series) {
            return Card(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                series.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if ((series.description ?? '').trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(series.description!),
                                ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            switch (value) {
                              case 'codes':
                                await _showCouponCodes(series);
                                break;
                              case 'edit':
                                await _openCouponSeriesEditor(initial: series);
                                break;
                              case 'toggle':
                                await _toggleCouponSeries(series);
                                break;
                              case 'delete':
                                await _deleteCouponSeries(series);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'codes',
                              child: Text('View Codes'),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(
                                  series.isActive ? 'Deactivate' : 'Activate'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(series.prefix)),
                        Chip(
                          label: Text(
                            '${series.discountType} ${series.discountValue.toStringAsFixed(2)}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            'Min ${series.minPurchaseAmount.toStringAsFixed(2)}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            '${_fmtDate(series.startDate)} to ${_fmtDate(series.endDate)}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            '${series.availableCoupons}/${series.totalCoupons} available',
                          ),
                        ),
                        Chip(
                          label: Text('Redeemed ${series.redeemedCoupons}'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRafflesTab() {
    return ListView(
      children: [
        _buildHeader(
          title: 'Raffles',
          subtitle:
              'Control qualifying-purchase raffle issuance, coupon printing after invoice, and traditional winner tracking.',
          actions: [
            FilledButton.icon(
              onPressed: () => _openRaffleEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Raffle'),
            ),
          ],
        ),
        if (_raffleDefinitions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No raffle definitions configured')),
          )
        else
          ..._raffleDefinitions.map((definition) {
            return Card(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                definition.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if ((definition.description ?? '')
                                  .trim()
                                  .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(definition.description!),
                                ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            switch (value) {
                              case 'coupons':
                                await _showRaffleCoupons(definition);
                                break;
                              case 'edit':
                                await _openRaffleEditor(initial: definition);
                                break;
                              case 'toggle':
                                await _toggleRaffleDefinition(definition);
                                break;
                              case 'delete':
                                await _deleteRaffleDefinition(definition);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'coupons',
                              child: Text('View Issued Coupons'),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(
                                definition.isActive ? 'Deactivate' : 'Activate',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            'Trigger ${definition.triggerAmount.toStringAsFixed(2)}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            '${definition.couponsPerTrigger} coupon(s) / trigger',
                          ),
                        ),
                        if (definition.maxCouponsPerSale != null)
                          Chip(
                            label: Text(
                              'Max ${definition.maxCouponsPerSale} / sale',
                            ),
                          ),
                        Chip(
                          label: Text(
                            '${_fmtDate(definition.startDate)} to ${_fmtDate(definition.endDate)}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            definition.defaultAutoFillCustomerData
                                ? 'Auto-fill enabled'
                                : 'Auto-fill optional',
                          ),
                        ),
                        Chip(
                          label: Text(
                            definition.printAfterInvoice
                                ? 'Print after invoice'
                                : 'No auto print',
                          ),
                        ),
                        Chip(label: Text('Issued ${definition.issuedCoupons}')),
                        Chip(label: Text('Winners ${definition.winnerCount}')),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildImportTab() {
    return ListView(
      children: [
        _buildHeader(
          title: 'Imports',
          subtitle:
              'Upload Excel pricing campaigns for specific products with percentage, fixed-amount, or fixed-price rules.',
          actions: [
            OutlinedButton.icon(
              onPressed: _importing
                  ? null
                  : () => ref
                      .read(promotionsRepositoryProvider)
                      .downloadPromotionImportTemplate(),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Template'),
            ),
            OutlinedButton.icon(
              onPressed: _importing
                  ? null
                  : () => ref
                      .read(promotionsRepositoryProvider)
                      .downloadPromotionImportExample(),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Example'),
            ),
            FilledButton.icon(
              onPressed: _importing ? null : _importPromotionRules,
              icon: _importing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: const Text('Upload .xlsx'),
            ),
          ],
        ),
        Card(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Expected columns',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Campaign Name, Description, Start Date, End Date, Priority, '
                  'Product ID, SKU, Barcode, Discount Type, Value, Min Qty',
                ),
              ],
            ),
          ),
        ),
        if (_lastImportResult != null)
          Card(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last Import',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                          label: Text('Created ${_lastImportResult!.created}')),
                      Chip(
                          label: Text('Skipped ${_lastImportResult!.skipped}')),
                      Chip(
                          label: Text('Updated ${_lastImportResult!.updated}')),
                      Chip(label: Text('Count ${_lastImportResult!.count}')),
                    ],
                  ),
                  if (_lastImportResult!.errors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Errors',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ..._lastImportResult!.errors.take(10).map(
                          (error) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $error'),
                          ),
                        ),
                    if (_lastImportResult!.errors.length > 10)
                      Text(
                        '+ ${_lastImportResult!.errors.length - 10} more error(s)',
                      ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: isWide ? 104 : null,
          leading: isWide ? const DesktopSidebarToggleLeading() : null,
          title: const Text('Promotions'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 4),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Campaigns'),
              Tab(text: 'Coupon Series'),
              Tab(text: 'Raffles'),
              Tab(text: 'Imports'),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              SwitchListTile(
                value: _activeOnly,
                title: const Text('Show active records only'),
                onChanged: (value) {
                  setState(() => _activeOnly = value);
                  _load();
                },
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPromotionsTab(),
                    _buildCouponSeriesTab(),
                    _buildRafflesTab(),
                    _buildImportTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
