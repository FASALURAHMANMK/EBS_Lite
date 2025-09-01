import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/category_brand_notifiers.dart';
import '../../data/inventory_repository.dart';
import '../../controllers/inventory_notifier.dart';
import '../../data/models.dart';

class CategoryManagementPage extends ConsumerWidget {
  const CategoryManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(categoryManagementProvider);
    final notifier = ref.read(categoryManagementProvider.notifier);
    final theme = Theme.of(context);

    final filtered = state.items
        .where((c) => c.name.toLowerCase().contains(state.query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Management'),
        actions: [
          IconButton(
            tooltip: 'New Category',
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final created = await _showCategoryDialog(context, ref: ref);
              if (created == true) ref.read(categoryManagementProvider.notifier).load();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search categories',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: notifier.setQuery,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: state.viewMode == InventoryViewMode.grid
                      ? 'Switch to list view'
                      : 'Switch to grid view',
                  onPressed: () => notifier.setViewMode(
                    state.viewMode == InventoryViewMode.grid
                        ? InventoryViewMode.list
                        : InventoryViewMode.grid,
                  ),
                  icon: Icon(state.viewMode == InventoryViewMode.grid
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded),
                ),
              ],
            ),
          ),
          if (state.isLoading) const LinearProgressIndicator(minHeight: 2),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(state.error!,
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          Expanded(
            child: filtered.isEmpty
                ? const _EmptyState(message: 'No categories found')
                : (state.viewMode == InventoryViewMode.grid
                    ? _CategoryGrid(items: filtered)
                    : _CategoryList(items: filtered)),
      ),
    ],
  ),
);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message));
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.items});
  final List<CategoryDto> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount;
        if (width >= 1200) {
          crossAxisCount = 4;
        } else if (width >= 900) {
          crossAxisCount = 3;
        } else if (width >= 600) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 2;
        }
        final childAspectRatio = width < 600 ? 0.95 : 1.4;
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => _CategoryCard(item: items[i]),
        );
      },
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  const _CategoryCard({required this.item});
  final CategoryDto item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () async {
        final updated = await _showCategoryDialog(context, ref: ref, existing: item);
        if (updated == true) ref.read(categoryManagementProvider.notifier).load();
      },
      child: Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'ID: ${item.categoryId}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                item.isActive ? 'Active' : 'Inactive',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: item.isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.items});
  final List<CategoryDto> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = items[i];
        return ListTile(
          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('ID: ${c.categoryId}'),
          trailing: Text(
            c.isActive ? 'Active' : 'Inactive',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          onTap: () async {
            final updated = await _showCategoryDialog(context, ref: ref, existing: c);
            if (updated == true) ref.read(categoryManagementProvider.notifier).load();
          },
        );
      },
    );
  }
}

Future<bool?> _showCategoryDialog(BuildContext context, {required WidgetRef ref, CategoryDto? existing}) async {
  final isEdit = existing != null;
  final controller = TextEditingController(text: existing?.name ?? '');
  final repo = ref.read(inventoryRepositoryProvider);
  bool saving = false;
  return showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(isEdit ? 'Edit Category' : 'New Category'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Name'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) async {
              if (controller.text.trim().isEmpty) return;
              setState(() => saving = true);
              try {
                if (isEdit) {
                  await repo.updateCategory(id: existing!.categoryId, name: controller.text.trim());
                } else {
                  await repo.createCategory(name: controller.text.trim());
                }
                Navigator.of(context).pop(true);
              } finally {
                setState(() => saving = false);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.of(context).maybePop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: saving || controller.text.trim().isEmpty
                ? null
                : () async {
                    setState(() => saving = true);
                    try {
                      if (isEdit) {
                        await repo.updateCategory(id: existing!.categoryId, name: controller.text.trim());
                      } else {
                        await repo.createCategory(name: controller.text.trim());
                      }
                      Navigator.of(context).pop(true);
                    } finally {
                      setState(() => saving = false);
                    }
                  },
            child: saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.4))
                : Text(isEdit ? 'Save' : 'Create'),
          ),
        ],
      ),
    ),
  );
}
