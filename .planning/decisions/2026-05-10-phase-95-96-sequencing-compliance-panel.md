---
date: 2026-05-10
status: Proposed
authors: Senior Eng Lead + Swiss Financial Compliance Officer (1-shot risk panel)
panel: 2-role (eng + compliance)
supersedes: —
superseded_by: —
description: Phase 95→96 sequencing decisions + compliance gates + stop conditions for autonomous orchestration chain after Phase 94 close-out.
related:
  - .planning/ROADMAP.md
  - .planning/phases/94-mvp-citation-gate/94-VERIFICATION.md
  - .planning/phases/94-mvp-citation-gate/94-03-FLAG-FLIP-PROPOSAL.md
  - CLAUDE.md
  - tools/checks/no_legal_admission_in_public_docs.py
---

# Phase 95→96 Sequencing + Compliance Panel — Autonomous Execution Review

## TLDR

Phase 95 (DAG-INVALIDATION) and Phase 96 (CHAT-AS-VERB) may begin with a worktree-parallel strategy, but Phase 96's `NarrativeSleeve` linter MUST NOT merge before Phase 95's `inputs_hash` contract is stable; four additional compliance gates are required before either phase merges to dev; and the autonomous loop carries three hard stop conditions.

---

## Context

Phase 94 closes at 4/5 verified (GATE-01..04 green; SC-3 eval thresholds NOT MET — Sonnet 6%, Haiku 14% vs targets ≥95% / ≥90%; prod flag stays OFF). Julien approved NO-GO + PARTIAL on 2026-05-10. Wave 4 (narrator prompt fattening) is the Phase 94.1 unblocker. The autonomous orchestrator is about to chain `/gsd-discuss-phase 95 --auto` → `/gsd-discuss-phase 96 --auto`.

Citation: `.planning/phases/94-mvp-citation-gate/94-VERIFICATION.md` §Stage 3 Threshold Tracking; `94-03-FLAG-FLIP-PROPOSAL.md` §Decision.

---

## Decision

### Q1 — 95→96 dependency: is GroundingPack a HARD blocker?

**Decision: SOFT dependency with mandatory fallback.**

Phase 96's `NarrativeSleeve` (hook/caption/next_step/metaphor) linter operates on narrator text structure, not on numeric content. It does NOT require `GroundingPack` to function. Phase 96 MUST accept `GroundingPack | None` on the backend `source_card_facts` path — if `inputs_hash` is absent (Phase 95 not yet merged), card facts are treated as unverified and the narrator prompt receives a `staleness: unknown` flag rather than blocking.

The ONE hard dependency: Phase 96's 3-turn cap server-side logic reads `source_card_id` → resolves projection → checks `staleness` flag. That resolution path requires at minimum the nullable `inputs_hash` field to exist on `ProjectionModel`. Phase 95 MUST land the additive migration (nullable hash, ROADMAP DAG-04) before Phase 96 merges — not before Phase 96 opens a branch.

**Implementation: Phase 95 delivers nullable `inputs_hash` first. Phase 96 can open in parallel worktree but merges second.**

### Q2 — Parallel worktree feasibility

**Decision: YES, open Phase 96 worktree in parallel with Phase 95 backend work.**

Phase 96 mobile work (kill chat-tab, `MintCardActionBar`, `MintChatOverlay` widget) touches `apps/mobile/lib/screens/` and `apps/mobile/lib/widgets/`. Phase 95 touches `apps/mobile/lib/services/financial_core/` + `services/backend/app/models/projection.py`. File collision surface is nil on the Flutter side. Collision risk on backend: `coach_chat.py` (Phase 95 may add staleness propagation; Phase 96 adds `source_card_facts` injection). Both phases must coordinate a single `coach_chat.py` merge order: Phase 95 lands first, Phase 96 rebase on top.

Memory `feedback_no_nuke_worktree_with_running_agent` constrains cleanup, not creation. Parallel branches are safe.

