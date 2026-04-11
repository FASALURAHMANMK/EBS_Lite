import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_selection_dialog.dart';
import '../../../../shared/widgets/desktop_sidebar_toggle_action.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../../pos/data/models.dart';
import '../../../pos/data/pos_repository.dart';
import '../../data/sales_repository.dart';
import '../utils/invoice_actions.dart';
import '../widgets/sales_workbench_widgets.dart';
import 'b2b_invoice_form_page.dart';
import 'sale_detail_page.dart';

class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});

  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> {
  final _search = TextEditingController();

  bool _loading = true;
  bool _detailLoading = false;
  bool _actionBusy = false;
  Object? _error;
  Object? _detailError;
  List<Map<String, dynamic>> _sales = const [];
  DateTimeRange? _dateRange;
  List<PosCustomerDto> _selectedCustomers = const [];
  int? _selectedSaleId;
  int? _selectionTargetSaleId;
  SaleDto? _selectedSale;
  int _detailRequestToken = 0;

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

  String _toApiDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<_InvoiceDocument> _buildVisibleDocuments(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    final documents = _sales
        .where(_isInvoiceRow)
        .map(_InvoiceDocument.new)
        .toList(growable: false)
      ..sort((a, b) => b.sortDate.compareTo(a.sortDate));
    if (normalizedQuery.isEmpty) {
      return documents;
    }
    return documents.where((document) {
      return document.number.toLowerCase().contains(normalizedQuery) ||
          document.customerLabel.toLowerCase().contains(normalizedQuery);
    }).toList(growable: false);
  }

  bool _isInvoiceRow(Map<String, dynamic> row) {
    final transactionType =
        (row['transaction_type']?.toString() ?? 'RETAIL').trim().toUpperCase();
    final sourceChannel =
        (row['source_channel']?.toString() ?? '').trim().toUpperCase();
    final totalAmount = (row['total_amount'] as num?)?.toDouble() ?? 0;
    return transactionType == 'B2B' &&
        sourceChannel != 'POS_REFUND' &&
        totalAmount >= 0;
  }

  List<Map<String, dynamic>> _filterByCustomers(
    List<Map<String, dynamic>> rows,
    List<int> selectedIds,
  ) {
    if (selectedIds.isEmpty || selectedIds.length == 1) {
      return rows;
    }
    final selectedSet = selectedIds.toSet();
    return rows.where((row) {
      final customer = row['customer'];
      final customerId = customer is Map<String, dynamic>
          ? customer['customer_id'] as int?
          : row['customer_id'] as int?;
      return customerId != null && selectedSet.contains(customerId);
    }).toList(growable: false);
  }

  Future<void> _load({int? selectSaleId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final selectedIds =
        _selectedCustomers.map((customer) => customer.customerId).toList();
    final singleCustomerId = selectedIds.length == 1 ? selectedIds.first : null;
    final now = DateTime.now();
    var fromDate = _toApiDate(now.subtract(const Duration(days: 30)));
    String? toDate;
    if (_dateRange != null) {
      fromDate = _toApiDate(_dateRange!.start);
      toDate = _toApiDate(_dateRange!.end);
    }

    try {
      final list = await ref.read(salesRepositoryProvider).getSalesHistory(
            dateFrom: fromDate,
            dateTo: toDate,
            customerId: singleCustomerId,
            transactionType: 'B2B',
          );
      if (!mounted) return;
      setState(() {
        _sales = _filterByCustomers(list, selectedIds);
        _selectionTargetSaleId = selectSaleId;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _syncDesktopSelection(List<_InvoiceDocument> documents) {
    if (!mounted) return;
    if (documents.isEmpty) {
      if (_selectedSaleId != null ||
          _selectedSale != null ||
          _detailError != null ||
          _detailLoading) {
        setState(() {
          _selectedSaleId = null;
          _selectedSale = null;
          _detailError = null;
          _detailLoading = false;
        });
      }
      return;
    }

    _InvoiceDocument? next;
    final targetSaleId = _selectionTargetSaleId;
    if (targetSaleId != null) {
      for (final document in documents) {
        if (document.saleId == targetSaleId) {
          next = document;
          break;
        }
      }
    }

    if (next == null && _selectedSaleId != null) {
      for (final document in documents) {
        if (document.saleId == _selectedSaleId) {
          next = document;
          break;
        }
      }
    }
    next ??= documents.first;

    if (_selectionTargetSaleId != null) {
      _selectionTargetSaleId = null;
    }

    if (_selectedSaleId != next.saleId ||
        (_selectedSale == null && !_detailLoading && _detailError == null)) {
      _selectSale(next);
    }
  }

  Future<void> _selectSale(_InvoiceDocument document) async {
    if (_selectedSaleId == document.saleId &&
        (_detailLoading || _selectedSale?.saleId == document.saleId)) {
      return;
    }

    final requestToken = ++_detailRequestToken;
    setState(() {
      _selectedSaleId = document.saleId;
      _selectedSale = null;
      _detailError = null;
      _detailLoading = true;
    });

    try {
      final sale =
          await ref.read(posRepositoryProvider).getSaleById(document.saleId);
      if (!mounted || requestToken != _detailRequestToken) return;
      setState(() {
        _selectedSale = sale;
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

  Future<void> _reloadSelection({int? selectSaleId}) async {
    await _load(selectSaleId: selectSaleId ?? _selectedSaleId);
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
    if (picked == null || !mounted) return;
    setState(() => _dateRange = picked);
    await _load();
  }

  Future<void> _pickCustomers() async {
    final result = await showDialog<List<PosCustomerDto>>(
      context: context,
      builder: (context) {
        final repo = ref.read(posRepositoryProvider);
        final selected =
            _selectedCustomers.map((item) => item.customerId).toSet();
        final controller = TextEditingController();
        List<PosCustomerDto> results = const [];
        bool loading = true;
        bool kickoff = true;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> runSearch(String query) async {
              loading = true;
              setStateDialog(() {});
              try {
                results = await repo.searchCustomers(query);
              } finally {
                loading = false;
                setStateDialog(() {});
              }
            }

            if (kickoff) {
              kickoff = false;
              Future.microtask(() => runSearch(''));
            }

            return AppSelectionDialog(
              title: 'Filter Customers',
              maxWidth: 480,
              loading: loading,
              searchField: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Search customers',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search_rounded),
                    onPressed: () => runSearch(controller.text.trim()),
                  ),
                ),
                onChanged: (value) => runSearch(value.trim()),
                onSubmitted: (value) => runSearch(value.trim()),
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
                          subtitle: Text(
                            [
                              if ((customer.phone ?? '').isNotEmpty)
                                customer.phone!,
                              if ((customer.email ?? '').isNotEmpty)
                                customer.email!,
                            ].where((value) => value.isNotEmpty).join(' · '),
                          ),
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
                      for (final customer in results)
                        customer.customerId: customer,
                      for (final customer in _selectedCustomers)
                        customer.customerId: customer,
                    };
                    Navigator.of(context).pop(
                      selected
                          .map((id) => mapById[id])
                          .whereType<PosCustomerDto>()
                          .toList(growable: false),
                    );
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() => _selectedCustomers = result);
    await _load();
  }

  Future<void> _openInvoiceForm({SaleDto? sale}) async {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final result = await Navigator.of(context).push<B2BInvoiceWorkflowResult>(
      MaterialPageRoute(
        builder: (_) => B2BInvoiceFormPage(
          sale: sale,
          returnResultOnSave: true,
        ),
      ),
    );
    if (!mounted) return;
    if (result == null) {
      await _reloadSelection(selectSaleId: sale?.saleId);
      return;
    }
    await _reloadSelection(selectSaleId: result.saleId);
    if (!mounted || isDesktop) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SaleDetailPage(saleId: result.saleId)),
    );
    await _reloadSelection(selectSaleId: result.saleId);
  }

  Future<void> _openSelectedReview() async {
    final sale = _selectedSale;
    if (sale == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SaleDetailPage(saleId: sale.saleId)),
    );
    await _reloadSelection(selectSaleId: sale.saleId);
  }

  Future<void> _printSelectedInvoice() async {
    final sale = _selectedSale;
    if (sale == null) return;
    setState(() => _actionBusy = true);
    try {
      await InvoiceActions(ref: ref, context: context).printA4(sale.saleId);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _shareSelectedInvoice() async {
    final sale = _selectedSale;
    if (sale == null) return;
    setState(() => _actionBusy = true);
    try {
      await InvoiceActions(ref: ref, context: context)
          .shareInvoice(sale.saleId);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  bool get _canEditSelectedInvoice {
    final sale = _selectedSale;
    if (sale == null) return false;
    return sale.isB2B &&
        !sale.isRefundInvoice &&
        !sale.isFullyRefunded &&
        !sale.isPartiallyRefunded;
  }

  Widget _buildFilters(bool isDesktop) {
    final dateLabel = _dateRange == null
        ? 'Last 30 days'
        : '${_dateRange!.start.month}/${_dateRange!.start.day}/${_dateRange!.start.year} - ${_dateRange!.end.month}/${_dateRange!.end.day}/${_dateRange!.end.year}';
    final hasFilter = _dateRange != null || _selectedCustomers.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search invoice # or customer',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text(dateLabel),
                ),
                OutlinedButton.icon(
                  onPressed: _pickCustomers,
                  icon: const Icon(Icons.groups_rounded),
                  label: Text(
                    _selectedCustomers.isEmpty
                        ? 'All customers'
                        : _selectedCustomers.length == 1
                            ? _selectedCustomers.first.name
                            : '${_selectedCustomers.length} customers',
                  ),
                ),
                if (hasFilter)
                  TextButton.icon(
                    onPressed: () async {
                      setState(() {
                        _dateRange = null;
                        _selectedCustomers = const [];
                      });
                      await _load();
                    },
                    icon: const Icon(Icons.filter_alt_off_rounded),
                    label: const Text('Clear filters'),
                  ),
                if (isDesktop)
                  const Padding(
                    padding: EdgeInsets.only(left: 8, top: 10),
                    child: Text('B2B invoices only'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(
    ThemeData theme,
    LocalePreferencesState localePrefs,
    List<_InvoiceDocument> documents,
  ) {
    final selectedSale = _selectedSale;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: SalesWorkbenchPane(
              title: 'Invoices',
              subtitle: '${documents.length} matching invoice(s)',
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: documents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final document = documents[index];
                  final selected = document.saleId == _selectedSaleId;
                  final colorScheme = theme.colorScheme;
                  return Material(
                    color: selected
                        ? colorScheme.primaryContainer.withValues(alpha: 0.55)
                        : colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _selectSale(document),
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
                                  Icons.receipt_long_rounded,
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
                                SalesStatusChip(status: document.statusLabel),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              document.customerLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              document.dateLabel(context, localePrefs),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const SalesTransactionTypeChip(
                                  transactionType: 'B2B',
                                ),
                                const Spacer(),
                                Text(
                                  document.amountLabel,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
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
            child: SalesWorkbenchPane(
              title: 'Review',
              subtitle: selectedSale == null
                  ? 'Select an invoice from the list'
                  : 'Invoice overview and actions',
              headerTrailing: _canEditSelectedInvoice
                  ? IconButton(
                      tooltip: 'Edit selected invoice',
                      onPressed: _actionBusy
                          ? null
                          : () => _openInvoiceForm(sale: _selectedSale),
                      icon: const Icon(Icons.edit_outlined),
                    )
                  : null,
              child: _buildOverviewPane(localePrefs),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: SalesWorkbenchPane(
              title: 'Item Lines',
              subtitle: selectedSale == null
                  ? 'Item lines appear after a selection'
                  : '${selectedSale.items.length} line(s)',
              child: _buildItemsPane(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewPane(LocalePreferencesState localePrefs) {
    if (_detailLoading && _selectedSale == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_detailError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: ProfessionalDocumentEmptyState(
            title: 'Unable to load invoice details',
            message: _detailError.toString(),
            actionLabel: 'Retry',
            onAction: () {
              final documents = _buildVisibleDocuments(_search.text);
              _InvoiceDocument? selected;
              for (final document in documents) {
                if (document.saleId == _selectedSaleId) {
                  selected = document;
                  break;
                }
              }
              if (selected != null) {
                _selectSale(selected);
              }
            },
            icon: Icons.error_outline_rounded,
          ),
        ),
      );
    }
    final sale = _selectedSale;
    if (sale == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: ProfessionalDocumentEmptyState(
            title: 'No invoice selected',
            message: 'Choose a B2B invoice to review its financial summary.',
            icon: Icons.touch_app_rounded,
          ),
        ),
      );
    }

    final balance = sale.totalAmount - sale.paidAmount;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sale.saleNumber,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Text(
                    sale.totalAmount.toStringAsFixed(2),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                (sale.customerName ?? '').trim().isEmpty
                    ? 'Walk-in customer'
                    : sale.customerName!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                AppDateTime.formatFlexibleDate(
                  context,
                  localePrefs,
                  sale.saleDate?.toIso8601String(),
                  fallback: sale.saleDate == null ? 'Date unavailable' : '-',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const SalesTransactionTypeChip(transactionType: 'B2B'),
                  SalesStatusChip(status: (sale.status ?? 'COMPLETED').trim()),
                  if (sale.isFullyRefunded)
                    const SalesRefundStateChip(label: 'Fully refunded'),
                  if (sale.isPartiallyRefunded)
                    const SalesRefundStateChip(label: 'Partially refunded'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ProfessionalOverviewCard(
          title: 'Invoice Overview',
          icon: Icons.info_outline_rounded,
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
                value: AppDateTime.formatFlexibleDate(
                  context,
                  localePrefs,
                  sale.saleDate?.toIso8601String(),
                  fallback: 'Not available',
                ),
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
                value: AppDateTime.formatFlexibleDate(
                  context,
                  localePrefs,
                  sale.createdAt?.toIso8601String(),
                  fallback: 'Not available',
                ),
              ),
              if ((sale.refundSourceSaleNumber ?? '').trim().isNotEmpty)
                ProfessionalFieldGridItem(
                  label: 'Source Refund Link',
                  value: sale.refundSourceSaleNumber!,
                ),
              ProfessionalFieldGridItem(
                label: 'Document State',
                value: [
                  if ((sale.status ?? '').trim().isNotEmpty)
                    sale.status!.trim(),
                  if ((sale.posStatus ?? '').trim().isNotEmpty)
                    sale.posStatus!.trim(),
                ].join(' · '),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ProfessionalSummaryCard(
          title: 'Financial Summary',
          rows: [
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
              FilledButton.icon(
                onPressed: _actionBusy ? null : _openSelectedReview,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Full Review'),
                style: professionalCompactButtonStyle(context),
              ),
              FilledButton.tonalIcon(
                onPressed: _actionBusy ? null : _printSelectedInvoice,
                icon: const Icon(Icons.print_rounded),
                label: const Text('Print'),
                style: professionalCompactButtonStyle(context),
              ),
              FilledButton.tonalIcon(
                onPressed: _actionBusy ? null : _shareSelectedInvoice,
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share'),
                style: professionalCompactButtonStyle(context),
              ),
            ],
          ),
        ),
        if ((sale.notes ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          ProfessionalSectionCard(
            title: 'Notes',
            child: Text(sale.notes!.trim()),
          ),
        ],
      ],
    );
  }

  Widget _buildItemsPane() {
    if (_detailLoading && _selectedSale == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_detailError != null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: ProfessionalDocumentEmptyState(
            title: 'Items unavailable',
            message: 'Invoice lines could not be loaded for this selection.',
            icon: Icons.inventory_2_outlined,
          ),
        ),
      );
    }
    final sale = _selectedSale;
    if (sale == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: ProfessionalDocumentEmptyState(
            title: 'No lines yet',
            message: 'Select an invoice to review its item lines.',
            icon: Icons.view_list_outlined,
          ),
        ),
      );
    }
    if (sale.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: ProfessionalDocumentEmptyState(
            title: 'No item lines',
            message: 'This invoice does not have line items to display.',
            icon: Icons.inventory_2_outlined,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: sale.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = sale.items[index];
        final trackingSummary = <String>[
          if (item.serialNumbers.isNotEmpty)
            'Serials: ${item.serialNumbers.join(', ')}',
          if (item.comboComponentTracking.isNotEmpty)
            item.comboComponentTracking
                .map((component) => component.summary(item.quantity))
                .join(' | '),
        ].where((value) => value.isNotEmpty).join('\n');

        return ProfessionalOverviewCard(
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
              if (trackingSummary.isNotEmpty)
                ProfessionalFieldGridItem(
                  label: 'Tracking',
                  value: trackingSummary,
                  maxLines: 3,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileList(
    List<_InvoiceDocument> documents,
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
            leading: const Icon(Icons.receipt_long_rounded),
            title: Text(document.number),
            subtitle: Text(document.mobileSubtitle(context, localePrefs)),
            trailing: Text(
              document.amountLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SaleDetailPage(saleId: document.saleId),
                ),
              );
              await _reloadSelection(selectSaleId: document.saleId);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localePrefs = ref.watch(localePreferencesProvider);
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final isDesktop = AppBreakpoints.isDesktop(context);
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
        title: const Text('B2B Invoices'),
        actions: [
          IconButton(
            tooltip: 'New Invoice',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => _openInvoiceForm(),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _load(selectSaleId: _selectedSaleId),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            _buildFilters(isDesktop),
            Expanded(
              child: _error != null
                  ? AppErrorView(error: _error!, onRetry: _load)
                  : documents.isEmpty
                      ? const AppEmptyView(
                          title: 'No invoices',
                          message:
                              'B2B invoices will appear here once they are created.',
                          icon: Icons.receipt_long_outlined,
                        )
                      : (isDesktop
                          ? _buildDesktopLayout(theme, localePrefs, documents)
                          : _buildMobileList(documents, localePrefs)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceDocument {
  const _InvoiceDocument(this.raw);

  final Map<String, dynamic> raw;

  int get saleId => (raw['sale_id'] as num?)?.toInt() ?? 0;

  String get number => raw['sale_number']?.toString() ?? 'Invoice #$saleId';

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
    final rawDate = raw['created_at'] ?? raw['sale_date'];
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
      statusLabel,
    ].where((value) => value.isNotEmpty).join(' · ');
  }

  String get statusLabel {
    final primary = (raw['status']?.toString() ?? '').trim();
    final secondary = (raw['pos_status']?.toString() ?? '').trim();
    if (primary.isNotEmpty && secondary.isNotEmpty && primary != secondary) {
      return '$primary · $secondary';
    }
    if (secondary.isNotEmpty) return secondary;
    if (primary.isNotEmpty) return primary;
    return 'Invoice';
  }

  double get amount => (raw['total_amount'] as num?)?.toDouble() ?? 0;

  String get amountLabel => amount.toStringAsFixed(2);
}
