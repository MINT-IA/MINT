---
name: MVP-DESIGN-LINTS-V1 — PLAN
description: Plan to ship 5 design-system lint scripts + baselines + lefthook + CI in 2 days, blocking new violations without forcing existing-codebase sweep.
type: phase-plan
date: 2026-05-09
phase: MVP-DESIGN-LINTS-V1
milestone: CHAT-AS-VERB-2026-05-09
status: PROPOSED
related:
  - .planning/MILESTONE-CHAT-AS-VERB-2026-05-09.md
  - .planning/phases/MVP-DESIGN-LINTS-V1/RESEARCH.md
sources:
  - .planning/phases/MVP-DESIGN-LINTS-V1/RESEARCH.md (886 lines, 5-lint scope, baseline pattern, hard-CI/soft-lefthook split)
  - tools/checks/wcag_aa_all_touched.py (closest precedent — Python regex over apps/mobile/lib)
  - tools/checks/accent_lint_fr.py (closest precedent — --file lefthook flag, EXCLUDE_SUBSTRINGS)
  - tools/checks/test_banned_terms_arb.py (closest precedent — pure-stdlib unittest)
  - lefthook.yml (insertion point: pre-commit.commands)
  - .github/workflows/ci.yml (insertion point: new top-level job sibling of `wcag-aa-all-touched`)
---

# Phase 1 — MVP-DESIGN-LINTS-V1 — PLAN

## Goal recap

> Ship **5 Python lint scripts** under `tools/checks/` that BLOCK net-new design-system violations (raw colors, fontSize, fontFamily/GoogleFonts, BorderRadius outside allowlist, raw CTA buttons) at CI-time. Existing violations are baselined as `path:line` snapshots — NOT fixed in this phase. Wire lefthook (soft warn on staged files) + a new `design-lints` CI job (hard fail on net-new). 2-day budget. Tooling-only ; zero `apps/mobile/lib/**/*.dart` modifications.

## Scope discipline (Karpathy #2 / #3)

- Touch ONLY : `tools/checks/*.py`, `tools/checks/baselines/*.txt`, `tools/checks/tests/*.py`, `tools/checks/fixtures/`, `tools/checks/README-DESIGN-LINTS.md`, `lefthook.yml`, `.github/workflows/design-lints.yml`, `.planning/audit/ui_drift_baseline_2026-05-09.txt`.
- DO NOT touch any `apps/mobile/lib/**/*.dart` file. Drift fixes are deferred to Phases 3 + 4.
- DO NOT add a `MintRadius` token (deferred to Phase 4 per RESEARCH §Open Q1).
- DO NOT add a `MintCTA` widget (deferred to Phase 4 per RESEARCH §Open Q2).
- DO NOT lint `EdgeInsets`, `SizedBox`, `Duration`, `Text('...CHF...')` (deferred per RESEARCH §Out-of-scope drift).

## Cross-cutting concerns

| Concern | Answer |
|---|---|
| New ARB keys ? | No — tooling only, zero user-facing strings. |
| Production code path touched ? | No — `tools/checks/` + CI workflow only. |
| Blocks future phase ? | YES — Phase 3 (FONTS-TOKENS-V2) + Phase 4 (CTA-UNIFICATION) must NOT land before this phase, or the sweep PRs re-introduce drift. |
| ARB parity / banned-terms / accent lint impacted ? | No (additive ; G5 stays green). |
| Backward compat ? | N/A — pure addition. |
| Performance ? | Lefthook target ≤ 1.5 s on a 1-line commit (`--file` mode). CI full-repo scan target ≤ 30 s for all 5 lints combined. |

---

## Task breakdown (atomic, each fits in 30-90 min)

> Notation : `Tn` = task number ; `dep:` = dependency on prior task ; `effort:` = estimated Claude execution time.

### Wave 0 — Test scaffolding (TDD setup)

#### T1 — Author shared test helper module
- **files** : `tools/checks/tests/__init__.py`, `tools/checks/tests/_lint_test_helpers.py`
- **action** : Create a tiny stdlib helper that (a) loads a lint script via `importlib.util.spec_from_file_location` (mirroring `tools/checks/test_banned_terms_arb.py:13-23`), (b) writes a synthetic `.dart` fixture into a tmpdir, (c) invokes `lint.scan(files=[fixture])` or `lint.main()` with monkey-patched `sys.argv`. NO new pip dep — pure stdlib `unittest` + `tempfile` + `importlib`.
- **verify** : `python3 -m unittest discover tools/checks/tests -p '_lint_test_helpers.py'` exits 0 (file imports cleanly, no tests yet).
- **effort** : 30 min
- **dep** : —

