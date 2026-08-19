import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/app_models.dart';
import '../../app_state/providers/app_controller.dart';

class CartState {
  const CartState({
    this.foodCart = const {},
    this.groceryCart = const {},
    this.knownItems = const {},
    this.cartRestaurantId = '',
  });

  final Map<String, int> foodCart;
  final Map<String, int> groceryCart;
  final Map<String, CartSelection> knownItems;
  final String cartRestaurantId;

  CartState copyWith({
    Map<String, int>? foodCart,
    Map<String, int>? groceryCart,
    Map<String, CartSelection>? knownItems,
    String? cartRestaurantId,
  }) {
    return CartState(
      foodCart: foodCart ?? this.foodCart,
      groceryCart: groceryCart ?? this.groceryCart,
      knownItems: knownItems ?? this.knownItems,
      cartRestaurantId: cartRestaurantId ?? this.cartRestaurantId,
    );
  }

  int quantityForItem(String itemId) {
    var total = 0;
    foodCart.forEach((lineId, quantity) {
      if (knownItems[lineId]?.item.id == itemId) total += quantity;
    });
    groceryCart.forEach((lineId, quantity) {
      if (knownItems[lineId]?.item.id == itemId) total += quantity;
    });
    return total;
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
    final activeCart = mode == DeliveryMode.food ? state.foodCart : state.groceryCart;
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
    final lineId = selection.lineId;
    final next = Map<String, int>.from(
      food ? state.foodCart : state.groceryCart,
    );
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
      cartRestaurantId: (restaurantId != null && restaurantId.isNotEmpty)
          ? restaurantId
          : state.cartRestaurantId,
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
    final activeCart = mode == DeliveryMode.food ? state.foodCart : state.groceryCart;
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
        ? state.copyWith(foodCart: const {})
        : state.copyWith(groceryCart: const {});
  }
}

final cartControllerProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);

final cartLinesProvider = Provider<List<CartLine>>((ref) {
  final appState = ref.watch(appControllerProvider);
  final cartState = ref.watch(cartControllerProvider);
  
  final cart = appState.mode == DeliveryMode.food ? cartState.foodCart : cartState.groceryCart;
  
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
  return ref.watch(cartLinesProvider).fold(0, (sum, line) => sum + line.total);
});

final cartCountProvider = Provider<int>((ref) {
  return ref
      .watch(cartLinesProvider)
      .fold(0, (sum, line) => sum + line.quantity);
});
