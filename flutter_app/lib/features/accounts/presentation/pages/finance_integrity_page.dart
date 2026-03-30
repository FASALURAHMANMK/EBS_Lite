import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../shared/widgets/app_error_view.dart';
import '../../../auth/controllers/auth_permissions_provider.dart';
import '../../../dashboard/presentation/widgets/dashboard_sidebar.dart';
import '../../data/accounts_repository.dart';
import '../../data/models.dart';

class FinanceIntegrityPage extends ConsumerStatefulWidget {
  const FinanceIntegrityPage({
    super.key,
    this.fromMenu = false,
    this.onMenuSelect,
  });

  final bool fromMenu;
  final void Function(BuildContext context, String label)? onMenuSelect;

  @override
  ConsumerState<FinanceIntegrityPage> createState() =>
      _FinanceIntegrityPageState();
}

class _FinanceIntegrityPageState extends ConsumerState<FinanceIntegrityPage> {
  static const _allStatuses = ['', 'PENDING', 'FAILED', 'COMPLETED'];

  bool _loading = true;
  bool _busy = false;
  Object? _error;
  String _status = '';
  FinanceIntegrityDiagnosticsDto? _diagnostics;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(accountsRepositoryProvider);
      final data = await repo.getFinanceDiagnostics(status: _status);
      if (!mounted) return;
      setState(() => _diagnostics = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runReplay() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(accountsRepositoryProvider);
      final result = await repo.replayFinanceOutbox();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Replay finished. ${result.succeededCount} succeeded, ${result.failedCount} failed.',
            ),
          ),
        );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runLedgerRepair() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(accountsRepositoryProvider);
      final result = await repo.repairMissingLedger();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Ledger repair queued ${result.enqueuedCount} documents. ${result.failedCount} failures remain.',
            ),
          ),
        );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(authHasPermissionProvider('MANAGE_SETTINGS'));
    final theme = Theme.of(context);
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final diagnostics = _diagnostics;
    final summary = diagnostics?.summary;

    final scaffold = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.fromMenu,
        leadingWidth: (!widget.fromMenu && isWide) ? 104 : null,
        leading: widget.fromMenu
            ? Builder(
                builder: (context) => IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : (isWide ? const DesktopSidebarToggleLeading() : null),
        title: const Text('Finance Integrity'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
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
                : diagnostics == null
                    ? const Center(child: Text('No diagnostics available'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _allStatuses
                                  .map(
                                    (status) => ChoiceChip(
                                      label: Text(
                                        status.isEmpty
                                            ? 'All statuses'
                                            : status,
                                      ),
                                      selected: _status == status,
                                      onSelected: (_) async {
                                        setState(() => _status = status);
                                        await _load();
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _SummaryCard(
                                  label: 'Pending',
                                  value: summary?.pendingCount ?? 0,
                                  color: theme.colorScheme.primaryContainer,
                                ),
                                _SummaryCard(
                                  label: 'Failed',
                                  value: summary?.failedCount ?? 0,
                                  color: theme.colorScheme.errorContainer,
                                ),
                                _SummaryCard(
                                  label: 'Processing',
                                  value: summary?.processingCount ?? 0,
                                  color: theme.colorScheme.secondaryContainer,
                                ),
                                _SummaryCard(
                                  label: 'Completed',
                                  value: summary?.completedCount ?? 0,
                                  color: theme.colorScheme.tertiaryContainer,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed:
                                      _busy || !canManage ? null : _runReplay,
                                  icon: const Icon(Icons.replay_rounded),
                                  label: const Text('Replay Outbox'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _busy || !canManage
                                      ? null
                                      : _runLedgerRepair,
                                  icon: const Icon(Icons.rule_folder_outlined),
                                  label: const Text('Repair Missing Ledger'),
                                ),
                              ],
                            ),
                            if (!canManage) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Replay and repair actions require MANAGE_SETTINGS permission.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Text(
                              'Outbox Backlog',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            if (diagnostics.outboxEntries.isEmpty)
                              const Card(
                                child: ListTile(
                                  title: Text('No finance outbox entries.'),
                                  subtitle: Text(
                                    'Guaranteed async side effects are currently clear.',
                                  ),
                                ),
                              )
                            else
                              ...diagnostics.outboxEntries
                                  .map(_buildOutboxCard),
                            const SizedBox(height: 24),
                            Text(
                              'Missing Ledger Postings',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            if (diagnostics.missingLedgerEntries.isEmpty)
                              const Card(
                                child: ListTile(
                                  title: Text('No missing ledger postings.'),
                                  subtitle: Text(
                                    'Operational documents currently reconcile to ledger entries.',
                                  ),
                                ),
                              )
                            else
                              ...diagnostics.missingLedgerEntries
                                  .map(_buildMismatchCard),
                          ],
                        ),
                      ),
      ),
    );

    if (!widget.fromMenu) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }

  Widget _buildOutboxCard(FinanceOutboxEntryDto entry) {
    final df = DateFormat('yyyy-MM-dd HH:mm');
    return Card(
      child: ListTile(
        leading: Icon(
          entry.status == 'FAILED'
              ? Icons.error_outline_rounded
              : entry.status == 'PENDING'
                  ? Icons.schedule_rounded
                  : Icons.check_circle_outline_rounded,
        ),
        title: Text(
            '${entry.eventType} • ${entry.aggregateType} #${entry.aggregateId}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: ${entry.status} • Attempts: ${entry.attemptCount} • Next: ${df.format(entry.nextAttemptAt.toLocal())}',
            ),
            if ((entry.lastError ?? '').isNotEmpty) Text(entry.lastError!),
          ],
        ),
      ),
    );
  }

  Widget _buildMismatchCard(FinanceLedgerMismatchDto item) {
    final df = DateFormat('yyyy-MM-dd');
    final date = item.documentDate == null
        ? 'Unknown date'
        : df.format(item.documentDate!.toLocal());
    return Card(
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded),
        title: Text('${item.documentType} • ${item.documentNumber}'),
        subtitle: Text(
          '${item.diagnostic}\nDate: $date • Amount: ${item.totalAmount.toStringAsFixed(2)}',
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
