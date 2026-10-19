import assert from "node:assert/strict";

const required = ["SUPABASE_URL", "SUPABASE_ANON_KEY", "SUPABASE_TEST_ADDRESS_A_ID"];
for (const name of required) {
  if (!process.env[name]) {
    console.error("Missing required environment variable: " + name);
    process.exit(2);
  }
}

const expectedProjectRef = "bxwbrnzhyzrvdnvqozce";
const baseUrl = new URL(process.env.SUPABASE_URL);
assert.equal(
  baseUrl.hostname,
  expectedProjectRef + ".supabase.co",
  "Refusing to run: URL is not the explicitly approved YourTaste staging project.",
);
assert.equal(baseUrl.protocol, "https:", "Staging URL must use HTTPS.");

const apiKey = process.env.SUPABASE_ANON_KEY;
const addressA = process.env.SUPABASE_TEST_ADDRESS_A_ID;
const orderA = process.env.SUPABASE_TEST_ORDER_A_ID;
const fakeId = "00000000-0000-0000-0000-000000000001";

function decodeJwt(token) {
  try {
    return JSON.parse(Buffer.from(token.split(".")[1], "base64url").toString("utf8"));
  } catch {
    return null;
  }
}

const apiKeyClaims = decodeJwt(apiKey);
assert.ok(
  !apiKey.startsWith("sb_secret_") && apiKeyClaims?.role !== "service_role",
  "Use only the Supabase publishable/anon key; service-role keys are refused.",
);

for (const [name, value] of [["SUPABASE_TEST_ADDRESS_A_ID", addressA]]) {
  assert.match(value, /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i, name + " must be a UUID");
}
if (orderA) {
  assert.match(orderA, /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i, "SUPABASE_TEST_ORDER_A_ID must be a UUID");
}

async function customerToken(label) {
  const jwt = process.env["SUPABASE_TEST_CUSTOMER_" + label + "_JWT"];
  if (jwt) return jwt;

  const email = process.env["SUPABASE_TEST_CUSTOMER_" + label + "_EMAIL"];
  const password = process.env["SUPABASE_TEST_CUSTOMER_" + label + "_PASSWORD"];
  if (!email || !password) {
    throw new Error(
      "Provide SUPABASE_TEST_CUSTOMER_" + label + "_JWT or both SUPABASE_TEST_CUSTOMER_" + label + "_EMAIL and SUPABASE_TEST_CUSTOMER_" + label + "_PASSWORD.",
    );
  }

  const response = await fetch(new URL("/auth/v1/token?grant_type=password", baseUrl), {
    method: "POST",
    headers: { apikey: apiKey, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (!response.ok) {
    throw new Error("Staging sign-in failed for Customer " + label + " (HTTP " + response.status + "). Check test-account credentials and email confirmation; response body is intentionally not printed.");
  }
  const session = await response.json();
  assert.equal(typeof session.access_token, "string", "Supabase Auth did not return an access token.");
  return session.access_token;
}

async function request(path, { token, method = "GET", body } = {}) {
  const response = await fetch(new URL(path, baseUrl), {
    method,
    headers: {
      apikey: apiKey,
      ...(token ? { Authorization: "Bearer " + token } : {}),
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

const customerA = await customerToken("A");
const customerB = await customerToken("B");
const claimsA = decodeJwt(customerA);
const claimsB = decodeJwt(customerB);
assert.ok(claimsA?.sub && claimsB?.sub, "Customer access tokens must be valid JWTs with subjects.");
assert.notEqual(claimsA.sub, claimsB.sub, "Customer A and B must be different staging users.");
assert.equal(claimsA.role, "authenticated", "Customer A token must use the authenticated role.");
assert.equal(claimsB.role, "authenticated", "Customer B token must use the authenticated role.");

const checks = [];
async function check(name, run) {
  await run();
  checks.push(name);
  console.log("PASS " + name);
}

// Anonymous clients must not execute the trusted checkout RPC.
await check("anonymous role cannot invoke checkout order creation", async () => {
  const result = await request("/rest/v1/rpc/create_checkout_order", {
    method: "POST",
    body: { p_address_id: addressA, p_items: [], p_idempotency_key: "staging-authz-check-0001" },
  });
  assert.equal(result.ok, false, "Unexpected checkout RPC success: " + JSON.stringify(result.data));
});

// Confirm the fixture really belongs to Customer A before testing isolation.
await check("customer A can read their own synthetic address", async () => {
  const result = await request("/rest/v1/addresses?select=id&id=eq." + encodeURIComponent(addressA), { token: customerA });
  assert.equal(result.ok, true, "Customer A address read failed: " + JSON.stringify(result.data));
  assert.ok(Array.isArray(result.data));
  assert.equal(result.data.length, 1, "Address fixture must exist and belong to Customer A.");
});

// A customer cannot invoke admin-only moderation RPCs, even with a fabricated UUID.
for (const [name, rpc, args] of [
  ["product moderation", "admin_review_product", { p_product_id: fakeId, p_approve: true, p_reason: "authorization test" }],
  ["vendor moderation", "admin_review_vendor", { p_vendor_id: fakeId, p_approve: true, p_reason: "authorization test" }],
]) {
  await check("customer JWT is denied " + name, async () => {
    const result = await request("/rest/v1/rpc/" + rpc, {
      token: customerA,
      method: "POST",
      body: args,
    });
    assert.equal(result.ok, false, "Unexpected moderation RPC success: " + JSON.stringify(result.data));
    assert.match(errorText(result), /admin_required|permission denied|not allowed|42501/i);
  });
}

await check("customer B cannot read customer A's address", async () => {
  const result = await request("/rest/v1/addresses?select=id&id=eq." + encodeURIComponent(addressA), { token: customerB });
  assert.equal(result.ok, true, "Read failed instead of being filtered by RLS: " + JSON.stringify(result.data));
  assert.ok(Array.isArray(result.data));
  assert.equal(result.data.length, 0, "RLS leaked customer A's address: " + JSON.stringify(result.data));
});

await check("customer B cannot set customer A's address as default", async () => {
  const result = await request("/rest/v1/rpc/set_default_customer_address", {
    token: customerB,
    method: "POST",
    body: { p_address_id: addressA },
  });
  assert.equal(result.ok, false, "Unexpected cross-customer address mutation: " + JSON.stringify(result.data));
  assert.match(errorText(result), /address_not_found|42501|permission denied/i);
});

if (orderA) {
  await check("customer A can read their own synthetic order", async () => {
    const result = await request("/rest/v1/orders?select=id&id=eq." + encodeURIComponent(orderA), { token: customerA });
    assert.equal(result.ok, true, "Customer A order read failed: " + JSON.stringify(result.data));
    assert.ok(Array.isArray(result.data));
    assert.equal(result.data.length, 1, "Order fixture must exist and belong to Customer A.");
  });
  await check("customer B cannot read customer A's order", async () => {
    const result = await request("/rest/v1/orders?select=id&id=eq." + encodeURIComponent(orderA), { token: customerB });
    assert.equal(result.ok, true, "Read failed instead of being filtered by RLS: " + JSON.stringify(result.data));
    assert.ok(Array.isArray(result.data));
    assert.equal(result.data.length, 0, "RLS leaked customer A's order: " + JSON.stringify(result.data));
  });
} else {
  console.log("SKIP customer-order isolation checks: set SUPABASE_TEST_ORDER_A_ID after creating a synthetic pending order owned by Customer A.");
}

console.log("\nPassed " + checks.length + " staging authorization checks.");
