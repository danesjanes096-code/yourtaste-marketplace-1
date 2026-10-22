# Staging acceptance plan

Use synthetic accounts and test payment credentials only. Never use real customer data or live payment keys in staging.

## Identity and access

- [ ] New signup creates exactly one customer profile; submitted metadata cannot set role.
- [ ] Email confirmation and callback work; invalid/expired code fails safely.
- [ ] Unauthenticated users cannot access account, seller, or admin routes.
- [ ] Customers cannot read/update other customers' profiles, addresses, orders, or payments.
- [ ] Sellers cannot alter their role, commission, approval status, or publish products without review.
- [ ] Non-admin users cannot call moderation RPCs even if they bypass the UI.

## Catalogue

- [ ] Anonymous visitors see only products with published status, approved vendor, and active category.
- [ ] Search, sort, pagination, invalid parameters, empty results and provider errors are handled.
- [ ] Product images are validated and upload paths are not executable content.

## Checkout

- [ ] Checkout requires authenticated customer and their own saved address.
- [ ] Prices are read from the database; client-submitted prices are ignored.
- [ ] Duplicate lines, invalid quantities, unavailable products and insufficient stock fail safely.
- [ ] Same idempotency key and same request returns the original order; changed request returns conflict.
- [ ] Concurrent checkout cannot oversell stock.
- [ ] Expired unpaid orders release stock exactly once.
- [ ] Payment success, duplicate webhook, invalid signature, late success, refund and reconciliation paths are tested in sandbox.

## Release and recovery

- [x] `npm run verify:source`, `npm run typecheck`, and `npm run build:web` pass in GitHub Actions on the current commit. See the [CI run](https://github.com/danesjanes096-code/yourtaste-marketplace-1/actions).
- [x] All twelve timestamped migrations are recorded on staging; `supabase/tests/security_smoke.sql` passes against the live staging catalog.
- [x] Replay all twelve migrations from an empty local Supabase/PostgreSQL 17 database in GitHub Actions; both `security_smoke.sql` and `authz_function_guards.sql` pass ([successful main replay](https://github.com/danesjanes096-code/yourtaste-marketplace-1/actions/runs/39812396713)).
- [ ] Apply the migration chain to a fresh disposable hosted project and review a full schema diff against staging.
- [ ] Backup restoration and deployment rollback are rehearsed.
- [ ] Error alerts, uptime checks and operational runbook are verified.
- [ ] Android/iOS builds are installed and tested on real devices.
