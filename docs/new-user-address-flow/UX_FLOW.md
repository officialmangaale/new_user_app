# Address UX flow

```
Saved addresses ──Add address──▶ Address sheet ──Save──▶ sheet closes
                                     │                     ├─ list refreshes
Checkout (no address) ──Add──────────┘                     └─ "Address saved. Delivering here."
```

## The sheet (`lib/features/account/address/address_form_sheet.dart`)

1. **Pin your location (optional)**: "Use current location". Permission is
   requested only on this tap. It takes one fix, with no tracking. The customer
   still fills the address; GPS gives coordinates, not a house number, because
   no reverse geocoding is used.
2. **Save as**: Home · Work · Other (Other asks for a label).
3. House / flat / floor · Street / building (optional) · Area / locality ·
   Landmark (optional).
4. **Pincode**: after 6 digits and a 400 ms pause, a lookup suggests city and
   state and lists post offices. Choosing one fills an empty Area.
5. City · State (auto-filled only if empty or still holding an earlier
   suggestion; never overwrites typing).
6. **Deliver my orders here**: on by default. It makes the address the
   default, which is what checkout uses.
7. **Save address** / **Saving…**

## States

| State | What the customer sees |
|---|---|
| Initial | Empty form, Home selected, "Pin your location (optional)" |
| Getting location | Spinner, "Getting your current location…" |
| Location pinned | "Location pinned · Accurate to about 25 m", Refresh / Remove pin |
| Permission denied | "Location permission is off. You can still enter your address manually." |
| Permanently denied | "…blocked. Allow it in Settings…" + **Open settings** |
| GPS off | "Turn on device location to use current location." + **Turn on location** |
| No fix | "Could not get your location. Try again, or enter your address manually." |
| Refresh failed | Old pin kept; the reason shown under it |
| Pincode loading | "Looking up pincode…" |
| Pincode found | "Gurgaon, Haryana" + post-office chips |
| Pincode not found | "We could not find this pincode. Check it, or continue manually." |
| Pincode lookup failed | "Could not fetch pincode details. You can continue manually." |
| Saving | Button "Saving…" with spinner, disabled; fields disabled |
| Save success | Sheet closes; page snackbar; list refreshed |
| Field error (local or server) | Message under the field |
| Server / network error | Red banner inside the sheet; Save enabled again |
| Timeout (25 s) | "Saving is taking longer than expected. Please try again." |
| Session expired | "Please log in again to save your address." |

## Copy

| Case | Message |
|---|---|
| Empty label (Other) | Please enter an address label. |
| Empty house | Please enter your house, flat or street details. |
| Empty area | Please enter your area or locality. |
| Bad pincode | Please enter a valid 6-digit pincode. |
| No connection | No internet connection. Check your connection and try again. |
| Any other failure | We could not save your address right now. Please try again. |

## Checkout

- **No saved address**: the address card shows **Add**, which opens the same
  sheet in place. After saving, the card shows "Deliver to Home".
- **Has addresses**: **Change** opens Saved addresses, where "Set as delivery
  address" selects another.
- **Place order** without a saved address: "Add a delivery address to place
  your order."
- **Address without a pin and location off**: "Pin this address so your rider
  can find you: edit it and tap "Use current location", or turn on location."
