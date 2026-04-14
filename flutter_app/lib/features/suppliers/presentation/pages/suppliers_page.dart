import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../data/models.dart';
import '../../data/supplier_repository.dart';
import '../../../../core/outbox/outbox_notifier.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../../shared/widgets/app_scrollbar.dart';
import '../../../../shared/widgets/workbench_pane.dart';
import '../widgets/supplier_workbench_widgets.dart';
import 'supplier_detail_page.dart';
import 'supplier_create_page.dart';
import 'supplier_edit_page.dart';
import 'supplier_balance_workbench_page.dart';

class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key});

  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
  bool _loading = true;
  bool _detailLoading = false;
  Object? _error;
  Object? _detailError;
  List<SupplierDto> _suppliers = const [];
  SupplierDto? _selectedSupplier;
  SupplierSummaryDto? _selectedSummary;
  final TextEditingController _searchCtrl = TextEditingController();

  int _detailRequestToken = 0;
  int? _lastSyncedListHash;
  int? _lastSyncedSupplierId;

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
      final repo = ref.read(supplierRepositoryProvider);
      final q = _searchCtrl.text.trim();
      final items = await repo.getSuppliers(
        search: q.isEmpty ? null : q,
      );
      if (!mounted) return;
      setState(() {
        _suppliers = items;
        if (_selectedSupplier != null &&
            !_suppliers
                .any((s) => s.supplierId == _selectedSupplier!.supplierId)) {
          _selectedSupplier = null;
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

  Future<void> _loadSupplierDetail(
    int supplierId, {
    bool clearCurrent = true,
  }) async {
    final requestToken = ++_detailRequestToken;
    setState(() {
      _detailError = null;
      _detailLoading = true;
      if (clearCurrent || _selectedSupplier?.supplierId != supplierId) {
        _selectedSummary = null;
      }
    });
    try {
      final repo = ref.read(supplierRepositoryProvider);
      final results = await Future.wait<dynamic>([
        repo.getSupplier(supplierId),
        repo.getSupplierSummary(supplierId),
      ]);
      if (!mounted || requestToken != _detailRequestToken) return;
      setState(() {
        _selectedSupplier = results[0] as SupplierDto;
        _selectedSummary = results[1] as SupplierSummaryDto;
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

  Future<void> _selectSupplier(
    SupplierDto supplier, {
    bool force = false,
  }) async {
    final isDesktop = AppBreakpoints.isDesktop(context);
    if (!isDesktop) {
      final updated = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SupplierDetailPage(supplierId: supplier.supplierId),
        ),
      );
      if (updated == true && mounted) {
        await _load(reset: true);
      }
      return;
    }

    final shouldLoad = force ||
        _selectedSupplier?.supplierId != supplier.supplierId ||
        _selectedSummary == null ||
        _detailError != null;
    if (!shouldLoad) {
      setState(() => _selectedSupplier = supplier);
      return;
    }
    await _loadSupplierDetail(supplier.supplierId);
  }

  Future<void> _refreshSelectedSupplier() async {
    final supplierId = _selectedSupplier?.supplierId;
    if (supplierId == null) return;
    await _loadSupplierDetail(supplierId);
  }

  void _syncDesktopSelection(List<SupplierDto> filtered) {
    if (!AppBreakpoints.isDesktop(context)) return;
    
    // Compute a simple hash of the list to avoid repeated work
    final listHash = filtered.isEmpty ? 0 : filtered.map((s) => s.supplierId).reduce((a, b) => a ^ b).hashCode;
    final nextSupplierId = filtered.isEmpty ? null : filtered.first.supplierId;
    
    // Skip if we already processed this exact list and supplier
    if (listHash == _lastSyncedListHash && nextSupplierId == _lastSyncedSupplierId) return;
    
    if (filtered.isEmpty) {
      _lastSyncedListHash = 0;
      _lastSyncedSupplierId = null;
      if (_selectedSupplier != null ||
          _selectedSummary != null ||
          _detailError != null ||
          _detailLoading) {
        setState(() {
          _selectedSupplier = null;
          _selectedSummary = null;
          _detailError = null;
          _detailLoading = false;
        });
      }
      return;
    }

    SupplierDto next = filtered.first;
    for (final s in filtered) {
      if (s.supplierId == _selectedSupplier?.supplierId) {
        next = s;
        break;
      }
    }

    final shouldReload = _selectedSupplier?.supplierId != next.supplierId ||
        (_selectedSummary == null && !_detailLoading && _detailError == null);
    if (shouldReload) {
      _lastSyncedListHash = listHash;
      _lastSyncedSupplierId = next.supplierId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectSupplier(next);
        }
      });
    }
  }

  Future<void> _refresh() async {
    await _load(reset: true);
    if (mounted &&
        AppBreakpoints.isDesktop(context) &&
        _selectedSupplier != null) {
      await _refreshSelectedSupplier();
    }
  }

  Future<void> _openCreateDialog() async {
    final created = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SupplierCreatePage()),
    );
    if (created == true && mounted) await _refresh();
  }

  Future<void> _openRecordPaymentSheet(int supplierId) async {
    final updated = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SupplierDetailPage(supplierId: supplierId),
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
    // list cards (outstanding amounts etc) don't stay stale.
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
        title: const Text('Suppliers'),
        actions: [
          IconButton(
            tooltip: 'Supplier balances',
            icon: const Icon(Icons.account_balance_wallet_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SupplierBalanceWorkbenchPage(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'New Supplier',
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

  List<SupplierDto> _filteredList() {
    if (_suppliers.isEmpty) return const [];
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _suppliers;
    return _suppliers.where((s) {
      final hay = [
        s.name,
        s.contactPerson ?? '',
        s.phone ?? '',
        s.email ?? '',
        s.usageLabel,
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
          hintText: 'Search suppliers',
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
    List<SupplierDto> filtered,
  ) {
    return Column(
      children: [
        TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Search suppliers',
            prefixIcon: Icon(Icons.search_rounded),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => _load(reset: true),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const AppLoadingView(label: 'Loading suppliers')
              : _error != null
                  ? AppErrorView(
                      error: _error!,
                      onRetry: () => _load(reset: true),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: AppEmptyView(
                            title: 'No suppliers found',
                            message: _searchCtrl.text.trim().isEmpty
                                ? 'Suppliers you create or sync will appear here.'
                                : 'No suppliers match your current search.',
                            icon: Icons.local_shipping_outlined,
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
                              final s = filtered[i];
                              final isSelected =
                                  s.supplierId == _selectedSupplier?.supplierId;
                              return _SupplierListTile(
                                supplier: s,
                                isSelected: isSelected,
                                onTap: () => _selectSupplier(s),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildReviewPanel(BuildContext context, ThemeData theme) {
    if (_selectedSupplier == null && !_detailLoading) {
      return WorkbenchPane(
        title: 'Supplier',
        subtitle: 'Select a supplier from the queue to review',
        child: Center(
          child: AppEmptyView(
            title: 'No supplier selected',
            message:
                'Choose a supplier from the queue to view their details here.',
            icon: Icons.local_shipping_outlined,
          ),
        ),
      );
    }

    if (_detailLoading && _selectedSummary == null) {
      return WorkbenchPane(
        title: _selectedSupplier?.name ?? 'Supplier',
        subtitle: 'Loading details...',
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_detailError != null) {
      return WorkbenchPane(
        title: _selectedSupplier?.name ?? 'Supplier',
        subtitle: 'Error loading details',
        headerTrailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SupplierTypeBadge(
              isMercantile: _selectedSupplier?.isMercantile ?? true,
              isNonMercantile: _selectedSupplier?.isNonMercantile ?? false,
            ),
            const SizedBox(width: 6),
            SupplierStatusBadge(isActive: _selectedSupplier?.isActive ?? true),
          ],
        ),
        child: AppErrorView(
          error: _detailError!,
          onRetry: _refreshSelectedSupplier,
        ),
      );
    }

    if (_selectedSupplier != null && _selectedSummary != null) {
      return WorkbenchPane(
        title: _selectedSupplier!.name,
        subtitle:
            '${_selectedSupplier!.usageLabel} • ID: #${_selectedSupplier!.supplierId}',
        headerTrailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SupplierTypeBadge(
              isMercantile: _selectedSupplier!.isMercantile,
              isNonMercantile: _selectedSupplier!.isNonMercantile,
            ),
            const SizedBox(width: 6),
            SupplierStatusBadge(isActive: _selectedSupplier!.isActive),
          ],
        ),
        child: SupplierReviewCard(
          supplier: _selectedSupplier!,
          summary: _selectedSummary!,
          onEdit: () async {
            final updated = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    SupplierEditPage(supplierId: _selectedSupplier!.supplierId),
              ),
            );
            if (updated == true && mounted) {
              await _refresh();
            }
          },
          onRecordPayment: () =>
              _openRecordPaymentSheet(_selectedSupplier!.supplierId),
          onViewFullDetails: () async {
            final updated = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SupplierDetailPage(
                    supplierId: _selectedSupplier!.supplierId),
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
    List<SupplierDto> filtered,
  ) {
    if (_loading) return const AppLoadingView(label: 'Loading suppliers');
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
            title: 'No suppliers yet',
            message: 'Suppliers you create or sync will appear here.',
            icon: Icons.local_shipping_outlined,
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
            final s = filtered[i];
            return ListTile(
              tileColor: theme.colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                s.name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${s.usageLabel} • Outstanding: ${s.outstandingAmount.toStringAsFixed(2)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SupplierTypeBadge(
                    isMercantile: s.isMercantile,
                    isNonMercantile: s.isNonMercantile,
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              onTap: () => _selectSupplier(s),
            );
          },
        ),
      ),
    );
  }
}

class _SupplierListTile extends StatelessWidget {
  const _SupplierListTile({
    required this.supplier,
    required this.isSelected,
    required this.onTap,
  });

  final SupplierDto supplier;
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
                    supplier.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((supplier.phone ?? '').isNotEmpty)
                    Text(
                      supplier.phone!,
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
              child: SupplierTypeBadge(
                isMercantile: supplier.isMercantile,
                isNonMercantile: supplier.isNonMercantile,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    supplier.outstandingAmount.toStringAsFixed(2),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  Text(
                    'Purchases: ${supplier.totalPurchases.toStringAsFixed(2)}',
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
            SupplierStatusBadge(isActive: supplier.isActive),
          ],
        ),
      ),
    );
  }
}
