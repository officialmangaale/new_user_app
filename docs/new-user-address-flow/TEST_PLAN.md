# Test plan

## Automated

### new_user_app — `flutter test` → 158 passed, 0 failed (45 new)

| File | Covers |
|---|---|
| `test/features/account/address_form_logic_test.dart` (16) | field copy; pincode rules; line composition; pin validity incl. (0,0); every error type → a message (timeout, offline, 401, field errors, unknown); autofill never overwrites typing; post-office parsing, not-found vs failure |
| `test/features/account/address_repository_test.dart` (7) | **regression for the root cause**: save posts to user-service `/customers/me/addresses`, never the restaurant stub; nested response parsed; no coordinates sent without a pin; list from user-service; server field error preserved; pincode lookup sends **no Authorization header**, caches, does not cache failures |
| `test/features/account/address_form_sheet_test.dart` (16) | empty form shows errors and sends nothing; short pincode; Other needs a label; **Saving… + disabled + double tap sends once + sheet closes with the saved address**; manual save with no GPS use; server field error on the field; network error banner + retry; 25 s timeout; 401; location denied → manual save; GPS off → settings; captured pin saved with accuracy; pincode fills city/state/post office; waits for 6 digits; failed lookup never blocks save; **Saved addresses: new address appears, list refetched, confirmation shown** |
| `test/features/cart/checkout_address_test.dart` (6) | pinned address delivered to its own pin (not the phone) with no GPS wait; landmark sent as landmark; no pin → phone location; no pin + no location → blocked; no saved address → blocked; "deliver here" address is the one ordered to |

`flutter analyze`: no issues in changed files. Pre-existing notes remain in
untouched files (unused imports in `content_provider.dart`,
`favorites_provider.dart`, lint option in `analysis_options.yaml`, and infos).

### user-service — `go test ./...` → all pass (11 new test functions)

| File | Covers |
|---|---|
| `service/customer_address_test.go` | create with pin stores lat/lng + district + accuracy; old payload without pin still works; default toggled in one transaction; rollback when the insert fails (no silent success); invalid pincode / lat / lng / half pair rejected before any write; editing another user's address forbidden; coordinate sanitising; accuracy sanitising |
| `controller/customer_address_test.go` | auth required; `user_id` in the body ignored (owner from token); validation errors keep their message and name the field |

## Manual QA (Android device)

Not performed in the authoring environment (no Android SDK or device).
Run against a build pointing at production user-service:

- [ ] Fresh login → Saved addresses → Add address → fill manually → Save →
      sheet closes, "Address saved. Delivering here.", address listed.
- [ ] Add with **Use current location** (grant) → "Location pinned" → Save.
      Read-only check: `SELECT latitude, longitude FROM user_addresses WHERE id = '<id>'`.
- [ ] Deny the permission → message shown → save manually works.
- [ ] Turn GPS off → **Use current location** → "Turn on device location…" →
      **Turn on location** opens settings.
- [ ] Pincode **122003** → "Gurgaon, Haryana", post offices listed; pick one.
- [ ] Pincode **12200** → "Please enter a valid 6-digit pincode." on save.
- [ ] Airplane mode → Save → "No internet connection…" inside the sheet.
- [ ] Expired session → "Please log in again to save your address."
- [ ] Edit an address, change the label → Update → list updated.
- [ ] Delete an address → removed.
- [ ] Empty cart address → Checkout **Add** → save → card shows "Deliver to
      Home" → place order → restaurant sees that address and the rider gets
      its pin (`orders.delivery_latitude`).
- [ ] Web client (food.mangaale.com) still lists and saves addresses.
