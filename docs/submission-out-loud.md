# Submission Narrative — "Out Loud" (Scenario 1)

> **Status**: strategy artifact (2026-05-11). Writeup-ready prose for the Kaggle submission, framed for the team. Not yet built — this is the *direction*, designed against the hackathon brief + the Gemma 3n winners' wow pattern. Sibling: `submission-maia.md`. Decision pending.

---

## Title / Subtitle / Track

- **Title**: Out Loud
- **Subtitle**: The phone that reads the world to you — in your language, out loud, offline. Even the things you can't show anyone.
- **Track**: Digital Equity & Inclusivity *(supporting use cases: Health & Sciences, Safety & Trust)*

---

## The Story — writeup opening (~210 words)

> 754 million adults cannot read. Billions more cannot read the language their bills, court letters, diagnoses, or children's school notices are written in. For them, a sheet of paper is a locked door — and the help that could open it (a paralegal, a translator, a patient explainer) is exactly the help that never shows up at a kitchen table on a Tuesday night.
>
> Cloud AI cannot fill that gap. You will never paste your eviction notice, your custody papers, or your HIV diagnosis into a chatbot — and you shouldn't have to. But **Gemma 4**, running entirely on a $90 Android phone with no network connection, can. **Out Loud** is voice-first: you hold your phone over a document, a sign, a label, a screenshot. It *looks*. It reads it aloud — in your language, in plain words — and it tells you what to do next: *"This is your third eviction notice. You have 14 days. Here is the legal-aid number for your county."* It remembers your other documents, so it can say *"the first notice, two months ago, gave you 30 days — this one is faster."* And when the right answer is "a human," it says so: it routes you to a lawyer, a doctor, a hotline; it never pretends to be one.
>
> No internet. No account. No subscription. No byte leaves your hand — verify it: the app declares zero network permissions; airplane-mode the phone and it still works. Built for everyone the system traps with a piece of paper.

---

## 3-Minute Video Script — beat by beat ("the most important part of the submission")

| Time | Beat | Content |
|---|---|---|
| 0:00–0:20 | **The problem, made physical** | No narration. A kitchen at night. An elderly woman (recently joined her daughter abroad) sorts envelopes — a medical bill, an IRS letter, a landlord notice, all in dense English. Her hands hesitate over each. She picks up her phone, looks at it, puts it down. Title card on black: *754 million adults can't read. Billions can't read the language their lives are written in.* |
| 0:20–0:55 | **The turn** | She opens Out Loud (just a camera viewfinder + a big "Read it" button). She holds the phone over the medical bill. The phone, in her language: *"This is a bill from ___ Hospital. ER visit, March 12, charged $1,240. But — look at this 'patient responsibility' line. That's the pre-insurance amount. If you bill it to your insurer, most of it goes away. The hospital billing number is here, ☎ ... — say 're-bill to insurance.'"* Her face changes — fear → workable. (Screen: the document, the key line highlighted, a "What to do next" card.) |
| 0:55–1:30 | **Depth: it remembers; it's grounded** | She holds the phone over the landlord's notice. *"This is an eviction notice. You have 14 days to pay or respond. But — your first notice two months ago gave you 30 days. This one is faster. This is beyond what I should answer — you need free legal advice. The legal-aid number for ___ County is here, ☎ ... Bring this notice with you."* Beat. The phone did **not** tell her what to write. It told her **who** can. Quick montage: the same flow on a Spanish prescription label, a school discipline letter, a confusing government form read field-by-field. |
| 1:30–2:10 | **The proof** | Calm narration: *"You would never upload your eviction notice to a cloud AI. You don't have to. Out Loud runs Gemma 4's E4B model, 4-bit, entirely on the phone. Multimodal vision reads the document. Native function calling routes it — explain, translate, assess urgency, find the local resource, log it for next time. A 256K context window holds your whole document history, so it connects this letter to the last one. And it's offline by construction."* Cut: she puts the phone in airplane mode (the icon shows). She holds it over a new letter. It reads it. Cut to a laptop beside her running Wireshark — flat line, zero packets — while the phone is mid-sentence. Title card: *Her medical bill never left her hand. Verify it: zero network permissions in the manifest.* |
| 2:10–2:45 | **Scale + the "Good" thesis** | *"This is the help that couldn't exist before a frontier model could run on a $90 phone with no signal. There are 754 million adults who can't read this sentence. Billions who can't read the language their landlord, doctor, government writes in. Out Loud doesn't make them dependent on a company in the cloud. It reads the world to them — and hands them back the agency the paperwork took away."* Cut: the woman, next morning, on the phone with the hospital billing department, the letter in front of her, calm. |
| 2:45–3:00 | **Close** | Title card: **Out Loud — the world, read to you. Your language. Out loud. Offline. Even the things you can't show anyone.** / Gemma 4 E4B · on-device · zero network permissions · [GitHub] · [Demo APK] |