**Implementation: open `feature/S96-mvp-chat-as-verb` worktree immediately; block its PR merge behind Phase 95 PR merge confirmation.**

### Q3 — Phase 94.1→95 dependency: does Phase 95 require 94.1 GO-prod?

**Decision: NO. Phase 95 ships on staging-only gate.**

Phase 95 (`inputs_hash` + `superseded_by`) is a pure data-model + calculator layer. It does not invoke the citation gate at runtime; it only populates `GatedResponse.inputs_hash` (Phase 94 stub field at `citation_parser.py:263`). Phase 95 can merge to dev with `COACH_CITATION_GATE_ENABLED` remaining OFF on prod. The Phase 94.1 prod-flip threshold (Sonnet ≥95% gate-correct) is a narrator prompt correctness gate, independent of the DAG hash chain. Phase 95's own 5-gate exit contract closes against: (a) test_projection_dag_invalidation.py green, (b) G5 lint clean, (c) G3 CI green — none of these depend on 94.1 eval pass.

**Implementation: Phase 95 opens immediately without waiting for Phase 94.1 eval results.**

---

### Q4 — Additional autonomous-output compliance gates

Beyond the `NarrativeSleeve` linter (no num in hook), wire these four gates before merging Phase 95 or 96:

1. **Banned-terms grep on every narrator-touching commit** — extend `tools/checks/banned_terms_python.py` to cover FR string constants in any `build_narrator_system_prompt*` function. Run in lefthook pre-commit AND in `.github/workflows/` CI. Cite: CLAUDE.md §1 (LSFin banned terms); `mint-swiss-compliance/SKILL.md` §Forbidden Words.
2. **PII scan on every API response fixture** — before committing eval fixtures under `tests/fixtures/`, run `grep -E '\b\d{3}[\s.-]\d{3}[\s.-]\d{4}\b|\bAHV[-\s]\d+\b'` (phone + AHV number patterns) on the JSONL. No real-user data in fixtures. Add to `tools/checks/` as `pii_fixture_scan.py`.
3. **`no_legal_admission_in_public_docs.py` pre-commit on all `.planning/**/*.md` changes** — already in scope per `tools/checks/no_legal_admission_in_public_docs.py`; verify it runs in lefthook for Phase 95/96 PR commits. Any Phase 95/96 ADR text must avoid the 13 forensic phrases enumerated in the lint (explicit violation language, personal-liability framing, panel-panic adjectives). Cite: `tools/checks/no_legal_admission_in_public_docs.py:40-57`.
4. **`accent_lint_fr.py` on all narrator prompt fragments** — every new `prompt_fragment: str` in `bundles/` must pass `python3 tools/checks/accent_lint_fr.py` before merge. ASCII `e` in place of `é` in narrator output is a user-trust regression. Cite: CLAUDE.md §2 (Accents 100% FR mandatory).

### Q5 — Public-repo discipline: ROADMAP phrases at risk

The ROADMAP entries for Phase 94/95/96 contain: « ChatGPT clone fear », « calc-first vs LLM », « ADR calc-first N2 ». Run against `no_legal_admission_in_public_docs.py` patterns: none of these phrases match the 13 PATTERNS in `tools/checks/no_legal_admission_in_public_docs.py:40-57`. They are descriptive product-strategy language, not forensic admission. Safe for public repo as written.

Pre-flight check result: 0 ROADMAP.md lines match PATTERNS. No edits needed.

### Q6 — TestFlight fast path after Phase 96

Per memory `project_testflight_ship_path`: actual ship = pubspec bump + dev→staging merge fires `testflight.yml`. After Phase 96 closes, the fast path is:

