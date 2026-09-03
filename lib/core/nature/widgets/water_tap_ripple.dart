import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../app/theme/app_colors.dart';
import '../nature_tokens.dart';

/// Signature for a child that needs the wrapper's tap handler.
///
/// The wrapper never owns a tap gesture of its own — it hands `handleTap` to
/// the real control (an `OutlinedButton`, a `FilledButton`, an `InkWell`) and
/// that control stays the one and only path to the callback. This is what
/// keeps "execute the existing callback exactly once" structurally true rather
/// than merely tested: there is no second recognizer that could fire.
typedef NatureTapBuilder =
    Widget Function(BuildContext context, VoidCallback handleTap);

/// Wraps a control and paints a soft water ripple from the exact point the
/// finger landed.
///
/// Two deliberate choices:
///
///  * Position is captured with a [Listener], not a [GestureDetector].
///    A `Listener` is passive — it never competes in the gesture arena, so it
///    cannot steal, delay or duplicate the child's own tap.
///  * The ripple is painted as a foreground painter that only exists while the
///    animation runs, so an idle button costs nothing to rebuild.
class WaterTapRipple extends StatefulWidget {
  const WaterTapRipple({
    required this.builder,
    required this.onTap,
    this.enabled = true,
    this.borderRadius,
    this.color,
    this.onPressedChanged,
    super.key,
  });

  final NatureTapBuilder builder;

  /// The real callback. Invoked synchronously, exactly once per tap, and never
  /// held back by the animation.
  final VoidCallback? onTap;

  /// When false the callback still fires — only the ripple is skipped.
  /// This is the reduced-motion path.
  final bool enabled;

  /// Clips the ripple to the control's own silhouette. Null means a modest
  /// uniform radius, which suits a rectangular control; the leaf ADD button
  /// passes its asymmetric radii so the ripple cannot bleed past the shape.
  final BorderRadius? borderRadius;

  final Color? color;

  /// Reports press state so a parent can add compression without installing a
  /// second [Listener] over the same child.
  final ValueChanged<bool>? onPressedChanged;

  @override
  State<WaterTapRipple> createState() => _WaterTapRippleState();
}

class _WaterTapRippleState extends State<WaterTapRipple>
    with SingleTickerProviderStateMixin {
  /// Created eagerly rather than lazily.
  ///
  /// A `late final` initialiser here is a trap: with motion reduced the build
  /// path never reads the field, so the controller is first constructed inside
  /// `dispose()` — which builds a ticker against an already-deactivated
  /// element and throws. An idle controller schedules no ticker and costs
  /// nothing, so there is no reason to defer it.
  late final AnimationController _controller;

  Offset? _origin;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: NatureDurations.ripple,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    final callback = widget.onTap;
    if (callback == null) return;

    // Ripple first: it is a synchronous, cheap controller start, and doing it
    // before the callback means a callback that navigates away (and disposes
    // this widget) cannot leave us starting an animation on a dead ticker.
    if (widget.enabled && mounted) {
      _controller.forward(from: 0);
    }

    callback();
  }

  void _setPressed(bool value) => widget.onPressedChanged?.call(value);

  @override
  Widget build(BuildContext context) {
    final child = widget.builder(context, _handleTap);

    if (!widget.enabled) {
      // Reduced motion: no painter, no controller work, no Listener overhead
      // beyond press reporting.
      return Listener(
        behavior: HitTestBehavior.deferToChild,
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: child,
      );
    }

    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (event) {
        _origin = event.localPosition;
        _setPressed(true);
      },
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(14),
          child: AnimatedBuilder(
            animation: _controller,
            // Passed through untouched so the control itself does not rebuild
            // on any animation frame.
            child: child,
            builder: (context, innerChild) {
              if (!_controller.isAnimating || _origin == null) {
                return innerChild!;
              }
              return CustomPaint(
                foregroundPainter: WaterRipplePainter(
                  progress: _controller.value,
                  origin: _origin!,
                  color: widget.color ?? NatureColors.ripple,
                ),
                child: innerChild,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Paints a single expanding water ring.
///
/// Kept public so other nature surfaces — the cart's arrival ripple, the order
/// celebration — can reuse the same visual language rather than each inventing
/// their own circle.
class WaterRipplePainter extends CustomPainter {
  const WaterRipplePainter({
    required this.progress,
    required this.color,
    this.origin,
    this.maxRadius,
  });

  /// 0 to 1.
  final double progress;

  /// Where the ring starts. Null means the centre of the painted box, which is
  /// what a ripple answering an arrival wants — there is no finger involved.
  final Offset? origin;

  final Color color;

  /// Defaults to reaching the farthest corner from the origin.
  final double? maxRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final origin = this.origin ?? size.center(Offset.zero);
    final target = maxRadius ?? _distanceToFarthestCorner(origin, size);
    // Eased so the ring races out and then settles, like water spreading.
    final eased = Curves.easeOutCubic.transform(progress);
    final radius = target * eased;

    // Fades throughout, so the ripple is never at full strength over text.
    final fade = (1 - progress) * (1 - progress);

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: color.a * fade);
    canvas.drawCircle(origin, radius, fill);

    // A brighter leading edge gives the ring a water-surface quality that a
    // flat disc does not have.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = NatureColors.rippleEdge.withValues(
        alpha: NatureColors.rippleEdge.a * fade,
      );
    canvas.drawCircle(origin, radius, edge);
  }

  static double _distanceToFarthestCorner(Offset origin, Size size) {
    final corners = <Offset>[
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    var farthest = 0.0;
    for (final corner in corners) {
      farthest = math.max(farthest, (corner - origin).distance);
    }
    return farthest;
  }

  @override
  bool shouldRepaint(covariant WaterRipplePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.origin != origin ||
      oldDelegate.color != color ||
      oldDelegate.maxRadius != maxRadius;

  /// Decoration must never absorb a touch.
  @override
  bool hitTest(Offset position) => false;
}
