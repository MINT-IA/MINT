---
phase: 34-agent-guardrails-m-caniques
plan: 03
subsystem: infra
tags: [lefthook, no-hardcoded-fr, guard-03, i18n, glob-scoped, pre-commit]

# Dependency graph
requires:
  - phase: 30.5
    provides: early-ship `tools/checks/no_hardcoded_fr.py` (CTX-02 heuristic — _QUOTED_ACCENT + _QUOTED_FR_WORDS fallbacks, IGNORE_MARKERS)
  - plan: 34-00
    provides: Wave 0 fixtures `hardcoded_fr_bad_widget.dart` + `hardcoded_fr_good_widget.dart` (with preceding-line override demo); tests/checks/conftest.py `fixtures_dir` fixture
  - plan: 34-02
    provides: preceding-line override semantics (`_override_in_preceding` helper API shape); `// lefthook-allow:<rule>: <reason>` >=3-word reason convention; parallel:true flipped; lefthook_self_test.sh 3-section structure
provides:
  - GUARD-03 activated via D-08 glob-scoped lefthook hook (`apps/mobile/lib/{widgets,screens,features}/**/*.dart` only) — decouples pre-commit gate from Phase 36 FIX-06 full-codebase i18n audit (services / models / ~120 strings D4)
  - tools/checks/no_hardcoded_fr.py (262 LOC, stdlib-only, Python 3.9-compat) — 4 D-09 primary patterns + 2 fallback patterns + 2 whitelist patterns + D-10 preceding-line override
  - tests/checks/test_no_hardcoded_fr.py (112 LOC, 11/11 pytest green in 0.03s) — covers D-09 primary patterns, D-09 whitelist (acronym + numeric), D-09 positive case (AppLocalizations), D-10 preceding-line override valid + insufficient-reason, Wave 0 fixtures
  - lefthook.yml: pre-commit.commands.no-hardcoded-fr wired with `{staged_files}` pattern + glob + fixtures/** exclude + `[i18n, phase-34]` tags
  - tools/checks/lefthook_self_test.sh: 4th section (FAIL + PASS direct-invocation checks against fixtures), reminder banner updated to cite Plans 01+02+03
affects: [34-04, 34-05, 34-06, 34-07, 36-FIX-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pattern H — Glob-based scope restriction: lefthook `glob: \"apps/mobile/lib/{widgets,screens,features}/**/*.dart\"` enforces D-08 scope at the hook layer while the Python script keeps a broader DEFAULT_SCOPE for manual full-repo audits. Resolves RESEARCH Open Question 3: no refactor of the early-ship script, no script-internal scope logic — glob does the restriction. Pattern reusable for any future lint that wants pre-commit scope narrower than manual-audit scope."
    - "Pattern I — Whitelist gating via negative FR signal: `_is_whitelisted_string()` fires ONLY when the line has no FR accent AND no FR function-word signal. Prevents 'ERR: erreur grave' from bypassing via its acronym prefix. Pairs whitelist (acronym + numeric) with strict must-not-have-FR-signal precondition."
    - "Pattern J — Ordered pattern dispatch (most-specific → least): _TEXT_ACCENT → _TEXT_CAPITALISED → _TITLE_PARAM → _LABEL_PARAM → _QUOTED_ACCENT (generic) → _QUOTED_FR_WORDS (fallback). First match on a line wins (single row per line). Keeps diagnostic kind informative (`hardcoded-fr-title` vs `hardcoded-fr-words`) and prevents duplicate violations from overlapping patterns."

key-files:
  created:
    - tests/checks/test_no_hardcoded_fr.py
    - .planning/phases/34-agent-guardrails-m-caniques/34-03-SUMMARY.md
  modified:
    - tools/checks/no_hardcoded_fr.py (rewrote 137 → 262 LOC, adds 4 D-09 primary patterns + D-10 preceding-line override + extended EXCLUDE_SUBSTRINGS)
    - lefthook.yml (appended no-hardcoded-fr command block with glob + exclude)
    - tools/checks/lefthook_self_test.sh (appended Plan 03 FAIL + PASS direct-invocation checks; reminder banner updated)

