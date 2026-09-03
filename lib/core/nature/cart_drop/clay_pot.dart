import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../nature_tokens.dart';
import 'cart_beacon.dart';

/// The cart, drawn as a small earthen pot.
///
/// This is a *visual wrapper* around the existing cart control, not a new one.
/// It takes the same count and the same tap callback the count square took, and
/// tapping it opens the same route. Nothing about cart state or navigation
/// lives here.
///
/// It is also the destination the falling drops aim at. It registers itself
/// with [CartBeaconRegistry] and reports its **mouth** rather than its centre,
/// so a drop lands in the opening instead of somewhere on the clay.
class ClayPotCart extends ConsumerStatefulWidget {
  const ClayPotCart({
    required this.count,
    required this.onTap,
    this.size = 38,
    super.key,
  });

  /// Read from the existing cart count provider by the caller. The pot never
  /// computes or caches it.
  final int count;

  /// The existing cart navigation callback, passed straight through.
  final VoidCallback onTap;

  /// Kept at the size of the element it replaces so nothing on the bar shifts.
  final double size;

  @override
  ConsumerState<ClayPotCart> createState() => ClayPotCartState();
}

class ClayPotCartState extends ConsumerState<ClayPotCart>
    with TickerProviderStateMixin
    implements CartDropTarget {
  /// One controller drives every impact: ripple, particles and the pot's own
  /// small recoil all read from it.
  late final AnimationController _impact;
  late final AnimationController _badge;
  late final Animation<double> _badgeScale;

  CartBeaconRegistry? _registry;

  /// Where the water sits inside the mouth, as a fraction of [widget.size] from
  /// the top of the widget. Drops aim here.
  static const double _mouthYFraction = 0.30;

  @override
  void initState() {
    super.initState();
    _impact = AnimationController(
      duration: NatureDurations.potRipple,
      vsync: this,
    );
    _badge = AnimationController(
      duration: NatureDurations.badgeBounce,
      vsync: this,
    );
    _badgeScale = Tween<double>(begin: 1, end: NatureMetrics.badgeBounceScale)
        .animate(
          CurvedAnimation(
            parent: _badge,
            curve: NatureCurves.bounce,
            reverseCurve: NatureCurves.flow,
          ),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = ref.read(cartBeaconRegistryProvider);
    if (identical(registry, _registry)) return;
    _registry?.unregister(this);
    _registry = registry..register(this);
  }

  @override
  void dispose() {
    _registry?.unregister(this);
    _impact.dispose();
    _badge.dispose();
    super.dispose();
  }

  // --- CartDropTarget ------------------------------------------------------

  @override
  bool get isTargetable {
    if (!mounted) return false;
    final box = context.findRenderObject() as RenderBox?;
    return box != null && box.attached && box.hasSize;
  }

  @override
  Offset? targetPoint() {
    if (!mounted) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    // The water surface inside the mouth, not the widget's centre.
    return box.localToGlobal(
      Offset(box.size.width / 2, box.size.height * _mouthYFraction),
    );
  }

  @override
  void playArrival() {
    if (!mounted) return;
    _impact.forward(from: 0);
    _badge.forward(from: 0).then((_) {
      if (mounted) _badge.reverse();
    });
  }

  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final label =
        'Cart, ${widget.count} '
        '${widget.count == 1 ? 'item' : 'items'}';

    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RepaintBoundary(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _impact,
                  builder: (context, _) => CustomPaint(
                    painter: ClayPotPainter(
                      impact: _impact.isAnimating ? _impact.value : 0,
                      mouthYFraction: _mouthYFraction,
                    ),
                  ),
                ),
              ),
              // The tap surface covers the whole pot and routes to the caller's
              // existing callback.
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    customBorder: const CircleBorder(),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              if (widget.count > 0)
                Positioned(
                  right: -4,
                  top: -5,
                  child: ScaleTransition(
                    scale: _badgeScale,
                    child: ExcludeSemantics(
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85),
                            width: 1.4,
                          ),
                        ),
                        child: Text(
                          widget.count > 99 ? '99+' : '${widget.count}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            height: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints a minimal earthen pot: a bulging body, a turned rim, and turquoise
/// water sitting in the mouth.
///
/// Deliberately plain — no ornament, no religious motif, no illustration. It has
/// to read at 38 px on a dark bar, which rules out detail anyway.
class ClayPotPainter extends CustomPainter {
  const ClayPotPainter({required this.impact, required this.mouthYFraction});

  /// 0 to 1 while a drop is landing; 0 at rest.
  final double impact;

  final double mouthYFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final centreX = width / 2;
    final mouthY = height * mouthYFraction;
    final mouthRx = width * 0.34;

    // The pot recoils a hair as the drop lands, then settles.
    final recoil = impact == 0
        ? 0.0
        : math.sin(impact * math.pi) * (1 - impact) * height * 0.035;

    canvas.save();
    canvas.translate(0, recoil);

    // ---- body -------------------------------------------------------------
    final body = Path()
      ..moveTo(centreX - mouthRx, mouthY)
      ..cubicTo(
        centreX - width * 0.52,
        height * 0.52,
        centreX - width * 0.44,
        height,
        centreX,
        height,
      )
      ..cubicTo(
        centreX + width * 0.44,
        height,
        centreX + width * 0.52,
        height * 0.52,
        centreX + mouthRx,
        mouthY,
      )
      ..close();

    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [NatureColors.clayLight, NatureColors.clayDeep],
          stops: [0.12, 0.92],
        ).createShader(Offset.zero & size),
    );

    // A soft shoulder highlight, so it reads as turned pottery rather than a
    // flat blob.
    canvas.drawPath(
      Path()
        ..moveTo(centreX - width * 0.26, height * 0.52)
        ..quadraticBezierTo(
          centreX - width * 0.06,
          height * 0.42,
          centreX + width * 0.14,
          height * 0.48,
        ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.045
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.16),
    );

    // ---- rim --------------------------------------------------------------
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centreX, mouthY),
        width: mouthRx * 2,
        height: height * 0.15,
      ),
      Paint()..color = NatureColors.clayDeep,
    );

    // ---- water ------------------------------------------------------------
    final waterRect = Rect.fromCenter(
      center: Offset(centreX, mouthY + height * 0.012),
      width: mouthRx * 1.52,
      height: height * 0.10,
    );
    canvas.drawOval(waterRect, Paint()..color = NatureColors.potWater);

    // ---- impact ripple ----------------------------------------------------
    if (impact > 0 && impact < 1) {
      final eased = Curves.easeOutCubic.transform(impact);
      final fade = (1 - impact) * (1 - impact);

      // Two rings spreading across the water's surface, drawn as flattened
      // ovals so they sit in the plane of the water rather than facing us.
      for (final scale in <double>[1.0, 0.58]) {
        final r = mouthRx * 0.92 * eased * scale;
        canvas.drawOval(
          Rect.fromCenter(
            center: waterRect.center,
            width: r * 2,
            height: r * 2 * 0.34,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = NatureColors.potWaterLight.withValues(
              alpha: 0.9 * fade * scale,
            ),
        );
      }

      // Two or three particles lifting off the surface and falling back.
      const particles = <double>[-0.42, 0.05, 0.46];
      for (var i = 0; i < particles.length; i++) {
        final lift = math.sin(impact * math.pi);
        final px = waterRect.center.dx + mouthRx * particles[i] * (0.5 + eased);
        final py = waterRect.center.dy - lift * height * (0.16 + i * 0.03);
        canvas.drawCircle(
          Offset(px, py),
          width * 0.032 * (1 - eased * 0.5),
          Paint()
            ..color = NatureColors.potWaterLight.withValues(alpha: 0.85 * fade),
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ClayPotPainter oldDelegate) =>
      oldDelegate.impact != impact ||
      oldDelegate.mouthYFraction != mouthYFraction;

  /// The InkWell above handles taps; the painting must never intercept them.
  @override
  bool hitTest(Offset position) => false;
}
