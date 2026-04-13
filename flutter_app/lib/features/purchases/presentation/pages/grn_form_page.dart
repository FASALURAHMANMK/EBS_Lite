import 'package:ebs_lite/features/inventory/data/models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ebs_lite/core/error_handler.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/outbox/outbox_notifier.dart';
import '../../../../shared/widgets/desktop_sidebar_toggle_action.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../../dashboard/data/payment_methods_repository.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/presentation/widgets/inventory_tracking_selector.dart';
import '../../../pos/data/pos_repository.dart';
import '../../data/grn_repository.dart';
import '../../data/models.dart';
import '../widgets/cost_adjustment_editor.dart';
import '../widgets/purchase_document_widgets.dart';

class GrnFormPage extends ConsumerStatefulWidget {
  const GrnFormPage({super.key});

  @override
  ConsumerState<GrnFormPage> createState() => _GrnFormPageState();
}

class _GrnFormPageState extends ConsumerState<GrnFormPage> {
  int? _supplierId;
  String? _supplierName;
  final _invoiceNumber = TextEditingController();
  final _notes = TextEditingController();
  String? _invoiceFilePath;
  final List<EditableCostAdjustmentRow> _headerAdjustments = [];

  bool _paidNow = false;
  final _paidAmount = TextEditingController();
  List<PaymentMethodDto> _paymentMethods = const [];
  int? _paymentMethodId;
  bool _loadingPaymentMethods = false;
  Object? _paymentMethodsError;

  final List<_GrnLine> _lines = [
    _GrnLine(),
  ];
  bool _saving = false;

  List<_GrnLine> get _activeLines => _lines
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