key-decisions:
  - "D-08 scope enforced at lefthook glob layer, NOT in the Python script. Resolves RESEARCH Open Question 3: `glob: \"apps/mobile/lib/{widgets,screens,features}/**/*.dart\"` narrows the pre-commit scope to widget code only; lib/l10n, lib/models, lib/services, test, integration_test are naturally outside this glob. The script's DEFAULT_SCOPE stays at `apps/mobile/lib` for manual full-repo audits (`python3 tools/checks/no_hardcoded_fr.py --scope apps/mobile/lib`). Also extended EXCLUDE_SUBSTRINGS with /lib/models/, /lib/services/, /integration_test/, /tests/checks/fixtures/ for manual-audit sanity. Phase 36 FIX-06 owns the full-codebase i18n audit (~120 strings in services/models per D4)."
  - "Preceding-line override mirrors Plan 34-02 verbatim (`_override_in_preceding_line(lines, idx)` API shape + `_OVERRIDE` regex with `(\\S+(?:\\s+\\S+){2,})` 3-word reason enforcement). This is the Phase 34 convention across GUARD-02 and GUARD-03. Same-line override also accepted via IGNORE_MARKERS + `_OVERRIDE.search(line)` in `_line_is_exempt`. Wave 0 `hardcoded_fr_good_widget.dart` fixture uses preceding-line form verbatim — pytest `test_scan_file_fixture_good_has_no_violations` proves end-to-end."
  - "Whitelist is NOT permissive — fires only when the line has no FR accent AND no FR function-word signal. Without this gate, `Text('ERR: erreur fatale')` would bypass because `_ACRONYM` matches the prefix quote. Negative-signal gating (`_is_whitelisted_string` checks `has_fr_accent` + `has_fr_words` before returning True) closes this loophole. Not explicitly in D-09 text but enforced by scan discipline."
  - "Ordered pattern dispatch with `continue` after first match — 1 row per line, most-specific diagnostic first. `_TEXT_ACCENT` before `_TEXT_CAPITALISED` (both match the same Text() wrapper), `_TITLE_PARAM`/`_LABEL_PARAM` before `_QUOTED_ACCENT` (both match title: named-args with accents), `_QUOTED_FR_WORDS` last (least specific). Ensures `title: 'Bonjour monde'` yields `hardcoded-fr-title`, not `hardcoded-fr-words`."
  - "Real widget sanity check — `python3 tools/checks/no_hardcoded_fr.py --file apps/mobile/lib/widgets/mint_shell.dart` exits 0 on Julien's reference i18n-wired file. No false positives on production code. Glob-scoped pre-commit + existing i18n discipline on mint_shell.dart align; future widget code that adds hardcoded FR will fire on the pre-commit hook."
  - "Lint LOC 262 — slightly over plan's `~250 LOC max` heuristic but in line with Plan 34-02's 255 LOC no_bare_catch.py. Extra ~12 lines are docstring (11 lines for D-08/D-09/D-10 self-documentation) + `_is_whitelisted_string` 2-gate helper (5 lines) + ordered-dispatch case for `_QUOTED_ACCENT` (4 lines) beyond early-ship's 2-pattern baseline. No dead code, no stub, no speculative helper."
  - "Pytest 11/11 in 0.03s — full coverage of D-08/D-09/D-10 axes. `test_flags_text_capitalised_word` / `test_flags_title_param` / `test_flags_label_param` / `test_accent_heuristic_still_flags` cover D-09 FAIL. `test_passes_l10n_call` / `test_whitelist_acronym` / `test_whitelist_numeric` cover D-09 PASS. `test_inline_override_valid` / `test_inline_override_insufficient_reason` cover D-10. `test_scan_file_fixture_bad_has_violations` / `test_scan_file_fixture_good_has_no_violations` cover Wave 0 fixtures. RED phase (against early-ship) had 2 failures on `_flags_title_param` + `_flags_label_param` — these drove the GREEN phase D-09 named-arg pattern additions."

requirements-completed: [GUARD-03]

# Metrics
duration: ~4min
completed: 2026-04-22
---

