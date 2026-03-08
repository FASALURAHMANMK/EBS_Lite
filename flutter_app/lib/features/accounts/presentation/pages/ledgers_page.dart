import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/accounts_repository.dart';
import '../../data/models.dart';
import '../../../dashboard/presentation/widgets/dashboard_sidebar.dart';
import '../../../../shared/widgets/app_error_view.dart';
import 'ledger_entries_page.dart';

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
  Object? _error;
  List<LedgerBalanceDto> _balances = const [];
  final TextEditingController _search = TextEditingController();

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
      setState(() => _balances = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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

    final scaffold = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.fromMenu,
        leading: widget.fromMenu
            ? Builder(
                builder: (context) => IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
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
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? AppErrorView(error: _error!, onRetry: _load)
                : Column(
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
                            ? const Center(
                                child: Text('No ledger balances found'),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final b = filtered[i];
                                  return Card(
                                    elevation: 0,
                                    child: ListTile(
                                      leading:
                                          const Icon(Icons.menu_book_rounded),
                                      title: Text(
                                        b.accountName == null ||
                                                b.accountName!.trim().isEmpty
                                            ? 'Account #${b.accountId}'
                                            : '${b.accountCode ?? ''} ${b.accountName}'
                                                .trim(),
                                      ),
                                      subtitle: Text(
                                        [
                                          if (b.accountType != null &&
                                              b.accountType!.trim().isNotEmpty)
                                            b.accountType!,
                                          'Balance: ${b.balance.toStringAsFixed(2)}',
                                          'ID: ${b.accountId}',
                                        ].join(' • '),
                                      ),
                                      trailing: const Icon(
                                          Icons.chevron_right_rounded),
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => LedgerEntriesPage(
                                            accountId: b.accountId,
                                          ),
                                        ),
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

    if (!widget.fromMenu) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }
}
