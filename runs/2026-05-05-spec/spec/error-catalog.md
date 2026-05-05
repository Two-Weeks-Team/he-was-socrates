# Error Catalog — He Was Socrates

**Authored:** 2026-05-05T16:05+09:00 (KST)
**Domain prefix:** `com.twoweeks.hewassocrates.<subsystem>`
**Schema:** every row has `{domain, code, severity, recoverable, retry_strategy, user_surface_modality, user_copy_ko_adult, user_copy_en_adult, user_copy_ko_child, user_copy_en_child, requires_adult_help, telemetry_disposition}`
**Telemetry disposition values:** `discard | local-log-only | user-initiated-export` (no cloud — SC3-017)
**User surface modality values:** `bust_caption_redirect | overlay_modal | overlay_emergency_full_screen | silent_state_change | onboarding_block`

This catalog addresses SC3-001 (catalog absence), SC3-016 (child-mode copy), SC3-017 (crash policy), and is referenced from SPEC.md §8.

> NOTE: copy is seed-quality (KO+EN adult+child). SC4 round-2 critic refines wording; freeze does not require literary perfection.

---

## STT — `com.twoweeks.hewassocrates.stt`

### `STT.PermissionDenied.Microphone`
- severity: blocking, recoverable: true, retry_strategy: user-action-then-relaunch, modality: overlay_modal
- ko_adult: "마이크 사용 권한이 필요합니다. 시스템 설정 > 개인정보 보호 및 보안 > 마이크에서 허용해주세요."
- en_adult: "Microphone permission is needed. Open System Settings > Privacy & Security > Microphone to allow it."
- ko_child: "소크라테스가 너의 목소리를 들으려면 도움이 필요해. 어른과 함께 설정을 열어줘."
- en_child: "Socrates needs help to hear you. Ask a grown-up to open Settings with you."
- requires_adult_help: true
- telemetry: discard

### `STT.PermissionDenied.SpeechRecognition`
- severity: blocking, recoverable: true, modality: overlay_modal
- ko_adult: "음성 인식 권한이 필요합니다. 시스템 설정 > 개인정보 보호 및 보안 > 음성 인식에서 허용해주세요."
- en_adult: "Speech Recognition permission is needed. Open System Settings > Privacy & Security > Speech Recognition."
- ko_child: "어른과 함께 음성 인식을 켜줘."
- en_child: "Ask a grown-up to turn on Speech Recognition."
- requires_adult_help: true

### `STT.PermissionRestricted.ParentalControl`
- severity: blocking, recoverable: false (in-app), modality: overlay_modal
- ko_adult: "이 Mac은 보호자 통제로 음성 인식이 제한되어 있습니다. 보호자에게 문의하세요."
- en_adult: "Speech Recognition is restricted by parental controls on this Mac. Ask a parent or guardian."
- ko_child: "이 기능은 어른의 도움이 필요해."
- en_child: "A grown-up needs to help with this feature."
- requires_adult_help: true

### `STT.OnDeviceModelMissing.ko_KR`
- severity: blocking, recoverable: true, modality: onboarding_block
- ko_adult: "한국어 음성 모델이 설치되어 있지 않습니다. 시스템 설정 > 키보드 > 받아쓰기 > 언어에서 한국어를 추가하고 'On-Device' 모드를 켜주세요."
- en_adult: "Korean on-device speech model is not installed. Open System Settings > Keyboard > Dictation > Languages and add Korean with 'On-Device' enabled."
- (deeplink: `x-apple.systempreferences:com.apple.preference.keyboard?Dictation`)
- ko_child / en_child: "어른과 함께 설정해줘 / Ask a grown-up to set it up."
- requires_adult_help: true

### `STT.OnDeviceModelMissing.en_US`
- (mirror of ko_KR with English locale wording)

