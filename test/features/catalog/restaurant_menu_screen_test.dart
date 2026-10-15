import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/app/theme/app_colors.dart';
import 'package:turquoise_delivery/app/theme/app_theme.dart';
import 'package:turquoise_delivery/features/catalog/domain/entities/catalog_entities.dart';
import 'package:turquoise_delivery/features/catalog/presentation/menu/menu_styles.dart';
import 'package:turquoise_delivery/features/catalog/presentation/menu/restaurant_menu_screen.dart';
import 'package:turquoise_delivery/features/catalog/providers/catalog_providers.dart';

CatalogItem _dish(
  String id,
  String name, {
  bool veg = true,
  int price = 120,
  int original = 0,
  String subtitle = '',
  bool available = true,
  bool bestseller = false,
}) => CatalogItem(
  id: id,
  name: name,
  subtitle: subtitle,
  store: 'Test Kitchen',
  storeId: 'r1',
  price: price,
  originalPrice: original == 0 ? price : original,
  imageUrl: '',
  type: CatalogItemType.food,
  isVeg: veg,
  isAvailable: available,
  isBestseller: bestseller,
);

Restaurant _restaurant({
  String name = 'Test Kitchen',
  double rating = 4.3,
  bool? isOpen,
  String opensAt = '',
  int discount = 0,
}) => Restaurant(
  id: 'r1',
  name: name,
  cuisine: 'Cafe, Sandwiches, Wraps',
  rating: rating,
  deliveryMinutes: 30,
  distanceKm: 2.4,
  deliveryFee: 20,
  discount: discount,
  imageUrl: '',
  isOpen: isOpen,
  opensAt: opensAt,
  costForTwo: 300,
  area: 'Indiranagar',
);

