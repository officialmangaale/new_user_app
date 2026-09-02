import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/models/app_models.dart';
import '../../widgets/app_ui.dart';
import '../nature_feedback_service.dart';
import '../nature_preferences.dart';
import '../nature_tokens.dart';
import 'cart_beacon.dart';

/// Plays the "a drop joins the stream" moment after a genuine add to cart.
///
/// Ordering, which the brief is strict about:
///
///   cart already mutated  ->  light haptic  ->  soft splash
///   ->  drop flies to the cart  ->  cart ripple  ->  badge bounce
///
/// Every step here is downstream of the mutation. This controller is only ever
/// called once `addItemToCart` has confirmed the cart actually changed, so a
/// refused or cancelled add can never produce a celebration. It also never
/// returns anything the caller waits on — the cart is updated and painted long
/// before the drop lands.
class CartDropController {
  CartDropController(this._ref);

  final Ref _ref;

  OverlayEntry? _entry;
  AnimationController? _controller;

  /// Celebrates a completed add.
  ///
  /// [isFirstAdd] separates the ADD button from the `+` stepper: the first unit
  /// of an item gets the full treatment, further units get a light haptic and
  /// the existing quantity update only, so adding six of something does not
  /// splash six times.
  ///
  /// [sourceKey] is the product image that was on screen. When it is absent or
  /// no longer laid out, the flight is skipped and the cart still ripples —
  /// the feedback degrades, it does not break.
  void celebrateAdd({
    required BuildContext context,
    required CatalogItem item,
    required bool isFirstAdd,
    GlobalKey? sourceKey,
  }) {
    if (!isFirstAdd) {
      // The "+" stepper path. Nothing happens here at all: that button already
      // fires its own selection haptic on press and updates the quantity
      // visually, which is the whole of the intended feedback. Adding anything
      // more would double the haptic and splash on every repeat tap.
      return;
    }

    final feedback = _ref.read(natureFeedbackServiceProvider);
    feedback.addToCartSplash();

    final registry = _ref.read(cartBeaconRegistryProvider);
    final motionAllowed = _motionAllowed(context);

    if (!motionAllowed) {
      // Reduced motion: the drop does not travel, but the cart still
      // acknowledges the arrival so the feedback is not motion-only.
      registry.playArrival();
      return;
    }

    final target = registry.targetCentre();
    final source = _globalRectOf(sourceKey);

    if (target == null || source == null) {
      // No cart icon on screen, or the source image has gone. Still ripple.
      registry.playArrival();
      return;
    }

    _launch(
      context: context,
      item: item,
      source: source,
      target: target,
      onArrive: registry.playArrival,
    );
  }

  bool _motionAllowed(BuildContext context) {
    final platformReduced =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final mode = _ref.read(naturePreferencesProvider).motionMode;
    if (platformReduced) return false;
    return mode == NatureMotionMode.full;
  }

  static Rect? _globalRectOf(GlobalKey? key) {
    final renderObject = key?.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return null;
    if (!renderObject.attached || !renderObject.hasSize) return null;
    final origin = renderObject.localToGlobal(Offset.zero);
    return origin & renderObject.size;
  }

  void _launch({
    required BuildContext context,
    required CatalogItem item,
    required Rect source,
    required Offset target,
    required VoidCallback onArrive,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      onArrive();
      return;
    }

    // Only one drop in the air at a time. A customer tapping quickly gets the
    // newest flight rather than a pile of overlapping ones, which keeps the
    // cost flat no matter how fast they tap.
    _clear();

    final ticker = Navigator.maybeOf(context);
    final controller = AnimationController(
      duration: NatureDurations.cartFlight,
      vsync: ticker ?? overlay,
    );
    _controller = controller;

    var arrived = false;
    void handleArrival() {
      if (arrived) return;
      arrived = true;
      onArrive();
    }

    final entry = OverlayEntry(
      builder: (context) => _DropInFlight(
        animation: controller,
        item: item,
        source: source,
        target: target,
      ),
    );
    _entry = entry;
    overlay.insert(entry);

    controller.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      handleArrival();
      // Tearing the controller down from inside its own status dispatch is
      // asking for trouble; clean up on the next frame instead.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (identical(_controller, controller)) _clear();
      });
    });

    controller.forward();
  }

  void _clear() {
    _entry?.remove();
    _entry = null;
    _controller?.dispose();
    _controller = null;
  }

  /// Removes any in-flight drop. Called when the provider container goes away.
  void dispose() => _clear();
}

