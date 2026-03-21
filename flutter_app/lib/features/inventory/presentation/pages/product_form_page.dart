import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_selection_dialog.dart';
import '../../data/inventory_repository.dart';
import '../../data/models.dart';
import '../widgets/inventory_tracking_selector.dart';
import '../widgets/product_storage_editor.dart';
import '../../../suppliers/data/supplier_repository.dart';
import '../../../dashboard/data/taxes_repository.dart';
import '../../../dashboard/controllers/location_notifier.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({
    super.key,
    this.initialName,
    this.initialItemType,
    this.title,
  });

  final String? initialName;
  final String? initialItemType;
  final String? title;

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _itemCode = TextEditingController();
  final _reorder = TextEditingController(text: '0');
  final _initialStock = TextEditingController(text: '0');
  final _warrantyPeriodMonths = TextEditingController();
  final _purchaseFactor = TextEditingController(text: '1');
  final _sellingFactor = TextEditingController(text: '1');
  final _primaryLoyaltyPoints = TextEditingController();

  bool _saving = false;
  bool _hasWarranty = false;
  bool _serialTracked = false;
  bool _batchTracked = false;
  bool _loading = true;
  bool _autoItemCode = false;
  bool _primaryLoyaltyGift = false;

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
  bool _weighable = false;
  int? _defaultSupplierId;
  int? _taxId;
  String? _taxName;
  final _categoryController = TextEditingController();
  final _brandController = TextEditingController();
  final _supplierController = TextEditingController();
  // Barcodes handled via dialog
  final List<ProductBarcodeDto> _barcodes = [];
  List<ProductStorageAssignmentPayload> _storageAssignments = const [];

  String get _itemType =>
      (widget.initialItemType ?? 'PRODUCT').trim().toUpperCase();

  String get _pageTitle {
    if ((widget.title ?? '').trim().isNotEmpty) {
      return widget.title!.trim();
    }
    switch (_itemType) {
      case 'ASSET':
        return 'New Asset Item';
      case 'CONSUMABLE':
        return 'New Consumable Item';
      default:
        return 'New Product';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _price.dispose();
    _cost.dispose();
    _itemCode.dispose();
    _reorder.dispose();
    _initialStock.dispose();
    _warrantyPeriodMonths.dispose();
    _purchaseFactor.dispose();
    _sellingFactor.dispose();
    _primaryLoyaltyPoints.dispose();
    for (final c in _attrText.values) {
      c.dispose();
    }
    _categoryController.dispose();
    _brandController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if ((widget.initialName ?? '').trim().isNotEmpty) {
      _name.text = widget.initialName!.trim();
    }
    _maybeGenerateItemCode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDefs());
  }

  void _maybeGenerateItemCode() {
    if (_autoItemCode) {
      _itemCode.text = _generate12DigitCode();
    }
  }

  String _generate12DigitCode() {
    final millis = DateTime.now().millisecondsSinceEpoch.toString();
    final seed = millis.substring(millis.length - 9);
    final r = (100 + (DateTime.now().microsecondsSinceEpoch % 900)).toString();
    return (r + seed).padLeft(12, '0').substring(0, 12);
  }

  Future<void> _loadDefs() async {
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final results = await Future.wait([
        repo.getAttributeDefinitions(),
        repo.getCategories(),
        repo.getBrands(),
        repo.getUnits(),
      ]);
      final defs = results[0] as List<ProductAttributeDefinitionDto>;
      _categories = results[1] as List<CategoryDto>;
      _brands = results[2] as List<BrandDto>;
      _units = results[3] as List<UnitDto>;
      setState(() {
        _attrDefs = defs;
        for (final d in defs) {
          if (d.type == 'BOOLEAN') {
            _attrBool[d.attributeId] = false;
          } else if (d.type == 'SELECT') {
            _attrSelect[d.attributeId] =
                (d.options?.isNotEmpty ?? false) ? d.options!.first : null;
          } else {
            _attrText[d.attributeId] = TextEditingController();
          }
        }
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _submit() async {
    if (_loading) return;
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final List<ProductBarcodeDto> barcodes = List.of(_barcodes);
      final code = _itemCode.text.trim();
      if (code.isNotEmpty) {
        final idx = barcodes.indexWhere((b) => b.isPrimary);
        if (idx >= 0) {
          barcodes[idx] = ProductBarcodeDto(
            barcodeId: barcodes[idx].barcodeId,
            barcode: code,
            packSize: barcodes[idx].packSize ?? 1,
            costPrice:
                barcodes[idx].costPrice ?? double.tryParse(_cost.text.trim()),
            sellingPrice: barcodes[idx].sellingPrice ??
                double.tryParse(_price.text.trim()),
            isPrimary: true,
            variantName: barcodes[idx].variantName,
            variantAttributes: barcodes[idx].variantAttributes,
            isActive: barcodes[idx].isActive,
          ).copyWithLoyaltyGift(
            enabled: _primaryLoyaltyGift,
            pointsRequired: double.tryParse(_primaryLoyaltyPoints.text.trim()),
          );
        } else {
          barcodes.insert(
            0,
            ProductBarcodeDto(
              barcode: code,
              packSize: 1,
              costPrice: double.tryParse(_cost.text.trim()),
              sellingPrice: double.tryParse(_price.text.trim()),
              isPrimary: true,
              isActive: true,
            ).copyWithLoyaltyGift(
              enabled: _primaryLoyaltyGift,
              pointsRequired:
                  double.tryParse(_primaryLoyaltyPoints.text.trim()),
            ),
          );
        }
      }
      // Build attributes
      final attrs = _buildAttributesMap();
      if (_taxId == null) {
        throw StateError('Please select Tax Type');
      }

      final payload = CreateProductPayload(
        itemType: _itemType,
        name: _name.text.trim(),
        sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
        sellingPrice: double.tryParse(_price.text.trim()),
        costPrice: double.tryParse(_cost.text.trim()),
        reorderLevel: int.tryParse(_reorder.text.trim()) ?? 0,
        hasWarranty: _hasWarranty,
        warrantyPeriodMonths: _hasWarranty
            ? int.tryParse(_warrantyPeriodMonths.text.trim())
            : null,
        isSerialized: _serialTracked,
        trackingType: _batchTracked ? 'BATCH' : 'VARIANT',
        barcodes: barcodes,
        attributes: attrs,
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
        description: null,
        weight: null,
        dimensions: null,
        taxId: _taxId!,
      );
      final created = await repo.createProduct(payload);
      final selectedLocation = ref.read(locationNotifierProvider).selected;
      if (selectedLocation != null && _storageAssignments.isNotEmpty) {
        await repo.replaceProductStorageAssignments(
          created.productId,
          locationId: selectedLocation.locationId,
          assignments: _storageAssignments
              .where((e) =>
                  (e.barcode ?? '').trim().isNotEmpty &&
                  e.storageLabel.trim().isNotEmpty)
              .toList(),
        );
      }
      if (!mounted) return;
      final initQty = double.tryParse(_initialStock.text.trim()) ?? 0;
      if (initQty != 0) {
        InventoryTrackingSelection? trackingSelection;
        if (initQty > 0 && (_serialTracked || _batchTracked)) {
          trackingSelection = await showInventoryTrackingSelector(
            context: context,
            ref: ref,
            productId: created.productId,
            productName: created.name,
            quantity: initQty,
            mode: InventoryTrackingMode.receive,
          );
          if (trackingSelection == null) {
            if (!mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text(
                    'Product created without initial stock. Add the tracked stock later from inventory adjustments.',
                  ),
                ),
              );
            Navigator.of(context).pop(true);
            return;
          }
        }

        await repo.adjustStock(
          productId: created.productId,
          adjustment: initQty,
          reason: 'Initial stock',
          barcodeId: trackingSelection?.barcodeId,
          serialNumbers: trackingSelection?.serialNumbers,
          batchAllocations: trackingSelection?.batchAllocations
              .map((e) => e.toJson())
              .toList(),
          batchNumber: trackingSelection?.batchNumber,
          expiryDate: trackingSelection?.expiryDate,
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

  Map<int, String> _buildAttributesMap() {
    final map = <int, String>{};
    for (final d in _attrDefs) {
      switch (d.type) {
        case 'BOOLEAN':
          final v = _attrBool[d.attributeId] ?? false;
          if (d.isRequired || v) {
            map[d.attributeId] = v.toString();
          }
          break;
        case 'SELECT':
          final v = _attrSelect[d.attributeId];
          if (v != null && v.isNotEmpty) {
            map[d.attributeId] = v;
          } else if (d.isRequired) {
            map[d.attributeId] = d.options?.first ?? '';
          }
          break;
        default:
          final c = _attrText[d.attributeId];
          final v = c?.text.trim() ?? '';
          if (v.isNotEmpty || d.isRequired) {
            map[d.attributeId] = v;
          }
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_pageTitle),
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
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Text('Create'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStorageTab() {
    final selectedLocation = ref.watch(locationNotifierProvider).selected;
    if (selectedLocation == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Select a location first to assign storage details.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ProductStorageEditor(
      entries: _storageAssignments,
      barcodes: _barcodes,
      locationLabel: selectedLocation.name,
      onChanged: (entries) => setState(() => _storageAssignments = entries),
    );
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
            // DATE format validation could be added here if needed
            return null;
          },
        );
    }
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
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Item Type',
            border: OutlineInputBorder(),
          ),
          child: Text(
            _itemType == 'ASSET'
                ? 'Asset Item'
                : _itemType == 'CONSUMABLE'
                    ? 'Consumable Item'
                    : 'Product',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Name'),
          validator: _req,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _supplierController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Default Supplier',
            suffixIcon: Icon(Icons.search_rounded),
          ),
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
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _itemCode,
                decoration: const InputDecoration(
                    labelText: 'Item Code (12-digit if auto)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final s = v.trim();
                  if (!RegExp(r'^\d+$').hasMatch(s)) return 'Digits only';
                  if (_autoItemCode && s.length != 12) {
                    return 'Must be 12 digits when auto';
                  }
                  return null;
                },
                readOnly: _autoItemCode,
                onFieldSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                const Text('Auto'),
                Switch(
                  value: _autoItemCode,
                  onChanged: (v) => setState(() {
                    _autoItemCode = v;
                    if (v) _itemCode.text = _generate12DigitCode();
                  }),
                ),
              ],
            ),
          ],
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
        _buildPrimaryGiftCard(),
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
              ? 'This product will track variation, batch, and serial together.'
              : _batchTracked
                  ? 'This product will track variation and batch.'
                  : _serialTracked
                      ? 'This product will track variation and serial.'
                      : 'This product will track stock by variation only.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          value: _hasWarranty,
          onChanged: (v) => setState(() {
            _hasWarranty = v;
            if (!v) {
              _warrantyPeriodMonths.clear();
            }
          }),
          title: const Text('Warranty enabled'),
          subtitle: const Text(
            'Mark this product as warranty-eligible for invoice-based registrations.',
          ),
          contentPadding: EdgeInsets.zero,
        ),
        if (_hasWarranty) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _warrantyPeriodMonths,
            decoration: const InputDecoration(
              labelText: 'Warranty Period (months)',
              helperText: 'Example: 6, 12, or 24 months',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (!_hasWarranty) return null;
              final months = int.tryParse((value ?? '').trim());
              if (months == null || months <= 0) {
                return 'Enter a valid warranty period';
              }
              return null;
            },
          ),
        ],
        SwitchListTile.adaptive(
          value: _weighable,
          onChanged: (v) => setState(() => _weighable = v),
          title: const Text('Weighable'),
          subtitle: const Text('Prompt quantity entry when selected in POS'),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 12),
        _categoryBrandUnitPickers(),
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
        const SizedBox(height: 12),
        TextFormField(
          controller: _initialStock,
          decoration:
              const InputDecoration(labelText: 'Initial Stock (optional)'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  Widget _buildPrimaryGiftCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Primary Barcode Loyalty Gift',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: _primaryLoyaltyGift,
              contentPadding: EdgeInsets.zero,
              title: const Text('Available for loyalty gift redemption'),
              subtitle: const Text(
                'Allow this primary barcode to be redeemed as a gift item.',
              ),
              onChanged: (value) => setState(() {
                _primaryLoyaltyGift = value;
                if (!value) {
                  _primaryLoyaltyPoints.clear();
                }
              }),
            ),
            if (_primaryLoyaltyGift) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _primaryLoyaltyPoints,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Points Required',
                  helperText: 'Points needed to redeem one unit of this item.',
                ),
                validator: (value) {
                  if (!_primaryLoyaltyGift) return null;
                  final points = double.tryParse((value ?? '').trim());
                  if (points == null || points <= 0) {
                    return 'Enter a valid points value';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
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
        if (_barcodes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: Text('No barcodes added')),
          )
        else
          ..._barcodes.asMap().entries.map((entry) {
            final i = entry.key;
            final b = entry.value;
            return Card(
              elevation: 0,
              child: ListTile(
                title: Text(b.barcode),
                subtitle: Text(
                    '${(b.variantName ?? '').isEmpty ? '' : '${b.variantName} • '}Conversion: ${b.packSize ?? 1} • Selling: ${b.sellingPrice?.toStringAsFixed(2) ?? '-'}${b.isLoyaltyGift ? ' • Gift: ${b.loyaltyPointsRequired?.toStringAsFixed(0) ?? '0'} pts' : ''}'),
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

  Widget _categoryBrandUnitPickers() {
    return Column(
      children: [
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
      ],
    );
  }

  Future<TaxDto?> _openTaxPicker() async {
    final repo = ref.read(taxesRepositoryProvider);
    List<TaxDto> taxes = [];
    try {
      taxes = await repo.getTaxes();
    } catch (_) {}
    int? current = _taxId ?? (taxes.isNotEmpty ? taxes.first.taxId : null);
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

class _BarcodeRow extends StatefulWidget {
  const _BarcodeRow(
      {required this.value,
      required this.onChanged,
      required this.onDelete,
      required this.onPrimary,
      required this.isPrimary});
  final ProductBarcodeDto value;
  final ValueChanged<ProductBarcodeDto> onChanged;
  final VoidCallback onDelete;
  final VoidCallback onPrimary;
  final bool isPrimary;

  @override
  State<_BarcodeRow> createState() => _BarcodeRowState();
}

class _BarcodeRowState extends State<_BarcodeRow> {
  late final TextEditingController _code =
      TextEditingController(text: widget.value.barcode);
  late final TextEditingController _pack =
      TextEditingController(text: (widget.value.packSize ?? 1).toString());
  late final TextEditingController _cost =
      TextEditingController(text: widget.value.costPrice?.toString() ?? '');
  late final TextEditingController _sell =
      TextEditingController(text: widget.value.sellingPrice?.toString() ?? '');

  @override
  void dispose() {
    _code.dispose();
    _pack.dispose();
    _cost.dispose();
    _sell.dispose();
    super.dispose();
  }

  void _emit({bool? primary}) {
    widget.onChanged(ProductBarcodeDto(
      barcodeId: widget.value.barcodeId,
      barcode: _code.text.trim(),
      packSize: int.tryParse(_pack.text.trim()) ?? 1,
      costPrice: double.tryParse(_cost.text.trim()),
      sellingPrice: double.tryParse(_sell.text.trim()),
      isPrimary: primary ?? widget.isPrimary,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Barcode / Code'),
                onChanged: (_) => _emit(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pack,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Pack Size'),
                      onChanged: (_) => _emit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _cost,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Cost'),
                      onChanged: (_) => _emit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _sell,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Price'),
                      onChanged: (_) => _emit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: widget.isPrimary ? 'Primary' : 'Make primary',
                    onPressed: () => widget.onPrimary(),
                    icon:
                        Icon(widget.isPrimary ? Icons.star : Icons.star_border),
                    color: widget.isPrimary
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ],
          ),
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
  final points = TextEditingController(
      text: initial?.loyaltyPointsRequired?.toStringAsFixed(0) ?? '');
  var isLoyaltyGift = initial?.isLoyaltyGift ?? false;
  return showDialog<ProductBarcodeDto>(
    context: context,
    builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
                      decoration:
                          const InputDecoration(labelText: 'Variation Name'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pack,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Conversion'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: sell,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Selling Price'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: isLoyaltyGift,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Available as loyalty gift'),
                      subtitle: const Text(
                        'Redeem this barcode as a gift item for points.',
                      ),
                      onChanged: (value) => setState(() {
                        isLoyaltyGift = value;
                        if (!value) points.clear();
                      }),
                    ),
                    if (isLoyaltyGift)
                      TextField(
                        controller: points,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Points Required'),
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
                    final giftPoints = double.tryParse(points.text.trim());
                    if (isLoyaltyGift &&
                        (giftPoints == null || giftPoints <= 0)) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(const SnackBar(
                            content: Text('Enter valid loyalty gift points')));
                      return;
                    }
                    Navigator.of(context).pop(
                      ProductBarcodeDto(
                        barcodeId: initial?.barcodeId,
                        barcode: s,
                        packSize: p,
                        sellingPrice: sp,
                        variantName: variant.text.trim().isEmpty
                            ? null
                            : variant.text.trim(),
                        isPrimary: false,
                      ).copyWithLoyaltyGift(
                        enabled: isLoyaltyGift,
                        pointsRequired: giftPoints,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            )),
  );
}
