import 'package:flutter/material.dart';

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({
    super.key,
    this.label = 'Loading...',
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spinner = SizedBox(
      width: compact ? 22 : 28,
      height: compact ? 22 : 28,
      child: const CircularProgressIndicator(strokeWidth: 2.4),
    );

    if (compact) {
      return Center(child: spinner);
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              spinner,
              const SizedBox(height: 14),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
