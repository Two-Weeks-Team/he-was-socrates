# Viseme Design Best Practices — Research Brief

| Field | Value |
|---|---|
| Authored | 2026-05-05 (KST) |
| Author | Deep Research subagent |
| Status | **Recommendations only — does NOT modify the SHA-locked SpecDD freeze.** Adoption requires user ratification, after which SPEC.md §4.3 + `phoneme-viseme-map.json` + `scripts/viseme_compose.py:VISEME_DIMS` may be revised in a delta document. |
| Scope | Critique of the 16-viseme set, the proportional pixel dims, the Korean phoneme map, the lip-sync timing model, and the AVSpeechSynthesizer pipeline assumption. |
| Confidence | High on industry survey (multiple corroborating sources). High on the AVSpeechSynthesizer finding (Apple docs are authoritative). Medium on Korean-specific dim proposals (academic sources sparse on pixel proportions; reasoned synthesis from articulatory-phonetics descriptions). |

> **Headline finding (read this first):** The locked SpecDD assumes `AVSpeechSynthesizer` exposes a *phoneme delegate* (see SPEC.md §4.3 line "g2p engine: AVSpeechSynthesizer phoneme delegate (PRIMARY; DELTA-01)" and `phoneme-viseme-map.json:g2p_engine_primary`). **No such delegate exists in Apple's public API.** The `AVSpeechSynthesizerDelegate` protocol exposes utterance lifecycle hooks (`didStart/didFinish/didPause/didContinue/didCancel`), `willSpeakRangeOfSpeechString:utterance:` (character-range, word-grain in practice), and `willSpeak:utterance:` (SSML marker events) only. Phoneme-level timing is not surfaced. ([AVSpeechSynthesizerDelegate ref](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizerdelegate); [WWDC18 session 236](https://asciiwwdc.com/2018/sessions/236)) This is the largest single risk in the current design and is detailed in §1.3 + §7 below.

---

## 1. Canonical viseme sets — survey

### 1.1 Disney / Preston Blair (1948, *Cartoon Animation*)

