import 'package:flutter/material.dart';

import 'report_viewer_page.dart';

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
  });

  final String title;
  final List<ReportConfig> reports;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
  }
}
