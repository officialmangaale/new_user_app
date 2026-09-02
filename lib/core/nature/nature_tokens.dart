import 'package:flutter/animation.dart';

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
}
