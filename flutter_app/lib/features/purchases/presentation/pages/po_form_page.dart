import 'package:ebs_lite/core/error_handler.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/features/inventory/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_selection_dialog.dart';
import '../../../../shared/widgets/desktop_sidebar_toggle_action.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../../suppliers/data/supplier_repository.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/presentation/widgets/inventory_variant_selector.dart';
import '../../../suppliers/data/models.dart';
import '../../data/purchases_repository.dart';

class PoFormPage extends ConsumerStatefulWidget {
  const PoFormPage({super.key});

  @override
  ConsumerState<PoFormPage> createState() => _PoFormPageState();
}

class _PoFormPageState extends ConsumerState<PoFormPage> {
  int? _supplierId;
  String? _supplierName;
  final _refNo = TextEditingController();
  final _notes = TextEditingController();
  final List<_PoLine> _lines = [_PoLine()];
  bool _saving = false;

  List<_PoLine> get _activeLines => _lines
      .where(
        (line) =>
            line.product != null &&
            (double.tryParse(line.qty.text.trim()) ?? 0) > 0,
      )
      .toList(growable: false);

  double get _totalQty => _activeLines.fold<double>(
        0,
        (sum, line) => sum + (double.tryParse(line.qty.text.trim()) ?? 0),
      );

  double get _subtotal => _activeLines.fold<double>(
        0,
        (sum, line) =>
            sum +
            ((double.tryParse(line.qty.text.trim()) ?? 0) *
                (double.tryParse(line.price.text.trim()) ?? 0)),
      );

