import test from "node:test";
import fs from "node:fs";
import assert from "node:assert/strict";
import { safeNext } from "../apps/web/lib/security/safe-next.mjs";

const base = "https://yourtaste.example/auth/callback?code=example";

test("preserves safe same-origin path, query, and fragment", () => {
  assert.equal(safeNext("/account/orders?tab=recent#latest", base), "/account/orders?tab=recent#latest");
});

test("allows a normal storefront destination", () => {
  assert.equal(safeNext("/products?q=tea", base), "/products?q=tea");
});

test("rejects protocol-relative and absolute external redirects", () => {
  assert.equal(safeNext("//evil.example/path", base), "/account");
  assert.equal(safeNext("https://evil.example/path", base), "/account");
});

test("rejects backslash-based external redirect tricks", () => {
  assert.equal(safeNext("/\\evil.example", base), "/account");
});

test("rejects auth destinations to avoid redirect loops", () => {
  assert.equal(safeNext("/auth/sign-in", base), "/account");
});

test("falls back for missing or malformed destinations", () => {
  assert.equal(safeNext(null, base), "/account");
  assert.equal(safeNext("http://[::1", base), "/account");
});

test("sign-in form uses the shared safe redirect validator", () => {
  const source = fs.readFileSync(new URL("../apps/web/app/auth/sign-in/SignInForm.tsx", import.meta.url), "utf8");
  assert.match(source, /import \{ safeNext \} from ["']@\/lib\/security\/safe-next\.mjs["']/);
  assert.match(source, /safeNext\(searchParams\.get\(["']next["']\), window\.location\.origin\)/);
  assert.doesNotMatch(source, /function safeNext\(/);
});
