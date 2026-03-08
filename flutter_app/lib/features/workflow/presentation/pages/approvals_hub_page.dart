import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/controllers/auth_permissions_provider.dart';
import '../../../hr/presentation/pages/leave_approvals_page.dart';
import '../../../dashboard/presentation/widgets/dashboard_sidebar.dart';
import 'workflow_requests_page.dart';

class ApprovalsHubPage extends ConsumerWidget {
  const ApprovalsHubPage({
    super.key,
    this.fromMenu = false,
    this.onMenuSelect,
  });

  final bool fromMenu;
  final void Function(BuildContext context, String label)? onMenuSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(authPermissionsProvider);
    final canViewWorkflows = perms.contains('VIEW_WORKFLOWS');
    final canViewLeaves = perms.contains('VIEW_LEAVES');

    final scaffold = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !fromMenu,
        leading: fromMenu
            ? Builder(
                builder: (context) => IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        title: const Text('Approvals'),
      ),
      drawer: fromMenu
          ? DashboardSidebar(
              onSelect: (label) => onMenuSelect?.call(context, label),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (!canViewWorkflows && !canViewLeaves)
            const Card(
              elevation: 0,
              child: ListTile(
                leading: Icon(Icons.lock_outline_rounded),
                title: Text('No approvals access'),
                subtitle:
                    Text('Ask your admin to grant approvals permissions.'),
              ),
            ),
          if (canViewWorkflows)
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.approval_rounded),
                title: const Text('Workflow Approvals'),
                subtitle: const Text('Review and approve workflow requests'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const WorkflowRequestsPage()),
                ),
              ),
            ),
          if (canViewLeaves)
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.event_available_rounded),
                title: const Text('Leave Approvals'),
                subtitle: const Text('Approve or reject leave requests'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LeaveApprovalsPage()),
                ),
              ),
            ),
        ],
      ),
    );

    if (!fromMenu) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }
}
