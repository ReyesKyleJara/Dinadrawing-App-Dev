import 'package:flutter/material.dart';

class PlanThemePalette {
  const PlanThemePalette({
    required this.primary,
    required this.onPrimary,
    required this.dark,
    required this.soft,
    required this.softest,
    required this.border,
  });

  final Color primary;
  final Color onPrimary;
  final Color dark;
  final Color soft;
  final Color softest;
  final Color border;

  static const String defaultHex = '#F2B73F';

  static const List<String> presetHexColors = <String>[
    '#F2B73F',
    '#4A78D6',
    '#8B5CF6',
    '#0F9D8A',
    '#E85D9E',
    '#F47B3A',
  ];

  factory PlanThemePalette.fromHex(
    String? value, {
    Brightness brightness = Brightness.light,
  }) {
    final primary = parseHex(value);
    final isDarkMode = brightness == Brightness.dark;

    return PlanThemePalette(
      primary: primary,
      onPrimary: contrastColor(primary),
      dark: Color.lerp(primary, Colors.black, 0.24)!,
      soft: Color.lerp(
        primary,
        isDarkMode ? const Color(0xFF242424) : Colors.white,
        isDarkMode ? 0.72 : 0.70,
      )!,
      softest: Color.lerp(
        primary,
        isDarkMode ? const Color(0xFF171717) : Colors.white,
        isDarkMode ? 0.86 : 0.88,
      )!,
      border: Color.lerp(
        primary,
        isDarkMode ? Colors.white : Colors.black,
        isDarkMode ? 0.10 : 0.04,
      )!.withValues(alpha: isDarkMode ? 0.56 : 0.42),
    );
  }

  static Color parseHex(
    String? value, {
    Color fallback = const Color(0xFFF2B73F),
  }) {
    if (value == null || value.trim().isEmpty) {
      return fallback;
    }

    var clean = value.trim().replaceAll('#', '');

    if (clean.length == 6) {
      clean = 'FF$clean';
    }

    if (clean.length != 8) {
      return fallback;
    }

    try {
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  static String toHex(Color color) {
    final value = color.toARGB32() & 0x00FFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static Color contrastColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }
}