1. Phase 96 PR merged to dev (CI green, G3).
2. `pubspec.yaml` version bump (patch increment) committed to dev.
3. dev→staging merge triggers `.github/workflows/testflight.yml` automatically.
4. Gate items before that merge: (a) G4 regression suite ≥229 Flutter model tests + new Phase 95/96 perimeter tests; (b) G5 LSFin + accent + ARB parity 6 locales; (c) Phase 95 Maestro flow `flow_profile_edit_staleness.yaml` PASS; (d) Phase 96 Maestro flow `flow_card_action_intent_bar.yaml` PASS; (e) `CHAT_TAB_VISIBLE` flag confirmed default-off in staging build.

Walker is NOT a ship blocker per memory `project_testflight_ship_path`. G2 Julien device confirm on TestFlight build is the final human gate.

### Q7 — Pre-merge audit script (0-trust, per-phase)

Add `tools/checks/pre_merge_audit.sh` with this pattern:

```bash
#!/usr/bin/env bash
# Usage: bash tools/checks/pre_merge_audit.sh <phase-tag>
set -euo pipefail
PHASE="${1:-UNKNOWN}"
echo "=== PRE-MERGE AUDIT: $PHASE ===" >> ".planning/reports/pre-merge-audit-$PHASE.txt"
# 1. Banned claim phrases
grep -rn "shipped\|livré\|closed\|fermé\|ready\|prêt\|works\|marche\|validated\|validé\|PROVISIONALLY READY" \
  .planning/phases/ --include="*.md" | grep -v "NEVER\|banned\|0-trust\|§9" \
  >> ".planning/reports/pre-merge-audit-$PHASE.txt" || true
# 2. LSFin banned terms in narrator strings
python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/ \
  >> ".planning/reports/pre-merge-audit-$PHASE.txt"
# 3. Accent lint on bundle fragments
python3 tools/checks/accent_lint_fr.py \
  >> ".planning/reports/pre-merge-audit-$PHASE.txt"
# 4. Public-repo discipline
python3 tools/checks/no_legal_admission_in_public_docs.py \
  >> ".planning/reports/pre-merge-audit-$PHASE.txt"
echo "=== AUDIT COMPLETE ===" >> ".planning/reports/pre-merge-audit-$PHASE.txt"
```

Run as the last step before opening each phase PR. Report file lives in `.planning/reports/` (persists across sessions, unlike `/tmp/`). Cite: memory `feedback_html_evidence_report`.

### Q8 — Anthropic API cost cap

