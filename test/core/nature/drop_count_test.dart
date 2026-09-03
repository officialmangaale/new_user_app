import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/core/nature/nature_preferences.dart';
import 'package:turquoise_delivery/core/nature/nature_tokens.dart';
import 'package:turquoise_delivery/features/cart/providers/cart_controller.dart';
import 'package:turquoise_delivery/features/catalog/presentation/add_to_cart.dart';
import 'package:turquoise_delivery/shared/models/app_models.dart';

/// The drop count is *measured*, never assumed.
///
/// The number of falling drops comes from the quantity that actually landed in
/// the cart, read before and after the mutation. That direction matters: an
/// animation driven by tap counts would eventually disagree with the cart, and
/// an animation that could trigger mutations would corrupt it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Sounds off throughout: constructing an AudioPlayer in a test VM with no
  // audioplayers plugin raises an asynchronous MissingPluginException, and none
  // of these assertions are about audio.
  setUp(
    () => SharedPreferences.setMockInitialValues(
      <String, Object>{NaturePreferences.soundsKey: false},
    ),
  );

  const item = CatalogItem(
    id: 'i1',
    name: 'Alphonso Mangoes',
    subtitle: '1 kg',
    store: 'Green Basket',
    price: 240,
    originalPrice: 280,
    imageUrl: '',
    type: CatalogItemType.grocery,
    storeId: 's1',
  );

  Future<ProviderContainer> pumpAdder(
    WidgetTester tester,
    int taps,
  ) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return TextButton(
                  onPressed: () => addItemToCart(context, ref, item),
                  child: const Text('add'),
                );
              },
            ),
          ),
        ),
      ),
    );

    for (var i = 0; i < taps; i++) {
      await tester.tap(find.text('add'));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('one tap adds exactly one unit', (tester) async {
    final container = await pumpAdder(tester, 1);
    expect(container.read(cartCountProvider), 1);
  });

  testWidgets('four taps add exactly four units, on one line', (tester) async {
    final container = await pumpAdder(tester, 4);

    expect(container.read(cartCountProvider), 4);
    expect(
      container.read(cartLinesProvider).length,
      1,
      reason: 'the same configuration stays a single cart line',
    );
  });

  testWidgets('the animation never mutates the cart', (tester) async {
    final container = await pumpAdder(tester, 3);
    final afterTaps = container.read(cartCountProvider);

    // Let every drop finish falling and every impact fire. If the sequence
    // touched cart state — even once, even by accident — the count would move
    // here, with no tap behind it.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(container.read(cartCountProvider), afterTaps);
    expect(afterTaps, 3);
  });

  group('the rendered-drop cap is visual only', () {
    test('caps the number of animated objects', () {
      expect(NatureMetrics.maxRenderedDrops, 5);
    });

    testWidgets('a quantity beyond the cap still counts in full', (
      tester,
    ) async {
      final container = await pumpAdder(tester, 8);

      // Eight taps, eight units. The cap only limits how many drops are drawn;
      // it must never limit the cart.
      expect(
        container.read(cartCountProvider),
        8,
        reason: 'the visual cap must not clamp the real quantity',
      );
    });
  });

  testWidgets('a refused add produces no units and no drops', (tester) async {
    late ProviderContainer container;
    late AddToCartOutcome outcome;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return TextButton(
                  onPressed: () async {
                    outcome = await addItemToCart(
                      context,
                      ref,
                      const CatalogItem(
                        id: 'i2',
                        name: 'Sold Out Dish',
                        subtitle: '',
                        store: 'Green Basket',
                        price: 100,
                        originalPrice: 100,
                        imageUrl: '',
                        type: CatalogItemType.grocery,
                        storeId: 's1',
                        isAvailable: false,
                      ),
                    );
                  },
                  child: const Text('add'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();

    expect(outcome, AddToCartOutcome.unavailable);
    expect(container.read(cartCountProvider), 0);
    expect(find.text('Sold Out Dish is unavailable right now.'), findsOneWidget);
  });
}
