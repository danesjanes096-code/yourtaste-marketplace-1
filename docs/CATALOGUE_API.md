# Catalogue API

`GET /api/products`

## Query parameters

- `page`: positive integer, defaults to `1`.
- `pageSize`: positive integer, defaults to `12`, maximum `48`.
- `q`: optional text search, truncated to 80 characters.
- `category`: optional category slug.
- `sort`: `price_asc`, `price_desc`, or default newest-first.

## Response

Returns `{ data: Product[], pagination: { page, pageSize, total, totalPages } }`. Money is returned as integer paise plus currency. Public catalogue access relies on database RLS and the published/approved-vendor/active-category policy.

## Failure cases

- `503 catalogue_unavailable`: Supabase public URL/key are not configured.
- `400 invalid_page`: page offset is outside supported bounds.
- `502 catalogue_query_failed`: query failed; database internals are not exposed to clients.

The API currently has no dedicated rate-limiting layer. Configure one at the edge before production traffic.
