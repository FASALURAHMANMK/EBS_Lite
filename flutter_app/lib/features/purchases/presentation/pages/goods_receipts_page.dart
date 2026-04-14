import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/error_handler.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/desktop_sidebar_toggle_action.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../data/grn_repository.dart';
import '../../data/models.dart';
import '../../data/purchases_repository.dart';
import '../widgets/purchase_document_widgets.dart';
import 'grn_detail_page.dart';
import 'grn_form_page.dart';
import 'purchase_receipt_page.dart';

class GoodsReceiptsPage extends ConsumerStatefulWidget {
  const GoodsReceiptsPage({super.key});

  @override
  ConsumerState<GoodsReceiptsPage> createState() => _GoodsReceiptsPageState();
}

class _GoodsReceiptsPageState extends ConsumerState<GoodsReceiptsPage> {
  final _search = TextEditingController();
  bool _loading = true;
  bool _detailLoading = false;
  List<GoodsReceiptDto> _list = const [];
  GoodsReceiptDetailDto? _selectedDetail;
  List<PurchaseCostAdjustmentDto> _selectedAddons = const [];
  Object? _detailError;
  int? _selectedReceiptId;
  int _detailToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({int? preferredReceiptId}) async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(grnRepositoryProvider);
      final list = await repo.getGoodsReceipts(
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      );
      if (!mounted) return;
      setState(() => _list = list);
      await _syncSelection(
        list,
        preferredReceiptId: preferredReceiptId,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncSelection(
    List<GoodsReceiptDto> visibleRows, {
    int? preferredReceiptId,
  }) async {
    if (!AppBreakpoints.isDesktop(context)) return;
    if (visibleRows.isEmpty) {
      if (!mounted) return;
      setState(() {
        _selectedReceiptId = null;
        _selectedDetail = null;
        _selectedAddons = const [];
        _detailError = null;
        _detailLoading = false;
      });
      return;
    }
    final preferredMatch = preferredReceiptId == null
        ? const <GoodsReceiptDto>[]
        : visibleRows
            .where((row) => row.goodsReceiptId == preferredReceiptId)
            .toList(growable: false);
    final selectedMatch = visibleRows
        .where((row) => row.goodsReceiptId == _selectedReceiptId)
        .toList(growable: false);
    final nextId = preferredMatch.isNotEmpty
        ? preferredMatch.first.goodsReceiptId
        : selectedMatch.isNotEmpty
            ? selectedMatch.first.goodsReceiptId
            : visibleRows.first.goodsReceiptId;
    if (nextId != _selectedReceiptId) {
      await _selectReceipt(nextId);
    }
  }

  Future<void> _selectReceipt(int goodsReceiptId) async {
    final token = ++_detailToken;
    setState(() {
      _selectedReceiptId = goodsReceiptId;
      _selectedDetail = null;
      _selectedAddons = const [];
      _detailError = null;
      _detailLoading = true;
    });
    try {
      final repo = ref.read(grnRepositoryProvider);
      final detail = await repo.getGoodsReceipt(goodsReceiptId);
      final addons = await repo.getGoodsReceiptAddons(goodsReceiptId);
      if (!mounted || token != _detailToken) return;
      setState(() {
        _selectedDetail = detail;
        _selectedAddons = addons;
        _detailLoading = false;
      });
    } catch (error) {
      if (!mounted || token != _detailToken) return;
      setState(() {
        _detailError = error;
        _detailLoading = false;
      });
    }
  }

  Future<void> _openCreateDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Goods Receipt'),
        content: const Text('Choose entry type:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'po'),
            child: const Text('With PO'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'no_po'),
            child: const Text('Without PO'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'po') {
      final picked = await _pickPO();
      if (!mounted) return;
      if (picked != null) {
        final result =
            await Navigator.of(context).push<GoodsReceiptWorkflowResult>(
          MaterialPageRoute(
            builder: (_) => PurchaseReceiptPage(purchaseId: picked),
          ),
        );
        await _handleCreateResult(result);
      }
      return;
    }
    final created =
        await Navigator.of(context).push<GoodsReceiptWorkflowResult>(
      MaterialPageRoute(builder: (_) => const GrnFormPage()),
    );
    await _handleCreateResult(created);
  }

  Future<void> _handleCreateResult(GoodsReceiptWorkflowResult? result) async {
    if (result == null) return;
    if (result.goodsReceiptId != null && _search.text.trim().isNotEmpty) {
      setState(_search.clear);
    }
    await _load(preferredReceiptId: result.goodsReceiptId);
    if (!mounted || result.queued || result.goodsReceiptId == null) {
      return;
    }
    if (AppBreakpoints.isDesktop(context)) {
      await _selectReceipt(result.goodsReceiptId!);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GoodsReceiptDetailPage(
          goodsReceiptId: result.goodsReceiptId!,
        ),
      ),
    );
    await _load(preferredReceiptId: result.goodsReceiptId);
  }

