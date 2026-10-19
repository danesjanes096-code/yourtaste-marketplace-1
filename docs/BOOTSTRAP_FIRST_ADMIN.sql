-- ONE-TIME, PRIVILEGED SUPABASE SQL EDITOR OPERATION ONLY.
-- First create/sign in with the trusted account and copy its UUID from auth.users.
-- Replace the placeholder. Run this entire script in one SQL Editor execution.
-- Never expose admin role assignment through signup metadata or a public API.

begin;
do $$
declare
  target_user uuid := 'REPLACE-WITH-TRUSTED-AUTH-USER-UUID'::uuid;
  matching_users integer;
begin
  select count(*) into matching_users from auth.users where id = target_user;
  if matching_users <> 1 then raise exception 'Target must match exactly one auth.users row'; end if;
  if not exists (select 1 from public.profiles where id = target_user) then raise exception 'Target user has no profile row; investigate the auth profile bootstrap trigger first'; end if;
  alter table public.profiles disable trigger profiles_prevent_role_escalation;
  update public.profiles set role = 'admin', updated_at = now() where id = target_user;
  alter table public.profiles enable trigger profiles_prevent_role_escalation;
end $$;
commit;

-- Verify result and trigger state:
-- select id, display_name, role from public.profiles where role = 'admin';
-- select tgname, tgenabled from pg_trigger where tgrelid = 'public.profiles'::regclass and tgname = 'profiles_prevent_role_escalation';
