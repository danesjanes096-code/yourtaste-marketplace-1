# YourTaste Marketplace

YourTaste is an India-first multi-vendor marketplace project. This GitHub repository currently contains an **initial web/mobile scaffold and development guardrails**. It is not yet the complete staging application.

## Current status

- Web: Next.js storefront UI with illustrative sample listings.
- Mobile: Expo/React Native catalogue UI with illustrative sample listings.
- Shared package: TypeScript domain primitives.
- CI: initial GitHub Actions workflow for source checks, typecheck, and web build.
- Supabase staging: a separate staging project exists, but the full migration set and staging-integrated application source still need to be published and reconciled in this repository.

**Not production-ready.** Authentication, seller workflows, persistent cart, order lifecycle, payment processing, shipping, taxes, refunds, and mobile release flows are not enabled in this scaffold. Do not collect real customer data or process payments with this version. See [production readiness gates](docs/PRODUCTION_READINESS.md).

## Requirements and local development

- Node.js 20.11 or newer
- npm

```bash
npm install
npm run dev:web
```

Open http://localhost:3000. Listings and prices are illustrative development content, not live inventory or verified offers.

## Environment variables

Copy `.env.example` to `.env.local` for local work. Never commit `.env` files, Supabase service-role keys, payment secrets, webhook secrets, or customer data. Client-side apps must only receive public Supabase URL and publishable/anon keys, and database access must be enforced by reviewed RLS policies.

## Required before launch

Follow [docs/PRODUCTION_READINESS.md](docs/PRODUCTION_READINESS.md). The full app source and migrations must first be published and verified, then automated tests, security review, payment-provider sandbox/webhook tests, operational monitoring, backup/restore, privacy/legal review, and release/rollback drills must pass. A successful build alone is not a production-readiness sign-off.
