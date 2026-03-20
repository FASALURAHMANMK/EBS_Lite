import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
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
    final purchase = _purchase;
    final titleNumber = purchase?['purchase_number']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(title: Text('Receive $titleNumber')),
      body: SafeArea(
        child: _loading
            ? const LinearProgressIndicator(minHeight: 2)
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  CostAdjustmentListEditor(
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
                  const SizedBox(height: 12),
                  if (_lines.isEmpty)
                    const Card(
                      elevation: 0,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Nothing left to receive'),
                      ),
                    )
                  else
                    ..._lines.map(
                      (line) => Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.productName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Remaining: ${line.remainingQuantity.toStringAsFixed(2)}',
                              ),
                              if ((line.lockedBarcodeId ?? 0) > 0)
                                Text(
                                  'Order line has a suggested variation. Change it here if the received barcode differs.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: line.qty,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Receive Quantity',
                                  prefixIcon:
                                      Icon(Icons.format_list_numbered_rounded),
                                ),
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
                                            double.tryParse(
                                                  line.qty.text.trim(),
                                                ) ??
                                                0,
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              CostAdjustmentListEditor(
                                title: 'Item Add-ons',
                                rows: line.adjustments,
                                onAdd: () => setState(
                                  () => line.adjustments
                                      .add(EditableCostAdjustmentRow()),
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
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _saving ? null : _receive,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : const Text('Record GRN'),
                    ),
                  ),
                ],
              ),
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
