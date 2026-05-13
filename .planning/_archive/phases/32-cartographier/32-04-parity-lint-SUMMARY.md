---
phase: 32-cartographier
plan: 04
subsystem: parity-lint
tags: [python, pytest, lint, ci, lefthook, wave-4, phase-32]

# Dependency graph
requires:
  - phase: 32-00-reconcile
    provides: "Authoritative app.dart path list (148 extractions including /admin/routes) + Wave 0 fixture scaffolds"
  - phase: 32-01-registry
    provides: "kRouteRegistry (147 entries) at apps/mobile/lib/routes/route_metadata.dart — the RHS of the parity comparison"
  - phase: 32-03-admin-ui
    provides: "/admin/routes ScopedGoRoute inside if (AdminGate.isAvailable) ...[ guard — requires Category 7 KNOWN-MISS exemption"
provides:
  - "tools/checks/route_registry_parity.py: standalone Python 3.9 lint (stdlib-only, argparse + re + pathlib). Runtime 30ms. Exits 0/1/2 per sysexits.h EX_USAGE."
  - "tools/checks/route_registry_parity-KNOWN-MISSES.md: amended with Category 7 (admin-conditional) + explicit allow-list strategy for Category 5 (nested /profile children)"
  - ".lefthook/route_registry_parity.sh: standalone bash wrapper (NOT wired to lefthook.yml here — Phase 34 scope per D-12 §5)"
  - "tests/checks/test_route_registry_parity.py: 9 pytest cases exercising lint + wrapper end-to-end"
  - "tests/checks/fixtures/parity_drift.dart: populated with marker-block content the lint parses via --dry-run-fixture"
  - "tests/checks/fixtures/parity_known_miss.dart: populated with ternary + dynamic Category 2/3 patterns"
affects:
  - "32-05 (CI + docs + J0): route-registry-parity CI job wires the script into .github/workflows/ci.yml per D-12 §1 — script is the hard dep"
  - "34 Guardrails: lefthook.yml commands block gets `route-registry-parity: run: .lefthook/route_registry_parity.sh` — wrapper is the hard dep"
  - "33 Kill-switches: when /admin/flags lands, maintainer MUST append '/admin/flags' to _ADMIN_CONDITIONAL in the lint + KNOWN-MISSES Category 7 bullet list — enforced by fail-loud drift detection"
  - "Future nested-route additions under /profile (or any parent): MUST update _NESTED_PROFILE_CHILDREN tuple list + KNOWN-MISSES Category 5 bullets, else the lint fails CI"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Stdlib-only Python lint pattern (matches accent_lint_fr.py + no_hardcoded_fr.py): shebang + __future__ annotations + argparse + re + sys.exit + sysexits.h codes. No external deps means zero pip install on CI, Python 3.9/3.11 forward-compat."
    - "Two-sided KNOWN-MISSES allow-list: both the bare-segment side (app.dart) AND the composed-path side (registry) stripped before set comparison. Preserves drift detection for any NEW entry not in the tuple list — unlike one-sided exemption, which would let ghost registry keys go unnoticed."
    - "Marker-block fixture format: `-- BEGIN fake app.dart -- ... -- END fake app.dart --` + same for registry, parsed via non-greedy DOTALL regex. The fixture IS a .dart file (compiles under flutter analyze, though not imported into mint_mobile) — single file does double duty as compilable scaffold + self-contained lint input."
    - "Anti-façade-sans-cablage shell wrapper test: `test_shell_wrapper_invokes_lint_and_propagates_exit_code` runs `bash .lefthook/route_registry_parity.sh` and asserts exit 0 + 'parity OK' literal in stdout. Proves the wrapper actually invokes the Python lint end-to-end, not just ships beside it."

key-files:
  created:
    - tools/checks/route_registry_parity.py
    - .lefthook/route_registry_parity.sh
    - tests/checks/test_route_registry_parity.py
  modified:
    - tools/checks/route_registry_parity-KNOWN-MISSES.md   # + Category 7 + Category 5 allow-list strategy
    - tests/checks/fixtures/parity_drift.dart              # Wave 0 scaffold -> live marker-block fixture
    - tests/checks/fixtures/parity_known_miss.dart         # Wave 0 scaffold -> live ternary + dynamic fixture

