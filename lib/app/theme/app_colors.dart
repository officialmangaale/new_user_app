import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF0F8B7E);
  static const secondary = Color(0xFF0F9D8A);
  static const primaryPressed = Color(0xFF075E54);
  static const primaryDark = Color(0xFF075E54);
  static const featureDark = Color(0xFF075E54);
  static const primaryLight = Color(0xFFDDF7F2);
  static const primaryVeryLight = Color(0xFFF2FBF9);
  static const background = Color(0xFFF7F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF172022);
  static const textSecondary = Color(0xFF667477);
  static const textMuted = Color(0xFF94A3A6);
  static const border = Color(0xFFE4ECEB);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFE5484D);
  static const warningLight = Color(0xFFFFF7E5);
  static const errorLight = Color(0xFFFFEDEE);
  static const successLight = Color(0xFFEAF8EF);
  static const shadow = Color(0x10172022);

  // Compatibility aliases for existing feature code.
  static const dark = primaryDark;
  static const light = primaryLight;
  static const navy = featureDark;
}
