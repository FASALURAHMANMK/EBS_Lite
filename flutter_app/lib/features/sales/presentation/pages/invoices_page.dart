import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';

import '../../../../shared/widgets/app_selection_dialog.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../data/sales_repository.dart';
import '../../../pos/data/pos_repository.dart';
import '../../../pos/data/models.dart';
import '../../../pos/presentation/pages/pos_page.dart';
import 'sale_detail_page.dart';
import '../utils/invoice_actions.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});

  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _sales = const [];
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

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(salesRepositoryProvider);
      final now = DateTime.now();
      String fromDate = _fmtDate(now.subtract(const Duration(days: 30)));
      String? toDate;
      final dr = _dateRange;
      if (dr != null) {
        fromDate = _fmtDate(dr.start);
        toDate = _fmtDate(dr.end);
      }

      // Single or multi-customer filtering
      final selectedIds =
          _selectedCustomers.map((e) => e.customerId).toList(growable: false);
      final singleCustomerId =
          selectedIds.length == 1 ? selectedIds.first : null;

      final sales = await repo.getSalesHistory(
        dateFrom: fromDate,
        dateTo: toDate,
        customerId: singleCustomerId,
      );
      List<Map<String, dynamic>> filtered = sales;
      if (selectedIds.isNotEmpty && singleCustomerId == null) {
        final selSet = selectedIds.toSet();
        filtered = sales.where((e) {
          final cid =
              (e['customer'] is Map && (e['customer']?['customer_id'] != null))
                  ? (e['customer']['customer_id'] as int?)
                  : (e['customer_id'] as int?);
          return cid != null && selSet.contains(cid);
        }).toList();
      }
      if (mounted) setState(() => _sales = filtered);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleInvoiceAction(String action, int saleId) async {
    final actions = InvoiceActions(
      ref: ref,
      context: context,
    );
    switch (action) {
      case 'view':
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SaleDetailPage(saleId: saleId)),
        );
        return;
      case 'print':
        await actions.printSmart(saleId);
        return;
      case 'share':
        await actions.shareInvoice(saleId);
        return;
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
                onChanged: (v) => doSearch(v.trim()),
                onSubmitted: (v) => doSearch(v.trim()),
              ),
              body: results.isEmpty && !loading
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
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final q = _search.text.trim().toLowerCase();

    // Sort newest first
    DateTime? parseDate(Map<String, dynamic> e) {
      DateTime? tryParse(dynamic v) {
        if (v == null) return null;
        if (v is DateTime) return v;
        return DateTime.tryParse(v.toString());
      }

      return tryParse(e['created_at']) ?? tryParse(e['sale_date']);
    }

    final sorted = [..._sales];
    sorted.sort((a, b) {
      final da = parseDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = parseDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });

    final filtered = q.isEmpty
        ? sorted
        : sorted.where((e) {
            final code = (e['sale_number'] ?? '').toString().toLowerCase();
            return code.contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Invoices'),
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        hintText: 'Search by Invoice #',
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
              child: filtered.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 64),
                        AppEmptyView(
                          title: 'No invoices found',
                          message:
                              'Invoices matching the current filters will appear here.',
                          icon: Icons.receipt_long_outlined,
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final row = filtered[i];
                        final amount =
                            ((row['total_amount'] as num?)?.toDouble() ?? 0)
                                .toStringAsFixed(2);
                        final subtitleParts = <String>[
                          if ((row['customer']?['name'] ?? '') != '')
                            (row['customer']?['name']).toString()
                          else if (row['customer_id'] != null)
                            'Customer #${row['customer_id']}',
                          if (row['sale_date'] != null)
                            row['sale_date'].toString(),
                        ];
                        final saleId = row['sale_id'] as int?;
                        return Card(
                          elevation: 0,
                          child: ListTile(
                            leading: const Icon(Icons.receipt_long_rounded),
                            title: Text(row['sale_number']?.toString() ?? ''),
                            subtitle: Text(subtitleParts
                                .where((e) => e.isNotEmpty)
                                .join(' · ')),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(amount,
                                    style: theme.textTheme.titleMedium),
                                PopupMenuButton<String>(
                                  tooltip: 'Invoice actions',
                                  onSelected: (v) {
                                    if (saleId == null) return;
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (!mounted) return;
                                      // ignore: unawaited_futures
                                      _handleInvoiceAction(v, saleId);
                                    });
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'view',
                                      child: Text('View'),
                                    ),
                                    PopupMenuItem(
                                      value: 'print',
                                      child: Text('Print'),
                                    ),
                                    PopupMenuItem(
                                      value: 'share',
                                      child: Text('Share'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () {
                              if (saleId != null) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          SaleDetailPage(saleId: saleId)),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
