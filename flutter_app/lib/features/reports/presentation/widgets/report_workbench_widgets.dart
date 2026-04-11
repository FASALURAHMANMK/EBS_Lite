import 'package:flutter/material.dart';

import '../../../../shared/widgets/professional_document_widgets.dart';
import '../pages/report_category_page.dart';

class ReportWorkbenchPane extends StatelessWidget {
  const ReportWorkbenchPane({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.headerTrailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (headerTrailing != null) ...[
                  const SizedBox(width: 8),
                  headerTrailing!,
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class ReportCapabilityWrap extends StatelessWidget {
  const ReportCapabilityWrap({
    super.key,
    required this.config,
  });

  final ReportConfig config;

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      const ProfessionalBadge(label: 'Print / Export ready'),
      ..._capabilityLabels(config)
          .map((label) => ProfessionalBadge(label: label)),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges,
    );
  }
}

class ReportConfigOverviewCard extends StatelessWidget {
  const ReportConfigOverviewCard({
    super.key,
    required this.config,
    this.action,
  });

  final ReportConfig config;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ProfessionalSectionCard(
      title: config.title,
      subtitle: config.description,
      action: action,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ProfessionalBadge(label: config.endpoint),
            ],
          ),
          const SizedBox(height: 12),
          ReportCapabilityWrap(config: config),
        ],
      ),
    );
  }
}

List<String> reportCapabilityLabels(ReportConfig config) =>
    _capabilityLabels(config);

List<String> _capabilityLabels(ReportConfig config) {
  final labels = <String>[];
  if (config.supportsDateRange) {
    labels.add('Date range');
  }
  if (config.supportsLocation) {
    labels.add('Location');
  }
  if (config.supportsGroupBy) {
    labels.add('Group by');
  }
  if (config.supportsExpensesGroupBy) {
    labels.add('Expense grouping');
  }
  if (config.supportsLimit) {
    labels.add('Limit');
  }
  if (config.supportsProductId) {
    labels.add('Product filter');
  }
  if (labels.isEmpty) {
    labels.add('Fixed report');
  }
  return labels;
}
