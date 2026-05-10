---
phase: 95-mvp-dag-invalidation
verified: 2026-05-11T00:00:00Z
status: passed
score: 4/4 DAG requirements verified
re_verification: false
deferred:
  - truth: "Dart financial_core/ projection models gain inputs_hash + superseded_by fields (ROADMAP SC#1 Dart half)"
    addressed_in: "Phase 96 W2"
    evidence: "ROADMAP Phase 95 phase-split note (2026-05-11): 'The DART half — apps/mobile/lib/services/financial_core/ projection-model field additions + calculator-wrapper read-path integration emitting staleness_iso = high on GroundingPackEntry — is deferred to Phase 96 W2 (consumer wiring + UI badges).'"
  - truth: "Calculator wrappers compute hash on read and return staleness:high flag through read-path (ROADMAP SC#2 read-path wiring)"
    addressed_in: "Phase 96 W2"
    evidence: "CONTEXT deferred block: 'Production read-path integration of staleness_high() — pure-function rule + unit tests ship in Phase 95 (staleness.py). Calling the rule from arbitrage_engine consumer and emitting staleness_iso=high on GroundingPackEntry is DEFERRED to Phase 96 W2 per SC#2 scope decision.'"
---

# Phase 95: MVP-DAG-INVALIDATION Verification Report

**Phase Goal:** Add `inputs_hash` + `superseded_by` on every projection. Calculator refuses stale cache when input hash differs from current profile hash. Closes silent stale-projection bug.
**Verified:** 2026-05-11
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | DAG-01: `compute_inputs_hash(dict) -> str` deterministic SHA256 (RFC 8785 + Decimal(0.01) quantize) exists and is tested | VERIFIED | `services/backend/app/services/coach/inputs_hash.py` — 79 lines, substantive. 10 unit tests in `test_inputs_hash.py` green (determinism, IEEE 754, bool/int, NaN/inf, numpy). |
| 2 | DAG-02: `new_projection_id() -> str` UUID7 wrapper + `ScenarioModel.superseded_by` nullable column exist | VERIFIED | `projection_id.py` (37 lines, uuid_utils backport). `scenario.py` line 33: `superseded_by = Column(String(36), nullable=True)`. 6 unit tests in `test_superseded_by.py` green. |
| 3 | DAG-03: `staleness_high(stored, current) -> bool` pure-function production module exists; SC#4(c) chain-reset test present | VERIFIED | `staleness.py` (37 lines). 7 tests in `test_staleness.py` including `test_recompute_resets_hash_chain`. pytest: 74/74 passed. |
| 4 | DAG-04: Additive Alembic migration adds nullable `inputs_hash` + `superseded_by` to `scenarios` table; idempotency guard present | VERIFIED | `alembic/versions/p95_dag_invalidation.py` — `down_revision = "29_05_magic_link_tokens"`, idempotency via `inspector.get_columns`, batch_alter_table downgrade. 4 migration tests green. |
| 5 | Python-Dart hash parity 50/50 byte-identical (R1 risk gate) | VERIFIED | `tests/fixtures/hash_parity_50.jsonl` (50 lines), `hash_parity_50_expected.jsonl` (50 lines) both exist. `test_hash_parity.py` 4 tests green including integration test. |
| 6 | `ProjectionGroundingPack` Pydantic v2 frozen+forbid contract replaces frozenset stub | VERIFIED | `grounding_pack.py` wholesale replaced (107 lines): `GroundingPackEntry`, `ParetoPoint`, `ProjectionGroundingPack` with `inputs_hash: str = Field(..., min_length=64, max_length=64)`, field_serializer for Decimal. 10 schema tests + 2 coupling tests green. |
| 7 | `compute_pareto_points` 3-point scalarisation MVP (D-10) implemented | VERIFIED | `pareto.py` (97 lines). 3 fixed PARETO_WEIGHT_SETS; scores trajectoires deterministically; returns exactly 3 ParetoPoint. 6/6 tests green. |
| 8 | `compute_what_ifs` ±10% uni-variate sensitivity (D-11) with 5 canonical perturb keys | VERIFIED | `sensitivity.py` (95 lines). PERTURB_KEYS tuple of 5. min/max bracket for credible_low/high invariant. 6/6 tests green. |
| 9 | `bootstrap_ci_p5_p95` frequentiste 200-iter numpy (D-12) | VERIFIED | `bootstrap_ci.py` (65 lines). Seed=42 by default, empty raises ValueError, returns (Decimal, Decimal). 7/7 tests green. |
| 10 | D-09 double-lookup in `_substitute_placeholders` + `gate()` (pack first, registry fallback, Sentry breadcrumb on miss) | VERIFIED | `citation_parser.py` lines 361+407: keyword-only `pack` kwarg. `grep -c "coach.grounding_pack.fallback"` returns 2. 9/9 double-lookup tests green including `test_pack_none_preserves_phase_94_behavior`. |
| 11 | 6 `GatedResponse` construction sites propagate `inputs_hash=pack.inputs_hash if pack else None` | VERIFIED | `grep -c "inputs_hash=pack.inputs_hash"` returns 6. Lines 465/494/503/547/556/569 confirmed. 2 propagation tests green. |
| 12 | `_run_narrator_with_gate(pack=None)` kwarg wired; both `_citation_gate` calls thread `pack=pack` | VERIFIED | `coach_chat.py` lines 3361+3382: `pack=pack` at both call sites. `test_coach_chat_wiring_pack_kwarg_threaded` green. |
| 13 | `banned_terms_python.py --lsfin-annotation` rule enforces verbatim FR « selon le modèle simplifié actuel » when credible fields present | VERIFIED | `tools/checks/banned_terms_python.py` lines 139-203: `--lsfin-annotation` CLI flag + `check_lsfin_annotation()`. `lefthook.yml` entry `lsfin_annotation_phase_95` scoped to 4 W2 modules. 5/5 tests green. |
| 14 | `pii_fixture_scan.py` lint exists and is wired in lefthook pre-commit | VERIFIED | `tools/checks/pii_fixture_scan.py` exists. `lefthook.yml` line 118: `pii_fixture_scan` entry. |
| 15 | Full backend suite 6522 passed, no regression vs baseline 6448 | VERIFIED | Live run: `6522 passed, 62 skipped, 1 xfailed, 1 warning in 108.18s`. Phase 94 byte-identity: `182 passed` in `tests/test_citation_gate/`. |

