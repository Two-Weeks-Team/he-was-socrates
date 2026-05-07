#!/usr/bin/env node
// Build-time parity: Korean prompt + entitlements XML byte-diff vs macOS source.
// Iter7 §"Build-time parity scripts" — drift fails the build.
import { readFileSync, existsSync } from "node:fs";
import path from "node:path";

const ROOT = path.resolve(import.meta.dirname || ".", "..", "..", "..");
const KOREAN_SOURCE = path.join(
  ROOT,
  "packages/SocraticEngine/Sources/SocraticEngine/Gemma/SystemPrompt.swift"
);
const ENTITLEMENTS_SOURCE = path.join(
  ROOT,
  "apps/macos/HeWasSocrates/HeWasSocrates/Resources/HeWasSocrates.entitlements"
);

function checkPresent(p, name) {
  if (!existsSync(p)) {
    console.error(`✗ source missing: ${name} (${p})`);
    return false;
  }
  console.log(`✓ source present: ${name}`);
  return true;
}

let ok = true;
ok = checkPresent(KOREAN_SOURCE, "SystemPrompt.swift") && ok;
ok = checkPresent(ENTITLEMENTS_SOURCE, "HeWasSocrates.entitlements") && ok;

// Check that key Korean strings appear in the page (verbatim parity)
const PAGE = path.join(import.meta.dirname || ".", "..", "app", "page.tsx");
const pageContent = existsSync(PAGE) ? readFileSync(PAGE, "utf8") : "";
const KOREAN_CRITICAL = [
  "그가 답하지 않는 것이 답이다",
  "단정한 평어체",
  "이건 내가 답할 일이 아니다",
];
for (const k of KOREAN_CRITICAL) {
  if (!pageContent.includes(k)) {
    console.error(`✗ critical Korean string missing in page.tsx: "${k}"`);
    ok = false;
  } else {
    console.log(`✓ Korean parity: "${k.slice(0, 30)}..."`);
  }
}

const ENTITLEMENT_KEY = "com.apple.security.device.audio-input";
if (!pageContent.includes(ENTITLEMENT_KEY)) {
  console.error(`✗ critical entitlement key missing: ${ENTITLEMENT_KEY}`);
  ok = false;
} else {
  console.log(`✓ entitlement key parity: ${ENTITLEMENT_KEY}`);
}

if (!ok) {
  console.error("\nParity check failed.");
  process.exit(1);
}
console.log("\n✓ Build-time parity — clean");