#### T2 — Author per-lint test fixtures (5 fixture sets)
- **files** : `tools/checks/tests/fixtures/raw_color_*.dart`, `tools/checks/tests/fixtures/raw_fontsize_*.dart`, `tools/checks/tests/fixtures/raw_fontfamily_*.dart`, `tools/checks/tests/fixtures/raw_borderradius_*.dart`, `tools/checks/tests/fixtures/raw_cta_*.dart`
- **action** : For each lint, author 3 fixture files :
  1. `<lint>_violation.dart` — contains exactly one raw violation
  2. `<lint>_clean.dart` — contains the token-correct equivalent
  3. `<lint>_ignored.dart` — contains a violation with `// lint-ignore: <rule>` on the same line
  Mirror the synthetic Dart shapes already covered in RESEARCH §Validation Architecture (lines 766-783).
- **verify** : `find tools/checks/tests/fixtures -name '*.dart' | wc -l` returns ≥ 15 ; `grep -L 'apps/mobile' tools/checks/tests/fixtures/*.dart` returns all (none reference real lib paths).
- **effort** : 45 min
- **dep** : T1

---

### Wave 1 — Lint scripts (RED → GREEN per LINT-NN)

> Pattern for every LINT-NN : (a) write the test file FIRST asserting expected exit codes + diagnostic format ; (b) run `python3 -m unittest tools/checks/tests/test_<lint>.py` (RED, fails because script does not exist) ; (c) author the lint script ; (d) re-run tests (GREEN). Each task is one RED→GREEN cycle.

#### T3 — LINT-01 : `prefer_mint_color_token` (RED→GREEN)
- **files** : `tools/checks/tests/test_prefer_mint_color_token.py`, `tools/checks/prefer_mint_color_token.py`
- **action** :
  1. Write 8 unit tests (matrix in RESEARCH §Phase Requirements → Test Map, lines 766-770) — assert : detects `Color(0xFF...)` outside `lib/theme/`, ignores inside `lib/theme/`, ignores `// lint-ignore: prefer_mint_color_token`, exits 0 when current ⊆ baseline, exits 1 with diagnostic on net-new, `--update-baseline` rewrites file, `--file <path>` works in single-file mode, `*.g.dart` skipped.
  2. Run tests → RED (script missing).
  3. Author `prefer_mint_color_token.py` following the skeleton in RESEARCH §Code Examples (lines 507-602). Pattern : `re.compile(r"Color\(0x([0-9A-Fa-f]{6,8})\)")`. EXCLUDE_DIRS : `/lib/theme/`, `/lib/l10n/`, `/test/`, `/test_driver/`, `/.dart_tool/`, `/build/`. Exclude `*.g.dart`, `*.freezed.dart`. Also detect `Colors.{white,black,transparent,red,grey,...}` outside theme as a SECOND pattern (29 sites per RESEARCH §Drift inventory, single combined baseline).
  4. Re-run tests → GREEN.
- **verify** :
  - `python3 -m unittest tools/checks/tests/test_prefer_mint_color_token.py` exits 0.
  - `python3 tools/checks/prefer_mint_color_token.py --update-baseline` produces a baseline with **31 ± 5** entries (RESEARCH §Drift inventory : 2 raw `Color(0xFF...)` + 29 Material refs).
  - `python3 tools/checks/prefer_mint_color_token.py` exits 0 against fresh baseline.
- **effort** : 75 min
- **dep** : T2

#### T4 — LINT-02 : `prefer_mint_text_style` (RED→GREEN)
- **files** : `tools/checks/tests/test_prefer_mint_text_style.py`, `tools/checks/prefer_mint_text_style.py`
- **action** :
  1. Write 8 unit tests (RESEARCH lines 771-773). Assert : detects `fontSize: N` outside theme, skips line comments (`// fontSize: 14 — historical`), `--file` works, baseline grandfathers existing.
  2. RED.
  3. Author script. Pattern : `re.compile(r"\bfontSize\s*:\s*([0-9]+(?:\.[0-9]+)?)")`. EXCLUDE_DIRS = LINT-01 set. Skip lines starting with `//`. Skip `*.g.dart`, `*.freezed.dart`, `lib/l10n/app_localizations*.dart`.
  4. GREEN.
- **verify** :
  - `python3 -m unittest tools/checks/tests/test_prefer_mint_text_style.py` exits 0.
  - `--update-baseline` produces **705 ± 50** entries (RESEARCH §LINT-02 drift inventory).
  - Re-run exits 0 against fresh baseline.
- **effort** : 75 min
- **dep** : T2 (parallel-safe with T3)

