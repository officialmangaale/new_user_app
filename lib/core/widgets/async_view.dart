import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_exception.dart';
import 'app_ui.dart';

/// Renders an [AsyncValue] using the app's existing loading, error and empty
/// widgets so every wired screen behaves the same way.
///
/// Network failures render [ErrorState] in its `offline` variant, which is why
/// repositories normalize everything to [ApiException].
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
        offline: error is ApiException && error.isNetworkError,
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
