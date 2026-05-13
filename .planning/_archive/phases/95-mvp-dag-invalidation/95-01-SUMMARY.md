---
phase: 95-mvp-dag-invalidation
plan: 01
subsystem: architecture
tags: [hash-chain, uuid7, alembic, dag-invalidation, rfc8785, scenarios, citation-gate]

# Dependency graph
requires:
  - phase: 94-mvp-citation-gate
    provides: "CITATION_REGISTRY 18-key namespace + GatedResponse.inputs_hash stub at citation_parser.py:263 (populated by Wave 2)"
  - phase: 92.5-calc-rigor
    provides: "pure-Dart harness pattern (calc_harness) — Path A hash_parity_harness reuses the pattern without financial_core imports"

provides:
  - "compute_inputs_hash(dict) -> str : SHA256 hex of RFC 8785 canonical JSON of Decimal(0.01)-quantized inputs (DAG-01)"
  - "new_projection_id() -> str : UUID7 (RFC 9562) hyphenated, time-ordered, via uuid_utils backport (DAG-02)"
  - "staleness_high(stored, current) -> bool : pure-function staleness rule, production module, zero financial_core coupling (DAG-03 backend half)"
  - "ScenarioModel.inputs_hash + .superseded_by : nullable String(64)/String(36) columns ; zero backfill on existing rows (DAG-04)"
  - "alembic p95_dag_invalidation : additive forward + drop-column downgrade ; SQLite + PostgreSQL safe ; idempotent (DAG-04)"
  - "hash_parity_50.jsonl : 50-fixture golden pack ; 50/50 byte-identical Python<->Dart hashes (R1 closed)"
  - "apps/mobile/tools/hash_parity_harness/ : pure-Dart standalone (no financial_core, no Flutter) — `dart run` works today on Phase 92.7 cascade-broken sdk"
  - "tools/checks/pii_fixture_scan.py : AHV13 + Swiss-phone regex scan on JSONL fixtures ; lefthook pre-commit + CI gate"

affects:
  - "phase-95 plan-02 (Wave 2 consumes compute_inputs_hash + new_projection_id + ProjectionGroundingPack stub)"
  - "phase-96-mvp-chat-as-verb (Wave 2 narrator wiring reads pack.inputs_hash + Phase 96 W2 wires staleness_high() consumer)"

# Tech tracking
tech-stack:
  added:
    - "rfc8785>=0.1.4,<1.0.0 (Trail of Bits, zero-deps RFC 8785 JCS canonical JSON)"
    - "uuid_utils>=0.14.1,<1.0.0 (Rust-backed UUID7 backport ; replaces stdlib uuid.uuid7 which is Python 3.14+ only)"
    - "package:crypto ^3.0.0 (resolved 3.0.7) — Dart-side SHA256 in hash_parity_harness"
  patterns:
    - "Quantize-before-canonicalize : floats Decimal(0.01) ROUND_HALF_UP before rfc8785.dumps to dodge IEEE 754 artifacts"
    - "UUID7 lex sort == chrono sort : superseded_by column doubles as supersession-chain index without a separate created_at"
    - "Additive nullable migrations + idempotency guard (inspector.get_columns) ; precedent p86_eclairage_delivered"
    - "Path A pure-Dart parity harness : sidesteps Phase 92.7 cascade by avoiding all financial_core imports"

key-files:
  created:
    - "services/backend/app/services/coach/inputs_hash.py"
    - "services/backend/app/services/coach/projection_id.py"
    - "services/backend/app/services/coach/staleness.py"
    - "services/backend/alembic/versions/p95_dag_invalidation.py"
    - "services/backend/tests/fixtures/hash_parity_50.jsonl"
    - "services/backend/tests/fixtures/hash_parity_50_expected.jsonl"
    - "services/backend/tests/test_dag_invalidation/__init__.py + conftest.py + 5 test files"
    - "apps/mobile/tools/hash_parity_harness/main.dart"
    - "apps/mobile/tools/hash_parity_harness/pubspec.yaml + pubspec.lock"
    - "tools/checks/pii_fixture_scan.py"
  modified:
    - "services/backend/pyproject.toml (+2 deps : rfc8785, uuid_utils)"
    - "services/backend/app/models/scenario.py (+2 nullable cols : inputs_hash, superseded_by)"
    - "lefthook.yml (+pii_fixture_scan pre-commit entry)"