key-decisions:
  - "Exemption mechanism chosen (from 3 options in additional_context): explicit allow-list sets `_ADMIN_CONDITIONAL` + `_NESTED_PROFILE_CHILDREN` in the lint source. Rejected (a) regex guard-detection preprocessing (fragile syntax variance) and (c) separate allow-list file (scope bloat). Allow-list is deterministic, auditable, fails loud on new entries not in the list."
  - "Symmetric subtraction for Category 5 nested children: the lint strips bare-segment from app.dart side AND composed `/profile/<segment>` from registry side. Asymmetric subtraction would let a drift where registry has `/profile/foo` but app.dart no longer declares `foo` go undetected."
  - "Fixture mode does NOT apply live KNOWN-MISSES exemptions. The fixture is a closed system; production allow-lists would confuse the drift assertion. This is documented inline in `run_fixture()`."
  - "Dropped plan's `--resolve-nested` flag in favor of static allow-list. Parent-walker would need to balance-match `routes: [...]` nested blocks — real scope creep for a 7-entry problem at HEAD."
  - "Kept Python 3.9 compat strict (no PEP 604 unions, no match/case, no dict|dict merge). Uses `from __future__ import annotations` so `list[...]` style generics defer evaluation — matches existing `accent_lint_fr.py` / `no_hardcoded_fr.py` templates."
  - "Sysexits.h exit codes: 0 OK, 1 drift, 2 usage/argparse/missing-file. argparse returns 2 by default for argument errors, which aligns. Deliberate — keeps CI signal unambiguous."
  - "Extracted paths sorted + deduped via set + sorted() — pytest `test_extract_only_prints_sorted_deduped_paths` asserts both invariants so ordering can never regress."
  - "Shell wrapper uses `exec python3 ...` to propagate signals and exit code correctly. `set -euo pipefail` catches the missing-python3 edge case via explicit `command -v` guard + exit 2."

patterns-established:
  - "Registry parity lints should ship with symmetric allow-list + KNOWN-MISSES.md companion doc. Single source of truth for what's exempt; fail-loud when drift lands that isn't in the list."
  - "Lefthook shell wrappers should be exercised by pytest (not just ship chmod +x). Shell-level façade-sans-cablage is the same bug class as Flutter-level — a wrapper that exists but doesn't invoke what it claims is worse than no wrapper."
  - "Python 3.9-compat lints in tools/checks/: `from __future__ import annotations` + typing.List/Optional/Set/Tuple (not PEP 585 builtins) + argparse stdlib. Template proven by accent_lint_fr.py, no_hardcoded_fr.py, route_registry_parity.py."

requirements-completed: [MAP-04]

# Metrics
duration: 5min
completed: 2026-04-20
---

# Phase 32 Plan 04: Parity Lint Summary

**Route registry parity lint shipped standalone per MAP-04. Regex extracts 148 path literals from app.dart, compares against 147 kRouteRegistry keys; 1 admin-conditional + 7 nested-profile entries exempted symmetrically via explicit allow-list in the lint source (KNOWN-MISSES.md Category 5 + 7) → 140 routes parity OK on pristine HEAD. 9/9 pytest green (including end-to-end shell-wrapper exercise). Runtime 30ms (CI budget 30s). stdlib-only (zero pip install on CI). lefthook.yml + .github/workflows/ci.yml untouched — wiring deferred to Phase 34 + Plan 05 respectively.**

## Live parity lint output (pristine HEAD)

```
$ python3 tools/checks/route_registry_parity.py
[info] extracted 148 path literal(s) from app.dart (ternary=0, dynamic=0 known-miss, category 2/3 skipped)
[info] registry has 147 key(s); 1 admin-conditional + 7 nested-profile entries exempted per KNOWN-MISSES.md
[OK] 140 routes parity OK (after KNOWN-MISSES exemption).
$ echo $?
0
```

Breakdown of the 140 after exemption:
- 148 app.dart extractions
- minus 1 `/admin/routes` (Category 7 admin-conditional)
- minus 7 nested bare segments (`admin-analytics`, `admin-observability`, `byok`, `slm`, `bilan`, `privacy-control`, `privacy`) (Category 5)
- = 140 app.dart comparison paths

- 147 registry keys
- minus 7 composed `/profile/<child>` paths (Category 5, symmetric strip)
- = 140 registry comparison keys

