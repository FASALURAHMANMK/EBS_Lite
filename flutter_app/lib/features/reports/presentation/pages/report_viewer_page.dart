import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../dashboard/controllers/location_notifier.dart';
import '../../../dashboard/data/models.dart';
import '../../data/reports_repository.dart';
import '../../../../core/error_handler.dart';
import 'report_category_page.dart';

class ReportViewerPage extends ConsumerStatefulWidget {
  const ReportViewerPage({super.key, required this.config});

  final ReportConfig config;

  @override
  ConsumerState<ReportViewerPage> createState() => _ReportViewerPageState();
}

class _ReportViewerPageState extends ConsumerState<ReportViewerPage> {
  bool _loading = true;
  String? _error;
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
    if (widget.config.supportsExpensesGroupBy &&
        _expensesGroupBy != 'none') {
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
      setState(() => _error = ErrorHandler.message(e));
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
      if (!context.mounted) return;
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
            onSelected: _export,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
              PopupMenuItem(value: 'excel', child: Text('Export Excel')),
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
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _ReportDataView(data: _data),
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
    final dateLabel = (DateTime? d) =>
        d == null ? 'Any' : DateFormat('yyyy-MM-dd').format(d);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (config.supportsDateRange)
                  OutlinedButton.icon(
                    onPressed: onPickFrom,
                    icon: const Icon(Icons.event_rounded),
                    label: Text('From: ${dateLabel(fromDate)}'),
                  ),
                if (config.supportsDateRange)
                  OutlinedButton.icon(
                    onPressed: onPickTo,
                    icon: const Icon(Icons.event_available_rounded),
                    label: Text('To: ${dateLabel(toDate)}'),
                  ),
                if (config.supportsLocation && locations.isNotEmpty)
                  DropdownButton<int?>(
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
                if (config.supportsGroupBy)
                  DropdownButton<String>(
                    value: groupBy,
                    items: const [
                      DropdownMenuItem(value: 'day', child: Text('Daily')),
                      DropdownMenuItem(value: 'month', child: Text('Monthly')),
                      DropdownMenuItem(value: 'year', child: Text('Yearly')),
                    ],
                    onChanged: (v) => onGroupByChanged(v ?? 'day'),
                  ),
                if (config.supportsExpensesGroupBy)
                  DropdownButton<String>(
                    value: expensesGroupBy,
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('No Group')),
                      DropdownMenuItem(value: 'day', child: Text('Daily')),
                      DropdownMenuItem(value: 'month', child: Text('Monthly')),
                    ],
                    onChanged: (v) => onExpensesGroupByChanged(v ?? 'none'),
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
                FilledButton(
                  onPressed: onApply,
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportDataView extends StatelessWidget {
  const _ReportDataView({required this.data});

  final dynamic data;

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return const Center(child: Text('No data available'));
    }
    if (data is List) {
      final list = data as List;
      if (list.isEmpty) {
        return const Center(child: Text('No results found'));
      }
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final row = list[i];
          return Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildRow(row),
            ),
          );
        },
      );
    }
    if (data is Map) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildRow(data),
            ),
          ),
        ],
      );
    }
    return Center(child: Text(data.toString()));
  }

  Widget _buildRow(dynamic row) {
    if (row is Map) {
      final entries = row.entries
          .map((e) => MapEntry(e.key.toString(), e.value))
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${e.key}: ${e.value ?? '—'}'),
              ),
            )
            .toList(),
      );
    }
    return Text(row.toString());
  }
}
