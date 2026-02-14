import 'package:flutter/material.dart';

/// Light theme using standard Material 3.
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    scrolledUnderElevation: 4,
    backgroundColor: Color(0xFF1565C0),
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
  ),
);
