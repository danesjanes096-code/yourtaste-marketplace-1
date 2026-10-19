# YourTaste Marketplace

YourTaste is a multi-vendor marketplace foundation with a Next.js web storefront, an Expo/React Native mobile app, shared TypeScript domain types, and Supabase migrations.

## Project status

**Staging foundation — not production-ready yet.** Do not process real payments or customer orders until the release checklist in `docs/IMPLEMENTATION_PLAN.md` and `docs/STAGING_TEST_PLAN.md` has been completed and reviewed.

## Source package

The current source archive is maintained in the project workspace as `yourtaste-marketplace-foundation-v5.zip`. The repository is being initialized; the application source, database migrations, environment setup, and CI configuration must be published and verified before this repository is a deployable source of truth.

## Planned stack

- Web: Next.js, React, TypeScript
- Mobile: Expo / React Native
- Database and authentication: Supabase
- CI: GitHub Actions

## Security rules

- Never commit `.env` files, Supabase service-role keys, payment secrets, or customer data.
- Only expose Supabase publishable/anon keys to client applications.
- Keep privileged order creation and moderation operations server-side and validate all authorization in the database.
- Treat all deployments as staging until security review, automated tests, payment integration, monitoring, backups, and rollback procedures are complete.
