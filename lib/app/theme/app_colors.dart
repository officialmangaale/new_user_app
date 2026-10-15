import 'package:flutter/material.dart';

/// Authoritative Mangaale User App palette. Feature code must take brand,
/// surface and semantic colours from here (or from `Theme.of(context)`), never
/// from ad-hoc `Color(...)` literals.
abstract final class AppColors {
  // Brand.
  static const primary = Color(0xFF17E6DB);
  static const primaryPressed = Color(0xFF12CBC2);

  /// Brand hover/cursor/selection shade. Too light for body text on white
  /// (2.6:1) - use [primaryText] for text and icons on light surfaces.
  static const primaryDark = Color(0xFF0DA9A3);
  static const primaryLight = Color(0xFFCFFAF7);
  static const primaryVeryLight = Color(0xFFEEFEFC);

  /// Content drawn on a [primary] fill (>= 9:1). Never use white on primary.
  static const onPrimary = Color(0xFF111918);

  /// Brand-coloured text/icons on light surfaces (6:1 on white).
  static const primaryText = Color(0xFF0B6E73);

  /// Dark brand surface that carries white content (hero cards, banners).
  static const featureDark = Color(0xFF064E52);

  // Surfaces and text.
  static const background = Color(0xFFF8FAFA);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF667372);
  static const textMuted = Color(0xFF98A3A2);
  static const border = Color(0xFFDCE6E5);
  static const disabledBackground = Color(0xFFE8EEEE);
  static const disabledText = Color(0xFF9AA5A4);
  static const shadow = Color(0x10111827);

  // Semantic - independent of the brand.
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);
  static const successLight = Color(0xFFEAF8EF);
  static const warningLight = Color(0xFFFFF7E5);
  static const errorLight = Color(0xFFFFEDEE);
  static const infoLight = Color(0xFFEAF1FF);

  // Restaurant menu / storefront tokens. Brand-owned: a restaurant's logo or
  // cover never feeds colours into the UI.
  static const ink = Color(0xFF0B2E2C);
  static const inkSecondary = Color(0xFF4A5E5C);
  static const deepTeal = Color(0xFF0B7A73);
  static const mint = Color(0xFFE2FBF9);
  static const pageTint = Color(0xFFF4FAF9);
  static const hairline = Color(0xFFD5E8E6);
  static const coral = Color(0xFFFF7A59);
  static const vegGreen = Color(0xFF1E7B3A);
  static const nonVegBrown = Color(0xFF8B3A1A);

  /// Secondary text on the dark ink banner (>= 9:1 on [ink]).
  static const onInkMuted = Color(0xFFB8D4D1);

  /// Second stop of brand gradients; stays inside the brand family.
  static const secondary = primaryPressed;

  // Compatibility aliases for existing feature code.
  static const dark = primaryText;
  static const light = primaryLight;
  static const navy = featureDark;
}
