import 'entities/catalog_entities.dart';

/// The dishes of one category that a single restaurant serves, with what is
/// known about that restaurant.
class RestaurantDishGroup {
  const RestaurantDishGroup({
    required this.key,
    required this.name,
    required this.storeId,
    required this.items,
    this.logoUrl = '',
    this.distanceKm,
    this.deliveryTime = '',
    this.rating,
    this.isOpen,
  });

  /// Stable identity: the restaurant id, else its lower-cased name.
  final String key;
  final String name;

  /// Empty when the row did not carry a restaurant id (then it cannot be
  /// opened, but its dishes are still grouped under the name).
  final String storeId;
  final List<CatalogItem> items;
  final String logoUrl;
  final double? distanceKm;
  final String deliveryTime;
  final double? rating;

  /// Null when unknown; only an explicit false means closed.
  final bool? isOpen;

  bool get isClosed => isOpen == false;
}

/// Groups a flat dish list by restaurant.
///
/// Restaurants keep the order in which they first appear, so whatever ranking
/// the server applied (nearest first) is preserved. Within a restaurant the
/// dishes keep their order too. Restaurant details are taken from the first
/// dish that supplies them; nothing is invented when none does.
List<RestaurantDishGroup> groupDishesByRestaurant(List<CatalogItem> dishes) {
  final order = <String>[];
  final byKey = <String, List<CatalogItem>>{};
  for (final dish in dishes) {
    final id = dish.storeId.trim();
    final name = dish.store.trim();
    final key = id.isNotEmpty ? 'id:$id' : 'name:${name.toLowerCase()}';
    if (!byKey.containsKey(key)) order.add(key);
    byKey.putIfAbsent(key, () => <CatalogItem>[]).add(dish);
  }
  return [
    for (final key in order)
      _group(key, byKey[key]!),
  ];
}

RestaurantDishGroup _group(String key, List<CatalogItem> items) {
  T? firstOf<T>(T? Function(CatalogItem item) pick) {
    for (final item in items) {
      final value = pick(item);
      if (value != null) return value;
    }
    return null;
  }

  String firstText(String Function(CatalogItem item) pick) {
    for (final item in items) {
      final value = pick(item).trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  return RestaurantDishGroup(
    key: key,
    name: firstText((i) => i.store),
    storeId: firstText((i) => i.storeId),
    items: List.unmodifiable(items),
    logoUrl: firstText((i) => i.storeLogoUrl),
    distanceKm: firstOf((i) => i.storeDistanceKm),
    deliveryTime: firstText((i) => i.storeDeliveryTime),
    rating: firstOf((i) => i.storeRating),
    isOpen: firstOf((i) => i.storeIsOpen),
  );
}
