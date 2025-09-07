import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sales_repository.dart';
import '../../../pos/data/pos_repository.dart';
import '../../../pos/data/models.dart';
import '../../../pos/presentation/pages/pos_page.dart';
import 'sale_detail_page.dart';
import 'sale_return_detail_page.dart';

class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  ConsumerState<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  bool _loading = true;
  Map<String, dynamic>? _summaryToday;
  Map<String, dynamic>? _summaryAll;
  List<Map<String, dynamic>> _sales = const [];
  List<Map<String, dynamic>> _returns = const [];
  final _search = TextEditingController();
  DateTimeRange? _dateRange;
  List<PosCustomerDto> _selectedCustomers = const [];

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

  String _fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(salesRepositoryProvider);
      final now = DateTime.now();
      final todayStr = _fmtDate(now);

      // Run sequentially but guarded so one failure doesn't block others
      try {
        final sToday = await repo.getSalesSummary(dateFrom: todayStr, dateTo: todayStr);
        if (mounted) setState(() => _summaryToday = sToday);
      } catch (_) {}
      try {
        final sAll = await repo.getSalesSummary();
        if (mounted) setState(() => _summaryAll = sAll);
      } catch (_) {}

      // History window: last 30 days by default
      String fromDate = _fmtDate(now.subtract(const Duration(days: 30)));
      String? toDate;
      final dr = _dateRange;
      if (dr != null) {
        fromDate = _fmtDate(dr.start);
        toDate = _fmtDate(dr.end);
      }

      // If exactly one customer selected, pass it to backend. If multiple, filter client-side.
      final selectedIds = _selectedCustomers.map((e) => e.customerId).toList(growable: false);
      final singleCustomerId = selectedIds.length == 1 ? selectedIds.first : null;

      try {
        final sales = await repo.getSalesHistory(
          dateFrom: fromDate,
          dateTo: toDate,
          customerId: singleCustomerId,
        );
        List<Map<String, dynamic>> filtered = sales;
        if (selectedIds.isNotEmpty && singleCustomerId == null) {
          final selSet = selectedIds.toSet();
          filtered = sales.where((e) {
            final cid = (e['customer'] is Map && (e['customer']?['customer_id'] != null))
                ? (e['customer']['customer_id'] as int?)
                : (e['customer_id'] as int?);
            return cid != null && selSet.contains(cid);
          }).toList();
        }
        if (mounted) setState(() => _sales = filtered);
      } catch (_) {}
      try {
        final returns = await repo.getSaleReturns(
          dateFrom: fromDate,
          dateTo: toDate,
          customerId: singleCustomerId,
        );
        List<Map<String, dynamic>> filtered = returns;
        if (selectedIds.isNotEmpty && singleCustomerId == null) {
          final selSet = selectedIds.toSet();
          filtered = returns.where((e) {
            final cid = e['customer_id'] as int?;
            return cid != null && selSet.contains(cid);
          }).toList();
        }
        if (mounted) setState(() => _returns = filtered);
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateRange() async {
    // Custom compact dialog with two small calendars and quick presets
    DateTime todayDate() {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
    DateTimeRange today() {
      final t = todayDate();
      return DateTimeRange(start: t, end: t);
    }
    DateTimeRange yesterday() {
      final t = todayDate().subtract(const Duration(days: 1));
      return DateTimeRange(start: t, end: t);
    }
    DateTimeRange lastNDays(int n) {
      final end = todayDate();
      final start = end.subtract(Duration(days: n - 1));
      return DateTimeRange(start: start, end: end);
    }
    DateTimeRange thisMonth() {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0);
      return DateTimeRange(start: start, end: end);
    }
    DateTimeRange lastMonth() {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 1, 1);
      final end = DateTime(now.year, now.month, 0);
      return DateTimeRange(start: start, end: end);
    }

    DateTimeRange initial = _dateRange ?? lastNDays(7);
    DateTime start = initial.start;
    DateTime end = initial.end;
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 3, 1, 1);
    final lastDate = DateTime(now.year + 1, 12, 31);

    DateTime clampToRange(DateTime d) {
      if (d.isBefore(firstDate)) return firstDate;
      if (d.isAfter(lastDate)) return lastDate;
      return DateTime(d.year, d.month, d.day);
    }

    final picked = await showDialog<DateTimeRange?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Widget calendarBox({required String label, required DateTime value, required void Function(DateTime) onChanged}) {
              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
                    ),
                    SizedBox(
                      height: 240,
                      child: CalendarDatePicker(
                        firstDate: firstDate,
                        lastDate: lastDate,
                        initialDate: value,
                        onDateChanged: (d) => onChanged(clampToRange(d)),
                      ),
                    ),
                  ],
                ),
              );
            }

            void applyPreset(DateTimeRange r) {
              start = r.start;
              end = r.end;
              setStateDialog(() {});
            }

            return AlertDialog(
              scrollable: true,
              title: const Text('Select Date Range'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Builder(
                  builder: (context) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      // Heuristic for narrow layout inside dialog
                      final narrow = screenWidth < 560;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                FilterChip(label: const Text('Today'), selected: start == today().start && end == today().end, onSelected: (_) => applyPreset(today())),
                                FilterChip(label: const Text('Yesterday'), selected: start == yesterday().start && end == yesterday().end, onSelected: (_) => applyPreset(yesterday())),
                                FilterChip(label: const Text('Last 7 days'), selected: start == lastNDays(7).start && end == lastNDays(7).end, onSelected: (_) => applyPreset(lastNDays(7))),
                                FilterChip(label: const Text('Last 30 days'), selected: start == lastNDays(30).start && end == lastNDays(30).end, onSelected: (_) => applyPreset(lastNDays(30))),
                                FilterChip(label: const Text('This month'), selected: start == thisMonth().start && end == thisMonth().end, onSelected: (_) => applyPreset(thisMonth())),
                                FilterChip(label: const Text('Last month'), selected: start == lastMonth().start && end == lastMonth().end, onSelected: (_) => applyPreset(lastMonth())),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (narrow) ...[
                            calendarBox(
                              label: 'Start',
                              value: start,
                              onChanged: (d) {
                                start = d;
                                if (start.isAfter(end)) {
                                  end = start;
                                }
                                setStateDialog(() {});
                              },
                            ),
                            const SizedBox(height: 12),
                            calendarBox(
                              label: 'End',
                              value: end,
                              onChanged: (d) {
                                end = d;
                                if (end.isBefore(start)) {
                                  start = end;
                                }
                                setStateDialog(() {});
                              },
                            ),
                          ] else ...[
                            Row(
                              children: [
                                calendarBox(
                                  label: 'Start',
                                  value: start,
                                  onChanged: (d) {
                                    start = d;
                                    if (start.isAfter(end)) {
                                      end = start;
                                    }
                                    setStateDialog(() {});
                                  },
                                ),
                                const SizedBox(width: 12),
                                calendarBox(
                                  label: 'End',
                                  value: end,
                                  onChanged: (d) {
                                    end = d;
                                    if (end.isBefore(start)) {
                                      start = end;
                                    }
                                    setStateDialog(() {});
                                  },
                                ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(const DateTimeRange(start: DateTime(0), end: DateTime(0)));
                  },
                  child: const Text('Clear'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(DateTimeRange(start: start, end: end)),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null) {
      if (picked.start.year == 0 && picked.end.year == 0) {
        // Clear
        setState(() => _dateRange = null);
      } else {
        setState(() => _dateRange = picked);
      }
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
                final list = await repo.searchCustomers(q);
                results = list;
              } finally {
                loading = false;
                setStateDialog(() {});
              }
            }

            if (kickoff) {
              kickoff = false;
              Future.microtask(() => doSearch(''));
            }

            return AlertDialog(
              title: const Text('Select Customers'),
              content: SizedBox(
                width: 420,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Search customers',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search_rounded),
                          onPressed: () => doSearch(controller.text.trim()),
                        ),
                      ),
                      onSubmitted: (v) => doSearch(v.trim()),
                    ),
                    const SizedBox(height: 8),
                    if (loading) const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: results.isEmpty && !loading
                          ? const Center(child: Text('No customers'))
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (context, i) {
                                final c = results[i];
                                final checked = selected.contains(c.customerId);
                                return CheckboxListTile(
                                  value: checked,
                                  title: Text(c.name),
                                  subtitle: Text([
                                    if ((c.phone ?? '').isNotEmpty) c.phone!,
                                    if ((c.email ?? '').isNotEmpty) c.email!,
                                  ].where((e) => e.isNotEmpty).join(' · ')),
                                  onChanged: (v) {
                                    if (v == true) {
                                      selected.add(c.customerId);
                                    } else {
                                      selected.remove(c.customerId);
                                    }
                                    setStateDialog(() {});
                                  },
                                );
                              },
                            ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            selected.clear();
                            setStateDialog(() {});
                          },
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(null),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            // Convert selected IDs to minimal objects (id, name lookup from results or previous selection)
                            final mapById = {
                              for (final r in results) r.customerId: r,
                              for (final r in _selectedCustomers) r.customerId: r,
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
                    )
                  ],
                ),
              ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _search.text.trim().toLowerCase();

    // Merge sales and returns into a single list with type
    final merged = <Map<String, dynamic>>[
      ..._sales.map((e) => {...e, '_type': 'sale'}),
      ..._returns.map((e) => {...e, '_type': 'return'}),
    ];

    // Sort by created_at/sale_date/return_date desc
    DateTime? parseDate(Map<String, dynamic> e) {
      DateTime? tryParse(dynamic v) {
        if (v == null) return null;
        if (v is DateTime) return v;
        return DateTime.tryParse(v.toString());
      }
      return tryParse(e['created_at']) ?? tryParse(e['sale_date']) ?? tryParse(e['return_date']);
    }

    merged.sort((a, b) {
      final da = parseDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = parseDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });

    final filtered = q.isEmpty
        ? merged
        : merged.where((e) {
            final t = (e['_type'] as String?) ?? '';
            final code = t == 'sale' ? (e['sale_number'] ?? '') : (e['return_number'] ?? '');
            return code.toString().toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          IconButton(
            tooltip: 'New Sale',
            icon: const Icon(Icons.point_of_sale_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PosPage())),
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
            // Top summary cards
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(child: _SummaryCard(title: 'Today', data: _summaryToday)),
                  const SizedBox(width: 8),
                  Expanded(child: _SummaryCard(title: 'All-time', data: _summaryAll)),
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
                        hintText: 'Search by Sale/Return #',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: _dateRange == null
                        ? 'Filter by date range'
                        : 'Date: ${_fmtDate(_dateRange!.start)} → ${_fmtDate(_dateRange!.end)}',
                    icon: Icon(
                      Icons.calendar_month_rounded,
                      color: _dateRange != null ? theme.colorScheme.primary : null,
                    ),
                    onPressed: _pickDateRange,
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
                          color: _selectedCustomers.isNotEmpty ? theme.colorScheme.primary : null,
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
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No sales or returns'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final row = filtered[i];
                        final type = (row['_type'] as String?) ?? '';
                        if (type == 'sale') {
                          final amount = ((row['total_amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
                          final subtitleParts = <String>[
                            if ((row['customer']?['name'] ?? '') != '') (row['customer']?['name']).toString(),
                            if (row['sale_date'] != null) row['sale_date'].toString(),
                          ];
                          return Card(
                            elevation: 0,
                            child: ListTile(
                              leading: const Icon(Icons.receipt_long_rounded),
                              title: Text(row['sale_number']?.toString() ?? ''),
                              subtitle: Text(subtitleParts.where((e) => e.isNotEmpty).join(' · ')),
                              trailing: Text(amount, style: theme.textTheme.titleMedium),
                              onTap: () {
                                final id = row['sale_id'] as int?;
                                if (id != null) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => SaleDetailPage(saleId: id)),
                                  );
                                }
                              },
                            ),
                          );
                        } else {
                          final amount = ((row['total_amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
                          final subtitleParts = <String>[
                            if ((row['customer']?['name'] ?? '') != '')
                              (row['customer']?['name']).toString()
                            else if (row['customer_id'] != null)
                              'Customer #${row['customer_id']}',
                            if (row['return_date'] != null) row['return_date'].toString(),
                          ];
                          return Card(
                            elevation: 0,
                            child: ListTile(
                              leading: const Icon(Icons.assignment_return_rounded),
                              title: Text(row['return_number']?.toString() ?? ''),
                              subtitle: Text(subtitleParts.where((e) => e.isNotEmpty).join(' · ')),
                              trailing: Text(amount, style: theme.textTheme.titleMedium),
                              onTap: () {
                                final id = row['return_id'] as int?;
                                if (id != null) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => SaleReturnDetailPage(returnId: id)),
                                  );
                                }
                              },
                            ),
                          );
                        }
                      },
                    ),
            ),
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
    final totalSales = ((data?['total_sales'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
    final txns = (data?['total_transactions'] as num?)?.toInt() ?? 0;
    final avg = ((data?['average_ticket'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
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