# Phase 34 Plan 03: GUARD-03 no_hardcoded_fr D-08/D-09/D-10 Lint Summary

**GUARD-03 shipped via D-08 glob-scoped lefthook hook (apps/mobile/lib/{widgets,screens,features}/**/*.dart only): 262-LOC stdlib-only Python lint with 4 D-09 primary patterns (Text capitalised, Text accent, title:, label:) + acronym/numeric whitelist + D-10 preceding-line override mirroring Plan 34-02; 11/11 pytest green in 0.03s; lefthook P95 0.110s with 5 commands + parallel:true (45x headroom vs 5s budget); resolves RESEARCH Open Question 3 without refactoring the early-ship script.**

## Performance

- **Duration:** ~3 minutes 47 seconds
- **Started:** 2026-04-22T20:33:45Z
- **Completed:** 2026-04-22T20:37:32Z
- **Tasks:** 2/2 auto (no checkpoints)
- **Files created:** 2 (test_no_hardcoded_fr.py + 34-03-SUMMARY.md)
- **Files modified:** 3 (no_hardcoded_fr.py, lefthook.yml, lefthook_self_test.sh)
- **Commits:** 3 on `feature/S30.7-tools-deterministes`
  - `1de6c2ba` test(34-03) RED phase — 11 cases; 9/11 pass against early-ship, 2 FAIL drive GREEN
  - `6f58a21f` feat(34-03) GREEN phase — D-08/D-09/D-10 lint, 11/11 green
  - `199f501f` feat(34-03) Task 2 — lefthook wiring + self-test extension

## Accomplishments

- **D-08 glob-scoped pre-commit hook** — `glob: "apps/mobile/lib/{widgets,screens,features}/**/*.dart"` restricts the pre-commit scope to widget code only. lib/l10n / lib/models / lib/services / test / integration_test stay out of scope naturally (outside the glob). Full-codebase i18n audit remains Phase 36 FIX-06 scope (~120 existing strings in services/models per D4). The Python script's DEFAULT_SCOPE stays at `apps/mobile/lib` for manual full-repo audits — resolves RESEARCH Open Question 3 without script refactor.
- **D-09 4 primary patterns** — `_TEXT_ACCENT` (Text with any FR diacritic), `_TEXT_CAPITALISED` (Text with capitalised-word >=6 chars), `_TITLE_PARAM` (named-arg `title:`), `_LABEL_PARAM` (named-arg `label:`). Plus 2 fallback patterns: `_QUOTED_ACCENT` (any quoted literal with FR diacritic, generic) and `_QUOTED_FR_WORDS` (2 FR function words touching, inherited from early-ship). Ordered most-specific → least, first-match-wins per line.
- **D-09 whitelist** — `_ACRONYM` (`['"][A-Z]{2,5}['"]`) + `_NUMERIC` (`['"]\d+['"]`) fire ONLY when the line has no FR accent AND no FR function-word signal. `_is_whitelisted_string()` gates via negative signal check (`has_fr_accent` + `has_fr_words`). Prevents `Text('ERR: erreur grave')` from bypassing via its acronym prefix.
- **D-10 preceding-line override mirrors Plan 34-02** — `// lefthook-allow:hardcoded-fr: <reason>` on the line IMMEDIATELY PRECEDING the flagged line, reason >=3 whitespace-separated words enforced by `_OVERRIDE` regex `(\S+(?:\s+\S+){2,})`. `_override_in_preceding_line(lines, idx)` helper API shape verbatim from no_bare_catch.py. Same-line override also accepted via `_line_is_exempt` IGNORE_MARKERS + `_OVERRIDE.search(line)`.
- **Wave 0 fixtures proven** — `tests/checks/fixtures/hardcoded_fr_bad_widget.dart` FAILS (rc=1, `hardcoded-fr-text: Bonjour tout le monde`). `tests/checks/fixtures/hardcoded_fr_good_widget.dart` PASSES (rc=0) — file has `AppLocalizations.of(context)!.greeting` (exempted by IGNORE_MARKERS) + preceding-line override `// lefthook-allow:hardcoded-fr: debug-only error fallback` above `final debugLabel = 'ERR';` (3-word reason + acronym whitelist both green). Direct-invocation self-test + pytest both cover these.
- **pytest 11/11 green in 0.03s** — all D-09 / D-10 / D-08 axes covered. `test_flags_text_capitalised_word` (Text + capitalised word) + `test_flags_title_param` (title: named-arg) + `test_flags_label_param` (label: named-arg) + `test_accent_heuristic_still_flags` (Text + diacritic) prove D-09 FAIL. `test_passes_l10n_call` (AppLocalizations exempted) + `test_whitelist_acronym` (ERR) + `test_whitelist_numeric` (404) prove D-09 PASS. `test_inline_override_valid` (3-word reason accepted) + `test_inline_override_insufficient_reason` (1-word reason rejected) prove D-10. Wave 0 fixtures covered by `test_scan_file_fixture_bad_has_violations` + `test_scan_file_fixture_good_has_no_violations`.
- **Self-test extended per D-25** — `lefthook_self_test.sh` 4th section added (Plan 03 FAIL + PASS direct-invocation checks against Wave 0 fixtures). Reminder banner updated to cite Plans 01+02+03 (Plans 04-05 still pending). Full self-test rc=0 with all 4 sections green (retention + accent + no_bare_catch + no_hardcoded_fr).
- **Benchmark P95 preserved at 0.110s** with 5 pre-commit commands + parallel:true. 45x headroom vs 5s budget. GUARD-01 success criterion #1 uncompromised. no-hardcoded-fr lint adds negligible cost (simple regex scan, per-file `--file {staged_files}` pattern means zero work on commits that don't touch the widget glob).
- **Self-compliance (Pitfall 8) green** — `accent_lint_fr.py --file tools/checks/no_hardcoded_fr.py` rc=0. Technical English throughout; no FR diagnostics, no ARB i18n. `accent_lint_fr.py --file lefthook.yml` rc=0 (no regression from Plan 02 Pitfall-8 fix).
- **Real widget sanity check** — `python3 tools/checks/no_hardcoded_fr.py --file apps/mobile/lib/widgets/mint_shell.dart` exits 0 on Julien's i18n-wired reference file. Zero false positive on production code. Glob-scoped pre-commit + existing i18n discipline align.

