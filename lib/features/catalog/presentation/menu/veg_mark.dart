import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// FSSAI food mark: a square outline with a dot (veg) or a triangle (non-veg).
class VegMark extends StatelessWidget {
  const VegMark({required this.isVeg, this.size = 16, super.key});

  final bool isVeg;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isVeg ? 'Vegetarian' : 'Non-vegetarian',
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(size),
          painter: _VegMarkPainter(isVeg: isVeg),
        ),
      ),
    );
  }
}

class _VegMarkPainter extends CustomPainter {
  const _VegMarkPainter({required this.isVeg});

  final bool isVeg;

  @override
  void paint(Canvas canvas, Size size) {
    final color = isVeg ? AppColors.vegGreen : AppColors.nonVegBrown;
    final stroke = size.width * 0.11;
    final box = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(size.width * 0.14)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final fill = Paint()..color = color;
    final c = size.center(Offset.zero);
    if (isVeg) {
      canvas.drawCircle(c, size.width * 0.2, fill);
    } else {
      final r = size.width * 0.24;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r, c.dy + r * 0.8)
          ..lineTo(c.dx - r, c.dy + r * 0.8)
          ..close(),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(_VegMarkPainter old) => old.isVeg != isVeg;
}

/// 1px dashed rule used between menu rows and inside the info card.
class DashedDivider extends StatelessWidget {
  const DashedDivider({this.indent = 0, super.key});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent),
      child: const SizedBox(
        height: 1,
        width: double.infinity,
        child: CustomPaint(painter: _DashPainter()),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + 4, 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}
