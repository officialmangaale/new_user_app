import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/core/nature/widgets/leaf_add_button.dart';
import 'package:turquoise_delivery/core/widgets/app_ui.dart';

/// The leaf is a *shape*, not a clip. These tests pin the two things that would
/// go wrong if that were ever changed: the button getting smaller than it looks,
/// and taps near the rounded corners missing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(Widget child) => ProviderScope(
    child: MaterialApp(home: Scaffold(body: Center(child: child))),
  );

  testWidgets('keeps the compact tap target at 72 x 38', (tester) async {
    await tester.pumpWidget(
      host(
        QuantityControl(
          quantity: 0,
          onAdd: () {},
          onRemove: () {},
          compact: true,
        ),
      ),
    );

    final size = tester.getSize(find.byType(LeafAddButton));
    expect(size.width, greaterThanOrEqualTo(72));
    expect(size.height, 38);
  });

  testWidgets('keeps the full-size tap target at 88 x 44', (tester) async {
    await tester.pumpWidget(
      host(QuantityControl(quantity: 0, onAdd: () {}, onRemove: () {})),
    );

    final size = tester.getSize(find.byType(LeafAddButton));
    expect(size.width, greaterThanOrEqualTo(88));
    expect(size.height, 44);
  });

  testWidgets('taps land in all four corners of the rectangle', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        QuantityControl(
          quantity: 0,
          onAdd: () => calls++,
          onRemove: () {},
          compact: true,
        ),
      ),
    );

    // A ClipPath around a leaf outline would swallow the two nearly-square
    // corners and, worse, most of the two rounded ones. Every corner must
    // still register.
    final rect = tester.getRect(find.byType(LeafAddButton));
    const inset = 3.0;
    for (final point in <Offset>[
      rect.topLeft + const Offset(inset, inset),
      rect.topRight + const Offset(-inset, inset),
      rect.bottomLeft + const Offset(inset, -inset),
      rect.bottomRight + const Offset(-inset, -inset),
    ]) {
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();

    expect(calls, 4, reason: 'the leaf shape must not shrink the hit area');
  });

  testWidgets('still shows the ADD label and reads as one button', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        QuantityControl(
          quantity: 0,
          onAdd: () {},
          onRemove: () {},
          compact: true,
        ),
      ),
    );

    expect(find.text('ADD'), findsOneWidget);
    expect(find.byType(LeafAddButton), findsOneWidget);
  });

  testWidgets('the stepper is untouched once an item is in the cart', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        QuantityControl(
          quantity: 2,
          onAdd: () {},
          onRemove: () {},
          compact: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No leaf on the +/-/quantity branch — that control was explicitly left
    // alone.
    expect(find.byType(LeafAddButton), findsNothing);
    expect(find.text('2'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
  });
}
