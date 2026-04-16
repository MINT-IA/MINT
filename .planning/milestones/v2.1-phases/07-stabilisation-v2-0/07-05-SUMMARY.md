---
phase: 07-stabilisation-v2-0
plan: 05
subsystem: lint-hygiene
tags: [lint, ruff, flutter-analyze, hygiene, stabilisation]
requires: []
provides: [ruff-clean-backend, analyze-clean-mobile-lib]
affects: [services/backend, apps/mobile/lib]
key-files:
  modified:
    - services/backend/app/services/anomaly_detection_service.py
    - services/backend/app/services/bank_import_service.py
    - services/backend/app/api/v1/endpoints/documents.py
    - services/backend/app/api/v1/endpoints/open_banking.py
    - services/backend/app/api/v1/endpoints/scenarios.py
    - services/backend/app/schemas/audit.py
    - services/backend/tests/(18 test files — unused imports)
    - apps/mobile/lib/screens/main_tabs/mint_home_screen.dart
    - apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart
    - apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart
    - apps/mobile/lib/screens/mortgage/affordability_screen.dart
    - apps/mobile/lib/screens/pillar_3a_deep/retroactive_3a_screen.dart
    - apps/mobile/lib/screens/simulator_3a_screen.dart
decisions: []
metrics:
  duration: ~6min
  completed: 2026-04-07
---

# Phase 7 Plan 07-05: Lint & Hygiene Cleanup Summary

One-liner: Backend ruff 43→0 and flutter analyze lib/ 6→0 via mechanical hygiene fixes — zero behavioral changes.

## Results

### STAB-08 — Backend ruff
- **Before:** 43 errors
- **After:** 0 errors (`python3 -m ruff check app/ tests/` → `All checks passed!`)
- **Fixes:** 37 auto-fixed (unused imports/variables, redefinition). 6 manual:
  - `anomaly_detection_service.py:70` — removed dead `amounts` local (F841)
  - `bank_import_service.py:522` — removed dead `currency` local (F841)
  - `test_document_parser.py:783,787` — added `# noqa: E402` to intentional mid-file imports
  - `test_document_scan.py:255,256` — added `# noqa: E402` to intentional mid-file imports
- **Regression check:** `pytest tests/ -q` → **5018 passed, 49 skipped** (no regressions)
- **Commit:** `67c765ee chore(07-05): fix 43 ruff errors (STAB-08)`

### STAB-09 — Flutter analyze lib/
- **Before:** 6 issues (1 warning + 5 info) on `apps/mobile/lib/`
- **After:** `No issues found!`
- **Fixes:**
  - `mint_home_screen.dart:817` — dropped `super.key` on private `_JourneyStepsCard` ctor (unused_element_parameter warning)
  - 5× `SmartDefaultIndicator(...)` → `const SmartDefaultIndicator(...)` in `rente_vs_capital_screen.dart`, `rachat_echelonne_screen.dart`, `affordability_screen.dart`, `retroactive_3a_screen.dart`, `simulator_3a_screen.dart` (prefer_const_constructors info)
- **Regression check:** `flutter test test/widgets/ test/services/` → 7215 passed, 1 failed
  - The single failure (`chat_tool_dispatcher_test.dart` — `returns null for intent key (deferred to Phase 6)`) is **pre-existing** and unrelated to this plan. Verified by stashing lib/ changes and re-running — still fails. It's a stale test from 07-02 (STAB-01) coach tool wiring that now resolves intent to `/rente-vs-capital` instead of null. Logged as out-of-scope.
- **Commit:** `17577a85 chore(07-05): fix flutter analyze warnings on lib/ (STAB-09)`

## Deviations from Plan

None — plan executed exactly as written.

## Deferred Issues

- **[Pre-existing, unrelated to 07-05] Stale test** `apps/mobile/test/services/coach/chat_tool_dispatcher_test.dart` → `ChatToolDispatcher.resolveRoute returns null for intent key (deferred to Phase 6)` asserts `null` but now receives `/rente-vs-capital`. Should be updated as a follow-up to 07-02 STAB-01 wiring (intent→route now supported). Out of scope for 07-05 (lint hygiene only).

## Files Modified

- **Backend:** 24 files (6 app/, 18 tests/)
- **Mobile lib/:** 6 files
- **Total:** 30 files

## Self-Check: PASSED

- Commit `67c765ee` present in `git log`: FOUND
- Commit `17577a85` present in `git log`: FOUND
- `ruff check app/ tests/`: All checks passed
- `flutter analyze lib/`: No issues found
- Backend pytest: 5018 passed (baseline preserved)
