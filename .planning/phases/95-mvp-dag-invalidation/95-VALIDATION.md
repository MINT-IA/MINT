---
phase: 95
slug: mvp-dag-invalidation
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-10
last_revision: 2026-05-11
revision_note: planner-revision iteration 1 — BLOCKER-1 fix #1 (staleness.py production module) + fix #4 (SC#4(c) chain-reset test) + BLOCKER-3 (GatedResponse inputs_hash propagation test) ; expected test count bumped 12 → 14
---

# Phase 95 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Drawn from 95-RESEARCH.md §Validation Architecture + 95-CONTEXT.md D-14..D-18 compliance gates.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 8.x (Python) + `dart test` (Dart harness) |
| **Config file** | `services/backend/pytest.ini` + `apps/mobile/tools/hash_parity_harness/pubspec.yaml` (new in W1) |
| **Quick run command** | `cd services/backend && python3 -m pytest tests/test_dag_invalidation/ -q --tb=no` |
| **Full suite command** | `cd services/backend && python3 -m pytest tests/ -q --ignore=tests/integration` |
| **Estimated runtime** | ~120s full suite (current baseline 6448 passed) ; ~5s phase-specific tests |
| **Dart harness command** | `cd apps/mobile && dart run tools/hash_parity_harness/main.dart fixtures/hash_parity_50.jsonl` |

---

## Sampling Rate

