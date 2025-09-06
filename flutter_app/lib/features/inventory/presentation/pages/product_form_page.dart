import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/inventory_repository.dart';
import '../../data/models.dart';
import '../../../suppliers/data/supplier_repository.dart';
import '../../../dashboard/data/taxes_repository.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key, this.initialName});

  final String? initialName;

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

  bool _saving = false;
  bool _serialized = false;
  bool _loading = true;
  bool _autoItemCode = false;

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
  int? _defaultSupplierId;
  int? _taxId;
  String? _taxName;
  final _categoryController = TextEditingController();
  final _brandController = TextEditingController();
  final _supplierController = TextEditingController();
  // Barcodes handled via dialog
  List<ProductBarcodeDto> _barcodes = [];

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _price.dispose();
    _cost.dispose();
    _itemCode.dispose();
    _reorder.dispose();
    _initialStock.dispose();
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
            costPrice: barcodes[idx].costPrice ?? double.tryParse(_cost.text.trim()),
            sellingPrice: barcodes[idx].sellingPrice ?? double.tryParse(_price.text.trim()),
            isPrimary: true,
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
        name: _name.text.trim(),
        sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
        sellingPrice: double.tryParse(_price.text.trim()),
        costPrice: double.tryParse(_cost.text.trim()),
        reorderLevel: int.tryParse(_reorder.text.trim()) ?? 0,
        isSerialized: _serialized,
        barcodes: barcodes,
        attributes: attrs,
        categoryId: _categoryId,
        brandId: _brandId,
        unitId: _unitId,
        defaultSupplierId: _defaultSupplierId,
        description: null,
        weight: null,
        dimensions: null,
        taxId: _taxId!,
      );
      final created = await repo.createProduct(payload);
      final initQty = double.tryParse(_initialStock.text.trim()) ?? 0;
      if (initQty != 0) {
        await repo.adjustStock(
          productId: created.productId,
          adjustment: initQty,
          reason: 'Initial stock',
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed: $e')));
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

  Map<int, String> _buildAttributesMapWithTax() {
    final map = _buildAttributesMap();
    final tid = _taxId;
    if (tid != null) {
      final def = _attrDefs.firstWhere(
        (d) => d.name.toLowerCase() == 'default tax' || d.name.toLowerCase() == 'tax',
        orElse: () => ProductAttributeDefinitionDto(
          attributeId: -1,
          name: '',
          type: 'TEXT',
          isRequired: false,
          options: const [],
        ),
      );
      if (def.attributeId > 0) {
        map[def.attributeId] = tid.toString();
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New Product')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
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
                            decoration: const InputDecoration(labelText: 'Item Code (12-digit if auto)'),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              final s = v.trim();
                              if (!RegExp(r'^\d+$').hasMatch(s)) return 'Digits only';
                              if (_autoItemCode && s.length != 12) return 'Must be 12 digits when auto';
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
                    if (_barcodes.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _barcodes.asMap().entries.map((entry) {
                          final i = entry.key;
                          final b = entry.value;
                          return Card(
                            elevation: 0,
                            child: ListTile(
                              title: Text(b.barcode),
                              subtitle: Text('Conversion: ${b.packSize ?? 1} • Selling: ${b.sellingPrice?.toStringAsFixed(2) ?? '-'}'),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () async {
                                      final edited = await _showBarcodeDialog(context, initial: b);
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
                        }).toList(),
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
                            decoration: const InputDecoration(
                                labelText: 'Selling Price'),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _cost,
                            decoration:
                                const InputDecoration(labelText: 'Cost Price'),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _reorder,
                      decoration:
                          const InputDecoration(labelText: 'Reorder Level'),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: _serialized,
                      onChanged: (v) => setState(() => _serialized = v),
                      title: const Text('Serialized'),
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
                      decoration: const InputDecoration(labelText: 'Initial Stock (optional)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const Divider(height: 24),
                    if (_attrDefs.isNotEmpty) ...[
                      Text('Attributes', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ..._attrDefs.map((d) => _buildAttrField(d)).toList(),
                      const SizedBox(height: 8),
                      const Divider(height: 24),
                    ],
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.4),
                              )
                            : const Text('Create'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            return RadioListTile<int>(
                              value: c.categoryId,
                              groupValue: current,
                              onChanged: (v) => setInner(() => current = v),
                              title: Text(c.name),
                            );
                          },
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
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final b = filtered[i];
                            return RadioListTile<int>(
                              value: b.brandId,
                              groupValue: current,
                              onChanged: (v) => setInner(() => current = v),
                              title: Text(b.name),
                            );
                          },
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
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final u = filtered[i];
                            final label = '${u.name}${u.symbol != null ? ' (${u.symbol})' : ''}';
                            return RadioListTile<int>(
                              value: u.unitId,
                              groupValue: current,
                              onChanged: (v) => setInner(() => current = v),
                              title: Text(label),
                            );
                          },
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

  Future<String?> _openAttributeOptionDialog(ProductAttributeDefinitionDto d) async {
    final opts = d.options ?? const <String>[];
    String? current = _attrSelect[d.attributeId] ?? (opts.isNotEmpty ? opts.first : null);
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
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: opts.length,
                    itemBuilder: (context, i) {
                      final o = opts[i];
                      return RadioListTile<String>(
                        value: o,
                        groupValue: current,
                        onChanged: (v) => setInner(() => current = v),
                        title: Text(o),
                      );
                    },
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
          valueText: _attrSelect[d.attributeId] ?? (opts.isNotEmpty ? opts.first : ''),
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
        const SizedBox(height: 12),
        _SelectField(
          label: 'Unit',
          valueText: () {
            final u = _units.firstWhere(
              (e) => e.unitId == _unitId,
              orElse: () => UnitDto(unitId: -1, name: ''),
            );
            if (u.unitId == -1) return '';
            return '${u.name}${u.symbol != null ? ' (${u.symbol})' : ''}';
          }(),
          icon: Icons.straighten_rounded,
          onTap: () async {
            final picked = await _openSingleUnitDialog();
            if (picked != null) {
              setState(() => _unitId = picked.unitId);
            }
          },
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
    return showDialog<TaxDto?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Select Tax Type'),
          content: SizedBox(
            width: 500,
            child: taxes.isEmpty
                ? const Center(child: Text('No tax types'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: taxes.length,
                    itemBuilder: (context, i) {
                      final t = taxes[i];
                      return RadioListTile<int>(
                        value: t.taxId,
                        groupValue: current,
                        onChanged: (v) => setInner(() => current = v),
                        title: Text(t.name),
                        subtitle: Text('${(t.percentage % 1 == 0 ? t.percentage.toStringAsFixed(0) : t.percentage.toStringAsFixed(2))} %'),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (current == null) {
                  Navigator.pop(context, null);
                  return;
                }
                final sel = taxes.firstWhere((e) => e.taxId == current, orElse: () => taxes.first);
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
    String query = '';
    List<_SupplierPick> results = const [];
    return showDialog<_SupplierPick>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Select Supplier'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search_rounded)),
                  onChanged: (v) async {
                    query = v.trim();
                    final repo = ref.read(supplierRepositoryProvider);
                    final list = await repo.getSuppliers(search: query);
                    setInner(() => results = list.map((e) => _SupplierPick(e.supplierId, e.name)).toList());
                  },
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final s = results[i];
                      return ListTile(
                        title: Text(s.name),
                        onTap: () => Navigator.of(context).pop(s),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
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
  const _SelectField({required this.label, required this.valueText, required this.icon, required this.onTap});
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
  const _BarcodeRow({super.key, required this.value, required this.onChanged, required this.onDelete, required this.onPrimary, required this.isPrimary});
  final ProductBarcodeDto value;
  final ValueChanged<ProductBarcodeDto> onChanged;
  final VoidCallback onDelete;
  final VoidCallback onPrimary;
  final bool isPrimary;

  @override
  State<_BarcodeRow> createState() => _BarcodeRowState();
}

class _BarcodeRowState extends State<_BarcodeRow> {
  late final TextEditingController _code = TextEditingController(text: widget.value.barcode);
  late final TextEditingController _pack = TextEditingController(text: (widget.value.packSize ?? 1).toString());
  late final TextEditingController _cost = TextEditingController(text: widget.value.costPrice?.toString() ?? '');
  late final TextEditingController _sell = TextEditingController(text: widget.value.sellingPrice?.toString() ?? '');

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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Cost'),
                      onChanged: (_) => _emit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _sell,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Price'),
                      onChanged: (_) => _emit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: widget.isPrimary ? 'Primary' : 'Make primary',
                    onPressed: () => widget.onPrimary(),
                    icon: Icon(widget.isPrimary ? Icons.star : Icons.star_border),
                    color: widget.isPrimary ? Theme.of(context).colorScheme.primary : null,
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

Future<ProductBarcodeDto?> _showBarcodeDialog(BuildContext context, {ProductBarcodeDto? initial}) async {
  final code = TextEditingController(text: initial?.barcode ?? '');
  final pack = TextEditingController(text: (initial?.packSize ?? 1).toString());
  final sell = TextEditingController(text: initial?.sellingPrice?.toString() ?? '');
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Selling Price'),
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
                ..showSnackBar(const SnackBar(content: Text('Barcode must be digits only')));
              return;
            }
            final p = int.tryParse(pack.text.trim()) ?? 1;
            if (p < 1) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Conversion must be at least 1')));
              return;
            }
            final sp = double.tryParse(sell.text.trim());
            Navigator.of(context).pop(ProductBarcodeDto(
              barcodeId: initial?.barcodeId,
              barcode: s,
              packSize: p,
              sellingPrice: sp,
              isPrimary: false,
            ));
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
