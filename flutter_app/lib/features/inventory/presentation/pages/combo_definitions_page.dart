import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../data/inventory_repository.dart';
import '../../data/models.dart';
import 'combo_form_page.dart';

class ComboDefinitionsPage extends ConsumerStatefulWidget {
  const ComboDefinitionsPage({super.key});

  @override
  ConsumerState<ComboDefinitionsPage> createState() =>
      _ComboDefinitionsPageState();
}

class _ComboDefinitionsPageState extends ConsumerState<ComboDefinitionsPage> {
  final _search = TextEditingController();
  bool _loading = true;
  List<ComboProductDto> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load([String? search]) async {
    setState(() => _loading = true);
    try {
      final items = await ref
          .read(inventoryRepositoryProvider)
          .getComboProducts(search: search ?? _search.text.trim());
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([int? comboProductId]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ComboFormPage(comboProductId: comboProductId),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Combo Definitions'),
        actions: [
          IconButton(
            tooltip: 'New combo',
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search combos',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => _load(),
                ),
              ),
              onChanged: (_) => _load(),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _items.isEmpty && !_loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No combos yet. Create a virtual bundle for POS and quote workflows.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openForm(item.comboProductId),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ),
                                    if (!item.isActive)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              theme.colorScheme.errorContainer,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: const Text('Inactive'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  [
                                    item.barcode,
                                    if ((item.sku ?? '').trim().isNotEmpty)
                                      item.sku!,
                                    'Price ${item.sellingPrice.toStringAsFixed(2)}',
                                  ].join(' • '),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _MetaChip(
                                      icon: Icons.layers_outlined,
                                      label:
                                          '${item.components.length} components',
                                    ),
                                    if (item.availableStock != null)
                                      _MetaChip(
                                        icon: Icons.inventory_2_outlined,
                                        label:
                                            'Available ${item.availableStock!.toStringAsFixed(2)}',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Combo'),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
