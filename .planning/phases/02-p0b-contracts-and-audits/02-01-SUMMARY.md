---
phase: "02-p0b-contracts-and-audits"
plan: "01"
subsystem: voice
tags: [contract, codegen, ci, voice-cursor]
requires: []
provides:
  - VoiceCursorContract v0.5.0 (single source of truth)
  - Generated Dart enums + matrix (apps/mobile/lib/services/voice/voice_cursor_contract.g.dart)
  - Generated Python Enums + matrix (services/backend/app/schemas/voice_cursor.py)
  - resolveLevel pure function (Dart)
  - CI contracts-drift gate
affects:
  - .github/workflows/ci.yml (new contracts-drift job; backend + flutter now depend on it)
tech_stack_added:
  - Hand-rolled JSON-driven codegen (no build_runner, no datamodel-code-generator at pipeline level)
key_files_created:
  - tools/contracts/voice_cursor.json
  - tools/contracts/generate_dart.py
  - tools/contracts/generate_python.py
  - tools/contracts/regenerate.sh
  - tools/contracts/README.md
  - apps/mobile/lib/services/voice/voice_cursor_contract.dart
  - apps/mobile/lib/services/voice/voice_cursor_contract.g.dart
  - apps/mobile/test/services/voice/voice_cursor_contract_test.dart
  - services/backend/app/schemas/voice_cursor.py
  - services/backend/tests/test_voice_cursor_schema.py
  - services/backend/requirements-dev.txt
key_files_modified:
  - .github/workflows/ci.yml
decisions:
  - Hand-rolled Pydantic emitter instead of datamodel-code-generator (deterministic output for drift gate, hermetic toolchain).
  - Dart identifier mapping: contract strings (N1/G1/new) → Dart-safe (n1/g1/relNew) to satisfy reserved keywords + camelCase lints.
  - 27 matrix cells derived from MINT_DESIGN_BRIEF_v0.2.3 §L1.6 (G1/new=N1, G2/new=N2, G3/new=N4 with floor-aware preferenceCap).
metrics:
  duration_min: 35
  tests_dart: 96
  tests_python: 9
  commits: 3
  completed: 2026-04-07
---

# Phase 02 Plan 01: VoiceCursorContract + Codegen + CI Drift Guard Summary

## One-liner
Single source of truth for MINT voice intensity (5 levels × 3 gravities × 3 relations × 3 preferences) with hand-rolled Dart/Python codegen, a `resolveLevel` pure function implementing the locked precedence cascade, and a CI gate that fails on any drift.

## What landed

1. **`tools/contracts/voice_cursor.json` (v0.5.0, frozen)** — 27-cell matrix + caps + sensitive topics + narrator wall exemptions + 6-stage precedence cascade.
2. **Hand-rolled codegen** — `generate_dart.py` and `generate_python.py` emit deterministic, banner-stamped consumer files with stable key ordering. `regenerate.sh` runs both. `README.md` documents the workflow.
3. **Dart wrapper + tests** — `voice_cursor_contract.dart` exposes `resolveLevel({gravity, relation, preference, sensitiveFlag, fragileFlag, n5Budget})`. 96 unit tests across 8 groups verify the cascade exhaustively.
4. **Python smoke test** — 9 tests prove the generated Pydantic-compatible Enum module imports, the matrix is complete, and the doctrinal anchors (deuil/divorce/perteEmploi/maladieGrave) are present.
5. **CI drift gate** — new `contracts-drift` job in `.github/workflows/ci.yml`, declared as `needs:` for both `backend` and `flutter` jobs. Runs `regenerate.sh` then `git diff --exit-code` against the three tracked artifacts.

## Precedence cascade (locked)

1. `sensitivityGuard` — sensitive topics cap at N3 (anti-shame doctrine, never N4/N5).
2. `fragilityCap` — user-declared fragile mode caps at N3 for 30 days.
3. `n5WeeklyBudget` — N5 candidates downgrade to N4 when weekly budget exhausted.
4. `gravityFloor` — G3 never below N2 (re-applied after every cap).
5. `preferenceCap` — soft → N3, direct → no cap, unfiltered → N5 allowed.
6. `matrixDefault` — fall back to the matrix lookup.

