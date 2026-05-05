# Demo-Day Reliability Checklist — He Was Socrates

**Authored:** 2026-05-05T16:30+09:00 (KST)
**Owner:** demo operator (Two-Weeks-Team)
**Run before:** every video shoot, every live demo
**Addresses:** SC6-19, M04, M11

---

## 1. Hardware (REQUIRED tier — L4)

- [ ] Mac model = MacBook Pro M2 Pro/Max OR Mac mini M2/M2 Pro OR Mac Studio
- [ ] RAM ≥ 16 GB (recorded: ____ GB)
- [ ] macOS version = 14.x (recorded: 14._)
- [ ] arm64 architecture (sysctl `hw.optional.arm64` returns 1)
- [ ] Free disk space ≥ 50 GB
- [ ] Power plugged in, battery ≥ 80% as backup
- [ ] **Backup machine** with identical config also pre-flighted

If only M2 Air available → DEGRADED tier — bigger TTFT margin needed; warn-only banner shown to user; document for video shoot.

## 2. System voices and speech models (SC6-12, SC6-13)

- [ ] Korean Yuna **Enhanced** voice downloaded (Settings > Accessibility > Spoken Content > System Voice > Manage Voices)
  - alternative: Heami Enhanced
- [ ] English Samantha **Enhanced** voice downloaded (or Alex)
- [ ] Korean dictation language pack downloaded (Settings > Keyboard > Dictation > Languages → Korean → "On-Device" enabled)
- [ ] English dictation language pack downloaded with on-device enabled
- [ ] App-level probe at launch returns `supportsOnDeviceRecognition == true` for both ko-KR and en-US

## 3. Network (M04 OfflineProofBadge)

- [ ] Airplane mode ON
- [ ] Wi-Fi off
- [ ] Ethernet unplugged
- [ ] Bluetooth off (avoids AirDrop traffic appearing in `nettop`)
- [ ] Verify with `nettop -p $(pgrep HeWasSocrates) -P -t wifi` shows 0 bytes

## 4. Audio I/O (SC6-15)

- [ ] Output device = built-in speakers OR wired headphones (NOT AirPods or Bluetooth)
- [ ] System volume not muted, ~60% level
- [ ] Microphone tested with the demo phrases at intended speaking distance
- [ ] `AVAudioSession.outputLatency` < 50 ms verified (or compensation enabled)

## 5. Performance hygiene (SC6 cluster)

- [ ] Activity Monitor: idle CPU < 5%, RAM available > 4 GB, no concurrent ML processes
- [ ] Spotlight not actively indexing (`mds_stores` CPU < 1%)
- [ ] Screen recorder NOT running during inference timing (record TTFT separately, then re-record with recorder on)
- [ ] Other heavy apps closed (browser tabs, IDE, etc.)
- [ ] Thermal state at start: `.nominal` (verify via `NSProcessInfo.thermalState`)

## 6. App preflight (cold + warm)

- [ ] App installed from notarized DMG
- [ ] First cold launch performed at least 30 minutes before recording (lets Spotlight/Gatekeeper finish)
- [ ] Second launch (warm path) used for the actual shoot
- [ ] Model integrity check passes at launch (no `Model.IntegrityMismatch` overlay)
- [ ] OfflineProofBadge showing "Blocked: 0" at start of session

## 7. Sample utterances rehearsed end-to-end

- [ ] Korean adult: "왜 어떤 노래는 들으면 우는지?"
- [ ] Korean child: "얼음이 미끄러워요"
- [ ] English: "Why does some music make me cry?"
- [ ] 14-month time-jump scenario rehearsed at least 2 times (rain/tire/grip → ice surfacing)

## 8. Crash plan

- [ ] If app hangs > 10 s → on-camera recovery: cancel inference (Cmd+. period), let bust freeze on REST, calmly say "let's rephrase," retry
- [ ] If app crashes → graceful relaunch within 30 s with backup machine ready

## 9. Cooldown protocol

- [ ] ≥ 2 minutes idle between consecutive 3-minute video takes (thermal budget)
- [ ] Watch for `.serious` thermalState; if reached, abort take, cool down, retry

## 10. COPPA mode (if recording child-mode segment)

- [ ] First-launch consent gate completed with parent_direct_basic
- [ ] Child-mode caption forced-on confirmed
- [ ] Adult-mode shown to NOT auto-collect child-mode-style utterances without re-consent

## 11. Recording

- [ ] Screen recorder framerate 60 fps (don't record at 30 fps; you'll undersample drift)
- [ ] Microphone for capturing the operator's spoken utterance is SEPARATE from the system mic doing STT (use a USB mic for the camera; built-in for the app), to avoid double-trigger
- [ ] Storage destination has > 10 GB free for the recording

## 12. Post-shoot verification

- [ ] OfflineProofBadge "Blocked: 0" still showing
- [ ] `~/Library/Logs/HeWasSocrates/crashdumps/` empty
- [ ] No telemetry SDK strings in binary (CI gate already enforced; smoke-check `strings` on demo Mac if paranoid)
- [ ] Wondering log entries for the demo session present, byte-stable JSON export verified

## 13. Demo video evidence beats

Per `design-approved.json#video_script_skeleton`:
- 0:00–0:10: menu bar disappears + airplane-mode toggle visible (M04)
- 2:30–2:50: Activity Monitor showing 0 network requests + RAM under cap (per L3)
- Optional inset: live `nettop` output

## 14. Shoot-day printable

Print this checklist + recorded values; sign at the bottom.

```
Operator: ______________
Date: ______________
Mac: ______________
RAM: ______________
macOS: ______________
TTFT first take (ms): ______________
TTFT third take (ms): ______________ [thermal check]
Drift RMS sample: ______________
OfflineProofBadge Blocked counter end-of-session: ______________
Sign: ______________
```