#### T5 — LINT-03 : `prefer_mint_fonts` (RED→GREEN)
- **files** : `tools/checks/tests/test_prefer_mint_fonts.py`, `tools/checks/prefer_mint_fonts.py`
- **action** :
  1. Write 6 unit tests (RESEARCH lines 774-775). Assert : detects `GoogleFonts.<x>(`, detects `TextStyle(fontFamily:` outside theme, allowlist `apps/mobile/lib/theme/mint_text_styles.dart` as the ONE file allowed to use `GoogleFonts.*`.
  2. RED.
  3. Author script. Two patterns ORed : `re.compile(r"\bGoogleFonts\.")` + `re.compile(r"\bfontFamily\s*:\s*['\"]")`. EXCLUDE_DIRS as above. Allowlist file : `apps/mobile/lib/theme/mint_text_styles.dart`.
  4. GREEN.
- **verify** :
  - Tests exit 0.
  - `--update-baseline` produces **100 ± 20** entries (RESEARCH §LINT-03 : 100 GoogleFonts + ~50 raw fontFamily).
  - Re-run exits 0.
- **effort** : 60 min
- **dep** : T2 (parallel-safe with T3, T4)

#### T6 — LINT-04 : `prefer_mint_radius` (RED→GREEN, soft mode)
- **files** : `tools/checks/tests/test_prefer_mint_radius.py`, `tools/checks/prefer_mint_radius.py`
- **action** :
  1. Write 8 unit tests (RESEARCH lines 776-777). Assert : `BorderRadius.circular(12)` PASSES (in allowlist), `BorderRadius.circular(7)` is BASELINED if pre-existing (in baseline), `BorderRadius.circular(13)` net-new FAILS, allowlist = `{2, 4, 6, 8, 10, 12, 14, 16, 20, 24, 999}` (RESEARCH §LINT-04, 11 values).
  2. RED.
  3. Author script. Pattern : `re.compile(r"BorderRadius\.circular\(\s*(\d+(?:\.\d+)?)\s*\)")`. ALLOWLIST = `{2, 4, 6, 8, 10, 12, 14, 16, 20, 24, 999}`. Violations are sites where `int(N) not in ALLOWLIST`. Per RESEARCH §Open Q1 + LINT-05 specs : ship in BASELINE-ONLY mode for Phase 1. Hard-mode-with-`MintRadius` is Phase 4.
  4. GREEN.
- **verify** :
  - Tests exit 0.
  - `--update-baseline` produces **~25 entries** (RESEARCH §LINT-04 : outlier values 1,3,5,7,9,11,19,22,99 = ~25 sites).
  - Re-run exits 0.
- **effort** : 75 min
- **dep** : T2 (parallel-safe with T3, T4, T5)

#### T7 — LINT-05 : `prefer_mint_cta` (RED→GREEN, baseline-only)
- **files** : `tools/checks/tests/test_prefer_mint_cta.py`, `tools/checks/prefer_mint_cta.py`
- **action** :
  1. Write 6 unit tests (RESEARCH lines 778-779). Assert : detects `ElevatedButton(`, `OutlinedButton(`, `FilledButton(`, `TextButton(` outside `apps/mobile/lib/widgets/cta/` AND outside `apps/mobile/lib/theme/` ; allows inside ; baseline grandfathers all 154 sites.
  2. RED.
  3. Author script. Pattern : `re.compile(r"\b(?:Elevated|Outlined|Filled|Text)Button\s*\(")`. Allowlist dirs : `/lib/widgets/cta/`, `/lib/theme/`. Diagnostic message MUST include : `"Raw button widgets are frozen pending Phase 4 (MVP-CTA-UNIFICATION-V1) — `MintCTA.{primary,secondary,tertiary,destructive}` lands then. If you need a new button surface this phase, contact #design or use `// lint-ignore: prefer_mint_cta`."` (RESEARCH §Open Q2 recommended copy).
  4. GREEN.
- **verify** :
  - Tests exit 0.
  - `--update-baseline` produces **154 ± 10** entries.
  - Re-run exits 0.
- **effort** : 60 min
- **dep** : T2 (parallel-safe with T3, T4, T5, T6)

---

### Wave 2 — Wiring (lefthook + CI + README + audit summary)

#### T8 — Lefthook integration (soft warn, `--file {staged_files}`)
- **files** : `lefthook.yml`
- **action** : Add 5 commands under `pre-commit.commands` (after the existing `wiki-lint:` block ; preserve existing 3 commands). Each command :
  ```yaml
  prefer-mint-color-token:
    run: python3 tools/checks/prefer_mint_color_token.py --file {staged_files}
    glob: "apps/mobile/lib/**/*.dart"
    tags: [design, phase-1-mvp-design-lints]
    fail_text: "design lint warning — see CI for full diff"
  ```
  Repeat for the 4 other lints. Per RESEARCH §Open Q5 — lefthook MUST exit 0 even on violations (warn-only). Lints accept `--file` repeated for multi-file commits (matches `accent_lint_fr.py:115` `--file` action). Lefthook's `{staged_files}` substitution → space-separated → must call lint as `--file f1 --file f2 ...` ; modify each script to support `--file` `nargs="+"` or `action="append"`.
