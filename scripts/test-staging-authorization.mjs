import assert from "node:assert/strict";

const required = [
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "SUPABASE_TEST_CUSTOMER_A_JWT",
  "SUPABASE_TEST_CUSTOMER_B_JWT",
  "SUPABASE_TEST_ADDRESS_A_ID",
  "SUPABASE_TEST_ORDER_A_ID",
];
for (const name of required) {
  if (!process.env[name]) {
    console.error(`Missing required environment variable: ${name}`);
    process.exit(2);
  }
}

const expectedProjectRef = "bxwbrnzhyzrvdnvqozce";
const baseUrl = new URL(process.env.SUPABASE_URL);
assert.equal(
  baseUrl.hostname,
  `${expectedProjectRef}.supabase.co`,
  "Refusing to run: URL is not the explicitly approved YourTaste staging project.",
);
assert.equal(baseUrl.protocol, "https:", "Staging URL must use HTTPS.");

const apiKey = process.env.SUPABASE_ANON_KEY;
const customerA = process.env.SUPABASE_TEST_CUSTOMER_A_JWT;
const customerB = process.env.SUPABASE_TEST_CUSTOMER_B_JWT;
const addressA = process.env.SUPABASE_TEST_ADDRESS_A_ID;
const orderA = process.env.SUPABASE_TEST_ORDER_A_ID;
const fakeId = "00000000-0000-0000-0000-000000000001";

for (const [name, value] of [["SUPABASE_TEST_ADDRESS_A_ID", addressA], ["SUPABASE_TEST_ORDER_A_ID", orderA]]) {
  assert.match(value, /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i, `${name} must be a UUID`);
}

async function request(path, { token, method = "GET", body } = {}) {
  const response = await fetch(new URL(path, baseUrl), {
    method,
    headers: {
      apikey: apiKey,
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body !== undefined ? { "Content-Type": "application/json" } : {}),
    },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  });
  const text = await response.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  return { status: response.status, ok: response.ok, data };
}

function errorText(result) {
  return typeof result.data === "string" ? result.data : JSON.stringify(result.data);
}

const checks = [];
async function check(name, run) {
  await run();
  checks.push(name);
  console.log(`PASS ${name}`);
}

// Anonymous clients must not execute the trusted checkout RPC.
await check("anonymous role cannot invoke checkout order creation", async () => {
  const result = await request("/rest/v1/rpc/create_checkout_order", {
    method: "POST",
    body: { p_address_id: addressA, p_items: [], p_idempotency_key: "staging-authz-check-0001" },
  });
  assert.equal(result.ok, false, `Unexpected checkout RPC success: ${JSON.stringify(result.data)}`);
});

// A customer cannot invoke admin-only moderation RPCs, even with a fabricated UUID.
for (const [name, rpc, args] of [
  ["product moderation", "admin_review_product", { p_product_id: fakeId, p_approve: true, p_reason: "authorization test" }],
  ["vendor moderation", "admin_review_vendor", { p_vendor_id: fakeId, p_approve: true, p_reason: "authorization test" }],
]) {
  await check(`customer JWT is denied ${name}`, async () => {
    const result = await request(`/rest/v1/rpc/${rpc}`, {
      token: customerA,
      method: "POST",
      body: args,
    });
    assert.equal(result.ok, false, `Unexpected moderation RPC success: ${JSON.stringify(result.data)}`);
    assert.match(errorText(result), /admin_required|permission denied|not allowed|42501/i);
  });
}

// RLS should hide customer A's address and order from customer B.
for (const [name, table, id] of [
  ["another customer's address", "addresses", addressA],
  ["another customer's order", "orders", orderA],
]) {
  await check(`customer B cannot read ${name}`, async () => {
    const result = await request(`/rest/v1/${table}?select=id&id=eq.${encodeURIComponent(id)}`, { token: customerB });
    assert.equal(result.ok, true, `Read failed instead of being filtered by RLS: ${JSON.stringify(result.data)}`);
    assert.ok(Array.isArray(result.data), `Expected row array, got: ${JSON.stringify(result.data)}`);
    assert.equal(result.data.length, 0, `RLS leaked ${name}: ${JSON.stringify(result.data)}`);
  });
}

// The address RPC must enforce ownership server-side, not just in the client.
await check("customer B cannot set customer A's address as default", async () => {
  const result = await request("/rest/v1/rpc/set_default_customer_address", {
    token: customerB,
    method: "POST",
    body: { p_address_id: addressA },
  });
  assert.equal(result.ok, false, `Unexpected cross-customer address mutation: ${JSON.stringify(result.data)}`);
  assert.match(errorText(result), /address_not_found|42501|permission denied/i);
});

console.log(`\nPassed ${checks.length} staging authorization checks.`);
