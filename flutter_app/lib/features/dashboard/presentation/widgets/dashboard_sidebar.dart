import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_confirm_dialog.dart';
import '../../../auth/controllers/auth_notifier.dart';
import '../../../auth/controllers/auth_permissions_provider.dart';
import '../../controllers/location_notifier.dart';
import '../../data/models.dart';
import 'company_logo.dart';

class DashboardSidebar extends ConsumerStatefulWidget {
  const DashboardSidebar({super.key, this.onSelect});

  final ValueChanged<String>? onSelect;

  @override
  ConsumerState<DashboardSidebar> createState() => _DashboardSidebarState();
}

class _DashboardSidebarState extends ConsumerState<DashboardSidebar> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final perms = ref.watch(authPermissionsProvider);
    final locationState = ref.watch(locationNotifierProvider);

    final showApprovals = perms.contains('VIEW_WORKFLOWS');

    return Drawer(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Brand header
            Container(
              alignment: Alignment.bottomCenter,
              height: 140, // custom height
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _CompanyLogo(radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            authState.company?.name ?? '',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (locationState.locations.isNotEmpty)
                          Flexible(
                            child: DropdownButton<Location>(
                              isExpanded: true,
                              value: locationState.selected,
                              dropdownColor: theme.colorScheme.primaryContainer,
                              iconEnabledColor: Colors.white,
                              items: locationState.locations
                                  .map(
                                    (l) => DropdownMenuItem<Location>(
                                      value: l,
                                      child: Text(
                                        l.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (loc) {
                                if (loc != null) {
                                  ref
                                      .read(locationNotifierProvider.notifier)
                                      .select(loc);
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _item(context, Icons.grid_view_rounded, 'Dashboard'),
                  const Divider(height: 24),
                  _section(context, Icons.account_balance_wallet_rounded,
                      'Accounts', const [
                    'Banking',
                    'Cash Register',
                    'Chart of Accounts',
                    'Day Open/Close',
                    'Expenses',
                    'Finance Integrity',
                    'Period Close',
                    'Vouchers',
                    'Ledgers',
                    'Audit Logs'
                  ]),
                  _section(context, Icons.group_rounded, 'HR', const [
                    'Departments & Designations',
                    'Employees',
                    'Attendance Register',
                    'Payroll Management'
                  ]),
                  _section(context, Icons.bar_chart_rounded, 'Reports', const [
                    'Sales Reports',
                    'Purchase Reports',
                    'Accounts Reports',
                    'Inventory Reports',
                  ]),
                  const Divider(height: 24),
                  if (showApprovals)
                    _item(context, Icons.approval_rounded, 'Approvals'),
                  if (showApprovals) const Divider(height: 24),
                  _item(context, Icons.settings_rounded, 'Settings'),
                  const Divider(height: 24),
                  ListTile(
                    leading: Icon(Icons.help_outline_rounded,
                        color: theme.colorScheme.primary),
                    title: const Text('Help & Support'),
                    horizontalTitleGap: 12,
                    onTap: () {
                      Navigator.pop(context);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        widget.onSelect?.call('Help & Support');
                      });
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.logout_rounded,
                        color: theme.colorScheme.primary),
                    title: const Text('Logout'),
                    horizontalTitleGap: 12,
                    onTap: () async {
                      final confirm = await showAppConfirmDialog(
                        context,
                        title: 'Logout',
                        message: 'Are you sure you want to logout?',
                        confirmLabel: 'Logout',
                        icon: Icons.logout_rounded,
                        destructive: true,
                      );
                      if (confirm == true) {
                        await ref.read(authNotifierProvider.notifier).logout();
                      }
                    },
                  ),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'v1.0.0',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label),
      horizontalTitleGap: 12,
      onTap: () {
        Navigator.pop(context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.onSelect?.call(label);
        });
      },
    );
  }

  Widget _section(BuildContext context, IconData icon, String title,
      List<String> children) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        childrenPadding: const EdgeInsets.only(left: 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .map(
              (label) => ListTile(
                leading: const SizedBox(
                    width: 24, child: Icon(Icons.circle, size: 6)),
                title: Text(label),
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.only(left: 8, right: 16),
                onTap: () {
                  Navigator.pop(context);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    widget.onSelect?.call(label);
                  });
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CompanyLogo extends ConsumerWidget {
  const _CompanyLogo({required this.radius});
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CompanyLogo(radius: radius);
  }
}
