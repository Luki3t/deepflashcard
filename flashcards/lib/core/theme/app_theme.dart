import 'package:flutter/material.dart';

const _seedColor = Colors.teal;

final lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.light,
  ),
);

final darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.dark,
  ),
);
