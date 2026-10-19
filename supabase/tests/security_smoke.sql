-- Read-only security and schema smoke test for YourTaste staging.
-- Run as a database owner after applying the full migration chain.
-- This checks catalog configuration; separate JWT-based RLS tests are still required.
do $$
declare
  v_bad text;
  v_index_count integer;
begin
  select string_agg(format('%I.%I', n.nspname, c.relname), ', ')
    into v_bad
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind='r' and not c.relrowsecurity;
  if v_bad is not null then raise exception 'Public tables missing RLS: %', v_bad; end if;

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
  if v_bad is not null then raise exception 'SECURITY DEFINER functions missing empty search_path: %', v_bad; end if;

  if not exists (select 1 from pg_policies where schemaname='public'
    and tablename='checkout_requests' and policyname='deny client access to checkout requests'
    and qual='false' and with_check='false') then
    raise exception 'Checkout request deny policy is missing';
  end if;

  select count(*) into v_index_count from pg_indexes where schemaname='public'
  and indexname in (
    'audit_logs_actor_id_fk_idx','categories_parent_id_fk_idx','checkout_requests_order_id_fk_idx',
    'order_items_order_id_fk_idx','order_items_product_id_fk_idx','payments_order_id_fk_idx',
    'products_category_id_fk_idx','refunds_order_item_id_fk_idx','refunds_payment_id_fk_idx',
    'refunds_requested_by_fk_idx','reviews_order_item_id_fk_idx','reviews_product_id_fk_idx',
    'shipments_order_id_fk_idx','shipments_vendor_id_fk_idx'
  );
  if v_index_count <> 14 then raise exception 'Expected 14 foreign-key indexes; found %', v_index_count; end if;

  if (select count(*) from pg_policies where schemaname='public' and tablename='orders' and cmd='SELECT') <> 1 then
    raise exception 'Expected one consolidated orders SELECT policy';
  end if;
  if (select count(*) from pg_policies where schemaname='public' and tablename='profiles' and cmd='UPDATE') <> 1 then
    raise exception 'Expected one consolidated profiles UPDATE policy';
  end if;
end $$;

select 'YourTaste staging security/schema smoke test passed' as result;
