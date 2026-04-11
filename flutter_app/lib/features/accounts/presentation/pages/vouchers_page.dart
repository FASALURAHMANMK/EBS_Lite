import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../core/app_date_time.dart';
import '../../data/accounts_repository.dart';
import '../../data/models.dart';
import '../../../dashboard/presentation/widgets/dashboard_sidebar.dart';
import '../../../../core/error_handler.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../../shared/widgets/app_scrollbar.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../../../shared/widgets/workbench_pane.dart';
import '../widgets/accounts_workbench_widgets.dart';

class VouchersPage extends ConsumerStatefulWidget {
  const VouchersPage({
    super.key,
    this.fromMenu = false,
    this.onMenuSelect,
  });

  final bool fromMenu;
  final void Function(BuildContext context, String label)? onMenuSelect;

  @override
  ConsumerState<VouchersPage> createState() => _VouchersPageState();
}

class _VouchersPageState extends ConsumerState<VouchersPage> {
  bool _loading = true;
  bool _loadingMore = false;
  bool _detailLoading = false;
  Object? _error;
  Object? _detailError;
  List<VoucherDto> _vouchers = const [];
  VoucherDto? _selectedVoucherDetail;
  final TextEditingController _searchCtrl = TextEditingController();

  int _page = 1;
  int _totalPages = 1;
  int _detailRequestToken = 0;
  final int _perPage = 20;

  String _typeFilter = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;
  int? _selectedVoucherId;

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

  Future<void> _load({
    required bool reset,
    int? pageOverride,
  }) async {
    final requestedPage = reset ? 1 : (pageOverride ?? _page);
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final repo = ref.read(accountsRepositoryProvider);
      final res = await repo.getVouchers(
        type: _typeFilter == 'all' ? null : _typeFilter,
        dateFrom: _fromDate,
        dateTo: _toDate,
        page: requestedPage,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _page = requestedPage;
        _totalPages = res.meta?.totalPages ?? 1;
        if (reset) {
          _vouchers = res.items;
        } else {
          _vouchers = [..._vouchers, ...res.items];
        }
        if (_selectedVoucherId != null &&
            !_vouchers.any((item) => item.voucherId == _selectedVoucherId)) {
          _selectedVoucherId = null;
          _selectedVoucherDetail = null;
          _detailError = null;
          _detailLoading = false;
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

  Future<void> _loadVoucherDetail(
    int voucherId, {
    bool clearCurrent = true,
  }) async {
    final requestToken = ++_detailRequestToken;
    setState(() {
      _selectedVoucherId = voucherId;
      _detailError = null;
      _detailLoading = true;
      if (clearCurrent || _selectedVoucherDetail?.voucherId != voucherId) {
        _selectedVoucherDetail = null;
      }
    });
    try {
      final detail = await ref.read(accountsRepositoryProvider).getVoucher(
            voucherId,
          );
      if (!mounted || requestToken != _detailRequestToken) return;
      setState(() => _selectedVoucherDetail = detail);
    } catch (e) {
      if (!mounted || requestToken != _detailRequestToken) return;
      setState(() => _detailError = e);
    } finally {
      if (mounted && requestToken == _detailRequestToken) {
        setState(() => _detailLoading = false);
      }
    }
  }

  Future<void> _selectVoucher(
    VoucherDto voucher, {
    bool force = false,
  }) async {
    final shouldLoad = force ||
        _selectedVoucherId != voucher.voucherId ||
        _selectedVoucherDetail?.voucherId != voucher.voucherId ||
        _detailError != null;
    if (!shouldLoad) {
      setState(() => _selectedVoucherId = voucher.voucherId);
      return;
    }
    await _loadVoucherDetail(voucher.voucherId);
  }

  Future<void> _refreshSelectedVoucher() async {
    final voucherId = _selectedVoucherId;
    if (voucherId == null) return;
    await _loadVoucherDetail(voucherId);
  }

  void _syncDesktopSelection(List<VoucherDto> filtered) {
    if (!AppBreakpoints.isDesktop(context)) return;
    if (filtered.isEmpty) {
      if (_selectedVoucherId != null ||
          _selectedVoucherDetail != null ||
          _detailError != null ||
          _detailLoading) {
        setState(() {
          _selectedVoucherId = null;
          _selectedVoucherDetail = null;
          _detailError = null;
          _detailLoading = false;
        });
      }
      return;
    }

    VoucherDto next = filtered.first;
    for (final voucher in filtered) {
      if (voucher.voucherId == _selectedVoucherId) {
        next = voucher;
        break;
      }
    }

    final shouldReload = _selectedVoucherId != next.voucherId ||
        (_selectedVoucherDetail?.voucherId != next.voucherId &&
            !_detailLoading &&
            _detailError == null);
    if (shouldReload) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectVoucher(next);
        }
      });
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

  Future<void> _clearDateFilters() async {
    if (_fromDate == null && _toDate == null) return;
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    await _load(reset: true);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _totalPages) return;
    await _load(reset: false, pageOverride: _page + 1);
  }

