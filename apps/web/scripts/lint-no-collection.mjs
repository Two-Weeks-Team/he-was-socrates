#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { glob } from "node:fs/promises";
import path from "node:path";

const FORBIDDEN_PATTERNS = [
  { re: /<form\b/i, name: "<form> tag" },
  { re: /<input\b/i, name: "<input> tag" },
  { re: /<textarea\b/i, name: "<textarea> tag" },
  { re: /\bfetch\s*\(/i, name: "fetch() call" },
  { re: /sendBeacon/i, name: "sendBeacon" },
  { re: /XMLHttpRequest/i, name: "XMLHttpRequest" },
  { re: /document\.cookie/i, name: "document.cookie" },
  { re: /localStorage\.setItem/i, name: "localStorage.setItem (write)" },
  { re: /sessionStorage\.setItem/i, name: "sessionStorage.setItem" },
  { re: /serviceWorker/i, name: "serviceWorker" },
  { re: /<script[^>]*src=/i, name: "<script src=...> external" },
];

let hits = 0;
const dirs = ["app", "components"];
for (const dir of dirs) {
  for await (const file of glob(path.join(dir, "**/*.{ts,tsx,js,jsx,mjs,html}"))) {
    const content = readFileSync(file, "utf8");
    for (const { re, name } of FORBIDDEN_PATTERNS) {
      if (re.test(content)) {
        console.error(`✗ ${file}: forbidden pattern — ${name}`);
        hits++;
      }
    }
  }
}
if (hits > 0) {
  console.error(`\n${hits} NO-DATA-COLLECTION violation(s). Fix or update SPEC.md.iter7.`);
  process.exit(1);
}
console.log("✓ NO-DATA-COLLECTION invariant — clean");
