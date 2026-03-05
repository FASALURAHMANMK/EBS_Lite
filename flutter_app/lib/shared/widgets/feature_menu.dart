import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import 'feature_grid.dart';

export 'feature_grid.dart' show FeatureItem;

/// Responsive "feature menu" used by module landing pages.
///
/// - Phones: shows the existing card grid.
/// - Tablets/desktops: shows a clean list (no menu cards).
class FeatureMenu extends StatelessWidget {
  const FeatureMenu({
    super.key,
    required this.items,
    this.title,
    this.padding,
  });

  final List<FeatureItem> items;
  final String? title;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);

    if (!isWide) {
      return FeatureGrid(
        items: items,
        padding: padding ?? const EdgeInsets.all(16),
      );
    }

    final theme = Theme.of(context);
    final effectivePadding = padding ?? AppBreakpoints.pagePadding(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView.separated(
          padding: effectivePadding,
          itemCount: items.length + (title == null ? 0 : 1),
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (title != null) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    title!,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }
              index -= 1;
            }
            final item = items[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: Icon(item.icon, color: theme.colorScheme.primary),
              title: Text(item.label),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: item.onTap,
            );
          },
        ),
      ),
    );
  }
}
