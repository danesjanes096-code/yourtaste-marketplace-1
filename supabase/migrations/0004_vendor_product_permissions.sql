-- Seller product workspace permissions. RLS policies from 0001/0002 still apply.
-- Sellers can insert drafts/pending-review products and update only their own rows.
-- The 0002 trigger prevents sellers from publishing directly.
grant insert, update on public.products to authenticated;
revoke delete on public.products from anon, authenticated;
