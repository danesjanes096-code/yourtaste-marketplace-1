-- Cover foreign-key columns used for joins, deletes, and referential checks.
-- Existing unused indexes are intentionally retained until real workload data is available.
create index if not exists audit_logs_actor_id_fk_idx on public.audit_logs(actor_id);
create index if not exists categories_parent_id_fk_idx on public.categories(parent_id);
create index if not exists checkout_requests_order_id_fk_idx on public.checkout_requests(order_id);
create index if not exists order_items_order_id_fk_idx on public.order_items(order_id);
create index if not exists order_items_product_id_fk_idx on public.order_items(product_id);
create index if not exists payments_order_id_fk_idx on public.payments(order_id);
create index if not exists products_category_id_fk_idx on public.products(category_id);
create index if not exists refunds_order_item_id_fk_idx on public.refunds(order_item_id);
create index if not exists refunds_payment_id_fk_idx on public.refunds(payment_id);
create index if not exists refunds_requested_by_fk_idx on public.refunds(requested_by);
create index if not exists reviews_order_item_id_fk_idx on public.reviews(order_item_id);
create index if not exists reviews_product_id_fk_idx on public.reviews(product_id);
create index if not exists shipments_order_id_fk_idx on public.shipments(order_id);
create index if not exists shipments_vendor_id_fk_idx on public.shipments(vendor_id);
