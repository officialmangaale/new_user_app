import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/auth_storage.dart';
import '../../../core/storage/guest_storage.dart';
import '../../../shared/models/app_models.dart';

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
    final authenticated =
        token != null || await _storage.isAuthenticated();
    state = state.copyWith(authenticated: authenticated, sessionLoaded: true);
  }

  void setMode(DeliveryMode mode) {
    state = state.copyWith(mode: mode, activeHomeTab: 1);
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
  }

  Future<void> logout() async {
    await _authStorage.clear();
    await _storage.setAuthenticated(false);
    state = state.copyWith(
      authenticated: false,
    );
  }

  void handleSessionExpired() {
    if (!state.authenticated) return;
    state = state.copyWith(authenticated: false);
  }

  void joinGroup(String id) {
    state = state.copyWith(joinedGroupIds: {...state.joinedGroupIds, id});
  }
}

final appControllerProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);

