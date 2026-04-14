import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/error_handler.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/desktop_sidebar_toggle_action.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../data/purchases_repository.dart';
import '../widgets/purchase_document_widgets.dart';
import 'po_detail_page.dart';
import 'po_form_page.dart';
import 'purchase_receipt_page.dart';

class PurchaseOrdersPage extends ConsumerStatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  ConsumerState<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends ConsumerState<PurchaseOrdersPage> {
  final _search = TextEditingController();
  bool _loading = true;
  bool _detailLoading = false;
  List<Map<String, dynamic>> _all = const [];
  Map<String, dynamic>? _selectedDetail;
  Object? _detailError;
  int? _selectedPurchaseId;
  int _detailToken = 0;
  String _filter = 'pending';

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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(purchasesRepositoryProvider);
      List<Map<String, dynamic>> list;
      switch (_filter) {
        case 'received':
          list = await repo.getOrders(status: 'RECEIVED');
          break;
        case 'unapproved':
          list = await repo.getOrders(status: 'PENDING');
          break;
        case 'all':
          list = await repo.getOrders();
          break;
        case 'pending':
        default:
          list = await repo.getPendingOrders();
      }
      if (!mounted) return;
      setState(() => _all = list);
      await _syncSelection(list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncSelection(List<Map<String, dynamic>> visibleRows) async {
    if (!AppBreakpoints.isDesktop(context)) return;
    if (visibleRows.isEmpty) {
      if (!mounted) return;
      setState(() {
        _selectedPurchaseId = null;
        _selectedDetail = null;
        _detailError = null;
        _detailLoading = false;
      });
      return;
    }

    final selectedMatch = visibleRows.where(
      (row) => row['purchase_id'] == _selectedPurchaseId,
    );
    final nextId = (selectedMatch.isNotEmpty
        ? selectedMatch.first
        : visibleRows.first)['purchase_id'] as int?;
    if (nextId != null && nextId != _selectedPurchaseId) {
      await _selectPurchase(nextId);
    }
  }

  Future<void> _selectPurchase(int purchaseId) async {
    final token = ++_detailToken;
    setState(() {
      _selectedPurchaseId = purchaseId;
      _selectedDetail = null;
      _detailError = null;
      _detailLoading = true;
    });

    try {
      final detail =
          await ref.read(purchasesRepositoryProvider).getPurchase(purchaseId);
      if (!mounted || token != _detailToken) return;
      setState(() {
        _selectedDetail = detail;
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

  Future<void> _openCreate() async {
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const PoFormPage()),
    );
    if (id == null) return;
    await _load();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PoDetailPage(purchaseId: id)),
    );
    await _load();
  }

  List<Map<String, dynamic>> _filteredItems() {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((row) {
      final supplier = (row['supplier']?['name'] ?? row['supplier_name'] ?? '')
          .toString()
          .toLowerCase();
      return (row['purchase_number'] ?? '')
              .toString()
              .toLowerCase()
              .contains(q) ||
          supplier.contains(q);
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

    final receivedCount =
        _all.where((row) => (row['status'] ?? '') == 'RECEIVED').length;
    final openCount =
        _all.where((row) => (row['status'] ?? '') != 'RECEIVED').length;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: showSidebarToggle ? 104 : null,
        leading: showSidebarToggle ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Purchase Orders'),
        actions: [
          IconButton(
            tooltip: 'New PO',
            icon: const Icon(Icons.add_rounded),
            onPressed: _openCreate,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: isDesktop
            ? _buildDesktopBody(
                localePrefs,
                filtered,
                openCount,
                receivedCount,
              )
            : _buildMobileBody(
                localePrefs,
                filtered,
                openCount,
                receivedCount,
              ),
      ),
    );
  }

  Widget _buildDesktopBody(
    LocalePreferencesState localePrefs,
    List<Map<String, dynamic>> filtered,
    int openCount,
    int receivedCount,
  ) {
    const gap = 12.0;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ProfessionalDocumentHeader(
            title: 'Purchase Order Workbench',
            subtitle:
                'Desktop operators can search, triage, approve, and open receiving from one dense PO workbench.',
            badges: [
              ProfessionalBadge(label: '${filtered.length} Visible'),
              const ProfessionalBadge(
                label: 'Desktop Workbench',
                backgroundColor: Color(0xFFEAF1F8),
                foregroundColor: Color(0xFF23415F),
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
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Purchase Order'),
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
                  label: 'Visible POs',
                  value: '${filtered.length}',
                  subtitle: 'Current search and filter result',
                  icon: Icons.description_outlined,
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: PurchaseDocumentMetricCard(
                  label: 'Open POs',
                  value: '$openCount',
                  subtitle: 'Pending approval or receiving',
                  icon: Icons.pending_actions_rounded,
                  tint: const Color(0xFFFFF4DD),
                  foreground: const Color(0xFF8A5200),
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: PurchaseDocumentMetricCard(
                  label: 'Received',
                  value: '$receivedCount',
                  subtitle: 'Completed in this list scope',
                  icon: Icons.task_alt_rounded,
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
                    title: 'Purchase Orders',
                    subtitle:
                        'Select a document to preview approval status and receiving readiness.',
                    expandChild: true,
                    child: filtered.isEmpty
                        ? AppEmptyView(
                            title: 'No purchase orders',
                            message:
                                'Adjust the filters or create a new purchase order to begin the workflow.',
                            onRetry: _load,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (int index = 0; index < filtered.length; index++) ...[
                                _buildPurchaseOrderCard(filtered[index], localePrefs),
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
    List<Map<String, dynamic>> filtered,
    int openCount,
    int receivedCount,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ProfessionalDocumentHeader(
          title: 'Purchase Orders',
          subtitle:
              'Mobile keeps the workflow stacked: search, filter, review, then open the full PO detail or create a new one.',
          badges: [
            ProfessionalBadge(label: '${filtered.length} Visible'),
            ProfessionalBadge(
              label: '$openCount Open',
              backgroundColor: const Color(0xFFFFF1D6),
              foregroundColor: const Color(0xFF8A5200),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildToolbar(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PurchaseDocumentMetricCard(
                label: 'Open',
                value: '$openCount',
                icon: Icons.pending_actions_rounded,
                tint: const Color(0xFFFFF4DD),
                foreground: const Color(0xFF8A5200),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PurchaseDocumentMetricCard(
                label: 'Received',
                value: '$receivedCount',
                icon: Icons.task_alt_rounded,
                tint: const Color(0xFFE8F3EC),
                foreground: const Color(0xFF255C35),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _openCreate,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create Purchase Order'),
        ),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (filtered.isEmpty)
          AppEmptyView(
            title: 'No purchase orders',
            message:
                'Adjust the filters or create a new purchase order to begin the workflow.',
            onRetry: _load,
          )
        else
          for (final po in filtered) ...[
            PurchaseDocumentListCard(
              title: po['purchase_number']?.toString() ?? 'Purchase Order',
              subtitle: _subtitleForListRow(context, localePrefs, po),
              badges: [
                purchaseStatusBadge((po['status'] ?? '').toString()),
                if ((po['supplier']?['name'] ?? po['supplier_name'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty)
                  ProfessionalBadge(
                    label: (po['supplier']?['name'] ?? po['supplier_name'])
                        .toString(),
                  ),
              ],
              onTap: () async {
                final purchaseId = po['purchase_id'] as int?;
                if (purchaseId == null) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PoDetailPage(purchaseId: purchaseId),
                  ),
                );
                await _load();
              },
            ),
            if (po != filtered.last) const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildPurchaseOrderCard(
    Map<String, dynamic> po,
    LocalePreferencesState localePrefs,
  ) {
    final purchaseId = po['purchase_id'] as int?;
    return PurchaseDocumentListCard(
      title: po['purchase_number']?.toString() ?? 'Purchase Order',
      subtitle: _subtitleForListRow(context, localePrefs, po),
      selected:
          purchaseId != null && purchaseId == _selectedPurchaseId,
      badges: [
        purchaseStatusBadge((po['status'] ?? '').toString()),
        if ((po['supplier']?['name'] ?? po['supplier_name'] ?? '')
                .toString()
                .trim()
                .isNotEmpty)
          ProfessionalBadge(
            label:
                (po['supplier']?['name'] ?? po['supplier_name']).toString(),
          ),
      ],
      trailing: IconButton(
        tooltip: 'Open detail',
        onPressed: purchaseId == null
            ? null
            : () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PoDetailPage(purchaseId: purchaseId),
                  ),
                );
                await _load();
              },
        icon: const Icon(Icons.open_in_new_rounded),
      ),
      onTap: purchaseId == null ? null : () => _selectPurchase(purchaseId),
    );
  }

  Widget _buildLineItemCard(Map<String, dynamic> item) {
    final ordered =
        (item['quantity'] as num?)?.toDouble() ?? 0;
    final received =
        (item['received_quantity'] as num?)?.toDouble() ?? 0;
    return PurchaseDocumentListCard(
      title: item['product']?['name']?.toString() ??
          'Product #${item['product_id']}',
      subtitle:
          'Ordered ${ordered.toStringAsFixed(2)} • Received ${received.toStringAsFixed(2)} • Unit ${((item['unit_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
      badges: [
        ProfessionalBadge(
          label:
              'Balance ${(ordered - received).clamp(0, double.infinity).toStringAsFixed(2)}',
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return ProfessionalSectionCard(
      title: 'Filters',
      subtitle:
          'Search by number or supplier and keep status chips visible while triaging work.',
      child: Column(
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search by PO number or supplier',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _load,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: _FilterChips(
              value: _filter,
              onChanged: (value) async {
                if (_filter == value) return;
                setState(() => _filter = value);
                await _load();
              },
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

  Widget _buildDetailPreview(LocalePreferencesState localePrefs) {
    if (_detailLoading) {
      return const ProfessionalSectionCard(
        title: 'PO Preview',
        expandChild: true,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_detailError != null) {
      return ProfessionalSectionCard(
        title: 'PO Preview',
        child: AppEmptyView(
          title: 'Preview unavailable',
          message: ErrorHandler.message(_detailError!),
          onRetry: () {
            final purchaseId = _selectedPurchaseId;
            if (purchaseId != null) {
              _selectPurchase(purchaseId);
            }
          },
        ),
      );
    }

    final detail = _selectedDetail;
    if (detail == null) {
      return const ProfessionalSectionCard(
        title: 'PO Preview',
        child: ProfessionalDocumentEmptyState(
          title: 'Select a purchase order',
          message:
              'Choose a PO from the left pane to review supplier, quantities, and next actions.',
        ),
      );
    }

    final items =
        (detail['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    final orderedQty = items.fold<double>(
      0,
      (sum, item) => sum + ((item['quantity'] as num?)?.toDouble() ?? 0),
    );
    final receivedQty = items.fold<double>(
      0,
      (sum, item) =>
          sum + ((item['received_quantity'] as num?)?.toDouble() ?? 0),
    );
    final remainingQty = (orderedQty - receivedQty).clamp(0, double.infinity);
    final totalValue = items.fold<double>(
      0,
      (sum, item) =>
          sum +
          (((item['quantity'] as num?)?.toDouble() ?? 0) *
              ((item['unit_price'] as num?)?.toDouble() ?? 0)),
    );
    final status = (detail['status'] ?? '').toString();
    final canApprove = status != 'APPROVED' &&
        status != 'PARTIALLY_RECEIVED' &&
        status != 'RECEIVED';
    final canReceive = remainingQty > 0 &&
        (status == 'APPROVED' || status == 'PARTIALLY_RECEIVED');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfessionalDocumentHeader(
            title: detail['purchase_number']?.toString() ?? 'Purchase Order',
            subtitle:
                'Preview approval state, supplier context, and receiving readiness before opening the full document.',
            badges: [
              purchaseStatusBadge(status),
              if ((detail['supplier']?['name'] ?? detail['supplier_name'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty)
                ProfessionalBadge(
                  label: (detail['supplier']?['name'] ?? detail['supplier_name'])
                      .toString(),
                ),
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
                      icon: Icons.inventory_2_outlined,
                      child: ProfessionalFieldGrid(
                        fields: [
                          ProfessionalFieldGridItem(
                            label: 'Supplier',
                            value: (detail['supplier']?['name'] ??
                                    detail['supplier_name'] ??
                                    '')
                                .toString(),
                          ),
                          ProfessionalFieldGridItem(
                            label: 'PO Date',
                            value: AppDateTime.formatFlexibleDate(
                              context,
                              localePrefs,
                              detail['purchase_date']?.toString(),
                              fallback: detail['purchase_date']?.toString() ??
                                  'Not available',
                            ),
                          ),
                          ProfessionalFieldGridItem(
                            label: 'Reference',
                            value: (detail['reference_number'] ?? '')
                                    .toString()
                                    .trim()
                                    .isEmpty
                                ? 'Not set'
                                : detail['reference_number'].toString(),
                          ),
                          ProfessionalFieldGridItem(
                            label: 'Notes',
                            value: (detail['notes'] ?? '')
                                    .toString()
                                    .trim()
                                    .isEmpty
                                ? 'No notes'
                                : detail['notes'].toString(),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ProfessionalSectionCard(
                      title: 'Line Snapshot',
                      subtitle:
                          'The first few lines stay visible for quick review from the list workbench.',
                      expandChild: true,
                      child: items.isEmpty
                          ? const Center(
                              child: ProfessionalDocumentEmptyState(
                                title: 'No lines available',
                                message:
                                    'This purchase order does not contain any lines to preview.',
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (int index = 0;
                                    index <
                                        (items.length > 5 ? 5 : items.length);
                                    index++) ...[
                                  _buildLineItemCard(items[index]),
                                  if (index <
                                      (items.length > 5 ? 5 : items.length) - 1)
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
                child: ProfessionalSummaryCard(
                  title: 'Workflow Summary',
                  expandContent: true,
                  rows: [
                    (
                      label: 'Line Count',
                      value: '${items.length}',
                      emphasize: false,
                    ),
                    (
                      label: 'Ordered Qty',
                      value: orderedQty.toStringAsFixed(2),
                      emphasize: false,
                    ),
                    (
                      label: 'Received Qty',
                      value: receivedQty.toStringAsFixed(2),
                      emphasize: false,
                    ),
                    (
                      label: 'Remaining Qty',
                      value: remainingQty.toStringAsFixed(2),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              totalValue.toStringAsFixed(2),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF19324D),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: canReceive
                            ? () async {
                                final purchaseId =
                                    detail['purchase_id'] as int?;
                                if (purchaseId == null) return;
                                final recorded =
                                    await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => PurchaseReceiptPage(
                                      purchaseId: purchaseId,
                                    ),
                                  ),
                                );
                                if (recorded == true) {
                                  await _load();
                                }
                              }
                            : null,
                        icon: const Icon(Icons.call_received_rounded),
                        label: const Text('Receive Goods'),
                        style: professionalCompactButtonStyle(context),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: canApprove
                            ? () async {
                                final purchaseId =
                                    detail['purchase_id'] as int?;
                                if (purchaseId == null) return;
                                try {
                                  await ref
                                      .read(purchasesRepositoryProvider)
                                      .approvePurchaseOrder(purchaseId);
                                  await _load();
                                } catch (error) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          ErrorHandler.message(error),
                                        ),
                                      ),
                                    );
                                }
                              }
                            : null,
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Approve PO'),
                        style: professionalCompactButtonStyle(
                          context,
                          outlined: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final purchaseId = detail['purchase_id'] as int?;
                          if (purchaseId == null) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  PoDetailPage(purchaseId: purchaseId),
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _subtitleForListRow(
    BuildContext context,
    LocalePreferencesState localePrefs,
    Map<String, dynamic> po,
  ) {
    return [
      if ((po['supplier']?['name'] ?? po['supplier_name'] ?? '')
          .toString()
          .trim()
          .isNotEmpty)
        (po['supplier']?['name'] ?? po['supplier_name']).toString(),
      if (po['purchase_date'] != null)
        AppDateTime.formatFlexibleDate(
          context,
          localePrefs,
          po['purchase_date']?.toString(),
          fallback: po['purchase_date'].toString(),
        ),
      if ((po['reference_number'] ?? '').toString().trim().isNotEmpty)
        'Ref ${po['reference_number']}',
    ].join(' • ');
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.value, required this.onChanged});

  final String value;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final items = const <(String, String)>[
      ('pending', 'Pending & Partial'),
      ('unapproved', 'Unapproved'),
      ('received', 'Received'),
      ('all', 'All'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final item in items)
          ChoiceChip(
            label: Text(item.$2),
            selected: value == item.$1,
            onSelected: (selected) => selected ? onChanged(item.$1) : null,
          ),
      ],
    );
  }
}
