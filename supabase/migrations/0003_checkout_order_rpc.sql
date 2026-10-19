-- Checkout order creation: server-authoritative prices, stock reservation, and idempotency.
-- This creates pending-payment orders only. It does NOT charge a payment method.
alter table public.orders add column if not exists payment_expires_at timestamptz;
alter table public.orders add column if not exists reservation_released_at timestamptz;
create table if not exists public.checkout_requests (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 idempotency_key text not null,
 request_hash text not null,
 order_id uuid references public.orders(id) on delete set null,
 created_at timestamptz not null default now(),
 unique(user_id, idempotency_key)
);
alter table public.checkout_requests enable row level security;
revoke all on table public.checkout_requests from anon, authenticated;

create or replace function public.create_checkout_order(
 p_address_id uuid,
 p_items jsonb,
 p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
 v_user_id uuid := auth.uid();
 v_hash text;
 v_existing public.checkout_requests%rowtype;
 v_address public.addresses%rowtype;
 v_item jsonb;
 v_product public.products%rowtype;
 v_vendor public.vendors%rowtype;
 v_product_id uuid;
 v_quantity integer;
 v_subtotal bigint := 0;
 v_order_id uuid;
 v_order_number text;
 v_items jsonb;
 v_line_count integer;
 v_seen integer := 0;
begin
 if v_user_id is null then raise exception using errcode='28000', message='authentication_required'; end if;
 if p_address_id is null or not exists(select 1 from public.addresses a where a.id=p_address_id and a.user_id=v_user_id) then
   raise exception using errcode='22023', message='address_not_found';
 end if;
 if p_idempotency_key is null or p_idempotency_key !~ '^[A-Za-z0-9._:-]{16,128}$' then
   raise exception using errcode='22023', message='invalid_idempotency_key';
 end if;
 if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) < 1 or jsonb_array_length(p_items) > 30 then
   raise exception using errcode='22023', message='invalid_cart';
 end if;
 if exists(select 1 from jsonb_array_elements(p_items) x where jsonb_typeof(x) <> 'object'
   or coalesce(x->>'product_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
   or coalesce(x->>'quantity','') !~ '^[0-9]+$'
   or (x->>'quantity')::numeric < 1 or (x->>'quantity')::numeric > 20) then
   raise exception using errcode='22023', message='invalid_cart_line';
 end if;
 if exists(select 1 from (select x->>'product_id' pid, count(*) n from jsonb_array_elements(p_items) x group by x->>'product_id') d where d.n > 1) then
   raise exception using errcode='22023', message='duplicate_product_lines';
 end if;
 select count(*) into v_line_count from jsonb_array_elements(p_items);
 if exists(select 1 from jsonb_array_elements(p_items) x where (x->>'quantity')::integer > 20) then
   raise exception using errcode='22023', message='cart_quantity_limit';
 end if;
 select encode(digest(jsonb_build_object('address_id',p_address_id,'items',(
   select jsonb_agg(jsonb_build_object('product_id',x->>'product_id','quantity',(x->>'quantity')::integer) order by x->>'product_id')
   from jsonb_array_elements(p_items) x
 ))::text,'sha256'),'hex') into v_hash;
 perform pg_advisory_xact_lock(hashtextextended(v_user_id::text || ':' || p_idempotency_key,0));
 select * into v_existing from public.checkout_requests where user_id=v_user_id and idempotency_key=p_idempotency_key for update;
 if found then
   if v_existing.request_hash <> v_hash then raise exception using errcode='23505', message='idempotency_key_reused_with_different_request'; end if;
   return jsonb_build_object('orderId',v_existing.order_id,'reused',true);
 end if;
 select * into v_address from public.addresses where id=p_address_id and user_id=v_user_id;
 for v_item in select x from jsonb_array_elements(p_items) x order by x->>'product_id'
 loop
   v_product_id := (v_item->>'product_id')::uuid;
   v_quantity := (v_item->>'quantity')::integer;
   select * into v_product from public.products where id=v_product_id for update;
   if not found or v_product.status <> 'published'
      or not exists(select 1 from public.vendors v where v.id=v_product.vendor_id and v.status='approved')
      or not exists(select 1 from public.categories c where c.id=v_product.category_id and c.is_active) then
     raise exception using errcode='P0001', message='product_unavailable';
   end if;
   if v_product.price_paise > 100000000 then raise exception using errcode='P0001', message='product_price_limit'; end if;
   if v_product.stock_quantity < v_quantity then raise exception using errcode='P0001', message='insufficient_stock'; end if;
   v_subtotal := v_subtotal + v_product.price_paise * v_quantity;
 end loop;
 if v_subtotal > 1000000000 then raise exception using errcode='22003', message='cart_quantity_limit'; end if;
 v_order_number := 'YT-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
 insert into public.orders(order_number,customer_id,status,currency,subtotal_paise,shipping_paise,tax_paise,discount_paise,total_paise,shipping_address_snapshot,placed_at,payment_expires_at)
 values(v_order_number,v_user_id,'pending_payment','INR',v_subtotal,0,0,0,v_subtotal,
   jsonb_build_object('recipient_name',v_address.recipient_name,'phone',v_address.phone,'line1',v_address.line1,'line2',v_address.line2,'city',v_address.city,'state',v_address.state,'postal_code',v_address.postal_code,'country_code',v_address.country_code),now(),now()+interval '15 minutes')
 returning id into v_order_id;
 for v_item in select x from jsonb_array_elements(p_items) x order by x->>'product_id'
 loop
   v_product_id := (v_item->>'product_id')::uuid; v_quantity := (v_item->>'quantity')::integer;
   select * into v_product from public.products where id=v_product_id for update;
   select * into v_vendor from public.vendors where id=v_product.vendor_id;
   update public.products set stock_quantity=stock_quantity-v_quantity, updated_at=now() where id=v_product_id and stock_quantity>=v_quantity;
   if not found then raise exception using errcode='P0001', message='insufficient_stock'; end if;
   insert into public.order_items(order_id,vendor_id,product_id,product_snapshot,sku_snapshot,quantity,unit_price_paise,commission_paise,tax_paise)
   values(v_order_id,v_product.vendor_id,v_product.id,jsonb_build_object('title',v_product.title,'slug',v_product.slug,'description',v_product.description,'images',v_product.images),v_product.sku,v_quantity,v_product.price_paise,(v_product.price_paise*v_quantity*v_vendor.commission_bps)/10000,0);
 end loop;
 insert into public.checkout_requests(user_id,idempotency_key,request_hash,order_id) values(v_user_id,p_idempotency_key,v_hash,v_order_id);
 return jsonb_build_object('orderId',v_order_id,'orderNumber',v_order_number,'status','pending_payment','totalPaise',v_subtotal,'currency','INR','paymentExpiresAt',now()+interval '15 minutes','reused',false);
end;
$$;
revoke all on function public.create_checkout_order(uuid,jsonb,text) from public, anon;
grant execute on function public.create_checkout_order(uuid,jsonb,text) to authenticated;

create or replace function public.release_expired_order_reservations()
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare v_order record; v_item record; v_released integer := 0;
begin
 for v_order in select id from public.orders where status='pending_payment' and payment_expires_at is not null and payment_expires_at<now() and reservation_released_at is null order by payment_expires_at for update skip locked
 loop
  for v_item in select product_id,quantity from public.order_items where order_id=v_order.id loop
   if v_item.product_id is not null then update public.products set stock_quantity=stock_quantity+v_item.quantity,updated_at=now() where id=v_item.product_id; end if;
  end loop;
  update public.orders set status='cancelled',reservation_released_at=now(),updated_at=now() where id=v_order.id and status='pending_payment';
  if found then v_released:=v_released+1; end if;
 end loop;
 return v_released;
end;
$$;
revoke all on function public.release_expired_order_reservations() from public, anon, authenticated;
grant execute on function public.release_expired_order_reservations() to service_role;