Both sides reduce to 140 symmetrically → parity holds, drift would be caught at the next set operation.

## Fixture coverage

### Drift fixture (`tests/checks/fixtures/parity_drift.dart`)

```
$ python3 tools/checks/route_registry_parity.py --dry-run-fixture tests/checks/fixtures/parity_drift.dart
[fixture] parity_drift.dart: extracted=3 ternary=0 dynamic=0 registry=2
[FAIL] fixture drift — paths in fake app.dart missing from fake registry:
  + /c-drift-only-in-code
$ echo $?
1
```

Proves the lint catches the `app.dart has it, registry doesn't` direction.

### Known-miss fixture (`tests/checks/fixtures/parity_known_miss.dart`)

```
$ python3 tools/checks/route_registry_parity.py --dry-run-fixture tests/checks/fixtures/parity_known_miss.dart
[fixture] parity_known_miss.dart: extracted=0 ternary=1 dynamic=1 registry=0
[OK] 0 routes parity OK (fixture mode).
$ echo $?
0
```

Proves ternary + dynamic path expressions (Category 2 + 3) are structurally invisible to the regex — the lint reports `extracted=0`, the empty fake registry is consistent, parity trivially holds. This is the correct behavior: the regex does not see them, so they cannot false-positive.

### Missing fixture (argparse EX_USAGE)

```
$ python3 tools/checks/route_registry_parity.py --dry-run-fixture /nonexistent/fixture.dart
[FAIL] fixture not found: /nonexistent/fixture.dart
$ echo $?
2
```

## pytest coverage

```
$ python3 -m pytest tests/checks/test_route_registry_parity.py -v
============================= test session starts =============================
platform darwin -- Python 3.9.6, pytest-8.4.2
collected 9 items

test_lint_script_exists_and_is_executable                  PASSED [ 11%]
test_live_parity_clean_exit_zero                           PASSED [ 22%]
test_extract_only_prints_sorted_deduped_paths              PASSED [ 33%]
test_drift_fixture_exits_one_with_diff                     PASSED [ 44%]
test_known_miss_fixture_exits_zero                         PASSED [ 55%]
test_missing_fixture_exits_two                             PASSED [ 66%]
test_banned_terms_absent_from_all_output                   PASSED [ 77%]
test_shell_wrapper_exists_and_is_executable                PASSED [ 88%]
test_shell_wrapper_invokes_lint_and_propagates_exit_code   PASSED [100%]

============================== 9 passed in 0.19s ==============================
```

Coverage summary:
- 2 hygiene tests (script + wrapper exist + executable bit)
- 1 live-HEAD assertion (the gate that proves Plan 01 + Plan 03 kept parity 1:1)
- 1 extraction sanity (sorted + deduped output on --extract-only)
- 2 fixture-mode direction tests (drift exits 1, known-miss exits 0)
- 1 argparse error-path test (missing fixture exits 2 per sysexits.h)
- 1 LSFin compliance test (banned terms absent from all lint output — CLAUDE.md TOP rule 1)
- 1 end-to-end anti-façade test (bash wrapper actually invokes the lint + propagates exit + stdout)

## Shell wrapper

```bash
$ bash .lefthook/route_registry_parity.sh
[info] extracted 148 path literal(s) from app.dart (ternary=0, dynamic=0 known-miss, category 2/3 skipped)
[info] registry has 147 key(s); 1 admin-conditional + 7 nested-profile entries exempted per KNOWN-MISSES.md
[OK] 140 routes parity OK (after KNOWN-MISSES exemption).
$ echo $?
0
```

Proven end-to-end via `test_shell_wrapper_invokes_lint_and_propagates_exit_code`. When Phase 34 wires this into `lefthook.yml`'s `commands:` block, the hook will fire this script on every pre-commit. CI wiring lands in Plan 32-05 via `.github/workflows/ci.yml` per D-12 §1.

## KNOWN-MISSES.md amendments

Category 5 (Nested `routes: [...]`) — amended:
- Removed stale reference to `--resolve-nested` flag (Wave 4 chose static allow-list instead)
- Added explicit `_NESTED_PROFILE_CHILDREN` allow-list strategy documentation with rationale and fail-loud behavior on new entries
- Noted that StatefulShellRoute absolute-path branches (`/home`, `/mon-argent`, `/coach/chat`, `/explore`) do NOT require an allow-list entry — they declare absolute paths (leading `/`), not segments

