import 'package:flutter/material.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import 'report_viewer_page.dart';
import '../../../dashboard/presentation/widgets/dashboard_sidebar.dart';

class ReportConfig {
  final String title;
  final String endpoint;
  final String description;
  final bool supportsDateRange;
  final bool supportsLocation;
  final bool supportsGroupBy;
  final bool supportsLimit;
  final bool supportsProductId;
  final bool supportsExpensesGroupBy;

  const ReportConfig({
    required this.title,
    required this.endpoint,
    required this.description,
    this.supportsDateRange = true,
    this.supportsLocation = true,
    this.supportsGroupBy = false,
    this.supportsLimit = false,
    this.supportsProductId = false,
    this.supportsExpensesGroupBy = false,
  });
}

class ReportCategoryPage extends StatelessWidget {
  const ReportCategoryPage({
    super.key,
    required this.title,
    required this.reports,
    this.fromMenu = false,
    this.onMenuSelect,
  });

  final String title;
  final List<ReportConfig> reports;
  final bool fromMenu;
  final void Function(BuildContext context, String label)? onMenuSelect;

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
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
            : (isWide ? const DesktopSidebarToggleLeading() : null),
        leadingWidth: (!fromMenu && isWide) ? 104 : null,
        title: Text(title),
      ),
      drawer: fromMenu
          ? DashboardSidebar(
              onSelect: (label) => onMenuSelect?.call(context, label),
            )
          : null,
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final r = reports[i];
          return Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.bar_chart_rounded),
              title: Text(r.title),
              subtitle: Text(r.description),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReportViewerPage(config: r),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (!fromMenu) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }
}
