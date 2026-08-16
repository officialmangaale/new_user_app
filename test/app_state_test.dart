import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/features/app_state/providers/app_controller.dart';
import 'package:turquoise_delivery/shared/mock_data/mock_data.dart';
import 'package:turquoise_delivery/shared/models/app_models.dart';

void main() {
  test('food and grocery carts update independently', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(appControllerProvider.notifier);
    controller.addItem(MockData.itemById('f1'));
    controller.addItem(MockData.itemById('f1'));
    expect(container.read(cartCountProvider), 2);
    expect(container.read(cartTotalProvider), 558);

    controller.setMode(DeliveryMode.grocery);
    expect(container.read(cartCountProvider), 0);
    controller.addItem(MockData.itemById('g1'));
    expect(container.read(cartCountProvider), 1);
    expect(container.read(cartTotalProvider), 49);

    controller.setMode(DeliveryMode.food);
    expect(container.read(cartCountProvider), 2);
    controller.removeItem('f1');
    expect(container.read(cartCountProvider), 1);
    controller.removeLine('f1');
    expect(container.read(cartCountProvider), 0);

    controller.joinGroup('s1');
    expect(
      container.read(appControllerProvider).joinedGroupIds,
      contains('s1'),
    );

    await Future<void>.delayed(Duration.zero);
  });
}
