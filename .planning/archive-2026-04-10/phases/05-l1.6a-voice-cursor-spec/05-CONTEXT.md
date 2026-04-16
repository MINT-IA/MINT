---
phase: 05-l1.6a-voice-cursor-spec
milestone: v2.2 La Beauté de Mint
status: planned
created: 2026-04-07
branch: feature/v2.2-p0a-code-unblockers
requirements: [VOICE-01, VOICE-02, VOICE-03, VOICE-07, VOICE-11, VOICE-12]
depends_on: [Phase 2 (v0.5 extract + contract SoT), Phase 1.5 (premier éclairage rename)]
unblocks: [Phase 6 (Regional voice VS/ZH/TI), Phase 11 (Krippendorff α validation), Phase 12 (Ton UX setting)]
---

# Phase 5 — L1.6a Voice Cursor Spec (full)

## Objective

Extend `docs/VOICE_CURSOR_SPEC.md` from the v0.5 extract (193 lines, 8 sections) to the **full v1.0 spec** that Phase 11 Krippendorff α validation can run against. Land the **50 frozen reference phrases** corpus, **20 anti-examples**, **few-shot + cost-delta decision**, **pacing rules per N level**, **regional voice stacking rules**, and **narrator wall grep-gate commitment**.

This is a **documentation + corpus** phase. No Dart, no Python, no CI code changes land here — only the spec, the corpus JSON, and the anti-examples appendix. Phase 11 will consume all three as inputs to the α study; Phase 6 will consume the regional stacking rules.

## Non-negotiables (locked decisions)

### D-01 — Append, never rewrite
The v0.5 extract is frozen. Phase 4 (MTC-05) and Phase 9 (MintAlertObject) anchored their tonal alignment against it. Phase 5 **appends** new sections **after** §8 Traceability. The 8 existing sections are touched only to: (a) update the version header to v1.0.0, (b) add forward-references like "see §9" where v0.5 points to "Phase 5". No sentence of the 8 existing sections is deleted or rewritten.

### D-02 — Single-file spec, corpus extracted
The full spec lives in **one file**: `docs/VOICE_CURSOR_SPEC.md`. Target final length **~1400-1700 lines** (v0.5 is 193, delta ~1200-1500). The 50 frozen reference phrases do **NOT** live in the markdown — they live in `tools/voice_corpus/frozen_phrases_v1.json` as a machine-consumable artifact. The spec references the JSON by path and reproduces a short illustrative sample (2-3 phrases per level) inline for readability. Rationale: Phase 11 Krippendorff tooling needs JSON; rewriting the JSON from markdown extraction is an error surface we refuse to create.

### D-03 — Anti-examples in the spec, not separate file
The 20 anti-examples land as an **appendix** (§13 or §14) inside `docs/VOICE_CURSOR_SPEC.md`. Each anti-example is tagged with: (a) the N level it superficially mimics, (b) the anti-shame checkpoint it violates (1-6 from `feedback_anti_shame_situated_learning.md`), (c) a one-line "why this fails" gloss, (d) the corrected form. Rationale: anti-examples are pedagogical and belong next to the definitions they protect.

### D-04 — Few-shot wins at current scale
The few-shot vs fine-tune decision is **locked to few-shot** in Phase 5. Rationale: (a) corpus is 50 phrases — fine-tune requires 1000+ for meaningful signal, (b) Anthropic prompt caching reduces the recurring few-shot cost by ~90% for stable prefixes, (c) fine-tuning locks tone before Krippendorff validates the corpus (tone-locking is the exact failure mode VOICE-06 tests for). Phase 5 writes the cost-delta analysis in `docs/COACH_COST_DELTA.md` and the decision log inline. Phase 11 may revisit if α fails.

### D-05 — Few-shot format: 3 × N4 + 3 × N5 verbatim + context header
The coach system prompt gets a `<voice_examples>` block with 6 verbatim phrases (3 at N4, 3 at N5), each preceded by a one-line context header `[N4 — G2 gravity, calm relation, non-sensitive]`. N1/N2/N3 are **not** few-shot embedded — the coach defaults toward calmness without tone-locking, and embedding the low levels risks pulling all output toward the mean. This mirrors the VOICE-07 requirement.

### D-06 — Regional stacking order (locked)
`base N level → regional adaptation (VS/ZH/TI) → sensitive topic cap → fragile mode cap → N5 rate-limit gate`. Regional adaptation is a **lexical+cadence** layer applied **after** N level is resolved. It never changes the N level. A VS user at N4 and a ZH user at N4 produce phrases of **equal intensity** — only the diction shifts. This is locked so Phase 6 does not invent a parallel intensity system.

### D-07 — Sensitive topic cap precedes user preference (reaffirmed)
Already in v0.5 §5. Phase 5 does **not** revisit. The prose rationale is expanded in the new precedence cascade section, but the rule itself is frozen.

### D-08 — 50-phrase distribution
**10 phrases per N level × 5 levels = 50.** Within each level, distribute across life-event contexts: retirement (2), housing (2), marriage (1), job loss (1), birth (1), inheritance (1), tax (1), debt (1). Each phrase carries metadata: `{id, level, lifeEvent, gravity, relation, sensitiveTopic, frText, rationale, antiShameCheckpointsPassed[1..6]}`. The `antiShameCheckpointsPassed` array is mandatory — every phrase must pass all 6 checkpoints or it is rejected.

