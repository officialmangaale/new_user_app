/// Use case: verify a one-time password and obtain an authenticated session.
library;

import '../../../../core/error/result.dart';
import '../entities/auth_entities.dart';
import '../repositories/auth_repository_interface.dart';

class VerifyOtpUseCase {
  const VerifyOtpUseCase(this._repository);

  final AuthRepositoryInterface _repository;

  Future<Result<AuthSession>> call({
    required String phone,
    required String otp,
  }) {
    return _repository.verifyOtp(phone: phone, otp: otp);
  }
}
