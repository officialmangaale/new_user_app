# Add Address — implementation summary

## Root cause

The app saved addresses to restaurant-service `/customer-web/addresses`,
placeholder handlers that answer **501** to every save and an empty list to
every read. The 501 was caught, but shown in a snackbar on the page *behind*
the bottom sheet, so the customer saw nothing. Save also waited silently for a
GPS fix first, and caught only API errors. Details: INVESTIGATION.md.

## What changed

### new_user_app

| File | Change |
|---|---|
| `lib/shared/repositories/account_repository.dart` | Address CRUD now calls user-service `/customers/me/addresses`; parses its nested response; model gains `state`, `landmark`, `district`, `locationAccuracyMeters` (all optional); pin sent only as a pair |
| `lib/features/account/address/address_form_sheet.dart` (new) | The Add/Edit sheet: `Form` validation, label chips, explicit GPS pin, pincode helper, deliver-here, in-sheet errors, "Saving…", no double submit, 25 s timeout, returns the saved address |
| `lib/features/account/address/address_form_logic.dart` (new) | Pure validation, error-to-copy mapping, autofill rules |
| `lib/features/account/address/pincode_lookup.dart` (new) | postalpincode.in client: no auth header, 6 s timeout, session cache, never throws |
| `lib/features/account/address/address_location_capture.dart` (new) | One-shot GPS capture with permission, GPS-off and stale-fix handling |
| `lib/features/account/address/address_providers.dart` (new) | Overridable providers |
| `lib/features/account/presentation/addresses_screen.dart` | Uses the new sheet; confirms on the page after the sheet closes; list actions catch every error |
| `lib/features/cart/presentation/cart_screens.dart` | Checkout "Add" opens the sheet in place |
| `lib/features/cart/providers/checkout_view_model.dart` | Requires a saved address; delivers to the address's pin (device location only as fallback; no GPS wait when pinned); landmark fixed |

### user-service (backward compatible, no migration)

| File | Change |
|---|---|
| `repository/customer_repository.go` | `CreateCustomerAddress` / `UpdateCustomerAddress`: write and default-clearing in one transaction; update scoped by `user_id` in SQL |
| `service/customer_service.go` | pin both-or-neither, NaN/∞ rejected, (0,0) stored as no pin; `district` and `location_accuracy_meters` in metadata and in the response; uses the transactional methods |
| `controller/customer_controller.go` | accepts the two new fields; validation errors add `error.details.{field}` (messages unchanged) |

restaurant-service is unchanged. Its `/customer-web/addresses` stubs remain;
nothing in the app calls them now.

## GPS

Only on "Use current location". One fix (high accuracy, 15 s limit). A cached
fix is accepted only if under 2 minutes old. The pin is saved with the address
only on Save. Manual entry never needs permission. Refresh or remove at any
time. No reverse geocoding: the customer always confirms house and area.

## Pincode

postalpincode.in (free India Post data). Debounced, stale responses ignored,
cached per session, 6 s timeout, token never sent. It suggests city (district),
state and post office, and never blocks saving. Recommended later: a
user-service proxy with a shared cache.

## Deploy order

1. **App**: works against the user-service already in production (its
   address endpoints are live). Older servers ignore `district` and
   `location_accuracy_meters`, and the app reads field errors from message
   text when `error.details` is absent.
2. **user-service** (recommended): atomic defaults, stricter pin validation,
   field-level errors, district/accuracy storage.

No migration. No deployment was done.

## Results

- new_user_app: 158 tests pass (45 new). `flutter analyze` clean for changed files.
- user-service: `go vet` clean, all tests pass (11 new test functions).
- Manual device QA: **not done** (no Android SDK or device here). See TEST_PLAN.md.

## Known limitations

- GPS gives a pin, not an address; there is no reverse geocoding by design.
- House and street are stored as one line; editing shows it in the house field.
- The pincode source has no SLA. Failures are non-blocking; heavy traffic
  should go through a backend cache.
- A new_user_app **web** build would need CORS from postalpincode.in
  (unverified); mobile builds are unaffected.
- Checkout now requires a saved address. Customers who ordered with
  "Current location" before will be asked to add one once.
- Accuracy and district are informational; delivery fee and serviceability
  stay server-side.

## Rollback

- App: revert the new_user_app commit. The previous build returns to the 501
  stub, i.e. the original bug.
- user-service: revert the commit. The API contract is a superset; clients
  keep working. No schema to roll back.
