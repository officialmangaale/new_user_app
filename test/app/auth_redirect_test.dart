import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/app/router/auth_redirect.dart';

/// The reported bug: after signing in, Android back could land the user back on
/// the login or "Explore as guest" screen while still authenticated. The
/// router had no redirect at all, so nothing re-checked the session when a
/// route was popped.
void main() {
  String? redirect({
    required bool authenticated,
    required String location,
    bool sessionLoaded = true,
  }) => authRedirect(
    sessionLoaded: sessionLoaded,
    authenticated: authenticated,
    location: location,
  );

  group('a signed-in user cannot land on an auth entry screen', () {
    // These two locations are exactly the screens named in the bug report.
    test('back onto /login sends them home', () {
      expect(redirect(authenticated: true, location: '/login'), '/home');
    });

    test('back onto /welcome — "Explore as guest" — sends them home', () {
      expect(redirect(authenticated: true, location: '/welcome'), '/home');
    });
  });

  group('the guard does not interfere with signing in', () {
    test('a signed-out visitor may use the auth screens', () {
      for (final loc in authEntryRoutes) {
        expect(redirect(authenticated: false, location: loc), isNull,
            reason: loc);
      }
    });

    // /otp turns authenticated part-way through its own flow and then picks
    // its own destination. Redirecting it would send a brand-new customer to
    // /home instead of /setup, and would lose the returnTo of a login started
    // from the cart.
    test('/otp is never redirected, even once authenticated', () {
      expect(redirect(authenticated: true, location: '/otp'), isNull);
      expect(redirect(authenticated: false, location: '/otp'), isNull);
    });

    test('/setup stays reachable for a newly signed-up customer', () {
      expect(redirect(authenticated: true, location: '/setup'), isNull);
    });
  });

  group('guests keep browsing', () {
    // Guest mode is a real, supported state: unauthenticated but allowed to
    // browse. A blanket "signed out -> login" rule would have broken it.
    test('an unauthenticated visitor is not pushed out of the app', () {
      for (final loc in ['/home', '/cart', '/restaurant/12', '/search', '/orders']) {
        expect(redirect(authenticated: false, location: loc), isNull,
            reason: loc);
      }
    });
  });

  group('while the stored session is still being read', () {
    // Answering before hydration finishes is what briefly shows a login
    // screen to someone who is actually signed in.
    test('no redirect is issued either way', () {
      for (final authed in [true, false]) {
        for (final loc in ['/login', '/welcome', '/home', '/']) {
          expect(
            redirect(authenticated: authed, location: loc, sessionLoaded: false),
            isNull,
            reason: 'authenticated=$authed location=$loc',
          );
        }
      }
    });
  });

  group('splash', () {
    // Splash does its own timed navigation; the guard must not race it.
    test('/ is never redirected', () {
      expect(redirect(authenticated: true, location: '/'), isNull);
      expect(redirect(authenticated: false, location: '/'), isNull);
    });
  });
}
