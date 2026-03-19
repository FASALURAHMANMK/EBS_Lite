import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../dashboard/controllers/location_notifier.dart';
import '../../../dashboard/data/models.dart';
import '../../data/reports_repository.dart';
import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../../shared/widgets/app_scrollbar.dart';
import 'report_category_page.dart';

class ReportViewerPage extends ConsumerStatefulWidget {
  const ReportViewerPage({super.key, required this.config});

  final ReportConfig config;

  @override
  ConsumerState<ReportViewerPage> createState() => _ReportViewerPageState();
}

class _ReportViewerPageState extends ConsumerState<ReportViewerPage> {
  bool _loading = true;
  Object? _error;
  dynamic _data;

  DateTime? _fromDate;
  DateTime? _toDate;
  int? _locationId;
  String _groupBy = 'day';
  String _expensesGroupBy = 'none';
  final TextEditingController _limitCtrl = TextEditingController(text: '10');
  final TextEditingController _productIdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncLocation();
    _load();
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    _productIdCtrl.dispose();
    super.dispose();
  }

  void _syncLocation() {
    final location = ref.read(locationNotifierProvider).selected;
    if (location != null) {
      _locationId = location.locationId;
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final initial = from ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  Map<String, dynamic> _buildQuery() {
    final qp = <String, dynamic>{};
    if (widget.config.supportsDateRange) {
      if (_fromDate != null) {
        qp['from_date'] = DateFormat('yyyy-MM-dd').format(_fromDate!);
      }
      if (_toDate != null) {
        qp['to_date'] = DateFormat('yyyy-MM-dd').format(_toDate!);
      }
    }
    if (widget.config.supportsLocation && _locationId != null) {
      qp['location_id'] = _locationId;
    }
    if (widget.config.supportsGroupBy) {
      qp['group_by'] = _groupBy;
    }
    if (widget.config.supportsExpensesGroupBy && _expensesGroupBy != 'none') {
      qp['group_by'] = _expensesGroupBy;
    }
    if (widget.config.supportsLimit) {
      final limit = int.tryParse(_limitCtrl.text.trim());
      if (limit != null && limit > 0) qp['limit'] = limit;
    }
    if (widget.config.supportsProductId) {
      final pid = int.tryParse(_productIdCtrl.text.trim());
      if (pid != null && pid > 0) qp['product_id'] = pid;
    }
    return qp;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(reportsRepositoryProvider);
      final data = await repo.fetchReport(
        widget.config.endpoint,
        queryParameters: _buildQuery(),
      );
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export(String format) async {
    try {
      await ref.read(reportsRepositoryProvider).exportReport(
            widget.config.endpoint,
            format: format,
            queryParameters: _buildQuery(),
            shareTitle: widget.config.title,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  Future<void> _printPdf() async {
    try {
      final bytes =
          await ref.read(reportsRepositoryProvider).downloadReportBytes(
                widget.config.endpoint,
                format: 'pdf',
                queryParameters: _buildQuery(),
              );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationNotifierProvider);
    final locations = locationState.locations;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.config.title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'print') {
                _printPdf();
              } else {
                _export(v);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
              PopupMenuItem(value: 'excel', child: Text('Export Excel')),
              PopupMenuItem(value: 'print', child: Text('Print PDF')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _FiltersCard(
              config: widget.config,
              fromDate: _fromDate,
              toDate: _toDate,
              onPickFrom: () => _pickDate(from: true),
              onPickTo: () => _pickDate(from: false),
              locations: locations,
              locationId: _locationId,
              onLocationChanged: (id) => setState(() => _locationId = id),
              groupBy: _groupBy,
              onGroupByChanged: (v) => setState(() => _groupBy = v),
              expensesGroupBy: _expensesGroupBy,
              onExpensesGroupByChanged: (v) =>
                  setState(() => _expensesGroupBy = v),
              limitCtrl: _limitCtrl,
              productIdCtrl: _productIdCtrl,
              onApply: _load,
            ),
            Expanded(
              child: _loading
                  ? const AppLoadingView(label: 'Loading report')
                  : _error != null
                      ? AppErrorView(error: _error!, onRetry: _load)
                      : _ReportDataView(
                          endpoint: widget.config.endpoint,
                          data: _data,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.config,
    required this.fromDate,
    required this.toDate,
    required this.onPickFrom,
    required this.onPickTo,
    required this.locations,
    required this.locationId,
    required this.onLocationChanged,
    required this.groupBy,
    required this.onGroupByChanged,
    required this.expensesGroupBy,
    required this.onExpensesGroupByChanged,
    required this.limitCtrl,
    required this.productIdCtrl,
    required this.onApply,
  });

  final ReportConfig config;
  final DateTime? fromDate;
  final DateTime? toDate;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final List<Location> locations;
  final int? locationId;
  final ValueChanged<int?> onLocationChanged;
  final String groupBy;
  final ValueChanged<String> onGroupByChanged;
  final String expensesGroupBy;
  final ValueChanged<String> onExpensesGroupByChanged;
  final TextEditingController limitCtrl;
  final TextEditingController productIdCtrl;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    String dateLabel(DateTime? d) =>
        d == null ? 'Any' : DateFormat('yyyy-MM-dd').format(d);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (config.supportsDateRange)
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 168),
                  child: OutlinedButton.icon(
                    onPressed: onPickFrom,
                    icon: const Icon(Icons.event_rounded),
                    label: Text('From: ${dateLabel(fromDate)}'),
                  ),
                ),
              if (config.supportsDateRange)
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 168),
                  child: OutlinedButton.icon(
                    onPressed: onPickTo,
                    icon: const Icon(Icons.event_available_rounded),
                    label: Text('To: ${dateLabel(toDate)}'),
                  ),
                ),
              if (config.supportsLocation && locations.isNotEmpty)
                SizedBox(
                  width: 220,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Location',
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        isExpanded: true,
                        value: locationId,
                        hint: const Text('Location'),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All locations'),
                          ),
                          ...locations.map(
                            (l) => DropdownMenuItem<int?>(
                              value: l.locationId,
                              child: Text(l.name),
                            ),
                          )
                        ],
                        onChanged: onLocationChanged,
                      ),
                    ),
                  ),
                ),
              if (config.supportsGroupBy)
                SizedBox(
                  width: 180,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Group By',
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: groupBy,
                        items: const [
                          DropdownMenuItem(value: 'day', child: Text('Daily')),
                          DropdownMenuItem(
                              value: 'month', child: Text('Monthly')),
                          DropdownMenuItem(
                              value: 'year', child: Text('Yearly')),
                        ],
                        onChanged: (v) => onGroupByChanged(v ?? 'day'),
                      ),
                    ),
                  ),
                ),
              if (config.supportsExpensesGroupBy)
                SizedBox(
                  width: 180,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Group Expenses By',
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: expensesGroupBy,
                        items: const [
                          DropdownMenuItem(
                              value: 'none', child: Text('No Group')),
                          DropdownMenuItem(value: 'day', child: Text('Daily')),
                          DropdownMenuItem(
                              value: 'month', child: Text('Monthly')),
                        ],
                        onChanged: (v) => onExpensesGroupByChanged(v ?? 'none'),
                      ),
                    ),
                  ),
                ),
              if (config.supportsLimit)
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: limitCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Limit',
                    ),
                  ),
                ),
              if (config.supportsProductId)
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: productIdCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Product ID',
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: onApply,
                icon: const Icon(Icons.filter_alt_rounded),
                label: const Text('Run Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportDataView extends StatelessWidget {
  const _ReportDataView({
    required this.endpoint,
    required this.data,
  });

  final String endpoint;
  final dynamic data;

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return const AppEmptyView(
        title: 'No data available',
        message: 'This report has no data for the current filters.',
        icon: Icons.bar_chart_rounded,
      );
    }
    if (data is List) {
      final list = data as List;
      if (list.isEmpty) {
        return const AppEmptyView(
          title: 'No results found',
          message: 'Try changing the report filters and run it again.',
          icon: Icons.table_rows_outlined,
        );
      }
      final allMaps = list.every((e) => e is Map);
      if (allMaps) {
        final rows = list.cast<Map>();
        return _MapTableView(
          endpoint: endpoint,
          rows: rows,
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(list[i].toString()),
          ),
        ),
      );
    }
    if (data is Map) {
      final map = (data as Map).cast<dynamic, dynamic>();
      return _KeyValueTableView(
        endpoint: endpoint,
        map: map,
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(data.toString()),
      ),
    );
  }
}

