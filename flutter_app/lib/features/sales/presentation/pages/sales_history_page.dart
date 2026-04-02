import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/error_handler.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_selection_dialog.dart';
import '../../../pos/controllers/pos_notifier.dart';
import '../../../pos/data/models.dart';
import '../../../pos/data/pos_repository.dart';
import '../../../pos/presentation/pages/pos_page.dart';
import '../../data/sales_repository.dart';
import 'sale_detail_page.dart';
import 'sales_returns_page.dart';
import '../utils/invoice_actions.dart';

class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  ConsumerState<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  bool _loading = true;
  bool _detailLoading = false;
  Map<String, dynamic>? _summaryToday;
  Map<String, dynamic>? _summaryAll;
  List<Map<String, dynamic>> _sales = const [];
  final _search = TextEditingController();
  DateTimeRange? _dateRange;
  List<PosCustomerDto> _selectedCustomers = const [];
  String? _selectedDocumentKey;
  _HistoryDocumentDetail? _selectedDetail;
  Object? _detailError;
  int _detailRequestToken = 0;
  bool _actionBusy = false;

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

  String _toApiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<_HistoryDocument> _buildVisibleDocuments(String query) {
    final merged = _sales.map((row) => _HistoryDocument.sale(row)).toList();

    merged.sort((a, b) => b.sortDate.compareTo(a.sortDate));

    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return merged;
    }
    return merged.where((doc) {
      return doc.number.toLowerCase().contains(normalizedQuery) ||
          doc.customerLabel.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final repo = ref.read(salesRepositoryProvider);
    final now = DateTime.now();
    final todayStr = _toApiDate(now);
    final selectedIds =
        _selectedCustomers.map((e) => e.customerId).toList(growable: false);
    final singleCustomerId = selectedIds.length == 1 ? selectedIds.first : null;

    String fromDate = _toApiDate(now.subtract(const Duration(days: 30)));
    String? toDate;
    final dr = _dateRange;
    if (dr != null) {
      fromDate = _toApiDate(dr.start);
      toDate = _toApiDate(dr.end);
    }

    Map<String, dynamic>? summaryToday = _summaryToday;
    Map<String, dynamic>? summaryAll = _summaryAll;
    List<Map<String, dynamic>> sales = _sales;

    try {
      try {
        summaryToday =
            await repo.getSalesSummary(dateFrom: todayStr, dateTo: todayStr);
      } catch (_) {}

      try {
        summaryAll = await repo.getSalesSummary();
      } catch (_) {}

      try {
        final data = await repo.getSalesHistory(
          dateFrom: fromDate,
          dateTo: toDate,
          customerId: singleCustomerId,
        );
        sales = _filterByCustomers(data, selectedIds);
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() {
          _summaryToday = summaryToday;
          _summaryAll = summaryAll;
          _sales = sales;
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _filterByCustomers(
    List<Map<String, dynamic>> items,
    List<int> selectedIds,
  ) {
    if (selectedIds.isEmpty || selectedIds.length == 1) {
      return items;
    }
    final selectedSet = selectedIds.toSet();
    return items.where((row) {
      final customer = row['customer'];
      final customerId = customer is Map<String, dynamic>
          ? customer['customer_id'] as int?
          : row['customer_id'] as int?;
      return customerId != null && selectedSet.contains(customerId);
    }).toList();
  }

  void _syncDesktopSelection(List<_HistoryDocument> docs) {
    if (!mounted) return;

    if (docs.isEmpty) {
      if (_selectedDocumentKey != null ||
          _selectedDetail != null ||
          _detailError != null) {
        setState(() {
          _selectedDocumentKey = null;
          _selectedDetail = null;
          _detailError = null;
          _detailLoading = false;
        });
      }
      return;
    }

    final selected = docs.where((doc) => doc.key == _selectedDocumentKey);
    final next = selected.isNotEmpty ? selected.first : docs.first;

    if (_selectedDocumentKey != next.key ||
        (_selectedDetail == null && !_detailLoading && _detailError == null)) {
      _selectDocument(next);
    }
  }

  Future<void> _selectDocument(_HistoryDocument doc) async {
    if (_selectedDocumentKey == doc.key &&
        (_detailLoading || _selectedDetail?.document.key == doc.key)) {
      return;
    }

    final requestToken = ++_detailRequestToken;
    setState(() {
      _selectedDocumentKey = doc.key;
      _selectedDetail = null;
      _detailError = null;
      _detailLoading = true;
    });

    try {
      final sale = await ref.read(posRepositoryProvider).getSaleById(doc.id);
      final detail = _HistoryDocumentDetail.fromSale(doc, sale);

      if (!mounted || requestToken != _detailRequestToken) return;
      setState(() {
        _selectedDetail = detail;
        _detailLoading = false;
      });
    } catch (error) {
      if (!mounted || requestToken != _detailRequestToken) return;
      setState(() {
        _detailError = error;
        _detailLoading = false;
      });
    }
  }

  Future<void> _reloadSelection() async {
    final selectedKey = _selectedDocumentKey;
    await _load();
    if (!mounted || selectedKey == null) return;
    final docs = _buildVisibleDocuments(_search.text);
    final match = docs.where((doc) => doc.key == selectedKey);
    if (match.isNotEmpty) {
      await _selectDocument(match.first);
    }
  }

  Future<void> _printSelectedSaleA4() async {
    final sale = _selectedDetail?.sale;
    if (sale == null) return;
    setState(() => _actionBusy = true);
    try {
      await InvoiceActions(ref: ref, context: context).printA4(sale.saleId);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _printSelectedSale80mm() async {
    final sale = _selectedDetail?.sale;
    if (sale == null) return;
    setState(() => _actionBusy = true);
    try {
      await InvoiceActions(ref: ref, context: context)
          .printThermal80(sale.saleId);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _shareSelectedSalePdf() async {
    final sale = _selectedDetail?.sale;
    if (sale == null) return;
    setState(() => _actionBusy = true);
    try {
      await InvoiceActions(ref: ref, context: context)
          .shareInvoice(sale.saleId);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _editSelectedSale() async {
    final sale = _selectedDetail?.sale;
    if (sale == null) return;

    setState(() => _actionBusy = true);
    try {
      ref.read(posNotifierProvider.notifier).loadInvoiceEditSession(sale);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PosPage()),
      );
      if (!mounted) return;
      await _reloadSelection();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(ErrorHandler.message(error))),
        );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _refundSelectedSale() async {
    final sale = _selectedDetail?.sale;
    if (sale == null) return;
    setState(() => _actionBusy = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SaleReturnFormPage(
            initialSaleId: sale.saleId,
            mode: SaleReturnDocumentMode.refundInvoice,
          ),
        ),
      );
      if (!mounted) return;
      await _reloadSelection();
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 3, 1, 1);
    final lastDate = DateTime(now.year + 1, 12, 31);
    final initial = _dateRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: initial,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      await _load();
    }
  }

  Future<void> _pickCustomers() async {
    final result = await showDialog<List<PosCustomerDto>>(
      context: context,
      builder: (context) {
        final repo = ref.read(posRepositoryProvider);
        final selected = _selectedCustomers.map((e) => e.customerId).toSet();
        final controller = TextEditingController();
        List<PosCustomerDto> results = const [];
        bool loading = true;
        bool kickoff = true;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> doSearch(String q) async {
              loading = true;
              setStateDialog(() {});
              try {
                results = await repo.searchCustomers(q);
              } finally {
                loading = false;
                setStateDialog(() {});
              }
            }

            if (kickoff) {
              kickoff = false;
              Future.microtask(() => doSearch(''));
            }

            return AppSelectionDialog(
              title: 'Select Customers',
              maxWidth: 480,
              loading: loading,
              searchField: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Search customers',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search_rounded),
                    onPressed: () => doSearch(controller.text.trim()),
                  ),
                ),
                onChanged: (value) => doSearch(value.trim()),
                onSubmitted: (value) => doSearch(value.trim()),
              ),
              body: results.isEmpty && !loading
                  ? const Center(child: Text('No customers'))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final customer = results[index];
                        final checked = selected.contains(customer.customerId);
                        return CheckboxListTile(
                          value: checked,
                          title: Text(customer.name),
                          subtitle: Text([
                            if ((customer.phone ?? '').isNotEmpty)
                              customer.phone!,
                            if ((customer.email ?? '').isNotEmpty)
                              customer.email!,
                          ].where((value) => value.isNotEmpty).join(' · ')),
                          onChanged: (value) {
                            if (value == true) {
                              selected.add(customer.customerId);
                            } else {
                              selected.remove(customer.customerId);
                            }
                            setStateDialog(() {});
                          },
                        );
                      },
                    ),
              footer: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      selected.clear();
                      setStateDialog(() {});
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final mapById = {
                      for (final result in results) result.customerId: result,
                      for (final result in _selectedCustomers)
                        result.customerId: result,
                    };
                    final list = selected
                        .map((id) => mapById[id])
                        .whereType<PosCustomerDto>()
                        .toList();
                    Navigator.of(context).pop(list);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() => _selectedCustomers = result);
      await _load();
    }
  }

  void _openDocument(_HistoryDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SaleDetailPage(saleId: document.id)),
    );
  }

  Widget _buildMobileList(
    BuildContext context,
    List<_HistoryDocument> documents,
    LocalePreferencesState localePrefs,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: documents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final document = documents[index];
        return Card(
          elevation: 0,
          child: ListTile(
            leading: Icon(document.icon),
            title: Text(document.number),
            subtitle: Text(document.mobileSubtitle(context, localePrefs)),
            trailing: Text(
              document.amountLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () => _openDocument(document),
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    ThemeData theme,
    LocalePreferencesState localePrefs,
    List<_HistoryDocument> documents,
  ) {
    final selectedDetail = _selectedDetail;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: _DesktopPane(
              title: 'Documents',
              subtitle: '${documents.length} matching document(s)',
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: documents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final document = documents[index];
                  final selected = document.key == _selectedDocumentKey;
                  final colorScheme = theme.colorScheme;
                  return Material(
                    color: selected
                        ? colorScheme.primaryContainer.withValues(alpha: 0.55)
                        : colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _selectDocument(document),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  document.icon,
                                  size: 16,
                                  color: selected
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    document.number,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                _DocumentTypeBadge(type: document.type),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              document.customerLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              document.dateLabel(context, localePrefs),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                document.amountLabel,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: _DesktopPane(
              title: 'Details',
              subtitle: selectedDetail == null
                  ? 'Select a document from the list'
                  : 'Selected document',
              headerTrailing: selectedDetail?.sale != null &&
                      !selectedDetail!.sale!.isRefundInvoice
                  ? IconButton(
                      tooltip: 'Edit sale',
                      onPressed: _actionBusy ? null : _editSelectedSale,
                      icon: const Icon(Icons.edit_outlined),
                    )
                  : null,
              child: _buildMetadataPane(context, theme, localePrefs),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: _DesktopPane(
              title: 'Item Lines',
              subtitle: selectedDetail == null
                  ? 'Item lines appear after a selection'
                  : '${selectedDetail.items.length} line(s)',
              child: _buildItemsPane(context, theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataPane(
    BuildContext context,
    ThemeData theme,
    LocalePreferencesState localePrefs,
  ) {
    if (_detailLoading && _selectedDetail == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_detailError != null) {
      return _PaneMessage(
        icon: Icons.error_outline_rounded,
        title: 'Unable to load document details',
        message: _detailError.toString(),
        actionLabel: 'Retry',
        onAction: () {
          final docs = _buildVisibleDocuments(_search.text);
          final selected = docs.where((doc) => doc.key == _selectedDocumentKey);
          if (selected.isNotEmpty) {
            _selectDocument(selected.first);
          }
        },
      );
    }

    final detail = _selectedDetail;
    if (detail == null) {
      return const AppEmptyView(
        title: 'No document selected',
        message: 'Choose an invoice to inspect its details.',
        icon: Icons.touch_app_rounded,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    detail.document.icon,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      detail.document.number,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail.document.amountLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                detail.document.customerLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail.document.dateLabel(context, localePrefs),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DocumentTypeBadge(type: detail.document.type),
                  _StatusChip(status: detail.document.statusLabel),
                  if (detail.sale?.isFullyRefunded == true)
                    const _RefundStateChip(label: 'Fully refunded'),
                  if (detail.sale?.isPartiallyRefunded == true)
                    const _RefundStateChip(label: 'Partially refunded'),
                ],
              ),
            ],
          ),
        ),
        if (detail.sale != null && !detail.sale!.isRefundInvoice) ...[
          const SizedBox(height: 12),
          _SaleActionsBar(
            busy: _actionBusy,
            onPrintA4: _printSelectedSaleA4,
            onPrint80mm: _printSelectedSale80mm,
            onSharePdf: _shareSelectedSalePdf,
            onRefund: _refundSelectedSale,
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              for (var index = 0; index < detail.metadata.length; index++) ...[
                _DetailTextRow(entry: detail.metadata[index]),
                if (index != detail.metadata.length - 1)
                  Divider(
                    height: 18,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.7,
                    ),
                  ),
              ],
            ],
          ),
        ),
        if ((detail.note ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            detail.noteLabel,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.32,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(detail.note!.trim()),
          ),
        ],
      ],
    );
  }

  Widget _buildItemsPane(BuildContext context, ThemeData theme) {
    if (_detailLoading && _selectedDetail == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_detailError != null) {
      return const AppEmptyView(
        title: 'Items unavailable',
        message:
            'Document lines could not be loaded for the current selection.',
        icon: Icons.inventory_2_outlined,
      );
    }

    final detail = _selectedDetail;
    if (detail == null) {
      return const AppEmptyView(
        title: 'No lines yet',
        message: 'Select a document to review its item lines.',
        icon: Icons.view_list_outlined,
      );
    }

    if (detail.items.isEmpty) {
      return const AppEmptyView(
        title: 'No item lines',
        message: 'This document does not have line items to display.',
        icon: Icons.inventory_2_outlined,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: detail.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = detail.items[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(
                    alpha: 0.65,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.inventory_2_rounded, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((item.subtitle ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if ((item.extra ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.extra!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                item.amountLabel,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final localePrefs = ref.watch(localePreferencesProvider);
    final documents = _buildVisibleDocuments(_search.text);

    if (isDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncDesktopSelection(documents);
      });
    }

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Sales History'),
        actions: [
          IconButton(
            tooltip: 'New Sale',
            icon: const Icon(Icons.point_of_sale_rounded),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PosPage())),
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
        child: Column(
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(title: 'Today', data: _summaryToday),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryCard(title: 'All-time', data: _summaryAll),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        hintText: 'Search by Sale/Return # or customer',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: _dateRange == null
                        ? 'Filter by date range'
                        : 'Date: ${AppDateTime.formatDate(context, localePrefs, _dateRange!.start)} → ${AppDateTime.formatDate(context, localePrefs, _dateRange!.end)}',
                    icon: Icon(
                      Icons.calendar_month_rounded,
                      color:
                          _dateRange != null ? theme.colorScheme.primary : null,
                    ),
                    onPressed: _pickDateRange,
                    onLongPress: () async {
                      if (_dateRange != null) {
                        setState(() => _dateRange = null);
                        await _load();
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: _selectedCustomers.isEmpty
                        ? 'Filter by customers'
                        : 'Customers: ${_selectedCustomers.length}',
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.group_rounded,
                          color: _selectedCustomers.isNotEmpty
                              ? theme.colorScheme.primary
                              : null,
                        ),
                        if (_selectedCustomers.isNotEmpty)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: _pickCustomers,
                    onLongPress: () async {
                      if (_selectedCustomers.isNotEmpty) {
                        setState(() => _selectedCustomers = const []);
                        await _load();
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: documents.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 64),
                        AppEmptyView(
                          title: 'No sales or returns',
                          message:
                              'Transactions matching the current filters will appear here.',
                          icon: Icons.receipt_long_outlined,
                        ),
                      ],
                    )
                  : (isDesktop
                      ? _buildDesktopLayout(
                          context,
                          theme,
                          localePrefs,
                          documents,
                        )
                      : _buildMobileList(context, documents, localePrefs)),
            ),
          ],
        ),
      ),
    );
  }
}

enum _HistoryDocumentType { sale, refund }

class _HistoryDocument {
  const _HistoryDocument({
    required this.type,
    required this.raw,
  });

  factory _HistoryDocument.sale(Map<String, dynamic> raw) => _HistoryDocument(
        type: (((raw['source_channel'] as String?)?.toUpperCase() ==
                    'POS_REFUND') ||
                (((raw['total_amount'] as num?)?.toDouble() ?? 0) < 0))
            ? _HistoryDocumentType.refund
            : _HistoryDocumentType.sale,
        raw: raw,
      );

  final _HistoryDocumentType type;
  final Map<String, dynamic> raw;

  int get id => ((raw['sale_id'] as num?)?.toInt() ?? 0);

  String get key => '${type.name}:$id';

  String get number => raw['sale_number']?.toString() ?? 'Document #$id';

  String? get customerName {
    final customer = raw['customer'];
    if (customer is Map<String, dynamic>) {
      return customer['name']?.toString();
    }
    return null;
  }

  int? get customerId => (raw['customer_id'] as num?)?.toInt();

  String get customerLabel {
    final value = (customerName ?? '').trim();
    if (value.isNotEmpty) return value;
    if (customerId != null) return 'Customer #$customerId';
    return 'Walk-in customer';
  }

  DateTime get sortDate {
    final rawDate = raw['created_at'] ?? raw['sale_date'] ?? raw['return_date'];
    if (rawDate is DateTime) return rawDate;
    return DateTime.tryParse(rawDate?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String dateLabel(BuildContext context, LocalePreferencesState localePrefs) {
    final rawDate = raw['sale_date']?.toString();
    if ((rawDate ?? '').isEmpty) {
      return 'Date unavailable';
    }
    return AppDateTime.formatFlexibleDate(
      context,
      localePrefs,
      rawDate,
      fallback: rawDate!,
    );
  }

  String mobileSubtitle(
    BuildContext context,
    LocalePreferencesState localePrefs,
  ) {
    return [
      customerLabel,
      dateLabel(context, localePrefs),
    ].where((value) => value.isNotEmpty).join(' · ');
  }

  String get statusLabel {
    final primary = (raw['status']?.toString() ?? '').trim();
    final secondary = (raw['pos_status']?.toString() ?? '').trim();
    if (type == _HistoryDocumentType.sale && secondary.isNotEmpty) {
      if (primary.isNotEmpty && primary != secondary) {
        return '$primary · $secondary';
      }
      return secondary;
    }
    if (primary.isNotEmpty) return primary;
    return type == _HistoryDocumentType.sale ? 'Sale' : 'Refund';
  }

  double get amount => (raw['total_amount'] as num?)?.toDouble() ?? 0;

  String get amountLabel => amount.toStringAsFixed(2);

  IconData get icon => type == _HistoryDocumentType.sale
      ? Icons.receipt_long_rounded
      : Icons.undo_rounded;
}

class _HistoryDocumentDetail {
  const _HistoryDocumentDetail({
    required this.document,
    required this.metadata,
    required this.items,
    required this.noteLabel,
    this.sale,
    this.note,
  });

  factory _HistoryDocumentDetail.fromSale(
    _HistoryDocument document,
    SaleDto sale,
  ) {
    final metadata = <_MetadataEntry>[
      _MetadataEntry(
        label: sale.isRefundInvoice ? 'Refund Invoice ID' : 'Sale ID',
        value: sale.saleId.toString(),
      ),
      if (sale.isRefundInvoice)
        _MetadataEntry(
          label: 'Refund For',
          value: (sale.refundSourceSaleNumber ?? '').trim().isNotEmpty
              ? sale.refundSourceSaleNumber!
              : 'Sale #${sale.refundSourceSaleId ?? 0}',
        ),
      if (!sale.isRefundInvoice &&
          (sale.refundSourceSaleNumber ?? '').trim().isNotEmpty)
        _MetadataEntry(
          label: 'Includes Refund From',
          value: sale.refundSourceSaleNumber!,
        ),
      _MetadataEntry(
        label: 'Location',
        value: (sale.locationName ?? '').trim().isNotEmpty
            ? sale.locationName!
            : 'Location #${sale.locationId}',
      ),
      _MetadataEntry(
        label: 'Payment',
        value: (sale.paymentMethodName ?? '').trim().isEmpty
            ? '-'
            : sale.paymentMethodName!,
      ),
      _MetadataEntry(
        label: 'Created By',
        value: (sale.createdByName ?? '').trim().isNotEmpty
            ? sale.createdByName!
            : 'User #${sale.createdBy}',
      ),
      _MetadataEntry(
        label: 'Created At',
        value: _displayDateTime(sale.createdAt),
      ),
      _MetadataEntry(
        label: 'Updated At',
        value: _displayDateTime(sale.updatedAt),
      ),
      _MetadataEntry(
        label: 'Number of Items',
        value: sale.items.length.toString(),
      ),
      _MetadataEntry(
        label: 'Subtotal',
        value: sale.subtotal.toStringAsFixed(2),
      ),
      _MetadataEntry(label: 'Tax', value: sale.taxAmount.toStringAsFixed(2)),
      _MetadataEntry(
        label: 'Discount',
        value: sale.discountAmount.toStringAsFixed(2),
      ),
      _MetadataEntry(label: 'Paid', value: sale.paidAmount.toStringAsFixed(2)),
      if ((sale.posStatus ?? '').trim().isNotEmpty &&
          (sale.posStatus ?? '').trim().toUpperCase() !=
              (sale.status ?? '').trim().toUpperCase())
        _MetadataEntry(label: 'POS State', value: sale.posStatus!.trim()),
    ];

    return _HistoryDocumentDetail(
      document: document,
      metadata: metadata,
      items: sale.items.map(_HistoryLineItem.fromSaleItem).toList(),
      noteLabel: sale.isRefundInvoice ? 'Refund Reason' : 'Notes',
      sale: sale,
      note: sale.notes,
    );
  }

  static String _displayDateTime(dynamic value) {
    DateTime? parsed;
    if (value is DateTime) {
      parsed = value;
    } else if (value != null) {
      parsed = DateTime.tryParse(value.toString());
    }
    if (parsed == null) return '-';
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  final _HistoryDocument document;
  final List<_MetadataEntry> metadata;
  final List<_HistoryLineItem> items;
  final String noteLabel;
  final SaleDto? sale;
  final String? note;
}

class _HistoryLineItem {
  const _HistoryLineItem({
    required this.title,
    required this.amountLabel,
    this.subtitle,
    this.extra,
  });

  factory _HistoryLineItem.fromSaleItem(SaleItemDto item) {
    final title = [
      (item.productName ?? '').trim(),
      (item.variantName ?? '').trim(),
    ].where((value) => value.isNotEmpty).join(' • ');
    final discountPart = item.discountPercent > 0
        ? 'Disc ${item.discountPercent.toStringAsFixed(item.discountPercent.truncateToDouble() == item.discountPercent ? 0 : 2)}%'
        : null;
    final extra = <String>[
      if (item.serialNumbers.isNotEmpty)
        'Serials: ${item.serialNumbers.join(', ')}',
      if (item.comboComponentTracking.isNotEmpty)
        'Tracked components: ${item.comboComponentTracking.map((component) => component.summary(item.quantity)).join(' | ')}',
    ].join('\n');

    return _HistoryLineItem(
      title: title.isEmpty ? 'Item' : title,
      subtitle: [
        'Qty ${item.quantity.toStringAsFixed(2)} × ${item.unitPrice.toStringAsFixed(2)}',
        if (discountPart != null) discountPart,
      ].join(' · '),
      extra: extra.isEmpty ? null : extra,
      amountLabel: (item.lineTotal > 0
              ? item.lineTotal
              : ((item.quantity * item.unitPrice) - item.discountAmount))
          .toStringAsFixed(2),
    );
  }

  final String title;
  final String amountLabel;
  final String? subtitle;
  final String? extra;
}

class _MetadataEntry {
  const _MetadataEntry({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _DesktopPane extends StatelessWidget {
  const _DesktopPane({
    required this.title,
    required this.subtitle,
    required this.child,
    this.headerTrailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (headerTrailing != null) ...[
                  const SizedBox(width: 8),
                  headerTrailing!,
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _DocumentTypeBadge extends StatelessWidget {
  const _DocumentTypeBadge({required this.type});

  final _HistoryDocumentType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSale = type == _HistoryDocumentType.sale;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSale ? const Color(0xFF123D2A) : const Color(0xFF49310C),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isSale ? 'Sale' : 'Refund',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: isSale ? const Color(0xFF8EE6B0) : const Color(0xFFF1C87A),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toUpperCase();
    final colors = switch (normalized) {
      'COMPLETED' => (bg: const Color(0xFF113826), fg: const Color(0xFF8EE6B0)),
      'ACTIVE' => (bg: const Color(0xFF11304A), fg: const Color(0xFF8FC8FF)),
      'HOLD' || 'HELD' => (
          bg: const Color(0xFF4B3310),
          fg: const Color(0xFFF1C87A),
        ),
      'DRAFT' => (bg: const Color(0xFF353535), fg: const Color(0xFFE0E0E0)),
      'CANCELLED' || 'VOIDED' => (
          bg: const Color(0xFF4A1717),
          fg: const Color(0xFFFF9A9A),
        ),
      _ => (bg: const Color(0xFF30343A), fg: const Color(0xFFD8DEE9)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _RefundStateChip extends StatelessWidget {
  const _RefundStateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF17324C),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF9ED0FF),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DetailTextRow extends StatelessWidget {
  const _DetailTextRow({required this.entry});

  final _MetadataEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            entry.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            entry.value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SaleActionsBar extends StatelessWidget {
  const _SaleActionsBar({
    required this.busy,
    required this.onPrintA4,
    required this.onPrint80mm,
    required this.onSharePdf,
    required this.onRefund,
  });

  final bool busy;
  final Future<void> Function() onPrintA4;
  final Future<void> Function() onPrint80mm;
  final Future<void> Function() onSharePdf;
  final Future<void> Function() onRefund;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilledButton.tonalIcon(
            onPressed: busy ? null : onPrintA4,
            icon: const Icon(Icons.print_rounded),
            label: const Text('A4'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: busy ? null : onPrint80mm,
            icon: const Icon(Icons.print_rounded),
            label: const Text('80mm'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : onSharePdf,
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : onRefund,
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Refund'),
          ),
        ],
      ),
    );
  }
}

class _PaneMessage extends StatelessWidget {
  const _PaneMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.data});

  final String title;
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSales =
        ((data?['total_sales'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
    final txns = (data?['total_transactions'] as num?)?.toInt() ?? 0;
    final avg =
        ((data?['average_ticket'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(totalSales, style: theme.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text('Txns: $txns · Avg: $avg', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
