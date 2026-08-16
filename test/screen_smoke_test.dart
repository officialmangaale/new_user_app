import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/app/theme/app_theme.dart';
import 'package:turquoise_delivery/features/account/presentation/profile_screen.dart';
import 'package:turquoise_delivery/features/account/presentation/wallet_referral_screens.dart';
import 'package:turquoise_delivery/features/cart/presentation/cart_screens.dart';
import 'package:turquoise_delivery/features/catalog/presentation/catalog_detail_screens.dart';
import 'package:turquoise_delivery/features/home/presentation/home_screen.dart';
import 'package:turquoise_delivery/features/notifications/presentation/notifications_screen.dart';
import 'package:turquoise_delivery/features/orders/presentation/orders_screen.dart';
import 'package:turquoise_delivery/features/shared_orders/presentation/shared_order_screens.dart';
import 'package:turquoise_delivery/features/tracking/presentation/tracking_screen.dart';
import 'package:turquoise_delivery/shared/mock_data/mock_data.dart';
import 'package:turquoise_delivery/shared/models/app_models.dart';
import 'package:turquoise_delivery/shared/widgets/delivery_cards.dart';
import 'package:turquoise_delivery/features/app_state/providers/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('major screens render on a small phone without exceptions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final screens = <Widget>[
      const HomeShellScreen(),
      const SharedOrderListingScreen(mode: DeliveryMode.food),
      const SharedOrderDetailsScreen(groupId: 's1'),
      const RestaurantDetailsScreen(restaurantId: 'r1'),
      const FoodItemDetailsScreen(itemId: 'f1'),
      const GroceryProductDetailsScreen(itemId: 'g1'),
      const CartScreen(),
      const OrdersScreen(),
      const TrackingScreen(orderId: 'TQ240761'),
      const WalletScreen(),
      const ReferralScreen(),
      const ProfileScreen(),
      const NotificationsScreen(),
    ];

    for (final screen in screens) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(theme: AppTheme.light, home: screen),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      final exception = tester.takeException();
      if (exception is FlutterError) {
        debugPrint(exception.toStringDeep());
      }
      expect(exception, isNull, reason: '${screen.runtimeType} failed');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('restaurant cart summary stays compact after adding an item', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(appControllerProvider.notifier)
        .addItem(MockData.itemById('f1'));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RestaurantDetailsScreen(restaurantId: 'r1'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    final cartBar = find.byType(CartSummaryBar);
    expect(cartBar, findsOneWidget);
    expect(tester.getSize(cartBar).height, lessThanOrEqualTo(72));
    expect(tester.takeException(), isNull);
  });
}
