import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/features/account/address/places_search_session.dart';

void main() {
  late DateTime clock;
  late int issued;

  PlacesSearchSession build({Duration maxAge = const Duration(minutes: 3)}) {
    clock = DateTime(2026, 10, 12, 9);
    issued = 0;
    return PlacesSearchSession(
      now: () => clock,
      tokenFactory: () => 'token-${++issued}',
      maxAge: maxAge,
    );
  }

  test('queries under three characters never request', () {
    final session = build();
    expect(session.decide(''), PlacesSearchAction.tooShort);
    expect(session.decide('  mg '), PlacesSearchAction.tooShort);
    // Characters, not bytes: two Devanagari letters are still too short.
    expect(session.decide('कर'), PlacesSearchAction.tooShort);
    expect(session.decide('करन'), PlacesSearchAction.search);
    expect(issued, 0, reason: 'a token is issued only when a request is made');
  });

  test('one token covers every request of a search session', () {
    final session = build();
    expect(session.decide('mg road'), PlacesSearchAction.search);
    final first = session.token;
    expect(session.decide('mg road g'), PlacesSearchAction.search);
    expect(session.token, first);
    expect(issued, 1);
  });

  test('an identical query in the same session is not sent twice', () {
    final session = build();
    session.token;
    expect(session.decide('Sector 17'), PlacesSearchAction.search);
    session.recordSearched('Sector 17');
    expect(session.decide('Sector 17'), PlacesSearchAction.reuseLast);
    expect(session.decide('  sector   17  '), PlacesSearchAction.reuseLast);
    expect(session.decide('Sector 17A'), PlacesSearchAction.search);
  });

  test('a failed search is retried: only recorded queries are reused', () {
    final session = build();
    session.token;
    expect(session.decide('Sector 17'), PlacesSearchAction.search);
    // recordSearched is not called when the request failed.
    expect(session.decide('Sector 17'), PlacesSearchAction.search);
  });

  test('ending the session starts a fresh one and re-allows the same query', () {
    final session = build();
    final first = session.token;
    session.recordSearched('Sector 17');
    session.end();
    expect(session.isActive, isFalse);
    expect(session.decide('Sector 17'), PlacesSearchAction.search);
    expect(session.token, isNot(first));
  });

  test('a session that outlives its max age gets a new token', () {
    final session = build();
    final first = session.token;
    session.recordSearched('Sector 17');
    clock = clock.add(const Duration(minutes: 2, seconds: 59));
    expect(session.token, first);
    clock = clock.add(const Duration(seconds: 2));
    final rotated = session.token;
    expect(rotated, isNot(first));
    // The same text is allowed again: it belongs to a new billing session.
    expect(session.decide('Sector 17'), PlacesSearchAction.search);
  });

  test('shortening the text forgets the last query', () {
    final session = build();
    session.token;
    session.recordSearched('Sector 17');
    expect(session.decide('Se'), PlacesSearchAction.tooShort);
    expect(session.decide('Sector 17'), PlacesSearchAction.search);
  });
}