## Task Commits

1. **RED — `1de6c2ba` test(34-03):** add failing tests for no_hardcoded_fr D-08/D-09/D-10
   - Files: `tests/checks/test_no_hardcoded_fr.py` (new, 112 lines, 11 cases)
   - Status: 9/11 PASS against early-ship, 2 FAIL (`test_flags_title_param` + `test_flags_label_param`) — early-ship catches via generic `_QUOTED_FR_WORDS` but diagnostic kind is `words`, not `title`/`label`. Drives GREEN named-arg pattern additions.

2. **GREEN — `6f58a21f` feat(34-03):** implement no_hardcoded_fr.py D-08/D-09/D-10 (GUARD-03)
   - Files: `tools/checks/no_hardcoded_fr.py` (rewritten, 137 → 262 lines)
   - Added: `_TEXT_ACCENT`, `_TEXT_CAPITALISED`, `_TITLE_PARAM`, `_LABEL_PARAM`, `_QUOTED_ACCENT` (generic), `_ACRONYM`, `_NUMERIC`, `_OVERRIDE`, `_is_whitelisted_string`, `_override_in_preceding_line`, extended EXCLUDE_SUBSTRINGS.
   - Verified: 11/11 pytest green 0.03s, bad fixture rc=1, good fixture rc=0, accent self-compliance rc=0, mint_shell.dart scan rc=0 (no false positive), all 8 grep acceptance criteria met.

3. **Task 2 — `199f501f` feat(34-03):** wire no-hardcoded-fr in lefthook + extend self-test
   - Files: `lefthook.yml`, `tools/checks/lefthook_self_test.sh`
   - Verified: `lefthook validate` All good; `grep -c "no-hardcoded-fr:" lefthook.yml` = 1; `grep -c "apps/mobile/lib/{widgets,screens,features}" lefthook.yml` = 1; self-test rc=0 (4 sections green); benchmark P95 0.110s (<<5s); accent lint on lefthook.yml rc=0.

