# Out Loud — Master Plan

> *"The phone that reads the world to you — in your language, out loud, offline. Even the things you can't show anyone."*
>
> Supersedes `submission-out-loud.md` (which remains the short narrative). This document is the *verified* plan: every load-bearing claim checked against the Gemma 4 model card, the Google AI Edge / LiteRT docs, and the Kaggle hackathon rules — with a verification log at the end. "100% verified" here means **the plan is verified against every checkable fact**; the *outcome* (a bug-free build, a video that lands, the specific judges' taste) is an execution result, not a fact verifiable in advance — that boundary is stated explicitly in §9.
>
> Hackathon: The Gemma 4 Good Hackathon (Kaggle × Google DeepMind) · deadline 2026-05-19 08:59 KST · $200K across General / Impact-focused / Technical · 5 problem areas (Health & Sciences / Global Resilience / Future of Education / Digital Equity & Inclusivity / Safety & Trust).

---

## 0. One-paragraph pitch (the thing a judge repeats)

754 million adults can't read; billions more can't read the language their eviction notice, medical bill, diagnosis, or child's school letter is written in. For them a sheet of paper is a locked door, and the help that opens it — a paralegal, a translator, a patient explainer — never shows up at a kitchen table on a Tuesday night. **Out Loud** is a $0 Android app: hold your phone over the document, the sign, the label, the screenshot. Gemma 4's E4B model — running entirely on the phone, no network — *reads it* (it has built-in multilingual OCR and document parsing), *explains it aloud in your language* (it has built-in speech-to-translated-text), and *tells you what to do next* via native function calling that routes to the right human resource. It remembers your other documents in a 128K context, so it can say "this is your third notice — the first one gave you 30 days, this one gives 14." And when the right answer is a human, it says so; it never pretends to be a lawyer or a doctor. No internet. No account. No subscription. No byte leaves your hand — verify it: the APK declares no INTERNET permission; airplane-mode the phone and it still works.

---

## 1. Why this direction (anchored to the brief + the precedent)

### 1.1 What the Kaggle Description repeatedly asks for (frequency-ordered)
1. **On-device / edge / local** (most repeated): "local frontier intelligence" · "optimizing E2B and E4B models for edge-based solutions" · "a classroom with spotty internet" · "a medical site far from a data center" · "offline, edge-based disaster response".
2. **"the places that need it most"** — underserved, low-resource, low-connectivity, privacy-critical. The brief's three named "perfect match" contexts: an offline classroom, a remote medical site, and **"a community where privacy is non-negotiable."**
3. **Multimodal understanding** — text/images/documents/screenshots/photos.
4. **Native function calling / multi-tool agents** — "agentic retrieval", structured tool use.
5. **Grounded / accurate outputs** — "ensure accurate, grounded outputs", "remains grounded and explainable".
6. **WOW via video/story** — "This is the most important part of your submission" · "We want to see the 'wow' factor" · "the ability to communicate your vision... is what will set the winners apart" · "Explore the winners and finalists of the Gemma 3n Impact Challenge."

### 1.2 The Gemma 3n winners' wow pattern (the precedent the brief points us to)
A specific person, with a specific barrier, for whom AI couldn't help before (cloud / cost / connectivity / sight / touch / literacy), now does the thing — on a cheap device, offline, in their language — **and you watch it happen in the video.** 8 winners, 600+ submissions: 6/8 prioritized offline/edge; 5/8 addressed disability/accessibility; the gold (Gemma Vision) was AI-for-the-blind with multimodal vision; the Google AI Edge Special Tech Prize went to the on-device deployment.
**Taken accessibility lanes**: vision (Gemma Vision), cognitive disability (Vite Vere), motor/speech (3VA, Dream Assistant), AAC. **Untaken, enormous lane**: literacy / language exclusion — 754M adults who can't read + ~2.6B offline + every immigrant who can't read the local bureaucracy. Out Loud takes that seat. It is the *complement* of "AI extends human capability" (Gemma Vision = sight for the blind), not a copy: "AI makes the world legible to the person the system traps with paper."

### 1.3 Why on-device is *necessary* here, not merely nice
You will never upload your eviction notice, your custody papers, or your HIV diagnosis to a cloud chatbot — and you shouldn't have to. The privacy property isn't a feature bolted onto Out Loud; it's the **precondition** for the use case to exist at all. That maps onto the brief's "a community where privacy is non-negotiable" word-for-word, and onto the Safety & Trust track's "transparency and reliability" — Out Loud's privacy claim is an *inspectable* fact (no INTERNET permission in the manifest), not a policy you trust.

---

## 2. Verified technical foundation (Gemma 4 E4B)

All facts below are from the official Gemma 4 model card (`ai.google.dev/gemma/docs/core/model_card_4`) and the Google AI Edge / LiteRT deployment docs — see the verification log (§10).

| Property | Verified value | Source |
|---|---|---|
| Model | Gemma 4 **E4B-it** (instruction-tuned), 4-bit quantized ~2.5 GB | model card / LiteRT docs |
| License | **Apache 2.0** | model card |
| Context window | **128 K tokens** | model card |
| Input modalities | **Text, Image, Audio** | model card |
| Output | Text | model card |
| Built-in vision skills | object detection, **document/PDF parsing**, screen/UI understanding, chart comprehension, **OCR (including multilingual)**, variable aspect ratios/resolutions | model card |
| Built-in audio skills (E2B/E4B only) | **Automatic speech recognition (ASR)** and **speech-to-translated-text translation** | model card |
| Function calling | **Native** — "Native support for structured tool use, enabling agentic workflows" | model card |
| Languages | **35+ output languages, pre-trained on 140+** | model card |
| On-device runtime (Android) | **Google AI Edge SDK / LiteRT** (`com.google.ai.edge:litert`) — "the most official path for running Gemma models on Android"; `.task`/`.tflite` format; **image bitmaps + audio PCM can be passed alongside the text prompt through the same API**; fully offline after download | Google AI Edge / LiteRT docs |
| On-device runtime (iOS) | MediaPipe LLM Inference SDK (v1.1 target) | Google AI Edge docs |
| Inference speed (E4B) | ~12–20 tok/s on a flagship (Snapdragon 8 Gen 3); slower on mid-range — a short document explanation (~150–400 output tokens) is ~5–20 s | LiteRT benchmarks |
| Known gotcha | Sustained inference → thermal throttling after several minutes of continuous use | LiteRT docs |

**Implication**: the entire Out Loud pipeline — *read the document* (multilingual OCR + document parsing), *explain it in the user's language* (speech-to-translated-text + multilingual generation), *decide what to do* (function calling), *connect it to prior documents* (128K context) — is **Gemma 4 doing the hard work**, not a wrapper. The app contributes: the camera capture, the offline TTS that voices the explanation, the small bundled local-resource table, the on-device document log, and the orchestration. This kills the "thin wrapper" critique a Technical judge would otherwise raise.

---

## 3. Gap closure — every gap identified, now closed

| Gap (from earlier reviews) | Status | Closure |
|---|---|---|
| **macOS-only excludes "the places that need it most"** | ✅ closed | Out Loud is **Android-first** (LiteRT / Google AI Edge SDK — the official Gemma-on-Android path; the Gemma 3n 1st-place won the Google AI Edge Special Tech Prize on this stack). Runs on a ~$90 mid-range Android. iOS via MediaPipe LLM Inference SDK in v1.1. macOS is not in scope. |
| **"multimodal" was thin (voice + viseme, no image input)** | ✅ closed & upgraded | Multimodal vision is now **load-bearing and verified**: E4B has built-in document/PDF parsing + multilingual OCR + screen/UI understanding, and LiteRT supports image bitmaps on-device on Android. Remove the vision modality → no product. |
| **Translation was a bolted-on API** | ✅ closed & upgraded | E4B has built-in **speech-to-translated-text** and is pre-trained on 140+ languages — the model itself does the cross-language comprehension and explanation. The only non-Gemma piece in the language path is the offline TTS that voices the result. |
| **"256K context" was wrong for E4B** | ✅ closed | Corrected everywhere to **128K** (E4B's actual window per the model card). 128K still holds a substantial multi-document history; the writeup must (and will) state 128K, because a judge can check the model card. |
| **"stubbed long-context recall" (He Was Socrates)** | ✅ N/A | Out Loud is a new app; the document log → 128K-context recall is built from the start (it's a simple, real retrieval — last-K fingerprinted document summaries concatenated into the prompt — not a research problem). |
| **"thin wrapper" critique** | ✅ closed | See §2 implication — Gemma 4 does vision, OCR, multilingual comprehension, translation, and the function-call dispatch. The app is the harness. |
| **Languages: which? how many?** | ✅ scoped | E4B supports 35+ output languages. v1 ships **~8–10** with good offline TTS voices on Android (en, es, ko, zh, hi, ar, pt, fr, vi, tl as a candidate set); the rest is roadmap. Honest in limitations. |
| **Local-resource table: where does "call legal aid at this number" come from?** | ✅ scoped | A small **bundled JSON** (`resources.json`): per-region (v1: ~2 regions, e.g. a US state + one other) mappings of document-type → resource-class → name + phone (legal aid, public health line, emergency, social services, immigrant services). Community-extensible (a documented schema + a contribution path). Honest in limitations: v1 = 2 regions. The model never invents a phone number — it only surfaces entries from the table; if the user's region isn't covered, it says "I don't have a verified number for your area — search 'legal aid + [region]'." |
| **TTS (reading aloud): is *that* Gemma too?** | ✅ honest split | No — comprehension/translation is Gemma 4; the *voice output* is the **Android system `TextToSpeech` API** (offline voices) or a small on-device TTS model. The writeup states this split plainly. (This is the He Was Socrates POC's lesson: be precise about which part is the model.) |
| **Speed / thermal** | ✅ honest in limitations | E4B ~8–15 tok/s on mid-range; a document turn is ~5–20 s with a "reading…" state. Thermal throttling on *sustained* inference — mitigated by the usage shape: you read one document at a time, not a continuous stream; the app does no background inference. |
| **Privacy verification — what exactly is the proof?** | ✅ specified | (1) `AndroidManifest.xml` declares **no `android.permission.INTERNET`** — the OS will reject any socket from the app process. (2) The *only* network event in the app's life is the one-time model download, which can be **sideloaded** (the `.task` file copied via USB / a local file) so a truly zero-network install is possible — the demo does exactly this. (3) Verifiable by the judge: `aapt dump permissions out-loud.apk` shows no INTERNET; `tcpdump`/Wireshark on the phone's interface shows zero packets during use. (4) The repo's CI runs a check that fails the build if `INTERNET` ever appears in the manifest. |
| **Is this a copycat of a Gemma 3n winner?** | ✅ closed | No — see §1.2. Gemma Vision = sight for the blind; Out Loud = legibility for the system-trapped. Different population (literacy/language exclusion), different barrier, same winning lineage (on-device + multimodal vision + helps the underserved at scale + cheap hardware + gut-punch demo). |
| **"How does the team have time to build a new Android app by D-8?"** | ⚠️ honest | This is the one gap that *cannot* be closed by planning — it's a scoping/effort reality. See §6: the realistic D-8 deliverable is a **focused vertical slice** (one region's resource table, ~3 document types, ~4 languages, the core read→explain→route→log loop, the demo flow), not the full vision. The writeup is honest about v1 scope. If D-8 is genuinely too tight for even the slice, the fallback is to submit the current He Was Socrates macOS build to Safety & Trust and ship Out Loud to the *next* competition — but that's a project decision, flagged, not assumed here. |

---

## 4. Architecture (verified buildable)

```
┌─────────────────────────────────────────────────────────────────┐
│  Android app (Kotlin) — NO android.permission.INTERNET           │
│                                                                  │
│  CameraX ──► image bitmap                                        │
│     │                                                            │
│     ▼                                                            │
│  Gemma 4 E4B-it (4-bit, ~2.5 GB)  via Google AI Edge SDK / LiteRT│
│  (.task model file, sideloadable; runs fully on-device)          │
│     │                                                            │
│     │  prompt = [image] + [system prompt] + [recent doc summaries│
│     │           from the local log] + [user's chosen language]   │
│     ▼                                                            │
│  ── function-calling dispatch (model decides the path) ──         │
│     1. classify_document(image) → {type, urgency, src_language}   │
│     2. explain(document, output_language, reading_level)          │
│        → plain-language explanation (model does OCR + translation │
│          + comprehension natively)                               │
│     3. (opt) assess_deadline(document, today) → {days_left, note} │
│     4. (opt) find_local_resource(type, region)                   │
│        → looks up resources.json (bundled); never invents numbers │
│     5. log_document(content_fingerprint, summary)                │
│        → SQLite (FileProtection / encrypted), SHA-256 dedup       │
│     ── refusal gate: medical-diagnosis / legal-advice /           │
│        financial-advice / immigration-advice → explain + route,   │
│        never advise                                              │
│     │                                                            │
│     ▼                                                            │
│  Android system TextToSpeech (offline voices)  ──► speaks aloud   │
│  + on-screen card: the document with the key line highlighted,    │
│    a "what to do next" block, the resource name + number          │
│     ▲                                                            │
│  Android system on-device STT (or Gemma 4 ASR) ◄── voice follow-ups│
│                                                                  │
│  SQLite document log ──► user-controlled export (the user owns    │
│    the off switch, the delete button, and the export)            │
└─────────────────────────────────────────────────────────────────┘
```
- **No network code.** `AndroidManifest.xml`: no `INTERNET` permission. CI gate enforces it.
- **Model delivery**: ~2.5 GB `.task` file. v1 demo sideloads it (USB / local file) to demonstrate a literally-zero-network install; production would offer an opt-in one-time download (the only network event ever) — and even then the app process can't open a socket, so the *download* is done by a separate, clearly-scoped installer flow, not the app.
- **iOS (v1.1)**: same logic, MediaPipe LLM Inference SDK, no network entitlement.

---

## 5. How Out Loud uses Gemma 4 — the proof-of-work core (for the writeup)

1. **Multimodal vision — load-bearing.** The document/photo/screenshot image goes straight to E4B's vision encoder. Used for: document/PDF parsing (it knows "this region is the amount, this is the deadline, this is the fine print"), multilingual OCR (it reads the document's language even when that differs from the user's), and screen/UI understanding (a confusing app screenshot, a government portal). *Verified*: these are named built-in capabilities of E4B in the model card.
2. **Built-in multilingual comprehension + speech-to-translated-text — load-bearing.** E4B is pre-trained on 140+ languages and has built-in speech-to-translated-text. Out Loud reads a document in language A and explains it in the user's language B — the cross-language step is the model, not a separate translation API. (The user can also *speak* a follow-up in their language; E4B's ASR handles it.) *Verified*: model card.
3. **Native function calling — the orchestration.** Every document triggers a structured dispatch (`classify_document` → `explain` → opt `assess_deadline` → opt `find_local_resource` → `log_document`), plus a refusal gate that routes regulated topics to humans. A frozen JSON contract for the functions + a parser for malformed output (the He Was Socrates `FunctionCallOrchestrator` pattern, repurposed). The dispatch is *legible* — the judge can see which path a turn took (Safety & Trust: "grounded and explainable"). *Verified*: native function calling is in the model card.
4. **128K context — agentic retrieval over the user's document history.** The on-device document log (SHA-256 content-fingerprint dedup) feeds prior document summaries into context, so "this is your third notice — the first gave you 30 days" is real, not a guess. 128K comfortably holds many documents' summaries. *Verified*: 128K is E4B's window per the model card.
5. **Edge / E4B 4-bit — the whole point.** ~2.5 GB, runs on a ~$90 Android, offline. *Verified*: LiteRT docs.
6. **Configurable thinking — used sparingly.** A small thinking budget when the document is genuinely ambiguous (a dense multi-page legal form), visualized as a "reading…" state; none for a simple label. (Honest: this is the lightest of the five — not the headline.)
7. **Grounded, not generative-medical/legal — the safety mechanic.** System prompt + the `find_local_resource` function + a hard refusal list mean Out Loud *explains and routes*; it never *advises*. A confidently-wrong reading of an eviction notice is worse than no reading — the refusal list is load-bearing safety, and it ties the submission to the Safety & Trust track's "grounded and explainable."

---

## 6. Build plan (honest about D-8 vs the full vision)

### 6.1 What carries over from the He Was Socrates POC
- **Design patterns** (not code — different platform/runtime/language): the function-call orchestrator + malformed-output parser pattern; the `defer_to_human` / abstention-gate pattern; the SHA-256 content-fingerprint dedup-log pattern; the deterministic-build discipline; the **zero-network-permission, CI-enforced** privacy discipline; the "be precise about which part is the model" honesty.
- **Team experience**: the team has shipped an on-device, function-calling, privacy-by-entitlement app once already — that's the hardest thing to learn, and it's done.
- **Reusable assets**: the bench-harness pattern (for the writeup's perf numbers); the deterministic asset pipeline pattern (for the demo's reproducibility).

### 6.2 What's new (most of it — Out Loud is a new Android app)
Android app shell (Kotlin, CameraX, system TTS/STT) · LiteRT / Google AI Edge SDK integration for E4B · the document-parsing prompt + the function contract for Out Loud's five functions · `resources.json` (the local-resource table, v1: 2 regions) · the document-log schema + the recall-into-context retrieval · the UI (camera viewfinder + "Read it" + the result card) · the CI gate (no INTERNET permission) · the demo flow.

### 6.3 D-8 realistic scope (the vertical slice, not the full vision)
| Component | v1 (by D-8) | Roadmap |
|---|---|---|
| Platform | Android (mid-range, e.g. a $90 phone) | iOS (MediaPipe LLM Inference SDK) |
| Document types | ~3, demo-able end to end: a medical/utility bill, an eviction/legal notice, a prescription label | the full taxonomy (custody papers, immigration forms, school letters, government forms, debt letters, …) |
| Output languages | ~4 with good offline TTS (en, es, ko, + 1) | the ~35 E4B supports |
| Local-resource table | 1–2 regions (e.g. one US state + one other) | community-contributed, many regions |
| Core loop | read → explain aloud → assess deadline → route to a resource → log | the same, polished, plus voice follow-ups, document history view |
| Privacy proof | no-INTERNET manifest + CI gate + sideloaded model in the demo | unchanged |
| Demo | the kitchen scene + airplane mode + `aapt dump permissions` + `tcpdump` zero-packets | a polished 3-min video |

### 6.4 The submission artifacts (these are the deliverable, not the full product)
1. **Kaggle writeup** (≤1500 words — §7) — the proof of work.
2. **3-min YouTube video** (§8) — the wow; "the most important part."
3. **Public GitHub repo** — the vertical-slice Android app, well-documented, CI-gated, Apache-2.0; the function contract; `resources.json`; the document-parsing prompt.
4. **Live demo** — the demo APK (sideloadable, runs offline) + a short "how to run it" doc.
5. **Media gallery** — a cover image + screenshots (the kitchen scene, the result card, the airplane-mode shot, the `aapt`/`tcpdump` proof).
6. **Track selected**: Digital Equity & Inclusivity (primary). Safety & Trust and Health & Sciences are present in the writeup as supporting framings — but a team selects one track for the writeup.

---

## 7. Kaggle writeup — final draft (≤1500 words; current draft ~1,150 words)

> **Title**: Out Loud
> **Subtitle**: The phone that reads the world to you — in your language, out loud, offline. Even the things you can't show anyone.
> **Track**: Digital Equity & Inclusivity

> **The locked door.** 754 million adults cannot read. Billions more cannot read the language their eviction notice, their medical bill, their diagnosis letter, or their child's school notice is written in. For them a sheet of paper is a locked door. The help that opens it — a paralegal who can say "you have 14 days, here's who to call," a translator, a patient explainer — does not show up at a kitchen table on a Tuesday night. And cloud AI cannot fill that gap, because filling it requires you to expose the thing you most need to keep private. You will never paste your eviction notice, your custody papers, or your HIV diagnosis into a chatbot. You shouldn't have to.
>
> **What Out Loud does.** Out Loud is a free Android app. You hold your phone over a document, a sign, a label, a screenshot. Gemma 4's E4B model — running entirely on the phone, with no network connection — *reads it*: E4B has built-in document/PDF parsing and multilingual OCR, so it doesn't matter what language the page is in. It *explains it aloud in your language*: E4B is pre-trained on 140+ languages and has built-in speech-to-translated-text, so the cross-language step is the model, not a bolted-on API. And it *tells you what to do next*: a native function-calling dispatch routes the turn — classify the document, explain it, assess the deadline, and (when there is one) surface the right human resource: *"This is an eviction notice. You have 14 days to pay or respond. This is beyond what I should answer — you need free legal advice. The legal-aid number for your county is here, ☎ … Bring this notice with you."* It remembers your other documents in a 128K context, so it can say *"this is your third notice — the first one, two months ago, gave you 30 days; this one is faster."* And when the right answer is a human, it says so — it never pretends to be a lawyer, a doctor, or an accountant.
>
> **Why it must be on-device.** The privacy here is not a feature. It is the precondition. The Gemma 4 Good Hackathon names three places that need this most — a classroom with spotty internet, a medical site far from a data center, and *a community where privacy is non-negotiable*. Out Loud is built for the third, and it makes "non-negotiable" mean something you can check: the APK declares no `android.permission.INTERNET`; the operating system will reject any socket from the app process; airplane-mode the phone and Out Loud still works; the demo sideloads the model file over USB so there is *no* network event in the app's life; and our CI fails the build if `INTERNET` ever appears in the manifest. Run `aapt dump permissions out-loud.apk` — there is no internet permission. Run `tcpdump` on the phone while you use it — there are no packets. The privacy claim is an inspectable fact, not a policy you trust. (This is also why we submit, in spirit, to Safety & Trust as much as to Digital Equity: a grounded, explainable AI whose privacy you can verify.)
>
> **Architecture.** CameraX captures the image. The image plus a system prompt plus the recent document summaries from the local log go to Gemma 4 E4B-it (4-bit, ~2.5 GB) running via the Google AI Edge SDK / LiteRT — the official path for Gemma on Android, which accepts image bitmaps alongside the text prompt. The model's function-calling output is parsed by a small orchestrator (a frozen JSON contract for five functions — `classify_document`, `explain`, `assess_deadline`, `find_local_resource`, `log_document` — plus a parser for malformed output, plus a hard refusal gate for medical/legal/financial/immigration advice). `find_local_resource` looks up a bundled `resources.json` — the model never invents a phone number; it only surfaces verified entries, and if the user's region isn't covered it says so. The result is voiced by the Android system `TextToSpeech` API (offline voices) and shown as an on-screen card: the document with the key line highlighted, a "what to do next" block, the resource. Voice follow-ups go back through on-device STT (or E4B's built-in ASR). The document log is encrypted local SQLite with SHA-256 content-fingerprint dedup; the user owns the off switch, the delete button, and the export. There is no network code anywhere in the app.
>
> **How we use Gemma 4 — specifically.** Five capabilities, and the product collapses without the first four. (1) *Multimodal vision*: document/PDF parsing, multilingual OCR, screen/UI understanding — verified built-in capabilities of E4B. (2) *Multilingual comprehension + speech-to-translated-text*: the model reads language A and explains in language B, and takes spoken follow-ups in the user's language — built-in to E4B (audio modality, E2B/E4B only). (3) *Native function calling*: the legible five-function dispatch + refusal gate — built-in structured tool use. (4) *128K context*: agentic retrieval over the user's document history — E4B's window. (5) *Configurable thinking*: a small budget for genuinely ambiguous multi-page forms (the lightest of the five — not the headline). Edge: E4B 4-bit, ~2.5 GB, runs on a ~$90 mid-range Android, fully offline after the model file is in place.
>
> **Why these choices were right.** On-device because the documents are unshowable — this is the precondition, not a feature. Voice-first because the users *can't read* — a text UI would be useless; the explanation read aloud *is* the product. Function calling over a single prompt because "explain → check the deadline → find the resource → log it" is genuinely a multi-tool task, and a legible dispatch is auditable. E4B 4-bit because a ~$90 phone is the hardware the people who need this actually have. Grounded-and-routes-to-humans because a confidently-wrong reading of an eviction notice is worse than no reading — the refusal list is load-bearing safety, and it never lets the app pretend to be the human you actually need.
>
> **What we are honest about.** v1 ships ~3 document types end to end, ~4 output languages with good offline TTS, and a `resources.json` covering 1–2 regions — the rest (the full document taxonomy, the ~35 languages E4B supports, community-contributed regions) is roadmap, and the schema and contribution path are in the repo. OCR quality degrades on crumpled or handwritten pages — we show a confidence flag and ask for a clearer photo. E4B on a mid-range phone runs at roughly 8–15 tokens/second, so a document explanation takes several seconds (a "reading…" state covers it); sustained inference would thermally throttle, which is why the app does no background work — you read one document at a time. Out Loud is not a lawyer, a doctor, or an accountant; it is a reader that knows exactly when to hand you to one.
>
> **The vision — and why this is "good."** There are 754 million adults who can't read this sentence, and billions who can't read the language their landlord, their hospital, their government writes in. The right tools — a frontier model that runs on a $90 phone with no signal — finally make it possible to read the world to them. Out Loud does that without making them dependent on, or surveilled by, anyone: no cloud, no account, no subscription, no byte that leaves their hand. "Good," in the old sense — it gives people back the agency the paperwork took away. *Code: [GitHub]. Demo APK: [link]. Video: [YouTube]. Apache-2.0 (code) · model: Gemma 4 E4B-it (Apache-2.0).*

*(Word count of the draft above: ~1,150 — comfortably under the 1,500 limit, leaving room for a "References" line and any judge-requested expansion. Final version: tighten, add the exact links, add a one-line acknowledgment of the He Was Socrates POC as the team's prior on-device work.)*

---

## 8. 3-minute video shot list (the wow — "the most important part")

| Time | Shot | What happens |
|---|---|---|
| 0:00–0:18 | **The locked door** | No narration. A kitchen at night. An elderly woman — recently joined her adult child abroad — at the table with a stack of envelopes: a hospital bill, a notice from the landlord, a government letter, all in dense English she can't read. Her hands move over each one and stop. She picks up her phone, looks at it, puts it down. Cut to black, white text: *754 million adults can't read. Billions can't read the language their lives are written in.* |
| 0:18–0:50 | **The turn** | She opens Out Loud — just a camera viewfinder and a big "Read it" button. She holds the phone over the hospital bill. The phone speaks, in her language: *"This is a bill from ___ Hospital. ER visit, March 12, charged $1,240. But — look at this 'patient responsibility' line. That's the pre-insurance amount. If you bill it to your insurer, most of it goes away. The hospital billing number is here, ☎ … — say 're-bill to insurance.'"* Her face: fear → workable. On screen: the bill with the line highlighted, a "what to do next" card. |
| 0:50–1:25 | **It remembers; it stays grounded** | She holds the phone over the landlord's notice. *"This is an eviction notice. You have 14 days to pay or respond. But your first notice, two months ago, gave you 30 days — this one is faster. This is beyond what I should answer — you need free legal advice. The legal-aid number for ___ County is here, ☎ … Bring this notice with you."* Beat. It did not tell her what to write. It told her *who* can. Quick montage on other phones: a Spanish prescription label read aloud, a confusing government form read field by field, a school discipline letter explained — different people, different documents, different languages. |
| 1:25–2:05 | **The proof** | Calm narration: *"You would never upload your eviction notice to a cloud AI. You don't have to. Out Loud runs Gemma 4's E4B model — multimodal, 4-bit, about 2.5 gigabytes — entirely on the phone. It has built-in document parsing and multilingual OCR, so it reads the page. It has built-in translation, so it explains it in your language. Native function calling routes it — explain, check the deadline, find the local resource, log it. A 128K context holds your whole document history. And there is no internet permission in the app — none."* Cut: she puts the phone in airplane mode (the icon shows). She holds it over a new letter. It reads it. Cut to a laptop beside her: `aapt dump permissions out-loud.apk` — the output, no `INTERNET`. Then `tcpdump` on the phone's interface — a flat line, zero packets — while the phone is mid-sentence. White text: *Her medical bill never left her hand. Verify it: no internet permission. No packets.* |
| 2:05–2:42 | **Scale + "Good"** | *"This is the help that couldn't exist before a frontier model could run on a $90 phone with no signal. 754 million adults can't read this sentence. Billions can't read the language their landlord, doctor, government writes in. Out Loud doesn't make them dependent on a company in the cloud. It reads the world to them — and hands them back the agency the paperwork took away."* Cut: the woman, next morning, on the phone with the hospital billing department, the bill in front of her, calm — using the words Out Loud gave her. |
| 2:42–3:00 | **Close** | White text on black: **Out Loud — the world, read to you. Your language. Out loud. Offline. Even the things you can't show anyone.** / Gemma 4 E4B-it · on-device · no internet permission · Apache-2.0 · [GitHub] · [Demo APK] |

Production notes: shoot the kitchen scene with a non-actor or a careful actor — the wow lives in a *real* face, not a staged one; the brief explicitly says the video is what sets winners apart, and judges can smell a fake. The `aapt`/`tcpdump` beat is the visceral version of the privacy claim — don't narrate it, *show* it. Korean (or another non-English) as the woman's language, with English subtitles, demonstrates the multilingual capability *in the demo itself*.

---

## 9. What "100% verified" means here (the honesty boundary)

**Verified now** (see §10): Gemma 4 E4B's capabilities (128K context, text+image+audio input, built-in multilingual OCR + document parsing, built-in ASR + speech-to-translated-text, native function calling, 35+/140+ languages, Apache-2.0); the Android on-device deployment path (LiteRT / Google AI Edge SDK, image+text on-device, fully offline after download, ~2.5 GB, the thermal-throttle gotcha); the architecture's buildability (every component maps to a documented API); the rule-compliance of the submission plan (§11); the writeup's word count (~1,150 < 1,500).

**Not verifiable in advance — execution outcomes, not facts**: that the vertical-slice app ships bug-free by D-8 (effort/scoping risk — §3 last row, §6.3); that the 3-min video lands emotionally (the brief says this is what sets winners apart, and it depends on the shoot, not the plan); that the specific judges' taste resonates with this idea over the other ~600–2000 submissions (irreducible). **"100% verified" therefore means the *plan* contains no unchecked load-bearing claim — not that winning is certain. Nothing in a 600–2000-submission hackathon with ~8 winners is certain, and any plan that claims otherwise is lying.**

---

## 10. Verification log

| # | Claim (load-bearing) | Source | Status |
|---|---|---|---|
| V1 | Gemma 4 E4B context window = 128K tokens | Gemma 4 model card (`ai.google.dev/gemma/docs/core/model_card_4`) | ✅ verified |
| V2 | E4B input modalities = text, image, audio | model card | ✅ verified |
| V3 | E4B has built-in document/PDF parsing + OCR (including multilingual) | model card | ✅ verified |
| V4 | E4B (and E2B) has built-in ASR + speech-to-translated-text translation | model card | ✅ verified |
| V5 | E4B has native function calling / structured tool use | model card | ✅ verified |
| V6 | E4B: 35+ output languages, pre-trained on 140+ | model card | ✅ verified |
| V7 | Gemma 4 license = Apache 2.0 | model card | ✅ verified |
| V8 | E4B 4-bit ≈ 2.5 GB; runs fully offline after download on Android | Google AI Edge / LiteRT docs; MindStudio Gemma-4-edge guide | ✅ verified |
| V9 | Android on-device runtime = Google AI Edge SDK / LiteRT (`com.google.ai.edge:litert`), `.task`/`.tflite`; supports image bitmaps + audio PCM alongside the text prompt on-device | Google AI Edge / LiteRT docs | ✅ verified |
| V10 | iOS on-device path = MediaPipe LLM Inference SDK | Google AI Edge docs | ✅ verified |
| V11 | E4B inference speed ≈ 12–20 tok/s on a flagship Android; slower on mid-range; thermal throttling on sustained use | LiteRT benchmarks / MindStudio guide | ✅ verified |
| V12 | Gemma 3n Impact Challenge: 600+ submissions, 8 winners; 6/8 offline/edge; 5/8 disability/accessibility; 1st place = AI-for-the-blind (Gemma Vision) + Google AI Edge Special Tech Prize; education winner (LENTERA) = offline ed hubs (infrastructure, not a personalized tutor) | Google blog "developers changing lives with Gemma 3n"; StartupHub.ai; Kaggle | ✅ verified |
| V13 | Gemma 4 Good Hackathon: $200K; General/Impact/Technical; 5 problem areas incl. "Digital Equity & Inclusivity" and "Safety & Trust"; deadline 2026-05-18 (KST 2026-05-19 08:59); video is "the most important part"; required: writeup ≤1500w + public video ≤3min YouTube + public code repo + live demo + media gallery (cover image required) + a track must be selected | Kaggle competition page (Overview/Description/Submission Requirements, as captured); EdTech Innovation Hub; Medium summary | ✅ verified |
| V14 | The brief names "a community where privacy is non-negotiable" as one of three "perfect match" contexts | Kaggle Description (captured verbatim) | ✅ verified |
| V15 | An "AI for the illiterate / linguistically excluded" is not among the Gemma 3n winners (the taken accessibility lanes are vision / cognitive / motor-speech / AAC) | Gemma 3n winners list (V12) | ✅ verified — the lane is open |
| V16 | The He Was Socrates POC's reusable contribution to Out Loud is *design patterns + team experience*, not code (different platform/runtime/language) | the POC repo (Swift/MLX/macOS) vs the Out Loud stack (Kotlin/LiteRT/Android) | ✅ verified — and stated honestly |
| V17 | Out Loud's writeup draft ≈ 1,150 words | §7, word count | ✅ verified — under the 1,500 limit |
| E1 | The vertical-slice Android app ships bug-free by D-8 | — | ⚠️ execution outcome — not verifiable in advance; §6.3 scopes it down to make it plausible |
| E2 | The 3-min video lands emotionally / "the wow lands" | — | ⚠️ execution outcome — depends on the shoot; §8 production notes mitigate |
| E3 | The specific judges resonate with this over ~600–2000 other submissions | — | ⚠️ irreducible uncertainty |

---

## 11. Rule-compliance checklist (line-by-line against the Kaggle submission requirements)

| Requirement (verbatim from the rules) | Out Loud plan | Status |
|---|---|---|
| "Kaggle Writeup ... should not exceed 1,500 words" | §7 draft ≈ 1,150 words | ✅ |
| "You must select a Track for your Writeup in order to submit." | Track: **Digital Equity & Inclusivity** (Safety & Trust + Health as supporting framings in the prose) | ✅ |
| Writeup must explain "the architecture of your app, how you specifically used Gemma 4, the challenges you overcame, and why your technical choices were the right ones" | §4 (architecture), §5 (how Gemma 4 used), §6.2/§3 (challenges), §7 ("Why these choices were right") | ✅ |
| "Attached Public Video ... 3 minutes or less ... published to YouTube ... viewable by the judges without requiring a login" | §8: 3:00 exactly; YouTube, public, no login | ✅ (to produce) |
| "Attached Public Code Repository ... well-documented and clearly show the implementation of Gemma 4 ... publicly accessible and not require a login or paywall" | public GitHub repo: vertical-slice Android app, the function contract, `resources.json`, the document-parsing prompt, the CI no-INTERNET gate; Apache-2.0; README documents the Gemma 4 / LiteRT integration | ✅ (to produce) |
| "Attached Live Demo ... URL or files ... publicly accessible and not require a login or paywall" | the demo APK (sideloadable, runs offline) + a "how to run it" doc, attached under Project Links / Files | ✅ (to produce) |
| "Media Gallery ... A cover image is required" | cover image + screenshots (kitchen scene, result card, airplane-mode shot, `aapt`/`tcpdump` proof) | ✅ (to produce) |
| "If building an app, explain your architecture and demonstrate real-world utility via a functional demo." | app, not a model train; architecture in §4; functional demo APK + video | ✅ |
| "Each team is limited to submitting only a single Writeup" | one team → one writeup (Out Loud); the He Was Socrates macOS build is *not* a second submission unless the team explicitly decides to enter it instead | ✅ (decision flagged, not assumed) |
| "If you attach a private Kaggle Resource ... it will automatically be made public after the deadline." | n/a — everything is public from the start (GitHub, YouTube, APK) | ✅ |
| "Your final Submission must be made prior to the deadline." (2026-05-19 08:59 KST) | submit early; can un-submit/edit/re-submit freely before the deadline | ✅ (operational) |
| Naming guidelines for Gemma model variants in submission videos | use "Gemma 4 E4B-it" / "Gemma 4" per the official naming guidelines; check the linked guidelines before the final cut | ✅ (to verify against the linked page at cut time) |

---

## 12. Honest probability (recalibrated)

For a hackathon with 600–2000 submissions and ~8 winners (grand prizes across 3 categories + sponsor prizes like the Google AI Edge prize the Gemma 3n 1st-place won):

| Execution level | Category/track placement (the realistic "winner" slot — most Gemma 3n "winners" were 1st–4th in a track + sponsor prizes) | Overall grand-prize top-3 |
|---|---|---|
| **Gemma-3n-winner level** — vision modality load-bearing, cheap-phone offline, multilingual, a *genuinely moving* 3-min video, grounded routing, clean Apache-2.0 repo, honest writeup, the `aapt`/`tcpdump` proof beat | **~20–35%** | **~8–15%** |
| Merely competent — works, but the video is a screencast not a short film | ~8–15% | ~3–5% |
| 95%+ | impossible — for any submission | impossible |

The load-bearing assumption is the video ("the wow lands") — §8 and the production notes mitigate it, but it's an execution outcome, not a fact. The plan is verified; the outcome depends on the build and the shoot.

---

## 13. Next actions (the path from plan → submission)

1. **Lock the track**: Digital Equity & Inclusivity. (Confirm "Safety & Trust" isn't a better primary by re-reading the prize-category breakdown on the Kaggle page — the brief lists 5 *problem areas* but 3 *prize categories*; map "Digital Equity" → which prize category, and check whether a "Google AI Edge" sponsor prize exists for Gemma 4. If it does, Android-via-LiteRT is a direct play for it.)
2. **Scaffold the Android app**: Kotlin + CameraX + LiteRT/Google AI Edge SDK + the system TTS/STT; the no-INTERNET manifest + the CI gate; the five-function contract + the orchestrator/parser (port the patterns from the He Was Socrates POC).
3. **Build the vertical slice** (§6.3): ~3 document types, ~4 languages, 1–2 regions in `resources.json`, the read→explain→assess→route→log loop, the result-card UI.
4. **Shoot the video** (§8): the kitchen scene with a real face; the `aapt`/`tcpdump` proof beat; Korean (or another non-English) with English subtitles.
5. **Write the final writeup** (§7): tighten to ≤1500, add the exact links, the He Was Socrates POC acknowledgment, a References line; verify against the naming guidelines.
6. **Assemble the submission**: public GitHub repo (Apache-2.0, README documents the Gemma 4/LiteRT integration), demo APK + how-to-run, media gallery (cover image + the screenshots), select the track, submit early.
7. **If D-8 proves too tight even for the slice**: the project decision is — submit the current He Was Socrates macOS build to Safety & Trust *or* ship Out Loud to the next competition. Flagged here; not assumed.
