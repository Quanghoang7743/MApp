import 'package:flutter/material.dart';

import 'auth/auth_flow_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const PremiumAuthApp());
}

class PremiumAuthApp extends StatefulWidget {
  const PremiumAuthApp({super.key});

  @override
  State<PremiumAuthApp> createState() => _PremiumAuthAppState();
}

class _PremiumAuthAppState extends State<PremiumAuthApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Premium Auth UI',
      themeMode: _themeMode,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      home: AuthFlowScreen(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
