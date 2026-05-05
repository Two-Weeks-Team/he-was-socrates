# Core Data Model — He Was Socrates

**Authored:** 2026-05-05T16:00+09:00 (KST)
**Storage choice:** Core Data (locked; SwiftData migration tooling immature on macOS 14 — SC5-04 L13)
**Encryption:** macOS user-level FileVault; per-folder `NSURLIsExcludedFromBackupKey = true` on Application Support root (SC7-010 supersedes `idea.spec.json`'s "File Protection complete" wording, which is iOS-only).

---

## 1. Storage layout

```
~/Library/Application Support/com.twoweeks.hewassocrates/
├── wondering.sqlite          # primary store
├── wondering.sqlite-shm
├── wondering.sqlite-wal
├── wondering.sqlite.pre-v{N} # pre-migration backup (SC5-04)
├── audio/
│   └── {wonder-uuid}.m4a     # AAC (never raw PCM); SC5-09 + SC7-015
├── viseme-cache/
│   └── {wonder-uuid}.timeline.cbor # cached viseme timeline (SC5-10)
└── diagnostics/
    └── attempts-{date}.log   # rolling 10 MB; SC5-11
```

All paths set `NSURLIsExcludedFromBackupKey = true` (SC7-010). Time Machine still backs them up unless user excludes manually — disclosure surfaced in COPPA consent screen (L19).

---

## 2. Entities

### 2.1 `AppMeta` (singleton)

| Field | Type | Notes |
|---|---|---|
| id | UUID, indexed unique | always `00000000-0000-4000-8000-000000000000` |
| schemaVersion | Int | SC5-04 |
| appVersionAtLastMigration | String | semver |
| consentSource | String enum | `self_adult \| parent_direct_basic \| parent_direct_strong \| school_authorized \| unset` (L19, SC7-018) |
| consentCapturedAt | Date? | KST stored; null until consent gate passed |
| consentParentName | String? | parent_direct_basic only; redacted on export |
| consentScreenAcceptedHash | String? | SHA-256 of accepted consent text (immutability proof) |
| coppaChildModeActive | Bool | derived from consentSource ∈ {parent_direct_basic, parent_direct_strong} |
| modelSHA256 | String | bound at first launch; SC7-006 |
| mlxSwiftVersion | String | embedded at build time |
| firstLaunchAt | Date | KST |
| lastLaunchAt | Date | KST |
| createdAt | Date | immutable |

### 2.2 `Session`

| Field | Type | Notes |
|---|---|---|
| id | UUID, indexed unique | UUIDv4 |
| startedAt | Date | KST |
| endedAt | Date? | nullable until session ends |
| mode | String enum | `curious_adult \| learning_student \| skeptical \| unspecified` (L10) |
| modeHistory | Transformable | `[(mode, confidence, atKST)]` (SC5-13) |
| deploymentContext | String enum | `individual \| school_mdm \| unset` (SC7-018, MVP=individual) |
| recoveryReason | String enum? | `crash \| user \| os_terminated` if crash recovery (SC5-06) |
| surfacedWonderIds | Transformable | `Set<UUID>` for per-session dedup (SC5-08) |
| createdAt | Date | immutable |

**Computed (not stored):** `wonderCount` = `wonders.count` derived. SC5-06 explicitly removes the stored counter.

**Crash recovery (SC5-06):** on app launch, scan for `endedAt == nil AND startedAt < now - 24h` → set `endedAt = lastWonderAt + 5min`, `recoveryReason = .crash`. Idempotent: re-running on already-recovered sessions is a no-op (recoveryReason ≠ nil).

### 2.3 `Wonder`

Append-only after first save (SC5-07 immutability invariant). "Edit" = soft-delete + re-insert with `supersedesId`.

| Field | Type | Mutability | Notes |
|---|---|---|---|
| id | UUID, indexed unique | immutable | UUIDv4 random (SC5-01 L14) |
| turnId | UUID | immutable | SC2-009 SC5-03; one turn → one Wonder; ties to function-call envelope |
| sessionId | UUID, indexed | immutable | foreign key → Session.id |
| createdAt | Date | immutable | KST `+09:00` preserved at JSON export (SC4-012) |
| userUtterance | String, ≤4000 | immutable | as transcribed by SFSpeechRecognizer (final) |
| socraticReply | String, ≤280 | immutable | full ask_back terminal text |
| socraticReplyDisplayText | String | immutable | caption-formatted, ≤2 lines chunked (SC1-014) |
| accessibilityNarrative | String, ≤200 | immutable | VoiceOver 1-line summary (SC1-014) |
| readingLevelGrade | Float? | immutable | grade-level estimate; null if unset (SC1-011) |
| mode | String enum | immutable | per L10 |
| modeRaw | String, ≤64? | immutable | Gemma's pre-normalization emission (SC2-007 L10) |
| modeConfidence | Float | immutable | 0.0–1.0 (SC2-013) |
| bcp47Locale | String | immutable | resolved BCP-47 (L11); no `auto` ever persisted |
| bcp47SecondaryLocale | String? | immutable | for code-switched utterance (SC4-005) |
| audioFilePathLocal | String? | immutable | relative path `audio/{id}.m4a`, validated regex `^audio/[0-9a-f-]{36}\.m4a$` (SC7-015) |
| thinkingTraceCompressed | String, ≤200 | immutable | first 200 chars of Gemma thinking-mode trace, truncated at last whole word + ellipsis (SC5-14) |
| inferenceFingerprint | Transformable | immutable | `{modelSHA256, mlxSwiftVersion, temp, topP, topK, seed}` (SC5-02) |
| contentFingerprint | String, 64 hex | immutable | SHA-256 over `normalize(userUtterance) + mode + bcp47Locale` (SC5-01 L14) |
| visemeTimelineCached | Data? (CBOR) | immutable after first synthesis | SC5-10 replay determinism |
| surfaceLater | Bool | mutable + audited | default true; SC5-07 |
| surfacedHistory | to-many SurfaceEvent | append-only | for replay-fire control |
| relatedWonderIds | Transformable | append-only | `[UUID]` cross-link from `surface_past_wonder` |
| supersedesId | UUID? | immutable | SC5-07 soft-delete pointer |
| tags | to-many SemanticTag | append-only | |
| _deletedAt | Date? | mutable | soft-delete sentinel; physical delete on COPPA 24h timer or user purge |

**Indexes:** `sessionId`, `bcp47Locale`, `mode`, `contentFingerprint`, `createdAt DESC`, `_deletedAt`.

### 2.4 `SurfaceEvent`

| Field | Type | Notes |
|---|---|---|
| id | UUID, indexed unique | |
| wonderId | UUID, indexed | foreign key → Wonder.id (the SURFACED wonder) |
| sessionId | UUID, indexed | session in which surfaced |
| atKST | Date | |
| contextHash | String, 32 hex | hash of current-turn user_utterance for diagnostics |

### 2.5 `SemanticTag`

| Field | Type | Notes |
|---|---|---|
| id | UUID, indexed unique | |
| name | String | NFC-normalized |
| embeddingHash | String, 32 hex | **SHA-256 of full embedding vector, truncated to 32 hex chars (one-way)** — SC7-014 RECOMMENDED option 1. NEVER a truncated embedding (privacy). |
| embeddingModelId | String | e.g. `apple-NLEmbedding-v1` or `gemma-4-e4b-embed-v1` |
| createdAt | Date | |
| _deletedAt | Date? | cascade from Wonder soft-delete (SC7-014) |

**Uniqueness:** (`embeddingHash`) — Core Data merge policy `NSMergeByPropertyStoreTrumpMergePolicy` (SC5-05).

---

## 3. Migration policy (SC5-04)

| Rule | Detail |
|---|---|
| Schema versioning | `AppMeta.schemaVersion: Int` (1 at v1.0). |
| Lightweight only | for v1.x patch versions. New optional fields, new entities. |
| Heavyweight | for any field rename/delete or required-field-addition. Triggers user-confirmation overlay → export-to-JSON-and-recreate flow. |
| Idempotency | Re-running migration on already-migrated store is a NO-OP, gated by `schemaVersion` comparison. |
| Backup before migrate | Copy `wondering.sqlite` → `wondering.sqlite.pre-v{N}` before any migration runs. |
| Failure rollback | If migration fails, restore from backup, surface "wondering log preserved, app rolling back to v{N-1}" UX. |
| 24h retention | For child-mode Wonder rows (`AppMeta.coppaChildModeActive == true`), background job purges `Wonder` AND associated `audioFilePathLocal` files at `createdAt + 24h`. SemanticTag cascade-deletes when last referencing Wonder is purged (SC7-014). |

---

## 4. Audio file lifecycle (SC5-09 + SC7-015)

- Filename = `{Wonder.id}.m4a` (UUID guarantees no collision).
- Format = AAC in M4A container (hardware-accelerated, never raw PCM — SC7-010).
- Lifecycle: create-on-first-write, never-overwrite.
- On Wonder soft-delete: rename `{id}.m4a` → `{id}.deleted.m4a`; physical purge on next launch + 30 days OR immediate on COPPA 24h timer.
- On launch: garbage-collect orphan audio files (no matching Wonder.id). Idempotent: re-running finds zero orphans.

---

## 5. JSON export schema (SC5-12)

Canonical, byte-stable format:

- Sorted by `Wonder.createdAt ASC, then Wonder.id lex`.
- JSON keys sorted alphabetically.
- ISO-8601 with KST `+09:00` offset preserved (NOT normalized to UTC — preserves user's wall-clock memory; SC4-012).
- Wonder.tags sorted by `SemanticTag.id`.
- Top-level metadata: `exportSchemaVersion: "1.0.0"`, `appVersion`, `generatedAt: ISO8601 +09:00`, `wonderingLogContentHash: SHA-256(canonical body excluding generatedAt)`.
- Two exports of an unchanged log produce identical `wonderingLogContentHash`.
- Audio files NOT included by default (more sensitive); user opt-in to bundle as sibling `audio/` folder.
- `inferenceFingerprint`, `contentFingerprint`, `visemeTimelineCached` INCLUDED for replay reproducibility.
- `embeddingHash` INCLUDED (one-way; safe).
- COPPA child-mode rows include only the metadata strictly required for the user's right-to-portability — utterance text + reply, NOT audio.
- Test fixture: `spec/test-fixtures/sample-export.json` (post-build artifact).

---

## 6. Cross-references

- L13 (storage choice), L14 (Wonder.id strategy), L15 (inference determinism), L19 (consent), L20 (entitlements)
- SC1-014 (a11y reservation fields), SC2-009 (turn_id propagation), SC4-012 (date formatting), SC5 cluster, SC7-010 / SC7-014 / SC7-015