- **verify** :
  - `lefthook run pre-commit --files apps/mobile/lib/screens/landing/landing_screen.dart` runs all 5 design lints AND existing 3 (memory-retention, map-freshness-hint, wiki-lint) without error (exits 0 even if violations present, since they are baselined).
  - `time lefthook run pre-commit --files <single-file>` ≤ 1.5 s.
- **effort** : 30 min
- **dep** : T3, T4, T5, T6, T7 (needs all 5 scripts present)

#### T9 — CI workflow (hard fail, net-new only)
- **files** : `.github/workflows/design-lints.yml` (NEW workflow file, sibling of `ci.yml`)
- **action** : Create a NEW dedicated workflow `design-lints.yml` rather than appending to `ci.yml` (RESEARCH §Architecture Patterns — explicit isolation, cleaner trigger surface). Workflow shape :
  ```yaml
  name: Design lints (MVP-DESIGN-LINTS-V1)
  on:
    pull_request:
      paths: ['apps/mobile/lib/**/*.dart', 'tools/checks/prefer_mint_*.py', 'tools/checks/baselines/prefer_mint_*.baseline.txt', '.github/workflows/design-lints.yml']
    push:
      branches: [main, dev, staging]
  jobs:
    design-lints:
      name: Design system lints
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - uses: actions/setup-python@v5
          with:
            python-version: "3.11"
        - run: python3 tools/checks/prefer_mint_color_token.py
        - run: python3 tools/checks/prefer_mint_text_style.py
        - run: python3 tools/checks/prefer_mint_fonts.py
        - run: python3 tools/checks/prefer_mint_radius.py
        - run: python3 tools/checks/prefer_mint_cta.py
  ```
  Each step exits non-zero on net-new violations → job fails → PR blocked.
- **verify** :
  - `cat .github/workflows/design-lints.yml | yq '.jobs.design-lints.steps | length'` returns ≥ 7 (checkout + setup-python + 5 lint steps).
  - `gh workflow list` after push shows `Design lints (MVP-DESIGN-LINTS-V1)`.
  - First PR push triggers the workflow ; all 5 steps pass against the freshly-snapshotted baseline.
- **effort** : 30 min
- **dep** : T8 (after lefthook is wired so the dev workflow is end-to-end before CI lands)

#### T10 — Baseline files committed + audit summary
- **files** :
  - `tools/checks/baselines/prefer_mint_color_token.baseline.txt`
  - `tools/checks/baselines/prefer_mint_text_style.baseline.txt`
  - `tools/checks/baselines/prefer_mint_fonts.baseline.txt`
  - `tools/checks/baselines/prefer_mint_radius.baseline.txt`
  - `tools/checks/baselines/prefer_mint_cta.baseline.txt`
  - `.planning/audit/ui_drift_baseline_2026-05-09.txt`
- **action** : Run `python3 tools/checks/prefer_mint_*.py --update-baseline` for each lint to write the 5 baseline files. Then write `.planning/audit/ui_drift_baseline_2026-05-09.txt` — a human-readable summary linking to each baseline file with line-count + top-10 sample (RESEARCH §Architecture lines 200-204). Format :
  ```
  # UI drift baseline — 2026-05-09 (Phase MVP-DESIGN-LINTS-V1)

  Total: <N> grandfathered violations across 5 design lints.
  Net-new violations BLOCK CI (`.github/workflows/design-lints.yml`).
  Existing violations are deferred to Phase 3 (FONTS-TOKENS-V2) + Phase 4 (CTA-UNIFICATION-V1) sweep PRs.

  ## prefer_mint_color_token: <N> entries
  See: tools/checks/baselines/prefer_mint_color_token.baseline.txt
  Sample (top 10):
    apps/mobile/lib/widgets/consent/policy_diff_view.dart:88: Color(0xFF...)
    ...

  ## prefer_mint_text_style: <N> entries
  ...
  ```
- **verify** :
  - `wc -l tools/checks/baselines/*.baseline.txt` returns 5 files with non-zero line counts.
  - Re-running every lint exits 0 (current ⊆ baseline) : `for s in tools/checks/prefer_mint_*.py; do python3 $s || exit 1; done; echo OK`.
  - `.planning/audit/ui_drift_baseline_2026-05-09.txt` exists, references all 5 baseline files, contains 5 H2 sections.
- **effort** : 30 min
- **dep** : T3, T4, T5, T6, T7 (needs all 5 scripts) ; can be done before T8/T9 but is more naturally last so the wiring runs against committed baselines.

