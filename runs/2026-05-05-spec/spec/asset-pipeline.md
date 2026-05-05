# Asset-Authoring Options Reference (NOT a contract)

**Status:** This file was rewritten on 2026-05-05 KST after Claude
over-interpreted earlier conversation context as a stack pivot. The actual
user direction is: *attached portrait = visual-direction only, runtime stack
= Swift+MLX-Swift unchanged, asset-authoring path deferred to scaffold
(Stage 5)*. See `spec/user-ratifications.md` (f) and
`spec/scaffold-plan-proposal.md` for authoritative scope.

This file is preserved as a **non-binding options reference** for scaffold
discussion. It is NOT part of the SHA-locked SpecDD deliverable set.

## Three asset-authoring options to evaluate at scaffold start

### Option A — Hand-authored 16 painterly PNGs

- Author 16 PNG files in Procreate / Photoshop / Figma
- Trace from the attached painterly source portrait
- Fidelity: highest (matches source aesthetic precisely)
- Time cost: 1-2 days (art skill required, or freelance commission)
- Reproducibility: not deterministic (artist's hand)
- Compatibility with frozen SpecDD: 100% (drop-in to bundle)

### Option B — Halftone-derived REST + procedural mouth variants

- Build-time Python: `src/halftone.py` converts portrait → 1-bit halftone REST PNG
- Build-time Python or Swift: 15 mouth-shape variants composed via affine
  transform / mask overlay onto the halftone REST PNG
- Fidelity: medium-high (halftone aesthetic, intentional stylization)
- Time cost: 1-2 days dev
- Reproducibility: fully deterministic (same source + same params → byte-identical PNGs)
- Compatibility with frozen SpecDD: 100% (the runtime still loads 16 PNGs)

### Option C — Hand-authored REST + runtime Metal shader morph

- Author 1 REST PNG (traced from portrait)
- Runtime Metal/Core Image shader deforms mouth region into 16 viseme shapes
- Fidelity: medium-high
- Time cost: 2 days dev (shader programming)
- Reproducibility: deterministic per shader inputs
- Compatibility with frozen SpecDD: requires re-evaluation of `viseme_swap_fps: 30`
  semantics — runtime shader morph at 30fps is GPU contention with MLX inference
  (SC6 risk). Probably **not recommended** for hackathon timeline.

## Recommended for hackathon timeline (W1+W2 = 14 days)

**Option B** balances time cost, fidelity, reproducibility, and SpecDD compatibility.
But this is a recommendation only — user picks at scaffold start.

## Decision deadline

Pick at scaffold start (Stage 5 kickoff). No earlier decision required;
SpecDD lock is unaffected.
