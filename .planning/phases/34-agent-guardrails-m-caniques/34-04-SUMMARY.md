---
phase: 34-agent-guardrails-m-caniques
plan: 04
subsystem: infra
tags: [lefthook, i18n, arb, icu, python, stdlib, guard-05, parity-lint, phase-34]

requires:
  - phase: 34-00
    provides: lefthook.yml skeleton + fixtures (arb_parity_pass, arb_drift_missing, arb_drift_placeholder) + conftest.py
  - phase: 34-02
    provides: preceding-line override convention + self-test structure (lefthook_self_test.sh + fixture-exclusion Pitfall 7 pattern)
  - phase: 30.7
    provides: validate_arb_parity() MCP tool (complementary runtime lookup; GUARD-05 is the pre-commit gate)
provides:
  - GUARD-05 cross-language ARB parity lint (6 langs: fr/en/de/es/it/pt)
  - stdlib-only (json + re + argparse) Python 3.9 implementation (361 LOC)
  - Depth-aware ICU placeholder walker (handles simple, typed, plural, select, DateTime forms with no false-positives on select variant labels)
  - arb-parity pre-commit command in lefthook.yml (glob app_*.arb, runs full 6-file check)
  - lefthook_self_test.sh 5th section (drift fixture FAIL + clean fixture PASS)
  - 3 pre-existing translation drifts fixed (forfaitFiscalSemanticsLabel in es/it/pt)
affects: [34-05, 34-06, 34-07, 35, 36 (FIX-06 MintShell ARB parity audit), v2.9 (1864 dead Dart-side keys cleanup)]

tech-stack:
  added: []  # stdlib only per D-14
  patterns:
    - "Depth-aware ICU walker (not regex) for placeholder name extraction"
    - "Structural filtering over keyword filtering (walker positions determine which tokens are names vs types)"
    - "Pre-commit lint runs full cross-file scan even when only 1 file staged (glob triggers, not {staged_files} expansion)"

key-files:
  created:
    - "tools/checks/arb_parity.py"
    - "tests/checks/test_arb_parity.py"
    - ".planning/phases/34-agent-guardrails-m-caniques/34-04-SUMMARY.md"
  modified:
    - "lefthook.yml (added arb-parity command)"
    - "tools/checks/lefthook_self_test.sh (5th section)"
    - "apps/mobile/lib/l10n/app_es.arb (forfaitFiscalSemanticsLabel translation completion)"
    - "apps/mobile/lib/l10n/app_it.arb (forfaitFiscalSemanticsLabel translation completion)"
    - "apps/mobile/lib/l10n/app_pt.arb (forfaitFiscalSemanticsLabel translation completion)"

key-decisions:
  - "Depth-aware ICU walker replaces RESEARCH Pattern 4 one-line regex — regex captured select variant labels {il}/{elle} as false-positive placeholder names"
  - "ICU_KEYWORDS filter REMOVED from placeholder emission — MINT production uses plural/number/date as real placeholder names, filtering would false-negative"
  - "3 pre-existing translation drifts fixed (Rule 1): forfaitFiscalSemanticsLabel in es/it/pt was missing final Savings: {savings} clause — truncated translations"
  - "Full 6-file scan per pre-commit event (no {staged_files} expansion) because drift is a cross-file property"
  - "RESEARCH baseline claim of 'all clean today' was stale — 1 real drift lurked until the lint ran"

patterns-established:
  - "Structural ICU parser: track brace depth + clause kind (placeholder / plural_or_select / variant_body) — robust against select variant label false-positives"
  - "Keyword-safe placeholder emission: filter at TYPE position via walker structure, not at emission via blacklist"
  - "Cross-file parity lint convention: glob triggers on any file in the set; script scans the full set in one call"

requirements-completed: [GUARD-05]

duration: 8m
completed: 2026-04-22
---

# Phase 34 Plan 04: GUARD-05 arb_parity Cross-Language ARB Lint Summary

**Stdlib-only 6-language ARB parity lint with depth-aware ICU walker — catches key-set divergence + placeholder name drift without any intl/ICU runtime dependency, baseline 6707 keys × 6 langs + 568 placeholder-bearing @keys verified clean**

