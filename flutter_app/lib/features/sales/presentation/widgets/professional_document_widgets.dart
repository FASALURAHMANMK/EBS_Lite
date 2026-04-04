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
            if (expandChild)
              Expanded(child: child)
            else
              Flexible(
                fit: FlexFit.loose,
                child: child,
              ),
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
    this.expandContent = false,
  });

  final String title;
  final List<({String label, String value, bool emphasize})> rows;
  final Widget? footer;
  final bool expandContent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ProfessionalSectionCard(
      title: title,
      expandChild: expandContent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
            if (expandContent) const Spacer(),
            const SizedBox(height: 14),
            footer!,
          ],
        ],
      ),
    );
  }
}

class ProfessionalBanner extends StatelessWidget {
  const ProfessionalBanner({
    super.key,
    required this.message,
    required this.color,
  });

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Text(message, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class ProfessionalOverviewCard extends StatelessWidget {
  const ProfessionalOverviewCard({
    super.key,
    this.title,
    this.icon,
    this.action,
    required this.child,
    this.showHeader = true,
    this.expandChild = false,
  });

  final String? title;
  final IconData? icon;
  final Widget? action;
  final Widget child;
  final bool showHeader;
  final bool expandChild;

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
            if (showHeader) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 16),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            title ?? '',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(width: 10),
                    action!,
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (expandChild) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}

class ProfessionalFieldGridItem {
  const ProfessionalFieldGridItem({
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final int maxLines;
}

class ProfessionalFieldGrid extends StatelessWidget {
  const ProfessionalFieldGrid({
    super.key,
    required this.fields,
    this.minTwoColumnWidth = 360,
  });

  final List<ProfessionalFieldGridItem> fields;
  final double minTwoColumnWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 14.0;
        final columns = constraints.maxWidth >= minTwoColumnWidth ? 2 : 1;
        final itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: 2,
          children: [
            for (final field in fields)
              SizedBox(
                width: itemWidth,
                child: ProfessionalFieldPair(
                  label: field.label,
                  value: field.value,
                  maxLines: field.maxLines,
                ),
              ),
          ],
        );
      },
    );
  }
}

class ProfessionalFieldPair extends StatelessWidget {
  const ProfessionalFieldPair({
    super.key,
    required this.label,
    required this.value,
    this.maxLines = 1,
    this.trailing,
  });

  final String label;
  final String value;
  final int maxLines;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cleanValue = value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  cleanValue.isEmpty ? 'Not set' : cleanValue,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cleanValue.isEmpty
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : null,
                      ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class ProfessionalMetaCell extends StatelessWidget {
  const ProfessionalMetaCell({
    super.key,
    required this.label,
    required this.value,
    this.width = 150,
  });

  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class ProfessionalPreviewRow extends StatelessWidget {
  const ProfessionalPreviewRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: emphasize
                ? theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  )
                : theme.textTheme.bodySmall,
          ),
        ),
        Text(
          value,
          style: emphasize
              ? theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                )
              : theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
        ),
      ],
    );
  }
}

class ProfessionalAmountHighlight extends StatelessWidget {
  const ProfessionalAmountHighlight({
    super.key,
    required this.value,
  });

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: const Color(0xFFBA1A1A),
          ),
    );
  }
}

class ProfessionalDocumentEmptyState extends StatelessWidget {
  const ProfessionalDocumentEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.receipt_long_rounded,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if ((actionLabel ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel!),
              style: professionalCompactButtonStyle(context),
            ),
          ],
        ],
      ),
    );
  }
}

class ProfessionalHeaderCell extends StatelessWidget {
  const ProfessionalHeaderCell({
    super.key,
    required this.label,
    required this.flex,
    this.textAlign = TextAlign.left,
  });

  final String label;
  final int flex;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
      ),
    );
  }
}

class ProfessionalBodyCell extends StatelessWidget {
  const ProfessionalBodyCell({
    super.key,
    required this.label,
    required this.flex,
    this.secondary,
    this.secondaryMaxLines = 1,
    this.emphasize = false,
    this.textAlign = TextAlign.left,
  });

  final String label;
  final int flex;
  final String? secondary;
  final int secondaryMaxLines;
  final bool emphasize;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: textAlign == TextAlign.right
            ? CrossAxisAlignment.end
            : textAlign == TextAlign.center
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (emphasize
                    ? Theme.of(context).textTheme.bodyMedium
                    : Theme.of(context).textTheme.bodySmall)
                ?.copyWith(
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12,
            ),
          ),
          if ((secondary ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              secondary!,
              textAlign: textAlign,
              maxLines: secondaryMaxLines,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10.5,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

ButtonStyle professionalCompactButtonStyle(
  BuildContext context, {
  bool outlined = false,
}) {
  final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
      );
  return outlined
      ? OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(0, 34),
          textStyle: textStyle,
        )
      : FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(0, 34),
          textStyle: textStyle,
        );
}
