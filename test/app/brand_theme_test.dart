import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/app/theme/app_colors.dart';
import 'package:turquoise_delivery/app/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('palette matches the Mangaale brand spec', () {
    expect(AppColors.primary, const Color(0xFF17E6DB));
    expect(AppColors.primaryPressed, const Color(0xFF12CBC2));
    expect(AppColors.primaryDark, const Color(0xFF0DA9A3));
    expect(AppColors.primaryLight, const Color(0xFFCFFAF7));
    expect(AppColors.primaryVeryLight, const Color(0xFFEEFEFC));
    expect(AppColors.onPrimary, const Color(0xFF111918));
    expect(AppColors.background, const Color(0xFFF8FAFA));
    expect(AppColors.textPrimary, const Color(0xFF111827));
    expect(AppColors.border, const Color(0xFFDCE6E5));
  });

  test('theme is driven by the palette', () {
    final theme = AppTheme.light;
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.onPrimary, AppColors.onPrimary);
    expect(theme.colorScheme.error, AppColors.error);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
  });

  test('primary button pressed state uses the pressed shade', () {
    final style = AppTheme.light.filledButtonTheme.style!;
    final bg = style.backgroundColor!;
    expect(bg.resolve({}), AppColors.primary);
    expect(bg.resolve({WidgetState.pressed}), AppColors.primaryPressed);
    expect(bg.resolve({WidgetState.disabled}), AppColors.disabledBackground);
  });

  test('content on brand fills meets WCAG AA', () {
    expect(_contrast(AppColors.primary, AppColors.onPrimary), greaterThan(7));
    expect(
      _contrast(AppColors.primaryPressed, AppColors.onPrimary),
      greaterThan(7),
    );
    // White on the brand fill must stay unused: it does not pass.
    expect(_contrast(AppColors.primary, Colors.white), lessThan(3));
  });

  test('brand text and dark surfaces meet WCAG AA', () {
    expect(
      _contrast(AppColors.primaryText, AppColors.surface),
      greaterThan(4.5),
    );
    expect(
      _contrast(AppColors.primaryText, AppColors.primaryLight),
      greaterThan(4.5),
    );
    expect(_contrast(Colors.white, AppColors.featureDark), greaterThan(4.5));
    expect(
      _contrast(AppColors.textPrimary, AppColors.background),
      greaterThan(7),
    );
  });

  test('semantic colours are independent of the brand', () {
    final brand = {
      AppColors.primary,
      AppColors.primaryPressed,
      AppColors.primaryDark,
      AppColors.primaryLight,
    };
    for (final semantic in [
      AppColors.success,
      AppColors.warning,
      AppColors.error,
      AppColors.info,
    ]) {
      expect(brand.contains(semantic), isFalse);
    }
    expect(AppColors.success, const Color(0xFF16A34A));
    expect(AppColors.error, const Color(0xFFDC2626));
    expect(AppColors.info, const Color(0xFF2563EB));
  });
}
