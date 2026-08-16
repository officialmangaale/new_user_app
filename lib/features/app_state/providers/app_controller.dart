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
    this.cartRestaurantId = '',
    this.joinedGroupIds = const {},
    this.activeHomeTab = 1,
  });

  final DeliveryMode mode;
  final bool authenticated;
  final bool sessionLoaded;
  final Map<String, int> foodCart;
  final Map<String, int> groceryCart;

  /// Configurations the customer has added, keyed by [CartSelection.lineId].
  ///
  /// Menu items arrive per screen from restaurant-service, so there is no
  /// global catalog to look an id up in. Keying by configuration rather than
  /// item id is what lets "Large + extra cheese" and "Regular" coexist.
  final Map<String, CartSelection> knownItems;

  /// Restaurant the current cart belongs to. Required by order placement.
  final String cartRestaurantId;
  final Set<String> joinedGroupIds;
  final int activeHomeTab;

  Map<String, int> get cart =>
      mode == DeliveryMode.food ? foodCart : groceryCart;

  /// Total quantity of an item across every configuration of it, so a menu row
  /// shows "2" when the customer added a Regular and a Large.
  ///
  /// Pure so it is safe to call inside a Riverpod `select`.
  int quantityForItem(String itemId) {
    var total = 0;
    cart.forEach((lineId, quantity) {
      if (knownItems[lineId]?.item.id == itemId) total += quantity;
    });
    return total;
  }

  AppState copyWith({
    DeliveryMode? mode,
    bool? authenticated,
    bool? sessionLoaded,
    Map<String, int>? foodCart,
    Map<String, int>? groceryCart,
    Map<String, CartSelection>? knownItems,
    String? cartRestaurantId,
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
      cartRestaurantId: cartRestaurantId ?? this.cartRestaurantId,
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

  /// Adds one unit of [item] with no options chosen.
  ///
  /// Only correct for items with no variants or addons — callers must route
  /// customisable items through the customise sheet and use [addSelection], or
  /// the customer's choices are silently dropped. See [addOrRepeat].
  void addItem(CatalogItem item, {String? restaurantId}) {
    addSelection(CartSelection(item: item), restaurantId: restaurantId);
  }

  /// Repeats the most recent configuration of [itemId] if one exists.
  ///
  /// Lets the "+" on a menu row increment an already-customised line instead of
  /// reopening the sheet. Returns false when the item is not in the cart yet.
  bool addOrRepeat(String itemId, {String? restaurantId}) {
    CartSelection? latest;
    for (final lineId in state.cart.keys) {
      final selection = state.knownItems[lineId];
      if (selection?.item.id == itemId) latest = selection;
    }
    if (latest == null) return false;
    addSelection(latest, restaurantId: restaurantId);
    return true;
  }

  /// Adds one unit of a fully configured [selection].
  ///
  /// [restaurantId] is recorded because order placement requires it and a
  /// [CatalogItem] only carries the store's display name.
  void addSelection(CartSelection selection, {String? restaurantId}) {
    final food = selection.item.type == CatalogItemType.food;
    final lineId = selection.lineId;
    final next = Map<String, int>.from(
      food ? state.foodCart : state.groceryCart,
    );
    next[lineId] = (next[lineId] ?? 0) + 1;
    state = state.copyWith(
      mode: food ? DeliveryMode.food : DeliveryMode.grocery,
      foodCart: food ? next : null,
      groceryCart: food ? null : next,
      knownItems: {...state.knownItems, lineId: selection},
      cartRestaurantId: (restaurantId != null && restaurantId.isNotEmpty)
          ? restaurantId
          : null,
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
      mode: food ? DeliveryMode.food : DeliveryMode.grocery,
      foodCart: food ? next : null,
      groceryCart: food ? null : next,
    );
  }

  void removeLine(String lineId) {
    final food = _isFood(lineId);
    final next = Map<String, int>.from(
      food ? state.foodCart : state.groceryCart,
    )..remove(lineId);
    state = state.copyWith(
      mode: food ? DeliveryMode.food : DeliveryMode.grocery,
      foodCart: food ? next : null,
      groceryCart: food ? null : next,
    );
  }

  /// Removes one unit of [itemId] from the most recently added configuration.
  ///
  /// Menu rows only know the item, not which configuration to decrement, so the
  /// newest matching line is used.
  void removeItemById(String itemId) {
    String? target;
    for (final lineId in state.cart.keys) {
      if (state.knownItems[lineId]?.item.id == itemId) target = lineId;
    }
    if (target != null) removeItem(target);
  }

  /// Which basket a line belongs to. Falls back to the active mode when the
  /// line is not remembered, which keeps removal safe after a restart.
  bool _isFood(String lineId) {
    final selection = state.knownItems[lineId];
    if (selection != null) {
      return selection.item.type == CatalogItemType.food;
    }
    if (state.foodCart.containsKey(lineId)) return true;
    if (state.groceryCart.containsKey(lineId)) return false;
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
        final selection = state.knownItems[entry.key];
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
