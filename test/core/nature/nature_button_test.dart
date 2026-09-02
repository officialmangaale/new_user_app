import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/core/nature/nature_preferences.dart';
import 'package:turquoise_delivery/core/widgets/app_ui.dart';
import 'package:turquoise_delivery/core/nature/widgets/nature_button.dart';

/// The contract that matters most for this wrapper: it must never turn one tap
/// into two callbacks, and it must never hold a callback back while an
/// animation plays.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(Widget child, {bool disableAnimations = false}) {
    return ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );
  }

  testWidgets('invokes the callback exactly once per tap', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        NatureButton(
          onTap: () => calls++,
          builder: (context, handleTap) =>
              OutlinedButton(onPressed: handleTap, child: const Text('ADD')),
        ),
      ),
    );

    await tester.tap(find.text('ADD'));
    await tester.pump();
    expect(calls, 1);

    await tester.pumpAndSettle();
    expect(calls, 1, reason: 'the ripple must not re-fire the callback');
  });

  testWidgets('rapid taps produce one callback each, never more', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        NatureButton(
          onTap: () => calls++,
          builder: (context, handleTap) =>
              OutlinedButton(onPressed: handleTap, child: const Text('ADD')),
        ),
      ),
    );

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('ADD'));
      // Mid-ripple: the next tap lands while the previous animation is running.
      await tester.pump(const Duration(milliseconds: 40));
    }

    expect(calls, 5);
    await tester.pumpAndSettle();
    expect(calls, 5);
  });

  testWidgets('callback runs synchronously, not after the animation', (
    tester,
  ) async {
    var called = false;
    await tester.pumpWidget(
      host(
        NatureButton(
          onTap: () => called = true,
          builder: (context, handleTap) =>
              OutlinedButton(onPressed: handleTap, child: const Text('ADD')),
        ),
      ),
    );

    await tester.tap(find.text('ADD'));
    // No pump beyond the tap's own: if the wrapper deferred the callback until
    // the ripple finished, this would still be false.
    expect(called, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('a null callback leaves the control disabled', (tester) async {
    await tester.pumpWidget(
      host(
        const NatureButton(
          onTap: null,
          builder: _disabledBuilder,
        ),
      ),
    );

    await tester.tap(find.text('ADD'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('still fires the callback with platform reduced motion on', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        NatureButton(
          onTap: () => calls++,
          builder: (context, handleTap) =>
              OutlinedButton(onPressed: handleTap, child: const Text('ADD')),
        ),
        disableAnimations: true,
      ),
    );

    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    expect(calls, 1, reason: 'reduced motion removes movement, not function');
  });

  testWidgets('still fires the callback with the motion preference reduced', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      NaturePreferences.motionKey: NatureMotionMode.reduced.name,
    });

    var calls = 0;
    await tester.pumpWidget(
      host(
        NatureButton(
          onTap: () => calls++,
          builder: (context, handleTap) =>
              OutlinedButton(onPressed: handleTap, child: const Text('ADD')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  group('QuantityControl ADD, the real shipping path', () {
    Widget quantityHost(VoidCallback onAdd, {int quantity = 0}) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuantityControl(
                quantity: quantity,
                onAdd: onAdd,
                onRemove: () {},
                compact: true,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('one tap on ADD calls onAdd exactly once', (tester) async {
      var calls = 0;
      await tester.pumpWidget(quantityHost(() => calls++));

      await tester.tap(find.text('ADD'));
      await tester.pumpAndSettle();

      expect(calls, 1);
    });

    testWidgets('ten rapid taps produce exactly ten calls', (tester) async {
      var calls = 0;
      await tester.pumpWidget(quantityHost(() => calls++));

      for (var i = 0; i < 10; i++) {
        await tester.tap(find.text('ADD'));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();

      expect(
        calls,
        10,
        reason: 'the ripple, the scale and the wrapper must not add or drop '
            'a single invocation',
      );
    });

    testWidgets('the + stepper still calls onAdd once per tap', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(quantityHost(() => calls++, quantity: 2));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(calls, 1);
    });
  });

  testWidgets('settles — no controller is left running', (tester) async {
    await tester.pumpWidget(
      host(
        NatureButton(
          onTap: () {},
          builder: (context, handleTap) =>
              OutlinedButton(onPressed: handleTap, child: const Text('ADD')),
        ),
      ),
    );

    await tester.tap(find.text('ADD'));
    // A repeating controller anywhere in the nature layer would hang here
    // rather than fail, so this assertion guards the whole suite.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposes cleanly while a ripple is mid-flight', (tester) async {
    await tester.pumpWidget(
      host(
        NatureButton(
          onTap: () {},
          builder: (context, handleTap) =>
              OutlinedButton(onPressed: handleTap, child: const Text('ADD')),
        ),
      ),
    );

    await tester.tap(find.text('ADD'));
    await tester.pump(const Duration(milliseconds: 60));

    // Tear the widget out while the ripple is still animating.
    await tester.pumpWidget(host(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Widget _disabledBuilder(BuildContext context, VoidCallback handleTap) =>
    const OutlinedButton(onPressed: null, child: Text('ADD'));
