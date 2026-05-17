---
phase: mint-data-architecture-v1-01-calc-engine-canonical
plan: 04
subsystem: codegen
tags: [d-08, d-16, regulatory-registry, codegen, dart, lefthook, github-actions, aging-policy, sha256, raw-string-jsondecode, tdd]

# Dependency graph
requires:
  - phase: mint-data-architecture-v1-01-calc-engine-canonical
    provides: "Plan 01 measurement script — _build_payload(today) serialisation pipeline replicated in --source local."
  - phase: mint-data-architecture-v1-01-calc-engine-canonical
    provides: "Plan 02 doctrine + skill — names regulatory_constants.g.dart as the D-16 codegen target path."
  - phase: mint-data-architecture-v1-01-calc-engine-canonical
    provides: "Plan 03 endpoints — /api/v1/regulatory/constants/snapshot consumed by --source staging."
  - phase: mint-calc-engine-v1
    provides: "RegulatoryRegistry.instance() + version_hash(today) + is_active(today) + .to_dict() — reused for the local pipeline."
provides:
  - "tools/codegen/regulatory_constants_to_dart.py — codegen CLI with --source local|staging + --check / --write + --aging-state-file + --json."
  - "apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart — first committed artifact ; 31 lines ; 44 065 bytes ; raw-string + jsonDecode pattern ; baked version_hash + _payloadIntegrityHash."
  - "lefthook.yml regulatory-codegen-check pre-commit entry — D-16 HARD local --check ; narrow-globbed on 3 file pointers."
  - ".github/workflows/regulatory-codegen.yml — PR Action with concrete 7/14/28-day aging escalation (UP probe → L1 PR comment → L2 auto-issue → L3 HARD BLOCK exit 1)."
  - ".planning/state/regulatory-codegen-aging.json — initial seeded state ({consecutive_down_days:0, escalation_level:0}) committed for visibility."
  - "+14 backend tests (8 codegen + 6 integration) + 3 Dart tests = 17 new tests."
  - "Plan 05 D-12 constants-drift lint transitions from MISSING-GENERATED-FILE → OK now that the canonical Dart artifact exists."
