import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../data/accounts_repository.dart';
import '../../data/models.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../../shared/widgets/app_scrollbar.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../../../shared/widgets/workbench_pane.dart';
import '../widgets/accounts_workbench_widgets.dart';

class LedgerEntriesPage extends ConsumerStatefulWidget {
  const LedgerEntriesPage({
    super.key,
    required this.accountId,
    this.accountCode,
    this.accountName,
    this.accountType,
    this.currentBalance,
  });

  final int accountId;
  final String? accountCode;
  final String? accountName;
  final String? accountType;
  final double? currentBalance;

  @override
  ConsumerState<LedgerEntriesPage> createState() => _LedgerEntriesPageState();
}

class _LedgerEntriesPageState extends ConsumerState<LedgerEntriesPage> {
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  List<LedgerEntryDto> _entries = const [];

  int _page = 1;
  int _totalPages = 1;
  final int _perPage = 20;

  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final repo = ref.read(accountsRepositoryProvider);
      final res = await repo.getLedgerEntries(
        accountId: widget.accountId,
        dateFrom: _fromDate,
        dateTo: _toDate,
        page: _page,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _totalPages = res.meta?.totalPages ?? 1;
        if (reset) {
          _entries = res.items;
        } else {
          _entries = [..._entries, ...res.items];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _pickDateRange({required bool from}) async {
    final initial = from ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
    await _load(reset: true);
  }

  Future<void> _clearDateRange() async {
    if (_fromDate == null && _toDate == null) return;
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    await _load(reset: true);
  }

  String _ledgerTitle() {
    final parts = <String>[
      if ((widget.accountCode ?? '').trim().isNotEmpty) widget.accountCode!,
      if ((widget.accountName ?? '').trim().isNotEmpty) widget.accountName!,
    ];
    return parts.isEmpty ? 'Account #${widget.accountId}' : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final localePrefs = ref.watch(localePreferencesProvider);
    String dateLabel(DateTime? d) =>
        d == null ? 'Any' : AppDateTime.formatDate(context, localePrefs, d);

    return Scaffold(
      appBar: AppBar(
        title: Text('Ledger Entries • ${_ledgerTitle()}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const AppLoadingView(label: 'Loading ledger entries')
            : _error != null
                ? AppErrorView(
                    error: _error!, onRetry: () => _load(reset: true))
                : (isDesktop
                    ? _buildDesktopBody(localePrefs, dateLabel)
                    : _buildMobileBody(localePrefs, dateLabel)),
      ),
    );
  }

  Widget _buildDesktopBody(
    LocalePreferencesState localePrefs,
    String Function(DateTime? date) dateLabel,
  ) {
    final linkedEntries = _entries
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
            title: _ledgerTitle(),
            subtitle:
                'Standalone desktop ledger review keeps filters, account context, and linked business references visible in one place.',
            badges: [
              ProfessionalBadge(label: 'Acct #${widget.accountId}'),
              if ((widget.accountType ?? '').trim().isNotEmpty)
                AccountTypeBadge(type: widget.accountType!),
              if (widget.currentBalance != null)
                ProfessionalBadge(
                  label: 'Balance ${widget.currentBalance!.toStringAsFixed(2)}',
                ),
              ProfessionalBadge(label: '${_entries.length} loaded'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ProfessionalSummaryCard(
                  title: 'Ledger review',
                  rows: [
                    (
                      label: 'Visible entries',
                      value: '${_entries.length}',
                      emphasize: true,
                    ),
                    (
                      label: 'Linked references',
                      value: '$linkedEntries',
                      emphasize: false,
                    ),
                    (
                      label: 'From date',
                      value: dateLabel(_fromDate),
                      emphasize: false,
                    ),
                    (
                      label: 'To date',
                      value: dateLabel(_toDate),
                      emphasize: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ProfessionalSectionCard(
                  title: 'Filters and actions',
                  subtitle:
                      'Apply a date range or refresh the standalone review surface.',
                  child: _buildFilterControls(dateLabel),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: WorkbenchPane(
              title: 'Entries',
              subtitle:
                  'Voucher, sale, and purchase references remain visible while you review ledger movement.',
              headerTrailing: IconButton(
                tooltip: 'Refresh entries',
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.refresh_rounded),
              ),
              child: _buildEntriesList(localePrefs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody(
    LocalePreferencesState localePrefs,
    String Function(DateTime? date) dateLabel,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _buildFilterControls(dateLabel),
        ),
        Expanded(child: _buildEntriesList(localePrefs)),
      ],
    );
  }

  Widget _buildFilterControls(String Function(DateTime? date) dateLabel) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => _pickDateRange(from: true),
          icon: const Icon(Icons.event_rounded),
          label: Text('From: ${dateLabel(_fromDate)}'),
        ),
        OutlinedButton.icon(
          onPressed: () => _pickDateRange(from: false),
          icon: const Icon(Icons.event_available_rounded),
          label: Text('To: ${dateLabel(_toDate)}'),
        ),
        TextButton.icon(
          onPressed: _clearDateRange,
          icon: const Icon(Icons.filter_alt_off_rounded),
          label: const Text('Clear dates'),
        ),
      ],
    );
  }

  Widget _buildEntriesList(LocalePreferencesState localePrefs) {
    if (_entries.isEmpty) {
      return const AppEmptyView(
        title: 'No ledger entries found',
        message:
            'Adjust the date range or refresh the ledger to review recorded activity.',
        icon: Icons.swap_horiz_rounded,
      );
    }
    return AppScrollbar(
      builder: (context, controller) => ListView.separated(
        controller: controller,
        padding: const EdgeInsets.all(12),
        itemCount: _entries.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == _entries.length) {
            final canLoadMore = _page < _totalPages && !_loadingMore;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: canLoadMore
                    ? OutlinedButton(
                        onPressed: () async {
                          setState(() => _page += 1);
                          await _load(reset: false);
                        },
                        child: const Text('Load more'),
                      )
                    : _loadingMore
                        ? const CircularProgressIndicator()
                        : const SizedBox.shrink(),
              ),
            );
          }
          return LedgerEntryReviewCard(
            entry: _entries[index],
            localePrefs: localePrefs,
          );
        },
      ),
    );
  }
}
