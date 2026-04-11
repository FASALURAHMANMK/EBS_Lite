import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../../shared/widgets/app_scrollbar.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../../../shared/widgets/workbench_pane.dart';
import '../../../dashboard/presentation/widgets/dashboard_sidebar.dart';
import '../../data/accounts_repository.dart';
import '../../data/models.dart';
import '../widgets/accounts_workbench_widgets.dart';

class ChartOfAccountsPage extends ConsumerStatefulWidget {
  const ChartOfAccountsPage({
    super.key,
    this.fromMenu = false,
    this.onMenuSelect,
  });

  final bool fromMenu;
  final void Function(BuildContext context, String label)? onMenuSelect;

  @override
  ConsumerState<ChartOfAccountsPage> createState() =>
      _ChartOfAccountsPageState();
}

class _ChartOfAccountsPageState extends ConsumerState<ChartOfAccountsPage> {
  bool _loading = true;
  Object? _error;
  bool _includeInactive = false;
  List<ChartOfAccountDto> _accounts = const [];
  final TextEditingController _searchCtrl = TextEditingController();
  int? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref
          .read(accountsRepositoryProvider)
          .getChartOfAccounts(includeInactive: _includeInactive);
      if (!mounted) return;
      setState(() {
        _accounts = items;
        if (_selectedAccountId != null &&
            !_accounts.any((item) => item.accountId == _selectedAccountId)) {
          _selectedAccountId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _syncDesktopSelection(List<ChartOfAccountDto> filtered) {
    if (!AppBreakpoints.isDesktop(context)) return;
    if (filtered.isEmpty) {
      if (_selectedAccountId != null) {
        setState(() => _selectedAccountId = null);
      }
      return;
    }

    final isCurrentVisible =
        filtered.any((item) => item.accountId == _selectedAccountId);
    if (!isCurrentVisible) {
      setState(() => _selectedAccountId = filtered.first.accountId);
    }
  }

  Future<void> _openAccountDialog({
    ChartOfAccountDto? existing,
    int? suggestedParentId,
  }) async {
    final parents =
        _accounts.where((e) => e.accountId != existing?.accountId).toList();
    final codeCtrl = TextEditingController(text: existing?.accountCode ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final subtypeCtrl = TextEditingController(text: existing?.subtype ?? '');
    var type = existing?.type ?? 'ASSET';
    var parentId = existing?.parentId ?? suggestedParentId;
    var isActive = existing?.isActive ?? true;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setInner) => AlertDialog(
            title: Text(existing == null ? 'Add Account' : 'Edit Account'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Account Code'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Account Name'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(value: 'ASSET', child: Text('Asset')),
                        DropdownMenuItem(
                          value: 'LIABILITY',
                          child: Text('Liability'),
                        ),
                        DropdownMenuItem(
                          value: 'EQUITY',
                          child: Text('Equity'),
                        ),
                        DropdownMenuItem(
                          value: 'REVENUE',
                          child: Text('Revenue'),
                        ),
                        DropdownMenuItem(
                          value: 'EXPENSE',
                          child: Text('Expense'),
                        ),
                      ],
                      onChanged: (value) =>
                          setInner(() => type = value ?? type),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: subtypeCtrl,
                      decoration: const InputDecoration(labelText: 'Subtype'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int?>(
                      initialValue: parentId,
                      decoration:
                          const InputDecoration(labelText: 'Parent Account'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('No parent'),
                        ),
                        ...parents.map(
                          (item) => DropdownMenuItem<int?>(
                            value: item.accountId,
                            child: Text(
                              formatAccountDisplayTitle(
                                accountCode: item.accountCode,
                                accountName: item.name,
                                accountId: item.accountId,
                              ),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => setInner(() => parentId = value),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: isActive,
                      onChanged: (value) => setInner(() => isActive = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );

      if (saved != true || !mounted) return;

      final repo = ref.read(accountsRepositoryProvider);
      try {
        if (existing == null) {
          await repo.createChartOfAccount(
            accountCode: codeCtrl.text,
            name: nameCtrl.text,
            type: type,
            subtype: subtypeCtrl.text,
            parentId: parentId,
            isActive: isActive,
          );
        } else {
          await repo.updateChartOfAccount(
            accountId: existing.accountId,
            accountCode: codeCtrl.text,
            name: nameCtrl.text,
            type: type,
            subtype: subtypeCtrl.text,
            parentId: parentId,
            isActive: isActive,
          );
        }
        await _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.message(e))),
        );
      }
    } finally {
      codeCtrl.dispose();
      nameCtrl.dispose();
      subtypeCtrl.dispose();
    }
  }

  String _parentLabel(ChartOfAccountDto item) {
    return formatAccountDisplayTitle(
      accountCode: item.parentCode,
      accountName: item.parentName,
      accountId: item.parentId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final query = _searchCtrl.text.trim().toLowerCase();
    final items = query.isEmpty
        ? _accounts
        : _accounts.where((item) {
            final haystack = [
              item.accountId.toString(),
              item.accountCode ?? '',
              item.name,
              item.type,
              item.subtype ?? '',
              item.parentCode ?? '',
              item.parentName ?? '',
            ].join(' ').toLowerCase();
            return haystack.contains(query);
          }).toList();
    final selectedAccount = items.cast<ChartOfAccountDto?>().firstWhere(
          (item) => item?.accountId == _selectedAccountId,
          orElse: () => _accounts.cast<ChartOfAccountDto?>().firstWhere(
                (item) => item?.accountId == _selectedAccountId,
                orElse: () => null,
              ),
        );
    if (isDesktop && !_loading && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncDesktopSelection(items);
        }
      });
    }

    final scaffold = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.fromMenu,
        leadingWidth: (!widget.fromMenu && isWide) ? 104 : null,
        leading: widget.fromMenu
            ? Builder(
                builder: (context) => IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : (isWide ? const DesktopSidebarToggleLeading() : null),
        title: const Text('Chart of Accounts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      drawer: widget.fromMenu
          ? DashboardSidebar(
              onSelect: (label) => widget.onMenuSelect?.call(context, label),
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAccountDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Account'),
      ),
      body: SafeArea(
        child: _loading
            ? const AppLoadingView(label: 'Loading chart of accounts')
            : _error != null
                ? AppErrorView(error: _error!, onRetry: _load)
                : (isDesktop
                    ? _buildDesktopBody(
                        filtered: items,
                        selectedAccount: selectedAccount,
                      )
                    : _buildMobileBody(items)),
      ),
    );

    if (!widget.fromMenu) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }

  Widget _buildDesktopBody({
    required List<ChartOfAccountDto> filtered,
    required ChartOfAccountDto? selectedAccount,
  }) {
    final inactiveCount = filtered.where((item) => !item.isActive).length;
    final rootCount = filtered.where((item) => item.parentId == null).length;
    final childCount = selectedAccount == null
        ? 0
        : _accounts
            .where((item) => item.parentId == selectedAccount.accountId)
            .length;

    return Padding(
      padding: AppBreakpoints.pagePadding(context),
      child: Column(
        children: [
          ProfessionalDocumentHeader(
            title: 'Chart of Accounts Workbench',
            subtitle:
                'Desktop users can keep the full account queue visible while reviewing hierarchy, balance posture, and maintenance actions in the adjacent pane.',
            badges: [
              ProfessionalBadge(label: '${filtered.length} visible'),
              ProfessionalBadge(label: '$rootCount root accounts'),
              ProfessionalBadge(
                label: '$inactiveCount inactive',
                backgroundColor: const Color(0xFFFFE4D6),
                foregroundColor: const Color(0xFF7A3715),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ProfessionalSummaryCard(
                  title: 'Workbench flow',
                  rows: [
                    (
                      label: 'Selected account',
                      value: selectedAccount == null
                          ? 'None'
                          : formatAccountDisplayTitle(
                              accountCode: selectedAccount.accountCode,
                              accountName: selectedAccount.name,
                              accountId: selectedAccount.accountId,
                            ),
                      emphasize: true,
                    ),
                    (
                      label: 'Visible queue',
                      value: '${filtered.length}',
                      emphasize: false,
                    ),
                    (
                      label: 'Child accounts',
                      value: '$childCount',
                      emphasize: false,
                    ),
                    (
                      label: 'Mobile behavior',
                      value: 'Stacked list with dialog edit',
                      emphasize: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ProfessionalSectionCard(
                  title: 'Review focus',
                  subtitle:
                      'Use the queue to pin an account, then maintain parent-child structure without losing desktop context.',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _openAccountDialog(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add root account'),
                      ),
                      OutlinedButton.icon(
                        onPressed: selectedAccount == null
                            ? null
                            : () => _openAccountDialog(
                                  suggestedParentId: selectedAccount.accountId,
                                ),
                        icon: const Icon(Icons.account_tree_rounded),
                        label: const Text('Add child'),
                      ),
                      TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh queue'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: WorkbenchPane(
                    title: 'Account queue',
                    subtitle:
                        'Search by code, name, type, subtype, parent, or ID and keep the selected account pinned beside the queue.',
                    headerTrailing: IconButton(
                      tooltip: 'Refresh chart',
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: const InputDecoration(
                              hintText:
                                  'Search code, name, type, subtype, or ID',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FilterChip(
                              label: const Text('Show inactive'),
                              selected: _includeInactive,
                              onSelected: (value) async {
                                setState(() => _includeInactive = value);
                                await _load();
                              },
                            ),
                          ),
                        ),
                        Expanded(
                          child: filtered.isEmpty
                              ? const AppEmptyView(
                                  title: 'No accounts found',
                                  message:
                                      'Accounts matching the current search and status filter will appear here.',
                                  icon: Icons.account_tree_outlined,
                                )
                              : AppScrollbar(
                                  builder: (context, controller) =>
                                      ListView.separated(
                                    controller: controller,
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 4, 12, 12),
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final item = filtered[index];
                                      final isSelected =
                                          item.accountId == _selectedAccountId;
                                      final meta = <String>[
                                        if ((item.subtype ?? '')
                                            .trim()
                                            .isNotEmpty)
                                          item.subtype!.trim(),
                                        'Balance ${(item.currentBalance ?? 0).toStringAsFixed(2)}',
                                        if (item.parentId == null)
                                          'Root account'
                                        else
                                          'Parent ${_parentLabel(item)}',
                                      ];
                                      return Card(
                                        elevation: 0,
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primaryContainer
                                                .withValues(alpha: 0.35)
                                            : null,
                                        child: ListTile(
                                          selected: isSelected,
                                          leading: Icon(
                                            Icons.account_tree_rounded,
                                            color: isSelected
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : null,
                                          ),
                                          title: Text(
                                            formatAccountDisplayTitle(
                                              accountCode: item.accountCode,
                                              accountName: item.name,
                                              accountId: item.accountId,
                                            ),
                                          ),
                                          subtitle: Padding(
                                            padding:
                                                const EdgeInsets.only(top: 6),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(meta.join(' • ')),
                                                const SizedBox(height: 6),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: [
                                                    AccountTypeBadge(
                                                      type: item.type,
                                                    ),
                                                    AccountStatusBadge(
                                                      isActive: item.isActive,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          trailing: IconButton(
                                            tooltip: 'Edit account',
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                            onPressed: () => _openAccountDialog(
                                              existing: item,
                                            ),
                                          ),
                                          onTap: () => setState(
                                            () => _selectedAccountId =
                                                item.accountId,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: WorkbenchPane(
                    title: 'Account review',
                    subtitle:
                        'Review selected account structure, status, and balance without losing queue context.',
                    headerTrailing: IconButton(
                      tooltip: 'Refresh chart',
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    child: _buildDesktopDetailContent(selectedAccount),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDetailContent(ChartOfAccountDto? selectedAccount) {
    if (selectedAccount == null) {
      return const AppEmptyView(
        title: 'Choose an account',
        message:
            'Select an account from the queue to review hierarchy, status, and maintenance actions.',
        icon: Icons.account_tree_outlined,
      );
    }

    final children = _accounts
        .where((item) => item.parentId == selectedAccount.accountId)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final siblings = selectedAccount.parentId == null
        ? _accounts
            .where((item) => item.parentId == null)
            .where((item) => item.accountId != selectedAccount.accountId)
            .length
        : _accounts
            .where((item) => item.parentId == selectedAccount.parentId)
            .where((item) => item.accountId != selectedAccount.accountId)
            .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ProfessionalDocumentHeader(
          title: formatAccountDisplayTitle(
            accountCode: selectedAccount.accountCode,
            accountName: selectedAccount.name,
            accountId: selectedAccount.accountId,
          ),
          subtitle:
              'Keep the chart queue visible while reviewing structure, status, and current balance for the selected account.',
          badges: [
            ProfessionalBadge(label: 'Acct #${selectedAccount.accountId}'),
            AccountTypeBadge(type: selectedAccount.type),
            AccountStatusBadge(isActive: selectedAccount.isActive),
            ProfessionalBadge(
              label: selectedAccount.parentId == null
                  ? 'Root account'
                  : 'Child account',
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!selectedAccount.isActive) ...[
          const ProfessionalBanner(
            message:
                'This account is inactive. Review child-account structure and downstream usage before reactivating or re-parenting it.',
            color: Color(0xFFFFF0D8),
          ),
          const SizedBox(height: 16),
        ],
        ProfessionalSummaryCard(
          title: 'Account snapshot',
          rows: [
            (
              label: 'Account code',
              value: (selectedAccount.accountCode ?? '').trim().isEmpty
                  ? 'Not set'
                  : selectedAccount.accountCode!.trim(),
              emphasize: true,
            ),
            (
              label: 'Subtype',
              value: (selectedAccount.subtype ?? '').trim().isEmpty
                  ? 'Not set'
                  : selectedAccount.subtype!.trim(),
              emphasize: false,
            ),
            (
              label: 'Current balance',
              value: (selectedAccount.currentBalance ?? 0).toStringAsFixed(2),
              emphasize: false,
            ),
            (
              label: 'Parent account',
              value: selectedAccount.parentId == null
                  ? 'None'
                  : _parentLabel(selectedAccount),
              emphasize: false,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ProfessionalSectionCard(
          title: 'Hierarchy context',
          subtitle:
              'Understand where this account sits before changing parentage or adding child accounts.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AccountInfoRow(
                label: 'Role in chart',
                value: selectedAccount.parentId == null
                    ? 'Top-level account'
                    : 'Nested under ${_parentLabel(selectedAccount)}',
              ),
              const SizedBox(height: 10),
              _AccountInfoRow(
                label: 'Sibling accounts',
                value: '$siblings',
              ),
              const SizedBox(height: 10),
              _AccountInfoRow(
                label: 'Child accounts',
                value: '${children.length}',
              ),
              const SizedBox(height: 14),
              if (children.isEmpty)
                Text(
                  'No child accounts are currently attached.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: children
                      .map(
                        (child) => ProfessionalBadge(
                          label: formatAccountDisplayTitle(
                            accountCode: child.accountCode,
                            accountName: child.name,
                            accountId: child.accountId,
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ProfessionalSectionCard(
          title: 'Next actions',
          subtitle:
              'Stay in the desktop workbench while maintaining the selected account structure.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _openAccountDialog(existing: selectedAccount),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit account'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openAccountDialog(
                  suggestedParentId: selectedAccount.accountId,
                ),
                icon: const Icon(Icons.account_tree_rounded),
                label: const Text('Add child account'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openAccountDialog(
                  suggestedParentId: selectedAccount.parentId,
                ),
                icon: const Icon(Icons.call_split_rounded),
                label: Text(
                  selectedAccount.parentId == null
                      ? 'Add another root account'
                      : 'Add sibling account',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBody(List<ChartOfAccountDto> items) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search code, name, type, subtype',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Show inactive'),
                selected: _includeInactive,
                onSelected: (value) async {
                  setState(() => _includeInactive = value);
                  await _load();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const AppEmptyView(
                  title: 'No accounts found',
                  message:
                      'Create account groups and ledgers to strengthen the accounting structure.',
                  icon: Icons.account_tree_outlined,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final summary = <String>[
                      item.type,
                      if ((item.subtype ?? '').isNotEmpty) item.subtype!,
                      if ((item.parentName ?? '').isNotEmpty)
                        'Parent ${item.parentName}',
                      'Balance ${(item.currentBalance ?? 0).toStringAsFixed(2)}',
                      if (!item.isActive) 'Inactive',
                    ];
                    return Card(
                      elevation: 0,
                      child: ListTile(
                        leading: const Icon(Icons.account_tree_rounded),
                        title: Text(
                          formatAccountDisplayTitle(
                            accountCode: item.accountCode,
                            accountName: item.name,
                            accountId: item.accountId,
                          ),
                        ),
                        subtitle: Text(summary.join(' • ')),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openAccountDialog(existing: item),
                        ),
                        onTap: () => _openAccountDialog(existing: item),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AccountInfoRow extends StatelessWidget {
  const _AccountInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
