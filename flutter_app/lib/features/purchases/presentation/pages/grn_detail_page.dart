import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/error_handler.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/desktop_sidebar_toggle_action.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../data/grn_repository.dart';
import '../../data/models.dart';
import 'po_detail_page.dart';

class GoodsReceiptDetailPage extends ConsumerStatefulWidget {
  const GoodsReceiptDetailPage({super.key, required this.goodsReceiptId});

  final int goodsReceiptId;

  @override
  ConsumerState<GoodsReceiptDetailPage> createState() =>
      _GoodsReceiptDetailPageState();
}

class _GoodsReceiptDetailPageState
    extends ConsumerState<GoodsReceiptDetailPage> {
  GoodsReceiptDetailDto? _detail;
  List<PurchaseCostAdjustmentDto> _addons = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(grnRepositoryProvider);
      final detail = await repo.getGoodsReceipt(widget.goodsReceiptId);
      final addons = await repo.getGoodsReceiptAddons(widget.goodsReceiptId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _addons = addons;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _receivedQty =>
      _detail?.items.fold<double>(
        0,
        (sum, item) => sum + item.receivedQuantity,
      ) ??
      0;

  double get _itemsTotal =>
      _detail?.items.fold<double>(
        0,
        (sum, item) => sum + item.lineTotal,
      ) ??
      0;

  double get _addonsTotal => _addons.fold<double>(
        0,
        (sum, addon) => sum + addon.totalAmount,
      );

  @override
  Widget build(BuildContext context) {
    final localePrefs = ref.watch(localePreferencesProvider);
    final showSidebarToggle = AppBreakpoints.isTabletOrDesktop(context);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final detail = _detail;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: showSidebarToggle ? 104 : null,
        leading: showSidebarToggle ? const DesktopSidebarToggleLeading() : null,
        title: Text(detail?.receiptNumber ?? 'Goods Receipt'),
      ),
      body: SafeArea(
        child: _loading && detail == null
            ? const Center(child: CircularProgressIndicator())
            : detail == null
                ? const Center(child: Text('Goods receipt not found'))
                : (isDesktop
                    ? _buildDesktopBody(localePrefs, detail)
                    : _buildMobileBody(localePrefs, detail)),
      ),
    );
  }

  Widget _buildDesktopBody(
    LocalePreferencesState localePrefs,
    GoodsReceiptDetailDto detail,
  ) {
    const gap = 12.0;
    const railWidth = 320.0;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildHeader(detail),
          if (_loading) ...[
            const SizedBox(height: gap),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: gap),
          SizedBox(
            height: 172,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildOverview(localePrefs, detail)),
                const SizedBox(width: gap),
                SizedBox(width: railWidth, child: _buildSummaryRail(detail)),
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
                SizedBox(width: railWidth, child: _buildActionPanel(detail)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody(
    LocalePreferencesState localePrefs,
    GoodsReceiptDetailDto detail,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(detail),
        if (_loading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 12),
        _buildOverview(localePrefs, detail),
        const SizedBox(height: 12),
        _buildActionPanel(detail),
        const SizedBox(height: 12),
        _buildItemsSection(),
        if (_addons.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildAddonsSection(),
        ],
        const SizedBox(height: 12),
        _buildSummaryRail(detail),
      ],
    );
  }

  Widget _buildHeader(GoodsReceiptDetailDto detail) {
    return ProfessionalDocumentHeader(
      title: detail.receiptNumber,
      subtitle:
          'Goods receipt review keeps the source PO, item totals, and landed-cost adjustments visible for inventory control.',
      badges: [
        const ProfessionalBadge(
          label: 'Goods Receipt',
          backgroundColor: Color(0xFFE8F3EC),
          foregroundColor: Color(0xFF255C35),
        ),
        if ((detail.supplierName ?? '').trim().isNotEmpty)
          ProfessionalBadge(label: detail.supplierName!),
        if (detail.purchaseId != null)
          const ProfessionalBadge(
            label: 'Linked PO',
            backgroundColor: Color(0xFFEAF1F8),
            foregroundColor: Color(0xFF23415F),
          ),
      ],
    );
  }

  Widget _buildOverview(
    LocalePreferencesState localePrefs,
    GoodsReceiptDetailDto detail,
  ) {
    return ProfessionalOverviewCard(
      title: 'Receipt Overview',
      icon: Icons.receipt_long_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              ProfessionalMetaCell(
                label: 'Receipt Number',
                value: detail.receiptNumber,
              ),
              ProfessionalMetaCell(
                label: 'Received Date',
                value: AppDateTime.formatDate(
                  context,
                  localePrefs,
                  detail.receivedDate,
                ),
              ),
              ProfessionalMetaCell(
                label: 'Supplier',
                value: (detail.supplierName ?? '').trim().isEmpty
                    ? 'Not available'
                    : detail.supplierName!,
              ),
              ProfessionalMetaCell(
                label: 'Source PO',
                value: detail.purchaseId == null
                    ? 'Standalone receipt'
                    : 'Purchase #${detail.purchaseId}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          ProfessionalFieldGrid(
            fields: [
              ProfessionalFieldGridItem(
                label: 'Posting Rule',
                value:
                    'Inventory is already received. Review line values and landed-cost add-ons together.',
                maxLines: 2,
              ),
              ProfessionalFieldGridItem(
                label: 'Adjustment Count',
                value: '${_addons.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection({bool desktopLayout = false}) {
    return ProfessionalSectionCard(
      title: 'Received Items',
      subtitle:
          'Review quantities, rates, and final line totals for the goods receipt.',
      expandChild: desktopLayout,
      child: _detail!.items.isEmpty
          ? const Center(
              child: ProfessionalDocumentEmptyState(
                title: 'No received lines',
                message: 'This goods receipt does not contain item lines.',
              ),
            )
          : desktopLayout
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _GrnItemsHeader(),
                    const SizedBox(height: 10),
                    for (int i = 0; i < _detail!.items.length; i++) ...[
                      _GrnItemDesktopRow(item: _detail!.items[i]),
                      if (i < _detail!.items.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                )
              : Column(
                  children: [
                    for (final item in _detail!.items) ...[
                      _GrnItemMobileCard(item: item),
                      if (item != _detail!.items.last)
                        const SizedBox(height: 10),
                    ],
                    if (_addons.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildAddonsSection(),
                    ],
                  ],
                ),
    );
  }

  Widget _buildAddonsSection() {
    return ProfessionalSectionCard(
      title: 'Add-ons',
      subtitle:
          'Header or item adjustments posted with this receipt stay visible for landed-cost review.',
      child: _addons.isEmpty
          ? const ProfessionalDocumentEmptyState(
              title: 'No add-ons',
              message: 'No landed-cost or income adjustments were posted.',
            )
          : Column(
              children: [
                for (final addon in _addons) ...[
                  PurchaseDocumentAddonCard(addon: addon),
                  if (addon != _addons.last) const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  Widget _buildSummaryRail(GoodsReceiptDetailDto detail) {
    return ProfessionalSummaryCard(
      title: 'Receipt Summary',
      expandContent: AppBreakpoints.isDesktop(context),
      rows: [
        (
          label: 'Line Count',
          value: '${detail.items.length}',
          emphasize: false,
        ),
        (
          label: 'Received Qty',
          value: _receivedQty.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: 'Items Total',
          value: _itemsTotal.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: 'Add-ons Total',
          value: _addonsTotal.toStringAsFixed(2),
          emphasize: true,
        ),
      ],
      footer: Text(
        'Net posted value: ${(_itemsTotal + _addonsTotal).toStringAsFixed(2)}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }

  Widget _buildActionPanel(GoodsReceiptDetailDto detail) {
    return ProfessionalSectionCard(
      title: 'Follow-up Actions',
      subtitle:
          'Open the linked purchase order when the warehouse team needs the full source document context.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: detail.purchaseId == null
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PoDetailPage(
                          purchaseId: detail.purchaseId!,
                        ),
                      ),
                    ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Open Linked Purchase Order'),
            style: professionalCompactButtonStyle(context, outlined: true),
          ),
          const SizedBox(height: 12),
          ProfessionalFieldGrid(
            fields: [
              ProfessionalFieldGridItem(
                label: 'Receipt Type',
                value: detail.purchaseId == null
                    ? 'Standalone GRN'
                    : 'PO-backed receipt',
              ),
              ProfessionalFieldGridItem(
                label: 'Add-ons Posted',
                value: '${_addons.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GrnItemsHeader extends StatelessWidget {
  const _GrnItemsHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        ProfessionalHeaderCell(label: 'Product', flex: 5),
        SizedBox(width: 10),
        ProfessionalHeaderCell(
          label: 'Quantity',
          flex: 2,
          textAlign: TextAlign.right,
        ),
        SizedBox(width: 10),
        ProfessionalHeaderCell(
          label: 'Unit Price',
          flex: 2,
          textAlign: TextAlign.right,
        ),
        SizedBox(width: 10),
        ProfessionalHeaderCell(
          label: 'Line Total',
          flex: 2,
          textAlign: TextAlign.right,
        ),
      ],
    );
  }
}

class _GrnItemDesktopRow extends StatelessWidget {
  const _GrnItemDesktopRow({required this.item});

  final GoodsReceiptItemDto item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          ProfessionalBodyCell(
            label: item.productName ?? 'Product #${item.productId}',
            secondary: [
              if ((item.sku ?? '').trim().isNotEmpty) 'SKU: ${item.sku}',
              if ((item.barcodeId ?? 0) > 0) 'Barcode #${item.barcodeId}',
            ].join(' • '),
            flex: 5,
            secondaryMaxLines: 2,
          ),
          const SizedBox(width: 10),
          ProfessionalBodyCell(
            label: item.receivedQuantity.toStringAsFixed(2),
            flex: 2,
            textAlign: TextAlign.right,
          ),
          const SizedBox(width: 10),
          ProfessionalBodyCell(
            label: item.unitPrice.toStringAsFixed(2),
            flex: 2,
            textAlign: TextAlign.right,
          ),
          const SizedBox(width: 10),
          ProfessionalBodyCell(
            label: item.lineTotal.toStringAsFixed(2),
            flex: 2,
            emphasize: true,
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

class _GrnItemMobileCard extends StatelessWidget {
  const _GrnItemMobileCard({required this.item});

  final GoodsReceiptItemDto item;

  @override
  Widget build(BuildContext context) {
    return ProfessionalOverviewCard(
      title: item.productName ?? 'Product #${item.productId}',
      icon: Icons.inventory_2_rounded,
      child: ProfessionalFieldGrid(
        fields: [
          ProfessionalFieldGridItem(
            label: 'Quantity',
            value: item.receivedQuantity.toStringAsFixed(2),
          ),
          ProfessionalFieldGridItem(
            label: 'Unit Price',
            value: item.unitPrice.toStringAsFixed(2),
          ),
          ProfessionalFieldGridItem(
            label: 'Line Total',
            value: item.lineTotal.toStringAsFixed(2),
          ),
          ProfessionalFieldGridItem(
            label: 'SKU',
            value: (item.sku ?? '').trim().isEmpty ? 'Not set' : item.sku!,
          ),
        ],
      ),
    );
  }
}

class PurchaseDocumentAddonCard extends StatelessWidget {
  const PurchaseDocumentAddonCard({super.key, required this.addon});

  final PurchaseCostAdjustmentDto addon;

  @override
  Widget build(BuildContext context) {
    return ProfessionalOverviewCard(
      title: addon.adjustmentNumber,
      icon: Icons.request_quote_rounded,
      child: ProfessionalFieldGrid(
        fields: [
          ProfessionalFieldGridItem(
            label: 'Type',
            value: addon.adjustmentType.replaceAll('_', ' '),
          ),
          ProfessionalFieldGridItem(
            label: 'Total Amount',
            value: addon.totalAmount.toStringAsFixed(2),
          ),
          ProfessionalFieldGridItem(
            label: 'Reference',
            value: (addon.referenceNumber ?? '').trim().isEmpty
                ? 'Not set'
                : addon.referenceNumber!,
          ),
          ProfessionalFieldGridItem(
            label: 'Notes',
            value:
                (addon.notes ?? '').trim().isEmpty ? 'No notes' : addon.notes!,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
