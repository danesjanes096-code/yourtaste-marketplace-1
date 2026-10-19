import fs from 'node:fs';
import path from 'node:path';

const required = [
  'README.md', '.env.example', 'package.json', 'apps/web/package.json',
  'apps/web/app/page.tsx', 'apps/web/app/layout.tsx',
  'apps/web/app/auth/sign-in/SignInForm.tsx', 'apps/web/app/auth/sign-up/SignUpForm.tsx',
  'apps/web/app/account/addresses/AddressBook.tsx', 'apps/web/app/api/products/route.ts',
  'apps/web/app/api/checkout/orders/route.ts', 'apps/web/middleware.ts',
  'apps/mobile/app/index.tsx', 'packages/shared/src/index.ts',
  '.github/workflows/ci.yml', 'docs/PRODUCTION_READINESS.md', 'supabase/tests/security_smoke.sql',
  ...[
    '20261019195925_marketplace_core.sql',
    '20261019195937_signup_catalogue_guards.sql',
    '20261019195955_checkout_order_rpc.sql',
    '20261019195958_vendor_product_permissions.sql',
    '20261019200006_admin_moderation_rpcs.sql',
    '20261019200014_customer_address_book.sql',
    '20261019200036_security_definer_grants_hardening.sql',
    '20261019200058_seed_marketplace_categories.sql',
    '20261019203501_private_rls_helpers.sql',
    '20261019203635_checkout_hardening.sql',
    '20261019204339_performance_fk_indexes.sql',
    '20261019204454_rls_policy_consolidation.sql'
  ].map((name) => `supabase/migrations/${name}`)
];
const errors = required.filter((file) => !fs.existsSync(path.resolve(file))).map((file) => `Missing required file: ${file}`);
const envExample = fs.readFileSync('.env.example', 'utf8');
if (!envExample.includes('NEXT_PUBLIC_SUPABASE_URL=')) errors.push('Missing Supabase URL placeholder.');
if (!envExample.includes('SUPABASE_SERVICE_ROLE_KEY=')) errors.push('Missing server-only service-role placeholder.');
for (const file of ['.env', '.env.local', '.env.production']) {
  if (fs.existsSync(file)) errors.push(`Refusing to verify with local secret file present: ${file}`);
}
const checkout = fs.readFileSync('apps/web/app/api/checkout/orders/route.ts', 'utf8');
for (const invariant of ['create_checkout_order', 'idempotencyKey', 'authentication_required']) {
  if (!checkout.includes(invariant)) errors.push(`Checkout invariant missing: ${invariant}`);
}
const migrations = fs.readFileSync('supabase/migrations/20261019195955_checkout_order_rpc.sql', 'utf8');
for (const invariant of ['create_checkout_order', 'release_expired_order_reservations', 'idempotency_key_reused_with_different_request']) {
  if (!migrations.includes(invariant)) errors.push(`Checkout migration invariant missing: ${invariant}`);
}
const securitySmoke = fs.readFileSync('supabase/tests/security_smoke.sql', 'utf8');
for (const invariant of ['relrowsecurity', 'checkout_requests', 'private.is_admin()', 'search_path=""']) {
  if (!securitySmoke.includes(invariant)) errors.push(`Security smoke test invariant missing: ${invariant}`);
}
const hardening = fs.readFileSync('supabase/migrations/20261019203635_checkout_hardening.sql', 'utf8');
for (const invariant of ['extensions.digest', 'deny client access to checkout requests', "set search_path TO ''"]) {
  if (!hardening.toLowerCase().includes(invariant.toLowerCase())) errors.push(`Checkout hardening invariant missing: ${invariant}`);
}
if (errors.length) {
  console.error('YourTaste source verification failed:');
  for (const error of errors) console.error(`- ${error}`);
  process.exitCode = 1;
} else {
  console.log(`YourTaste repository structure and checkout invariants verified (${required.length} required files).`);
}