  Future<void> _openCreateDialog() async {
    String type = 'payment';
    List<LedgerBalanceDto> accounts = const [];
    List<BankAccountDto> bankAccounts = const [];
    int? selectedAccountId;
    int? selectedSettlementAccountId;
    int? selectedBankAccountId;
    try {
      accounts = await ref.read(accountsRepositoryProvider).getLedgerBalances();
      bankAccounts =
          await ref.read(accountsRepositoryProvider).getBankAccounts();
      if (accounts.isNotEmpty) selectedAccountId = accounts.first.accountId;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load accounts list. Enter Account ID manually.\n${ErrorHandler.message(e)}',
          ),
        ),
      );
    }
    if (!mounted) return;

    final accountId = TextEditingController(
      text: selectedAccountId == null ? '' : selectedAccountId.toString(),
    );
    final amount = TextEditingController();
    final reference = TextEditingController();
    final description = TextEditingController();
    final journalLines = <_DraftVoucherLine>[
      _DraftVoucherLine(accountId: selectedAccountId),
      _DraftVoucherLine(
        accountId:
            accounts.length > 1 ? accounts[1].accountId : selectedAccountId,
      ),
    ];
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Create Voucher'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'payment', child: Text('Payment')),
                    DropdownMenuItem(value: 'receipt', child: Text('Receipt')),
                    DropdownMenuItem(value: 'journal', child: Text('Journal')),
                  ],
                  onChanged: (v) => setInner(() => type = v ?? type),
                ),
                const SizedBox(height: 8),
                if (type != 'journal' && accounts.isNotEmpty)
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    key: ValueKey(selectedAccountId),
                    initialValue: selectedAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Account',
                      prefixIcon: Icon(Icons.account_tree_rounded),
                    ),
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem<int>(
                            value: a.accountId,
                            child: Text(
                              [
                                if (a.accountCode != null &&
                                    a.accountCode!.trim().isNotEmpty)
                                  a.accountCode!,
                                a.accountName ?? 'Account #${a.accountId}',
                                if (a.accountType != null &&
                                    a.accountType!.trim().isNotEmpty)
                                  '(${a.accountType})',
                              ].join(' '),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setInner(() => selectedAccountId = v);
                      accountId.text = (v ?? '').toString();
                    },
                  )
                else if (type != 'journal')
                  TextField(
                    controller: accountId,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Account ID',
                      prefixIcon: Icon(Icons.account_tree_rounded),
                    ),
                  ),
                if (type != 'journal') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: Icon(Icons.payments_rounded),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedSettlementAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Settlement Ledger',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Default Cash Ledger'),
                      ),
                      ...accounts.map(
                        (a) => DropdownMenuItem<int?>(
                          value: a.accountId,
                          child: Text(
                            '${a.accountCode ?? ''} ${a.accountName ?? 'Account'}'
                                .trim(),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) =>
                        setInner(() => selectedSettlementAccountId = v),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedBankAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Bank Account',
                      prefixIcon: Icon(Icons.account_balance_rounded),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('No bank settlement'),
                      ),
                      ...bankAccounts.map(
                        (a) => DropdownMenuItem<int?>(
                          value: a.bankAccountId,
                          child: Text('${a.bankName} • ${a.accountName}'),
                        ),
                      ),
                    ],
                    onChanged: (v) => setInner(() => selectedBankAccountId = v),
                  ),
                ],
                if (type == 'journal') ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Balanced Journal Lines',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(journalLines.length, (index) {
                    final line = journalLines[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              DropdownButtonFormField<int>(
                                initialValue: line.accountId,
                                decoration: InputDecoration(
                                  labelText: 'Line ${index + 1} Account',
                                ),
                                items: accounts
                                    .map(
                                      (a) => DropdownMenuItem<int>(
                                        value: a.accountId,
                                        child: Text(
                                          '${a.accountCode ?? ''} ${a.accountName ?? 'Account'}'
                                              .trim(),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setInner(() => line.accountId = v),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: line.debitCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Debit',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: line.creditCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Credit',
                                      ),
                                    ),
                                  ),
                                  if (journalLines.length > 2)
                                    IconButton(
                                      onPressed: () => setInner(
                                          () => journalLines.removeAt(index)),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => setInner(
                        () => journalLines.add(
                          _DraftVoucherLine(accountId: selectedAccountId),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Line'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: reference,
                  decoration: const InputDecoration(
                    labelText: 'Reference',
                    prefixIcon: Icon(Icons.receipt_long_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (saved != true) return;
    if (reference.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reference is required')),
      );
      return;
    }
    try {
      int createdVoucherId = 0;
      if (type == 'journal') {
        createdVoucherId = await ref
            .read(accountsRepositoryProvider)
            .createVoucher(
              type: type,
              reference: reference.text,
              description: description.text,
              lines: journalLines
                  .map(
                    (line) => VoucherLineInput(
                      accountId: line.accountId ?? 0,
                      debit: double.tryParse(line.debitCtrl.text.trim()) ?? 0,
                      credit: double.tryParse(line.creditCtrl.text.trim()) ?? 0,
                    ),
                  )
                  .toList(),
            );
      } else {
        final id = int.tryParse(accountId.text.trim());
        final amt = double.tryParse(amount.text.trim());
        if (id == null || id <= 0 || amt == null || amt <= 0) {
          throw Exception('Enter valid account and amount');
        }
        createdVoucherId =
            await ref.read(accountsRepositoryProvider).createVoucher(
                  type: type,
                  accountId: id,
                  amount: amt,
                  reference: reference.text,
                  description: description.text,
                  settlementAccountId: selectedSettlementAccountId,
                  bankAccountId: selectedBankAccountId,
                );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voucher created')),
      );
      if (createdVoucherId > 0) {
        setState(() {
          _selectedVoucherId = createdVoucherId;
          _selectedVoucherDetail = null;
          _detailError = null;
        });
      }
      await _load(reset: true);
      if (!mounted || createdVoucherId <= 0) return;
      final createdVoucher = _vouchers.cast<VoucherDto?>().firstWhere(
            (item) => item?.voucherId == createdVoucherId,
            orElse: () => null,
          );
      if (createdVoucher != null) {
        await _selectVoucher(createdVoucher, force: true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    } finally {
      for (final line in journalLines) {
        line.dispose();
      }
    }
  }

  String _voucherDateLabel(
    BuildContext context,
    LocalePreferencesState localePrefs,
    DateTime? date,
  ) {
    return date == null
        ? 'Any'
        : AppDateTime.formatDate(context, localePrefs, date);
  }

  String _accountIdLabel(int? accountId) {
    return formatAccountDisplayTitle(accountId: accountId);
  }

  String _voucherQueueSearchText(VoucherDto voucher) {
    return [
      voucher.voucherId.toString(),
      voucher.type,
      voucher.reference,
      voucher.description ?? '',
      voucher.accountId.toString(),
      if (voucher.settlementAccountId != null)
        voucher.settlementAccountId.toString(),
      if (voucher.bankAccountId != null) voucher.bankAccountId.toString(),
      for (final line in voucher.lines) ...[
        line.accountId.toString(),
        line.accountCode ?? '',
        line.accountName ?? '',
        line.description ?? '',
      ],
    ].join(' ').toLowerCase();
  }

  Widget _buildFiltersCard({
    required String Function(DateTime? date) dateLabel,
  }) {
    return ProfessionalSectionCard(
      title: 'Voucher filters',
      subtitle:
          'Keep type and date filters visible while the desktop queue and mobile stack stay aligned.',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              key: ValueKey(_typeFilter),
              initialValue: _typeFilter,
              decoration: const InputDecoration(
                labelText: 'Voucher type',
                prefixIcon: Icon(Icons.tune_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All types')),
                DropdownMenuItem(value: 'payment', child: Text('Payment')),
                DropdownMenuItem(value: 'receipt', child: Text('Receipt')),
                DropdownMenuItem(value: 'journal', child: Text('Journal')),
              ],
              onChanged: (value) async {
                final next = value ?? 'all';
                if (next == _typeFilter) return;
                setState(() => _typeFilter = next);
                await _load(reset: true);
              },
            ),
          ),
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
            onPressed: (_fromDate == null && _toDate == null)
                ? null
                : _clearDateFilters,
            icon: const Icon(Icons.filter_alt_off_rounded),
            label: const Text('Clear dates'),
          ),
          FilledButton.icon(
            onPressed: _openCreateDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create voucher'),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherQueueCard(
    VoucherDto voucher,
    LocalePreferencesState localePrefs, {
    required bool isSelected,
    required Future<void> Function() onSelect,
  }) {
    final theme = Theme.of(context);
    final description = (voucher.description ?? '').trim();
    final subtitleBadges = <Widget>[
      VoucherTypeBadge(type: voucher.type),
      ProfessionalBadge(
        label: AppDateTime.formatDate(context, localePrefs, voucher.date),
      ),
      ProfessionalBadge(label: _accountIdLabel(voucher.accountId)),
      if (voucher.lines.isNotEmpty)
        ProfessionalBadge(label: '${voucher.lines.length} lines'),
    ];

    return Card(
      elevation: 0,
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      formatVoucherDisplayTitle(
                        type: voucher.type,
                        reference: voucher.reference,
                        voucherId: voucher.voucherId,
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        voucher.amount.toStringAsFixed(2),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Voucher amount',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: subtitleBadges,
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopBody({
    required List<VoucherDto> filtered,
    required LocalePreferencesState localePrefs,
    required VoucherDto? selectedVoucher,
    required String Function(DateTime? date) dateLabel,
  }) {
    final journalCount = filtered
        .where((voucher) => voucher.type.trim().toLowerCase() == 'journal')
        .length;
    final loadedLineCount = filtered.fold<int>(
      0,
      (sum, voucher) => sum + voucher.lines.length,
    );

    return Padding(
      padding: AppBreakpoints.pagePadding(context),
      child: Column(
        children: [
          ProfessionalDocumentHeader(
            title: 'Voucher Workbench',
            subtitle:
                'Desktop users can keep the voucher queue pinned on the left while reviewing posting detail, references, and settlement context on the right.',
            badges: [
              ProfessionalBadge(label: '${filtered.length} visible'),
              ProfessionalBadge(label: '$journalCount journals'),
              ProfessionalBadge(label: 'Page $_page / $_totalPages'),
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
                      label: 'Selected voucher',
                      value: selectedVoucher == null
                          ? 'None'
                          : formatVoucherDisplayTitle(
                              type: selectedVoucher.type,
                              reference: selectedVoucher.reference,
                              voucherId: selectedVoucher.voucherId,
                            ),
                      emphasize: true,
                    ),
                    (
                      label: 'Visible queue',
                      value: '${filtered.length}',
                      emphasize: false,
                    ),
                    (
                      label: 'Loaded line refs',
                      value: '$loadedLineCount',
                      emphasize: false,
                    ),
                    (
                      label: 'Mobile behavior',
                      value: 'Stacked review above queue',
                      emphasize: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFiltersCard(dateLabel: dateLabel),
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
                    title: 'Voucher queue',
                    subtitle:
                        'Search the loaded queue by reference, type, description, account, line account, or voucher ID and keep one voucher pinned beside it.',
                    headerTrailing: IconButton(
                      tooltip: 'Refresh vouchers',
                      onPressed: () => _load(reset: true),
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
                                  'Search reference, type, account, line account, or ID',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        Expanded(
                          child: filtered.isEmpty
                              ? const AppEmptyView(
                                  title: 'No vouchers found',
                                  message:
                                      'Vouchers matching the current search and filters will appear here.',
                                  icon: Icons.receipt_long_outlined,
                                )
                              : AppScrollbar(
                                  builder: (context, controller) =>
                                      ListView.separated(
                                    controller: controller,
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 4, 12, 12),
                                    itemCount: filtered.length + 1,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      if (index == filtered.length) {
                                        return _buildLoadMoreRow();
                                      }
                                      final voucher = filtered[index];
                                      return _buildVoucherQueueCard(
                                        voucher,
                                        localePrefs,
                                        isSelected: voucher.voucherId ==
                                            _selectedVoucherId,
                                        onSelect: () => _selectVoucher(voucher),
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
                    title: 'Voucher review',
                    subtitle:
                        'Selected voucher detail stays visible so desktop users do not lose queue context while reviewing the posting.',
                    headerTrailing: IconButton(
                      tooltip: 'Refresh selected voucher',
                      onPressed: _selectedVoucherId == null
                          ? null
                          : _refreshSelectedVoucher,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    child: _buildDesktopDetailContent(localePrefs),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDetailContent(LocalePreferencesState localePrefs) {
    if (_selectedVoucherId == null) {
      return const AppEmptyView(
        title: 'Choose a voucher',
        message:
            'Select a voucher from the queue to review posting detail, settlement context, and journal lines.',
        icon: Icons.receipt_long_outlined,
      );
    }
    if (_detailLoading && _selectedVoucherDetail == null) {
      return const AppLoadingView(label: 'Loading voucher detail');
    }
    if (_detailError != null && _selectedVoucherDetail == null) {
      return AppErrorView(
          error: _detailError!, onRetry: _refreshSelectedVoucher);
    }
    final detail = _selectedVoucherDetail;
    if (detail == null) {
      return const AppEmptyView(
        title: 'Voucher detail unavailable',
        message:
            'Refresh the selected voucher to retry loading its review data.',
        icon: Icons.receipt_long_outlined,
      );
    }

    return AppScrollbar(
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(16),
        children: _buildVoucherReviewSections(detail, localePrefs),
      ),
    );
  }

  Widget _buildMobileBody(
    List<VoucherDto> filtered,
    LocalePreferencesState localePrefs,
    String Function(DateTime? date) dateLabel,
  ) {
    return AppScrollbar(
      builder: (context, controller) => ListView(
        controller: controller,
        padding: AppBreakpoints.pagePadding(context),
        children: [
          ProfessionalDocumentHeader(
            title: 'Vouchers',
            subtitle:
                'Mobile stays stacked: filters, optional selected-voucher review, then the voucher queue.',
            badges: [
              ProfessionalBadge(label: '${filtered.length} loaded'),
              ProfessionalBadge(label: 'Page $_page / $_totalPages'),
            ],
          ),
          const SizedBox(height: 16),
          _buildFiltersCard(dateLabel: dateLabel),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText:
                      'Search reference, type, account, line account, or ID',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          if (_selectedVoucherId != null) ...[
            const SizedBox(height: 16),
            ..._buildMobileDetailSections(localePrefs),
          ],
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            const AppEmptyView(
              title: 'No vouchers found',
              message:
                  'Vouchers matching the current search and filters will appear here.',
              icon: Icons.receipt_long_outlined,
            )
          else ...[
            for (var index = 0; index < filtered.length; index++) ...[
              _buildVoucherQueueCard(
                filtered[index],
                localePrefs,
                isSelected: filtered[index].voucherId == _selectedVoucherId,
                onSelect: () => _selectVoucher(filtered[index]),
              ),
              if (index < filtered.length - 1) const SizedBox(height: 8),
            ],
            _buildLoadMoreRow(),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildMobileDetailSections(
    LocalePreferencesState localePrefs,
  ) {
    if (_detailLoading && _selectedVoucherDetail == null) {
      return const [
        Card(
          elevation: 0,
          child: SizedBox(
            height: 180,
            child: AppLoadingView(label: 'Loading voucher detail'),
          ),
        ),
      ];
    }
    if (_detailError != null && _selectedVoucherDetail == null) {
      return [
        Card(
          elevation: 0,
          child: SizedBox(
            height: 220,
            child: AppErrorView(
              error: _detailError!,
              onRetry: _refreshSelectedVoucher,
            ),
          ),
        ),
      ];
    }
    final detail = _selectedVoucherDetail;
    if (detail == null) {
      return const [];
    }
    return _buildVoucherReviewSections(detail, localePrefs);
  }

  List<Widget> _buildVoucherReviewSections(
    VoucherDto voucher,
    LocalePreferencesState localePrefs,
  ) {
    final description = (voucher.description ?? '').trim();
    final lines = voucher.lines;
    final totalDebit = lines.fold<double>(0, (sum, line) => sum + line.debit);
    final totalCredit = lines.fold<double>(0, (sum, line) => sum + line.credit);

    return [
      ProfessionalDocumentHeader(
        title: formatVoucherDisplayTitle(
          type: voucher.type,
          reference: voucher.reference,
          voucherId: voucher.voucherId,
        ),
        subtitle:
            'Review voucher amount, settlement context, and posted debits/credits without leaving the current workbench state.',
        badges: [
          ProfessionalBadge(label: 'Voucher #${voucher.voucherId}'),
          VoucherTypeBadge(type: voucher.type),
          ProfessionalBadge(
              label: 'Amount ${voucher.amount.toStringAsFixed(2)}'),
          if (lines.isNotEmpty)
            ProfessionalBadge(label: '${lines.length} lines'),
        ],
      ),
      const SizedBox(height: 16),
      ProfessionalSummaryCard(
        title: 'Voucher snapshot',
        rows: [
          (
            label: 'Reference',
            value: voucher.reference.trim().isEmpty
                ? 'Not provided'
                : voucher.reference.trim(),
            emphasize: true,
          ),
          (
            label: 'Posted date',
            value: AppDateTime.formatDate(context, localePrefs, voucher.date),
            emphasize: false,
          ),
          (
            label: 'Primary account',
            value: _accountIdLabel(voucher.accountId),
            emphasize: false,
          ),
          (
            label: 'Settlement ledger',
            value: voucher.settlementAccountId == null
                ? 'Default cash ledger'
                : _accountIdLabel(voucher.settlementAccountId),
            emphasize: false,
          ),
          (
            label: 'Bank settlement',
            value: voucher.bankAccountId == null
                ? 'No bank settlement'
                : 'Bank #${voucher.bankAccountId}',
            emphasize: false,
          ),
          (
            label: 'Journal totals',
            value: lines.isEmpty
                ? 'Detail endpoint returned no lines'
                : '${totalDebit.toStringAsFixed(2)} DR / ${totalCredit.toStringAsFixed(2)} CR',
            emphasize: false,
          ),
        ],
      ),
      if (description.isNotEmpty) ...[
        const SizedBox(height: 16),
        ProfessionalSectionCard(
          title: 'Description',
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      ProfessionalSectionCard(
        title: lines.isEmpty ? 'Posting detail' : 'Journal lines',
        subtitle: lines.isEmpty
            ? 'This voucher did not return line-level detail from the current endpoint response.'
            : 'Review the debit and credit lines posted by the selected voucher.',
        child: lines.isEmpty
            ? Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ProfessionalBadge(label: _accountIdLabel(voucher.accountId)),
                  if (voucher.settlementAccountId != null)
                    ProfessionalBadge(
                      label: _accountIdLabel(voucher.settlementAccountId),
                    ),
                  if (voucher.bankAccountId != null)
                    ProfessionalBadge(label: 'Bank #${voucher.bankAccountId}'),
                ],
              )
            : Column(
                children: [
                  for (var index = 0; index < lines.length; index++) ...[
                    VoucherLineReviewCard(line: lines[index]),
                    if (index < lines.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
      const SizedBox(height: 16),
      ProfessionalSectionCard(
        title: 'Workbench actions',
        subtitle:
            'Keep the current review context while refreshing the selected voucher or posting the next one.',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _openCreateDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create voucher'),
            ),
            OutlinedButton.icon(
              onPressed: _refreshSelectedVoucher,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh detail'),
            ),
            TextButton.icon(
              onPressed: (_fromDate == null && _toDate == null)
                  ? null
                  : _clearDateFilters,
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: const Text('Clear dates'),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildLoadMoreRow() {
    final canLoadMore = _page < _totalPages;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: _loadingMore
            ? const CircularProgressIndicator()
            : canLoadMore
                ? OutlinedButton(
                    onPressed: _loadMore,
                    child: const Text('Load more'),
                  )
                : const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final localePrefs = ref.watch(localePreferencesProvider);
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _vouchers
        : _vouchers
            .where(
                (voucher) => _voucherQueueSearchText(voucher).contains(query))
            .toList();
    final selectedVoucher = filtered.cast<VoucherDto?>().firstWhere(
          (item) => item?.voucherId == _selectedVoucherId,
          orElse: () => null,
        );
    if (isDesktop && !_loading && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncDesktopSelection(filtered);
        }
      });
    }
    String dateLabel(DateTime? d) => _voucherDateLabel(context, localePrefs, d);

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
        title: const Text('Vouchers'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      drawer: widget.fromMenu
          ? DashboardSidebar(
              onSelect: (label) => widget.onMenuSelect?.call(context, label),
            )
          : null,
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateDialog,
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: _loading
            ? const AppLoadingView(label: 'Loading vouchers')
            : _error != null
                ? AppErrorView(
                    error: _error!, onRetry: () => _load(reset: true))
                : (isDesktop
                    ? _buildDesktopBody(
                        filtered: filtered,
                        localePrefs: localePrefs,
                        selectedVoucher: selectedVoucher,
                        dateLabel: dateLabel,
                      )
                    : _buildMobileBody(filtered, localePrefs, dateLabel)),
      ),
    );

    if (!widget.fromMenu) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }
}

class _DraftVoucherLine {
  _DraftVoucherLine({this.accountId});

  int? accountId;
  final TextEditingController debitCtrl = TextEditingController();
  final TextEditingController creditCtrl = TextEditingController();

  void dispose() {
    debitCtrl.dispose();
    creditCtrl.dispose();
  }
}
