import 'package:flutter/material.dart';

class FeatureItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const FeatureItem({required this.icon, required this.label, this.onTap});
}

class FeatureGrid extends StatelessWidget {
  const FeatureGrid({super.key, required this.items});

  final List<FeatureItem> items;

  int _columnsForWidth(double w) {
    if (w >= 1200) return 4;
    if (w >= 800) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = _columnsForWidth(constraints.maxWidth);
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.25,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _FeatureTile(
              icon: item.icon,
              label: item.label,
              onTap: item.onTap,
              color: theme.colorScheme.surface,
              fg: theme.colorScheme.onSurface,
              highlight: theme.colorScheme.primary.withOpacity(0.08),
            );
          },
        );
      },
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    required this.fg,
    required this.highlight,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color fg;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: highlight,
        highlightColor: highlight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: fg.withOpacity(0.90)),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

