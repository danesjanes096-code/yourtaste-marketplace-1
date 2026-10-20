# Staging authorization test runbook

This test makes real PostgREST requests to the approved YourTaste staging project. Its local fail-closed guards are covered by `npm run test:security`; those tests deliberately stop before any network request. It refuses any other project URL and rejects a service-role/secret API key. It does not create orders or write test rows; it only attempts calls that must be denied and reads synthetic fixtures.

## 1. Create synthetic fixtures

1. In the YourTaste staging app, register two test-only customer accounts you control (Customer A and Customer B). Complete email confirmation if the staging Auth settings require it. Do not use real customer accounts.
2. Sign in as Customer A and create a synthetic address in the account address book.
3. In the Supabase SQL Editor for the staging project, find Customer A's Auth user UUID in Authentication → Users, then get the address UUID:
   
   ```sql
   select id, user_id, label
   from public.addresses
   where user_id = '<customer-a-auth-user-uuid>'
   order by created_at desc;
   ```

4. For the order-isolation checks, create a synthetic pending order for Customer A through the staging checkout flow after a synthetic published product is available. Find its UUID:
   
   ```sql
   select id, customer_id, status
   from public.orders
   where customer_id = '<customer-a-auth-user-uuid>'
     and status = 'pending_payment'
   order by created_at desc
   limit 1;
   ```

   If the staging catalogue has no approved vendor/product yet, omit the order UUID for the first run. The script will skip order-isolation checks, and that release gate remains open.

## 2. Run from a local trusted shell

Use only the staging project's publishable/anon API key from Supabase Dashboard → Settings → API Keys. Never use a service-role or secret key. The script signs into the two synthetic accounts using Supabase Auth's password grant; it keeps access tokens in memory and never prints tokens or passwords.

```bash
export SUPABASE_URL="https://bxwbrnzhyzrvdnvqozce.supabase.co"
read -r -p "Staging publishable/anon API key: " SUPABASE_ANON_KEY
export SUPABASE_ANON_KEY

read -r -p "Customer A test email: " SUPABASE_TEST_CUSTOMER_A_EMAIL
read -r -s -p "Customer A test password: " SUPABASE_TEST_CUSTOMER_A_PASSWORD; printf '\n'
export SUPABASE_TEST_CUSTOMER_A_EMAIL SUPABASE_TEST_CUSTOMER_A_PASSWORD

read -r -p "Customer B test email: " SUPABASE_TEST_CUSTOMER_B_EMAIL
read -r -s -p "Customer B test password: " SUPABASE_TEST_CUSTOMER_B_PASSWORD; printf '\n'
export SUPABASE_TEST_CUSTOMER_B_EMAIL SUPABASE_TEST_CUSTOMER_B_PASSWORD

read -r -p "Customer A address UUID: " SUPABASE_TEST_ADDRESS_A_ID
export SUPABASE_TEST_ADDRESS_A_ID
read -r -p "Customer A pending order UUID (blank to skip order checks): " SUPABASE_TEST_ORDER_A_ID
export SUPABASE_TEST_ORDER_A_ID

npm run test:staging-authz
status=$?
unset SUPABASE_ANON_KEY SUPABASE_TEST_CUSTOMER_A_EMAIL SUPABASE_TEST_CUSTOMER_A_PASSWORD
unset SUPABASE_TEST_CUSTOMER_B_EMAIL SUPABASE_TEST_CUSTOMER_B_PASSWORD SUPABASE_TEST_ADDRESS_A_ID SUPABASE_TEST_ORDER_A_ID
exit "$status"
```

Alternatively, supply short-lived JWTs as SUPABASE_TEST_CUSTOMER_A_JWT and SUPABASE_TEST_CUSTOMER_B_JWT instead of the email/password variables. Do not paste credentials or JWTs into chat, commit them, or place them in GitHub Actions logs.

## 3. Expected checks

- Anonymous cannot execute checkout order creation.
- Customer A can read their own synthetic address.
- A customer JWT cannot invoke either admin moderation RPC.
- Customer B cannot read Customer A's address or set it as default.
- If a synthetic order UUID is provided, Customer A can read it while Customer B receives an empty RLS-filtered result.

The current script does not test seller A/B or a positive admin moderation action; those require approved synthetic seller/product fixtures and remain separate release gates.

Supabase references: [sign in with email/password](https://supabase.com/docs/reference/javascript/auth-signinwithpassword), [password-based Auth](https://supabase.com/docs/guides/auth/passwords).
