import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/features/cart/providers/cart_controller.dart';
import 'package:turquoise_delivery/features/catalog/presentation/add_to_cart.dart';
import 'package:turquoise_delivery/features/catalog/providers/catalog_providers.dart';
import 'package:turquoise_delivery/shared/models/app_models.dart';

/// Cart outcomes remain independent of visual feedback.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  CatalogItem item({
    String id = 'i1',
    bool isAvailable = true,
    bool hasVariants = false,
    bool hasAddons = false,
    CatalogItemType type = CatalogItemType.grocery,
  }) {
    return CatalogItem(
      id: id,
      name: 'Alphonso Mangoes',
      subtitle: '1 kg',
      store: 'Green Basket',
      price: 240,
      originalPrice: 280,
      imageUrl: '',
      type: type,
      storeId: 's1',
      isAvailable: isAvailable,
      hasVariants: hasVariants,
      hasAddons: hasAddons,
    );
  }

  /// Pumps a host that gives [addItemToCart] a real BuildContext with a
  /// ScaffoldMessenger and an Overlay, then runs it and returns the outcome.
  Future<(AddToCartOutcome, ProviderContainer)> run(
    WidgetTester tester,
    CatalogItem product, {
    bool forceCustomise = false,
  }) async {
    late AddToCartOutcome outcome;
    late ProviderContainer container;

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
                      product,
                      forceCustomise: forceCustomise,
                    );
                  },
                  child: const Text('go'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return (outcome, container);
  }

  testWidgets('a plain available item reports added and changes the cart', (
    tester,
  ) async {
    final (outcome, container) = await run(tester, item());

    expect(outcome, AddToCartOutcome.added);
    expect(outcome.didMutateCart, isTrue);
    expect(container.read(cartCountProvider), 1);
  });

  testWidgets('an unavailable item never reports added', (tester) async {
    final (outcome, container) = await run(tester, item(isAvailable: false));

    expect(outcome, AddToCartOutcome.unavailable);
    expect(
      outcome.didMutateCart,
      isFalse,
      reason: 'an unavailable item must not produce a success animation',
    );
    expect(
      container.read(cartCountProvider),
      0,
      reason: 'the guard clause must still block the mutation',
    );
  });

  testWidgets('the existing unavailable message is still shown', (
    tester,
  ) async {
    await run(tester, item(isAvailable: false));
    expect(
      find.text('Alphonso Mangoes is unavailable right now.'),
      findsOneWidget,
    );
  });

  testWidgets('slow option hydration does not add or celebrate early', (
    tester,
  ) async {
    final hydration = Completer<CatalogItem>();
    late ProviderContainer container;
    Future<AddToCartOutcome>? pending;
    final product = item(
      id: 'slow-food',
      type: CatalogItemType.food,
      hasVariants: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemDetailProvider.overrideWith((ref, id) => hydration.future),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return TextButton(
                  onPressed: () =>
                      pending = addItemToCart(context, ref, product),
                  child: const Text('go'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 500));

    final firstRequest = pending;
    await tester.tap(find.text('go'));
    expect(
      await pending,
      AddToCartOutcome.cancelled,
      reason: 'rapid taps must not open duplicate option flows',
    );

    expect(container.read(cartCountProvider), 0);

    hydration.complete(item(id: 'slow-food', type: CatalogItemType.food));
    await tester.pumpAndSettle();

    expect(await firstRequest, AddToCartOutcome.added);
    expect(container.read(cartCountProvider), 1);
  });

  testWidgets('failed option hydration never mutates the cart', (tester) async {
    late ProviderContainer container;
    Future<AddToCartOutcome>? pending;
    final product = item(
      id: 'failed-food',
      type: CatalogItemType.food,
      hasVariants: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          itemDetailProvider.overrideWith(
            (ref, id) => Future<CatalogItem>.error(Exception('offline')),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return TextButton(
                  onPressed: () =>
                      pending = addItemToCart(context, ref, product),
                  child: const Text('go'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(await pending, AddToCartOutcome.optionsUnavailable);
    expect(container.read(cartCountProvider), 0);
    expect(find.text('Could not load options for Alphonso Mangoes.'), findsOne);
  });

  testWidgets('a dismissed customise sheet reports cancelled', (tester) async {
    // This one cannot use `run`: the call parks on the open sheet, so the
    // future has to be held and awaited after the sheet is dismissed.
    late ProviderContainer container;
    Future<AddToCartOutcome>? pending;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return TextButton(
                  // A grocery item flagged as needing variants skips
                  // hydration (that path is food-only) and opens the sheet.
                  onPressed: () => pending = addItemToCart(
                    context,
                    ref,
                    item(hasVariants: true),
                  ),
                  child: const Text('go'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    // The sheet is open; dismiss it the way a customer would.
    final sheetContext = tester.element(find.byType(Scaffold).last);
    Navigator.of(sheetContext).pop();
    await tester.pumpAndSettle();

    expect(await pending, AddToCartOutcome.cancelled);
    expect(
      container.read(cartCountProvider),
      0,
      reason: 'dismissing the sheet must not add anything',
    );
  });

  testWidgets('adding twice increments rather than duplicating a line', (
    tester,
  ) async {
    late ProviderContainer container;
    var taps = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return TextButton(
                  onPressed: () {
                    taps++;
                    addItemToCart(context, ref, item());
                  },
                  child: const Text('go'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(taps, 2);
    expect(container.read(cartCountProvider), 2);
    expect(
      container.read(cartLinesProvider).length,
      1,
      reason: 'the same configuration must stay one line',
    );
  });
}
