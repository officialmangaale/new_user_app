/// Backend service origins.
///
/// Mangaale splits the customer surface across two services, exactly as the
/// existing food-ordering web client does:
///
///   * restaurant-service — catalog, cart, orders, tracking, notifications
///   * user-service       — customer OTP auth, profile, addresses
///
/// Both accept the same HMAC JWT, so one login covers both.
///
/// Values mirror `Food Ordering App/mangaale-food-web/.env` and can be
/// overridden per build without touching code:
///
/// ```
/// flutter run \
///   --dart-define=RESTAURANT_SERVICE_BASE_URL=http://10.0.2.2:8080 \
///   --dart-define=USER_SERVICE_BASE_URL=http://10.0.2.2:8081
/// ```
class AppConfig {
  const AppConfig._();

  static const String restaurantServiceBaseUrl = String.fromEnvironment(
    'RESTAURANT_SERVICE_BASE_URL',
    defaultValue: 'https://restaurant-prod.mangaale.com',
  );

  static const String userServiceBaseUrl = String.fromEnvironment(
    'USER_SERVICE_BASE_URL',
    defaultValue: 'https://user-prod.mangaale.com',
  );

  /// restaurant-service also serves the order WebSocket. The web client points
  /// its socket at the same origin by default.
  static const String restaurantServiceWsBaseUrl = String.fromEnvironment(
    'RESTAURANT_SERVICE_WS_BASE_URL',
    defaultValue: restaurantServiceBaseUrl,
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
