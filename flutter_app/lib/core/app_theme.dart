import 'package:flutter/material.dart';

/// Brand palette derived from the logo
const Color _brandRed = Colors.red; // punchy crimson (logo red)
const Color _brandGray = Color(0xFFB5B8BD); // light logo gray
const Color _brandGrayDark = Color(0xFF8F9398); // darker logo gray

// Neutrals
const Color _bgLight = Color(0xFFFFFFFF);
const Color _surfaceLight = Color(0xFFF7F8FA);
const Color _bgDark = Color(0xFF0F1114);
const Color _surfaceDark = Color(0xFF15181C);

// Shared radii
const BorderRadius _rMd = BorderRadius.all(Radius.circular(16));
const BorderRadius _rLg = BorderRadius.all(Radius.circular(20));

ColorScheme _lightScheme() {
  final base =
      ColorScheme.fromSeed(seedColor: _brandRed, brightness: Brightness.light);
  return base.copyWith(
    primary: _brandRed,
    onPrimary: Colors.white,
    secondary: _brandGrayDark,
    onSecondary: Colors.white,
    background: _bgLight,
    onBackground: const Color(0xFF111418),
    surface: _surfaceLight,
    onSurface: const Color(0xFF1A1E23),
    surfaceVariant: const Color(0xFFEAECEF),
    outline: const Color(0xFFE0E3E7),
    outlineVariant: const Color(0xFFD6DADF),
    primaryContainer: const Color(0xFFFFE6EC),
    onPrimaryContainer: const Color(0xFF6A0017),
    secondaryContainer: const Color(0xFFE7EAEE),
    onSecondaryContainer: const Color(0xFF1E2329),
    error: const Color(0xFFB3261E),
    onError: Colors.white,
  );
}

ColorScheme _darkScheme() {
  final base =
      ColorScheme.fromSeed(seedColor: _brandRed, brightness: Brightness.dark);
  return base.copyWith(
    primary: _brandRed,
    onPrimary: Colors.white,
    secondary: _brandGray,
    onSecondary: Colors.black,
    background: _bgDark,
    onBackground: Colors.white,
    surface: _surfaceDark,
    onSurface: Colors.white,
    surfaceVariant: const Color(0xFF23272D),
    outline: const Color(0xFF2E343B),
    outlineVariant: const Color(0xFF2A2F36),
    primaryContainer: const Color(0xFF3A0B16),
    onPrimaryContainer: const Color(0xFFFFDEE5),
    secondaryContainer: const Color(0xFF2A2F36),
    onSecondaryContainer: Colors.white,
    error: const Color(0xFFFFB4AB),
    onError: const Color(0xFF690005),
  );
}

/// LIGHT THEME
final ThemeData lightTheme = () {
  final scheme = _lightScheme();
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.background,
    splashFactory: InkSparkle.splashFactory,

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.background,
      foregroundColor: scheme.onBackground,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: scheme.onBackground,
      ),
      toolbarHeight: 56,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: scheme.onBackground),
      actionsIconTheme: IconThemeData(color: scheme.onBackground),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(
        borderRadius: _rLg,
        side: BorderSide(color: scheme.outline, width: 1),
      ),
    ),

    // Inputs
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.5)),
      border: OutlineInputBorder(
          borderRadius: _rMd, borderSide: BorderSide(color: scheme.outline)),
      enabledBorder: OutlineInputBorder(
          borderRadius: _rMd, borderSide: BorderSide(color: scheme.outline)),
      focusedBorder: OutlineInputBorder(
          borderRadius: _rMd,
          borderSide: BorderSide(color: scheme.primary, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: _rMd, borderSide: BorderSide(color: scheme.error)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: _rMd,
          borderSide: BorderSide(color: scheme.error, width: 2)),
      labelStyle: TextStyle(color: scheme.onSurface.withOpacity(0.8)),
    ),

    // Buttons
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: _rMd),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: _rMd),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: scheme.outline),
        foregroundColor: scheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: _rMd),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: _rMd),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),

    // Selection controls
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected) ? scheme.primary : scheme.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    radioTheme:
        RadioThemeData(fillColor: MaterialStatePropertyAll(scheme.primary)),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected) ? scheme.primary : scheme.outline),
      trackColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected)
              ? scheme.primary.withOpacity(.25)
              : scheme.outline.withOpacity(.4)),
    ),

    // Chips
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surface,
      selectedColor: scheme.primary.withOpacity(0.15),
      disabledColor: scheme.surfaceVariant,
      labelStyle: TextStyle(color: scheme.onSurface),
      side: BorderSide(color: scheme.outline),
      shape: RoundedRectangleBorder(borderRadius: _rMd),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),

    // NavigationBar (bottom)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      elevation: 0,
      // Remove the selected indicator “chip”
      indicatorColor: Colors.transparent,
      // Smaller labels; fill selected label with primary color
      labelTextStyle: MaterialStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight:
              states.contains(MaterialState.selected) ? FontWeight.w700 : FontWeight.w600,
          color: states.contains(MaterialState.selected)
              ? scheme.primary
              : scheme.onSurface.withOpacity(.70),
        ),
      ),
      iconTheme: MaterialStateProperty.resolveWith(
        (s) => IconThemeData(
            color: s.contains(MaterialState.selected)
                ? scheme.primary
                : scheme.onSurface.withOpacity(.70)),
      ),
      height: 64,
    ),

    // Tabs
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurface.withOpacity(0.6),
      indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: scheme.primary, width: 2)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    // NavigationRail (desktop/tablet sidebar)
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      selectedIconTheme: IconThemeData(color: scheme.primary),
      unselectedIconTheme:
          IconThemeData(color: scheme.onSurface.withOpacity(.70)),
      selectedLabelTextStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: scheme.primary,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface.withOpacity(.70),
      ),
    ),

    // Dividers & Lists
    dividerTheme:
        DividerThemeData(color: scheme.outline, thickness: 1, space: 24),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: _rMd),
      tileColor: scheme.surface,
      selectedTileColor: scheme.primary.withOpacity(0.06),
      iconColor: scheme.onSurface.withOpacity(.8),
      titleTextStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),

    // FAB
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: const CircleBorder(),
      elevation: 0,
    ),

    // BottomSheet & Dialogs
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: _rLg),
    ),

    // SnackBar & Progress
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.primary,
      contentTextStyle:
          TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: _rMd),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    iconTheme: IconThemeData(color: scheme.onSurface.withOpacity(.85)),
  );
}();

