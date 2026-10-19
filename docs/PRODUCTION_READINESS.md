# Production readiness gates

**Current status: not production-ready.** The public repository is currently an initial scaffold, not the full staging implementation. Do not use it to process real customer data or payments.

## Release blockers

- [ ] Publish and review the full web, mobile, API, and Supabase migration source from the staging foundation.
- [ ] Verify migration files match the live staging schema and apply cleanly to a fresh disposable Supabase project.
- [ ] Complete automated unit, integration, RLS/authorization, API, and end-to-end tests.
- [ ] Complete independent review of all RLS policies, SECURITY DEFINER functions, grants, and service-role usage.
- [ ] Connect and test Supabase Auth callbacks, email verification, password reset, rate limiting, and account recovery.
- [ ] Implement payment-provider order creation, signed webhook verification, idempotent capture/refund handling, reconciliation, and late-payment behavior in sandbox.
- [ ] Implement trusted scheduled release of expired stock reservations and monitor job failures.
- [ ] Implement shipping, tax, invoices, cancellation/returns, customer support, and transactional email.
- [ ] Configure managed product-image storage, upload validation, moderation, backups, retention, and restore drills.
- [ ] Add structured logs, error tracking, uptime monitoring, alerting, abuse controls, and an incident response runbook.
- [ ] Test performance, accessibility, privacy obligations, and security with realistic staging data.
- [ ] Configure production environment variables and domain; verify no secrets or customer data enter Git history.
- [ ] Complete Android/iOS signing, device testing, store compliance, privacy disclosures, and release procedures.
- [ ] Obtain business/legal review for seller terms, consumer protection, tax/GST, privacy policy, and marketplace obligations applicable in India.
- [ ] Complete staging acceptance tests and rollback rehearsal; obtain explicit launch approval.

## Secrets

Never commit .env files, Supabase service-role keys, payment secrets, webhook secrets, or production customer data. Client applications may use only public Supabase URL and publishable/anon key with correctly enforced RLS.

## Payments

No live payment integration is enabled by this scaffold. Never enable live payment credentials until signed webhooks, idempotency, refunds, reconciliation, late/duplicate events, and failure recovery are tested end to end.
