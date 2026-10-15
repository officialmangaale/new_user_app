import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/app/theme/app_colors.dart';
import 'package:turquoise_delivery/app/theme/app_theme.dart';
import 'package:turquoise_delivery/core/services/location_service.dart';
import 'package:turquoise_delivery/core/services/reverse_geocoding_service.dart';
import 'package:turquoise_delivery/features/app_state/providers/location_providers.dart';
import 'package:turquoise_delivery/features/cart/providers/cart_controller.dart';
import 'package:turquoise_delivery/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:turquoise_delivery/features/catalog/providers/catalog_providers.dart';
import 'package:turquoise_delivery/features/home/presentation/home_screen.dart';
import 'package:turquoise_delivery/features/home/presentation/widgets/home_header.dart';
import 'package:turquoise_delivery/shared/models/app_models.dart';
import 'package:turquoise_delivery/shared/widgets/delivery_cards.dart';

Restaurant _r(
  String id,
  String name, {
  double rating = 4.3,
  int minutes = 30,
  double? km = 2.4,
  int discount = 0,
  bool? isOpen,
  String opensAt = '',
  int costForTwo = 0,
  String cuisine = 'Cafe, Sandwiches',
}) => Restaurant(
  id: id,
  name: name,
  cuisine: cuisine,
  rating: rating,
  deliveryMinutes: minutes,
  distanceKm: km,
  deliveryFee: 0,
  discount: discount,
  imageUrl: '',
  isOpen: isOpen,
  opensAt: opensAt,
  costForTwo: costForTwo,
);

final _restaurants = [
  _r('1', 'Bite Hut', rating: 4.6, discount: 20, costForTwo: 300),
  _r('2', 'Noodle Bar', rating: 3.8, minutes: 45, costForTwo: 180),
  _r('3', 'Fresh Start', rating: 0, minutes: 0, km: null),
  _r('4', 'Night Owl', isOpen: false, opensAt: '11:00'),
];

class _NoGeocoder implements ReverseGeocoder {
  const _NoGeocoder();

  @override
  Future<PlaceAddress?> reverse(double latitude, double longitude) async =>
      null;
}

class _FixedGeocoder implements ReverseGeocoder {
  const _FixedGeocoder(this.address);
  final PlaceAddress address;