  Future<int?> _pickPO() async {
    final repo = ref.read(purchasesRepositoryProvider);
    List<Map<String, dynamic>> list = [];
    try {
      final pending = await repo.getPendingOrders();
      list = pending
          .where((row) => (row['status'] ?? '') == 'PARTIALLY_RECEIVED')
          .toList();
    } catch (_) {}
    try {
      final approved = await repo.getOrders(status: 'APPROVED');
      final ids = list.map((row) => row['purchase_id'] as int).toSet();
      for (final row in approved) {
        final id = row['purchase_id'] as int?;
        if (id != null && !ids.contains(id)) {
          list.add(row);
          ids.add(id);
        }
      }
    } catch (_) {}

    int? selected = list.isNotEmpty ? list.first['purchase_id'] as int? : null;
    if (!mounted) return null;
    return showDialog<int?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Select Purchase Order'),
          content: SizedBox(
            width: 720,
            child: list.isEmpty
                ? const Text('No approved or partially received orders')
                : SizedBox(
                    height: 360,
                    child: RadioGroup<int>(
                      groupValue: selected,
                      onChanged: (value) => setInner(() => selected = value),
                      child: ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final item = list[index];
                          return RadioListTile<int>(
                            value: item['purchase_id'] as int,
                            title:
                                Text(item['purchase_number']?.toString() ?? ''),
                            subtitle: Text(
                              (item['supplier']?['name'] ??
                                      item['supplier_name'] ??
                                      '')
                                  .toString(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Select'),
            ),
          ],
        ),
      ),
    );
  }

  List<GoodsReceiptDto> _filteredItems() {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _list;
    return _list.where((receipt) {
      return receipt.receiptNumber.toLowerCase().contains(q) ||
          (receipt.supplierName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final localePrefs = ref.watch(localePreferencesProvider);
    final showSidebarToggle = AppBreakpoints.isTabletOrDesktop(context);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final filtered = _filteredItems();
    if (isDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncSelection(filtered);
        }
      });
    }

    final linkedPoCount =
        _list.where((receipt) => receipt.purchaseId != null).length;
    final standaloneCount = _list.length - linkedPoCount;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: showSidebarToggle ? 104 : null,
        leading: showSidebarToggle ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Goods Receipt Notes'),
        actions: [
          IconButton(
            tooltip: 'Create',
            icon: const Icon(Icons.add_rounded),
            onPressed: _openCreateDialog,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: isDesktop
            ? _buildDesktopBody(
                localePrefs,
                filtered,
                linkedPoCount,
                standaloneCount,
              )
            : _buildMobileBody(
                localePrefs,
                filtered,
                linkedPoCount,
                standaloneCount,
              ),
      ),
    );
  }

  Widget _buildDesktopBody(
    LocalePreferencesState localePrefs,
    List<GoodsReceiptDto> filtered,
    int linkedPoCount,
    int standaloneCount,
  ) {
    const gap = 12.0;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ProfessionalDocumentHeader(
            title: 'Goods Receipt Workbench',
            subtitle:
                'Desktop users can search receipts, review posted inventory, and jump into the next PO-backed or standalone GRN workflow.',
            badges: [
              ProfessionalBadge(label: '${filtered.length} Visible'),
              ProfessionalBadge(
                label: '$linkedPoCount PO-backed',
                backgroundColor: const Color(0xFFEAF1F8),
                foregroundColor: const Color(0xFF23415F),
              ),
            ],
          ),
          const SizedBox(height: gap),
          Row(
            children: [
              Expanded(child: _buildToolbar()),
              const SizedBox(width: gap),
              SizedBox(
                width: 220,
                child: FilledButton.icon(
                  onPressed: _openCreateDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Goods Receipt'),
                  style: professionalCompactButtonStyle(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: gap),
          Row(
            children: [
              Expanded(
                child: PurchaseDocumentMetricCard(
                  label: 'Visible GRNs',
                  value: '${filtered.length}',
                  subtitle: 'Current search result',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: PurchaseDocumentMetricCard(
                  label: 'PO-backed',
                  value: '$linkedPoCount',
                  subtitle: 'Recorded from purchase orders',
                  icon: Icons.description_outlined,
                  tint: const Color(0xFFEAF1F8),
                  foreground: const Color(0xFF23415F),
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: PurchaseDocumentMetricCard(
                  label: 'Standalone',
                  value: '$standaloneCount',
                  subtitle: 'Direct GRN creation path',
                  icon: Icons.inventory_2_outlined,
                  tint: const Color(0xFFE8F3EC),
                  foreground: const Color(0xFF255C35),
                ),
              ),
            ],
          ),
          const SizedBox(height: gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: ProfessionalSectionCard(
                    title: 'Goods Receipts',
                    subtitle:
                        'Select a receipt to review quantities, totals, and any landed-cost add-ons.',
                    expandChild: true,
                    child: filtered.isEmpty
                        ? AppEmptyView(
                            title: 'No goods receipts',
                            message:
                                'Create a goods receipt or adjust the search to review posted receipts.',
                            onRetry: () => _load(),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (int index = 0; index < filtered.length; index++) ...[
                                _buildReceiptCard(filtered[index], localePrefs),
                                if (index < filtered.length - 1)
                                  const SizedBox(height: 10),
                              ],
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: gap),
                Expanded(
                  flex: 4,
                  child: _buildDetailPreview(localePrefs),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody(
    LocalePreferencesState localePrefs,
    List<GoodsReceiptDto> filtered,
    int linkedPoCount,
    int standaloneCount,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ProfessionalDocumentHeader(
          title: 'Goods Receipts',
          subtitle:
              'Mobile keeps receipt review stacked: search, review, and then open the full GRN detail.',
          badges: [
            ProfessionalBadge(label: '${filtered.length} Visible'),
          ],
        ),
        const SizedBox(height: 12),
        _buildToolbar(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PurchaseDocumentMetricCard(
                label: 'PO-backed',
                value: '$linkedPoCount',
                icon: Icons.description_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PurchaseDocumentMetricCard(
                label: 'Standalone',
                value: '$standaloneCount',
                icon: Icons.inventory_2_outlined,
                tint: const Color(0xFFE8F3EC),
                foreground: const Color(0xFF255C35),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _openCreateDialog,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create Goods Receipt'),
        ),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (filtered.isEmpty)
          AppEmptyView(
            title: 'No goods receipts',
            message:
                'Create a goods receipt or adjust the search to review posted receipts.',
            onRetry: () => _load(),
          )
        else
          for (final receipt in filtered) ...[
            PurchaseDocumentListCard(
              title: receipt.receiptNumber,
              subtitle: [
                if ((receipt.supplierName ?? '').trim().isNotEmpty)
                  receipt.supplierName!,
                AppDateTime.formatDate(
                  context,
                  localePrefs,
                  receipt.receivedDate,
                ),
              ].join(' • '),
              badges: [
                const ProfessionalBadge(
                  label: 'Posted',
                  backgroundColor: Color(0xFFE8F3EC),
                  foregroundColor: Color(0xFF255C35),
                ),
                if (receipt.purchaseId != null)
                  const ProfessionalBadge(
                    label: 'Linked PO',
                    backgroundColor: Color(0xFFEAF1F8),
                    foregroundColor: Color(0xFF23415F),
                  ),
              ],
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GoodsReceiptDetailPage(
                      goodsReceiptId: receipt.goodsReceiptId,
                    ),
                  ),
                );
                await _load();
              },
            ),
            if (receipt != filtered.last) const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildToolbar() {
    return ProfessionalSectionCard(
      title: 'Filters',
      subtitle:
          'Search by receipt number or supplier and refresh the workbench without leaving the page.',
      child: Column(
        children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by GRN # or supplier',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
                onPressed: () => _load(),
              ),
            ),
          ),
          if (_loading) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    );
  }

  Widget _buildReceiptCard(
    GoodsReceiptDto receipt,
    LocalePreferencesState localePrefs,
  ) {
    return PurchaseDocumentListCard(
      title: receipt.receiptNumber,
      subtitle: [
        if ((receipt.supplierName ?? '').trim().isNotEmpty)
          receipt.supplierName!,
        AppDateTime.formatDate(context, localePrefs, receipt.receivedDate),
      ].join(' • '),
      selected: receipt.goodsReceiptId == _selectedReceiptId,
      badges: [
        const ProfessionalBadge(
          label: 'Posted',
          backgroundColor: Color(0xFFE8F3EC),
          foregroundColor: Color(0xFF255C35),
        ),
        if (receipt.purchaseId != null)
          const ProfessionalBadge(
            label: 'Linked PO',
            backgroundColor: Color(0xFFEAF1F8),
            foregroundColor: Color(0xFF23415F),
          ),
      ],
      trailing: IconButton(
        tooltip: 'Open detail',
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  GoodsReceiptDetailPage(goodsReceiptId: receipt.goodsReceiptId),
            ),
          );
          await _load();
        },
        icon: const Icon(Icons.open_in_new_rounded),
      ),
      onTap: () => _selectReceipt(receipt.goodsReceiptId),
    );
  }

  Widget _buildLineItemCard(GoodsReceiptItemDto item) {
    return PurchaseDocumentListCard(
      title: item.productName ?? 'Product #${item.productId}',
      subtitle:
          'Qty ${item.receivedQuantity.toStringAsFixed(2)} • Unit ${item.unitPrice.toStringAsFixed(2)} • Total ${item.lineTotal.toStringAsFixed(2)}',
      badges: [
        if ((item.sku ?? '').trim().isNotEmpty)
          ProfessionalBadge(label: item.sku!),
      ],
    );
  }

  Widget _buildDetailPreview(LocalePreferencesState localePrefs) {
    if (_detailLoading) {
      return const ProfessionalSectionCard(
        title: 'GRN Preview',
        expandChild: true,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_detailError != null) {
      return ProfessionalSectionCard(
        title: 'GRN Preview',
        child: AppEmptyView(
          title: 'Preview unavailable',
          message: ErrorHandler.message(_detailError!),
          onRetry: () {
            final receiptId = _selectedReceiptId;
            if (receiptId != null) {
              _selectReceipt(receiptId);
            }
          },
        ),
      );
    }

    final detail = _selectedDetail;
    if (detail == null) {
      return const ProfessionalSectionCard(
        title: 'GRN Preview',
        child: ProfessionalDocumentEmptyState(
          title: 'Select a goods receipt',
          message:
              'Choose a posted GRN from the left pane to review quantities and add-ons.',
        ),
      );
    }

    final receivedQty = detail.items.fold<double>(
      0,
      (sum, item) => sum + item.receivedQuantity,
    );
    final totalValue = detail.items.fold<double>(
      0,
      (sum, item) => sum + item.lineTotal,
    );
    final addonsTotal = _selectedAddons.fold<double>(
      0,
      (sum, addon) => sum + addon.totalAmount,
    );

    final items = detail.items;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfessionalDocumentHeader(
            title: detail.receiptNumber,
            subtitle:
                'Preview received quantities, source linkage, and posted add-ons before opening the full GRN detail page.',
            badges: [
              const ProfessionalBadge(
                label: 'Posted',
              backgroundColor: Color(0xFFE8F3EC),
              foregroundColor: Color(0xFF255C35),
            ),
            if ((detail.supplierName ?? '').trim().isNotEmpty)
              ProfessionalBadge(label: detail.supplierName!),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                    ProfessionalOverviewCard(
                      title: 'Overview',
                      icon: Icons.receipt_long_rounded,
                      child: ProfessionalFieldGrid(
                        fields: [
                          ProfessionalFieldGridItem(
                            label: 'Supplier',
                            value: (detail.supplierName ?? '').trim().isEmpty
                                ? 'Not available'
                                : detail.supplierName!,
                          ),
                          ProfessionalFieldGridItem(
                            label: 'Received Date',
                            value: AppDateTime.formatDate(
                              context,
                              localePrefs,
                              detail.receivedDate,
                            ),
                          ),
                          ProfessionalFieldGridItem(
                            label: 'Source PO',
                            value: detail.purchaseId == null
                                ? 'Standalone receipt'
                                : 'Purchase #${detail.purchaseId}',
                          ),
                          ProfessionalFieldGridItem(
                            label: 'Add-ons',
                            value: '${_selectedAddons.length}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ProfessionalSectionCard(
                        title: 'Line Snapshot',
                        subtitle:
                            'The first few posted lines stay visible for quick warehouse review.',
                        expandChild: true,
                        child: items.isEmpty
                            ? const Center(
                                child: ProfessionalDocumentEmptyState(
                                  title: 'No lines available',
                                  message:
                                      'This goods receipt does not contain any lines to preview.',
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (int index = 0;
                                      index <
                                          (detail.items.length > 5
                                              ? 5
                                              : detail.items.length);
                                      index++) ...[
                                    _buildLineItemCard(detail.items[index]),
                                    if (index <
                                        (detail.items.length > 5
                                            ? 5
                                            : detail.items.length) -
                                            1)
                                      const SizedBox(height: 10),
                                  ],
                                ],
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProfessionalSummaryCard(
                      title: 'GRN Summary',
                      expandContent: true,
                      rows: [
                        (
                          label: 'Line Count',
                          value: '${detail.items.length}',
                          emphasize: false,
                        ),
                        (
                          label: 'Received Qty',
                          value: receivedQty.toStringAsFixed(2),
                          emphasize: false,
                        ),
                        (
                          label: 'Items Total',
                          value: totalValue.toStringAsFixed(2),
                          emphasize: false,
                        ),
                        (
                          label: 'Add-ons Total',
                          value: addonsTotal.toStringAsFixed(2),
                          emphasize: true,
                        ),
                      ],
                      footer: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GoodsReceiptDetailPage(
                                    goodsReceiptId: detail.goodsReceiptId,
                                  ),
                                ),
                              );
                              await _load();
                            },
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Open Full Detail'),
                            style: professionalCompactButtonStyle(
                              context,
                              outlined: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
