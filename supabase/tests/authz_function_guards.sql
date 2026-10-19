-- Guard tests for privileged SECURITY DEFINER RPCs.
-- Run against staging as a database owner. This test deliberately uses nonexistent
-- identities/IDs and must not create or modify marketplace rows.
-- It simulates Supabase's request.jwt.claim.sub setting; it is not a substitute
-- for a real PostgREST request signed with an actual user's JWT.
begin;
do $test$
declare
  v_uid constant text := '8c2f7c62-3f9d-4a3e-9a6a-0c8c65e5d5aa';
begin
  perform set_config('request.jwt.claim.sub','',true);
  begin
    perform public.create_checkout_order(null, '[]'::jsonb, 'security-test-key-0001');
    raise exception 'Expected unauthenticated checkout to be rejected';
  exception when sqlstate '28000' then null;
  end;
  begin
    perform public.save_customer_address('Home','Test User','9876543210','123 Test Road',null,'Pune','Maharashtra','411001',true);
    raise exception 'Expected unauthenticated address creation to be rejected';
  exception when sqlstate '28000' then null;
  end;
  begin
    perform public.set_default_customer_address('00000000-0000-0000-0000-000000000001'::uuid);
    raise exception 'Expected unauthenticated default-address change to be rejected';
  exception when sqlstate '28000' then null;
  end;

  perform set_config('request.jwt.claim.sub',v_uid,true);
  begin
    perform public.admin_review_vendor('00000000-0000-0000-0000-000000000001'::uuid,true,null);
    raise exception 'Expected non-admin vendor moderation to be rejected';
  exception when sqlstate '42501' then null;
  end;
  begin
    perform public.admin_review_product('00000000-0000-0000-0000-000000000001'::uuid,true,null);
    raise exception 'Expected non-admin product moderation to be rejected';
  exception when sqlstate '42501' then null;
  end;
end
$test$;
rollback;