  @override
  Future<PlaceAddress?> reverse(double latitude, double longitude) async =>
      address;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> host(
    WidgetTester tester, {
    List<Restaurant>? restaurants,
    List<HomeBanner> banners = const [],
    List<HomeCategory> categories = const [],
    Size size = const Size(390, 900),
    int cartCount = 0,
    ReverseGeocoder? geocoder,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: DeliveryHomeFeed()),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        restaurantsProvider.overrideWith(
          (ref) async => restaurants ?? _restaurants,
        ),
        homeFeedProvider.overrideWith(
          (ref) async => HomeFeed(
            restaurants: restaurants ?? _restaurants,
            featuredItems: const [],
            banners: banners,
          ),
        ),
        categoriesProvider.overrideWith((ref) async => categories),
        groceryMerchantsProvider.overrideWith(
          (ref) async => const <Restaurant>[],
        ),
        groceryCategoriesProvider.overrideWith(
          (ref) async => const <HomeCategory>[],
        ),
        nearbyGroceryProductsProvider.overrideWith(
          (ref) async => const <CatalogItem>[],
        ),
        currentLocationProvider.overrideWith(
          (ref) async => const UserLocation(latitude: 12.9, longitude: 77.6),
        ),
        cartCountProvider.overrideWithValue(cartCount),
        reverseGeocoderProvider.overrideWithValue(
          geocoder ?? const _NoGeocoder(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  test(
    'greeting follows the time of day and drops the comma without a name',
    () {
      expect(
        greetingFor(DateTime(2026, 1, 1, 8), 'Asha Rao'),
        'Good morning, Asha',
      );
      expect(
        greetingFor(DateTime(2026, 1, 1, 13), 'Asha'),
        'Good afternoon, Asha',
      );
      expect(greetingFor(DateTime(2026, 1, 1, 19), null), 'Good evening');
      expect(greetingFor(DateTime(2026, 1, 1, 19), '  '), 'Good evening');
    },
  );

  test('stray possessive apostrophes are cleaned from category names', () {
    expect(cleanCategoryName("Burger's"), 'Burgers');
    expect(cleanCategoryName('Burger’s'), 'Burgers');
    expect(cleanCategoryName("Momo's"), 'Momos');
    expect(cleanCategoryName("Mom's Kitchen"), "Mom's Kitchen");
    expect(cleanCategoryName('Pizza'), 'Pizza');
  });

  testWidgets('renders header, sections and restaurant data', (tester) async {
    await host(
      tester,
      categories: const [
        HomeCategory(
          key: 'burgers',
          name: 'Burgers',
          imageUrl: '',
          icon: 'burger',
          itemCount: 3,
        ),
      ],
    );
    expect(find.textContaining('Good '), findsWidgets);
    expect(find.text('What are you craving today?'), findsOneWidget);
    expect(find.text('Search "momos" or "pizza"'), findsOneWidget);
    expect(find.text("What's on your mind?"), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Burgers'), findsOneWidget);
    expect(find.text('Popular near you'), findsOneWidget);
    expect(find.text('All restaurants'), findsOneWidget);
    expect(find.text('3 open now'), findsOneWidget);
    expect(find.text('Bite Hut'), findsWidgets);
  });

  testWidgets('missing rating, distance and offer are hidden cleanly', (
    tester,
  ) async {
    await host(
      tester,
      restaurants: [_r('3', 'Fresh Start', rating: 0, minutes: 0, km: null)],
    );
    expect(find.text('New'), findsWidgets);
    expect(find.textContaining('null'), findsNothing);
    // An unknown distance is omitted, never rendered as "0 km".
    expect(find.textContaining(' km'), findsNothing);
    expect(find.textContaining('0 min'), findsNothing);
    expect(find.textContaining('% OFF'), findsNothing);
    // Logo falls back to initials.
    expect(find.text('FS'), findsOneWidget);
  });

  testWidgets('header shows the resolved locality, not "Current location"', (
    tester,
  ) async {
    await host(
      tester,
      geocoder: const _FixedGeocoder(
        PlaceAddress(
          sublocality: 'Vijay Nagar',
          locality: 'Bijnor',
          district: 'Bijnor',
          state: 'Uttar Pradesh',
          postalCode: '246722',
        ),
      ),
    );
    expect(find.text('Vijay Nagar'), findsOneWidget);
    expect(find.text('Bijnor, Uttar Pradesh'), findsOneWidget);
    expect(find.text('Current location'), findsNothing);
  });

  testWidgets('header falls back honestly when no area name is found', (
    tester,
  ) async {
    await host(tester);
    expect(find.text('Current location'), findsOneWidget);
    expect(find.text('Locating...'), findsNothing);
  });

  testWidgets('offer badge appears only when data says so', (tester) async {
    await host(tester);
    expect(find.text('20% OFF'), findsOneWidget);
  });

  testWidgets('closed restaurant is labelled with its opening time', (
    tester,
  ) async {
    await host(
      tester,
      restaurants: [_r('4', 'Night Owl', isOpen: false, opensAt: '11:00')],
    );
    expect(find.text('Closed · Opens at 11 AM'), findsOneWidget);
    expect(find.text('0 open now'), findsOneWidget);
  });

  testWidgets('quick filters narrow the list and hide when unsupported', (
    tester,
  ) async {
    await host(tester);
    expect(find.text('Pure veg'), findsNothing);
    await tester.tap(find.text('Rating 4.0+'));
    await tester.pumpAndSettle();
    expect(find.text('Noodle Bar'), findsNothing);
    expect(find.text('Bite Hut'), findsWidgets);
    await tester.tap(find.text('Rating 4.0+'));
    await tester.pumpAndSettle();
    expect(find.text('Noodle Bar'), findsWidgets);
  });

  testWidgets('banner shows the stored restaurant name and no null text', (
    tester,
  ) async {
    await host(
      tester,
      banners: const [
        HomeBanner(
          id: 'b1',
          title: '20% off on sandwiches',
          subtitle: 'bite hut',
          imageUrl: '',
          restaurantId: '1',
          ctaText: '',
        ),
        HomeBanner(
          id: 'b2',
          title: '',
          subtitle: 'Noodle Bar',
          imageUrl: '',
          restaurantId: '2',
          ctaText: '',
        ),
      ],
    );
    expect(find.text('20% off on sandwiches'), findsOneWidget);
    expect(find.text('at Bite Hut · Cafe'), findsOneWidget);
    expect(find.text('OFFER'), findsOneWidget);
    expect(find.text('Order now'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('cart badge matches the cart and hides when empty', (
    tester,
  ) async {
    await host(tester, cartCount: 2);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('no cart badge when the cart is empty', (tester) async {
    await host(tester);
    expect(find.bySemanticsLabel('Cart'), findsOneWidget);
  });

  testWidgets('Food/Grocery pill stays in the bottom nav and toggles mode', (
    tester,
  ) async {
    var toggles = 0;
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          bottomNavigationBar: FloatingHomeNavigation(
            mode: DeliveryMode.food,
            index: 1,
            hasActiveGroup: false,
            onChanged: (_) {},
            onModeToggle: () => toggles++,
          ),
        ),
      ),
    );
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('FoodShare'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('Switch from')));
    expect(toggles, 1);
  });

  testWidgets('header no longer carries a service toggle', (tester) async {
    await host(tester);
    expect(find.text('Grocery'), findsNothing);
  });

  testWidgets('empty feed offers Change location', (tester) async {
    await host(tester, restaurants: const []);
    expect(find.text('Change location'), findsOneWidget);
  });

  testWidgets('no overflow on a 360x640 phone with long names', (tester) async {
    await host(
      tester,
      size: const Size(360, 640),
      restaurants: [
        _r(
          '9',
          'The Extraordinarily Long Restaurant Name Kitchen & Bakery House',
          costForTwo: 450,
          cuisine: 'North Indian, Chinese, Continental, Italian, Mexican',
        ),
      ],
    );
    expect(tester.takeException(), isNull);
  });

  test('home surfaces keep dark text on the brand colour', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (la > lb ? la + 0.05 : lb + 0.05) /
          (la > lb ? lb + 0.05 : la + 0.05);
    }

    expect(contrast(AppColors.primary, AppColors.ink), greaterThan(7));
    expect(contrast(AppColors.deepTeal, AppColors.pageTint), greaterThan(4.5));
    expect(contrast(AppColors.onInkMuted, AppColors.ink), greaterThan(7));
    expect(contrast(Colors.white, AppColors.ink), greaterThan(7));
  });
}