**Score:** 15/15 truths verified (4 DAG requirements + 11 derived implementation truths)

---

### Deferred Items

Items not yet met but explicitly addressed in later milestone phases. SC#1 (Dart half) and SC#2 (read-path wiring) are the two partial deliveries — documented in ROADMAP phase-split note and CONTEXT deferred block.

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | Dart `financial_core/` projection models gain `inputs_hash + superseded_by` fields | Phase 96 W2 | ROADMAP phase-split note: "The DART half — apps/mobile/lib/services/financial_core/ projection-model field additions — is deferred to Phase 96 W2 (consumer wiring + UI badges)." |
| 2 | Calculator-wrapper read-path calls `staleness_high()` and emits `staleness_iso="high"` on `GroundingPackEntry` | Phase 96 W2 | CONTEXT deferred block: "Calling the rule from arbitrage_engine consumer and emitting staleness_iso='high' on GroundingPackEntry is DEFERRED to Phase 96 W2 per SC#2 scope decision." |
| 3 | Sentry breadcrumb `coach.grounding_pack.fallback` verified E2E in production (Railway DSN) | Phase 96 W2 | SUMMARY 95-02 caveat: "Sentry breadcrumb production wiring NOT exercised E2E (deferred to Phase 96 W2)." |
| 4 | Phase 96 narrator templates enforce LSFin annotation at runtime when `credible_low/high` non-None | Phase 96 W2 | SUMMARY 95-02: "Phase 96 W2 narrator templates will be the actual runtime enforcement target; if any Phase 96 narrator file ships credible_low/high values without the FR annotation, pre-commit fails." |