final _sections = [
  MenuSection(
    id: 's1',
    name: 'Sandwich',
    items: [
      _dish(
        'a',
        'Paneer Tikka Sandwich',
        subtitle: 'Grilled with mint chutney',
        bestseller: true,
        original: 160,
      ),
      _dish('b', 'Chicken Club', veg: false),
    ],
  ),
  MenuSection(
    id: 's2',
    name: 'Bao',
    items: [_dish('c', 'Mushroom Bao'), _dish('d', 'Pork Bao', veg: false)],
  ),
  MenuSection(
    id: 's3',
    name: 'Wraps',
    items: [_dish('e', 'Falafel Wrap', available: false)],
  ),
  MenuSection(
    id: 's4',
    name: 'Chicken Specials',
    items: [_dish('f', 'Chicken Roll', veg: false)],
  ),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> host(
    WidgetTester tester, {
    Restaurant? restaurant,
    List<MenuSection>? sections,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const RestaurantDetailsScreen(restaurantId: 'r1'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          restaurantDetailProvider.overrideWith(
            (ref, id) async => restaurant ?? _restaurant(),
          ),
          restaurantMenuProvider.overrideWith(
            (ref, id) async => sections ?? _sections,
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows restaurant data, sections and ADD buttons', (
    tester,
  ) async {
    await host(tester);
    expect(find.text('Test Kitchen'), findsOneWidget);
    expect(find.text('Cafe, Sandwiches, Wraps'), findsOneWidget);
    expect(find.text('4.3'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('₹300 for two'), findsOneWidget);
    expect(find.text('Sandwich'), findsWidgets);
    expect(find.text('2 items'), findsWidgets);
    expect(find.text('Bestseller'), findsOneWidget);
    expect(find.text('Paneer Tikka Sandwich'), findsOneWidget);
    expect(find.text('₹160'), findsOneWidget); // struck-through old price
    expect(find.text('ADD'), findsWidgets);
    // No logo from the API -> initials in the badge.
    expect(find.text('TK'), findsOneWidget);
  });

  testWidgets('unrated restaurant shows New and no offer strip', (
    tester,
  ) async {
    await host(tester, restaurant: _restaurant(rating: 0));
    expect(find.text('New'), findsOneWidget);
    expect(find.textContaining('% OFF'), findsNothing);
  });

  testWidgets('discount renders the coral offer strip', (tester) async {
    await host(tester, restaurant: _restaurant(discount: 20));
    expect(find.text('20% OFF'), findsOneWidget);
  });

  testWidgets('closed restaurant shows banner and disables ADD', (
    tester,
  ) async {
    await host(
      tester,
      restaurant: _restaurant(isOpen: false, opensAt: '11:00'),
    );
    expect(find.text('Currently closed · Opens at 11 AM'), findsOneWidget);
    final add = find.bySemanticsLabel(RegExp('unavailable'));
    expect(add, findsWidgets);
  });

  testWidgets('ADD becomes a stepper and the cart bar appears', (tester) async {
    await host(tester);
    expect(find.textContaining('added'), findsNothing);
    await tester.tap(find.text('ADD').first);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsWidgets);
    expect(find.text('1 item added'), findsOneWidget);
    expect(find.text('View cart'), findsOneWidget);
  });

  testWidgets('sold out items show a disabled Sold out button', (tester) async {
    await host(tester);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Sold out'), findsOneWidget);
  });

  testWidgets('veg toggle hides non-veg dishes and empty categories', (
    tester,
  ) async {
    await host(tester);
    expect(find.text('Chicken Specials'), findsWidgets);
    await tester.tap(find.text('Veg'));
    await tester.pumpAndSettle();
    expect(find.text('Chicken Specials'), findsNothing);
    expect(find.text('Chicken Club'), findsNothing);
    expect(find.text('Paneer Tikka Sandwich'), findsOneWidget);
  });

  testWidgets('empty search shows message and Clear search restores', (
    tester,
  ) async {
    await host(tester);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text("No dishes match 'zzz'"), findsOneWidget);
    await tester.tap(find.text('Clear search').last);
    await tester.pumpAndSettle();
    expect(find.text("No dishes match 'zzz'"), findsNothing);
    expect(find.text('Paneer Tikka Sandwich'), findsOneWidget);
  });

  testWidgets('tapping a chip scrolls to that section', (tester) async {
    await host(tester);
    // "Wraps" starts below the fold.
    final chip = find.widgetWithText(InkWell, 'Wraps').first;
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('Falafel Wrap'), findsOneWidget);
    final box = tester.getRect(find.text('Falafel Wrap'));
    expect(box.top, greaterThan(100));
    expect(box.top, lessThan(500));
  });

  testWidgets('no overflow on a 360x640 phone with long names', (tester) async {
    await host(
      tester,
      size: const Size(360, 640),
      restaurant: _restaurant(
        name: 'The Extraordinarily Long Restaurant Name Kitchen & Bakery',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('menu helpers', () {
    expect(initialsOf('Cafe Mocha'), 'CM');
    expect(initialsOf('burger'), 'B');
    expect(initialsOf('  '), '');
    expect(friendlyTime('11:00'), '11 AM');
    expect(friendlyTime('18:30:00'), '6:30 PM');
    expect(friendlyTime('Tomorrow 9 AM'), 'Tomorrow 9 AM');
    expect(rupees(359.6), '₹360');
  });

  test('brand tokens used by the menu keep their contrast', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (la > lb ? la + 0.05 : lb + 0.05) /
          (la > lb ? lb + 0.05 : la + 0.05);
    }

    expect(contrast(AppColors.primary, AppColors.ink), greaterThan(7));
    expect(contrast(AppColors.deepTeal, AppColors.surface), greaterThan(4.5));
    expect(
      contrast(AppColors.inkSecondary, AppColors.surface),
      greaterThan(4.5),
    );
    expect(contrast(Colors.white, AppColors.vegGreen), greaterThan(4.5));
    expect(contrast(AppColors.ink, AppColors.coral), greaterThan(4.5));
  });
}
