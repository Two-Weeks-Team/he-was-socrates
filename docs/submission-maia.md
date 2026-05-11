# Submission Narrative — "Maia" (Scenario 2)

> **Status**: strategy artifact (2026-05-11). Writeup-ready prose for the Kaggle submission, framed for the team. Not yet built — this is the *direction*, designed against the hackathon brief + the Gemma 3n winners' wow pattern. Sibling: `submission-out-loud.md`. Decision pending.
>
> Working title **Maia** = from *maieutic* ("midwifery of ideas", the Socratic method); also "mother / midwife" in several languages. Final name TBD.

---

## Title / Subtitle / Track

- **Title**: Maia — one child's teacher, offline
- **Subtitle**: A patient tutor that adapts to one child, in their language, with no internet — and hands their real teacher a map of where all sixty are stuck.
- **Track**: Future of Education *(supporting: Digital Equity & Inclusivity)*

---

## The Story — writeup opening (~190 words)

> In a one-room school with sixty children and one teacher, no child gets ten minutes alone with someone who can see exactly where their thinking went wrong. The internet that could bring a tutor is spotty or absent. The cloud AI that could help requires a connection, an account, and a parent's trust that their child's homework isn't training someone's model.
>
> **Maia** is a Gemma 4 tutor that runs entirely on an $80 tablet, offline. A child shows it their handwritten work — *"여기 보여줘 봐" / "show me here"* — and Maia *sees* it (multimodal vision), finds where it went wrong, and does the one thing a worksheet can't: it doesn't give the answer. It asks back. *"You added 3/4 and 1/2. The denominators are different — how did you do that?"* — and the child gets to the *"...oh!"* themselves. For a child learning, productive struggle *is* the lesson. And at the end of the day, Maia hands the teacher a one-page map: *"Aisha understands fractions but flips numerator and denominator — 10 minutes one-on-one. Marco is bored; he's three units ahead. Fatima hasn't opened the tablet in two days."* The teacher's scarcest resource — attention — finally has a target.
>
> No internet. No account. No subscription. The child's work never leaves the tablet — verify it: zero network permissions. One model. One $80 tablet. One child's teacher.

---

## 3-Minute Video Script — beat by beat

| Time | Beat | Content |
|---|---|---|
| 0:00–0:20 | **The problem** | A real-feeling under-resourced classroom: sixty kids, one teacher moving between rows, never enough of her. A girl — Aisha — staring at a fraction problem, stuck, hand half-raised then lowered; the teacher is three rows away. Title card on black: *Sixty children. One teacher. No child gets ten minutes alone with someone who can see where their thinking went wrong.* |
| 0:20–1:00 | **The turn: it sees, and it doesn't tell** | Aisha picks up a battered tablet. She holds her notebook to it. Maia, in her language, warm and unhurried: *"Okay, show me. Hmm... you added 3/4 and 1/2. You wrote the answer as 4/6. The denominators are 4 and 2, different — so how did you get 4/6?"* Aisha (typing/speaking): *"Top: 3 plus 1. Bottom: 4 plus 2..."* Maia: *"Ah. So 1/2 plus 1/2, same way, would be 2/4 — is that equal to 1?"* Aisha pauses. *"...No. 1/2 plus 1/2 is 1."* Maia: *"Right. So is 4/6 the answer?"* Aisha: *"...Oh! I have to make the denominators the same."* (Maia's screen: her handwriting, the wrong line gently circled, **no answer shown** — just the next question.) |
| 1:00–1:40 | **The other half: it empowers the teacher** | End of day. The exhausted teacher picks up her phone. One screen: *Today's class — 60.* A tight list: *Aisha · fractions: concept ok, flips numerator/denominator → 10 min 1:1. Marco · 3 units ahead, bored → give enrichment. Fatima · hasn't opened the tablet in 2 days → check in. ...* She taps Aisha's row → a 30-second replay of *where* Aisha got stuck and *what* unstuck her. The teacher nods, makes a note. *(This is "empower the educator through seamless integration" — the brief's exact words — made concrete.)* |
| 1:40–2:20 | **The proof** | *"Maia runs Gemma 4's E4B model, 4-bit, on the tablet — no server, no signal. Multimodal vision reads the child's handwriting. Native function calling routes the turn — assess the work, ask the next Socratic question, check the child's reasoning, flag a stuck point, write the teacher's report. A 256K context holds the child's whole history, so the question Maia asks today knows what they got wrong last week. And it adapts: the system prompt is built once, locked, in the child's language and register — a teacher's tone, patient, never flattering, never giving the answer."* Cut: the teacher puts the tablet in airplane mode. Aisha keeps working. Cut to a laptop: Wireshark, zero packets, while Maia is mid-question. Title card: *Aisha's homework never left the tablet. Verify it: zero network permissions.* |
| 2:20–2:50 | **Scale + the "Good" thesis** | *"There are hundreds of millions of children in classrooms like this one. The cloud can't reach them — and even where it can, their homework shouldn't be someone else's training data. Maia doesn't replace the teacher; it gives her sixty children's worth of attention back. And it doesn't give children answers; it teaches them to find their own — which is the only thing a teacher ever really teaches."* Cut: Aisha, next morning, helping the kid next to her — *"You have to make the denominators the same"* — passing it on. |
| 2:50–3:00 | **Close** | Title card: **Maia — one child's teacher. Offline. In their language. And the teacher's, too.** / Gemma 4 E4B · on-device · zero network permissions · [GitHub] · [Demo build] |

