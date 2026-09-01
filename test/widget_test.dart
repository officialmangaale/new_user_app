import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:turquoise_delivery/app/app.dart';
import 'package:turquoise_delivery/app/theme/app_theme.dart';
import 'package:turquoise_delivery/features/account/providers/engagement_providers.dart';
import 'package:turquoise_delivery/features/app_state/providers/location_providers.dart';
import 'package:turquoise_delivery/features/catalog/providers/catalog_providers.dart';
import 'package:turquoise_delivery/features/home/presentation/home_screen.dart';
import 'package:turquoise_delivery/features/orders/providers/orders_providers.dart';
import 'package:turquoise_delivery/shared/models/app_models.dart';

void main() {
  testWidgets('launches the turquoise delivery app', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TurquoiseApp()));
    expect(find.text('turquoise'), findsOneWidget);
  });

  testWidgets('guest can enter home and use the redesigned navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: TurquoiseApp()));
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Explore as guest'), findsOneWidget);

    await tester.tap(find.text('Explore as guest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.textContaining('Good evening'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.receipt_long_outlined).last);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('My orders'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_rounded).last);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('Good evening'), findsOneWidget);

    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home and four-part bottom bar fit supported phone widths', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentLocationProvider.overrideWith((ref) async => null),
          homeFeedProvider.overrideWith(
            (ref) async => const HomeFeed(restaurants: [], featuredItems: []),
          ),
          restaurantsProvider.overrideWith((ref) async => const <Restaurant>[]),
          groceryMerchantsProvider.overrideWith(
            (ref) async => const <Restaurant>[],
          ),
          categoriesProvider.overrideWith(
            (ref) async => const <HomeCategory>[],
          ),
          groceryCategoriesProvider.overrideWith(
            (ref) async => const <HomeCategory>[],
          ),
          nearbyGroceryProductsProvider.overrideWith(
            (ref) async => const <CatalogItem>[],
          ),
          sharedGroupsProvider(
            DeliveryMode.food,
          ).overrideWith((ref) async => const <SharedGroup>[]),
          sharedGroupsProvider(
            DeliveryMode.grocery,
          ).overrideWith((ref) async => const <SharedGroup>[]),
          ordersProvider.overrideWith((ref) async => const <DeliveryOrder>[]),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const HomeShellScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('FoodShare'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Food'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ShareBasket'), findsOneWidget);
    expect(find.text('Grocery'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final width in <double>[360, 375, 390, 414, 430]) {
      await tester.binding.setSurfaceSize(Size(width, 760));
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Home overflowed at ${width.toInt()}px',
      );
    }
  });

  testWidgets('login route supports back navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TurquoiseApp()));
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(milliseconds: 350));

    await tester.ensureVisible(find.text('Continue with mobile number'));
    await tester.tap(find.text('Continue with mobile number'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('What’s your number?'), findsOneWidget);

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('Explore as guest'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
