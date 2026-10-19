import test from "node:test";
import assert from "node:assert/strict";
import { findBlockingHighVulnerabilities } from "./check-audit.mjs";

const bracesUrl = "https://github.com/advisories/GHSA-vfj7-8cjw-p6xm";
const forgeUrl = "https://github.com/advisories/GHSA-86w9-cpqp-85rv";

test("allows only the documented unpatched braces advisory", () => {
  const vulnerabilities = {
    braces: { severity: "high", isDirect: false, via: [{ title: "braces DoS", url: bracesUrl }] },
  };
  assert.deepEqual(findBlockingHighVulnerabilities(vulnerabilities), []);
});

test("allows only the documented unpatched node-forge advisory", () => {
  const vulnerabilities = {
    "node-forge": { severity: "high", isDirect: false, via: [{ title: "node-forge signature issue", url: forgeUrl }] },
  };
  assert.deepEqual(findBlockingHighVulnerabilities(vulnerabilities), []);
});

test("allows high-severity transitive parents only when every high chain reaches an approved advisory", () => {
  const vulnerabilities = {
    braces: { severity: "high", isDirect: false, via: [{ url: bracesUrl }] },
    "node-forge": { severity: "high", isDirect: false, via: [{ url: forgeUrl }] },
    "@expo/metro": { severity: "high", isDirect: false, via: ["braces"] },
    "@expo/cli": { severity: "high", isDirect: false, via: ["@expo/metro", "node-forge"] },
    "@expo/config": { severity: "moderate", isDirect: false, via: [{ url: "https://example.test/moderate" }] },
  };
  assert.deepEqual(findBlockingHighVulnerabilities(vulnerabilities), []);
});

test("blocks a new unapproved high-severity advisory", () => {
  const vulnerabilities = {
    "new-package": { severity: "high", isDirect: false, via: [{ url: "https://example.test/new-high" }] },
  };
  assert.deepEqual(findBlockingHighVulnerabilities(vulnerabilities).map((v) => v.name), ["new-package"]);
});

test("blocks direct high-severity dependencies even if an advisory URL is allowlisted", () => {
  const vulnerabilities = {
    braces: { severity: "high", isDirect: true, via: [{ url: bracesUrl }] },
  };
  assert.deepEqual(findBlockingHighVulnerabilities(vulnerabilities).map((v) => v.name), ["braces"]);
});

test("blocks critical advisories even when their URL is allowlisted", () => {
  const vulnerabilities = {
    braces: { severity: "critical", isDirect: false, via: [{ url: bracesUrl }] },
  };
  assert.deepEqual(findBlockingHighVulnerabilities(vulnerabilities).map((v) => v.name), ["braces"]);
});

test("fails closed on circular or incomplete high-severity chains", () => {
  const circular = {
    a: { severity: "high", isDirect: false, via: ["b"] },
    b: { severity: "high", isDirect: false, via: ["a"] },
  };
  const incomplete = {
    a: { severity: "high", isDirect: false, via: ["missing-child"] },
  };
  assert.deepEqual(findBlockingHighVulnerabilities(circular).map((v) => v.name), ["a", "b"]);
  assert.deepEqual(findBlockingHighVulnerabilities(incomplete).map((v) => v.name), ["a"]);
});
