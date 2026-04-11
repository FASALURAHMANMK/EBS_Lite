import 'package:flutter/material.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../shared/widgets/professional_document_widgets.dart';
import 'report_viewer_page.dart';
import '../widgets/report_workbench_widgets.dart';
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

class ReportCategoryPage extends StatefulWidget {
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
  State<ReportCategoryPage> createState() => _ReportCategoryPageState();
}

class _ReportCategoryPageState extends State<ReportCategoryPage> {
  ReportConfig? _selectedReport;

  @override
  void initState() {
    super.initState();
    _syncSelectedReport();
  }

  @override
  void didUpdateWidget(covariant ReportCategoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSelectedReport();
  }

  void _syncSelectedReport() {
    if (widget.reports.isEmpty) {
      _selectedReport = null;
      return;
    }
    final selectedEndpoint = _selectedReport?.endpoint;
    final match = widget.reports.where((report) {
      return report.endpoint == selectedEndpoint;
    });
    _selectedReport = match.isNotEmpty ? match.first : widget.reports.first;
  }

  Future<void> _openReport(ReportConfig report) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportViewerPage(
          config: report,
          categoryTitle: widget.title,
          fromMenu: widget.fromMenu,
          onMenuSelect: widget.onMenuSelect,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
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
        title: Text(widget.title),
      ),
      drawer: widget.fromMenu
          ? DashboardSidebar(
              onSelect: (label) => widget.onMenuSelect?.call(context, label),
            )
          : null,
      body: widget.reports.isEmpty
          ? const Center(child: Text('No reports configured'))
          : (isWide ? _buildDesktopBody(context) : _buildMobileBody()),
    );

    if (!widget.fromMenu) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }

  Widget _buildDesktopBody(BuildContext context) {
    final selected = _selectedReport!;
    final padding = AppBreakpoints.pagePadding(context);

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: ReportWorkbenchPane(
              title: widget.title,
              subtitle:
                  'Choose a report to review its filter contract before opening the full results view.',
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: widget.reports.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final report = widget.reports[index];
                  final isSelected =
                      report.endpoint == _selectedReport?.endpoint;
                  final tileColor = isSelected
                      ? Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.40)
                      : null;
                  return Card(
                    elevation: 0,
                    color: tileColor,
                    child: ListTile(
                      selected: isSelected,
                      leading: Icon(
                        Icons.bar_chart_rounded,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(report.title),
                      subtitle: Text(
                        report.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => setState(() => _selectedReport = report),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 6,
            child: ListView(
              children: [
                ProfessionalDocumentHeader(
                  title: widget.title,
                  subtitle:
                      'Desktop report workbench with a persistent category view, visible filter capabilities, and direct drill-in to the live result surface.',
                  badges: [
                    ProfessionalBadge(
                      label: '${widget.reports.length} reports',
                    ),
                    const ProfessionalBadge(label: 'Desktop workbench'),
                    if (widget.fromMenu)
                      const ProfessionalBadge(label: 'Menu aware'),
                  ],
                ),
                const SizedBox(height: 16),
                ReportConfigOverviewCard(
                  config: selected,
                  action: FilledButton.icon(
                    onPressed: () => _openReport(selected),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open report'),
                  ),
                ),
                const SizedBox(height: 16),
                ProfessionalSummaryCard(
                  title: 'Workbench flow',
                  rows: [
                    (
                      label: 'Selected report',
                      value: selected.title,
                      emphasize: true,
                    ),
                    (
                      label: 'Supported filters',
                      value: '${reportCapabilityLabels(selected).length}',
                      emphasize: false,
                    ),
                    (
                      label: 'Output actions',
                      value: 'PDF, Excel, Print',
                      emphasize: false,
                    ),
                    (
                      label: 'Mobile behavior',
                      value: 'Stacked list to detail',
                      emphasize: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final report = widget.reports[index];
        return Card(
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openReport(report),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bar_chart_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          report.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(report.description),
                  const SizedBox(height: 12),
                  ReportCapabilityWrap(config: report),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
