import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/accounts_repository.dart';
import '../../data/models.dart';
import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';

class BankingPage extends ConsumerStatefulWidget {
  const BankingPage({super.key});

  @override
  ConsumerState<BankingPage> createState() => _BankingPageState();
}

class _BankingPageState extends ConsumerState<BankingPage> {
  bool _loading = true;
  Object? _error;
  List<BankAccountDto> _bankAccounts = const [];
  List<BankStatementEntryDto> _statementEntries = const [];
  int? _selectedBankAccountId;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(accountsRepositoryProvider);
      final accounts = await repo.getBankAccounts();
      final selected = _selectedBankAccountId ??
          (accounts.isNotEmpty ? accounts.first.bankAccountId : null);
      final entries = selected == null
          ? const <BankStatementEntryDto>[]
          : await repo.getBankStatementEntries(
              bankAccountId: selected,
              status: _statusFilter == 'all' ? null : _statusFilter,
            );
      if (!mounted) return;
      setState(() {
        _bankAccounts = accounts;
        _selectedBankAccountId = selected;
        _statementEntries = entries;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  BankAccountDto? get _selectedBankAccount {
    for (final item in _bankAccounts) {
      if (item.bankAccountId == _selectedBankAccountId) return item;
    }
    return null;
  }

  Future<void> _selectBankAccount(int? bankAccountId) async {
    setState(() => _selectedBankAccountId = bankAccountId);
    await _load();
  }

  Future<void> _openBankAccountDialog({BankAccountDto? existing}) async {
    final ledgers =
        await ref.read(accountsRepositoryProvider).getChartOfAccounts();
    if (!mounted) return;
    final ledgerItems = ledgers.where((e) => e.type == 'ASSET').toList();
    var ledgerAccountId = existing?.ledgerAccountId ??
        (ledgerItems.isNotEmpty ? ledgerItems.first.accountId : 0);
    final accountNameCtrl =
        TextEditingController(text: existing?.accountName ?? '');
    final bankNameCtrl = TextEditingController(text: existing?.bankName ?? '');
    final maskedCtrl =
        TextEditingController(text: existing?.accountNumberMasked ?? '');
    final branchCtrl = TextEditingController(text: existing?.branchName ?? '');
    final currencyCtrl =
        TextEditingController(text: existing?.currencyCode ?? 'USD');
    final hintCtrl =
        TextEditingController(text: existing?.statementImportHint ?? '');
    final openingBalanceCtrl = TextEditingController(
      text: (existing?.openingBalance ?? 0).toStringAsFixed(2),
    );
    var isActive = existing?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title:
              Text(existing == null ? 'Add Bank Account' : 'Edit Bank Account'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: ledgerAccountId == 0 ? null : ledgerAccountId,
                    decoration:
                        const InputDecoration(labelText: 'Ledger Account'),
                    items: ledgerItems
                        .map(
                          (item) => DropdownMenuItem<int>(
                            value: item.accountId,
                            child: Text(
                              '${item.accountCode ?? ''} ${item.name}'.trim(),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setInner(() => ledgerAccountId = value ?? 0),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: accountNameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Account Name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: bankNameCtrl,
                    decoration: const InputDecoration(labelText: 'Bank Name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: maskedCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Masked Account Number',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: branchCtrl,
                    decoration: const InputDecoration(labelText: 'Branch'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: currencyCtrl,
                    decoration: const InputDecoration(labelText: 'Currency'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: hintCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Statement Import Hint',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: openingBalanceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Opening Balance'),
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

    try {
      final repo = ref.read(accountsRepositoryProvider);
      final openingBalance =
          double.tryParse(openingBalanceCtrl.text.trim()) ?? 0.0;
      if (existing == null) {
        await repo.createBankAccount(
          ledgerAccountId: ledgerAccountId,
          accountName: accountNameCtrl.text,
          bankName: bankNameCtrl.text,
          accountNumberMasked: maskedCtrl.text,
          branchName: branchCtrl.text,
          currencyCode: currencyCtrl.text,
          statementImportHint: hintCtrl.text,
          openingBalance: openingBalance,
          isActive: isActive,
        );
      } else {
        await repo.updateBankAccount(
          bankAccountId: existing.bankAccountId,
          ledgerAccountId: ledgerAccountId,
          accountName: accountNameCtrl.text,
          bankName: bankNameCtrl.text,
          accountNumberMasked: maskedCtrl.text,
          branchName: branchCtrl.text,
          currencyCode: currencyCtrl.text,
          statementImportHint: hintCtrl.text,
          openingBalance: openingBalance,
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
  }

  Future<void> _openStatementEntryDialog() async {
    final bankAccount = _selectedBankAccount;
    if (bankAccount == null) return;
    final dateCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    final descriptionCtrl = TextEditingController();
    final referenceCtrl = TextEditingController();
    final depositCtrl = TextEditingController();
    final withdrawalCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New Statement Entry • ${bankAccount.accountName}'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(labelText: 'Entry Date'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: referenceCtrl,
                  decoration: const InputDecoration(labelText: 'Reference'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: depositCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Deposit Amount'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: withdrawalCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Withdrawal Amount'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: balanceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Running Balance'),
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
    );

    if (saved != true || !mounted) return;

    try {
      await ref.read(accountsRepositoryProvider).createBankStatementEntry(
            bankAccountId: bankAccount.bankAccountId,
            entryDate: DateTime.parse(dateCtrl.text.trim()),
            description: descriptionCtrl.text,
            reference: referenceCtrl.text,
            depositAmount: double.tryParse(depositCtrl.text.trim()) ?? 0,
            withdrawalAmount: double.tryParse(withdrawalCtrl.text.trim()) ?? 0,
            runningBalance: double.tryParse(balanceCtrl.text.trim()),
          );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  Future<void> _matchEntry(BankStatementEntryDto entry) async {
    final ledgerIdCtrl = TextEditingController();
    final amountCtrl =
        TextEditingController(text: entry.availableAmount.toStringAsFixed(2));
    final notesCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Match Statement Entry'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ledgerIdCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Bank Ledger Entry ID'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Matched Amount'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Match'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted || _selectedBankAccountId == null) return;

    try {
      await ref.read(accountsRepositoryProvider).matchBankStatement(
            bankAccountId: _selectedBankAccountId!,
            statementEntryId: entry.statementEntryId,
            ledgerEntryId: int.tryParse(ledgerIdCtrl.text.trim()) ?? 0,
            matchedAmount: double.tryParse(amountCtrl.text.trim()) ?? 0,
            notes: notesCtrl.text,
          );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  Future<void> _reviewEntry(BankStatementEntryDto entry) async {
    final reviewCtrl = TextEditingController(text: entry.reviewReason ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark For Review'),
        content: TextField(
          controller: reviewCtrl,
          decoration: const InputDecoration(labelText: 'Review Reason'),
          maxLines: 3,
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
    );
    if (saved != true || !mounted || _selectedBankAccountId == null) return;
    try {
      await ref.read(accountsRepositoryProvider).reviewBankStatement(
            bankAccountId: _selectedBankAccountId!,
            statementEntryId: entry.statementEntryId,
            reviewReason: reviewCtrl.text,
          );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  Future<void> _createAdjustment(BankStatementEntryDto entry) async {
    final accounts =
        await ref.read(accountsRepositoryProvider).getChartOfAccounts();
    if (!mounted) return;
    final candidateAccounts =
        accounts.where((e) => e.type != 'ASSET').toList(growable: false);
    if (candidateAccounts.isEmpty) return;
    var offsetAccountId = candidateAccounts.first.accountId;
    var adjustmentType =
        entry.withdrawalAmount > 0 ? 'BANK_CHARGE' : 'ADJUSTMENT';
    final descriptionCtrl = TextEditingController(
      text: adjustmentType == 'BANK_CHARGE'
          ? 'Bank charge from reconciliation'
          : 'Bank adjustment from reconciliation',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Post Bank Adjustment'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: adjustmentType,
                  decoration:
                      const InputDecoration(labelText: 'Adjustment Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'BANK_CHARGE',
                      child: Text('Bank Charge'),
                    ),
                    DropdownMenuItem(
                      value: 'ADJUSTMENT',
                      child: Text('Adjustment'),
                    ),
                  ],
                  onChanged: (value) =>
                      setInner(() => adjustmentType = value ?? adjustmentType),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: offsetAccountId,
                  decoration:
                      const InputDecoration(labelText: 'Offset Account'),
                  items: candidateAccounts
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: item.accountId,
                          child: Text(
                            '${item.accountCode ?? ''} ${item.name}'.trim(),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setInner(
                      () => offsetAccountId = value ?? offsetAccountId),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted || _selectedBankAccountId == null) return;

    try {
      await ref.read(accountsRepositoryProvider).createBankAdjustment(
            bankAccountId: _selectedBankAccountId!,
            statementEntryId: entry.statementEntryId,
            adjustmentType: adjustmentType,
            offsetAccountId: offsetAccountId,
            description: descriptionCtrl.text,
          );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  Future<void> _unmatchEntry(BankStatementEntryDto entry) async {
    if (_selectedBankAccountId == null || entry.matches.isEmpty) return;
    try {
      await ref.read(accountsRepositoryProvider).unmatchBankStatement(
            bankAccountId: _selectedBankAccountId!,
            statementEntryId: entry.statementEntryId,
            matchId: entry.matches.first.matchId,
          );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bankAccount = _selectedBankAccount;
    final money = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Banking & Reconciliation'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: bankAccount == null
          ? FloatingActionButton.extended(
              onPressed: _openBankAccountDialog,
              icon: const Icon(Icons.account_balance_rounded),
              label: const Text('Add Bank Account'),
            )
          : null,
      body: SafeArea(
        child: _loading
            ? const AppLoadingView(label: 'Loading banking workspace')
            : _error != null
                ? AppErrorView(error: _error!, onRetry: _load)
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: _selectedBankAccountId,
                                decoration: const InputDecoration(
                                  labelText: 'Bank Account',
                                ),
                                items: _bankAccounts
                                    .map(
                                      (item) => DropdownMenuItem<int>(
                                        value: item.bankAccountId,
                                        child: Text(
                                          '${item.bankName} • ${item.accountName}',
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _selectBankAccount,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'all', label: Text('All')),
                                ButtonSegment(
                                    value: 'UNMATCHED',
                                    label: Text('Unmatched')),
                                ButtonSegment(
                                    value: 'MATCHED', label: Text('Matched')),
                                ButtonSegment(
                                    value: 'REVIEW', label: Text('Review')),
                              ],
                              selected: {_statusFilter},
                              onSelectionChanged: (value) async {
                                setState(() => _statusFilter = value.first);
                                await _load();
                              },
                            ),
                          ],
                        ),
                      ),
                      if (bankAccount != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Card(
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${bankAccount.bankName} • ${bankAccount.accountName}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          [
                                            if ((bankAccount
                                                        .accountNumberMasked ??
                                                    '')
                                                .isNotEmpty)
                                              bankAccount.accountNumberMasked!,
                                            if ((bankAccount.currencyCode ?? '')
                                                .isNotEmpty)
                                              bankAccount.currencyCode!,
                                            'Unmatched ${bankAccount.unmatchedEntries}',
                                            'Review ${bankAccount.reviewEntries}',
                                          ].join(' • '),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _openBankAccountDialog(
                                            existing: bankAccount),
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const Text('Edit'),
                                      ),
                                      FilledButton.icon(
                                        onPressed: _openStatementEntryDialog,
                                        icon: const Icon(Icons.add_rounded),
                                        label: const Text('Statement Entry'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: bankAccount == null
                            ? const AppEmptyView(
                                title: 'No bank accounts found',
                                message:
                                    'Create a bank account to start statement capture and reconciliation.',
                                icon: Icons.account_balance_outlined,
                              )
                            : _statementEntries.isEmpty
                                ? const AppEmptyView(
                                    title: 'No statement entries found',
                                    message:
                                        'Add statement lines for the selected bank account to begin reconciliation.',
                                    icon: Icons.receipt_long_outlined,
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: _statementEntries.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final entry = _statementEntries[index];
                                      final isDeposit = entry.depositAmount > 0;
                                      final signedAmount = isDeposit
                                          ? entry.depositAmount
                                          : -entry.withdrawalAmount;
                                      return Card(
                                        elevation: 0,
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.all(12),
                                          leading: CircleAvatar(
                                            child: Icon(
                                              isDeposit
                                                  ? Icons.south_west_rounded
                                                  : Icons.north_east_rounded,
                                            ),
                                          ),
                                          title: Text(
                                            '${DateFormat('yyyy-MM-dd').format(entry.entryDate.toLocal())} • ${money.format(signedAmount)}',
                                          ),
                                          subtitle: Text(
                                            [
                                              if ((entry.reference ?? '')
                                                  .isNotEmpty)
                                                entry.reference!,
                                              if ((entry.description ?? '')
                                                  .isNotEmpty)
                                                entry.description!,
                                              'Matched ${money.format(entry.matchedAmount)}',
                                              'Open ${money.format(entry.availableAmount)}',
                                              'Status ${entry.status}',
                                            ].join(' • '),
                                          ),
                                          trailing: PopupMenuButton<String>(
                                            onSelected: (value) {
                                              switch (value) {
                                                case 'match':
                                                  _matchEntry(entry);
                                                  break;
                                                case 'unmatch':
                                                  _unmatchEntry(entry);
                                                  break;
                                                case 'review':
                                                  _reviewEntry(entry);
                                                  break;
                                                case 'adjustment':
                                                  _createAdjustment(entry);
                                                  break;
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'match',
                                                child: Text('Match'),
                                              ),
                                              if (entry.matches.isNotEmpty)
                                                const PopupMenuItem(
                                                  value: 'unmatch',
                                                  child: Text('Unmatch Latest'),
                                                ),
                                              const PopupMenuItem(
                                                value: 'review',
                                                child: Text('Mark Review'),
                                              ),
                                              const PopupMenuItem(
                                                value: 'adjustment',
                                                child: Text('Post Adjustment'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
