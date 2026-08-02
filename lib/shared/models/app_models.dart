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

  int get discountPercent => originalPrice <= price
      ? 0
      : ((originalPrice - price) * 100 ~/ originalPrice);
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
  const CartLine({required this.item, required this.quantity});

  final CatalogItem item;
  final int quantity;
  int get total => item.price * quantity;
}
