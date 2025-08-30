import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/inventory_repository.dart';
import '../../data/models.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key});

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _barcode = TextEditingController();
  final _reorder = TextEditingController(text: '0');

  bool _saving = false;
  bool _serialized = false;
  bool _loading = true;

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
  final _desc = TextEditingController();
  final _weight = TextEditingController();
  final _dimensions = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _price.dispose();
    _cost.dispose();
    _barcode.dispose();
    _reorder.dispose();
    for (final c in _attrText.values) {
      c.dispose();
    }
    _categoryController.dispose();
    _brandController.dispose();
    _desc.dispose();
    _weight.dispose();
    _dimensions.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDefs());
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
            _attrSelect[d.attributeId] = (d.options?.isNotEmpty ?? false) ? d.options!.first : null;
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

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _submit() async {
    if (_loading) return;
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final barcodes = [
        ProductBarcodeDto(
          barcode: _barcode.text.trim(),
          sellingPrice: double.tryParse(_price.text.trim()),
          costPrice: double.tryParse(_cost.text.trim()),
          packSize: 1,
          isPrimary: true,
        ),
      ];
      final payload = CreateProductPayload(
        name: _name.text.trim(),
        sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
        sellingPrice: double.tryParse(_price.text.trim()),
        costPrice: double.tryParse(_cost.text.trim()),
        reorderLevel: int.tryParse(_reorder.text.trim()) ?? 0,
        isSerialized: _serialized,
        barcodes: barcodes,
        attributes: _buildAttributesMap(),
        categoryId: _categoryId,
        brandId: _brandId,
        unitId: _unitId,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        weight: double.tryParse(_weight.text.trim()),
        dimensions: _dimensions.text.trim().isEmpty ? null : _dimensions.text.trim(),
      );
      await repo.createProduct(payload);
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
              TextFormField(
                controller: _sku,
                decoration: const InputDecoration(labelText: 'SKU (optional)'),
                textInputAction: TextInputAction.next,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      decoration: const InputDecoration(labelText: 'Selling Price'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cost,
                      decoration: const InputDecoration(labelText: 'Cost Price'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _reorder,
                decoration: const InputDecoration(labelText: 'Reorder Level'),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              SwitchListTile.adaptive(
                value: _serialized,
                onChanged: (v) => setState(() => _serialized = v),
                title: const Text('Serialized'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              _categoryBrandUnitPickers(),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weight,
                      decoration: const InputDecoration(labelText: 'Weight'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _dimensions,
                      decoration: const InputDecoration(labelText: 'Dimensions'),
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
              Text('Primary Barcode', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _barcode,
                decoration: const InputDecoration(labelText: 'Barcode'),
                validator: _req,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              SizedBox(
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
                  ],
                ),
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
        return DropdownButtonFormField<String>(
          value: _attrSelect[d.attributeId],
          items: opts
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => setState(() => _attrSelect[d.attributeId] = v),
          decoration: InputDecoration(labelText: d.name + (d.isRequired ? ' *' : '')),
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
            if (d.isRequired && (v == null || v.trim().isEmpty)) {
              return 'Required';
            }
            return null;
          },
        );
      default:
        final c = _attrText.putIfAbsent(d.attributeId, () => TextEditingController());
        return TextFormField(
          controller: c,
          decoration: InputDecoration(labelText: d.name + (d.isRequired ? ' *' : '')),
          keyboardType: d.type == 'NUMBER'
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          validator: (v) {
            if (d.isRequired && (v == null || v.trim().isEmpty)) {
              return 'Required';
            }
            if ((v ?? '').isNotEmpty && d.type == 'NUMBER' && double.tryParse(v!.trim()) == null) {
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
              child: Autocomplete<CategoryDto>(
                displayStringForOption: (c) => c.name,
                optionsBuilder: (text) {
                  final q = text.text.toLowerCase();
                  return _categories.where((c) => c.name.toLowerCase().contains(q));
                },
                onSelected: (c) {
                  _categoryId = c.categoryId;
                  _categoryController.text = c.name;
                },
                fieldViewBuilder: (context, controller, focus, onSubmit) {
                  controller.text = _categoryController.text;
                  return TextField(
                    controller: controller,
                    focusNode: focus,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_rounded),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Autocomplete<BrandDto>(
                displayStringForOption: (b) => b.name,
                optionsBuilder: (text) {
                  final q = text.text.toLowerCase();
                  return _brands.where((b) => b.name.toLowerCase().contains(q));
                },
                onSelected: (b) {
                  _brandId = b.brandId;
                  _brandController.text = b.name;
                },
                fieldViewBuilder: (context, controller, focus, onSubmit) {
                  controller.text = _brandController.text;
                  return TextField(
                    controller: controller,
                    focusNode: focus,
                    decoration: const InputDecoration(
                      labelText: 'Brand',
                      prefixIcon: Icon(Icons.sell_rounded),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: _unitId,
          items: _units
              .map((u) => DropdownMenuItem(
                    value: u.unitId,
                    child: Text('${u.name}${u.symbol != null ? ' (${u.symbol})' : ''}'),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _unitId = v),
          decoration: const InputDecoration(
            labelText: 'Unit',
            prefixIcon: Icon(Icons.straighten_rounded),
          ),
        ),
      ],
    );
  }
}
