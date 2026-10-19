# Supabase and GitHub setup

## Staging project

The staging project is in Mumbai (`ap-south-1`). Project URL: `https://bxwbrnzhyzrvdnvqozce.supabase.co`. Never put the service-role key in client-side variables.

## Environment setup

1. Copy `.env.example` to `.env.local` for local development.
2. Set `NEXT_PUBLIC_SUPABASE_URL` to the staging URL.
3. Set `NEXT_PUBLIC_SUPABASE_ANON_KEY` to the public/publishable key from Supabase project settings.
4. Keep `SUPABASE_SERVICE_ROLE_KEY` empty unless a reviewed server-only task specifically requires it. Never prefix it with `NEXT_PUBLIC_`.
5. Configure Supabase Auth site URL and allowed redirect URLs for local and staging domains, including `/auth/callback`.
6. Keep production credentials in the hosting provider's encrypted environment settings, not GitHub source files.

## Migrations

Migration files are named with timestamp versions under `supabase/migrations`, matching the ten versions currently recorded in live staging. The private-schema RLS helper migration and checkout hardening migration have been applied and verified against staging. Before production, apply the full chain to a fresh disposable project, compare its schema with staging, and test authorization behavior. Do not blindly re-run schema-changing SQL against production.

## GitHub Actions

CI runs source verification, TypeScript typechecking, and a Next.js production build. A successful workflow is a build check, not a security or launch approval. Review the full workflow and release gates before deployment.

## First administrator

Follow `BOOTSTRAP_FIRST_ADMIN.sql` only in the Supabase SQL editor, with the trusted Auth user's exact UUID. Never expose admin assignment in public signup metadata or client code.
