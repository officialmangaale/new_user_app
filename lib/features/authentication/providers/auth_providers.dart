import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../shared/repositories/auth_repository.dart';
import '../../app_state/providers/app_controller.dart';

/// Persisted customer session (token + identity).
final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());

/// Shared HTTP client for both Mangaale customer services.
///
/// The bearer token is read per-request, so a login or logout takes effect
/// immediately without rebuilding the client.
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(authStorageProvider);
  return ApiClient(
    tokenReader: storage.readToken,
    onUnauthorized: () async {
      await storage.clear();
      // Read lazily: this runs during a request, never during construction,
      // so it cannot create a provider cycle.
      ref.read(appControllerProvider.notifier).handleSessionExpired();
    },
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
