-- Consolidate overlapping SELECT/UPDATE policies to reduce repeated RLS evaluation.
-- The predicates preserve the existing customer/vendor/admin access rules.
drop policy if exists "customer reads own orders" on public.orders;
drop policy if exists "vendor reads orders containing their items" on public.orders;
create policy "order parties read orders" on public.orders
for select to authenticated
using (
  (select private.is_admin())
  or (select private.customer_owns_order(id))
  or (select private.vendor_has_order(id))
);

drop policy if exists "profiles update self" on public.profiles;
drop policy if exists "admins may manage profiles" on public.profiles;
create policy "profiles update self or admin" on public.profiles
for update to authenticated
using (id=(select auth.uid()) or (select private.is_admin()))
with check (id=(select auth.uid()) or (select private.is_admin()));
