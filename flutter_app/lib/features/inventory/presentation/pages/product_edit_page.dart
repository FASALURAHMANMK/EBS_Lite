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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final results = await Future.wait([
        repo.getProduct(widget.productId),
        repo.getCategories(),
        repo.getBrands(),
        repo.getUnits(),
      ]);
      final p = results[0] as ProductDto;
      _categories = results[1] as List<CategoryDto>;
      _brands = results[2] as List<BrandDto>;
      _units = results[3] as List<UnitDto>;
      _product = p;
      _name.text = p.name;
      _sku.text = p.sku ?? '';
      _price.text = p.sellingPrice?.toString() ?? '';
      _cost.text = p.costPrice?.toString() ?? '';
      _reorder.text = p.reorderLevel.toString();
      _serialized = p.isSerialized;
      _active = p.isActive;
      _categoryId = p.categoryId;
      _brandId = p.brandId;
      _unitId = p.unitId;
      _desc.text = p.description ?? '';
      _weight.text = p.weight?.toString() ?? '';
      _dimensions.text = p.dimensions ?? '';
      _categoryController.text = _categories.firstWhere(
        (c) => c.categoryId == _categoryId,
        orElse: () => CategoryDto(categoryId: -1, name: ''),
      ).name;
      _brandController.text = _brands.firstWhere(
        (b) => b.brandId == _brandId,
        orElse: () => BrandDto(brandId: -1, name: ''),
      ).name;
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
      final updated = ProductDto(
        productId: p.productId,
        companyId: p.companyId,
        categoryId: _categoryId,
        brandId: _brandId,
        unitId: _unitId,
        name: _name.text.trim(),
        sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        costPrice: double.tryParse(_cost.text.trim()),
        sellingPrice: double.tryParse(_price.text.trim()),
        reorderLevel: int.tryParse(_reorder.text.trim()) ?? 0,
        weight: double.tryParse(_weight.text.trim()),
        dimensions: _dimensions.text.trim().isEmpty ? null : _dimensions.text.trim(),
        isSerialized: _serialized,
        isActive: _active,
        barcodes: p.barcodes,
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(inventoryRepositoryProvider).deleteProduct(widget.productId);
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
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                    SwitchListTile.adaptive(
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                      title: const Text('Active'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),
                    // Category / Brand pickers and Unit
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
                    const SizedBox(height: 24),
                    SizedBox(
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
                  ],
                ),
              ),
            ),
    );
  }
}