Note: Phase 96 success criteria as currently defined in ROADMAP focus on the Chat-as-Verb UI layer (MintCardActionBar, MintChatOverlay, 3-turn cap). The Dart-side financial_core wiring items are scoped by the Phase 95 CONTEXT deferred block as "Phase 96 W2 consumer wiring." They are referenced in Phase 95 ROADMAP's phase-split note — verified as intentionally scheduled forward, not an oversight.

---

### Required Artifacts

| Artifact | Provides | Status | Details |
|----------|----------|--------|---------|
| `services/backend/app/services/coach/inputs_hash.py` | DAG-01 compute_inputs_hash | VERIFIED | 79 lines, substantive, exports `compute_inputs_hash` + `_quantize_floats` |
| `services/backend/app/services/coach/projection_id.py` | DAG-02 new_projection_id UUID7 | VERIFIED | 37 lines, uuid_utils backport, well-documented migration path |
| `services/backend/app/services/coach/staleness.py` | DAG-03 staleness_high | VERIFIED | 37 lines, zero imports beyond stdlib typing |
| `services/backend/alembic/versions/p95_dag_invalidation.py` | DAG-04 additive migration | VERIFIED | down_revision=29_05_magic_link_tokens, idempotency guard, batch_alter downgrade |
| `services/backend/app/models/scenario.py` | DAG-04 ORM columns | VERIFIED | inputs_hash String(64) nullable + superseded_by String(36) nullable at lines 32-33 |
| `services/backend/app/services/coach/grounding_pack.py` | D-07/D-08 contract | VERIFIED | 113 lines, replaces Phase 93.5 stub, Pydantic v2 frozen+forbid, backward-compat GROUNDING_PACK_KEYS_REGISTRY kept |
| `services/backend/app/services/coach/pareto.py` | D-10 3-point Pareto | VERIFIED | 97 lines, PARETO_WEIGHT_SETS tuple, deterministic scorer |
| `services/backend/app/services/coach/sensitivity.py` | D-11 what_ifs | VERIFIED | 95 lines, PERTURB_KEYS tuple 5 keys, min/max bracket |
| `services/backend/app/services/coach/bootstrap_ci.py` | D-12 bootstrap CI | VERIFIED | 65 lines, numpy 200-iter, Decimal output |
| `services/backend/tests/fixtures/hash_parity_50.jsonl` | R1 parity fixtures | VERIFIED | 50 lines |
| `services/backend/tests/fixtures/hash_parity_50_expected.jsonl` | R1 golden hashes | VERIFIED | 50 lines |
| `apps/mobile/tools/hash_parity_harness/main.dart` | D-03 Dart harness | VERIFIED | exists, pubspec.yaml + pubspec.lock present |
| `tools/checks/pii_fixture_scan.py` | D-14 PII lint | VERIFIED | exists, lefthook entry confirmed |
| `tools/checks/banned_terms_python.py` (extended) | D-14 LSFin annotation | VERIFIED | --lsfin-annotation flag at line 189, check_lsfin_annotation() at line 158 |
| `services/backend/tests/test_dag_invalidation/` (13 files) | All test coverage | VERIFIED | __init__.py, conftest.py, 11 test files — 74 tests green |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `citation_parser._substitute_placeholders` | `ProjectionGroundingPack.entries` | `pack.entries.get(key)` first, registry fallback | WIRED | Lines 379-399, keyword-only `pack` kwarg, Sentry breadcrumb on miss |
| `citation_parser.gate()` | 6 `GatedResponse` sites | `inputs_hash=pack.inputs_hash if pack else None` | WIRED | grep count = 6, lines 465/494/503/547/556/569 |
| `coach_chat._run_narrator_with_gate` | `citation_parser.gate()` | `pack=pack` kwarg threading | WIRED | Lines 3361 + 3382, both `_citation_gate` call sites |
| `pareto.compute_pareto_points` | `grounding_pack.ParetoPoint` | `from app.services.coach.grounding_pack import ParetoPoint` | WIRED | pareto.py line 20 |
| `sensitivity.compute_what_ifs` | `grounding_pack.GroundingPackEntry` | `from app.services.coach.grounding_pack import GroundingPackEntry` | WIRED | sensitivity.py line 28 |
| `alembic p95_dag_invalidation` | `scenarios` table | `op.add_column("scenarios", ...)` | WIRED | down_revision chain: 29_05_magic_link_tokens -> p95_dag_invalidation, single head verified |
| `ScenarioModel` | `alembic p95` columns | `Column(String(64), nullable=True)` + `Column(String(36), nullable=True)` | WIRED | scenario.py lines 32-33 |
| `staleness_high()` | Production read-path | NOT wired in Phase 95 production | DEFERRED | Explicitly deferred to Phase 96 W2 — pure-function rule exists, consumer wiring is Phase 96 scope |

