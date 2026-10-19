-- Reduce the public Data API surface for SECURITY DEFINER helpers.
-- Keep the internal authorization helpers in a schema that is not exposed by PostgREST.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated;

create or replace function private.is_admin()
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.profiles where id=(select auth.uid()) and role='admin'::public.app_role) $$;
create or replace function private.owns_vendor(target_vendor uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.vendors where id=target_vendor and owner_id=(select auth.uid())) $$;
create or replace function private.customer_owns_order(target_order uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.orders where id=target_order and customer_id=(select auth.uid())) $$;
create or replace function private.vendor_has_order(target_order uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.order_items oi join public.vendors v on v.id=oi.vendor_id where oi.order_id=target_order and v.owner_id=(select auth.uid())) $$;
grant execute on function private.is_admin() to anon, authenticated;
grant execute on function private.owns_vendor(uuid) to anon, authenticated;
grant execute on function private.customer_owns_order(uuid) to anon, authenticated;
grant execute on function private.vendor_has_order(uuid) to anon, authenticated;

-- These helpers are now used by policies from the unexposed private schema.
revoke all on function public.is_admin() from public, anon, authenticated;
revoke all on function public.owns_vendor(uuid) from public, anon, authenticated;
revoke all on function public.customer_owns_order(uuid) from public, anon, authenticated;
revoke all on function public.vendor_has_order(uuid) from public, anon, authenticated;

drop policy if exists "profiles read self or admin" on public.profiles;
create policy "profiles read self or admin" on public.profiles for select using (id=(select auth.uid()) or (select private.is_admin()));
drop policy if exists "profiles update self" on public.profiles;
create policy "profiles update self" on public.profiles for update using (id=(select auth.uid())) with check (id=(select auth.uid()));
drop policy if exists "approved vendors are public" on public.vendors;
create policy "approved vendors are public" on public.vendors for select using (status='approved' or owner_id=(select auth.uid()) or (select private.is_admin()));
drop policy if exists "vendor owner may create own vendor application" on public.vendors;
create policy "vendor owner may create own vendor application" on public.vendors for insert with check (owner_id=(select auth.uid()) and status='pending');
drop policy if exists "vendor owner may update own vendor details" on public.vendors;
create policy "vendor owner may update own vendor details" on public.vendors for update using (owner_id=(select auth.uid()) or (select private.is_admin())) with check (owner_id=(select auth.uid()) or (select private.is_admin()));
drop policy if exists "active categories are public" on public.categories;
create policy "active categories are public" on public.categories for select using (is_active or (select private.is_admin()));
drop policy if exists "published products are public" on public.products;
drop policy if exists "approved vendor published products are public" on public.products;
create policy "approved vendor published products are public" on public.products for select using (
 (status='published' and exists(select 1 from public.vendors v where v.id=products.vendor_id and v.status='approved')
  and exists(select 1 from public.categories c where c.id=products.category_id and c.is_active=true))
 or (select private.owns_vendor(vendor_id)) or (select private.is_admin())
);
drop policy if exists "vendor can create draft products" on public.products;
create policy "vendor can create draft products" on public.products for insert with check ((select private.owns_vendor(vendor_id)) and status in ('draft','pending_review'));
drop policy if exists "vendor can update own products" on public.products;
create policy "vendor can update own products" on public.products for update using ((select private.owns_vendor(vendor_id)) or (select private.is_admin())) with check ((select private.owns_vendor(vendor_id)) or (select private.is_admin()));
drop policy if exists "customer manages own addresses" on public.addresses;
create policy "customer manages own addresses" on public.addresses for all using (user_id=(select auth.uid()) or (select private.is_admin())) with check (user_id=(select auth.uid()) or (select private.is_admin()));
drop policy if exists "customer reads own orders" on public.orders;
create policy "customer reads own orders" on public.orders for select using (customer_id=(select auth.uid()) or (select private.is_admin()));
drop policy if exists "vendor reads orders containing their items" on public.orders;
create policy "vendor reads orders containing their items" on public.orders for select using ((select private.is_admin()) or (select private.vendor_has_order(id)));
drop policy if exists "customer reads own order items" on public.order_items;
create policy "customer reads own order items" on public.order_items for select using ((select private.is_admin()) or (select private.customer_owns_order(order_id)) or (select private.owns_vendor(vendor_id)));
drop policy if exists "customer reads own payments" on public.payments;
create policy "customer reads own payments" on public.payments for select using ((select private.is_admin()) or (select private.customer_owns_order(order_id)));
drop policy if exists "shipment parties read shipment" on public.shipments;
create policy "shipment parties read shipment" on public.shipments for select using ((select private.is_admin()) or (select private.owns_vendor(vendor_id)) or (select private.customer_owns_order(order_id)));
drop policy if exists "customer reads own refunds" on public.refunds;
create policy "customer reads own refunds" on public.refunds for select using ((select private.is_admin()) or requested_by=(select auth.uid()) or exists(select 1 from public.payments p where p.id=payment_id and (select private.customer_owns_order(p.order_id))));
drop policy if exists "published reviews are public" on public.reviews;
create policy "published reviews are public" on public.reviews for select using (is_published or customer_id=(select auth.uid()) or (select private.is_admin()));
drop policy if exists "customer may submit own review" on public.reviews;
create policy "customer may submit own review" on public.reviews for insert with check (customer_id=(select auth.uid()) and is_published=false);
drop policy if exists "audit logs admin only" on public.audit_logs;
create policy "audit logs admin only" on public.audit_logs for select using ((select private.is_admin()));