#### T11 — Documentation : `README-DESIGN-LINTS.md`
- **files** : `tools/checks/README-DESIGN-LINTS.md`
- **action** : Concise (≤ 200 lines) README covering : (a) what the 5 lints check, (b) the baseline-snapshot pattern, (c) how to run a single lint locally, (d) how to update a baseline after a sweep PR (`--update-baseline` + commit), (e) the `// lint-ignore: <rule>` escape hatch syntax, (f) the hard-CI / soft-lefthook split, (g) which phase the lint will pivot in (Phase 3 for fonts hard-mode ; Phase 4 for radius + CTA hard-mode). Content is mostly assembly of RESEARCH.md sections — Karpathy #2 simplicity-first, no novel decisions.
- **verify** :
  - File exists with ≥ 5 H2 sections (one per lint) + 1 H2 « Baseline workflow » section.
  - `grep -c '^## ' tools/checks/README-DESIGN-LINTS.md` returns ≥ 6.
  - `python3 tools/checks/wiki_lint.py` (existing wiki-lint hook) passes on the file.
- **effort** : 45 min
- **dep** : T10 (so the README references real baseline files)

---

### Wave 3 — Smoke + integration verification

#### T12 — Full-repo smoke + end-to-end synthetic-violation test
- **files** : `tools/checks/tests/test_design_lints_smoke.py` (new integration test)
- **action** :
  1. Author one integration test that : (a) writes a synthetic `apps/mobile/lib/widgets/_lint_smoke_fixture.dart` with one violation per lint (then deletes it after assertion — uses a `tempfile.TemporaryDirectory` mounted view OR copies the lint scripts into a tmpdir + crafts a tiny `apps/mobile/lib/` shadow tree), (b) runs each lint pointed at the synthetic tree, (c) asserts each lint exits 1 + emits a diagnostic referencing the fixture line.
  2. Run all 5 lints against the actual repo HEAD with `--update-baseline` no-op confirm (current ⊆ baseline, exit 0).
  3. Run `python3 -m unittest discover tools/checks/tests -p 'test_*.py'` — all tests exit 0 (5 unit-test files from T3-T7 + this smoke file).
- **verify** :
  - `python3 -m unittest tools/checks/tests/test_design_lints_smoke.py` exits 0.
  - `python3 -m unittest discover tools/checks/tests -p 'test_*.py'` exits 0 ; pytest-style summary shows ≥ 36 tests passing (8+8+6+8+6 unit + smoke).
  - `time (for s in tools/checks/prefer_mint_*.py; do python3 $s; done)` ≤ 30 s on local repo.
- **effort** : 60 min
- **dep** : T10 (baselines exist) + T11 (README exists for completeness)

---

## Atomic commit sequence

> One commit per task or task-group. Branch : `feature/MVP-DESIGN-LINTS-V1` cut from `dev`. Squash-merge into `dev`. Per memory `feedback_pre_push_checklist.md` — full `python3 -m unittest discover tools/checks/tests` MUST pass before each push.

| # | Task(s) | Branch state | Commit message |
|---|---|---|---|
| C1 | T1, T2 | scaffolding only | `chore(design-lints): scaffold test helpers + per-lint fixtures (Phase MVP-DESIGN-LINTS-V1 prep)` |
| C2 | T3 | LINT-01 RED→GREEN | `feat(tools/checks): add prefer_mint_color_token lint + tests (LINT-01)` |
| C3 | T4 | LINT-02 RED→GREEN | `feat(tools/checks): add prefer_mint_text_style lint + tests (LINT-02)` |
| C4 | T5 | LINT-03 RED→GREEN | `feat(tools/checks): add prefer_mint_fonts lint + tests (LINT-03, blocks GoogleFonts re-introduction)` |
| C5 | T6 | LINT-04 RED→GREEN | `feat(tools/checks): add prefer_mint_radius lint + tests (LINT-04, soft allowlist mode)` |
| C6 | T7 | LINT-05 RED→GREEN | `feat(tools/checks): add prefer_mint_cta lint + tests (LINT-05, baseline-only pending Phase 4)` |
| C7 | T10 | 5 baselines committed | `chore(design-lints): snapshot 5 baseline files + .planning/audit/ui_drift_baseline_2026-05-09.txt` |
| C8 | T8 | lefthook wired | `chore(lefthook): wire 5 design lints in pre-commit (soft warn, --file staged)` |
| C9 | T9 | CI wired | `ci(design-lints): add hard-fail design-lints workflow (Phase MVP-DESIGN-LINTS-V1)` |
| C10 | T11 | docs | `docs(tools/checks): add README-DESIGN-LINTS.md (baseline workflow + per-lint specs)` |
| C11 | T12 | smoke green | `test(design-lints): add full-suite smoke + synthetic-violation integration test` |

