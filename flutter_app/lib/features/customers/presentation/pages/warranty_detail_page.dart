import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';

import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../data/warranty_models.dart';
import '../../data/warranty_repository.dart';
import '../utils/warranty_card_actions.dart';

class WarrantyDetailPage extends ConsumerStatefulWidget {
  const WarrantyDetailPage({super.key, required this.warrantyId});

  final int warrantyId;

  @override
  ConsumerState<WarrantyDetailPage> createState() => _WarrantyDetailPageState();
}

class _WarrantyDetailPageState extends ConsumerState<WarrantyDetailPage> {
  late Future<WarrantyRegistrationDto> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<WarrantyRegistrationDto> _load() {
    return ref.read(warrantyRepositoryProvider).getWarranty(widget.warrantyId);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final actions = WarrantyCardActions(ref: ref, context: context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Warranty Registration'),
        actions: [
          PopupMenuButton<_WarrantyCardAction>(
            tooltip: 'Warranty card options',
            onSelected: (value) async {
              switch (value) {
                case _WarrantyCardAction.printA4:
                  await actions.printWarrantyCard(
                    widget.warrantyId,
                    format: PdfPageFormat.a4,
                  );
                  break;
                case _WarrantyCardAction.printA5:
                  await actions.printWarrantyCard(
                    widget.warrantyId,
                    format: PdfPageFormat.a5,
                  );
                  break;
                case _WarrantyCardAction.shareA4:
                  await actions.shareWarrantyCard(
                    widget.warrantyId,
                    format: PdfPageFormat.a4,
                  );
                  break;
                case _WarrantyCardAction.shareA5:
                  await actions.shareWarrantyCard(
                    widget.warrantyId,
                    format: PdfPageFormat.a5,
                  );
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _WarrantyCardAction.printA4,
                child: Text('Print A4 Card'),
              ),
              PopupMenuItem(
                value: _WarrantyCardAction.printA5,
                child: Text('Print A5 Card'),
              ),
              PopupMenuItem(
                value: _WarrantyCardAction.shareA4,
                child: Text('Share A4 PDF'),
              ),
              PopupMenuItem(
                value: _WarrantyCardAction.shareA5,
                child: Text('Share A5 PDF'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<WarrantyRegistrationDto>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingView(label: 'Loading warranty');
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 72),
                  AppErrorView(error: snapshot.error!, onRetry: _refresh),
                ],
              );
            }
            final warranty = snapshot.data!;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _heroCard(context, warranty),
                const SizedBox(height: 16),
                _sectionCard(
                  context,
                  title: 'Customer',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow('Name', warranty.customerName),
                      if ((warranty.customerPhone ?? '').trim().isNotEmpty)
                        _detailRow('Mobile', warranty.customerPhone!.trim()),
                      if ((warranty.customerEmail ?? '').trim().isNotEmpty)
                        _detailRow('Email', warranty.customerEmail!.trim()),
                      if ((warranty.customerAddress ?? '').trim().isNotEmpty)
                        _detailRow('Address', warranty.customerAddress!.trim()),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  context,
                  title: 'Covered Items',
                  child: Column(
                    children: warranty.items
                        .map((item) => _itemTile(context, item))
                        .toList(),
                  ),
                ),
                if ((warranty.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _sectionCard(
                    context,
                    title: 'Notes',
                    child: Text(warranty.notes!.trim()),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context, WarrantyRegistrationDto warranty) {
    final theme = Theme.of(context);
    final dates = warranty.items
        .map((e) => e.warrantyEndDate)
        .whereType<DateTime>()
        .toList(growable: false);
    DateTime? latestEnd;
    if (dates.isNotEmpty) {
      dates.sort();
      latestEnd = dates.last;
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            warranty.customerName,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroChip(context, 'Invoice', warranty.saleNumber),
              _heroChip(context, 'Registration', '#${warranty.warrantyId}'),
              _heroChip(
                context,
                'Registered',
                _fmtDate(warranty.registeredAt),
              ),
              if (latestEnd != null)
                _heroChip(context, 'Valid Until', _fmtDate(latestEnd)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _itemTile(BuildContext context, WarrantyItemDto item) {
    final details = <String>[
      if ((item.variantName ?? '').trim().isNotEmpty) item.variantName!.trim(),
      if ((item.barcode ?? '').trim().isNotEmpty)
        'Code ${item.barcode!.trim()}',
      if ((item.serialNumber ?? '').trim().isNotEmpty)
        'Serial ${item.serialNumber!.trim()}',
      if ((item.batchNumber ?? '').trim().isNotEmpty)
        'Batch ${item.batchNumber!.trim()}',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text('Qty ${_fmtQty(item.quantity)}'),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(details.join('  •  ')),
          ],
          const SizedBox(height: 8),
          Text(
            'Coverage: ${_fmtDate(item.warrantyStartDate)} to ${_fmtDate(item.warrantyEndDate)}',
          ),
        ],
      ),
    );
  }

  Widget _heroChip(BuildContext context, String label, String value) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: onPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: onPrimary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _fmtDate(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('dd MMM yyyy').format(value.toLocal());
  }

  String _fmtQty(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }
}

enum _WarrantyCardAction {
  printA4,
  printA5,
  shareA4,
  shareA5,
}
