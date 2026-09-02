import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'nature_preferences.dart';

/// Resolves how much motion a nature effect may use, right where it is about
/// to animate.
///
/// Two inputs, and the OS wins:
///
///  * the platform's accessibility setting, surfaced by Flutter as
///    `MediaQuery.disableAnimations` (iOS "Reduce Motion", Android "Remove
///    animations");
///  * the customer's own Nature Motion preference.
///
/// A customer who has asked their phone for less motion gets less motion,
/// whatever the in-app preference says. The in-app control can only reduce
/// further, never override the OS.
///
/// Reduced never means "nothing happens". It means the travelling part of an
/// effect is replaced by a fade or an immediate state change, so the feedback
/// still lands — the brief's rule that nothing may rely on motion alone.
extension NatureMotionContext on BuildContext {
  /// True when the device itself has asked for reduced motion.
  bool get prefersReducedMotionFromPlatform =>
      MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}

/// Whether full nature motion may play right now.
///
/// Watches the preference, so flipping the setting re-renders anything that
/// depends on it.
bool natureMotionEnabled(WidgetRef ref, BuildContext context) {
  if (context.prefersReducedMotionFromPlatform) return false;
  final mode = ref.watch(
    naturePreferencesProvider.select((state) => state.motionMode),
  );
  return mode == NatureMotionMode.full;
}

/// The same decision without a [WidgetRef], for code holding a plain
/// [Ref] — services and controllers rather than widgets.
///
/// [platformReducedMotion] must be supplied by the caller, because a
/// non-widget has no [BuildContext] to read it from.
bool natureMotionEnabledFor({
  required NatureMotionMode mode,
  required bool platformReducedMotion,
}) {
  if (platformReducedMotion) return false;
  return mode == NatureMotionMode.full;
}