---

## How We Use Gemma 4 Specifically

- **Multimodal vision (load-bearing)** — the child's handwritten work goes to the vision encoder; Maia *reads the actual page*, identifies the step where it went wrong (not "wrong answer" — *where* and *why*). Also reads diagrams the child draws, a textbook page they're stuck on.
- **Native function calling / multi-tool agent** — `assess_work(image, child_profile) → {concept, error_pattern, mastery}` → `ask_back(error_pattern, child_level, language)` (the Socratic next question) → `check_reasoning(child_response)` → optionally `flag_stuck(child_id, concept)` → optionally `escalate_to_teacher(child_id, reason)` ("this is a feelings thing, not a math thing — for you, not me") → end of day: `write_teacher_report(class_id)`. This is *literally* "multi-tool agents that adapt to the individual and empower the educator through seamless integration" — the brief's phrasing, implemented.
- **256K long context** — the child's full learning log (every assessed page, every error pattern, every breakthrough — SHA-256-deduped, the He Was Socrates `WonderingLog` generalized) feeds into context, so today's question is informed by last month's mistakes. *Adaptation* is real, not a setting.
- **Edge / E4B 4-bit** — runs on the cheap tablet the school actually has, offline. ~4 GB downloaded once at setup.
- **Configurable thinking** — a thinking budget when the child's error is subtle (a conceptual misconception vs a slip); none for a clear arithmetic mistake.
- **Domain adaptation, lightly** — optionally a small LoRA fine-tune that sharpens the Socratic-questioning discipline (never give the answer; always ask the *productive* next question) and the teacher's-tone register — published with weights and benchmarks per the brief's "if training a model, publish your weights." (The one place a small post-training pass is worth it — and it ticks the brief's "post-training, domain adaptation" box.)
- **Grounded** — Maia never gives a child medical, personal, or safety advice — `escalate_to_teacher` / "ask a grown-up". *(The He Was Socrates abstention gate, child-appropriate.)*

---

## Architecture (brief)

```
Tablet camera → child's work image → Gemma 4 E4B (vision + function calling, on-device)
       → orchestrator
       → { TTS reads the Socratic question aloud + on-screen: work with wrong step circled, no answer }
       ↔ STT / keyboard for the child's response
       → SQLite per-child learning log
       → end-of-day aggregate
       → teacher's one-page report (teacher's phone, same device family; P2P or shared install — no server)
```
Zero network code; **no INTERNET permission**.

---

## Why these technical choices were right

1. **On-device** — the school has spotty internet *and* a child's homework shouldn't be training data — both are in the brief.
2. **Socratic-not-answering** — for a *learner*, productive struggle is the pedagogy; here the "ask back" thesis is *correct*, not *clever*.
3. **Multimodal vision** — real tutoring needs to *see the work*; "wrong answer" is useless, "you flipped the fraction here" is teaching.
4. **The teacher report** — the brief says "empower the educator"; a tutor that *replaces* the teacher fails the brief, one that *targets her attention* nails it.
5. **E4B 4-bit on a cheap tablet** — that is the hardware these classrooms have.

---

## Reuses from the He Was Socrates POC

The `ask_back` / Socratic-counter-question logic (**its true home**) · the `FunctionCallOrchestrator` + parser · `WonderingLog` (→ per-child learning log) with SHA-256 dedup · the `defer_to_human` abstention gate (→ `escalate_to_teacher`) · the verbatim-locked, compile-time-embedded system prompt pattern (the teacher's tone, locked) · the deterministic build discipline · the zero-network-entitlement privacy pattern · the on-device TTS (now: reads the Socratic question aloud).

**Discards**: the 1-bit halftone bust · macOS-only · the fullscreen-Socratic-bust UX · the "a bust that refuses to answer" framing (here it is "a tutor that helps you find it yourself").

---

## Honest limitations

- v1 covers math (fractions → algebra) and reading comprehension in ~3 languages; other subjects/languages are roadmap.
- Handwriting recognition degrades on very messy work — confidence flag + "show me a clearer photo."
- The teacher report is only as good as the day's data — a child who avoids the tablet shows up as "hasn't opened it," which is itself useful signal.
- It does not grade, does not replace a curriculum, does not replace the teacher — it gives her attention a target.

---

## The vision / why this is "Good"

A teacher's scarcest resource is attention; a child's deepest need is to be *seen* where their thinking actually is. Maia gives both — without a server, without an account, without turning a child's homework into someone's data. And it teaches the one thing a teacher really teaches: not the answer, but how to find it.
