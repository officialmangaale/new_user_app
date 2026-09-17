import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/features/cart/providers/cart_controller.dart';
import 'package:turquoise_delivery/features/catalog/presentation/add_to_cart.dart';
import 'package:turquoise_delivery/shared/models/app_models.dart';

/// Grocery lists mix shops; a grocery order comes from one shop. Adding a
/// product from another shop must never empty the cart without asking.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  CatalogItem grocery(String id, String storeId, String store) => CatalogItem(
    id: id,
    name: 'Item $id',
    subtitle: '',
    store: store,
    price: 40,
    originalPrice: 40,
    imageUrl: '',
    type: CatalogItemType.grocery,
    storeId: storeId,
  );

  final fromAnita = grocery('milk', 's1', 'Anita Daily Needs');
  final fromGreen = grocery('rice', 's2', 'Green Basket');

  /// Pumps a host whose button adds [product]; returns the container and a
  /// getter for the outcome once the add completes.
  Future<(ProviderContainer, AddToCartOutcome? Function())> host(
    WidgetTester tester,
    CatalogItem product,
  ) async {
    late ProviderContainer container;
    AddToCartOutcome? outcome;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return TextButton(
                  onPressed: () async {
                    outcome = await addItemToCart(context, ref, product);
                  },
                  child: const Text('add'),
                );
              },
            ),
          ),
        ),
      ),
    );
    return (container, () => outcome);
  }

  List<String> groceryStores(ProviderContainer container) {
    final cart = container.read(cartControllerProvider);
    return cart.groceryCart.keys
        .map((lineId) => cart.knownItems[lineId]!.item.storeId)
        .toList();
  }

  testWidgets('another shop asks, and Keep cart changes nothing', (
    tester,
  ) async {
    final (container, outcome) = await host(tester, fromGreen);
    container
        .read(cartControllerProvider.notifier)
        .addItem(fromAnita, restaurantId: 's1');

    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();

    expect(find.text('Replace your grocery cart?'), findsOneWidget);
    expect(find.textContaining('Anita Daily Needs'), findsOneWidget);
    expect(find.textContaining('Green Basket'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('grocery_shop_switch_keep')));
    await tester.pumpAndSettle();

    expect(outcome(), AddToCartOutcome.cancelled);
    expect(groceryStores(container), ['s1']);
    expect(container.read(cartControllerProvider).cartGroceryMerchantId, 's1');
  });

  testWidgets('Replace starts a new cart from the new shop', (tester) async {
    final (container, outcome) = await host(tester, fromGreen);
    container
        .read(cartControllerProvider.notifier)
        .addItem(fromAnita, restaurantId: 's1');

    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('grocery_shop_switch_replace')));
    await tester.pumpAndSettle();

    expect(outcome(), AddToCartOutcome.added);
    expect(groceryStores(container), ['s2']);
    expect(container.read(cartControllerProvider).cartGroceryMerchantId, 's2');
  });

  testWidgets('the same shop, or an empty cart, adds without asking', (
    tester,
  ) async {
    final sameShop = grocery('curd', 's1', 'Anita Daily Needs');
    final (container, outcome) = await host(tester, sameShop);

    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();
    expect(find.text('Replace your grocery cart?'), findsNothing);
    expect(outcome(), AddToCartOutcome.added);

    container
        .read(cartControllerProvider.notifier)
        .addItem(fromAnita, restaurantId: 's1');
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();

    expect(find.text('Replace your grocery cart?'), findsNothing);
    expect(groceryStores(container), everyElement('s1'));
  });
}
