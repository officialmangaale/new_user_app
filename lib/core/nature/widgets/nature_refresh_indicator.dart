import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../nature_motion.dart';
import '../nature_tokens.dart';
import 'leaf_accent.dart';
import 'water_tap_ripple.dart';

/// Pull-to-refresh with a water drop instead of a spinner.
///
/// This replaces **only the visual**. It is built on
/// [RefreshIndicator.noSpinner], so the drag threshold, the trigger mode, the
/// scroll-notification handling and — importantly — the guard that stops a
/// second `onRefresh` while one is already running are all still Flutter's own
/// battle-tested implementation. The `onRefresh` callback passed in is handed
/// straight through, called the same number of times, at the same moment.
///
/// The sequence:
///
///  * **drag**   — a drop forms and grows as the list is pulled down.
///  * **armed**  — the drop completes and sends out a single ripple.
///  * **refresh**— a leaf turns gently while the data loads.
///  * **done**   — everything fades away.
///
/// With motion reduced this degrades to a plain, static drop that appears while
/// refreshing, so the state is still communicated without movement.
class NatureRefreshIndicator extends ConsumerStatefulWidget {
  const NatureRefreshIndicator({
    required this.onRefresh,
    required this.child,
    this.displacement = 44,
    super.key,
  });

  /// Passed through to [RefreshIndicator.noSpinner] untouched.
  final Future<void> Function() onRefresh;

  final Widget child;

  /// How far below the top of the viewport the drop sits.
  final double displacement;

  @override
  ConsumerState<NatureRefreshIndicator> createState() =>
      _NatureRefreshIndicatorState();
}

class _NatureRefreshIndicatorState
    extends ConsumerState<NatureRefreshIndicator>
    with TickerProviderStateMixin {
  /// Eases the drop between its formed states.
  late final AnimationController _form;

  /// The single ripple when the pull arms.
  late final AnimationController _ripple;

  /// The leaf's rotation while loading.
  late final AnimationController _spin;

  RefreshIndicatorStatus? _status;

  @override
  void initState() {
    super.initState();
    _form = AnimationController(
      duration: NatureDurations.breeze,
      vsync: this,
    );
    _ripple = AnimationController(
      duration: NatureDurations.ripple,
      vsync: this,
    );
    _spin = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _form.dispose();
    _ripple.dispose();
    _spin.dispose();
    super.dispose();
  }

  void _handleStatusChange(RefreshIndicatorStatus? status) {
    if (!mounted || status == _status) return;
    setState(() => _status = status);

    switch (status) {
      case RefreshIndicatorStatus.drag:
        _form.animateTo(0.55);
      case RefreshIndicatorStatus.armed:
        _form.animateTo(1);
        _ripple.forward(from: 0);
      case RefreshIndicatorStatus.snap:
      case RefreshIndicatorStatus.refresh:
        _form.animateTo(1);
        // Bounded by the refresh itself: the moment the future completes the
        // status leaves `refresh` and this stops. The stock RefreshIndicator
        // spins its own spinner for exactly the same window.
        if (!_spin.isAnimating) _spin.repeat();
      case RefreshIndicatorStatus.done:
      case RefreshIndicatorStatus.canceled:
      case null:
        _spin.stop();
        _spin.value = 0;
        _form.animateTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final motion = natureMotionEnabled(ref, context);

    return Stack(
      children: [
        RefreshIndicator.noSpinner(
          // Handed through exactly as given. Flutter still owns when and how
          // often this runs, and will not start a second one while this is in
          // flight.
          onRefresh: widget.onRefresh,
          onStatusChange: _handleStatusChange,
          child: widget.child,
        ),
        Positioned(
          top: widget.displacement,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Center(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_form, _ripple, _spin]),
                    builder: (context, _) => _RefreshDrop(
                      form: _form.value,
                      ripple: _ripple.value,
                      spin: _spin.value,
                      loading: _status == RefreshIndicatorStatus.refresh ||
                          _status == RefreshIndicatorStatus.snap,
                      motion: motion,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RefreshDrop extends StatelessWidget {
  const _RefreshDrop({
    required this.form,
    required this.ripple,
    required this.spin,
    required this.loading,
    required this.motion,
  });

  final double form;
  final double ripple;
  final double spin;
  final bool loading;
  final bool motion;

  @override
  Widget build(BuildContext context) {
    if (form <= 0.01 && !loading) return const SizedBox.shrink();

    const box = 46.0;

    return SizedBox(
      width: box,
      height: box,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (motion && ripple > 0 && ripple < 1)
            Positioned.fill(
              child: CustomPaint(
                painter: WaterRipplePainter(
                  progress: ripple,
                  color: NatureColors.ripple,
                  maxRadius: box / 2,
                ),
              ),
            ),
          // The drop itself. Sits on a pale surface so it stays visible over
          // both the list background and any card that scrolls under it.
          Container(
            width: 30 * (motion ? form.clamp(0.35, 1.0) : 1.0),
            height: 30 * (motion ? form.clamp(0.35, 1.0) : 1.0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: NatureColors.shadowNear,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: loading
                ? Transform.rotate(
                    angle: motion ? spin * 6.28318 : 0,
                    child: const LeafAccent(size: 17, rotation: 0),
                  )
                : CustomPaint(
                    size: const Size(11, 15),
                    painter: _DropletPainter(
                      fill: form.clamp(0.0, 1.0),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// A teardrop that fills with turquoise as the pull deepens.
class _DropletPainter extends CustomPainter {
  const _DropletPainter({required this.fill});

  final double fill;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Pointed at the top, round at the bottom — a hanging drop.
    final path = Path()
      ..moveTo(width * 0.5, 0)
      ..cubicTo(width * 0.5, height * 0.34, width, height * 0.44, width, height * 0.66)
      ..arcToPoint(
        Offset(0, height * 0.66),
        radius: Radius.circular(width * 0.5),
        clockwise: false,
      )
      ..cubicTo(0, height * 0.44, width * 0.5, height * 0.34, width * 0.5, 0)
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = AppColors.primary.withValues(alpha: 0.18 + 0.72 * fill),
    );
  }

  @override
  bool shouldRepaint(covariant _DropletPainter oldDelegate) =>
      oldDelegate.fill != fill;

  @override
  bool hitTest(Offset position) => false;
}
