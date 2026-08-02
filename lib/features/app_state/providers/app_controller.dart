import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/guest_storage.dart';
import '../../../shared/mock_data/mock_data.dart';
import '../../../shared/models/app_models.dart';

class AppState {
  const AppState({
    this.mode = DeliveryMode.food,
    this.authenticated = false,
    this.sessionLoaded = false,
    this.foodCart = const {},
    this.groceryCart = const {},
    this.joinedGroupIds = const {},
    this.activeHomeTab = 1,
  });

  final DeliveryMode mode;
  final bool authenticated;
  final bool sessionLoaded;
  final Map<String, int> foodCart;
  final Map<String, int> groceryCart;
  final Set<String> joinedGroupIds;
  final int activeHomeTab;

  Map<String, int> get cart =>
      mode == DeliveryMode.food ? foodCart : groceryCart;

  AppState copyWith({
    DeliveryMode? mode,
    bool? authenticated,
    bool? sessionLoaded,
    Map<String, int>? foodCart,
    Map<String, int>? groceryCart,
    Set<String>? joinedGroupIds,
    int? activeHomeTab,
  }) {
    return AppState(
      mode: mode ?? this.mode,
      authenticated: authenticated ?? this.authenticated,
      sessionLoaded: sessionLoaded ?? this.sessionLoaded,
      foodCart: foodCart ?? this.foodCart,
      groceryCart: groceryCart ?? this.groceryCart,
      joinedGroupIds: joinedGroupIds ?? this.joinedGroupIds,
      activeHomeTab: activeHomeTab ?? this.activeHomeTab,
    );
  }
}

class AppController extends Notifier<AppState> {
  final GuestStorage _storage = GuestStorage();

  @override
  AppState build() {
    unawaited(_hydrate());
    return const AppState();
  }

  Future<void> _hydrate() async {
    final authenticated = await _storage.isAuthenticated();
    state = state.copyWith(authenticated: authenticated, sessionLoaded: true);
  }

  void setMode(DeliveryMode mode) {
    state = state.copyWith(mode: mode, activeHomeTab: 1);
  }

  void setHomeTab(int index) => state = state.copyWith(activeHomeTab: index);

  Future<void> authenticate() async {
    await _storage.setAuthenticated(true);
    await _storage.setOnboardingSeen();
    state = state.copyWith(authenticated: true, sessionLoaded: true);
  }

  Future<void> logout() async {
    await _storage.setAuthenticated(false);
    state = state.copyWith(
      authenticated: false,
      foodCart: const {},
      groceryCart: const {},
    );
  }

  void addItem(String itemId) {
    final item = MockData.itemById(itemId);
    final food = item.type == CatalogItemType.food;
    final next = Map<String, int>.from(
      food ? state.foodCart : state.groceryCart,
    );
    next[itemId] = (next[itemId] ?? 0) + 1;
    state = state.copyWith(
      mode: food ? DeliveryMode.food : DeliveryMode.grocery,
      foodCart: food ? next : null,
      groceryCart: food ? null : next,
    );
  }

  void removeItem(String itemId) {
    final item = MockData.itemById(itemId);
    final food = item.type == CatalogItemType.food;
    final next = Map<String, int>.from(
      food ? state.foodCart : state.groceryCart,
    );
    final quantity = next[itemId] ?? 0;
    if (quantity <= 1) {
      next.remove(itemId);
    } else {
      next[itemId] = quantity - 1;
    }
    state = state.copyWith(
      mode: food ? DeliveryMode.food : DeliveryMode.grocery,
      foodCart: food ? next : null,
      groceryCart: food ? null : next,
    );
  }

  void removeLine(String itemId) {
    final item = MockData.itemById(itemId);
    final food = item.type == CatalogItemType.food;
    final next = Map<String, int>.from(
      food ? state.foodCart : state.groceryCart,
    )..remove(itemId);
    state = state.copyWith(
      mode: food ? DeliveryMode.food : DeliveryMode.grocery,
      foodCart: food ? next : null,
      groceryCart: food ? null : next,
    );
  }

  void clearCart() {
    state = state.mode == DeliveryMode.food
        ? state.copyWith(foodCart: const {})
        : state.copyWith(groceryCart: const {});
  }

  void joinGroup(String id) {
    state = state.copyWith(joinedGroupIds: {...state.joinedGroupIds, id});
  }
}

final appControllerProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);

final cartLinesProvider = Provider<List<CartLine>>((ref) {
  final cart = ref.watch(appControllerProvider.select((state) => state.cart));
  return cart.entries
      .map(
        (entry) =>
            CartLine(item: MockData.itemById(entry.key), quantity: entry.value),
      )
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
