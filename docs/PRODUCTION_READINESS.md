# Production readiness gates

**Current status: not production-ready.** The repository is being reconciled with the staging implementation. Do not process real customer orders or payments with this version.

## Release blockers

- [x] Publish and align the twelve timestamped migration files with the staging migration history.
- [x] Commit a reproducible npm workspace lockfile and upgrade web/mobile framework dependencies; clean install, ESLint, typecheck, web build, Expo Doctor, and Android bundle export pass on main ([CI run](https://github.com/danesjanes096-code/yourtaste-marketplace-1/actions/runs/39812396931)).
- [x] Replay all migrations from an empty local Supabase/PostgreSQL 17 database and execute both committed SQL security tests ([database replay run](https://github.com/danesjanes096-code/yourtaste-marketplace-1/actions/runs/39812396713)).
- [x] Exercise actual local Auth-signed JWTs through PostgREST for customer address ownership, direct-write restrictions, anonymous checkout denial, and non-admin moderation denial ([local authorization run](https://github.com/danesjanes096-code/yourtaste-marketplace-1/actions/runs/39813361026)); hosted staging authorization tests remain open.
- [ ] Reconcile all web/mobile source against staging behavior.
- [ ] Compare the fully migrated schema against hosted staging; local replay is complete, but a separate hosted disposable-project schema diff has not been run.
- [ ] Complete automated unit, integration, RLS/authorization, API, and end-to-end tests.
- [x] Run the staging security/schema smoke test for RLS coverage, checkout request grants, private helper grants, privileged function search paths, 14 foreign-key indexes, and consolidated policy counts.
- [ ] Complete hosted-staging JWT authorization tests and resolve or explicitly accept the remaining five Supabase SECURITY DEFINER advisor findings after code review.
- [ ] Test Auth callbacks, email verification, password reset, abuse controls, and account recovery.
- [ ] Implement payment-provider order creation, signed webhook verification, idempotent capture/refund handling, reconciliation, and late-payment behavior in sandbox.
- [ ] Schedule and monitor expiry of stock reservations.
- [ ] Implement shipping, tax, invoices, cancellation/returns, customer support, and transactional email.
- [ ] Configure image storage, upload validation, moderation, backups, retention, and restore drills.
- [ ] Add structured logs, error tracking, uptime monitoring, alerting, abuse controls, and an incident response runbook.
- [ ] Test performance, accessibility, privacy, and security with realistic staging data.
- [ ] Configure separate production secrets/domain and ensure no secrets or customer data enter Git history.
- [ ] Complete Android/iOS signing, device tests, store compliance, privacy disclosures, and release procedures.
- [ ] Obtain India-specific legal/business review for seller terms, consumer protection, tax/GST, privacy, and marketplace obligations.
- [ ] Complete staging acceptance tests and rollback rehearsal; obtain explicit launch approval.

## Secrets

Never commit `.env` files, Supabase service-role keys, payment secrets, webhook secrets, or customer data. Client apps may use only the public Supabase URL and publishable/anon key with correctly enforced RLS.

## Payments

No live payment integration is enabled. Never use live payment credentials until signed webhooks, idempotency, refunds, reconciliation, late/duplicate events, and failure recovery are tested end to end.


See also the [private pilot release gates](PRIVATE_PILOT_RELEASE_GATES.md) and [payment/shipping provider evaluation](PROVIDER_DECISIONS.md).
