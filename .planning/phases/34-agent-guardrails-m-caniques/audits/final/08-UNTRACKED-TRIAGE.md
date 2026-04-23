# Untracked Work Triage — 2026-04-23

**Branch:** `feature/S30.7-tools-deterministes` (42 commits ahead of origin, 76 ahead of base per context)
**Repo:** `/Users/julienbattaglia/Desktop/MINT` → `/MINT.nosync`
**Total untracked items:** 19 (15 files + 4 directories)
**Modified tracked files:** 15 (3 ARB + 12 golden-test PNGs)
**Critical items requiring decision:** 3 (tier.py, 5x Phase 30.7 PLAN files, 5x ADRs)

---

## Decision matrix

| Path | Kind | Classification | Action | Risk if left untracked |
|------|------|----------------|--------|------------------------|
| `services/backend/app/services/llm/tier.py` | file | **COMMIT-NOW + WIRING-REQUIRED** | own commit **PLUS** follow-up wiring commit | HIGH — $40 incident can recur; module exists but NOT called anywhere |
| `.planning/phases/30.7-tools-d-terministes/30.7-00-PLAN.md` | file | **COMMIT-NOW** | bundle into single "backfill Phase 30.7 PLAN files" commit | MED — plan artifacts missing while SUMMARY/VERIFICATION tracked; breaks phase archive consistency |
| `.planning/phases/30.7-tools-d-terministes/30.7-01-PLAN.md` | file | **COMMIT-NOW** | (same commit as above) | MED — same |
| `.planning/phases/30.7-tools-d-terministes/30.7-02-PLAN.md` | file | **COMMIT-NOW** | (same commit) | MED — same |
| `.planning/phases/30.7-tools-d-terministes/30.7-03-PLAN.md` | file | **COMMIT-NOW** | (same commit) | MED — same |
| `.planning/phases/30.7-tools-d-terministes/30.7-04-PLAN.md` | file | **COMMIT-NOW** | (same commit) | MED — same |
| `decisions/ADR-20260415-tax-declaration-autopilot.md` | file | **COMMIT-NOW** | ADR batch commit | MED — vision ADR referenced by tracked Phase 0 ADR |
| `decisions/ADR-20260415-tax-declaration-autopilot-REVIEW.md` | file | **COMMIT-NOW** | ADR batch commit | MED — adversarial review synthesis, irreplaceable analysis |
| `decisions/ADR-20260418-wave-order-daily-loop.md` | file | **COMMIT-NOW** | ADR batch commit | MED — explains wave reordering that already shipped |
| `decisions/ADR-20260419-killed-gamification-layers.md` | file | **COMMIT-NOW** | ADR batch commit | MED — explains what was killed and why |
| `decisions/ADR-20260501-tax-phase-0-wedge.md` | file | **COMMIT-NOW** | ADR batch commit | MED — execution plan for vision ADR |
| `decisions/archive/` (1 file: `ADR-20260415-tax-declaration-autopilot-v1-REJECTED.md`) | dir | **COMMIT-NOW** | ADR batch commit | LOW — rejected version, audit trail |
| `.planning/backlog/scan-screen-ux-audit-2026-04-20.md` | file | **COMMIT-NOW** | small commit "backlog: scan screen UX audit" | LOW — 2.2 KB P2 finding, ship-blocking UX debt |
| `.planning/mvp-wedge-onboarding-2026-04-21/PERSONA-WALK-JULIEN-2026-04-22.md` | file | **COMMIT-NOW** | own commit | MED — 15 KB persona walkthrough, critical artifact for MVP wedge |
| `.planning/mvp-wedge-onboarding-2026-04-21/screenshots/v2-00-landing.png` | file | **COMMIT-AFTER-REVIEW** | bundle into persona-walk commit (or skip: `v2-01` == `v2-02` byte-identical, suspicious) | LOW — storyboard evidence |
| `.planning/mvp-wedge-onboarding-2026-04-21/screenshots/v2-01-opener.png` | file | **COMMIT-AFTER-REVIEW** | bundle OR leave (duplicate of v2-02) | LOW — see note |
| `.planning/mvp-wedge-onboarding-2026-04-21/screenshots/v2-02-after-tap.png` | file | **COMMIT-AFTER-REVIEW** | bundle OR leave | LOW — byte-identical to v2-01 (140547 bytes each), likely re-screenshot of same state |
| `.planning/phases/32-cartographier/screenshots/` (13 PNGs, 2.6 MB) | dir | **COMMIT-AFTER-REVIEW** | Phase 32 already shipped (PR #368 → dev efe409dd) — decide: archive with phase 32 or leave local only | LOW — evidence of E2E flow test referenced by `scan-screen-ux-audit-2026-04-20.md` |
| `.planning/live-testing/` (3 MB, 6 files + 1 subdir with 21 files) | dir | **LEAVE-AS-IS** | none, or add to `.gitignore` | LOW — scratch journal, contains 24 files of adversarial review that may have value but NOT yet merged into consolidated ADR |
| — | — | — | — | — |
| `apps/mobile/lib/l10n/app_localizations_{es,it,pt}.dart` | files | **COMMIT-NOW** | bundle with Phase 34-04 follow-up commit | MED — `forfaitFiscalSemanticsLabel` Savings clause completion drifted post-34-04 arb_parity fix |
| `apps/mobile/test/goldens/failures/*.png` (12 files) | files | **REVERT** | `git checkout apps/mobile/test/goldens/failures/` | NONE — gitignored but pre-existed; stale test output, not work product |

---

## Deep-dives

### `services/backend/app/services/llm/tier.py` (43 lines, created 2026-04-22 13:06)

**Verdict:** **COMMIT-NOW — but module is UNWIRED. Commit alone will not prevent $40 recurrence.**

**Evidence:**
- File defines `is_mvp_tier()` reading env `MINT_LLM_TIER` (default `"prod"`) and `resolve_primary_model(default_sonnet, haiku_override="claude-haiku-4-5-20251001")`.
- `resolve_primary_model` is **called nowhere in the repo**. Grep across `services/backend/` returns only self-references in the docstring.
- Hardcoded model IDs still present in 3 production code paths:
  - `services/backend/app/api/v1/endpoints/coach_chat.py:1050` — `PRIMARY_MODEL_DEFAULT = "claude-sonnet-4-5-20250929"` (and `FALLBACK_MODEL_HAIKU` line 1051 — already has a Haiku reference but not gated by tier)
  - `services/backend/app/services/coach/token_budget.py:31` — `_MODEL_PRIMARY = "claude-sonnet-4-5-20250929"`
  - `services/backend/app/services/rag/llm_client.py:72` — `"claude": "claude-sonnet-4-5-20250929"` (RAG alias map)
- Version drift: `tier.py` hardcodes the old IDs (`...20250929` / `...20251001`); repo elsewhere uses updated IDs (`...20251022` in `bedrock_client.py`, `vision_guard.py`, `router.py`). The tier module's defaults are already stale.

**Proposed commit message (module only, no wiring yet):**
```
feat(llm): add MINT_LLM_TIER env switch for MVP cost tier (Haiku fallback)

Introduces resolve_primary_model(default_sonnet, haiku_override) that
returns the haiku override when MINT_LLM_TIER=mvp, else the sonnet
default. Isolates the policy so coach + RAG call sites can be migrated
one at a time without cross-cutting grep-and-replace.

Context: ~$40 API spend on 2026-04-22 without a functional MVP flow.
Staging burns in on Haiku 4.5 during MVP; production stays on Sonnet.

NOTE: call sites are NOT yet migrated. coach_chat.py, token_budget.py,
and rag/llm_client.py still hardcode sonnet IDs. Wiring lands in a
follow-up commit.
```

**Wiring follow-up (required for the incident fix to be real):**
1. `services/backend/app/api/v1/endpoints/coach_chat.py` — replace `PRIMARY_MODEL_DEFAULT` assignment with `resolve_primary_model(default_sonnet="claude-sonnet-4-5-20251022", haiku_override="claude-haiku-4-5-20251022")` (note: update model IDs to `20251022` to match bedrock_client/vision_guard canonical IDs).
2. `services/backend/app/services/coach/token_budget.py:31` — same treatment for `_MODEL_PRIMARY`.
3. `services/backend/app/services/rag/llm_client.py:72` — `"claude"` alias should resolve via `resolve_primary_model`.
4. Also update `tier.py` defaults to `20251022` to match the codebase canonical IDs (or drop the stale defaults from the docstring).
5. Add env var to Railway staging: `MINT_LLM_TIER=mvp`; leave production unset.
6. Add a pytest that asserts `resolve_primary_model` picks Haiku when `monkeypatch.setenv("MINT_LLM_TIER", "mvp")`.

**Ship gate:** Commit tier.py now (cheap), ship wiring commit before next Railway deploy, otherwise MVP burn-in is a no-op.

---

### `.planning/phases/30.7-tools-d-terministes/30.7-0X-PLAN.md` (5 files, ~120 KB total)

**Verdict:** **COMMIT-NOW. Not duplicates — legitimately missing PLAN artifacts.**

**Evidence:**
- `git ls-files .planning/phases/30.7-tools-d-terministes/` shows 10 tracked files: `30.7-0{0..4}-SUMMARY.md`, `30.7-CONTEXT.md`, `30.7-HUMAN-UAT.md`, `30.7-RESEARCH.md`, `30.7-VALIDATION.md`, `30.7-VERIFICATION.md`. **PLAN files are absent.**
- Every other phase in the repo tracks its PLAN files: `.planning/phases/30.5-context-sanity/30.5-0{0,1,2}-PLAN.md`, `30.6-…/30.6-0{0,1,2}-PLAN.md`, `31-instrumenter/31-0{0..4}-PLAN.md`, `32-cartographier/32-0{0..5}-*-PLAN.md`, `34-agent-guardrails-m-caniques/34-0{0..7}-PLAN.md` (all present in `git ls-files`).
- `.gitignore` does NOT exclude PLAN files.
- Commit `edf468b6 docs(phase-30.7): complete phase execution (11/12 auto pass, J0 smoke deferred by plan design)` shipped the phase WITHOUT the PLANs. Likely an oversight when the executor staged only SUMMARY files.
- PLAN files are real content: YAML frontmatter, `must_haves.truths`, `artifacts`, `files_modified` lists referring to actual shipped code (`tools/mcp/mint-tools/`, `tools/checks/accent_lint_fr.py`, `CLAUDE.md`).

**Proposed commit message:**
```
docs(30.7): backfill missing PLAN files (00..04)

Phase 30.7 shipped the SUMMARY/VERIFICATION/HUMAN-UAT artifacts in
edf468b6 but the five PLAN files (one per wave) were left untracked.
This commit restores phase archive consistency with all other phases
in .planning/phases/ which carry PLAN alongside SUMMARY.

No code change — docs-only backfill.
```

---

### ADRs (5 new files in `decisions/` + 1 in `decisions/archive/`)

**Verdict:** **COMMIT-NOW as one "ADR batch" commit.** All 5 are mature, reference each other, and 2 are referenced by already-tracked ADRs.

**Evidence per file:**
| File | Size | Status in header | Referenced by tracked content? |
|---|---|---|---|
| `ADR-20260415-tax-declaration-autopilot.md` | 13 KB | "Proposed (vision)" | Cross-links to `ADR-20260501-tax-phase-0-wedge.md` |
| `ADR-20260415-tax-declaration-autopilot-REVIEW.md` | 18 KB | "Reviewer synthesis — 6 adversarial agents" | Supersedes v1 (now in `archive/`) |
| `ADR-20260418-wave-order-daily-loop.md` | 5.6 KB | "Accepted" | Work shipped (Wave B-minimal, Wave A-prime) |
| `ADR-20260419-killed-gamification-layers.md` | 6.9 KB | "Accepted (pending Wave B-minimal ship)" | Cites `feedback_anti_shame_situated_learning`, MEMORY.md references Wave A shipped |
| `ADR-20260501-tax-phase-0-wedge.md` | 30 KB | "Proposed" | Phase 0 plan for the vision ADR above |
| `decisions/archive/ADR-20260415-tax-declaration-autopilot-v1-REJECTED.md` | 26 KB | "REJECTED by 6/6 panel" | Audit trail for the REVIEW doc |

**Proposed commit message:**
```
docs(decisions): archive 6 ADRs from the April 2026 tax + daily-loop sessions

Adds:
- ADR-20260415 Tax Declaration Autopilot (vision, v2 rescoped)
- ADR-20260415 Adversarial review synthesis (6-agent panel, v1 KILLED)
- ADR-20260418 Wave order — B before A (accepted, already shipped)
- ADR-20260419 Killed gamification layers (accepted pre Wave B-min)
- ADR-20260501 Tax Phase 0 Wedge (execution plan for vision)
- archive/ADR-20260415-v1-REJECTED (audit trail)

All five new ADRs cross-reference each other and are already referenced
by tracked content. Backfill so fresh clones have the decision history.
```

---

### Modified ARB files (3 files: es, it, pt) — `forfaitFiscalSemanticsLabel`

**Verdict:** **COMMIT-NOW as "Phase 34-04 arb_parity follow-up".**

**Evidence:**
- Diff in all 3 files is identical shape: append `Savings: $savings` / `Ahorro: $savings` / `Risparmio: $savings` / `Economia: $savings` to the 3-arg semantic label. The `$savings` placeholder was already declared in the method signature (line above) but not consumed in the French output — a bug carried in the generated code.
- Commit `30c7c900 feat(34-04): implement arb_parity lint + fix 3 pre-existing drifts (GUARD-05 GREEN)` landed the lint that CATCHES this class of drift; these 3 file mods are the **matching fix** that appears to have been run locally (probably via `flutter gen-l10n` after an ARB source edit) but never staged.
- No other keys changed. The change is additive + safe.

**Why it wasn't auto-committed:** Likely the ARB **source** files (`.arb`) were staged and committed in 34-04 but the re-generated `.dart` bindings drifted in a subsequent `flutter gen-l10n` invocation without a stage.

**Proposed commit message:**
```
chore(l10n): regenerate es/it/pt bindings for forfaitFiscalSemanticsLabel

Follow-up to 30c7c900 (arb_parity lint). The $savings placeholder was
declared in the method signature but absent from the es/it/pt output
strings. Running flutter gen-l10n picks up the Savings clause from the
.arb source and threads it through the generated Dart.

No code change — generator output only.
```

---

### Golden test failures (12 PNGs under `apps/mobile/test/goldens/failures/`)

**Verdict:** **REVERT (`git checkout`), do not commit.**

**Evidence:**
- `.gitignore` contains `apps/mobile/test/goldens/failures/` (line in "Golden test failures - never commit" block).
- These show as "modified" because they were committed in `b75f0a6b fix: 3 critical architecture bugs from audit` BEFORE the gitignore rule was added in `24b36038 On dev: pre-existing golden test failures (not Phase 32)`. The tracked copies from b75f0a6b are now stale.
- Timestamps: 2026-04-23 08:25 — generated minutes before this audit, likely by a local `flutter test` run.
- Recommended action: `git checkout apps/mobile/test/goldens/failures/` to restore the committed versions. A separate follow-up can clean up the tracked stale PNGs via `git rm --cached`, but that is a scope-expansion and should be its own decision.

---

### `.planning/live-testing/` (3 MB, 24 files)

**Verdict:** **LEAVE-AS-IS** (or gitignore if Julien prefers).

**Evidence:**
- Contains `README.md` defining the "user-vivant" QA protocol (5 personas: Julien, Lauren, Sophie, Marc, Clara), 4 audit synthesis files dated 2026-04-17 (coach-robustness, data-flow, routes, screens) plus 1 run log, plus subdirectory `2026-04-19-lea-ruchat-month/` with 21 files (dream-team reviews, 6 expert audits, findings, plan quality gate v2).
- Content is real analysis but is a **scratch workspace**, not a published decision. The consolidated outputs either already landed as ADRs or as phase plans.
- Risk of commit: 3 MB payload, much of which will be superseded by future consolidations — bloats git history.
- Risk of leaving untracked: losing 3 MB of raw reviewer output on a fresh clone. Acceptable given the distilled outputs (ADRs + plans) are tracked.
- **Recommended nuance:** add a `.planning/live-testing/` line to `.gitignore` so it stops appearing in `git status` as noise.

---

### `.planning/backlog/scan-screen-ux-audit-2026-04-20.md`

**Verdict:** **COMMIT-NOW (small).**

**Evidence:** 2.2 KB, P2 UX finding, 6 concrete doctrine violations identified during Phase 32 E2E flow test. Accompanies the `.planning/backlog/STAB-carryover.md` already tracked (same directory pattern).

**Proposed commit message:**
```
backlog: scan screen UX audit 2026-04-20 (6 doctrine violations)

P2 finding from Phase 32 E2E flow test. 5 design direction breaches +
1 accent regression + 1 P1 text clipping. Deferred to v2.9 or design
sprint per STAB-carryover convention.
```

---

### `.planning/mvp-wedge-onboarding-2026-04-21/PERSONA-WALK-JULIEN-2026-04-22.md`

**Verdict:** **COMMIT-NOW.**

**Evidence:** 15 KB persona walkthrough, Julien 34 Lausanne, traces CoachProfile keys through every tab and surface post-T9. Same directory already tracks STORYBOARD-DECISIONS.md, STORYBOARD-FINAL-LOCKED.md, OPENER-PHRASES-PANEL2.md, PANEL3-POST-OPENER.md — this is the missing walkthrough companion.

**Proposed commit message:**
```
docs(mvp-wedge): persona walk Julien 34 Lausanne (2026-04-22)

End-to-end walkthrough post-T9 sync: every tab, every surface, expected
vs observable rendering with P0/P1 verdicts. Evidence input for the
locked storyboard decisions.
```

---

### `.planning/mvp-wedge-onboarding-2026-04-21/screenshots/v2-{00,01,02}-*.png` (3 PNGs)

**Verdict:** **COMMIT-AFTER-REVIEW — investigate `v2-01 == v2-02`.**

**Evidence:**
- `v2-01-opener.png` and `v2-02-after-tap.png` are both 140547 bytes. Likely byte-identical (two screenshots of the same state, mis-labeled) or the "after tap" state visually == "opener".
- `v2-00-landing.png` is 107430 bytes (distinct).
- Directory already tracks `00-landing-fresh.png` and `01-entry.png` — the `v2-` series is a second capture wave.

**Recommendation:**
- If v2-01/v2-02 are intentionally identical (to prove "tap has no visible effect"), keep both and annotate in the README.
- Otherwise drop one (or recapture) before committing.
- Bundle into the persona-walk commit.

---

### `.planning/phases/32-cartographier/screenshots/` (13 PNGs, 2.6 MB)

**Verdict:** **LEAVE-AS-IS or separate "Phase 32 E2E evidence" commit.**

**Evidence:**
- Phase 32 already shipped (PR #368 → dev efe409dd per MEMORY.md).
- These screenshots are evidence referenced by `.planning/backlog/scan-screen-ux-audit-2026-04-20.md` (e.g., `10-scanner-tap-587.png`, `11-gallery-picker.png`, `12-scrolled.png`).
- Landing them now means a retroactive add to a shipped phase. Git-hygiene-neutral — docs/evidence only.

**Recommendation:** Commit only if we are also committing `scan-screen-ux-audit-2026-04-20.md` (they reference each other). Add to the backlog commit, or leave untracked if storage is a concern (2.6 MB).

---

## Recommended commit sequence (ready-to-run — do NOT execute yet)

```bash
# Pre-flight: revert gitignored golden failures
git checkout -- apps/mobile/test/goldens/failures/

# Commit 1 — feat(llm): tier switch module (no wiring yet)
git add services/backend/app/services/llm/tier.py
git commit -m "feat(llm): add MINT_LLM_TIER env switch for MVP cost tier (Haiku fallback)

Introduces resolve_primary_model(default_sonnet, haiku_override) that
returns the haiku override when MINT_LLM_TIER=mvp, else the sonnet
default. Isolates the policy so coach + RAG call sites can be migrated
one at a time without cross-cutting grep-and-replace.

Context: ~\$40 API spend on 2026-04-22 without a functional MVP flow.
Staging burns in on Haiku 4.5 during MVP; production stays on Sonnet.

NOTE: call sites are NOT yet migrated. coach_chat.py, token_budget.py,
and rag/llm_client.py still hardcode sonnet IDs. Wiring lands next."

# Commit 2 — docs(30.7): backfill PLAN files
git add .planning/phases/30.7-tools-d-terministes/30.7-0{0,1,2,3,4}-PLAN.md
git commit -m "docs(30.7): backfill missing PLAN files (00..04)

Phase 30.7 shipped SUMMARY/VERIFICATION/HUMAN-UAT in edf468b6 but the
five PLAN files (one per wave) were left untracked. This restores
phase archive consistency with all other phases in .planning/phases/."

# Commit 3 — docs(decisions): ADR batch
git add decisions/ADR-20260415-tax-declaration-autopilot.md \
        decisions/ADR-20260415-tax-declaration-autopilot-REVIEW.md \
        decisions/ADR-20260418-wave-order-daily-loop.md \
        decisions/ADR-20260419-killed-gamification-layers.md \
        decisions/ADR-20260501-tax-phase-0-wedge.md \
        decisions/archive/ADR-20260415-tax-declaration-autopilot-v1-REJECTED.md
git commit -m "docs(decisions): archive 6 ADRs from the April 2026 tax + daily-loop sessions

Adds tax autopilot vision + v2 adversarial review + Phase 0 wedge plan,
plus wave-order + killed-gamification ADRs. All cross-reference each
other or already-tracked ADRs. Backfill so fresh clones carry the
decision history."

# Commit 4 — chore(l10n): regenerate es/it/pt bindings
git add apps/mobile/lib/l10n/app_localizations_es.dart \
        apps/mobile/lib/l10n/app_localizations_it.dart \
        apps/mobile/lib/l10n/app_localizations_pt.dart
git commit -m "chore(l10n): regenerate es/it/pt bindings for forfaitFiscalSemanticsLabel

Follow-up to 30c7c900 (arb_parity lint). The \$savings placeholder
was declared in the method signature but absent from the es/it/pt
output. flutter gen-l10n picks up the Savings clause from .arb and
threads it through the generated Dart."

# Commit 5 — docs(mvp-wedge): persona walk + screenshots
git add .planning/mvp-wedge-onboarding-2026-04-21/PERSONA-WALK-JULIEN-2026-04-22.md
# (decide v2-*.png after resolving v2-01 == v2-02 question)
git commit -m "docs(mvp-wedge): persona walk Julien 34 Lausanne (2026-04-22)

End-to-end walkthrough post-T9 sync: every tab, every surface,
expected vs observable rendering with P0/P1 verdicts."

# Commit 6 — backlog: scan screen UX audit (+ optional phase-32 screenshots)
git add .planning/backlog/scan-screen-ux-audit-2026-04-20.md
# optional: git add .planning/phases/32-cartographier/screenshots/
git commit -m "backlog: scan screen UX audit 2026-04-20 (6 doctrine violations)

P2 finding from Phase 32 E2E flow test. 5 design direction breaches +
1 accent regression + 1 P1 text clipping. Deferred to v2.9 or design
sprint per STAB-carryover convention."

# Follow-up (separate branch or PR): wire tier.py into coach_chat + token_budget + rag/llm_client
```

---

## Items explicitly recommended to LEAVE untracked

| Path | Reason |
|---|---|
| `.planning/live-testing/` (3 MB, 24 files) | Scratch workspace, consolidated outputs already tracked as ADRs/plans. Consider adding to `.gitignore` to silence status noise. |
| `apps/mobile/test/goldens/failures/*.png` (12 files, 0.1 MB) | Already gitignored; showing as modified only because stale copies predate the gitignore rule. Revert with `git checkout`. |
| `.planning/phases/32-cartographier/screenshots/` (2.6 MB) | Phase 32 shipped. Only commit if bundling with `scan-screen-ux-audit-2026-04-20.md` (cross-references). Otherwise keep local evidence. |

---

## Summary

**MUST commit before `/clear`:**
1. `tier.py` (+ follow-up wiring commit queued) — prevents $40 recurrence
2. 5 Phase 30.7 PLAN files — phase archive consistency
3. 6 ADRs — decision history
4. 3 ARB bindings — Phase 34-04 follow-up

**SHOULD commit before `/clear`:**
5. `PERSONA-WALK-JULIEN-2026-04-22.md` — MVP wedge artifact
6. `scan-screen-ux-audit-2026-04-20.md` — backlog

**CAN leave:**
- `live-testing/` (consider gitignore)
- Phase 32 screenshots (evidence-only)
- 3 `v2-*.png` MVP wedge screenshots (pending v2-01==v2-02 resolution)

**MUST revert:**
- 12 golden failure PNGs (stale, gitignored).

**Critical wiring NOT covered by commits:**
- `tier.py` module commit alone does nothing. Follow-up commit required to replace hardcoded `"claude-sonnet-4-5-20250929"` literals in `coach_chat.py:1050`, `token_budget.py:31`, `rag/llm_client.py:72` with `resolve_primary_model(...)` calls, AND to update the stale `20250929/20251001` defaults in `tier.py` itself to the `20251022` canonical IDs used elsewhere. Without this, MINT_LLM_TIER=mvp has zero effect on Railway.