key-decisions:
  - "DEVIATION (Rule 3) : alembic p95.down_revision chained off 29_05_magic_link_tokens, not p86_eclairage_delivered as plan prescribed — p86 was already a branchpoint, chaining off it again would create multi-head, breaking `alembic upgrade head`."
  - "AUTO-FIX (Rule 1) : Dart harness initial recipe (per RESEARCH §D-03) omitted _quantize step, producing 38/50 matches. Added _quantize() mirror of Python _quantize_floats() to harness — now 50/50 byte-identical."
  - "uuid_utils backport over stdlib uuid.uuid7 (Python 3.14+) because Railway base image is python:3.12-slim per RESEARCH §D-04 correction."
  - "rfc8785 (Trail of Bits) over stale jcs==0.2.1 (last release 2021) per RESEARCH §D-01 correction."
  - "Path A pure-Dart harness — zero financial_core / Flutter imports — sidesteps Phase 92.7 cascade ; uses only dart:convert + package:crypto."
  - "staleness.py extracted as production module (zero financial_core coupling) per BLOCKER-1 fix #1 ; chain-reset SC#4(c) test added per BLOCKER-1 fix #4."

patterns-established:
  - "Pure-Dart standalone harness pattern for Python<->Dart parity testing (no financial_core / Flutter coupling)"
  - "Quantize-floats-before-canonicalize-before-hash recipe (Python AND Dart) — eliminates IEEE 754 phantom-hash drift"
  - "Idempotency guard pattern for alembic add_column on cross-DB (SQLite + PostgreSQL) — inspector.get_columns short-circuit"
  - "pii_fixture_scan lefthook gate on tests/fixtures/*.jsonl — pattern reusable for any future JSONL fixture pack"

requirements-completed: [DAG-01, DAG-02, DAG-03, DAG-04]

# Metrics
duration: 17m
completed: 2026-05-10
---

# Phase 95 Plan 01: Wave 1 — DAG-INVALIDATION foundation Summary

**Deterministic Python<->Dart hash chain (RFC 8785 + Decimal(0.01)) + UUID7 supersession IDs + additive scenarios schema migration + zero-coupling staleness rule, validated by 50/50 byte-identical hash-parity test.**

## Performance

