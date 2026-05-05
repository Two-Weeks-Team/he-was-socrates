# Network Egress Test Plan — He Was Socrates

**Authored:** 2026-05-05T16:20+09:00 (KST)
**Addresses:** SC3-014, SC7-001, SC7-020, M04 (OfflineProofBadge)

---

## 1. Engineering proof of "0 byte egress"

The OfflineProofBadge (M04) is a TRUST SIGNAL, not a live network probe (a live probe would itself be a network call). Its boolean state is set at build time. The engineering proof of the underlying invariant is layered:

### Layer 1: Build-time gate (CI)

Refuses to ship if the `network.client` entitlement creeps into the bundle.

```sh
codesign -d --entitlements :- ./HeWasSocrates.app | \
  grep -q "network\\.client\\|network\\.server" && exit 1
echo "GATE PASS: no network entitlements"
```

### Layer 2: Telemetry-SDK string scan (CI)

```sh
strings -a HeWasSocrates.app/Contents/MacOS/HeWasSocrates | \
  grep -E "(sentry\\.io|datadoghq|mixpanel|segment\\.io|amplitude\\.com|crashlytics|firebase|appcenter)" \
  && exit 1
echo "GATE PASS: no telemetry SDK strings"
```

### Layer 3: Runtime NSURLProtocol shim

Installed at `NSApplicationDidFinishLaunching` BEFORE any framework gets a chance to fire a request. Catches any request attempted by any framework or transitive dependency, converts it to a `Sandbox.NetworkAttemptBlocked` event, and increments a counter visible in the OfflineProofBadge as "Blocked: N" (in normal operation, N = 0).

```swift
final class EgressBlockingProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        // Trap EVERYTHING. Log + reject.
        Diagnostics.logBlockedAttempt(request.url?.absoluteString ?? "<nil>")
        OfflineProofBadge.incrementBlockedCounter()
        return true
    }
    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: NSError(
            domain: "com.twoweeks.hewassocrates.sandbox",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Network egress blocked by app policy."]))
    }
    override func stopLoading() {}
}

// Registration at app launch, before any framework loads:
URLProtocol.registerClass(EgressBlockingProtocol.self)
```

### Layer 4: Demo-day live verification

Documented in `spec/demo-day-reliability.md` and shown on-camera at video timestamp 2:30–2:50:

```sh
# Show on-camera during demo:
nettop -p $(pgrep HeWasSocrates) -P -t wifi
# Expected output: 0 bytes during a 5-minute session
```

Plus visual: System Settings > Privacy & Security > Network — "He Was Socrates" shows "Never" or absent.

Optional reinforcement (if available on demo Mac):
- Little Snitch with rule-set: deny all from HeWasSocrates → no prompts during 5-minute session.
- macOS Network filter (NetworkExtension framework with `nm.framework`).

---

## 2. SFSpeechRecognizer cloud-fallback prevention

```swift
let request = SFSpeechAudioBufferRecognitionRequest()
request.requiresOnDeviceRecognition = true
```

If the locale model is unavailable, recognition fails with an explicit error (per `STT.OnDeviceModelMissing.{ko_KR|en_US}` in error-catalog.md). It does NOT silently fall back to Apple's network recognizer. SC4-015 + L20.

---

## 3. MetricKit + Crash Reporter

- `MetricKit` framework not linked.
- macOS CrashReporter writes locally to `~/Library/Logs/DiagnosticReports/`. Apple does NOT auto-upload these without user opt-in via System Settings → Privacy & Security → Analytics & Improvements (system-level, not app-controlled). The app surfaces this dependency in About > Privacy.

---

## 4. mDNS / Bonjour

- App does NOT advertise or browse Bonjour services.
- Sandbox default permits mDNS UDP responses; we do not listen.
- Verification: `lsof -p $(pgrep HeWasSocrates) -i` shows no UDP/TCP except loopback or none.

---

## 5. Test schedule

| When | Step | Pass criterion |
|---|---|---|
| Every CI build | Layer 1 entitlement scan | exit 0 |
| Every CI build | Layer 2 telemetry SDK scan | exit 0 |
| Every release tag | Layer 4 manual `nettop` recording | 0 bytes over 5 min |
| Demo day | Live `nettop` on screen | 0 bytes |

---

## 6. Cross-references

- M04 OfflineProofBadge (design-approved.json), L20, SC3-014, SC7-001, SC7-020
