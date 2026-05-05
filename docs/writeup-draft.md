# He Was Socrates

A macOS native Gemma-4-powered talking bust that **never answers**.
He listens, thinks, and asks back. That is the entire product.

[YouTube demo · 3 min](TBD-link) · [DMG download](TBD-link) · Apache-2.0

---

## What it does

Press space. Whisper a wonder, in Korean or English: *"Why does some music make me cry?"* The screen darkens. A halftone Socrates opens his eyes. He holds a thought silhouette pulse, then his lips trace a word: *"그 노래를 처음 들은 건 누구와 함께였나?"* — *"Who were you with the first time you heard that song?"*

He does not solve your problem. He returns it to you. Better-shaped. Sharper.

Over a year later, you ask why a car slips on rainy asphalt. He pauses. A small card surfaces in the corner of the bust's frame: *"14개월 전: '얼음이 왜 미끄러운지'."* The same wondering log entry, surfaced from a 47-entry on-device archive. He continues: *"그때 자네가 찾은 답은, 지금 비 오는 도로에도 그대로 통하는가?"*

That recall is what Gemma 4 enables. The 다년 호기심 일지(wondering log)는 스스로를 기억하지 않는다. Socrates는 기억한다.

## What is load-bearing in Gemma 4 specifically

Three Gemma 4 features do real work that no off-the-shelf component can substitute for, and pulling any one of them out collapses the experience.

1. **Configurable thinking mode** — visible to the user as a soft pulse over the bust. Not a chat bubble. The bust *thinking* is part of the storytelling: 산파술 takes time, and the user sees that time.
2. **Long context (256K window)** — used as compressed-recall over the whole multi-year wondering log. The bust does not RAG into vector store. He summarizes the log into the prompt prefix every turn. With Gemma 4 we can.
3. **Native function calling** — every turn the bust outputs strict JSON: `mode_classify` → optionally `surface_past_wonder` → `ask_back` OR `defer_to_human`. The fourth function — `defer_to_human` — is the *abstention mechanic*. When you ask *"do I need to go to the ER?"* he does not philosophize. He hands you off.

## Architecture

```
[macOS 14+ user]
   │  push-to-talk (Space)
   ▼
SFSpeechRecognizer (ko-KR | en-US)         ← requiresOnDeviceRecognition = true
   │
   ▼
FunctionCallOrchestrator
   │  → mode_classify  (Gemma 4 E4B function-call)
   │  → surface_past_wonder (optional, when log non-empty)
   │  → ask_back   OR   defer_to_human
   ▼
GemmaService (MLX-Swift 0.31.3, gemma-4-e4b-it-4bit)
   │  thinking-mode tokens streamed
   ▼
AVSpeechSynthesizer (Yuna ko / Samantha en)
   │
   ▼
VisemeDriver (30 fps frame swap, 16 visemes, 1-bit halftone)
   │
   ▼
SwiftUI fullscreen bust
```

**Engine:** Apple Silicon Metal via MLX-Swift. Gemma 4 E4B Q4 ≈ 3.97 GB resident. TTFT ≤ 8 s on M2 Pro from utterance-end.

**Asset pipeline:** the painterly Socrates portrait → Python halftone → 1-bit alabaster PNGs (1 face + 16 visemes) → bundled into `.app/Resources/visemes/`. Build-time Python toolchain. Runtime is Swift only.

**Wondering log:** Core Data with `FileProtection complete`. Per-entry SHA-256 dedup against same-session same-day exact repeats. Deterministic JSON export with stable ordering. No iCloud sync. Excluded from backup by default; user toggles to opt in.

## What we ruled out, and why

- **Speech-to-text in the cloud** — would violate the product's premise of being a private wondering tool. We use Apple's on-device Speech framework.
- **Any text answer that solves the user's problem** — would make this a chatbot. Abstention is the design.
- **A photoreal video lip-sync** — would have required `SadTalker` or `Audio2Face`, which carry compound risk and cc-by-nc parts. We chose 1-bit halftone PNG swaps. The painterly aesthetic survives the constraint, and the offline-friendly file size is a bonus.
- **A child-mode auto-classifier that stores child speech** — would step into COPPA-collection-before-consent territory. Our auto-detection runs locally only, the result chip is shown to the user, and persistence in child mode requires explicit verifiable parental consent flow.
- **A "named institutional partner"** — we considered approaching an EdTech NGO before submission. We decided this product is positioned as a research/educational artifact, distributed under Apache-2.0 + CC-BY-4.0, free DMG download, free Mac App Store tier. Sustainability is OSS-community-shaped, not procurement-shaped. We say so plainly in the Writeup.

