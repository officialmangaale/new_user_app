import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF16B8A6);
  static const primaryPressed = Color(0xFF109F90);
  static const primaryDark = Color(0xFF0E4B47);
  static const featureDark = Color(0xFF103F3C);
  static const primaryLight = Color(0xFFE8F8F5);
  static const primaryVeryLight = Color(0xFFF3FBF9);
  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF172033);
  static const textSecondary = Color(0xFF737B8C);
  static const textMuted = Color(0xFF98A1B2);
  static const border = Color(0xFFE3E7EA);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const warningLight = Color(0xFFFFF7E5);
  static const errorLight = Color(0xFFFFEDEE);
  static const successLight = Color(0xFFEAF8EF);
  static const shadow = Color(0x0A172033);

  // Compatibility aliases for existing feature code.
  static const dark = primaryDark;
  static const light = primaryLight;
  static const navy = featureDark;
}
