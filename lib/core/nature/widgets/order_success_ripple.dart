import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../nature_feedback_service.dart';
import '../nature_motion.dart';
import '../nature_tokens.dart';
import 'leaf_accent.dart';
import 'water_tap_ripple.dart';

/// Remembers that an order was just placed, so the screen the customer lands on
/// can celebrate it.
///
/// This exists instead of a query parameter on `/tracking/:id` for two reasons:
/// the route's shape stays exactly as it is, and opening the same tracking
/// screen later from order history correctly shows no celebration.
///
/// The flag is consumed on first read and cleared, so it can never fire twice
/// or survive into a later session.
class OrderCelebration extends Notifier<String?> {
  @override
  String? build() => null;

  /// Called by checkout immediately after a confirmed order, before it
  /// navigates. Does not block or delay navigation.
  void arm(String orderId) => state = orderId;

  /// True once, for the order that was just placed.
  bool consume(String orderId) {
    if (state != orderId) return false;
    state = null;
    return true;
  }
}

final orderCelebrationProvider = NotifierProvider<OrderCelebration, String?>(
  OrderCelebration.new,
);

/// A one-shot ripple with a leaf rising from its centre.
///
/// Layered over the tracking screen rather than shown before it, so the order
/// number, status and navigation are on screen and readable from the first
/// frame. It ignores pointers throughout, so a customer who wants to scroll or
/// tap immediately is never held up, and it is excluded from semantics so a
/// screen reader announces the order, not the decoration.
class OrderSuccessCelebration extends ConsumerStatefulWidget {
  const OrderSuccessCelebration({
    required this.orderId,
    required this.child,
    super.key,
  });

  final String orderId;
  final Widget child;

  @override
  ConsumerState<OrderSuccessCelebration> createState() =>
      _OrderSuccessCelebrationState();
}

/// Share of the screen height the celebration is allowed to occupy, measured
/// from the top.
///
/// Sized to the tracking screen's map header, which is the one region with no
/// text or controls in it.
const double _celebrationBandFraction = 0.42;

class _OrderSuccessCelebrationState
    extends ConsumerState<OrderSuccessCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: NatureDurations.celebration,
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;

    // Read after the first frame: this must not run during build, and the
    // screen should be painted before anything is layered over it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(orderCelebrationProvider.notifier).consume(widget.orderId)) {
        return;
      }

      ref.read(natureFeedbackServiceProvider).orderPlaced();

      // With motion reduced the haptic and sound still fire; only the
      // travelling part is dropped, so success is never signalled by movement
      // alone.
      if (natureMotionEnabled(ref, context)) {
        _controller.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Confined to the upper band of the screen rather than filling it.
        //
        // On the tracking screen that band is the map; below it sit the order
        // number, the status timeline and the actions. Keeping the leaf inside
        // this region is what stops it drifting across text — a full-height
        // overlay put it straight through the order number, which is exactly
        // the "never hide important information" rule this is supposed to obey.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.sizeOf(context).height * _celebrationBandFraction,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    if (!_controller.isAnimating) {
                      return const SizedBox.shrink();
                    }
                    return CustomPaint(
                      painter: WaterRipplePainter(
                        // The ripple occupies the first two-thirds; the leaf
                        // rises through the whole thing.
                        progress: (_controller.value / 0.66).clamp(0.0, 1.0),
                        color: NatureColors.ripple,
                      ),
                      child: _RisingLeaf(progress: _controller.value),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RisingLeaf extends StatelessWidget {
  const _RisingLeaf({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    // Drifts up from the centre and fades out at the top of its travel.
    final eased = NatureCurves.flow.transform(progress);
    final opacity = progress < 0.25
        ? progress / 0.25
        : (1 - (progress - 0.25) / 0.75).clamp(0.0, 1.0);

    return Align(
      alignment: Alignment(0, 0.06 - eased * 0.34),
      child: Transform.rotate(
        angle: 0.5 - eased * 0.9,
        child: LeafAccent(
          size: 30 + eased * 8,
          color: NatureColors.leaf,
          rotation: 0,
          opacity: opacity,
        ),
      ),
    );
  }
}
