import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../auth/controllers/auth_permissions_provider.dart';
import '../../../dashboard/presentation/widgets/dashboard_sidebar.dart';
import '../../data/workflow_repository.dart';

class WorkflowRequestsPage extends ConsumerStatefulWidget {
  const WorkflowRequestsPage({
    super.key,
    this.fromMenu = false,
    this.onMenuSelect,
  });

  final bool fromMenu;
  final void Function(BuildContext context, String label)? onMenuSelect;

  @override
  ConsumerState<WorkflowRequestsPage> createState() =>
      _WorkflowRequestsPageState();
}

class _WorkflowRequestsPageState extends ConsumerState<WorkflowRequestsPage> {
  bool _loading = true;
  String _status = 'PENDING';
  List<WorkflowRequestDto> _requests = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(workflowRepositoryProvider).listRequests(
            status: _status == 'ALL' ? '' : _status,
          );
      if (!mounted) return;
      setState(() => _requests = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRequest(WorkflowRequestDto request) async {
    final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => WorkflowRequestDetailPage(
              approvalId: request.approvalId,
              initialRequest: request,
            ),
          ),
        ) ??
        false;
    if (changed && mounted) {
      await _load();
    }
  }

  String _formatDue(DateTime? value) {
    if (value == null) return 'No due date';
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Color _statusColor(BuildContext context, WorkflowRequestDto request) {
    final scheme = Theme.of(context).colorScheme;
    if (request.status == 'APPROVED') return Colors.green;
    if (request.status == 'REJECTED') return scheme.error;
    if (request.isOverdue) return Colors.orange;
    return scheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final perms = ref.watch(authPermissionsProvider);
    final canApprove = perms.contains('APPROVE_WORKFLOWS');

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
            : (isWide ? const DesktopSidebarToggleLeading() : null),
        leadingWidth: (!widget.fromMenu && isWide) ? 104 : null,
        title: const Text('Approvals'),
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
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: ['PENDING', 'APPROVED', 'REJECTED', 'ALL']
                  .map(
                    (value) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: _status == value,
                        label: Text(value),
                        onSelected: _loading
                            ? null
                            : (_) async {
                                setState(() => _status = value);
                                await _load();
                              },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const AppLoadingView(label: 'Loading approval requests')
                : _requests.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 64),
                            AppEmptyView(
                              title: 'No workflow requests',
                              message:
                                  'Operational approvals and reviews will appear here.',
                              icon: Icons.approval_outlined,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _requests.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final r = _requests[i];
                            final statusColor = _statusColor(context, r);
                            return Card(
                              elevation: 0,
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      statusColor.withValues(alpha: .12),
                                  child: Icon(
                                    r.isPending
                                        ? Icons.approval_rounded
                                        : (r.status == 'APPROVED'
                                            ? Icons.task_alt_rounded
                                            : Icons.cancel_outlined),
                                    color: statusColor,
                                  ),
                                ),
                                title: Text(
                                  r.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if ((r.summary ?? '').trim().isNotEmpty)
                                        Text(r.summary!.trim()),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _MetaChip(label: r.status),
                                          _MetaChip(label: r.module),
                                          _MetaChip(label: r.priority),
                                          _MetaChip(label: r.entityLabel),
                                          _MetaChip(
                                            label: r.isOverdue
                                                ? 'Overdue'
                                                : _formatDue(r.dueAt),
                                          ),
                                        ],
                                      ),
                                      if ((r.createdByName ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Requested by ${r.createdByName!.trim()}',
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                isThreeLine: true,
                                onTap: () => _openRequest(r),
                                trailing: canApprove && r.isPending
                                    ? const Icon(Icons.chevron_right_rounded)
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );

    if (!widget.fromMenu) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }
}

class WorkflowRequestDetailPage extends ConsumerStatefulWidget {
  const WorkflowRequestDetailPage({
    super.key,
    required this.approvalId,
    this.initialRequest,
  });

  final int approvalId;
  final WorkflowRequestDto? initialRequest;

  @override
  ConsumerState<WorkflowRequestDetailPage> createState() =>
      _WorkflowRequestDetailPageState();
}

class _WorkflowRequestDetailPageState
    extends ConsumerState<WorkflowRequestDetailPage> {
  bool _loading = false;
  bool _saving = false;
  WorkflowRequestDto? _request;

  @override
  void initState() {
    super.initState();
    _request = widget.initialRequest;
    if (widget.initialRequest == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final request = await ref
          .read(workflowRepositoryProvider)
          .getRequest(widget.approvalId);
      if (!mounted) return;
      setState(() => _request = request);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _askRemarks(String title) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Reason or remarks',
              ),
              minLines: 2,
              maxLines: 6,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return null;
    return controller.text.trim();
  }

  Future<void> _approve() async {
    final remarks = await _askRemarks('Approve request');
    if (!mounted || remarks == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(workflowRepositoryProvider)
          .approve(widget.approvalId, remarks: remarks);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reject() async {
    final remarks = await _askRemarks('Reject request');
    if (!mounted || remarks == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(workflowRepositoryProvider)
          .reject(widget.approvalId, remarks: remarks);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmtDateTime(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final perms = ref.watch(authPermissionsProvider);
    final canApprove = perms.contains('APPROVE_WORKFLOWS');

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: Text('Request #${widget.approvalId}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading && request == null
          ? const AppLoadingView(label: 'Loading workflow request')
          : request == null
              ? const AppEmptyView(
                  title: 'Workflow request unavailable',
                  message: 'The request could not be loaded.',
                  icon: Icons.error_outline_rounded,
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if ((request.summary ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(request.summary!.trim()),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _MetaChip(label: request.status),
                                _MetaChip(label: request.module),
                                _MetaChip(label: request.priority),
                                _MetaChip(label: request.entityLabel),
                                _MetaChip(label: request.actionType),
                                _MetaChip(
                                  label: request.isOverdue
                                      ? 'Overdue'
                                      : 'Due ${_fmtDateTime(request.dueAt)}',
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _InfoLine(
                              label: 'Requested by',
                              value: request.createdByName ??
                                  'User #${request.createdBy}',
                            ),
                            _InfoLine(
                              label: 'Approver role',
                              value: request.approverRoleName ??
                                  'Role #${request.approverRoleId}',
                            ),
                            _InfoLine(
                              label: 'Created',
                              value: _fmtDateTime(request.createdAt),
                            ),
                            if ((request.requestReason ?? '').trim().isNotEmpty)
                              _InfoLine(
                                label: 'Request reason',
                                value: request.requestReason!.trim(),
                              ),
                            if ((request.decisionReason ?? '')
                                .trim()
                                .isNotEmpty)
                              _InfoLine(
                                label: 'Decision reason',
                                value: request.decisionReason!.trim(),
                              ),
                            if (request.approvedAt != null)
                              _InfoLine(
                                label: 'Decision time',
                                value: _fmtDateTime(request.approvedAt),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (request.events.isNotEmpty)
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Audit Trail',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 12),
                              ...request.events.map(
                                (event) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Icon(
                                          Icons.fiber_manual_record_rounded,
                                          size: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              event.eventType,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            Text(
                                              [
                                                if ((event.actorName ?? '')
                                                    .trim()
                                                    .isNotEmpty)
                                                  event.actorName!.trim(),
                                                _fmtDateTime(event.createdAt),
                                              ].join(' • '),
                                            ),
                                            if ((event.remarks ?? '')
                                                .trim()
                                                .isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 2),
                                                child:
                                                    Text(event.remarks!.trim()),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                (!canApprove || _saving || !request.isPending)
                                    ? null
                                    : _reject,
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                (!canApprove || _saving || !request.isPending)
                                    ? null
                                    : _approve,
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                    if (!canApprove)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'You do not have permission to approve or reject requests.',
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
