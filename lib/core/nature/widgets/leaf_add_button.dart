import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../nature_tokens.dart';

/// The ADD control, shaped as a leaf.
///
/// The leaf is the first beat of the story: it is the surface that receives the
/// product before the product becomes water. So it has to read as a leaf while
/// still behaving in every respect like the button it replaces.
///
/// Three deliberate choices:
///
///  * **Shape, not clip.** The silhouette comes from asymmetric corner radii on
///    the button's `shape` — two opposite corners fully rounded, two nearly
///    square. A `ClipPath` around a leaf outline would shrink the hit area to
///    the visible shape; a shape only affects painting, so the tap target is
///    exactly the rectangle it has always been.
///  * **Same metrics.** `minimumSize` and `padding` are unchanged from the
///    OutlinedButton this replaces, so nothing on the card moves.
///  * **No gesture of its own.** It takes a handler and gives it to a normal
///    Material button. There is no second recognizer that could double-fire.
///
/// At rest it is completely static. Nothing floats, pulses or breathes.
class LeafAddButton extends StatelessWidget {
  const LeafAddButton({
    required this.onPressed,
    required this.compact,
    this.label = 'ADD',
    super.key,
  });

  /// The handler supplied by `NatureButton`. Null leaves the control disabled.
  final VoidCallback? onPressed;

  final bool compact;
  final String label;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 38.0 : 44.0;
    final width = compact ? 72.0 : 88.0;
    final radius = NatureMetrics.leafRadius(height);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        // Turquoise into fresh green. Both ends were picked against the label:
        // white on the turquoise end measures 5.85:1 and on the green end
        // 5.33:1, so the text clears 4.5:1 across the whole sweep. The obvious
        // choice — AppColors.primary — measures 4.19:1 and would have failed.
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [NatureColors.leafFillTurquoise, NatureColors.leafFillGreen],
        ),
        boxShadow: onPressed == null
            ? null
            : const [
                BoxShadow(
                  color: NatureColors.shadowNear,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      // No centre vein.
      //
      // A midrib is what makes a leaf drawing read as a leaf, but on a 72x38
      // button with a centred label there is nowhere to put one that does not
      // cross the word ADD, and a decorative line over the label works directly
      // against the contrast this button is supposed to guarantee. The
      // asymmetric silhouette carries the identity on its own.
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: Size(width, height),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
        // Styled on the Text rather than through `styleFrom(textStyle:)`.
        // A ButtonStyle text style replaces the inherited one outright, and a
        // replacement carrying no font family does not always resolve back to
        // the ambient default — it renders as missing glyphs under a
        // FontLoader-registered family. Styling the child inherits properly
        // and has no such dependency.
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
