import '../models/app_models.dart';

abstract final class MockData {
  static const foodCategories = [
    ('Biryani', 'rice'),
    ('Pizza', 'pizza'),
    ('Burger', 'burger'),
    ('Indian', 'indian'),
    ('Chinese', 'noodles'),
    ('Healthy', 'healthy'),
    ('Desserts', 'dessert'),
    ('Beverages', 'beverage'),
  ];

  static const groceryCategories = [
    ('Fruits', 'fruit'),
    ('Vegetables', 'vegetable'),
    ('Dairy', 'dairy'),
    ('Snacks', 'snack'),
    ('Beverages', 'beverage'),
    ('Bakery', 'bakery'),
    ('Household', 'household'),
    ('Personal Care', 'personal'),
    ('Frozen Food', 'frozen'),
    ('Baby Care', 'baby'),
  ];

  static const restaurants = [
    Restaurant(
      id: 'r1',
      name: 'The Spice Route',
      cuisine: 'North Indian • Biryani',
      rating: 4.7,
      deliveryMinutes: 24,
      distanceKm: 1.8,
      deliveryFee: 0,
      discount: 30,
      imageUrl:
          'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=900',
      foodShare: true,
    ),
    Restaurant(
      id: 'r2',
      name: 'Olive & Basil',
      cuisine: 'Italian • Pizzas',
      rating: 4.5,
      deliveryMinutes: 31,
      distanceKm: 2.4,
      deliveryFee: 25,
      discount: 20,
      imageUrl:
          'https://images.unsplash.com/photo-1552566626-52f8b828add9?w=900',
      foodShare: true,
    ),
    Restaurant(
      id: 'r3',
      name: 'Green Bowl Co.',
      cuisine: 'Healthy • Salads',
      rating: 4.8,
      deliveryMinutes: 19,
      distanceKm: 1.1,
      deliveryFee: 0,
      discount: 15,
      imageUrl:
          'https://images.unsplash.com/photo-1547592180-85f173990554?w=900',
    ),
  ];

  static const catalog = [
    CatalogItem(
      id: 'f1',
      name: 'Royal Chicken Biryani',
      subtitle: 'Aromatic basmati, tender chicken',
      store: 'The Spice Route',
      price: 279,
      originalPrice: 349,
      imageUrl:
          'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=700',
      type: CatalogItemType.food,
      isVeg: false,
      sharedDiscount: 8,
    ),
    CatalogItem(
      id: 'f2',
      name: 'Margherita Woodfire Pizza',
      subtitle: 'Fresh basil, mozzarella, tomato',
      store: 'Olive & Basil',
      price: 329,
      originalPrice: 399,
      imageUrl:
          'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=700',
      type: CatalogItemType.food,
      sharedDiscount: 8,
    ),
    CatalogItem(
      id: 'f3',
      name: 'Avocado Harvest Bowl',
      subtitle: 'Quinoa, greens and house dressing',
      store: 'Green Bowl Co.',
      price: 249,
      originalPrice: 299,
      imageUrl:
          'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=700',
      type: CatalogItemType.food,
      sharedDiscount: 5,
    ),
    CatalogItem(
      id: 'f4',
      name: 'Classic Smash Burger',
      subtitle: 'Double patty with signature sauce',
      store: 'Burger District',
      price: 219,
      originalPrice: 269,
      imageUrl:
          'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=700',
      type: CatalogItemType.food,
      isVeg: false,
      sharedDiscount: 5,
    ),
    CatalogItem(
      id: 'g1',
      name: 'Fresh Farm Bananas',
      subtitle: '6 pcs • approx. 700 g',
      store: 'Turquoise Daily',
      price: 49,
      originalPrice: 65,
      imageUrl:
          'https://images.unsplash.com/photo-1603833665858-e61d17a86224?w=700',
      type: CatalogItemType.grocery,
      sharedDiscount: 8,
    ),
    CatalogItem(
      id: 'g2',
      name: 'Full Cream Milk',
      subtitle: '1 L • pasteurised',
      store: 'Turquoise Daily',
      price: 68,
      originalPrice: 72,
      imageUrl:
          'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=700',
      type: CatalogItemType.grocery,
      sharedDiscount: 5,
    ),
    CatalogItem(
      id: 'g3',
      name: 'Sourdough Bread',
      subtitle: '400 g • baked today',
      store: 'FreshCart Market',
      price: 89,
      originalPrice: 120,
      imageUrl:
          'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=700',
      type: CatalogItemType.grocery,
      sharedDiscount: 8,
    ),
    CatalogItem(
      id: 'g4',
      name: 'Garden Tomatoes',
      subtitle: '500 g • pesticide safe',
      store: 'FreshCart Market',
      price: 42,
      originalPrice: 55,
      imageUrl:
          'https://images.unsplash.com/photo-1546094096-0df4bcaaa337?w=700',
      type: CatalogItemType.grocery,
      sharedDiscount: 12,
    ),
    CatalogItem(
      id: 'g5',
      name: 'Dark Chocolate Granola',
      subtitle: '350 g • high fibre',
      store: 'Turquoise Daily',
      price: 199,
      originalPrice: 249,
      imageUrl:
          'https://images.unsplash.com/photo-1517093157656-b9eccef91cb1?w=700',
      type: CatalogItemType.grocery,
      sharedDiscount: 5,
    ),
  ];

