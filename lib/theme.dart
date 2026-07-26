import 'package:flutter/material.dart';

class AppTheme {
  // Accent colors (shared across themes)
  static const Color softGreen = Color(0xFFA9D7B0);
  static const Color softGreenDark = Color(0xFF6FAF7B);
  static const Color softYellow = Color(0xFFF7E8A4);

  // Dark theme palette (matching website)
  static const Color darkBg = Color(0xFF0A0F0A);
  static const Color darkCard = Color(0xFF111A12);
  static const Color darkCardHover = Color(0xFF162017);
  static const Color darkBorder = Color(0xFF1E2E1F);
  static const Color textLight = Color(0xFFE0E8E1);
  static const Color textMuted = Color(0xFF8A9C8C);

  // Legacy aliases for backward compatibility
  static const Color softCream = darkBg;
  static const Color cardColor = darkCard;
  static const Color textDark = textLight;

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    colorScheme: const ColorScheme.dark(
      primary: softGreenDark,
      secondary: softYellow,
      surface: darkCard,
      onPrimary: Color(0xFF0A0F0A),
      onSecondary: textLight,
      onSurface: textLight,
      outline: darkBorder,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBg,
      foregroundColor: textLight,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: darkBorder, width: 1),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: darkCard,
      indicatorColor: softGreenDark.withValues(alpha: 0.25),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: softGreen);
        }
        return const IconThemeData(color: textMuted);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontWeight: FontWeight.w600,
            color: softGreen,
            fontSize: 12,
          );
        }
        return const TextStyle(
          fontWeight: FontWeight.w500,
          color: textMuted,
          fontSize: 12,
        );
      }),
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(
      color: darkBorder,
      thickness: 1,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        color: textLight,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(
        color: textLight,
      ),
      bodyMedium: TextStyle(
        color: textLight,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkCard,
      contentTextStyle: const TextStyle(color: textLight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: darkBorder),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: darkCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: darkBorder),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: darkCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: darkCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: darkBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: softGreenDark, width: 2),
      ),
      labelStyle: const TextStyle(color: textMuted),
      hintStyle: const TextStyle(color: textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: softGreenDark,
        foregroundColor: const Color(0xFF0A0F0A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: softGreen,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return softGreenDark;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(darkBg),
      side: const BorderSide(color: textMuted, width: 1.5),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: softGreenDark,
      foregroundColor: Color(0xFF0A0F0A),
      elevation: 4,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: textLight,
      iconColor: textMuted,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: softGreenDark,
    ),
  );
}