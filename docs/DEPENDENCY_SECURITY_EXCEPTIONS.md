# Dependency security exceptions

Reviewed: 2026-10-20

The CI dependency audit blocks all unapproved high/critical findings. Two advisories currently have no patched npm release listed by the upstream GitHub Advisory Database and are allowed only as transitive build-tool dependencies. The exception is temporary, narrow, tested, and must be revisited when upstream status changes.

## Allowed advisories

- **braces — GHSA-vfj7-8cjw-p6xm / CVE-2026-93687 (High).** The advisory lists versions through 3.0.3 as affected and no patched release. It is pulled in by Metro/glob tooling. YourTaste does not expose an endpoint that accepts attacker-controlled brace patterns; builds must use trusted repository code and must not process untrusted path/glob patterns.
  - Advisory: https://github.com/advisories/GHSA-vfj7-8cjw-p6xm
  - Upstream discussion: https://github.com/micromatch/braces/issues/84

- **node-forge — GHSA-86w9-cpqp-85rv / CVE-2026-85393 (High).** The advisory lists versions through 1.4.0 as affected and no patched release. It is present transitively through Expo CLI/certificate tooling, not as a direct YourTaste application dependency. Do not use it to verify user-supplied signatures or certificates, and keep Expo development tooling restricted to trusted developers and ephemeral CI.
  - Advisory: https://github.com/advisories/GHSA-86w9-cpqp-85rv
  - Upstream issue: https://github.com/digitalbazaar/forge/issues/1149

## Controls and review

- scripts/check-audit.mjs permits only these exact advisory URLs and only when they are transitive. Direct high-severity dependencies, critical findings, unknown chains, missing reports, or any other high/critical advisory fail CI.
- scripts/test-audit-policy.mjs tests both allowed cases and fail-closed behavior.
- Do not add a package override to a version that does not exist. The advisories currently have no patched releases; attempted overrides were removed after npm correctly rejected nonexistent versions.
- Re-check the advisory pages before each pilot release and weekly until upstream patches are published. Remove each exception and its test fixture as soon as a patched release is available.
- These exceptions do not close other YourTaste launch gates, including real-JWT authorization tests and Supabase SECURITY DEFINER review.
