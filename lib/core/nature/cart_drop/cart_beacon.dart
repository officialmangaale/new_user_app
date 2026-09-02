import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../nature_tokens.dart';
import '../widgets/water_tap_ripple.dart';

/// A cart icon that can be flown to.
///
/// Any cart icon in the app can opt in by wrapping itself in a [CartBeacon].
/// The beacon does three things:
///
///  * gives the icon a calm, low-opacity turquoise disc to sit on;
///  * registers its position so an add-to-cart drop knows where to land;
///  * plays a single arrival ripple and hands its caller a badge-bounce
///    animation.
///
/// Nothing here reads or writes cart state. The count shown in the badge is
/// still whatever the caller passes from `cartCountProvider`; the bounce is
/// decoration layered over it.
class CartBeaconRegistry {
  final List<_CartBeaconState> _beacons = <_CartBeaconState>[];

  void _register(_CartBeaconState beacon) => _beacons.add(beacon);

  void _unregister(_CartBeaconState beacon) => _beacons.remove(beacon);

  /// The beacon a drop should aim at.
  ///
  /// Last registered wins: that is the one on the topmost route. Beacons whose
  /// element has gone away, or which have no laid-out box, are skipped rather
  /// than returned as a target at the origin — a flight to `Offset.zero` looks
  /// like a bug, so the caller is told there is no target instead.
  _CartBeaconState? get _active {
    for (var i = _beacons.length - 1; i >= 0; i--) {
      final beacon = _beacons[i];
      if (beacon.isTargetable) return beacon;
    }
    return null;
  }

  /// Centre of the active cart icon in global coordinates, or null when no
  /// cart icon is currently on screen.
  Offset? targetCentre() {
    final beacon = _active;
    if (beacon == null) return null;
    final box = beacon.context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  /// Plays the arrival ripple and badge bounce on the active cart icon.
  ///
  /// Safe to call when nothing is registered — it simply does nothing.
  void playArrival() => _active?.playArrival();

  bool get hasTarget => _active != null;
}

final cartBeaconRegistryProvider = Provider<CartBeaconRegistry>(
  (ref) => CartBeaconRegistry(),
);

class CartBeacon extends ConsumerStatefulWidget {
  const CartBeacon({
    required this.builder,
    this.showDisc = true,
    this.discSize = 44,
    super.key,
  });

  /// Builds the cart icon. `badgeScale` is a one-shot bounce the caller should
  /// apply to its count badge — the brief asks for the badge to react, not the
  /// whole icon.
  final Widget Function(BuildContext context, Animation<double> badgeScale)
      builder;

  /// The calm turquoise surface behind the icon.
  final bool showDisc;
  final double discSize;

  @override
  ConsumerState<CartBeacon> createState() => _CartBeaconState();
}

class _CartBeaconState extends ConsumerState<CartBeacon>
    with TickerProviderStateMixin {
  late final AnimationController _ripple;
  late final AnimationController _bounce;
  late final Animation<double> _badgeScale;

  CartBeaconRegistry? _registry;

  @override
  void initState() {
    super.initState();
    // Eager, not lazy: a controller first touched inside dispose() would build
    // its ticker against a dead element.
    _ripple = AnimationController(
      duration: NatureDurations.cartArrival,
      vsync: this,
    );
    _bounce = AnimationController(
      duration: NatureDurations.badgeBounce,
      vsync: this,
    );
    _badgeScale = Tween<double>(
      begin: 1,
      end: NatureMetrics.badgeBounceScale,
    ).animate(
      CurvedAnimation(
        parent: _bounce,
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
    _registry?._unregister(this);
    _registry = registry.._register(this);
  }

  @override
  void dispose() {
    _registry?._unregister(this);
    _ripple.dispose();
    _bounce.dispose();
    super.dispose();
  }

  /// Whether this beacon is currently a sensible thing to fly to.
  bool get isTargetable {
    if (!mounted) return false;
    final box = context.findRenderObject() as RenderBox?;
    return box != null && box.attached && box.hasSize;
  }

  void playArrival() {
    if (!mounted) return;
    _ripple.forward(from: 0);
    // Out and back, so the badge settles at its true size.
    _bounce.forward(from: 0).then((_) {
      if (mounted) _bounce.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.builder(context, _badgeScale);

    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (widget.showDisc)
            IgnorePointer(
              child: Container(
                width: widget.discSize,
                height: widget.discSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(
                    alpha: NatureMetrics.decorationOpacity,
                  ),
                ),
              ),
            ),
          // The arrival ripple. Painted only while it runs, and never a hit
          // target, so it cannot swallow a tap on the cart.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _ripple,
                builder: (context, _) {
                  if (!_ripple.isAnimating) {
                    return const SizedBox.shrink();
                  }
                  return CustomPaint(
                    painter: WaterRipplePainter(
                      progress: _ripple.value,
                      color: NatureColors.ripple,
                      maxRadius: NatureMetrics.cartRippleRadius,
                    ),
                  );
                },
              ),
            ),
          ),
          icon,
        ],
      ),
    );
  }
}
