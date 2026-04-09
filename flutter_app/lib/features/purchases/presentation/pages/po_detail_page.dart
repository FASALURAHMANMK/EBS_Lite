import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/error_handler.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/desktop_sidebar_toggle_action.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../widgets/purchase_document_widgets.dart';
import '../../data/purchases_repository.dart';
import 'purchase_receipt_page.dart';

class PoDetailPage extends ConsumerStatefulWidget {
  const PoDetailPage({super.key, required this.purchaseId});

  final int purchaseId;

  @override
  ConsumerState<PoDetailPage> createState() => _PoDetailPageState();
}

class _PoDetailPageState extends ConsumerState<PoDetailPage> {
  Map<String, dynamic>? _po;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(purchasesRepositoryProvider);
      final po = await repo.getPurchase(widget.purchaseId);
      if (!mounted) return;
      setState(() => _po = po);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _items =>
      (_po?['items'] as List? ?? const []).cast<Map<String, dynamic>>();

  String get _status => (_po?['status'] ?? '').toString();

  double get _orderedQty => _items.fold<double>(
        0,
        (sum, item) => sum + ((item['quantity'] as num?)?.toDouble() ?? 0),
      );

  double get _receivedQty => _items.fold<double>(
        0,
        (sum, item) =>
            sum + ((item['received_quantity'] as num?)?.toDouble() ?? 0),
      );

  double get _remainingQty =>
      (_orderedQty - _receivedQty).clamp(0, double.infinity);

  double get _totalValue => _items.fold<double>(
        0,
        (sum, item) =>
            sum +
            (((item['quantity'] as num?)?.toDouble() ?? 0) *
                ((item['unit_price'] as num?)?.toDouble() ?? 0)),
      );

  bool get _canApprove =>
      !_loading &&
      (_status != 'APPROVED' &&
          _status != 'PARTIALLY_RECEIVED' &&
          _status != 'RECEIVED');

  bool get _canReceive =>
      !_loading &&
      _remainingQty > 0 &&
      (_status == 'APPROVED' || _status == 'PARTIALLY_RECEIVED');

