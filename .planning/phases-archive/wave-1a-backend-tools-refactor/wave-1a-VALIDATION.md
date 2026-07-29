---
phase: wave-1a
slug: wave-1a-backend-tools-refactor
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-14
---

# Wave 1a — Validation Strategy

> Per-phase validation contract. Wave 1a is backend-Python-only. No Flutter test layer.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 7.x (existing `services/backend/pyproject.toml`) |
| **Config file** | `services/backend/pyproject.toml` (`tool.pytest.ini_options`) + `services/backend/conftest.py` |
| **Quick run command** | `cd services/backend && python3 -m pytest tests/test_coach_tools_parity.py tests/test_couple_optimizer.py tests/test_memory_bm25.py -q` |
| **Full suite command** | `cd services/backend && python3 -m pytest tests/ -q` |
| **Estimated runtime** | ~6s quick, ~90s full (current baseline ~6567 tests) |

---

## Sampling Rate

- **After every task commit:** Run quick command (parity + couple_optimizer + memory tests)
- **After every plan wave:** Run full suite (target ≥6617 pass)
- **Before 5-gate close-out:** Full suite green + lints green (`banned_terms_python.py`, `accent_lint_fr.py`)
- **Max feedback latency:** ≤90s

---

## Per-Task Verification Map (per-plan; planner fills task-level rows)

| Plan | Wave | Requirement | Test Type | Automated Command | Wave 0 Status |
|------|------|-------------|-----------|-------------------|---------------|
| 00 — scaffolding (Wave 0 prerequisite) | 0 | WAVE1A-09 + WAVE1A-10 | unit | `pytest tests/test_coach_tools_scaffolding.py -q` | ✅ (this plan IS W0) |
| 01 — `get_budget_status` server-side | 1 | WAVE1A-01 | unit + parity | `pytest tests/test_coach_tools_parity.py::test_budget_status_parity -q` | ❌ W0 (parity fixture) |
| 02 — `get_retirement_projection` server-side | 1 | WAVE1A-02 | unit + parity | `pytest tests/test_coach_tools_parity.py::test_retirement_projection_parity -q` | ❌ W0 (parity fixture) |
| 03 — `get_cross_pillar_analysis` server-side | 1 | WAVE1A-03 | unit + parity | `pytest tests/test_coach_tools_parity.py::test_cross_pillar_parity -q` | ❌ W0 (parity fixture) |
| 04 — `get_couple_optimization` Python port | 1 | WAVE1A-05 | unit + parity | `pytest tests/test_couple_optimizer.py tests/test_coach_tools_parity.py::test_couple_parity -q` | ❌ W0 (parity fixture) |
| 05 — `retrieve_memories` BM25 wrapper | 1 | WAVE1A-06 | unit + parity | `pytest tests/test_memory_bm25.py tests/test_coach_tools_parity.py::test_memory_parity -q` | ❌ W0 (parity fixture) |
| 06 — `get_cap_status` CHF garde | 1 | WAVE1A-04 | unit | `pytest tests/test_cap_garde.py -q` | ❌ W0 (parity fixture) |
| 07 — Parity harness + seed fixtures | 2 | WAVE1A-08 | infra | `wc -l tests/fixtures/coach_tools_parity_v1.jsonl ; pytest tests/test_coach_tools_parity.py -q` | ❌ W0 (new files) |
| 08 — Rollout flags + 5-gate close | 3 | WAVE1A-10 | infra + integration | `pytest tests/test_coach_tools_dispatcher_flags.py -q ; bash tools/checks/wave_1a_close.sh` | ❌ W0 (new files) |

*Status legend: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky · ❌ W0 (parity fixture) = unit test self-bootstraps in the plan's Task 1; parity verification waits for plan-07 fixtures · ❌ W0 (new file) = plan creates the test file as part of its own scaffolding*

**W0 column clarification (checker iteration-1 issue #5):** Plans 01-06 each create their own unit-test file inside their plan (TDD-style — RED in Task 1, GREEN in Task 1 once code is added). They do NOT need Wave 0 to pre-create the test file. The « W0 (parity fixture) » mark means the PARITY layer of verification (cross-comparing legacy `_format_*` vs new `_compute_*` on a shared fixture profile) is delivered by plan-07. Unit tests bootstrap themselves.

---

## Wave 0 Requirements (planner must add as Wave-0 task in plan-07)

- [ ] `services/backend/tests/test_coach_tools_parity.py` — pytest harness loading `coach_tools_parity_v1.jsonl`
- [ ] `services/backend/tests/fixtures/coach_tools_parity_v1.jsonl` — 18 fixtures (3 archetypes × 6 tools)
- [ ] `services/backend/tests/test_couple_optimizer.py` — ≥18 unit tests
- [ ] `services/backend/tests/test_memory_bm25.py` — ≥10 unit tests
- [ ] `services/backend/tests/test_cap_garde.py` — ≥5 unit tests
- [ ] `services/backend/tests/test_coach_tools_dispatcher_flags.py` — flag ON/OFF dispatcher routing
- [ ] `services/backend/app/models/coach_tools/__init__.py` — Pydantic v2 response models (5 classes)
- [ ] `services/backend/app/services/memory/__init__.py` — `bm25_index(user_id)` + `retrieve(topic, user_id, k=5)`
- [ ] `services/backend/app/services/couple_optimizer/__init__.py` — Python port
- [ ] `services/backend/tools/checks/wave_1a_close.sh` — 5-gate close shell script (runs G3 + G5 lints)

*All `wave_0_complete: true` once plan-07 ships. Other plans depend on these scaffolds.*

---

## Manual-Only Verifications (G2 device gate)

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Coach card "explique" tap invokes server-side tool with flag ON | WAVE1A-01..05 | Real LLM call to Anthropic API + Maestro tap on iOS sim | Run `tools/simulator/walker.sh --flow coach_tools_server_side_smoke` against staging build with `COACH_TOOL_SERVER_SIDE_*_ENABLED=true` env. Maestro flow + `idb ui describe-all` snapshot. |
| Sentry breadcrumb emission visible on staging Sentry project | WAVE1A-01..05 | External system | Trigger one of each tool via staging chat. Confirm `coach.tool.<name>.invoked` breadcrumbs appear in Sentry staging project within 10s. |
| `coach.cap.cap_chf_uncited` Sentry breadcrumb fires when garde triggers | WAVE1A-04 | External Sentry | Inject test cap text "tu peux économiser 1'250 CHF" into staging coach response. Confirm breadcrumb fires + response rewrites to `[montant indisponible]`. |
| Julien G2 device walkthrough on TestFlight | All | Per memory `feedback_perimeter_5_gates` | Build feature branch → staging → TestFlight. Julien runs each refactored tool from a coach card and confirms response visible. |

---

## Validation Sign-Off

- [ ] All 8 plans have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive plans without automated verify (Wave 1a passes — each plan has its own parity test)
- [ ] Wave 0 (plan-07) covers all MISSING references
- [ ] No watch-mode flags (CI mode only)
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter post-plan-checker

**Approval:** pending plan-checker green.
