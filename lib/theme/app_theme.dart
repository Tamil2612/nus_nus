import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.ink,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brass,
        brightness: Brightness.dark,
      ),
      fontFamily: 'Roboto',
      // Input fields sit on a light "paper" fill regardless of the app's
      // overall dark theme, so force dark text/cursor here rather than
      // letting them inherit the dark-theme's light on-surface color.
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.ink,
        selectionColor: AppColors.brassSoft,
        selectionHandleColor: AppColors.brass,
      ),
    );
  }

  static InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.slate, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.ink, width: 1.4),
      ),
    );
  }

  static ButtonStyle get solidButton {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.ink,
      foregroundColor: AppColors.paper,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    );
  }
}