## LOC + API Surface

| File | LOC | Purpose |
|------|-----|---------|
| tools/checks/no_hardcoded_fr.py | 262 | D-08/D-09/D-10 hardcoded-FR lint with 4 primary patterns + 2 fallbacks + acronym/numeric whitelist + preceding-line override |
| tests/checks/test_no_hardcoded_fr.py | 112 | 11 pytest cases covering all D-08/D-09/D-10 axes + Wave 0 fixtures |

**Public API surface of no_hardcoded_fr.py:**
- `scan_file(path: Path) -> List[Tuple[int, str, str]]` — unchanged signature from early-ship (external consumers: `services/backend/app/scripts/ingest_git.py` violations-table ingestor)
- `main() -> int` — argparse entry point (exit 0/1)
- `_collect_paths(scope: List[str]) -> List[Path]` — manual-audit path walker with EXCLUDE_SUBSTRINGS filter
- `_line_is_exempt(line: str) -> bool` — IGNORE_MARKERS + same-line override check
- `_is_whitelisted_string(line: str) -> bool` — acronym/numeric whitelist gated by negative FR signal
- `_override_in_preceding_line(lines: List[str], idx: int) -> bool` — D-10 preceding-line check (mirrors Plan 34-02 `_override_in_preceding`)

## Before/After no_hardcoded_fr.py Pattern List

