import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Something a falling water drop can land on.
///
/// Implemented by `ClayPotCartState`. Kept as an interface rather than a
/// concrete widget so the registry has no opinion about what the destination
/// looks like — the pilot uses a clay pot, and a different surface could
/// register instead without the animation layer knowing.
abstract interface class CartDropTarget {
  /// Whether this target is currently laid out and worth aiming at.
  bool get isTargetable;

  /// The exact point a drop should land on, in global coordinates.
  ///
  /// Deliberately not "the centre of the widget": the pot wants drops to arrive
  /// at the water inside its mouth, which sits near the top of its box.
  Offset? targetPoint();

  /// Play whatever this target does when a drop arrives — for the pot, a ripple
  /// on the water, a few particles, a small recoil and a badge bounce.
  void playArrival();
}

/// Tracks which cart destinations are on screen.
///
/// Nothing here reads or writes cart state. The count shown on a target still
/// comes from `cartCountProvider`; this only answers "where should a drop go,
/// and who should react when it lands".
class CartBeaconRegistry {
  final List<CartDropTarget> _targets = <CartDropTarget>[];

  void register(CartDropTarget target) => _targets.add(target);

  void unregister(CartDropTarget target) => _targets.remove(target);

  /// The target a drop should aim at.
  ///
  /// Last registered wins — that is the one on the topmost route. Targets whose
  /// element has gone away, or which have no laid-out box, are skipped rather
  /// than returned, because a flight to a stale position looks like a bug and a
  /// flight to `Offset.zero` looks like a crash.
  CartDropTarget? get _active {
    for (var i = _targets.length - 1; i >= 0; i--) {
      if (_targets[i].isTargetable) return _targets[i];
    }
    return null;
  }

  /// Where a drop should land, or null when no cart destination is on screen.
  Offset? targetCentre() => _active?.targetPoint();

  /// Plays the arrival reaction on the active target. Safe to call when nothing
  /// is registered — it simply does nothing.
  void playArrival() => _active?.playArrival();

  bool get hasTarget => _active != null;
}

final cartBeaconRegistryProvider = Provider<CartBeaconRegistry>(
  (ref) => CartBeaconRegistry(),
);
