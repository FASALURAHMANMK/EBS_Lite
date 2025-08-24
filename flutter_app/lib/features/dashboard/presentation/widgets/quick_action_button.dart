// lib/dashboard/presentation/quick_action_button.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A polished, animated “speed-dial” style FAB with radial fan-out actions.
/// - Dynamic sizing & spacing
/// - Staggered scale+fade animation
/// - Tap‑outside scrim to close
/// - Optional callbacks & custom colors
///
/// Place it inside a Stack aligned to bottomRight (or wherever you want).
///
/// Example:
/// ```dart
/// Align(
///   alignment: Alignment.bottomRight,
///   child: QuickActionButton(
///     actions: [
///       QuickAction(icon: Icons.point_of_sale_rounded, label: 'Sale', onTap: () {} ),
///       QuickAction(icon: Icons.shopping_cart_rounded, label: 'Purchase', onTap: () {} ),
///       QuickAction(icon: Icons.payments_rounded, label: 'Collection', onTap: () {} ),
///       QuickAction(icon: Icons.money_off_csred_rounded, label: 'Expense', onTap: () {} ),
///     ],
///   ),
/// )
/// ```
class QuickActionButton extends StatefulWidget {
  const QuickActionButton({
    super.key,
    this.actions = const [],
    this.openIcon = Icons.close_rounded,
    this.closedIcon = Icons.add_rounded,
    this.primaryColor,
    this.distance = 100, // how far actions fly out from the main FAB
    this.startAngleDegrees = 15, // where the fan starts (relative to +X axis)
    this.sweepAngleDegrees = 105, // how wide the fan spreads
    this.heroTag,
    this.onOpenChanged,
    this.initiallyOpen = false,
    this.useExtendedLabelsOnWide = true,
  });

  /// Actions to show in the radial menu.
  final List<QuickAction> actions;

  /// Icon for the main FAB when opened.
  final IconData openIcon;

  /// Icon for the main FAB when closed.
  final IconData closedIcon;

  /// Optional main FAB color; defaults to theme color.
  final Color? primaryColor;

  /// Distance from the main FAB to each action.
  final double distance;

  /// Fan start angle in degrees (0 = pointing right, 90 = up).
  final double startAngleDegrees;

  /// Total sweep angle of the fan in degrees.
  final double sweepAngleDegrees;

  /// Optional hero tag for the main FAB.
  final Object? heroTag;

  /// Callback when open/close changes.
  final ValueChanged<bool>? onOpenChanged;

  /// Whether the menu starts opened.
  final bool initiallyOpen;

  /// On wider layouts, actions use extended FABs with visible labels.
  final bool useExtendedLabelsOnWide;

  @override
  State<QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<QuickActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late bool _open;

  @override
  void initState() {
    super.initState();
    _open = widget.initiallyOpen;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
    if (_open) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        HapticFeedback.selectionClick();
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
    widget.onOpenChanged?.call(_open);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final isWide = media.size.shortestSide >= 600;

    // Keep actions within safe area (e.g., avoid bottom system nav).
    final bottomPadding = media.viewPadding.bottom;

    // Visual tuning.
    final primary = widget.primaryColor ?? theme.colorScheme.primary;
    final iconColor = theme.colorScheme.onPrimary;

    // If there are no actions, render only a single FAB.
    final actions = widget.actions;
    final count = actions.length;

    return IgnorePointer(
      ignoring: false,
      child: SizedBox(
        // Allow enough space for the fan to expand in any direction.
        width: math.max(160, widget.distance + 64),
        height: math.max(160, widget.distance + 64 + bottomPadding),
        child: Stack(
          alignment: Alignment.bottomRight,
          clipBehavior: Clip.none,
          children: [
            // Tap-outside scrim (only visible when open)
            if (_open)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) {
                      return Container(
                        color: Colors.transparent,
                      );
                    },
                  ),
                ),
              ),

            // Fan-out action buttons
            ...List.generate(count, (i) {
              // Distribute actions evenly across the sweep angle.
              final t = (count == 1) ? 0.5 : i / (count - 1);
              final angleDeg =
                  widget.startAngleDegrees + t * widget.sweepAngleDegrees;
              final angleRad = angleDeg * math.pi / 224.0;

              final dx = math.cos(angleRad) * widget.distance;
              final dy = math.sin(angleRad) * widget.distance;

              // Stagger each action slightly
              final base = CurvedAnimation(
                parent: _controller,
                curve: Interval(0.0, 0.7, curve: Curves.easeOutBack),
                reverseCurve: Curves.easeIn,
              );

              final scale = Tween(begin: 0.6, end: 1.0).animate(base);
              final opacity = Tween(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: _controller,
                  curve: Interval(
                      0.15 + i * (0.12 / math.max(1, count - 1)), 1.0,
                      curve: Curves.easeOut),
                ),
              );

              final action = actions[i];
              final heroTag = '${action.label}_${action.icon}_$i${hashCode}';

              // On wide layouts, show extended FABs with labels.
              final showExtended = widget.useExtendedLabelsOnWide && isWide;

              return Positioned(
                right: dx,
                bottom: dy + bottomPadding,
                child: FadeTransition(
                  opacity: opacity,
                  child: ScaleTransition(
                    scale: scale,
                    child: Semantics(
                      button: true,
                      label: action.label,
                      child: showExtended
                          ? _ExtendedMiniFab(
                              heroTag: heroTag,
                              icon: action.icon,
                              label: action.label,
                              backgroundColor: action.backgroundColor ??
                                  theme.colorScheme.surfaceContainerHighest,
                              foregroundColor: action.foregroundColor ??
                                  theme.colorScheme.onSurface,
                              onTap: () {
                                _toggle();
                                action.onTap?.call();
                              },
                            )
                          : FloatingActionButton.small(
                              heroTag: heroTag,
                              tooltip: action.label,
                              backgroundColor: action.backgroundColor ??
                                  theme.colorScheme.surfaceContainerHighest,
                              foregroundColor: action.foregroundColor ??
                                  theme.colorScheme.onSurface,
                              onPressed: () {
                                _toggle();
                                action.onTap?.call();
                              },
                              child: Icon(action.icon),
                            ),
                    ),
                  ),
                ),
              );
            }),

            // Main FAB
            Positioned(
              right: 0,
              bottom: bottomPadding,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                  final icon = _open ? widget.openIcon : widget.closedIcon;
                  return FloatingActionButton(
                    heroTag: widget.heroTag,
                    backgroundColor: primary,
                    foregroundColor: iconColor,
                    onPressed: _toggle,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) => RotationTransition(
                          turns: Tween(begin: 0.85, end: 1.0).animate(anim),
                          child: FadeTransition(opacity: anim, child: child)),
                      child: Icon(icon, key: ValueKey<bool>(_open)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single quick action definition.
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.backgroundColor,
    this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;
}

/// A compact, extended-style mini FAB with label — good for wide layouts.
class _ExtendedMiniFab extends StatelessWidget {
  const _ExtendedMiniFab({
    required this.heroTag,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final Object heroTag;
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Hero(
      tag: heroTag,
      // Keep hero effects subtle for mini fabs with labels.
      createRectTween: (begin, end) =>
          MaterialRectArcTween(begin: begin, end: end),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: ShapeDecoration(
              color: backgroundColor,
              shape: const StadiumBorder(),
              shadows: kElevationToShadow[1] ?? const [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foregroundColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