11 atomic commits. Each fits a single concern. Per memory `feedback_no_micro_pauses.md` — push commits as they're ready, don't bundle into one mega-PR. Per memory `feedback_pre_push_checklist.md` — before each push : (a) `python3 -m unittest discover tools/checks/tests`, (b) `lefthook run pre-commit` on a touched file, (c) confirm no regression on existing 11 lints (`for s in tools/checks/{wcag_aa_all_touched,accent_lint_fr,banned_terms_arb,no_hardcoded_fr,memory_retention,wiki_lint,no_chiffre_choc,no_legacy_confidence_render,no_implicit_bloom_strategy,sentence_subject_arb_lint,no_llm_alert,landing_no_numbers,landing_no_financial_core,sentence_subject_arb_lint,sentry_capture_single_source}.py; do python3 $s 2>/dev/null || true; done`).

---

## Dependency graph

```
T1 (helpers)
 └→ T2 (fixtures)
      ├→ T3 (LINT-01) ──┐
      ├→ T4 (LINT-02) ──┤
      ├→ T5 (LINT-03) ──┤   parallel
      ├→ T6 (LINT-04) ──┤
      └→ T7 (LINT-05) ──┘
                        │
              T10 (baselines + audit) ←─┘
                        │
              T8 (lefthook)
                        │
              T9 (CI workflow)
                        │
              T11 (README)
                        │
              T12 (smoke test) ── DONE
```

Critical path : T1 → T2 → T3..T7 (parallel) → T10 → T8 → T9 → T11 → T12. ~6.5 h Claude-execution time across 12 tasks ; comfortably fits the 2-day budget with margin for rebases / unexpected false-positive triage.

---

## 5-gate exit criteria

> Per CLAUDE.md §9 + memory `feedback_perimeter_5_gates.md`. NO claim « ready » unless all 5 gates green with deterministic citations.

### G1 — Maestro flow
**N/A for this phase.** Pure tooling — no UI surface, no user-visible behavior change. Citation : RESEARCH.md §Locked Decisions confirms « no `apps/mobile/lib/**/*.dart` files modified in this phase ». Replacement gate :
- **G1' (substitute)** : `python3 -m unittest discover tools/checks/tests -p 'test_*.py'` exits 0 with ≥ 36 tests passing. This is the deterministic « lint behavior verified » equivalent of « user flow verified ».
- Citation evidence required at phase close : test runner output pasted in VERIFICATION.md.

### G2 — Device verify (Julien)
**N/A for this phase.** No user-facing change to verify on device. Citation : milestone strategy confirms Phase 1 is « foundation, blocks UI sweep PRs ». Replacement gate :
- **G2' (substitute)** : Julien runs `lefthook run pre-commit --files <any-changed-dart-file>` locally on his machine, confirms ≤ 1.5 s + warn-only output (no false positive that would block his commits). Confirms in VERIFICATION.md with command output.

### G3 — dev CI green
- `flutter analyze` green (unchanged ; phase touches no Dart code).
- `flutter test` green (unchanged ; phase touches no Dart code).
- `pytest -q` green (unchanged ; phase touches no backend code).
- **NEW : `Design lints (MVP-DESIGN-LINTS-V1)` workflow green** on the merge commit (5 jobs : prefer_mint_color_token, prefer_mint_text_style, prefer_mint_fonts, prefer_mint_radius, prefer_mint_cta).
- `WCAG AA all touched (ACCESS-03)` workflow green (unchanged ; sibling job).
- Citation evidence required : `gh pr checks <N>` output pasted in VERIFICATION.md showing all required jobs ≠ fail / ≠ pending.

### G4 — Regression suite
- Flutter ≥ 229 model tests green (unchanged).
- Backend ≥ 6047 tests green (unchanged).
- Existing 11 `tools/checks/*.py` lints exit 0 against current HEAD (no regression). Specifically : `accent_lint_fr.py`, `banned_terms_arb.py`, `no_hardcoded_fr.py`, `wcag_aa_all_touched.py`, `s0_s5_aaa_only.py`, `no_chiffre_choc.py`, `no_legacy_confidence_render.py`, `no_implicit_bloom_strategy.py`, `sentence_subject_arb_lint.py`, `no_llm_alert.py`, `landing_no_numbers.py`, `landing_no_financial_core.py`, `wiki_lint.py`, `memory_retention.py`, `regional_microcopy_drift.py`, `sentry_capture_single_source.py`.
- **NEW : All 5 design lints exit 0** against committed baselines on a freshly-checked-out repo (`for s in tools/checks/prefer_mint_*.py; do python3 $s || exit 1; done`).
- Citation evidence required : test output pasted in VERIFICATION.md.

