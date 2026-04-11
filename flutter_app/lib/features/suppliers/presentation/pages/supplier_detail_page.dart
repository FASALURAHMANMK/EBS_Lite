import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../data/models.dart';
import '../../data/supplier_repository.dart';
import '../widgets/supplier_workbench_widgets.dart';
import '../widgets/supplier_payment_sheet.dart';
import 'supplier_edit_page.dart';

class SupplierDetailPage extends ConsumerStatefulWidget {
  const SupplierDetailPage({super.key, required this.supplierId});
  final int supplierId;
  @override
  ConsumerState<SupplierDetailPage> createState() => _SupplierDetailPageState();
}

class _SupplierDetailPageState extends ConsumerState<SupplierDetailPage> {
  bool _loading = true;
  Object? _error;
  SupplierDto? _supplier;
  SupplierSummaryDto? _summary;
  List<Map<String, dynamic>>? _purchases;
  List<Map<String, dynamic>>? _returns;
  List<SupplierPaymentDto>? _payments;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(supplierRepositoryProvider);
      final results = await Future.wait<dynamic>([
        repo.getSupplier(widget.supplierId),
        repo.getSupplierSummary(widget.supplierId),
        repo.getPurchases(supplierId: widget.supplierId),
        repo.getPurchaseReturns(supplierId: widget.supplierId),
        repo.getPayments(supplierId: widget.supplierId),
      ]);
      if (!mounted) return;
      setState(() {
        _supplier = results[0] as SupplierDto;
        _summary = results[1] as SupplierSummaryDto;
        _purchases = results[2] as List<Map<String, dynamic>>;
        _returns = results[3] as List<Map<String, dynamic>>;
        _payments = results[4] as List<SupplierPaymentDto>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPaymentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SupplierPaymentSheet(
        supplierId: widget.supplierId,
        onDone: () {
          if (mounted) _reload();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final isLoading = _loading && _supplier == null;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isDesktop ? 104 : null,
        leading: isDesktop ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Supplier'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _reload,
          ),
          IconButton(
            tooltip: 'Record Payment',
            icon: const Icon(Icons.payments_rounded),
            onPressed: _supplier == null ? null : _showPaymentSheet,
          ),
        ],
      ),
      body: isLoading
          ? const AppLoadingView(label: 'Loading supplier details')
          : _error != null && _supplier == null
              ? AppErrorView(error: _error!, onRetry: _reload)
              : _supplier == null
                  ? const Center(child: Text('Supplier not found'))
                  : _buildBody(isDesktop),
    );
  }

  Widget _buildBody(bool isDesktop) {
    final supplier = _supplier!;
    final summary = _summary!;

    if (isDesktop) {
      return _buildDesktopBody(supplier, summary);
    }
    return _buildMobileBody(supplier, summary);
  }

  Widget _buildDesktopBody(
    SupplierDto supplier,
    SupplierSummaryDto summary,
  ) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ProfessionalDocumentHeader(
              title: supplier.name,
              subtitle: [
                if ((supplier.address ?? '').isNotEmpty) supplier.address!,
                if ((supplier.phone ?? '').isNotEmpty)
                  'Phone: ${supplier.phone}',
                if ((supplier.email ?? '').isNotEmpty)
                  'Email: ${supplier.email}',
              ].join(' | ').isEmpty
                  ? 'Supplier #${supplier.supplierId}'
                  : [
                      'Supplier #${supplier.supplierId}',
                      if ((supplier.address ?? '').isNotEmpty)
                        supplier.address!,
                    ].join(' | '),
              badges: [
                SupplierTypeBadge(
                  isMercantile: supplier.isMercantile,
                  isNonMercantile: supplier.isNonMercantile,
                ),
                SupplierStatusBadge(isActive: supplier.isActive),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: ProfessionalOverviewCard(
                    title: 'Financial Overview',
                    icon: Icons.account_balance_rounded,
                    action: FilledButton.tonalIcon(
                      onPressed: () async {
                        final updated = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SupplierEditPage(
                              supplierId: supplier.supplierId,
                            ),
                          ),
                        );
                        if (updated == true && mounted) _reload();
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                      style: professionalCompactButtonStyle(context),
                    ),
                    expandChild: false,
                    child: ProfessionalFieldGrid(
                      fields: [
                        ProfessionalFieldGridItem(
                          label: 'Contact Person',
                          value: supplier.contactPerson ?? '',
                        ),
                        ProfessionalFieldGridItem(
                          label: 'Phone',
                          value: supplier.phone ?? '',
                        ),
                        ProfessionalFieldGridItem(
                          label: 'Email',
                          value: supplier.email ?? '',
                        ),
                        ProfessionalFieldGridItem(
                          label: 'Address',
                          value: supplier.address ?? '',
                          maxLines: 2,
                        ),
                        ProfessionalFieldGridItem(
                          label: 'Payment Terms',
                          value: '${supplier.paymentTerms} days',
                        ),
                        ProfessionalFieldGridItem(
                          label: 'Credit Limit',
                          value: supplier.creditLimit.toStringAsFixed(2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ProfessionalSummaryCard(
                    title: 'Payment Summary',
                    expandContent: false,
                    rows: [
                      (
                        label: 'Total Purchases',
                        value: summary.totalPurchases.toStringAsFixed(2),
                        emphasize: true,
                      ),
                      (
                        label: 'Total Payments',
                        value: summary.totalPayments.toStringAsFixed(2),
                        emphasize: true,
                      ),
                      (
                        label: 'Total Returns',
                        value: summary.totalReturns.toStringAsFixed(2),
                        emphasize: false,
                      ),
                      (
                        label: 'Debit Notes',
                        value: summary.totalDebitNotes.toStringAsFixed(2),
                        emphasize: false,
                      ),
                      (
                        label: 'Outstanding Balance',
                        value: summary.outstandingBalance.toStringAsFixed(2),
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (_purchases != null && _purchases!.isNotEmpty) ...[
                  ProfessionalSectionCard(
                    title: 'Purchases',
                    subtitle: '${_purchases!.length} transaction(s)',
                    child: Column(
                      children: _purchases!
                          .map((e) => _buildDesktopTransactionRow(
                                number:
                                    (e['purchase_number'] ?? e['number'] ?? '')
                                        .toString(),
                                status: (e['status'] ?? '').toString(),
                                amount: (e['total_amount'] ?? 0).toString(),
                                date: e['purchase_date'] != null
                                    ? e['purchase_date'].toString()
                                    : null,
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_returns != null && _returns!.isNotEmpty) ...[
                  ProfessionalSectionCard(
                    title: 'Purchase Returns',
                    subtitle: '${_returns!.length} transaction(s)',
                    child: Column(
                      children: _returns!
                          .map((e) => _buildDesktopTransactionRow(
                                number:
                                    (e['return_number'] ?? e['number'] ?? '')
                                        .toString(),
                                status: (e['status'] ?? '').toString(),
                                amount: (e['total_amount'] ?? 0).toString(),
                                date: e['return_date'] != null
                                    ? e['return_date'].toString()
                                    : null,
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_payments != null && _payments!.isNotEmpty) ...[
                  ProfessionalSectionCard(
                    title: 'Payments',
                    subtitle: '${_payments!.length} payment(s)',
                    child: Column(
                      children: _payments!
                          .map((p) => _buildDesktopTransactionRow(
                                number: p.paymentNumber,
                                status: p.referenceNumber ?? '',
                                amount: p.amount.toStringAsFixed(2),
                                date: p.paymentDate.toLocal().toString(),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTransactionRow({
    required String number,
    required String status,
    required String amount,
    String? date,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              number,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ProfessionalBadge(
              label: status.isEmpty ? '—' : status.toUpperCase(),
            ),
          ),
          if (date != null) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                date.split(' ').first,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              amount,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody(
    SupplierDto supplier,
    SupplierSummaryDto summary,
  ) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SupplierReviewCard(
            supplier: supplier,
            summary: summary,
            onEdit: () async {
              final updated = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      SupplierEditPage(supplierId: supplier.supplierId),
                ),
              );
              if (updated == true && mounted) _reload();
            },
            onRecordPayment: _showPaymentSheet,
            onViewFullDetails: null,
          ),
          const SizedBox(height: 12),
          if (_purchases != null && _purchases!.isNotEmpty) ...[
            _mobileSectionTitle('Purchases'),
            _simpleList(
              _purchases!
                  .map((e) => _SimpleRow(
                        title: (e['purchase_number'] ?? e['number'] ?? '')
                            .toString(),
                        subtitle: (e['status'] ?? '').toString(),
                        trailing: (e['total_amount'] ?? 0).toString(),
                      ))
                  .toList(),
            ),
          ],
          if (_returns != null && _returns!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _mobileSectionTitle('Purchase Returns'),
            _simpleList(
              _returns!
                  .map((e) => _SimpleRow(
                        title: (e['return_number'] ?? e['number'] ?? '')
                            .toString(),
                        subtitle: (e['status'] ?? '').toString(),
                        trailing: (e['total_amount'] ?? 0).toString(),
                      ))
                  .toList(),
            ),
          ],
          if (_payments != null && _payments!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _mobileSectionTitle('Payments'),
            _simpleList(
              _payments!
                  .map((p) => _SimpleRow(
                        title: p.paymentNumber,
                        subtitle: p.paymentDate.toLocal().toString(),
                        trailing: p.amount.toStringAsFixed(2),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mobileSectionTitle(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
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
