import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../data/models.dart';
import '../../data/customer_repository.dart';
import '../../../loyalty/data/loyalty_repository.dart';
import '../widgets/customer_workbench_widgets.dart';
import '../widgets/customer_collection_sheet.dart';
import 'customer_edit_page.dart';

class CustomerDetailPage extends ConsumerStatefulWidget {
  const CustomerDetailPage({super.key, required this.customerId});
  final int customerId;
  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage> {
  bool _loading = true;
  Object? _error;
  CustomerDto? _customer;
  CustomerSummaryDto? _summary;
  List<LoyaltyTierDto>? _tiers;
  LoyaltySettingsDto? _loySettings;
  List<Map<String, dynamic>>? _sales;
  List<Map<String, dynamic>>? _returns;
  List<CustomerCollectionDto>? _collections;

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
      final repo = ref.read(customerRepositoryProvider);
      final loyRepo = ref.read(loyaltyRepositoryProvider);
      final results = await Future.wait<dynamic>([
        repo.getCustomer(widget.customerId),
        repo.getCustomerSummary(widget.customerId),
        loyRepo.getTiers(),
        loyRepo.getSettings(),
        repo.getSales(customerId: widget.customerId),
        repo.getSaleReturns(customerId: widget.customerId),
        repo.getCollections(customerId: widget.customerId),
      ]);
      if (!mounted) return;
      setState(() {
        _customer = results[0] as CustomerDto;
        _summary = results[1] as CustomerSummaryDto;
        _tiers = results[2] as List<LoyaltyTierDto>;
        _loySettings = results[3] as LoyaltySettingsDto;
        _sales = results[4] as List<Map<String, dynamic>>;
        _returns = results[5] as List<Map<String, dynamic>>;
        _collections = results[6] as List<CustomerCollectionDto>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCollectSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CustomerCollectionSheet(
        customerId: widget.customerId,
        onDone: () {
          if (mounted) _reload();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final isLoading = _loading && _customer == null;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isDesktop ? 104 : null,
        leading: isDesktop ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Customer'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _reload,
          ),
          IconButton(
            tooltip: 'Record Collection',
            icon: const Icon(Icons.payments_rounded),
            onPressed: _customer == null ? null : _showCollectSheet,
          ),
        ],
      ),
      body: isLoading
          ? const AppLoadingView(label: 'Loading customer details')
          : _error != null && _customer == null
              ? AppErrorView(error: _error!, onRetry: _reload)
              : _customer == null
                  ? const Center(child: Text('Customer not found'))
                  : _buildBody(isDesktop),
    );
  }

  Widget _buildBody(bool isDesktop) {
    final customer = _customer!;
    final summary = _summary!;

    if (isDesktop) {
      return _buildDesktopBody(customer, summary);
    }
    return _buildMobileBody(customer, summary);
  }

