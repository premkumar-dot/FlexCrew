import 'package:flutter/material.dart';

class AppTheme {
  static const Color brand = Color(0xFFFF6A00); // FlexCrew orange

  static ThemeData light() {
    // Use an explicit ColorScheme to keep primary consistent across platforms
    final scheme = ColorScheme.light(
      primary: brand,
      onPrimary: Colors.white,
      secondary: brand,
      onSurface: Colors.black87,
      background: Colors.white, // removed tint: use pure white
      surface: Colors.white, // surfaces should be white for a clean look
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.white, // removed tint

      // Let AppBar pick up colorScheme.primary / onPrimary by not hard-coding backgroundColor / foregroundColor
      appBarTheme: const AppBarTheme(
        elevation: 0,
      ),

      // Dialog background and shape (use DialogThemeData to match SDK)
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        titleTextStyle: TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w600),
        contentTextStyle: TextStyle(fontSize: 14, color: Colors.black87),
      ),

      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(width: 1.6, color: Color(0xFFFF6A00)),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand,
          side: BorderSide(color: brand),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: brand),
      ),

      chipTheme: ChipThemeData.fromDefaults(
        secondaryColor: brand,
        brightness: Brightness.light,
        labelStyle: const TextStyle(color: Colors.black87),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: brand),
    );
  }
}

