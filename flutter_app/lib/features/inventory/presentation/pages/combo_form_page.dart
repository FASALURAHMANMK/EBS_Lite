import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_selection_dialog.dart';
import '../../../dashboard/data/taxes_repository.dart';
import '../../data/inventory_repository.dart';
import '../../data/models.dart';

class ComboFormPage extends ConsumerStatefulWidget {
  const ComboFormPage({super.key, this.comboProductId});

  final int? comboProductId;

  bool get isEdit => comboProductId != null;

  @override
  ConsumerState<ComboFormPage> createState() => _ComboFormPageState();
}

class _ComboFormPageState extends ConsumerState<ComboFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _barcode = TextEditingController();
  final _price = TextEditingController();
  final _notes = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _active = true;
  int? _taxId;
  String? _taxName;
  List<ComboProductComponentPayload> _components = const [];
  final Map<int, String> _componentLabels = {};
  final Map<int, double?> _componentStocks = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _barcode.dispose();
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (widget.isEdit) {
        final combo = await ref
            .read(inventoryRepositoryProvider)
            .getComboProduct(widget.comboProductId!);
        _name.text = combo.name;
        _sku.text = combo.sku ?? '';
        _barcode.text = combo.barcode;
        _price.text = combo.sellingPrice.toStringAsFixed(2);
        _notes.text = combo.notes ?? '';
        _active = combo.isActive;
        _taxId = combo.taxId;
        _components = combo.components
            .map(
              (e) => ComboProductComponentPayload(
                productId: e.productId,
                barcodeId: e.barcodeId,
                quantity: e.quantity,
                sortOrder: e.sortOrder,
              ),
            )
            .toList();
        for (final component in combo.components) {
          _componentLabels[component.barcodeId] = [
            component.productName,
            if ((component.variantName ?? '').trim().isNotEmpty)
              component.variantName!,
            if ((component.barcode ?? '').trim().isNotEmpty) component.barcode!,
          ].join(' • ');
          _componentStocks[component.barcodeId] = component.availableStock;
        }
      }
      if (_taxId != null) {
        final taxes = await ref.read(taxesRepositoryProvider).getTaxes();
        final tax = taxes.firstWhere(
          (e) => e.taxId == _taxId,
          orElse: () => const TaxDto(
            taxId: -1,
            name: '',
            percentage: 0,
            isCompound: false,
            isActive: true,
          ),
        );
        if (tax.taxId > 0) {
          _taxName = '${tax.name} (${tax.percentage.toStringAsFixed(0)}%)';
        }
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

  Future<void> _pickTax() async {
    final taxes = await ref.read(taxesRepositoryProvider).getTaxes();
    if (!mounted) return;
    final picked = await showDialog<TaxDto>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Tax'),
        children: taxes
            .where((e) => e.isActive)
            .map(
              (tax) => SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(tax),
                child: Text(
                  '${tax.name} (${tax.percentage.toStringAsFixed(0)}%)',
                ),
              ),
            )
            .toList(),
      ),
    );
    if (picked != null) {
      setState(() {
        _taxId = picked.taxId;
        _taxName = '${picked.name} (${picked.percentage.toStringAsFixed(0)}%)';
      });
    }
  }

  Future<void> _pickComponent() async {
    final repo = ref.read(inventoryRepositoryProvider);
    final picked = await showDialog<InventoryListItem>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        List<InventoryListItem> results = const [];
        bool loading = true;
        bool kickoff = true;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> runSearch(String term) async {
              loading = true;
              setDialogState(() {});
              try {
                results = await repo.searchProducts(
                  term,
                  includeComboProducts: false,
                );
              } finally {
                loading = false;
                setDialogState(() {});
              }
            }

            if (kickoff) {
              kickoff = false;
              Future.microtask(() => runSearch(''));
            }

            return AppSelectionDialog(
              title: 'Add Component',
              loading: loading,
              searchField: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Search stock items',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: runSearch,
              ),
              body: results.isEmpty && !loading
                  ? const Center(child: Text('No eligible products'))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final item = results[index];
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            [
                              if ((item.variantName ?? '').trim().isNotEmpty)
                                item.variantName!,
                              if ((item.primaryStorage ?? '').trim().isNotEmpty)
                                item.primaryStorage!,
                              'Stock ${item.stock.toStringAsFixed(2)}',
                            ].join(' • '),
                          ),
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
    if (picked == null) return;
    if (!mounted) return;

    final qtyCtrl = TextEditingController(text: '1');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(picked.name),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Qty per combo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final quantity = double.tryParse(qtyCtrl.text.trim()) ?? 0;
    if (quantity <= 0) return;
    setState(() {
      final existingIndex =
          _components.indexWhere((e) => e.barcodeId == (picked.barcodeId ?? 0));
      if (existingIndex >= 0) {
        _components[existingIndex] = ComboProductComponentPayload(
          productId: _components[existingIndex].productId,
          barcodeId: _components[existingIndex].barcodeId,
          quantity: _components[existingIndex].quantity + quantity,
          sortOrder: _components[existingIndex].sortOrder,
        );
      } else {
        _components = [
          ..._components,
          ComboProductComponentPayload(
            productId: picked.productId,
            barcodeId: picked.barcodeId ?? 0,
            quantity: quantity,
            sortOrder: _components.length + 1,
          ),
        ];
      }
      _componentLabels[picked.barcodeId ?? 0] = [
        picked.name,
        if ((picked.variantName ?? '').trim().isNotEmpty) picked.variantName!,
        if ((picked.barcodeId ?? 0) > 0) 'Variation ${picked.barcodeId}',
      ].join(' • ');
      _componentStocks[picked.barcodeId ?? 0] = picked.stock;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_taxId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Select a tax first.')));
      return;
    }
    if (_components.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Add at least one component.')),
        );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final payload = ComboProductPayload(
        name: _name.text.trim(),
        sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
        barcode: _barcode.text.trim(),
        sellingPrice: double.tryParse(_price.text.trim()) ?? 0,
        taxId: _taxId!,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        isActive: _active,
        components: _components,
      );
      if (widget.isEdit) {
        await repo.updateComboProduct(widget.comboProductId!, payload);
      } else {
        await repo.createComboProduct(payload);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Combo' : 'New Combo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Combo name'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _barcode,
                          decoration: const InputDecoration(
                            labelText: 'Custom barcode',
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _sku,
                          decoration: const InputDecoration(
                              labelText: 'SKU (Optional)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _price,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Selling price',
                          ),
                          validator: (value) =>
                              (double.tryParse((value ?? '').trim()) ?? -1) < 0
                                  ? 'Enter a valid price'
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _pickTax,
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Tax'),
                            child: Text(_taxName ?? 'Select tax'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _active,
                    onChanged: (value) => setState(() => _active = value),
                    title: const Text('Active'),
                    subtitle: const Text(
                        'Only active combos appear in POS and quotes.'),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bundle Components',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'These stock-carrying items are reduced when the combo is sold.',
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _pickComponent,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_components.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'No components added yet.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ..._components.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(
                          _componentLabels[item.barcodeId] ??
                              'Product #${item.productId} • Variant #${item.barcodeId}',
                        ),
                        subtitle: Text(
                          [
                            'Qty per combo: ${item.quantity.toStringAsFixed(2)}',
                            if (_componentStocks[item.barcodeId] != null)
                              'Stock ${_componentStocks[item.barcodeId]!.toStringAsFixed(2)}',
                          ].join(' • '),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () {
                            setState(() {
                              _components = [
                                for (var i = 0; i < _components.length; i++)
                                  if (i != index)
                                    ComboProductComponentPayload(
                                      productId: _components[i].productId,
                                      barcodeId: _components[i].barcodeId,
                                      quantity: _components[i].quantity,
                                      sortOrder: i + 1,
                                    ),
                              ];
                            });
                          },
                        ),
                        onTap: () async {
                          final controller = TextEditingController(
                            text: item.quantity.toString(),
                          );
                          final saved = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Update quantity'),
                              content: TextField(
                                controller: controller,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Qty per combo',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('Save'),
                                ),
                              ],
                            ),
                          );
                          if (saved != true) return;
                          final nextQty =
                              double.tryParse(controller.text.trim()) ??
                                  item.quantity;
                          if (nextQty <= 0) return;
                          setState(() {
                            _components[index] = ComboProductComponentPayload(
                              productId: item.productId,
                              barcodeId: item.barcodeId,
                              quantity: nextQty,
                              sortOrder: item.sortOrder,
                            );
                          });
                        },
                      ),
                    );
                  }),
                ],
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
                  : Text(widget.isEdit ? 'Save changes' : 'Create combo'),
            ),
          ),
        ),
      ),
    );
  }
}
