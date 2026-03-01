import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/accounts_repository.dart';
import '../../data/models.dart';
import '../../../../core/error_handler.dart';

class LedgerEntriesPage extends ConsumerStatefulWidget {
  const LedgerEntriesPage({super.key, required this.accountId});

  final int accountId;

  @override
  ConsumerState<LedgerEntriesPage> createState() => _LedgerEntriesPageState();
}

class _LedgerEntriesPageState extends ConsumerState<LedgerEntriesPage> {
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<LedgerEntryDto> _entries = const [];

  int _page = 1;
  int _totalPages = 1;
  final int _perPage = 20;

  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final repo = ref.read(accountsRepositoryProvider);
      final res = await repo.getLedgerEntries(
        accountId: widget.accountId,
        dateFrom: _fromDate,
        dateTo: _toDate,
        page: _page,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _totalPages = res.meta?.totalPages ?? 1;
        if (reset) {
          _entries = res.items;
        } else {
          _entries = [..._entries, ...res.items];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ErrorHandler.message(e));
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _pickDateRange({required bool from}) async {
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
    await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    final dateLabel = (DateTime? d) => d == null ? 'Any' : df.format(d);

    return Scaffold(
      appBar: AppBar(
        title: Text('Ledger Entries • #${widget.accountId}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _pickDateRange(from: true),
                              icon: const Icon(Icons.event_rounded),
                              label: Text('From: ${dateLabel(_fromDate)}'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _pickDateRange(from: false),
                              icon: const Icon(Icons.event_available_rounded),
                              label: Text('To: ${dateLabel(_toDate)}'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _entries.isEmpty
                            ? const Center(
                                child: Text('No ledger entries found'),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _entries.length + 1,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  if (index == _entries.length) {
                                    final canLoadMore =
                                        _page < _totalPages && !_loadingMore;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Center(
                                        child: canLoadMore
                                            ? OutlinedButton(
                                                onPressed: () async {
                                                  setState(() => _page += 1);
                                                  await _load(reset: false);
                                                },
                                                child: const Text('Load more'),
                                              )
                                            : _loadingMore
                                                ? const CircularProgressIndicator()
                                                : const SizedBox.shrink(),
                                      ),
                                    );
                                  }
                                  final entry = _entries[index];
                                  return _LedgerEntryCard(entry: entry);
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _LedgerEntryCard extends StatelessWidget {
  const _LedgerEntryCard({required this.entry});

  final LedgerEntryDto entry;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    final details = <String>[];
    if (entry.voucher != null) {
      details.add(
          'Voucher: ${entry.voucher!.type.toUpperCase()} ${entry.voucher!.reference}');
    }
    if (entry.sale != null) {
      details.add('Sale: ${entry.sale!.saleNumber}');
    }
    if (entry.purchase != null) {
      details.add('Purchase: ${entry.purchase!.purchaseNumber}');
    }
    if (entry.description != null && entry.description!.isNotEmpty) {
      details.add(entry.description!);
    }

    return Card(
      elevation: 0,
      child: ListTile(
        leading: const Icon(Icons.swap_horiz_rounded),
        title: Text(
            '${df.format(entry.date.toLocal())} • ${entry.debit.toStringAsFixed(2)} / ${entry.credit.toStringAsFixed(2)}'),
        subtitle: Text(
            details.isEmpty ? 'Entry #${entry.entryId}' : details.join(' • ')),
        trailing: Text('Bal: ${entry.balance.toStringAsFixed(2)}'),
      ),
    );
  }
}
