/// Concrete authentication repository backed by user-service.
///
/// Implements the domain interface and returns `Result` instead of throwing.
/// DioExceptions are caught at the boundary and converted to domain `Failure`s.
library;

import 'package:dio/dio.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/api_exception.dart';
import '../../domain/entities/auth_entities.dart';
import '../../domain/repositories/auth_repository_interface.dart';
import '../dtos/auth_dtos.dart';

class AuthRepositoryImpl implements AuthRepositoryInterface {
  const AuthRepositoryImpl(this._client);

  final ApiClient _client;

  static const String _sendOtpPath = '/customers/auth/send-otp';
  static const String _verifyOtpPath = '/customers/auth/verify-otp';

  @override
  Future<Result<OtpSendResult>> sendOtp(String phone) async {
    try {
      final response = await _client.user.post<dynamic>(
        _sendOtpPath,
        data: <String, dynamic>{'phone': phone},
      );
      final dto = OtpSendResultDto.fromJson(unwrapApiObject(response.data));
      return Result.success(dto.toEntity());
    } on DioException catch (error) {
      return Result.failure(
        Failure.fromApiException(ApiException.fromDioException(error)),
      );
    } on ApiException catch (error) {
      return Result.failure(Failure.fromApiException(error));
    }
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final response = await _client.user.post<dynamic>(
        _verifyOtpPath,
        data: <String, dynamic>{'phone': phone, 'otp': otp},
      );
      final dto = AuthSessionDto.fromJson(unwrapApiObject(response.data));
      if (dto.authToken.isEmpty) {
        return const Result.failure(
          ServerFailure(
            'Login failed: the server did not return a session token.',
          ),
        );
      }
      return Result.success(dto.toEntity());
    } on DioException catch (error) {
      return Result.failure(
        Failure.fromApiException(ApiException.fromDioException(error)),
      );
    } on ApiException catch (error) {
      return Result.failure(Failure.fromApiException(error));
    }
  }
}
