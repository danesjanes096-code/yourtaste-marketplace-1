# YourTaste implementation plan

## Phase 1 — Source of truth and CI

- [x] Initialize GitHub repository and basic CI workflow.
- [x] Publish initial responsive storefront and mobile shell.
- [x] Publish initial Supabase schema/RLS and checkout/order migrations.
- [ ] Reconcile every file with the staging workspace and pin dependency versions.
- [x] Require clean-checkout CI for source verification, dependency audit policy, security tests, ESLint, TypeScript typecheck, Next.js production build, Expo Doctor, and Android bundle export.
- [x] Commit the npm workspace lockfile and add a tested dependency-audit policy. Two upstream-unpatched high-severity advisories in transitive build tooling are narrowly allowlisted and documented.
- [x] Replay all twelve migrations from an empty local Supabase/PostgreSQL 17 database and run the SQL security/schema and privileged-function guard tests in CI; hosted disposable-project schema comparison remains open.
- [x] Document provider shortlist for a future pilot: Cashfree Easy Split first to evaluate, Razorpay Route alternative; Shiprocket first to evaluate, Delhivery alternative. No provider account or paid service was enabled.

## Phase 2 — Identity and access

- [ ] Verify Supabase Auth email confirmation and redirect URLs in staging.
- [x] Review profile bootstrap trigger, role changes, seller access and admin bootstrap design; runtime authorization tests remain open.
- [ ] Test every RLS policy as anon, customer A/B, seller A/B, and admin.
- [x] Add and run a staging catalog smoke test for RLS coverage, checkout idempotency-table grants, private helper grants, and privileged function search paths.
- [ ] Add password reset and abuse/rate-limit protections.

## Phase 3 — Catalogue and sellers

- [ ] Complete live catalogue browsing, category/search/pagination and image storage.
- [ ] Finish seller application and product draft flows with server/database validation.
- [ ] Complete moderation audit trail and vendor/product state transitions.
- [ ] Add image validation, upload limits and content moderation.

## Phase 4 — Checkout and fulfilment

- [ ] Finish cart and checkout UX with server-authoritative prices.
- [ ] Integrate payment provider in sandbox; verify webhook signatures and event idempotency.
- [ ] Test stock reservations, expired orders, duplicate/late payment events and refunds.
- [ ] Add shipping quotes, tax/GST calculation, invoices, cancellations and returns.
- [ ] Schedule reservation cleanup using a trusted service-role job and alert on failures.

## Phase 5 — Mobile and operations

- [ ] Integrate mobile auth, persistent cart, checkout and order history.
- [ ] Configure app signing, privacy disclosures, Android/iOS device testing and store submissions.
- [ ] Add logs, monitoring, error reporting, backups, restore drills and rollback documentation.
- [ ] Complete accessibility, load, security and privacy reviews.

## Phase 6 — Launch decision

Launch only when all release blockers in `PRODUCTION_READINESS.md` are closed and the business owner explicitly approves production rollout. A passing build alone is not a launch sign-off.
