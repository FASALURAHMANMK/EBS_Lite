import 'package:flutter/material.dart';

/// Screen-size breakpoints used to switch the app navigation and layouts.
///
/// We intentionally prefer `shortestSide` for device class detection so large
/// phones in landscape still behave like phones.
class AppBreakpoints {
  AppBreakpoints._();

  /// Tablet and above.
  static const double tabletShortestSide = 600;

  /// Desktop-ish width (used only for spacing tweaks).
  static const double desktopWidth = 1024;

  static bool isTabletOrDesktop(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.shortestSide >= tabletShortestSide;
  }

  static bool isDesktop(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width >= desktopWidth;
  }

  static EdgeInsetsGeometry pagePadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    }
    if (isTabletOrDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
  }
}
