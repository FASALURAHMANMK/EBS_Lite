import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../data/models.dart';
import '../../data/supplier_repository.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import 'supplier_detail_page.dart';
import 'supplier_create_page.dart';

class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key});
  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
  String _query = '';
  late Future<List<SupplierDto>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<SupplierDto>> _load() async {
    final repo = ref.read(supplierRepositoryProvider);
    return repo.getSuppliers(
        search: _query.trim().isEmpty ? null : _query.trim());
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() {
      _future = f;
    });
    await f;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Suppliers'),
        actions: [
          IconButton(
            tooltip: 'New Supplier',
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final created = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SupplierCreatePage()),
              );
              if (created == true) await _refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search suppliers',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                _query = v;
                _refresh();
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<SupplierDto>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AppLoadingView(label: 'Loading suppliers');
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 64),
                        AppErrorView(
                          error: snapshot.error!,
                          onRetry: _refresh,
                        ),
                      ],
                    );
                  }
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 64),
                        const AppEmptyView(
                          title: 'No suppliers yet',
                          message:
                              'Suppliers you create or sync will appear here.',
                          icon: Icons.local_shipping_outlined,
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _SupplierTile(item: items[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierTile extends StatelessWidget {
  const _SupplierTile({required this.item});
  final SupplierDto item;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      tileColor: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(item.name,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Text(
          '${item.usageLabel}\nPurchases: ${item.totalPurchases.toStringAsFixed(2)} • Outstanding: ${item.outstandingAmount.toStringAsFixed(2)}'),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => SupplierDetailPage(supplierId: item.supplierId)),
      ),
    );
  }
}