/// DARK THEME
final ThemeData darkTheme = () {
  final scheme = _darkScheme();
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.background,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.background,
      foregroundColor: scheme.onBackground,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: scheme.onBackground,
      ),
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: scheme.onBackground),
      actionsIconTheme: IconThemeData(color: scheme.onBackground),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(
        borderRadius: _rLg,
        side: BorderSide(color: scheme.outline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.55)),
      border: OutlineInputBorder(
          borderRadius: _rMd, borderSide: BorderSide(color: scheme.outline)),
      enabledBorder: OutlineInputBorder(
          borderRadius: _rMd, borderSide: BorderSide(color: scheme.outline)),
      focusedBorder: OutlineInputBorder(
          borderRadius: _rMd,
          borderSide: BorderSide(color: scheme.primary, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: _rMd, borderSide: BorderSide(color: scheme.error)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: _rMd,
          borderSide: BorderSide(color: scheme.error, width: 2)),
      labelStyle: TextStyle(color: scheme.onSurface.withOpacity(0.9)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: _rMd),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: _rMd),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: scheme.outline),
        foregroundColor: scheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: _rMd),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: _rMd),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected) ? scheme.primary : scheme.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    radioTheme:
        RadioThemeData(fillColor: MaterialStatePropertyAll(scheme.primary)),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected) ? scheme.primary : scheme.outline),
      trackColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected)
              ? scheme.primary.withOpacity(.35)
              : scheme.outline.withOpacity(.5)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surface,
      selectedColor: scheme.primary.withOpacity(0.18),
      disabledColor: scheme.surfaceVariant,
      labelStyle: TextStyle(color: scheme.onSurface),
      side: BorderSide(color: scheme.outline),
      shape: RoundedRectangleBorder(borderRadius: _rMd),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      elevation: 0,
      // Remove the selected indicator “chip”
      indicatorColor: Colors.transparent,
      // Smaller labels; fill selected label with primary color
      labelTextStyle: MaterialStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight:
              states.contains(MaterialState.selected) ? FontWeight.w700 : FontWeight.w600,
          color: states.contains(MaterialState.selected)
              ? scheme.primary
              : scheme.onSurface.withOpacity(.75),
        ),
      ),
      iconTheme: MaterialStateProperty.resolveWith(
        (s) => IconThemeData(
            color: s.contains(MaterialState.selected)
                ? scheme.primary
                : scheme.onSurface.withOpacity(.75)),
      ),
      height: 64,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurface.withOpacity(0.7),
      indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: scheme.primary, width: 2)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      selectedIconTheme: IconThemeData(color: scheme.primary),
      unselectedIconTheme:
          IconThemeData(color: scheme.onSurface.withOpacity(.75)),
      selectedLabelTextStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: scheme.primary,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface.withOpacity(.75),
      ),
    ),
    dividerTheme:
        DividerThemeData(color: scheme.outline, thickness: 1, space: 24),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: _rMd),
      tileColor: scheme.surface,
      selectedTileColor: scheme.primary.withOpacity(0.09),
      iconColor: scheme.onSurface.withOpacity(.9),
      titleTextStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: const CircleBorder(),
      elevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: _rLg),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.primary,
      contentTextStyle:
          TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: _rMd),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    iconTheme: IconThemeData(color: scheme.onSurface.withOpacity(.9)),
  );
}();
