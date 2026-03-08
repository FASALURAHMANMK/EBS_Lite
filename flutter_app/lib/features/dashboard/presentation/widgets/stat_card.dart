import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Dashboard cards can get quite small on desktop when the sidebar is open.
        // Make the card resilient by adapting spacing/typography and truncating
        // secondary text in "dense" layouts.
        final dense = constraints.maxHeight < 140 || constraints.maxWidth < 200;
        final padding = dense ? 12.0 : 16.0;
        final iconRadius = dense ? 16.0 : 20.0;
        final iconGap = dense ? 8.0 : 12.0;
        final titleMaxLines = dense ? 1 : 2;
        final showSubtitle = subtitle != null && !dense;

        final titleStyle =
            (dense ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
                ?.copyWith(fontWeight: FontWeight.w600);
        final valueStyle = (dense
                ? theme.textTheme.headlineSmall
                : theme.textTheme.headlineMedium)
            ?.copyWith(
          fontWeight: FontWeight.w700,
          color: color ?? theme.colorScheme.primary,
        );

        return Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null)
                  CircleAvatar(
                    radius: iconRadius,
                    backgroundColor: (color ?? theme.colorScheme.primary)
                        .withValues(alpha: 0.15),
                    child: Icon(
                      icon,
                      color: color ?? theme.colorScheme.primary,
                      size: dense ? 18 : 22,
                    ),
                  ),
                if (icon != null) SizedBox(height: iconGap),
                Text(
                  title,
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: valueStyle,
                        ),
                        if (showSubtitle) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
