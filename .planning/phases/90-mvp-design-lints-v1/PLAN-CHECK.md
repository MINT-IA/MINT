---
name: MVP-DESIGN-LINTS-V1 — PLAN-CHECK
description: Goal-backward verification of PLAN.md. Verdict + concrete gaps + concrete fixes. The plan covers the 5-lint scope cleanly, with one MED risk on lefthook --file multi-arg compatibility and three MED gaps on false-positive measurement, baseline-vs-script chicken-and-egg ordering, and CI workflow trigger surface.
type: phase-plan-check
date: 2026-05-09
phase: MVP-DESIGN-LINTS-V1
status: FLAG
verifier: gsd-plan-checker (Opus 4.7 1M)
---

# PLAN-CHECK — MVP-DESIGN-LINTS-V1

## 1. Verdict

**FLAG (not BLOCK)** — proceed to execution after the planner addresses 3 plan amendments below. The plan is well-structured, scope-disciplined, and the 5-lint × 4-deliverable matrix is fully covered. Drift counts are independently verified (1551 BorderRadius vs. claimed 1545, 705 fontSize vs. claimed 705, 154 CTA vs. claimed 154, 100 GoogleFonts vs. claimed 100 — all within ±0.5%). The 5-gate exit contract is realistic with G1/G2 honestly degraded to G1'/G2' substitutes since the phase is pure tooling. Risks remaining are operational (lefthook `--file` multi-arg, false-positive measurement, baseline ordering), not strategic.

## 2. Goal-coverage matrix

5 lints × 4 deliverables = 20 cells. Deliverables per lint : (a) Python script, (b) baseline file, (c) unit tests, (d) lefthook+CI wiring.

| Lint | Script (`tools/checks/*.py`) | Baseline (`*.baseline.txt`) | Tests (`tools/checks/tests/test_*.py`) | Wiring (lefthook + CI) |
|---|---|---|---|---|
| LINT-01 prefer_mint_color_token | T3 | T10 | T2 fixtures + T3 tests | T8 + T9 |
| LINT-02 prefer_mint_text_style (fontSize) | T4 | T10 | T2 fixtures + T4 tests | T8 + T9 |
| LINT-03 prefer_mint_fonts (GoogleFonts/fontFamily) | T5 | T10 | T2 fixtures + T5 tests | T8 + T9 |
| LINT-04 prefer_mint_radius (BorderRadius allowlist) | T6 | T10 | T2 fixtures + T6 tests | T8 + T9 |
| LINT-05 prefer_mint_cta (raw button widgets) | T7 | T10 | T2 fixtures + T7 tests | T8 + T9 |

**All 20 cells filled.** Plus T1 (test helper), T11 (README), T12 (smoke integration) are cross-cutting deliverables. No gaps in the goal-coverage matrix.

The original spawn prompt's `prefer_mint_spacing` and `no_raw_chf_text` lints are explicitly deferred — that's correct per RESEARCH §Open Questions Q3 and §Out-of-scope. Not a coverage gap; an explicit, justified scope cut.

## 3. Risks identified

### R1 — Lefthook `--file {staged_files}` multi-arg compatibility (MED)

**Issue.** Plan T8 (lines 154-167) says lefthook will pass `{staged_files}` as space-separated, and that "lints accept `--file` repeated for multi-file commits (matches `accent_lint_fr.py:115` `--file` action)". But `accent_lint_fr.py:115` declares `ap.add_argument("--file", ...)` as a SINGLE-value arg (no `nargs`, no `action="append"`). The actual existing precedent for `{staged_files}` is `map_freshness_hint.py:37`, which uses `sys.argv[1:]` (positional list, no `--file`).

**Risk.** If T3-T7 author scripts follow the `accent_lint_fr.py` model verbatim, lefthook will pass `--file f1 f2 f3` and argparse will only consume `f1`, silently dropping `f2`, `f3`. Pre-commit will appear to pass while linting only the first staged file. Soft-warn behavior masks this until a real net-new violation slips through.

**Remediation.** Add to T3-T7 acceptance criteria : *"Each lint script's `--file` argument MUST be `action='append'` OR `nargs='+'`. Add a unit test asserting `lint.main(['--file', 'a.dart', '--file', 'b.dart'])` scans both."* And to T8 verification : *"Run `lefthook run pre-commit --files a.dart b.dart` and assert lint output references BOTH files (not just `a.dart`)."*

### R2 — Baseline chicken-and-egg ordering (MED)

**Issue.** Plan dependency graph says T10 (baselines) runs AFTER T3-T7 (scripts) but BEFORE T8 (lefthook wiring). However, T3-T7 verification steps (e.g., T3 line 88) say *"`--update-baseline` produces a baseline with 31 ± 5 entries"* — meaning each task's verification ALREADY runs `--update-baseline` and writes its baseline file. By the time T10 runs, baseline files already exist from T3-T7's verify steps. The intent (deferred commit of baselines as one chunk in C7) is sensible, but T10 effectively becomes a no-op ("re-generate the same files") OR a re-snapshot at a different commit (drift between T3 and T10 if any new violation lands in dev branch in between).

