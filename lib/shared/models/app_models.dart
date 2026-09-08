export '../../features/catalog/domain/entities/catalog_entities.dart';
export '../../features/cart/domain/entities/cart_entities.dart';
export '../../features/orders/domain/entities/order_entities.dart';

enum DeliveryMode { food, grocery }

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
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.kind,
    this.unread = false,
  });

  final String id;
  final String title;
  final String body;
  final String time;
  final String kind;
  final bool unread;
}

class FavoriteRestaurant {
  const FavoriteRestaurant({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.tags,
    required this.rating,
  });

  final String id;
  final String name;
  final String imageUrl;
  final String tags;
  final double rating;
}

class FavoriteGroceryItem {
  const FavoriteGroceryItem({
    required this.productId,
    required this.merchantId,
    required this.name,
    required this.imageUrl,
    required this.sellingPrice,
    required this.packageSize,
  });

  final String productId;
  final String merchantId;
  final String name;
  final String imageUrl;
  final double sellingPrice;
  final String packageSize;
}

class AppContent {
  const AppContent({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

