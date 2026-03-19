import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/features/accounts/data/accounts_repository.dart';
import 'package:ebs_lite/features/accounts/data/models.dart';
import 'package:ebs_lite/features/dashboard/controllers/location_notifier.dart';
import 'package:ebs_lite/shared/widgets/app_empty_view.dart';
import 'package:ebs_lite/shared/widgets/app_error_view.dart';
import 'package:ebs_lite/shared/widgets/app_loading_view.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../suppliers/data/models.dart';
import '../../../suppliers/data/supplier_repository.dart';
import '../../data/inventory_repository.dart';
import '../../data/models.dart';
import '../widgets/inventory_tracking_selector.dart';
import 'asset_consumable_shared.dart';
import 'consumable_category_management_page.dart';

class ConsumableManagementPage extends ConsumerStatefulWidget {
  const ConsumableManagementPage({super.key});

  @override
  ConsumerState<ConsumableManagementPage> createState() =>
      _ConsumableManagementPageState();
}

class _ConsumableManagementPageState
    extends ConsumerState<ConsumableManagementPage> {
  bool _loading = true;
  Object? _error;
  String _query = '';
  List<ConsumableCategoryDto> _categories = const [];
  List<ConsumableEntryDto> _entries = const [];
  ConsumableSummaryDto _summary = const ConsumableSummaryDto(
    totalEntries: 0,
    totalQuantity: 0,
    totalCost: 0,
    averageUnitCost: 0,
  );
  List<ProductDto> _products = const [];
  List<LedgerBalanceDto> _ledgers = const [];
  List<SupplierDto> _nonMercantileSuppliers = const [];
  bool _lookupsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final location = ref.read(locationNotifierProvider).selected;
    if (location == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
          _entries = const [];
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final results = await Future.wait([
        repo.getConsumableCategories(),
        repo.getConsumableEntries(),
        repo.getConsumableSummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<ConsumableCategoryDto>;
        _entries = results[1] as List<ConsumableEntryDto>;
        _summary = results[2] as ConsumableSummaryDto;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ensureLookups() async {
    if (_lookupsLoaded) return;
    final inventoryRepo = ref.read(inventoryRepositoryProvider);
    final accountsRepo = ref.read(accountsRepositoryProvider);
    final suppliersRepo = ref.read(supplierRepositoryProvider);
    final results = await Future.wait([
      inventoryRepo.getProducts(),
      accountsRepo.getLedgerBalances(),
      suppliersRepo.getSuppliers(isNonMercantile: true),
    ]);
    _products = results[0] as List<ProductDto>;
    _ledgers = results[1] as List<LedgerBalanceDto>;
    _nonMercantileSuppliers = (results[2] as List<SupplierDto>)
        .where((supplier) => supplier.isActive && supplier.isNonMercantile)
        .toList();
    _lookupsLoaded = true;
  }

  Future<void> _openEntryDialog() async {
    try {
      await _ensureLookups();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
      return;
    }
    if (!mounted) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => ConsumableEntryDialog(
        categories: _categories,
        products: _products,
        ledgers: _ledgers,
        suppliers: _nonMercantileSuppliers,
      ),
    );
    if (created == true) {
      await _load();
    }
  }

  List<ConsumableEntryDto> get _filteredEntries {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _entries;
    return _entries.where((entry) {
      final values = [
        entry.entryNumber,
        entry.itemName,
        entry.productName ?? '',
        entry.categoryName ?? '',
        entry.supplierName ?? '',
        entry.offsetLedgerDisplay,
      ];
      return values.any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final location = ref.watch(locationNotifierProvider).selected;

    ref.listen(locationNotifierProvider, (previous, next) {
      final previousId = previous?.selected?.locationId;
      final nextId = next.selected?.locationId;
      if (previousId != nextId) {
        _load();
      }
    });

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Consumable Register'),
        actions: [
          IconButton(
            tooltip: 'Consumable categories',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ConsumableCategoryManagementPage(),
              ),
            ),
            icon: const Icon(Icons.category_rounded),
          ),
          IconButton(
            tooltip: 'Record consumption',
            onPressed: location == null ? null : _openEntryDialog,
            icon: const Icon(Icons.playlist_add_check_circle_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: location == null
            ? const AppEmptyView(
                title: 'Select a location',
                message:
                    'Choose a working location from the sidebar before posting or reviewing consumable usage.',
                icon: Icons.location_on_outlined,
              )
            : _loading && _entries.isEmpty
                ? const AppLoadingView(label: 'Loading consumable register')
                : _error != null && _entries.isEmpty
                    ? AppErrorView(error: _error!, onRetry: _load)
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText:
                                    'Search entry, item, category, or ledger',
                                prefixIcon: Icon(Icons.search_rounded),
                              ),
                              onChanged: (value) =>
                                  setState(() => _query = value),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Consumption entries debit the configured consumable expense ledger and credit inventory or the selected direct-entry ledger.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: isWide ? 260 : double.infinity,
                                  child: SummaryMetricCard(
                                    label: 'Consumption Entries',
                                    value: _summary.totalEntries.toString(),
                                    icon: Icons.receipt_long_rounded,
                                  ),
                                ),
                                SizedBox(
                                  width: isWide ? 260 : double.infinity,
                                  child: SummaryMetricCard(
                                    label: 'Total Quantity',
                                    value:
                                        formatQuantity(_summary.totalQuantity),
                                    icon: Icons.numbers_rounded,
                                  ),
                                ),
                                SizedBox(
                                  width: isWide ? 260 : double.infinity,
                                  child: SummaryMetricCard(
                                    label: 'Total Cost',
                                    value: formatMoney(_summary.totalCost),
                                    icon: Icons.account_balance_wallet_rounded,
                                  ),
                                ),
                                SizedBox(
                                  width: isWide ? 260 : double.infinity,
                                  child: SummaryMetricCard(
                                    label: 'Average Unit Cost',
                                    value:
                                        formatMoney(_summary.averageUnitCost),
                                    icon: Icons.analytics_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      ErrorHandler.message(_error!),
                                      style: TextStyle(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: _filteredEntries.isEmpty
                                ? const AppEmptyView(
                                    title: 'No consumable entries found',
                                    message:
                                        'Record usage from stock or post a custom consumption entry to start the register.',
                                    icon: Icons.inventory_2_outlined,
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _filteredEntries.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final entry = _filteredEntries[index];
                                      return _ConsumableEntryCard(entry: entry);
                                    },
                                  ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _ConsumableEntryCard extends StatelessWidget {
  const _ConsumableEntryCard({required this.entry});

  final ConsumableEntryDto entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
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
                        entry.itemName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Entry: ${entry.entryNumber}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatMoney(entry.totalCost),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(entry.sourceModeLabel)),
                Chip(
                  label: Text(
                    'Qty ${formatQuantity(entry.quantity)} @ ${formatMoney(entry.unitCost)}',
                  ),
                ),
                if ((entry.supplierName ?? '').trim().isNotEmpty)
                  Chip(label: Text(entry.supplierName!.trim())),
                if ((entry.categoryName ?? '').trim().isNotEmpty)
                  Chip(label: Text(entry.categoryName!.trim())),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              [
                'Consumed ${formatShortDate(entry.consumedAt)}',
                'Credit ${entry.offsetLedgerDisplay}',
              ].join(' • '),
              style: theme.textTheme.bodyMedium,
            ),
            if ((entry.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.notes!.trim(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ConsumableEntryDialog extends ConsumerStatefulWidget {
  const ConsumableEntryDialog({
    super.key,
    required this.categories,
    required this.products,
    required this.ledgers,
    required this.suppliers,
  });

  final List<ConsumableCategoryDto> categories;
  final List<ProductDto> products;
  final List<LedgerBalanceDto> ledgers;
  final List<SupplierDto> suppliers;

  @override
  ConsumerState<ConsumableEntryDialog> createState() =>
      _ConsumableEntryDialogState();
}

class _ConsumableEntryDialogState extends ConsumerState<ConsumableEntryDialog> {
  final _itemNameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitCostController = TextEditingController();
  final _notesController = TextEditingController();

  String _sourceMode = 'STOCK';
  ConsumableCategoryDto? _selectedCategory;
  ProductDto? _selectedProduct;
  SupplierDto? _selectedSupplier;
  LedgerBalanceDto? _selectedLedger;
  DateTime _consumedAt = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _unitCostController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool _needsTrackingSelection(ProductDto product) {
    return product.isSerialized ||
        product.trackingType == 'BATCH' ||
        product.barcodes.length > 1;
  }

  int? _defaultBarcodeId(ProductDto product) {
    final primary = product.barcodes.where((b) => b.isPrimary).toList();
    if (primary.isNotEmpty) return primary.first.barcodeId;
    return product.barcodes.isEmpty ? null : product.barcodes.first.barcodeId;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _consumedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _consumedAt = picked);
    }
  }

  Future<void> _save() async {
    final quantity = double.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      _showMessage('Enter a valid quantity.');
      return;
    }
    if (_sourceMode == 'STOCK' && _selectedProduct == null) {
      _showMessage('Select an existing stock item to consume.');
      return;
    }
    if (_sourceMode == 'DIRECT') {
      if (_itemNameController.text.trim().isEmpty) {
        _showMessage('Enter an item name for the direct entry.');
        return;
      }
      if (_selectedSupplier == null) {
        _showMessage('Select a non-mercantile supplier for the custom entry.');
        return;
      }
      if ((double.tryParse(_unitCostController.text.trim()) ?? -1) < 0) {
        _showMessage('Enter a valid unit cost.');
        return;
      }
      if (_selectedLedger == null) {
        _showMessage('Select the offset ledger for the direct entry.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      InventoryTrackingSelection? trackingSelection;
      int? barcodeId;
      if (_sourceMode == 'STOCK' && _selectedProduct != null) {
        if (_needsTrackingSelection(_selectedProduct!)) {
          trackingSelection = await showInventoryTrackingSelector(
            context: context,
            ref: ref,
            productId: _selectedProduct!.productId,
            productName: _selectedProduct!.name,
            quantity: quantity,
            mode: InventoryTrackingMode.issue,
          );
          if (trackingSelection == null) {
            setState(() => _saving = false);
            return;
          }
          barcodeId = trackingSelection.barcodeId;
        } else {
          barcodeId = _defaultBarcodeId(_selectedProduct!);
        }
      }

      final repo = ref.read(inventoryRepositoryProvider);
      await repo.createConsumableEntry(
        CreateConsumableEntryPayload(
          categoryId: _selectedCategory?.categoryId,
          productId:
              _sourceMode == 'STOCK' ? _selectedProduct?.productId : null,
          barcodeId: barcodeId,
          supplierId:
              _sourceMode == 'DIRECT' ? _selectedSupplier?.supplierId : null,
          itemName:
              _sourceMode == 'DIRECT' ? _itemNameController.text.trim() : null,
          sourceMode: _sourceMode,
          quantity: quantity,
          unitCost: _sourceMode == 'DIRECT'
              ? double.tryParse(_unitCostController.text.trim())
              : null,
          consumedAt: _consumedAt,
          offsetAccountId:
              _sourceMode == 'DIRECT' ? _selectedLedger?.accountId : null,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          serialNumbers: trackingSelection?.serialNumbers ?? const [],
          batchAllocations: trackingSelection?.batchAllocations ?? const [],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _showMessage(ErrorHandler.message(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = widget.categories
        .where((item) =>
            item.isActive || item.categoryId == _selectedCategory?.categoryId)
        .toList();
    final eligibleSupplierIds =
        widget.suppliers.map((supplier) => supplier.supplierId).toSet();
    final activeProducts = widget.products
        .where((item) =>
            item.isActive &&
            item.defaultSupplierId != null &&
            eligibleSupplierIds.contains(item.defaultSupplierId))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final suppliers = [...widget.suppliers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final supplierById = {
      for (final supplier in widget.suppliers) supplier.supplierId: supplier,
    };

    return AlertDialog(
      title: const Text('Record Consumption'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'STOCK',
                    label: Text('From Stock'),
                    icon: Icon(Icons.inventory_2_rounded),
                  ),
                  ButtonSegment(
                    value: 'DIRECT',
                    label: Text('Custom Item'),
                    icon: Icon(Icons.edit_note_rounded),
                  ),
                ],
                selected: {_sourceMode},
                onSelectionChanged: _saving
                    ? null
                    : (value) {
                        setState(() {
                          _sourceMode = value.first;
                          if (_sourceMode == 'STOCK') {
                            _selectedLedger = null;
                            _selectedSupplier = null;
                            _itemNameController.clear();
                            _unitCostController.clear();
                          } else {
                            _selectedProduct = null;
                          }
                        });
                      },
              ),
              const SizedBox(height: 16),
              _SelectionField(
                label: 'Consumable Category',
                value: _selectedCategory?.name ?? 'Select category',
                icon: Icons.category_rounded,
                onTap: () async {
                  final picked =
                      await showSearchPickerDialog<ConsumableCategoryDto>(
                    context: context,
                    title: 'Select Consumable Category',
                    items: filteredCategories,
                    titleBuilder: (item) => item.name,
                    subtitleBuilder: (item) => item.ledgerDisplay,
                    searchTextBuilder: (item) =>
                        '${item.name} ${item.description ?? ''} ${item.ledgerDisplay}',
                  );
                  if (picked != null) {
                    setState(() => _selectedCategory = picked);
                  }
                },
              ),
              if (_selectedCategory != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Expense ledger: ${_selectedCategory!.ledgerDisplay}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              if (_sourceMode == 'STOCK')
                _SelectionField(
                  label: 'Existing Stock Item',
                  value: _selectedProduct == null
                      ? 'Select stock item'
                      : _selectedProduct!.name,
                  icon: Icons.inventory_rounded,
                  onTap: () async {
                    final picked = await showSearchPickerDialog<ProductDto>(
                      context: context,
                      title: 'Select Stock Item',
                      items: activeProducts,
                      titleBuilder: (item) => item.name,
                      subtitleBuilder: (item) => [
                        if ((item.sku ?? '').trim().isNotEmpty) item.sku!,
                        if (supplierById[item.defaultSupplierId] != null)
                          supplierById[item.defaultSupplierId]!.name,
                        humanizeToken(item.itemType),
                      ].join(' • '),
                      searchTextBuilder: (item) =>
                          '${item.name} ${item.sku ?? ''} ${item.itemType} ${supplierById[item.defaultSupplierId]?.name ?? ''}',
                    );
                    if (picked != null) {
                      setState(() => _selectedProduct = picked);
                    }
                  },
                )
              else ...[
                TextField(
                  controller: _itemNameController,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    prefixIcon: Icon(Icons.badge_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                _SelectionField(
                  label: 'Supplier',
                  value: _selectedSupplier == null
                      ? 'Select non-mercantile supplier'
                      : _selectedSupplier!.name,
                  icon: Icons.local_shipping_rounded,
                  onTap: () async {
                    final picked = await showSearchPickerDialog<SupplierDto>(
                      context: context,
                      title: 'Select Supplier',
                      items: suppliers,
                      titleBuilder: (item) => item.name,
                      subtitleBuilder: (item) => item.usageLabel,
                      searchTextBuilder: (item) =>
                          '${item.name} ${item.contactPerson ?? ''} ${item.phone ?? ''} ${item.usageLabel}',
                    );
                    if (picked != null) {
                      setState(() => _selectedSupplier = picked);
                    }
                  },
                ),
              ],
              const SizedBox(height: 12),
              if (_sourceMode == 'DIRECT') ...[
                TextField(
                  controller: _unitCostController,
                  enabled: !_saving,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Unit Cost',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                _SelectionField(
                  label: 'Offset Ledger',
                  value: _selectedLedger == null
                      ? 'Select offset ledger'
                      : [
                          _selectedLedger!.accountCode ?? '',
                          _selectedLedger!.accountName ?? '',
                        ].where((item) => item.trim().isNotEmpty).join(' '),
                  icon: Icons.account_balance_wallet_rounded,
                  onTap: () async {
                    final picked =
                        await showSearchPickerDialog<LedgerBalanceDto>(
                      context: context,
                      title: 'Select Offset Ledger',
                      items: widget.ledgers,
                      titleBuilder: (item) => [
                        item.accountCode ?? '',
                        item.accountName ?? 'Ledger #${item.accountId}',
                      ].where((value) => value.trim().isNotEmpty).join(' '),
                      subtitleBuilder: (item) => [
                        item.accountType ?? '',
                        'Balance ${formatMoney(item.balance)}',
                      ].where((value) => value.trim().isNotEmpty).join(' • '),
                      searchTextBuilder: (item) => [
                        item.accountId.toString(),
                        item.accountCode ?? '',
                        item.accountName ?? '',
                        item.accountType ?? '',
                      ].join(' '),
                    );
                    if (picked != null) {
                      setState(() => _selectedLedger = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
              ] else
                Text(
                  'Stock-backed usage credits inventory automatically. Variation, batch, or serial details are requested only when needed.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      enabled: !_saving,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: Icon(Icons.numbers_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickDate,
                      icon: const Icon(Icons.event_rounded),
                      label: Text(
                        'Consumed ${formatShortDate(_consumedAt)}',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                enabled: !_saving,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _saving ? null : () => Navigator.of(context).maybePop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : const Icon(Icons.save_rounded),
          label: const Text('Post Entry'),
        ),
      ],
    );
  }
}

class _SelectionField extends StatelessWidget {
  const _SelectionField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }
}
