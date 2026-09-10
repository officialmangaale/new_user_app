# new_user_app — Navigation and Session Investigation

Evidence for the reported bug and the nearby gaps found while tracing it.

> **Docs location.** `new_user_app` had no `docs/` directory. It is placed
> inside the app rather than at the monorepo root because every finding is
> specific to this Flutter app; the repo's other docs live inside the service
> they describe (`restaurant-service/docs/`, `user-service/docs/`).

---

## 1. Architecture as found

| Concern | Where |
| --- | --- |
| Entry point | `lib/main.dart` → `ProviderScope(child: TurquoiseApp())` |
| App shell | `lib/app/app.dart` — `MaterialApp.router(routerConfig: ref.watch(appRouterProvider))` |
| Router | `lib/app/router/app_router.dart` — go_router 17.3, flat top-level routes |
| Session state | `lib/features/app_state/providers/app_controller.dart` — `AppState` |
| Token storage | `lib/core/storage/auth_storage.dart` |
| Guest flag | `lib/core/storage/guest_storage.dart` |
| HTTP + 401 handling | `lib/core/di/di_providers.dart` — `apiClientProvider` |
| Auth screens | `lib/features/authentication/presentation/auth_screens.dart` |

`AppState` carries `authenticated` and `sessionLoaded`. The second is what
distinguishes "still reading storage" from "decided", and it already existed.

---

## 2. The confirmed bug — back after login

### Navigation trace

| Step | Call | Resulting stack |
| --- | --- | --- |
| Splash, after a 1300 ms timer | `context.go(authenticated ? '/home' : '/welcome')` — `auth_screens.dart:39` | `[/welcome]` |
| Welcome → "Continue with mobile number" | `context.push('/login')` — `:141` | `[/welcome, /login]` |
| Welcome → "Explore as guest" | `context.go('/home')` — `:147` | `[/home]` |
| Login → OTP sent | `context.push('/otp?returnTo=…&phone=…)` — `:248` | `[/welcome, /login, /otp]` |
| OTP verified | `context.go(destination)` — `:443` | replaced |

### Root cause

**The router had no `redirect` and no `refreshListenable`.** Nothing
re-evaluated the session on navigation, so no location was ever checked against
auth state.

`context.go` normally replaces the stack, which is why the symptom is
intermittent rather than constant. But the auth chain is built from `push`es,
and with no guard *any* path that leaves an auth page underneath — imperative
push interactions, a deep link, a notification open — surfaces the login or
"Explore as guest" screen to a signed-in user, with nothing to correct it.

The two screens named in the report, `/login` and `/welcome`, are exactly the
two entry screens reachable this way.

### Why `/otp` must not be guarded

`/otp` becomes authenticated part-way through its own flow, then chooses a
destination:

```dart
final destination = (!session.user.isNewUser && widget.returnTo == '/setup')
    ? '/home'
    : widget.returnTo;
```

A redirect firing on the session change would send a brand-new customer to
`/home` instead of `/setup`, and would discard the `returnTo` of a login
started from the cart. `/` is excluded too, so splash keeps its own timing.

---

## 3. Other gaps found while tracing

### 3.1 Session-scoped caches survived logout — data exposure

`logout()` cleared the token and the flag, and nothing else:

```dart
Future<void> logout() async {
  await _authStorage.clear();
  await _storage.setAuthenticated(false);
  state = state.copyWith(authenticated: false);
}
```

Thirteen providers hold data belonging to one signed-in customer, and none of
them were `autoDispose`:

| Provider | Holds |
| --- | --- |
| `profileProvider` | name, phone, email |
| `addressesProvider` | delivery addresses |
| `paymentMethodsProvider` | payment methods |
| `ordersProvider`, `activeOrdersProvider` | order history |
| `walletProvider` | wallet balance |
| `referralSummaryProvider`, `referralDashboardProvider`, `referralDiscountsProvider` | referral code and earnings |
| `notificationsProvider`, `cartBillProvider`, `sharedGroupsProvider`, `sharedGroupProvider` | assorted per-customer state |

On a shared device the next person to sign in could see the previous
customer's addresses, payment methods and order history. This is the highest
severity item found — priority 2 in the brief's ordering.

`favorites_provider.dart` was already `autoDispose`, so the codebase's own
pattern for per-customer data existed; these providers had simply not followed
it.

### 3.2 `handleSessionExpired` depended on its caller

```dart
void handleSessionExpired() {
  if (!state.authenticated) return;
  state = state.copyWith(authenticated: false);   // token not cleared
}
```

**Not a live bug.** Its only caller, the 401 handler in `di_providers.dart`,
calls `storage.clear()` first. But the method was unsafe standing alone: a
future caller would leave a dead token on disk for `_hydrate()` to trust on the
next cold start, because `_hydrate` treats a stored token as proof of sign-in.

### 3.3 `ref.invalidate` alone does not remove a cached value

Found while testing the logout fix. After `ref.invalidate(profileProvider)` the
state is `AsyncData(isLoading: true, value: <previous>)` — Riverpod keeps the
old value while refetching. A widget rendering `.value`, or `.when` with the
default `skipLoadingOnReload`, still shows the previous customer during the
reload.

Invalidation alone was therefore not sufficient for the data-exposure fix.

---

## 4. Confirmed working, left alone

- **Guest mode.** "Explore as guest" uses `go('/home')` and browsing works
  without a session. Protected actions prompt for login at the point of action
  via the `returnTo` query parameter, which the login and OTP routes already
  accept. No blanket "signed out → login" rule was added, because it would have
  broken this.
- **401 handling.** `apiClientProvider.onUnauthorized` clears the token and
  marks the session expired.
- **Token storage.** Read per request, so a login or logout takes effect
  without rebuilding the client.

---

## 5. Not confirmed

- **Whether the reported back-button symptom is fully explained by the missing
  guard.** The guard makes the state unreachable regardless of how the stack
  got there, so the fix holds either way — but the exact sequence the reporter
  hit was not reproduced on a device.
- **Deep link and notification navigation.** `deviceTokenRegistrarProvider`
  registers a push token, but the tap-handling path was not traced.
- **Checkout, cart, address and payment flows** beyond what earlier work in
  this repo already covered. The silent-failure sweep in section 9 of the brief
  is not complete.
