import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import test from "node:test";

const script = fileURLToPath(new URL("./test-staging-authorization.mjs", import.meta.url));
const stagingUrl = "https://bxwbrnzhyzrvdnvqozce.supabase.co";
const validAddress = "10000000-0000-4000-8000-000000000001";
const safeAnonKey = "eyJhbGciOiJub25lIn0.eyJyb2xlIjoiYW5vbiJ9.test-only";

function run(overrides = {}) {
  const env = { ...process.env };
  for (const name of [
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "SUPABASE_TEST_ADDRESS_A_ID",
    "SUPABASE_TEST_ORDER_A_ID",
    "SUPABASE_TEST_CUSTOMER_A_JWT",
    "SUPABASE_TEST_CUSTOMER_B_JWT",
    "SUPABASE_TEST_CUSTOMER_A_EMAIL",
    "SUPABASE_TEST_CUSTOMER_A_PASSWORD",
    "SUPABASE_TEST_CUSTOMER_B_EMAIL",
    "SUPABASE_TEST_CUSTOMER_B_PASSWORD",
  ]) delete env[name];
  Object.assign(env, overrides);
  return spawnSync(process.execPath, [script], { env, encoding: "utf8", timeout: 5000 });
}

function validConfig(overrides = {}) {
  return {
    SUPABASE_URL: stagingUrl,
    SUPABASE_ANON_KEY: safeAnonKey,
    SUPABASE_TEST_ADDRESS_A_ID: validAddress,
    ...overrides,
  };
}

test("staging authorization harness refuses to run without required configuration", () => {
  const result = run();
  assert.equal(result.status, 2);
  assert.match(result.stderr, /Missing required environment variable: SUPABASE_URL/);
});

test("staging authorization harness refuses a different Supabase project before network access", () => {
  const result = run(validConfig({ SUPABASE_URL: "https://attacker.example" }));
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /approved YourTaste staging project/);
  assert.doesNotMatch(result.stdout + result.stderr, /fetch failed|ENOTFOUND|ECONNREFUSED/);
});

test("staging authorization harness refuses a secret API key before network access", () => {
  const result = run(validConfig({ SUPABASE_ANON_KEY: "sb_secret_not-a-real-key" }));
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /service-role\/secret API keys are refused|service-role\/secret API key is refused/i);
  assert.doesNotMatch(result.stdout + result.stderr, /fetch failed|ENOTFOUND|ECONNREFUSED/);
});

test("staging authorization harness refuses a service-role JWT API key", () => {
  const payload = Buffer.from(JSON.stringify({ role: "service_role" })).toString("base64url");
  const result = run(validConfig({ SUPABASE_ANON_KEY: "eyJhbGciOiJub25lIn0." + payload + ".test-only" }));
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /service-role\/secret API keys are refused|service-role\/secret API key is refused/i);
});

test("staging authorization harness refuses malformed address fixture IDs before sign-in", () => {
  const result = run(validConfig({ SUPABASE_TEST_ADDRESS_A_ID: "not-a-uuid" }));
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /SUPABASE_TEST_ADDRESS_A_ID must be a UUID/);
  assert.doesNotMatch(result.stdout + result.stderr, /fetch failed|ENOTFOUND|ECONNREFUSED/);
});