### `STT.LowConfidenceTranscription`
- severity: medium, recoverable: true (re-utterance), modality: bust_caption_redirect
- ko_adult: "잘 못 들었어요. 한 번 더 들려줄 수 있나요?"
- en_adult: "I missed that. Could you say it again?"
- ko_child / en_child: same
- This is delivered by Gemma `ask_back` (in-character), NOT by overlay.

### `STT.AudioInterruption.SystemEvent`
- severity: medium, recoverable: true (auto-resume), modality: silent_state_change → overlay_modal if persists
- ko_adult: "시스템 알림으로 듣기가 잠시 중단됐어요. 클릭하면 계속 들을게요."
- en_adult: "Listening paused (system notification). Click to continue."
- recoverable on `NSApplication.didBecomeActive` + permission re-check.

### `STT.RecognitionTaskTimeout`
- severity: medium, recoverable: true, modality: silent_state_change
- (auto-rotate to fresh SFSpeechRecognitionTask every 50s; user does not see error)

### `STT.AudioReadFailed`
- severity: medium, recoverable: true, modality: bust_caption_redirect
- (treat as STT.LowConfidenceTranscription)

### `STT.SilenceTimeout`
- severity: low, NOT an error; idle bust posture transition.

---

## TTS — `com.twoweeks.hewassocrates.tts`

### `TTS.VoiceUnavailable.ko_KR`
- severity: high, recoverable: true (degraded), modality: onboarding_block (first-launch only) + silent_state_change (mid-session)
- ko_adult: "최상의 경험을 위해 시스템 설정 > 손쉬운 사용 > 말하기 콘텐츠 > 시스템 음성에서 'Yuna (향상됨)' 음성을 다운로드해주세요. 지금은 자막과 입 모양으로 계속할게요."
- en_adult: "For the best experience, download 'Yuna (Enhanced)' voice in System Settings > Accessibility > Spoken Content > System Voice. For now I'll continue with captions and lip-sync."
- (deeplink: `x-apple.systempreferences:com.apple.preference.universalaccess?Speech`)
- Degraded mode: text-only captions + viseme animation driven by phoneme stream from g2p (no audio). Bust still "speaks" silently.

### `TTS.VoiceUnavailable.en_US`
- (mirror)

### `TTS.SynthesizerInitFailed`
- severity: high, recoverable: false (mid-session), modality: overlay_modal
- ko_adult: "음성 합성기를 시작할 수 없습니다. 앱을 다시 시작해주세요."
- en_adult: "Speech synthesizer failed to start. Please restart the app."

### `TTS.UtteranceCancelled`
- severity: low, normal state transition (user re-utterance pre-empts).

### `TTS.AudioRouteLost`
- severity: medium, recoverable: true, modality: overlay_modal
- ko_adult: "오디오 출력이 사라졌어요. 스피커나 헤드폰을 연결해주세요."
- en_adult: "Audio output unavailable. Reconnect speakers or headphones."

### `TTS.SystemMuted`
- severity: low, modality: silent_state_change with caption indicator
- ko_adult/en_adult/etc: small `🔇 muted` indicator in caption area; lip-sync continues.

---

## Model — `com.twoweeks.hewassocrates.model`

### `Model.IntegrityMismatch`
- severity: blocking, recoverable: false, modality: overlay_modal (refuse launch)
- ko_adult: "모델 무결성 검사 실패. 공증된 DMG에서 다시 설치해주세요."
- en_adult: "Model integrity check failed. Reinstall from the notarized DMG."
- NEVER attempts re-download (would violate `idea.spec.json#no_go`).

### `Model.BundleMissing`
- (similar; "Model file missing.")

### `Model.LoadFailed.Corrupt`
- (similar; "Model file is unreadable.")

### `Model.InferenceTimeout.Soft`
- severity: medium, recoverable: true, modality: silent_state_change
- thought-silhouette pulse changes amplitude (does NOT break character)
- thresholds: > 15s on M2/M3, > 25s on M1

