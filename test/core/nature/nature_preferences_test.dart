import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/core/nature/nature_motion.dart';
import 'package:turquoise_delivery/core/nature/nature_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer container() {
    final result = ProviderContainer();
    addTearDown(result.dispose);
    return result;
  }

  test('defaults to sounds on and full motion for the preview build', () async {
    final ref = container();
    final state = ref.read(naturePreferencesProvider);

    expect(state.soundsEnabled, isTrue);
    expect(state.motionMode, NatureMotionMode.full);
  });

  test('persists the sound preference and reads it back', () async {
    final ref = container();
    await ref.read(naturePreferencesProvider.notifier).setSoundsEnabled(false);

    expect(ref.read(naturePreferencesProvider).soundsEnabled, isFalse);

    final stored = await SharedPreferences.getInstance();
    expect(stored.getBool(NaturePreferences.soundsKey), isFalse);
  });

  test('persists the motion preference and reads it back', () async {
    final ref = container();
    await ref
        .read(naturePreferencesProvider.notifier)
        .setMotionMode(NatureMotionMode.reduced);

    expect(
      ref.read(naturePreferencesProvider).motionMode,
      NatureMotionMode.reduced,
    );

    final stored = await SharedPreferences.getInstance();
    expect(
      stored.getString(NaturePreferences.motionKey),
      NatureMotionMode.reduced.name,
    );
  });

  test('hydrates stored values on a fresh container', () async {
    SharedPreferences.setMockInitialValues({
      NaturePreferences.soundsKey: false,
      NaturePreferences.motionKey: NatureMotionMode.reduced.name,
    });

    final ref = container();
    // Build starts an async hydrate; let it complete.
    ref.read(naturePreferencesProvider);
    await Future<void>.delayed(Duration.zero);

    final state = ref.read(naturePreferencesProvider);
    expect(state.loaded, isTrue);
    expect(state.soundsEnabled, isFalse);
    expect(state.motionMode, NatureMotionMode.reduced);
  });

  test('unrecognised stored motion value falls back to full', () {
    expect(NatureMotionMode.fromStorage(null), NatureMotionMode.full);
    expect(NatureMotionMode.fromStorage('nonsense'), NatureMotionMode.full);
    expect(
      NatureMotionMode.fromStorage('reduced'),
      NatureMotionMode.reduced,
    );
  });

  group('platform reduced motion overrides the in-app preference', () {
    test('device asking for reduced motion wins over "full"', () {
      expect(
        natureMotionEnabledFor(
          mode: NatureMotionMode.full,
          platformReducedMotion: true,
        ),
        isFalse,
      );
    });

    test('in-app "reduced" applies even when the device is unrestricted', () {
      expect(
        natureMotionEnabledFor(
          mode: NatureMotionMode.reduced,
          platformReducedMotion: false,
        ),
        isFalse,
      );
    });

    test('full motion needs both to agree', () {
      expect(
        natureMotionEnabledFor(
          mode: NatureMotionMode.full,
          platformReducedMotion: false,
        ),
        isTrue,
      );
    });
  });
}