Category 7 (NEW) — Admin-only compile-conditional routes:
- Added with full rationale (tree-shake + dev-only surface + registry would defeat tree-shake)
- Documented 3-option decision (regex guard detection / separate file / allow-list in source), with allow-list chosen
- Listed `/admin/routes` at L1151 as the single current occurrence
- Documented maintenance policy for Phase 33 `/admin/flags` + future admin routes

## Dependency Graph Impact

**Plan 32-05 (CI + docs + J0) unblocked.** Consumes:
- `tools/checks/route_registry_parity.py` → CI job `route-registry-parity` per D-12 §1 adds to `.github/workflows/ci.yml` (runs on every push, fails PR on drift).
- Phase 32 closure needs this in CI before Phase 32 is considered shipped per ROADMAP Success Criterion 5 (parity lint fails CI on drift).

**Phase 34 (Guardrails) unblocked.** Consumes:
- `.lefthook/route_registry_parity.sh` → Phase 34 GUARD-01 adds the `commands:` entry to `lefthook.yml` per D-12 §5. This plan intentionally did NOT modify `lefthook.yml` (scope discipline, avoid merge conflict with GUARD-02 bare-catch work).

**Future nested/admin routes (cross-phase).** Any new nested child under `/profile` (or any parent) MUST update `_NESTED_PROFILE_CHILDREN`; any new `/admin/*` route (Phase 33 `/admin/flags` etc.) MUST update `_ADMIN_CONDITIONAL`. The lint fails loudly until the allow-list catches up — this is the desired fail-loud behavior (no_shortcuts_ever doctrine).

## Task Commits

Single atomic commit on `feature/v2.8-phase-32-cartographier`:

1. **Task 1: Parity lint + fixtures + shell wrapper + pytest coverage** — `189aa0d6` (feat)

_Plan metadata commit (SUMMARY.md + STATE.md + ROADMAP.md updates) follows this file._

## Decisions Made

- **Allow-list exemption over regex guard detection** — chosen deterministic static lists over fragile parent-walker or guard-detector regex. The 3 options in the prompt's `additional_context` were weighed against scope creep, false-positive risk, and maintenance burden. Static allow-list wins on all three axes for a 7+1 entry problem.
- **Symmetric registry-side + app.dart-side subtraction for Category 5** — asymmetric exemption would mask ghost registry keys. Tuple form `(segment, composed)` in `_NESTED_PROFILE_CHILDREN` makes the pairing explicit and prevents half-updates.
- **Fixture mode skips live allow-lists** — fixtures are synthetic closed systems; applying production exemptions would confuse drift assertions in tests. Documented inline in `run_fixture()`.
- **Dropped `--resolve-nested` plan hint** — would require balanced-bracket walker through arbitrary nesting. Not worth the complexity for 7 current entries, and the allow-list is more readable + more auditable.
- **Python 3.9 strict compat** — keeps dev (3.9.6) == CI (3.11) invariant; zero forward-compat risk. `from __future__ import annotations` + `typing.List/Optional/Set/Tuple` imports (not PEP 585 builtins). Verified via `python3 -m py_compile`.
- **`exec python3 ...` in shell wrapper** — propagates signals + exit code natively without an intermediate process. `set -euo pipefail` + `command -v python3` guard handles missing-interpreter edge case with explicit exit 2.
- **End-to-end shell-wrapper test (anti-façade)** — `test_shell_wrapper_invokes_lint_and_propagates_exit_code` is the most important test in the file. Shell wrappers that ship beside a lint but don't actually invoke it are the `feedback_facade_sans_cablage` pattern at the Bash level. Test proves the wrapper runs the Python and forwards stdout + exit unchanged.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Plan's `_ADMIN_CONDITIONAL` + nested-route strategy under-specified**