---

## How We Use Gemma 4 Specifically (proof-of-work core)

- **Multimodal vision (load-bearing)** — the document/photo/screenshot image goes straight to Gemma 4's vision encoder. Remove it and there is no product. Used for: layout-aware reading ("this line is the amount, this is the deadline"), small-print detection (the "patient responsibility" line, the drug-interaction warning), and language detection (it reads the document's language; the user picks the output language).
- **Native function calling** — every document triggers a dispatch: `classify_document(image) → {type, urgency, language}` → `explain(document, output_language, reading_level)` → optionally `assess_deadline(document, today)` → optionally `find_local_resource(document_type, region)` (a small on-device table of legal-aid / health-line / 119-equivalent numbers by region) → `log_document(fingerprint, summary)`. The model decides the path; the app routes. *(Repurposed `FunctionCallOrchestrator` pattern from the He Was Socrates POC.)*
- **256K long context** — the on-device document log (SHA-256 content-fingerprint dedup — the He Was Socrates `WonderingLog` generalized) feeds prior document summaries into context, so "this is your third notice" is real, not a guess.
- **Edge / E4B 4-bit** — the whole point: runs on a mid-range Android, offline. ~4 GB weights downloaded once over wifi at install — the only network event, ever.
- **Configurable thinking** — a small thinking budget when the document is ambiguous (a dense legal form), visualized as a brief "reading…" state; none for a simple label.
- **Grounded, not generative-medical/legal** — system prompt + the `find_local_resource` function + a hard refusal list (medical diagnosis, legal advice, financial advice, immigration advice) → the app *explains and routes*; it never *advises*. *(The He Was Socrates `defer_to_human` abstention gate, in a place where it is obviously the right call.)*

---

## Architecture (brief)

```
Camera → image → Gemma 4 E4B (vision + function calling;
                  MLX on iOS / MediaPipe LLM Inference or llama.cpp on Android)
       → orchestrator (Swift/Kotlin shared logic)
       → { system multilingual TTS reads aloud + on-screen card with highlights }
       ↔ on-device STT for voice follow-ups
       → SQLite document log (FileProtection complete)
       → user-controlled export
```
Zero network code. App manifest: **no INTERNET permission** (Android) / **no network entitlement** (iOS).

---

## Why these technical choices were right (the writeup's job: prove the demo is backed by engineering)

1. **On-device** — the documents are unshowable; this is not a privacy *feature*, it is the *precondition* for the use case to exist.
2. **Voice-first** — the users *can't read*; a text UI would be useless. The TTS reading the world aloud *is* the product.
3. **Function calling over a single prompt** — "explain → check deadline → find resource → log" is genuinely a multi-tool task, and a legible dispatch is auditable (Safety & Trust).
4. **E4B 4-bit** — a $90 phone is the hardware "the places that need it most" actually have.
5. **Grounded and routes to humans** — a confidently-wrong reading of an eviction notice is worse than no reading. The refusal list is load-bearing safety, not garnish.

---

## Reuses from the He Was Socrates POC

On-device STT/TTS voice loop · `FunctionCallOrchestrator` + parser · `WonderingLog` (→ document log) with SHA-256 dedup · the `defer_to_human` abstention gate (→ "this needs a lawyer/doctor") · the deterministic build discipline · the zero-network-entitlement / Wireshark-verifiable privacy pattern.

**Discards**: the 1-bit halftone bust · the Korean-only tone lock · macOS-only · the fullscreen-Socratic UX · the "a bust that refuses to answer" framing (Out Loud is a different product — He Was Socrates becomes the proven voice-I/O + orchestrator substrate it sits on).

---

## Honest limitations

- v1 ships ~8 output languages (the ones with good on-device TTS); the rest is roadmap.
- OCR quality on crumpled / handwritten documents degrades — we show a confidence flag and "show me a clearer photo."
- The local-resource table is hand-curated for ~3 regions in v1; community-contributed expansion is the path.
- It is not a lawyer, doctor, or accountant — it is a reader that knows when to hand you to one.

---

## The vision / why this is "Good"

"Good" in the old sense — it gives people back agency the system took with a piece of paper, and it does so without making them dependent on, or surveilled by, anyone. The right tools, accessible to everyone, on the hardware everyone has. That is the brief.