### G5 — LSFin / accent / ARB lint
- Phase ADDS to G5 surface (5 lints) ; does NOT modify existing G5 (banned_terms_arb, accent_lint_fr, ARB parity).
- `python3 tools/checks/banned_terms_arb.py` exits 0 (no ARB changes in this phase).
- `python3 tools/checks/accent_lint_fr.py` exits 0 ; the new lint scripts + README MUST themselves pass `accent_lint_fr.py` (any FR string in error messages or README must carry diacritics — e.g. `« génère »` not `« genere »`).
- Public-repo discipline (memory `feedback_public_repo_discipline.md`) : NO forensic legal language in any lint diagnostic, README, or commit message. `python3 tools/checks/no_legal_admission_in_public_docs.py` exits 0 on the new files.
- Citation evidence required : output of the 3 lints above pasted in VERIFICATION.md.

### Phase exit checklist
Phase is closed only when ALL of the below are pasted into VERIFICATION.md with deterministic citations :
- [ ] G1' : `python3 -m unittest discover tools/checks/tests -p 'test_*.py'` exit code + test count
- [ ] G2' : Julien-confirmed lefthook timing + soft-warn behavior
- [ ] G3 : `gh pr checks` output, all required jobs green, including new `Design lints` workflow
- [ ] G4 : 16 existing lints + 5 new lints all exit 0 ; Flutter + backend test counts unchanged
- [ ] G5 : banned_terms_arb + accent_lint_fr + no_legal_admission_in_public_docs all exit 0 on new files

---

## Counter-arguments and data gaps (Wiki Pattern Karpathy #3, REQUIRED)

### What does the strongest opposing view say ?

> « Don't ship 5 lints in 2 days — ship the most painful 2 (LINT-02 fontSize + LINT-03 GoogleFonts) and defer LINT-04 (BorderRadius, 1545 sites) + LINT-05 (CTA, 154 sites) to the perimeters that actually fix them (Phase 3 + Phase 4). Adding lints that *baseline 100 % of existing drift* and only fail on net-new is performance theater — it's effectively zero immediate enforcement, and the 2-day cost of authoring the lint + baseline + tests + docs + CI + lefthook integration is real. Spend the 2 days on Phase 3 fonts and ship LINT-03 + the GoogleFonts deletion together. »

This view is **rejected** for Phase 1 but kept on record :

- The milestone strategy explicitly orders « lints first, sweep second » (RESEARCH §Locked Decisions, milestone § « Why this is Phase 1 »). Without LINT-04 + LINT-05 in place BEFORE the sweep PRs, the sweep PRs themselves re-introduce the violations they're sweeping (touch-rebuild cycle).
- Authoring 5 lints in parallel is cheaper per-lint than 5 sequential lint phases (shared test helpers, shared fixtures pattern, shared CI workflow).
- The « zero immediate enforcement » critique is partly true — the lint catches nothing on day-one — but **catches every PR opened after day-one**, which is precisely the point.

### What does this plan not address ?

Empirical gaps :
- **No measurement of false-positive rate** (RESEARCH §Assumption A2 : « < 5 % » is a guess). T3-T7 fixtures cover synthetic cases ; the real-world false-positive rate against the 1500+ baselined sites is unknown until first PR pushes the lint.
- **No measurement of lefthook latency on a 100-file commit** (RESEARCH §Pitfall 3). The 1.5 s budget is a guess for a 1-line commit ; a sweep PR touching 100 files may exceed it.
- **No coverage on the « developer adds to baseline rather than fixes »** anti-pattern (RESEARCH §Pitfall 4). T11 README documents the discipline but doesn't enforce it. Could add a `wiki-lint`-style gate that warns when a PR touches a `.baseline.txt` file ; deferred.
- **No coverage on auto-generated `.g.dart`** beyond an exclusion list ; if a future codegen produces files outside the current pattern, lints may fire spuriously.
- **No `MintRadius` token landing in this phase** — the LINT-04 allowlist `{2,4,6,8,10,12,14,16,20,24,999}` is hardcoded in Python, NOT derived from a Dart token file. Drift between the Python allowlist and any future `MintRadius` token is a maintenance liability.

### What would change this conclusion ?

Concrete future signals that would force re-litigation :
- If LINT-04 false-positive rate > 10 % in week 1 PRs → drop LINT-04 to baseline-only-no-allowlist mode (only fail on `path:line` net-new, ignore numeric value).
- If `analysis_server_plugin` reaches v1.0 stable in window → reconsider migrating LINT-01..LINT-03 to AST-based plugin in a v2 lint phase.
- If a sweep PR (Phase 3 or Phase 4) is consistently blocked by `--update-baseline` ergonomics → introduce a CI bot that auto-updates baselines on label `baseline-shrink-allowed` (deferred).
- If lefthook > 3 s on common commit → migrate to a single dispatcher script that runs all 5 lints in one Python process (avoid Python startup × 5).

---

