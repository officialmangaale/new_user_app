# new_user_app — Manual QA Checklist

The fixes in [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) are covered
by unit tests, but **no device or emulator run was possible in this
environment** — there is no Android SDK installed. Nothing below has been
observed. This is the list to work through on a real build.

Record for each session: device, OS version, build mode (debug/profile/release),
and environment (staging/prod).

```
Device: ______________  OS: ________  Build: ________  Env: ________
```

---

## A. The reported bug

The fix targets these two screens specifically.

- [ ] Fresh install → splash → **Welcome** appears
- [ ] "Continue with mobile number" → enter number → OTP → verify
- [ ] Land on Home
- [ ] **Press Android back once.** Expected: app minimises or exits.
      **Must not** show Login or Welcome.
- [ ] Press back repeatedly. Login and Welcome never appear.
- [ ] Repeat with the gesture back (swipe from edge) on a gesture-nav device
- [ ] Repeat from a nested screen: Home → Restaurant → back → Home, not Login

## B. Sign-in variants

- [ ] **New customer**: after OTP, lands on **`/setup`** (profile setup), not Home
- [ ] From `/setup`, back does not reveal Login
- [ ] **Returning customer**: after OTP, lands on Home, skipping `/setup`
- [ ] **Login started from checkout**: add to cart as guest → checkout → prompted
      to log in → after OTP, returns to **checkout**, not Home
      *(this is why `/otp` is deliberately not guarded — worth confirming)*

## C. Guest mode

- [ ] "Explore as guest" → Home, browsing works
- [ ] Back from guest Home behaves as before this change (exits)
- [ ] A protected action still prompts for login at the point of action
- [ ] After logging in from that prompt, the intended action resumes

## D. Restart and session restore

- [ ] Sign in, kill the app, reopen → lands on Home, still signed in
- [ ] Guest, kill, reopen → guest browsing, no forced login
- [ ] Airplane mode, reopen while signed in → no login screen flash
      *(the `sessionLoaded` guard is meant to prevent this)*

## E. Logout and account switching — the data-exposure fix

The most important section. Use **two different accounts** with clearly
different data: different name, different saved address, different order
history, different wallet balance.

- [ ] Sign in as **A**. Visit Profile, Addresses, Orders, Wallet — note the values.
- [ ] Log out. Confirm you land on the unauthenticated entry.
- [ ] Press back. Login/Welcome is fine here; Home must **not** reappear.
- [ ] Sign in as **B**.
- [ ] Profile shows **B's** name and phone — never A's, not even for a frame
- [ ] Addresses shows **B's** addresses only
- [ ] Orders shows **B's** history only
- [ ] Wallet shows **B's** balance
- [ ] Payment methods show B's only
- [ ] Repeat the A → B switch **without** killing the app in between

## F. Forced logout

- [ ] Sign in, then invalidate the token server-side (or wait for expiry)
- [ ] Trigger any authenticated request
- [ ] The app routes to login rather than showing a broken screen
- [ ] Kill and reopen → still signed out, **not** silently signed back in
      *(a stale token on disk would cause this)*
- [ ] Sign in as a different account → no data from the expired session

## G. Regression — flows that must be unaffected

- [ ] Browse restaurants, search, category, item detail
- [ ] Add to cart, change quantity, remove
- [ ] Select address, select COD, place order
- [ ] Order success → back does **not** return to a resubmittable payment form
- [ ] Track an order; status updates arrive
- [ ] Favorites, wallet, referral screens load
- [ ] Notification tap while signed in, and while signed out

## H. Not covered by this work

Listed so they are not mistaken for verified:

- [ ] Deep link / notification navigation authorization re-check
- [ ] Silent-failure audit of every primary action (section 9 of the brief)
- [ ] Cart contents and open sockets across an account switch
