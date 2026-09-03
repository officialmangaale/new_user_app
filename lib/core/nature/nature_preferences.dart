import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How much nature motion the customer wants.
enum NatureMotionMode {
  /// Flights, drifts and ripples all play.
  full,

  /// Movement is replaced by a plain fade or an immediate state change.
  /// Nothing is removed — only the travelling part of each effect.
  reduced;

  static NatureMotionMode fromStorage(String? value) =>
      value == reduced.name ? reduced : full;
}

/// Customer preferences for the nature presentation layer.
///
/// Two new SharedPreferences keys, chosen not to collide with anything in
/// `AuthStorage` or `GuestStorage`. Nothing here is read by business logic —
/// if this file were deleted, every feature would still work.
class NaturePreferencesState {
  const NaturePreferencesState({
    this.soundsEnabled = defaultSoundsEnabled,
    this.motionMode = NatureMotionMode.full,
    this.loaded = false,
  });

  /// Sounds are on for the initial preview build at the reviewer's request.
  ///
  /// Note this differs from the original brief's "off by default". If that is
  /// reverted before release, this is the single line to change.
  static const bool defaultSoundsEnabled = true;

  final bool soundsEnabled;
  final NatureMotionMode motionMode;

  /// False until the stored values have been read back from disk. Used to
  /// avoid writing a default over a stored value during startup.
  final bool loaded;

  NaturePreferencesState copyWith({
    bool? soundsEnabled,
    NatureMotionMode? motionMode,
    bool? loaded,
  }) {
    return NaturePreferencesState(
      soundsEnabled: soundsEnabled ?? this.soundsEnabled,
      motionMode: motionMode ?? this.motionMode,
      loaded: loaded ?? this.loaded,
    );
  }
}

class NaturePreferences extends Notifier<NaturePreferencesState> {
  static const soundsKey = 'nature_sounds_enabled';
  static const motionKey = 'nature_motion_mode';

  @override
  NaturePreferencesState build() {
    unawaited(_hydrate());
    return const NaturePreferencesState();
  }

  Future<void> _hydrate() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      state = state.copyWith(
        soundsEnabled: preferences.getBool(soundsKey) ??
            NaturePreferencesState.defaultSoundsEnabled,
        motionMode:
            NatureMotionMode.fromStorage(preferences.getString(motionKey)),
        loaded: true,
      );
    } catch (_) {
      // A preferences failure must never take the app down over decoration.
      // The in-memory defaults stand for this session.
      state = state.copyWith(loaded: true);
    }
  }

  Future<void> setSoundsEnabled(bool value) async {
    state = state.copyWith(soundsEnabled: value);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(soundsKey, value);
    } catch (_) {
      // Kept in memory for this session even if it could not be persisted.
    }
  }

  Future<void> setMotionMode(NatureMotionMode mode) async {
    state = state.copyWith(motionMode: mode);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(motionKey, mode.name);
    } catch (_) {
      // As above.
    }
  }
}

final naturePreferencesProvider =
    NotifierProvider<NaturePreferences, NaturePreferencesState>(
  NaturePreferences.new,
);
