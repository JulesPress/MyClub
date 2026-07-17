import 'package:flutter/material.dart';

class AppTheme {
  static const Color softGreen = Color(0xFFA9D7B0);
  static const Color softGreenDark = Color(0xFF6FAF7B);
  static const Color softYellow = Color(0xFFF7E8A4);
  static const Color softCream = Color(0xFFFFFCF4);
  static const Color cardColor = Colors.white;
  static const Color textDark = Color(0xFF2E3A2F);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: softCream,
    colorScheme: const ColorScheme.light(
      primary: softGreenDark,
      secondary: softYellow,
      surface: cardColor,
      onPrimary: Colors.white,
      onSecondary: textDark,
      onSurface: textDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: softCream,
      foregroundColor: textDark,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: softYellow,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        color: textDark,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(
        color: textDark,
      ),
      bodyMedium: TextStyle(
        color: textDark,
      ),
    ),
  );
}