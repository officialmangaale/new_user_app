/// Authentication ViewModel — mediates between the auth screens and domain
/// use cases.
///
/// Exposes [sendOtp] and [verifyOtp] as methods that update [AsyncValue] state,
/// so the UI can react to loading/error/success without manual `setState` or
/// `try/catch`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/auth_entities.dart';
import '../../providers/auth_providers.dart';

/// State exposed to the OTP login / verify screens.
class AuthViewState {
  const AuthViewState({
    this.otpSending = false,
    this.otpVerifying = false,
    this.error,
  });

  final bool otpSending;
  final bool otpVerifying;
  final String? error;

  AuthViewState copyWith({
    bool? otpSending,
    bool? otpVerifying,
    String? error,
    bool clearError = false,
  }) {
    return AuthViewState(
      otpSending: otpSending ?? this.otpSending,
      otpVerifying: otpVerifying ?? this.otpVerifying,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthViewModel extends Notifier<AuthViewState> {
  @override
  AuthViewState build() => const AuthViewState();

  /// Requests an OTP. Returns the [OtpSendResult] on success, `null` on
  /// failure (the error is surfaced in [state.error]).
  Future<OtpSendResult?> sendOtp(String phone) async {
    state = state.copyWith(otpSending: true, clearError: true);
    final result = await ref.read(requestOtpUseCaseProvider).call(phone);
    return result.when(
      success: (data) {
        state = state.copyWith(otpSending: false);
        return data;
      },
      failure: (failure) {
        state = state.copyWith(otpSending: false, error: failure.message);
        return null;
      },
    );
  }

  /// Verifies the OTP. Returns the [AuthSession] on success, `null` on
  /// failure.
  Future<AuthSession?> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    state = state.copyWith(otpVerifying: true, clearError: true);
    final result = await ref
        .read(verifyOtpUseCaseProvider)
        .call(phone: phone, otp: otp);
    return result.when(
      success: (session) {
        state = state.copyWith(otpVerifying: false);
        return session;
      },
      failure: (failure) {
        state = state.copyWith(otpVerifying: false, error: failure.message);
        return null;
      },
    );
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final authViewModelProvider =
    NotifierProvider<AuthViewModel, AuthViewState>(AuthViewModel.new);
