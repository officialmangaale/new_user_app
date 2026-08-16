import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/profile_screen.dart';
import '../../features/account/presentation/wallet_referral_screens.dart';
import '../../features/authentication/presentation/auth_screens.dart';
import '../../features/cart/presentation/cart_screens.dart';
import '../../features/catalog/presentation/catalog_detail_screens.dart';
import '../../features/catalog/presentation/category_items_screen.dart';
import '../../features/catalog/presentation/search_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/shared_orders/presentation/shared_order_screens.dart';
import '../../features/tracking/presentation/tracking_screen.dart';
import '../../shared/models/app_models.dart';
import '../theme/app_colors.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(
        path: '/login',
        builder: (_, state) =>
            LoginScreen(returnTo: state.uri.queryParameters['returnTo']),
      ),
      GoRoute(
        path: '/otp',
        builder: (_, state) => OtpScreen(
          returnTo: state.uri.queryParameters['returnTo'] ?? '/setup',
          phone: state.uri.queryParameters['phone'] ?? '',
        ),
      ),
      GoRoute(path: '/setup', builder: (_, _) => const ProfileSetupScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomeShellScreen()),
      GoRoute(
        path: '/shared-list',
        builder: (_, state) => SharedOrderListingScreen(
          mode: _modeFrom(state.uri.queryParameters['mode']),
        ),
      ),
      GoRoute(
        path: '/shared/:id',
        builder: (_, state) =>
            SharedOrderDetailsScreen(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/create-shared',
        builder: (_, state) => CreateSharedOrderScreen(
          mode: _modeFrom(state.uri.queryParameters['mode']),
        ),
      ),
      GoRoute(
        path: '/waiting-room/:id',
        builder: (_, state) =>
            WaitingRoomScreen(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/invite/:id',
        builder: (_, state) =>
            InviteFriendsScreen(groupId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/restaurant/:id',
        builder: (_, state) =>
            RestaurantDetailsScreen(restaurantId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/food-item/:id',
        builder: (_, state) =>
            FoodItemDetailsScreen(itemId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (_, state) =>
            GroceryProductDetailsScreen(itemId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/search',
        builder: (_, state) =>
            SearchScreen(initialQuery: state.uri.queryParameters['q'] ?? ''),
      ),
      GoRoute(
        path: '/category/:key',
        builder: (_, state) => CategoryItemsScreen(
          categoryKey: Uri.decodeComponent(state.pathParameters['key']!),
          title: state.uri.queryParameters['title'] ?? '',
        ),
      ),
      GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
      GoRoute(
        path: '/checkout',
        builder: (_, state) => CheckoutScreen(
          shared: state.uri.queryParameters['shared'] != 'false',
        ),
      ),
      GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen()),
      GoRoute(
        path: '/tracking/:id',
        builder: (_, state) =>
            TrackingScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/wallet', builder: (_, _) => const WalletScreen()),
      GoRoute(path: '/referral', builder: (_, _) => const ReferralScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: '/info/:title',
        builder: (_, state) => InformationScreen(
          title: Uri.decodeComponent(state.pathParameters['title']!),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page unavailable')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.explore_off_outlined,
                size: 58,
                color: AppColors.dark,
              ),
              const SizedBox(height: 16),
              Text(
                'We couldn’t open that page',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(state.error?.toString() ?? 'The route is not available.'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => GoRouter.of(context).go('/home'),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});

DeliveryMode _modeFrom(String? value) =>
    value == 'grocery' ? DeliveryMode.grocery : DeliveryMode.food;
