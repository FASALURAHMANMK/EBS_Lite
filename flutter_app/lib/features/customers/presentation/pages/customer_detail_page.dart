import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/customer_repository.dart';
import 'customer_edit_page.dart';

class CustomerDetailPage extends ConsumerStatefulWidget {
  const CustomerDetailPage({super.key, required this.customerId});
  final int customerId;
  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage> {
  late Future<CustomerDto> _customerFuture;
  late Future<CustomerSummaryDto> _summaryFuture;
  late Future<List<Map<String, dynamic>>> _salesFuture;
  late Future<List<Map<String, dynamic>>> _returnsFuture;
  late Future<List<CustomerCollectionDto>> _collectionsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = ref.read(customerRepositoryProvider);
    _customerFuture = repo.getCustomer(widget.customerId);
    _summaryFuture = repo.getCustomerSummary(widget.customerId);
    _salesFuture = repo.getSales(customerId: widget.customerId);
    _returnsFuture = repo.getSaleReturns(customerId: widget.customerId);
    _collectionsFuture = repo.getCollections(customerId: widget.customerId);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Customer')),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await Future.wait([
            _customerFuture, _summaryFuture, _salesFuture, _returnsFuture, _collectionsFuture
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            FutureBuilder<CustomerDto>(
              future: _customerFuture,
              builder: (context, s) {
                if (!s.hasData) return const LinearProgressIndicator(minHeight: 2);
                final cu = s.data!;
                return Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(cu.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      if ((cu.phone ?? '').isNotEmpty) 'Phone: ${cu.phone}',
                      if ((cu.email ?? '').isNotEmpty) 'Email: ${cu.email}',
                      if ((cu.address ?? '').isNotEmpty) 'Address: ${cu.address}',
                      if ((cu.taxNumber ?? '').isNotEmpty) 'Tax#: ${cu.taxNumber}',
                      'Credit Limit: ${cu.creditLimit.toStringAsFixed(2)} | Terms: ${cu.paymentTerms} days',
                    ].join('\n')),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        final updated = await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => CustomerEditPage(customerId: cu.customerId)),
                        );
                        if (updated == true && mounted) _reload();
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            FutureBuilder<CustomerSummaryDto>(
              future: _summaryFuture,
              builder: (context, s) {
                if (!s.hasData) return const SizedBox.shrink();
                final sum = s.data!;
                return Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _metric('Sales', sum.totalSales),
                        _metric('Payments', sum.totalPayments),
                        _metric('Returns', sum.totalReturns),
                        _metric('Loyalty', sum.loyaltyPoints),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _sectionTitle('Sales'),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _salesFuture,
              builder: (context, s) {
                if (!s.hasData) return const SizedBox.shrink();
                final items = s.data!;
                return _simpleList(
                  items.map((e) => _SimpleRow(
                    title: (e['sale_number'] ?? e['number'] ?? '').toString(),
                    subtitle: (e['status'] ?? '').toString(),
                    trailing: (e['total_amount'] ?? 0).toString(),
                  )).toList(),
                );
              },
            ),
            const SizedBox(height: 8),
            _sectionTitle('Sale Returns'),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _returnsFuture,
              builder: (context, s) {
                if (!s.hasData) return const SizedBox.shrink();
                final items = s.data!;
                return _simpleList(
                  items.map((e) => _SimpleRow(
                    title: (e['return_number'] ?? e['number'] ?? '').toString(),
                    subtitle: (e['status'] ?? '').toString(),
                    trailing: (e['total_amount'] ?? 0).toString(),
                  )).toList(),
                );
              },
            ),
            const SizedBox(height: 8),
            _sectionTitle('Collections'),
            FutureBuilder<List<CustomerCollectionDto>>(
              future: _collectionsFuture,
              builder: (context, s) {
                if (!s.hasData) return const SizedBox.shrink();
                final items = s.data!;
                return _simpleList(
                  items.map((p) => _SimpleRow(
                    title: p.collectionNumber,
                    subtitle: p.collectionDate.toLocal().toString(),
                    trailing: p.amount.toStringAsFixed(2),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Widget _metric(String label, double value) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      );

  Widget _simpleList(List<_SimpleRow> rows) => Card(
        elevation: 0,
        child: Column(
          children: rows
              .map((r) => ListTile(
                    title: Text(r.title),
                    subtitle: r.subtitle != null ? Text(r.subtitle!) : null,
                    trailing: Text(r.trailing ?? ''),
                  ))
              .toList(),
        ),
      );
}

class _SimpleRow {
  final String title;
  final String? subtitle;
  final String? trailing;
  _SimpleRow({required this.title, this.subtitle, this.trailing});
}

