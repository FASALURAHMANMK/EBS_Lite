import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../data/expenses_repository.dart';
import '../../data/models.dart';

class ExpenseCategoriesPage extends ConsumerStatefulWidget {
  const ExpenseCategoriesPage({super.key});

  @override
  ConsumerState<ExpenseCategoriesPage> createState() =>
      _ExpenseCategoriesPageState();
}

class _ExpenseCategoriesPageState extends ConsumerState<ExpenseCategoriesPage> {
  late Future<List<ExpenseCategoryDto>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ExpenseCategoryDto>> _load() async {
    final repo = ref.read(expensesRepositoryProvider);
    return repo.getCategories();
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    await f;
  }

  Future<void> _openEditor({ExpenseCategoryDto? initial}) async {
    final name = TextEditingController(text: initial?.name ?? '');
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(initial == null ? 'New Category' : 'Edit Category'),
            content: TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
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
        ) ??
        false;
    if (!ok) return;
    try {
      final repo = ref.read(expensesRepositoryProvider);
      final v = name.text.trim();
      if (v.isEmpty) return;
      if (initial == null) {
        await repo.createCategory(v);
      } else {
        await repo.updateCategory(initial.categoryId, v);
      }
      if (!mounted) return;
      try {
        await _refresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text(
                  initial == null ? 'Category created' : 'Category updated')));
      } catch (_) {
        // If the create succeeded but refresh fails (e.g., transient network),
        // avoid showing a scary error. The category will be visible on next load.
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text('Saved, but failed to refresh the list.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    }
  }

  Future<void> _delete(ExpenseCategoryDto c) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Category'),
            content: Text('Delete "${c.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await ref.read(expensesRepositoryProvider).deleteCategory(c.categoryId);
      if (!mounted) return;
      try {
        await _refresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Category deleted')));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text('Deleted, but failed to refresh the list.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Categories'),
        actions: [
          IconButton(
            tooltip: 'New Category',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ExpenseCategoryDto>>(
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
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return const Center(child: Text('No categories'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = items[i];
                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: Text(c.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openEditor(initial: c),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => _delete(c),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
