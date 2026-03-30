import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/accounts_repository.dart';
import '../../data/models.dart';
import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';

class ChartOfAccountsPage extends ConsumerStatefulWidget {
  const ChartOfAccountsPage({super.key});

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
      setState(() => _accounts = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAccountDialog({ChartOfAccountDto? existing}) async {
    final parents =
        _accounts.where((e) => e.accountId != existing?.accountId).toList();
    final codeCtrl = TextEditingController(text: existing?.accountCode ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final subtypeCtrl = TextEditingController(text: existing?.subtype ?? '');
    var type = existing?.type ?? 'ASSET';
    var parentId = existing?.parentId;
    var isActive = existing?.isActive ?? true;

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
                          value: 'LIABILITY', child: Text('Liability')),
                      DropdownMenuItem(value: 'EQUITY', child: Text('Equity')),
                      DropdownMenuItem(
                          value: 'REVENUE', child: Text('Revenue')),
                      DropdownMenuItem(
                          value: 'EXPENSE', child: Text('Expense')),
                    ],
                    onChanged: (value) => setInner(() => type = value ?? type),
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
                            '${item.accountCode ?? ''} ${item.name}'.trim(),
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
    try {
      final repo = ref.read(accountsRepositoryProvider);
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
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final items = query.isEmpty
        ? _accounts
        : _accounts.where((item) {
            final haystack = [
              item.accountCode ?? '',
              item.name,
              item.type,
              item.subtype ?? '',
              item.parentName ?? '',
            ].join(' ').toLowerCase();
            return haystack.contains(query);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chart of Accounts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAccountDialog,
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: _loading
            ? const AppLoadingView(label: 'Loading chart of accounts')
            : _error != null
                ? AppErrorView(error: _error!, onRetry: _load)
                : Column(
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
                              label: const Text('Show Inactive'),
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
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return Card(
                                    elevation: 0,
                                    child: ListTile(
                                      leading: const Icon(
                                          Icons.account_tree_rounded),
                                      title: Text(
                                        '${item.accountCode ?? ''} ${item.name}'
                                            .trim(),
                                      ),
                                      subtitle: Text(
                                        [
                                          item.type,
                                          if ((item.subtype ?? '').isNotEmpty)
                                            item.subtype!,
                                          if ((item.parentName ?? '')
                                              .isNotEmpty)
                                            'Parent ${item.parentName}',
                                          'Balance ${(item.currentBalance ?? 0).toStringAsFixed(2)}',
                                          if (!item.isActive) 'Inactive',
                                        ].join(' • '),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () =>
                                            _openAccountDialog(existing: item),
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
