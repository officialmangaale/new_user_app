import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'nature_preferences.dart';
import 'nature_tokens.dart';

/// Haptic and audio feedback for the nature layer.
///
/// The only file in the app that imports `audioplayers`. Everything else asks
/// this service for a named moment — a tap, a successful add — and never
/// touches a player.
///
/// Three rules hold everywhere in here:
///
///  1. **Nothing blocks.** Every method returns immediately. Playback is fired
///     and forgotten, so a cart mutation is never waiting on a speaker.
///  2. **Nothing throws.** Audio is decoration. On a device with no audio
///     route, in a widget test with no plugin registered, or when the platform
///     channel simply fails, these calls go quiet rather than up the stack.
///  3. **Sound is rationed.** The splash is reserved for a genuinely completed
///     add. Steppers, navigation and ordinary buttons get haptics only.
class NatureFeedbackService {
  NatureFeedbackService({required this.isSoundEnabled});

  /// Read at call time, not construction time, so toggling the setting takes
  /// effect on the very next tap.
  final bool Function() isSoundEnabled;

  AudioPlayer? _splashPlayer;
  Future<void>? _splashLoading;
  DateTime? _lastSplashAt;

  /// A small pool for the tip.
  ///
  /// Unlike the splash, several tips can legitimately sound in quick succession
  /// — one per drop entering the pot. A single player would cut each one off as
  /// the next began, so the pool round-robins and each drop gets to ring out.
  final List<AudioPlayer> _tipPool = <AudioPlayer>[];
  Future<void>? _tipLoading;
  int _tipCursor = 0;
  DateTime? _lastTipAt;

  /// Enough for the maximum number of rendered drops in one sequence, so a run
  /// of five never steals a player from itself.
  static const int _tipPoolSize = 3;

  bool _disposed = false;

  /// True once the splash asset has been loaded into a player.
  @visibleForTesting
  bool get splashReady => _splashPlayer != null;

  /// Platform audio configuration.
  ///
  /// iOS: the `ambient` category is the one that respects the physical
  /// ring/silent switch, and mixes rather than interrupting whatever the
  /// customer is already listening to. `mixWithOthers` is deliberately not
  /// passed — audioplayers asserts against combining it with `ambient`, and
  /// ambient already mixes.
  ///
  /// Android: routed as a sonification/UI sound with no audio focus request,
  /// so it plays at the system volume and never ducks the customer's music.
  /// Android exposes no per-app equivalent of the iOS silent switch; see the
  /// note on [silentModeSupport].
  static AudioContext _audioContext() => AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.assistanceSonification,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  /// Honest statement of what silent mode does per platform, surfaced so the
  /// limitation can be reported rather than assumed away.
  static const String silentModeSupport =
      'iOS: honoured — the ambient audio session category follows the physical '
      'ring/silent switch. Android: partially — the sound follows system '
      'volume and never takes audio focus, but Android has no per-app silent '
      'switch, so a device set to vibrate-only may still play it. The Nature '
      'Sounds toggle is the reliable off switch on Android.';

  /// Loads the splash into a player so the first tap does not pay for it.
  ///
  /// Safe to call more than once; concurrent calls share one load.
  Future<void> preload() {
    if (_disposed || _splashPlayer != null) return Future<void>.value();
    return _splashLoading ??= _load();
  }

  Future<void> _load() async {
    try {
      final player = AudioPlayer()
        ..setReleaseMode(ReleaseMode.stop)
        ..setPlayerMode(PlayerMode.lowLatency);
      await player.setAudioContext(_audioContext());
      await player.setSource(AssetSource(NatureAudio.splashAsset));
      await player.setVolume(NatureAudio.splashVolume);
      if (_disposed) {
        await player.dispose();
        return;
      }
      _splashPlayer = player;
    } catch (error) {
      // No audio route, no plugin (widget tests), or a codec the device does
      // not like. The app carries on silently.
      debugPrint('NatureFeedbackService: splash unavailable ($error)');
    } finally {
      _splashLoading = null;
    }
  }

  /// Light acknowledgement of a touch. No sound.
  ///
  /// Used by the ADD button on press, the quantity stepper, and anything else
  /// that wants to feel responsive without making noise.
  void tap() {
    unawaited(_safeHaptic(HapticFeedback.selectionClick));
  }

  /// A slightly firmer haptic, for a completed action.
  void impact() {
    unawaited(_safeHaptic(HapticFeedback.lightImpact));
  }

  /// The full add-to-cart moment: a light haptic followed by the splash.
  ///
  /// Call this **only** after the cart has genuinely been mutated. It is
  /// deliberately not reachable from a tap handler — see `AddToCartOutcome`.
  ///
  /// Returns immediately; the sound catches up on its own.
  void addToCartSplash() {
    impact();
    unawaited(_playSplash());
  }

