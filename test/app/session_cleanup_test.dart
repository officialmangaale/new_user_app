import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/features/account/providers/engagement_providers.dart';
import 'package:turquoise_delivery/features/app_state/providers/app_controller.dart';
import 'package:turquoise_delivery/features/orders/domain/entities/order_entities.dart';
import 'package:turquoise_delivery/features/orders/providers/orders_providers.dart';
import 'package:turquoise_delivery/shared/repositories/account_repository.dart';
import 'package:turquoise_delivery/shared/repositories/engagement_repository.dart';

/// On a shared device the next person to sign in must not see the previous
/// customer's data.
///
/// Each test serves "user A" first, signs out, then serves "user B" from the
/// same override. If the cache survived the sign-out, the provider would still
/// report user A — which is exactly the bug.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({
        'auth_token': 'user-a-token',
        'guest_authenticated': true,
      }));

  CustomerProfile profileFor(String name) =>
      CustomerProfile(id: name, name: name, phone: '9990000001', email: '$name@example.com');

  test('logout clears the profile so the next customer sees their own', () async {
    var serving = 'User A';
    final container = ProviderContainer(overrides: [
      profileProvider.overrideWith((ref) async => profileFor(serving)),
    ]);
    addTearDown(container.dispose);

    expect((await container.read(profileProvider.future)).name, 'User A');

    await container.read(appControllerProvider.notifier).logout();
    serving = 'User B';

    expect(
      (await container.read(profileProvider.future)).name,
      'User B',
      reason: "the previous customer's name and phone must not survive logout",
    );
  });

  test('logout clears the wallet balance', () async {
    var balance = 4200.0;
    final container = ProviderContainer(overrides: [
      walletProvider.overrideWith((ref) async => WalletStatement(
            balance: balance, currency: 'INR', status: 'active', transactions: const [],
          )),
    ]);
    addTearDown(container.dispose);

    expect((await container.read(walletProvider.future)).balance, 4200.0);

    await container.read(appControllerProvider.notifier).logout();
    balance = 0;

    expect(
      (await container.read(walletProvider.future)).balance,
      0,
      reason: "the previous customer's wallet balance must not survive logout",
    );
  });

  test('logout clears order history', () async {
    var orders = <DeliveryOrder>[_order('A-1001')];
    final container = ProviderContainer(overrides: [
      ordersProvider.overrideWith((ref) async => orders),
    ]);
    addTearDown(container.dispose);

    expect((await container.read(ordersProvider.future)).single.id, 'A-1001');

    await container.read(appControllerProvider.notifier).logout();
    orders = <DeliveryOrder>[];

    expect(
      await container.read(ordersProvider.future),
      isEmpty,
      reason: "the previous customer's order history must not survive logout",
    );
  });

  // A rejected token is a forced logout and must clear the same data.
  test('an expired session clears delivery addresses', () async {
    var addresses = <CustomerAddress>[
      const CustomerAddress(
        id: 'a1', label: 'Home', addressLine1: '12 Example Street',
        area: 'Example Area', city: 'Delhi', pincode: '110001',
        isDefault: true,
      ),
    ];
    final container = ProviderContainer(overrides: [
      addressesProvider.overrideWith((ref) async => addresses),
    ]);
    addTearDown(container.dispose);

    await container.read(appControllerProvider.notifier).completeLogin(
          authToken: 'user-a-token', userId: 'a', name: 'User A', phone: '9990000001',
        );
    expect((await container.read(addressesProvider.future)).length, 1);

    await container.read(appControllerProvider.notifier).handleSessionExpired();
    addresses = <CustomerAddress>[];

    expect(
      (await container.read(addressesProvider.future)),
      isEmpty,
      reason: 'a rejected token must not leave delivery addresses readable',
    );
    expect(container.read(appControllerProvider).authenticated, isFalse);
  });

}

DeliveryOrder _order(String id) => DeliveryOrder(
  id: id,
  store: 'Example Kitchen',
  date: '2026-09-10',
  itemCount: 2,
  total: 42000,
  status: OrderStatus.completed,
  savings: 0,
);
