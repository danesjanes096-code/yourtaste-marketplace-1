import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const root = process.cwd();
const sourceRoots = ["apps/web", "apps/mobile", "packages"];
const ignoredDirectories = new Set(["node_modules", ".next", "dist", "build", "coverage"]);
const sourceExtensions = new Set([".js", ".jsx", ".mjs", ".cjs", ".ts", ".tsx", ".mts", ".cts"]);
const serverOnlyNames = [
  "SUPABASE_SERVICE_ROLE_KEY",
  "RAZORPAY_KEY_SECRET",
  "RAZORPAY_WEBHOOK_SECRET",
  "SHIPROCKET_EMAIL",
  "SHIPROCKET_PASSWORD",
  "RESEND_API_KEY",
  "PRIVATE_KEY",
];

function sourceFiles(directory) {
  if (!fs.existsSync(directory)) return [];
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) return ignoredDirectories.has(entry.name) ? [] : sourceFiles(fullPath);
    return sourceExtensions.has(path.extname(entry.name)) ? [fullPath] : [];
  });
}

const files = sourceRoots.flatMap((directory) => sourceFiles(path.join(root, directory)));

test("public build variable names never imply server-only secrets", () => {
  const errors = [];
  const publicSecretName = /\b(?:NEXT_PUBLIC|EXPO_PUBLIC)_[A-Z0-9_]*(?:SERVICE_ROLE|SECRET|PASSWORD|PRIVATE_KEY|WEBHOOK|RESEND|SHIPROCKET)[A-Z0-9_]*\b/g;
  for (const file of files) {
    const source = fs.readFileSync(file, "utf8");
    for (const match of source.matchAll(publicSecretName)) {
      errors.push(path.relative(root, file) + ": " + match[0]);
    }
  }
  assert.deepEqual(errors, [], "Secret-like environment variables must never use NEXT_PUBLIC_ or EXPO_PUBLIC_ prefixes.");
});

test("client components never reference server-only secret variables", () => {
  const errors = [];
  const clientDirective = /^\s*["']use client["']\s*;?/m;
  const secretReference = new RegExp(
    "(?:process\\s*\\.\\s*env\\s*\\.\\s*|process\\s*\\.\\s*env\\s*\\[\\s*[\"'])(" +
      serverOnlyNames.join("|") +
      ")(?:[\"']\\s*\\])?",
    "g",
  );
  for (const file of files) {
    const source = fs.readFileSync(file, "utf8");
    if (!clientDirective.test(source)) continue;
    for (const match of source.matchAll(secretReference)) {
      errors.push(path.relative(root, file) + ": " + match[1]);
    }
  }
  assert.deepEqual(errors, [], "Client components must not read server-only secret environment variables.");
});

test(".env.example keeps secret values empty", () => {
  const envPath = path.join(root, ".env.example");
  const lines = fs.readFileSync(envPath, "utf8").split(/\r?\n/);
  const secretName = /(?:SERVICE_ROLE|SECRET|PASSWORD|PRIVATE_KEY|RESEND_API_KEY)/i;
  const populated = lines.flatMap((line, index) => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) return [];
    const match = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!match || !secretName.test(match[1])) return [];
    return match[2].trim() === "" ? [] : [".env.example:" + (index + 1) + " " + match[1]];
  });
  assert.deepEqual(populated, [], "Secret placeholders in .env.example must remain blank.");
});
