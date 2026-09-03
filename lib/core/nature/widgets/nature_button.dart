import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../nature_feedback_service.dart';
import '../nature_motion.dart';
import '../nature_tokens.dart';
import 'water_tap_ripple.dart';

/// How much haptic a wrapped control should produce.
enum NatureHaptic {
  /// Silent and still — for controls where feedback would be noise.
  none,

  /// A light selection tick. The default for ordinary controls.
  tap,

  /// A slightly firmer tick, for a control that completes something.
  impact,
}

/// Reusable wrapper that gives an existing control the nature tap feel:
/// a ripple from the touch point, a small compression, and a light haptic.
///
/// It wraps rather than replaces. The caller keeps building its own button, so
/// theming, sizing, tap targets, semantics and the disabled state all remain
/// exactly whatever they already were:
///
/// ```dart
/// NatureButton(
///   onTap: existingCallback,
///   builder: (context, handleTap) =>
///       OutlinedButton(onPressed: handleTap, child: const Text('ADD')),
/// )
/// ```
///
/// Three guarantees:
///
///  * `onTap` runs exactly once per tap, synchronously.
///  * `onTap` is never delayed by the ripple, the compression or the sound.
///  * With motion reduced, the callback and the haptic still happen; only the
///    ripple and the compression are dropped.
///
/// This widget deliberately does **not** play the water splash. Sound is
/// reserved for a genuinely completed add-to-cart, which only the cart layer
/// can know about — see `NatureFeedbackService.addToCartSplash`.
class NatureButton extends ConsumerStatefulWidget {
  const NatureButton({
    required this.builder,
    required this.onTap,
    this.haptic = NatureHaptic.tap,
    this.borderRadius,
    this.rippleColor,
    this.compress = true,
    super.key,
  });

  final NatureTapBuilder builder;

  /// The existing callback. Null disables the effects along with the control.
  final VoidCallback? onTap;

  final NatureHaptic haptic;

  /// Clips the ripple to the wrapped control's silhouette. Null falls back to
  /// a modest uniform radius.
  final BorderRadius? borderRadius;
  final Color? rippleColor;

  /// Whether the control compresses on press.
  final bool compress;

  @override
  ConsumerState<NatureButton> createState() => _NatureButtonState();
}

class _NatureButtonState extends ConsumerState<NatureButton> {
  bool _pressed = false;

  void _handlePressedChanged(bool pressed) {
    if (!mounted || _pressed == pressed) return;
    if (widget.onTap == null) return;
    setState(() => _pressed = pressed);
  }

  void _handleTap() {
    switch (widget.haptic) {
      case NatureHaptic.none:
        break;
      case NatureHaptic.tap:
        ref.read(natureFeedbackServiceProvider).tap();
      case NatureHaptic.impact:
        ref.read(natureFeedbackServiceProvider).impact();
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final motion = natureMotionEnabled(ref, context);

    final ripple = WaterTapRipple(
      enabled: motion,
      borderRadius: widget.borderRadius,
      color: widget.rippleColor,
      onPressedChanged: widget.compress && motion
          ? _handlePressedChanged
          : null,
      // The haptic and the real callback are bundled here so the wrapped
      // control has one handler to call and cannot fire them separately.
      onTap: widget.onTap == null ? null : _handleTap,
      builder: widget.builder,
    );

    if (!widget.compress || !motion) return ripple;

    return AnimatedScale(
      scale: _pressed ? NatureMetrics.pressScale : 1,
      duration: _pressed ? NatureDurations.press : NatureDurations.release,
      curve: _pressed ? NatureCurves.press : NatureCurves.flow,
      child: ripple,
    );
  }
}