---

### Data-Flow Trace (Level 4)

Phase 95 ships a **plumbing layer**, not a user-visible rendering surface. All seven production modules (`inputs_hash.py`, `projection_id.py`, `staleness.py`, `grounding_pack.py`, `pareto.py`, `sensitivity.py`, `bootstrap_ci.py`) are pure-Python compute contracts consumed by downstream callers. The `pack=None` default at all Phase 95 production call sites (coach_chat.py) means no live data flows through the pack in Phase 95 — this is intentional. Phase 96 W2 wires the real `arbitrage_engine` outputs.

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `inputs_hash.py:compute_inputs_hash` | `inputs: dict` | Caller-supplied at call time | Yes — deterministic pure function | FLOWING (unit + parity tested) |
| `grounding_pack.py:ProjectionGroundingPack` | Pack fields | Phase 96 W2 caller (arbitrage_engine) | Not yet wired in production | DEFERRED — contract surface ready, Phase 96 wires it |
| `citation_parser:_substitute_placeholders` | `pack` kwarg | `pack=None` in Phase 95 production | Registry-only fallback (Phase 94 behavior preserved) | FLOWING — double-lookup path tested; pack=None path byte-identical to Phase 94 |
| `pareto.py:compute_pareto_points` | `trajectoires: list` | Phase 96 W2 (arbitrage_engine outputs) | Synthetic dict inputs in Phase 95 tests | DEFERRED — compute logic correct, real inputs wire in Phase 96 |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Phase 95-specific tests green | `cd services/backend && python3 -m pytest tests/test_dag_invalidation/ -q` | 74 passed, 1 warning | PASS |
| Full backend suite no regression | `python3 -m pytest tests/ -q --ignore=tests/integration` | 6522 passed, 62 skipped, 1 xfailed | PASS |
| Phase 94 byte-identity preserved | `python3 -m pytest tests/test_citation_gate/ -q` | 182 passed | PASS |
| inputs_hash module importable | `python3 -c "from app.services.coach.inputs_hash import compute_inputs_hash"` | SUMMARY: import + 10 tests green | PASS |
| grounding_pack Pydantic contract | `test_grounding_pack_schema.py::test_schema_frozen_extra_forbid` | 10/10 schema tests green | PASS |
| Alembic single head | `python3 -m alembic heads` | Single head `p95_dag_invalidation` (SUMMARY evidence) | PASS (cited in SUMMARY 95-01 deviations) |
| Hash parity 50/50 | `test_hash_parity.py::test_python_dart_parity_50_50` | 4/4 parity tests green | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| DAG-01 | 95-01 | inputs_hash on every projection | SATISFIED | `inputs_hash.py` + `ScenarioModel.inputs_hash` col; 10 unit tests; 50/50 parity |
| DAG-02 | 95-01 | superseded_by chain | SATISFIED | `projection_id.py` UUID7 + `ScenarioModel.superseded_by` col; 6 unit tests |
| DAG-03 | 95-01 | staleness=high flag | SATISFIED (backend rule) | `staleness.py` production module; 7 tests incl. SC#4(c) chain-reset; read-path wiring deferred to Phase 96 W2 per CONTEXT |
| DAG-04 | 95-01 | Additive migration (hash nullable for backward compat) | SATISFIED | `p95_dag_invalidation.py`; idempotency guard; both cols nullable; 4 migration tests |

