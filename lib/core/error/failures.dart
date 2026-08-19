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
    final code = exception.statusCode;
    if (code == 401 || code == 403) {
      return AuthFailure(
        exception.message,
        statusCode: code,
      );
    }
    if (code != null && code >= 400 && code < 500) {
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
