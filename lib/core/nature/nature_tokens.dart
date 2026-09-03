import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Timing, easing and intensity constants for the nature presentation layer.
///
/// Every nature animation reads its numbers from here, so the whole feel can be
/// retuned — or flattened — in one file without touching a widget.
abstract final class NatureDurations {
  /// Transitions between screens and sections. The brief's 180–300 ms window;
  /// anything longer starts to feel like waiting rather than breathing.
  static const breeze = Duration(milliseconds: 240);
  static const breezeShort = Duration(milliseconds: 180);

  /// A tap ripple's full expansion.
  static const ripple = Duration(milliseconds: 420);

  /// Button press compression, and its release.
  static const press = Duration(milliseconds: 110);
  static const release = Duration(milliseconds: 220);

  /// The drop's flight from the product image to the cart.
  ///
  /// Long enough to read as movement, short enough that a customer adding six
  /// items quickly never queues up a backlog of animations.
  static const cartFlight = Duration(milliseconds: 520);

  // ---------------------------------------------------------------------------
  // Leaf → drop → pot sequence
  // ---------------------------------------------------------------------------

  /// The product image travelling from the card onto the leaf button.
  static const imageToLeaf = Duration(milliseconds: 180);

  /// The image becoming a water drop while the leaf takes its weight.
  static const dropTransform = Duration(milliseconds: 180);

  /// A drop falling from the leaf into the pot.
  static const dropFall = Duration(milliseconds: 450);

  /// Gap between consecutive drops when more than one unit was added.
  static const dropStagger = Duration(milliseconds: 95);

  /// The ripple on the pot's water after a drop lands.
  static const potRipple = Duration(milliseconds: 380);

  /// The ripple that answers the drop's arrival, and the badge bounce.
  static const cartArrival = Duration(milliseconds: 340);
  static const badgeBounce = Duration(milliseconds: 320);

  /// The order-success ripple and rising leaf.
  static const celebration = Duration(milliseconds: 1100);
}

abstract final class NatureCurves {
  /// Water settling: quick to start, unhurried to finish.
  static const flow = Curves.easeOutCubic;

  /// A breeze arriving — gentle at both ends.
  static const breeze = Curves.easeInOutCubic;

  /// The drop's fall. Slight acceleration, no bounce: a bouncing drop reads as
  /// rubber, not water.
  static const drop = Curves.easeInOutQuart;

  /// Badge acknowledgement. The one place a little overshoot is welcome.
  static const bounce = Curves.easeOutBack;

  /// Button compression.
  static const press = Curves.easeOut;
}

abstract final class NatureMetrics {
  /// How far a button compresses on press. Small on purpose — a button that
  /// visibly shrinks feels cheap.
  static const pressScale = 0.965;

  /// Horizontal/vertical drift for breeze entrances, in logical pixels.
  static const breezeDrift = 10.0;

  /// Diameter of the drop in flight.
  static const dropSize = 46.0;

  /// Radius of the ripple that answers an arrival at the cart.
  static const cartRippleRadius = 34.0;

  /// Peak scale of the cart badge bounce.
  static const badgeBounceScale = 1.32;

  /// Opacity ceiling for any decorative fill placed behind content. Above this
  /// the decoration starts to interfere with text contrast.
  static const decorationOpacity = 0.10;

  // ---------------------------------------------------------------------------
  // Leaf → drop → pot sequence
  // ---------------------------------------------------------------------------

  /// Corner radii that turn a plain button into a leaf silhouette: two opposite
  /// corners fully rounded, the other two nearly square.
  ///
  /// Applied as the button's `shape`, never as a clip. A `ClipPath` would shrink
  /// the hit area to the visible leaf; a shape only affects painting, so the tap
  /// target stays exactly the rectangle it has always been.
  static BorderRadius leafRadius(double height) => BorderRadius.only(
    topLeft: Radius.circular(height / 2),
    bottomRight: Radius.circular(height / 2),
    topRight: const Radius.circular(4),
    bottomLeft: const Radius.circular(4),
  );

  /// How far the leaf squashes as it takes the product's weight.
  static const leafSquash = 0.90;

  /// Diameter of a drop at the moment it leaves the leaf.
  static const fallingDropSize = 30.0;

  /// Sideways drift as a drop falls, as a fraction of the vertical distance.
  /// Small on purpose — a drop curves, it does not swerve.
  static const fallDriftFactor = 0.16;

  /// Radius of the ripple on the pot's water surface.
  static const potRippleRadius = 15.0;

  /// Beyond this many units, remaining drops collapse into a `+N` badge rather
  /// than each getting their own animated object.
  static const maxRenderedDrops = 5;
}

abstract final class NatureAudio {
  /// Playback volume for the splash.
  ///
  /// Low by intent: this fires on every successful add, and a sound that is
  /// pleasant once is irritating on the tenth repeat. The asset itself is
  /// already rendered with headroom, so this attenuates a quiet file further.
  static const splashVolume = 0.34;

  /// Minimum gap between two splashes.
  ///
  /// Slightly longer than the asset itself (420 ms), so rapid taps can never
  /// stack or overlap — the second tap is silent rather than doubled.
  static const splashCooldown = Duration(milliseconds: 460);

  /// Asset path, relative to the `assets/` prefix that audioplayers applies.
  static const splashAsset = 'audio/water_drop.wav';

  // ---------------------------------------------------------------------------
  // The tip: one drop landing in the pot
  // ---------------------------------------------------------------------------

  /// A single drop meeting the water inside the clay pot.
  ///
  /// A different sound from [splashAsset], not a variation of it. The splash is
  /// deliberately broadband with its tonal content suppressed; a drop falling
  /// into a narrow earthen vessel is the opposite — the pot's air cavity rings,
  /// so the real sound is short, soft and pitched.
  static const tipAsset = 'audio/water_tip.wav';

  /// Base volume for a single tip. Quieter than the splash: this can fire
  /// several times in a row.
  static const tipVolume = 0.28;

  /// Each successive drop in one sequence plays at this fraction of the
  /// previous one, so a run of four recedes instead of hammering.
  static const tipFalloff = 0.82;

  /// The quietest a tip is allowed to get, so the last drop of a long run is
  /// still audible.
  static const tipMinVolume = 0.14;

  /// Minimum gap between two tips. Shorter than the splash cooldown because
  /// sequential drops are meant to be heard individually — this only guards
  /// against two landing in the same frame.
  static const tipCooldown = Duration(milliseconds: 55);
}
