/// Domain-level failure hierarchy.
///
/// Repositories catch infrastructure exceptions (Dio, platform, etc.) and
/// return the appropriate [Failure] subtype inside a `Result.failure(...)`.
/// Presentation code never sees raw exceptions — it pattern-matches on these
/// sealed types instead.
library;

import '../services/api_exception.dart';

/// Base type for all domain failures.
sealed class Failure {
  const Failure(this.message, {this.statusCode});

  /// A human-readable description suitable for user-facing snackbars/dialogs.
  final String message;

  /// The HTTP status code, when the failure originated from a network call.
  final int? statusCode;

  @override
  String toString() => '$runtimeType($message, statusCode: $statusCode)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          statusCode == other.statusCode;

  @override
  int get hashCode => Object.hash(runtimeType, message, statusCode);

  /// Converts the app's existing [ApiException] into the matching [Failure]
  /// subtype. Repositories call this at the catch boundary so the domain layer
  /// never sees Dio artefacts.
  factory Failure.fromApiException(ApiException exception) {
    if (exception.isNetworkError) {
      return NetworkFailure(exception.message);
    }
    final pricing = DeliveryPricingFailure.tryFrom(exception);
    if (pricing != null) return pricing;
    final code = exception.statusCode;
    if (code == 401 || code == 403) {
      return AuthFailure(
        exception.message,
        statusCode: code,
      );
    }
    if (code >= 400 && code < 500) {
      return ValidationFailure(
        exception.message,
        statusCode: code,
      );
    }
    return ServerFailure(
      exception.message,
      statusCode: code,
    );
  }
}

/// The device has no connectivity, DNS failed, or the request timed out.
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// The server returned a 5xx or an otherwise unexpected error.
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.statusCode});
}

/// The session token is invalid, expired, or the user lacks permission.
final class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.statusCode});
}

/// The request was well-formed but the server rejected it (4xx, excluding auth).
/// Typically a bad input or a business-rule violation.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.statusCode});
}

/// A catch-all for failures that don't fit the categories above.
final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong.']);
}
/// Why a delivery order could not be priced. Mirrors the backend's typed
/// `pricing_status` (FD-03); the customer-facing wording is chosen here so the
/// right fix is offered, instead of blaming the address for every status.
enum DeliveryPricingStatus {
  /// The delivery pin is missing or invalid: confirm the address.
  missingCustomerLocation,

  /// The restaurant has no usable pin: nothing the customer can fix.
  missingRestaurantLocation,

  /// Both pins are valid but no delivery slab covers the distance.
  noMatchingRule,

  /// The pin is beyond the restaurant's maximum delivery distance.
  outOfRange,

  /// The resolver failed or is not configured: try again.
  pricingUnavailable;

  static DeliveryPricingStatus? parse(String? raw) => switch (raw) {
    'MISSING_CUSTOMER_LOCATION' => missingCustomerLocation,
    'MISSING_RESTAURANT_LOCATION' => missingRestaurantLocation,
    'NO_MATCHING_RULE' => noMatchingRule,
    'PRICING_UNAVAILABLE' => pricingUnavailable,
    'DELIVERY_OUT_OF_RANGE' => outOfRange,
    'DELIVERY_PRICING_UNAVAILABLE' => pricingUnavailable,
    _ => null,
  };

  String get userMessage => switch (this) {
    missingCustomerLocation => 'Please confirm your delivery location.',
    missingRestaurantLocation =>
      'Delivery is temporarily unavailable for this restaurant.',
    noMatchingRule => 'This location is outside the current delivery area.',
    outOfRange => 'Delivery is not available for this location.',
    pricingUnavailable =>
      "We couldn't calculate the delivery charge. Please try again.",
  };

  /// True when changing the delivery address could fix it.
  bool get addressCanFix =>
      this == missingCustomerLocation ||
      this == noMatchingRule ||
      this == outOfRange;

  /// True when a plain retry is the right action.
  bool get retryable =>
      this == pricingUnavailable || this == missingRestaurantLocation;
}

/// A coded delivery-pricing refusal. Never produces a ₹0 bill: the cart stays
/// unpriced and checkout stays disabled.
final class DeliveryPricingFailure extends Failure {
  const DeliveryPricingFailure(
    this.status, {
    String? message,
    super.statusCode,
  }) : super(message ?? '');

  final DeliveryPricingStatus status;

  @override
  String get message => super.message.isEmpty ? status.userMessage : super.message;

  static DeliveryPricingFailure? tryFrom(ApiException exception) {
    final raw = exception.data?['pricing_status'];
    final status =
        DeliveryPricingStatus.parse(raw is String ? raw : null) ??
        DeliveryPricingStatus.parse(exception.code);
    if (status == null) return null;
    return DeliveryPricingFailure(status, statusCode: exception.statusCode);
  }
}
