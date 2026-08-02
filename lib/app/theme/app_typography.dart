import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static const textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: AppColors.textPrimary,
    ),
    headlineLarge: TextStyle(
      fontSize: 26,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.35,
      color: AppColors.textPrimary,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: AppColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontSize: 15,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
    labelLarge: TextStyle(
      fontSize: 15,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    labelMedium: TextStyle(
      fontSize: 13,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    labelSmall: TextStyle(
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
  );
}
