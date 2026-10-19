-- Security hardening: trigger functions are not RPC endpoints.
revoke all on function public.guard_profile_role_change() from public, anon, authenticated;
revoke all on function public.guard_vendor_moderation_fields() from public, anon, authenticated;
revoke all on function public.guard_product_publication() from public, anon, authenticated;

-- Helpers are required by authenticated RLS policies, but must not be callable anonymously.
revoke all on function public.is_admin() from public, anon;
revoke all on function public.owns_vendor(uuid) from public, anon;
revoke all on function public.customer_owns_order(uuid) from public, anon;
revoke all on function public.vendor_has_order(uuid) from public, anon;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.owns_vendor(uuid) to authenticated;
grant execute on function public.customer_owns_order(uuid) to authenticated;
grant execute on function public.vendor_has_order(uuid) to authenticated;
