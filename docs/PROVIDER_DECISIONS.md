# YourTaste pilot: payment and shipping provider decisions

**Status: recommendation only. No accounts were created, no paid service was enabled, and no credentials were added.**

## Recommended shortlist

### Payments: evaluate Cashfree Payments Easy Split first; keep Razorpay Route as the alternative

YourTaste is a multi-vendor marketplace, so the requirement is not just collecting a customer's payment. It includes seller onboarding/verification, commission calculations, split settlements, partial/full refunds, seller settlement reporting, reconciliation, and signed webhooks.

- **First evaluation: Cashfree Easy Split.** Its official documentation describes marketplace vendor management, split orders, settlement/reconciliation APIs, and refund handling. Public pricing currently describes a platform fee around 0.20%–0.25% in addition to standard gateway charges, with promotions and eligibility terms that may change. Ask Cashfree to confirm YourTaste's eligibility, exact fee schedule, onboarding requirements, settlement controls, and sandbox support in writing.
- **Alternative: Razorpay Route.** Its official product material describes linked accounts, seller transfers, reversals, settlement controls, and webhook events. Confirm product approval, account eligibility, current fees, settlement/refund semantics, and whether the account configuration fits the intended Indian marketplace model.
- **Decision gate:** do not select based on headline pricing alone. Compare the written commercial offer, seller KYC/onboarding, marketplace approval, settlement timing, refund/reversal behaviour, support SLAs, and legal/compliance requirements. Do not accept live payments until those checks and sandbox tests pass.

Official references:
- Cashfree Easy Split overview: https://www.cashfree.com/docs/api-reference/payments/latest/split/easy-split-overview
- Cashfree Easy Split product/pricing: https://www.cashfree.com/easy-split/split-payment-gateway/
- Cashfree gateway pricing and terms: https://www.cashfree.com/payment-gateway-charges/
- Razorpay Route: https://razorpay.com/route/
- Razorpay Route API docs: https://d6xcmfyh68wv8.cloudfront.net/docs/api/payments/route/

### Shipping: evaluate Shiprocket first; keep Delhivery direct API as the alternative

- **First evaluation: Shiprocket.** Its API surface covers order creation, courier/serviceability, shipment labels/manifests, tracking, returns/exchanges, and webhooks. This is a useful breadth for a small pilot that needs to compare courier options without building separate carrier integrations immediately.
- **Alternative: Delhivery direct integration.** Its official B2C developer portal documents pincode serviceability, shipment creation/cancellation, cost estimates, labels, tracking, pickup requests, and status webhooks. Evaluate direct integration if commercial terms, pickup coverage, or operational control are better.
- **Pilot approach:** keep shipping manual in the first internal/pilot phase if that avoids paid commitments. Store carrier and tracking fields only after the operational workflow is tested. Do not create live shipments or buy labels during staging tests.

Official references:
- Shiprocket API docs: https://apidocs.shiprocket.in/?version=latest
- Shiprocket developer portal: https://sr-website.shiprocket.in/developers/
- Delhivery B2C developer portal: https://one.delhivery.com/developer-portal/documents/b2c/

## Provider-neutral architecture requirements

1. Keep provider secrets server-side only. Never prefix private keys with `NEXT_PUBLIC_`, commit them, or send them to the browser/mobile app.
2. Use a provider adapter boundary; the order model must not depend on a provider's raw status names.
3. The browser asks the server to create a payment session for an already-created pending-payment order. Server-side amount and currency come from the order database, never the client.
4. Verify webhook signatures against the raw request body, reject invalid signatures, and store provider event IDs with a unique constraint before applying state changes.
5. Make webhook processing idempotent and monotonic. A duplicate event must not duplicate an order, stock movement, seller transfer, refund, or notification.
6. A client redirect or success screen is not proof of payment. Only a verified provider webhook or server-to-server status verification can mark payment captured.
7. Handle late success after stock reservation expiry, failed/duplicate events, partial refunds, chargebacks/disputes, reconciliation gaps, and seller payout reversals.
8. Split one customer order into vendor-specific fulfilment/settlement records where needed; do not assume one shipment or one seller per order.
9. Keep provider configuration disabled by default in staging. Test mode requires explicit environment configuration; production mode must fail closed unless separately approved.
10. Before production, complete provider sandbox testing, finance reconciliation, seller terms, tax/invoice review, support and refund procedures, and explicit business-owner approval.

## Pilot rollout

- **Stage A — internal staging:** fake catalogue data, no real customer data, no live provider keys, no charges or shipments.
- **Stage B — controlled private pilot:** only after authorization and end-to-end tests pass; use provider sandbox and manual fulfilment while validating operations.
- **Stage C — limited real orders:** requires explicit owner approval, provider approval, legal/tax review, monitoring, incident/rollback drills, and tested refunds. This stage is not authorized by the current decision.