- **After every task commit:** Run `python3 -m pytest tests/test_dag_invalidation/ -q --tb=no`
- **After every plan wave:** Run the full backend pytest suite + lint stack (banned-terms + accent + PII + legal-admission)
- **Before `/gsd-verify-work`:** Full suite green + Python↔Dart hash parity 50/50 + alembic upgrade/downgrade roundtrip on staging clone
- **Max feedback latency:** 120 seconds (full backend suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 95-01-01 | 01 | 1 | DAG-04 | T-95-01 (schema-drift) | additive migration; downgrade roundtrips clean | integration | `cd services/backend && alembic upgrade head && alembic downgrade -1 && alembic upgrade head` | ❌ W0 (alembic version file pending) | ⬜ pending |
| 95-01-02 | 01 | 1 | DAG-01 | T-95-02 (hash non-determinism) | inputs_hash deterministic across runs | unit | `python3 -m pytest tests/test_dag_invalidation/test_inputs_hash.py -q` | ❌ W0 | ⬜ pending |
| 95-01-03 | 01 | 1 | DAG-01 | T-95-03 (Python↔Dart parity) | 50 input dicts hash identically in both runtimes | integration | `cd services/backend && python3 -m pytest tests/test_dag_invalidation/test_hash_parity.py -q` AND `cd apps/mobile && dart run tools/hash_parity_harness/main.dart` | ❌ W0 | ⬜ pending |
| 95-01-04 | 01 | 1 | DAG-02 | — | UUID7 time-ordered; `superseded_by` populated on new projection | unit | `python3 -m pytest tests/test_dag_invalidation/test_superseded_by.py -q` | ❌ W0 | ⬜ pending |
| 95-01-05a | 01 | 1 | DAG-03 (backend half) | — | **[BLOCKER-1 fix #1]** `staleness_high(stored_hash, current_hash)` lives at `services/backend/app/services/coach/staleness.py` as a pure production module ; 5-6 unit tests cover both-None / stored-None / both-same / both-different / both-empty-strings | unit | `python3 -m pytest tests/test_dag_invalidation/test_staleness.py -q -k "not chain_reset"` | ❌ W0 | ⬜ pending |
| 95-01-05b | 01 | 1 | **ROADMAP SC#4(c)** | — | **[BLOCKER-1 fix #4]** « recompute resets hash chain » — given a stale scenario (stored_hash ≠ current_hash), recomputing with updated inputs produces inputs_hash == current AND staleness_high() flips False AND old row's superseded_by points to new UUID7 | unit | `python3 -m pytest tests/test_dag_invalidation/test_staleness.py::test_recompute_resets_hash_chain -q` | ❌ W0 | ⬜ pending |
| 95-02-01 | 02 | 2 | (consumer of DAG-01..04) | T-95-04 (cohabitation race) | double-lookup: pack.entries first, CITATION_REGISTRY fallback | unit | `python3 -m pytest tests/test_dag_invalidation/test_substitute_double_lookup.py -q` | ❌ W0 | ⬜ pending |
| 95-02-01b | 02 | 2 | **[BLOCKER-3 fix]** | T-95-04 | gate() returns GatedResponse whose `.inputs_hash == pack.inputs_hash` when pack supplied ; `is None` when pack=None — enforces 7 stub-site rewrite at citation_parser.py:430/459/468/512/521/533 | unit | `python3 -m pytest tests/test_dag_invalidation/test_substitute_double_lookup.py::test_gated_response_inputs_hash_propagated_from_pack -q` | ❌ W0 | ⬜ pending |
| 95-02-02 | 02 | 2 | (calc-first N2) | — | ProjectionGroundingPack Pydantic v2 frozen+forbid validates | unit | `python3 -m pytest tests/test_dag_invalidation/test_grounding_pack_schema.py -q` | ❌ W0 | ⬜ pending |
| 95-02-03 | 02 | 2 | (calc-first N2 Pareto MVP) | — | 3-point scalarisation produces exactly 3 ParetoPoint entries with deterministic outputs | unit | `python3 -m pytest tests/test_dag_invalidation/test_pareto_3point.py -q` | ❌ W0 | ⬜ pending |
| 95-02-04 | 02 | 2 | (calc-first N2 sensitivity) | — | uni-variate ±10% produces 5 what_ifs entries | unit | `python3 -m pytest tests/test_dag_invalidation/test_what_ifs.py -q` | ❌ W0 | ⬜ pending |
| 95-02-05 | 02 | 2 | (calc-first N2 CI) | — | bootstrap 200 iter produces P5/P95 within MC bounds | unit | `python3 -m pytest tests/test_dag_invalidation/test_bootstrap_ci.py -q` | ❌ W0 | ⬜ pending |
| 95-02-06 | 02 | 2 | (LSFin compliance) | T-95-05 (anti-promise) | narrator emits « selon le modèle simplifié actuel » whenever credible_low/credible_high are non-None in the pack | unit | `python3 -m pytest tests/test_dag_invalidation/test_lsfin_annotation.py -q` | ❌ W0 | ⬜ pending |
| 95-02-07 | 02 | 2 | (full backend regression) | — | no regression vs baseline 6448 | integration | `cd services/backend && python3 -m pytest tests/ -q --ignore=tests/integration` | ✅ (existing infra) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Test count expected:** 14 phase-specific test entries (was 12 in v0 — +1 for staleness module split (05a + 05b) per BLOCKER-1 ; +1 for GatedResponse inputs_hash propagation per BLOCKER-3). Each row maps to one or more `<task>` blocks in the corresponding `*-PLAN.md`.

---

## Wave 0 Requirements

- [ ] `services/backend/tests/test_dag_invalidation/__init__.py` — empty package init
- [ ] `services/backend/tests/test_dag_invalidation/conftest.py` — shared fixtures (inputs_hash, scenario factory, alembic test DB harness)
- [ ] `services/backend/tests/fixtures/hash_parity_50.jsonl` — 50 input dicts for Python↔Dart hash parity
- [ ] `apps/mobile/tools/hash_parity_harness/main.dart` — pure-Dart harness using `dart:convert` + `package:crypto` (NO `financial_core/` imports per Path A — sidesteps Phase 92.7 calc_harness blocker)
- [ ] `apps/mobile/tools/hash_parity_harness/pubspec.yaml` — minimal pubspec with `crypto` dep only
- [ ] `services/backend/alembic/versions/{stamp}_phase_95_add_inputs_hash_superseded_by.py` — additive migration
- [ ] `tools/checks/pii_fixture_scan.py` — new lint that greps AHV + phone patterns on every JSONL before commit (registered in lefthook)
- [ ] **[BLOCKER-1 fix #1]** `services/backend/app/services/coach/staleness.py` — production module with `staleness_high(stored_hash, current_hash) -> bool` pure-function rule (DAG-03 backend half ; production read-path integration deferred to Phase 96 W2 per CONTEXT `<deferred>` block)

*Pyproject deps additions: `rfc8785>=0.1.4,<1.0.0`, `uuid_utils>=0.14.1,<1.0.0` (UUID7 backport because Python 3.14 not yet on Railway base image — RESEARCH §OQ-1 RESOLVED).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Alembic upgrade/downgrade roundtrip on staging DB clone | DAG-04 | Requires staging snapshot pull + replay (CI doesn't have prod-shape data) | (1) `railway run --service backend-staging-clone pg_dump > /tmp/staging.sql` (2) Restore to local PostgreSQL (3) `alembic upgrade head && alembic downgrade -1 && alembic upgrade head` (4) Verify schema unchanged via `pg_dump --schema-only` diff |
| Visual inspection of `ProjectionGroundingPack` JSON shape against Phase 96 narrator expectation | calc-first N2 | Phase 96 narrator templates aren't built yet ; manual inspection ensures shape is consumable | (1) Run a sample arbitrage scenario through the new emitter (2) Print resulting `ProjectionGroundingPack.model_dump_json(indent=2)` (3) Verify all 18 keys from CITATION_REGISTRY have corresponding entries (4) Confirm `credible_low`/`credible_high` populated for Decimal values, `None` for legal_constraints |
| Phase 95 → Phase 96 SOFT dependency contract handshake | sequencing-panel §1 | Cross-phase contract verification requires Phase 96 to exist | Deferred to Phase 96 Wave 2 verifier |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify (all 14 tasks above have automated checks)
- [ ] Wave 0 covers all MISSING references (8 W0 items listed — added staleness.py per BLOCKER-1 fix #1)
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter (toggle after planner reviews + W0 stubs land)
- [ ] **[2026-05-11 revision]** BLOCKER-1 (staleness.py extraction + SC#4(c) chain-reset test) addressed by rows 95-01-05a + 95-01-05b
- [ ] **[2026-05-11 revision]** BLOCKER-3 (GatedResponse inputs_hash propagation) addressed by row 95-02-01b

**Approval:** pending (planner agent will set `nyquist_compliant: true` once all W0 stubs are referenced in plan tasks)
