/// Centralized dependency-injection providers.
///
/// Every feature imports its infrastructure dependencies from this file rather
/// than reaching into another feature's provider barrel. This eliminates the
/// implicit coupling where, for example, `catalog_providers.dart` imported
/// `apiClientProvider` from `authentication/providers/auth_providers.dart`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../storage/auth_storage.dart';
import '../storage/guest_storage.dart';
import '../../features/app_state/providers/app_controller.dart';

/// Persisted customer session (token + identity).
final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());

/// Guest/onboarding flags.
final guestStorageProvider = Provider<GuestStorage>((ref) => GuestStorage());

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
