enum CatalogItemType { food, grocery }

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.rating,
    required this.deliveryMinutes,
    required this.distanceKm,
    required this.deliveryFee,
    required this.discount,
    required this.imageUrl,
    this.foodShare = false,
  });

  final String id;
  final String name;
  final String cuisine;
  final double rating;
  final int deliveryMinutes;
  final double distanceKm;
  final int deliveryFee;
  final int discount;
  final String imageUrl;
  final bool foodShare;
}

/// A selectable size/option on a menu item (for example Regular vs Large).
///
/// `price` is the absolute price of the item at this variant, matching how
/// restaurant-service returns menu variants.
class MenuVariant {
  const MenuVariant({
    required this.id,
    required this.name,
    required this.price,
    this.isAvailable = true,
  });

  final String id;
  final String name;
  final int price;
  final bool isAvailable;
}

/// An optional extra that can be added to a menu item.
class MenuAddon {
  const MenuAddon({
    required this.id,
    required this.name,
    required this.price,
    this.isAvailable = true,
  });

  final String id;
  final String name;
  final int price;
  final bool isAvailable;
}

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.store,
    required this.price,
    required this.originalPrice,
    required this.imageUrl,
    required this.type,
    this.isVeg = true,
    this.sharedDiscount = 0,
    this.variants = const [],
    this.addons = const [],
  });

  final String id;
  final String name;
  final String subtitle;
  final String store;
  final int price;
  final int originalPrice;
  final String imageUrl;
  final CatalogItemType type;
  final bool isVeg;
  final int sharedDiscount;

  /// Empty when the item has no size options.
  final List<MenuVariant> variants;

  /// Empty when the item takes no extras.
  final List<MenuAddon> addons;

  bool get needsCustomisation => variants.isNotEmpty || addons.isNotEmpty;

  int get discountPercent => originalPrice <= price
      ? 0
      : ((originalPrice - price) * 100 ~/ originalPrice);
}

/// Grouped menu section returned by [CatalogRepository.fetchRestaurantMenu].
class MenuSection {
  const MenuSection({
    required this.id,
    required this.name,
    required this.items,
  });

  final String id;
  final String name;
  final List<CatalogItem> items;
}

/// One entry in the home category rail.
class HomeCategory {
  const HomeCategory({
    required this.key,
    required this.name,
    required this.imageUrl,
    required this.icon,
    required this.itemCount,
  });

  final String key;
  final String name;

  /// Artwork URL. May be empty — fall back to [icon].
  final String imageUrl;

  /// Icon *name* (not a URL), used when [imageUrl] is empty.
  final String icon;
  final int itemCount;
}

/// Payload of `GET /api/home`.
class HomeFeed {
  const HomeFeed({required this.restaurants, required this.featuredItems});

  final List<Restaurant> restaurants;
  final List<CatalogItem> featuredItems;
}
