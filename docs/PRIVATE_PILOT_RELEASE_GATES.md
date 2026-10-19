# YourTaste private pilot and release gates

This checklist is the release control for the current private-pilot approach. A checkbox is not complete unless there is a repeatable test or recorded evidence.

## Non-negotiable staging safety

- [x] No live payment provider is integrated or enabled.
- [x] No provider account, paid plan, domain, or hosting change was initiated by this implementation work.
- [ ] Confirm staging environment variables contain only the Supabase public URL and publishable/anon key; verify no service-role/payment/shipping secrets are exposed to web or mobile builds.
- [ ] Use clearly marked synthetic products/users/addresses for staging; remove any accidental real customer data.
- [ ] Keep provider mode disabled unless explicit sandbox-only credentials and configuration are supplied by the owner.
- [ ] Never run a live shipment, capture, payout, refund, or paid label from staging.

## Gate 1 — code and supply chain

- [x] GitHub Actions source verification, TypeScript typecheck, and Next.js production build pass on the current recorded run.
- [x] Commit a reproducible npm workspace lockfile and pass CI with `npm ci`, source verification, security tests, typecheck, and production build.
- [ ] Add dependency vulnerability scanning and secret scanning; review advisories before upgrades.
- [ ] Run the full source verification from a clean checkout and verify no secrets or local artifacts are committed.

## Gate 2 — identity and authorization

- [x] Staging security/schema smoke test checks RLS coverage, client privileges on checkout idempotency records, helper grants, SECURITY DEFINER search paths, index coverage, and selected policy counts.
- [x] Staging SQL guard test rejects unauthenticated checkout/address RPCs and non-admin moderation calls using simulated JWT subject claims (`supabase/tests/authz_function_guards.sql`).
- [ ] Run `npm run test:staging-authz` with two real staging customer JWTs and known synthetic customer-A address/order IDs. The script refuses any URL except the approved staging project and never creates an order.
- [ ] Extend the staged JWT run to seller A, seller B, and admin after synthetic seller/product fixtures exist; SQL claim simulation is not a substitute.
- [ ] Confirm real non-admin JWTs cannot invoke moderation RPCs successfully, even with forged product/vendor IDs.
- [ ] Confirm address/order ownership cannot be bypassed by changing IDs.
- [ ] Test signup, email confirmation, login, logout, session expiry, password reset, and redirect allowlists.
- [ ] Add rate limiting and abuse protection to auth, checkout, seller application, product submission, and upload flows.
- [ ] Review and close/justify Supabase security advisor warnings for the five SECURITY DEFINER RPCs.

## Gate 3 — catalogue and seller operations

- [ ] Verify search/category/pagination and published-only catalogue visibility against staging data.
- [ ] Validate seller onboarding and approval/rejection; prevent suspended/unapproved sellers from publishing or fulfilling orders.
- [ ] Test product draft/edit/review/rejection/archival, price/stock validation, and audit records.
- [ ] Add protected image storage, MIME/type/size validation, upload limits, and removal controls.
- [ ] Test empty/error/loading states and keyboard/accessibility basics.

## Gate 4 — checkout and payment lifecycle

- [ ] Verify server-authoritative prices, address ownership, duplicate line rejection, stock reservation and expiration.
- [ ] Test idempotent repeated requests, same key/different payload, stock races, and order creation failures.
- [ ] Choose and approve a payment provider only after reviewing the written commercial and compliance terms in `PROVIDER_DECISIONS.md`.
- [ ] Implement sandbox payment creation, signed webhook verification, event-id uniqueness, and server-to-server payment verification.
- [ ] Test duplicate, delayed, out-of-order, invalid-signature, failed, and late-success webhook events.
- [ ] Test full/partial refunds, payment reconciliation, stock restoration, seller settlement reversals, and support escalation.
- [ ] Keep payment mode disabled until every preceding check passes and the owner explicitly approves.

## Gate 5 — shipping, tax and customer operations

- [ ] Decide whether the pilot uses manual shipping or a shipping API; evaluate Shiprocket and Delhivery terms first.
- [ ] Test multi-vendor orders, split fulfilment, cancellation, tracking, return pickup, failed delivery, and damaged/wrong-item support.
- [ ] Confirm tax/GST, invoices, pricing disclosures, seller commission, refund, cancellation, and consumer-protection requirements with qualified advisors.
- [ ] Add transactional email/SMS only after provider, consent, template, and cost decisions are approved.
- [ ] Publish support contacts, response targets, return/refund policy, seller terms, and privacy notice before taking real orders.

## Gate 6 — operations and release

- [ ] Configure the owner's existing domain/hosting only after they provide the target hostname and grant the minimum required access; do not alter DNS during staging.
- [ ] Configure TLS, production/staging separation, least-privilege secrets, logs, uptime/error alerts, and security event monitoring.
- [ ] Test database backup restoration, incident response, rollback, and reservation-cleanup scheduling.
- [ ] Complete Android/iOS device tests and release signing before any public mobile launch.
- [ ] Run an end-to-end acceptance test and record evidence for each gate.
- [ ] Obtain explicit owner approval for a limited real-order launch; the current authorization is staging/private pilot only.

## Current known blockers

- Supabase security advisor reports five callable SECURITY DEFINER functions. Their function bodies include checks, but these must be tested with real JWT identities and reviewed rather than waived automatically.
- The real-JWT staging suite is committed but not run yet; it requires synthetic staging accounts, customer-A address/order UUIDs, and their short-lived JWTs in the local shell environment.
- Fresh disposable-project migration replay and full schema diff are outstanding.
- Payment, shipping, tax/GST, notifications, monitoring, backup/restore, and production hosting are not finished.
