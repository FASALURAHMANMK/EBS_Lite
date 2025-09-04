import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/supplier_repository.dart';
import 'supplier_edit_page.dart';

class SupplierDetailPage extends ConsumerStatefulWidget {
  const SupplierDetailPage({super.key, required this.supplierId});
  final int supplierId;
  @override
  ConsumerState<SupplierDetailPage> createState() => _SupplierDetailPageState();
}

class _SupplierDetailPageState extends ConsumerState<SupplierDetailPage> {
  late Future<SupplierDto> _supplierFuture;
  late Future<SupplierSummaryDto> _summaryFuture;
  late Future<List<Map<String, dynamic>>> _purchasesFuture;
  late Future<List<Map<String, dynamic>>> _returnsFuture;
  late Future<List<SupplierPaymentDto>> _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = ref.read(supplierRepositoryProvider);
    _supplierFuture = repo.getSupplier(widget.supplierId);
    _summaryFuture = repo.getSupplierSummary(widget.supplierId);
    _purchasesFuture = repo.getPurchases(supplierId: widget.supplierId);
    _returnsFuture = repo.getPurchaseReturns(supplierId: widget.supplierId);
    _paymentsFuture = repo.getPayments(supplierId: widget.supplierId);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Supplier')),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await Future.wait([
            _supplierFuture, _summaryFuture, _purchasesFuture, _returnsFuture, _paymentsFuture
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            FutureBuilder<SupplierDto>(
              future: _supplierFuture,
              builder: (context, s) {
                if (!s.hasData) return const LinearProgressIndicator(minHeight: 2);
                final sup = s.data!;
                return Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(sup.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      if ((sup.contactPerson ?? '').isNotEmpty) 'Contact: ${sup.contactPerson}',
                      if ((sup.phone ?? '').isNotEmpty) 'Phone: ${sup.phone}',
                      if ((sup.email ?? '').isNotEmpty) 'Email: ${sup.email}',
                      if ((sup.address ?? '').isNotEmpty) 'Address: ${sup.address}',
                      'Credit Limit: ${sup.creditLimit.toStringAsFixed(2)} | Terms: ${sup.paymentTerms} days',
                    ].join('\n')),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        final updated = await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => SupplierEditPage(supplierId: sup.supplierId)),
                        );
                        if (updated == true && mounted) _reload();
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            FutureBuilder<SupplierSummaryDto>(
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
                        _metric('Purchased', sum.totalPurchases),
                        _metric('Payments', sum.totalPayments),
                        _metric('Returns', sum.totalReturns),
                        _metric('Balance', sum.outstandingBalance),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _sectionTitle('Purchases'),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _purchasesFuture,
              builder: (context, s) {
                if (!s.hasData) return const SizedBox.shrink();
                final items = s.data!;
                return _simpleList(
                  items.map((e) => _SimpleRow(
                    title: (e['purchase_number'] ?? e['number'] ?? '').toString(),
                    subtitle: (e['status'] ?? '').toString(),
                    trailing: (e['total_amount'] ?? 0).toString(),
                  )).toList(),
                );
              },
            ),
            const SizedBox(height: 8),
            _sectionTitle('Purchase Returns'),
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
            _sectionTitle('Payments'),
            FutureBuilder<List<SupplierPaymentDto>>(
              future: _paymentsFuture,
              builder: (context, s) {
                if (!s.hasData) return const SizedBox.shrink();
                final items = s.data!;
                return _simpleList(
                  items.map((p) => _SimpleRow(
                    title: p.paymentNumber,
                    subtitle: p.paymentDate.toLocal().toString(),
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