  Widget _buildDesktopBody(CustomerDto customer, CustomerSummaryDto summary) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ProfessionalDocumentHeader(
              title: customer.name,
              subtitle: [
                if ((customer.address ?? '').isNotEmpty) customer.address!,
                if ((customer.phone ?? '').isNotEmpty)
                  'Phone: ${customer.phone}',
                if ((customer.email ?? '').isNotEmpty)
                  'Email: ${customer.email}',
              ].join(' | ').isEmpty
                  ? 'Customer #${customer.customerId}'
                  : [
                      'Customer #${customer.customerId}',
                      if ((customer.address ?? '').isNotEmpty)
                        customer.address!,
                    ].join(' | '),
              badges: [
                CustomerTypeBadge(customerType: customer.customerType),
                CustomerStatusBadge(isActive: customer.isActive),
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
                            builder: (_) => CustomerEditPage(
                              customerId: customer.customerId,
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
                          value: customer.contactPerson ?? '',
                        ),
                        ProfessionalFieldGridItem(
                          label: 'Phone',
                          value: customer.phone ?? '',
                        ),
                        ProfessionalFieldGridItem(
                          label: 'Email',
                          value: customer.email ?? '',
                        ),
                        ProfessionalFieldGridItem(
                          label: 'Tax Number',
                          value: customer.taxNumber ?? '',
                        ),
                        ProfessionalFieldGridItem(
                          label: 'Payment Terms',
                          value: '${customer.paymentTerms} days',
                        ),
                        ProfessionalFieldGridItem(
                          label: 'Credit Limit',
                          value: customer.creditLimit.toStringAsFixed(2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ProfessionalSummaryCard(
                    title: 'Credit Status',
                    expandContent: false,
                    rows: [
                      (
                        label: 'Outstanding',
                        value: customer.creditBalance.toStringAsFixed(2),
                        emphasize: true,
                      ),
                      (
                        label: 'Available Credit',
                        value: (customer.creditLimit - customer.creditBalance)
                            .clamp(0.0, double.infinity)
                            .toStringAsFixed(2),
                        emphasize: true,
                      ),
                      (
                        label: 'Credit Limit',
                        value: customer.creditLimit.toStringAsFixed(2),
                        emphasize: false,
                      ),
                      (
                        label: 'Total Sales',
                        value: summary.totalSales.toStringAsFixed(2),
                        emphasize: false,
                      ),
                      (
                        label: 'Total Payments',
                        value: summary.totalPayments.toStringAsFixed(2),
                        emphasize: false,
                      ),
                      (
                        label: 'Total Returns',
                        value: summary.totalReturns.toStringAsFixed(2),
                        emphasize: false,
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
                if (customer.isLoyalty &&
                    _tiers != null &&
                    _loySettings != null)
                  ..._buildDesktopLoyaltySection(theme),
                if (_sales != null && _sales!.isNotEmpty) ...[
                  ProfessionalSectionCard(
                    title: 'Sales',
                    subtitle: '${_sales!.length} transaction(s)',
                    child: Column(
                      children: _sales!
                          .map((e) => _buildDesktopTransactionRow(
                                number: (e['sale_number'] ?? e['number'] ?? '')
                                    .toString(),
                                status: (e['status'] ?? '').toString(),
                                amount: (e['total_amount'] ?? 0).toString(),
                                date: e['sale_date'] != null
                                    ? e['sale_date'].toString()
                                    : null,
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_returns != null && _returns!.isNotEmpty) ...[
                  ProfessionalSectionCard(
                    title: 'Sale Returns',
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
                if (_collections != null && _collections!.isNotEmpty) ...[
                  ProfessionalSectionCard(
                    title: 'Collections',
                    subtitle: '${_collections!.length} payment(s)',
                    child: Column(
                      children: _collections!
                          .map((p) => _buildDesktopTransactionRow(
                                number: p.collectionNumber,
                                status: p.paymentMethod ?? '',
                                amount: p.amount.toStringAsFixed(2),
                                date: p.collectionDate.toLocal().toString(),
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

  List<Widget> _buildDesktopLoyaltySection(ThemeData theme) {
    if (_tiers == null ||
        _tiers!.isEmpty ||
        _loySettings == null ||
        _summary == null) {
      return const [];
    }

    final customer = _customer!;
    final tiers = _tiers!;
    final tierName = tiers
        .firstWhere(
          (t) => t.tierId == (customer.loyaltyTierId ?? -1),
          orElse: () => LoyaltyTierDto(
            tierId: -1,
            name: 'Member',
            minPoints: 0,
            isActive: true,
          ),
        )
        .name;
    final pts = _summary!.loyaltyPoints;
    final avail =
        (pts - _loySettings!.minPointsReserve).clamp(0.0, double.infinity);

    return [
      ProfessionalSummaryCard(
        title: 'Loyalty',
        rows: [
          (label: 'Tier', value: tierName, emphasize: true),
          (label: 'Points', value: pts.toStringAsFixed(0), emphasize: true),
          (
            label: 'Available',
            value: avail.toStringAsFixed(0),
            emphasize: false,
          ),
        ],
      ),
      const SizedBox(height: 16),
    ];
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

  Widget _buildMobileBody(CustomerDto customer, CustomerSummaryDto summary) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          CustomerReviewCard(
            customer: customer,
            summary: summary,
            onEdit: () async {
              final updated = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CustomerEditPage(customerId: customer.customerId),
                ),
              );
              if (updated == true && mounted) _reload();
            },
            onRecordCollection: _showCollectSheet,
            onViewFullDetails: null,
          ),
          const SizedBox(height: 12),
          if (customer.isLoyalty && _tiers != null && _loySettings != null)
            ..._buildMobileLoyaltySection(),
          if (_sales != null && _sales!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _mobileSectionTitle('Sales'),
            _simpleList(
              _sales!
                  .map((e) => _SimpleRow(
                        title:
                            (e['sale_number'] ?? e['number'] ?? '').toString(),
                        subtitle: (e['status'] ?? '').toString(),
                        trailing: (e['total_amount'] ?? 0).toString(),
                      ))
                  .toList(),
            ),
          ],
          if (_returns != null && _returns!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _mobileSectionTitle('Sale Returns'),
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
          if (_collections != null && _collections!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _mobileSectionTitle('Collections'),
            _simpleList(
              _collections!
                  .map((p) => _SimpleRow(
                        title: p.collectionNumber,
                        subtitle: p.collectionDate.toLocal().toString(),
                        trailing: p.amount.toStringAsFixed(2),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildMobileLoyaltySection() {
    if (_tiers == null ||
        _tiers!.isEmpty ||
        _loySettings == null ||
        _summary == null) {
      return const [];
    }

    final customer = _customer!;
    final tiers = _tiers!;
    final tierName = tiers
        .firstWhere(
          (t) => t.tierId == (customer.loyaltyTierId ?? -1),
          orElse: () => LoyaltyTierDto(
            tierId: -1,
            name: 'Member',
            minPoints: 0,
            isActive: true,
          ),
        )
        .name;
    final pts = _summary!.loyaltyPoints;
    final avail =
        (pts - _loySettings!.minPointsReserve).clamp(0.0, double.infinity);

    return [
      ProfessionalSummaryCard(
        title: 'Loyalty',
        rows: [
          (label: 'Tier', value: tierName, emphasize: true),
          (label: 'Points', value: pts.toStringAsFixed(0), emphasize: true),
          (
            label: 'Available',
            value: avail.toStringAsFixed(0),
            emphasize: false
          ),
        ],
      ),
    ];
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
