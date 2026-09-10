import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/auth_storage.dart';
import '../../../core/storage/guest_storage.dart';
import '../../../core/storage/referral_storage.dart';
import '../../account/providers/referral_providers.dart';
import '../../../shared/models/app_models.dart';
import 'session_scoped_providers.dart';

class AppState {
  const AppState({
    this.mode = DeliveryMode.food,
    this.authenticated = false,
    this.sessionLoaded = false,
    this.joinedGroupIds = const {},
    this.activeHomeTab = 1,
  });

  final DeliveryMode mode;
  final bool authenticated;
  final bool sessionLoaded;

  final Set<String> joinedGroupIds;
  final int activeHomeTab;

  AppState copyWith({
    DeliveryMode? mode,
    bool? authenticated,
    bool? sessionLoaded,
    Set<String>? joinedGroupIds,
    int? activeHomeTab,
  }) {
    return AppState(
      mode: mode ?? this.mode,
      authenticated: authenticated ?? this.authenticated,
      sessionLoaded: sessionLoaded ?? this.sessionLoaded,
      joinedGroupIds: joinedGroupIds ?? this.joinedGroupIds,
      activeHomeTab: activeHomeTab ?? this.activeHomeTab,
    );
  }
}

class AppController extends Notifier<AppState> {
  final GuestStorage _storage = GuestStorage();
  final AuthStorage _authStorage = AuthStorage();

  @override
  AppState build() {
    unawaited(_hydrate());
    return const AppState();
  }

  /// A stored bearer token is the source of truth for "signed in". The legacy
  /// boolean flag is still honoured so an existing install is not signed out
  /// by this change.
  Future<void> _hydrate() async {
    final token = await _authStorage.readToken();
    final authenticated = token != null || await _storage.isAuthenticated();
    state = state.copyWith(authenticated: authenticated, sessionLoaded: true);
  }

  void setMode(DeliveryMode mode) {
    state = state.copyWith(mode: mode, activeHomeTab: 1);
  }

  void toggleMode() {
    setMode(
      state.mode == DeliveryMode.food
          ? DeliveryMode.grocery
          : DeliveryMode.food,
    );
  }

  void setHomeTab(int index) => state = state.copyWith(activeHomeTab: index);

  /// Persists a verified customer session from user-service.
  Future<void> completeLogin({
    required String authToken,
    required String userId,
    required String name,
    required String phone,
  }) async {
    await _authStorage.saveSession(
      token: authToken,
      userId: userId,
      name: name,
      phone: phone,
    );
    await _storage.setAuthenticated(true);
    await _storage.setOnboardingSeen();
    state = state.copyWith(authenticated: true, sessionLoaded: true);
    await _applyPendingReferral();
  }

  /// Attributes a referral code captured from a link before this customer had
  /// an account.
  ///
  /// Runs after the session exists, because the apply endpoint is
  /// authenticated. Failures are deliberately swallowed: the customer has a
  /// working account either way, and failing login over a referral would be
  /// the wrong trade. The stored code is cleared whatever the outcome, so a
  /// code the server refused is not retried on every sign-in.
  Future<void> _applyPendingReferral() async {
    final storage = ReferralStorage();
    final code = await storage.readPendingCode();
    if (code == null) return;
    try {
      await ref.read(referralRepositoryProvider).applyCode(code);
    } catch (_) {
      // Deliberately ignored — see above.
    } finally {
      await storage.clearPendingCode();
    }
  }

  Future<void> logout() async {
    await _authStorage.clear();
    await _storage.setAuthenticated(false);
    state = state.copyWith(authenticated: false);
    // Drop everything cached for the customer who just signed out, so the
    // next person on this device cannot see their addresses, payment methods,
    // order history or wallet.
    invalidateSessionScopedProviders(ref);
  }

  /// Called when the API rejects the stored token.
  ///
  /// The 401 handler in di_providers.dart clears the token before calling
  /// this; clearing again here keeps the method safe on its own, so a future
  /// caller cannot leave a dead token on disk for _hydrate to trust on the
  /// next cold start.
  Future<void> handleSessionExpired() async {
    if (!state.authenticated) return;
    await _authStorage.clear();
    await _storage.setAuthenticated(false);
    state = state.copyWith(authenticated: false);
    invalidateSessionScopedProviders(ref);
  }

  void joinGroup(String id) {
    state = state.copyWith(joinedGroupIds: {...state.joinedGroupIds, id});
  }
}

final appControllerProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);