  /// One water drop meeting the water inside the clay pot.
  ///
  /// Called at the instant of *visual contact*, not when the button was
  /// pressed — a sound that arrives before the drop lands reads as a UI beep
  /// rather than as water.
  ///
  /// [sequenceIndex] is the drop's position in a run. Each successive tip plays
  /// a little quieter so four drops recede rather than hammer, with [isLast]
  /// allowed back up slightly so the run has a clear end.
  ///
  /// Returns immediately, and never throws.
  void potTip({int sequenceIndex = 0, bool isLast = true}) {
    unawaited(_playTip(sequenceIndex: sequenceIndex, isLast: isLast));
  }

  Future<void> _playTip({
    required int sequenceIndex,
    required bool isLast,
  }) async {
    if (_disposed || !isSoundEnabled()) return;

    // Guards only against two drops landing in the same frame. Deliberately
    // short: sequential tips are meant to be heard individually.
    final now = DateTime.now();
    final last = _lastTipAt;
    if (last != null && now.difference(last) < NatureAudio.tipCooldown) {
      return;
    }
    _lastTipAt = now;

    try {
      await _loadTipPool();
      if (_disposed || _tipPool.isEmpty) return;

      var volume =
          NatureAudio.tipVolume *
          math.pow(NatureAudio.tipFalloff, sequenceIndex).toDouble();
      if (isLast) volume *= 1.18;
      volume = volume.clamp(NatureAudio.tipMinVolume, NatureAudio.tipVolume);

      final player = _tipPool[_tipCursor % _tipPool.length];
      _tipCursor++;
      await player.setVolume(volume);
      await player.stop();
      await player.resume();
    } catch (error) {
      debugPrint('NatureFeedbackService: tip failed ($error)');
    }
  }

  Future<void> _loadTipPool() {
    if (_disposed || _tipPool.isNotEmpty) return Future<void>.value();
    return _tipLoading ??= _createTipPool();
  }

  Future<void> _createTipPool() async {
    try {
      for (var i = 0; i < _tipPoolSize; i++) {
        final player = AudioPlayer()
          ..setReleaseMode(ReleaseMode.stop)
          ..setPlayerMode(PlayerMode.lowLatency);
        await player.setAudioContext(_audioContext());
        await player.setSource(AssetSource(NatureAudio.tipAsset));
        await player.setVolume(NatureAudio.tipVolume);
        if (_disposed) {
          await player.dispose();
          return;
        }
        _tipPool.add(player);
      }
    } catch (error) {
      debugPrint('NatureFeedbackService: tip unavailable ($error)');
    } finally {
      _tipLoading = null;
    }
  }

  /// The order-placed moment: a firmer success haptic and a single water
  /// confirmation.
  ///
  /// Reuses the same splash asset rather than shipping a second file — it is
  /// the app's one natural confirmation sound, and a second asset would add
  /// weight for a moment that happens once per order.
  ///
  /// Returns immediately. The order is already confirmed and on screen before
  /// this is called.
  void orderPlaced() {
    unawaited(_safeHaptic(HapticFeedback.mediumImpact));
    unawaited(_playSplash());
  }

  Future<void> _playSplash() async {
    if (_disposed || !isSoundEnabled()) return;

    // Cooldown. Two adds in quick succession produce one splash, not two
    // overlapping ones — the second tap is silent rather than doubled.
    final now = DateTime.now();
    final last = _lastSplashAt;
    if (last != null && now.difference(last) < NatureAudio.splashCooldown) {
      return;
    }
    _lastSplashAt = now;

    try {
      await preload();
      final player = _splashPlayer;
      if (player == null || _disposed) return;
      // Stop before resume so a replay always starts from the beginning,
      // whichever backend is in use.
      await player.stop();
      await player.resume();
    } catch (error) {
      debugPrint('NatureFeedbackService: splash failed ($error)');
    }
  }

  Future<void> _safeHaptic(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Devices without a vibrator, and the test environment.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    final player = _splashPlayer;
    _splashPlayer = null;
    final tips = List<AudioPlayer>.from(_tipPool);
    _tipPool.clear();
    try {
      await player?.dispose();
      await Future.wait(tips.map((p) => p.dispose()));
    } catch (_) {
      // Already gone.
    }
  }
}

/// App-wide feedback service.
///
/// Keeps one player for the life of the app rather than one per screen, and
/// disposes it when the provider container goes away.
final natureFeedbackServiceProvider = Provider<NatureFeedbackService>((ref) {
  final service = NatureFeedbackService(
    isSoundEnabled: () => ref.read(naturePreferencesProvider).soundsEnabled,
  );
  ref.onDispose(service.dispose);
  return service;
});