### `Model.InferenceTimeout.Hard`
- severity: high, recoverable: true (cancel + offer retry), modality: bust_caption_redirect
- threshold: > 45s
- ko_adult: "생각이 좀 길어졌어요. 더 짧은 질문으로 다시 들려줄래요?"
- en_adult: "Thinking is taking longer than usual. Try a shorter question?"

### `Model.ThermalThrottle.Warning`
- severity: medium, recoverable: true (degrade), modality: silent_state_change
- on `NSProcessInfo.thermalState == .serious`: reduce viseme fps to 24, defer `surface_past_wonder`, prefer shorter ask_back.
- on `.critical`: surface overlay "잠깐 쉬어가요 / Let's pause briefly" + freeze on REST viseme.

### `Model.MemoryPressure.Warning`
- severity: medium, modality: silent_state_change
- on macOS `.warning` pressure: free non-essential caches (viseme PNGs evict).

### `Model.MemoryPressure.Critical`
- severity: blocking, recoverable: false (graceful exit), modality: overlay_modal
- ko_adult: "메모리가 부족해요. 다른 앱을 닫고 다시 열어주세요."
- en_adult: "Memory is low. Close other apps and reopen."

### `Model.OOMRecovery.GracefulExit`
- (logs final state, closes Core Data, exits cleanly)

### `Model.RAMInsufficientWarning.M1_8GB`
- severity: medium (warning, not block), modality: onboarding_block (first launch only)
- ko_adult: "이 Mac의 메모리(8GB)에서는 성능이 제한될 수 있습니다. 16GB 이상 Mac을 권장합니다."
- en_adult: "Performance may be reduced on this Mac (8 GB RAM). 16 GB+ recommended."

### `Model.FunctionCall.JSONParseError`
- severity: high, recoverable: true (retry once with stricter prompt, then fallback), modality: silent_state_change
- not user-surfaced unless retry exhausts → bust_caption_redirect with canned safe phrase.

### `Model.FunctionCall.UnknownFunctionName`
- (similar)

### `Model.FunctionCall.RequiredFieldMissing`
- (similar)

### `Model.FunctionCall.EnumOutOfRange`
- severity: medium, recoverable: true (normalize to `unspecified`)
- emit Wonder.modeRaw with the OOR value for diagnostic.

### `Model.FunctionCall.ConfidenceBelowThreshold`
- threshold: < 0.6
- severity: low, recoverable: true (use neutral question template)
- normalize mode to `unspecified`.

---

## Viseme / Lip-sync — `com.twoweeks.hewassocrates.viseme`

### `Viseme.DriftMicro`
- severity: low, recoverable: auto, modality: silent_state_change
- threshold: < 33 ms — no action.

### `Viseme.DriftRecover.SnapToWordBoundary`
- threshold: 33–100 ms — micro-adjust frame duration (skip or repeat one frame). At 100–250 ms, snap to next word boundary.

### `Viseme.StallRecovery`
- threshold: ≥ 250 ms — freeze on REST viseme; emit local-log-only.

### `Viseme.G2P_Failed.Hangul_Edge_Case`
- severity: low, recoverable: auto-fallback (jamo-class heuristic).

### `Viseme.G2P.LoanwordUnknown`
- severity: low, recoverable: auto-fallback.

### `Viseme.PhonemeStreamStalled`
- severity: medium, recoverable: REST viseme.

---

## Storage — `com.twoweeks.hewassocrates.storage`

### `Storage.MigrationFailed`
- severity: blocking, recoverable: true (rollback to .pre-v{N} backup), modality: overlay_modal
- ko_adult: "데이터 마이그레이션 실패. 이전 버전으로 복원하시겠어요?"
- en_adult: "Data migration failed. Restore the previous version?"

### `Storage.DiskFull`
- severity: high, recoverable: true (free space), modality: overlay_modal
- ko_adult: "디스크 공간이 부족합니다. 100MB 이상 확보해주세요."
- en_adult: "Disk space is low. Free at least 100 MB."

