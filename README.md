# YourTaste Marketplace

YourTaste is an India-first multi-vendor marketplace foundation. This repository is an actively developed staging scaffold, not a production release.

## Local database validation

The database replay workflow starts an isolated local Supabase stack, applies every migration to an empty database, and runs the SQL security/schema smoke tests. It does not connect to the hosted staging project and needs no Supabase secrets.

For local use, install Docker and the Supabase CLI, then run:

```bash
supabase start
supabase db reset
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/security_smoke.sql
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/authz_function_guards.sql
```

Never use `supabase db reset --linked` against staging or production; the linked reset is destructive.

## Current status

- Web: responsive storefront, Supabase Auth forms, account and address-book routes, seller application/product submission, moderation queue, catalogue API, and pending-order API.
- Mobile: Expo/React Native catalogue UI with optional live catalogue API connection and a local in-memory bag counter.
- Database: twelve timestamped Supabase migrations, including private-schema RLS helpers, checkout hardening, 14 foreign-key indexes, and consolidated order/profile policies.
- CI: clean npm install, tested dependency-audit policy, redirect/audit-policy tests, ESLint, TypeScript typecheck, Next.js production build, Expo Doctor, and Android JS bundle export all pass on main.
- Staging: twelve migrations are recorded. The security/schema smoke test passes, checking public-table RLS, checkout-request client grants, helper RPC grants, privileged function search paths, 14 foreign-key indexes, and consolidated policies. Fresh local replay and both SQL guard suites pass in CI; a hosted disposable-project replay and full schema diff are still required.

## Not production-ready

Authentication and seller flows are implemented in part but have not completed end-to-end staging acceptance. The checkout endpoint can create pending-payment orders and reserve inventory; **no payment provider is integrated and no money is charged**. Shipping, taxes, refunds, transactional notifications, mobile authentication/checkout, monitoring, backup/restore, and production deployment are not complete. Do not collect real customer data or process live orders with this version.

See [production readiness gates](docs/PRODUCTION_READINESS.md), the [staging test plan](docs/STAGING_TEST_PLAN.md), the [private pilot release checklist](docs/PRIVATE_PILOT_RELEASE_GATES.md), and the [payment/shipping provider shortlist](docs/PROVIDER_DECISIONS.md).

## Requirements and local development

- Node.js 22 or newer
- npm

```bash
npm ci
npm run dev:web
```

Open http://localhost:3000. Listings and prices on the storefront are illustrative development content, not live inventory or verified offers.

To run the mobile shell, set `EXPO_PUBLIC_API_BASE_URL` to a reachable staging web API URL and run `npm run dev:mobile`.

## Environment variables and secrets

Copy `.env.example` to `.env.local` for local work. Never commit `.env` files, Supabase service-role keys, payment secrets, webhook secrets, or customer data. Client applications may use only the public Supabase URL and publishable/anon key, with database access enforced by reviewed RLS policies.

## Launch gate

Do not deploy to production until the full source/schema parity check, clean-checkout CI, RLS authorization tests, payment-provider sandbox/webhook/refund tests, monitoring, backup/restore, privacy/legal review, mobile device tests, and release/rollback drills pass. A successful build alone is not a production-readiness sign-off.
