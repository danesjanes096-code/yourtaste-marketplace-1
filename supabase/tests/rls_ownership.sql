-- Transactional RLS and ownership integration tests.
-- Creates only synthetic users/address/order rows in the isolated local replay DB.
-- The final ROLLBACK removes every fixture; never run against a hosted database.
begin;

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  is_super_admin, is_sso_user, is_anonymous
) values
  ('00000000-0000-4000-8000-000000000101', 'authenticated', 'authenticated',
   'rls-customer-a@example.invalid', '', now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now(), false, false, false),
  ('00000000-0000-4000-8000-000000000102', 'authenticated', 'authenticated',
   'rls-customer-b@example.invalid', '', now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now(), false, false, false);

insert into public.addresses (
  id, user_id, label, recipient_name, phone, line1, city, state, postal_code, country_code, is_default
) values (
  '00000000-0000-4000-8000-000000000201',
  '00000000-0000-4000-8000-000000000101',
  'RLS test', 'Synthetic Customer A', '9876543210', '123 Test Road',
  'Pune', 'Maharashtra', '411001', 'IN', true
);

insert into public.orders (
  id, order_number, customer_id, status, currency, subtotal_paise,
  shipping_paise, tax_paise, discount_paise, total_paise, shipping_address_snapshot
) values (
  '00000000-0000-4000-8000-000000000202',
  'YT-RLS-OWNERSHIP-TEST-A',
  '00000000-0000-4000-8000-000000000101',
  'pending_payment', 'INR', 100, 0, 0, 0, 100,
  '{"recipient_name":"Synthetic Customer A","city":"Pune","postal_code":"411001"}'::jsonb
);

set local role authenticated;

do $test$
declare
  v_count integer;
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000101', true);

  select count(*) into v_count from public.profiles
   where id = '00000000-0000-4000-8000-000000000101';
  if v_count <> 1 then raise exception 'Customer A cannot read their own profile'; end if;

  select count(*) into v_count from public.addresses
   where id = '00000000-0000-4000-8000-000000000201';
  if v_count <> 1 then raise exception 'Customer A cannot read their own address'; end if;

  select count(*) into v_count from public.orders
   where id = '00000000-0000-4000-8000-000000000202';
  if v_count <> 1 then raise exception 'Customer A cannot read their own order'; end if;

  perform set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000102', true);

  select count(*) into v_count from public.profiles
   where id = '00000000-0000-4000-8000-000000000101';
  if v_count <> 0 then raise exception 'Customer B can read Customer A profile'; end if;

  select count(*) into v_count from public.addresses
   where id = '00000000-0000-4000-8000-000000000201';
  if v_count <> 0 then raise exception 'Customer B can read Customer A address'; end if;

  select count(*) into v_count from public.orders
   where id = '00000000-0000-4000-8000-000000000202';
  if v_count <> 0 then raise exception 'Customer B can read Customer A order'; end if;

  begin
    perform public.set_default_customer_address('00000000-0000-4000-8000-000000000201'::uuid);
    raise exception 'Customer B unexpectedly changed Customer A default address';
  exception when sqlstate '22023' then
    if sqlerrm <> 'address_not_found' then raise; end if;
  end;

  begin
    perform public.create_checkout_order(
      '00000000-0000-4000-8000-000000000201'::uuid,
      '[{"product_id":"00000000-0000-4000-8000-000000000999","quantity":1}]'::jsonb,
      'rls-ownership-check-0001'
    );
    raise exception 'Customer B unexpectedly checked out with Customer A address';
  exception when sqlstate '22023' then
    if sqlerrm <> 'address_not_found' then raise; end if;
  end;
end
$test$;

rollback;
