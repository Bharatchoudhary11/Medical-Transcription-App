import 'package:flutter/material.dart';

class AppTheme {
  AppTheme({required this.light, required this.dark});

  final ThemeData light;
  final ThemeData dark;
}

AppTheme createTheme() {
  final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0057B8));
  final darkColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF00A1D6),
    brightness: Brightness.dark,
  );
  return AppTheme(
    light: ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: false),
    ),
    dark: ThemeData(
      colorScheme: darkColorScheme,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: false),
    ),
  );
}
