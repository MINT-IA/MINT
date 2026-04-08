# `tools/voice_corpus/` — MINT Frozen Voice Reference Corpus (v1)

Phase 5 Plan 02 artifact. Closes **VOICE-02**.
Authoritative files in this directory:

- `frozen_phrases_v1.json` — 50 frozen reference phrases (the corpus)
- `lint_anti_shame.mjs` — mechanical gate (schema + anti-shame checkpoints + banned terms)
- `README.md` — this file

Cross-reference: `docs/VOICE_CURSOR_SPEC.md` §9, §14.3, §14.4 ; `tools/contracts/voice_cursor.json` ;
`.planning/phases/05-l1.6a-voice-cursor-spec/05-CONTEXT.md` (D-08, D-09, D-10).

---

## §1 — Purpose

This corpus is the **Krippendorff α anchor set** for Phase 11 (VOICE-05). A small jury of raters
will classify each of the 50 phrases against the N1–N5 scale defined in
`docs/VOICE_CURSOR_SPEC.md` §2. Agreement is measured with Krippendorff's α. Target: **α ≥ 0.67
overall, α ≥ 0.67 per level on N4 and N5 specifically**.

The corpus also feeds:

- **VOICE-06** — reverse-Krippendorff generation test (Phase 11)
- **VOICE-07** — the coach few-shot block (`docs/VOICE_CURSOR_SPEC.md` §14.3)
- **VOICE-08** — ComplianceGuard regression set (paired with the Phase 5 Plan 03 anti-examples)

Phase 5 is **100 % documentation + corpus**. No Dart, no Python, no CI code lands here. The
corpus is a machine-consumable artifact — not a markdown table — precisely so Phase 11 tooling
can read it directly without lossy extraction.

---

## §2 — Freeze rule (NON-NEGOTIABLE)

**Once raters begin Phase 11 classification, no phrase in this file may be edited.** Re-rolls
invalidate Krippendorff α: raters who have already scored a phrase would be scoring a different
phrase than the one the α statistic is computed against.

Operational consequences:

1. If a phrase is found defective **after Phase 11 raters have started**, document the defect in
   a new file `tools/voice_corpus/corpus_errata.md`. Do **not** edit `frozen_phrases_v1.json`.
2. Errata entries specify: phrase id, defect description, exclusion decision (include with
   caveat / exclude from final α computation).
3. A **v2 corpus** (`frozen_phrases_v1.1.json`) may be created for a future α study. v1 is
   immutable.
4. The SHA-256 checksum in §9 below is the freeze proof. Phase 11 verifies the checksum before
   starting the study.

Authoring-phase exceptions (before Phase 11 starts) are tracked here:

- _No errata yet — corpus authored and frozen Phase 5 Plan 02, 2026-04-07._

---

## §3 — Distribution rule (D-08)

- **10 phrases per level × 5 levels = 50.**
- Within each level, life events are covered as: **retirement ×2, housing ×2, marriage ×1,
  jobLoss ×1, birth ×1, inheritance ×1, tax ×1, debt ×1**. Total = 10.
- **Exception — sensitive-topic cap collisions**: `jobLoss` maps to `sensitiveTopic =
  "perteEmploi"`, which is capped at **N3** by `docs/VOICE_CURSOR_SPEC.md` §5 (v0.5 hard cap).
  The `jobLoss` slot at N4 and N5 is therefore **forbidden**. At those levels, substitute with
  an extra `tax` or `debt` phrase and log the substitution in the phrase `rationale` field.
- The lint (`lint_anti_shame.mjs`) enforces the distribution mechanically and tolerates the
  documented substitution (`jobLoss` absent at N4/N5).

---

## §4 — Sourcing rule (D-09)

- ~20 phrases **mined** from existing MINT assets, principally
  `apps/mobile/lib/l10n/app_fr.arb` (calm-default registers naturally supply N2–N3 anchors). The
  current backend coach service (`services/backend/app/services/coach/claude_coach_service.py`)
  does not carry French fallback templates, so mining is ARB-only in Plan 02.
- ~30 phrases written **fresh**, concentrated on under-represented levels — N1 (murmure), N4
  (franche), and especially N5 (coup de poing), which does not exist in production copy.
- Every **mined** phrase carries `"source": "mined:<relative/path>:<arb-key-or-line>"`.
- Every **fresh** phrase carries `"source": "fresh:phase-5-plan-02"`.
- Mined phrases are re-audited against the 6 anti-shame checkpoints. If a mined candidate fails
  a checkpoint, it is **rejected** — not "fixed", because a fixed mined phrase becomes a fresh
  phrase and loses its production anchor.

---

## §5 — Anti-shame mandate (D-10)

Every phrase must pass **all six** checkpoints from
`feedback_anti_shame_situated_learning.md` §"Application checkpoints". Phrases carry
`"antiShameCheckpointsPassed": [1,2,3,4,5,6]` verbatim. Any phrase that cannot carry the full
array is rejected and regenerated.

The six checkpoints, reproduced for ease of reference:

