import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../shared/widgets/desktop_sidebar_toggle_action.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../../inventory/data/models.dart';
import '../../../inventory/presentation/widgets/inventory_tracking_selector.dart';
import '../../data/models.dart';
import '../../data/purchases_repository.dart';
import '../widgets/cost_adjustment_editor.dart';

class PurchaseReceiptPage extends ConsumerStatefulWidget {
  const PurchaseReceiptPage({super.key, required this.purchaseId});

  final int purchaseId;

  @override
  ConsumerState<PurchaseReceiptPage> createState() =>
      _PurchaseReceiptPageState();
}

class _PurchaseReceiptPageState extends ConsumerState<PurchaseReceiptPage> {
  Map<String, dynamic>? _purchase;
  bool _loading = true;
  bool _saving = false;
  final List<_ReceiptLineDraft> _lines = [];
  final List<EditableCostAdjustmentRow> _headerAdjustments = [];

  double get _totalReceiveQty => _lines.fold<double>(
        0,
        (sum, line) => sum + (double.tryParse(line.qty.text.trim()) ?? 0),
      );

  double get _remainingQty => _lines.fold<double>(
        0,
        (sum, line) => sum + line.remainingQuantity,
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final row in _headerAdjustments) {
      row.dispose();
    }
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(purchasesRepositoryProvider);
      final purchase = await repo.getPurchase(widget.purchaseId);
      final details =
          (purchase['items'] as List? ?? const []).cast<Map<String, dynamic>>();
      for (final line in _lines) {
        line.dispose();
      }
      _lines
        ..clear()
        ..addAll(
          details.map((detail) => _ReceiptLineDraft.fromDetail(detail)).where(
                (line) => line.remainingQuantity > 0,
              ),
        );
      if (!mounted) return;
      setState(() => _purchase = purchase);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _configureTracking(_ReceiptLineDraft line) async {
    final qty = double.tryParse(line.qty.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Enter a receive quantity first')),
        );
      return;
    }
    final selection = await showInventoryTrackingSelector(
      context: context,
      ref: ref,
      productId: line.productId,
      productName: line.productName,
      quantity: qty,
      mode: InventoryTrackingMode.receive,
      initialSelection: line.initialSelection,
    );
    if (selection != null && mounted) {
      setState(() => line.tracking = selection);
    }
  }

  Future<void> _receive() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final payload = <Map<String, dynamic>>[];
      final itemAdjustments = <Map<String, dynamic>>[];
      for (final line in _lines) {
        final qty = double.tryParse(line.qty.text.trim()) ?? 0;
        if (qty <= 0) continue;
        final cappedQty =
            qty > line.remainingQuantity ? line.remainingQuantity : qty;
        final tracking = line.tracking;
        if (tracking == null) {
          throw StateError(
            'Configure variation / tracking for ${line.productName}',
          );
        }
        payload.add({
          'purchase_detail_id': line.purchaseDetailId,
          'received_quantity': cappedQty,
          ...tracking.toReceiveJson(),
        });
        for (final adjustment in line.adjustments) {
          final draft = adjustment.toDraft();
          if (draft == null) continue;
          itemAdjustments.add({
            'purchase_detail_id': line.purchaseDetailId,
            ...draft.toJson(),
          });
        }
      }
      if (payload.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Enter quantities to receive')),
          );
        return;
      }
      final result =
          await ref.read(purchasesRepositoryProvider).receiveAgainstPO(
                purchaseId: widget.purchaseId,
                items: payload,
                headerAdjustments: _headerAdjustments
                    .map((row) => row.toDraft())
                    .whereType<CostAdjustmentDraft>()
                    .toList(),
                itemAdjustments: itemAdjustments,
              );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('GRN recorded')));
      Navigator.of(context).pop(result);
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
    final purchase = _purchase;
    final titleNumber = purchase?['purchase_number']?.toString() ?? '';
    final showSidebarToggle = AppBreakpoints.isTabletOrDesktop(context);
    final isDesktop = AppBreakpoints.isDesktop(context);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: showSidebarToggle ? 104 : null,
        leading: showSidebarToggle ? const DesktopSidebarToggleLeading() : null,
        title: Text('Receive $titleNumber'),
      ),
      body: SafeArea(
        child: _loading && purchase == null
            ? const Center(child: CircularProgressIndicator())
            : isDesktop
                ? _buildDesktopBody(purchase)
                : _buildMobileBody(purchase),
      ),
    );
  }

  Widget _buildDesktopBody(Map<String, dynamic>? purchase) {
    const gap = 12.0;
    const railWidth = 320.0;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildHeader(purchase),
          if (_loading) ...[
            const SizedBox(height: gap),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: gap),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildReceiptOverview(purchase)),
                const SizedBox(width: gap),
                Expanded(child: _buildHeaderAddonsSection()),
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

  Widget _buildMobileBody(Map<String, dynamic>? purchase) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(purchase),
        if (_loading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 12),
        _buildReceiptOverview(purchase),
        const SizedBox(height: 12),
        _buildHeaderAddonsSection(),
        const SizedBox(height: 12),
        _buildItemsSection(),
        const SizedBox(height: 12),
        _buildSummaryCard(),
        const SizedBox(height: 12),
        _buildActionPanel(),
      ],
    );
  }

  Widget _buildHeader(Map<String, dynamic>? purchase) {
    return ProfessionalDocumentHeader(
      title: purchase?['purchase_number']?.toString() ?? 'Record Goods Receipt',
      subtitle:
          'Capture received quantities, confirm the final tracking, and record any landed-cost adjustments before the GRN is posted.',
      badges: [
        const ProfessionalBadge(label: 'Receive Against PO'),
        ProfessionalBadge(
          label: '${_lines.length} Remaining Lines',
          backgroundColor: const Color(0xFFEAF1F8),
          foregroundColor: const Color(0xFF23415F),
        ),
      ],
    );
  }

  Widget _buildReceiptOverview(Map<String, dynamic>? purchase) {
    return ProfessionalOverviewCard(
      title: 'Receipt Context',
      icon: Icons.call_received_rounded,
      child: ProfessionalFieldGrid(
        fields: [
          ProfessionalFieldGridItem(
            label: 'Purchase Order',
            value: purchase?['purchase_number']?.toString() ?? 'Not loaded',
          ),
          ProfessionalFieldGridItem(
            label: 'Supplier',
            value: (purchase?['supplier']?['name'] ??
                        purchase?['supplier_name'] ??
                        '')
                    .toString()
                    .trim()
                    .isEmpty
                ? 'Not available'
                : (purchase?['supplier']?['name'] ?? purchase?['supplier_name'])
                    .toString(),
          ),
          ProfessionalFieldGridItem(
            label: 'Receipt Rule',
            value: _lines.isEmpty
                ? 'All ordered quantities are already received.'
                : 'Each remaining line needs quantity and final tracking.',
            maxLines: 2,
          ),
          ProfessionalFieldGridItem(
            label: 'Remaining Qty',
            value: _remainingQty.toStringAsFixed(2),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAddonsSection() {
    return ProfessionalSectionCard(
      title: 'Header Add-ons',
      subtitle:
          'Apply freight, duty, rebate, or other GRN-level adjustments before posting the receipt.',
      child: CostAdjustmentListEditor(
        title: 'Header Add-ons',
        rows: _headerAdjustments,
        onAdd: () => setState(
          () => _headerAdjustments.add(EditableCostAdjustmentRow()),
        ),
        onChanged: () => setState(() {}),
        onRemove: (index) => setState(() {
          _headerAdjustments[index].dispose();
          _headerAdjustments.removeAt(index);
        }),
        emptyLabel:
            'Distribute freight, duty, rebate, or other GRN-level adjustments across received lines.',
      ),
    );
  }

  Widget _buildItemsSection({bool desktopLayout = false}) {
    return ProfessionalSectionCard(
      title: 'Receipt Lines',
      subtitle:
          'Review each remaining line, confirm the received quantity, and capture the final barcode or tracking details.',
      expandChild: desktopLayout,
      child: _lines.isEmpty
          ? const Center(
              child: ProfessionalDocumentEmptyState(
                title: 'Nothing left to receive',
                message:
                    'This purchase order has no remaining quantities waiting for a goods receipt.',
              ),
            )
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final line in _lines) ...[
                  _buildReceiptLineCard(line),
                  if (line != _lines.last) const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  Widget _buildReceiptLineCard(_ReceiptLineDraft line) {
    return ProfessionalOverviewCard(
      title: line.productName,
      icon: Icons.inventory_2_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfessionalFieldGrid(
            fields: [
              ProfessionalFieldGridItem(
                label: 'Remaining Qty',
                value: line.remainingQuantity.toStringAsFixed(2),
              ),
              ProfessionalFieldGridItem(
                label: 'Suggested Variation',
                value: (line.lockedBarcodeId ?? 0) > 0
                    ? 'Barcode #${line.lockedBarcodeId}'
                    : 'Select during receipt',
              ),
            ],
          ),
          if ((line.lockedBarcodeId ?? 0) > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Order line has a suggested variation. Change it here if the received barcode differs.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: line.qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Receive Quantity',
              prefixIcon: Icon(Icons.format_list_numbered_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _configureTracking(line),
              icon: const Icon(Icons.qr_code_2_rounded),
              label: Text(
                line.tracking == null
                    ? 'Configure Variation / Tracking'
                    : line.tracking!.summary(
                        double.tryParse(line.qty.text.trim()) ?? 0,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          CostAdjustmentListEditor(
            title: 'Item Add-ons',
            rows: line.adjustments,
            onAdd: () => setState(
              () => line.adjustments.add(EditableCostAdjustmentRow()),
            ),
            onChanged: () => setState(() {}),
            onRemove: (index) => setState(() {
              line.adjustments[index].dispose();
              line.adjustments.removeAt(index);
            }),
            emptyLabel:
                'Optional cost or income adjustments for this received line.',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return ProfessionalSummaryCard(
      title: 'Receipt Summary',
      expandContent: AppBreakpoints.isDesktop(context),
      rows: [
        (
          label: 'Remaining Lines',
          value: '${_lines.length}',
          emphasize: false,
        ),
        (
          label: 'Remaining Qty',
          value: _remainingQty.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: 'Receipt Qty',
          value: _totalReceiveQty.toStringAsFixed(2),
          emphasize: true,
        ),
      ],
      footer: Text(
        'Posting this receipt creates the GRN and updates inventory against the approved purchase order.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Widget _buildActionPanel() {
    return ProfessionalSectionCard(
      title: 'Post Receipt',
      subtitle:
          'Record the GRN once quantities and tracking are complete for every line you are receiving now.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _saving ? null : _receive,
            icon: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.task_alt_rounded),
            label: Text(_saving ? 'Posting...' : 'Record GRN'),
            style: professionalCompactButtonStyle(context),
          ),
          const SizedBox(height: 12),
          ProfessionalFieldGrid(
            fields: [
              ProfessionalFieldGridItem(
                label: 'Ready Lines',
                value: '${_lines.length}',
              ),
              ProfessionalFieldGridItem(
                label: 'Header Add-ons',
                value: '${_headerAdjustments.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptLineDraft {
  _ReceiptLineDraft({
    required this.purchaseDetailId,
    required this.productId,
    required this.productName,
    required this.remainingQuantity,
    required this.lockedBarcodeId,
    required this.qty,
    required this.tracking,
  });

  factory _ReceiptLineDraft.fromDetail(Map<String, dynamic> detail) {
    final quantity = (detail['quantity'] as num?)?.toDouble() ?? 0;
    final received = (detail['received_quantity'] as num?)?.toDouble() ?? 0;
    final remaining = quantity - received;
    final lockedBarcodeId = detail['barcode_id'] as int?;
    return _ReceiptLineDraft(
      purchaseDetailId: detail['purchase_detail_id'] as int? ?? 0,
      productId: detail['product_id'] as int? ?? 0,
      productName: detail['product']?['name']?.toString() ??
          'Product #${detail['product_id']}',
      remainingQuantity: remaining > 0 ? remaining : 0,
      lockedBarcodeId: lockedBarcodeId,
      qty: TextEditingController(
        text: remaining > 0 ? remaining.toStringAsFixed(2) : '0',
      ),
      tracking: lockedBarcodeId != null && lockedBarcodeId > 0
          ? InventoryTrackingSelection(barcodeId: lockedBarcodeId)
          : null,
    );
  }

  final int purchaseDetailId;
  final int productId;
  final String productName;
  final double remainingQuantity;
  final int? lockedBarcodeId;
  final TextEditingController qty;
  InventoryTrackingSelection? tracking;
  final List<EditableCostAdjustmentRow> adjustments = [];

  InventoryTrackingSelection? get initialSelection => tracking;

  void dispose() {
    for (final adjustment in adjustments) {
      adjustment.dispose();
    }
    qty.dispose();
  }
}