  static const groups = [
    SharedGroup(
      id: 's1',
      title: 'The Spice Route',
      subtitle: 'Biryani • North Indian',
      participants: 3,
      requiredParticipants: 5,
      distanceKm: 0.8,
      minutesLeft: 12,
      currentDiscount: 8,
      maximumDiscount: 15,
      deliveryDiscount: 40,
      savings: 72,
      imageUrl:
          'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=900',
      mode: DeliveryMode.food,
    ),
    SharedGroup(
      id: 's2',
      title: 'Olive & Basil',
      subtitle: 'Pizza • Italian',
      participants: 2,
      requiredParticipants: 5,
      distanceKm: 1.2,
      minutesLeft: 18,
      currentDiscount: 5,
      maximumDiscount: 15,
      deliveryDiscount: 25,
      savings: 54,
      imageUrl:
          'https://images.unsplash.com/photo-1579751626657-72bc17010498?w=900',
      mode: DeliveryMode.food,
    ),
    SharedGroup(
      id: 'b1',
      title: 'Turquoise Daily',
      subtitle: 'Milk, fruits + 5 more essentials',
      participants: 5,
      requiredParticipants: 8,
      distanceKm: 0.6,
      minutesLeft: 15,
      currentDiscount: 8,
      maximumDiscount: 12,
      deliveryDiscount: 50,
      savings: 91,
      imageUrl:
          'https://images.unsplash.com/photo-1542838132-92c53300491e?w=900',
      mode: DeliveryMode.grocery,
    ),
    SharedGroup(
      id: 'b2',
      title: 'FreshCart Market',
      subtitle: 'Vegetables, bakery + 3 more',
      participants: 3,
      requiredParticipants: 5,
      distanceKm: 1.4,
      minutesLeft: 22,
      currentDiscount: 5,
      maximumDiscount: 12,
      deliveryDiscount: 30,
      savings: 64,
      imageUrl:
          'https://images.unsplash.com/photo-1601600576337-c1d8a0d1373c?w=900',
      mode: DeliveryMode.grocery,
    ),
  ];

  static const orders = [
    DeliveryOrder(
      id: 'TQ240761',
      store: 'The Spice Route',
      date: 'Today, 7:24 PM',
      itemCount: 3,
      total: 624,
      status: OrderStatus.active,
      savings: 108,
      isShared: true,
    ),
    DeliveryOrder(
      id: 'TQ239842',
      store: 'Turquoise Daily',
      date: '16 Jul, 9:12 AM',
      itemCount: 7,
      total: 849,
      status: OrderStatus.completed,
      savings: 91,
      isShared: true,
    ),
    DeliveryOrder(
      id: 'TQ237120',
      store: 'Green Bowl Co.',
      date: '10 Jul, 1:42 PM',
      itemCount: 2,
      total: 462,
      status: OrderStatus.completed,
      savings: 73,
    ),
    DeliveryOrder(
      id: 'TQ235811',
      store: 'Olive & Basil',
      date: '4 Jul, 8:20 PM',
      itemCount: 1,
      total: 329,
      status: OrderStatus.cancelled,
      savings: 0,
    ),
  ];

  static const walletTransactions = [
    WalletTransaction(
      title: 'FoodShare cashback',
      date: 'Today, 8:02 PM',
      amount: 42,
      iconName: 'cashback',
    ),
    WalletTransaction(
      title: 'Referral reward • Riya',
      date: 'Today, 1:26 PM',
      amount: 1,
      iconName: 'referral',
    ),
    WalletTransaction(
      title: 'Order payment',
      date: '16 Jul, 9:10 AM',
      amount: -199,
      iconName: 'order',
    ),
    WalletTransaction(
      title: 'Money added via UPI',
      date: '12 Jul, 6:18 PM',
      amount: 500,
      iconName: 'add',
    ),
    WalletTransaction(
      title: 'Referral reward • Ayaan',
      date: '11 Jul, 7:45 PM',
      amount: 1,
      iconName: 'referral',
    ),
  ];

  static const notifications = [
    AppNotificationItem(
      title: 'Rider arriving soon',
      body: 'Arjun is less than 2 minutes away. Keep your phone handy.',
      time: 'Just now',
      kind: 'rider',
      unread: true,
    ),
    AppNotificationItem(
      title: '8% group discount unlocked!',
      body: 'Five neighbours joined your Share Basket.',
      time: '18 min',
      kind: 'discount',
      unread: true,
    ),
    AppNotificationItem(
      title: '₹1 referral reward',
      body: 'Riya completed an eligible order. Your wallet was credited.',
      time: '6 hr',
      kind: 'wallet',
    ),
    AppNotificationItem(
      title: 'Kabir joined your group',
      body: 'Your FoodShare group now has 3 participants.',
      time: 'Yesterday',
      kind: 'group',
    ),
    AppNotificationItem(
      title: 'Weekend freshness sale',
      body: 'Save up to 35% on fruits and vegetables.',
      time: '2 days',
      kind: 'promo',
    ),
  ];

  static CatalogItem itemById(String id) =>
      catalog.firstWhere((item) => item.id == id, orElse: () => catalog.first);

  static Restaurant restaurantById(String id) => restaurants.firstWhere(
    (item) => item.id == id,
    orElse: () => restaurants.first,
  );

  static SharedGroup groupById(String id) =>
      groups.firstWhere((item) => item.id == id, orElse: () => groups.first);
}
