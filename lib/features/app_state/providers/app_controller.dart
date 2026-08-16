import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/auth_storage.dart';
import '../../../core/storage/guest_storage.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/repositories/auth_repository.dart';

class AppState {
  const AppState({
    this.mode = DeliveryMode.food,
    this.authenticated = false,
    this.sessionLoaded = false,
    this.foodCart = const {},
    this.groceryCart = const {},
    this.knownItems = const {},
    this.joinedGroupIds = const {},
    this.activeHomeTab = 1,
  });

  final DeliveryMode mode;
  final bool authenticated;
  final bool sessionLoaded;
  final Map<String, int> foodCart;
  final Map<String, int> groceryCart;

  /// Items the customer has actually added, keyed by id.
  ///
  /// Menu items now arrive from restaurant-service per screen, so there is no
  /// global catalog to look an id up in the way `MockData.itemById` allowed.
  /// The cart therefore remembers the item it was given.
  final Map<String, CatalogItem> knownItems;
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
    Map<String, CatalogItem>? knownItems,
    Set<String>? joinedGroupIds,
    int? activeHomeTab,
  }) {
    return AppState(
      mode: mode ?? this.mode,
      authenticated: authenticated ?? this.authenticated,
      sessionLoaded: sessionLoaded ?? this.sessionLoaded,
      foodCart: foodCart ?? this.foodCart,
      groceryCart: groceryCart ?? this.groceryCart,
      knownItems: knownItems ?? this.knownItems,
      joinedGroupIds: joinedGroupIds ?? this.joinedGroupIds,
      activeHomeTab: activeHomeTab ?? this.activeHomeTab,
    );
  }
}

class AppController extends Notifier<AppState> {
  final GuestStorage _storage = GuestStorage();
  final AuthStorage _authStorage = AuthStorage();

  @override
  AppState build() {
    unawaited(_hydrate());
    return const AppState();
  }

  /// A stored bearer token is the source of truth for "signed in". The legacy
  /// boolean flag is still honoured so an existing install is not signed out
  /// by this change.
  Future<void> _hydrate() async {
    final token = await _authStorage.readToken();
    final authenticated =
        token != null || await _storage.isAuthenticated();
    state = state.copyWith(authenticated: authenticated, sessionLoaded: true);
  }

  void setMode(DeliveryMode mode) {
    state = state.copyWith(mode: mode, activeHomeTab: 1);
  }

  void setHomeTab(int index) => state = state.copyWith(activeHomeTab: index);

  /// Persists a verified customer session from user-service.
  Future<void> completeLogin(AuthSession session) async {
    await _authStorage.saveSession(
      token: session.authToken,
      userId: session.user.userId,
      name: session.user.name,
      phone: session.user.phone,
    );
    await _storage.setAuthenticated(true);
    await _storage.setOnboardingSeen();
    state = state.copyWith(authenticated: true, sessionLoaded: true);
  }

  Future<void> logout() async {
    await _authStorage.clear();
    await _storage.setAuthenticated(false);
    state = state.copyWith(
      authenticated: false,
      foodCart: const {},
      groceryCart: const {},
    );
  }

  /// Invoked when the backend rejects the stored token (HTTP 401). The token
  /// has already been cleared; this only reflects it in app state.
  void handleSessionExpired() {
    if (!state.authenticated) return;
    state = state.copyWith(authenticated: false);
  }

  /// Adds one unit of [item], remembering the item so the cart can render it
  /// without a global catalog lookup.
  void addItem(CatalogItem item) {
    final food = item.type == CatalogItemType.food;
    final next = Map<String, int>.from(
      food ? state.foodCart : state.groceryCart,
    );
    next[item.id] = (next[item.id] ?? 0) + 1;
    state = state.copyWith(
      mode: food ? DeliveryMode.food : DeliveryMode.grocery,
      foodCart: food ? next : null,
      groceryCart: food ? null : next,
      knownItems: {...state.knownItems, item.id: item},
    );
  }

  void removeItem(String itemId) {
    final food = _isFood(itemId);
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
    final food = _isFood(itemId);
    final next = Map<String, int>.from(
      food ? state.foodCart : state.groceryCart,
    )..remove(itemId);
    state = state.copyWith(
      mode: food ? DeliveryMode.food : DeliveryMode.grocery,
      foodCart: food ? next : null,
      groceryCart: food ? null : next,
    );
  }

  /// Which basket an id belongs to. Falls back to the active mode when the
  /// item is not remembered, which keeps removal safe after a restart.
  bool _isFood(String itemId) {
    final item = state.knownItems[itemId];
    if (item != null) return item.type == CatalogItemType.food;
    if (state.foodCart.containsKey(itemId)) return true;
    if (state.groceryCart.containsKey(itemId)) return false;
    return state.mode == DeliveryMode.food;
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
  final state = ref.watch(appControllerProvider);
  return state.cart.entries
      .map((entry) {
        final item = state.knownItems[entry.key];
        return item == null
            ? null
            : CartLine(item: item, quantity: entry.value);
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
