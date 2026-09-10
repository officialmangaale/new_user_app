# new_user_app — Implementation Summary

What changed, why, and what is still open. See
[INVESTIGATION.md](INVESTIGATION.md) for the evidence.

Nothing was deployed. No migration was written or run — no backend change was
needed.

---

## 1. Router auth guard

**Before.** `GoRouter` had `initialLocation` and a flat route list, with no
`redirect` and no `refreshListenable`. Auth state was never consulted during
navigation.

**After.** A single `redirect`, backed by a `refreshListenable` driven by the
session, is now the one place deciding whether a location is allowed.

```dart
String? authRedirect({
  required bool sessionLoaded,
  required bool authenticated,
  required String location,
}) {
  if (!sessionLoaded) return null;
  if (authenticated && authEntryRoutes.contains(location)) return '/home';
  return null;
}
```

`authEntryRoutes` is `{'/welcome', '/login'}` — the two screens named in the
report.

Three deliberate exclusions:

| Excluded | Why |
| --- | --- |
| `/otp` | Becomes authenticated mid-flow, then picks its own destination: `/setup` for a new customer, or the `returnTo` of a login started from the cart. Guarding it would strand new users and lose cart intent. |
| `/` | Splash owns its own timing. |
| Signed-out users on any route | Guest browsing is a supported state. A blanket rule would have broken it; the app already prompts for login at the point of action. |

The `sessionLoaded` check matters on its own: answering before hydration
finishes is what briefly shows a login screen to someone who is signed in.

`refreshListenable` means a logout takes effect immediately rather than at
whatever the next navigation happens to be.

The decision lives in `lib/app/router/auth_redirect.dart` rather than inline,
because testing it through the widget tree would mean building real screens
that fetch over the network.

---

## 2. Session-scoped data is cleared on sign-out

**Before.** `logout()` cleared the token and the flag. Thirteen providers
holding per-customer data were not `autoDispose` and nothing invalidated them,
so the next person to sign in on a shared device could see the previous
customer's addresses, payment methods and order history.

**After.** Two changes, because either alone is insufficient:

1. **`lib/features/app_state/providers/session_scoped_providers.dart`** — one
   documented registry, called by both `logout()` and `handleSessionExpired()`.
   Adding a provider that returns data for the signed-in customer means adding
   it here; that is the file's whole contract.

2. **`autoDispose` on the identity-bearing providers** — `profileProvider`,
   `addressesProvider`, `paymentMethodsProvider`, `ordersProvider`,
   `activeOrdersProvider`, `walletProvider`.

The second was necessary because `ref.invalidate` keeps the previous value
while refetching (`AsyncData(isLoading: true, value: old)`), so a widget could
still render the previous customer during the reload. `autoDispose` makes the
state genuinely discarded once the screen unmounts. It matches
`favorites_provider.dart`, which already scoped per-customer data this way.

Every call site of the flipped providers was checked first: all are `watch`
inside `build`, and the two `read(...).value` calls sit in the same widget that
already watches. `cartBillProvider` and the shared-order families were
deliberately **not** flipped — checkout is mid-flight state, and an
`autoDispose` provider torn down at an async gap is what broke COD previously
in this repo.

---

## 3. `handleSessionExpired` is now safe standing alone

It clears the token and the guest flag itself rather than relying on the 401
handler having done so. Not a live bug — its only caller already cleared
storage — but `_hydrate()` treats a stored token as proof of sign-in, so a
future caller could otherwise have left a dead token to be trusted on the next
cold start. It became `async`, and the 401 handler now awaits it.

---

## 4. Files changed

```
lib/app/router/auth_redirect.dart                            new — the guard rule
lib/app/router/app_router.dart                               redirect + refreshListenable
lib/features/app_state/providers/session_scoped_providers.dart  new — cache registry
lib/features/app_state/providers/app_controller.dart         logout + expiry clear caches
lib/features/orders/providers/orders_providers.dart          5 providers autoDispose
lib/features/account/providers/engagement_providers.dart     walletProvider autoDispose
lib/core/di/di_providers.dart                                awaits the expiry cleanup

test/app/auth_redirect_test.dart                             new — 8 tests
test/app/session_cleanup_test.dart                           new — 4 tests
```

No backend service was touched. No existing route, contract or screen was
removed or renamed.

---

## 5. Verification

| Command | Result |
| --- | --- |
| `flutter analyze` | 17 issues, all pre-existing info-level, **0 errors** |
| `flutter test` | **67 passed** (55 before this work) |

New tests:

- **`auth_redirect_test.dart`** — a signed-in user is sent home from `/login`
  and `/welcome`; `/otp` and `/setup` are never redirected; guests browse
  freely; nothing is decided before hydration; `/` is left to splash.
- **`session_cleanup_test.dart`** — each test serves "user A", signs out, then
  serves "user B" from the same override, so a surviving cache fails the test.
  Covers profile, wallet, order history on logout, and addresses on a rejected
  token.

---

## 6. Found but not fixed

**The silent-failure sweep in section 9 of the brief is not complete.** Login,
signup, OTP, add to cart, quantity, address and payment selection, coupons,
ratings, cancel and track were not individually audited for loading state,
double-submit protection and error mapping. Checkout and COD place-order were
covered by earlier work in this repo; the rest were not.

**Deep link and notification navigation was not traced.** A push token is
registered, but the tap-handling path and its authorization re-check were not
followed, so the brief's requirement that deep links re-check authorization is
unverified.

**Multi-account switching was verified only at the provider layer.** The tests
prove cached provider data does not survive a sign-out. Whether any other state
— cart contents, in-memory singletons, open sockets — carries across an account
switch was not audited.

---

## 7. Not verified

Everything here is verified by unit tests, static analysis and code reading. No
device or emulator run was possible in this environment, so the back-button
behaviour itself has not been observed. See
[MANUAL_QA_CHECKLIST.md](MANUAL_QA_CHECKLIST.md).