## Risks + mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| LINT-04 1545 sites cause a baseline file > 50 KB | high | low | Files are sorted ; git diffs are noisy on rebase. Mitigation : commit early, baseline file rarely changes outside explicit `--update-baseline` runs. |
| Lefthook > 1.5 s with all 5 lints on a multi-file commit | medium | medium | Use `--file` per script (not full-repo scan in pre-commit). Each Python startup ~80 ms ; 5 × 80 ms + scan time ≈ 600 ms target. If exceeded, fold into a single dispatcher script. |
| Net-new violation from a refactor that just shifts line numbers | medium | low | Baseline format is `path:line` ; line shifts cause apparent net-new. Mitigation : `--update-baseline` is a known follow-up commit in any sweep PR. RESEARCH §Pitfall 2 documented in T11 README. |
| Public-repo discipline drift in lint diagnostic copy | low | high | T3-T7 review : every diagnostic message reviewed against `feedback_public_repo_discipline.md` rules. Run `python3 tools/checks/no_legal_admission_in_public_docs.py` before each commit (G5). |
| `// lint-ignore: <rule>` abuse | low | medium | Out of scope for Phase 1 ; track a quarterly grep audit (RESEARCH §Security Domain table). |
| Phase 1 lands but Phase 3 or Phase 4 sweep accidentally re-introduces violations | medium | high | Lints fire on net-new — sweep PR with regression is blocked at CI. This IS the design intent. |

---

## Success criteria (concrete, post-execution)

Phase is shippable when :
1. 5 lint scripts + 5 test files + 5 baseline files + 5 fixture sets exist under `tools/checks/`.
2. `lefthook run pre-commit --files <staged>` runs all 5 design lints in ≤ 1.5 s, exits 0 even on baselined violations (warn-only).
3. `.github/workflows/design-lints.yml` runs on every PR ; green against fresh baselines ; red on synthetic net-new violation (proven by T12 smoke).
4. `python3 -m unittest discover tools/checks/tests -p 'test_*.py'` exits 0 with ≥ 36 tests.
5. `tools/checks/README-DESIGN-LINTS.md` documents the 5 lints + baseline workflow + ignore syntax + phase pivot dates.
6. `.planning/audit/ui_drift_baseline_2026-05-09.txt` summarizes the 5 baselines for human review.
7. All 5 G3 + G4 + G5 sub-checks green with deterministic citations in VERIFICATION.md.

---

## Out-of-scope reminders (deferred ; do NOT attempt)

- Fixing existing drift in `apps/mobile/lib/` (Phase 3 + Phase 4).
- Adding `MintRadius` token (Phase 4).
- Adding `MintCTA` widget (Phase 4).
- Adding `MintCurrencyText` widget + `Text('CHF...')` lint (Phase 5).
- IDE quick-fixes / `analysis_server_plugin` migration (v2 lint phase).
- Dark mode token enforcement (separate `MVP-DARK-MODE-FOUNDATION` perimeter).
- `EdgeInsets`, `SizedBox`, `Duration` linting (separate `MVP-MOTION-LINT-V1` perimeter).
- Auto-shrink-on-PR baseline updates (manual `--update-baseline` only in Phase 1).

---

## Sources

- `.planning/MILESTONE-CHAT-AS-VERB-2026-05-09.md` (milestone strategy + 5-gate contract)
- `.planning/phases/MVP-DESIGN-LINTS-V1/RESEARCH.md` lines 1-886 (5-lint scope, baselines, hard-CI/soft-lefthook, drift inventory verified, assumptions A1-A10)
- `tools/checks/wcag_aa_all_touched.py` (lint script shape)
- `tools/checks/accent_lint_fr.py` lines 19-152 (`--file` flag, EXCLUDE_SUBSTRINGS, exit codes)
- `tools/checks/test_banned_terms_arb.py` lines 1-50 (stdlib unittest pattern, no pip dep)
- `lefthook.yml` lines 1-41 (pre-commit.commands insertion point, glob + tags)
- `.github/workflows/ci.yml` lines 92-130 (`wcag-aa-all-touched` job pattern, `actions/setup-python@v5`, Python 3.11)
- `.planning/decisions/_TEMPLATE.md` (counter-arguments + data gaps section schema)
- CLAUDE.md §9 (0-trust protocol — citation requirements for « ready » claim)
- CLAUDE.md §7 (Karpathy 4 — simplicity-first, surgical-changes principles applied to scope discipline)
- Memory `feedback_perimeter_5_gates.md` (5-gate exit contract per perimeter)
- Memory `feedback_pre_push_checklist.md` (pre-push test sweep)
- Memory `feedback_public_repo_discipline.md` (no forensic legal language ; G5 sub-check)
- Memory `feedback_no_micro_pauses.md` (commit cadence : push as ready)
- Memory `feedback_design_panel_before_push.md` (N/A — pure tooling, no Flutter screens touched)

---

*Plan v1 — PROPOSED for execution by `gsd-executor`. Activates on Julien's ack.*
