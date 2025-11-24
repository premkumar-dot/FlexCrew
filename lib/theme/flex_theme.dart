import 'package:flutter/material.dart';

class AppTheme {
  // Brand orange you’ve been using for the logo/buttons.
  static const Color brand = Color(0xFFF97316); // Tailwind "orange-500"
  static ThemeData light() {
    final base = ThemeData(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: brand,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.white, // <-- no pinkish tint
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: UnderlineInputBorder(),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: brand, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(44),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: brand),
      chipTheme: base.chipTheme.copyWith(
        // Use a neutral background for chips by default to avoid
        // a pale orange/pink tint in some screens. Individual ChoiceChips
        // can still override this where needed.
        color: MaterialStateProperty.all(Colors.white),
        side: BorderSide.none,
        labelStyle: const TextStyle(color: Colors.black87),
      ),
    );
  }
}

