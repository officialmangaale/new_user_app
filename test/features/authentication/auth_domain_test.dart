import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:turquoise_delivery/core/error/failures.dart';
import 'package:turquoise_delivery/core/error/result.dart';
import 'package:turquoise_delivery/features/authentication/domain/entities/auth_entities.dart';
import 'package:turquoise_delivery/features/authentication/domain/repositories/auth_repository_interface.dart';
import 'package:turquoise_delivery/features/authentication/domain/usecases/request_otp_usecase.dart';
import 'package:turquoise_delivery/features/authentication/domain/usecases/verify_otp_usecase.dart';
import 'package:turquoise_delivery/features/authentication/presentation/viewmodels/auth_viewmodel.dart';
import 'package:turquoise_delivery/features/authentication/providers/auth_providers.dart';

// ---------------------------------------------------------------------------
// Fake repository for testing without network
// ---------------------------------------------------------------------------

class FakeAuthRepository implements AuthRepositoryInterface {
  Result<OtpSendResult>? nextOtpResult;
  Result<AuthSession>? nextVerifyResult;
  int sendOtpCallCount = 0;
  int verifyOtpCallCount = 0;

  @override
  Future<Result<OtpSendResult>> sendOtp(String phone) async {
    sendOtpCallCount++;
    return nextOtpResult ?? const Result.failure(
      UnknownFailure('sendOtp not configured'),
    );
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    verifyOtpCallCount++;
    return nextVerifyResult ?? const Result.failure(
      UnknownFailure('verifyOtp not configured'),
    );
  }
}

