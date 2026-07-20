import 'package:flutter/material.dart';

/// Central color palette for Nus-Nus. Keep every hardcoded color in the UI
/// referencing this file so the theme can be retouched from one place.
class AppColors {
  AppColors._();

  static const ink = Color(0xFF142B2B);
  static const inkSoft = Color(0xFF1E3B39);
  static const paper = Color(0xFFF5EFE3);
  static const paperDim = Color(0xFFEDE4D2);
  static const brass = Color(0xFFC99A3C);
  static const brassSoft = Color(0xFFE4C989);
  static const sage = Color(0xFF3F7A5D);
  static const rust = Color(0xFFB24C34);
  static const slate = Color(0xFF6B7A78);
  static const line = Color(0x1F142B2B);

  /// Rotating palette used to color-code each person's avatar.
  static const avatarPalette = [
    Color(0xFFB24C34),
    Color(0xFF3F7A5D),
    Color(0xFFC99A3C),
    Color(0xFF2E6E8E),
    Color(0xFF8E4E9E),
    Color(0xFF6B7A78),
    Color(0xFFA0522D),
    Color(0xFF4A7A8C),
  ];

  static Color avatarColorFor(int index) =>
      avatarPalette[index % avatarPalette.length];
}