1. **No comparison to other users** — past self only.
2. **No data request without insight repayment** — every ask unlocks a specific insight.
3. **No `tu dois` / `il faut` / `tu devrais` without conditional softening** (`pourrais`,
   `pourrait`, `envisager`, `peut-être`).
4. **No concept explanation before personal stake** — the user sees their own number before
   the jargon.
5. **No more than 2 screens between intent and first insight** — for isolated phrases this is
   the "flow-equivalent" interpretation: no phrase may assume the user has already absorbed a
   concept this session has not surfaced.
6. **No error/empty state implying the user "should" have something.**

The lint enforces a mechanical subset of these:

- Checkpoint 1 — banned terms grep (`meilleur`, comparatives).
- Checkpoint 3 — prescription regex (`tu dois / il faut / tu devrais`) without softener
  (`pourrais / pourrait / envisager / peut-être`).
- Checkpoints 2, 4, 5, 6 — not mechanically testable on isolated strings; enforced by
  `antiShameCheckpointsPassed` self-declaration + human review at authoring.

---

## §6 — Schema

```jsonc
{
  "version": "1.0.0",
  "frozenAt": "2026-04-07",
  "phase": "05-l1.6a",
  "phraseCount": 50,
  "phrases": [
    {
      "id": "N3-004",                    // N{1-5}-{001-010}, unique
      "level": "N3",                     // N1|N2|N3|N4|N5
      "lifeEvent": "retirement",         // retirement|housing|marriage|jobLoss|birth|inheritance|tax|debt
      "gravity": "G2",                   // G1|G2|G3 (from voice_cursor.json)
      "relation": "established",         // new|established|intimate
      "sensitiveTopic": null,            // null or one of voice_cursor.json sensitiveTopics
      "frText": "Mint voit dans ton certificat un détail…",
      "source": "mined:apps/mobile/lib/l10n/app_fr.arb:renteVsCapitalConfidenceNoticeLow",
      "rationale": "why this phrase belongs at this level + context",
      "antiShameCheckpointsPassed": [1, 2, 3, 4, 5, 6]
    }
  ]
}
```

All fields are mandatory. `sensitiveTopic` is `null` for non-sensitive phrases (majority case).

---

## §7 — Krippendorff sampling rules (for Phase 11)

Raters receive phrases in a **single deterministic shuffle**, stratified by level (no three
identical-level phrases in a row). The shuffle is seeded by the SHA-256 of this frozen JSON
file, truncated to the first 8 hex characters, so every Phase 11 rater session is reproducible.

To derive the seed:

```bash
shasum -a 256 tools/voice_corpus/frozen_phrases_v1.json | awk '{print substr($1, 1, 8)}'
```

Target per-level rater count: **10 phrases × ≥ 3 raters = ≥ 30 scores per level**, which is the
minimum for a trustworthy per-level α. Total ratings ≥ 150.

The Phase 11 executor is responsible for:

1. Re-verifying the checksum in §9 below.
2. Applying the deterministic shuffle with the derived seed.
3. Running the rating session against the unchanged file.
4. Computing α (overall + per-level) and appending the result to a new file
   `tools/voice_corpus/krippendorff_alpha_v1.json` — never by modifying this corpus.

---

## §8 — Lint usage

```bash
node tools/voice_corpus/lint_anti_shame.mjs
# exit 0 + "OK: 50/50 phrases pass anti-shame checkpoints" on success
# exit 1 + per-phrase error report on failure
```

The lint reads `frozen_phrases_v1.json` from this directory by default. Pass an explicit path
to test a candidate file:

```bash
node tools/voice_corpus/lint_anti_shame.mjs tools/voice_corpus/candidate.json
```

What the lint enforces (mechanical gate):

- 50 phrases total, 10 per level.
- Per-level life-event distribution per §3 (with `jobLoss` N4/N5 substitution tolerated).
- Unique `id` matching `N{1-5}-{001-010}`.
- All required fields present; enum values valid against `voice_cursor.json`.
- `antiShameCheckpointsPassed` equals `[1,2,3,4,5,6]` exactly.
- No banned terms (`garanti`, `sans risque`, `meilleur`, `parfait`, `optimal`, `conseiller`,
  `chiffre choc`).
- No prescriptive `tu dois / il faut / tu devrais` without conditional softener.
- Non-breaking space (`\u00a0`) before `!`, `?`, `:`, `;`, `%`.
- `sensitiveTopic` null on all N4 and N5 entries (v0.5 §5 cap).
- `relation: "new"` absent from N4 and N5 entries (v0.5 §3 relation cap).
- `source` starts with `mined:` or equals `fresh:phase-5-plan-02`.

---

## §9 — Freeze checksum (SHA-256)

Once the corpus is final, the SHA-256 of `frozen_phrases_v1.json` is pasted below. Phase 11
verifies this checksum before starting the α study. If the hash does not match, the corpus has
drifted and the study is aborted pending errata review.

```
frozen_phrases_v1.json sha256 = 75293279916f5cd860db99289c7d78d89bb1dd65c9970b404d4684a49e0eea3a
```

Compute command:

```bash
shasum -a 256 tools/voice_corpus/frozen_phrases_v1.json | awk '{print $1}'
```

_Frozen 2026-04-07 by Phase 5 Plan 02._
