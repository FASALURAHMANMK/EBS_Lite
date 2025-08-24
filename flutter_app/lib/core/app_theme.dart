import 'package:flutter/material.dart';

/// Light theme definition used across the app.
final ThemeData lightTheme = ThemeData(
  colorScheme: const ColorScheme.light(
    primary: Colors.black,
    secondary: Colors.red,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(backgroundColor: Colors.black, foregroundColor: Colors.white),
  floatingActionButtonTheme:
      const FloatingActionButtonThemeData(backgroundColor: Colors.red, foregroundColor: Colors.white),
  useMaterial3: true,
);

/// Dark theme counterpart
final ThemeData darkTheme = ThemeData(
  colorScheme: const ColorScheme.dark(
    primary: Colors.white,
    secondary: Colors.red,
    surface: Colors.black,
  ),
  scaffoldBackgroundColor: Colors.black,
  appBarTheme: const AppBarTheme(backgroundColor: Colors.black, foregroundColor: Colors.white),
  floatingActionButtonTheme:
      const FloatingActionButtonThemeData(backgroundColor: Colors.red, foregroundColor: Colors.white),
  useMaterial3: true,
);
