import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/failures.dart';
import '../services/api_exception.dart';
import 'app_ui.dart';

/// True when [error] represents "the request never reached the server".
///
/// Repositories normalize transport errors to [ApiException] and then convert
/// them to a [NetworkFailure] at the domain boundary. Providers rethrow the
/// [Failure], so checking only for [ApiException] would never match and the
/// offline state would be unreachable — both are accepted here.
bool isOfflineError(Object error) =>
    error is NetworkFailure ||
    (error is ApiException && error.isNetworkError);

/// Renders an [AsyncValue] using the app's existing loading, error and empty
/// widgets so every wired screen behaves the same way.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    required this.value,
    required this.builder,
    this.onRetry,
    this.empty,
    this.isEmpty,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  /// Shown instead of [builder] when [isEmpty] reports the payload is empty.
  final Widget? empty;
  final bool Function(T data)? isEmpty;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const LoadingSkeleton(),
      error: (error, _) => ErrorState(
        offline: isOfflineError(error),
        onRetry: onRetry,
      ),
      data: (data) {
        if (empty != null && (isEmpty?.call(data) ?? false)) return empty!;
        return builder(data);
      },
    );
  }
}

/// Convenience for the common `List<T>` case.
class AsyncListView<T> extends StatelessWidget {
  const AsyncListView({
    required this.value,
    required this.builder,
    required this.empty,
    this.onRetry,
    super.key,
  });

  final AsyncValue<List<T>> value;
  final Widget Function(List<T> items) builder;
  final Widget empty;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<T>>(
      value: value,
      onRetry: onRetry,
      empty: empty,
      isEmpty: (items) => items.isEmpty,
      builder: builder,
    );
  }
}
