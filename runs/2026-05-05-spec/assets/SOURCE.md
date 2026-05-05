# Visual Brief — Source-of-Truth References

## socrates-portrait.png (canonical bust reference)

User-attached at SpecDD entry (2026-05-05 14:44 KST). Not yet persisted to disk
(Claude Code multimodal cache is in-memory only). User to drop the file at:

```
runs/2026-05-05-spec/assets/socrates-portrait.png
```

### Description (from observation)

Stylized illustration / digital painting on transparent background:

- **Pose:** Frontal three-quarter, head and upper chest visible
- **Head:** Bald crown, gray-and-white tightly curled hair flaring sideways
  above the ears (classical Greek portrait convention)
- **Beard:** Voluminous, long, gray-and-white, curl-textured, covers chin and
  upper chest — a defining silhouette feature
- **Eyebrows:** Heavy, gray-and-white, slightly furrowed
- **Eyes:** Dark brown, gaze cast slightly to viewer's left, expression
  thoughtful / mildly skeptical (the "Socratic squint")
- **Skin:** Warm peach-amber tone with painterly shading, ears slightly
  reddened — hints at flushed liveliness rather than marble pallor
- **Garment:** Loose draped white himation / chiton, soft brushwork on folds
- **Background:** Transparent (PNG alpha)
- **Style:** Painterly digital portrait, not photoreal. Reads as warm and
  human rather than cold marble. Slightly caricatured proportions
  (large beard, expressive eyes).

### Implications for SPEC

1. **Color palette** — design-approved.json `color.alabaster_bust`
   (oklch 0.92 0.02 75) is the *light highlight* tone, but the source image
   skews warmer (peach-amber). `warm_amber_accent` (oklch 0.78 0.15 75) on
   skin midtones may be more faithful than pure alabaster. **SC1_a11y +
   SC6_performance critics: confirm WCAG contrast against ink-black bg
   (oklch 0.15 0.01 280) holds for the warmer tone.**
2. **Viseme rendering target** — 16 viseme PNGs/SVGs swapped at 30 fps must
   maintain this warm-painterly aesthetic. Viseme set must be authored
   *from* this portrait (not generated from a different style guide) to
   avoid uncanny mid-sentence style break.
3. **Reduce-Motion fallback** — at 12 fps (per design tokens), the painterly
   style may show frame-stutter more than a flat-vector style would. SC1
   critic: validate that 12 fps fallback still feels intentional, not broken.
4. **Beard occlusion** — heavy beard covers most of the lower face. Mouth
   shape changes will read primarily through (a) the visible mouth opening
   in the beard, and (b) subtle beard-edge motion. SC6 perf: this means
   small per-frame pixel deltas → tighter drift tolerance (≤30ms RMS may be
   needed vs the design-approved 50ms target).
5. **Transparency / fullscreen composition** — alpha channel must survive
   the 30 fps swap; black ink-black bg fills around the bust. M04 (UP D1)
   "menu bar disappears" cold-open is composed against this alpha portrait.

### License & Provenance

User declared 2026-05-05 KST: **AI-generated**. Per-user direction,
generator/prompt/date hygiene tracking declared **out-of-scope** for this
project ("필요 없어"). The PROVENANCE.md stub file remains as a marker
that the user took ownership of the AI-generation decision.

Implication for distribution: if the runtime app ever ships the source
portrait directly, the user's AI-generation declaration is the only
license documentation. Per Hybrid stack decision (2026-05-05), the runtime
ships **only the halftone-converted derivative** (1-bit PNG produced by
`src/halftone.py` at build time), not the source portrait. So distribution
license risk is bounded to the derivative.

### Cross-References

- `chosen_preview.json` line 11-15 (concept_name = "He Was Socrates")
- `design-approved.json` lines 22-30 (color tokens)
- `design-approved.json` line 41-43 (viseme_swap_fps 30, crossfade 0)
- `idea.spec.json` line 47 (viseme-audio drift target ≤ 50ms RMS)
