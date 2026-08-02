import 'package:shared_preferences/shared_preferences.dart';

class GuestStorage {
  static const _authenticatedKey = 'is_authenticated';
  static const _onboardingKey = 'onboarding_seen';
  static const _bestScoreKey = 'puzzle_best_score';

  Future<bool> isAuthenticated() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_authenticatedKey) ?? false;
  }

  Future<void> setAuthenticated(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_authenticatedKey, value);
  }

  Future<bool> hasSeenOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_onboardingKey) ?? false;
  }

  Future<void> setOnboardingSeen() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingKey, true);
  }

  Future<int> bestPuzzleScore() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_bestScoreKey) ?? 0;
  }

  Future<void> setBestPuzzleScore(int score) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_bestScoreKey, score);
  }
}
