# Video Script — He Was Socrates · 3:00

**Target:** Kaggle Gemma 4 Good Hackathon — 30/30 storytelling rubric.
**Format:** YouTube unlisted/public, ≤ 3 minutes, 16:9, 1080p+.
**Voice:** Korean primary (Yuna voice for Socrates bust), English subtitles.
**Aspect:** screen-capture (macOS fullscreen) + B-roll inserts.
**Locked anchors:** `runs/2026-05-05-spec/design-approved.json#video_script_skeleton`
**Persona basis:** `packages/SocraticEngine/Sources/SocraticEngine/Gemma/SystemPrompt.swift` (Part A 산파술 + Part B 현대 한국어 — verbatim from user 2026-05-05).
**Mitigation evidence beats:** M01 (load-bearing 3 features), M02 (compound risk avoided), M04 (visible offline affordance ≤30s), M05 (joy/curious tonal break first), M06 (WCAG 2.2 AA), M07 (regulated-advice abstention is the mechanic), M08 (COPPA child mode mention).

---

## Beat-by-beat (28 beats, 6.4 s avg)

### Cold open · 0:00 – 0:30  (M04 + M05)

**0:00 – 0:05 · BLACK**
- Screen: solid `oklch(0.15 0.01 280)` ink-black.
- Audio: silence.
- Subtitle: *(none — let the silence settle)*