  @override
  void dispose() {
    _invoiceNumber.dispose();
    _notes.dispose();
    _paidAmount.dispose();
    for (final row in _headerAdjustments) {
      row.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showSidebarToggle = AppBreakpoints.isTabletOrDesktop(context);
    final isDesktop = AppBreakpoints.isDesktop(context);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: showSidebarToggle ? 104 : null,
        leading: showSidebarToggle ? const DesktopSidebarToggleLeading() : null,
        title: const Text('New Goods Receipt'),
      ),
      body: SafeArea(
        child: isDesktop ? _buildDesktopBody(theme) : _buildMobileBody(theme),
      ),
    );
  }

  Widget _buildDesktopBody(ThemeData theme) {
    const gap = 12.0;
    const railWidth = 320.0;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ProfessionalDocumentHeader(
            title: 'Standalone GRN Workspace',
            subtitle:
                'Desktop operators can capture supplier paperwork, landed costs, payment, and receipt lines in one dense workspace.',
            badges: [
              const ProfessionalBadge(label: 'Without PO'),
              ProfessionalBadge(
                label: '${_activeLines.length} Active Lines',
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
            height: 228,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildDocumentOverview()),
                const SizedBox(width: gap),
                Expanded(child: _buildHeaderAdjustmentsSection()),
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
                Expanded(child: _buildItemsSection(theme, desktopLayout: true)),
                const SizedBox(width: gap),
                SizedBox(width: railWidth, child: _buildActionPanel(theme)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ProfessionalDocumentHeader(
          title: 'New Goods Receipt',
          subtitle:
              'Mobile keeps the GRN flow stacked: paperwork, header add-ons, payment, then item receipt details.',
          badges: [
            ProfessionalBadge(label: '${_activeLines.length} Active Lines'),
          ],
        ),
        if (_saving) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 12),
        _buildDocumentOverview(),
        const SizedBox(height: 12),
        _buildHeaderAdjustmentsSection(),
        const SizedBox(height: 12),
        _buildPaymentCard(theme),
        const SizedBox(height: 12),
        _buildItemsSection(theme),
        const SizedBox(height: 12),
        _buildSummaryCard(),
        const SizedBox(height: 12),
        _buildActionPanel(theme),
      ],
    );
  }

  Widget _buildDocumentOverview() {
    return ProfessionalOverviewCard(
      title: 'Supplier & Paperwork',
      icon: Icons.receipt_long_rounded,
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
          TextField(
            controller: _invoiceNumber,
            decoration: const InputDecoration(
              labelText: 'Invoice Number (physical)',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickInvoiceFile,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(
                    _invoiceFilePath == null
                        ? 'Upload Invoice (Image/PDF)'
                        : 'Invoice Selected',
                  ),
                ),
              ),
              if (_invoiceFilePath != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Clear',
                  onPressed: () => setState(() => _invoiceFilePath = null),
                  icon: const Icon(Icons.clear_rounded),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: 4,
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

  Widget _buildHeaderAdjustmentsSection() {
    return ProfessionalSectionCard(
      title: 'Header Add-ons',
      subtitle:
          'Capture freight, duty, rebate, or other receipt-level costs before the GRN is created.',
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
        emptyLabel: 'Add freight, duty, rebate, or other header-level costs.',
      ),
    );
  }

  Widget _buildItemsSection(ThemeData theme, {bool desktopLayout = false}) {
    return ProfessionalSectionCard(
      title: 'Receipt Lines',
      subtitle:
          'Add products, confirm quantities and tracking, then capture any line-level landed-cost adjustments.',
      action: FilledButton.tonalIcon(
        onPressed: () => setState(() => _lines.add(_GrnLine())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item'),
        style: professionalCompactButtonStyle(context),
      ),
      expandChild: desktopLayout,
      child: _lines.isEmpty
          ? const Center(
              child: ProfessionalDocumentEmptyState(
                title: 'No receipt lines',
                message:
                    'Add at least one item line before creating the goods receipt.',
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildLines(theme),
            ),
    );
  }

  Widget _buildSummaryCard() {
    return ProfessionalSummaryCard(
      title: 'GRN Summary',
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
          value: _computeTotal().toStringAsFixed(2),
          emphasize: true,
        ),
      ],
      footer: Text(
        _paidNow
            ? 'This receipt will also post immediate payment when saved.'
            : 'Leave payment off to record the purchase on credit.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Widget _buildActionPanel(ThemeData theme) {
    return ProfessionalSectionCard(
      title: 'Post Receipt',
      subtitle:
          'Create the standalone GRN after supplier, payment, and tracking details are complete.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPaymentCard(theme),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.task_alt_rounded),
            label: Text(_saving ? 'Creating...' : 'Create GRN'),
            style: professionalCompactButtonStyle(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(ThemeData theme) {
    final total = _computeTotal();
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Payment', style: theme.textTheme.titleMedium),
                ),
                Switch.adaptive(
                  value: _paidNow,
                  onChanged: _saving
                      ? null
                      : (v) async {
                          setState(() {
                            _paidNow = v;
                            _paymentMethodsError = null;
                          });
                          if (!v) return;
                          if (_paidAmount.text.trim().isEmpty ||
                              (double.tryParse(_paidAmount.text.trim()) ?? 0) <=
                                  0) {
                            _paidAmount.text = total.toStringAsFixed(2);
                          }
                          await _loadPaymentMethodsIfNeeded();
                        },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${total.toStringAsFixed(2)}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (_paidNow) ...[
              const SizedBox(height: 12),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  border: const OutlineInputBorder(),
                  prefixIcon: _loadingPaymentMethods
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.payments_outlined),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _paymentMethodId,
                    items: _paymentMethods
                        .where((m) => m.isActive)
                        .map(
                          (m) => DropdownMenuItem<int>(
                            value: m.methodId,
                            child: Text(m.name),
                          ),
                        )
                        .toList(),
                    onChanged: _saving || _loadingPaymentMethods
                        ? null
                        : (v) => setState(() => _paymentMethodId = v),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _paidAmount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Paid Amount',
                  prefixIcon: Icon(Icons.currency_exchange_rounded),
                ),
              ),
              if (_paymentMethodsError != null) ...[
                const SizedBox(height: 8),
                Text(
                  ErrorHandler.message(_paymentMethodsError!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Leave this off to record the purchase on credit.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _computeTotal() {
    double total = 0;
    for (final l in _lines) {
      final qty = double.tryParse(l.qty.text.trim()) ?? 0;
      final price = double.tryParse(l.price.text.trim()) ?? 0;
      if (l.product == null || qty <= 0 || price < 0) continue;
      total += qty * price;
      for (final adjustment in l.adjustments) {
        final draft = adjustment.toDraft();
        if (draft == null) continue;
        total += draft.direction == 'INCOME' ? -draft.amount : draft.amount;
      }
    }
    for (final adjustment in _headerAdjustments) {
      final draft = adjustment.toDraft();
      if (draft == null) continue;
      total += draft.direction == 'INCOME' ? -draft.amount : draft.amount;
    }
    return total;
  }

  Future<void> _loadPaymentMethodsIfNeeded() async {
    if (_paymentMethods.isNotEmpty || _loadingPaymentMethods) return;
    setState(() {
      _loadingPaymentMethods = true;
      _paymentMethodsError = null;
    });
    try {
      final repo = ref.read(posRepositoryProvider);
      final list = await repo.getPaymentMethods();
      if (!mounted) return;
      setState(() {
        _paymentMethods = list;
        _paymentMethodId = list.isNotEmpty ? list.first.methodId : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _paymentMethodsError = e);
    } finally {
      if (mounted) setState(() => _loadingPaymentMethods = false);
    }
  }

  List<Widget> _buildLines(ThemeData theme) {
    final widgets = <Widget>[];
    for (int i = 0; i < _lines.length; i++) {
      widgets.add(
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                PurchaseProductPicker(
                  product: _lines[i].product,
                  selectedVariantName: _lines[i].tracking?.variantName,
                  onPicked: (picked) async {
                    InventoryTrackingSelection? tracking;
                    try {
                      final variants = await ref
                          .read(inventoryRepositoryProvider)
                          .getStockVariants(picked.productId);
                      if (variants.isNotEmpty) {
                        final variant = variants.first;
                        tracking = InventoryTrackingSelection(
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
                      _lines[i].tracking = tracking;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lines[i].qty,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          prefixIcon: Icon(Icons.format_list_numbered_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _lines[i].price,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Unit Cost',
                          prefixIcon: Icon(Icons.currency_rupee_rounded),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: _lines.length == 1
                          ? null
                          : () => setState(() => _lines.removeAt(i)),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _configureTracking(_lines[i]),
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: Text(
                      _lines[i].tracking == null
                          ? 'Configure Variation / Tracking'
                          : _lines[i].tracking!.summary(
                                double.tryParse(_lines[i].qty.text.trim()) ?? 0,
                              ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                CostAdjustmentListEditor(
                  title: 'Item Add-ons',
                  rows: _lines[i].adjustments,
                  onAdd: () => setState(
                    () =>
                        _lines[i].adjustments.add(EditableCostAdjustmentRow()),
                  ),
                  onChanged: () => setState(() {}),
                  onRemove: (index) => setState(() {
                    _lines[i].adjustments[index].dispose();
                    _lines[i].adjustments.removeAt(index);
                  }),
                  emptyLabel:
                      'Add line-level charges or supplier income adjustments for this item.',
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Future<void> _pickInvoiceFile() async {
    final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg']);
    if (res != null && res.files.single.path != null) {
      setState(() => _invoiceFilePath = res.files.single.path);
    }
  }

  Future<void> _save() async {
    final supplierId = _supplierId;
    if (supplierId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Please select supplier')));
      return;
    }
    final validLines = _lines
        .where((l) =>
            l.product != null &&
            (double.tryParse(l.qty.text.trim()) ?? 0) > 0 &&
            (double.tryParse(l.price.text.trim()) ?? 0) >= 0)
        .toList();
    if (validLines.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Add at least one item with quantity and cost')));
      return;
    }
    setState(() => _saving = true);
    try {
      final total = _computeTotal();
      for (final line in validLines) {
        final tracking = line.tracking;
        final qty = double.tryParse(line.qty.text.trim()) ?? 0;
        if (tracking == null || (tracking.barcodeId ?? 0) <= 0) {
          throw StateError(
            'Configure variation / tracking for ${line.product!.name}',
          );
        }
        if (tracking.isSerialized) {
          if (qty != qty.roundToDouble() ||
              tracking.serialNumbers.length != qty.round()) {
            throw StateError(
              'Serial count must match quantity for ${line.product!.name}',
            );
          }
        }
        if (tracking.trackingType == 'BATCH' &&
            (tracking.batchNumber ?? '').trim().isEmpty) {
          throw StateError(
            'Batch / expiry details are required for ${line.product!.name}',
          );
        }
      }
      double? paidAmount;
      int? methodId;
      if (_paidNow) {
        paidAmount = double.tryParse(_paidAmount.text.trim()) ?? 0;
        methodId = _paymentMethodId;
        if (paidAmount <= 0) {
          throw StateError('Enter a valid paid amount');
        }
        if (paidAmount > total) {
          throw StateError('Paid amount cannot exceed total');
        }
        if (methodId == null) {
          throw StateError('Select a payment method');
        }
      }
      final repo = ref.read(grnRepositoryProvider);
      final headerAdjustments = _headerAdjustments
          .map((row) => row.toDraft())
          .whereType<CostAdjustmentDraft>()
          .toList();
      final itemAdjustments = <int, List<CostAdjustmentDraft>>{};
      final items = [
        for (int index = 0; index < validLines.length; index++)
          () {
            final l = validLines[index];
            final drafts = l.adjustments
                .map((row) => row.toDraft())
                .whereType<CostAdjustmentDraft>()
                .toList();
            if (drafts.isNotEmpty) {
              itemAdjustments[index] = drafts;
            }
            return GrnCreateItem(
              productId: l.product!.productId,
              quantity: double.tryParse(l.qty.text.trim()) ?? 0,
              unitPrice: double.tryParse(l.price.text.trim()) ?? 0,
              barcodeId: l.tracking?.barcodeId,
              serialNumbers: l.tracking?.serialNumbers ?? const [],
              batchNumber: l.tracking?.batchNumber,
              expiryDate: l.tracking?.expiryDate,
            );
          }(),
      ];
      final result = await repo.createGrnWithoutPo(
        supplierId: supplierId,
        items: items,
        headerAdjustments: headerAdjustments,
        itemAdjustments: itemAdjustments,
        invoiceNumber: _invoiceNumber.text.trim().isEmpty
            ? null
            : _invoiceNumber.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        invoiceFilePath: _invoiceFilePath,
        paidAmount: paidAmount,
        paymentMethodId: methodId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on OutboxQueuedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
      Navigator.of(context).pop((
        purchaseId: null,
        goodsReceiptId: null,
        queued: true,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _configureTracking(_GrnLine line) async {
    final product = line.product;
    if (product == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Select a product first')),
        );
      return;
    }
    final qty = double.tryParse(line.qty.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Enter quantity first')),
        );
      return;
    }
    final selection = await showInventoryTrackingSelector(
      context: context,
      ref: ref,
      productId: product.productId,
      productName: product.name,
      quantity: qty,
      mode: InventoryTrackingMode.receive,
      initialSelection: line.tracking,
    );
    if (selection != null && mounted) {
      setState(() => line.tracking = selection);
    }
  }
}

class _GrnLine {
  InventoryListItem? product;
  InventoryTrackingSelection? tracking;
  final qty = TextEditingController();
  final price = TextEditingController();
  final adjustments = <EditableCostAdjustmentRow>[];
  void dispose() {
    for (final adjustment in adjustments) {
      adjustment.dispose();
    }
    qty.dispose();
    price.dispose();
  }
}