## Performance

- **Duration:** 8 minutes (1 RED commit + 1 GREEN commit + 1 wiring commit)
- **Started:** 2026-04-22T20:44:08Z
- **Completed:** 2026-04-22T20:52:00Z (approx)
- **Tasks:** 2 (Task 1 TDD lint + tests, Task 2 lefthook + self-test)
- **Files modified:** 7 (2 created: arb_parity.py + test_arb_parity.py; 5 modified: lefthook.yml + lefthook_self_test.sh + 3 ARB translations)

## Accomplishments

- **GUARD-05 active as pre-commit gate** — any ARB file staged under apps/mobile/lib/l10n/ triggers a full 6-file cross-language parity check before the commit lands. D-13 mechanical prevention of drift is now enforced; FIX-06 Phase 36 will do the first full human-driven audit behind this gate.
- **Depth-aware ICU walker** correctly handles all 5 ARB placeholder forms (simple, typed, plural, select, DateTime) without false-positives on select variant labels. RESEARCH Pattern 4 one-liner regex was naive about `{sex, select, male {il} female {elle}}` — literal text `il`/`elle` inside variant bodies would have been captured as placeholder names. Walker dispatches on brace depth + clause kind.
- **Production baseline PASS verified empirically**: `python3 tools/checks/arb_parity.py` exits 0 reporting `non-@ keys=6707, placeholder-bearing @keys checked=568`. 3 pre-existing drift bugs (Rule 1 auto-fix) were discovered + fixed in the process.
- **pytest 14/14 green** covering: 4 fixture-directory scenarios (parity_pass, missing-key, extra-key, placeholder-drift), 7 extract_placeholders unit tests (simple, plural, select, typed, multiple, empty, DateTime), 2 defensive tests (missing-file / malformed JSON), 1 production baseline.
- **Self-test 5 sections green**: memory-retention + accent_lint_fr + no_bare_catch + no_hardcoded_fr + arb_parity.
- **P95 benchmark 0.100s** — unchanged from Phase 34 Plan 03 (50x headroom vs 5s budget). GUARD-01 success criterion #1 uncompromised with 6 active pre-commit commands.

## Task Commits

1. **Task 1 (TDD RED): Add failing test for arb_parity** — `b3fd76b0` (test)
2. **Task 1 (TDD GREEN): Implement arb_parity lint + fix 3 pre-existing drifts** — `30c7c900` (feat)
3. **Task 2: Wire arb-parity command + extend self-test** — `d91976f1` (chore)

_Note: Task 1 is TDD so RED + GREEN committed separately per `<tdd_execution>` protocol. No REFACTOR pass was needed — the walker design after the initial GREEN iteration passed all acceptance criteria._

## Files Created/Modified

- **`tools/checks/arb_parity.py`** (361 LOC, NEW) — stdlib-only Python 3.9 lint. Depth-aware ICU walker + 6-file JSON loader + CLI arg parser. Exit codes 0 (parity OK) / 1 (divergence). `check_parity(l10n_dir: Path) -> (int, List[str])` is the programmatic entry; `main(argv)` wraps it with argparse.
- **`tests/checks/test_arb_parity.py`** (180 LOC, NEW) — 14 pytest cases covering D-13 key-parity, D-13 placeholder parity, Pitfall 3 (plural not false-positive), ICU form coverage, production baseline.
- **`lefthook.yml`** (+14 lines) — `arb-parity` pre-commit command added. Glob `apps/mobile/lib/l10n/app_*.arb`. No `{staged_files}` expansion; script scans full directory.
- **`tools/checks/lefthook_self_test.sh`** (+14 lines) — 5th section runs `arb_parity --dir tests/checks/fixtures/arb_drift_missing` (must fail) + `--dir tests/checks/fixtures/arb_parity_pass` (must pass). Pitfall-7 reminder now cites Plans 01+02+03+04.
- **`apps/mobile/lib/l10n/app_es.arb`** — `forfaitFiscalSemanticsLabel` completed with `. Ahorro: {savings}.`
- **`apps/mobile/lib/l10n/app_it.arb`** — `forfaitFiscalSemanticsLabel` completed with `. Risparmio: {savings}.`
- **`apps/mobile/lib/l10n/app_pt.arb`** — `forfaitFiscalSemanticsLabel` completed with `. Economia: {savings}.`

