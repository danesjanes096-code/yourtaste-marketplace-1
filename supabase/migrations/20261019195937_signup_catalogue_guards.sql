-- YourTaste security hardening and public catalogue rules.
-- Apply only after reviewing 0001_marketplace_core.sql in a disposable project first.
create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare requested_name text;
begin
  requested_name := left(coalesce(new.raw_user_meta_data ->> 'display_name', ''), 100);
  insert into public.profiles (id, display_name, role) values (new.id, requested_name, 'customer'::public.app_role) on conflict (id) do nothing;
  return new;
end;
$$;
revoke all on function public.handle_new_auth_user() from public, anon, authenticated;
drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile after insert on auth.users for each row execute function public.handle_new_auth_user();
insert into public.profiles (id, display_name, role)
select u.id, left(coalesce(u.raw_user_meta_data ->> 'display_name', ''), 100), 'customer'::public.app_role from auth.users u on conflict (id) do nothing;
drop policy if exists "published products are public" on public.products;
drop policy if exists "approved vendor published products are public" on public.products;
create policy "approved vendor published products are public" on public.products for select using (
 (status='published' and exists(select 1 from public.vendors v where v.id=products.vendor_id and v.status='approved')
 and exists(select 1 from public.categories c where c.id=products.category_id and c.is_active=true))
 or public.owns_vendor(vendor_id) or public.is_admin()
);
drop policy if exists "admins may manage profiles" on public.profiles;
create policy "admins may manage profiles" on public.profiles for update using (public.is_admin()) with check (public.is_admin());
grant insert, update on public.vendors to authenticated;
create or replace function public.guard_vendor_moderation_fields()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
 if public.is_admin() then return new; end if;
 if tg_op='INSERT' then new.status := 'pending'::public.vendor_status; new.commission_bps := 1000; return new; end if;
 if new.status is distinct from old.status or new.commission_bps is distinct from old.commission_bps then raise exception 'vendor status and commission changes require an administrator'; end if;
 return new;
end;
$$;
drop trigger if exists vendors_guard_moderation_fields on public.vendors;
create trigger vendors_guard_moderation_fields before insert or update on public.vendors for each row execute function public.guard_vendor_moderation_fields();
create or replace function public.guard_product_publication()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
 if public.is_admin() then return new; end if;
 if new.status='published' and (tg_op='INSERT' or old.status is distinct from new.status) then raise exception 'publishing products requires administrator approval'; end if;
 return new;
end;
$$;
drop trigger if exists products_guard_publication on public.products;
create trigger products_guard_publication before insert or update on public.products for each row execute function public.guard_product_publication();
grant select on public.products, public.categories, public.vendors to anon, authenticated;
grant select, update on public.profiles to authenticated;
grant select, insert, update on public.addresses to authenticated;
grant select, insert, update on public.reviews to authenticated;
