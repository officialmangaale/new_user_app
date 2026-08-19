/// Authentication-specific Riverpod providers.
///
/// Infrastructure providers (`apiClientProvider`, `authStorageProvider`) live
/// in `core/di/di_providers.dart` and are re-exported here for backward
/// compatibility. New code should import from `core/di/di_providers.dart`
/// directly.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---- Legacy re-exports (kept for existing import sites) ----
export '../../../core/di/di_providers.dart'
    show apiClientProvider, authStorageProvider;

import '../../../core/di/di_providers.dart';

// ---- Data layer ----
import '../data/repositories/auth_repository_impl.dart';

// ---- Domain layer ----
import '../domain/repositories/auth_repository_interface.dart';
import '../domain/usecases/request_otp_usecase.dart';
import '../domain/usecases/verify_otp_usecase.dart';

// ---- Legacy repository (kept for backward compat during migration) ----
import '../../../shared/repositories/auth_repository.dart';

/// Legacy provider — screens not yet migrated to the ViewModel still use this.
/// Will be removed once `auth_screens.dart` fully consumes the ViewModel.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

// ---- New architecture providers ----

/// The clean repository, typed to the domain interface.
final authRepositoryImplProvider = Provider<AuthRepositoryInterface>((ref) {
  return AuthRepositoryImpl(ref.watch(apiClientProvider));
});

/// Use case: send OTP.
final requestOtpUseCaseProvider = Provider<RequestOtpUseCase>((ref) {
  return RequestOtpUseCase(ref.watch(authRepositoryImplProvider));
});

/// Use case: verify OTP.
final verifyOtpUseCaseProvider = Provider<VerifyOtpUseCase>((ref) {
  return VerifyOtpUseCase(ref.watch(authRepositoryImplProvider));
});
