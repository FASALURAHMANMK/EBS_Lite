import 'package:ebs_lite/core/error_handler.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/features/inventory/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/desktop_sidebar_toggle_action.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/presentation/widgets/inventory_variant_selector.dart';
import '../../data/purchases_repository.dart';
import '../widgets/purchase_document_widgets.dart';

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
          PurchaseSupplierPicker(
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
          : Column(
              mainAxisSize: MainAxisSize.min,
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
              PurchaseProductPicker(
                product: _lines[i].product,
                selectedVariantName: _lines[i].variation?.variantName,
                onPicked: (picked) async {
                  InventoryTrackingSelection? variation;
                  try {
                    final variants = await ref
                        .read(inventoryRepositoryProvider)
                        .getStockVariants(picked.productId);
                    if (variants.isNotEmpty) {
                      final variant = variants.first;
                      variation = InventoryTrackingSelection(
                        barcodeId: variant.barcodeId,
                        trackingType: variant.trackingType,
                        isSerialized: variant.isSerialized,
                        barcode: variant.barcode,
                        variantName: variant.variantName,
                      );
                    }
                  } catch (_) {}
                  if (!mounted) return;
                  setState(() {
                    _lines[i].product = picked;
                    _lines[i].variation = variation;
                  });
                },
              ),
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