ROADMAP SC#3 ("Migration is additive: inputs_hash nullable, zero forced recomputation"): FULLY SATISFIED.
ROADMAP SC#4 (test covers a/b/c): SATISFIED — `test_staleness.py` covers all three sub-cases including `test_recompute_resets_hash_chain`.
ROADMAP SC#1 + SC#2 (Dart half + read-path): PARTIAL — backend half shipped, Dart half + live read-path deferred to Phase 96 W2 per ROADMAP phase-split note.

---

### Anti-Patterns Found

No production stubs detected. Scanned all 7 production modules:
- Zero `TODO`/`FIXME`/`PLACEHOLDER`/`pass` stubs in production code
- Zero `return null` / `return {}` / `return []` in computation paths
- Zero hardcoded empty data passed to rendering surfaces (Phase 95 is backend-only compute)

The two grep hits on `grounding_pack.py` lines 6 and 18 for "placeholder" are in docstring text referring to the citation-gate `{{cite:<key>}}` placeholder syntax — not code stubs.

Pre-existing issue (OUT OF SCOPE, logged for traceability):
- `coach_chat.py:3079`: `Salaire assure LPP` — pre-existing banned term "assure" from commit 30c6d2b6 (2026-04-17, 3 weeks before Phase 95). Not introduced by Phase 95. Default banned-terms lint doesn't catch it because `coach_chat.py` is not in the Phase 95 W2 scope for `--lsfin-annotation`. To be addressed in a separate perimeter.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `coach_chat.py` | 3079 | `Salaire assure LPP` (banned term "assure") | Warning | Pre-existing, out of Phase 95 scope. No impact on DAG-invalidation goal. |

---

### Human Verification Required

None. Phase 95 is a backend-only compute + plumbing layer with no user-visible UI surface. All acceptance criteria are mechanically verifiable:
- Test suites green (live run confirmed)
- File existence and substantiveness confirmed via direct read
- Key links confirmed via grep
- Hash parity confirmed via parity test + fixture files

The one manual gate from VALIDATION.md (D-17 — alembic roundtrip on staging DB clone) is explicitly marked `autonomous: false` and is a pre-merge-to-dev gate, not a phase-close blocker. Evidence from SUMMARY 95-01: local SQLite roundtrip `upgrade head -> downgrade -1 -> upgrade head` all exit 0.

---

### Gaps Summary

No gaps. All 4 DAG requirements are satisfied. The 2 deferred ROADMAP SCs (SC#1 Dart half + SC#2 read-path) are explicitly documented in the ROADMAP phase-split note and CONTEXT deferred block as intentionally scheduled for Phase 96 W2. They do not constitute gaps — they are tracked forward-work items with clear ownership.

---

## Commit Evidence

| Commit | Description |
|--------|-------------|
| `30381bad` | chore: Wave 0 scaffold (deps + test dirs + PII lint + lefthook) |
| `cb613e01` | feat: inputs_hash.py compute_inputs_hash + _quantize_floats (DAG-01) |
| `adbda907` | feat: projection_id.py new_projection_id UUID7 wrapper (DAG-02) |
| `1296e7a7` | feat: alembic p95 + ScenarioModel ext + staleness.py + tests (DAG-03/04) |
| `93baff1c` | feat: hash_parity 50/50 byte-identical Python<->Dart (DAG-01 R1) |
| `fb2b13aa` | feat: ProjectionGroundingPack + GroundingPackEntry + ParetoPoint (D-07/D-08) |
| `e316ffbe` | feat: compute_pareto_points 3-point scalarisation (D-10) |
| `a037c56d` | feat: compute_what_ifs +/-10% uni-variate sensitivity (D-11) |
| `8f474391` | feat: bootstrap_ci_p5_p95 numpy 200-iter (D-12) |
| `e6a4a12f` | feat: D-09 double-lookup + pack threading + 6 GatedResponse propagation sites |
| `debe24f1` | feat: banned_terms_python.py --lsfin-annotation rule (D-12) |
| `206e7ab2` | docs: Wave 1 close — SUMMARY + STATE + VERIFICATION-REPORT |
| `29bb08de` | docs: Wave 2 close — SUMMARY + STATE + VERIFICATION-REPORT |

---

_Verified: 2026-05-11_
_Verifier: Claude (gsd-verifier)_
_Branch: feature/S94-mvp-citation-gate_
