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
    this.storeId = '',
    this.categoryId = '',
    this.isVeg = true,
    this.sharedDiscount = 0,
    this.variants = const [],
    this.addons = const [],
    this.isAvailable = true,
    this.hasVariants = false,
    this.hasAddons = false,
  });

  final String id;
  final String name;
  final String subtitle;
  final String store;
  final int price;
  final int originalPrice;
  final String imageUrl;
  final CatalogItemType type;
  final String storeId;
  final String categoryId;
  final bool isVeg;
  final int sharedDiscount;

  /// Empty when the item has no size options.
  final List<MenuVariant> variants;

  /// Empty when the item takes no extras.
  final List<MenuAddon> addons;

  /// False when the kitchen has switched the item off. Ordering must be
  /// blocked rather than failing at checkout.
  final bool isAvailable;

  /// The backend's `has_variants` / `has_addons` flags.
  ///
  /// List endpoints are inconsistent about shipping the option arrays —
  /// `/customer-web/search` never does, and some `/customer-web/categories/…`
  /// rows omit them too — while still setting these flags. They are the
  /// reliable signal that a choice is required; [variants] and [addons] are
  /// only the payload when the endpoint happened to include it.
  final bool hasVariants;
  final bool hasAddons;

  /// True when the customer must pick something before this can be ordered.
  bool get needsCustomisation =>
      variants.isNotEmpty || addons.isNotEmpty || hasVariants || hasAddons;

  /// True when a choice is required but the options were not delivered with
  /// this record, so the full item has to be fetched before adding to cart.
  bool get needsOptionHydration =>
      (hasVariants && variants.isEmpty) || (hasAddons && addons.isEmpty);

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

/// A merchandising banner from the `banners` array of `GET /api/home`.
class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.restaurantId,
    required this.ctaText,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;

  /// The restaurant the banner opens. Empty when the banner is informational.
  final String restaurantId;
  final String ctaText;
}

/// Payload of `GET /api/home`.
class HomeFeed {
  const HomeFeed({
    required this.restaurants,
    required this.featuredItems,
    this.banners = const [],
  });

  final List<Restaurant> restaurants;
  final List<CatalogItem> featuredItems;

  /// Server-curated banners. Previously dropped on the floor, which left the
  /// home carousel dependent on a `discount` field the discovery endpoints
  /// never return.
  final List<HomeBanner> banners;
}

/// Mixed global search payload from `/customer-web/search`.
class CatalogSearchResults {
  const CatalogSearchResults({
    required this.items,
    required this.restaurants,
  });

  final List<CatalogItem> items;
  final List<Restaurant> restaurants;

  bool get isEmpty => items.isEmpty && restaurants.isEmpty;
}
