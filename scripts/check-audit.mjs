import fs from "node:fs";

export const ALLOWED_UNPATCHED_ADVISORIES = new Set([
  "https://github.com/advisories/GHSA-vfj7-8cjw-p6xm",
  "https://github.com/advisories/GHSA-86w9-cpqp-85rv",
]);

const BLOCKING = new Set(["high", "critical"]);

export function findBlockingHighVulnerabilities(vulnerabilities) {
  const memo = new Map();

  function isCovered(name, visiting = new Set()) {
    const vulnerability = vulnerabilities[name];
    if (!vulnerability || !BLOCKING.has(vulnerability.severity)) return true;
    if (vulnerability.severity === "critical" || vulnerability.isDirect) return false;
    if (memo.has(name)) return memo.get(name);
    if (visiting.has(name)) return false;

    const nextVisiting = new Set(visiting);
    nextVisiting.add(name);
    const via = Array.isArray(vulnerability.via) ? vulnerability.via : [];
    if (via.length === 0) return false;

    let tracedAllowedHighReason = false;
    for (const reason of via) {
      if (typeof reason === "string") {
        const child = vulnerabilities[reason];
        if (!child) return false;
        if (BLOCKING.has(child.severity)) {
          tracedAllowedHighReason = true;
          if (!isCovered(reason, nextVisiting)) return false;
        }
      } else if (reason && typeof reason.url === "string") {
        if (!ALLOWED_UNPATCHED_ADVISORIES.has(reason.url)) return false;
        tracedAllowedHighReason = true;
      } else {
        return false;
      }
    }

    const covered = tracedAllowedHighReason;
    memo.set(name, covered);
    return covered;
  }

  return Object.entries(vulnerabilities)
    .filter(([name, vulnerability]) =>
      BLOCKING.has(vulnerability.severity) && !isCovered(name)
    )
    .map(([name, vulnerability]) => ({
      name,
      severity: vulnerability.severity,
      via: vulnerability.via ?? [],
      fixAvailable: vulnerability.fixAvailable ?? false,
    }));
}

function main() {
  const reportPath = process.argv[2];
  if (!reportPath) {
    console.error("Usage: node scripts/check-audit.mjs <npm-audit-json-path>");
    process.exit(2);
  }

  let report;
  try {
    report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
  } catch (error) {
    console.error("Could not parse npm audit JSON:", error.message);
    process.exit(2);
  }

  if (report.error || !report.metadata?.vulnerabilities || !report.vulnerabilities) {
    console.error("npm audit did not return a complete vulnerability report; failing closed.");
    process.exit(2);
  }

  const counts = report.metadata.vulnerabilities;
  console.log("npm audit: " + (counts.critical ?? 0) + " critical, " + (counts.high ?? 0) + " high, " + (counts.moderate ?? 0) + " moderate, " + (counts.low ?? 0) + " low.");
  const blocking = findBlockingHighVulnerabilities(report.vulnerabilities);
  if (blocking.length) {
    console.error("Unapproved high/critical dependency advisories:");
    for (const item of blocking) console.error("- " + item.name + " (" + item.severity + "); fix available: " + JSON.stringify(item.fixAvailable));
    process.exit(1);
  }

  console.log("No unapproved high/critical advisories found. Any remaining high advisories must match the tested, documented upstream-unpatched exception chains.");
}

if (process.argv[1] && import.meta.url === new URL("file://" + process.argv[1]).href) main();
