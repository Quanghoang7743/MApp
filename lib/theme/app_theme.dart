import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: '.SF Pro Text',
    );

    return base.copyWith(
      scaffoldBackgroundColor: isDark ? const Color(0xFF131417) : Colors.white,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: const Color(0xFF2A89FF),
        onPrimary: Colors.white,
        secondary: const Color(0xFF9FC6FF),
        onSecondary: Colors.black,
        error: const Color(0xFFD32F2F),
        onError: Colors.white,
        surface: isDark ? const Color(0xFF17191D) : Colors.white,
        onSurface: isDark ? const Color(0xFFF4F5F7) : const Color(0xFF16181D),
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: TextStyle(
          fontSize: 24,
          height: 1.2,
          letterSpacing: -0.4,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFF7F8FA) : const Color(0xFF0F1115),
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          height: 1.25,
          letterSpacing: -0.2,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF131722),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.3,
          letterSpacing: -0.15,
          color: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1D24),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.35,
          letterSpacing: -0.1,
          color: isDark ? const Color(0xFFA9AFBB) : const Color(0xFF7A8394),
        ),
      ),
    );
  }
}
