import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../core/outbox/outbox_notifier.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../../shared/widgets/app_scrollbar.dart';
import '../../../../shared/widgets/workbench_pane.dart';
import '../../../customers/data/customer_repository.dart';
import '../../../customers/data/models.dart';
import '../../../customers/presentation/widgets/customer_workbench_widgets.dart';
import '../../../customers/presentation/pages/customer_detail_page.dart';
import 'b2b_party_form_page.dart';

class B2BPartyManagementPage extends ConsumerStatefulWidget {
  const B2BPartyManagementPage({super.key});

  @override
  ConsumerState<B2BPartyManagementPage> createState() =>
      _B2BPartyManagementPageState();
}

class _B2BPartyManagementPageState
    extends ConsumerState<B2BPartyManagementPage> {
  bool _loading = true;
  bool _detailLoading = false;
  Object? _error;
  Object? _detailError;
  List<CustomerDto> _parties = const [];
  CustomerDto? _selectedParty;
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
      final items = await repo.getCustomers(customerType: 'B2B');
      if (!mounted) return;
      setState(() {
        _parties = items;
        if (_selectedParty != null &&
            !_parties.any((c) => c.customerId == _selectedParty!.customerId)) {
          _selectedParty = null;
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

  Future<void> _loadPartyDetail(int customerId,
      {bool clearCurrent = true}) async {
    final requestToken = ++_detailRequestToken;
    setState(() {
      _detailError = null;
      _detailLoading = true;
      if (clearCurrent || _selectedParty?.customerId != customerId) {
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
        _selectedParty = results[0] as CustomerDto;
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

  Future<void> _selectParty(CustomerDto party, {bool force = false}) async {
    final isDesktop = AppBreakpoints.isDesktop(context);
    if (!isDesktop) {
      final updated = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerDetailPage(customerId: party.customerId),
        ),
      );
      if (updated == true && mounted) {
        await _load(reset: true);
      }
      return;
    }

    final shouldLoad = force ||
        _selectedParty?.customerId != party.customerId ||
        _selectedSummary == null ||
        _detailError != null;
    if (!shouldLoad) {
      setState(() => _selectedParty = party);
      return;
    }
    await _loadPartyDetail(party.customerId);
  }

  Future<void> _refreshSelectedParty() async {
    final customerId = _selectedParty?.customerId;
    if (customerId == null) return;
    await _loadPartyDetail(customerId);
  }

  void _syncDesktopSelection(List<CustomerDto> filtered) {
    if (!AppBreakpoints.isDesktop(context)) return;

    // Compute a simple hash of the list to avoid repeated work
    final listHash = filtered.isEmpty
        ? 0
        : filtered.map((c) => c.customerId).reduce((a, b) => a ^ b).hashCode;
    final nextCustomerId = filtered.isEmpty ? null : filtered.first.customerId;

    // Skip if we already processed this exact list and customer
    if (listHash == _lastSyncedListHash &&
        nextCustomerId == _lastSyncedCustomerId) {
      return;
    }

    if (filtered.isEmpty) {
      _lastSyncedListHash = 0;
      _lastSyncedCustomerId = null;
      if (_selectedParty != null ||
          _selectedSummary != null ||
          _detailError != null ||
          _detailLoading) {
        setState(() {
          _selectedParty = null;
          _selectedSummary = null;
          _detailError = null;
          _detailLoading = false;
        });
      }
      return;
    }

    CustomerDto next = filtered.first;
    for (final c in filtered) {
      if (c.customerId == _selectedParty?.customerId) {
        next = c;
        break;
      }
    }

    final shouldReload = _selectedParty?.customerId != next.customerId ||
        (_selectedSummary == null && !_detailLoading && _detailError == null);
    if (shouldReload) {
      _lastSyncedListHash = listHash;
      _lastSyncedCustomerId = next.customerId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectParty(next);
        }
      });
    }
  }

  Future<void> _refresh() async {
    await _load(reset: true);
    if (mounted &&
        AppBreakpoints.isDesktop(context) &&
        _selectedParty != null) {
      await _refreshSelectedParty();
    }
  }

  Future<void> _openCreateDialog() async {
    final created = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const B2BPartyFormPage()),
    );
    if (created == true && mounted) await _refresh();
  }

  Future<void> _openDetailPage(int customerId) async {
    final updated = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerDetailPage(customerId: customerId),
      ),
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
        title: const Text('B2B Parties'),
        actions: [
          IconButton(
            tooltip: 'New B2B Party',
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
    if (_parties.isEmpty) return const [];
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _parties;
    return _parties.where((c) {
      final hay = [
        c.name,
        c.contactPerson ?? '',
        c.phone ?? '',
        c.email ?? '',
        c.taxNumber ?? '',
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
          hintText: 'Search B2B parties',
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
            hintText: 'Search B2B parties',
            prefixIcon: Icon(Icons.search_rounded),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => _load(reset: true),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const AppLoadingView(label: 'Loading B2B parties')
              : _error != null
                  ? AppErrorView(
                      error: _error!, onRetry: () => _load(reset: true))
                  : filtered.isEmpty
                      ? Center(
                          child: AppEmptyView(
                            title: 'No B2B parties found',
                            message: _searchCtrl.text.trim().isEmpty
                                ? 'B2B parties you create will appear here.'
                                : 'No B2B parties match your current search.',
                            icon: Icons.business_outlined,
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
                                  c.customerId == _selectedParty?.customerId;
                              return _B2BPartyListTile(
                                party: c,
                                isSelected: isSelected,
                                onTap: () => _selectParty(c),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildReviewPanel(BuildContext context, ThemeData theme) {
    if (_selectedParty == null && !_detailLoading) {
      return WorkbenchPane(
        title: 'B2B Party',
        subtitle: 'Select a B2B party from the queue to review',
        child: Center(
          child: AppEmptyView(
            title: 'No B2B party selected',
            message:
                'Choose a B2B party from the queue to view their details here.',
            icon: Icons.business_outlined,
          ),
        ),
      );
    }

    if (_detailLoading && _selectedSummary == null) {
      return WorkbenchPane(
        title: _selectedParty?.name ?? 'B2B Party',
        subtitle: 'Loading details...',
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_detailError != null) {
      return WorkbenchPane(
        title: _selectedParty?.name ?? 'B2B Party',
        subtitle: 'Error loading details',
        headerTrailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CustomerTypeBadge(customerType: 'B2B'),
            const SizedBox(width: 6),
            CustomerStatusBadge(isActive: _selectedParty?.isActive ?? true),
          ],
        ),
        child: AppErrorView(
          error: _detailError!,
          onRetry: _refreshSelectedParty,
        ),
      );
    }

    if (_selectedParty != null && _selectedSummary != null) {
      return WorkbenchPane(
        title: _selectedParty!.name,
        subtitle:
            'B2B • ID: #${_selectedParty!.customerId}',
        headerTrailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CustomerTypeBadge(customerType: 'B2B'),
            const SizedBox(width: 6),
            CustomerStatusBadge(isActive: _selectedParty!.isActive),
          ],
        ),
        child: CustomerReviewCard(
          customer: _selectedParty!,
          summary: _selectedSummary!,
          onEdit: () async {
            final updated = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    B2BPartyFormPage(customerId: _selectedParty!.customerId),
              ),
            );
            if (updated == true && mounted) {
              await _refresh();
            }
          },
          onRecordCollection: () =>
              _openDetailPage(_selectedParty!.customerId),
          onViewFullDetails: () async {
            final updated = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CustomerDetailPage(
                    customerId: _selectedParty!.customerId),
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
    if (_loading) return const AppLoadingView(label: 'Loading B2B parties');
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
            title: 'No B2B parties yet',
            message: 'B2B parties you create will appear here.',
            icon: Icons.business_outlined,
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
                'Credit Bal: ${c.creditBalance.toStringAsFixed(2)} • Limit: ${c.creditLimit.toStringAsFixed(2)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CustomerTypeBadge(customerType: 'B2B'),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              onTap: () => _selectParty(c),
            );
          },
        ),
      ),
    );
  }
}

class _B2BPartyListTile extends StatelessWidget {
  const _B2BPartyListTile({
    required this.party,
    required this.isSelected,
    required this.onTap,
  });

  final CustomerDto party;
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
                    party.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((party.contactPerson ?? '').isNotEmpty)
                    Text(
                      party.contactPerson!,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    party.creditBalance.toStringAsFixed(2),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  Text(
                    'Limit: ${party.creditLimit.toStringAsFixed(2)}',
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
            CustomerStatusBadge(isActive: party.isActive),
          ],
        ),
      ),
    );
  }
}