### D-09 — Corpus sourcing: mix, biased toward fresh
- ~20 phrases **mined from existing ARB** (`apps/mobile/lib/l10n/app_fr.arb` + `claude_coach_service.py` fallback templates) — these anchor the corpus to what MINT currently says, giving Phase 11 raters a baseline to calibrate against.
- ~30 phrases **written fresh** by the Phase 5 executor, because the current ARB is biased toward N2-N3 (calm default) and under-represents N1 (murmure/fragile), N4 (franche), and especially N5 (coup de poing) which does not yet exist in production copy.
- Every mined phrase is re-audited against the 6 anti-shame checkpoints before inclusion; ARB age does not grant immunity.

### D-10 — Anti-shame doctrine: every phrase and anti-example must pass all 6 checkpoints
The 6 checkpoints from `feedback_anti_shame_situated_learning.md` §"Application checkpoints":
1. No comparison to other users (past self only)
2. No data request without insight repayment
3. No "tu devrais / il faut / tu dois" without conditional softening
4. No concept explanation before personal stake
5. No more than 2 screens between intent and first insight (N/A for isolated phrases — apply the flow-equivalent: no phrase may assume the user has already absorbed a concept the current session has not surfaced)
6. No error/empty state implying the user "should" have something

Every phrase in `frozen_phrases_v1.json` carries `antiShameCheckpointsPassed: [1,2,3,4,5,6]`. Any phrase that cannot carry the full list is **rejected and regenerated**. Anti-examples (§13) are the inverse: each one is tagged with the specific checkpoint(s) it **violates**.

### D-11 — Pacing rules are prose-only at Phase 5 (no ms numbers)
Pacing per N level is described as: sentence length range (word count), paragraph length range (sentence count), cadence descriptor ("breathing", "measured", "sharp", "clipped", "ruptured"), and inter-sentence silence descriptor ("long", "medium", "short", "beat", "hard silence"). **Millisecond numbers are deferred to Phase 11** because they can only be calibrated against audio playback telemetry that does not exist yet. Phase 5 commits the shape; Phase 11 calibrates the numbers.

### D-12 — Narrator wall grep gate: documented here, wired in Phase 11
v0.5 §4 committed Phase 5 to "wire a lint check". Correction logged in D-12: the **lint specification** lands in Phase 5 (exact grep pattern, expected call sites, red-build rules) but the **CI wiring** moves to Phase 11 alongside the ComplianceGuard regression (VOICE-08). Rationale: the grep needs live call sites to test against, and Phase 6/7/8 will add more surfaces during their migrations. Landing the grep in Phase 5 would produce false positives on half-migrated surfaces.

## Deferred ideas (explicit — do NOT include)

- **Millisecond pacing targets** → Phase 11 (needs audio telemetry).
- **CI grep-gate wiring** → Phase 11 (needs stable call-site surface).
- **Krippendorff α study execution** → Phase 11.
- **Reverse-Krippendorff generation test** → Phase 11 (VOICE-06).
- **Coach few-shot embedding into `claude_coach_service.py`** → Phase 11 (VOICE-07 implementation; Phase 5 only writes the cost-delta doc and the few-shot content).
- **User-facing "Ton" setting UI** → Phase 12 (VOICE-13).
- **30-phrase coach rewrite** → Phase 11 (VOICE-04).
- **Regional ARB files for VS/ZH/TI** → Phase 6 (L1.4). Phase 5 writes only the stacking rules.
- **N5 server-side rate limiter** → Phase 11 (VOICE-09).
- **Auto-fragility detector** → Phase 11 (VOICE-10).

## Claude's discretion

- Exact wording of the 50 phrases, as long as D-08/D-09/D-10 constraints hold.
- Section numbering within the appended block (§9 onward), as long as the 8 existing sections remain untouched.
- Whether to use tables or prose for the 9-cell × 5-level matrix — prose preferred for Phase 11 rater clarity, but tables acceptable for the pacing rules.
- Exact format of the cost-delta doc, as long as it carries: baseline token count, few-shot delta, prompt-caching mitigation, decision log with D-04 reference.

## Scope concerns (flagged to orchestrator)

1. **Corpus authoring density.** 50 phrases × 6 checkpoints × metadata = the heaviest single artifact in this phase. It is a full plan on its own (Plan 02), not a task inside Plan 01.
2. **Anti-examples risk drift.** 20 anti-examples that "look correct" require the executor to actively write violations of the doctrine they just absorbed. Split into its own plan (Plan 03) so context is fresh and the executor is explicitly in "adversary mode".
3. **Phase 5 is 100% documentation.** No code changes means no flutter test / pytest verification. Each plan's `<verify>` relies on grep-based structural checks + anti-shame checkpoint lint (a lightweight Node script the executor writes inline in Plan 02). This is acceptable but must be called out.
4. **CONTEXT.md length.** This document itself is long because the decisions are load-bearing. Executors read it once per plan.
5. **Anti-shame checkpoint #5 is flow-level, not phrase-level.** The executor must apply the "flow-equivalent" interpretation (D-10) and not regenerate phrases that fail #5 on a literal reading.

## Requirements coverage

| Req | Plan | Coverage |
|---|---|---|
| VOICE-01 (full spec) | Plan 01 | Full |
| VOICE-02 (50 frozen phrases) | Plan 02 | Full |
| VOICE-03 (anti-examples) | Plan 03 | Full |
| VOICE-07 (few-shot + cost delta doc) | Plan 01 | Full (decision + cost doc; embedding wiring = Phase 11) |
| VOICE-11 (context bleeding rules) | Plan 01 | Full (register-reset clause + `[N5]` tag + breath separator rules documented; runtime enforcement = Phase 11) |
| VOICE-12 (narrator wall) | Plan 01 | Full (grep spec documented; CI wiring = Phase 11 per D-12) |