  @override
  void dispose() {
    _refNo.dispose();
    _notes.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showSidebarToggle = AppBreakpoints.isTabletOrDesktop(context);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final activeLines = _activeLines;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: showSidebarToggle ? 104 : null,
        leading: showSidebarToggle ? const DesktopSidebarToggleLeading() : null,
        title: const Text('New Purchase Order'),
      ),
      body: SafeArea(
        child: isDesktop
            ? _buildDesktopBody(activeLines)
            : _buildMobileBody(activeLines),
      ),
    );
  }

  Widget _buildDesktopBody(List<_PoLine> activeLines) {
    const gap = 12.0;
    const railWidth = 320.0;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ProfessionalDocumentHeader(
            title: 'PO Creation Workspace',
            subtitle:
                'Desktop purchasers get supplier context, commercial notes, and a dense line-entry workspace in one view.',
            badges: [
              const ProfessionalBadge(label: 'Purchases'),
              ProfessionalBadge(
                label: '${activeLines.length} Active Lines',
                backgroundColor: const Color(0xFFEAF1F8),
                foregroundColor: const Color(0xFF23415F),
              ),
            ],
          ),
          if (_saving) ...[
            const SizedBox(height: gap),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: gap),
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildOverviewCard()),
                const SizedBox(width: gap),
                Expanded(child: _buildCommercialCard()),
                const SizedBox(width: gap),
                SizedBox(width: railWidth, child: _buildSummaryCard()),
              ],
            ),
          ),
          const SizedBox(height: gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildItemsSection(desktopLayout: true)),
                const SizedBox(width: gap),
                SizedBox(width: railWidth, child: _buildActionPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody(List<_PoLine> activeLines) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ProfessionalDocumentHeader(
          title: 'New Purchase Order',
          subtitle:
              'Mobile keeps the PO flow stacked: supplier first, commercial notes next, then item entry and final confirmation.',
          badges: [
            ProfessionalBadge(label: '${activeLines.length} Active Lines'),
          ],
        ),
        if (_saving) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 12),
        _buildOverviewCard(),
        const SizedBox(height: 12),
        _buildCommercialCard(),
        const SizedBox(height: 12),
        _buildItemsSection(),
        const SizedBox(height: 12),
        _buildSummaryCard(),
        const SizedBox(height: 12),
        _buildActionPanel(),
      ],
    );
  }

  Widget _buildOverviewCard() {
    return ProfessionalOverviewCard(
      title: 'Supplier & Reference',
      icon: Icons.local_shipping_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SupplierPicker(
            supplierId: _supplierId,
            supplierName: _supplierName,
            onPicked: (id, name) => setState(() {
              _supplierId = id;
              _supplierName = name;
            }),
          ),
          const SizedBox(height: 12),
          ProfessionalFieldGrid(
            fields: [
              ProfessionalFieldGridItem(
                label: 'Supplier Status',
                value: _supplierId == null
                    ? 'Select a supplier before saving'
                    : 'Supplier selected',
              ),
              ProfessionalFieldGridItem(
                label: 'PO Number',
                value: 'Auto-generated on save',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommercialCard() {
    return ProfessionalSectionCard(
      title: 'Commercial Notes',
      subtitle:
          'Reference numbers and notes stay visible so operators can enter procurement context before line entry.',
      child: Column(
        children: [
          TextField(
            controller: _refNo,
            decoration: const InputDecoration(
              labelText: 'Reference Number (optional)',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 4,
            maxLines: 6,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.description_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection({bool desktopLayout = false}) {
    return ProfessionalSectionCard(
      title: 'Order Lines',
      subtitle:
          'Add products, enter quantities, and confirm the intended variation before creating the PO.',
      action: FilledButton.tonalIcon(
        onPressed: () => setState(() => _lines.add(_PoLine())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item'),
        style: professionalCompactButtonStyle(context),
      ),
      expandChild: desktopLayout,
      child: _lines.isEmpty
          ? const Center(
              child: ProfessionalDocumentEmptyState(
                title: 'No lines yet',
                message:
                    'Add at least one product line to create the purchase order.',
              ),
            )
          : desktopLayout
              ? ListView(
                  padding: EdgeInsets.zero,
                  children: _buildLines(),
                )
              : Column(
                  children: _buildLines(),
                ),
    );
  }

  Widget _buildSummaryCard() {
    return ProfessionalSummaryCard(
      title: 'PO Summary',
      expandContent: AppBreakpoints.isDesktop(context),
      rows: [
        (
          label: 'Active Lines',
          value: '${_activeLines.length}',
          emphasize: false,
        ),
        (
          label: 'Total Qty',
          value: _totalQty.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: 'Estimated Value',
          value: _subtotal.toStringAsFixed(2),
          emphasize: true,
        ),
      ],
      footer: Text(
        'POs remain editable until approval. Receiving happens from the approved document workspace.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Widget _buildActionPanel() {
    return ProfessionalSectionCard(
      title: 'Create Document',
      subtitle:
          'Save the PO after supplier selection and line review. The detail page will handle approval and receiving.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(_saving ? 'Creating...' : 'Create Purchase Order'),
            style: professionalCompactButtonStyle(context),
          ),
          const SizedBox(height: 12),
          ProfessionalFieldGrid(
            fields: [
              ProfessionalFieldGridItem(
                label: 'Supplier',
                value: _supplierName ??
                    (_supplierId == null
                        ? 'Required before save'
                        : 'Supplier #$_supplierId'),
              ),
              ProfessionalFieldGridItem(
                label: 'Reference',
                value: _refNo.text.trim().isEmpty
                    ? 'Optional'
                    : _refNo.text.trim(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLines() {
    final widgets = <Widget>[];
    for (int i = 0; i < _lines.length; i++) {
      widgets.add(
        ProfessionalOverviewCard(
          title: 'Line ${i + 1}',
          icon: Icons.inventory_2_rounded,
          action: IconButton(
            tooltip: 'Remove line',
            onPressed: _lines.length == 1
                ? null
                : () => setState(() => _lines.removeAt(i)),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          child: Column(
            children: [
              _LineProductPicker(line: _lines[i]),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _lines[i].qty,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: Icon(Icons.format_list_numbered_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _lines[i].price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Unit Price',
                        prefixIcon: Icon(Icons.currency_rupee_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _configureVariation(_lines[i]),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: Text(
                    _lines[i].variation == null
                        ? 'Select Variation'
                        : _lines[i].variation!.summary(
                              double.tryParse(_lines[i].qty.text.trim()) ?? 0,
                            ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      if (i != _lines.length - 1) {
        widgets.add(const SizedBox(height: 10));
      }
    }
    return widgets;
  }

  Future<void> _save() async {
    final supplierId = _supplierId;
    if (supplierId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Please select supplier')));
      return;
    }
    final lines = _lines
        .where((l) =>
            l.product != null && (double.tryParse(l.qty.text.trim()) ?? 0) > 0)
        .toList();
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Add at least one item with quantity')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(purchasesRepositoryProvider);
      final items = [
        for (final l in lines)
          {
            'product_id': l.product!.productId,
            if (l.variation?.barcodeId != null && l.variation!.barcodeId! > 0)
              'barcode_id': l.variation!.barcodeId,
            'quantity': double.tryParse(l.qty.text.trim()) ?? 0,
            'unit_price': double.tryParse(l.price.text.trim()) ?? 0,
          }
      ];
      final id = await repo.createPurchaseOrder(
        supplierId: supplierId,
        items: items,
        referenceNumber: _refNo.text.trim().isEmpty ? null : _refNo.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _configureVariation(_PoLine line) async {
    final product = line.product;
    if (product == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Select a product first')),
        );
      return;
    }
    final selection = await showInventoryVariantSelector(
      context: context,
      ref: ref,
      productId: product.productId,
      productName: product.name,
      initialSelection: line.variation,
    );
    if (selection != null && mounted) {
      setState(() => line.variation = selection);
    }
  }
}

class _PoLine {
  InventoryListItem? product;
  InventoryTrackingSelection? variation;
  final qty = TextEditingController();
  final price = TextEditingController();
  void dispose() {
    qty.dispose();
    price.dispose();
  }
}

class _LineProductPicker extends ConsumerStatefulWidget {
  const _LineProductPicker({required this.line});
  final _PoLine line;

  @override
  ConsumerState<_LineProductPicker> createState() => _LineProductPickerState();
}

class _LineProductPickerState extends ConsumerState<_LineProductPicker> {
  @override
  Widget build(BuildContext context) {
    final p = widget.line.product;
    return InkWell(
      onTap: () async {
        final picked = await _openProductPicker(context);
        if (picked != null) {
          InventoryTrackingSelection? variation;
          try {
            final variants = await ref
                .read(inventoryRepositoryProvider)
                .getStockVariants(picked.productId);
            if (variants.isNotEmpty) {
              final v = variants.first;
              variation = InventoryTrackingSelection(
                barcodeId: v.barcodeId,
                trackingType: v.trackingType,
                isSerialized: v.isSerialized,
                barcode: v.barcode,
                variantName: v.variantName,
              );
            }
          } catch (_) {}
          setState(() {
            widget.line.product = picked;
            widget.line.variation = variation;
          });
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Product',
          prefixIcon: Icon(Icons.inventory_2_rounded),
          border: OutlineInputBorder(),
        ),
        child: Row(children: [
          Expanded(
              child: Text(
                  p == null
                      ? 'Tap to select a product'
                      : [
                          p.name,
                          if ((widget.line.variation?.variantName ?? '')
                              .trim()
                              .isNotEmpty)
                            widget.line.variation!.variantName!.trim(),
                          if ((p.sku ?? '').isNotEmpty) 'SKU: ${p.sku}',
                        ].join(' • '),
                  overflow: TextOverflow.ellipsis)),
          const Icon(Icons.arrow_drop_down_rounded),
        ]),
      ),
    );
  }

  Future<InventoryListItem?> _openProductPicker(BuildContext context) async {
    final repo = ref.read(inventoryRepositoryProvider);
    List<InventoryListItem> initial = [];
    try {
      initial = await repo.getStock();
    } catch (_) {}
    List<InventoryListItem> results = List.of(initial);
    int? selectedId = widget.line.product?.productId;
    if (!context.mounted) return null;
    return showDialog<InventoryListItem?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AppSelectionDialog(
          title: 'Select Product',
          maxWidth: 720,
          searchField: TextField(
            decoration: const InputDecoration(
              hintText: 'Search by name or SKU',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (v) async {
              final q = v.trim();
              if (q.isEmpty) {
                setInner(() => results = List.of(initial));
                return;
              }
              final list = await repo.searchProducts(q);
              setInner(() => results = list);
            },
          ),
          body: results.isEmpty
              ? const Center(child: Text('No products'))
              : RadioGroup<int>(
                  groupValue: selectedId,
                  onChanged: (value) => setInner(() => selectedId = value),
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final it = results[i];
                      return RadioListTile<int>(
                        value: it.productId,
                        title: Text(it.name),
                        subtitle: Text([
                          if ((it.sku ?? '').isNotEmpty) 'SKU: ${it.sku}',
                          'Stock: ${it.stock.toStringAsFixed(2)}'
                        ].join(' • ')),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  final it = results.firstWhere(
                    (e) => e.productId == selectedId,
                    orElse: () => InventoryListItem(
                        productId: -1,
                        name: '',
                        sku: null,
                        categoryName: null,
                        brandName: null,
                        unitSymbol: null,
                        reorderLevel: 0,
                        stock: 0,
                        isLowStock: false,
                        price: null),
                  );
                  Navigator.pop(context, it.productId == -1 ? null : it);
                },
                child: const Text('Select')),
          ],
        ),
      ),
    );
  }
}

class _SupplierPicker extends ConsumerWidget {
  const _SupplierPicker(
      {this.supplierId, this.supplierName, required this.onPicked});
  final int? supplierId;
  final String? supplierName;
  final void Function(int id, String name) onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = supplierName ??
        (supplierId == null
            ? 'Tap to select supplier'
            : 'Supplier #$supplierId');
    return InkWell(
      onTap: () async {
        final picked = await _openSupplierPicker(context, ref);
        if (picked != null) onPicked(picked.$1, picked.$2);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
            labelText: 'Supplier',
            prefixIcon: Icon(Icons.local_shipping_outlined),
            border: OutlineInputBorder()),
        child: Row(children: [
          Expanded(child: Text(display, overflow: TextOverflow.ellipsis)),
          const Icon(Icons.arrow_drop_down_rounded)
        ]),
      ),
    );
  }

  Future<(int, String)?> _openSupplierPicker(
      BuildContext context, WidgetRef ref) async {
    final repo = ref.read(supplierRepositoryProvider);
    List<SupplierDto> results = [];
    try {
      results = await repo.getSuppliers();
    } catch (_) {}
    String q = '';
    int? selected = supplierId;
    if (!context.mounted) return null;
    return showDialog<(int, String)?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AppSelectionDialog(
          title: 'Select Supplier',
          maxWidth: 720,
          searchField: TextField(
            decoration: const InputDecoration(
              hintText: 'Search suppliers',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (v) async {
              q = v.trim();
              final list =
                  await repo.getSuppliers(search: q.isEmpty ? null : q);
              setInner(() => results = list);
            },
          ),
          body: results.isEmpty
              ? const Center(child: Text('No suppliers'))
              : RadioGroup<int>(
                  groupValue: selected,
                  onChanged: (value) => setInner(() => selected = value),
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final s = results[i];
                      return RadioListTile<int>(
                        value: s.supplierId,
                        title: Text(s.name),
                        subtitle: Text(
                          [(s.phone ?? ''), (s.email ?? '')]
                              .where((e) => e.isNotEmpty)
                              .join(' • '),
                        ),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  final s = results.firstWhere((e) => e.supplierId == selected,
                      orElse: () => results.isEmpty
                          ? SupplierDto(
                              supplierId: -1,
                              name: '',
                              contactPerson: null,
                              phone: null,
                              email: null,
                              address: null,
                              paymentTerms: 0,
                              creditLimit: 0,
                              isMercantile: true,
                              isNonMercantile: false,
                              isActive: true,
                              totalPurchases: 0,
                              totalReturns: 0,
                              outstandingAmount: 0,
                              lastPurchaseDate: null)
                          : results.first);
                  if (s.supplierId <= 0) {
                    Navigator.pop(context, null);
                    return;
                  }
                  Navigator.pop(context, (s.supplierId, s.name));
                },
                child: const Text('Select')),
          ],
        ),
      ),
    );
  }
}
