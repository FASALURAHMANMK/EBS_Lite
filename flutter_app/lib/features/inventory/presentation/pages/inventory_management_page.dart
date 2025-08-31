import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/inventory_notifier.dart';
import '../../data/models.dart';
import 'product_form_page.dart';
import 'product_edit_page.dart';

class InventoryManagementPage extends ConsumerStatefulWidget {
  const InventoryManagementPage({super.key});

  @override
  ConsumerState<InventoryManagementPage> createState() => _InventoryManagementPageState();
}

class _InventoryManagementPageState extends ConsumerState<InventoryManagementPage> {
  String _sort = 'name_asc';

  List<InventoryListItem> _applySort(List<InventoryListItem> list) {
    final items = [...list];
    switch (_sort) {
      case 'name_desc':
        items.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case 'stock_asc':
        items.sort((a, b) => a.stock.compareTo(b.stock));
        break;
      case 'stock_desc':
        items.sort((a, b) => b.stock.compareTo(a.stock));
        break;
      case 'name_asc':
      default:
        items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryNotifierProvider);
    final notifier = ref.read(inventoryNotifierProvider.notifier);
    final theme = Theme.of(context);

    final filtered = state.items.where((e) {
      if (state.onlyLowStock && !e.isLowStock) return false;
      final catId = state.selectedCategoryId;
      if (catId != null) {
        // We only have category name in stock response; category filter will be basic
        // In a full app, map id->name. For now, match by id via categories list and compare names.
        final selected = state.categories.firstWhere(
          (c) => c.categoryId == catId,
          orElse: () => CategoryDto(categoryId: -1, name: ''),
        );
        if (selected.name.isNotEmpty && e.categoryName != selected.name) {
          return false;
        }
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          IconButton(
            tooltip: 'New Product',
            onPressed: () async {
              final created = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ProductFormPage(),
                ),
              );
              if (created == true) {
                await notifier.refreshList();
              }
            },
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Row 1: Search + Sort (95:5 approx)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search products by name, SKU or barcode',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: notifier.setQuery,
                  ),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  tooltip: 'Sort',
                  initialValue: _sort,
                  onSelected: (v) => setState(() => _sort = v),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'name_asc', child: Text('Name (A–Z)')),
                    PopupMenuItem(value: 'name_desc', child: Text('Name (Z–A)')),
                    PopupMenuItem(value: 'stock_desc', child: Text('Stock (High→Low)')),
                    PopupMenuItem(value: 'stock_asc', child: Text('Stock (Low→High)')),
                  ],
                  icon: const Icon(Icons.sort_rounded),
                ),
              ],
            ),
          ),
          // Row 2: Category (70) + Filters (30)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 7,
                  child: _CategoryPicker(
                    categories: state.categories,
                    selectedId: state.selectedCategoryId,
                    onChanged: (id) => notifier.setCategory(id),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Low stock'),
                          selected: state.onlyLowStock,
                          onSelected: (v) => notifier.setOnlyLowStock(v),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (state.isLoading)
            const LinearProgressIndicator(minHeight: 2),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(state.error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          // Row 3: Right-aligned view toggle with a vertical divider
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(
              children: [
                const Spacer(),
                Container(width: 1, height: 24, color: theme.dividerColor.withOpacity(0.5)),
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
          Expanded(
            child: _buildListingOrEmpty(context, _applySort(filtered)),
          ),
        ],
      ),
    );
  }

  Widget _buildListingOrEmpty(BuildContext context, List<InventoryListItem> items) {
    final state = ref.watch(inventoryNotifierProvider);
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No products available'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final created = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProductFormPage()),
                );
                if (created == true && mounted) {
                  await ref.read(inventoryNotifierProvider.notifier).refreshList();
                }
              },
              child: const Text('Create one'),
            ),
          ],
        ),
      );
    }
    return state.viewMode == InventoryViewMode.grid
        ? _GridList(items: items)
        : _ListView(items: items);
  }
}

class _CategoryPicker extends StatefulWidget {
  const _CategoryPicker({
    required this.categories,
    required this.selectedId,
    required this.onChanged,
  });
  final List<CategoryDto> categories;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.categories
        .where((c) => c.categoryId == widget.selectedId)
        .toList();
    _controller.text = selected.isNotEmpty ? selected.first.name : '';
    return Autocomplete<CategoryDto>(
      initialValue: TextEditingValue(text: _controller.text),
      displayStringForOption: (c) => c.name,
      optionsBuilder: (text) {
        final q = text.text.toLowerCase();
        return widget.categories
            .where((c) => c.name.toLowerCase().contains(q));
      },
      onSelected: (c) => widget.onChanged(c.categoryId),
      fieldViewBuilder: (context, controller, focus, onSubmit) {
        return TextField(
          controller: controller,
          focusNode: focus,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.category_rounded),
            hintText: 'Category',
          ),
        );
      },
    );
  }
}

class _GridList extends StatelessWidget {
  const _GridList({required this.items});
  final List<InventoryListItem> items;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortest = size.shortestSide;
    final crossAxisCount = shortest >= 1100
        ? 4
        : shortest >= 900
            ? 3
            : shortest >= 600
                ? 2
                : 1;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _InventoryCard(item: items[i]),
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView({required this.items});
  final List<InventoryListItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _InventoryTile(item: items[i]),
    );
  }
}

class _InventoryCard extends ConsumerWidget {
  const _InventoryCard({required this.item});
  final InventoryListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final low = item.isLowStock;
    return InkWell(
      onTap: () async {
        final updated = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductEditPage(productId: item.productId),
          ),
        );
        if (updated == true) {
          await ref.read(inventoryNotifierProvider.notifier).refreshList();
        }
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (low)
                    Chip(
                      label: const Text('Low'),
                      backgroundColor: theme.colorScheme.errorContainer,
                      labelStyle: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                (item.sku ?? '').isNotEmpty ? 'SKU: ${item.sku}' : 'SKU: —',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Stock: ${item.stock.toStringAsFixed(2)}'),
                  Text(
                    item.price != null ? 'Price: ${item.price!.toStringAsFixed(2)}' : '',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryTile extends ConsumerWidget {
  const _InventoryTile({required this.item});
  final InventoryListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final low = item.isLowStock;
    return ListTile(
      onTap: () async {
        final updated = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductEditPage(productId: item.productId),
          ),
        );
        if (updated == true) {
          await ref.read(inventoryNotifierProvider.notifier).refreshList();
        }
      },
      tileColor: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [(item.sku ?? '').isNotEmpty ? 'SKU: ${item.sku}' : null,
                item.categoryName]
            .whereType<String>()
            .join(' • '),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Stock: ${item.stock.toStringAsFixed(2)}'),
          if (low)
            Text('Low',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                )),
        ],
      ),
    );
  }
}
