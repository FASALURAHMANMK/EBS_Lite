import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../data/models.dart';
import '../../data/customer_repository.dart';
import '../../../../core/outbox/outbox_notifier.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../../shared/widgets/app_scrollbar.dart';
import '../../../../shared/widgets/workbench_pane.dart';
import '../widgets/customer_workbench_widgets.dart';
import '../widgets/quick_collection_sheet.dart';
import 'customer_detail_page.dart';
import 'customer_create_page.dart';
import 'customer_edit_page.dart';

class CustomerManagementPage extends ConsumerStatefulWidget {
  const CustomerManagementPage({super.key});

  @override
  ConsumerState<CustomerManagementPage> createState() =>
      _CustomerManagementPageState();
}

class _CustomerManagementPageState
    extends ConsumerState<CustomerManagementPage> {
  bool _loading = true;
  bool _detailLoading = false;
  Object? _error;
  Object? _detailError;
  List<CustomerDto> _customers = const [];
  CustomerDto? _selectedCustomer;
  CustomerSummaryDto? _selectedSummary;
  final TextEditingController _searchCtrl = TextEditingController();

  int _detailRequestToken = 0;
  int? _lastSyncedListHash;
  int? _lastSyncedCustomerId;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final repo = ref.read(customerRepositoryProvider);
      final q = _searchCtrl.text.trim();
      final items = await repo.getCustomers(
        search: q.isEmpty ? null : q,
      );
      // Exclude B2B customers (they have a dedicated page)
      final nonB2B = items.where((c) => c.customerType.toUpperCase() != 'B2B').toList();
      if (!mounted) return;
      setState(() {
        _customers = nonB2B;
        if (_selectedCustomer != null &&
            !_customers
                .any((c) => c.customerId == _selectedCustomer!.customerId)) {
          _selectedCustomer = null;
          _selectedSummary = null;
          _detailError = null;
          _detailLoading = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCustomerDetail(int customerId,
      {bool clearCurrent = true}) async {
    final requestToken = ++_detailRequestToken;
    setState(() {
      _detailError = null;
      _detailLoading = true;
      if (clearCurrent || _selectedCustomer?.customerId != customerId) {
        _selectedSummary = null;
      }
    });
    try {
      final repo = ref.read(customerRepositoryProvider);
      final results = await Future.wait<dynamic>([
        repo.getCustomer(customerId),
        repo.getCustomerSummary(customerId),
      ]);
      if (!mounted || requestToken != _detailRequestToken) return;
      setState(() {
        _selectedCustomer = results[0] as CustomerDto;
        _selectedSummary = results[1] as CustomerSummaryDto;
      });
    } catch (e) {
      if (!mounted || requestToken != _detailRequestToken) return;
      setState(() => _detailError = e);
    } finally {
      if (mounted && requestToken == _detailRequestToken) {
        setState(() => _detailLoading = false);
      }
    }
  }

  Future<void> _selectCustomer(CustomerDto customer,
      {bool force = false}) async {
    final isDesktop = AppBreakpoints.isDesktop(context);
    if (!isDesktop) {
      final updated = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerDetailPage(customerId: customer.customerId),
        ),
      );
      if (updated == true && mounted) {
        await _load(reset: true);
      }
      return;
    }

    final shouldLoad = force ||
        _selectedCustomer?.customerId != customer.customerId ||
        _selectedSummary == null ||
        _detailError != null;
    if (!shouldLoad) {
      setState(() => _selectedCustomer = customer);
      return;
    }
    await _loadCustomerDetail(customer.customerId);
  }

  Future<void> _refreshSelectedCustomer() async {
    final customerId = _selectedCustomer?.customerId;
    if (customerId == null) return;
    await _loadCustomerDetail(customerId);
  }

  void _syncDesktopSelection(List<CustomerDto> filtered) {
    if (!AppBreakpoints.isDesktop(context)) return;
    
    // Compute a simple hash of the list to avoid repeated work
    final listHash = filtered.isEmpty ? 0 : filtered.map((c) => c.customerId).reduce((a, b) => a ^ b).hashCode;
    final nextCustomerId = filtered.isEmpty ? null : filtered.first.customerId;
    
    // Skip if we already processed this exact list and customer
    if (listHash == _lastSyncedListHash && nextCustomerId == _lastSyncedCustomerId) return;
    
    if (filtered.isEmpty) {
      _lastSyncedListHash = 0;
      _lastSyncedCustomerId = null;
      if (_selectedCustomer != null ||
          _selectedSummary != null ||
          _detailError != null ||
          _detailLoading) {
        setState(() {
          _selectedCustomer = null;
          _selectedSummary = null;
          _detailError = null;
          _detailLoading = false;
        });
      }
      return;
    }

    CustomerDto next = filtered.first;
    for (final c in filtered) {
      if (c.customerId == _selectedCustomer?.customerId) {
        next = c;
        break;
      }
    }

    final shouldReload = _selectedCustomer?.customerId != next.customerId ||
        (_selectedSummary == null && !_detailLoading && _detailError == null);
    if (shouldReload) {
      _lastSyncedListHash = listHash;
      _lastSyncedCustomerId = next.customerId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectCustomer(next);
        }
      });
    }
  }

  Future<void> _refresh() async {
    await _load(reset: true);
    if (mounted &&
        AppBreakpoints.isDesktop(context) &&
        _selectedCustomer != null) {
      await _refreshSelectedCustomer();
    }
  }

  Future<void> _openCreateDialog() async {
    final created = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CustomerCreatePage()),
    );
    if (created == true && mounted) await _refresh();
  }

  Future<void> _openRecordCollectionSheet(int customerId) async {
    final detailPage = CustomerDetailPage(customerId: customerId);
    // We reuse the detail page's internal collection sheet by pushing the detail page.
    // For a more direct approach, we could extract the sheet, but this preserves the
    // existing pattern and gives the user the full detail+collection flow.
    final updated = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => detailPage),
    );
    if (updated == true && mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);

    // When queued transactions sync (or we regain online), refresh so
    // list cards (credit balances etc) don't stay stale.
    ref.listen(outboxNotifierProvider, (prev, next) {
      if (next.isOnline && next.lastSyncAt != prev?.lastSyncAt) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _refresh();
        });
      }
    });

    final theme = Theme.of(context);
    final filtered = _filteredList();
    _syncDesktopSelection(filtered);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isDesktop ? 104 : null,
        leading: isDesktop ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Customers'),
        actions: [
          if (!isDesktop)
            IconButton(
              tooltip: 'Quick Collection',
              icon: const Icon(Icons.payments_rounded),
              onPressed: () async {
                final done = await showQuickCollectionSheet(context, ref);
                if (done == true && mounted) await _refresh();
              },
            ),
          IconButton(
            tooltip: 'New Customer',
            icon: const Icon(Icons.add_rounded),
            onPressed: _openCreateDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: isDesktop
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildQueuePanel(context, theme, filtered),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: _buildReviewPanel(context, theme),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  _buildSearchBar(context),
                  Expanded(
                    child: _buildMobileList(context, theme, filtered),
                  ),
                ],
              ),
      ),
    );
  }

  List<CustomerDto> _filteredList() {
    if (_customers.isEmpty) return const [];
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _customers;
    return _customers.where((c) {
      final hay = [
        c.name,
        c.contactPerson ?? '',
        c.phone ?? '',
        c.email ?? '',
        c.customerType,
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchCtrl,
        decoration: const InputDecoration(
          hintText: 'Search customers',
          prefixIcon: Icon(Icons.search_rounded),
          border: OutlineInputBorder(),
        ),
        onChanged: (_) => _load(reset: true),
      ),
    );
  }

  Widget _buildQueuePanel(
    BuildContext context,
    ThemeData theme,
    List<CustomerDto> filtered,
  ) {
    return Column(
      children: [
        TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Search customers',
            prefixIcon: Icon(Icons.search_rounded),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => _load(reset: true),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const AppLoadingView(label: 'Loading customers')
              : _error != null
                  ? AppErrorView(
                      error: _error!, onRetry: () => _load(reset: true))
                  : filtered.isEmpty
                      ? Center(
                          child: AppEmptyView(
                            title: 'No customers found',
                            message: _searchCtrl.text.trim().isEmpty
                                ? 'Customers you create or sync will appear here.'
                                : 'No customers match your current search.',
                            icon: Icons.people_outline_rounded,
                          ),
                        )
                      : AppScrollbar(
                          builder: (context, scrollController) =>
                              ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.only(right: 4),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, i) {
                              final c = filtered[i];
                              final isSelected =
                                  c.customerId == _selectedCustomer?.customerId;
                              return _CustomerListTile(
                                customer: c,
                                isSelected: isSelected,
                                onTap: () => _selectCustomer(c),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildReviewPanel(BuildContext context, ThemeData theme) {
    if (_selectedCustomer == null && !_detailLoading) {
      return WorkbenchPane(
        title: 'Customer',
        subtitle: 'Select a customer from the queue to review',
        child: Center(
          child: AppEmptyView(
            title: 'No customer selected',
            message:
                'Choose a customer from the queue to view their details here.',
            icon: Icons.person_outline_rounded,
          ),
        ),
      );
    }

    if (_detailLoading && _selectedSummary == null) {
      return WorkbenchPane(
        title: _selectedCustomer?.name ?? 'Customer',
        subtitle: 'Loading details...',
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_detailError != null) {
      return WorkbenchPane(
        title: _selectedCustomer?.name ?? 'Customer',
        subtitle: 'Error loading details',
        headerTrailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomerTypeBadge(
                customerType: _selectedCustomer?.customerType ?? ''),
            const SizedBox(width: 6),
            CustomerStatusBadge(isActive: _selectedCustomer?.isActive ?? true),
          ],
        ),
        child: AppErrorView(
          error: _detailError!,
          onRetry: _refreshSelectedCustomer,
        ),
      );
    }

    if (_selectedCustomer != null && _selectedSummary != null) {
      return WorkbenchPane(
        title: _selectedCustomer!.name,
        subtitle:
            '${_selectedCustomer!.customerType} • ID: #${_selectedCustomer!.customerId}',
        headerTrailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomerTypeBadge(customerType: _selectedCustomer!.customerType),
            const SizedBox(width: 6),
            CustomerStatusBadge(isActive: _selectedCustomer!.isActive),
          ],
        ),
        child: CustomerReviewCard(
          customer: _selectedCustomer!,
          summary: _selectedSummary!,
          onEdit: () async {
            final updated = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    CustomerEditPage(customerId: _selectedCustomer!.customerId),
              ),
            );
            if (updated == true && mounted) {
              await _refresh();
            }
          },
          onRecordCollection: () =>
              _openRecordCollectionSheet(_selectedCustomer!.customerId),
          onViewFullDetails: () async {
            final updated = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CustomerDetailPage(
                    customerId: _selectedCustomer!.customerId),
              ),
            );
            if (updated == true && mounted) {
              await _refresh();
            }
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMobileList(
    BuildContext context,
    ThemeData theme,
    List<CustomerDto> filtered,
  ) {
    if (_loading) return const AppLoadingView(label: 'Loading customers');
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 64),
          AppErrorView(error: _error!, onRetry: () => _load(reset: true)),
        ],
      );
    }
    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 64),
          AppEmptyView(
            title: 'No customers yet',
            message: 'Customers you create or sync will appear here.',
            icon: Icons.people_outline_rounded,
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: AppScrollbar(
        builder: (context, scrollController) => ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final c = filtered[i];
            return ListTile(
              tileColor: theme.colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                c.name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${c.customerType} • Credit Bal: ${c.creditBalance.toStringAsFixed(2)} • Limit: ${c.creditLimit.toStringAsFixed(2)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomerTypeBadge(customerType: c.customerType),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              onTap: () => _selectCustomer(c),
            );
          },
        ),
      ),
    );
  }
}

class _CustomerListTile extends StatelessWidget {
  const _CustomerListTile({
    required this.customer,
    required this.isSelected,
    required this.onTap,
  });

  final CustomerDto customer;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: theme.colorScheme.secondary, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((customer.phone ?? '').isNotEmpty)
                    Text(
                      customer.phone!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: CustomerTypeBadge(customerType: customer.customerType),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    customer.creditBalance.toStringAsFixed(2),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  Text(
                    'Limit: ${customer.creditLimit.toStringAsFixed(2)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CustomerStatusBadge(isActive: customer.isActive),
          ],
        ),
      ),
    );
  }
}
