import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../core/outbox/outbox_notifier.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../dashboard/presentation/widgets/dashboard_sidebar.dart';
import '../../data/expenses_repository.dart';
import '../../data/models.dart';
import 'expense_categories_page.dart';

class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({
    super.key,
    this.fromMenu = false,
    this.onMenuSelect,
  });

  final bool fromMenu;
  final void Function(BuildContext context, String label)? onMenuSelect;

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  DateTimeRange? _range;
  int? _categoryId;
  late Future<_ExpensesLoad> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ExpensesLoad> _load() async {
    final repo = ref.read(expensesRepositoryProvider);
    final cats = await repo.getCategories();
    final items = await repo.listExpenses(
      categoryId: _categoryId,
      dateFrom: _range?.start,
      dateTo: _range?.end,
    );
    return _ExpensesLoad(categories: cats, items: items);
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() {
      _future = f;
    });
    await f;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final res = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: DateTime(now.year, now.month, now.day),
          ),
    );
    if (res == null) return;
    setState(() => _range = res);
    await _refresh();
  }

  Future<void> _openNewExpense(List<ExpenseCategoryDto> categories) async {
    final outbox = ref.read(outboxNotifierProvider);
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Create an expense category first.')));
      return;
    }

    int categoryId = _categoryId ?? categories.first.categoryId;
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime date = DateTime.now();

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => StatefulBuilder(
            builder: (context, setInner) => AlertDialog(
              title: const Text('New Expense'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: categoryId,
                          items: categories
                              .map((c) => DropdownMenuItem(
                                    value: c.categoryId,
                                    child: Text(c.name),
                                  ))
                              .toList(),
                          onChanged: (v) => setInner(() {
                            if (v != null) categoryId = v;
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_rounded),
                      title: Text(
                          'Date: ${date.toIso8601String().split('T').first}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(DateTime.now().year - 2, 1, 1),
                          lastDate: DateTime(DateTime.now().year + 1, 12, 31),
                          initialDate: date,
                        );
                        if (picked == null) return;
                        setInner(() => date = picked);
                      },
                    ),
                    if (!outbox.isOnline)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'You are offline. This expense will be queued and synced when online.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!ok) return;

    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) return;

    try {
      await ref.read(expensesRepositoryProvider).createExpense(
            categoryId: categoryId,
            amount: amount,
            expenseDate: date,
            notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Expense saved')));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
      // Queued expenses won't appear in server list until synced.
      if (e is OutboxQueuedException) return;
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Expenses'),
        actions: [
          IconButton(
            tooltip: 'Date filter',
            icon: const Icon(Icons.date_range_rounded),
            onPressed: _pickRange,
          ),
          IconButton(
            tooltip: 'Categories',
            icon: const Icon(Icons.category_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const ExpenseCategoriesPage()),
              );
              if (!mounted) return;
              await _refresh();
            },
          ),
        ],
      ),
      drawer: widget.fromMenu
          ? DashboardSidebar(
              onSelect: (label) => widget.onMenuSelect?.call(context, label),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_ExpensesLoad>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 64),
                  AppErrorView(error: snapshot.error!, onRetry: _refresh),
                ],
              );
            }
            final data =
                snapshot.data ?? const _ExpensesLoad(categories: [], items: []);
            final categories = data.categories;
            final items = data.items;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        isExpanded: true,
                        value: _categoryId,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All categories'),
                          ),
                          ...categories.map(
                            (c) => DropdownMenuItem<int?>(
                              value: c.categoryId,
                              child: Text(c.name),
                            ),
                          ),
                        ],
                        onChanged: (v) async {
                          setState(() => _categoryId = v);
                          await _refresh();
                        },
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 64),
                            Center(child: Text('No expenses')),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final e = items[i];
                            final date = e.expenseDate
                                .toIso8601String()
                                .split('T')
                                .first;
                            return Card(
                              elevation: 0,
                              child: ListTile(
                                leading: const Icon(Icons.receipt_long_rounded),
                                title: Text(
                                    '${e.categoryName ?? 'Category'} • ${e.amount.toStringAsFixed(2)}'),
                                subtitle: Text([
                                  date,
                                  if ((e.notes ?? '').trim().isNotEmpty)
                                    e.notes!.trim(),
                                ].join(' • ')),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final snap = await _future;
          if (!mounted) return;
          await _openNewExpense(snap.categories);
        },
        child: const Icon(Icons.add_rounded),
      ),
    );

    if (!widget.fromMenu) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }
}

class _ExpensesLoad {
  const _ExpensesLoad({required this.categories, required this.items});
  final List<ExpenseCategoryDto> categories;
  final List<ExpenseDto> items;
}