  @override
  Widget build(BuildContext context) {
    final localePrefs = ref.watch(localePreferencesProvider);
    final showSidebarToggle = AppBreakpoints.isTabletOrDesktop(context);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final po = _po;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: showSidebarToggle ? 104 : null,
        leading: showSidebarToggle ? const DesktopSidebarToggleLeading() : null,
        title: Text(po?['purchase_number']?.toString() ?? 'Purchase Order'),
      ),
      body: SafeArea(
        child: _loading && po == null
            ? const Center(child: CircularProgressIndicator())
            : po == null
                ? const Center(child: Text('Purchase order not found'))
                : (isDesktop
                    ? _buildDesktopBody(context, localePrefs, po)
                    : _buildMobileBody(context, localePrefs, po)),
      ),
    );
  }

  Widget _buildDesktopBody(
    BuildContext context,
    LocalePreferencesState localePrefs,
    Map<String, dynamic> po,
  ) {
    const gap = 12.0;
    const railWidth = 320.0;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildHeader(context, po),
          if (_loading) ...[
            const SizedBox(height: gap),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: gap),
          SizedBox(
            height: 166,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildOverviewCard(context, localePrefs, po)),
                const SizedBox(width: gap),
                SizedBox(width: railWidth, child: _buildSummaryRail(context)),
              ],
            ),
          ),
          const SizedBox(height: gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                    child: _buildItemsSection(context, desktopLayout: true)),
                const SizedBox(width: gap),
                SizedBox(
                  width: railWidth,
                  child: _buildActionPanel(context, po),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody(
    BuildContext context,
    LocalePreferencesState localePrefs,
    Map<String, dynamic> po,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(context, po),
        if (_loading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 12),
        _buildOverviewCard(context, localePrefs, po),
        const SizedBox(height: 12),
        _buildActionPanel(context, po),
        const SizedBox(height: 12),
        _buildItemsSection(context),
        const SizedBox(height: 12),
        _buildSummaryRail(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> po) {
    final supplierName =
        (po['supplier']?['name'] ?? po['supplier_name'] ?? '').toString();
    return ProfessionalDocumentHeader(
      title: po['purchase_number']?.toString() ?? 'Purchase Order',
      subtitle: supplierName.isEmpty
          ? 'Purchase order workspace with approval status, receiving progress, and line-level review.'
          : 'Purchase order workspace for $supplierName with approval status, receiving progress, and line-level review.',
      badges: [
        purchaseStatusBadge(_status),
        if (supplierName.isNotEmpty) ProfessionalBadge(label: supplierName),
        if (_remainingQty <= 0 && _items.isNotEmpty)
          const ProfessionalBadge(
            label: 'Ready To Close',
            backgroundColor: Color(0xFFE8F3EC),
            foregroundColor: Color(0xFF255C35),
          ),
      ],
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    LocalePreferencesState localePrefs,
    Map<String, dynamic> po,
  ) {
    return ProfessionalOverviewCard(
      title: 'Order Overview',
      icon: Icons.inventory_2_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              ProfessionalMetaCell(
                label: 'Supplier',
                value: (po['supplier']?['name'] ?? po['supplier_name'] ?? '')
                        .toString()
                        .trim()
                        .isEmpty
                    ? 'Not available'
                    : (po['supplier']?['name'] ?? po['supplier_name'])
                        .toString(),
              ),
              ProfessionalMetaCell(
                label: 'PO Date',
                value: AppDateTime.formatFlexibleDate(
                  context,
                  localePrefs,
                  po['purchase_date']?.toString(),
                  fallback: po['purchase_date']?.toString() ?? 'Not available',
                ),
              ),
              ProfessionalMetaCell(
                label: 'Reference',
                value: (po['reference_number'] ?? '').toString().trim().isEmpty
                    ? 'Not set'
                    : po['reference_number'].toString(),
              ),
              ProfessionalMetaCell(
                label: 'Notes',
                value: (po['notes'] ?? '').toString().trim().isEmpty
                    ? 'No notes'
                    : po['notes'].toString(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ProfessionalFieldGrid(
            fields: [
              ProfessionalFieldGridItem(
                label: 'Approval Rule',
                value: _canApprove
                    ? 'Approve before any receiving activity.'
                    : 'Order is approved or already in receiving progress.',
                maxLines: 2,
              ),
              ProfessionalFieldGridItem(
                label: 'Receiving Rule',
                value: _canReceive
                    ? 'Open the receipt workspace to capture received quantities and tracking.'
                    : _remainingQty <= 0
                        ? 'All ordered quantities are already received.'
                        : 'Receiving opens after approval.',
                maxLines: 2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(BuildContext context,
      {bool desktopLayout = false}) {
    return ProfessionalSectionCard(
      title: 'Ordered Items',
      subtitle:
          'Review ordered versus received quantities before approving or recording the next goods receipt.',
      expandChild: desktopLayout,
      child: _items.isEmpty
          ? const Center(
              child: ProfessionalDocumentEmptyState(
                title: 'No order lines',
                message: 'This purchase order does not contain any line items.',
              ),
            )
          : desktopLayout
              ? Column(
                  children: [
                    const _PoItemsHeader(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _PoItemDesktopRow(
                          item: _items[index],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    for (final item in _items) ...[
                      _PoItemMobileCard(item: item),
                      if (item != _items.last) const SizedBox(height: 10),
                    ],
                  ],
                ),
    );
  }

  Widget _buildSummaryRail(BuildContext context) {
    return ProfessionalSummaryCard(
      title: 'PO Summary',
      expandContent: AppBreakpoints.isDesktop(context),
      rows: [
        (
          label: 'Line Count',
          value: '${_items.length}',
          emphasize: false,
        ),
        (
          label: 'Ordered Qty',
          value: _orderedQty.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: 'Received Qty',
          value: _receivedQty.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: 'Remaining Qty',
          value: _remainingQty.toStringAsFixed(2),
          emphasize: true,
        ),
      ],
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1F8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated Order Value',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  _totalValue.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF19324D),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel(BuildContext context, Map<String, dynamic> po) {
    return ProfessionalSectionCard(
      title: 'Workflow Actions',
      subtitle:
          'Approval and receiving stay visible so operators can move the PO forward without hunting through secondary screens.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _canReceive ? _receive : null,
            icon: const Icon(Icons.call_received_rounded),
            label: Text(
                _status == 'RECEIVED' ? 'Fully Received' : 'Receive Goods'),
            style: professionalCompactButtonStyle(context),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _canApprove ? _approve : null,
            icon: const Icon(Icons.verified_outlined),
            label: Text(
                _canApprove ? 'Approve Purchase Order' : 'Already Approved'),
            style: professionalCompactButtonStyle(context, outlined: true),
          ),
          const SizedBox(height: 14),
          ProfessionalFieldGrid(
            fields: [
              ProfessionalFieldGridItem(
                label: 'Current Status',
                value: _status.replaceAll('_', ' '),
              ),
              ProfessionalFieldGridItem(
                label: 'Open Receiving',
                value: _canReceive
                    ? 'Enabled'
                    : 'Disabled until approval or remaining quantity exists',
                maxLines: 2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approve() async {
    try {
      setState(() => _loading = true);
      final repo = ref.read(purchasesRepositoryProvider);
      await repo.approvePurchaseOrder(widget.purchaseId);
      await _load();
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    }
  }

  Future<void> _receive() async {
    final po = _po;
    if (po == null) return;
    if (_status != 'APPROVED' && _status != 'PARTIALLY_RECEIVED') {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Approve the PO before receiving')),
        );
      return;
    }
    if (_remainingQty <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Nothing left to receive')));
      return;
    }
    final recorded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PurchaseReceiptPage(purchaseId: widget.purchaseId),
      ),
    );
    if (recorded == true) {
      await _load();
    }
  }
}

class _PoItemsHeader extends StatelessWidget {
  const _PoItemsHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        ProfessionalHeaderCell(label: 'Product', flex: 5),
        SizedBox(width: 10),
        ProfessionalHeaderCell(
            label: 'Ordered', flex: 2, textAlign: TextAlign.right),
        SizedBox(width: 10),
        ProfessionalHeaderCell(
            label: 'Received', flex: 2, textAlign: TextAlign.right),
        SizedBox(width: 10),
        ProfessionalHeaderCell(
            label: 'Balance', flex: 2, textAlign: TextAlign.right),
        SizedBox(width: 10),
        ProfessionalHeaderCell(
            label: 'Unit Price', flex: 2, textAlign: TextAlign.right),
      ],
    );
  }
}

class _PoItemDesktopRow extends StatelessWidget {
  const _PoItemDesktopRow({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final ordered = (item['quantity'] as num?)?.toDouble() ?? 0;
    final received = (item['received_quantity'] as num?)?.toDouble() ?? 0;
    final remaining = (ordered - received).clamp(0, double.infinity);
    final productName = item['product']?['name']?.toString() ??
        'Product #${item['product_id']}';
    final sku = item['product']?['sku']?.toString() ?? '';
    final barcode = item['barcode_id']?.toString() ?? '';
    final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          ProfessionalBodyCell(
            label: productName,
            secondary: [
              if (sku.trim().isNotEmpty) 'SKU: $sku',
              if (barcode.trim().isNotEmpty) 'Barcode #$barcode',
            ].join(' • '),
            flex: 5,
            secondaryMaxLines: 2,
          ),
          const SizedBox(width: 10),
          ProfessionalBodyCell(
            label: ordered.toStringAsFixed(2),
            flex: 2,
            textAlign: TextAlign.right,
          ),
          const SizedBox(width: 10),
          ProfessionalBodyCell(
            label: received.toStringAsFixed(2),
            flex: 2,
            textAlign: TextAlign.right,
          ),
          const SizedBox(width: 10),
          ProfessionalBodyCell(
            label: remaining.toStringAsFixed(2),
            flex: 2,
            emphasize: remaining > 0,
            textAlign: TextAlign.right,
          ),
          const SizedBox(width: 10),
          ProfessionalBodyCell(
            label: unitPrice.toStringAsFixed(2),
            flex: 2,
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

class _PoItemMobileCard extends StatelessWidget {
  const _PoItemMobileCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final ordered = (item['quantity'] as num?)?.toDouble() ?? 0;
    final received = (item['received_quantity'] as num?)?.toDouble() ?? 0;
    final remaining = (ordered - received).clamp(0, double.infinity);
    final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;

    return ProfessionalOverviewCard(
      title: item['product']?['name']?.toString() ??
          'Product #${item['product_id']}',
      icon: Icons.inventory_2_rounded,
      child: ProfessionalFieldGrid(
        fields: [
          ProfessionalFieldGridItem(
            label: 'Ordered Qty',
            value: ordered.toStringAsFixed(2),
          ),
          ProfessionalFieldGridItem(
            label: 'Received Qty',
            value: received.toStringAsFixed(2),
          ),
          ProfessionalFieldGridItem(
            label: 'Remaining Qty',
            value: remaining.toStringAsFixed(2),
          ),
          ProfessionalFieldGridItem(
            label: 'Unit Price',
            value: unitPrice.toStringAsFixed(2),
          ),
        ],
      ),
    );
  }
}
