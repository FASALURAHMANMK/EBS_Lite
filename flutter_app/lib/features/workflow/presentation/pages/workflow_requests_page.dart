import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../core/error_handler.dart';
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
  List<WorkflowRequestDto> _requests = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(workflowRepositoryProvider).listRequests();
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? const Center(child: Text('No pending requests'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = _requests[i];
                      final subtitle = [
                        'State ${r.stateId}',
                        'Approver role ${r.approverRoleId}',
                        'Created by ${r.createdBy}',
                        if (r.remarks != null && r.remarks!.trim().isNotEmpty)
                          'Remarks: ${r.remarks!.trim()}',
                      ].join(' • ');
                      return Card(
                        elevation: 0,
                        child: ListTile(
                          leading: const Icon(Icons.approval_rounded),
                          title: Text('Request #${r.approvalId}'),
                          subtitle: Text(subtitle),
                          onTap: () async {
                            final ok = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        WorkflowRequestDetailPage(request: r),
                                  ),
                                ) ??
                                false;
                            if (ok) await _load();
                          },
                          trailing: canApprove
                              ? Text(
                                  r.status,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
    );

    if (!widget.fromMenu) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }
}

class WorkflowRequestDetailPage extends ConsumerStatefulWidget {
  const WorkflowRequestDetailPage({super.key, required this.request});

  final WorkflowRequestDto request;

  @override
  ConsumerState<WorkflowRequestDetailPage> createState() =>
      _WorkflowRequestDetailPageState();
}

class _WorkflowRequestDetailPageState
    extends ConsumerState<WorkflowRequestDetailPage> {
  bool _saving = false;

  Future<String?> _askRemarks(String title) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Remarks (optional)',
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
    if (remarks == null && !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(workflowRepositoryProvider)
          .approve(widget.request.approvalId, remarks: remarks);
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
    if (remarks == null && !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(workflowRepositoryProvider)
          .reject(widget.request.approvalId, remarks: remarks);
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

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final perms = ref.watch(authPermissionsProvider);
    final canApprove = perms.contains('APPROVE_WORKFLOWS');

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: Text('Request #${r.approvalId}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${r.status}',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('State ID: ${r.stateId}'),
                  Text('Approver role ID: ${r.approverRoleId}'),
                  Text('Created by user ID: ${r.createdBy}'),
                  if (r.updatedBy != null) Text('Updated by: ${r.updatedBy}'),
                  if (r.approvedAt != null)
                    Text('Approved at: ${r.approvedAt}'),
                  if (r.remarks != null && r.remarks!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Remarks: ${r.remarks!.trim()}'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (!canApprove || _saving) ? null : _reject,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (!canApprove || _saving) ? null : _approve,
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
                'You do not have permission to approve/reject.',
              ),
            ),
        ],
      ),
    );
  }
}
