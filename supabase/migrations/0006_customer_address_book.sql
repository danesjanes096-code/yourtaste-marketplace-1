-- Customer address book with transactional default-address handling.
with ranked as (select id,row_number() over(partition by user_id order by is_default desc,created_at asc,id asc) as position from public.addresses)
update public.addresses a set is_default=(ranked.position=1) from ranked where ranked.id=a.id;
create unique index if not exists addresses_one_default_per_user_idx on public.addresses(user_id) where is_default=true;
revoke insert,update,delete on public.addresses from anon,authenticated;
grant select on public.addresses to authenticated;
create or replace function public.save_customer_address(p_label text,p_recipient_name text,p_phone text,p_line1 text,p_line2 text,p_city text,p_state text,p_postal_code text,p_is_default boolean default false)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_user_id uuid:=auth.uid(); v_id uuid; v_make_default boolean:=coalesce(p_is_default,false);
begin
 if v_user_id is null then raise exception using errcode='28000',message='authentication_required'; end if;
 if length(trim(coalesce(p_recipient_name,'')))<2 or length(trim(p_recipient_name))>100 or length(trim(coalesce(p_line1,'')))<4 or length(trim(p_line1))>250 or length(trim(coalesce(p_city,'')))<2 or length(trim(p_city))>100 or length(trim(coalesce(p_state,'')))<2 or length(trim(p_state))>100 then raise exception using errcode='22023',message='invalid_address_fields'; end if;
 if coalesce(p_phone,'') !~ '^\+?[0-9]{10,13}$' then raise exception using errcode='22023',message='invalid_phone'; end if;
 if coalesce(p_postal_code,'') !~ '^[0-9]{6}$' then raise exception using errcode='22023',message='invalid_postal_code'; end if;
 if length(coalesce(p_label,'Home'))>50 or length(coalesce(p_line2,''))>250 then raise exception using errcode='22023',message='invalid_address_fields'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_user_id::text,0));
 if not exists(select 1 from public.addresses where user_id=v_user_id) then v_make_default:=true; end if;
 if v_make_default then update public.addresses set is_default=false where user_id=v_user_id and is_default=true; end if;
 insert into public.addresses(user_id,label,recipient_name,phone,line1,line2,city,state,postal_code,country_code,is_default)
 values(v_user_id,coalesce(nullif(trim(p_label),''),'Home'),trim(p_recipient_name),trim(p_phone),trim(p_line1),nullif(trim(coalesce(p_line2,'')),''),trim(p_city),trim(p_state),trim(p_postal_code),'IN',v_make_default) returning id into v_id;
 return v_id;
end; $$;
create or replace function public.set_default_customer_address(p_address_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_user_id uuid:=auth.uid();
begin
 if v_user_id is null then raise exception using errcode='28000',message='authentication_required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_user_id::text,0));
 perform 1 from public.addresses where id=p_address_id and user_id=v_user_id for update;
 if not found then raise exception using errcode='22023',message='address_not_found'; end if;
 update public.addresses set is_default=false where user_id=v_user_id and is_default=true;
 update public.addresses set is_default=true where id=p_address_id and user_id=v_user_id;
 return true;
end; $$;
revoke all on function public.save_customer_address(text,text,text,text,text,text,text,text,boolean) from public,anon;
revoke all on function public.set_default_customer_address(uuid) from public,anon;
grant execute on function public.save_customer_address(text,text,text,text,text,text,text,text,boolean) to authenticated;
grant execute on function public.set_default_customer_address(uuid) to authenticated;
