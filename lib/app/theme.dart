import 'package:flutter/material.dart';

class AppTheme {
  static const Color seed = Color(0xFFC8102E); // MEB kırmızısı
  static const Color cardBg = Color(0xFFFFE2E2); // açık pembe

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: Colors.white,
    cardTheme: const CardThemeData(
      color: cardBg,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
  );
}
