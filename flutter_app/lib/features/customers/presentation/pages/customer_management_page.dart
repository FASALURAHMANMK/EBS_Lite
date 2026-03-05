import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/customer_repository.dart';
import '../../../../core/outbox/outbox_notifier.dart';
import '../../../../shared/widgets/app_error_view.dart';
import 'customer_detail_page.dart';
import 'customer_create_page.dart';

class CustomerManagementPage extends ConsumerStatefulWidget {
  const CustomerManagementPage({super.key});
  @override
  ConsumerState<CustomerManagementPage> createState() =>
      _CustomerManagementPageState();
}

class _CustomerManagementPageState
    extends ConsumerState<CustomerManagementPage> {
  String _query = '';
  late Future<List<CustomerDto>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CustomerDto>> _load() async {
    final repo = ref.read(customerRepositoryProvider);
    return repo.getCustomers(
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
    // When queued transactions sync (or we regain online), refresh so
    // list cards (credit balances etc) don't stay stale.
    ref.listen(outboxNotifierProvider, (prev, next) {
      if (next.isOnline && next.lastSyncAt != prev?.lastSyncAt) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // ignore: unawaited_futures
          _refresh();
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            tooltip: 'New Customer',
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final created = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CustomerCreatePage()),
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
                hintText: 'Search customers',
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
              child: FutureBuilder<List<CustomerDto>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator(minHeight: 2);
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
                    return const Center(child: Text('No customers'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final theme = Theme.of(context);
                      return ListTile(
                        tileColor: theme.colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        title: Text(
                          item.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                            'Credit Bal: ${item.creditBalance.toStringAsFixed(2)} • Limit: ${item.creditLimit.toStringAsFixed(2)}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CustomerDetailPage(
                                  customerId: item.customerId),
                            ),
                          );
                          if (!mounted) return;
                          await _refresh();
                        },
                      );
                    },
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
