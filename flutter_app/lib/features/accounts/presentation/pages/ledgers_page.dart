import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/app_date_time.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../core/locale_preferences.dart';
import '../../data/accounts_repository.dart';
import '../../data/models.dart';
import '../../../dashboard/presentation/widgets/dashboard_sidebar.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../../shared/widgets/app_scrollbar.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../../../shared/widgets/workbench_pane.dart';
import 'ledger_entries_page.dart';
import '../widgets/accounts_workbench_widgets.dart';

class LedgersPage extends ConsumerStatefulWidget {
  const LedgersPage({
    super.key,
    this.fromMenu = false,
    this.onMenuSelect,
  });

  final bool fromMenu;
  final void Function(BuildContext context, String label)? onMenuSelect;

  @override
  ConsumerState<LedgersPage> createState() => _LedgersPageState();
}

class _LedgersPageState extends ConsumerState<LedgersPage> {
  bool _loading = true;
  bool _detailLoading = false;
  bool _detailLoadingMore = false;
  Object? _error;
  Object? _detailError;
  List<LedgerBalanceDto> _balances = const [];
  List<LedgerEntryDto> _selectedEntries = const [];
  final TextEditingController _search = TextEditingController();
  int? _selectedAccountId;
  LedgerBalanceDto? _selectedBalance;
  int _detailPage = 1;
  int _detailTotalPages = 1;
  int _detailRequestToken = 0;
  final int _detailPerPage = 20;
  DateTime? _detailFromDate;
  DateTime? _detailToDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(accountsRepositoryProvider);
      final list = await repo.getLedgerBalances();
      if (!mounted) return;
      setState(() {
        _balances = list;
        if (_selectedAccountId != null) {
          for (final balance in list) {
            if (balance.accountId == _selectedAccountId) {
              _selectedBalance = balance;
              break;
            }
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncDesktopSelection(List<LedgerBalanceDto> filtered) async {
    if (!AppBreakpoints.isDesktop(context)) return;
    if (filtered.isEmpty) {
      if (!mounted) return;
      setState(() {
        _selectedAccountId = null;
        _selectedBalance = null;
        _selectedEntries = const [];
        _detailError = null;
        _detailLoading = false;
        _detailLoadingMore = false;
        _detailPage = 1;
        _detailTotalPages = 1;
      });
      return;
    }

    LedgerBalanceDto next = filtered.first;
    for (final balance in filtered) {
      if (balance.accountId == _selectedAccountId) {
        next = balance;
        break;
      }
    }

    final shouldReload = _selectedAccountId != next.accountId ||
        (_selectedEntries.isEmpty &&
            !_detailLoading &&
            !_detailLoadingMore &&
            _detailError == null);
    if (shouldReload) {
      await _selectLedger(next);
      return;
    }
    if (_selectedBalance?.accountId != next.accountId ||
        _selectedBalance?.balance != next.balance ||
        _selectedBalance?.accountName != next.accountName ||
        _selectedBalance?.accountCode != next.accountCode ||
        _selectedBalance?.accountType != next.accountType) {
      if (!mounted) return;
      setState(() => _selectedBalance = next);
    }
  }

  Future<void> _selectLedger(
    LedgerBalanceDto balance, {
    bool reset = true,
  }) async {
    final requestToken = ++_detailRequestToken;
    setState(() {
      _selectedAccountId = balance.accountId;
      _selectedBalance = balance;
      _detailError = null;
      if (reset) {
        _detailLoading = true;
        _detailLoadingMore = false;
        _detailPage = 1;
        _selectedEntries = const [];
      } else {
        _detailLoadingMore = true;
      }
    });
    try {
      final repo = ref.read(accountsRepositoryProvider);
      final page = reset ? 1 : _detailPage + 1;
      final result = await repo.getLedgerEntries(
        accountId: balance.accountId,
        dateFrom: _detailFromDate,
        dateTo: _detailToDate,
        page: page,
        perPage: _detailPerPage,
      );
      if (!mounted || requestToken != _detailRequestToken) return;
      setState(() {
        _detailPage = page;
        _detailTotalPages = result.meta?.totalPages ?? 1;
        _selectedEntries =
            reset ? result.items : [..._selectedEntries, ...result.items];
      });
    } catch (e) {
      if (!mounted || requestToken != _detailRequestToken) return;
      setState(() => _detailError = e);
    } finally {
      if (mounted && requestToken == _detailRequestToken) {
        setState(() {
          _detailLoading = false;
          _detailLoadingMore = false;
        });
      }
    }
  }

  Future<void> _reloadSelectedLedger() async {
    final balance = _selectedBalance;
    if (balance == null) return;
    await _selectLedger(balance);
  }

  Future<void> _pickDetailDate({required bool from}) async {
    final initial = from ? _detailFromDate : _detailToDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _detailFromDate = picked;
      } else {
        _detailToDate = picked;
      }
    });
    await _reloadSelectedLedger();
  }

  Future<void> _clearDetailDateFilters() async {
    if (_detailFromDate == null && _detailToDate == null) return;
    setState(() {
      _detailFromDate = null;
      _detailToDate = null;
    });
    await _reloadSelectedLedger();
  }

  Future<void> _openLedgerEntries(LedgerBalanceDto balance) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LedgerEntriesPage(
          accountId: balance.accountId,
          accountCode: balance.accountCode,
          accountName: balance.accountName,
          accountType: balance.accountType,
          currentBalance: balance.balance,
        ),
      ),
    );
    await _load();
  }

  String _ledgerTitle(LedgerBalanceDto balance) {
    final parts = <String>[
      if ((balance.accountCode ?? '').trim().isNotEmpty) balance.accountCode!,
      if ((balance.accountName ?? '').trim().isNotEmpty) balance.accountName!,
    ];
    return parts.isEmpty ? 'Account #${balance.accountId}' : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final localePrefs = ref.watch(localePreferencesProvider);
    final query = _search.text.trim();
    final lower = query.toLowerCase();
    final filtered = query.isEmpty
        ? _balances
        : _balances.where((b) {
            if (b.accountId.toString().contains(query)) return true;
            final code = (b.accountCode ?? '').toLowerCase();
            final name = (b.accountName ?? '').toLowerCase();
            final type = (b.accountType ?? '').toLowerCase();
            return code.contains(lower) ||
                name.contains(lower) ||
                type.contains(lower);
          }).toList();
    if (isDesktop && !_loading && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncDesktopSelection(filtered);
        }
      });
    }
    String dateLabel(DateTime? date) => date == null
        ? 'Any'
        : AppDateTime.formatDate(context, localePrefs, date);

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
        title: const Text('Ledgers'),
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
      body: SafeArea(
        child: _loading
            ? const AppLoadingView(label: 'Loading ledger balances')
            : _error != null
                ? AppErrorView(error: _error!, onRetry: _load)
                : (isDesktop
                    ? _buildDesktopBody(filtered, localePrefs, dateLabel)
                    : _buildMobileBody(filtered)),
      ),
    );

    if (!widget.fromMenu) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }

  Widget _buildDesktopBody(
    List<LedgerBalanceDto> filtered,
    LocalePreferencesState localePrefs,
    String Function(DateTime? date) dateLabel,
  ) {
    final positiveBalances = filtered.where((item) => item.balance > 0).length;
    final negativeBalances = filtered.where((item) => item.balance < 0).length;
    final selectedBalance = _selectedBalance;
    final linkedEntries = _selectedEntries
        .where((entry) =>
            entry.voucher != null ||
            entry.sale != null ||
            entry.purchase != null)
        .length;

    return Padding(
      padding: AppBreakpoints.pagePadding(context),
      child: Column(
        children: [
          ProfessionalDocumentHeader(
            title: 'Ledger Workbench',
            subtitle:
                'Desktop users keep the full ledger queue visible while reviewing account movement, linked documents, and date-filtered activity.',
            badges: [
              ProfessionalBadge(label: '${filtered.length} visible'),
              ProfessionalBadge(label: '$positiveBalances positive'),
              ProfessionalBadge(
                label: '$negativeBalances negative',
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
                      label: 'Selected ledger',
                      value: selectedBalance == null
                          ? 'None'
                          : _ledgerTitle(selectedBalance),
                      emphasize: true,
                    ),
                    (
                      label: 'Visible queue',
                      value: '${filtered.length}',
                      emphasize: false,
                    ),
                    (
                      label: 'Linked entry refs',
                      value: '$linkedEntries',
                      emphasize: false,
                    ),
                    (
                      label: 'Mobile behavior',
                      value: 'Stacked route to detail',
                      emphasize: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ProfessionalSectionCard(
                  title: 'Review controls',
                  subtitle:
                      'Apply an entry date window without leaving the desktop queue.',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: selectedBalance == null
                            ? null
                            : () => _pickDetailDate(from: true),
                        icon: const Icon(Icons.event_rounded),
                        label: Text('From: ${dateLabel(_detailFromDate)}'),
                      ),
                      OutlinedButton.icon(
                        onPressed: selectedBalance == null
                            ? null
                            : () => _pickDetailDate(from: false),
                        icon: const Icon(Icons.event_available_rounded),
                        label: Text('To: ${dateLabel(_detailToDate)}'),
                      ),
                      TextButton.icon(
                        onPressed: selectedBalance == null
                            ? null
                            : _clearDetailDateFilters,
                        icon: const Icon(Icons.filter_alt_off_rounded),
                        label: const Text('Clear dates'),
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
                    title: 'Ledger balances',
                    subtitle:
                        'Search by account code, name, type, or ID and keep a selected account pinned in the adjacent review pane.',
                    headerTrailing: IconButton(
                      tooltip: 'Refresh ledgers',
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: TextField(
                            controller: _search,
                            decoration: const InputDecoration(
                              hintText: 'Search code, name, type, or ID',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        Expanded(
                          child: filtered.isEmpty
                              ? const AppEmptyView(
                                  title: 'No ledger balances found',
                                  message:
                                      'Ledger balances matching the current search will appear here.',
                                  icon: Icons.menu_book_outlined,
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
                                      final balance = filtered[index];
                                      final isSelected = balance.accountId ==
                                          _selectedAccountId;
                                      final title = _ledgerTitle(balance);
                                      final type =
                                          (balance.accountType ?? '').trim();
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
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 4,
                                          ),
                                          leading: Icon(
                                            Icons.menu_book_rounded,
                                            color: isSelected
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : null,
                                          ),
                                          title: Text(title),
                                          subtitle: Text(
                                            [
                                              if (type.isNotEmpty) type,
                                              'Acct #${balance.accountId}',
                                            ].join(' • '),
                                          ),
                                          trailing: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                balance.balance
                                                    .toStringAsFixed(2),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Text('Current balance'),
                                            ],
                                          ),
                                          onTap: () => _selectLedger(balance),
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
                    title: 'Ledger review',
                    subtitle:
                        'Selected account detail stays visible so desktop users do not lose queue context while reviewing movement.',
                    headerTrailing: IconButton(
                      tooltip: 'Refresh selected ledger',
                      onPressed: selectedBalance == null
                          ? null
                          : _reloadSelectedLedger,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    child: _buildDesktopDetailContent(
                      localePrefs: localePrefs,
                      dateLabel: dateLabel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDetailContent({
    required LocalePreferencesState localePrefs,
    required String Function(DateTime? date) dateLabel,
  }) {
    final balance = _selectedBalance;
    if (balance == null) {
      return const AppEmptyView(
        title: 'Choose a ledger',
        message:
            'Select a ledger from the queue to review recent entries and linked business documents.',
        icon: Icons.menu_book_outlined,
      );
    }
    if (_detailLoading && _selectedEntries.isEmpty) {
      return const AppLoadingView(label: 'Loading ledger entries');
    }
    if (_detailError != null && _selectedEntries.isEmpty) {
      return AppErrorView(error: _detailError!, onRetry: _reloadSelectedLedger);
    }
    final hasMore = _detailPage < _detailTotalPages;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ProfessionalDocumentHeader(
          title: _ledgerTitle(balance),
          subtitle:
              'Review current balance, linked vouchers, sales, and purchases without leaving the desktop ledger workbench.',
          badges: [
            ProfessionalBadge(label: 'Acct #${balance.accountId}'),
            if ((balance.accountType ?? '').trim().isNotEmpty)
              AccountTypeBadge(type: balance.accountType!),
            ProfessionalBadge(
                label: 'Balance ${balance.balance.toStringAsFixed(2)}'),
            ProfessionalBadge(label: '${_selectedEntries.length} loaded'),
          ],
        ),
        const SizedBox(height: 16),
        ProfessionalSummaryCard(
          title: 'Ledger snapshot',
          rows: [
            (
              label: 'Current balance',
              value: balance.balance.toStringAsFixed(2),
              emphasize: true,
            ),
            (
              label: 'Date from',
              value: dateLabel(_detailFromDate),
              emphasize: false,
            ),
            (
              label: 'Date to',
              value: dateLabel(_detailToDate),
              emphasize: false,
            ),
            (
              label: 'Loaded page',
              value: '$_detailPage / $_detailTotalPages',
              emphasize: false,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ProfessionalSectionCard(
          title: 'Actions',
          subtitle:
              'Open the full route for a dedicated review surface or keep working in the split-pane queue.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _openLedgerEntries(balance),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open full detail'),
              ),
              OutlinedButton.icon(
                onPressed: _reloadSelectedLedger,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reload entries'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ProfessionalSectionCard(
          title: 'Recent entries',
          subtitle:
              'Voucher, sale, and purchase references remain visible in the review pane for faster finance verification.',
          child: _detailError != null
              ? AppErrorView(
                  error: _detailError!,
                  onRetry: _reloadSelectedLedger,
                )
              : _selectedEntries.isEmpty
                  ? const AppEmptyView(
                      title: 'No ledger entries found',
                      message:
                          'Adjust the date range or refresh the ledger to review recorded activity.',
                      icon: Icons.swap_horiz_rounded,
                    )
                  : Column(
                      children: [
                        for (var index = 0;
                            index < _selectedEntries.length;
                            index++) ...[
                          LedgerEntryReviewCard(
                            entry: _selectedEntries[index],
                            localePrefs: localePrefs,
                          ),
                          if (index != _selectedEntries.length - 1)
                            const SizedBox(height: 10),
                        ],
                        if (_detailLoadingMore) ...[
                          const SizedBox(height: 12),
                          const Center(child: CircularProgressIndicator()),
                        ] else if (hasMore) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton(
                              onPressed: () => _selectLedger(
                                balance,
                                reset: false,
                              ),
                              child: const Text('Load more entries'),
                            ),
                          ),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildMobileBody(List<LedgerBalanceDto> filtered) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Search code, name, type, or ID',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 64),
                    AppEmptyView(
                      title: 'No ledger balances found',
                      message:
                          'Ledger balances matching the current search will appear here.',
                      icon: Icons.menu_book_outlined,
                    ),
                  ],
                )
              : AppScrollbar(
                  builder: (context, controller) => ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final balance = filtered[index];
                      return Card(
                        elevation: 0,
                        child: ListTile(
                          leading: const Icon(Icons.menu_book_rounded),
                          title: Text(_ledgerTitle(balance)),
                          subtitle: Text(
                            [
                              if ((balance.accountType ?? '').trim().isNotEmpty)
                                balance.accountType!,
                              'Balance: ${balance.balance.toStringAsFixed(2)}',
                              'ID: ${balance.accountId}',
                            ].join(' • '),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _openLedgerEntries(balance),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
