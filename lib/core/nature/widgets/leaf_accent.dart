import 'package:flutter/widgets.dart';

import '../../../app/theme/app_colors.dart';

/// A small leaf, drawn as two bézier curves with a centre vein.
///
/// Deliberately not an SVG or an image: the shape is four control points, so a
/// path in code costs nothing to ship, scales perfectly, recolours for free and
/// avoids adding an XML parser to the dependency list.
///
/// It is decoration in the strict sense — wrapped in [ExcludeSemantics] so a
/// screen reader never announces it, and painted with a hit test that always
/// returns false so it can never absorb a touch meant for something else.
class LeafAccent extends StatelessWidget {
  const LeafAccent({
    this.size = 14,
    this.color = NatureColors.leaf,
    this.rotation = -0.35,
    this.opacity = 1,
    super.key,
  });

  /// Height of the leaf. Width follows at roughly 62% of this.
  final double size;
  final Color color;

  /// Rotation in radians. The default tilts the tip up and to the right, which
  /// reads as growth rather than as a falling leaf.
  final double rotation;

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Transform.rotate(
          angle: rotation,
          child: CustomPaint(
            size: Size(size * 0.62, size),
            painter: _LeafPainter(
              color: color.withValues(alpha: color.a * opacity),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeafPainter extends CustomPainter {
  const _LeafPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Two mirrored curves from the stem to the tip give the classic almond
    // leaf silhouette; the slight asymmetry in the control points keeps it from
    // looking like a machine-drawn lens shape.
    final blade = Path()
      ..moveTo(width * 0.5, height)
      ..cubicTo(
        -width * 0.08,
        height * 0.66,
        width * 0.06,
        height * 0.16,
        width * 0.5,
        0,
      )
      ..cubicTo(
        width * 0.96,
        height * 0.18,
        width * 1.08,
        height * 0.68,
        width * 0.5,
        height,
      )
      ..close();

    canvas.drawPath(blade, Paint()..color = color);

    // Centre vein, a shade darker, so the leaf reads at small sizes where the
    // silhouette alone would be a blob.
    final vein = Path()
      ..moveTo(width * 0.5, height * 0.94)
      ..quadraticBezierTo(
        width * 0.52,
        height * 0.5,
        width * 0.5,
        height * 0.08,
      );

    canvas.drawPath(
      vein,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.045
        ..strokeCap = StrokeCap.round
        ..color = NatureColors.leafDeep.withValues(alpha: color.a * 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant _LeafPainter oldDelegate) =>
      oldDelegate.color != color;

  @override
  bool hitTest(Offset position) => false;
}