## Decisions Made

- **Depth-aware walker over regex** (core deviation from RESEARCH Pattern 4): the suggested one-liner `\{\s*([A-Za-z_]...)(?:[},]|\s)` is unsound for select forms. Any `{ident}` inside a select variant body (e.g. `male {il}`) would match. Walker tracks brace depth and clause kind so only name-position identifiers emit. Single O(n) pass, zero external deps.
- **ICU_KEYWORDS filter removed at emission** — MINT production ARB has real placeholder names that clash with ICU type keywords:
  - `stepOcrContinueWith` + `stepOcrSnackSuccess` have placeholder LITERALLY NAMED `plural` (referenced as `{plural}` in the value for pluralisation suffix handling)
  - `mortgageJourneyStepLabel` uses `number` as a placeholder name
  - `mintHomeDeltaSince` / `planCard_targetDate` / `pensionFundSyncDate` / `dossierUpdatedOn` use `date` as a placeholder name
  Filtering at emission time would false-negative all these. The walker's structural dispatch already handles ambiguity: when walking `{name, type, ...}`, the type token is consumed by a dedicated branch and never reaches `names.add()`. Only a `{plural}` simple-form references the NAME `plural`, which is legitimately emitted.
- **3 pre-existing translation drifts auto-fixed (Rule 1)** — `forfaitFiscalSemanticsLabel` in es/it/pt was missing `. {LanguageLocalWord}: {savings}.` final clause. The FR template + EN + DE have the full 3-placeholder template; es/it/pt had truncated translations missing `{savings}`. Added idiomatic target-language words (Ahorro/Risparmio/Economia). Required to unblock the baseline success criterion — and catches the real translation bug the lint was designed to prevent.
- **RESEARCH baseline claim was stale** — RESEARCH lines 388-410 asserted "all 6 langs PASS today" but the forfaitFiscal drift went unnoticed because the claim was based on KEY-set comparison only, not placeholder-set comparison. The lint as shipped is stricter than the research envisioned, which is the entire point of shipping it.
- **Full 6-file scan on any single-file stage** — a drift is a cross-file property; checking just the staged file is unsound. lefthook's `glob:` matcher fires the command when ANY ARB is staged, and the script internally scans all 6 via its default `--dir`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Depth-aware ICU walker replaces RESEARCH Pattern 4 regex**
- **Found during:** Task 1 (GREEN phase, test_extract_placeholders_select failing)
- **Issue:** Research Pattern 4 regex `\{\s*([A-Za-z_]...)(?:[},]|\s)` falsely captures `il`/`elle`/`iel` from `{sex, select, male {il} female {elle} other {iel}}`. Inner variant bodies are literal text, not placeholders, but identifier-like literals inside `{}` match the regex.
- **Fix:** Rewrote `extract_placeholders()` as a depth-aware single-pass walker. Tracks stack of clause kinds (placeholder / plural_or_select / variant_body); only emits identifiers when at name position (immediately after `{` + optional whitespace, followed by `}` or `,`).
- **Files modified:** `tools/checks/arb_parity.py` (one function, ~110 LOC walker body including inline documentation of the algorithm)
- **Verification:** `test_extract_placeholders_select` + all 7 extract_placeholders tests green. Production baseline uses the same code path for 568 placeholder-bearing @keys and passes clean.
- **Committed in:** `30c7c900` (GREEN phase, Task 1B)