- **Found during:** Task 1 RED phase (test_live_parity_clean_exit_zero failed on first lint-draft run).
- **Issue:** The plan's prose `<action>` gave a Python skeleton that detected known-miss PATTERNS (ternary, dynamic) but did not explicitly subtract nested `/profile/<child>` composed keys from the registry side or `/admin/routes` from the app side. First-draft output was `[FAIL] 8 path(s) in app.dart but absent from kRouteRegistry` — correct drift detection, but the pristine HEAD should exit 0 per plan Must-Haves. The plan's `<action>` also did not match its own `<must_haves>` frontmatter ("Parity lint respects KNOWN-MISSES.md categories").
- **Fix:** Added explicit `_ADMIN_CONDITIONAL: Set[str]` and `_NESTED_PROFILE_CHILDREN: List[Tuple[str, str]]` module-level constants + `_apply_known_misses()` helper that strips both sides symmetrically before comparison. Documented both in KNOWN-MISSES.md Categories 5 + 7.
- **Files modified:** `tools/checks/route_registry_parity.py`, `tools/checks/route_registry_parity-KNOWN-MISSES.md`
- **Committed in:** `189aa0d6`

**2. [Rule 2 — Critical] Shell wrapper had no end-to-end test in plan**

- **Found during:** Test drafting phase (Task 1 RED).
- **Issue:** Plan's Test cases 1–5 cover the Python lint thoroughly but did not assert the shell wrapper actually invokes it. Shipping a wrapper that is executable but doesn't run the lint (or swallows exit code) would be a Bash-level façade-sans-câblage bug. Per `feedback_facade_sans_cablage` doctrine, wrappers must be exercised.
- **Fix:** Added two extra pytest cases: `test_shell_wrapper_exists_and_is_executable` (hygiene) and `test_shell_wrapper_invokes_lint_and_propagates_exit_code` (end-to-end, runs `bash .lefthook/route_registry_parity.sh` and asserts both exit code + stdout content propagation). Result: the test file has 9 cases, not the 6 the plan `<acceptance_criteria>` mentioned. This is strictly additive coverage.
- **Files modified:** `tests/checks/test_route_registry_parity.py`
- **Committed in:** `189aa0d6`

**3. [Rule 3 — Blocking] Plan's `--extract-only` test had ambiguous sort vs file-order assertion**

- **Found during:** Test 4 drafting.
- **Issue:** Plan test 4 specifies `--extract-only` prints "only the extracted paths (no comparison), sorted + deduped" but doesn't assert the output invariant. A regression could ship where paths are printed in file-declaration order (not sorted), or with duplicates, and the plan's pytest would silently accept it.
- **Fix:** Pytest asserts both `lines == sorted(lines)` AND `len(lines) == len(set(lines))` explicitly. Either violation fails the test with an actionable message.
- **Files modified:** `tests/checks/test_route_registry_parity.py`
- **Committed in:** `189aa0d6`

---

**Total deviations:** 3 auto-fixed (1 bug, 1 critical-missing-test, 1 blocking). No architectural changes. No user permission required.

## Issues Encountered

- **lefthook retention WARNING (non-blocking):** `MEMORY.md` at 167 lines (target <100). Same warning across Phases 31, 32-00, 32-01, 32-02, 32-03. Not a D-02 failure gate.
- **Non-blocking git identity warning:** same as prior plans (`Committer: Julien <julienbattaglia@Juliens-Mac-mini.local>`). Co-Author trailer correctly carries Claude signature.
- **Flaky golden PNGs unstaged:** pre-existing drift in `apps/mobile/test/goldens/failures/*.png` from prior sessions. Not touched, not staged.
- **32-RESEARCH.md unstaged:** pre-existing modification from prior session (probably Wave 3 carry-over). Not touched, not staged.

## Authentication Gates

None. The lint is purely static (reads app.dart + route_metadata.dart from the local filesystem). No network calls, no API tokens, no Keychain access.

## User Setup Required

None for CI / development use of the lint. The script runs as:

```bash
python3 tools/checks/route_registry_parity.py
```

No virtualenv, no pip install, no Python package managers. Python 3.9+ is the only requirement (macOS dev Python is 3.9.6; CI is 3.11).

The lefthook wrapper is ready for Phase 34 to wire into `lefthook.yml`:

```yaml
# (Phase 34 will add this — NOT shipped here)
pre-commit:
  commands:
    route-registry-parity:
      run: .lefthook/route_registry_parity.sh
      tags: [routes, phase-32]
```

## Known Stubs