final cartDropControllerProvider = Provider<CartDropController>((ref) {
  final controller = CartDropController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

/// The drop itself: the product's already-loaded image, rounded into a
/// water-drop shape, travelling along a curved path.
///
/// It renders the same `AppNetworkImage` the card is already showing, so the
/// bytes come from the `cached_network_image` cache. No request is made to
/// animate — the brief's hard rule.
class _DropInFlight extends StatelessWidget {
  const _DropInFlight({
    required this.animation,
    required this.item,
    required this.source,
    required this.target,
  });

  final Animation<double> animation;
  final CatalogItem item;
  final Rect source;
  final Offset target;

  @override
  Widget build(BuildContext context) {
    // `Positioned` must be the outermost widget an OverlayEntry returns — the
    // Overlay lays its entries out in a Stack, and a Positioned nested inside
    // anything else (an IgnorePointer, say) throws a ParentDataWidget error.
    // So the pointer-transparency wrapper goes *inside* the Positioned.
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = NatureCurves.drop.transform(animation.value);
        final position = _pointOnArc(t);

        // Shrinks as it travels: a drop leaving a product and joining
        // something larger.
        final scale = 1 - 0.55 * t;
        final size = NatureMetrics.dropSize * scale;

        // Fades only at the very end, as it merges into the cart.
        final opacity = t < 0.82 ? 1.0 : (1 - (t - 0.82) / 0.18);

        // Rounds from the card's corner radius into a full droplet, with the
        // trailing corner staying slightly pointed — the shape a falling
        // drop actually takes.
        final radius = 14 + (size / 2 - 14) * t;

        return Positioned(
          left: position.dx - size / 2,
          top: position.dy - size / 2,
          width: size,
          height: size,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: -math.pi / 4 * t,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(radius),
                      topRight: Radius.circular(radius),
                      bottomRight: Radius.circular(radius),
                      bottomLeft: Radius.circular(radius * 0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: NatureColors.shadowFar,
                        blurRadius: 12 * (1 - t),
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  foregroundDecoration: BoxDecoration(
                    // A turquoise wash that deepens as it nears the cart, so
                    // the product visibly becomes water on the way in.
                    color: NatureColors.aqua.withValues(alpha: 0.10 + 0.30 * t),
                    borderRadius: BorderRadius.circular(radius),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      // Built once, not per frame.
      child: item.imageUrl.isEmpty
          ? const ColoredBox(color: AppColors.primaryLight)
          : AppNetworkImage(url: item.imageUrl, fit: BoxFit.cover),
    );
  }

  /// A gentle arc rather than a straight line.
  ///
  /// The control point is lifted above the midpoint so the drop rises slightly
  /// before falling into the cart, which reads as water arcing rather than a
  /// sprite sliding.
  Offset _pointOnArc(double t) {
    final start = source.center;
    final end = target;
    final mid = Offset(
      (start.dx + end.dx) / 2,
      math.min(start.dy, end.dy) - (start - end).distance * 0.18,
    );
    final oneMinusT = 1 - t;
    return Offset(
      oneMinusT * oneMinusT * start.dx +
          2 * oneMinusT * t * mid.dx +
          t * t * end.dx,
      oneMinusT * oneMinusT * start.dy +
          2 * oneMinusT * t * mid.dy +
          t * t * end.dy,
    );
  }
}
