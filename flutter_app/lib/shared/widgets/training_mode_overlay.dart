import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/accounts/controllers/training_mode_notifier.dart';

class TrainingModeOverlay extends ConsumerWidget {
  const TrainingModeOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainingEnabled = ref.watch(trainingModeEnabledProvider);

    if (!trainingEnabled) return child;

    final theme = Theme.of(context);
    final trainingBannerTextStyle = (theme.textTheme.labelLarge ??
            theme.textTheme.bodyMedium ??
            const TextStyle())
        .copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w600,
    );
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.center,
              child: Opacity(
                opacity: 0.07,
                child: Transform.rotate(
                  angle: -0.4,
                  child: Text(
                    'TRAINING',
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: Material(
                color: Colors.orange.shade800.withValues(alpha: 0.92),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.school_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'TRAINING MODE — transactions will not post to stock/cash',
                          style: trainingBannerTextStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
