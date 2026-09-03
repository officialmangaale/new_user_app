import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/models/app_models.dart';
import '../../widgets/app_ui.dart';
import '../nature_feedback_service.dart';
import '../nature_motion.dart';
import '../nature_preferences.dart';
import '../nature_tokens.dart';
import 'cart_beacon.dart';

/// Where an add-to-cart animation should start from.
///
/// Both keys are optional and both are allowed to go stale — a card can scroll
/// away mid-animation. Every use is null-checked and degrades rather than
/// throwing.
class ProductAddOrigin {
  const ProductAddOrigin({this.imageKey, this.addButtonKey});

  /// The product photo already on screen. The drop carries this image; it is
  /// never re-fetched.
  final GlobalKey? imageKey;

  /// The leaf ADD button, which the image lands on before becoming water.
  final GlobalKey? addButtonKey;
}

/// Plays the Mangaale add-to-cart story:
/// **the leaf receives the product, the product becomes water, the water falls
/// into the clay pot.**
///
/// Everything here is downstream of a real cart mutation. It is only ever
/// called once `addItemToCart` has confirmed the cart actually changed, and it
/// returns immediately — the cart is updated and painted long before the first
/// drop has left the leaf.
class CartDropController {
  CartDropController(this._ref);

  final Ref _ref;

  OverlayEntry? _entry;
  AnimationController? _controller;

  /// Celebrates a completed add.
  ///
  /// [unitsAdded] is the **real** quantity delta measured across the mutation,
  /// not a guess and not a tap count. One drop falls per unit, capped at
  /// [NatureMetrics.maxRenderedDrops] rendered objects with the remainder shown
  /// as a `+N` badge. The cap is purely visual; the cart is untouched by it.
  ///
  /// [isIncrement] marks the `+` stepper path, which gets the short version:
  /// a single drop straight from the button, no image and no leaf transform,
  /// because replaying the whole story on every `+` tap would be exhausting.
  void celebrateAdd({
    required BuildContext context,
    required CatalogItem item,
    required int unitsAdded,
    bool isIncrement = false,
    ProductAddOrigin? origin,
  }) {
    if (unitsAdded <= 0) return;

    final registry = _ref.read(cartBeaconRegistryProvider);

    if (!_motionAllowed(context)) {
      // Reduced motion: no travel, no transform. The pot still acknowledges the
      // arrival and the badge still moves, so success is never signalled by
      // motion alone — and the tip still sounds if sounds are on.
      registry.playArrival();
      _ref.read(natureFeedbackServiceProvider).potTip();
      return;
    }

    final target = registry.targetCentre();
    final leafRect = _globalRectOf(origin?.addButtonKey);
    final imageRect = _globalRectOf(origin?.imageKey);

    // The leaf is where drops are born. Without it there is nothing to fall
    // from, so fall back to the pot reaction alone.
    if (leafRect == null) {
      registry.playArrival();
      _ref.read(natureFeedbackServiceProvider).potTip();
      return;
    }

    _launch(
      context: context,
      item: item,
      units: unitsAdded,
      leafRect: leafRect,
      imageRect: isIncrement ? null : imageRect,
      target: target,
      registry: registry,
    );
  }

  bool _motionAllowed(BuildContext context) {
    final platformReduced =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return natureMotionEnabledFor(
      mode: _ref.read(naturePreferencesProvider).motionMode,
      platformReducedMotion: platformReduced,
    );
  }

  static Rect? _globalRectOf(GlobalKey? key) {
    final renderObject = key?.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return null;
    if (!renderObject.attached || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  void _launch({
    required BuildContext context,
    required CatalogItem item,
    required int units,
    required Rect leafRect,
    required Rect? imageRect,
    required Offset? target,
    required CartBeaconRegistry registry,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      registry.playArrival();
      _ref.read(natureFeedbackServiceProvider).potTip();
      return;
    }

    // One sequence in the air at a time. A customer tapping quickly gets the
    // newest one rather than a growing pile, which keeps the cost flat however
    // fast they tap.
    _clear();

    final rendered = math.min(units, NatureMetrics.maxRenderedDrops);
    final overflow = units - rendered;

    final hasImageStage = imageRect != null;
    final leadIn = hasImageStage
        ? NatureDurations.imageToLeaf + NatureDurations.dropTransform
        : NatureDurations.dropTransform;
    final total =
        leadIn +
        NatureDurations.dropStagger * (rendered - 1) +
        NatureDurations.dropFall;

    final controller = AnimationController(duration: total, vsync: overlay);
    _controller = controller;

    final feedback = _ref.read(natureFeedbackServiceProvider);
    final landed = List<bool>.filled(rendered, false);

    // Impact moments, as a fraction of the whole sequence.
    final impactAt = <double>[
      for (var i = 0; i < rendered; i++)
        (leadIn.inMilliseconds +
                NatureDurations.dropStagger.inMilliseconds * i +
                NatureDurations.dropFall.inMilliseconds) /
            total.inMilliseconds,
    ];

    void onTick() {
      final t = controller.value;
      for (var i = 0; i < rendered; i++) {
        if (landed[i] || t < impactAt[i]) continue;
        landed[i] = true;
        // Sound and reaction fire at the instant of visual contact, not when
        // the button was pressed.
        feedback.potTip(sequenceIndex: i, isLast: i == rendered - 1);
        registry.playArrival();
      }
    }

    controller
      ..addListener(onTick)
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        // Never tear a controller down inside its own dispatch.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (identical(_controller, controller)) _clear();
        });
      });

    final entry = OverlayEntry(
      builder: (context) => _AddSequence(
        animation: controller,
        item: item,
        leafRect: leafRect,
        imageRect: imageRect,
        target: target,
        rendered: rendered,
        overflow: overflow,
        leadIn: leadIn,
        total: total,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    controller.forward();
  }

  void _clear() {
    _entry?.remove();
    _entry = null;
    _controller?.dispose();
    _controller = null;
  }

  /// Cancels anything in flight. Called when the provider container goes away,
  /// and whenever a new sequence starts.
  void dispose() => _clear();
}

