# Address API contracts

## Before → after (app)

| Action | Before (restaurant-service, stub) | After (user-service) |
|---|---|---|
| List | GET `/customer-web/addresses` → always `[]` | GET `/customers/me/addresses` |
| Create | POST `/customer-web/addresses` → 501 | POST `/customers/me/addresses` → 201 |
| Update | PATCH `/customer-web/addresses/:id` → 501 | PATCH `/customers/me/addresses/:id` |
| Delete | DELETE `/customer-web/addresses/:id` → 501 | DELETE `/customers/me/addresses/:id` |
| Default | PATCH `/customer-web/addresses/:id/default` → 501 | POST `/customers/me/addresses/:id/default` |

Auth: `Authorization: Bearer <customer JWT>`. The owner is always the token's
user; the body has no user field, and one sent is ignored.

## Request (POST / PATCH)

```json
{
  "label": "Home",
  "address_line1": "108, Sector 49",
  "area": "Sector 49",
  "landmark": "Opposite the park",
  "city": "Gurgaon",
  "state": "Haryana",
  "district": "Gurgaon",
  "pincode": "122003",
  "is_default": true,
  "latitude": 28.4089,
  "longitude": 77.0532,
  "location_accuracy_meters": 25
}
```

- `address_line1` is house/flat/floor and street/building joined by the app
  (the table has one line).
- The pin is optional and is sent **only as a pair**. The app omits all three
  location fields when there is no pin.
- `district` and `location_accuracy_meters` are new and optional. They are
  stored in `metadata` (no migration). Older servers ignore them.
- `is_default` true ("Deliver my orders here") clears the user's other
  defaults in the **same transaction** as the write.

Server validation (user-service):

| Rule | Status | `message` | `error.details` |
|---|---|---|---|
| address_line1 empty | 400 | `address_line1 is required` | `{"address_line1": …}` |
| pincode not 6 digits (when sent) | 400 | `valid pincode is required` | `{"pincode": …}` |
| latitude outside ±90 / NaN / ∞ | 400 | `valid latitude is required` | `{"latitude": …}` |
| longitude outside ±180 | 400 | `valid longitude is required` | `{"longitude": …}` |
| only one of latitude/longitude | 400 | `latitude and longitude must be sent together` | `{"latitude": …}` |
| exactly (0, 0) | — | stored as **no pin** (not rejected) | — |
| accuracy ≤ 0, > 100 km, NaN | — | dropped (diagnostic only) | — |
| not signed in | 401 | `unauthenticated` | — |
| other user's address | 403 | `forbidden` | — |

`message` strings are unchanged from before, so older clients are unaffected;
`error.details` is additive.

## Response

```json
{
  "status": "success",
  "statusCode": 201,
  "message": "address created",
  "data": {
    "address": {
      "address_id": "…uuid…",
      "label": "Home",
      "name": "", "phone": "9876…",
      "address_line1": "108, Sector 49",
      "area": "Sector 49", "landmark": "Opposite the park",
      "city": "Gurgaon", "state": "Haryana", "district": "Gurgaon",
      "pincode": "122003",
      "latitude": 28.4089, "longitude": 77.0532,
      "location_accuracy_meters": 25,
      "is_default": true
    }
  }
}
```

The list returns `data.addresses: [...]` with the same objects.

## Pincode lookup (third party, from the app)

`GET https://api.postalpincode.in/pincode/{pin}`, sent **without** the
customer's token (separate HTTP client), 6 s timeout, cached per session.

```json
[{"Status":"Success","PostOffice":[{"Name":"Jharsa","District":"Gurgaon","State":"Haryana","Block":"NA","DeliveryStatus":"Delivery"}]}]
[{"Status":"Error","Message":"No records found","PostOffice":null}]
```

Used only to suggest city (district), state and post offices. It never
blocks saving and never supplies coordinates. Evaluated 2026-09-11: HTTPS,
1.3–1.9 s, no published SLA or rate limit. A user-service proxy with a shared
cache is the recommended next step before heavy traffic.

## Order placement (unchanged API, changed values)

The checkout still sends the address fields and `delivery_latitude/longitude`
to restaurant-service. Now:

- the coordinates are the **selected address's pin** when it has one, and the
  device location only when it does not;
- `delivery_landmark` is the landmark, not the area;
- no order is sent without a saved address.

Serviceability and fees remain server-side (restaurant-service rejects
out-of-radius orders; the app shows its message).
