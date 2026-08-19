/// Lightweight functional Result type for the domain layer.
///
/// Every repository method returns `Result<T>` instead of throwing. Callers
/// use [when], [map], or [flatMap] to handle both paths without `try/catch`.
///
/// ```dart
/// final result = await authRepo.verifyOtp(phone, code);
/// result.when(
///   success: (session) => completeLogin(session),
///   failure: (f) => showError(f.message),
/// );
/// ```
library;

import 'failures.dart';

/// A value that is either a [Success] carrying [T] or a [Fail] carrying a
/// [Failure].
sealed class Result<T> {
  const Result();

  /// Wraps [data] in a successful result.
  const factory Result.success(T data) = Success<T>;

  /// Wraps [failure] in an unsuccessful result.
  const factory Result.failure(Failure failure) = Fail<T>;

  /// The payload when successful, otherwise `null`.
  T? get dataOrNull => switch (this) {
    Success<T>(:final data) => data,
    Fail<T>() => null,
  };

  /// The failure when unsuccessful, otherwise `null`.
  Failure? get failureOrNull => switch (this) {
    Success<T>() => null,
    Fail<T>(:final failure) => failure,
  };

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Fail<T>;

  /// Exhaustive fold over the two states.
  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) failure,
  }) =>
      switch (this) {
        Success<T>(:final data) => success(data),
        Fail<T>(:final failure) => failure(failure),
      };

  /// Transforms the success payload, leaving failures untouched.
  Result<R> map<R>(R Function(T data) transform) => switch (this) {
    Success<T>(:final data) => Result<R>.success(transform(data)),
    Fail<T>(:final failure) => Result<R>.failure(failure),
  };

  /// Chains an async operation that itself may fail.
  Future<Result<R>> flatMap<R>(
    Future<Result<R>> Function(T data) transform,
  ) async =>
      switch (this) {
        Success<T>(:final data) => transform(data),
        Fail<T>(:final failure) => Result<R>.failure(failure),
      };
}

/// A successful result carrying [data].
final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;

  @override
  String toString() => 'Success($data)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Success<T> && other.data == data;

  @override
  int get hashCode => data.hashCode;
}

/// An unsuccessful result carrying a [failure].
final class Fail<T> extends Result<T> {
  const Fail(this.failure);
  final Failure failure;

  @override
  String toString() => 'Fail($failure)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Fail<T> && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