class _TableShell extends StatelessWidget {
  const _TableShell({
    required this.child,
    this.caption,
  });

  final Widget child;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (caption != null) ...[
                Text(
                  caption!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyValueTableView extends StatelessWidget {
  const _KeyValueTableView({
    required this.endpoint,
    required this.map,
  });

  final String endpoint;
  final Map<dynamic, dynamic> map;

  @override
  Widget build(BuildContext context) {
    final entries = map.entries
        .map((e) => MapEntry(e.key.toString(), e.value))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return _TableShell(
      caption: '${entries.length} fields',
      child: AppScrollbar(
        builder: (context, controller) => SingleChildScrollView(
          controller: controller,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Field')),
                DataColumn(label: Text('Value')),
              ],
              rows: entries
                  .map(
                    (e) => DataRow(
                      cells: [
                        DataCell(
                            Text(_ReportDisplay.labelForKey(endpoint, e.key))),
                        DataCell(
                          Text(_ReportDisplay.formatValue(
                              endpoint, e.key, e.value)),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapTableView extends StatelessWidget {
  const _MapTableView({
    required this.endpoint,
    required this.rows,
  });

  final String endpoint;
  final List<Map> rows;

  @override
  Widget build(BuildContext context) {
    final columns = <String>{};
    for (final r in rows.take(200)) {
      for (final k in r.keys) {
        columns.add(k.toString());
      }
    }
    final orderedCols = _ReportDisplay.orderColumns(
      endpoint,
      columns.map((e) => e.toString()).toList(),
    );

    return _TableShell(
      caption:
          '${rows.length} rows • ${orderedCols.length} columns${rows.length > 500 ? ' • showing first 500' : ''}',
      child: AppScrollbar(
        builder: (context, controller) => SingleChildScrollView(
          controller: controller,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 720),
              child: DataTable(
                columns: orderedCols
                    .map(
                      (c) => DataColumn(
                        label: Text(_ReportDisplay.labelForKey(endpoint, c)),
                      ),
                    )
                    .toList(),
                rows: rows
                    .take(500)
                    .map(
                      (r) => DataRow(
                        cells: orderedCols
                            .map(
                              (c) => DataCell(
                                Text(
                                  _ReportDisplay.formatValue(
                                    endpoint,
                                    c,
                                    r[c],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportDisplay {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

  static const Map<String, List<String>> _columnOrderByEndpoint = {
    '/reports/sales-summary': [
      'period',
      'transactions',
      'total_sales',
      'outstanding',
    ],
    '/reports/top-products': [
      'product_id',
      'product_name',
      'quantity_sold',
      'revenue',
    ],
    '/reports/customer-balances': [
      'customer_id',
      'name',
      'total_due',
    ],
    '/reports/tax': [
      'tax_name',
      'tax_rate',
      'taxable_amount',
      'tax_amount',
    ],
    '/reports/purchase-vs-returns': [
      'purchases_total',
      'returns_total',
      'net_purchases',
      'purchases_outstanding',
    ],
    '/reports/supplier': [
      'supplier_id',
      'supplier_name',
      'purchases_total',
      'purchases_paid',
      'purchases_outstanding',
      'returns_total',
    ],
    '/reports/daily-cash': [
      'date',
      'location_id',
      'status',
      'opening_balance',
      'cash_in',
      'cash_out',
      'expected_balance',
      'closing_balance',
      'variance',
    ],
    '/reports/income-expense': [
      'day',
      'sales_total',
      'expenses_total',
      'net_income',
    ],
    '/reports/general-ledger': [
      'date',
      'account_code',
      'account_name',
      'debit',
      'credit',
      'transaction_type',
      'transaction_id',
      'reference',
      'description',
      'voucher_id',
      'entry_id',
      'account_id',
    ],
    '/reports/trial-balance': [
      'account_code',
      'account_name',
      'account_type',
      'total_debit',
      'total_credit',
      'balance',
    ],
    '/reports/profit-loss': [
      'section',
      'account_code',
      'account_name',
      'amount',
    ],
    '/reports/balance-sheet': [
      'section',
      'account_code',
      'account_name',
      'amount',
    ],
    '/reports/outstanding': [
      'type',
      'amount',
    ],
    '/reports/top-performers': [
      'category',
      'name',
      'total_sales',
      'transactions',
    ],
    '/reports/stock-summary': [
      'product_id',
      'location_id',
      'quantity',
      'stock_value',
    ],
    '/reports/item-movement': [
      'product_id',
      'product_name',
      'purchased_qty',
      'purchase_return_qty',
      'sold_qty',
      'sale_return_qty',
      'adjustment_qty',
      'net_movement',
    ],
    '/reports/valuation': [
      'product_id',
      'product_name',
      'quantity',
      'stock_value',
    ],
    '/reports/asset-register': [
      'asset_tag',
      'item_name',
      'category_name',
      'supplier_name',
      'location_id',
      'acquisition_date',
      'in_service_date',
      'status',
      'source_mode',
      'quantity',
      'unit_cost',
      'total_value',
    ],
    '/reports/asset-value-summary': [
      'category_name',
      'status',
      'item_count',
      'total_value',
    ],
    '/reports/consumable-consumption': [
      'entry_number',
      'item_name',
      'category_name',
      'supplier_name',
      'location_id',
      'consumed_at',
      'source_mode',
      'quantity',
      'unit_cost',
      'total_cost',
    ],
    '/reports/consumable-balance': [
      'product_id',
      'product_name',
      'location_id',
      'quantity',
      'stock_value',
    ],
  };

  static const Map<String, String> _globalLabels = {
    'id': 'ID',
    'account_id': 'Account ID',
    'account_code': 'Account Code',
    'account_name': 'Account Name',
    'account_type': 'Account Type',
    'amount': 'Amount',
    'asset_tag': 'Asset Tag',
    'balance': 'Balance',
    'cash_in': 'Cash In',
    'cash_out': 'Cash Out',
    'closing_balance': 'Closing Balance',
    'closing_count': 'Closing Count',
    'credit': 'Credit',
    'consumed_at': 'Consumed At',
    'customer_id': 'Customer ID',
    'date': 'Date',
    'day': 'Day',
    'debit': 'Debit',
    'description': 'Description',
    'entry_id': 'Entry ID',
    'expected_balance': 'Expected Balance',
    'expenses_total': 'Expenses',
    'item_count': 'Item Count',
    'item_name': 'Item Name',
    'location_id': 'Location ID',
    'name': 'Name',
    'net_income': 'Net Income',
    'net_movement': 'Net Movement',
    'net_purchases': 'Net Purchases',
    'opening_balance': 'Opening Balance',
    'outstanding': 'Outstanding Balance',
    'period': 'Period',
    'product_id': 'Product ID',
    'product_name': 'Product Name',
    'purchased_qty': 'Purchased Quantity',
    'purchase_return_qty': 'Purchase Return Quantity',
    'purchases_outstanding': 'Outstanding Payables',
    'purchases_paid': 'Payments Made',
    'purchases_total': 'Purchases',
    'quantity': 'Quantity',
    'quantity_sold': 'Quantity Sold',
    'reference': 'Reference',
    'returns_total': 'Purchase Returns',
    'revenue': 'Sales Revenue',
    'sale_return_qty': 'Sales Return Quantity',
    'sales_total': 'Sales',
    'section': 'Section',
    'status': 'Status',
    'stock_value': 'Stock Value',
    'source_mode': 'Source Mode',
    'supplier_id': 'Supplier ID',
    'supplier_name': 'Supplier Name',
    'tax_amount': 'Tax Amount',
    'tax_name': 'Tax Code',
    'tax_rate': 'Tax Rate',
    'taxable_amount': 'Taxable Amount',
    'total_credit': 'Total Credit',
    'total_debit': 'Total Debit',
    'total_due': 'Outstanding Balance',
    'total_sales': 'Sales Total',
    'transactions': 'Transactions',
    'transaction_id': 'Transaction ID',
    'transaction_type': 'Source Type',
    'type': 'Type',
    'total_cost': 'Total Cost',
    'total_value': 'Total Value',
    'unit_cost': 'Unit Cost',
    'variance': 'Variance',
    'voucher_id': 'Voucher ID',
    'entry_number': 'Entry Number',
    'in_service_date': 'In Service Date',
    'category_name': 'Category',
  };

  static const Map<String, String> _sectionValueLabels = {
    'ASSET': 'Assets',
    'LIABILITY': 'Liabilities',
    'EQUITY': 'Equity',
    'REVENUE': 'Revenue',
    'EXPENSE': 'Expenses',
    'TOTAL_ASSETS': 'Total Assets',
    'TOTAL_LIABILITIES': 'Total Liabilities',
    'TOTAL_EQUITY': 'Total Equity',
    'TOTAL_REVENUE': 'Total Revenue',
    'TOTAL_EXPENSE': 'Total Expenses',
    'NET_PROFIT': 'Net Profit',
    'ASSETS_MINUS_LIABILITIES_EQUITY': 'Balance Sheet Difference',
  };

  static const Map<String, String> _typeValueLabels = {
    'sales': 'Accounts Receivable',
    'purchases': 'Accounts Payable',
  };

  static List<String> orderColumns(String endpoint, List<String> columns) {
    final remaining = [...columns]..sort();
    final ordered = <String>[];
    final preferred = _columnOrderByEndpoint[endpoint] ?? const <String>[];
    for (final column in preferred) {
      if (remaining.remove(column)) {
        ordered.add(column);
      }
    }
    ordered.addAll(remaining);
    return ordered;
  }

  static String labelForKey(String endpoint, String key) {
    final normalized = key.trim();
    return _globalLabels[normalized] ?? _humanizeKey(normalized);
  }

  static String formatValue(String endpoint, String key, dynamic value) {
    if (value == null) return '—';

    if (key == 'section') {
      final raw = value.toString();
      return _sectionValueLabels[raw] ?? _humanizeKey(raw);
    }
    if (key == 'type') {
      final raw = value.toString();
      return _typeValueLabels[raw] ?? _humanizeKey(raw);
    }
    if (key == 'status') {
      return _humanizeKey(value.toString());
    }
    if (value is DateTime) {
      return _dateTimeFormat.format(value.toLocal());
    }
    if (_looksLikeDateKey(key)) {
      final parsed = DateTime.tryParse(value.toString());
      if (parsed != null) {
        return _dateFormat.format(parsed.toLocal());
      }
    }
    if (value is num) {
      if (_looksLikePercentKey(key)) {
        return '${value.toStringAsFixed(2)}%';
      }
      if (_looksLikeQuantityKey(key)) {
        return value.toStringAsFixed(value % 1 == 0 ? 0 : 3);
      }
      return value.toStringAsFixed(2);
    }
    return value.toString();
  }

  static bool _looksLikeDateKey(String key) =>
      key == 'date' ||
      key == 'day' ||
      key.endsWith('_date') ||
      key.endsWith('_at');

  static bool _looksLikePercentKey(String key) =>
      key.contains('rate') || key.contains('percent');

  static bool _looksLikeQuantityKey(String key) =>
      key == 'quantity' ||
      key == 'transactions' ||
      key == 'item_count' ||
      key.endsWith('_qty');

  static String _humanizeKey(String raw) {
    if (raw.isEmpty) return raw;
    final parts = raw
        .replaceAll('-', '_')
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return raw;
    return parts
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }
}
