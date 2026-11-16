import 'package:flutter/material.dart';
export 'camera_filter.dart';

/// App-wide color palette and theme tokens.
/// All features import from here — never hardcode colors in widgets.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF6B3F26); // Espresso brown
  static const Color primaryDark = Color(0xFF4A2A18); // Dark roast
  static const Color accent = Color(0xFFD4813A); // Caramel gold
  static const Color background = Color(0xFFFAF6F2); // Warm cream
  static const Color surface = Color(0xFFFFFFFF); // White card surface
  static const Color surfaceVariant = Color(0xFFF3ECE5); // Latte
  static const Color cardBorder = Color(0xFFDDD0C5); // Warm mocha border
  static const Color onPrimary = Colors.white;
  static const Color onBackground = Color(0xFF2C1A0E); // Dark espresso text
  static const Color onSurface = Color(0xFF7A5C4A); // Muted coffee-brown
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
          surfaceContainerHighest: AppColors.surfaceVariant,
          onPrimary: AppColors.onPrimary,
          onSurface: AppColors.onBackground,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.background,
        cardColor: AppColors.surface,
        dividerColor: AppColors.cardBorder,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.onBackground,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.onBackground),
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.onBackground,
            letterSpacing: 0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          labelStyle: const TextStyle(color: AppColors.onSurface),
          hintStyle: const TextStyle(color: AppColors.onSurface),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: AppColors.onBackground,
          ),
          displayMedium: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: AppColors.onBackground,
          ),
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.onBackground,
          ),
          headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.onBackground,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: AppColors.onBackground),
          bodyMedium: TextStyle(fontSize: 14, color: AppColors.onSurface),
          labelLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.onPrimary,
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFA0633E),
          secondary: Color(0xFFD4813A),
          surface: Color(0xFF1E1208),
          onPrimary: Colors.white,
          onSurface: Color(0xFFC9A98A),
          error: Color(0xFFFF4D6A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0804),
        cardColor: const Color(0xFF1E1208),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1208),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA0633E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A1A0E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFA0633E), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFFC9A98A)),
          hintStyle: const TextStyle(color: Color(0xFFC9A98A)),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: Color(0xFFF5EDE0),
          ),
          displayMedium: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF5EDE0),
          ),
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF5EDE0),
          ),
          headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF5EDE0),
          ),
          bodyLarge: TextStyle(fontSize: 16, color: Color(0xFFF5EDE0)),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFFC9A98A)),
          labelLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      );
}
