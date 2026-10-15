import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Type scale of the restaurant menu screen. Colours come from [AppColors];
/// swap the font family here to restyle the whole screen.
abstract final class MenuText {
  static const restaurantName = TextStyle(
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    color: AppColors.ink,
  );
  static const sectionTitle = TextStyle(
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const itemName = TextStyle(
    fontSize: 17,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
  static const price = TextStyle(
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const description = TextStyle(
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.inkSecondary,
  );
  static const meta = TextStyle(
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: AppColors.inkSecondary,
  );
}

/// Prices are whole rupees everywhere on this screen.
String rupees(num value) => '₹${value.round()}';

/// Initials for the logo fallback badge ("Cafe Mocha" -> "CM").
String initialsOf(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return '';
  final first = String.fromCharCode(words.first.runes.first).toUpperCase();
  if (words.length == 1) return first;
  final last = String.fromCharCode(words.last.runes.first).toUpperCase();
  return '$first$last';
}

/// "11:00" / "11:00:00" -> "11 AM"; anything else is returned unchanged.
String friendlyTime(String raw) {
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})(?::\d{2})?$',
  ).firstMatch(raw.trim());
  if (match == null) return raw.trim();
  final hour = int.parse(match.group(1)!);
  final minute = match.group(2)!;
  if (hour > 23) return raw.trim();
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return minute == '00' ? '$h12 $suffix' : '$h12:$minute $suffix';
}
