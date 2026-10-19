-- Read-only security smoke test for YourTaste staging.
-- Run as a database owner in the Supabase SQL editor after applying all migrations.
-- This checks catalog configuration; separate JWT-based tests are still required for row-level behavior.
do $$
declare
  v_bad text;
begin
  select string_agg(format('%I.%I', n.nspname, c.relname), ', ')
    into v_bad
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind='r' and not c.relrowsecurity;
  if v_bad is not null then
    raise exception 'Public tables missing RLS: %', v_bad;
  end if;

  if has_table_privilege('anon','public.checkout_requests','select')
     or has_table_privilege('authenticated','public.checkout_requests','select')
     or has_table_privilege('anon','public.checkout_requests','insert')
     or has_table_privilege('authenticated','public.checkout_requests','insert')
     or has_table_privilege('anon','public.checkout_requests','update')
     or has_table_privilege('authenticated','public.checkout_requests','update')
     or has_table_privilege('anon','public.checkout_requests','delete')
     or has_table_privilege('authenticated','public.checkout_requests','delete') then
    raise exception 'Client role has direct privileges on checkout_requests';
  end if;

  if has_function_privilege('anon','public.is_admin()','execute')
     or has_function_privilege('authenticated','public.is_admin()','execute')
     or has_function_privilege('anon','public.owns_vendor(uuid)','execute')
     or has_function_privilege('authenticated','public.owns_vendor(uuid)','execute')
     or has_function_privilege('anon','public.customer_owns_order(uuid)','execute')
     or has_function_privilege('authenticated','public.customer_owns_order(uuid)','execute')
     or has_function_privilege('anon','public.vendor_has_order(uuid)','execute')
     or has_function_privilege('authenticated','public.vendor_has_order(uuid)','execute') then
    raise exception 'Legacy public RLS helper RPC remains executable by client roles';
  end if;

  if not has_function_privilege('authenticated','private.is_admin()','execute')
     or not has_function_privilege('authenticated','private.owns_vendor(uuid)','execute')
     or not has_function_privilege('authenticated','private.customer_owns_order(uuid)','execute')
     or not has_function_privilege('authenticated','private.vendor_has_order(uuid)','execute') then
    raise exception 'Private RLS helper execution grants are missing';
  end if;

  select string_agg(format('%I.%I', n.nspname, p.proname), ', ')
    into v_bad
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','private') and p.prosecdef
    and not coalesce(p.proconfig @> array['search_path=""'], false);
  if v_bad is not null then
    raise exception 'SECURITY DEFINER functions missing empty search_path: %', v_bad;
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='checkout_requests'
      and policyname='deny client access to checkout requests'
      and qual='false' and with_check='false'
  ) then
    raise exception 'Checkout request deny policy is missing';
  end if;
end $$;

select 'YourTaste staging security smoke test passed' as result;
