# SECURITY DEFINER RPC review

Reviewed: 2026-10-20
Project: YourTaste staging (Mumbai)

Supabase's security advisor currently reports five public-schema SECURITY DEFINER functions as callable by the authenticated role. This is an intentional application design choice because direct writes to protected marketplace tables are revoked from client roles and these RPCs must perform multiple checks and writes atomically. The advisor finding is not considered closed until real-JWT tests pass.

## Common controls verified in staging

- All five functions have an empty function-level search path (SET search_path TO ''); application objects are schema-qualified.
- The anon role cannot execute any of these functions.
- The authenticated role can execute them, but each function checks the authenticated identity and resource ownership/administrator role in its body.
- These are not payment-provider integrations; checkout only creates a pending_payment order and does not charge a customer.
- The SQL guard test at supabase/tests/authz_function_guards.sql simulates JWT subject claims. It is useful as a database-owner smoke test, but it is not a substitute for actual PostgREST requests with signed user JWTs.

## Per-function justification

| RPC | Why SECURITY DEFINER is used | Required in-function controls |
| --- | --- | --- |
| admin_review_product(uuid, boolean, text) | Moderates product status and writes an audit log while client DML remains restricted. | Requires non-null auth.uid() and public.is_admin(); validates product existence and approved vendor/active category before publishing; writes an audit event. |
| admin_review_vendor(uuid, boolean, text) | Changes vendor status and the owner's application role atomically. | Requires non-null auth.uid() and public.is_admin(); rejects missing or suspended vendors; updates status/role and writes an audit event. |
| create_checkout_order(uuid, jsonb, text) | Creates an order, reserves stock, records idempotency and order lines in one transaction. | Requires auth.uid(); checks address ownership, cart structure/quantities, idempotency payload, published product/vendor/category, server-side price and stock; returns only pending-payment orders. |
| save_customer_address(...) | Inserts an address and changes the default-address flag atomically while direct client writes are revoked. | Requires auth.uid(); validates fields; locks per user; always inserts for the current user. |
| set_default_customer_address(uuid) | Updates the current user's default address while direct client writes are revoked. | Requires auth.uid(); locks per user; selects the target with user_id = auth.uid() and errors if not owned before changing defaults. |

## Required evidence before pilot

1. Use the instructions in STAGING_AUTHORIZATION_TEST.md with two synthetic customers and real access tokens.
2. Confirm anonymous checkout RPC calls are denied and a non-admin customer cannot invoke either moderation RPC.
3. Confirm Customer B cannot read Customer A's address/order or set Customer A's address as default.
4. Add synthetic seller A/B and admin fixtures; verify non-owner seller actions fail and an admin can perform an allowed moderation action.
5. Re-run the Supabase security advisor after tests. Do not remove the functions' EXECUTE grants without replacing the application flow; the client needs the checkout/address RPCs, and admin moderation requires a protected RPC.

Supabase advisor reference: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