None. Every surface is real:
- The Python lint does real regex extraction against the live app.dart + route_metadata.dart.
- The shell wrapper really invokes the Python lint via `exec`.
- The fixtures contain real marker-block content the lint parses end-to-end.
- KNOWN-MISSES.md documents the actual exempted paths and maintenance policy — not placeholders.

## Threat Flags

None new. The lint is a build-time tool — no runtime surface, no network, no storage, no user input. Inherits no existing threat surface. The admin-conditional allow-list is a secondary line of defense behind the compile-time `ENABLE_ADMIN` + runtime `FeatureFlags.isAdmin` double gate (T-32-04 mitigation lives in Plan 32-03 + Plan 32-05 J0).

## Next Phase Readiness

**Plan 32-05 (Wave 5 CI + docs + J0 gates) unblocked.** Consumes:
- `tools/checks/route_registry_parity.py` → `route-registry-parity` CI job in `.github/workflows/ci.yml` per D-12 §1.
- The script is Python 3.11 forward-compat (verified via `from __future__ import annotations` + typing imports, no PEP 604 unions).
- Expected CI runtime: <1s wall-clock (pristine HEAD: 30ms local).

**Phase 34 (Guardrails) unblocked.** Consumes:
- `.lefthook/route_registry_parity.sh` → GUARD-01 wires into `lefthook.yml` `commands:` block. This plan intentionally did NOT modify `lefthook.yml` to avoid merge conflict with GUARD-02 bare-catch work per D-12 §5.

**Phase 33 (Kill-switches) forward-dependency flagged.** When `/admin/flags` lands, the maintainer MUST:
1. Append `'/admin/flags'` to `_ADMIN_CONDITIONAL` in `tools/checks/route_registry_parity.py`
2. Append a bullet to KNOWN-MISSES.md Category 7 occurrences list with line number
3. The lint fails loudly in CI until these updates ship — by design (no_shortcuts_ever doctrine).

**No blockers. No concerns.**

## Self-Check: PASSED

File existence + commit existence + behavior verification:

- `/Users/julienbattaglia/Desktop/MINT/tools/checks/route_registry_parity.py` — FOUND, executable
- `/Users/julienbattaglia/Desktop/MINT/tools/checks/route_registry_parity-KNOWN-MISSES.md` — MODIFIED (7 categories present: 1, 2, 3, 4, 5, 6, 7)
- `/Users/julienbattaglia/Desktop/MINT/.lefthook/route_registry_parity.sh` — FOUND, executable
- `/Users/julienbattaglia/Desktop/MINT/tests/checks/test_route_registry_parity.py` — FOUND
- `/Users/julienbattaglia/Desktop/MINT/tests/checks/fixtures/parity_drift.dart` — MODIFIED (marker-block content live)
- `/Users/julienbattaglia/Desktop/MINT/tests/checks/fixtures/parity_known_miss.dart` — MODIFIED (ternary + dynamic content live)
- Commit `189aa0d6` — FOUND (git log --oneline -3 shows it at HEAD)
- `python3 -m py_compile tools/checks/route_registry_parity.py`: exit 0 — VERIFIED (3.9 compat)
- `python3 tools/checks/route_registry_parity.py`: exit 0, stdout "140 routes parity OK" — VERIFIED
- `python3 tools/checks/route_registry_parity.py --dry-run-fixture tests/checks/fixtures/parity_drift.dart`: exit 1, stderr mentions `/c-drift-only-in-code` — VERIFIED
- `python3 tools/checks/route_registry_parity.py --dry-run-fixture tests/checks/fixtures/parity_known_miss.dart`: exit 0 — VERIFIED
- `python3 -m pytest tests/checks/test_route_registry_parity.py -q`: 9 passed, 0 failed — VERIFIED
- `bash .lefthook/route_registry_parity.sh`: exit 0 — VERIFIED
- `grep -E "^(import|from) " tools/checks/route_registry_parity.py` shows only stdlib (argparse, re, sys, pathlib, typing, __future__) — VERIFIED
- `git diff HEAD~1 lefthook.yml`: empty — VERIFIED (Phase 34 scope)
- `git diff HEAD~1 .github/workflows/ci.yml`: empty — VERIFIED (Plan 05 scope)
- Runtime 30ms (CI budget 30s): 1000x headroom — VERIFIED

---

*Phase: 32-cartographier*
*Plan: 04-parity-lint*
*Completed: 2026-04-20*
