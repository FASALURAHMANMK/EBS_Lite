import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/category_brand_notifiers.dart';
import '../../data/inventory_repository.dart';
import '../../controllers/inventory_notifier.dart';
import '../../data/models.dart';

class AttributeManagementPage extends ConsumerWidget {
  const AttributeManagementPage({super.key});

  static const _types = ['TEXT', 'NUMBER', 'DATE', 'BOOLEAN', 'SELECT'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attributeManagementProvider);
    final notifier = ref.read(attributeManagementProvider.notifier);
    final theme = Theme.of(context);

    final filtered = state.items
        .where((a) => a.name.toLowerCase().contains(state.query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attribute Management'),
        actions: [
          IconButton(
            tooltip: 'New Attribute',
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final created = await _showAttributeDialog(context, ref: ref);
              if (created == true) ref.read(attributeManagementProvider.notifier).load();
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
                      hintText: 'Search attributes',
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
                ? const _EmptyState(message: 'No attributes found')
                : (state.viewMode == InventoryViewMode.grid
                    ? _AttributeGrid(items: filtered)
                    : _AttributeList(items: filtered)),
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

class _AttributeGrid extends StatelessWidget {
  const _AttributeGrid({required this.items});
  final List<ProductAttributeDefinitionDto> items;

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
          itemBuilder: (context, i) => _AttributeCard(item: items[i]),
        );
      },
    );
  }
}

class _AttributeCard extends ConsumerWidget {
  const _AttributeCard({required this.item});
  final ProductAttributeDefinitionDto item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () async {
        final updated =
            await _showAttributeDialog(context, ref: ref, existing: item);
        if (updated == true) ref.read(attributeManagementProvider.notifier).load();
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
                'Type: ${item.type}${item.isRequired ? '  •  Required' : ''}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if ((item.options?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 6),
                Text(
                  'Options: ${item.options!.join(', ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  'ID: ${item.attributeId}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _AttributeList extends ConsumerWidget {
  const _AttributeList({required this.items});
  final List<ProductAttributeDefinitionDto> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final a = items[i];
        return ListTile(
          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('Type: ${a.type}${a.isRequired ? '  •  Required' : ''}'),
          trailing: Text('ID: ${a.attributeId}',
              style: Theme.of(context).textTheme.labelMedium),
          onTap: () async {
            final updated = await _showAttributeDialog(context, ref: ref, existing: a);
            if (updated == true) ref.read(attributeManagementProvider.notifier).load();
          },
        );
      },
    );
  }
}

Future<bool?> _showAttributeDialog(BuildContext context, {required WidgetRef ref, ProductAttributeDefinitionDto? existing}) async {
  final isEdit = existing != null;
  final nameController = TextEditingController(text: existing?.name ?? '');
  String type = existing?.type ?? AttributeManagementPage._types.first;
  bool isRequired = existing?.isRequired ?? false;
  final optionsController = TextEditingController(text: (existing?.options ?? const []).join(', '));
  final repo = ref.read(inventoryRepositoryProvider);
  bool saving = false;
  return showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(isEdit ? 'Edit Attribute' : 'New Attribute'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                items: AttributeManagementPage._types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => type = v ?? type),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                value: isRequired,
                onChanged: (v) => setState(() => isRequired = v),
                title: const Text('Required'),
                contentPadding: EdgeInsets.zero,
              ),
              if (type == 'SELECT')
                TextField(
                  controller: optionsController,
                  decoration: const InputDecoration(
                    labelText: 'Options (comma-separated)',
                    helperText: 'Example: Red, Blue, Green',
                  ),
                  textInputAction: TextInputAction.done,
                ),
            ],
          ),
        ),
        actions: [
          if (isEdit)
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Attribute'),
                          content: const Text('Are you sure you want to delete this attribute?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(_).pop(false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.of(_).pop(true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        setState(() => saving = true);
                        try {
                          await repo.deleteAttributeDefinition(existing!.attributeId);
                          // Return true to trigger reload
                          // ignore: use_build_context_synchronously
                          Navigator.of(context).pop(true);
                        } finally {
                          setState(() => saving = false);
                        }
                      }
                    },
              child: const Text('Delete'),
            ),
          TextButton(
            onPressed: saving ? null : () => Navigator.of(context).maybePop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: saving || nameController.text.trim().isEmpty
                ? null
                : () async {
                    setState(() => saving = true);
                    try {
                      final opts = type == 'SELECT'
                          ? optionsController.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList()
                          : <String>[];
                      if (isEdit) {
                        await repo.updateAttributeDefinition(
                          existing!.attributeId,
                          name: nameController.text.trim(),
                          type: type,
                          isRequired: isRequired,
                          options: type == 'SELECT' ? opts : null,
                        );
                      } else {
                        await repo.createAttributeDefinition(
                          name: nameController.text.trim(),
                          type: type,
                          isRequired: isRequired,
                          options: type == 'SELECT' ? opts : null,
                        );
                      }
                      // ignore: use_build_context_synchronously
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

