# YourTaste Marketplace

YourTaste is an India-first multi-vendor marketplace foundation. This repository is an actively developed staging scaffold, not a production release.

## Current status

- Web: responsive storefront, Supabase Auth forms, account and address-book routes, seller application/product submission, moderation queue, catalogue API, and pending-order API.
- Mobile: Expo/React Native catalogue UI with optional live catalogue API connection and a local in-memory bag counter.
- Database: nine versioned migration files, including a pending private-schema/RLS helper hardening migration.
- CI: GitHub Actions source verification, TypeScript typecheck, and Next.js production build.
- Staging: the live Supabase project records migrations 0001–0008. Migration 0009 is committed but has not yet been applied. A fresh-database migration run and schema diff are still required.

## Not production-ready

Authentication and seller flows are implemented in part but have not completed end-to-end staging acceptance. The checkout endpoint can create pending-payment orders and reserve inventory; **no payment provider is integrated and no money is charged**. Shipping, taxes, refunds, transactional notifications, mobile authentication/checkout, monitoring, backup/restore, and production deployment are not complete. Do not collect real customer data or process live orders with this version.

See [production readiness gates](docs/PRODUCTION_READINESS.md) and the [staging test plan](docs/STAGING_TEST_PLAN.md).

## Requirements and local development

- Node.js 22 or newer
- npm

```bash
npm install
npm run dev:web
```

Open http://localhost:3000. Listings and prices on the storefront are illustrative development content, not live inventory or verified offers.

To run the mobile shell, set `EXPO_PUBLIC_API_BASE_URL` to a reachable staging web API URL and run `npm run dev:mobile`.

## Environment variables and secrets

Copy `.env.example` to `.env.local` for local work. Never commit `.env` files, Supabase service-role keys, payment secrets, webhook secrets, or customer data. Client applications may use only the public Supabase URL and publishable/anon key, with database access enforced by reviewed RLS policies.

## Launch gate

Do not deploy to production until the full source/schema parity check, clean-checkout CI, RLS authorization tests, payment-provider sandbox/webhook/refund tests, monitoring, backup/restore, privacy/legal review, mobile device tests, and release/rollback drills pass. A successful build alone is not a production-readiness sign-off.