**Risk LOW.** The drift between T3 and T10 in a 2-day window is essentially zero (Phase 1 itself touches no `apps/mobile/lib/**/*.dart`). But the dependency graph is logically inconsistent — `verify` of T3 cannot succeed unless baseline file is present (lint exits 2 if missing per the skeleton in RESEARCH lines 577-579). This means T3 verify must call `--update-baseline` THEN call the lint to confirm exit 0. Then T10 just re-runs the same `--update-baseline`.

**Remediation.** Either : (a) Move baseline writing INTO T3-T7 verify steps explicitly (each task writes its OWN baseline as part of its acceptance) and demote T10 to a meta-task that only writes `.planning/audit/ui_drift_baseline_2026-05-09.txt` (the human-readable summary). OR (b) Restructure T3-T7 to use a tmpdir baseline during their unit tests, leaving the real `tools/checks/baselines/*.baseline.txt` empty until T10. Option (a) is simpler and matches the script skeleton in RESEARCH lines 564-597 which assumes the baseline exists when `main()` is called without `--update-baseline`.

### R3 — CI workflow trigger surface incomplete (MED)

**Issue.** Plan T9 (lines 174-178) restricts the `design-lints.yml` trigger to `paths:` `apps/mobile/lib/**/*.dart`, `tools/checks/prefer_mint_*.py`, `tools/checks/baselines/prefer_mint_*.baseline.txt`, `.github/workflows/design-lints.yml`. **Missing trigger : the lint scripts themselves are tested via `tools/checks/tests/test_*.py` files which a developer might modify to fix a false-positive without touching the script ; that PR will not run the design-lints workflow** (because none of the path filters match `tools/checks/tests/**`). Also missing : the workflow does not run on `tools/checks/README-DESIGN-LINTS.md` doc updates (low impact) and does not run on `tools/checks/tests/fixtures/**` updates (medium impact — fixture drift could mask test regression).

**Risk MED.** A PR that touches only `tools/checks/tests/test_prefer_mint_radius.py` to soften a test would NOT trigger the workflow that runs the actual lint, allowing the softened test to land without the lint ever re-running. This is a CI escape valve.

**Remediation.** T9 paths trigger expanded :
```yaml
paths:
  - 'apps/mobile/lib/**/*.dart'
  - 'tools/checks/prefer_mint_*.py'
  - 'tools/checks/baselines/prefer_mint_*.baseline.txt'
  - 'tools/checks/tests/test_prefer_mint_*.py'
  - 'tools/checks/tests/fixtures/**'
  - 'tools/checks/tests/_lint_test_helpers.py'
  - '.github/workflows/design-lints.yml'
```

Plus add a step at end of the workflow : `python3 -m unittest discover tools/checks/tests -p 'test_prefer_mint_*.py'` so test regressions fail CI on the same workflow that fails lint regressions. Currently T9 only runs the lint scripts, not their tests — the unit-test-suite green is only verified by T12 smoke locally, never in CI.

### R4 — False-positive rate is unmeasured (MED)

**Issue.** RESEARCH §Assumption A2 ("< 5% FP rate") is openly a guess. The plan acknowledges this in §Counter-arguments and data gaps line 371 ("No measurement of false-positive rate"). T3-T7 fixtures are synthetic (3 files per lint) and won't surface real-world FPs.

**Risk MED.** If LINT-04 BorderRadius hits even 5% FPs across 1551 sites, that's 78 spurious entries in the baseline. Devs see `// lint-ignore: prefer_mint_radius` proliferating, lint loses signal, eventually deactivated.

**Remediation.** Add a non-blocking T13 task (15 min, parallel-safe with T12) :
```
T13 — Empirical FP scan. Run each of the 5 lints with --update-baseline; manually
review 20 random entries from each baseline (100 total samples); document FP/TP
classification in .planning/audit/ui_drift_baseline_2026-05-09.txt #FP-AUDIT section.
If any lint > 10% FP rate, mark that lint baseline-only-no-allowlist (LINT-04) or
revisit the regex (LINT-01..03). Acceptance: documented FP rate per lint, decision
record in audit file.
```

This is the most forensically valuable addition and costs <30 min. It's mentioned in §Counter-arguments as an empirical gap but not promoted to a task — it should be.

### R5 — Lefthook latency budget is not empirically validated (LOW)

**Issue.** Plan T8 verify says `time lefthook run pre-commit --files <single-file>` ≤ 1.5 s. RESEARCH §Pitfall 3 sets 1.5s as the budget. Plan §Risks line 392 notes "5 × 80 ms + scan time ≈ 600 ms target".

**Risk LOW.** Plausible but unverified. If exceeded, plan §Risks proposes folding into a single dispatcher script.

**Remediation (optional).** Add to T8 verify : *"Also run on a 5-file commit (`lefthook run pre-commit --files a.dart b.dart c.dart d.dart e.dart`); MUST be ≤ 3 s. If exceeded, fold all 5 lints into `tools/checks/design_lints_dispatcher.py` and call once."* Already in plan §Risks but not in task verify — promote.

### R6 — Existing `--file` precedent is single-value but plan claims multi (LOW, overlap with R1)

