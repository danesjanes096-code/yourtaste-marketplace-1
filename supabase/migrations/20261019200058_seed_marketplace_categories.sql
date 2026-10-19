-- Starter categories for the initial staging catalogue. Safe to re-run.
insert into public.categories(name, slug, sort_order, is_active) values
 ('Fashion', 'fashion', 10, true),
 ('Electronics', 'electronics', 20, true),
 ('Home & Living', 'home-living', 30, true),
 ('Beauty & Personal Care', 'beauty-personal-care', 40, true),
 ('Sports & Outdoors', 'sports-outdoors', 50, true),
 ('Books & Stationery', 'books-stationery', 60, true),
 ('Toys & Games', 'toys-games', 70, true),
 ('Food & Pantry', 'food-pantry', 80, true)
on conflict (slug) do update set name = excluded.name, sort_order = excluded.sort_order, is_active = true;
