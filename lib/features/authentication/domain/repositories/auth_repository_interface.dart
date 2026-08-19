/// Abstract authentication repository contract.
///
/// The domain layer defines *what* can be done; the data layer decides *how*.
/// Use cases and ViewModels depend on this interface, never on the concrete
/// implementation.
library;

import '../../../../core/error/result.dart';
import '../entities/auth_entities.dart';

abstract interface class AuthRepositoryInterface {
  /// Dispatches a one-time password to [phone].
  Future<Result<OtpSendResult>> sendOtp(String phone);

  /// Verifies the [otp] for [phone] and returns an authenticated session.
  Future<Result<AuthSession>> verifyOtp({
    required String phone,
    required String otp,
  });
}
