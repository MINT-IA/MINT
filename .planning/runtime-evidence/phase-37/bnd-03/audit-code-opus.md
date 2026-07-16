# MINT External Audit — BND-03 Archive Build + Budget Setup Router Harness

**Scope:** 3 files, 630 changed lines (326 ins / 304 del) vs base `68506813f`. Within the 3000-line budget. Tree is clean (committed).

## Evidence gathered
- **Orchestrator test suite:** `python3 -m pytest tools/checks/tests/test_g1_bnd03_budget_runtime_orchestrator.py` → **42 passed** (134s). This exercises the full happy path, fail-closed matrix, TERM-signal restoration, sanitization, and the new `git archive` → `tar -xf` → physical-build path with faked `git/tar/flutter/codesign/xattr/xcrun`.
- **Router harness change is really wired, not a facade:**
  - `budget_setup_screen.dart:241-245` — save calls `context.pop()` if `canPop()`, else `context.go('/budget')`. The screen genuinely depends on go_router.
  - Real routes exist: `app.dart:1007` `/budget`, `app.dart:1012` `/budget/setup`. `go_router: ^13.2.0` is a real dependency (`pubspec.yaml:18`).
  - Test harness (`provider_bridge_recompute_test.dart:112-136`) supplies `initialLocation: '/budget/setup'` with no back-stack, so `canPop()` is false and the fallback `context.go('/budget')` lands on `budget_route_probe`. The prior `MaterialApp(home:)` form would throw once navigation fired — the change is required, not cosmetic. `addTearDown(router.dispose)` is present.
- **Privacy/sanitization preserved:** new stages `production-export`/`production-extract` route through `sanitize_stage_log`; TERM-signal tests assert `repo`, `HOME`, UDID, `external_root`, `/private/var/folders` are all redacted from the new logs and metadata uses `device_sha256` (raw UDID absent). Archive output is forced external (`case "$output" in "$repo"/*) exit 93`).
- **Build isolation intact:** dangling `apps/mobile/build` symlink after `rm -rf external_build` is still cleaned and the physical original build is restored on every exit path (`_assert_original_build_restored` in success, fail-closed, TERM, and collision tests).

## Findings

### P0 — none
### P1 — none

### P2 (observational, non-blocking)
- **Real-toolchain regeneration of the archive export is unverified by the fakes.** `patrol_bnd03_budget_process_death.sh` now builds production from a `git archive` export that intentionally excludes `ios/Pods`, `ios/Flutter/Generated.xcconfig`, `.dart_tool` (asserted absent at `...:forbidden_export_path` loop). The fake `flutter` only checks these are absent and required inputs present; it does not exercise the real `pod install` / `pub get` regeneration that a live `flutter build ios --simulator` must perform from a clean tree. This matches the stated design (comment: FileProvider-backed checkout, build exact commit in disposable tree), but correctness on a real simulator host is provable only by running the orchestrator end-to-end on macOS with the real toolchain — no evidence for that exists in-repo. Command that would prove it: run `tools/simulator/patrol_bnd03_budget_process_death.sh` against a booted simulator with `PATROL_BIN`/real `flutter` and confirm `production-build.log` shows a successful pod/pub regeneration.

No correctness, routing, privacy, or facade-without-wiring defects found in the reviewed diff. Both the test harness and the orchestrator refactor are backed by real wiring and passing tests.

## Verdict

**PASS**
