import 'dart:math';

/// What a change in the address search box should do.
enum PlacesSearchAction {
  /// Too few characters to be a useful query: make no request.
  tooShort,

  /// Same query as the one already answered in this session: keep showing the
  /// current suggestions and make no request.
  reuseLast,

  /// A new query: request autocomplete suggestions.
  search,
}

/// Autocomplete session and duplicate-request policy for the address search.
///
/// Places Autocomplete is billed per session when every request carries the
/// same session token and the session ends with a Place Details call. This
/// class keeps that contract in one testable place:
///
///  * one token per search, reused by every keystroke's request and by the
///    Place Details call that ends the session;
///  * [end] after a place is resolved, so the next search starts a new session
///    (a token must never be reused after its session ended);
///  * the token is rotated if a session outlives [maxAge], because Google
///    treats an expired token as no token;
///  * an identical query in the same session is not sent twice.
///
/// It performs no network I/O and holds no results or addresses.
class PlacesSearchSession {
  PlacesSearchSession({
    DateTime Function()? now,
    String Function()? tokenFactory,
    this.maxAge = const Duration(minutes: 3),
    this.minChars = 3,
  }) : _now = now ?? DateTime.now,
       _tokenFactory = tokenFactory ?? _secureToken;

  final DateTime Function() _now;
  final String Function() _tokenFactory;

  /// How long one session token is used before a new one starts.
  final Duration maxAge;

  /// Minimum characters (not bytes) before a request is worthwhile.
  final int minChars;

  String? _token;
  DateTime? _startedAt;
  String? _lastQuery;

  /// Lower-cased, single-spaced form used to compare queries.
  static String normalize(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// The token for the current session, starting (or rotating) it as needed.
  String get token {
    final startedAt = _startedAt;
    if (_token == null ||
        startedAt == null ||
        _now().difference(startedAt) >= maxAge) {
      _token = _tokenFactory();
      _startedAt = _now();
      _lastQuery = null;
    }
    return _token!;
  }

  /// Whether a session is currently open (a token has been issued).
  bool get isActive => _token != null;

  /// Decides what a change of the search text should do.
  PlacesSearchAction decide(String raw) {
    final query = normalize(raw);
    if (query.runes.length < minChars) {
      _lastQuery = null;
      return PlacesSearchAction.tooShort;
    }
    if (_token != null && query == _lastQuery) {
      return PlacesSearchAction.reuseLast;
    }
    return PlacesSearchAction.search;
  }

  /// Records that [raw] was answered successfully in the current session.
  void recordSearched(String raw) {
    _lastQuery = normalize(raw);
  }

  /// Ends the session, after Place Details resolved the chosen suggestion.
  void end() {
    _token = null;
    _startedAt = null;
    _lastQuery = null;
  }

  static String _secureToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${DateTime.now().microsecondsSinceEpoch}-$hex';
  }
}
