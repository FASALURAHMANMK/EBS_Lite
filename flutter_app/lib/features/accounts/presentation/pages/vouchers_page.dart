import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../data/accounts_repository.dart';
import '../../data/models.dart';
import '../../../dashboard/presentation/widgets/dashboard_sidebar.dart';
import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_error_view.dart';

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
  Object? _error;
  List<VoucherDto> _vouchers = const [];

  int _page = 1;
  int _totalPages = 1;
  final int _perPage = 20;

  String _typeFilter = 'all';
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
      final res = await repo.getVouchers(
        type: _typeFilter == 'all' ? null : _typeFilter,
        dateFrom: _fromDate,
        dateTo: _toDate,
        page: _page,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _totalPages = res.meta?.totalPages ?? 1;
        if (reset) {
          _vouchers = res.items;
        } else {
          _vouchers = [..._vouchers, ...res.items];
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
      if (type == 'journal') {
        await ref.read(accountsRepositoryProvider).createVoucher(
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
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final df = DateFormat('yyyy-MM-dd');
    String dateLabel(DateTime? d) => d == null ? 'Any' : df.format(d);

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
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? AppErrorView(
                    error: _error!, onRetry: () => _load(reset: true))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            DropdownButton<String>(
                              isExpanded: true,
                              value: _typeFilter,
                              items: const [
                                DropdownMenuItem(
                                    value: 'all', child: Text('All Types')),
                                DropdownMenuItem(
                                    value: 'payment', child: Text('Payment')),
                                DropdownMenuItem(
                                    value: 'receipt', child: Text('Receipt')),
                                DropdownMenuItem(
                                    value: 'journal', child: Text('Journal')),
                              ],
                              onChanged: (v) {
                                final next = v ?? 'all';
                                if (next == _typeFilter) return;
                                setState(() => _typeFilter = next);
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => _load(reset: true),
                                );
                              },
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
                          ],
                        ),
                      ),
                      Expanded(
                        child: _vouchers.isEmpty
                            ? const Center(child: Text('No vouchers found'))
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _vouchers.length + 1,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  if (index == _vouchers.length) {
                                    final canLoadMore =
                                        _page < _totalPages && !_loadingMore;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
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
                                  final v = _vouchers[index];
                                  return Card(
                                    elevation: 0,
                                    child: ListTile(
                                      leading: const Icon(
                                          Icons.receipt_long_rounded),
                                      title: Text(
                                          '${v.type.toUpperCase()} • ${v.amount.toStringAsFixed(2)}'),
                                      subtitle: Text(
                                          '${v.reference} • ${df.format(v.date.toLocal())}'),
                                      trailing: Text('Acct #${v.accountId}'),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
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
}
