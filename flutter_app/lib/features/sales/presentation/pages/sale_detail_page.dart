import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/error_handler.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/desktop_sidebar_toggle_action.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../../pos/data/models.dart';
import '../../../pos/data/pos_repository.dart';
import '../utils/invoice_actions.dart';
import '../widgets/sales_workbench_widgets.dart';
import 'b2b_invoice_form_page.dart';

class SaleDetailPage extends ConsumerStatefulWidget {
  const SaleDetailPage({super.key, required this.saleId});

  final int saleId;

  @override
  ConsumerState<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends ConsumerState<SaleDetailPage> {
  SaleDto? _sale;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sale =
          await ref.read(posRepositoryProvider).getSaleById(widget.saleId);
      if (!mounted) return;
      setState(() => _sale = sale);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = ErrorHandler.message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canEditInvoice {
    final sale = _sale;
    if (sale == null) return false;
    return sale.isB2B &&
        !sale.isRefundInvoice &&
        !sale.isFullyRefunded &&
        !sale.isPartiallyRefunded;
  }

  Future<void> _openEditInvoice() async {
    final sale = _sale;
    if (sale == null) return;
    final result = await Navigator.of(context).push<B2BInvoiceWorkflowResult>(
      MaterialPageRoute(
        builder: (_) => B2BInvoiceFormPage(
          sale: sale,
          returnResultOnSave: true,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      await _load();
    }
  }

  String _formatDateTime(
    LocalePreferencesState localePrefs,
    DateTime? value, {
    String fallback = 'Not available',
  }) {
    return AppDateTime.formatFlexibleDate(
      context,
      localePrefs,
      value?.toIso8601String(),
      fallback: fallback,
    );
  }

  Widget _buildHeader(SaleDto sale) {
    final subtitle = sale.isRefundInvoice
        ? 'Refund invoice review keeps source references, payment posture, and line-level impacts visible before printing or sharing.'
        : 'Review customer, payment, and line-level totals from the same document shell used by the Sales invoice workbench.';

    return ProfessionalDocumentHeader(
      title: sale.saleNumber.isEmpty ? 'Sale #${sale.saleId}' : sale.saleNumber,
      subtitle: subtitle,
      badges: [
        SalesTransactionTypeChip(
          transactionType: sale.isB2B ? 'B2B' : 'Retail',
        ),
        SalesStatusChip(
            status: (sale.status ?? sale.posStatus ?? 'Sale').trim()),
        if (sale.isFullyRefunded)
          const SalesRefundStateChip(label: 'Fully refunded'),
        if (sale.isPartiallyRefunded)
          const SalesRefundStateChip(label: 'Partially refunded'),
        if (sale.isRefundInvoice)
          const ProfessionalBadge(
            label: 'Refund Invoice',
            backgroundColor: Color(0xFFFFF1D6),
            foregroundColor: Color(0xFF8A5200),
          ),
      ],
    );
  }

  Widget _buildOverview(
    SaleDto sale,
    LocalePreferencesState localePrefs,
  ) {
    return ProfessionalOverviewCard(
      title: 'Invoice Overview',
      icon: Icons.receipt_long_rounded,
      child: ProfessionalFieldGrid(
        fields: [
          ProfessionalFieldGridItem(
            label: 'Customer',
            value: (sale.customerName ?? '').trim().isEmpty
                ? 'Walk-in customer'
                : sale.customerName!,
          ),
          ProfessionalFieldGridItem(
            label: 'Location',
            value: (sale.locationName ?? '').trim().isEmpty
                ? 'Location #${sale.locationId}'
                : sale.locationName!,
          ),
          ProfessionalFieldGridItem(
            label: 'Sale Date',
            value: _formatDateTime(localePrefs, sale.saleDate),
          ),
          ProfessionalFieldGridItem(
            label: 'Payment Method',
            value: (sale.paymentMethodName ?? '').trim().isEmpty
                ? 'Not recorded'
                : sale.paymentMethodName!,
          ),
          ProfessionalFieldGridItem(
            label: 'Created By',
            value: (sale.createdByName ?? '').trim().isEmpty
                ? 'User #${sale.createdBy}'
                : sale.createdByName!,
          ),
          ProfessionalFieldGridItem(
            label: 'Created At',
            value: _formatDateTime(localePrefs, sale.createdAt),
          ),
          ProfessionalFieldGridItem(
            label: 'Updated At',
            value: _formatDateTime(localePrefs, sale.updatedAt),
          ),
          ProfessionalFieldGridItem(
            label: 'Document State',
            value: [
              if ((sale.status ?? '').trim().isNotEmpty) sale.status!.trim(),
              if ((sale.posStatus ?? '').trim().isNotEmpty)
                sale.posStatus!.trim(),
            ].join(' · '),
          ),
          if ((sale.refundSourceSaleNumber ?? '').trim().isNotEmpty)
            ProfessionalFieldGridItem(
              label:
                  sale.isRefundInvoice ? 'Refund For' : 'Includes Refund From',
              value: sale.refundSourceSaleNumber!,
            ),
        ],
      ),
    );
  }

  Widget _buildSummary(SaleDto sale, bool isDesktop) {
    final totalQty =
        sale.items.fold<double>(0, (sum, item) => sum + item.quantity);
    final balance = sale.totalAmount - sale.paidAmount;

    return ProfessionalSummaryCard(
      title: 'Financial Summary',
      expandContent: isDesktop,
      rows: [
        (
          label: 'Item Count',
          value: sale.items.length.toString(),
          emphasize: false,
        ),
        (
          label: 'Total Qty',
          value: totalQty.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: 'Subtotal',
          value: sale.subtotal.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: 'Tax',
          value: sale.taxAmount.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: 'Discount',
          value: sale.discountAmount.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: 'Paid',
          value: sale.paidAmount.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: balance <= 0 ? 'Settled Balance' : 'Outstanding Balance',
          value: balance.toStringAsFixed(2),
          emphasize: true,
        ),
      ],
      footer: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_canEditInvoice)
            FilledButton.icon(
              onPressed: _openEditInvoice,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit'),
              style: professionalCompactButtonStyle(context),
            ),
          FilledButton.tonalIcon(
            onPressed: () => InvoiceActions(ref: ref, context: context)
                .printSmart(sale.saleId),
            icon: const Icon(Icons.print_rounded),
            label: const Text('Print'),
            style: professionalCompactButtonStyle(context),
          ),
          FilledButton.tonalIcon(
            onPressed: () => InvoiceActions(ref: ref, context: context)
                .shareInvoice(sale.saleId),
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share'),
            style: professionalCompactButtonStyle(context),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(SaleDto sale) {
    if (sale.items.isEmpty) {
      return const ProfessionalSectionCard(
        title: 'Item Lines',
        child: ProfessionalDocumentEmptyState(
          title: 'No item lines',
          message: 'This sale does not contain any invoice items.',
          icon: Icons.inventory_2_outlined,
        ),
      );
    }

    return ProfessionalSectionCard(
      title: 'Item Lines',
      subtitle:
          'Review quantities, unit prices, and any tracked serial or component details before sharing the invoice.',
      child: Column(
        children: [
          for (final item in sale.items) ...[
            ProfessionalOverviewCard(
              title: [
                (item.productName ?? '').trim(),
                (item.variantName ?? '').trim(),
              ].where((value) => value.isNotEmpty).join(' • ').isEmpty
                  ? 'Item'
                  : [
                      (item.productName ?? '').trim(),
                      (item.variantName ?? '').trim(),
                    ].where((value) => value.isNotEmpty).join(' • '),
              icon: Icons.inventory_2_rounded,
              child: ProfessionalFieldGrid(
                fields: [
                  ProfessionalFieldGridItem(
                    label: 'Quantity',
                    value: item.quantity.toStringAsFixed(2),
                  ),
                  ProfessionalFieldGridItem(
                    label: 'Unit Price',
                    value: item.unitPrice.toStringAsFixed(2),
                  ),
                  ProfessionalFieldGridItem(
                    label: 'Discount',
                    value: item.discountAmount.toStringAsFixed(2),
                  ),
                  ProfessionalFieldGridItem(
                    label: 'Line Total',
                    value: (item.lineTotal != 0
                            ? item.lineTotal
                            : ((item.quantity * item.unitPrice) -
                                item.discountAmount))
                        .toStringAsFixed(2),
                  ),
                  if (item.serialNumbers.isNotEmpty)
                    ProfessionalFieldGridItem(
                      label: 'Serials',
                      value: item.serialNumbers.join(', '),
                      maxLines: 3,
                    ),
                  if (item.comboComponentTracking.isNotEmpty)
                    ProfessionalFieldGridItem(
                      label: 'Tracked Components',
                      value: item.comboComponentTracking
                          .map((component) => component.summary(item.quantity))
                          .join(' | '),
                      maxLines: 3,
                    ),
                ],
              ),
            ),
            if (item != sale.items.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(SaleDto sale, LocalePreferencesState localePrefs) {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final notes = (sale.notes ?? '').trim();

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildHeader(sale),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildOverview(sale, localePrefs)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 320,
                    child: _buildSummary(sale, true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  _buildItemsSection(sale),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ProfessionalSectionCard(
                      title: sale.isRefundInvoice ? 'Refund Reason' : 'Notes',
                      child: Text(notes),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(sale),
        const SizedBox(height: 12),
        _buildOverview(sale, localePrefs),
        const SizedBox(height: 12),
        _buildItemsSection(sale),
        const SizedBox(height: 12),
        _buildSummary(sale, false),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          ProfessionalSectionCard(
            title: sale.isRefundInvoice ? 'Refund Reason' : 'Notes',
            child: Text(notes),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localePrefs = ref.watch(localePreferencesProvider);
    final sale = _sale;
    final showSidebarToggle = AppBreakpoints.isTabletOrDesktop(context);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: showSidebarToggle ? 104 : null,
        leading: showSidebarToggle ? const DesktopSidebarToggleLeading() : null,
        title: Text(
          sale?.saleNumber.isNotEmpty == true
              ? sale!.saleNumber
              : 'Sale #${widget.saleId}',
        ),
        actions: [
          if (_canEditInvoice)
            IconButton(
              tooltip: 'Edit invoice',
              icon: const Icon(Icons.edit_rounded),
              onPressed: _openEditInvoice,
            ),
          IconButton(
            tooltip: 'Print invoice',
            icon: const Icon(Icons.print_rounded),
            onPressed: sale == null
                ? null
                : () => InvoiceActions(ref: ref, context: context)
                    .printSmart(sale.saleId),
          ),
          IconButton(
            tooltip: 'Share invoice',
            icon: const Icon(Icons.share_rounded),
            onPressed: sale == null
                ? null
                : () => InvoiceActions(ref: ref, context: context)
                    .shareInvoice(sale.saleId),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _loading && sale == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && sale == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ProfessionalDocumentEmptyState(
                        title: 'Unable to load sale details',
                        message: _error!,
                        actionLabel: 'Retry',
                        onAction: _load,
                        icon: Icons.error_outline_rounded,
                      ),
                    ),
                  )
                : sale == null
                    ? const Center(child: Text('Sale not found'))
                    : _buildBody(sale, localePrefs),
      ),
    );
  }
}