final cartDropControllerProvider = Provider<CartDropController>((ref) {
  final controller = CartDropController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

/// The whole visual story, driven by one controller on one overlay entry.
///
/// Splitting it across several controllers would mean several things to
/// dispose and several ways to leak; one timeline with computed phases is both
/// cheaper and easier to cancel.
class _AddSequence extends StatelessWidget {
  const _AddSequence({
    required this.animation,
    required this.item,
    required this.leafRect,
    required this.imageRect,
    required this.target,
    required this.rendered,
    required this.overflow,
    required this.leadIn,
    required this.total,
  });

  final Animation<double> animation;
  final CatalogItem item;
  final Rect leafRect;
  final Rect? imageRect;
  final Offset? target;
  final int rendered;
  final int overflow;
  final Duration leadIn;
  final Duration total;

  double get _leadInFraction => leadIn.inMilliseconds / total.inMilliseconds;

  double get _imageFraction => imageRect == null
      ? 0
      : NatureDurations.imageToLeaf.inMilliseconds / total.inMilliseconds;

  double get _fallFraction =>
      NatureDurations.dropFall.inMilliseconds / total.inMilliseconds;

  double get _staggerFraction =>
      NatureDurations.dropStagger.inMilliseconds / total.inMilliseconds;

  /// Where a drop finishes. Falls back to a point below the leaf when no pot is
  /// on screen, so the motion still reads as downward rather than vanishing
  /// sideways or aiming at the origin.
  Offset get _landing =>
      target ?? Offset(leafRect.center.dx, leafRect.bottom + 96);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = animation.value;
          final children = <Widget>[];

          // ---- stage 1 + 2: the leaf receives, the product becomes water ----
          if (t < _leadInFraction) {
            children.add(_buildOnLeaf(t, child));
          }

          // ---- stage 3: drops fall -----------------------------------------
          for (var i = 0; i < rendered; i++) {
            final start = _leadInFraction + _staggerFraction * i;
            final end = start + _fallFraction;
            if (t < start || t > end) continue;
            children.add(
              _buildFallingDrop(
                progress: (t - start) / (end - start),
                index: i,
                child: child,
              ),
            );
          }

          if (children.isEmpty) return const SizedBox.shrink();
          return Stack(children: children);
        },
        // Built once. The product's already-loaded image — no request is made
        // to animate, which is the hard rule.
        child: item.imageUrl.isEmpty
            ? null
            : AppNetworkImage(url: item.imageUrl, fit: BoxFit.cover),
      ),
    );
  }

  /// The product travelling onto the leaf, then rounding into a drop while the
  /// leaf takes its weight.
  Widget _buildOnLeaf(double t, Widget? image) {
    final imageStage = _imageFraction > 0 && t < _imageFraction;

    late final Offset centre;
    late final double size;
    late final double morph;

    if (imageStage) {
      // Sliding from the card's photo down onto the leaf.
      final p = Curves.easeOutCubic.transform(t / _imageFraction);
      final from = imageRect!;
      centre = Offset.lerp(from.center, leafRect.center, p)!;
      size = ui_lerp(from.shortestSide * 0.55, leafRect.height * 0.78, p);
      morph = 0;
    } else {
      // Settled on the leaf and becoming water.
      final span = _leadInFraction - _imageFraction;
      final p = span <= 0
          ? 1.0
          : Curves.easeInOutCubic.transform(
              ((t - _imageFraction) / span).clamp(0.0, 1.0),
            );
      centre = leafRect.center;
      size = ui_lerp(leafRect.height * 0.78, NatureMetrics.fallingDropSize, p);
      morph = p;
    }

    return Stack(
      children: [
        // The leaf compressing under the weight. Drawn over the real button at
        // its exact rect and shape, so it reads as the button itself bending.
        Positioned(
          left: leafRect.left,
          top: leafRect.top,
          width: leafRect.width,
          height: leafRect.height,
          child: _LeafReceiving(
            progress: imageStage ? t / _imageFraction : 1.0,
            release: morph,
            height: leafRect.height,
          ),
        ),
        _drop(centre: centre, size: size, morph: morph, image: image),
      ],
    );
  }

  Widget _buildFallingDrop({
    required double progress,
    required int index,
    required Widget? child,
  }) {
    // Blended, not a pure acceleration curve.
    //
    // `easeInCubic` is what gravity-from-rest actually looks like, and it reads
    // as broken: a quarter of the way through the fall the drop has covered
    // 1.4% of the distance and appears stuck to the leaf. A drop leaving a leaf
    // already has some velocity, so this mixes a linear component with a
    // quadratic one — visibly moving from the first frame, still accelerating
    // into the pot.
    final eased = progress * (0.38 + 0.62 * progress);
    final from = leafRect.center;
    final to = _landing;

    // Gravity down, with a small sideways curve so it arcs rather than slides.
    final dy = from.dy + (to.dy - from.dy) * eased;
    final straightX = from.dx + (to.dx - from.dx) * progress;
    final bow =
        math.sin(progress * math.pi) *
        (to.dy - from.dy).abs() *
        NatureMetrics.fallDriftFactor *
        (index.isEven ? 1 : -1) *
        0.35;

    final size = NatureMetrics.fallingDropSize * (1 - 0.28 * progress);
    final fade = progress > 0.88 ? (1 - (progress - 0.88) / 0.12) : 1.0;

    return _drop(
      centre: Offset(straightX + bow, dy),
      size: size,
      morph: 1,
      image: child,
      opacity: fade.clamp(0.0, 1.0),
      badge: index == rendered - 1 && overflow > 0 ? '+$overflow' : null,
    );
  }

  Widget _drop({
    required Offset centre,
    required double size,
    required double morph,
    required Widget? image,
    double opacity = 1,
    String? badge,
  }) {
    // Rounds from the card's corner radius into a teardrop. The trailing corner
    // stays pointed, which is the shape a falling drop actually takes.
    final round = ui_lerp(12, size / 2, morph);

    return Positioned(
      left: centre.dx - size / 2,
      top: centre.dy - size / 2,
      width: size,
      height: size,
      child: Opacity(
        opacity: opacity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(round),
                  topRight: Radius.circular(round),
                  bottomRight: Radius.circular(round),
                  bottomLeft: Radius.circular(ui_lerp(12, size * 0.22, morph)),
                ),
                color: image == null ? NatureColors.aqua : null,
                boxShadow: [
                  BoxShadow(
                    color: NatureColors.shadowFar,
                    blurRadius: 10 * (1 - morph * 0.5),
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              // A turquoise film that thickens as the product turns to water,
              // while the product stays recognisable underneath.
              foregroundDecoration: BoxDecoration(
                color: NatureColors.aqua.withValues(alpha: 0.12 + 0.30 * morph),
                borderRadius: BorderRadius.circular(round),
              ),
              // No image cached for this product: a clean branded droplet
              // rather than a grey placeholder or a broken-image icon.
              child: image,
            ),
            if (badge != null)
              Positioned(
                right: -8,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A copy of the leaf button drawn over the real one, compressing as it takes
/// the product's weight and springing back as the drop leaves.
class _LeafReceiving extends StatelessWidget {
  const _LeafReceiving({
    required this.progress,
    required this.release,
    required this.height,
  });

  /// 0 to 1 as the product approaches.
  final double progress;

  /// 0 to 1 as the drop forms and lifts away.
  final double release;

  final double height;

  @override
  Widget build(BuildContext context) {
    final squash = ui_lerp(
      1,
      NatureMetrics.leafSquash,
      Curves.easeOut.transform(progress) * (1 - release),
    );

    return Transform.scale(
      scaleY: squash,
      scaleX: 1 + (1 - squash) * 0.5,
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: NatureMetrics.leafRadius(height),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              NatureColors.leafFillTurquoise,
              NatureColors.leafFillGreen,
            ],
          ),
        ),
        // The label comes along too. This copy sits directly over the real
        // button, so leaving the text out made ADD appear to vanish for the
        // ~180 ms the leaf is compressed.
        child: const Center(
          child: Text(
            'ADD',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// `lerpDouble` without importing `dart:ui` for one function.
// ignore: non_constant_identifier_names
double ui_lerp(double a, double b, double t) => a + (b - a) * t;