**2. [Rule 1 - Bug] ICU_KEYWORDS filter removed (was false-negating real placeholder names)**
- **Found during:** Task 1 (GREEN phase, test_production_arb_files_parity failing with missing=['plural'] and missing=['number'] and missing=['date'] diagnostics on several production keys)
- **Issue:** Research suggested filtering tokens `{plural, select, number, DateTime, date, time, ordinal}` from emission. But MINT uses `plural`/`number`/`date` as real placeholder names (e.g. stepOcrContinueWith's placeholder literally named `plural`, mortgageJourneyStepLabel's `number`, mintHomeDeltaSince's `date`). Filter caused 7+ production keys to false-positive as drift.
- **Fix:** Removed keyword filter. Kept the walker's structural dispatch which consumes type tokens (tokens after first comma in `{name, type, ...}`) WITHOUT adding to `names` set — so type position tokens never emit. Only name position tokens reach `names.add()`.
- **Files modified:** `tools/checks/arb_parity.py` (filter set renamed to `ICU_TYPE_ONLY_KEYWORDS` = empty set, documentation explains why; 2 `if ident not in ICU_KEYWORDS` gates replaced with unconditional `names.add(ident)`)
- **Verification:** Production baseline exit 0 (6707 keys, 568 @keys with placeholders checked, clean). 14/14 pytest green.
- **Committed in:** `30c7c900` (GREEN phase, Task 1B)

**3. [Rule 1 - Bug] 3 pre-existing translation drifts fixed in forfaitFiscalSemanticsLabel**
- **Found during:** Task 1 (GREEN phase, test_production_arb_files_parity still failing after filter fix — 3 keys remaining)
- **Issue:** `forfaitFiscalSemanticsLabel` in es/it/pt was truncated. FR declares 3 placeholders (`ordinary, forfait, savings`); es/it/pt values referenced only `ordinary` + `forfait`, missing the final `Savings: {savings}` sentence. Translation quality bug, pre-existing, exactly the class of drift GUARD-05 was designed to catch.
- **Fix:** Added idiomatic target-language final sentence:
  - es: `Comparación forfait fiscal. Imposición ordinaria: {ordinary}. Forfait fiscal: {forfait}. Ahorro: {savings}.`
  - it: `Confronto forfait fiscale. Imposizione ordinaria: {ordinary}. Forfait fiscale: {forfait}. Risparmio: {savings}.`
  - pt: `Comparação forfait fiscal. Tributação ordinária: {ordinary}. Forfait fiscal: {forfait}. Economia: {savings}.`
- **Files modified:** `apps/mobile/lib/l10n/app_es.arb`, `apps/mobile/lib/l10n/app_it.arb`, `apps/mobile/lib/l10n/app_pt.arb`
- **Verification:** Production baseline exit 0; `test_production_arb_files_parity` green.
- **Committed in:** `30c7c900` (GREEN phase, Task 1B)

---

**Total deviations:** 3 auto-fixed (all Rule 1 bug fixes discovered during TDD GREEN phase — 2 lint implementation bugs from following RESEARCH too literally + 1 real production translation bug the lint was designed to catch).
**Impact on plan:** All auto-fixes essential for correctness. No scope creep. LOC came in at 361 vs plan estimate 100-180 due to the walker being inherently more complex than a one-liner regex (plus extensive inline documentation of the walker algorithm); the plan's LOC target was based on the unsound regex approach and could not hold up to real ARB content.

## Issues Encountered

- **`LANGS = ` grep check failed in acceptance criteria** — plan expected `grep -c "LANGS = "` to return 1, but the file uses a typed annotation `LANGS: List[str] = [...]`. Semantically equivalent, mypy-clean, matches `grep "LANGS:"` = 3. Plan's grep was string-literal-sensitive; the typed annotation is preferable for Python 3.9+ strict typing. Minor documentation-only deviation; no code change needed.
- **LOC budget overrun** — plan estimated 100-180 LOC for arb_parity.py; actual is 361 LOC. The delta is 100% the walker algorithm documentation + the structural walker being ~110 LOC vs. a 1-line regex. Walker complexity is inherent to the ICU spec (select variants can't be parsed with a flat regex), so the LOC budget was unachievable with correct behaviour. Plan's success criterion was "parity + no false positives"; that's delivered. LOC is a proxy, not the goal.

## Known Stubs

None. All behaviour is fully wired:
- `tools/checks/arb_parity.py` is invoked by `lefthook.yml` via `run: python3 tools/checks/arb_parity.py` (tested end-to-end via lefthook_self_test.sh 5th section).
- `check_parity()` always returns a concrete (int, List[str]) tuple. No `NotImplementedError`, no pass-through, no mock.
- Production ARB files are scanned by the lint today (test_production_arb_files_parity proves the wiring).

## Threat Flags

None. The lint reads-only from `apps/mobile/lib/l10n/app_*.arb` files (already under version control, not a new trust boundary) and emits diagnostics to stdout/stderr. No new network endpoints, auth paths, file writes, or schema changes.

## Next Phase Readiness

- **Plan 34-05 (GUARD-06 proof_of_read)** — unblocked. Self-test reminder updated to cite Plans 01+02+03+04; Plan 05 adds the 5th exclude target.
- **Plan 34-06 (GUARD-07 bypass audit)** — unblocked, depends only on 34-00 scaffold.
- **Plan 34-07 (GUARD-08 CI thinning)** — can now depend on GUARD-05 active pre-commit gate to justify removing the equivalent CI job from `.github/workflows/ci.yml`.
- **FIX-06 Phase 36 (MintShell ARB parity audit)** — GUARD-05 is the active prevention gate; FIX-06 is the first human-driven full audit BEHIND the gate. Thanks to GUARD-05 running today, the baseline was cleaned of 1 real drift (forfaitFiscal) — Phase 36 starts from a clean baseline.
- **v2.9 dead Dart key cleanup (1864 orphans per CONCERNS T5)** — still deferred. GUARD-05 scope is CROSS-LANGUAGE, not Dart-side orphan detection (D-15).

## Self-Check: PASSED

**Files verified:**
- [x] `/Users/julienbattaglia/Desktop/MINT/tools/checks/arb_parity.py` exists
- [x] `/Users/julienbattaglia/Desktop/MINT/tests/checks/test_arb_parity.py` exists
- [x] `/Users/julienbattaglia/Desktop/MINT/lefthook.yml` contains `arb-parity:` block
- [x] `/Users/julienbattaglia/Desktop/MINT/tools/checks/lefthook_self_test.sh` contains `arb_parity:` self-test section

**Commits verified:**
- [x] `b3fd76b0` — test(34-04): add failing test for arb_parity lint (GUARD-05 RED)
- [x] `30c7c900` — feat(34-04): implement arb_parity lint + fix 3 pre-existing drifts (GUARD-05 GREEN)
- [x] `d91976f1` — chore(34-04): wire arb-parity command in lefthook.yml + extend self-test

**Runtime verification:**
- [x] `python3 -m pytest tests/checks/test_arb_parity.py -q` → 14 passed in 0.06s
- [x] `python3 tools/checks/arb_parity.py` → exit 0, non-@ keys=6707, placeholder-bearing @keys checked=568
- [x] `python3 tools/checks/arb_parity.py --dir tests/checks/fixtures/arb_drift_missing` → exit 1 with `goodbye` + `app_de.arb` in diagnostic
- [x] `python3 tools/checks/arb_parity.py --dir tests/checks/fixtures/arb_parity_pass` → exit 0
- [x] `lefthook validate` → "All good" exit 0
- [x] `bash tools/checks/lefthook_self_test.sh` → exit 0 with 5 sections green
- [x] `bash tools/checks/lefthook_benchmark.sh --assert-p95=5` → P95 = 0.100s (OK under threshold)
- [x] `python3 tools/checks/accent_lint_fr.py --file tools/checks/arb_parity.py` → exit 0 (self-compliance)
- [x] `python3 tools/checks/accent_lint_fr.py --file lefthook.yml` → exit 0 (Pitfall 8)

**Requirements marked complete:**
- [x] `GUARD-05` (via `node .claude/get-shit-done/bin/gsd-tools.cjs requirements mark-complete GUARD-05` → `{"updated":true,"marked_complete":["GUARD-05"]}`)

---
*Phase: 34-agent-guardrails-m-caniques*
*Plan: 04*
*Completed: 2026-04-22*
