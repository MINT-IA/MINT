---
phase: 34-agent-guardrails-m-caniques
plan: 01
subsystem: infra
tags: [lefthook, accent-lint, guard-04, i18n, pre-commit]

# Dependency graph
requires:
  - phase: 30.5
    provides: tools/checks/accent_lint_fr.py early-ship (CTX-02 ingestion)
  - plan: 34-00
    provides: lefthook.yml schema-valid + tests/checks/fixtures/accent_{bad,good}.dart + conftest.py
provides:
  - GUARD-04 activated — lefthook pre-commit blocks NEW FR accent regressions on .dart/.py/app_fr.arb
  - tools/checks/accent_lint_fr.py PATTERNS reconciled with CLAUDE.md §2 (14 canonical stems, 3 removed, 3 added)
  - tests/checks/test_accent_lint_fr.py 13/13 pytest coverage (cardinality guard + new-stem firing + removed-stem silence + fixture scan + MCP signature guard)
  - lefthook_self_test.sh extended with Plan 01 accent FAIL + PASS cases per D-25
  - Phase 30.7 TOOL-04 parametrize cases updated in lockstep (44/44 tests green)
affects: [34-02, 34-03, 34-04, 34-05, 34-06, 34-07, 36-FIX-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Shell loop wrapper for per-file lint invocation under lefthook `run: |` block (for f in {staged_files}; do ... done) — reusable for any single-file Python lint that doesn't natively accept multi-arg"
    - "Exclude contract extended: tests/checks/fixtures/** + tests/checks/test_accent_lint_fr.py + tools/mcp/mint-tools/tests/** — test files that legitimately contain ASCII-flattened stems as test data must be exempted to prevent Pitfall 7 self-regression"
    - "Cross-file cardinality guard: tests/checks/test_accent_lint_fr.py + tools/mcp/mint-tools/tests/test_{accent_lint_scan_text,check_accent_patterns}.py all assert len(PATTERNS) == 14 — any future drift fires 3 tests simultaneously"

key-files:
  created:
    - tests/checks/test_accent_lint_fr.py
    - .planning/phases/34-agent-guardrails-m-caniques/34-01-SUMMARY.md
  modified:
    - tools/checks/accent_lint_fr.py (PATTERNS list reconciled, docstring updated)
    - lefthook.yml (accent-lint-fr command added under pre-commit.commands)
    - tools/checks/lefthook_self_test.sh (Plan 01 accent FAIL+PASS cases appended before reminder banner)
    - tools/mcp/mint-tools/tests/test_accent_lint_scan_text.py (parametrize reconciled)
    - tools/mcp/mint-tools/tests/test_check_accent_patterns.py (parametrize reconciled)

key-decisions:
  - "CLAUDE.md §2 is authoritative over Phase 30.5 early-ship extras — 3 stems (specialistes/gerer/progres) removed despite firing on existing code, 3 stems (prevoyance/reperer/cle) added per D-11. The early-ship list was a snapshot of MEMORY.md feedback, not the canonical compliance source."
  - "Rule 1 blocking auto-fix: Phase 30.7 TOOL-04 downstream tests (test_accent_lint_scan_text + test_check_accent_patterns) had parametrize cases referencing the 3 removed stems — updated in lockstep with accent_lint_fr.py to keep the MCP tool contract aligned with CLAUDE.md §2. 44/44 MCP tests green post-reconcile."
  - "Rule 2 blocking auto-fix: docstring originally listed the stems verbatim (specialistes/gerer/progres AND prevoyance/reperer/cle) — fired self-compliance (Pitfall 8) because docstring `prevoyance/reperer/cle` matches \\b...\\b regex. Rephrased to refer to CLAUDE.md §2 authoritatively without naming stems inline. Self-compliance rc=0."
  - "Rule 3 blocking auto-fix: lefthook hook fired on legitimate test files containing ASCII stems as test data (MCP tests reference 'creer' / 'decouvrir' etc as parametrize inputs, my own test_accent_lint_fr.py contains CANONICAL_STEMS set). Added tests/checks/test_accent_lint_fr.py + tools/mcp/mint-tools/tests/** + tests/checks/fixtures/** to the exclude list — matches the Pitfall 7 self-regression mitigation pattern established in Wave 0."
  - "Existing-code FIX-07 scope reconfirmed: 899 violations on apps/mobile/lib when scanned full-scope (incl. 32 in generated app_localizations_en.dart using 'prevoyance' as a variable name for the ARB key). Plan 34-01 goal = ACTIVATE the gate to prevent NEW regressions, NOT CONVERGE existing code. FIX-07 Phase 36 owns the convergence sprint."
  - "Benchmark preserved end-to-end: P95 0.100s with 3 commands active (memory-retention-gate + map-freshness-hint + accent-lint-fr) vs Wave 0 baseline 0.120s with 2 commands. Well under 5s budget. GUARD-01 <5s success criterion not compromised."

requirements-completed: [GUARD-04]

# Metrics
duration: ~6min
completed: 2026-04-22
---

# Phase 34 Plan 01: GUARD-04 Accent Lint Activation Summary

**Reconciled accent_lint_fr.py PATTERNS with CLAUDE.md §2 canonical 14 stems (3 added, 3 removed), wired lefthook pre-commit hook scoped to .dart/.py/app_fr.arb with D-12 non-FR ARB exclusions + Pitfall 7 fixture/test exclusions, and updated Phase 30.7 TOOL-04 parametrize cases in lockstep — 44/44 MCP tests + 13/13 new pytest suite green, benchmark preserved at 0.100s.**

## Performance

- **Duration:** ~6 minutes 13 seconds
- **Started:** 2026-04-22T20:06:50Z
- **Completed:** 2026-04-22T20:13:03Z
- **Tasks:** 1/1 auto (no checkpoints)
- **Files created:** 2 (test_accent_lint_fr.py + this SUMMARY.md)
- **Files modified:** 5 (accent_lint_fr.py, lefthook.yml, lefthook_self_test.sh, 2 MCP TOOL-04 test files)
- **Commits:** 2 on `feature/S30.7-tools-deterministes`
  - `613aeb6b` — test(34-01) RED phase
  - `066fb178` — feat(34-01) GREEN phase

## Accomplishments

- **PATTERNS list canonical** — `tools/checks/accent_lint_fr.py` now matches CLAUDE.md §2 exactly. Before: 14 entries (11 canonical + 3 early-ship extras). After: 14 entries (14 canonical). Delta: removed `specialistes`, `gerer`, `progres`; added `prevoyance`, `reperer`, `cle`.
- **GUARD-04 hook live** — `lefthook.yml` pre-commit has a new `accent-lint-fr` command that fires on staged `.dart`/`.py`/`.arb` files, excluding 5 non-FR ARBs (per D-12) + fixtures + test files (per Pitfall 7). Hook fires end-to-end and returns exit 1 on accent violations (verified on a real-path temp Dart file with `creer`).
- **pytest GUARD-04 green** — 13/13 cases cover cardinality (`len(PATTERNS) == 14`), canonical stem set equality, new-stem firing (`prevoyance`/`reperer`/`cle`), removed-stem silence (`specialistes`/`gerer`/`progres`), fixture scan (accent_bad.dart → ≥3 violations, accent_good.dart → 0 violations), and MCP TOOL-04 signature guard.
- **Phase 30.7 TOOL-04 preserved** — MCP wrapper (`tools/mcp/mint-tools/tools/accent.py`) imports `scan_text` from Wave 0 unchanged. 44/44 TOOL-04 tests green after parametrize-case reconciliation (removed 3 old, added 3 new). No duplicate PATTERNS table in the MCP tool module (anti-drift test `test_no_duplicate_pattern_table_in_tool_module` still green).
- **Self-test extended per D-25** — `lefthook_self_test.sh` now runs 2 additional direct-invocation checks (accent_bad fixture must exit 1, accent_good fixture must exit 0) before the Pitfall-7 reminder banner. Plan 00's 30.5 retention-gate test preserved. Full self-test rc=0.
- **Benchmark preserved at P95 0.100s** with 3 commands active (down from 0.120s baseline with 2 commands — GC noise). 50x headroom vs 5s budget. GUARD-01 success criterion #1 uncompromised.
- **Self-compliance (Pitfall 8) green** — `python3 tools/checks/accent_lint_fr.py --file tools/checks/accent_lint_fr.py` exits 0. The reconciled docstring refers to CLAUDE.md §2 authoritatively rather than enumerating stems inline (which would fire `\\bstem\\b` on the lint's own source).

## Task Commits

1. **RED — `613aeb6b` test(34-01):** add failing test for PATTERNS reconciliation w/ CLAUDE.md §2
   - Files: `tests/checks/test_accent_lint_fr.py` (new, 149 lines, 13 cases)
   - Verified: 7/13 failures on current PATTERNS (3 missing stems + 3 removed stems + set-match drift)

2. **GREEN — `066fb178` feat(34-01):** reconcile PATTERNS w/ CLAUDE.md §2 + wire GUARD-04 lefthook
   - Files: `tools/checks/accent_lint_fr.py`, `lefthook.yml`, `tools/checks/lefthook_self_test.sh`, `tools/mcp/mint-tools/tests/test_accent_lint_scan_text.py`, `tools/mcp/mint-tools/tests/test_check_accent_patterns.py`
   - Verified: 13/13 pytest green, 44/44 MCP TOOL-04 green, `lefthook validate` All good, self-test rc=0, benchmark P95 0.100s, self-compliance rc=0, hook fires end-to-end on real `.dart` with `creer` (exit status 1 + 🥊 emoji).

## PATTERNS Before/After Diff

### Before (Phase 30.5 early-ship, commit `066fb178~1`)

```python
PATTERNS: list[tuple[str, str]] = [
    (r"\bcreer\b", "créer"),
    (r"\bdecouvrir\b", "découvrir"),
    (r"\beclairage\b", "éclairage"),
    (r"\bsecurite\b", "sécurité"),
    (r"\bliberer\b", "libérer"),
    (r"\bpreter\b", "prêter"),
    (r"\brealiser\b", "réaliser"),
    (r"\bdeja\b", "déjà"),
    (r"\brecu\b", "reçu"),
    (r"\belaborer\b", "élaborer"),
    (r"\bregler\b", "régler"),
    (r"\bspecialistes?\b", "spécialiste(s)"),   # ← REMOVED
    (r"\bgerer\b", "gérer"),                    # ← REMOVED
    (r"\bprogres\b", "progrès"),                # ← REMOVED
]
```

### After (Phase 34 Plan 01, commit `066fb178`)

```python
PATTERNS: list[tuple[str, str]] = [
    (r"\bcreer\b", "créer"),
    (r"\bdecouvrir\b", "découvrir"),
    (r"\beclairage\b", "éclairage"),
    (r"\bsecurite\b", "sécurité"),
    (r"\bliberer\b", "libérer"),
    (r"\bpreter\b", "prêter"),
    (r"\brealiser\b", "réaliser"),
    (r"\bdeja\b", "déjà"),
    (r"\brecu\b", "reçu"),
    (r"\belaborer\b", "élaborer"),
    (r"\bregler\b", "régler"),
    (r"\bprevoyance\b", "prévoyance"),          # ← ADDED
    (r"\breperer\b", "repérer"),                # ← ADDED
    (r"\bcle\b", "clé"),                        # ← ADDED
]
```

**Cardinality:** 14 → 14 (unchanged count, different set composition). Matches CLAUDE.md §2 byte-exact.

## lefthook.yml Diff (accent-lint-fr command block)

```yaml
    # ─── Phase 34 GUARD-04 (D-11 canonical 14 patterns, D-12 scope) ───
    # Scans staged .dart, .py, .arb for ASCII-flattened FR accents.
    # Exclusions (D-12 + Pitfall 7):
    #  - 5 non-FR ARBs (en/de/es/it/pt) — no FR accents to enforce there.
    #  - tests/checks/fixtures/** — Wave 0 fixtures contain deliberate bad
    #    accents as test input.
    #  - tools/mcp/mint-tools/tests/** — Phase 30.7 TOOL-04 parametrize
    #    cases MUST contain ASCII-flattened stems verbatim ("creer" etc)
    #    to assert scan_text fires. Scanning them would be Pitfall 7.
    #  - tests/checks/test_accent_lint_fr.py — this lint's own pytest
    #    suite contains ASCII stems in its canonical set assertions.
    accent-lint-fr:
      run: |
        rc=0
        for f in {staged_files}; do
          python3 tools/checks/accent_lint_fr.py --file "$f" || rc=1
        done
        exit $rc
      glob: "*.{dart,py,arb}"
      exclude:
        - "apps/mobile/lib/l10n/app_en.arb"
        - "apps/mobile/lib/l10n/app_de.arb"
        - "apps/mobile/lib/l10n/app_es.arb"
        - "apps/mobile/lib/l10n/app_it.arb"
        - "apps/mobile/lib/l10n/app_pt.arb"
        - "tests/checks/fixtures/**"
        - "tests/checks/test_accent_lint_fr.py"
        - "tools/mcp/mint-tools/tests/**"
      tags: [i18n, phase-34]
```

30.5 skeleton preserved verbatim (memory-retention-gate + map-freshness-hint present and firing on every pre-commit run — GUARD-01 non-regression test #1).

## Benchmark Delta

| State | Commands | P95 (s) | Budget headroom |
|-------|----------|---------|-----------------|
| Wave 0 baseline | 2 (memory-retention-gate + map-freshness-hint) | 0.120 | 4.88s |
| Plan 01 after GUARD-04 | 3 (+ accent-lint-fr) | 0.100 | 4.90s |

No regression. In fact slight improvement (likely GC/file-cache noise). accent-lint-fr adds ~0.02-0.03s per invocation on a typical staged diff — well within RESEARCH §Pattern 6 estimates (regex lints 100-500ms on typical diff; our diff is small).

## Self-test tail (proves FAIL + PASS cases land)

```
┃  memory-retention-gate ❯
retention: FAIL — 1 non-whitelisted file(s) in topics/ have mtime >30d...
exit status 1
self-test: OK — lefthook caught the stale fixture as expected (exit 1)
[self-test] accent_lint_fr: scanning known-bad fixture...
[self-test] accent_lint_fr: scanning known-good fixture...
[self-test] accent_lint_fr: OK (FAIL + PASS cases green)
self-test: reminder — Phase 34 fixtures under tests/checks/fixtures/ must be
  added to each new lint's lefthook 'exclude:' list (per Pitfall 7).
  Plan 01 accent-lint-fr command excludes fixtures; Plans 02-05 must follow.
```

rc=0.

## Existing-Code FIX-07 Catalog (out-of-scope per plan design)

Running `python3 tools/checks/accent_lint_fr.py --scope apps/mobile/lib` reports **899 existing violations** including 32 in `apps/mobile/lib/l10n/app_localizations_en.dart` (GENERATED by `flutter gen-l10n` — uses `prevoyance` as a variable name because the ARB key is `prevoyance`). These are **FIX-07 Phase 36 scope**, NOT a Plan 34-01 blocker. The GUARD-04 hook correctly prevents NEW violations from entering on staged files via the glob filter (only scans changed-files, never full-repo).

Per Plan `<important_notes>`: "Plan 34-01 goal is to ACTIVATE the gate, not CONVERGE existing code. Document the failure count in SUMMARY ("accent_lint_fr fires on N existing files — FIX-07 scope") and continue — do NOT attempt to fix accents across the codebase in this plan."

**Flag for FIX-07 Phase 36:** 899 ASCII-flattened FR stems on `apps/mobile/lib`. Generated `app_localizations_en.dart` file is the easy-win top-offender (32 violations from `prevoyance` used as variable name in auto-gen code — fixable by either accenting the ARB key OR excluding generated files from the lint default scope).

## Per-Decision Coverage

| Decision | Status | Evidence |
|----------|--------|----------|
| D-11 (CLAUDE.md §2 canonical 14 patterns) | ✓ | `len(PATTERNS) == 14`, `test_pattern_set_matches_canonical` green, docstring cites CLAUDE.md §2 as authoritative source |
| D-12 (scope .dart/.py/app_fr.arb, 5 non-FR ARB excluded) | ✓ | `glob: "*.{dart,py,arb}"` + 5 explicit `exclude:` entries for app_{en,de,es,it,pt}.arb |
| D-25 (self-test extended with FAIL + PASS cases) | ✓ | 2 new direct-invocation checks in `lefthook_self_test.sh` before the reminder banner, self-test rc=0 |
| Pitfall 7 (fixtures exclude) | ✓ | `tests/checks/fixtures/**` + `tests/checks/test_accent_lint_fr.py` + `tools/mcp/mint-tools/tests/**` all in exclude list |
| Pitfall 8 (self-compliance) | ✓ | `accent_lint_fr.py --file <self>` exits 0; docstring rephrased to avoid `\\bstem\\b` matches |
| RESEARCH Open Question 2 (reconcile vs extend) | ✓ | CLAUDE.md §2 authoritative set chosen; 3 extras removed, 3 missing added (union-towards-canonical) |
| GUARD-01 <5s budget preservation | ✓ | Benchmark P95 0.100s with 3 commands (was 0.120s with 2) — no regression |

## Decisions Made

None beyond what PLAN.md specified. Three small execution-discretion choices:

1. **Exclude `tools/mcp/mint-tools/tests/**` (directory-wide)** rather than the three individual test file paths. The directory houses tests for the MCP TOOL-04 wrapper which, by design, MUST contain ASCII-flattened stems as parametrize inputs (that's the whole point of a lint test). Future tests added there will inherit the exemption automatically. Matches the fixture-directory exclusion philosophy established by Wave 0.

2. **Exclude `tests/checks/test_accent_lint_fr.py` as an explicit file (not `tests/checks/**`)** — only this one file contains ASCII stems in its CANONICAL_STEMS set. Other future tests in `tests/checks/` should be scanned (they'd only hit the lint if THEY write accent-violating text, which is a real violation). Narrow exclusion reduces blast radius.

3. **Rephrase docstring to reference CLAUDE.md §2 authoritatively** instead of listing stems inline. Any approach that names the stems in prose would re-trigger the `\\bstem\\b` match on the docstring itself (Pitfall 8 self-regression). Using "3 extras" / "3 canonical patterns" without naming them preserves auditability (CLAUDE.md §2 is the single source of truth).

## Deviations from Plan

**Rule 1 auto-fix:** Phase 30.7 TOOL-04 downstream test files (`tools/mcp/mint-tools/tests/test_accent_lint_scan_text.py` and `test_check_accent_patterns.py`) had parametrize cases referencing the 3 removed stems (`specialiste`, `gerer`, `progres`). RED-phase test run exposed 6 MCP test failures directly caused by the PATTERNS reconcile in `accent_lint_fr.py`. Updated both parametrize blocks in lockstep with matching comments explaining the D-11 reconciliation. This prevents an MCP tool contract mismatch between `scan_text` behaviour and the tests that assert it. Both test files staged and committed alongside `accent_lint_fr.py` in the GREEN phase commit `066fb178`.

**Rule 2 auto-fix (Pitfall 8 self-compliance):** the initial reconciliation docstring enumerated the stems inline ("3 extras (specialistes/gerer/progres) and was missing 3 canonical patterns (prevoyance/reperer/cle)"). The `prevoyance`, `reperer`, `cle` stems then fired against the docstring itself when running self-compliance (`accent_lint_fr.py --file <self>` exited 1). Rephrased to reference CLAUDE.md §2 authoritatively without naming stems in the docstring body. Self-compliance passes cleanly.

**Rule 3 auto-fix (blocking commit-time lint failure):** the GREEN-phase commit initially FAILED because the lefthook `accent-lint-fr` hook fired on two legitimate test files in the staged set. The MCP TOOL-04 tests contain ASCII stems as parametrize test inputs (e.g., `("creer", "créer")`), and my own GUARD-04 pytest file contains the CANONICAL_STEMS set with all 14 ASCII stems as string literals. Both are mandatory parts of the lint's test infrastructure — they MUST contain ASCII stems verbatim to assert lint behaviour. Expanded the lefthook `exclude:` list to include `tests/checks/test_accent_lint_fr.py` + `tools/mcp/mint-tools/tests/**` before re-committing. This is the same class of mitigation as Wave 0's `tests/checks/fixtures/**` exclusion (Pitfall 7). Matches the documented self-test reminder banner pattern.

No architectural (Rule 4) deviations. All 3 Rule 1-3 auto-fixes tracked inline in this section.

## Issues Encountered

**Issue 1:** Initial GREEN-phase commit failed because the accent-lint-fr hook fired on its own test infrastructure (resolved via Rule 3 exclude-list expansion — see Deviations).

**Issue 2:** Self-compliance fired on docstring prose enumerating the stems (resolved via Rule 2 rephrase — see Deviations).

**Issue 3:** Pre-existing iCloud duplicate directories + files under `tools/mcp/mint-tools/tests/` (none actually, but broader `.claude/worktrees/agent-ae615269/...`) NOT touched — out of scope per CONTEXT §Duplicates-to-watch.

No unplanned work required beyond the three auto-fixed deviations above.

## User Setup Required

None — all changes are repo-local. No env vars, no secrets, no external services. Lefthook already installed (version 2.1.6 on dev box, min_version 2.1.5 in config).

## Threat Model Coverage

| Threat ID | Status | Evidence |
|-----------|--------|----------|
| T-34-01 (PATTERNS drift) | mitigated | `test_pattern_count_matches_canonical` + `test_pattern_set_matches_canonical` in tests/checks/ + `test_pattern_count_matches_claude_md_section_2` in tools/mcp/mint-tools/tests/ — any future drift fails 3 tests simultaneously |
| T-34-03 (scan_text signature break) | mitigated | `test_scan_text_signature_returns_tuples_of_three` locks `(int, str, str)` return shape; Phase 30.7 TOOL-04 MCP wrapper continues to destructure `(lineno, snippet, raw_pattern)` without change |
| T-34-08 (self-compliance) | mitigated | `accent_lint_fr.py --file <self>` exits 0; docstring rephrased to avoid `\\bstem\\b` self-matches |
| T-34-07 (fixture self-regression, Pitfall 7) | mitigated | lefthook exclude: list documents the contract in inline comments; self-test reminder banner reinforces it for Plans 02-05 |

## Next Phase Readiness

**Plan 01 unblocks nothing — GUARD-04 is standalone and zero-risk by design (D-11 "déjà existant, à activer").**

**Plan 02 (GUARD-02 no_bare_catch) readiness:** pattern established by Plan 01 is reusable — single lefthook command under `pre-commit.commands:` with glob + exclude list. Wave 0's `conftest.py::tmp_git_repo` fixture available for Plan 02's diff-only mode tests. Pitfall 7 contract (fixtures under `tests/checks/fixtures/**` must be in exclude list) confirmed viable end-to-end here — Plan 02 inherits the same discipline.

**Flip `parallel: true`:** deferred to Plan 02 per RESEARCH Pattern 6 (wait until no-bare-catch, a read-only lint, lands to validate race-safety across 3 lints simultaneously).

**FIX-07 Phase 36 backlog:** 899 existing violations catalogued above. The lint is now the moving-target guard — FIX-07 can batch-converge the existing code knowing no NEW violations enter on staged diffs.

## Self-Check: PASSED

**Files verified on disk:**
- FOUND: `tests/checks/test_accent_lint_fr.py` (149 lines, 13 test cases)
- FOUND: `tools/checks/accent_lint_fr.py` (modified, PATTERNS list reconciled)
- FOUND: `lefthook.yml` (accent-lint-fr command added, validates green)
- FOUND: `tools/checks/lefthook_self_test.sh` (Plan 01 accent cases appended)
- FOUND: `tools/mcp/mint-tools/tests/test_accent_lint_scan_text.py` (parametrize reconciled)
- FOUND: `tools/mcp/mint-tools/tests/test_check_accent_patterns.py` (parametrize reconciled)

**Commits verified:**
- FOUND: `613aeb6b` — test(34-01): add failing test for PATTERNS reconciliation w/ CLAUDE.md §2
- FOUND: `066fb178` — feat(34-01): reconcile PATTERNS w/ CLAUDE.md §2 + wire GUARD-04 lefthook

**Hooks + tests green:**
- FOUND: `lefthook validate` → All good
- FOUND: `bash tools/checks/lefthook_self_test.sh` → rc=0
- FOUND: `bash tools/checks/lefthook_benchmark.sh` → P95 0.100s (<<5s)
- FOUND: `pytest tests/checks/test_accent_lint_fr.py` → 13/13 green
- FOUND: `pytest tools/mcp/mint-tools/tests/test_accent_lint_scan_text.py + test_check_accent_patterns.py` → 44/44 green
- FOUND: `accent_lint_fr.py --file <self>` → rc=0 (self-compliance)

---
*Phase: 34-agent-guardrails-m-caniques*
*Plan: 01*
*Completed: 2026-04-22*
