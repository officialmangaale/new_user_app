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
    this.logoUrl = '',
    this.coverUrl = '',
    this.isOpen,
    this.opensAt = '',
    this.costForTwo = 0,
    this.area = '',
    this.offerText = '',
  });

  final String id;
  final String name;
  final String cuisine;
  final double rating;
  final int deliveryMinutes;
  /// Distance from the selected delivery location, or null when it could not
  /// be calculated (no delivery location yet, or the restaurant has no
  /// coordinates). Never 0 as a stand-in for "unknown".
  final double? distanceKm;
  final int deliveryFee;
  final int discount;
  final String imageUrl;
  final bool foodShare;

  /// Restaurant logo, when the API ships one separately from the cover photo.
  final String logoUrl;

  /// Cover/banner photo. Empty when the API only supplied a single image.
  final String coverUrl;

  /// `null` when the API does not say; only an explicit `false` means closed.
  final bool? isOpen;

  /// Display text for the next opening time, e.g. `11:00`. May be empty.
  final String opensAt;
  final int costForTwo;
  final String area;

  /// Offer headline such as "20% OFF up to ₹100". May be empty.
  final String offerText;

  /// Photo suited to a wide card: the cover when there is one, otherwise the
  /// legacy single image unless that image is the logo (a logo cropped to a
  /// banner looks broken). Empty when there is nothing suitable.
  String get displayCoverUrl {
    if (coverUrl.isNotEmpty) return coverUrl;
    if (imageUrl.isNotEmpty && imageUrl != logoUrl) return imageUrl;
    return '';
  }

  /// Offer text for badges, or empty when the restaurant has no offer.
  String get displayOffer {
    if (offerText.trim().isNotEmpty) return offerText.trim();
    return discount > 0 ? '$discount% OFF' : '';
  }
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
    this.isBestseller = false,
    this.storeLogoUrl = '',
    this.storeDistanceKm,
    this.storeDeliveryTime = '',
    this.storeRating,
    this.storeIsOpen,
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

  /// Merchandising flag set by the restaurant; drives the "Bestseller" tag.
  final bool isBestseller;

  // The restaurant this dish belongs to, as category/search rows describe it.
  // All optional: a row that does not say leaves them empty rather than
  // guessing, and nothing orders or prices from them.

  /// Restaurant logo, or empty.
  final String storeLogoUrl;

  /// Distance from the selected delivery location; null when unknown.
  final double? storeDistanceKm;

  /// Display text such as "25-30 min"; empty when unknown.
  final String storeDeliveryTime;

  /// Restaurant rating; null when it has none yet.
  final double? storeRating;

  /// Null when the row does not say; only an explicit false means closed.
  final bool? storeIsOpen;

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

/// One page of grocery products from every nearby shop.
class GroceryProductPage {
  const GroceryProductPage({required this.items, required this.hasMore});

  final List<CatalogItem> items;
  final bool hasMore;
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
