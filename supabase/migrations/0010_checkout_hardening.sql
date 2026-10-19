-- Harden callable SECURITY DEFINER functions and make checkout idempotency independent of cart line ordering.
-- The checkout RPC remains a pending-order creator only; it does not charge a payment method.
alter table public.checkout_requests enable row level security;
drop policy if exists "deny client access to checkout requests" on public.checkout_requests;
create policy "deny client access to checkout requests" on public.checkout_requests
for all to anon, authenticated using (false) with check (false);

CREATE OR REPLACE FUNCTION public.create_checkout_order(p_address_id uuid, p_items jsonb, p_idempotency_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_customer_id uuid := auth.uid(); v_request_hash text; v_request public.checkout_requests%rowtype;
 v_address_snapshot jsonb; v_order_id uuid; v_order_number text; v_subtotal bigint := 0;
 v_total_quantity integer := 0; v_commission bigint; v_lines jsonb := '[]'::jsonb;
 v_line record; v_product record; v_order public.orders%rowtype; v_duplicate_count integer;
begin
 if v_customer_id is null then raise exception using errcode='28000', message='authentication_required'; end if;
 if p_address_id is null then raise exception using errcode='22023', message='address_required'; end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)<1 or jsonb_array_length(p_items)>30 then
   raise exception using errcode='22023', message='invalid_cart'; end if;
 if p_idempotency_key is null or length(p_idempotency_key)<16 or length(p_idempotency_key)>128 or p_idempotency_key !~ '^[A-Za-z0-9._:-]+$' then
   raise exception using errcode='22023', message='invalid_idempotency_key'; end if;
 if exists(select 1 from jsonb_array_elements(p_items) e(value)
   where jsonb_typeof(e.value)<>'object'
   or coalesce(e.value->>'product_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
   or coalesce(e.value->>'quantity','') !~ '^[0-9]+$') then
   raise exception using errcode='22023', message='invalid_cart_line'; end if;
 select count(*)-count(distinct x.product_id) into v_duplicate_count
 from jsonb_to_recordset(p_items) as x(product_id uuid, quantity integer);
 if v_duplicate_count<>0 then raise exception using errcode='22023', message='duplicate_product_lines'; end if;
 if exists(select 1 from jsonb_to_recordset(p_items) as x(product_id uuid, quantity integer) where x.quantity<1 or x.quantity>20) then
   raise exception using errcode='22023', message='invalid_quantity'; end if;
 select coalesce(sum(x.quantity),0) into v_total_quantity from jsonb_to_recordset(p_items) as x(product_id uuid, quantity integer);
 if v_total_quantity>100 then raise exception using errcode='22023', message='cart_quantity_limit'; end if;
 select to_jsonb(a)-'user_id'-'created_at' into v_address_snapshot from public.addresses a where a.id=p_address_id and a.user_id=v_customer_id;
 if v_address_snapshot is null then raise exception using errcode='22023', message='address_not_found'; end if;
 v_request_hash := encode(extensions.digest(p_address_id::text || ':' || (select jsonb_agg(jsonb_build_object('product_id',x.product_id,'quantity',x.quantity) order by x.product_id)::text from jsonb_to_recordset(p_items) as x(product_id uuid, quantity integer)),'sha256'),'hex');
 insert into public.checkout_requests(customer_id,idempotency_key,request_hash) values(v_customer_id,p_idempotency_key,v_request_hash)
 on conflict(customer_id,idempotency_key) do nothing;
 select * into v_request from public.checkout_requests where customer_id=v_customer_id and idempotency_key=p_idempotency_key for update;
 if v_request.request_hash<>v_request_hash then raise exception using errcode='22023', message='idempotency_key_reused_with_different_request'; end if;
 if v_request.order_id is not null then
   select * into v_order from public.orders where id=v_request.order_id;
   if found then return jsonb_build_object('orderId',v_order.id,'orderNumber',v_order.order_number,'status',v_order.status,
    'totalPaise',v_order.total_paise,'currency',v_order.currency,'paymentExpiresAt',v_order.payment_expires_at,'reused',true); end if;
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
   v_lines:=v_lines||jsonb_build_array(jsonb_build_object('product_id',v_product.id,'vendor_id',v_product.vendor_id,
    'quantity',v_line.quantity,'unit_price_paise',v_product.price_paise,'commission_paise',v_commission,'sku_snapshot',v_product.sku,
    'product_snapshot',jsonb_build_object('title',v_product.title,'slug',v_product.slug,'description',v_product.description,
    'images',v_product.images,'category',v_product.category_name,'vendor',v_product.store_name,'currency',v_product.currency)));
 end loop;
 v_order_number:='YT-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
 insert into public.orders(order_number,customer_id,status,currency,subtotal_paise,shipping_paise,tax_paise,discount_paise,total_paise,shipping_address_snapshot,payment_expires_at)
 values(v_order_number,v_customer_id,'pending_payment','INR',v_subtotal,0,0,0,v_subtotal,v_address_snapshot,now()+interval '15 minutes') returning id into v_order_id;
 insert into public.order_items(order_id,vendor_id,product_id,product_snapshot,sku_snapshot,quantity,unit_price_paise,commission_paise)
 select v_order_id,x.vendor_id,x.product_id,x.product_snapshot,x.sku_snapshot,x.quantity,x.unit_price_paise,x.commission_paise
 from jsonb_to_recordset(v_lines) as x(product_id uuid,vendor_id uuid,quantity integer,unit_price_paise bigint,commission_paise bigint,sku_snapshot text,product_snapshot jsonb);
 update public.checkout_requests set order_id=v_order_id where id=v_request.id;
 return jsonb_build_object('orderId',v_order_id,'orderNumber',v_order_number,'status','pending_payment','totalPaise',v_subtotal,
  'currency','INR','paymentExpiresAt',now()+interval '15 minutes','reused',false);
end; $function$

revoke all on function public.create_checkout_order(uuid,jsonb,text) from public, anon;
grant execute on function public.create_checkout_order(uuid,jsonb,text) to authenticated;

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