Phase 95 eval (50-fixture DAG invalidation pack) + Phase 96 eval (3-turn cap flow × 50 fixtures) at Sonnet pricing: approximately $0.003/1K input + $0.015/1K output. Estimated 100 eval calls × ~4K tokens each = ~$8–12 per eval run. With retries and wave-based execution: total Phase 95+96 eval spend likely $40–80 (comparable to Phase 94's three live eval runs).

**Hard cap mechanism**: in `eval_narrator.py` and any Phase 95/96 eval harness, add `--max-calls N` flag (default 150). If executor reports ≥3 consecutive FALLBACK verdicts on different fixture categories (indicating a systemic prompt regression, not noise), halt and surface to Julien. Do NOT auto-iterate on systemic failures — that compounds spend with no diagnostic value. Cite: CLAUDE.md §7 #4 Goal-Driven Execution.

### Q9 — Stop conditions for autonomous loop

Pause the autonomous loop and surface to Julien on any of these five signals:

1. **Eval threshold miss by >30pp** — if any phase's Stage 3 eval lands below (target − 30pp) on first run (e.g. Sonnet gate-correct <65% when target is ≥95%), the root cause is structural, not iteratable without a scope decision. Surface immediately; do not iterate with prompt tweaks.
2. **`coach_chat.py` merge conflict on both Phase 95 and 96 branches** — indicates the worktree parallel strategy has produced diverging edits to the same function. Stop, consolidate, re-plan merge order. Manual resolution required.
3. **CI failure not attributable to the phase's own changes** — if `flutter analyze` or `pytest -q` fails on a file not touched by Phase 95 or 96, a regression from a prior merge is likely. Do not push through; surface the failure with the offending test name.
4. **Railway staging deploy fails (non-200 health check after Phase 95 migration)** — the additive `inputs_hash` nullable migration could surface a Pydantic v2 schema validation error on existing profiles. Halt; do not flip any flag; surface to Julien with the Railway log excerpt.
5. **`chat_overflow_turn_4` Sentry metric fires at >40% rate within first 24h of Phase 96 staging flag-on** — indicates users are actively trying to circumvent the 3-turn cap, which means the UX framing of the overlay is adversarial. Walkback flag before proceeding. Cite: ROADMAP.md Phase 96 §Success Criteria 5.

---

## Counter-arguments and data gaps

- **Strongest opposing view — sequential over parallel:** Running Phases 95 and 96 in parallel worktrees adds coordination overhead (rebase on `coach_chat.py`, merge order enforcement) that a solo founder workflow cannot absorb without tooling. A strict sequential chain (95 fully merged + CI green, THEN 96 opens) eliminates merge-conflict risk entirely at the cost of ~2–3 days of calendar time. This view is credible for a team of one.

- **What this analysis does not address:** We have no empirical data on how often `coach_chat.py` is touched per phase on average in v2.9. If Phase 95 and Phase 96 each require ≥5 edits to `coach_chat.py`, the rebase surface is non-trivial and the parallel strategy may cost more than it saves. This should be checked by counting the Phase 95 ROADMAP requirements that touch `coach_chat.py` before opening the Phase 96 worktree.

- **What would change this conclusion:** If Phase 94.1 (narrator prompt fattening) delivers Sonnet ≥95% gate-correct on first Wave 4 re-eval, the prod flip opens immediately and Phase 95's DAG hash chain becomes the next hard dependency for citation correctness on prod. In that scenario, Phase 95 becomes a de-facto blocker for prod Phase 96, not just a staging dependency — the sequencing decision reverts to strict serial.

---

## Sources

- `.planning/ROADMAP.md` — Phase 95 (DAG-01..DAG-04), Phase 96 (VERB-01..VERB-06), 5-gate exit contract
- `.planning/phases/94-mvp-citation-gate/94-VERIFICATION.md` — 4/5 verified, G2+G3 open, SC-3 NOT MET
- `.planning/phases/94-mvp-citation-gate/94-03-FLAG-FLIP-PROPOSAL.md` — NO-GO + PARTIAL rationale, D-21 sunset clause
- `tools/checks/no_legal_admission_in_public_docs.py:40-57` — PATTERNS list (13 forensic phrases)
- `.claude/skills/mint-swiss-compliance/SKILL.md` — LSFin forbidden words, mandatory disclaimers
- `CLAUDE.md` §1 (banned terms), §2 (accents), §7 (Karpathy 4), §9 (0-trust protocol)
- Memory `project_testflight_ship_path` — dev→staging merge fires testflight.yml; walker not a ship blocker
- Memory `feedback_no_nuke_worktree_with_running_agent` — parallel worktree creation safe; nuking running agent not safe
- Memory `feedback_html_evidence_report` — reports must live in `.planning/reports/`, not `/tmp/`

---

## Status & follow-up

- Implementation tracking: Phase 95 PR (TBD), Phase 96 PR (TBD), `tools/checks/pre_merge_audit.sh` (to author in Phase 95 Wave 0)
- Re-litigation triggers:
  - Phase 94.1 Wave 4 eval delivers Sonnet ≥95% on first run → revisit sequencing Q3 (95 may become hard dep for prod Phase 96)
  - Phase 95 `coach_chat.py` touch count ≥5 → revisit parallel worktree strategy (revert to sequential)
  - `chat_overflow_turn_4` rate >40% at Phase 96 staging → revisit 3-turn cap design (not just flag rollback)

---
*Template v1 — Wiki Pattern Karpathy practice 3 enforced by `tools/checks/wiki_lint.py`.*
