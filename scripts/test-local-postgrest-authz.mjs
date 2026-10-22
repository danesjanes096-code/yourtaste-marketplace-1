import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";

const apiUrlValue = process.env.API_URL;
const anonKey = process.env.ANON_KEY;
const serviceRoleKey = process.env.SERVICE_ROLE_KEY;
for (const [name, value] of [["API_URL", apiUrlValue], ["ANON_KEY", anonKey], ["SERVICE_ROLE_KEY", serviceRoleKey]]) {
  if (!value) { console.error("Missing local Supabase environment variable: " + name); process.exit(2); }
}
const apiUrl = new URL(apiUrlValue);
assert.equal(apiUrl.protocol, "http:", "Local authz tests must use HTTP on the local stack only.");
assert.ok(["127.0.0.1", "localhost"].includes(apiUrl.hostname), "Refusing to run: API_URL must point to loopback, never a hosted project.");
assert.equal(apiUrl.port, "54321", "Refusing to run: unexpected local Supabase API port.");

function decodeJwt(token) {
  try { return JSON.parse(Buffer.from(token.split(".")[1], "base64url").toString("utf8")); } catch { return null; }
}
assert.equal(decodeJwt(anonKey)?.role, "anon", "Expected local Supabase ANON_KEY.");
assert.equal(decodeJwt(serviceRoleKey)?.role, "service_role", "Expected local Supabase SERVICE_ROLE_KEY.");

async function request(path, { key = anonKey, token, method = "GET", body } = {}) {
  const response = await fetch(new URL(path, apiUrl), {
    method,
    headers: { apikey: key, ...(token ? { Authorization: "Bearer " + token } : {}), ...(body !== undefined ? { "Content-Type": "application/json" } : {}) },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  });
  const text = await response.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  return { status: response.status, ok: response.ok, data };
}
function errorText(result) { return typeof result.data === "string" ? result.data : JSON.stringify(result.data); }

const createdUserIds = [];
const checks = [];
async function check(name, run) { await run(); checks.push(name); console.log("PASS " + name); }

async function createCustomer(label) {
  const email = "local-authz-" + randomUUID() + "@example.com";
  const password = "Local-" + randomUUID() + "-Aa9!";
  const created = await request("/auth/v1/admin/users", {
    key: serviceRoleKey, token: serviceRoleKey, method: "POST",
    body: { email, password, email_confirm: true, user_metadata: { display_name: "Local AuthZ " + label } },
  });
  assert.equal(created.ok, true, "Could not create temporary local test user (HTTP " + created.status + ").");
  const id = created.data?.id ?? created.data?.user?.id;
  assert.match(id ?? "", /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i, "Auth admin response did not contain a user UUID.");
  createdUserIds.push(id);
  const signIn = await request("/auth/v1/token?grant_type=password", { method: "POST", body: { email, password } });
  assert.equal(signIn.ok, true, "Could not sign in temporary local test user (HTTP " + signIn.status + ").");
  assert.equal(typeof signIn.data?.access_token, "string", "Local Auth did not return an access token.");
  const claims = decodeJwt(signIn.data.access_token);
  assert.equal(claims?.sub, id, "Signed JWT subject does not match the newly created local user.");
  assert.equal(claims?.role, "authenticated", "Signed JWT must use the authenticated role.");
  return { id, token: signIn.data.access_token };
}
async function createAddress(token) {
  const result = await request("/rest/v1/rpc/save_customer_address", {
    token, method: "POST",
    body: { p_label: "Local test", p_recipient_name: "Local Test Customer", p_phone: "9876543210", p_line1: "100 Local Test Street", p_line2: null, p_city: "Pune", p_state: "Maharashtra", p_postal_code: "411001", p_is_default: true },
  });
  assert.equal(result.ok, true, "Authorized address RPC failed (HTTP " + result.status + ").");
  const id = typeof result.data === "string" ? result.data : result.data?.[0];
  assert.match(id ?? "", /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i, "Address RPC did not return a UUID.");
  return id;
}
async function cleanupUsers() {
  let failed = false;
  for (const id of createdUserIds.reverse()) {
    try {
      const result = await request("/auth/v1/admin/users/" + encodeURIComponent(id), { key: serviceRoleKey, token: serviceRoleKey, method: "DELETE" });
      if (!result.ok && result.status !== 404) failed = true;
    } catch { failed = true; }
  }
  if (failed) console.error("WARNING: temporary local test users could not all be deleted; the workflow will discard the local stack.");
}

let testError;
try {
  const customerA = await createCustomer("A");
  const customerB = await createCustomer("B");
  assert.notEqual(customerA.id, customerB.id, "Temporary users must be distinct.");
  const addressA = await createAddress(customerA.token);
  const fakeId = "00000000-0000-0000-0000-000000000001";

  await check("customer A can read their own address through PostgREST", async () => {
    const result = await request("/rest/v1/addresses?select=id&id=eq." + encodeURIComponent(addressA), { token: customerA.token });
    assert.equal(result.ok, true, "Customer A address read failed (HTTP " + result.status + ").");
    assert.ok(Array.isArray(result.data)); assert.equal(result.data.length, 1, "Customer A's address should be visible to its owner.");
  });
  await check("customer B cannot read customer A's address through RLS", async () => {
    const result = await request("/rest/v1/addresses?select=id&id=eq." + encodeURIComponent(addressA), { token: customerB.token });
    assert.equal(result.ok, true, "RLS should filter the row rather than fail the read.");
    assert.ok(Array.isArray(result.data)); assert.equal(result.data.length, 0, "RLS exposed another customer's address.");
  });
  await check("customer B cannot change customer A's default address", async () => {
    const result = await request("/rest/v1/rpc/set_default_customer_address", { token: customerB.token, method: "POST", body: { p_address_id: addressA } });
    assert.equal(result.ok, false, "Cross-customer default-address mutation unexpectedly succeeded.");
    assert.match(errorText(result), /address_not_found|42501|permission denied/i);
  });
  await check("customer B cannot directly update address rows", async () => {
    const result = await request("/rest/v1/addresses?id=eq." + encodeURIComponent(addressA), { token: customerB.token, method: "PATCH", body: { is_default: true } });
    assert.equal(result.ok, false, "Direct address table update unexpectedly succeeded.");
  });
  await check("anonymous client cannot invoke checkout order creation", async () => {
    const result = await request("/rest/v1/rpc/create_checkout_order", { method: "POST", body: { p_address_id: addressA, p_items: [], p_idempotency_key: "local-authz-" + randomUUID() } });
    assert.equal(result.ok, false, "Anonymous checkout RPC unexpectedly succeeded.");
  });
  for (const [name, rpc, args] of [
    ["product moderation", "admin_review_product", { p_product_id: fakeId, p_approve: true, p_reason: "local authorization test" }],
    ["vendor moderation", "admin_review_vendor", { p_vendor_id: fakeId, p_approve: true, p_reason: "local authorization test" }],
  ]) {
    await check("customer JWT is denied " + name, async () => {
      const result = await request("/rest/v1/rpc/" + rpc, { token: customerA.token, method: "POST", body: args });
      assert.equal(result.ok, false, "Non-admin moderation unexpectedly succeeded.");
      assert.match(errorText(result), /admin_required|permission denied|not allowed|42501/i);
    });
  }
} catch (error) {
  testError = error;
} finally {
  await cleanupUsers();
}
if (testError) throw testError;
console.log("\nPassed " + checks.length + " local signed-JWT/PostgREST authorization checks.");
