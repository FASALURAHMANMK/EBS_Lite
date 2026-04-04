import 'package:flutter/material.dart';

class ProfessionalDocumentHeader extends StatelessWidget {
  const ProfessionalDocumentHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.badges = const [],
  });

  final String title;
  final String subtitle;
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF4F7FB),
            Color(0xFFE6EEF8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFD4E0EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badges,
          ),
          if (badges.isNotEmpty) const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF19324D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF4A6178),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfessionalBadge extends StatelessWidget {
  const ProfessionalBadge({
    super.key,
    required this.label,
    this.backgroundColor = const Color(0xFFEAF1F8),
    this.foregroundColor = const Color(0xFF23415F),
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class ProfessionalSectionCard extends StatelessWidget {
  const ProfessionalSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.expandChild = false,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final bool expandChild;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if ((subtitle ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: 12),
                  action!,
                ],
              ],
            ),
            const SizedBox(height: 14),
            if (expandChild) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}

class ProfessionalSummaryCard extends StatelessWidget {
  const ProfessionalSummaryCard({
    super.key,
    required this.title,
    required this.rows,
    this.footer,
  });

  final String title;
  final List<({String label, String value, bool emphasize})> rows;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ProfessionalSectionCard(
      title: title,
      child: Column(
        children: [
          for (final row in rows) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.label,
                    style: row.emphasize
                        ? theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          )
                        : theme.textTheme.bodySmall,
                  ),
                ),
                Text(
                  row.value,
                  style: row.emphasize
                      ? theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        )
                      : theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                ),
              ],
            ),
            if (row != rows.last) const SizedBox(height: 10),
          ],
          if (footer != null) ...[
            const SizedBox(height: 14),
            footer!,
          ],
        ],
      ),
    );
  }
}