### `Storage.Corruption`
- severity: blocking, recoverable: true (export attempt + start fresh), modality: overlay_modal
- ko_adult: "wondering log을 읽을 수 없습니다. 내보내기를 시도하시겠어요? / 처음부터 시작하시겠어요?"
- en_adult: "Wondering log unreadable. Try export? / Start fresh?"

### `Storage.StoreUnavailable`
- (e.g., user manually moved sqlite mid-session)

### `Storage.EncryptionUnavailable`
- (no-op on macOS — relies on FileVault; document)

### `Storage.AudioPurgeFailed.PartialCleanup`
- severity: medium, recoverable: retry-on-next-launch.

---

## Sandbox — `com.twoweeks.hewassocrates.sandbox`

### `Sandbox.NetworkAttemptBlocked`
- severity: warning (counter-only), modality: silent_state_change
- increments OfflineProofBadge "Blocked: N" — visible reassurance, not error.
- emit local-log-only with stack frame for engineering audit.

### `Sandbox.EntitlementMisconfigured`
- severity: blocking, build-time check (CI gate); never reached at runtime.

---

## OS Compatibility — `com.twoweeks.hewassocrates.oscompat`

### `OSCompat.IntelMacUnsupported`
- severity: blocking, modality: overlay_modal (refuse launch)
- ko_adult: "이 앱은 Apple Silicon Mac (M1 이상)에서만 작동합니다."
- en_adult: "This app requires an Apple Silicon Mac (M1 or later)."

### `OSCompat.MacOSTooOld`
- severity: blocking, modality: overlay_modal
- (LSMinimumSystemVersion = 14.0 in Info.plist enforces at install; runtime guard for sideload)

### `OSCompat.M1_8GB_Warning`
- (see Model.RAMInsufficientWarning.M1_8GB)

---

## Defer (regulated advice + emergency) — `com.twoweeks.hewassocrates.defer`

### `Defer.Emergency.HotlineSurfaced`
- severity: high (always succeeds), modality: overlay_emergency_full_screen
- KO emergency: "지금 도움이 필요하다면 자살예방상담전화 1393에 전화하세요. 24시간 무료입니다."
- US-EN emergency: "If you need help right now, call or text 988. It's free, 24 hours a day."
- BYPASSES bust character (per L9 / SC3-024).

### `Defer.Emergency.NoLocaleHotline.Fallback`
- severity: high, modality: overlay_emergency_full_screen
- ko: "가장 가까운 응급 서비스에 연락하세요."
- en: "Contact your nearest emergency services."

---

## Diagnostic — `com.twoweeks.hewassocrates.diagnostic`

### `Diagnostic.LogWriteFailed`
- severity: low, modality: silent_state_change.

### `Diagnostic.LogRotationFailed`
- (similar)

---

## Crash — `com.twoweeks.hewassocrates.crash`

### `Crash.UnhandledException`
- severity: blocking, modality: process-death
- written to `~/Library/Logs/HeWasSocrates/crashdumps/` (rolling 10 MB)
- child-mode redacts userUtterance / socraticReply fields before write (SC3-017).
- user-initiated export only; never auto-uploaded.

---

## Cross-references

- SC3-001 (catalog), SC3-002 (TCC), SC3-003 (locale model), SC3-004 (integrity), SC3-005 (OS guards), SC3-006 (modality), SC3-007 (TTS), SC3-008 (timeout), SC3-009 (function call), SC3-010 (drift), SC3-011/012 (STT), SC3-013 (storage), SC3-014 (sandbox), SC3-015 (OOM), SC3-016 (child copy), SC3-017 (crash), SC3-018 (size — separate doc), SC3-019 (g2p — separate doc), SC3-020 (mode), SC3-021 (TTS), SC3-022 (keyboard — see SPEC.md §7.4), SC3-023 (audio opt-in), SC3-024 (emergency)
- SC7-013 (TCC revocation state machine — same as STT.* permission rows)
- L16 (error surface modality), L19 (consent), L20 (entitlements)