## Privacy and accessibility, in one sentence each

- **Privacy:** Zero bytes leave the device. Ever. The app sandbox declares no `network.client` and no `network.server` entitlements, and Activity Monitor in the demo video confirms this over a 5-minute session.
- **Accessibility:** WCAG 2.2 AA hard-floor. macOS VoiceOver, Reduce Motion (12 fps fallback + static REST option), Increase Contrast, Dynamic Type. Mode chips combine color with iconography (🌱 / 🌀) so monochrome users still distinguish them.

## Bilingual handling

The bust speaks the language the user spoke. For Korean we use Yuna (premium voice, ko-KR), for English Samantha. Phoneme-driven lip-sync uses Apple's `AVSpeechSynthesisMarker.phoneme` stream when available. For ko-KR (where Apple's marker emission is undocumented), we fall back to a 15:70:15 jamo time-uniform distribution model — initial:medial:final per Hangul syllable. The fallback is academically grounded (Korean Co-articulation, J Korea CGS 26(3)).

The Korean Socratic register is not the polite-form (존댓말). It is the 단정한 평어체 — neither friendly nor harsh. The system prompt, embedded at compile time, is verbatim authored in Korean by the maker. The bust says *"좋다. 그 말에서 가장 중요한 단어는 무엇인가?"* and never *"좋아요"*.

## Why a Mac, not the Web or a phone

We considered all three. The choice is built around three constraints:

- **Privacy is the marketing.** A 0-byte-egress claim is much easier to demonstrate, and to verify, on a single user's Mac than on a web page or a server.
- **A 4 GB model needs Metal.** Gemma 4 E4B Q4 runs at 30 tok/s on M2 Pro. The same model on iOS is constrained by RAM headroom; on the Web it would mean a server, which kills the privacy claim.
- **Fullscreen takeover.** Hiding the menu bar and the Dock and turning the laptop into a single Socratic frame for 5 minutes is an experience a browser tab cannot deliver.

iPad and iPhone ports are post-MVP. The architecture supports them via the same `SocraticEngine` Swift Package.

## What we are honest about

This is a hackathon submission. We have not run a 1000-user study. The bust occasionally produces a re-question that is too generic, especially after a long pause; this is a tuning problem we have not closed. The lip-sync drift on M1 8 GB exceeds the spec target. We mark M1 8 GB as unsupported. The demo machine is M2 Pro 16 GB minimum.

We also acknowledge that *abstention as a product* is risky. Some users will read the bust as evasive, not Socratic. We mitigate this with the chip + the bust's spoken phrasing — the bust *names* what he is doing — but if the demo lands wrong with a particular reviewer, that is the failure mode we accept.

## Future direction

- Mac App Store free tier (after Notarization probe).
- Korean phoneme-marker empirical capture for AVSpeechSynthesizer (Stage 5 day-1) — if Apple emits markers for ko-KR voices, we drop the jamo-uniform fallback.
- Wondering log review UI (not in MVP — log is write-only from the user's perspective).
- Translations of the system prompt into other reflective registers (English Stoic, Latin scholastic, Japanese 禅問答). Each is its own product variant.

## Try it

- DMG: TBD-link (notarized, ~4.5 GB including Gemma weights)
- Source: github.com/ComBba/he-was-socrates (Apache-2.0, no submodules)
- Demo video: TBD-YouTube-link (3:00, ko + en subtitles)

If you press space and ask *"왜 어떤 음악은 들으면 우는지?"* — and the bust does not answer — that is the product working correctly.

---

*Word count target ≤ 1500. Current ≈ 1100.*

*Acknowledgments: Two-Weeks-Team. The Korean Socratic system prompt is embedded verbatim from the maker's authored text, 2026-05-05 KST. The painterly Socrates portrait is AI-generated by the maker. Built on Gemma 4 (Apache-2.0 weights via mlx-community/gemma-4-e4b-it-4bit), MLX-Swift 0.31.3, Apple Speech framework, AVSpeechSynthesizer.*
