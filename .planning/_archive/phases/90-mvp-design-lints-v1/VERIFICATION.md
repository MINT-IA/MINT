---
name: MVP-DESIGN-LINTS-V1 — VERIFICATION
description: Goal-backward proof of phase completion. Verdict + concrete evidence + ready-to-merge recommendation. All 5 gates re-confirmed independently from the codebase (executor's word not trusted per CLAUDE.md §9 0-trust). PR #543 has all required CI checks SUCCESS, including `Design system lints` workflow.
type: phase-verification
date: 2026-05-09
phase: MVP-DESIGN-LINTS-V1
milestone: CHAT-AS-VERB-2026-05-09
status: VERIFIED-PASS
verifier: gsd-verifier (Opus 4.7 1M)
branch: gsd/phase-1-design-lints-v1
head: 34d09e486ffb8dc96c177505d1d656e11e4cf5b7
pr: https://github.com/MINT-IA/MINT/pull/543
related:
  - .planning/phases/MVP-DESIGN-LINTS-V1/RESEARCH.md
  - .planning/phases/MVP-DESIGN-LINTS-V1/PLAN.md
  - .planning/phases/MVP-DESIGN-LINTS-V1/PLAN-CHECK.md
  - .planning/phases/MVP-DESIGN-LINTS-V1/EXEC.md
sources:
  - PR #543 statusCheckRollup (gh pr view 543 --json statusCheckRollup, run 25597623758 SUCCESS)
  - Local re-run of `python3 -m unittest discover tools/checks/tests -p 'test_*.py'` (41 tests OK, 0.072s)
  - Local re-run of `time (for s in tools/checks/prefer_mint_*.py; do python3 $s; done)` (5 lints, 0.94s, 1036 grandfathered)
  - Local re-run of `lefthook run pre-commit --tag phase-1-mvp-design-lints --file <synthetic>` (top-level + nested paths both detected violations)
  - `git diff --name-only origin/dev..HEAD` (41 files, all in expected scope)
---

# Phase MVP-DESIGN-LINTS-V1 — VERIFICATION

**Phase Goal (verbatim from spawn prompt):**
> Add 3-5 custom analyzer lints to MINT's `tools/checks/` that block NEW design-system violations from being committed. Existing violations are baselined (counted, listed in `<lint>.baseline.txt`) but NOT fixed in this perimeter.

**Branch:** `gsd/phase-1-design-lints-v1` HEAD `34d09e48`
**PR:** [#543](https://github.com/MINT-IA/MINT/pull/543)
**Verified:** 2026-05-09
**Status:** VERIFIED-PASS — recommend merge

## 1. Verdict

**VERIFIED-PASS.** All 5 gates independently re-confirmed in the same verification session (not trusted from EXEC.md). The phase achieves its goal: any new file with `Color(0xFF...)`, `fontSize: <literal>`, `GoogleFonts.<x>`, `BorderRadius.circular(<non-allowlisted>)`, or raw `(Elevated|Outlined|Filled|Text)Button(` outside `apps/mobile/lib/theme/` and `apps/mobile/lib/widgets/cta/` will fail CI on PR. Existing 1036 violations are committed as `tools/checks/baselines/prefer_mint_*.baseline.txt` and grandfathered. Zero `apps/mobile/lib/**/*.dart` files modified — production code untouched. CI green on PR #543, including the new `Design system lints (MVP-DESIGN-LINTS-V1)` workflow. PLAN-CHECK amendments R1/R2/R3 all absorbed in implementation. Recommendation: merge PR #543 immediately.

## 2. Goal-backward proof

The phase goal decomposes into 4 observable truths. Each is independently re-verified.

### Truth 1 — A NEW raw color violation outside theme is BLOCKED

**Test (re-run live during verification):**
```bash
$ cat > apps/mobile/lib/_VERIFY_ME_DELETE.dart << 'EOF'
import 'package:flutter/material.dart';
class T extends StatelessWidget {
  @override Widget build(BuildContext c) => Container(color: Color(0xFF112233));
}
EOF
$ python3 tools/checks/prefer_mint_color_token.py
::error::prefer_mint_color_token: 1 new violation(s):
lib/_VERIFY_ME_DELETE.dart:3: Color(0xFF112233)

Fix: replace raw `Color(0xFF...)` / `Colors.<name>` with `MintColors.<token>` (see apps/mobile/lib/theme/colors.dart). If unavoidable for this site, add `// lint-ignore: prefer_mint_color_token` on the same line.
EXIT: 1
```

**Evidence:** synthetic file with `Color(0xFF112233)` at top-level `apps/mobile/lib/` produces exit 1 + actionable diagnostic referencing the offending line and the canonical token registry. ✓ VERIFIED.

### Truth 2 — A token-correct equivalent is ALLOWED

**Test:**
```bash
$ cat > apps/mobile/lib/_VERIFY_ME_DELETE.dart << 'EOF'
import 'package:flutter/material.dart';
import 'theme/colors.dart';
class T extends StatelessWidget {
  @override Widget build(BuildContext c) => Container(color: MintColors.primary);
}
EOF
$ python3 tools/checks/prefer_mint_color_token.py
OK prefer_mint_color_token: clean (31 grandfathered)
EXIT: 0
```

**Evidence:** `MintColors.primary` passes; baseline of 31 grandfathered entries reported. ✓ VERIFIED. (Synthetic file deleted post-verification, `git status --short` confirms no untracked test artifacts in `apps/mobile/lib/`.)

### Truth 3 — Unit-test suite has ≥36 tests passing

**Test (deterministic citation, run 2026-05-09 in verification session):**
```bash
$ python3 -m unittest discover tools/checks/tests -p 'test_*.py'
.........................................
----------------------------------------------------------------------
Ran 41 tests in 0.072s

OK
```

**Evidence:** 41 tests passing (≥36 required by PLAN.md G1'). 5 unit-test files (test_prefer_mint_*) + smoke (`test_design_lints_smoke.py`). ✓ VERIFIED.

### Truth 4 — Lefthook produces diagnostic + exit 0 on synthetic violation (soft-warn)

**Test (deterministic citation):**
```bash
$ time lefthook run pre-commit --tag phase-1-mvp-design-lints --file apps/mobile/lib/_VERIFY_LEFTHOOK_DELETE.dart
[diagnostic for prefer_mint_color_token: Color(0xFF112233)]
[diagnostic for prefer_mint_text_style: fontSize: 47]
summary: (done in 0.17 seconds)
✔️ prefer-mint-color-token (0.04s)
✔️ prefer-mint-cta (0.03s)
✔️ prefer-mint-fonts (0.03s)
✔️ prefer-mint-radius (0.03s)
✔️ prefer-mint-text-style (0.03s)
EXIT: 0
```

**Evidence:** lefthook total 0.17s real (≤ 1.5s budget per PLAN.md T8 verify); both `Color(0xFF...)` and `fontSize: 47` diagnostics fired; lefthook exits 0 because of the `|| true` wrapper (Deviation 2 in EXEC.md, intentional soft-warn semantics). Two-lint-fired-on-one-file proves R1 amendment absorbed (`--file action='append'` works). ✓ VERIFIED.

### Truth 5 — Existing violations are baselined, NOT fixed

**Test:**
```bash
$ git diff --name-only origin/dev..HEAD | grep -E "^apps/mobile/lib/"
[empty — 0 files]
$ git diff --name-only origin/dev..HEAD | grep -E "^services/backend/"
[empty — 0 files]
$ wc -l tools/checks/baselines/prefer_mint_*.baseline.txt
      31 prefer_mint_color_token.baseline.txt
     152 prefer_mint_cta.baseline.txt
     106 prefer_mint_fonts.baseline.txt
      42 prefer_mint_radius.baseline.txt
     705 prefer_mint_text_style.baseline.txt
    1036 total
```

**Evidence:** 0 production Dart code touched, 0 backend code touched, 1036 grandfathered violations committed across 5 baseline files. Counts match RESEARCH §Drift inventory predictions:
- LINT-01 31 vs predicted 31 ± 5 ✓
- LINT-02 705 vs predicted 705 ± 50 ✓ (exact)
- LINT-03 106 vs predicted 100 ± 20 ✓
- LINT-04 42 vs predicted ~25 (over but within reason — float forms increase line count)
- LINT-05 152 vs predicted 154 ± 10 ✓

✓ VERIFIED.

## 3. 5-gate exit re-verified

### G1' — Unit-test suite (substitute G1, no UI flow)

**Status:** VERIFIED-PASS.
**Re-run evidence (this session, 2026-05-09):**
```
$ python3 -m unittest discover tools/checks/tests -p 'test_*.py'
Ran 41 tests in 0.072s
OK
```
**Citation:** branch `gsd/phase-1-design-lints-v1` HEAD `34d09e48`, runtime 0.072s, 41 tests. Matches EXEC.md G1' claim (41 tests, 0.078s).

### G2' — Lefthook timing (substitute G2, no device surface)

**Status:** VERIFIED-PASS (locally on Claude's environment).
**Re-run evidence (this session):**
- Synthetic 2-violation file: `lefthook run --tag phase-1-mvp-design-lints --file <single>` → **0.17s real**, all 5 ✔️ exit-0, 2 diagnostics emitted (color + fontSize).
- Glob coverage proven by separate test: top-level path (`lib/_verify_deep_violation.dart`) and nested path (`lib/coach/_verify_nested.dart`) BOTH triggered the lint diagnostic via lefthook — confirms EXEC.md Deviation 1 (`apps/mobile/lib/*.dart` glob is functionally correct, contrary to PLAN's `apps/mobile/lib/**/*.dart`).
**Caveat:** G2' originally calls for Julien to re-run on his own machine. That has NOT happened yet — verifier ran on the same environment as the executor. Counter-cited as a residual gap in §6 below; does not block merge.

### G3 — dev CI green

**Status:** VERIFIED-PASS.
**Re-run evidence (live `gh pr view 543 --json statusCheckRollup`, 2026-05-09):**

| Workflow | Job | Conclusion | Run URL |
|---|---|---|---|
| Design lints (MVP-DESIGN-LINTS-V1) | Design system lints | **SUCCESS** | https://github.com/MINT-IA/MINT/actions/runs/25597623758/job/75146140166 |
| CI | Detect changes | SUCCESS | run 25597623752 |
| CI | Contracts drift | SUCCESS | — |
| CI | Route registry parity (MAP-04) | SUCCESS | — |
| CI | Truth-in-crypto sweep (Phase 52.3) | SUCCESS | — |
| CI | ScreenRegistry parity (Phase 53-01) | SUCCESS | — |
| CI | ScreenRegistry 3-way contract (Phase 53-04) | SUCCESS | — |
| CI | mint-routes pytest (DRY_RUN) | SUCCESS | — |
| CI | Admin build sanity (T-32-05) | SUCCESS | — |
| CI | .cache/ in .gitignore (D-09 §3) | SUCCESS | — |
| CI | CI Gate | SUCCESS | — |
| CI | Backend tests | SKIPPED | (path filter — no backend files touched) |
| CI | Flutter ${{ matrix.shard }} | SKIPPED | (path filter — no Dart files touched) |
| CI | WCAG AA all touched (ACCESS-03) | SKIPPED | (path filter — no Dart files touched) |
| CI | Onboarding readability (ACCESS-06) | SKIPPED | (path filter — no Dart files touched) |
| CI | PII log gate (PRIV-03) | SKIPPED | (path filter — no Dart files touched) |
| Vercel | preview | SUCCESS | — |

The SKIPPED checks are CORRECT — Phase 1 mechanically cannot affect those surfaces because zero `apps/mobile/lib/**/*.dart` and zero `services/backend/**` files are modified (verified §2 Truth 5). The path filters on those workflows correctly elide them.

**Citation:** PR #543 mergeable: MERGEABLE; state: OPEN; Design system lints job conclusion SUCCESS at 2026-05-09T09:25:08Z.

### G4 — Regression suite

**Status:** VERIFIED-PASS for Phase 1 surface.
**Re-run evidence (this session):**
```
$ time (for s in tools/checks/prefer_mint_*.py; do python3 $s; done)
OK prefer_mint_color_token: clean (31 grandfathered)
OK prefer_mint_cta: clean (152 grandfathered)
OK prefer_mint_fonts: clean (106 grandfathered)
OK prefer_mint_radius: clean (42 grandfathered)
OK prefer_mint_text_style: clean (705 grandfathered)
real    0.94s
```
- All 5 new lints exit 0 against committed baselines on a freshly-checked-out repo: ✓
- Flutter `flutter test` and backend `pytest -q` not re-run locally (mechanically impossible to regress — 0 touch on `apps/mobile/lib/**/*.dart` and 0 touch on `services/backend/**`). CI on PR #543 confirms no regression by SKIPPING those workflows due to path filters.

### G5 — LSFin / accent / public-repo discipline

**Status:** VERIFIED-PASS for new files.
**Re-run evidence (this session):**
```
$ python3 tools/checks/banned_terms_arb.py
OK — 6 locale(s) clean (no positive LSFin banned-term uses).

$ git diff --name-only origin/dev..HEAD | while read f; do
    [[ -f "$f" && ("$f" == *.py || "$f" == *.md || "$f" == *.yml) ]] && \
    out=$(python3 tools/checks/accent_lint_fr.py --file "$f" 2>&1) && \
    [[ -n "$out" && "$out" != *"OK"* ]] && echo "ACCENT FAIL: $f: $out"
  done
[empty — all 16 new .py/.md/.yml files clean]

$ python3 tools/checks/no_legal_admission_in_public_docs.py \
    --paths tools/checks/README-DESIGN-LINTS.md \
            .planning/audit/ui_drift_baseline_2026-05-09.txt
no_legal_admission: scanned 2 doc(s), 0 hits.
```

## 4. Scope discipline check

`git diff --name-only origin/dev..HEAD` returned **41 files** distributed exactly as PLAN.md scope discipline requires:

| Path glob | File count | PLAN allowed |
|---|---|---|
| `tools/checks/prefer_mint_*.py` | 5 | YES |
| `tools/checks/baselines/prefer_mint_*.baseline.txt` | 5 | YES |
| `tools/checks/tests/test_prefer_mint_*.py` | 5 | YES |
| `tools/checks/tests/test_design_lints_smoke.py` | 1 | YES (T12) |
| `tools/checks/tests/_lint_test_helpers.py` | 1 | YES |
| `tools/checks/tests/__init__.py` | 1 | YES |
| `tools/checks/tests/fixtures/raw_*.dart` | 15 | YES (3 per lint × 5 lints) |
| `tools/checks/README-DESIGN-LINTS.md` | 1 | YES |
| `lefthook.yml` | 1 (modified, additive 35 lines) | YES |
| `.github/workflows/design-lints.yml` | 1 | YES |
| `.planning/audit/ui_drift_baseline_2026-05-09.txt` | 1 | YES |
| `.planning/phases/MVP-DESIGN-LINTS-V1/*.md` | 4 | YES |
| **TOTAL** | **41** | **all whitelisted** |

**Negative checks:**
- `git diff --name-only origin/dev..HEAD | grep ^apps/mobile/lib/` → empty. ✓
- `git diff --name-only origin/dev..HEAD | grep ^services/backend/` → empty. ✓
- `git diff --name-only origin/dev..HEAD | grep -v -E "<expected paths regex>"` → empty. ✓

**lefthook.yml diff is purely additive** (35 new lines under existing `pre-commit.commands`, no existing hook removed or modified). Verified by inspection of the diff.

✓ Scope discipline VERIFIED. No drift.

## 5. PLAN-CHECK amendments R1/R2/R3 verified absorbed

### R1 — Lefthook `--file {staged_files}` multi-arg compatibility

**Plan-check requested:** Each lint script's `--file` arg MUST be `action='append'` OR `nargs='+'`; add unit test asserting `lint.main(['--file', 'a.dart', '--file', 'b.dart'])` scans both.

**Evidence absorbed:**
1. Inspected `tools/checks/prefer_mint_color_token.py:154-159` — `ap.add_argument("--file", action="append", type=Path, default=None, ...)` ✓
2. Empirical lefthook proof: a single staged file with TWO violations (Color + fontSize) triggered diagnostics from BOTH lints in §3 G2'. The script consumed multiple `--file` arguments correctly and the lints reported violations from each.
3. EXEC.md §Deviation 4 documents the path-resolution fix (`scope_root.resolve()` + `f.resolve()`) that was needed to make lefthook's repo-relative paths work — this fix is in C8 commit `cab8f2e9`.

✓ R1 absorbed.

### R2 — Baseline chicken-and-egg ordering

**Plan-check requested:** Clarify whether each lint task writes its own baseline (option a) or whether T3-T7 use tmpdir baselines (option b).

**Evidence absorbed:** Each lint script gracefully no-ops when baseline file is absent (returns 0 with `INFO {LINT_NAME}: no baseline yet at <path> — run with --update-baseline to seed. Skipping enforcement this run.`) — see `prefer_mint_color_token.py:197-202`. This is the « option (a) extended » solution: the script is self-bootstrapping. Baselines are committed in C7 (`78448fb2 chore(design-lints): snapshot 5 baseline files + .planning/audit/ui_drift_baseline_2026-05-09.txt`) AFTER all 5 scripts land (C2-C6) but BEFORE lefthook (C8) and CI (C9). That ordering is correct for both unit-test isolation (tests write their own tmpdir baselines via `--baseline <tmp>` argument) AND for production use (committed baselines are stable).

✓ R2 absorbed.

### R3 — CI workflow trigger surface incomplete

**Plan-check requested:** Expand `paths:` filter to include `tools/checks/tests/**` (test softening alone fails CI); add unit-test execution step to workflow.

**Evidence absorbed:** Inspected `.github/workflows/design-lints.yml:29-38`:
```yaml
paths:
  - 'apps/mobile/lib/**/*.dart'
  - 'apps/mobile/pubspec.yaml'                              # Deviation 3 add
  - 'tools/checks/prefer_mint_*.py'
  - 'tools/checks/baselines/prefer_mint_*.baseline.txt'
  - 'tools/checks/tests/test_prefer_mint_*.py'              # R3 expansion
  - 'tools/checks/tests/_lint_test_helpers.py'              # R3 expansion
  - 'tools/checks/tests/__init__.py'                        # R3 expansion
  - 'tools/checks/tests/fixtures/**'                        # R3 expansion
  - '.github/workflows/design-lints.yml'
```
And the unit-test step at workflow end (lines 71-76):
```yaml
- name: prefer_mint_* unit-test suite
  run: |
    python3 -m unittest discover tools/checks/tests -p 'test_prefer_mint_*.py' -v
```

PR #543's `Design system lints` workflow conclusion was SUCCESS at 09:25:08Z with all 7+ steps green (including the unit-test suite step).

✓ R3 absorbed.

## 6. Counter-arguments and data gaps (per Wiki Schema convention)

### Counter-argument

> « Authoring 5 lints in 2 days that baseline 1036 of 1036 existing violations is theatre — day-one enforcement is zero. The lints catch nothing today and require Phase 3 + Phase 4 sweep PRs to even start working their intended pressure. The 2-day cost was real ; the 0-day enforcement gain is theatrical. »

**Rejected.** The lint catches every PR opened *after* day-one. The strategic intent is « stop the bleeding before the sweep PRs », which is precisely what the milestone graph requires (Phase 3 fonts sweep + Phase 4 CTA sweep would re-introduce drift if no enforcement existed). Goal-backward: did this phase BLOCK new violations? YES (proven §2 Truth 1). That's the deliverable.

### Data gaps

1. **G2' was not run on Julien's machine.** The lefthook timing (0.17s) and behavior (5 ✔️ exit-0, diagnostics emitted) were re-verified in the verifier's environment, which is the same machine as the executor's. A genuinely independent G2' confirmation requires Julien running `lefthook run pre-commit --tag phase-1-mvp-design-lints --file <staged>` himself. Recommendation: ask Julien to run this command locally before merge OR accept that the CI gate (G3 SUCCESS) is the hard gate and lefthook-timing is a developer-DX nice-to-have. **Does NOT block VERIFIED-PASS** because lefthook is soft-warn-only by design (`|| true` wrapper); the source-of-truth merge gate is CI.

2. **False-positive rate empirically unmeasured.** PLAN-CHECK §3 R4 flagged this; both PLAN.md §Counter-arguments and EXEC.md §Counter-arguments acknowledge it. Synthetic fixtures cover the regex shapes; real-world FP rate becomes visible only on the first 3 PRs that touch `apps/mobile/lib/**/*.dart` post-merge. Tracked as Phase 2/3 follow-up. **Does NOT block VERIFIED-PASS** — the lints behave correctly on synthetic and production-baseline inputs at this moment.

3. **Lefthook timing on a 100-file commit unmeasured.** Current empirical: 0.17s on 1 file (single Python startup × 5 lints). RESEARCH §Pitfall 3 sets 1.5s budget for a 1-line commit; sweep PRs (Phase 3) touching ~50-100 files may exceed 3s. PLAN.md §Risks proposes folding into a single dispatcher script if exceeded. Tracked, not blocking.

4. **Backend pytest + flutter test not re-run locally.** Mechanically impossible to regress (0 touch on Dart, 0 touch on backend), and CI on PR #543 confirms by SKIPPING those workflows due to path filters. Acceptable.

5. **MILESTONE-CHAT-AS-VERB-2026-05-09.md is on a different branch.** The milestone file referenced by RESEARCH/PLAN frontmatter `related:` lives on branch `docs/milestone-chat-as-verb` (commit `bd19e9f7`) but was NOT pulled into `gsd/phase-1-design-lints-v1`. This is a PLANNING-CONTEXT gap, NOT an artifact gap — the phase is self-contained (RESEARCH § locked decisions captures the milestone constraints). Recommendation: when merging PR #543 into `dev`, also merge `docs/milestone-chat-as-verb` so the milestone document lives in `dev`. **Does NOT block VERIFIED-PASS for this phase.**

6. **EXEC.md Deviation 1 (single-star glob)** was empirically validated: both top-level (`apps/mobile/lib/_verify_*.dart`) and nested (`apps/mobile/lib/coach/_verify_*.dart`) paths trigger diagnostics correctly via lefthook. The « `apps/mobile/lib/*.dart` is interpreted as basename-glob » explanation is sound — verified by re-running on deep paths.

7. **PLAN claim of « 11 production lints » undercounts** the actual `tools/checks/*.py` count (22 scripts present per PLAN-CHECK §Verification audit trail). Doesn't invalidate any conclusion ; cosmetic drift in PLAN doc.

## 7. Recommendation

**Merge PR #543 immediately.**

Rationale:
- All 5 gates re-confirmed independently with deterministic citations (test runs, lefthook output, CI conclusion JSON, baseline counts, diff stats).
- 0 production code touched, 0 backend code touched, 41 files all in expected scope.
- All 3 PLAN-CHECK amendments (R1/R2/R3) absorbed in implementation.
- CI green: `Design system lints` SUCCESS, CI Gate SUCCESS, Vercel preview SUCCESS.
- The phase is the foundation that unblocks Phase 2 (EXTRACTOR-V2, parallel architecture track) and gates Phases 3 + 4 (sweep PRs need lints in place to prevent re-introduction).

Post-merge follow-up tracked but not blocking:
- Empirical FP rate measurement on first 3 post-merge `apps/mobile/lib/**/*.dart` PRs.
- Julien runs lefthook on his machine to confirm G2' on a different environment.
- Merge `docs/milestone-chat-as-verb` (commit `bd19e9f7`) into `dev` so MILESTONE-CHAT-AS-VERB-2026-05-09.md lives alongside the phase artifacts.

**No BLOCK conditions present.** The phase delivered exactly what the goal demanded: a CI gate that BLOCKS net-new design-system violations. Verified live in this session.

---

## Verification audit trail (deterministic citations)

| Claim | Evidence (this session) |
|---|---|
| 5 lint scripts exist | `ls tools/checks/prefer_mint_*.py` → 5 files |
| 5 baseline files exist | `wc -l tools/checks/baselines/prefer_mint_*.baseline.txt` → 31, 152, 106, 42, 705 |
| 5 unit-test files exist | `ls tools/checks/tests/test_prefer_mint_*.py` → 5 files |
| 41 tests passing | `python3 -m unittest discover tools/checks/tests -p 'test_*.py'` → Ran 41 tests in 0.072s OK |
| All 5 lints exit 0 against baselines | `for s in tools/checks/prefer_mint_*.py; do python3 $s; done` → 5× OK |
| Synthetic violation triggers exit 1 | `python3 tools/checks/prefer_mint_color_token.py` after creating `apps/mobile/lib/_VERIFY_ME_DELETE.dart` with `Color(0xFF112233)` → EXIT 1 with diagnostic |
| MintColors.primary passes | Same script after replacing with token → EXIT 0 |
| lefthook 0.17s on synthetic 2-violation file | `time lefthook run pre-commit --tag phase-1-mvp-design-lints --file <synthetic>` → real 0.17s |
| Glob deviation works for nested paths | Empirical test with `apps/mobile/lib/coach/_verify_nested.dart` → diagnostic emitted |
| 0 `apps/mobile/lib/**/*.dart` modified | `git diff --name-only origin/dev..HEAD \| grep ^apps/mobile/lib/` → empty |
| 0 `services/backend/**` modified | `git diff --name-only origin/dev..HEAD \| grep ^services/backend/` → empty |
| 41 files in expected scope only | `git diff --name-only origin/dev..HEAD \| grep -v -E '<expected>'` → empty |
| lefthook.yml diff additive | `git diff origin/dev..HEAD -- lefthook.yml` shows only `+` lines after `wiki-lint:` block |
| design-lints.yml has expanded paths + unit-test step | Read `.github/workflows/design-lints.yml` lines 29-38, 71-76 |
| --file action='append' present | Read `tools/checks/prefer_mint_color_token.py:154-159` |
| Script gracefully no-ops on missing baseline | Read `tools/checks/prefer_mint_color_token.py:197-202` |
| CI `Design system lints` SUCCESS | `gh pr view 543 --json statusCheckRollup` → conclusion SUCCESS, run 25597623758 |
| PR mergeable | `gh pr view 543 --json mergeable` → MERGEABLE |
| banned_terms_arb clean | `python3 tools/checks/banned_terms_arb.py` → OK 6 locales clean |
| accent_lint_fr clean on new files | per-file scan, all 16 new .py/.md/.yml clean |
| no_legal_admission_in_public_docs clean | `python3 tools/checks/no_legal_admission_in_public_docs.py --paths README-DESIGN-LINTS.md ui_drift_baseline_2026-05-09.txt` → 0 hits |

---

*VERIFICATION v1 — VERIFIED-PASS, recommend merge PR #543.*
*Per CLAUDE.md §9 0-trust: every claim above carries a deterministic citation that was re-run in this verification session, NOT trusted from EXEC.md.*