-- Pin all SECURITY DEFINER routines to an empty search_path; bodies use schema-qualified objects.

-- Replace the live checkout RPC with canonical idempotency hashing and a safe empty search_path.
create or replace function public.create_checkout_order(p_address_id uuid,p_items jsonb,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
 v_customer_id uuid:=auth.uid(); v_request_hash text; v_request public.checkout_requests%rowtype;
 v_address_snapshot jsonb; v_order_id uuid; v_order_number text; v_subtotal bigint:=0;
 v_total_quantity integer:=0; v_commission bigint; v_lines jsonb:='[]'::jsonb;
 v_line record; v_product record; v_order public.orders%rowtype; v_duplicate_count integer;
begin
 if v_customer_id is null then raise exception using errcode='28000',message='authentication_required'; end if;
 if p_address_id is null then raise exception using errcode='22023',message='address_required'; end if;
 if p_items is null or jsonb_typeof(p_items) is distinct from 'array' then raise exception using errcode='22023',message='invalid_cart'; end if;
 if jsonb_array_length(p_items)<1 or jsonb_array_length(p_items)>30 then raise exception using errcode='22023',message='invalid_cart'; end if;
 if p_idempotency_key is null or length(p_idempotency_key)<16 or length(p_idempotency_key)>128 or p_idempotency_key !~ '^[A-Za-z0-9._:-]+alter function public.is_admin() set search_path='';
alter function public.owns_vendor(uuid) set search_path='';
alter function public.customer_owns_order(uuid) set search_path='';
alter function public.vendor_has_order(uuid) set search_path='';
alter function public.guard_profile_role_change() set search_path='';
alter function public.handle_new_auth_user() set search_path='';
alter function public.guard_vendor_moderation_fields() set search_path='';
alter function public.guard_product_publication() set search_path='';
alter function public.admin_review_vendor(uuid,boolean,text) set search_path='';
alter function public.admin_review_product(uuid,boolean,text) set search_path='';
alter function public.release_expired_order_reservations() set search_path='';
alter function public.save_customer_address(text,text,text,text,text,text,text,text,boolean) set search_path='';
alter function public.set_default_customer_address(uuid) set search_path='';
 then raise exception using errcode='22023',message='invalid_idempotency_key'; end if;
 if exists(select 1 from jsonb_array_elements(p_items) e(value) where
   jsonb_typeof(e.value) is distinct from 'object'
   or coalesce(e.value->>'product_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}alter function public.is_admin() set search_path='';
alter function public.owns_vendor(uuid) set search_path='';
alter function public.customer_owns_order(uuid) set search_path='';
alter function public.vendor_has_order(uuid) set search_path='';
alter function public.guard_profile_role_change() set search_path='';
alter function public.handle_new_auth_user() set search_path='';
alter function public.guard_vendor_moderation_fields() set search_path='';
alter function public.guard_product_publication() set search_path='';
alter function public.admin_review_vendor(uuid,boolean,text) set search_path='';
alter function public.admin_review_product(uuid,boolean,text) set search_path='';
alter function public.release_expired_order_reservations() set search_path='';
alter function public.save_customer_address(text,text,text,text,text,text,text,text,boolean) set search_path='';
alter function public.set_default_customer_address(uuid) set search_path='';

   or case when coalesce(e.value->>'quantity','') ~ '^[0-9]+alter function public.is_admin() set search_path='';
alter function public.owns_vendor(uuid) set search_path='';
alter function public.customer_owns_order(uuid) set search_path='';
alter function public.vendor_has_order(uuid) set search_path='';
alter function public.guard_profile_role_change() set search_path='';
alter function public.handle_new_auth_user() set search_path='';
alter function public.guard_vendor_moderation_fields() set search_path='';
alter function public.guard_product_publication() set search_path='';
alter function public.admin_review_vendor(uuid,boolean,text) set search_path='';
alter function public.admin_review_product(uuid,boolean,text) set search_path='';
alter function public.release_expired_order_reservations() set search_path='';
alter function public.save_customer_address(text,text,text,text,text,text,text,text,boolean) set search_path='';
alter function public.set_default_customer_address(uuid) set search_path='';
 then (e.value->>'quantity')::numeric<1 or (e.value->>'quantity')::numeric>20 else true end) then
   raise exception using errcode='22023',message='invalid_cart_line';
 end if;
 select count(*)-count(distinct x.product_id) into v_duplicate_count from jsonb_to_recordset(p_items) as x(product_id uuid,quantity integer);
 if v_duplicate_count<>0 then raise exception using errcode='22023',message='duplicate_product_lines'; end if;
 if exists(select 1 from jsonb_to_recordset(p_items) as x(product_id uuid,quantity integer) where x.quantity<1 or x.quantity>20) then raise exception using errcode='22023',message='invalid_quantity'; end if;
 select coalesce(sum(x.quantity),0) into v_total_quantity from jsonb_to_recordset(p_items) as x(product_id uuid,quantity integer);
 if v_total_quantity>100 then raise exception using errcode='22023',message='cart_quantity_limit'; end if;
 select to_jsonb(a)-'user_id'-'created_at' into v_address_snapshot from public.addresses a where a.id=p_address_id and a.user_id=v_customer_id;
 if v_address_snapshot is null then raise exception using errcode='22023',message='address_not_found'; end if;
 select encode(public.digest(p_address_id::text||':'||(
   select jsonb_agg(jsonb_build_object('product_id',x.product_id,'quantity',x.quantity) order by x.product_id)::text
   from jsonb_to_recordset(p_items) as x(product_id uuid,quantity integer)
 ),'sha256'),'hex') into v_request_hash;
 insert into public.checkout_requests(customer_id,idempotency_key,request_hash) values(v_customer_id,p_idempotency_key,v_request_hash)
 on conflict(customer_id,idempotency_key) do nothing;
 select * into v_request from public.checkout_requests where customer_id=v_customer_id and idempotency_key=p_idempotency_key for update;
 if v_request.request_hash<>v_request_hash then raise exception using errcode='22023',message='idempotency_key_reused_with_different_request'; end if;
 if v_request.order_id is not null then
  select * into v_order from public.orders where id=v_request.order_id;
  if found then return jsonb_build_object('orderId',v_order.id,'orderNumber',v_order.order_number,'status',v_order.status,'totalPaise',v_order.total_paise,'currency',v_order.currency,'paymentExpiresAt',v_order.payment_expires_at,'reused',true); end if;
 end if;
 for v_line in select x.product_id,x.quantity from jsonb_to_recordset(p_items) as x(product_id uuid,quantity integer) order by x.product_id loop
  select p.*,v.commission_bps,v.store_name,c.name as category_name into v_product
  from public.products p join public.vendors v on v.id=p.vendor_id and v.status='approved'
  join public.categories c on c.id=p.category_id and c.is_active=true
  where p.id=v_line.product_id and p.status='published' for update of p;
  if not found then raise exception using errcode='P0001',message='product_unavailable'; end if;
  if v_product.stock_quantity<v_line.quantity then raise exception using errcode='P0001',message='insufficient_stock'; end if;
  if v_product.price_paise>1000000000 then raise exception using errcode='P0001',message='product_price_limit'; end if;
  v_commission:=floor(v_product.price_paise::numeric*v_product.commission_bps/10000)::bigint;
  update public.products set stock_quantity=stock_quantity-v_line.quantity,updated_at=now() where id=v_product.id;
  v_subtotal:=v_subtotal+(v_product.price_paise*v_line.quantity);
  v_lines:=v_lines||jsonb_build_array(jsonb_build_object('product_id',v_product.id,'vendor_id',v_product.vendor_id,'quantity',v_line.quantity,'unit_price_paise',v_product.price_paise,'commission_paise',v_commission,'sku_snapshot',v_product.sku,'product_snapshot',jsonb_build_object('title',v_product.title,'slug',v_product.slug,'description',v_product.description,'images',v_product.images,'category',v_product.category_name,'vendor',v_product.store_name,'currency',v_product.currency)));
 end loop;
 v_order_number:='YT-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
 insert into public.orders(order_number,customer_id,status,currency,subtotal_paise,shipping_paise,tax_paise,discount_paise,total_paise,shipping_address_snapshot,payment_expires_at)
 values(v_order_number,v_customer_id,'pending_payment','INR',v_subtotal,0,0,0,v_subtotal,v_address_snapshot,now()+interval '15 minutes') returning id into v_order_id;
 insert into public.order_items(order_id,vendor_id,product_id,product_snapshot,sku_snapshot,quantity,unit_price_paise,commission_paise)
 select v_order_id,x.vendor_id,x.product_id,x.product_snapshot,x.sku_snapshot,x.quantity,x.unit_price_paise,x.commission_paise
 from jsonb_to_recordset(v_lines) as x(product_id uuid,vendor_id uuid,quantity integer,unit_price_paise bigint,commission_paise bigint,sku_snapshot text,product_snapshot jsonb);
 update public.checkout_requests set order_id=v_order_id where id=v_request.id;
 return jsonb_build_object('orderId',v_order_id,'orderNumber',v_order_number,'status','pending_payment','totalPaise',v_subtotal,'currency','INR','paymentExpiresAt',now()+interval '15 minutes','reused',false);
end; $$;

alter function public.is_admin() set search_path='';
alter function public.owns_vendor(uuid) set search_path='';
alter function public.customer_owns_order(uuid) set search_path='';
alter function public.vendor_has_order(uuid) set search_path='';
alter function public.guard_profile_role_change() set search_path='';
alter function public.handle_new_auth_user() set search_path='';
alter function public.guard_vendor_moderation_fields() set search_path='';
alter function public.guard_product_publication() set search_path='';
alter function public.admin_review_vendor(uuid,boolean,text) set search_path='';
alter function public.admin_review_product(uuid,boolean,text) set search_path='';
alter function public.release_expired_order_reservations() set search_path='';
alter function public.save_customer_address(text,text,text,text,text,text,text,text,boolean) set search_path='';
alter function public.set_default_customer_address(uuid) set search_path='';
