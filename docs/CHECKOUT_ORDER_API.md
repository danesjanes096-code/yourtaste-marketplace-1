# Checkout order API

`POST /api/checkout/orders`

This endpoint creates a pending-payment order and reserves inventory. **It does not charge a payment method.** Do not use it as a live checkout flow.

## Request

Send authenticated JSON with `addressId`, `items` (1–30 entries, each containing `productId` and `quantity` from 1–20), and an `idempotencyKey` (16–128 safe ASCII characters). The address must belong to the signed-in user.

## Server guarantees

- The server verifies the Supabase user.
- Database RPC reads current product prices and checks publication, vendor/category status, and available stock.
- Duplicate product lines are rejected.
- Repeating an idempotency key with the same canonical request reuses the original order; reusing it with a different request returns a conflict.
- Stock reservation expires after 15 minutes; a trusted scheduled worker must execute `release_expired_order_reservations()` using service-role credentials.

## Not implemented

No payment provider, signed payment webhook, payment capture/refund flow, tax calculation, shipping quote, or order notification is wired in this repository. Do not enable live payments until these are built and tested, including late and duplicate payment events.
