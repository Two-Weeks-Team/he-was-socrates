# Data Flow Diagram — He Was Socrates (M08 COPPA explicit)

**Authored:** 2026-05-05T16:35+09:00 (KST)
**Addresses:** M08, SC7-004, L19, SC7-018

---

## 1. Adult-mode (self_adult consent) data flow

```
┌──────────────────────┐
│ User microphone      │
│ (NSMicrophoneUsage)  │
└──────────┬───────────┘
           │ AVAudioEngine PCM buffer (in-process)
           ▼
┌──────────────────────────────────────────────┐
│ SFSpeechRecognizer                           │
│ requiresOnDeviceRecognition = true           │  [no egress: forced on-device]
│ locale = ko-KR or en-US                      │
└──────────┬───────────────────────────────────┘
           │ user_utterance: String (final transcription)
           ▼
┌──────────────────────────────────────────────┐
│ Swift Orchestrator                           │
│   1. defer_to_human  (Gemma function-call)   │  [in-process MLX-Swift]
│   2. mode_classify   (Gemma function-call)   │
│   3. ask_back ‖ surface_past_wonder          │
└──────────┬───────────────────────────────────┘
           │ TokenDelta stream (ask_back)
           ▼                        ┌───────────────────────────┐
┌──────────────────┐                │ surface_past_wonder       │
│ AVSpeechSynth    │                │ → reads from Core Data    │
│ + viseme paint   │                │   (read-only this turn)   │
└──────────┬───────┘                └───────────────────────────┘
           │ speech audio + visemes (display only)
           ▼
        [user]
           ↑
           │ (no further data path; nothing returns)
           
End-of-turn:
┌──────────────────────────────────────────────┐
│ Core Data write (Wonder + SemanticTag)       │
│   ~/Library/Application Support/com.tw...    │
│   NSURLIsExcludedFromBackupKey = true        │
│   FileVault user-level encryption            │
│   (no egress arrow; local only)              │
└──────────────────────────────────────────────┘
           
                 ╳ NETWORK SEVERED ╳
       (entitlements: network.client = false,
        network.server = false; NSURLProtocol shim
        traps any framework-level attempt and
        increments OfflineProofBadge "Blocked")
```

---

## 2. Child-mode (parent_direct_basic consent) data flow

```
┌──────────────────────────────────────────────┐
│ FIRST LAUNCH GATE (BEFORE microphone init)   │
│  "Who is using this app?"                    │
│   • Adult (13+)                              │
│   • Child (under 13) — needs adult to set up │
│  default = no microphone activation          │
└──────────┬───────────────────────────────────┘
           │ Choice = "Child"
           ▼
┌──────────────────────────────────────────────┐
│ Verifiable Parental Consent (parent_direct_  │
│   basic): in-app form                        │
│   • Parent name (typed)                      │
│   • Today's date                             │
│   • Consent checkbox: "I confirm I am the    │
│     parent/guardian. I consent to on-device  │
│     -only processing of my child's voice.    │
│     No data leaves this device."             │
│   • Time Machine caveat disclosed (SC7-010)  │
│ AppMeta.consentSource = parent_direct_basic  │
│ AppMeta.consentScreenAcceptedHash =          │
│   SHA-256(consent text shown)                │
└──────────┬───────────────────────────────────┘
           │ consent captured
           ▼
[ same flow as adult-mode, with: ]
  • caption forced-on (override impossible) (L18)
  • font scale +20% (Larger Text base × 1.2) (SC1-011)
  • viseme fps user-configurable but default Tier 2 (12 fps) (SC1-011)
  • ask_back reading_level cap = 6 (Korean grade-equiv ~elementary)
  • automatic-utterance start FORBIDDEN (SC1-004 strengthened)
  • defer_to_human threshold lower (SC1-011)
  • 24h retention timer on every Wonder row + audio file
  • cascade SemanticTag delete when last child Wonder purged
```

### Auto-detection safety net (SC7-004 (c))

If first-launch was "Adult" but `mode_classify` returns `learning_student` with confidence ≥ 0.6 and the utterance pattern indicates likely under-13 (heuristic: short sentences, present-tense, simple vocabulary), the orchestrator:
1. PAUSES the bust at REST (no `ask_back` dispatched).
2. PURGES the just-collected `userUtterance` and any partial Wonder row (atomic via Core Data context discard).
3. SHOWS the consent gate overlay: "It looks like a child is using this app. We'd like an adult to help set it up first."
4. Resumes only after consent gate completes.

---

## 3. NEGATIVE flow (everything that does NOT happen)

| Path | Status |
|---|---|
| HTTP server listening | ABSENT (no `network.server` entitlement) |
| HTTP client outbound | BLOCKED (no `network.client` + NSURLProtocol shim) |
| AppleScript `.sdef` | ABSENT (no scripting dictionary shipped) |
| NSXPC service | ABSENT |
| URL scheme handler | ABSENT |
| Universal Links | ABSENT |
| Share extension | ABSENT |
| Spotlight CoreSpotlight indexing | ABSENT (Wonder rows NOT exposed to Spotlight) |
| Siri Shortcuts donation | ABSENT |
| Debug WebSocket | ABSENT |
| File-watch outside container | ABSENT (FSEvents on user's Documents/etc. NOT subscribed) |
| MetricKit | NOT linked |
| Sentry / Crashlytics / Mixpanel / Segment / Amplitude / Datadog / Bugsnag / AppCenter | NOT linked (CI gate enforces) |
| Voice cloning | FORBIDDEN |
| Cloud STT fallback | EXPLICITLY DISABLED via `requiresOnDeviceRecognition = true` |
| Auto-update (Sparkle) | NOT included |
| Bonjour service advertise/browse | NOT used |

This negative declaration is the binding posture for SC2-010 + SC7 cluster.

---

## 4. Data lifecycle invariants

| Invariant | Mechanism |
|---|---|
| User utterance audio: never persisted unless user opts in per-Wonder | Wonder.audioFilePathLocal nullable; opt-out triggers immediate purge within 60 s (SC3-023) |
| User utterance text + reply: persisted as Wonder row (immutable) | Wonder fields immutable after first save (SC5-07) |
| Child-mode 24h retention | Background timer scheduled at Wonder.createdAt + 24h purges Wonder + audio + cascade SemanticTag |
| Right-to-erasure (GDPR Article 17) | Settings > Data > "Delete all wondering log" — atomic deletion of Core Data store + all audio |
| Right-to-portability (GDPR Article 20) | Settings > Data > "Export wondering log" — canonical byte-stable JSON (SC5-12) |
| Crash logs: redact user utterance/reply | SC3-017 child-mode field redaction before write |

---

## 5. Future school deployment reservation (SC7-018, out of MVP)

```
School-MDM variant (POST-MVP, reserved):
  AppMeta.consentSource = "school_authorized"
  Session.deploymentContext = "school_mdm"
  → consent delegated to school under COPPA 312.5(c) sliding-scale
  → SchoolAgreement.pdf at /licenses/SCHOOL_DEPLOYMENT/
  → still no central data store; still 0-byte egress
```

Schema reservation in `coredata-model.md` already includes the enum values; no migration required when feature ships.

---

## 6. Cross-references

- M08 (design-approved.json), L19 (consent), L20 (entitlements), SC7-004 (VPC), SC7-010 (FileVault macOS reconciliation), SC7-018 (school reservation), SC1-011 (child a11y defaults), SC3-023 (audio opt-in lifecycle)