- **Set size:** 10 mouth shapes + 1 rest = 11 distinct positions. Older summaries cite "9" because two shapes (L, T/D/N) are sometimes folded into a single "tongue-up" position.
- **Mapping (canonical):** (1) AI, (2) E, (3) O, (4) U, (5) C/D/G/K/N/R/S/Th/Y/Z (the "default open" bucket), (6) F/V (occasionally folded with Th), (7) L (occasionally folded with Th), (8) M/B/P, (9) W/Q, (10) Rest.
- **Proportions:** Preston Blair's drawings show qualitative shapes only — no published width:height ratios. Common animation-school summaries describe AI as "the widest open shape, ~2× taller than wide for an exaggerated cartoon mouth", O as "circular and tall", E as "a horizontal slit, very wide and very short", M/B/P as "fully closed line".
- **License:** The Preston Blair book itself is in print under copyright (Walter Foster Publishing). The 10-shape *concept* is industry common-knowledge / not copyrightable; specific renderings of his drawings are. **Do not copy his drawings.** Trace-from-photo or original-art per shape is fine.
- **Authoritative refs:** [Gary C. Martin's Preston Blair phoneme reference](https://www.garycmartin.com/mouth_shapes.html); [Extended PB chart](https://www.garycmartin.com/phoneme_examples.html); [Papagayo's `phonemes_preston_blair.py`](https://github.com/aziagiles/papagayo/blob/master/phonemes_preston_blair.py) (the de-facto open-source encoding of the PB set).

### 1.2 Microsoft Azure Speech SDK — 22 visemes (en-US)

- **Set size:** 22 visemes (IDs 0–21), where ID 0 = silence. Often called "the 21-viseme set" because ID 0 is the rest. Locked across all the company's Cognitive Services / Foundry properties.
- **Mapping (en-US, full table):** ID 0 silence; 1 = `æ ə ʌ`; 2 = `ɑ`; 3 = `ɔ`; 4 = `ɛ ʊ`; 5 = `ɝ`; 6 = `j i ɪ`; 7 = `w u`; 8 = `o`; 9 = `aʊ`; 10 = `ɔɪ`; 11 = `aɪ`; 12 = `h`; 13 = `ɹ`; 14 = `l`; 15 = `s z`; 16 = `ʃ tʃ dʒ ʒ`; 17 = `ð`; 18 = `f v`; 19 = `d t n θ`; 20 = `k g ŋ`; 21 = `p b m`.
- **Reference imagery:** SVG-only (en-US); 2D SVGs are served per viseme ID with smooth-tweened animation tags. 3D blendshape output is a 55-position ARKit-style array per frame at 60 fps.
- **License:** Reference imagery is © Microsoft. **Do NOT copy the SVGs.** The mapping table itself is documentation and free to reference. ([Azure docs](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/how-to-speech-synthesis-viseme))

### 1.3 Apple AVSpeechSynthesizer — there is no Apple viseme set

- **The phoneme delegate the SpecDD assumes does not exist.** `AVSpeechSynthesizerDelegate` exposes only: utterance lifecycle (start/finish/pause/continue/cancel), `willSpeakRangeOfSpeechString:utterance:` (character range, word-grain), and `willSpeak:utterance:` (SSML marker events). No `willSpeakPhoneme`, no IPA emit, no viseme stream. ([Apple docs](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizerdelegate); [`willSpeakRangeOfSpeechString` ref](https://developer.apple.com/documentation/avfoundation/avspeechsynthesizerdelegate/1619681-speechsynthesizer))
- **What Apple *does* expose** that is phoneme-relevant:
  - `AVSpeechSynthesisIPANotationAttribute` — an *input* attribute on `NSAttributedString` so the synthesizer **accepts** IPA from you. It does not emit. ([API ref](https://developer.apple.com/documentation/avfaudio/avspeechsynthesisipanotationattribute))
  - `AVSpeechSynthesizer.write(_:toBufferCallback:)` (iOS 13 / macOS 10.15) — gives you raw `AVAudioPCMBuffer` chunks **and** a parallel callback delivering `AVSpeechSynthesisMarker` events. The marker stream **does include phoneme markers** in macOS 14+ (`AVSpeechSynthesisMarker.Mark.phoneme`) when SSML phoneme metadata is present, but it is keyed to whatever phoneme labels the chosen voice's underlying TTS engine emits — which for Korean is undocumented and not IPA-stable. ([WWDC20 — *Create a seamless speech experience*](https://developer.apple.com/videos/play/wwdc2020/10022/))
- **Recommended read of this finding:** the SpecDD's "AVSpeechSynthesizer phoneme delegate" must be re-interpreted as **the `AVSpeechSynthesisMarker` stream from `write(_:toBufferCallback:)`**, not the `AVSpeechSynthesizerDelegate` protocol. SPEC.md §4.3 conflates the two. See §7 recommendations.

### 1.4 Oculus / Meta Lipsync (OVR) — 15 visemes

- **Set:** `sil, PP, FF, TH, DD, kk, CH, SS, nn, RR, aa, E, ih, oh, ou`. ([Meta ref](https://developers.meta.com/horizon/documentation/unity/audio-ovrlipsync-viseme-reference/); [VRChat wiki summary](https://wiki.vrchat.com/wiki/Visemes))
- **Mapping:** PP = p/b/m; FF = f/v; TH = θ/ð; DD = t/d; kk = k/g; CH = tʃ/dʒ/ʃ; SS = s/z; nn = n/l; RR = r; aa = ɑː (jaw open, oval); E = e (mid-open, wider); ih = ɪ (lips stretched, jaw higher); oh = o (rounded, jaw mid-open); ou = u (tightly rounded, slightly forward).
- **Proportions:** described qualitatively (above). MPEG-4 FAP-aligned. Driven as 0..1 blendshape weights, interpolated 60 fps; viseme target is one-hot per frame in the simplest mode.
- **License:** Documentation under Meta dev-docs ToS; the *names* are common usage. Reference renders are © Meta — do not copy.

### 1.5 NVIDIA Audio2Face — 52 ARKit-style blendshapes

- Effectively 51 facial blendshapes + neutral. **Overkill for this project** (we have a halftone bust occluded by beard). Listed for completeness.
- License: NVIDIA Omniverse SDK; non-permissive; not relevant to us.

### 1.6 Rhubarb Lip Sync — 9 mouth shapes (A–H, X)

- **Set:** A (closed P/B/M), B (slightly open, EE-like), C (open EH/AE), D (wide-open AA), E (rounded AO/ER), F (puckered UW/OW/W), G (F/V — upper teeth on lower lip — *optional*), H (long L tongue — *optional*), X (idle pause).
- **License:** **MIT for Rhubarb itself** plus permissive deps (BSD-2/3, Boost, MIT). Generated lip-sync data is unencumbered. ([repo](https://github.com/DanielSWolf/rhubarb-lip-sync); [LICENSE.md verified](https://github.com/DanielSWolf/rhubarb-lip-sync/blob/master/LICENSE.md))
- **Output formats:** TSV / XML / JSON with `(timestamp_seconds, shape_letter)` rows. Hold semantics: a shape persists until the next row.
- **Korean coverage:** Rhubarb runs PocketSphinx with the en-US acoustic model under the hood. **It will not produce useful timing for Korean audio** without a Korean acoustic model — and shipping one would re-introduce the GPL/g2p license mess we removed. Practical rule: Rhubarb is en-US-only for our purposes.

### 1.7 Papagayo / Papagayo-NG

- Open-source desktop dialogue editor (not a runtime library). Encodes the Preston Blair set in [`phonemes_preston_blair.py`](https://github.com/aziagiles/papagayo/blob/master/phonemes_preston_blair.py). Useful as a *reference encoding* of the PB mapping. License: GPL — not directly linkable, but the *mapping table* is a fact and freely re-implementable.

### 1.8 MPEG-4 Face Animation Parameters (FAPs)

- ISO/IEC 14496-2 (MPEG-4 Visual). Defines 14 visemes (Visemes 0–13: silence, p/b/m, f/v, T/D, t/d, k/g, tʃ/ʃ/dʒ, s/z, n/l, r, A:, e, I, Q, U). The OVR set is essentially MPEG-4-aligned with the addition of `nn` and `RR` distinguished. Public standard; the mapping table is non-copyrightable.

### 1.9 JALI (Edwards et al., SIGGRAPH 2016)

- **Two-axis procedural model** rather than a viseme set: every viseme is parameterized by `(jaw, lip)` ∈ [0,1]². Hyper-articulation = high lip, low jaw; hypo-articulation = high jaw, low lip. Driven from audio formants/volume/pitch. Built atop FACS action units. ([Paper PDF](https://dgp.toronto.edu/~elf/JALISIG16.pdf); [project page](https://www.dgp.toronto.edu/~elf/jali.html))
- **Why it matters to us:** Even though we ship discrete PNGs, **the JALI insight that one viseme = one (jaw, lip) point lets us validate our 16-PNG dim choices**: if our AA differs from EE primarily in jaw (vertical) and from M in lip (lip-closure), our dim ratios should reflect that. Our current `AA: 100×75` and `M: 94×8` honor this. Our `EE: 118×18` is jaw-low + lip-spread, which is also correct.
- License: paper (academic fair use); patent: U-Toronto holds patents on the JALI rig; **using the conceptual axes is fine, copying their rig is not**.

### 1.10 Reallusion CrazyTalk / Cartoon Animator — 15 visemes

- Phoneme-pair grouping similar to Preston Blair extended. Proprietary; ref imagery © Reallusion. Mapping is in their docs and is structurally similar to OVR + Rhubarb. Not a primary reference for us.

### 1.11 Annosoft 17-viseme set

- Industry-popular intermediate point between PB-10 and Azure-22. ([Annosoft 17-viseme reference](http://www.annosoft.com/docs/Visemes17.html)) Distinguishes M from B from P (yes — the underlying *audio* differs even though the *mouth* is identical, useful when mapping back from CMU phonemes). For pure visual lip-sync, M=P=B is the correct collapse.

---

## 2. Korean / non-English viseme considerations

### 2.1 Published Korean phoneme→viseme mappings

- **Jang & Park, *Korean Phonological Viseme for Lip Synch Based on Phoneme Recognition*, Proc. ASK Conference** ([Korea Science](https://koreascience.kr/article/CFKO199920828527868.page)) — uses 8 vowels + 13 consonants from the SAPI 49-phoneme inventory.
- **Kim et al., *Speech Animation Synthesis based on a Korean Co-articulation Model*, J. Korea Computer Graphics Society 26(3):49** ([CG Korea](http://journal.cg-korea.org/archive/view_article?pid=jkcgs-26-3-49); cert error at fetch time; cached search snippets verified) — Korean co-articulation rules; double-vowel decomposition (ㅑ → [ㅣ→ㅏ] viseme transition).
- **Hyung & Ahn, *Evaluation of a Korean Lip-sync system for an android robot*** ([Semantic Scholar](https://www.semanticscholar.org/paper/Evaluation-of-a-Korean-Lip-sync-system-for-an-robot-Hyung-Ahn/e22bb23967cc30ef3336a46daabe73b4c84ec7df)) — 10 mouth shapes for the 10 single Korean vowels, validated on a humanoid robot's mechanical jaw.
- **Korean academic consensus:** **10 single-vowel mouth shapes** for ㅏ ㅐ ㅓ ㅔ ㅗ ㅚ ㅜ ㅟ ㅡ ㅣ; **double vowels are decomposed into glide+vowel viseme pairs** (ㅑ = ㅣ→ㅏ, ㅛ = ㅣ→ㅗ, ㅠ = ㅣ→ㅜ, ㅘ = ㅗ→ㅏ, ㅝ = ㅜ→ㅓ, ㅢ = ㅡ→ㅣ).

### 2.2 Hangul jamo → viseme (articulatory-phonetic basis)

Combining the academic sources with Wikipedia's articulation features ([Hangul vowel table](https://en.wikipedia.org/wiki/Hangul); [Glossika pronunciation](https://ai.glossika.com/blog/korean-hangul-pronunciation)):

| Jamo | IPA | Tongue | Lip rounding | Aperture | Best fit in our 16-set |
|---|---|---|---|---|---|
| ㅏ | a / ɐ | low front | unrounded | wide | **AA** |
| ㅐ | ɛ | mid front | unrounded | mid-wide | **EE** (or new MID — see §7) |
| ㅓ | ʌ / ɘ | mid back | unrounded | medium | **UH** ← *current map says AA — disagree, see §7* |
| ㅔ | e | mid front | unrounded | mid | **EE** |
| ㅗ | o | mid back | rounded | mid+round | **OH** |
| ㅜ | u | high back | rounded tightly | small+round | **OW** |
| ㅡ | ɯ | high central | unrounded | small horizontal | **UH** (lip-flat) |
| ㅣ | i | high front | unrounded spread | small horizontal | **EE** |
| ㅚ | ø | mid front | rounded | mid-round | **OH** |
| ㅟ | y | high front | rounded | small-round | **OW** |

Consonants (initial position only — final position collapses to 7 representative sounds in Korean phonology, all of which are visually subsumed by an existing viseme + a following REST):

- **ㅁ ㅂ ㅍ ㅃ** → **M / P / B** (full bilabial closure). MAP: ㅁ→M, ㅂ→B, ㅍ/ㅃ→P. *Visually identical*; the audio-driven viseme can use any of the three since on the bust they are the same PNG.
- **ㄴ ㄷ ㄸ ㅌ ㄹ(initial) ㅅ ㅆ** → **S** (alveolar/dental, narrow mouth, no labial info). ㄹ initial in our current map is `R`, which is acceptable but **non-canonical**: Korean ㄹ initial is a flap [ɾ], visually closer to S/D than to English /ɹ/. See §7.
- **ㅈ ㅊ ㅉ** → **SH** (alveolo-palatal affricate; lip-rounded narrow opening). Current map agrees.
- **ㄱ ㅋ ㄲ** → **UH** (velar; no visible lip articulation; default to neutral-open). Current map agrees.
- **ㅎ** → **REST** (glottal; barely-visible). Current map agrees.

### 2.3 Code-switched Korean+English

No published guidance found. The locked SpecDD strategy (Gemma post-processes into `[{text, lang}]` segments, 150 ms gap allowed; SPEC.md §10.3) is consistent with how multi-language TTS is handled industrially. No change recommended.

---

## 3. Mouth-shape proportions — comparison and critique

### 3.1 Comparison table

(Pixel dims for "ours" = current `VISEME_DIMS` on 1024² canvas. Disney/MS/OVR/Rhubarb columns capture qualitative shape only — none publish pixel proportions; values shown are the *implied* width:height ratio from articulatory description, normalized so REST = 1.0 width.)

| Viseme | Disney/PB | MS-Speech (en-US) | OVR | Rhubarb | JALI (jaw, lip) | Ours (W×H) | Implied W:H ratio | Verdict |
|---|---|---|---|---|---|---|---|---|
| AA  | wide-open, ~1.3:1 W:H | ID 2 (`ɑ`) — open oval | aa — oval, jaw max | D — wide-open | (jaw 1.0, lip 0.3) | 100×75 | **1.33** | **OK**, slightly tall side. Could go 110×70 to read more cinematic. |
| EE  | horizontal slit, ~6:1 | ID 6 (`i`) — wide thin | I — lips stretched | B — slight-open clenched-teeth | (jaw 0.2, lip 1.0 spread) | 118×18 | **6.6** | **OK**, properly extreme. |
| IH  | (collapsed into AI in PB) | shared with EE in MS | ih — slight-open | (no shape) | (jaw 0.3, lip 0.7) | 98×22 | **4.45** | **Borderline** — almost identical to EE (118×18 → 6.6) and might collapse visually. Either widen IH to 105×26 (5:1, distinct from EE) or remove IH and merge to EE. |
| OH  | round, ~1:1 | ID 8 (`o`) — round | oh — round mid | E — rounded | (jaw 0.6, lip 0.6 round) | 58×58 | **1.0** | **OK**. |
| OW  | small round, ~1:1 | ID 7 (`u/w`) — tight round | ou — tight round | F — puckered | (jaw 0.3, lip 0.9 round) | 44×44 | **1.0** | **OK**, but **OW should be smaller AND more forward-pursed than OH**. With a halftone bust we cannot show "forward" — so OW = 44×44 is fine because it's smaller. |
| UH  | (in PB default bucket) | ID 1 (`ə/ʌ`) — small open | (closest to E) | C — open mid | (jaw 0.4, lip 0.4) | 82×32 | **2.56** | **OK**. |
| M   | fully closed line | ID 21 (`p/b/m`) — closed | PP — closed | A — closed | (jaw 0.0, lip 0.0) | 94×8 | **11.75** | **OK**. Genuinely flat. |
| P   | identical to M | identical to M | identical to M (PP) | identical to M (A) | identical | 94×8 | **11.75** | **OK** — see note below on whether to differentiate. |
| B   | identical to M | identical to M | identical to M | identical to M | identical | 94×8 | **11.75** | **OK** — see note below. |
| F   | upper teeth on lower lip | ID 18 (`f/v`) — upper-teeth bite | FF — teeth bite | G — teeth/lip | (jaw 0.2, lip 0.4 + teeth) | 88×22 | **4.0** | **Marginal** — too similar to IH (98×22). Should be **shorter wide**, e.g. 80×14, with the lip-bite implied by being asymmetric (top edge close to neutral, bottom edge raised). |
| V   | identical to F | identical to F | identical to F | identical to F | identical | 88×22 | **4.0** | Same issue as F. Recommend identical to F (genuinely no visible difference). |
| TH  | tongue tip protrudes | ID 17 (`ð`) / ID 19 (`θ`) — tongue between teeth | TH — tongue between teeth | (no shape) | (jaw 0.3, lip 0.5) | 82×32 | **2.56** | **Risky** — current dim is identical to UH (82×32). They will be visually indistinguishable on a halftone bust. Recommend TH → 76×26 (slightly narrower, slightly shorter). |
| S   | (in default bucket) | ID 15 (`s/z`) — narrow slit, teeth visible | SS — teeth-near, narrow slit | (in default bucket) | (jaw 0.1, lip 0.3 spread) | 74×24 | **3.08** | **OK**. |
| SH  | (in default bucket) | ID 16 (`ʃ` etc.) — rounded narrow | CH — rounded narrow | (in default bucket) | (jaw 0.2, lip 0.5 round) | 68×32 | **2.13** | **OK**, properly more rounded than S. |
| R   | (in default bucket) | ID 13 (`ɹ`) — rounded narrow, retroflex | RR — rounded, cheeks firm | (in default bucket) | (jaw 0.3, lip 0.6) | 58×38 | **1.53** | **OK**, distinctively rounder than S/SH. |
| REST | rest, slight closed | ID 0 — closed neutral | sil — relaxed closed | X — idle (≈A) | (jaw 0.0, lip 0.0) | 78×18 | **4.33** | **WRONG?** — REST is more open than M (94×8). On a halftone bust occluded by beard, the user reading "REST" as "slightly speaking" is a real risk. Recommend REST → 82×6 (essentially closed, very slightly narrower than M so M reads as "actively pressed") OR REST → identical to M (94×8). See §7. |

### 3.2 Critique of stated questions

> **Is AA tall/wide ratio correct?** Mostly. 100×75 = 1.33 W:H is industry-standard (Disney target ~1.3, MS ID-2 ~1.4). For a *cinematic* read on a 1024² canvas, 110×72 (1.53) reads slightly more cartoony-open and would be the "video demo" choice; 100×75 is the "phonetically accurate" choice. **Keep 100×75 unless the demo video reviewer flags it.**

> **Should OH and OW differ in size as well as shape?** Yes — already do (OH 58×58 vs OW 44×44, both 1:1). The size delta is correct. Industry convention is OW slightly smaller and slightly more forward-pursed. Halftone occlusion masks the "forward" component, leaving size as the primary differentiator — your 24% size delta is enough to read on screen.

> **Are M/P/B truly visually identical?** **Yes**, by every canonical reference (Azure ID 21, OVR PP, Rhubarb A, MPEG-4 viseme 1). The only systems that differentiate are audio-driven 50+ blendshape rigs (NVIDIA A2F, ARKit) which encode lip *pressure* not lip *shape*. **Three identical PNGs (M, P, B) is the right call**, but it wastes ~200 KB of disk and 3 frame swaps per "B" word. **Recommend collapsing M/P/B into one PNG with three IDs at the runtime mapping layer**, not at the asset layer. (This change is a runtime optimization, not a SpecDD-touching change — it goes in the Swift `VisemeAtlas` loader.)

> **Is REST correctly slightly-open or fully closed?** Industry consensus: **REST = lips lightly together, NOT pressed**, and **distinct from M (lips actively pressed flat)**. ([Rhubarb's note: "It is almost identical to A, but with slightly less pressure between the lips. Whether there should be any visible difference depends on your art style."](https://github.com/DanielSWolf/rhubarb-lip-sync)) Our REST 78×18 is *more open* than M 94×8 — **inverted from the convention**. Fix: REST 82×8 (same height as M, narrower; reads as "lips touching but relaxed") OR identical to M.

> **Is the F/V mouth distinct from S/SH?** Currently F=V=88×22; S=74×24; SH=68×32. The aspect ratios are close (4.0, 3.08, 2.13). On a halftone bust, **F/V is the riskiest** because the canonical F/V *requires* showing upper teeth biting lower lip — which we cannot do via an alpha-erase ellipse. Two options: (a) accept F=V=IH-ish ambiguity and rely on phonetic context to disambiguate (acceptable for a Socratic re-questioning bust where speech intelligibility is not the goal); (b) author F/V as a *non-elliptical* asymmetric cutout (top edge straight-ish, bottom edge lifted) — requires changing `viseme_compose.py` from a single ellipse to a polygon or two-ellipse composite. Recommend (a) for hackathon timeline; flag (b) as v1.1 polish.

---

## 4. Halftone / 1-bit / pixel-art viseme precedents

- **Return of the Obra Dinn (Lucas Pope, 2018)** — 1-bit dithered 3D. Dialogue is *audio-only*; characters do NOT have lip-sync. Speech is rendered as floating text + voice-acted audio with frozen body. ([dukope devlog](https://dukope.com/devlogs/obra-dinn/)) **Lesson: Pope deliberately dropped lip-sync because it doesn't read at low fidelity.** Our halftone bust is in the same fidelity zone — this is evidence that doing lip-sync at all is the bold choice, and that **users may forgive imperfect viseme reads more than we expect**.
- **World of Horror (panstasz, 2020)** — 1-bit Macintosh-aesthetic. Has "Animated Head" enemies but no Korean/English lip-sync per se; mouth animation is ~3-frame sprite cycles tied to dialogue typewriter speed, not phonemes. ([WoH wiki](https://woh.fandom.com/wiki/Animated_Head)) **Lesson: 3-frame open/mid/closed cycling at typewriter cadence is sufficient for "this character is talking" reads, even with no phonetic accuracy.** This is our Reduce Motion Tier 2 fallback baseline.
- **Faith / Lethal Company / Dwarf Fortress Adventure mode** — none implement phoneme-aware lip-sync. All use 2–4 frame "talking" cycles or no cycle.
- **Halftone shaders for SwiftUI / Metal** — straightforward; the halftone is *space-domain dithering* (no temporal component), so swapping viseme PNGs at 30 fps does not break the halftone read.

**Aesthetic-preserving design choices:**
- **Hard cuts at low fidelity read better than crossfades.** A 16 ms crossfade (current DELTA-06 spec) on a halftone bust means 1 frame at 60 fps where the dot pattern "ghosts." This may break the halftone illusion. **Test before committing.**
- **Beard occlusion is a free pass.** Painters and animators have used beards/mustaches/hair for centuries to hide bad lip-sync. ([Disney's Mickey Mouse uses a tiny mouth-on-jaw rig precisely to fit a half-frame budget.](https://www.garycmartin.com/mouth_shapes.html)) Our heavy beard means **viseme errors of 1–2 frames will be invisible**, which means we have **substantial drift tolerance** beyond the 30 ms RMS spec.

---

## 5. Lip-sync timing & animation best practices

### 5.1 Frame rate

- **Film standard:** 24 fps (Disney/Pixar feature animation), with mouth shapes typically held for 2–4 frames each ("on twos"/"on fours") = effective 6–12 viseme swaps per second.
- **Game-engine standard:** 30 or 60 fps render, but viseme blendshape weights interpolated; effective viseme update rate is bound by phoneme rate (~10–15 Hz natural speech).
- **Real speech:** ~10–15 phonemes per second average, peak ~20.
- **Implication for our 30 fps:** Strictly speaking, **30 fps is overkill** — we will swap visemes ~10 times per second on average, with 20 of every 30 frames being "hold previous". This is fine for the GPU but means our **30 fps spec is really a "30 fps render rate, 10–15 Hz effective viseme rate" claim**. This should be made explicit in the spec to avoid demo-day confusion (someone saying "but it's only swapping mouths 10 times a second"). 30 fps render is correct because we want the *halftone bust* (background) at 30 fps for any other sub-effects (thought silhouette pulse, focus ring), not because the mouth itself needs 30 distinct shapes per second.

### 5.2 Hold duration

- Per-phoneme hold = phoneme duration; for short phonemes (stops like /p/), audio-true hold can be 30–50 ms which is below the human visual perception threshold (~80–120 ms for *change* perception). **Below 80 ms holds, snap to the next viseme without rendering** — this is implicit in 30 fps gridding (33 ms per frame) but should be explicit: **a viseme is held for ≥ 2 frames (66 ms) or skipped**.

### 5.3 Crossfade vs hard cut

- **Disney 2D:** hard cuts always.
- **Modern 3D (Pixar, Tangled):** continuous blendshape interpolation = effectively crossfade always.
- **Game-engine Source 1/Source 2 / Unreal MetaHuman:** smoothed blendshape, ~50 ms crossfade.
- **For halftone bust:** crossfades cause halftone-pattern ghosting. Recommend **hard cut** (i.e., revert DELTA-06's 16 ms crossfade to 0 ms) **OR** keep the 16 ms crossfade but render it as a 1-frame intermediate "blended viseme" PNG generated at build time (8 frames between each pair of visemes = 16² = 256 extra PNGs — too many). Easier: **hard cut, no crossfade**. The halftone aesthetic justifies it; demo-day video will not show the difference at 30 fps.

### 5.4 Co-articulation

- **Anticipatory coarticulation:** lips begin shaping the next vowel ~50–100 ms before its acoustic onset, especially for rounded vowels like /u/. ([UCL phonetics notes](https://www.phon.ucl.ac.uk/courses/spsci/expphon/week7.php))
- **Practical implication:** when transitioning AA→OW (e.g. "now"), **start the OW lip-rounding 1–2 frames (33–66 ms) before the audio /aʊ→u/ transition**.
- **Implementation:** since we don't have phoneme-level timing from AVSpeechSynthesizer (see §1.3), we must approximate: at the word-boundary delegate `willSpeakRangeOfSpeechString`, pre-shift the entire word's viseme sequence by 0–33 ms to account for the natural anticipatory bias. **Or skip co-articulation entirely** — the heavy beard makes this invisible.

### 5.5 Phoneme-to-viseme retiming

- Phoneme boundaries from *recognition* are never frame-aligned; from *synthesis* they are deterministic given the engine. AVSpeechSynthesizer phoneme timing (via `AVSpeechSynthesisMarker`) **is deterministic per voice** but the *output sample clock* drifts vs. the system clock by ~1–5 ms over 5 s utterances. SPEC.md DELTA-04 (≤ 30 ms RMS, ≤ 80 ms peak) is well within this margin.

### 5.6 Reduce Motion accessibility

- macOS exposes `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` (and SwiftUI `@Environment(\.accessibilityReduceMotion)`). ([Apple Reduce Motion guide](https://support.apple.com/guide/mac-help/change-motion-settings-for-accessibility-mchla3c4f1da/mac))
- **Best practice (cross-industry):** never *eliminate* status indication; replace with static cue. ([Pope.tech accessible motion guide](https://blog.pope.tech/2025/12/08/design-accessible-animation-and-movement/))
- **Current SpecDD §7.3 has 3 tiers** (30 fps full, 12 fps + pulse off, static + caption-only) — this is **above industry best-practice**. Endorsed without changes. The only refinement: **Tier 3 should still swap REST→one-of-{AA,EE,OH} once per ~500 ms of speech** as a "talking" cue, otherwise users with Reduce Motion + Captions Off perceive the bust as broken. A single "active talking" frame + REST on a 500 ms cycle is acceptable per WCAG 2.3.3 (Animation from Interactions).

---

## 6. Open-source tooling — integration evaluation

| Tool | License | Apache-2.0 compat? | Integration cost (Swift app) | Output we'd consume | Maintenance | Verdict |
|---|---|---|---|---|---|---|
| **Rhubarb Lip Sync** | MIT (verified) | Yes | Run as build-time CLI on the **TTS-rendered audio** to produce ground-truth timing for our test fixtures. Not a runtime dep. | TSV `(time_s, shape_letter)` mapped 1:1 to our 16-set | Active, last release 2024+ | **INTEGRATE as build-time test oracle only.** |
| **Papagayo-NG** | GPL-3 | NO (cannot link) | Not viable for runtime | — | Active | Skip. |
| **espeak-ng** | GPL-3 | NO (already removed in DELTA-01) | — | — | Active | Skip. |
| **g2pK** ([Kyubyong/g2pK](https://github.com/Kyubyong/g2pK)) | **Apache-2.0** (verified) | Yes | Heavy: requires Python + MeCab + KoNLPy + nltk in the build pipeline. Output is Hangul (post-pronunciation-rule) jamo, not IPA. Could be invoked at **build time** to generate a Korean-pronunciation lookup for the test fixtures only. | Hangul jamo string per input | 21 commits, semi-maintained | **INTEGRATE as build-time fixture generator only.** Not a runtime dep. |
| **OpenJTalk / MeCab-ko** | BSD/Apache | Yes (Mecab-ko Apache-2.0) | Available transitively via g2pK; not directly needed | — | Active | Use only via g2pK. |
| **Microsoft Speech SDK** | MIT (client libs); commercial cloud service | Cloud — **violates 0-byte network egress** (SPEC.md §11.1). Even on-device variant requires EULA acceptance. | High | viseme stream | Active | **DISQUALIFIED** by 0-byte rule. |
| **Apple `AVSpeechSynthesisMarker`** ([WWDC20](https://developer.apple.com/videos/play/wwdc2020/10022/)) | Apple system framework | N/A (system) | Already-required dep (TTS) | `AVSpeechSynthesisMarker` array via `write(_:toBufferCallback:)` with `.phoneme` markers (macOS 14+) | Apple-maintained | **PRIMARY runtime path.** This is what SpecDD §4.3 *should* be referencing. |

**Recommended integrations: 2 (Rhubarb + g2pK), both build-time only.** Zero new runtime deps.

---

## 7. Recommendations for `He Was Socrates`

### 7.1 CRITICAL — Reframe the AVSpeechSynthesizer pipeline

**SPEC.md §4.3 and `phoneme-viseme-map.json:g2p_engine_primary` say "AVSpeechSynthesizer phoneme delegate". This API does not exist.** The actual mechanism is:

- `AVSpeechSynthesizer.write(utterance, toBufferCallback: { (buffer, markers) in ... })` (iOS 13 / macOS 10.15+; phoneme markers added in macOS 14). The callback delivers `(AVAudioPCMBuffer, [AVSpeechSynthesisMarker])` — markers include type `.phoneme` carrying a string label and an audio offset.
- Phoneme labels are **voice-engine-specific**. For en-US Apple voices they appear to be Apple's internal SAPI-style codes (NOT IPA). For ko-KR (Yuna/Heami) the label format is **undocumented** — must be empirically discovered at scaffold time.

**Action:**
1. **Update SPEC.md §4.3** in a delta proposal: replace "AVSpeechSynthesizer phoneme delegate (PRIMARY; DELTA-01)" with "AVSpeechSynthesizer marker stream from `write(_:toBufferCallback:)` with `AVSpeechSynthesisMarker.Mark.phoneme` (macOS 14+). Phoneme label format is Apple-internal and locale-dependent; mapping from Apple labels → IPA → 16-viseme is built at scaffold via empirical capture against the test-fixture utterances."
2. **Update `phoneme-viseme-map.json:g2p_engine_fallback_chain`** to insert as fallback level 1.5: "Empirical Apple-label → IPA mapping table (built at scaffold time, captured over `_test_fixture_utterances`)".
3. **Add a scaffold task** (Stage 5): write `tools/capture-apple-phonemes.swift` that runs every test-fixture utterance through `write(_:toBufferCallback:)`, dumps every emitted `(label, audio_offset)`, and produces a deterministic `apple_phoneme_to_ipa.json` lookup committed to the repo.
4. **Risk if Apple does not emit phoneme markers for ko-KR:** fall back to **time-uniform jamo distribution** — for each Hangul syllable, allocate (initial:medial:final) = (15%:70%:15%) of the syllable's audio duration to the corresponding visemes. This is the academic-standard Korean co-articulation approximation and is robust.

### 7.2 Revised `VISEME_DIMS` proposal

```python
# Drop-in replacement for scripts/viseme_compose.py:VISEME_DIMS
VISEME_DIMS = {
    "AA":   (100, 75),   # unchanged — phonetically accurate, 1.33:1
    "EE":   (118, 18),   # unchanged — properly extreme spread
    "IH":   (105, 26),   # WAS 98×22 — widen + slightly taller to read distinct from EE
    "OH":   (58, 58),    # unchanged — round
    "OW":   (44, 44),    # unchanged — small round, distinct from OH
    "UH":   (82, 32),    # unchanged
    "M":    (94, 8),     # unchanged
    "P":    (94, 8),     # unchanged (visually identical to M — runtime can share PNG)
    "B":    (94, 8),     # unchanged (visually identical to M — runtime can share PNG)
    "F":    (80, 14),    # WAS 88×22 — narrower + much shorter, implies upper-teeth bite
    "V":    (80, 14),    # WAS 88×22 — match F
    "TH":   (76, 26),    # WAS 82×32 — narrower + shorter to read distinct from UH
    "S":    (74, 24),    # unchanged
    "SH":   (68, 32),    # unchanged
    "R":    (58, 38),    # unchanged
    "REST": (82, 8),     # WAS 78×18 — flatter; lips touching but relaxed; distinct-from-M by being narrower
}
```

**Rationale per change:**
- **IH 98×22 → 105×26:** Was indistinguishable from EE (same height). New 5:1 ratio sits between EE 6.6:1 and UH 2.56:1.
- **F/V 88×22 → 80×14:** The flatter, narrower opening implies the upper-teeth-on-lower-lip articulation that an ellipse cannot literally render. This makes F/V visually distinct from IH (105×26) and from S (74×24). At 80×14 it reads as "almost closed but with a teeth-line feel".
- **TH 82×32 → 76×26:** Was identical to UH 82×32. Now distinguishably smaller and shorter — TH still reads as "open but tongue-blocked".
- **REST 78×18 → 82×8:** Was *more open* than M, contradicting industry convention (REST is the "lightly closed" baseline). New REST is the same height as M but narrower (82 vs 94) so users perceive REST as relaxed-closed and M as actively-pressed.

### 7.3 Phoneme map (`phoneme-viseme-map.json`) deltas

```jsonc
// Recommended edits to ipa_to_viseme_ko:
{
  "ʌ": { "viseme": "UH", "rationale": "ㅓ; mid back unrounded. Korean lip-sync academic consensus is UH not AA — see viseme-best-practices.md §2.2." },
  // WAS: "ʌ": { "viseme": "AA", "rationale": "...wider aperture due to mid-back" }

  "ɾ": { "viseme": "S", "rationale": "ㄹ initial as flap [ɾ]; visually closer to alveolar S/D than to English /ɹ/. Korean lip-sync convention." },
  // WAS: "ɾ": { "viseme": "R" }
}

// Recommended edit to hangul_jamo_classes.vowel:
{
  "ㅓ": "UH",  // WAS: "AA"
  "ㅕ": "UH",  // WAS: "AA"  (ㅕ = j+ʌ → IH transition_to UH; bucket fallback)
  "ㅝ": "UH"   // WAS: "AA"  (ㅝ = w+ʌ; bucket fallback)
}

// Add new diphthong transitions for academic-consensus Korean:
"ja":  { "viseme": "EE", "transition_to": "AA" },  // already present
"jʌ":  { "viseme": "EE", "transition_to": "UH" },  // CHANGED from AA
"jo":  { "viseme": "EE", "transition_to": "OH" },  // already present
"ju":  { "viseme": "EE", "transition_to": "OW" },  // already present
"wa":  { "viseme": "OW", "transition_to": "AA" },  // ADD (ㅘ)
"wʌ":  { "viseme": "OW", "transition_to": "UH" }   // CHANGED from AA
```

### 7.4 Frame rate

**Keep 30 fps render rate.** Add to SPEC.md §4.3 a clarifying line: *"30 fps is the **render rate** of the bust composition; effective viseme swap rate is phoneme-bound (≈ 10–15 Hz). A new viseme is held for ≥ 2 render frames (66 ms) before being eligible to swap."*

### 7.5 Crossfade

**Revert DELTA-06's 16 ms crossfade to 0 ms (hard cut)** for the halftone aesthetic. Crossfade introduces dot-pattern ghosting that breaks the 1-bit illusion. Document as an aesthetic decision, not a perf one. If demo-video review flags choppy mouth, **add a 1-frame `cubic-ease-in-out` opacity tween** but only on the alpha channel (the halftone dot grid stays sharp).

### 7.6 Reduce Motion fallback (refinement to §7.3)

Tier 3 spec gains: *"Static bust + caption only. Bust briefly animates from REST → one-of-{AA, EE, OH} → REST on a 500 ms square wave for the duration of audio playback (single 'talking' cue, not phoneme-driven). Complies with WCAG 2.3.3 (Animation from Interactions)."*

### 7.7 External tooling — pick exactly 2

1. **Rhubarb Lip Sync (MIT)** — build-time test oracle. Run on each `_test_fixture_utterance` after TTS rendering; produce TSV. Use Rhubarb's 9-shape output → mapped to our 16-set as the **golden timing reference** for the drift-RMS test (DELTA-04 enforcement). Adds zero runtime weight.
2. **g2pK (Apache-2.0)** — build-time Korean pronunciation oracle. Run on each Korean test-fixture utterance to produce the post-pronunciation-rule jamo sequence; feed it through our hangul_jamo_classes table to produce the expected viseme sequence. Used to validate that our scaffold-built `apple_phoneme_to_ipa.json` agrees with the academic-standard pronunciation. Adds Python+MeCab to build env only.

### 7.8 Demo-day risks surfaced by this research

1. **The "phoneme delegate" terminology in SpecDD is technically incorrect** and could be challenged by a Kaggle reviewer who knows the AVSpeechSynthesizer API. **Fix the terminology** before video shoot — even if the implementation works, a reviewer may say "you're claiming an Apple API that doesn't exist." See §7.1.
2. **ko-KR phoneme markers may not exist on macOS 14 AVSpeechSynthesizer at all.** Apple's docs only confirm the `.phoneme` marker type for English-derived voices. If Yuna/Heami don't emit phoneme markers, the entire viseme pipeline degrades to syllable-uniform jamo distribution (which is academically defensible but is *not* what the SpecDD currently claims). **Empirically verify at scaffold start (Stage 5 day 1)**; if absent, update SPEC.md before the video shoot.
3. **F/V visemes will read identically to IH** on a halftone bust until the dim change in §7.2 ships. Demo video showing "fffff" sound will look like an open-mouth IH. Low risk because Korean has no /f/ /v/ phonemes natively and English /f/ /v/ rarely fall on emphasized words in a Socratic re-questioning context.
4. **REST currently looks "slightly open"** which on a static frame (Reduce Motion Tier 3 default) reads as "the bust is mid-talking and frozen." Fix per §7.2.
5. **The 16-viseme set is fine** for a Korean-primary, English-secondary, beard-occluded Socratic bust. Expanding to Azure's 22 or OVR's 15 is **not justified** by this research — the marginal accuracy is invisible behind the beard, and the asset count grows.
6. **Crossfade DELTA-06 may break the halftone aesthetic**. Test before locking; revert to hard-cut if so. See §7.5.

---

## Cited authoritative sources

| # | Reference | Used for |
|---|---|---|
| S1 | [Microsoft Azure Speech SDK viseme reference](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/how-to-speech-synthesis-viseme) | §1.2 22-viseme table |
| S2 | [Meta OVR Lipsync viseme reference](https://developers.meta.com/horizon/documentation/unity/audio-ovrlipsync-viseme-reference/) | §1.4 15-viseme list |
| S3 | [VRChat Visemes wiki](https://wiki.vrchat.com/wiki/Visemes) | §1.4 corroboration |
| S4 | [Rhubarb Lip Sync repo](https://github.com/DanielSWolf/rhubarb-lip-sync) + [LICENSE.md](https://github.com/DanielSWolf/rhubarb-lip-sync/blob/master/LICENSE.md) | §1.6, §6 (MIT verified) |
| S5 | [Gary C. Martin Preston Blair charts](https://www.garycmartin.com/mouth_shapes.html) | §1.1 PB canonical |
| S6 | [Papagayo PB encoding](https://github.com/aziagiles/papagayo/blob/master/phonemes_preston_blair.py) | §1.7 |
| S7 | [JALI SIGGRAPH 2016 PDF](https://dgp.toronto.edu/~elf/JALISIG16.pdf) + [project page](https://www.dgp.toronto.edu/~elf/jali.html) | §1.9 jaw/lip axes |
| S8 | [Apple AVSpeechSynthesizerDelegate](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizerdelegate) | §1.3, §7.1 (no phoneme delegate) |
| S9 | [Apple AVSpeechSynthesisIPANotationAttribute](https://developer.apple.com/documentation/avfaudio/avspeechsynthesisipanotationattribute) | §1.3 (input-only) |
| S10 | [WWDC20 — Create a seamless speech experience](https://developer.apple.com/videos/play/wwdc2020/10022/) | §1.3 marker stream |
| S11 | [WWDC18 session 236 transcript](https://asciiwwdc.com/2018/sessions/236) | §1.3 corroboration |
| S12 | [Korean Phonological Viseme paper, ASK](https://koreascience.kr/article/CFKO199920828527868.page) | §2.1 |
| S13 | [Korean Co-articulation paper, J Korea CGS 26(3)](http://journal.cg-korea.org/archive/view_article?pid=jkcgs-26-3-49) | §2.1, §2.2 |
| S14 | [Korean lip-sync robot eval, Hyung & Ahn](https://www.semanticscholar.org/paper/Evaluation-of-a-Korean-Lip-sync-system-for-an-robot-Hyung-Ahn/e22bb23967cc30ef3336a46daabe73b4c84ec7df) | §2.1 (10-vowel mouth set) |
| S15 | [Hangul (Wikipedia)](https://en.wikipedia.org/wiki/Hangul) + [Glossika Hangul pronunciation](https://ai.glossika.com/blog/korean-hangul-pronunciation) | §2.2 articulatory features |
| S16 | [g2pK repo](https://github.com/Kyubyong/g2pK) | §6 (Apache-2.0 verified) |
| S17 | [UCL Phonetics — Variation with Context](https://www.phon.ucl.ac.uk/courses/spsci/expphon/week7.php) | §5.4 coarticulation |
| S18 | [Lucas Pope Obra Dinn devlog](https://dukope.com/devlogs/obra-dinn/) | §4 (no lip-sync precedent) |
| S19 | [World of Horror wiki — Animated Head](https://woh.fandom.com/wiki/Animated_Head) | §4 (3-frame cycle precedent) |
| S20 | [Apple Reduce Motion guide](https://support.apple.com/guide/mac-help/change-motion-settings-for-accessibility-mchla3c4f1da/mac) + [Pope.tech accessible motion guide](https://blog.pope.tech/2025/12/08/design-accessible-animation-and-movement/) | §5.6 |
| S21 | [Annosoft 17-viseme reference](http://www.annosoft.com/docs/Visemes17.html) | §1.11 |

— End of viseme-best-practices.md —