## Verification

| Check | Result |
|---|---|
| `bash tools/contracts/regenerate.sh && git diff --exit-code` | clean (drift gate green) |
| `flutter test test/services/voice/voice_cursor_contract_test.dart` | **+96 / 96 passed** |
| `flutter analyze lib/` | **0 issues** |
| `pytest services/backend/tests/test_voice_cursor_schema.py -q` | **9 passed** |
| `python3 -c "import yaml; ..."` (CI yaml parses + needs:) | OK |

## Commits

| # | Hash | Message |
|---|---|---|
| 1 | `4c7cedaf` | feat(p0b-01): add VoiceCursorContract source of truth (5 levels + matrix) |
| 2 | `b6e154d9` | feat(p0b-01): add resolveLevel pure fn + 96 unit tests for VoiceCursorContract |
| 3 | `030ec304` | feat(p0b-01): add CI drift guard + Python schema smoke test for VoiceCursorContract |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Hand-rolled Pydantic emitter instead of `datamodel-code-generator`**
- **Found during:** Task 1
- **Issue:** The plan specified shelling out to `datamodel-code-generator==0.25.*` for Python codegen, but its output formatting changes between minor versions and would constantly red-build the drift gate. It also adds a runtime dep where the contract is a frozen enum + matrix that needs no JSON-Schema → Pydantic round-tripping.
- **Fix:** Wrote a ~70-LOC hand-rolled emitter (`tools/contracts/generate_python.py`) producing deterministic Python with `Enum` + `Final[...]` annotations + the same `GENERATED — DO NOT EDIT` banner. `datamodel-code-generator==0.25.*` is still pinned in `services/backend/requirements-dev.txt` for ad-hoc dev exploration but is **not** invoked by `regenerate.sh`. Rationale documented in script docstring + `tools/contracts/README.md`.
- **Files modified:** `tools/contracts/generate_python.py`, `tools/contracts/README.md`, `services/backend/requirements-dev.txt`
- **Commit:** `4c7cedaf`

**2. [Rule 1 - Bug] Dart identifier mapping for reserved keyword + camelCase lints**
- **Found during:** Task 1 first regen
- **Issue:** The contract uses `new` as a relation value and `N1`/`G1` as level/gravity values. `new` is a reserved Dart keyword and uppercase enum values violate `constant_identifier_names`.
- **Fix:** Added `_DART_IDENT` mapping in `generate_dart.py`: `new → relNew`, `N1..N5 → n1..n5`, `G1..G3 → g1..g3`. Identifiers stay machine-readable on the Dart side; the underlying contract strings remain canonical (and Python keeps `N1`/`G1`/`new` since none collide there).
- **Files modified:** `tools/contracts/generate_dart.py`
- **Commit:** `4c7cedaf`

### Auth gates
None.

## Known Stubs
None. Every artifact is wired and verified.

## Threat Flags
None. The contract introduces no new network surface; `resolveLevel` is a pure client-side advisory function. T-02-04 (n5WeeklyBudget bypass) remains a Phase 11 server-side concern as planned.

## Self-Check: PASSED
- tools/contracts/voice_cursor.json — FOUND
- tools/contracts/generate_dart.py — FOUND
- tools/contracts/generate_python.py — FOUND
- tools/contracts/regenerate.sh — FOUND
- tools/contracts/README.md — FOUND
- apps/mobile/lib/services/voice/voice_cursor_contract.dart — FOUND
- apps/mobile/lib/services/voice/voice_cursor_contract.g.dart — FOUND
- apps/mobile/test/services/voice/voice_cursor_contract_test.dart — FOUND
- services/backend/app/schemas/voice_cursor.py — FOUND
- services/backend/tests/test_voice_cursor_schema.py — FOUND
- services/backend/requirements-dev.txt — FOUND
- .github/workflows/ci.yml (modified) — FOUND
- Commit 4c7cedaf — FOUND
- Commit b6e154d9 — FOUND
- Commit 030ec304 — FOUND
