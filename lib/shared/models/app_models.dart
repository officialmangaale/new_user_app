enum DeliveryMode { food, grocery }

enum CatalogItemType { food, grocery }

enum OrderStatus { active, completed, cancelled }

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

/// One configured cart entry: an item plus the exact options chosen.
///
/// Two entries of the same item with different options are different lines, so
/// the identity is [lineId] rather than the item id.
class CartSelection {
  const CartSelection({
    required this.item,
    this.variant,
    this.addons = const [],
  });

  final CatalogItem item;
  final MenuVariant? variant;
  final List<MenuAddon> addons;

  /// Stable, order-independent identity for this configuration.
  String get lineId {
    final addonIds = addons.map((addon) => addon.id).toList()..sort();
    return [item.id, variant?.id ?? '', addonIds.join('+')].join('|');
  }

  /// Unit price: the variant replaces the base price, addons add on top.
  int get unitPrice =>
      (variant?.price ?? item.price) +
      addons.fold(0, (sum, addon) => sum + addon.price);

  /// Human-readable option summary, e.g. "Large • Extra cheese".
  String get optionsLabel => [
    if (variant != null) variant!.name,
    ...addons.map((addon) => addon.name),
  ].join(' • ');
}

class SharedGroup {
  const SharedGroup({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.participants,
    required this.requiredParticipants,
    required this.distanceKm,
    required this.minutesLeft,
    required this.currentDiscount,
    required this.maximumDiscount,
    required this.deliveryDiscount,
    required this.savings,
    required this.imageUrl,
    required this.mode,
  });

  final String id;
  final String title;
  final String subtitle;
  final int participants;
  final int requiredParticipants;
  final double distanceKm;
  final int minutesLeft;
  final int currentDiscount;
  final int maximumDiscount;
  final int deliveryDiscount;
  final int savings;
  final String imageUrl;
  final DeliveryMode mode;
}

class DeliveryOrder {
  const DeliveryOrder({
    required this.id,
    required this.store,
    required this.date,
    required this.itemCount,
    required this.total,
    required this.status,
    required this.savings,
    this.isShared = false,
  });

  final String id;
  final String store;
  final String date;
  final int itemCount;
  final int total;
  final OrderStatus status;
  final int savings;
  final bool isShared;
}

class WalletTransaction {
  const WalletTransaction({
    required this.title,
    required this.date,
    required this.amount,
    required this.iconName,
  });

  final String title;
  final String date;
  final int amount;
  final String iconName;
}

class AppNotificationItem {
  const AppNotificationItem({
    required this.title,
    required this.body,
    required this.time,
    required this.kind,
    this.unread = false,
  });

  final String title;
  final String body;
  final String time;
  final String kind;
  final bool unread;
}

class CartLine {
  const CartLine({required this.selection, required this.quantity});

  final CartSelection selection;
  final int quantity;

  CatalogItem get item => selection.item;
  MenuVariant? get variant => selection.variant;
  List<MenuAddon> get addons => selection.addons;
  String get lineId => selection.lineId;
  String get optionsLabel => selection.optionsLabel;

  int get total => selection.unitPrice * quantity;
}
