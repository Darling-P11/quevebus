import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const primary = Color(0xFF1565C0); // azul corporativo
  const secondary = Color(0xFF2E7D32); // verde transporte

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF8F9FB),

    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(height: 1.2),
    ),

    appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),

    // ⬇️ Aquí va CardThemeData (no CardTheme)
    cardTheme: CardThemeData(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0.5,
      surfaceTintColor: Colors.white, // para Material 3
      color: Colors.white,
    ),

    chipTheme: const ChipThemeData(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: Colors.black38),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: Colors.black54,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}