Already covered by R1 remediation. Mentioned for completeness.

### R7 — `// lint-ignore` discipline drift (LOW)

RESEARCH §Pitfall 4 + plan §Counter-arguments both acknowledge that devs may abuse `// lint-ignore: <rule>`. Plan defers this to a quarterly grep audit (RESEARCH §Security Domain table). Acceptable for Phase 1.

## 4. Suggestions for the plan

### Additions (non-blocking, but raise quality)

1. **Promote T13 (empirical FP scan) from §Counter-arguments aside to a real task.** 15-30 min, parallel-safe, single deterministic deliverable in `.planning/audit/ui_drift_baseline_2026-05-09.txt #FP-AUDIT`. (R4)

2. **In T8 verify, add the multi-file lefthook test.** R1 mitigation : `lefthook run pre-commit --files a.dart b.dart` with assertion that BOTH files appear in lint output. (R1)

3. **In T9, expand the workflow `paths:` trigger AND add a unit-test execution step at end of workflow.** R3 mitigation. (R3)

### Clarifications

1. **T10 ordering vs. T3-T7 verify** — clarify whether each lint task writes its own baseline (option (a) in R2 remediation) or whether T3-T7 use tmpdir baselines (option (b)). Plan currently mixes both implicitly — T3 verify says `--update-baseline` writes the file, T10 says it does too. Pick one and document. (R2)

2. **`--file` arg shape across all 5 scripts** — explicit acceptance criterion that each lint MUST use `--file` with `action='append'`. Not just "T3-T7 author following the skeleton" — the skeleton in RESEARCH lines 564-597 actually uses `action="append"` (line 565) but the plan's T3-T7 `action:` blocks don't restate this. (R1)

### Re-orderings

None required. Wave structure is correct (Wave 0 helpers/fixtures → Wave 1 RED→GREEN per lint in parallel → Wave 2 wiring → Wave 3 smoke). Dependency graph at line 287 is consistent with that.

## 5. Activation recommendation

**Proceed to gsd-executor AFTER planner amends 3 items :**
1. T8 multi-file lefthook acceptance test (R1).
2. T9 workflow `paths:` expansion + unit-test step at workflow end (R3).
3. T10 vs. T3-T7 baseline-write ownership clarification (R2).

These are 10-minute plan edits, not a re-spec. The 5-lint scope, drift counts, baseline-snapshot pattern, hard-CI/soft-lefthook split, 5-gate degradation to G1'/G2' for tooling-only phase — all are sound. The risks identified are operational refinements, not strategic gaps.

T13 (empirical FP scan) is a STRONG suggestion but technically non-blocking — phase can ship without it and the FP rate becomes visible in the first sweep PR. Promoting T13 is the difference between "shipped on hope" and "shipped with a deterministic FP receipt".

If planner declines T13, that is acceptable provided VERIFICATION.md at phase close documents the first-week FP rate empirically (i.e., G3 evidence collection includes "first 3 PRs that touched .dart files post-merge → count of `// lint-ignore` additions and `--update-baseline` invocations").

**No BLOCK conditions present.** The plan is goal-achieving as written ; the FLAG is for refinement quality, not goal failure.

---

## Verification audit trail

- Drift count BorderRadius : claimed 1545, actual `grep -rEn "BorderRadius\.circular\(" apps/mobile/lib --include="*.dart" | grep -v "/lib/theme/" | wc -l` = **1551**. Within ±0.4%. ✓
- Drift count fontSize : claimed 705, actual = **705**. Exact. ✓
- Drift count CTA buttons : claimed 154, actual = **154**. Exact. ✓
- Drift count GoogleFonts : claimed 100, actual = **100**. Exact. ✓
- `MintRadius` token absence : `ls apps/mobile/lib/theme/` returns colors.dart, mint_motion.dart, mint_spacing.dart, mint_text_styles.dart, wcag_helper.dart. **No mint_radius.dart.** ✓ (matches RESEARCH §A5 verification)
- `MintCTA` widget absence : RESEARCH §A6 verified. (Not re-verified in this check — relying on RESEARCH evidence.)
- `accent_lint_fr.py` `--file` arg : declared at line 115 as **single-value** (`ap.add_argument("--file", help="...")` with no `nargs` or `action="append"`). Plan T8 misreads this precedent — basis of R1.
- `map_freshness_hint.py` staged_files handling : line 37 uses `sys.argv[1:]` (positional list). This is the actual `{staged_files}` precedent. T8 should reference this, not `accent_lint_fr.py`.
- Existing CI workflows : `ci.yml`, `deploy-backend.yml`, `golden-document-flow.yml`, `play-store.yml`, `sync-branches.yml`, `testflight.yml`, `walker_nightly.yml`, `web.yml`. T9's choice to author a NEW `design-lints.yml` rather than extend `ci.yml` is consistent with the established split-by-concern pattern.
- Existing `tools/checks/` script count : 22 Python scripts present. Plan claim of "11 production lints" undercounts but doesn't invalidate the precedent argument.
- Lefthook current commands : `memory-retention-gate`, `map-freshness-hint`, `wiki-lint`. T8's "preserve existing 3 commands" is correct.