**0:05 – 0:10 · MENU BAR DISAPPEARS** *(M04 evidence #1)*
- Screen-capture (Cmd+Shift+5): cursor toggles fullscreen on `He Was Socrates.app`.
- Visible: macOS menu bar fades out (0.8 s ease), Dock slides down.
- Bottom-right HUD: small `00 KB sent` counter starts ticking (stays at 00).
- Subtitle EN: *"No menu bar. No Dock. No network."*
- Subtitle KO (caption track): *"메뉴바도, Dock도, 네트워크도 없다."*

**0:10 – 0:15 · AIRPLANE MODE TOGGLE** *(M04 evidence #2)*
- Cut to top-right Control Center: user clicks ✈️ Airplane Mode → ON.
- Wi-Fi icon greys out. Activity Monitor sidebar (PIP corner) shows `Network: 0.0 KB/s in · 0.0 KB/s out`.
- Subtitle EN: *"Airplane mode on. Now everything that follows happens on-device."*

**0:15 – 0:30 · ADULT USER WHISPER** *(M05 — joy/curious tone, first 30s)*
- Camera: tight on user's face profile, soft warm light. *(B-roll, 50mm lens.)*
- User (whisper, KO, casual): *"왜 어떤 노래는 들으면 우는지 모르겠어."*
- Cut to fullscreen: bust eyes still closed. A breath.
- Subtitle EN: *"I don't know why some music makes me cry."*

---

### Bust speaks · 0:30 – 0:55  (M01 evidence: Gemma 4 thinking + ask_back)

**0:30 – 0:34 · BUST WAKES**
- Bust's eyes open with a 200 ms cross-fade. Halftone alabaster face on ink-black.
- Top-right "thought silhouette" pulse begins: 2.4 s ease, low-amplitude `oklch(0.32 0.04 285)` glow.
- Lower-third: a faint `curious_adult` chip materializes for 1.2 s, then fades. *(M03 — UP/RP separated; chip accessible per SC1.)*

**0:34 – 0:48 · SOCRATIC ASK_BACK** *(M01 — function-call ask_back load-bearing)*
- Mouth viseme animates per phoneme stream. We will SEE the bust's lower lip move through OW → UH → AA → REST on each syllable.
- Bust voice (Yuna, 0.95×, KO): *"그 노래를 처음 들은 건 누구와 함께였나?"*
- Caption: *"그 노래를 처음 들은 건 누구와 함께였나?"* (32 px, Times New Roman, alabaster)
- Subtitle EN: *"Who were you with the first time you heard that song?"*

**0:48 – 0:55 · USER REACTS**
- Cut back to user — long blink, eyes welling. No dialogue. The silence does the work.
- Bottom-left tiny UI: a wondering log entry materializes briefly (`#noseong-uneun-yeoseong … 14m ago`) and dims out.

---

### Student mode · 0:55 – 1:30  (M05 second tone — learning)

**0:55 – 1:02 · MODE SHIFT TITLE**
- Hard cut to BLACK.
- Centered text fade-in: *"또 다른 모드 / Another mode"*
- 1 s hold, fade.

**1:02 – 1:18 · STUDENT UTTERANCE**
- Cut to bust again. Mode chip changes to `learning_student` (green), with a small 🌱 icon (per SC1 a11y — color alone insufficient).
- Student voice (KO, ~10 yo): *"얼음이 왜 미끄러운지 알아요?"*
- Subtitle EN: *"Do you know why ice is slippery?"*

**1:18 – 1:30 · SOCRATIC ASK_BACK #2**
- Bust replies (Yuna, KO): *"미끄러운 건 얼음 때문일까, 네 손가락이 밀어낸 무엇 때문일까?"*
- Caption: same KO line, alabaster 32 px.
- Subtitle EN: *"Is it the ice that's slippery — or what your finger pushes off?"*
- Word-boundary highlight: each Korean 음절 lit briefly as the bust speaks it.

---

### 14-month time jump · 1:30 – 2:15  (M01 evidence: long-context recall)

**1:30 – 1:36 · TITLE CARD**
- BLACK. Fade in: *"14 개월 후 / 14 months later"*.
- Below in mono: `wondering_log: 47 entries · 0 KB synced ever`.
- 1.5 s hold.

**1:36 – 1:50 · NEW UTTERANCE**
- Same student, now visibly older.
- Student (KO, slightly lower voice): *"비 오는 날 차가 잘 안 멈춰요. 왜 그런 거예요?"*
- Subtitle EN: *"On rainy days the car doesn't stop well. Why?"*

**1:50 – 2:00 · SURFACE_PAST_WONDER ANIMATION** *(M01 — surface_past_wonder load-bearing)*
- Bust pauses. Thought silhouette pulses brighter, period drops to 1.2 s.
- Lower-third UI: small text card slides up from bottom — *"14개월 전: '얼음이 왜 미끄러운지'"* with a soft amber underline (`oklch(0.78 0.15 75)` — `warm_amber_accent`).
- 1.5 s reveal, the card stays bottom-left as bust speaks.

**2:00 – 2:15 · SOCRATIC ASK_BACK #3** *(connector + ask_back composed)*
- Bust (Yuna, KO): *"좋다. 14개월 전에도 자네는 무언가가 미끄러진다고 물었지. 그때 자네가 찾은 답은, 지금 비 오는 도로에도 그대로 통하는가?"*
- Caption + EN subtitle.
- Held 2.5 s of silence after final syllable.

---

### Proof of mechanic · 2:15 – 2:50  (M07 + M02 + M11)

**2:15 – 2:25 · ABSTENTION = MECHANIC** *(M07 evidence)*
- Cut to a dialog snippet: user types "응급실 가야 할까요?" *(should I go to ER?)*.
- Bust does NOT respond with a question. Instead the screen shows a small overlay: `defer_to_human · suggested: 의사 / 119`.
- Bust voice (KO): *"이 질문은 전문가의 도움이 필요하다. 자네에게 더 적합한 사람을 찾아보라."*
- Subtitle EN: *"Socrates does not answer when an expert is needed. He hands you off."*

**2:25 – 2:40 · ACTIVITY MONITOR PROOF** *(M02 + M04 evidence #3)*
- Cut to macOS Activity Monitor over 5 s of bust dialogue:
  - Network: 0.0 KB/s in · 0.0 KB/s out · cumulative 0 B since launch
  - Memory: 3.97 GB (Gemma 4 E4B 4-bit weights + KV cache)
  - GPU: 70 % (MLX-Swift Metal inference)
- Subtitle EN: *"Gemma 4 E4B-IT-4bit · MLX-Swift on Apple Silicon · 0 KB egress, ever."*

**2:40 – 2:50 · CHILD MODE NOTE** *(M08 acknowledgment)*
- Title-card: *"학생 모드 = 부모 동의 흐름 / Student mode requires parental consent flow"*
- Small print: *"COPPA-compliant. Audio is never recorded by default."*

---

### Closing · 2:50 – 3:00

**2:50 – 2:55 · TAGLINE**
- BLACK. Center, alabaster, Times New Roman 64 pt:
  *"소크라테스는 답하지 않는다."*
- 1.5 s hold.

**2:55 – 3:00 · TAGLINE 2**
- Center swap (no transition):
  *"묻는다."*
- 1.0 s hold.
- Cut to BLACK at exactly 3:00.

---

## Voice production notes

- **Bust voice** = AVSpeechSynthesizer Yuna (ko-KR Premium quality, downloadable in System Settings > Accessibility > Spoken Content). All dialog rendered through the actual app — NOT post-recorded.
- **User whisper** = real human (recorded separately).
- **Student** = real child (~10 yo). If unavailable, use AVSpeechSynthesizer ko-KR with a child-modulated pitch.
- **Bilingual subtitle track** = baked-in for the recorded video; YouTube auto-CC also enabled.

## Mitigation evidence checklist (must be visible in final cut)

| ID | Beat(s) | What proves it |
|---|---|---|
| M01 | 0:34, 1:50–2:00, 2:00–2:15 | thinking pulse / surface_past_wonder card / ask_back connector |
| M02 | 2:25–2:40 | Activity Monitor RAM 3.97 GB (E4B only, no 26B) |
| M04 | 0:05–0:10, 2:25–2:40 | menu bar disappears + 0 KB egress over 5 s |
| M05 | 0:15–0:30 | adult joy/curious tone first 30 s, NOT trauma |
| M06 | throughout | mode chip iconography + caption track + 32 px legible serif |
| M07 | 2:15–2:25 | abstention is the product mechanic, not a hidden disclaimer |
| M08 | 2:40–2:50 | parental consent flow acknowledgment |
| M11 | structure | every beat optimized for storytelling 30/30, not for technical depth |

## Shooting checklist

- [ ] Demo Mac: M2 Pro+ fan-cooled, plugged in, 16 GB+ RAM (per `runs/2026-05-05-spec/spec/demo-day-reliability.md`).
- [ ] Yuna voice pre-installed (System Settings > Accessibility > Spoken Content > System Voice > Korean (Korea) > Yuna).
- [ ] ko-KR speech recognition model pre-downloaded.
- [ ] Wondering log seeded with the "ice is slippery" entry from "14 months ago" (timestamp adjusted in fixture).
- [ ] Airplane mode toggle visible in QuickTime/ScreenFlow capture.
- [ ] Activity Monitor pinned, visible in PiP corner.
- [ ] Backup take recorded immediately after primary.
- [ ] Captions pre-burnt-in for both KO and EN streams.

## Cut-down notes

If 3:00 runs over: drop **0:55–1:02 mode-shift title** to gain 7 s, or shorten the **2:25–2:40 Activity Monitor proof** to 10 s.

If under: extend the **0:48–0:55 user reaction silence** by 3–4 s — silence is a feature.
