import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../core/outbox/outbox_notifier.dart';
import '../../data/expenses_repository.dart';
import '../../data/models.dart';

Future<bool?> showQuickExpenseSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _QuickExpenseSheet(),
  );
}

class _QuickExpenseSheet extends ConsumerStatefulWidget {
  const _QuickExpenseSheet();

  @override
  ConsumerState<_QuickExpenseSheet> createState() => _QuickExpenseSheetState();
}

class _QuickExpenseSheetState extends ConsumerState<_QuickExpenseSheet> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<ExpenseCategoryDto> _categories = const [];
  int? _categoryId;
  DateTime _date = DateTime.now();
  final _amount = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(expensesRepositoryProvider);
      final list = await repo.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = list;
        _categoryId = list.isNotEmpty ? list.first.categoryId : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ErrorHandler.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDate: _date,
    );
    if (!mounted || picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _save() async {
    final categoryId = _categoryId;
    if (categoryId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Create an expense category first')));
      return;
    }
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(expensesRepositoryProvider);
      await repo.createExpense(
        categoryId: categoryId,
        amount: amount,
        expenseDate: _date,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Expense recorded')));
    } on OutboxQueuedException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: _loading
          ? const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            )
          : (_error != null)
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Text(_error!, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.money_off_rounded),
                        const SizedBox(width: 8),
                        Text('Quick Expense',
                            style: theme.textTheme.titleMedium),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _categoryId,
                      items: _categories
                          .map((c) => DropdownMenuItem<int>(
                                value: c.categoryId,
                                child: Text(c.name),
                              ))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _categoryId = v),
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _pickDate,
                      icon: const Icon(Icons.event_rounded),
                      label: Text(
                        'Date: ${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notes,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.4),
                              )
                            : const Text('Save Expense'),
                      ),
                    ),
                  ],
                ),
    );
  }
}
