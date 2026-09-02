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

/// Supporting palette for the nature presentation layer.
///
/// Deliberately a separate class rather than new members on [AppColors]: these
/// are additive decoration, and keeping them apart makes it obvious that no
/// existing brand value moved. [AppColors.primary] remains the primary action
/// colour and the source of every flowing-water effect — nothing here replaces
/// it.
///
/// Nothing in this class is applied globally. Each value is opted into by a
/// specific widget, so the nature layer can be removed by deleting
/// `lib/core/nature/` without leaving a theme that depends on it.
abstract final class NatureColors {
  /// Interaction feedback — tap ripples, the drop in flight, the disc behind
  /// the cart icon. Lighter and airier than the brand turquoise so it reads as
  /// water moving over a surface rather than as another button.
  static const aqua = Color(0xFF3FBEAD);
  static const aquaSoft = Color(0xFFDDF2EF);

  /// Ripple fill. Low alpha by design: the ripple must never compete with the
  /// label underneath it.
  static const ripple = Color(0x2E0F8B7E);
  static const rippleEdge = Color(0x5C3FBEAD);

  /// Leaves, freshness and availability.
  ///
  /// Distinct from [AppColors.success], which stays the semantic success colour
  /// for banners and price savings. This is the decorative botanical green.
  static const leaf = Color(0xFF4F9D5D);
  static const leafDeep = Color(0xFF35704A);
  static const leafSoft = Color(0xFFE7F2E8);

  /// Rewards, offers and positive highlights. Used as a soft glow, never as a
  /// flash or a pulse.
  static const sunlight = Color(0xFFF0B429);
  static const sunlightSoft = Color(0xFFFCF3DE);
  static const sunlightGlow = Color(0x33F0B429);

  /// Main background for nature-enabled surfaces. A hair cooler and softer
  /// than [AppColors.background].
  static const offWhite = Color(0xFFF7FAF8);

  /// Secondary surfaces — earthy, warm, used behind grouped content.
  static const beige = Color(0xFFF3EFE6);
  static const beigeDeep = Color(0xFFE8E1D3);

  /// Readable text on nature surfaces. A dark natural green rather than a
  /// neutral charcoal, so type sits in the same world as the rest of the
  /// palette while staying comfortably above contrast minimums on
  /// [offWhite] and [beige].
  static const bark = Color(0xFF172A25);

  /// Earth-inspired depth for cards and floating surfaces. Warmer and softer
  /// than the existing neutral [AppColors.shadow].
  static const shadowNear = Color(0x14183A33);
  static const shadowFar = Color(0x1F183A33);
}
