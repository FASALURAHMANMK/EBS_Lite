import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../controllers/inventory_notifier.dart';
import '../../data/models.dart';
import '../../../dashboard/controllers/location_notifier.dart';
import '../../../dashboard/data/models.dart';
import '../../../../core/outbox/outbox_notifier.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../../shared/widgets/app_message_view.dart';
import '../../../../shared/widgets/app_scrollbar.dart';
import '../../../../shared/widgets/no_network_view.dart';
import 'product_transactions_page.dart';

class InventoryViewPage extends ConsumerStatefulWidget {
  const InventoryViewPage({super.key});

  @override
  ConsumerState<InventoryViewPage> createState() => _InventoryViewPageState();
}

class _InventoryViewPageState extends ConsumerState<InventoryViewPage> {
  String _sort = 'name_asc';
  bool _promptedLocation = false;

  List<InventoryListItem> _applySort(List<InventoryListItem> list) {
    final items = [...list];
    switch (_sort) {
      case 'name_desc':
        items.sort(
            (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case 'stock_asc':
        items.sort((a, b) => a.stock.compareTo(b.stock));
        break;
      case 'stock_desc':
        items.sort((a, b) => b.stock.compareTo(a.stock));
        break;
      case 'name_asc':
      default:
        items.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return items;
  }

  Future<void> _openSortDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Sort by'),
        children: [
          RadioGroup<String>(
            groupValue: _sort,
            onChanged: (value) => Navigator.of(context).pop(value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                RadioListTile<String>(
                  value: 'name_asc',
                  title: Text('Name (A–Z)'),
                ),
                RadioListTile<String>(
                  value: 'name_desc',
                  title: Text('Name (Z–A)'),
                ),
                RadioListTile<String>(
                  value: 'stock_desc',
                  title: Text('Stock (High→Low)'),
                ),
                RadioListTile<String>(
                  value: 'stock_asc',
                  title: Text('Stock (Low→High)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (choice != null) {
      setState(() => _sort = choice);
    }
  }

  Future<void> _openCategoryDialog({
    required List<CategoryDto> categories,
    required List<int> selectedIds,
    required ValueChanged<List<int>> onApply,
  }) async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (context) {
        final Set<int> current = {...selectedIds};
        String query = '';
        List<CategoryDto> filtered = categories;
        return StatefulBuilder(
          builder: (context, setInner) => AlertDialog(
            title: const Text('Select Category'),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search categories',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (v) {
                      query = v.toLowerCase();
                      setInner(() {
                        filtered = categories
                            .where((c) => c.name.toLowerCase().contains(query))
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No categories'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final c = filtered[i];
                              final checked = current.contains(c.categoryId);
                              return CheckboxListTile(
                                title: Text(c.name),
                                value: checked,
                                onChanged: (v) {
                                  setInner(() {
                                    if (v ?? false) {
                                      current.add(c.categoryId);
                                    } else {
                                      current.remove(c.categoryId);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(<int>[]),
                child: const Text('Clear'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(selectedIds),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(current.toList()),
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
    if (result != null) {
      onApply(result);
    }
  }

  Future<void> _openFilterDialog({
    required bool onlyLowStock,
    required ValueChanged<bool> onApply,
  }) async {
    bool low = onlyLowStock;
    final applied = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Filters'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: low,
                  onChanged: (v) => setInner(() => low = v ?? false),
                  title: const Text('Low stock only'),
                  controlAffinity: ListTileControlAffinity.leading,
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
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (applied == true) {
      onApply(low);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryNotifierProvider);
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final locState = ref.watch(locationNotifierProvider);
    ref.listen<LocationState>(locationNotifierProvider, (prev, next) async {
      final prevId = prev?.selected?.locationId;
      final nextId = next.selected?.locationId;
      if (nextId != null && nextId != prevId) {
        await ref.read(inventoryNotifierProvider.notifier).refreshList();
      }
    });

    // If stock-changing operations sync, refresh stock list so cards don't stay stale.
    ref.listen(outboxNotifierProvider, (prev, next) async {
      if (!next.isOnline) return;
      if (next.lastSyncAt != prev?.lastSyncAt) {
        await ref.read(inventoryNotifierProvider.notifier).refreshList();
      }
    });

    if (!_promptedLocation &&
        locState.selected == null &&
        locState.locations.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showLocationPicker(locState.locations);
        _promptedLocation = true;
      });
    }
    final notifier = ref.read(inventoryNotifierProvider.notifier);
    final theme = Theme.of(context);

    final filtered = state.items.where((e) {
      if (state.onlyLowStock && !e.isLowStock) return false;
      final selectedIds = state.selectedCategoryIds;
      if (selectedIds.isNotEmpty) {
        if (e.categoryId == null || !selectedIds.contains(e.categoryId)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Inventory'),
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
                      hintText: 'Search products',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: notifier.setQuery,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isWide ? 300 : MediaQuery.sizeOf(context).width - 112,
                  child: _CategoryField(
                    label: 'Category',
                    valueText: () {
                      if (state.selectedCategoryIds.isEmpty) {
                        return 'All categories';
                      }
                      if (state.selectedCategoryIds.length == 1) {
                        final id = state.selectedCategoryIds.first;
                        return state.categories
                            .firstWhere(
                              (c) => c.categoryId == id,
                              orElse: () =>
                                  CategoryDto(categoryId: -1, name: ''),
                            )
                            .name;
                      }
                      return '${state.selectedCategoryIds.length} selected';
                    }(),
                    onTap: () => _openCategoryDialog(
                      categories: state.categories,
                      selectedIds: state.selectedCategoryIds,
                      onApply: (ids) => notifier.setCategories(ids),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _openSortDialog,
                  icon: const Icon(Icons.sort_rounded),
                  label: const Text('Sort'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openFilterDialog(
                    onlyLowStock: state.onlyLowStock,
                    onApply: (low) => notifier.setOnlyLowStock(low),
                  ),
                  icon: const Icon(Icons.filter_list_rounded),
                  label: const Text('Filters'),
                ),
                Chip(label: Text('${filtered.length} items')),
                if (state.onlyLowStock)
                  const Chip(label: Text('Low stock only')),
              ],
            ),
          ),
          if (state.isLoading) const LinearProgressIndicator(minHeight: 2),
          if (state.error != null && state.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: TextStyle(color: theme.colorScheme.error),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        ref.read(inventoryNotifierProvider.notifier).load(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: SegmentedButton<InventoryViewMode>(
                segments: const [
                  ButtonSegment(
                    value: InventoryViewMode.grid,
                    icon: Icon(Icons.grid_view_rounded),
                    label: Text('Grid'),
                  ),
                  ButtonSegment(
                    value: InventoryViewMode.list,
                    icon: Icon(Icons.view_list_rounded),
                    label: Text('List'),
                  ),
                ],
                selected: {state.viewMode},
                onSelectionChanged: (selection) =>
                    notifier.setViewMode(selection.first),
              ),
            ),
          ),
          Expanded(
            child: _buildListingOrEmpty(context, _applySort(filtered)),
          ),
        ],
      ),
    );
  }

  Future<void> _showLocationPicker(List<Location> locations) async {
    final notifier = ref.read(locationNotifierProvider.notifier);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Location'),
          content: SizedBox(
            width: 360,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: locations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final loc = locations[index];
                return ListTile(
                  title: Text(loc.name),
                  onTap: () async {
                    await notifier.select(loc);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListingOrEmpty(
      BuildContext context, List<InventoryListItem> items) {
    final state = ref.watch(inventoryNotifierProvider);
    if (items.isEmpty) {
      if (state.isLoading) {
        return const AppLoadingView(label: 'Loading products');
      }
      if (state.error != null) {
        final outbox = ref.watch(outboxNotifierProvider);
        void onRetry() => ref.read(inventoryNotifierProvider.notifier).load();
        return outbox.isOnline
            ? AppMessageView(
                icon: Icons.error_outline_rounded,
                title: 'Unable to load products',
                message: state.error!,
                onRetry: onRetry,
              )
            : NoNetworkView(onRetry: onRetry);
      }
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 64),
          AppEmptyView(
            title: 'No products available',
            message:
                'Products for the selected filters and location will appear here.',
            icon: Icons.inventory_2_outlined,
          ),
        ],
      );
    }
    return state.viewMode == InventoryViewMode.grid
        ? _GridList(items: items)
        : _ListView(items: items);
  }
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.label,
    required this.valueText,
    required this.onTap,
  });
  final String label;
  final String valueText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          hintText: 'Category',
          prefixIcon: Icon(Icons.category_rounded),
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                valueText.isEmpty ? label : valueText,
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }
}

class _GridList extends StatelessWidget {
  const _GridList({required this.items});
  final List<InventoryListItem> items;

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
        return AppScrollbar(
          builder: (context, controller) => GridView.builder(
            controller: controller,
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => _InventoryCard(item: items[i]),
          ),
        );
      },
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView({required this.items});
  final List<InventoryListItem> items;

  @override
  Widget build(BuildContext context) {
    return AppScrollbar(
      builder: (context, controller) => ListView.separated(
        controller: controller,
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _InventoryTile(item: items[i]),
      ),
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
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductTransactionsPage(
              productId: item.productId,
              productName: item.name,
            ),
          ),
        );
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
                children: [
                  Expanded(
                    child: Text(
                      'Stock: ${item.stock.toStringAsFixed(2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (item.price != null)
                    Expanded(
                      child: Text(
                        'Price: ${item.price!.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
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
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductTransactionsPage(
              productId: item.productId,
              productName: item.name,
            ),
          ),
        );
      },
      tileColor: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          (item.sku ?? '').isNotEmpty ? 'SKU: ${item.sku}' : null,
          item.categoryName
        ].whereType<String>().join(' · '),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Stock: ${item.stock.toStringAsFixed(2)}'),
          if (item.price != null)
            Text(
              'Price: ${item.price!.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
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
