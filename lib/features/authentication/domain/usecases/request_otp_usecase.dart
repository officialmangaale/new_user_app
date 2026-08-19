/// Use case: request a one-time password for a phone number.
///
/// Single-responsibility — this class does one thing and is trivially testable.
library;

import '../../../../core/error/result.dart';
import '../entities/auth_entities.dart';
import '../repositories/auth_repository_interface.dart';

class RequestOtpUseCase {
  const RequestOtpUseCase(this._repository);

  final AuthRepositoryInterface _repository;

  Future<Result<OtpSendResult>> call(String phone) {
    return _repository.sendOtp(phone);
  }
}
