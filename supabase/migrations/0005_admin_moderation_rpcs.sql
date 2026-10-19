-- Admin-only transactional moderation. Always authorize in the function, not only the UI.
create or replace function public.admin_review_vendor(p_vendor_id uuid,p_approve boolean,p_reason text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_vendor public.vendors%rowtype; v_status public.vendor_status; v_role public.app_role;
begin
 if auth.uid() is null or not public.is_admin() then raise exception using errcode='42501',message='admin_required'; end if;
 if p_vendor_id is null then raise exception using errcode='22023',message='vendor_id_required'; end if;
 v_status:=case when p_approve then 'approved'::public.vendor_status else 'rejected'::public.vendor_status end;
 v_role:=case when p_approve then 'vendor'::public.app_role else 'customer'::public.app_role end;
 select * into v_vendor from public.vendors where id=p_vendor_id for update;
 if not found then raise exception using errcode='P0002',message='vendor_not_found'; end if;
 if v_vendor.status='suspended' then raise exception using errcode='P0001',message='suspended_vendor_requires_manual_review'; end if;
 update public.vendors set status=v_status,updated_at=now() where id=p_vendor_id;
 update public.profiles set role=v_role,updated_at=now() where id=v_vendor.owner_id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),case when p_approve then 'vendor.approved' else 'vendor.rejected' end,'vendor',p_vendor_id::text,jsonb_build_object('owner_id',v_vendor.owner_id,'reason',left(coalesce(p_reason,''),500)));
 return jsonb_build_object('vendorId',p_vendor_id,'status',v_status,'ownerRole',v_role);
end; $$;
create or replace function public.admin_review_product(p_product_id uuid,p_approve boolean,p_reason text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_product public.products%rowtype; v_status public.product_status;
begin
 if auth.uid() is null or not public.is_admin() then raise exception using errcode='42501',message='admin_required'; end if;
 if p_product_id is null then raise exception using errcode='22023',message='product_id_required'; end if;
 select * into v_product from public.products where id=p_product_id for update;
 if not found then raise exception using errcode='P0002',message='product_not_found'; end if;
 if p_approve and not exists(select 1 from public.vendors v join public.categories c on c.id=v_product.category_id where v.id=v_product.vendor_id and v.status='approved' and c.is_active=true) then raise exception using errcode='P0001',message='vendor_or_category_not_approved'; end if;
 v_status:=case when p_approve then 'published'::public.product_status else 'rejected'::public.product_status end;
 update public.products set status=v_status,updated_at=now() where id=p_product_id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),case when p_approve then 'product.published' else 'product.rejected' end,'product',p_product_id::text,jsonb_build_object('vendor_id',v_product.vendor_id,'reason',left(coalesce(p_reason,''),500)));
 return jsonb_build_object('productId',p_product_id,'status',v_status);
end; $$;
revoke all on function public.admin_review_vendor(uuid,boolean,text) from public,anon;
revoke all on function public.admin_review_product(uuid,boolean,text) from public,anon;
grant execute on function public.admin_review_vendor(uuid,boolean,text) to authenticated;
grant execute on function public.admin_review_product(uuid,boolean,text) to authenticated;