- **Duration:** ~17 min (2026-05-10T22:25:14Z -> 2026-05-10T22:42:56Z)
- **Started:** 2026-05-10T22:25:14Z
- **Completed:** 2026-05-10T22:42:56Z
- **Tasks:** 5/5 atomic commits
- **Files created:** 13 (4 production modules + 1 alembic + 7 test files + 2 fixture pack + 2 Dart harness + 1 PII lint, counting __init__.py/conftest.py as 1)
- **Files modified:** 3 (pyproject.toml, scenario.py, lefthook.yml)
- **Tests added:** 31 (10 inputs_hash + 6 projection_id + 7 staleness incl SC#4(c) + 4 migration + 4 hash_parity)

## Accomplishments

- **R1 risk CLOSED** : Python<->Dart hash parity 50/50 byte-identical on `hash_parity_50.jsonl` (evidence: `/tmp/dart_hashes.jsonl` vs `services/backend/tests/fixtures/hash_parity_50_expected.jsonl` diff = 0 after _quantize fix).
- **DAG-01 shipped** : `compute_inputs_hash(dict) -> str` deterministic across runs (10 unit tests covering IEEE 754, bool!=int, NaN/inf, numpy.float64, nested recursion).
- **DAG-02 shipped** : `new_projection_id() -> str` returns RFC 9562 UUID7 (6 unit tests covering format, version, time-ordering, uniqueness 1000 calls).
- **DAG-03 backend half shipped** : `staleness_high(stored, current)` pure-function rule in `services/backend/app/services/coach/staleness.py` (6 unit tests + 1 SC#4(c) chain-reset). Production read-path integration deferred to Phase 96 W2 per CONTEXT `<deferred>` block.
- **DAG-04 shipped** : ScenarioModel extended with 2 nullable columns ; alembic p95 migration upgrades + downgrades cleanly on local SQLite (manual roundtrip exit 0 ; 4 automated tests).
- **Full backend suite 6479 passed** (baseline 6448 -> +31 new, 0 regressions ; 62 skipped, 1 xfailed unchanged).
- **PII fixture lint live** : `tools/checks/pii_fixture_scan.py` registered in lefthook pre-commit ; smoke-tested catches AHV13 (`756.1234.5678.90`) + Swiss phone (`+41 22 345 67 89`) ; exits 0 on the 50-fixture pack.

## Task Commits

Each task was committed atomically on `feature/S94-mvp-citation-gate` :

1. **Task 1: Wave 0 scaffold (deps + test dirs + PII lint + lefthook)** — `30381bad` (chore)
2. **Task 2: inputs_hash.py compute_inputs_hash + _quantize_floats (DAG-01)** — `cb613e01` (feat, TDD RED -> GREEN 10/10)
3. **Task 3: projection_id.py new_projection_id UUID7 wrapper (DAG-02)** — `adbda907` (feat, TDD RED -> GREEN 6/6)
4. **Task 4: alembic p95 + ScenarioModel ext + staleness.py + tests (DAG-03/04)** — `1296e7a7` (feat, 11/11 tests + manual alembic roundtrip exit 0)
5. **Task 5: hash_parity 50/50 byte-identical Python<->Dart (DAG-01 R1)** — `93baff1c` (feat, 4/4 tests incl integration)

**Plan metadata commit** : pending (this SUMMARY.md + STATE.md updates committed in the final docs commit by the orchestrator).

## Files Created/Modified

### Created

- `services/backend/app/services/coach/inputs_hash.py` — compute_inputs_hash + _quantize_floats deterministic hasher
- `services/backend/app/services/coach/projection_id.py` — new_projection_id UUID7 via uuid_utils
- `services/backend/app/services/coach/staleness.py` — staleness_high pure-function rule (production module ; zero financial_core coupling)
- `services/backend/alembic/versions/p95_dag_invalidation.py` — additive forward migration + batch_alter_table downgrade
- `services/backend/tests/test_dag_invalidation/__init__.py` — empty package marker
- `services/backend/tests/test_dag_invalidation/conftest.py` — hash_parity_inputs + sample_profile_inputs fixtures
- `services/backend/tests/test_dag_invalidation/test_inputs_hash.py` — 10 unit tests (determinism, IEEE 754, bool/int, NaN/inf, numpy)
- `services/backend/tests/test_dag_invalidation/test_superseded_by.py` — 6 unit tests (format, version=7, time-ordering, uniqueness)
- `services/backend/tests/test_dag_invalidation/test_staleness.py` — 7 unit tests (6 staleness + 1 SC#4(c) chain-reset)
- `services/backend/tests/test_dag_invalidation/test_migration.py` — 4 integration tests (upgrade/downgrade/roundtrip/ORM)
- `services/backend/tests/test_dag_invalidation/test_hash_parity.py` — 4 tests (counts + Python golden + Python<->Dart 50/50)
- `services/backend/tests/fixtures/hash_parity_50.jsonl` — 50-fixture pack (5 buckets : 20 happy / 10 nested / 10 edge-floats / 5 boolean / 5 lex-sort)
- `services/backend/tests/fixtures/hash_parity_50_expected.jsonl` — 50 frozen Python golden hashes
- `apps/mobile/tools/hash_parity_harness/main.dart` — pure-Dart parity harness with _quantize + canonicalize + sha256
- `apps/mobile/tools/hash_parity_harness/pubspec.yaml` — minimal `crypto: ^3.0.0` dep
- `apps/mobile/tools/hash_parity_harness/pubspec.lock` — locked resolution (crypto 3.0.7, collection 1.19.1, typed_data 1.4.0)
- `tools/checks/pii_fixture_scan.py` — AHV13 + Swiss-phone regex scanner

### Modified

- `services/backend/pyproject.toml` — +2 lines : `rfc8785>=0.1.4,<1.0.0` and `uuid_utils>=0.14.1,<1.0.0`
- `services/backend/app/models/scenario.py` — +2 nullable columns (inputs_hash String(64), superseded_by String(36)) + module docstring update
- `lefthook.yml` — +1 pre-commit entry `pii_fixture_scan` glob `services/backend/tests/fixtures/*.jsonl`

## Decisions Made

- **uuid_utils backport over stdlib uuid.uuid7** — Python 3.14 stdlib uuid.uuid7 is not yet available on Railway's python:3.12-slim base image per RESEARCH §D-04 correction. Migration path documented in module docstring : swap `import uuid_utils` for `import uuid` when Railway upgrades to 3.14.
- **rfc8785 over stale `jcs`** — Trail of Bits maintained, zero deps ; the older `jcs==0.2.1` package hasn't been released since 2021 per RESEARCH §D-01 correction.
- **ScenarioModel extension over new projections table** — there is no `projections` table in the schema today ; scenarios IS the persistence point for the DAG. CONTEXT D-05 said `projections` but the codebase reality is `scenarios.__tablename__` per RESEARCH §Pitfall 5 correction.
- **Path A pure-Dart harness over flutter test runner** — zero financial_core imports means `dart run` works today on the Phase 92.7 cascade-broken Flutter SDK. Sidesteps the blocker entirely.
- **Quantize-floats-before-canonicalize in BOTH languages** — the Python recipe canonicalises AFTER quantization ; the Dart harness initially didn't quantize (per the RESEARCH §D-03 recipe), producing 38/50 matches. Adding _quantize() to the Dart harness yielded 50/50.
- **alembic chain off 29_05_magic_link_tokens, not p86_eclairage_delivered** — see Deviations Rule 3 below.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] alembic chain parent moved from p86_eclairage_delivered to 29_05_magic_link_tokens**
- **Found during:** Task 4 (manual `alembic upgrade head` exit-code check)
- **Issue:** Plan/CONTEXT prescribed `down_revision = "p86_eclairage_delivered"`. But the codebase reality is that `29_05_magic_link_tokens.py` already chained off `p86_eclairage_delivered` — chaining p95 off p86 too creates a 2-head branchpoint that breaks `alembic upgrade head` (ERROR : "Multiple head revisions are present"). Evidence : `cd services/backend && python3 -m alembic heads` returned 2 heads with the plan-prescribed parent.
- **Fix:** Changed `down_revision = "29_05_magic_link_tokens"` so the chain stays linear (`p86 -> 29_05_magic_link_tokens -> p95_dag_invalidation`).
- **Files modified:** services/backend/alembic/versions/p95_dag_invalidation.py
- **Verification:** `python3 -m alembic heads` returns single head `p95_dag_invalidation (head)`. `upgrade head` -> `downgrade -1` -> `upgrade head` roundtrip exits 0 on each step on local SQLite mint.db.
- **Committed in:** `1296e7a7` (Task 4 commit)

**2. [Rule 1 — Bug] Dart harness initial recipe omitted _quantize step, producing 38/50 parity mismatch**
- **Found during:** Task 5 (first Python<->Dart parity check)
- **Issue:** RESEARCH §D-03 Dart recipe only canonicalized + hashed ; it did NOT mirror Python's `_quantize_floats()` step. Result : 12/50 fixtures diverged on hp-021..hp-030 (nested float values like `0.068` quantized to `0.07` on Python, stayed `0.068` on Dart). The first run produced 38/50 byte-identical hashes — failing the R1 acceptance criterion (RESEARCH §Pitfalls #1).
- **Fix:** Added `_quantize()` function to `main.dart` that mirrors Python `_quantize_floats()` recursion order exactly : Map -> List -> bool -> int -> double (Decimal(0.01) ROUND_HALF_UP via `(v * 100).roundToDouble() / 100`). main() now calls `_quantize(fx['inputs'])` BEFORE `canonicalize()`.
- **Files modified:** apps/mobile/tools/hash_parity_harness/main.dart
- **Verification:** `dart run main.dart hash_parity_50.jsonl > /tmp/dart_hashes.jsonl` then diff vs Python expected file = 0 drift. `python3 -m pytest tests/test_dag_invalidation/test_hash_parity.py::test_python_dart_parity_50_50` exits 0 (50/50 byte-identical).
- **Committed in:** `93baff1c` (Task 5 commit)

**3. [Rule 3 — Blocking] test_migration.py used monkeypatch.setenv + importlib.reload for sqlalchemy.url override**
- **Found during:** Task 4 (first pytest run on migration tests)
- **Issue:** Plan-prescribed `cfg.set_main_option("sqlalchemy.url", ...)` is overwritten by `services/backend/alembic/env.py:38` which reads `settings.DATABASE_URL` AFTER the test's main-option assignment. First run produced `NoSuchTableError: scenarios` because migrations ran against the default `mint.db`, not the tmp_path test DB.
- **Fix:** Each test fixture now uses `monkeypatch.setenv("DATABASE_URL", db_url)` + `importlib.reload(app.core.config)` to invalidate the cached Settings before constructing Config.
- **Files modified:** services/backend/tests/test_dag_invalidation/test_migration.py
- **Verification:** `pytest tests/test_dag_invalidation/test_migration.py -q` 4/4 pass.
- **Committed in:** `1296e7a7` (Task 4 commit)

---

**Total deviations:** 3 auto-fixed (2 blocking Rule 3, 1 bug Rule 1)
**Impact on plan:** All auto-fixes essential for correctness ; no scope creep. The Dart-side _quantize fix is the most important — it closed the R1 risk and shipped the Wave 2 unblocking parity gate.

## Issues Encountered

- **`alembic` CLI not on PATH** : pyenv shims point to `system` Python 3.9 ; alembic only installed on the 3.12.12 venv. Resolved by using `python3 -m alembic` from `services/backend/`.
- **`pip install -e .[dev]` fails** : the `services/backend/` repo has no `setup.py`/`setup.cfg`, just `pyproject.toml`, and the system pip is 21.2.4 (too old for editable mode via pyproject alone). Resolved by `python3 -m pip install --user rfc8785 uuid_utils` directly with the desired pins.
- **`accent_lint_fr.py` requires `--file` flag per invocation** : not the positional-args contract assumed in the plan ; iterated per-file with `--file $f`. All 4 new files exit 0.

## User Setup Required

None — no external service configuration required for this plan. Two new pyproject deps (`rfc8785`, `uuid_utils`) will install automatically on `pip install -e ".[dev]"` (or via Railway's existing requirements pipeline at deploy time).

## Next Phase Readiness

- Wave 1 closes ; Wave 2 (Plan 95-02) unblocked. R1 risk (Python<->Dart parity) closed — Wave 2 fattens `ProjectionGroundingPack` emission + double-lookup in `_substitute_placeholders` + Pareto 3-point + what_ifs + bootstrap CIs + LSFin annotation.
- staleness_high() production read-path integration deferred to Phase 96 W2 per SC#2 (consumer call from arbitrage_engine).
- Dart-side projection-model field additions (Dart inputs_hash + superseded_by on financial_core/) deferred to Phase 96 W2 per ROADMAP SC#1 partial-delivery note.
- Manual staging-clone roundtrip carried as 95-VALIDATION.md manual gate (D-17, autonomous: false) — run pre-merge to dev, not blocking Wave 1 close.

## 0-Trust Self-Check (per CLAUDE.md §9.6)

**Claim: "Wave 1 closes with all 5 tasks committed and the regression suite green."**

- **Evidence:**
  - `git log --oneline -6` shows : `93baff1c` T5, `1296e7a7` T4, `adbda907` T3, `cb613e01` T2, `30381bad` T1, prior commits.
  - `cd services/backend && python3 -m pytest tests/ -q --ignore=tests/integration` returned `6479 passed, 62 skipped, 1 xfailed, 1 warning in 107.51s` (vs baseline 6448 = +31 new, 0 regressions).
  - `cd services/backend && python3 -m pytest tests/test_dag_invalidation/ -q` returned `31 passed, 1 warning in 0.85s`.
  - `cd apps/mobile/tools/hash_parity_harness && dart run main.dart ../../../../services/backend/tests/fixtures/hash_parity_50.jsonl > /tmp/dart_hashes.jsonl` exit 0 ; comparison vs `services/backend/tests/fixtures/hash_parity_50_expected.jsonl` shows 50/50 byte-identical.
  - `cd services/backend && rm -f mint.db && python3 -m alembic upgrade head && python3 -m alembic downgrade -1 && python3 -m alembic upgrade head` all exit 0.
  - `python3 tools/checks/pii_fixture_scan.py services/backend/tests/fixtures/hash_parity_50.jsonl` exit 0.
  - `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/*.py` exit 0.
  - 4 new files iterated via `python3 tools/checks/accent_lint_fr.py --file <f>` all exit 0.

- **Caveat:**
  - Manual staging-clone alembic roundtrip (D-17) NOT run — carried as 95-VALIDATION.md `Manual-Only Verifications` gate, pre-merge to dev.
  - Phase 95 Wave 2 narrator paths (`_substitute_placeholders`, `gate()`, `coach_chat.py`) NOT touched — Wave 2 owns those per scope.
  - The Dart-side `financial_core/` projection-model field additions are NOT in scope per CONTEXT `<deferred>` block ; only the Path-A pure-Dart parity harness exists in `apps/mobile/tools/hash_parity_harness/`.
  - No CI run yet on this branch ; G3 dev CI green is a phase-level gate, not a plan-level one.
  - End-to-end user value : NONE yet. This is data-model + parity-test foundation only ; user-visible behavior changes ship in Phase 96 narrator wiring.

## Self-Check: PASSED

All claimed deliverables cited with reproducible commands. 50/50 hash parity verified by file diff. 6479 backend tests verified by pytest output. Alembic roundtrip verified by 3 sequential `python3 -m alembic` exits.

---
*Phase: 95-mvp-dag-invalidation*
*Plan: 01 (Wave 1 of 2)*
*Completed: 2026-05-10*
