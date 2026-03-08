import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dashboard/controllers/location_notifier.dart';
import '../../../dashboard/data/models.dart';
import '../../../dashboard/presentation/widgets/dashboard_sidebar.dart';
import '../../data/accounts_repository.dart';
import '../../data/models.dart';
import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../reports/presentation/pages/report_category_page.dart';
import '../../../reports/presentation/pages/report_viewer_page.dart';

class DayEndFlowPage extends ConsumerStatefulWidget {
  const DayEndFlowPage({
    super.key,
    this.fromMenu = false,
    this.onMenuSelect,
  });

  final bool fromMenu;
  final void Function(BuildContext context, String label)? onMenuSelect;

  @override
  ConsumerState<DayEndFlowPage> createState() => _DayEndFlowPageState();
}

enum _Step { count, review, zreport }

class _DayEndFlowPageState extends ConsumerState<DayEndFlowPage> {
  bool _loading = true;
  Object? _error;
  CashRegisterDto? _openRegister;
  _Step _step = _Step.count;

  final Map<String, TextEditingController> _counts = {
    '100': TextEditingController(),
    '50': TextEditingController(),
    '20': TextEditingController(),
    '10': TextEditingController(),
    '5': TextEditingController(),
    '1': TextEditingController(),
    '0.5': TextEditingController(),
    '0.25': TextEditingController(),
    '0.1': TextEditingController(),
    '0.05': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _counts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final loc = ref.read(locationNotifierProvider).selected;
    if (loc == null) {
      setState(() {
        _loading = false;
        _error = 'Select a location to run Day End.';
        _openRegister = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref
          .read(accountsRepositoryProvider)
          .getCashRegisters(locationId: loc.locationId);
      final open = list.where((r) => r.status.toUpperCase() == 'OPEN').toList();
      setState(() {
        _openRegister = open.isEmpty ? null : open.first;
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, int> _denominations() {
    final out = <String, int>{};
    _counts.forEach((k, c) {
      final n = int.tryParse(c.text.trim()) ?? 0;
      if (n > 0) out[k] = n;
    });
    return out;
  }

  double _countedTotal() {
    var total = 0.0;
    for (final entry in _denominations().entries) {
      final denom = double.tryParse(entry.key) ?? 0.0;
      total += denom * entry.value;
    }
    return total;
  }

  Future<void> _close(Location loc) async {
    final reg = _openRegister;
    if (reg == null) return;
    final counted = _countedTotal();
    try {
      await ref.read(accountsRepositoryProvider).closeCashRegister(
            closingBalance: counted,
            denominations: _denominations(),
            locationId: loc.locationId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash register closed')),
      );
      setState(() => _step = _Step.count);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locState = ref.watch(locationNotifierProvider);
    final loc = locState.selected;
    final reg = _openRegister;
    final theme = Theme.of(context);

    final scaffold = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.fromMenu,
        leading: widget.fromMenu
            ? Builder(
                builder: (context) => IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        title: const Text('Day End'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      drawer: widget.fromMenu
          ? DashboardSidebar(
              onSelect: (label) => widget.onMenuSelect?.call(context, label),
            )
          : null,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? AppErrorView(error: _error!, onRetry: _load)
                : reg == null
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text('No open cash register.'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: loc == null ? null : () => _load(),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Check again'),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Open register #${reg.registerId}',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Expected: ${reg.expectedBalance.toStringAsFixed(2)}',
                                  ),
                                  Text(
                                    'Cash in/out: ${reg.cashIn.toStringAsFixed(2)} / ${reg.cashOut.toStringAsFixed(2)}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_step == _Step.count) ...[
                            Text(
                              'Count cash by denominations',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            ..._counts.entries.map((e) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextField(
                                  controller: e.value,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Denomination ${e.key}',
                                    prefixIcon:
                                        const Icon(Icons.payments_rounded),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: () =>
                                  setState(() => _step = _Step.review),
                              child: Text(
                                'Review total (${_countedTotal().toStringAsFixed(2)})',
                              ),
                            ),
                          ] else if (_step == _Step.review) ...[
                            Text(
                              'Review',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Card(
                              elevation: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Counted: ${_countedTotal().toStringAsFixed(2)}',
                                    ),
                                    Text(
                                      'Expected: ${reg.expectedBalance.toStringAsFixed(2)}',
                                    ),
                                    Text(
                                      'Variance: ${(_countedTotal() - reg.expectedBalance).toStringAsFixed(2)}',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        setState(() => _step = _Step.count),
                                    child: const Text('Back'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () =>
                                        setState(() => _step = _Step.zreport),
                                    child: const Text('Z report'),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Text(
                              'Z report',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                                'Export/share the Daily Cash report, then close the session.'),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () async {
                                const cfg = ReportConfig(
                                  title: 'Daily Cash',
                                  endpoint: '/reports/daily-cash',
                                  description: 'Daily cash activity overview.',
                                );
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ReportViewerPage(
                                      config: cfg,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.receipt_long_rounded),
                              label: const Text('Open Daily Cash report'),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        setState(() => _step = _Step.review),
                                    child: const Text('Back'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed:
                                        loc == null ? null : () => _close(loc),
                                    icon: const Icon(Icons.lock_rounded),
                                    label: const Text('Close session'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
      ),
    );

    if (!widget.fromMenu) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }
}