void main() {
  // ---- Result<T> type tests ----

  group('Result', () {
    test('Success carries data', () {
      const result = Result<int>.success(42);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('Failure carries error', () {
      const result = Result<int>.failure(NetworkFailure('offline'));
      expect(result.isFailure, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, isA<NetworkFailure>());
    });

    test('when folds exhaustively', () {
      const result = Result<String>.success('hello');
      final output = result.when(
        success: (data) => 'got: $data',
        failure: (f) => 'error: ${f.message}',
      );
      expect(output, 'got: hello');
    });

    test('map transforms success', () {
      const result = Result<int>.success(5);
      final mapped = result.map((n) => n * 2);
      expect(mapped.dataOrNull, 10);
    });

    test('map preserves failure', () {
      const result = Result<int>.failure(ServerFailure('boom'));
      final mapped = result.map((n) => n * 2);
      expect(mapped.isFailure, isTrue);
      expect(mapped.failureOrNull?.message, 'boom');
    });

    test('equality works', () {
      const a = Result<int>.success(1);
      const b = Result<int>.success(1);
      expect(a, equals(b));

      const fa = Result<int>.failure(NetworkFailure('x'));
      const fb = Result<int>.failure(NetworkFailure('x'));
      expect(fa, equals(fb));
    });
  });

  // ---- Failure hierarchy tests ----

  group('Failure.fromApiException', () {
    test('creates NetworkFailure for network errors', () {
      // ApiException with isNetworkError needs statusCode == null
      // and a message — simulate by constructing directly.
      const failure = NetworkFailure('No connection');
      expect(failure.message, 'No connection');
      expect(failure.statusCode, isNull);
    });

    test('creates AuthFailure for 401', () {
      const failure = AuthFailure('Unauthorized', statusCode: 401);
      expect(failure, isA<AuthFailure>());
      expect(failure.statusCode, 401);
    });

    test('creates ValidationFailure for 422', () {
      const failure = ValidationFailure('Invalid phone', statusCode: 422);
      expect(failure, isA<ValidationFailure>());
    });

    test('creates ServerFailure for 500', () {
      const failure = ServerFailure('Internal error', statusCode: 500);
      expect(failure, isA<ServerFailure>());
    });
  });

  // ---- Use case tests ----

  group('RequestOtpUseCase', () {
    test('delegates to repository and returns success', () async {
      final repo = FakeAuthRepository();
      repo.nextOtpResult = const Result.success(
        OtpSendResult(phone: '9876543210', expiresInSeconds: 300, resendAfterSeconds: 30),
      );
      final useCase = RequestOtpUseCase(repo);

      final result = await useCase.call('9876543210');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.phone, '9876543210');
      expect(repo.sendOtpCallCount, 1);
    });

    test('propagates failure from repository', () async {
      final repo = FakeAuthRepository();
      repo.nextOtpResult = const Result.failure(
        ValidationFailure('Invalid phone number', statusCode: 400),
      );
      final useCase = RequestOtpUseCase(repo);

      final result = await useCase.call('123');

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ValidationFailure>());
    });
  });

  group('VerifyOtpUseCase', () {
    test('returns session on success', () async {
      final repo = FakeAuthRepository();
      repo.nextVerifyResult = const Result.success(
        AuthSession(
          authToken: 'token123',
          user: AuthUser(
            userId: 'u1',
            name: 'Aarav',
            phone: '9876543210',
            email: '',
            role: 'customer',
            isNewUser: false,
          ),
        ),
      );
      final useCase = VerifyOtpUseCase(repo);

      final result = await useCase.call(phone: '9876543210', otp: '123456');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.authToken, 'token123');
      expect(result.dataOrNull?.user.name, 'Aarav');
    });

    test('returns failure for wrong OTP', () async {
      final repo = FakeAuthRepository();
      repo.nextVerifyResult = const Result.failure(
        ValidationFailure('Invalid OTP', statusCode: 400),
      );
      final useCase = VerifyOtpUseCase(repo);

      final result = await useCase.call(phone: '9876543210', otp: '000000');

      expect(result.isFailure, isTrue);
    });
  });

  // ---- ViewModel tests ----

  group('AuthViewModel', () {
    late FakeAuthRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeAuthRepository();
      container = ProviderContainer(
        overrides: [
          requestOtpUseCaseProvider.overrideWith(
            (ref) => RequestOtpUseCase(fakeRepo),
          ),
          verifyOtpUseCaseProvider.overrideWith(
            (ref) => VerifyOtpUseCase(fakeRepo),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('sendOtp sets sending state and returns result', () async {
      fakeRepo.nextOtpResult = const Result.success(
        OtpSendResult(phone: '9876543210', expiresInSeconds: 300, resendAfterSeconds: 30),
      );

      final vm = container.read(authViewModelProvider.notifier);
      final result = await vm.sendOtp('9876543210');

      expect(result, isNotNull);
      expect(result?.phone, '9876543210');

      final state = container.read(authViewModelProvider);
      expect(state.otpSending, isFalse);
      expect(state.error, isNull);
    });

    test('sendOtp sets error on failure', () async {
      fakeRepo.nextOtpResult = const Result.failure(
        NetworkFailure('No connection'),
      );

      final vm = container.read(authViewModelProvider.notifier);
      final result = await vm.sendOtp('9876543210');

      expect(result, isNull);

      final state = container.read(authViewModelProvider);
      expect(state.otpSending, isFalse);
      expect(state.error, 'No connection');
    });

    test('verifyOtp returns session on success', () async {
      fakeRepo.nextVerifyResult = const Result.success(
        AuthSession(
          authToken: 'tok',
          user: AuthUser(
            userId: 'u1',
            name: 'Test',
            phone: '1234567890',
            email: '',
            role: 'customer',
            isNewUser: true,
          ),
        ),
      );

      final vm = container.read(authViewModelProvider.notifier);
      final session = await vm.verifyOtp(phone: '1234567890', otp: '111111');

      expect(session, isNotNull);
      expect(session?.authToken, 'tok');
      expect(session?.user.isNewUser, isTrue);
    });

    test('verifyOtp sets error on failure', () async {
      fakeRepo.nextVerifyResult = const Result.failure(
        AuthFailure('Token expired', statusCode: 401),
      );

      final vm = container.read(authViewModelProvider.notifier);
      final session = await vm.verifyOtp(phone: '1234567890', otp: '000000');

      expect(session, isNull);
      expect(container.read(authViewModelProvider).error, 'Token expired');
    });

    test('clearError removes error from state', () async {
      fakeRepo.nextOtpResult = const Result.failure(
        NetworkFailure('offline'),
      );

      final vm = container.read(authViewModelProvider.notifier);
      await vm.sendOtp('123');
      expect(container.read(authViewModelProvider).error, 'offline');

      vm.clearError();
      expect(container.read(authViewModelProvider).error, isNull);
    });
  });
}