| Pattern | Early-ship (Phase 30.5 CTX-02) | Plan 34-03 (D-08/D-09/D-10) |
|---------|--------------------------------|------------------------------|
| `_QUOTED_ACCENT` | Present (any quoted literal with diacritic) | Kept as fallback (case: not in Text() wrapper) |
| `_QUOTED_FR_WORDS` | Present (2 FR function words touching) | Kept as final fallback |
| `_TEXT_ACCENT` | — | Added: `Text('...diacritic...')` |
| `_TEXT_CAPITALISED` | — | Added: `Text('<capitalised-word>.{5,}')` |
| `_TITLE_PARAM` | — | Added: `title: '<capitalised>...'` named-arg |
| `_LABEL_PARAM` | — | Added: `label: '<capitalised>...'` named-arg |
| `_ACRONYM` (whitelist) | — | Added: `['"][A-Z]{2,5}['"]` |
| `_NUMERIC` (whitelist) | — | Added: `['"]\d+['"]` |
| `_OVERRIDE` (D-10) | — | Added: `// lefthook-allow:hardcoded-fr: <3+ words>` |
| IGNORE_MARKERS | 8 markers (AppLocalizations, l10n, tr(, // lint-ignore, // ignore:, debugPrint(, print(, assert() | Unchanged (8 markers) |
| EXCLUDE_SUBSTRINGS | /lib/l10n/, /.dart_tool/, /build/, /.git/, /test/ | +/lib/models/, +/lib/services/, +/integration_test/, +/tests/checks/fixtures/ |
| Scope enforcement | Script-internal via DEFAULT_SCOPE | Lefthook glob does it (RESEARCH Open Question 3 resolution) |

## lefthook.yml Diff (no-hardcoded-fr command)

```yaml
pre-commit:
  parallel: true
  skip:
    - merge
    - rebase
  commands:
    # ... memory-retention-gate + map-freshness-hint + accent-lint-fr +
    #     no-bare-catch preserved from Plans 00/01/02 ...

    # ─── Phase 34 GUARD-03 (D-08 glob-scoped, D-09 patterns, D-10 override) ──
    # D-08: glob restricts to widgets/screens/features only -- lib/models,
    # lib/services, lib/l10n, test, integration_test stay out of scope
    # (full-repo i18n audit = Phase 36 FIX-06). The Python script's
    # DEFAULT_SCOPE remains broader for manual `--scope` audits.
    # D-09: catches Text('<capitalised>...'), Text('<accented>'),
    # title: / label: named-args, plus fallback 2-FR-function-words heuristic.
    # Whitelist: short acronyms (<=5 chars), numeric strings.
    # D-10: inline override `// lefthook-allow:hardcoded-fr: <3+ words>` on
    # preceding line (mirrors Plan 34-02 no_bare_catch semantics).
    # fixtures/** excluded per Pitfall 7 (legitimate FR test inputs).
    no-hardcoded-fr:
      run: python3 tools/checks/no_hardcoded_fr.py --file {staged_files}
      glob: "apps/mobile/lib/{widgets,screens,features}/**/*.dart"
      exclude:
        - "tests/checks/fixtures/**"
      tags: [i18n, phase-34]
```

## Benchmark Delta

| State | Commands | P95 (s) | Budget headroom |
|-------|----------|---------|-----------------|
| Wave 0 baseline (Plan 00) | 2 (memory + map-freshness) | 0.120 | 4.88s |
| Plan 01 after GUARD-04 | 3 (+ accent-lint-fr) | 0.100 | 4.90s |
| Plan 02 after GUARD-02 + parallel:true | 4 (+ no-bare-catch) | 0.110 | 4.89s |
| **Plan 03 after GUARD-03** | **5 (+ no-hardcoded-fr)** | **0.110** | **4.89s** |

no-hardcoded-fr adds essentially zero cost — lint runs only when `{staged_files}` matches the widget glob. On a clean tree (no widget files staged), the command early-returns via lefthook's `(skip) no matching staged files` path. On a real widget commit, it scans only the staged file(s) via `--file {staged_files}`. P95 unchanged at 0.110s.

## Self-test tail

```
[self-test] accent_lint_fr: OK (FAIL + PASS cases green)
[self-test] no_bare_catch: scanning known-bad diff...
[self-test] no_bare_catch: scanning known-good diff...
[self-test] no_bare_catch: OK (FAIL + PASS cases green)
[self-test] no_hardcoded_fr: scanning known-bad fixture...
[self-test] no_hardcoded_fr: scanning known-good fixture...
[self-test] no_hardcoded_fr: OK (FAIL + PASS cases green)
self-test: reminder — Phase 34 fixtures under tests/checks/fixtures/ must be
  added to each new lint's lefthook 'exclude:' list (per Pitfall 7).
  Plans 01 + 02 + 03 exclude fixtures; Plans 04-05 must follow.
```

rc=0.

## Per-Decision Coverage

| Decision | Status | Evidence |
|----------|--------|----------|
| D-08 (scope: widgets/screens/features only) | PASS | Lefthook `glob: "apps/mobile/lib/{widgets,screens,features}/**/*.dart"` + EXCLUDE_SUBSTRINGS extended (/lib/models/ + /lib/services/ + /integration_test/ + /tests/checks/fixtures/) for manual `--scope` audits |
| D-09 (4 primary patterns + whitelist) | PASS | `_TEXT_CAPITALISED`, `_TEXT_ACCENT`, `_TITLE_PARAM`, `_LABEL_PARAM` all present (grep counts 2 each); `_ACRONYM` + `_NUMERIC` whitelist with negative-signal gating; `_QUOTED_ACCENT` + `_QUOTED_FR_WORDS` fallbacks preserved |
| D-10 (preceding-line override with >=3-word reason) | PASS | `_OVERRIDE = re.compile(r"//\s*lefthook-allow:hardcoded-fr:\s*(\S+(?:\s+\S+){2,})")` enforces >=3 whitespace-separated words; `_override_in_preceding_line` mirrors Plan 34-02 API shape; `test_inline_override_insufficient_reason` proves 1-word reason fails |
| D-25 (self-test extended with FAIL + PASS) | PASS | `lefthook_self_test.sh` 4th section runs bad fixture (must rc=1) + good fixture (must rc=0); all 4 sections green end-to-end |
| Pitfall 7 (fixture self-regression) | PASS | `tests/checks/fixtures/**` in both lefthook `exclude:` AND lint's EXCLUDE_SUBSTRINGS |
| Pitfall 8 (self-compliance) | PASS | `accent_lint_fr.py --file tools/checks/no_hardcoded_fr.py` rc=0; technical English only, no FR prose, no ARB i18n |
| Pitfall 1 (façade sans câblage) | PASS | Self-test exercises the lint end-to-end (direct `python3 --file` invocation); `lefthook run pre-commit` smoke-test in benchmark proves hook wiring fires |
| RESEARCH Open Question 3 | RESOLVED | Script's DEFAULT_SCOPE stays broader for manual audits; lefthook glob does the D-08 scope restriction for pre-commit. No script refactor needed. |
| GUARD-01 <5s budget preservation | PASS | P95 0.110s with 5 commands + parallel:true — 45x headroom vs 5s budget |

## Decisions Made

None beyond what PLAN.md specified. Two small execution-discretion choices:

1. **Added `_QUOTED_ACCENT` generic pattern** beyond plan's explicit D-09 list. The plan listed 4 primary patterns + 2 whitelist + 1 fallback (`_QUOTED_FR_WORDS`). Added `_QUOTED_ACCENT` as a 5th pattern to catch cases like `final x = 'Créer'` or `const title = 'Sécurité'` (accented literal outside Text() wrapper). Rationale: early-ship already had this pattern; dropping it would be a regression on CTX-02 coverage. Pattern is ordered AFTER `_TEXT_*` and `_*_PARAM` so Text/title/label variants emit their specific diagnostic kind first.

2. **Negative-signal gating in `_is_whitelisted_string`** — whitelist fires only when the line has no FR accent AND no FR function-word signal. Not explicitly mandated by D-09 text, but required for whitelist sanity (otherwise `Text('ERR: erreur grave')` would bypass because `_ACRONYM` matches the 'ERR' quote). Closed this loophole at implementation time.

## Deviations from Plan

None. All 2 tasks executed as planned. 3 commits in sequence (RED test → GREEN lint → Task 2 wiring). No Rule 1/2/3/4 auto-fix escalations. No inherited regressions to close. Plan 34-02 pre-existing lefthook.yml Pitfall-8 remediation held (`accent_lint_fr.py --file lefthook.yml` rc=0 pre- and post- Plan 03 edits).

## Issues Encountered

None. Plan's recommended implementation was near-verbatim correct; small LOC-pressure compression rounds were not needed because the 262 LOC total stayed within normal range (Plan 34-02's no_bare_catch.py is 255 LOC for comparable scope). Pattern discovery was smooth — ordered dispatch with `continue` after first match keeps the scan loop readable at 60 lines.

No blockers, no architectural escalations (Rule 4), no external dependencies.

## User Setup Required

None — all changes are repo-local lint infrastructure. No env vars, no secrets, no external services. Lefthook 2.1.6 already installed on dev box (min_version 2.1.5 in config).

## Threat Model Coverage

| Threat ID | Status | Evidence |
|-----------|--------|----------|
| T-34-02 (override abuse) | mitigated | `_OVERRIDE` regex `(\S+(?:\s+\S+){2,})` enforces >=3-word reason; `test_inline_override_insufficient_reason` proves 1-word reason fails. Override accepted only on same line or immediately preceding line (minimal blast radius, matches Plan 34-02 convention). |
| T-34-04 (lint tampering) | flagged | Plan 34-07 `lefthook-ci.yml` will re-run hooks on CI worktree — tampering visible in PR diff. Not mitigated here; flagged for Plan 07. |
| T-34-05 (parallel index race) | preserved-safe | no-hardcoded-fr is strictly read-only (file reads + regex) — no `.git/index.lock` contention. Plan 02's parallel:true flip remains safe with 5 commands. |
| T-34-07 (fixture self-regression) | mitigated | Fixture paths excluded via TWO layers: lefthook `exclude: [tests/checks/fixtures/**]` + lint's EXCLUDE_SUBSTRINGS includes `/tests/checks/fixtures/`. Belt-and-braces, matches Plan 02 convention. |
| T-34-DoS-regex (ReDoS) | mitigated | All 6 Phase 34 Plan 03 patterns are linear bounded (no nested quantifiers, no backtracking traps). `_TEXT_CAPITALISED` uses `.{5,}?` non-greedy with bounded char class, `_QUOTED_FR_WORDS` uses `\w+` bounded; no patterns of form `(a+)+` or `(a|a)+`. Compiled once at module load. |

## Next Phase Readiness

**Plan 03 unblocks Plans 04-07:**
- **Plan 34-04 (GUARD-05 arb_parity)** inherits the glob-scoped hook pattern for `*.arb` files (different glob, same principle: lefthook glob narrows scope, script stays broader).
- **Plan 34-05 (GUARD-06 proof_of_read)** adds a `commit-msg:` block (D-27 amendment) orthogonal to pre-commit scope; 5 pre-commit commands + 1 commit-msg command after Plan 05.
- **Plan 34-07 (CI thinning + lefthook-ci.yml)** can invoke `bash tools/checks/lefthook_benchmark.sh --assert-p95=5` against the now-stable 0.110s baseline with 5 commands. Plan 34-07 will add `route_registry_parity`, `no_chiffre_choc`, `landing_no_financial_core`, `landing_no_numbers` per D-23 — P95 must stay <5s.

**Phase 36 FIX-06 decoupling confirmed** — the ~120 hardcoded FR strings in services/models (per D4 known gap) remain in-place without blocking commits. Pre-commit glob restricts scope to widgets/screens/features only. FIX-06 can now converge the services/models backlog by batch knowing no new hardcoded FR enters widget code without the override.

**Plan 34-03 completes GUARD-03 (requirements-completed: [GUARD-03])** — 3/8 Phase 34 requirements done (GUARD-04 Plan 01 + GUARD-02 Plan 02 + GUARD-03 Plan 03). Plan 34-04/05/06/07 still pending (GUARD-05 ARB parity, GUARD-06 proof-of-read, GUARD-07 bypass audit, GUARD-08 CI thinning + GUARD-01 full completion).

## Self-Check: PASSED

**Files verified on disk:**
- FOUND: `tools/checks/no_hardcoded_fr.py` (262 LOC, stdlib-only, Python 3.9-compat, self-compliance rc=0)
- FOUND: `tests/checks/test_no_hardcoded_fr.py` (112 LOC, 11 test cases, all green in 0.03s)
- FOUND: `lefthook.yml` (modified — no-hardcoded-fr command block present, validate rc=0)
- FOUND: `tools/checks/lefthook_self_test.sh` (extended with Plan 03 FAIL + PASS cases; Plan 01+02+03 reminder)
- FOUND: `.planning/phases/34-agent-guardrails-m-caniques/34-03-SUMMARY.md` (this file)

**Commits verified:**
- FOUND: `1de6c2ba` — test(34-03): add failing tests for no_hardcoded_fr D-08/D-09/D-10
- FOUND: `6f58a21f` — feat(34-03): implement no_hardcoded_fr.py D-08/D-09/D-10 (GUARD-03)
- FOUND: `199f501f` — feat(34-03): wire no-hardcoded-fr in lefthook + extend self-test

**Hooks + tests green:**
- FOUND: `lefthook validate` -> All good
- FOUND: `bash tools/checks/lefthook_self_test.sh` -> rc=0 (4 sections green)
- FOUND: `bash tools/checks/lefthook_benchmark.sh --assert-p95=5` -> P95 0.110s (<<5s)
- FOUND: `python3 -m pytest tests/checks/test_no_hardcoded_fr.py` -> 11/11 green in 0.03s
- FOUND: `accent_lint_fr.py --file tools/checks/no_hardcoded_fr.py` -> rc=0 (self-compliance)
- FOUND: `accent_lint_fr.py --file lefthook.yml` -> rc=0 (Plan 02 Pitfall-8 fix preserved)
- FOUND: `no_hardcoded_fr.py --file tests/checks/fixtures/hardcoded_fr_bad_widget.dart` -> rc=1
- FOUND: `no_hardcoded_fr.py --file tests/checks/fixtures/hardcoded_fr_good_widget.dart` -> rc=0
- FOUND: `no_hardcoded_fr.py --file apps/mobile/lib/widgets/mint_shell.dart` -> rc=0 (no false positive on real i18n-wired widget)

---
*Phase: 34-agent-guardrails-m-caniques*
*Plan: 03*
*Completed: 2026-04-22*
