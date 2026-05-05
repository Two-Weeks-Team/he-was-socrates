# Model Integrity — He Was Socrates

**Authored:** 2026-05-05T16:18+09:00 (KST)
**Addresses:** SC7-006, SC3-004, L20

---

## 1. Bundle layout

```
HeWasSocrates.app/Contents/Resources/
├── models/
│   ├── gemma-4-e4b-it-4bit/
│   │   ├── weights.safetensors        # ~3.97 GB
│   │   ├── tokenizer.json
│   │   └── config.json
│   └── embedding/
│       └── nl-embedding-v1.bin        # if Apple NLEmbedding chosen
└── visemes/
    ├── AA.png ... REST.png            # 16 PNGs, ~50–100 KB each
    └── manifest.json
```

## 2. Build-time hash registration

`spec/MODEL_HASHES.json` (committed; updated at every model bump):

```json
{
  "schema_version": "1.0.0",
  "models": [
    {
      "id": "gemma-4-e4b-it-4bit/weights.safetensors",
      "expected_sha256": "TBD-COMPUTED-AT-BUILD-TIME",
      "size_bytes_expected": 4262400000,
      "license_ref": "/licenses/GEMMA_TOU.txt"
    },
    {
      "id": "gemma-4-e4b-it-4bit/tokenizer.json",
      "expected_sha256": "TBD-COMPUTED-AT-BUILD-TIME"
    },
    {
      "id": "gemma-4-e4b-it-4bit/config.json",
      "expected_sha256": "TBD-COMPUTED-AT-BUILD-TIME"
    }
  ],
  "_note": "TBD values are filled by build script `_scripts/compute-model-hashes.sh` and embedded into the Swift binary as a const struct at compile time."
}
```

## 3. Runtime check (Swift sketch)

```swift
struct ModelIntegrityCheck {
    /// Hash baked into the binary at build time from spec/MODEL_HASHES.json.
    static let expectedHashes: [String: String] = [
        "gemma-4-e4b-it-4bit/weights.safetensors": "<sha256>",
        "gemma-4-e4b-it-4bit/tokenizer.json":      "<sha256>",
        "gemma-4-e4b-it-4bit/config.json":         "<sha256>"
    ]

    /// Verify on first launch (full SHA-256) and on every launch (mtime+size cached check).
    /// Mismatch → refuse to launch with `Model.IntegrityMismatch`.
    static func verifyOrAbort() throws {
        // 1. Cache check by mtime + size (fast path; SC6-feedback on launch latency)
        // 2. If cache stale or first launch → full SHA-256
        // 3. Compare against expectedHashes
        // 4. On mismatch → throw ModelIntegrityError.mismatch(file)
        // 5. NEVER re-download (would violate idea.spec.json#no_go)
    }
}
```

## 4. Performance budget for the check

- First launch: full SHA-256 of 3.97 GB blob ≈ 2–4 s on M2 SSD. Hidden behind the splash screen (SC6-05 launch state machine).
- Every-launch: mtime + size cache check ≈ < 50 ms. Full SHA only if cache invalidated by mtime change.

## 5. Threat model (explicit non-goals)

This integrity check protects against:
- DMG corruption in transit (download mid-flight)
- Post-install tampering by another process with write access to /Applications
- Antivirus/Gatekeeper partial-extract corruption

This check does NOT protect against:
- A compromised codesigning identity (out of scope; mitigated by Apple notarization)
- A compromised Gemma weights upstream (mitigated by Gemma's own attestation if available; NOT this app's responsibility)
- An attacker who controls the binary itself (would just modify expectedHashes)

## 6. License binding

- `/Resources/models/*` is governed by `/licenses/GEMMA_TOU.txt`, NOT by the Apache-2.0 repo license.
- The About > Acknowledgments view in the app surfaces the Gemma TOU and all third-party SBOM entries (SC7-016).
- Cross-reference: SBOM at `/sbom/he-was-socrates.cdx.json` (CycloneDX 1.5).
