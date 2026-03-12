import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_selection_dialog.dart';
import '../../data/inventory_repository.dart';
import '../../data/models.dart';
import '../widgets/product_storage_editor.dart';
import '../../../suppliers/data/supplier_repository.dart';
import '../../../dashboard/data/taxes_repository.dart';
import '../../../dashboard/controllers/location_notifier.dart';

class ProductEditPage extends ConsumerStatefulWidget {
  const ProductEditPage({super.key, required this.productId});
  final int productId;

  @override
  ConsumerState<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends ConsumerState<ProductEditPage> {
  final _formKey = GlobalKey<FormState>();
  ProductDto? _product;
  bool _loading = true;
  bool _saving = false;

  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _reorder = TextEditingController();
  final _purchaseFactor = TextEditingController(text: '1');
  final _sellingFactor = TextEditingController(text: '1');
  bool _serialTracked = false;
  bool _batchTracked = false;
  bool _active = true;
  bool _weighable = false;
  final _itemCode = TextEditingController();
  List<ProductBarcodeDto> _barcodes = [];
  // Attributes
  List<ProductAttributeDefinitionDto> _attrDefs = const [];
  final Map<int, TextEditingController> _attrText = {};
  final Map<int, bool> _attrBool = {};
  final Map<int, String?> _attrSelect = {};

  // Pick lists
  List<CategoryDto> _categories = const [];
  List<BrandDto> _brands = const [];
  List<UnitDto> _units = const [];
  int? _categoryId;
  int? _brandId;
  int? _unitId;
  int? _purchaseUnitId;
  int? _sellingUnitId;
  String _purchaseUomMode = 'LOOSE';
  String _sellingUomMode = 'LOOSE';
  int? _defaultSupplierId;
  int? _taxId;
  String? _taxName;
  final _categoryController = TextEditingController();
  final _brandController = TextEditingController();
  final _supplierController = TextEditingController();
  // description/weight/dimensions removed; use attributes
  List<ProductStorageAssignmentPayload> _storageAssignments = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _price.dispose();
    _cost.dispose();
    _reorder.dispose();
    _purchaseFactor.dispose();
    _sellingFactor.dispose();
    _itemCode.dispose();
    _categoryController.dispose();
    _brandController.dispose();
    _supplierController.dispose();
    for (final c in _attrText.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final results = await Future.wait([
        repo.getProduct(widget.productId),
        repo.getAttributeDefinitions(),
        repo.getCategories(),
        repo.getBrands(),
        repo.getUnits(),
      ]);
      final p = results[0] as ProductDto;
      _attrDefs = results[1] as List<ProductAttributeDefinitionDto>;
      _categories = results[2] as List<CategoryDto>;
      _brands = results[3] as List<BrandDto>;
      _units = results[4] as List<UnitDto>;
      _product = p;
      _name.text = p.name;
      _sku.text = p.sku ?? '';
      _price.text = p.sellingPrice?.toString() ?? '';
      _cost.text = p.costPrice?.toString() ?? '';
      _reorder.text = p.reorderLevel.toString();
      _serialTracked = p.isSerialized;
      _batchTracked = p.trackingType == 'BATCH';
      _active = p.isActive;
      _barcodes = List.of(p.barcodes);
      final pri = _barcodes.firstWhere(
        (b) => b.isPrimary,
        orElse: () => _barcodes.isNotEmpty
            ? _barcodes.first
            : ProductBarcodeDto(barcode: '', packSize: 1, isPrimary: true),
      );
      _itemCode.text = pri.barcode;
      _categoryId = p.categoryId;
      _brandId = p.brandId;
      _unitId = p.unitId;
      _purchaseUnitId = p.purchaseUnitId ?? p.unitId;
      _sellingUnitId = p.sellingUnitId ?? p.unitId;
      _purchaseUomMode = p.purchaseUomMode;
      _sellingUomMode = p.sellingUomMode;
      _purchaseFactor.text = p.purchaseToStockFactor.toString();
      _sellingFactor.text = p.sellingToStockFactor.toString();
      _weighable = p.isWeighable;
      _defaultSupplierId = p.defaultSupplierId;
      _categoryController.text = _categories
          .firstWhere(
            (c) => c.categoryId == _categoryId,
            orElse: () => CategoryDto(categoryId: -1, name: ''),
          )
          .name;
      _brandController.text = _brands
          .firstWhere(
            (b) => b.brandId == _brandId,
            orElse: () => BrandDto(brandId: -1, name: ''),
          )
          .name;
      // Load supplier name if a default supplier is already linked
      if (_defaultSupplierId != null) {
        try {
          final sup = await ref
              .read(supplierRepositoryProvider)
              .getSupplier(_defaultSupplierId!);
          _supplierController.text = sup.name;
        } catch (_) {
          _supplierController.text = '';
        }
      } else {
        _supplierController.text = '';
      }
      // Initialize attribute controls
      final existing = p.attributes ?? const <int, String>{};
      for (final d in _attrDefs) {
        final existingVal = existing[d.attributeId];
        switch (d.type) {
          case 'BOOLEAN':
            _attrBool[d.attributeId] =
                (existingVal ?? '').toLowerCase() == 'true';
            break;
          case 'SELECT':
            if (d.options != null && d.options!.isNotEmpty) {
              _attrSelect[d.attributeId] =
                  existingVal != null && d.options!.contains(existingVal)
                      ? existingVal
                      : d.options!.first;
            } else {
              _attrSelect[d.attributeId] = existingVal;
            }
            break;
          default:
            _attrText[d.attributeId] =
                TextEditingController(text: existingVal ?? '');
        }
      }
      // Read tax from product.taxId and map to name+percentage
      final id = p.taxId;
      if (id > 0) {
        _taxId = id;
        try {
          final taxes = await ref.read(taxesRepositoryProvider).getTaxes();
          final t = taxes.firstWhere((e) => e.taxId == id,
              orElse: () => const TaxDto(
                  taxId: -1,
                  name: '',
                  percentage: 0,
                  isCompound: false,
                  isActive: true));
          if (t.taxId == id) {
            final pct = _formatPercent(t.percentage);
            _taxName = '${t.name} ($pct%)';
          } else {
            _taxName = 'ID: $id';
          }
        } catch (_) {
          _taxName = 'ID: $id';
        }
      }
      final selectedLocation = ref.read(locationNotifierProvider).selected;
      if (selectedLocation != null) {
        final assignments = await repo.getProductStorageAssignments(
          widget.productId,
          locationId: selectedLocation.locationId,
        );
        _storageAssignments = assignments
            .map(
              (e) => ProductStorageAssignmentPayload(
                storageAssignmentId: e.storageAssignmentId,
                barcodeId: e.barcodeId,
                barcode: e.barcode,
                storageType: e.storageType,
                storageLabel: e.storageLabel,
                notes: e.notes,
                isPrimary: e.isPrimary,
                sortOrder: e.sortOrder,
              ),
            )
            .toList();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;
    final p = _product;
    if (p == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      // ensure primary barcode from item code
      if (_itemCode.text.trim().isNotEmpty) {
        final idx = _barcodes.indexWhere((b) => b.isPrimary);
        if (idx >= 0) {
          _barcodes[idx] = _copyBarcode(
            _barcodes[idx],
            barcode: _itemCode.text.trim(),
            isPrimary: true,
          );
        } else if (_barcodes.isNotEmpty) {
          _barcodes[0] = _copyBarcode(
            _barcodes[0],
            barcode: _itemCode.text.trim(),
            isPrimary: true,
          );
        } else {
          _barcodes.add(ProductBarcodeDto(
            barcode: _itemCode.text.trim(),
            packSize: 1,
            isPrimary: true,
            isActive: true,
          ));
        }
      }

      // Build attributes
      var attrs = _buildAttributesMap();
      if (_taxId == null) {
        throw StateError('Please select Tax Type');
      }

      final updated = ProductDto(
        productId: p.productId,
        companyId: p.companyId,
        categoryId: _categoryId,
        brandId: _brandId,
        unitId: _unitId,
        purchaseUnitId: _purchaseUnitId,
        sellingUnitId: _sellingUnitId,
        purchaseUomMode: _purchaseUomMode,
        sellingUomMode: _sellingUomMode,
        purchaseToStockFactor:
            double.tryParse(_purchaseFactor.text.trim()) ?? 1.0,
        sellingToStockFactor:
            double.tryParse(_sellingFactor.text.trim()) ?? 1.0,
        isWeighable: _weighable,
        defaultSupplierId: _defaultSupplierId,
        name: _name.text.trim(),
        sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
        description: null,
        costPrice: double.tryParse(_cost.text.trim()),
        sellingPrice: double.tryParse(_price.text.trim()),
        reorderLevel: int.tryParse(_reorder.text.trim()) ?? 0,
        weight: null,
        dimensions: null,
        isSerialized: _serialTracked,
        trackingType: _batchTracked ? 'BATCH' : 'VARIANT',
        isActive: _active,
        barcodes: _barcodes,
        attributes: attrs,
        taxId: _taxId!,
      );
      await repo.updateProduct(updated);
      final selectedLocation = ref.read(locationNotifierProvider).selected;
      if (selectedLocation != null) {
        await repo.replaceProductStorageAssignments(
          widget.productId,
          locationId: selectedLocation.locationId,
          assignments: _storageAssignments
              .where((e) =>
                  (e.barcode != null && e.barcode!.trim().isNotEmpty) &&
                  e.storageLabel.trim().isNotEmpty)
              .toList(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatPercent(double p) =>
      (p % 1 == 0) ? p.toStringAsFixed(0) : p.toStringAsFixed(2);

  ProductBarcodeDto _copyBarcode(
    ProductBarcodeDto source, {
    String? barcode,
    int? packSize,
    double? costPrice,
    double? sellingPrice,
    bool? isPrimary,
    String? variantName,
    Map<String, dynamic>? variantAttributes,
    bool? isActive,
  }) {
    return ProductBarcodeDto(
      barcodeId: source.barcodeId,
      barcode: barcode ?? source.barcode,
      packSize: packSize ?? source.packSize,
      costPrice: costPrice ?? source.costPrice,
      sellingPrice: sellingPrice ?? source.sellingPrice,
      isPrimary: isPrimary ?? source.isPrimary,
      variantName: variantName ?? source.variantName,
      variantAttributes: variantAttributes ?? source.variantAttributes,
      isActive: isActive ?? source.isActive,
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .deleteProduct(widget.productId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Product'),
          actions: [
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _loading ? null : _delete,
            ),
            const SizedBox(width: 4),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'General'),
              Tab(text: 'UOM'),
              Tab(text: 'Barcodes'),
              Tab(text: 'Attributes'),
              Tab(text: 'Storage'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Form(
                  key: _formKey,
                  child: TabBarView(
                    children: [
                      _buildGeneralTab(),
                      _buildUomTab(),
                      _buildBarcodeTab(),
                      _buildAttributesTab(),
                      _buildStorageTab(),
                    ],
                  ),
                ),
              ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Text('Save changes'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<int, String> _buildAttributesMap() {
    final map = <int, String>{};
    for (final d in _attrDefs) {
      switch (d.type) {
        case 'BOOLEAN':
          final v = _attrBool[d.attributeId] ?? false;
          if (d.isRequired || v) map[d.attributeId] = v.toString();
          break;
        case 'SELECT':
          final v = _attrSelect[d.attributeId];
          if (v != null && v.isNotEmpty) {
            map[d.attributeId] = v;
          } else if (d.isRequired && (d.options?.isNotEmpty ?? false)) {
            map[d.attributeId] = d.options!.first;
          }
          break;
        default:
          final c = _attrText[d.attributeId];
          final v = c?.text.trim() ?? '';
          if (v.isNotEmpty || d.isRequired) map[d.attributeId] = v;
      }
    }
    return map;
  }

  Widget _buildStorageTab() {
    final selectedLocation = ref.watch(locationNotifierProvider).selected;
    if (selectedLocation == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Select a location first to manage storage details.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ProductStorageEditor(
      entries: _storageAssignments,
      barcodes: _barcodes,
      locationLabel: selectedLocation.name,
      enabled: !_saving,
      onChanged: (entries) => setState(() => _storageAssignments = entries),
    );
  }

  String _unitLabel(int? unitId) {
    final u = _units.firstWhere(
      (e) => e.unitId == unitId,
      orElse: () => UnitDto(unitId: -1, name: ''),
    );
    if (u.unitId == -1) return '';
    return '${u.name}${u.symbol != null ? ' (${u.symbol})' : ''}';
  }

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Name'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _supplierController,
          readOnly: true,
          decoration: const InputDecoration(labelText: 'Default Supplier'),
          onTap: () async {
            final picked = await _openSupplierPicker();
            if (picked != null) {
              setState(() {
                _defaultSupplierId = picked.supplierId;
                _supplierController.text = picked.name;
              });
            }
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _itemCode,
          decoration: const InputDecoration(labelText: 'Item Code'),
          keyboardType: TextInputType.number,
          enabled: false,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Required'
              : (!RegExp(r'^\d+$').hasMatch(v.trim()) ? 'Digits only' : null),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _sku,
          decoration: const InputDecoration(labelText: 'SKU'),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _price,
                decoration: const InputDecoration(labelText: 'Selling Price'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _cost,
                decoration: const InputDecoration(labelText: 'Cost Price'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _reorder,
          decoration: const InputDecoration(labelText: 'Reorder Level'),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        Text(
          'Variation / barcode tracking is always enabled.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          value: _batchTracked,
          onChanged: (v) => setState(() => _batchTracked = v),
          title: const Text('Batch / expiry tracking'),
          subtitle: const Text(
            'Receive stock into batches and choose the batch during stock-out.',
          ),
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile.adaptive(
          value: _serialTracked,
          onChanged: (v) => setState(() => _serialTracked = v),
          title: const Text('Serial number tracking'),
          subtitle: const Text(
            'Every stock unit requires a unique serial number.',
          ),
          contentPadding: EdgeInsets.zero,
        ),
        Text(
          _batchTracked && _serialTracked
              ? 'This product tracks variation, batch, and serial together.'
              : _batchTracked
                  ? 'This product tracks variation and batch.'
                  : _serialTracked
                      ? 'This product tracks variation and serial.'
                      : 'This product tracks stock by variation only.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          value: _weighable,
          onChanged: (v) => setState(() => _weighable = v),
          title: const Text('Weighable'),
          subtitle: const Text('Prompt quantity entry when selected in POS'),
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile.adaptive(
          value: _active,
          onChanged: (v) => setState(() => _active = v),
          title: const Text('Active'),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SelectField(
                label: 'Category',
                valueText: _categories
                    .firstWhere(
                      (c) => c.categoryId == _categoryId,
                      orElse: () => CategoryDto(categoryId: -1, name: ''),
                    )
                    .name,
                icon: Icons.category_rounded,
                onTap: () async {
                  final picked = await _openSingleCategoryDialog();
                  if (picked != null) {
                    setState(() {
                      _categoryId = picked.categoryId;
                      _categoryController.text = picked.name;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SelectField(
                label: 'Brand',
                valueText: _brands
                    .firstWhere(
                      (b) => b.brandId == _brandId,
                      orElse: () => BrandDto(brandId: -1, name: ''),
                    )
                    .name,
                icon: Icons.sell_rounded,
                onTap: () async {
                  final picked = await _openSingleBrandDialog();
                  if (picked != null) {
                    setState(() {
                      _brandId = picked.brandId;
                      _brandController.text = picked.name;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SelectField(
          label: 'Tax Type',
          valueText: _taxName ?? 'None',
          icon: Icons.percent_rounded,
          onTap: () async {
            final picked = await _openTaxPicker();
            if (picked != null) {
              setState(() {
                _taxId = picked.taxId;
                final pct = (picked.percentage % 1 == 0)
                    ? picked.percentage.toStringAsFixed(0)
                    : picked.percentage.toStringAsFixed(2);
                _taxName = '${picked.name} ($pct%)';
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildUomTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SelectField(
          label: 'Stock Keeping UOM',
          valueText: _unitLabel(_unitId),
          icon: Icons.inventory_2_outlined,
          onTap: () async {
            final picked = await _openSingleUnitDialog();
            if (picked != null) {
              setState(() {
                _unitId = picked.unitId;
                _purchaseUnitId ??= picked.unitId;
                _sellingUnitId ??= picked.unitId;
              });
            }
          },
        ),
        const SizedBox(height: 16),
        _SelectField(
          label: 'Purchase UOM',
          valueText: _unitLabel(_purchaseUnitId),
          icon: Icons.shopping_bag_outlined,
          onTap: () async {
            final picked = await _openSingleUnitDialog();
            if (picked != null) {
              setState(() => _purchaseUnitId = picked.unitId);
            }
          },
        ),
        const SizedBox(height: 12),
        _buildModeSelector(
          label: 'Purchase Mode',
          value: _purchaseUomMode,
          onChanged: (value) => setState(() => _purchaseUomMode = value),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _purchaseFactor,
          decoration: const InputDecoration(
            labelText: 'Stock Qty per Purchase UOM',
            helperText: 'Example: 12 means 1 purchase UOM = 12 stock units',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) {
            final value = double.tryParse((v ?? '').trim());
            if (value == null || value <= 0) return 'Enter a value above 0';
            return null;
          },
        ),
        const SizedBox(height: 20),
        _SelectField(
          label: 'Selling UOM',
          valueText: _unitLabel(_sellingUnitId),
          icon: Icons.point_of_sale_outlined,
          onTap: () async {
            final picked = await _openSingleUnitDialog();
            if (picked != null) {
              setState(() => _sellingUnitId = picked.unitId);
            }
          },
        ),
        const SizedBox(height: 12),
        _buildModeSelector(
          label: 'Selling Mode',
          value: _sellingUomMode,
          onChanged: (value) => setState(() => _sellingUomMode = value),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _sellingFactor,
          decoration: const InputDecoration(
            labelText: 'Stock Qty per Selling UOM',
            helperText:
                'Example: 0.5 for half-kg, 1 for loose, 6 for half-dozen',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) {
            final value = double.tryParse((v ?? '').trim());
            if (value == null || value <= 0) return 'Enter a value above 0';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildBarcodeTab() {
    final secondary =
        _barcodes.where((b) => !b.isPrimary).toList(growable: false);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () async {
              final added = await _showBarcodeDialog(context);
              if (added != null) {
                setState(() => _barcodes.add(added));
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Barcode'),
          ),
        ),
        const SizedBox(height: 8),
        if (secondary.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: Text('No secondary barcodes')),
          )
        else
          ..._barcodes
              .asMap()
              .entries
              .where((e) => !e.value.isPrimary)
              .map((entry) {
            final i = entry.key;
            final b = entry.value;
            return Card(
              elevation: 0,
              child: ListTile(
                title: Text(b.barcode),
                subtitle: Text([
                  if ((b.variantName ?? '').trim().isNotEmpty) b.variantName!,
                  'Conversion: ${b.packSize ?? 1}',
                  'Selling: ${b.sellingPrice?.toStringAsFixed(2) ?? '-'}',
                ].join(' • ')),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        final edited =
                            await _showBarcodeDialog(context, initial: b);
                        if (edited != null) {
                          setState(() => _barcodes[i] = edited);
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => setState(() => _barcodes.removeAt(i)),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAttributesTab() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_attrDefs.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: Text('No attribute definitions')),
          )
        else ...[
          Text('Attributes', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._attrDefs.map(_buildAttrField),
        ],
      ],
    );
  }

  Widget _buildModeSelector({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: RadioGroup<String>(
        groupValue: value,
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
        child: const Row(
          children: [
            Radio<String>(value: 'LOOSE'),
            Text('Loose'),
            SizedBox(width: 16),
            Radio<String>(value: 'PACK'),
            Text('Pack'),
          ],
        ),
      ),
    );
  }

  Widget _buildAttrField(ProductAttributeDefinitionDto d) {
    switch (d.type) {
      case 'BOOLEAN':
        return SwitchListTile.adaptive(
          value: _attrBool[d.attributeId] ?? false,
          onChanged: (v) => setState(() => _attrBool[d.attributeId] = v),
          title: Text(d.name + (d.isRequired ? ' *' : '')),
          contentPadding: EdgeInsets.zero,
        );
      case 'SELECT':
        final opts = d.options ?? const <String>[];
        return _SelectField(
          label: d.name + (d.isRequired ? ' *' : ''),
          valueText:
              _attrSelect[d.attributeId] ?? (opts.isNotEmpty ? opts.first : ''),
          icon: Icons.list_rounded,
          onTap: () async {
            final picked = await _openAttributeOptionDialog(d);
            if (picked != null) {
              setState(() => _attrSelect[d.attributeId] = picked);
            }
          },
        );
      case 'DATE':
        final c =
            _attrText.putIfAbsent(d.attributeId, () => TextEditingController());
        return TextFormField(
          controller: c,
          readOnly: true,
          decoration:
              InputDecoration(labelText: d.name + (d.isRequired ? ' *' : '')),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(now.year - 10),
              lastDate: DateTime(now.year + 10),
            );
            if (picked != null) {
              final s =
                  '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              c.text = s;
            }
          },
          validator: (v) {
            if (d.isRequired && (v == null || v.trim().isEmpty)) {
              return 'Required';
            }
            return null;
          },
        );
      default:
        final c =
            _attrText.putIfAbsent(d.attributeId, () => TextEditingController());
        return TextFormField(
          controller: c,
          decoration:
              InputDecoration(labelText: d.name + (d.isRequired ? ' *' : '')),
          keyboardType: d.type == 'NUMBER'
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          validator: (v) {
            if (d.isRequired && (v == null || v.trim().isEmpty)) {
              return 'Required';
            }
            if ((v ?? '').isNotEmpty &&
                d.type == 'NUMBER' &&
                double.tryParse(v!.trim()) == null) {
              return 'Enter a valid number';
            }
            return null;
          },
        );
    }
  }

  Future<CategoryDto?> _openSingleCategoryDialog() async {
    String query = '';
    List<CategoryDto> filtered = _categories;
    int? current = _categoryId;
    return showDialog<CategoryDto?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Select Category'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search categories',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) {
                    query = v.toLowerCase();
                    setInner(() {
                      filtered = _categories
                          .where((c) => c.name.toLowerCase().contains(query))
                          .toList();
                    });
                  },
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No categories'))
                      : RadioGroup<int>(
                          groupValue: current,
                          onChanged: (value) => setInner(() => current = value),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final c = filtered[i];
                              return RadioListTile<int>(
                                value: c.categoryId,
                                title: Text(c.name),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final sel = _categories.firstWhere(
                  (c) => c.categoryId == current,
                  orElse: () => CategoryDto(categoryId: -1, name: ''),
                );
                Navigator.of(context).pop(sel.categoryId == -1 ? null : sel);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<BrandDto?> _openSingleBrandDialog() async {
    String query = '';
    List<BrandDto> filtered = _brands;
    int? current = _brandId;
    return showDialog<BrandDto?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Select Brand'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search brands',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) {
                    query = v.toLowerCase();
                    setInner(() {
                      filtered = _brands
                          .where((b) => b.name.toLowerCase().contains(query))
                          .toList();
                    });
                  },
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No brands'))
                      : RadioGroup<int>(
                          groupValue: current,
                          onChanged: (value) => setInner(() => current = value),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final b = filtered[i];
                              return RadioListTile<int>(
                                value: b.brandId,
                                title: Text(b.name),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final sel = _brands.firstWhere(
                  (b) => b.brandId == current,
                  orElse: () => BrandDto(brandId: -1, name: ''),
                );
                Navigator.of(context).pop(sel.brandId == -1 ? null : sel);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<UnitDto?> _openSingleUnitDialog() async {
    String query = '';
    List<UnitDto> filtered = _units;
    int? current = _unitId;
    return showDialog<UnitDto?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Select Unit'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search units',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) {
                    query = v.toLowerCase();
                    setInner(() {
                      filtered = _units
                          .where((u) =>
                              u.name.toLowerCase().contains(query) ||
                              (u.symbol ?? '').toLowerCase().contains(query))
                          .toList();
                    });
                  },
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No units'))
                      : RadioGroup<int>(
                          groupValue: current,
                          onChanged: (value) => setInner(() => current = value),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final u = filtered[i];
                              final label =
                                  '${u.name}${u.symbol != null ? ' (${u.symbol})' : ''}';
                              return RadioListTile<int>(
                                value: u.unitId,
                                title: Text(label),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final sel = _units.firstWhere(
                  (u) => u.unitId == current,
                  orElse: () => UnitDto(unitId: -1, name: ''),
                );
                Navigator.of(context).pop(sel.unitId == -1 ? null : sel);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _openAttributeOptionDialog(
      ProductAttributeDefinitionDto d) async {
    final opts = d.options ?? const <String>[];
    String? current =
        _attrSelect[d.attributeId] ?? (opts.isNotEmpty ? opts.first : null);
    return showDialog<String?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: Text('Select ${d.name}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: RadioGroup<String>(
                    groupValue: current,
                    onChanged: (value) => setInner(() => current = value),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: opts.length,
                      itemBuilder: (context, i) {
                        final o = opts[i];
                        return RadioListTile<String>(
                          value: o,
                          title: Text(o),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(current),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<_SupplierPick?> _openSupplierPicker() async {
    final repo = ref.read(supplierRepositoryProvider);
    List<_SupplierPick> initial = const [];
    try {
      initial = (await repo.getSuppliers())
          .map((e) => _SupplierPick(e.supplierId, e.name))
          .toList();
    } catch (_) {}
    String query = '';
    List<_SupplierPick> results = List.of(initial);
    if (!mounted) return null;
    return showDialog<_SupplierPick>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AppSelectionDialog(
          title: 'Select Supplier',
          maxWidth: 560,
          searchField: TextField(
            decoration: const InputDecoration(
              hintText: 'Search',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (v) async {
              query = v.trim();
              final list = await repo.getSuppliers(search: query);
              setInner(() => results = list
                  .map((e) => _SupplierPick(e.supplierId, e.name))
                  .toList());
            },
          ),
          body: results.isEmpty
              ? const Center(child: Text('No suppliers'))
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final s = results[i];
                    return ListTile(
                      title: Text(s.name),
                      onTap: () => Navigator.of(context).pop(s),
                    );
                  },
                ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }

  Future<TaxDto?> _openTaxPicker() async {
    final repo = ref.read(taxesRepositoryProvider);
    List<TaxDto> taxes = [];
    try {
      taxes = await repo.getTaxes();
    } catch (_) {}
    int? current = _taxId;
    if (current == null && taxes.isNotEmpty) {
      current = taxes.first.taxId;
    }
    if (!mounted) return null;

    String subtitleFor(TaxDto t) {
      final pct = (t.percentage % 1 == 0)
          ? t.percentage.toStringAsFixed(0)
          : t.percentage.toStringAsFixed(2);
      final comps = t.components
          .where((c) => c.name.trim().isNotEmpty && c.percentage != 0)
          .toList(growable: false);
      if (comps.isEmpty) return '$pct %';
      final breakdown = comps
          .map((c) =>
              '${c.name.trim()} ${(c.percentage % 1 == 0) ? c.percentage.toStringAsFixed(0) : c.percentage.toStringAsFixed(2)}')
          .join(' + ');
      return '$pct % • $breakdown';
    }

    return showDialog<TaxDto?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Select Tax Type'),
          content: SizedBox(
            width: 500,
            child: taxes.isEmpty
                ? const Center(child: Text('No tax types'))
                : RadioGroup<int>(
                    groupValue: current,
                    onChanged: (value) => setInner(() => current = value),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: taxes.length,
                      itemBuilder: (context, i) {
                        final t = taxes[i];
                        return RadioListTile<int>(
                          value: t.taxId,
                          title: Text(t.name),
                          subtitle: Text(subtitleFor(t)),
                        );
                      },
                    ),
                  ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (current == null) {
                  Navigator.pop(context, null);
                  return;
                }
                final sel = taxes.firstWhere((e) => e.taxId == current,
                    orElse: () => taxes.first);
                Navigator.pop(context, sel);
              },
              child: const Text('Apply'),
            )
          ],
        ),
      ),
    );
  }
}

class _SupplierPick {
  final int supplierId;
  final String name;
  const _SupplierPick(this.supplierId, this.name);
}

class _SelectField extends StatelessWidget {
  const _SelectField(
      {required this.label,
      required this.valueText,
      required this.icon,
      required this.onTap});
  final String label;
  final String valueText;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                valueText,
                style: theme.textTheme.bodyMedium,
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

Future<ProductBarcodeDto?> _showBarcodeDialog(BuildContext context,
    {ProductBarcodeDto? initial}) async {
  final code = TextEditingController(text: initial?.barcode ?? '');
  final variant = TextEditingController(text: initial?.variantName ?? '');
  final pack = TextEditingController(text: (initial?.packSize ?? 1).toString());
  final sell =
      TextEditingController(text: initial?.sellingPrice?.toString() ?? '');
  return showDialog<ProductBarcodeDto>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(initial == null ? 'Add Barcode' : 'Edit Barcode'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Barcode'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: variant,
              decoration: const InputDecoration(labelText: 'Variation Name'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pack,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Conversion'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: sell,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Selling Price'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final s = code.text.trim();
            if (s.isEmpty || !RegExp(r'^\d+$').hasMatch(s)) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(
                    content: Text('Barcode must be digits only')));
              return;
            }
            final p = int.tryParse(pack.text.trim()) ?? 1;
            if (p < 1) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(
                    content: Text('Conversion must be at least 1')));
              return;
            }
            final sp = double.tryParse(sell.text.trim());
            Navigator.of(context).pop(ProductBarcodeDto(
              barcodeId: initial?.barcodeId,
              barcode: s,
              packSize: p,
              costPrice: initial?.costPrice,
              sellingPrice: sp,
              variantName:
                  variant.text.trim().isEmpty ? null : variant.text.trim(),
              variantAttributes: initial?.variantAttributes,
              isActive: initial?.isActive ?? true,
              isPrimary: false,
            ));
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
