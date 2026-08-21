import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/app_models.dart';
import '../../app_state/providers/app_controller.dart';

class CartState {
  const CartState({
    this.foodCart = const {},
    this.groceryCart = const {},
    this.knownItems = const {},
    this.cartRestaurantId = '',
    this.cartGroceryMerchantId = '',
  });

  final Map<String, int> foodCart;
  final Map<String, int> groceryCart;
  final Map<String, CartSelection> knownItems;
  final String cartRestaurantId;
  final String cartGroceryMerchantId;

  CartState copyWith({
    Map<String, int>? foodCart,
    Map<String, int>? groceryCart,
    Map<String, CartSelection>? knownItems,
    String? cartRestaurantId,
    String? cartGroceryMerchantId,
  }) {
    return CartState(
      foodCart: foodCart ?? this.foodCart,
      groceryCart: groceryCart ?? this.groceryCart,
      knownItems: knownItems ?? this.knownItems,
      cartRestaurantId: cartRestaurantId ?? this.cartRestaurantId,
      cartGroceryMerchantId:
          cartGroceryMerchantId ?? this.cartGroceryMerchantId,
    );
  }

  int quantityForItem(
    String itemId, {
    CatalogItemType? type,
    String? storeId,
  }) {
    var total = 0;
    foodCart.forEach((lineId, quantity) {
      final item = knownItems[lineId]?.item;
      if (_matchesQuantityItem(item, itemId, type, storeId)) {
        total += quantity;
      }
    });
    groceryCart.forEach((lineId, quantity) {
      final item = knownItems[lineId]?.item;
      if (_matchesQuantityItem(item, itemId, type, storeId)) {
        total += quantity;
      }
    });
    return total;
  }

  bool _matchesQuantityItem(
    CatalogItem? item,
    String itemId,
    CatalogItemType? type,
    String? storeId,
  ) {
    if (item == null || item.id != itemId) return false;
    if (type != null && item.type != type) return false;
    if (storeId != null && storeId.isNotEmpty && item.storeId != storeId) {
      return false;
    }
    return true;
  }
}

class CartController extends Notifier<CartState> {
  @override
  CartState build() {
    return const CartState();
  }

  void addItem(CatalogItem item, {String? restaurantId}) {
    addSelection(CartSelection(item: item), restaurantId: restaurantId);
  }

  bool addOrRepeat(String itemId, {String? restaurantId}) {
    final mode = ref.read(appControllerProvider).mode;
    final activeCart =
        mode == DeliveryMode.food ? state.foodCart : state.groceryCart;
    CartSelection? latest;
    for (final lineId in activeCart.keys) {
      final selection = state.knownItems[lineId];
      if (selection?.item.id == itemId) latest = selection;
    }
    if (latest == null) return false;
    addSelection(latest, restaurantId: restaurantId);
    return true;
  }

  void addSelection(CartSelection selection, {String? restaurantId}) {
    final food = selection.item.type == CatalogItemType.food;
    final storeId = restaurantId ?? selection.item.storeId;
    final lineId = selection.lineId;
    final replacingGroceryStore = !food &&
        storeId.isNotEmpty &&
        state.cartGroceryMerchantId.isNotEmpty &&
        state.cartGroceryMerchantId != storeId;
    final activeSource = replacingGroceryStore
        ? const <String, int>{}
        : (food ? state.foodCart : state.groceryCart);
    final next = Map<String, int>.from(activeSource);
    next[lineId] = (next[lineId] ?? 0) + 1;
    
    // Automatically switch app mode if adding an item of a different type
    final appMode = ref.read(appControllerProvider).mode;
    final itemMode = food ? DeliveryMode.food : DeliveryMode.grocery;
    if (appMode != itemMode) {
      ref.read(appControllerProvider.notifier).setMode(itemMode);
    }
    
    state = state.copyWith(
      foodCart: food ? next : state.foodCart,
      groceryCart: food ? state.groceryCart : next,
      knownItems: {...state.knownItems, lineId: selection},
      cartRestaurantId: food && storeId.isNotEmpty
          ? storeId
          : state.cartRestaurantId,
      cartGroceryMerchantId: !food && storeId.isNotEmpty
          ? storeId
          : state.cartGroceryMerchantId,
    );
  }

  void removeItem(String lineId) {
    final food = _isFood(lineId);
    final next = Map<String, int>.from(
      food ? state.foodCart : state.groceryCart,
    );
    final quantity = next[lineId] ?? 0;
    if (quantity <= 1) {
      next.remove(lineId);
    } else {
      next[lineId] = quantity - 1;
    }
    state = state.copyWith(
      foodCart: food ? next : state.foodCart,
      groceryCart: food ? state.groceryCart : next,
    );
  }

  void removeLine(String lineId) {
    final food = _isFood(lineId);
    final next = Map<String, int>.from(
      food ? state.foodCart : state.groceryCart,
    )..remove(lineId);
    state = state.copyWith(
      foodCart: food ? next : state.foodCart,
      groceryCart: food ? state.groceryCart : next,
    );
  }

  void removeItemById(String itemId) {
    final mode = ref.read(appControllerProvider).mode;
    final activeCart =
        mode == DeliveryMode.food ? state.foodCart : state.groceryCart;
    String? target;
    for (final lineId in activeCart.keys) {
      if (state.knownItems[lineId]?.item.id == itemId) target = lineId;
    }
    if (target != null) removeItem(target);
  }

  bool _isFood(String lineId) {
    final selection = state.knownItems[lineId];
    if (selection != null) {
      return selection.item.type == CatalogItemType.food;
    }
    if (state.foodCart.containsKey(lineId)) return true;
    if (state.groceryCart.containsKey(lineId)) return false;
    return ref.read(appControllerProvider).mode == DeliveryMode.food;
  }

  void clearCart() {
    final mode = ref.read(appControllerProvider).mode;
    state = mode == DeliveryMode.food
        ? state.copyWith(foodCart: const {}, cartRestaurantId: '')
        : state.copyWith(groceryCart: const {}, cartGroceryMerchantId: '');
  }
}

final cartControllerProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);

final cartLinesProvider = Provider<List<CartLine>>((ref) {
  final appState = ref.watch(appControllerProvider);
  final cartState = ref.watch(cartControllerProvider);
  
  final cart = appState.mode == DeliveryMode.food
      ? cartState.foodCart
      : cartState.groceryCart;
  
  return cart.entries
      .map((entry) {
        final selection = cartState.knownItems[entry.key];
        return selection == null
            ? null
            : CartLine(selection: selection, quantity: entry.value);
      })
      .whereType<CartLine>()
      .toList(growable: false);
});

final cartTotalProvider = Provider<int>((ref) {
  return ref.watch(cartLinesProvider).fold(
        0,
        (sum, line) => sum + line.total,
      );
});

final cartCountProvider = Provider<int>((ref) {
  return ref
      .watch(cartLinesProvider)
      .fold(0, (sum, line) => sum + line.quantity);
});
