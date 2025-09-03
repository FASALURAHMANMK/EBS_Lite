import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/inventory_repository.dart';
import '../../data/models.dart';

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
  bool _serialized = false;
  bool _active = true;
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
  final _categoryController = TextEditingController();
  final _brandController = TextEditingController();
  // description/weight/dimensions removed; use attributes

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
    _itemCode.dispose();
    _categoryController.dispose();
    _brandController.dispose();
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
      _serialized = p.isSerialized;
      _active = p.isActive;
      _barcodes = List.of(p.barcodes);
      final pri = _barcodes.firstWhere(
        (b) => b.isPrimary,
        orElse: () => _barcodes.isNotEmpty ? _barcodes.first : ProductBarcodeDto(barcode: '', packSize: 1, isPrimary: true),
      );
      _itemCode.text = pri.barcode;
      _categoryId = p.categoryId;
      _brandId = p.brandId;
      _unitId = p.unitId;
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
      // Initialize attribute controls
      final existing = p.attributes ?? const <int, String>{};
      for (final d in _attrDefs) {
        final existingVal = existing[d.attributeId];
        switch (d.type) {
          case 'BOOLEAN':
            _attrBool[d.attributeId] = (existingVal ?? '').toLowerCase() == 'true';
            break;
          case 'SELECT':
            if (d.options != null && d.options!.isNotEmpty) {
              _attrSelect[d.attributeId] = existingVal != null && d.options!.contains(existingVal)
                  ? existingVal
                  : d.options!.first;
            } else {
              _attrSelect[d.attributeId] = existingVal;
            }
            break;
          default:
            _attrText[d.attributeId] = TextEditingController(text: existingVal ?? '');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed to load: $e')));
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
          _barcodes[idx] = ProductBarcodeDto(
            barcodeId: _barcodes[idx].barcodeId,
            barcode: _itemCode.text.trim(),
            packSize: _barcodes[idx].packSize ?? 1,
            costPrice: _barcodes[idx].costPrice,
            sellingPrice: _barcodes[idx].sellingPrice,
            isPrimary: true,
          );
        } else if (_barcodes.isNotEmpty) {
          _barcodes[0] = ProductBarcodeDto(
            barcodeId: _barcodes[0].barcodeId,
            barcode: _itemCode.text.trim(),
            packSize: _barcodes[0].packSize ?? 1,
            costPrice: _barcodes[0].costPrice,
            sellingPrice: _barcodes[0].sellingPrice,
            isPrimary: true,
          );
        } else {
          _barcodes.add(ProductBarcodeDto(barcode: _itemCode.text.trim(), packSize: 1, isPrimary: true));
        }
      }

      final updated = ProductDto(
        productId: p.productId,
        companyId: p.companyId,
        categoryId: _categoryId,
        brandId: _brandId,
        unitId: _unitId,
        name: _name.text.trim(),
        sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
        description: null,
        costPrice: double.tryParse(_cost.text.trim()),
        sellingPrice: double.tryParse(_price.text.trim()),
        reorderLevel: int.tryParse(_reorder.text.trim()) ?? 0,
        weight: null,
        dimensions: null,
        isSerialized: _serialized,
        isActive: _active,
        barcodes: _barcodes,
        attributes: _buildAttributesMap(),
      );
      await repo.updateProduct(updated);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        ..showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
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
      ),
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
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _itemCode,
                            decoration: const InputDecoration(labelText: 'Item Code'),
                            keyboardType: TextInputType.number,
                            enabled: false,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Required' : (!RegExp(r'^\d+$').hasMatch(v.trim()) ? 'Digits only' : null),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final added = await _showBarcodeDialog(context);
                            if (added != null) {
                              setState(() => _barcodes.add(added));
                            }
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Barcode'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_barcodes.any((b) => !b.isPrimary))
                      Column(
                        children: _barcodes
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
                      decoration: const InputDecoration(labelText: 'Reorder Level'),
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
                    SwitchListTile.adaptive(
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                      title: const Text('Active'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),
                    // Category / Brand pickers via dialogs
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
                    const Divider(height: 24),
                    if (_attrDefs.isNotEmpty) ...[
                      Text('Attributes', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ..._attrDefs.map((d) => _buildAttrField(d)).toList(),
                      const SizedBox(height: 8),
                      const Divider(height: 24),
                    ],
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
                    // Removed description/weight/dimensions in favor of attributes
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.4),
                              )
                            : const Text('Save changes'),
                      ),
                    ),
                  ],
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
          if (v != null && v.isNotEmpty) map[d.attributeId] = v;
          break;
        default:
          final c = _attrText[d.attributeId];
          final v = c?.text.trim() ?? '';
          if (v.isNotEmpty || d.isRequired) map[d.attributeId] = v;
      }
    }
    return map;
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
        final c = _attrText.putIfAbsent(d.attributeId, () => TextEditingController());
        return TextFormField(
          controller: c,
          readOnly: true,
          decoration: InputDecoration(labelText: d.name + (d.isRequired ? ' *' : '')),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(now.year - 10),
              lastDate: DateTime(now.year + 10),
            );
            if (picked != null) {
              final s = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              c.text = s;
            }
          },
          validator: (v) {
            if (d.isRequired && (v == null || v.trim().isEmpty)) return 'Required';
            return null;
          },
        );
      default:
        final c = _attrText.putIfAbsent(d.attributeId, () => TextEditingController());
        return TextFormField(
          controller: c,
          decoration: InputDecoration(labelText: d.name + (d.isRequired ? ' *' : '')),
          keyboardType: d.type == 'NUMBER' ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          validator: (v) {
            if (d.isRequired && (v == null || v.trim().isEmpty)) return 'Required';
            if ((v ?? '').isNotEmpty && d.type == 'NUMBER' && double.tryParse(v!.trim()) == null) {
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
