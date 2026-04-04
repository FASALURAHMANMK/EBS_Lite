import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../customers/data/customer_repository.dart';
import '../../../customers/data/models.dart';
import 'b2b_party_form_page.dart';

class B2BPartyManagementPage extends ConsumerStatefulWidget {
  const B2BPartyManagementPage({super.key});

  @override
  ConsumerState<B2BPartyManagementPage> createState() =>
      _B2BPartyManagementPageState();
}

class _B2BPartyManagementPageState
    extends ConsumerState<B2BPartyManagementPage> {
  String _query = '';
  late Future<List<CustomerDto>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CustomerDto>> _load() {
    return ref.read(customerRepositoryProvider).getCustomers(
          search: _query.trim().isEmpty ? null : _query.trim(),
          customerType: 'B2B',
        );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _openForm({int? customerId}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => B2BPartyFormPage(customerId: customerId),
      ),
    );
    if (changed == true) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('B2B Parties'),
        actions: [
          IconButton(
            tooltip: 'New B2B Party',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search parties',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) {
                _query = value;
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
                    return const AppLoadingView(label: 'Loading B2B parties');
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
                      children: const [
                        SizedBox(height: 64),
                        AppEmptyView(
                          title: 'No B2B parties',
                          message:
                              'Create your business customers here for invoices, quotes, and returns.',
                          icon: Icons.business_outlined,
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final subtitle = [
                        if ((item.contactPerson ?? '').isNotEmpty)
                          item.contactPerson!,
                        if ((item.phone ?? '').isNotEmpty) item.phone!,
                        if ((item.taxNumber ?? '').isNotEmpty) item.taxNumber!,
                      ].join(' • ');
                      return Card(
                        elevation: 0,
                        child: ListTile(
                          leading: const Icon(Icons.business_rounded),
                          title: Text(
                            item.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            [
                              if (subtitle.isNotEmpty) subtitle,
                              'Balance ${item.creditBalance.toStringAsFixed(2)}',
                              'Limit ${item.creditLimit.toStringAsFixed(2)}',
                            ].join(' • '),
                          ),
                          trailing: Icon(
                            item.isActive
                                ? Icons.chevron_right_rounded
                                : Icons.pause_circle_outline_rounded,
                          ),
                          onTap: () => _openForm(customerId: item.customerId),
                        ),
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
