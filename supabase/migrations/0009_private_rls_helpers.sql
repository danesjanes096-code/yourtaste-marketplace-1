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
alter function public.create_checkout_order(uuid,jsonb,text) set search_path='';
alter function public.release_expired_order_reservations() set search_path='';
alter function public.save_customer_address(text,text,text,text,text,text,text,text,boolean) set search_path='';
alter function public.set_default_customer_address(uuid) set search_path='';
