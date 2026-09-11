# Add Address — investigation

Date: 2026-09-11. Reproduced by code trace, read-only database queries and
unauthenticated HTTP probes. No data was written.

## Symptom

On Saved Addresses → Add address, the customer fills the form and taps
**Save address**. Nothing visibly happens: no success, no error, no redirect.

## Root cause

Three defects together.

### 1. The app saved to a stub that can never succeed — primary cause

`AccountRepository` (`lib/shared/repositories/account_repository.dart`) called
restaurant-service `POST /customer-web/addresses`. In restaurant-service those
handlers are placeholders (`controller/customer_web_extended.go`):

```go
func (cc *CustomerWebController) AddAddress(c *gin.Context) {
    ...
    utils.SendError(c, http.StatusNotImplemented, "saved address storage is not configured", ...)
}
func (cc *CustomerWebController) GetAddresses(c *gin.Context) {
    ... "addresses": []gin.H{}, "storage_configured": false ...
}
```

Every save answered **501**; every list answered **[]**; update, delete and
set-default were 501 too. The real address book is in **user-service**
(`/customers/me/addresses`, table `user_addresses`), which the web client
(`food-order-web/src/services/profileApi.ts`) already uses. The app's own
`ApiClient` already had a `user` Dio for it.

### 2. The error was shown where it could not be seen

`_AddressEditor._save` (`addresses_screen.dart`) caught the 501 and called
`ScaffoldMessenger.of(context).showSnackBar(...)` from **inside the modal
bottom sheet**. That messenger belongs to the page underneath, so the snackbar
rendered behind the sheet. The spinner stopped and the sheet stayed open.

### 3. Save first waited for GPS, and only API errors were caught

Before calling the API, `_save` awaited `LocationService().current()`: a
permission prompt and up to 12 s for a GPS fix, with nothing on screen. The
catch handled only `ApiException`; anything else (a parse error, a
`LocationException`, a `StateError`) escaped with the spinner still showing.

## Traced path (before)

| Step | Where | Finding |
|---|---|---|
| Saved addresses screen | `lib/features/account/presentation/addresses_screen.dart` `AddressesScreen` | list from `addressesProvider` (always empty) |
| Add address sheet | same file, `_openEditor` → `_AddressEditor` | `TextField`s, no `Form`, no field validation except house |
| Form state | `_AddressEditorState` controllers | label/line1/area/city/pincode/isDefault |
| Save handler | `_AddressEditorState._save` | GPS fix first, then API; catches `ApiException` only |
| API client | `AccountRepository.addAddress` | restaurant-service `/customer-web/addresses` (stub) |
| Backend | restaurant-service `AddAddress` | always 501 |
| Response parse | `CustomerAddress.fromJson(unwrapApiObject(...))` | never reached |
| UI update | snackbar via page messenger | hidden behind the sheet |
| List refresh | `ref.invalidate(addressesProvider)` | only after success, which never happened |
| Checkout | `CheckoutViewModel._readDefaultAddress` | always null → every order was "Current location" |

## The real API (user-service)

- Routes: `routes/user.go` `/customers/me/addresses` (GET, POST, PATCH `:addressId`,
  DELETE, POST `:addressId/default`), behind `AuthRequired` + `CustomerOnly`.
  The app's token comes from `/customers/auth/verify-otp`, role `customer`.
- Handlers: `controller/customer_controller.go`. Service:
  `service/customer_service.go` (`CreateCustomerAddress` …). Repository:
  `repository/user_repository.go`, `customer_repository.go`.
- Validation already present: address line required, pincode 6 digits (if
  sent), lat/lng range, phone. The owner comes from the token only.
- Table `user_addresses` (production, read-only check): `latitude numeric(10,8)`,
  `longitude numeric(11,8)`, `state`, `pincode`, `is_default`, `metadata jsonb`
  (name, phone, area, landmark). 6 rows, 4 with coordinates, 0 half-pairs, 0 at (0,0).
- Gaps found:
  - A default address was created, then other defaults cleared, in **two
    statements**. A failure between them returned 500 for a saved address.
  - Latitude without longitude was accepted.
  - Errors carried no field name.

## Checkout findings

`CheckoutViewModel.placeOrder` (`lib/features/cart/providers/checkout_view_model.dart`):

- The delivery pin was `device location ?? address pin`. An order to "Home"
  placed from the office was pinned at the office.
- `deliveryLandmark` was filled with the **area**.
- It allowed a "Current location" order with no house or flat number.

## Tests before

`test/features/account/profile_*`, `test/features/cart/place_order_test.dart`.
No address tests.