affects:
  - mint-data-architecture-v1-01-calc-engine-canonical/Plan 05 (D-12 constants-drift parity lint — was emitting MISSING-GENERATED-FILE, now exits OK with this plan's artifact at the canonical path)
  - mint-data-architecture-v1-02 (event-log + projection — Phase 02 first-migration PR per D-11 promotes Plan 05 to HARD via --hard ; the codegen + this workflow's HARD-BLOCK ceiling stay as-is)
  - future runtime D-08 delta-check (mobile launches → /version → /snapshot if mismatch → cache) — the regulatoryConstantsVersionHash constant IS the comparison anchor

# Tech tracking
tech-stack:
  added: []  # No new deps — stdlib only (urllib.request, hashlib, json, argparse, datetime, pathlib).
  patterns:
    - "Raw-string + jsonDecode Dart literal embedding : const String _snapshotJson = r'''<json>'''; final Map<String, dynamic> snapshot = jsonDecode(_snapshotJson) as Map<String, dynamic>. Sidesteps every Dart literal-escaping edge case (codex MEDIUM #3 resolved). Safe because deterministic JSON output cannot contain '''."
    - "Two cohabitating hash constants : regulatoryConstantsVersionHash (echoes backend) + _payloadIntegrityHash (SHA-256 of embedded JSON body). --check verifies BOTH ; integrity hash detects body tampering even when version_hash literal looks correct (codex MEDIUM #4 resolved)."
    - "Aging state machine as pure function compute_escalation_level(days) → 0/1/2/3 ; load/save_aging_state helpers ; missing-file returns defaults so CI never crashes on first run."
    - "Network-free --check by contract (Karpathy #2 simplicity) ; only --write resolves --source staging. Pre-commit hook stays fast + offline."
    - "Staging-source failure path falls back to local + updates aging state in the same call — CI keeps shipping while drift visibility is preserved across days."
    - "--json mode emits machine-readable status per invocation so CI workflows can parse aging level + version_hash without grepping stderr prose."

key-files:
  created:
    - "tools/codegen/regulatory_constants_to_dart.py (476 lines)"
    - "apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart (31 lines / 44 065 bytes)"
    - "apps/mobile/test/financial_core/generated/regulatory_constants_generated_test.dart (43 lines, 3 tests)"
    - "services/backend/tests/test_regulatory_codegen_script.py (244 lines, 8 tests)"
    - "services/backend/tests/test_regulatory_codegen_integration_p04.py (134 lines, 6 tests)"
    - ".github/workflows/regulatory-codegen.yml (155 lines)"
    - ".planning/state/regulatory-codegen-aging.json (seeded state)"
    - ".planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/01-04-SUMMARY.md"
  modified:
    - "lefthook.yml (+20 lines : regulatory-codegen-check pre-commit block inserted before plan-05 regulatory_constants_drift)"

key-decisions:
  - "Scope is REGULATORY CONSTANTS ONLY — doctrinal codegen DROPPED per codex HIGH #4 (scope creep). Doctrinal constants stay Dart-side with their own version field per D-13 ; future phase if needed."
  - "Raw-string + jsonDecode pattern for the Dart literal — eliminates every escape edge case. The defensive check `if \"'''\" in json_body: raise` ensures we fail loud rather than corrupt the file if a future param value ever introduced apostrophe sequences (unreachable for deterministic JSON output, but the guard is cheap)."
  - "Two baked hashes (version_hash from registry + _payloadIntegrityHash SHA-256 of body) — version_hash detects upstream registry drift ; integrity hash detects local body tampering. Both must match in --check, distinct error messages name which one failed."
  - "Aging state machine is a pure function plus 3 helpers. The state file is committed for visibility (.planning/state/regulatory-codegen-aging.json), not gitignored — codex HIGH #3 mitigation requires the aging level to be auditable, not transient."
  - "--check is network-free by contract — pre-commit cannot afford to depend on staging being up. The CI workflow runs the network-dependent --source staging variant ; the local hook only runs --source local."
  - "Lefthook entry is narrow-globbed on 3 file pointers only (backend regulatory/**, generated Dart, codegen script) — keeps SOFT-WARN-style noise floor low and only fires when files that could actually create drift are touched."
  - "Generated file added `unused_element` to ignore_for_file — the _payloadIntegrityHash literal is consumed by the Python --check via regex extraction, not by Dart code at runtime. The integrity hash IS the contract ; Dart never reads it. Without the suppression dart analyze flagged it, with the suppression dart analyze is clean."
  - "Dart test imports `package:mint_mobile/...` (the actual pubspec.yaml name) — plan template said `package:mint/...` which would have broken the test. Fixed silently as Rule 1 (bug in plan template, not in implementation choice)."

patterns-established:
  - "Pattern : codegen with --check/--write modes + integrity hash + version hash + JSON body raw-string embedding. Reusable for any other constants table that must ship offline-first in a mobile bundle (Phase 02 doctrinal constants may follow this template if D-13 promotion ever needs it)."
  - "Pattern : aging state machine (compute_escalation_level pure + load/save helpers) for any CI gate that depends on an external resource being up. The state file is the audit trail ; the workflow is the trigger."
  - "Pattern : staging-source with graceful local fallback in the SAME CLI call. Caller doesn't need orchestration ; the codegen handles the failover + aging-state update atomically."

requirements-completed: [D-08, D-13-clarification-doctrinal-out-of-scope, D-16, planner-discretion-aging-policy-7-14-28]

# Metrics
duration: ~17min
completed: 2026-05-17
---

# Phase mint-data-architecture-v1-01 Plan 04 — Mobile codegen for regulatory snapshot

**`tools/codegen/regulatory_constants_to_dart.py` ships with `--source local|staging`, `--check / --write`, integrity-hash tamper detection, and a concrete 7/14/28-day staging-aging policy. First generated `regulatory_constants.g.dart` committed (44 065 bytes, version_hash `b2ae1c9ae067…b1fb07`, 103 active params across 27 jurisdictions). Lefthook D-16 HARD local --check + `.github/workflows/regulatory-codegen.yml` SOFT-WARN against staging with auto-escalating PR comment / issue / hard-block. 14 backend tests + 3 Dart tests green ; full backend suite 7362 passed (+14 vs Plan 03/05 baseline 7348, zero regression) ; dart analyze on generated file clean ; Plan 05 D-12 drift lint transitions MISSING-GENERATED-FILE → OK now that the Dart artifact exists. Scope is REGULATORY ONLY — doctrinal codegen DROPPED per codex HIGH #4.**

## Performance

- **Duration:** ~17 min (2 atomic TDD tasks)
- **Started:** 2026-05-17T17:14Z
- **Completed:** 2026-05-17T17:31Z
- **Tasks:** 2 (both TDD ; both atomic-commit ; both `--no-verify` per parallel-executor contract)
- **Files created or modified:** 8 (7 created + 1 modified)

## Codegen script CLI signature

```
usage: regulatory_constants_to_dart.py [-h]
  [--source {local,staging}]         (default: local)
  [--staging-url URL]                (default: https://mint-staging.up.railway.app)
  [--output PATH]                    (default: apps/mobile/.../regulatory_constants.g.dart)
  [--aging-state-file PATH]          (default: .planning/state/regulatory-codegen-aging.json)
  [--json]                           (machine-readable status to stdout)
  (--check | --write)                (mutually exclusive ; required)
```

Escapement strategy : the snapshot is embedded as `const String _snapshotJson = r'''<deterministic JSON body>''';` and decoded lazily via `jsonDecode(_snapshotJson) as Map<String, dynamic>`. No Dart-literal escaping required ; the only forbidden sequence is `'''` in the JSON body, which is impossible for `json.dumps(separators=(',',':'), sort_keys=True, ensure_ascii=False)` output. A defensive `raise ValueError` in `render_dart_file()` would catch a future regression but is unreachable today.

## Generated Dart file — first bake

| Field | Value |
|---|---|
| Path | `apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart` |
| Size | 44 065 bytes |
| Lines | 31 |
| File SHA-256 | `dbef66a84fa44b8c6f1a02f76140034de1dbfddbd0c70ed2fdcc82efc2c09c10` |
| `regulatoryConstantsVersionHash` | `b2ae1c9ae06773a180705851c71f7f535309c41556c0dd50ddd00a41c4b1fb07` (identical to Plan 03 `/api/v1/regulatory/constants/version` response) |
| `regulatoryConstantsEffectiveOn` | `2026-05-17` |
| `param_count` (active) | 103 across 27 jurisdictions (CH + 26 cantons) |
| Header | `// AUTO-GENERATED by tools/codegen/regulatory_constants_to_dart.py — DO NOT EDIT MANUALLY.` + 4 more lines (Phase tag, source label, regen command, verify command) |
| Exports | `regulatoryConstantsVersionHash`, `regulatoryConstantsEffectiveOn`, `regulatoryConstantsSnapshot`, `_payloadIntegrityHash` (private, consumed by Python --check) |

## Aging policy state machine (codex HIGH #3 closed)

State file : `.planning/state/regulatory-codegen-aging.json`. Computed at workflow run time.

| consecutive_down_days | escalation_level | Action | Workflow exit |
|---|---|---|---|
| 0-6 | 0 | log warning only | 0 |
| 7-13 | 1 | post PR comment via github-actions[bot] | 0 |
| 14-27 | 2 | auto-open GitHub issue `[STAGING-AGING] regulatory-codegen drift visibility blocked` (deduplicated by title + label) | 0 |
| >=28 | 3 | HARD BLOCK — `::error::` + `exit 1` | 1 |

Recovery on staging-UP : reset all counters → re-run codegen → fail PR if hash differs from committed Dart file (the normal staging-up failure path) ; otherwise exit 0.

State transitions implemented by `_update_aging_on_down(state, now)` + `_update_aging_on_up(state, now)` ; pure functions `compute_escalation_level(days) → int` is unit-tested at 0/1/6/7/13/14/27/28/100 (Test 6 of codegen suite).

## Test deltas

| File | Tests | What |
|---|---|---|
| `services/backend/tests/test_regulatory_codegen_script.py` | 8 | Local-write produces valid Dart with registry hash ; --check exit 0 after write ; --check exit 1 on baked-hash mutation ; integrity hash trips on JSON payload tampering ; staging fallback on URLError ; aging-state thresholds 0-100 ; aging-state file round-trip ; phase-tagged header on generated file. |
| `services/backend/tests/test_regulatory_codegen_integration_p04.py` | 6 | Generated file exists + has header + 64-hex literal ; lefthook entry present + invokes --check ; workflow YAML parses + on:pull_request ; workflow references aging state path + --aging-state-file ; 4 escalation level steps + 7/14/28 thresholds named in YAML ; aging state JSON file seeded. |
| `apps/mobile/test/financial_core/generated/regulatory_constants_generated_test.dart` | 3 | Version hash is 64-char SHA-256 hex regex match ; snapshot decodes lazily to Map<String, dynamic> with non-empty parameters + matching version_hash ; effective_on matches ISO 8601 regex. |
| **Total** | **+17** | (14 backend + 3 Dart) |

## Task commits

Each task committed atomically with `--no-verify` per parallel-executor contract :

1. **Task 1 — Codegen script + 8 tests** : `52f1cac4`
   `feat(mint-data-architecture-v1-01-04): regulatory codegen script + 8 tests (Task 1)`
2. **Task 2 — Generated Dart + lefthook + CI aging workflow + 6 integration tests + 3 Dart tests** : `f986a1f5`
   `feat(mint-data-architecture-v1-01-04): generated Dart + lefthook + CI aging workflow (Task 2)`

## Codex findings closed during execution

Per REVIEWS.md, codex flagged 2 HIGH + 4 MEDIUM + 1 LOW on Plan 04. All addressed :

- **HIGH #3 — Live staging in CI / hooks ; even with soft-warn, drift can silently accumulate** → CONCRETE AGING POLICY shipped : `.github/workflows/regulatory-codegen.yml` reads `.planning/state/regulatory-codegen-aging.json`, computes `escalation_level` via the pure function, fires PR comment (L1) / auto-issue (L2) / hard-block (L3). State file is COMMITTED (not gitignored) so the aging counter is auditable across PRs. Tested via `test_aging_state_machine_thresholds` + `test_aging_state_file_round_trip`. CLOSED.
- **HIGH #4 — Scope creep : dual codegen (regulatory + doctrinal)** → DROPPED doctrinal codegen entirely. Plan 04 ships REGULATORY ONLY. Doctrinal constants stay Dart-side with their own version field per D-13 ; future phase if needed. CLOSED.
- **MEDIUM #3 — render_dart() literal escaping risks** → Raw-string + jsonDecode pattern used : `const String _snapshotJson = r'''<json>''';` + lazy `jsonDecode()`. No hand-escaped Dart literals. Defensive guard `if "'''" in json_body: raise` covers the unreachable future case. CLOSED.
- **MEDIUM #4 — `--check` compares only baked hash, not full payload integrity** → Two baked hashes : `regulatoryConstantsVersionHash` (from registry) + `_payloadIntegrityHash` (SHA-256 of embedded JSON body). `_run_check()` validates BOTH ; integrity-hash mismatch is checked FIRST so payload-tamper errors are distinguished from version-hash drift in stderr. Test 4 of codegen suite locks this contract. CLOSED.
- **MEDIUM — Dart generated map type `Map<String, Map<String, Object>>` may be too narrow** → REPLACED with `Map<String, dynamic>`. Test 2 of Dart suite locks the type via `expect(regulatoryConstantsSnapshot, isA<Map<String, dynamic>>())`. CLOSED.
- **LOW — No explicit tie-in to runtime delta-check consumer path** → `regulatoryConstantsVersionHash` IS the future tie-in ; runtime delta-check (whenever Phase 02 ships it) compares this constant against the live `/api/v1/regulatory/constants/version` response. The constant exists ; the consumer is Phase 02's concern. The header comment names the contract explicitly : « Matches GET /api/v1/regulatory/constants/version on the backend at bake time. Runtime delta-check (D-08) compares this against the live /version response. » CLOSED.

## Deviations from plan

### Auto-fixed issues

**1. [Rule 3 — Blocker] Worktree base mismatch**
- **Found during:** initial `<worktree_branch_check>` execution.
- **Issue:** Worktree HEAD started at `255373bb` (hotfix lineage, no calc-engine work, no phase directory). Expected base `41425d1e6e541a5a851dd0bf57d794640a24d0df` is on a different lineage (the agent-a3212e416af967b1f worktree containing Plans 01-01..01-03 + 01-05). Soft-reset would have staged thousands of unrelated deletions due to lineage divergence (shared ancestor only at `f2a71acd`).
- **Fix:** `git checkout 41425d1e...` (detached) → `git checkout -B worktree-agent-a0b58cb50e8fe7e1c-plan04` to create a working branch from the expected base. `git status --short` was then clean and all required prior artifacts (CONTEXT.md, prior SUMMARYs, REVIEWS.md, PLAN.md 01-04) were present on disk.
- **Files modified:** None directly ; pre-task housekeeping.
- **Committed in:** N/A.

**2. [Rule 1 — Bug] Dart test plan template referenced wrong package name**
- **Found during:** writing the Dart test (Task 2 Step 5).
- **Issue:** Plan 04 PLAN.md template said `import 'package:mint/services/financial_core/generated/...'` but `apps/mobile/pubspec.yaml` declares `name: mint_mobile` (confirmed by `grep 'package:mint_mobile' apps/mobile/test/calculators_test.dart`). The `package:mint/...` import would have failed to resolve and the test would not have run.
- **Fix:** Used `package:mint_mobile/services/financial_core/generated/regulatory_constants.g.dart` instead. Verified by `flutter test test/financial_core/generated/regulatory_constants_generated_test.dart` → 3/3 passed.
- **Files modified:** `apps/mobile/test/financial_core/generated/regulatory_constants_generated_test.dart` (1 line ; never committed with the wrong import).
- **Committed in:** Task 2 (`f986a1f5`) with the corrected import from the start.

**3. [Rule 1 — Bug] YAML scanner rejected unquoted `sqlite:///:memory:` value**
- **Found during:** Task 2 GREEN — `pytest test_regulatory_codegen_integration_p04.py::test_github_workflow_present` failed YAML parse.
- **Issue:** `.github/workflows/regulatory-codegen.yml` had 3 `env:` blocks with `DATABASE_URL: sqlite:///:memory:` — PyYAML scanner reads `sqlite:` as a mapping key and fails with `ScannerError: mapping values are not allowed here` on the second `:`.
- **Fix:** Quoted all 3 occurrences to `DATABASE_URL: "sqlite:///:memory:"`. YAML parses cleanly ; GitHub Actions accepts both quoted and unquoted forms in practice but quoting is the cross-parser-safe convention.
- **Files modified:** `.github/workflows/regulatory-codegen.yml` (3 lines).
- **Committed in:** Task 2 (`f986a1f5`) with the corrected quoting in the first commit.

**4. [Rule 1 — Bug] `dart analyze` flagged `_payloadIntegrityHash` as unused_element**
- **Found during:** Task 2 verification step (`dart analyze` on generated file).
- **Issue:** `_payloadIntegrityHash` is a private const in the generated file, consumed only by the Python `--check` via regex extraction from the raw file bytes — never read by Dart. `dart analyze` flagged it with `unused_element` warning. Without suppression the verification gate would fail.
- **Fix:** Added `unused_element` to the file-level `// ignore_for_file:` directive in the codegen template. Regen + re-analyze → 0 issues. The integrity hash is not « unused » in the cross-language contract sense ; it's the audit trail Python --check reads.
- **Files modified:** `tools/codegen/regulatory_constants_to_dart.py` (1 char in the template string), `apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart` (regen).
- **Committed in:** Task 2 (`f986a1f5`) ; the corrected template generated the committed file.

**Total deviations:** 4 auto-fixed (1 Rule 3 worktree alignment + 3 Rule 1 bugs : plan template typo, YAML quoting, dart analyze warning). No Rule 2 (missing-functionality) ; no Rule 4 (architectural) escalations. Plan structure executed 100% as written ; 2 tasks → 2 commits.

## 0-Trust Evidence Receipts (CLAUDE.md §9 protocol)

Each claim above carries a deterministic citation :

| Claim | Evidence |
|---|---|
| Task 1 commit exists | `git log --oneline 41425d1e..HEAD` line 1 = `52f1cac4 feat(mint-data-architecture-v1-01-04): regulatory codegen script + 8 tests (Task 1)`. |
| Task 2 commit exists | `git log --oneline 41425d1e..HEAD` line 0 = `f986a1f5 feat(mint-data-architecture-v1-01-04): generated Dart + lefthook + CI aging workflow (Task 2)`. |
| 8/8 codegen tests pass | `cd services/backend && DATABASE_URL=sqlite:///:memory: pytest tests/test_regulatory_codegen_script.py -q` → `8 passed in 2.20s` at 2026-05-17T17:18Z. |
| 6/6 integration tests pass | `cd services/backend && DATABASE_URL=sqlite:///:memory: pytest tests/test_regulatory_codegen_integration_p04.py -q` → `6 passed in 0.21s` at 2026-05-17T17:25Z. |
| Combined 14/14 green | `pytest tests/test_regulatory_codegen*.py -q` → `14 passed in 2.39s`. |
| 3/3 Dart tests pass | `cd apps/mobile && flutter test test/financial_core/generated/regulatory_constants_generated_test.dart` output `+3: All tests passed!`. |
| Generated Dart hash matches Plan 03 endpoint | `regulatoryConstantsVersionHash = 'b2ae1c9ae06773a180705851c71f7f535309c41556c0dd50ddd00a41c4b1fb07'` AND Plan 03 SUMMARY `/version` capture = same. Identity verified. |
| Generated Dart file SHA-256 | `shasum -a 256 apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart` → `dbef66a84fa44b8c6f1a02f76140034de1dbfddbd0c70ed2fdcc82efc2c09c10`. |
| Generated Dart 31 lines / 44 065 bytes | `wc -l` + `ls -la` direct measurement. |
| --check exit 0 on committed file | `python3 tools/codegen/regulatory_constants_to_dart.py --check --source local` → exit 0, stderr `[regulatory-codegen] --check OK : ... matches registry version_hash b2ae1c9ae06773a1...c4b1fb07.`. |
| Plan 05 D-12 lint transition MISSING-GENERATED-FILE → OK | `python3 tools/checks/profile_safe_fields_parity.py --mode constants-drift --json-status` → exit 0, stdout `{"mode": "constants-drift", "status": "OK", "exit_code": 0}`. |
| YAML lefthook + workflow parse | `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/regulatory-codegen.yml'))"` returns `YAML PASS, top-keys: ['name', True, 'permissions', 'jobs']`. (`True` is PyYAML's representation of the bareword `on:` key — workflow trigger block is parsed correctly.) |
| Full backend suite : 7362 passed (zero regression vs Plan 03/05 baseline 7348) | `cd services/backend && python3 -m pytest tests/ -q --tb=no` → `7362 passed, 82 skipped, 3 xfailed, 3 warnings in 130.50s`. +14 exactly matches +14 new backend tests (8 codegen + 6 integration). |
| dart analyze 0 issues on generated file | `cd apps/mobile && dart analyze lib/services/financial_core/generated/regulatory_constants.g.dart` → `No issues found!`. |
| banned_terms_python clean | `python3 tools/checks/banned_terms_python.py tools/codegen/regulatory_constants_to_dart.py services/backend/tests/test_regulatory_codegen_script.py services/backend/tests/test_regulatory_codegen_integration_p04.py` → exit 0 (no output). |
| accent_lint_fr clean | `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0. |
| Lefthook entry narrow-globbed (3 file pointers) | `grep -A 14 "regulatory-codegen-check:" lefthook.yml` shows glob `{services/backend/app/services/regulatory/**,apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart,tools/codegen/regulatory_constants_to_dart.py}`. |
| Workflow has 4 escalation steps + 7/14/28 thresholds named in YAML | `grep -E "level [1-3]\|PR comment\|open issue\|HARD BLOCK\|7\|14\|28" .github/workflows/regulatory-codegen.yml` returns matches for all required strings. Test 6 of integration suite locks this. |
| Aging state file seeded | `cat .planning/state/regulatory-codegen-aging.json` → `{"consecutive_down_days":0,"escalation_level":0,"first_staging_down_at":null,"last_staging_down_at":null,"last_staging_up_at":null}`. |

**Caveats** (per CLAUDE.md §9.4 « what I have NOT checked ») :
- **Live staging not hit** — the workflow's staging-UP / staging-DOWN steps were NOT executed against the actual Railway deployment. The script's staging-fallback path IS exercised by Test 5 of the codegen suite (`http://127.0.0.1:1` → URLError → fallback to local + aging-state update), but the network code path was only proven against an unbound port, not against Railway returning a real snapshot. First live exercise will happen when this PR triggers `.github/workflows/regulatory-codegen.yml` post-merge.
- **No real CI run** — the workflow YAML parses + the script behaviour is unit-tested, but no GitHub Actions run has actually executed this YAML against a real PR yet. First exercise = next PR that touches the path-filter globs.
- **Lefthook hook not exercised at real `git commit` time** — Test 3 of integration suite asserts the YAML content + the `run:` command shape, but the hook was not triggered via an actual `lefthook run pre-commit` invocation. The orchestrator's responsibility post-merge.
- **GitHub Issue auto-creation (L2) + PR comment (L1) not exercised** — these escalation paths fire only when staging has been down for 7+ days, which is a temporal condition I can't simulate without manipulating system time. The YAML structure is asserted ; the github-script@v7 calls are standard patterns. First real exercise will happen if/when staging actually goes down ≥7 days.
- **Phase 02 D-12 HARD promotion path not exercised** — Plan 05 already ships `--hard` support ; Plan 04 does not depend on that promotion. The Plan 04 lefthook entry is HARD always (because --check is network-free, deterministic). The Plan 05 CI workflow promotion to --hard is a Phase 02 concern.
- **Engram MCP save NOT executed yet by subagent** — handled at the end of this SUMMARY via mint_infra_contract block ; orchestrator-side belt-and-suspenders fallback per CLAUDE.md §3.5.

## Next Phase Readiness

- **Plan 05 D-12 drift lint** OPERATIONAL — was emitting `MISSING-GENERATED-FILE`, now emits `OK` with the canonical artifact at the expected path. The full SOFT-WARN → HARD promotion contract is intact and ready for Phase 02's first-migration PR per D-11.
- **Phase 02 first-migration PR (Monte Carlo per D-11)** UNBLOCKED for the regulatory-constants codegen side — the Dart artifact + delta-check anchor (`regulatoryConstantsVersionHash`) exist ; the runtime D-08 path can consume them. The Plan 05 lint can be flipped to `--hard` in that PR per D-12 contract.
- **Future runtime D-08 delta-check** UNBLOCKED — Plan 03 ships /version + /snapshot, Plan 04 ships baked Dart with comparison anchor, Plan 05 ships drift detection. The full pipeline (registry → endpoint → bundle → runtime sync) has deterministic contracts at every boundary.
- **No blockers** for downstream plans in this wave or the next phase.

## Known Stubs

None. All deliverables are wired end-to-end :
- The codegen script executes against the live `RegulatoryRegistry` singleton (no mocks) and against a real staging URL when reachable (TestClient-equivalent network code path exercised in Test 5 via fallback-on-failure).
- The generated Dart file is real (44 065 bytes, contains 103 active params, parses + decodes via `jsonDecode()` in the Dart test suite).
- The lefthook hook is wired to the real script with a real glob ; the only un-exercised piece is the `git commit`-time invocation itself.
- The GitHub Action YAML structure is real and tested via PyYAML + behavioural grep ; the only un-exercised piece is an actual `pull_request` run (which can only happen post-merge).

The « un-exercised » items above are NOT stubs — they're temporal/environmental constraints (live staging, real PR run, 7+ day aging timer) that cannot be exercised in a single subagent's turn. The contracts are deterministic and the wiring is complete.

## Threat Flags

Per the plan's `<threat_model>`, all 6 STRIDE threats are addressed :

| Threat ID | Status | Evidence |
|---|---|---|
| T-mintda-04-01 (Tampering, committed Dart) | MITIGATED | `_payloadIntegrityHash` SHA-256 of JSON body checked first in `_run_check()` ; Test 4 of codegen suite proves payload-tamper detection. |
| T-mintda-04-02 (Tampering, staging in transit) | ACCEPTED | Phase 02 may add manifest signature ; today TLS via Railway protects passive interception. Documented in plan. |
| T-mintda-04-03 (Info disclosure, aging state) | ACCEPTED | Only timestamps + counters ; no PII ; committed for auditability. |
| T-mintda-04-04 (DoS, staging hammered) | MITIGATED | 10-second timeout in `_fetch_payload_staging()` + Plan 03 ETag conditional GET + aging fallback to local on failure. |
| T-mintda-04-05 (Repudiation, aging chain) | MITIGATED | All 4 levels leave artifacts : workflow run logs (UP), PR comments (L1), GitHub Issues (L2), workflow failure (L3). |
| T-mintda-04-06 (Info disclosure, snapshot in bundle) | ACCEPTED | Public Swiss regulatory data per D-13 ; offline-first L1 ships it by design (D-08). |

No NEW network endpoints, auth paths, file access patterns, or schema changes beyond what the plan already documented. No threat flags to surface.

## MINT infra compliance (CLAUDE.md mint_infra_contract)

- **File lints (Bash, since mint-tools MCP doesn't propagate to subagents per anthropics/claude-code#13898)** :
  - `python3 tools/checks/banned_terms_python.py tools/codegen/regulatory_constants_to_dart.py services/backend/tests/test_regulatory_codegen_script.py services/backend/tests/test_regulatory_codegen_integration_p04.py` → exit 0.
  - `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0.
  - ARB parity not applicable (no Flutter / ARB string changes — the generated Dart file contains no user-facing FR strings, just hex hashes + JSON data).
- **Engram persistence** — orchestrator's responsibility per CLAUDE.md §3.5 ; this subagent did not have `mcp__plugin_engram_engram__mem_save` in its tool whitelist (only Read, Write, Edit, Bash). Recommended save : `topic_key: data-architecture:codegen:regulatory-constants-dart-bake` with `prior_finding_refs: [Plan 01 BUNDLE-SIZE-REPORT obs, Plan 03 endpoints obs, Plan 05 drift-lint obs]`.

## Self-Check: PASSED

Files (7/7 found) :
- `tools/codegen/regulatory_constants_to_dart.py` (NEW, 476 lines) — FOUND. `grep -c "def compute_escalation_level" tools/codegen/regulatory_constants_to_dart.py` = 1, `grep -c "def render_dart_file" tools/codegen/regulatory_constants_to_dart.py` = 1, `grep -c "def _run_check" tools/codegen/regulatory_constants_to_dart.py` = 1.
- `apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart` (NEW, 31 lines / 44 065 bytes) — FOUND. SHA-256 `dbef66a84fa44b8c6f1a02f76140034de1dbfddbd0c70ed2fdcc82efc2c09c10`. Contains `regulatoryConstantsVersionHash`, `regulatoryConstantsEffectiveOn`, `regulatoryConstantsSnapshot`, `_payloadIntegrityHash`, `_snapshotJson`.
- `apps/mobile/test/financial_core/generated/regulatory_constants_generated_test.dart` (NEW, 43 lines, 3 tests) — FOUND. Imports `package:mint_mobile/services/financial_core/generated/regulatory_constants.g.dart`.
- `services/backend/tests/test_regulatory_codegen_script.py` (NEW, 244 lines, 8 tests) — FOUND.
- `services/backend/tests/test_regulatory_codegen_integration_p04.py` (NEW, 134 lines, 6 tests) — FOUND.
- `.github/workflows/regulatory-codegen.yml` (NEW, 155 lines) — FOUND. `grep -c "level [1-3]" .github/workflows/regulatory-codegen.yml` = 3, references all 7/14/28 thresholds in the step naming.
- `lefthook.yml` (MODIFIED, +20 lines) — FOUND. `grep -c "regulatory-codegen-check:" lefthook.yml` = 1 at line 231, inserted BEFORE the existing `regulatory_constants_drift` (Plan 05) block.
- `.planning/state/regulatory-codegen-aging.json` (NEW) — FOUND, seeded with default state.
- `.planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/01-04-SUMMARY.md` — THIS FILE, FOUND.

Commits (2/2 found in `git log --all`) : `52f1cac4` (Task 1), `f986a1f5` (Task 2).

---
*Phase: mint-data-architecture-v1-01-calc-engine-canonical*
*Plan: 04*
*Completed: 2026-05-17*
*Next: Phase mint-data-architecture-v1-02 first-migration PR (Monte Carlo per D-11) — promotes Plan 05 D-12 lint to `--hard` via 1-line YAML edit ; wires Plan 04 runtime delta-check on app launch per D-08 (Phase 02 scope).*
