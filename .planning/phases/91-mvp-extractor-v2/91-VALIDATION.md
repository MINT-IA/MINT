---
phase: 91
slug: mvp-extractor-v2
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-09
---

# Phase 91 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Source: 91-RESEARCH.md §7.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 7.x |
| **Config file** | `services/backend/pyproject.toml` (existing) |
| **Quick run command** | `cd services/backend && python3 -m pytest tests/test_llm_extractor.py tests/test_coach_chat_dual_llm.py -x` |
| **Full suite command** | `cd services/backend && python3 -m pytest tests/ -q` |
| **Estimated runtime** | ~5s quick, ~60s full (≥6047 tests per Phase 90 baseline) |

---

## Sampling Rate

- **After every task commit:** Run quick run command (`tests/test_llm_extractor.py + tests/test_coach_chat_dual_llm.py -x`)
- **After every plan wave:** Run full suite command (`pytest tests/ -q`)
- **Before `/gsd-verify-work`:** Full suite must be green AND Maestro G1 flow PASS AND Stage 3 narrator eval ≥95% Sonnet pass-rate
- **Max feedback latency:** 5s on commit, 60s on wave merge

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| T0.1 | 91-00 | 0 | EXTR-03 (refactor) | — | _BASE_SYSTEM_PROMPT split into named blocks; legacy + narrator paths assemble correctly | unit | `pytest services/backend/tests/test_claude_coach_service.py::test_base_system_prompt_blocks -x` | ❌ W0 | ⬜ pending |
| T0.2 | 91-00 | 0 | All EXTR | — | `COACH_DUAL_LLM_ENABLED` flag exists in `app.core.config`, defaults False | unit | `pytest services/backend/tests/test_config.py::test_coach_dual_llm_flag_defaults_false -x` | ❌ W0 | ⬜ pending |
| T0.3 | 91-00 | 0 | EXTR-07 | — | Maestro flow stub passes against current single-LLM (regression baseline) | maestro | `bash tools/simulator/walker_audit_tap_render.sh flow_extractor_captures_age_canton` | ❌ W0 | ⬜ pending |
| T1.1 | 91-01 | 1 | EXTR-02 | T-91-01 (prompt injection in extractor input) | Pydantic models reject malformed/non-allowlisted keys | unit | `pytest services/backend/tests/test_extractor_schema.py -x` | ❌ W0 | ⬜ pending |
| T1.2 | 91-01 | 1 | EXTR-02, EXTR-05 | T-91-02 (hallucinated source_quote) | `run_llm_extractor` returns ExtractorOutput; source_quote substring check; 2nd-failure → empty | unit | `pytest services/backend/tests/test_llm_extractor.py -x` (~12 tests) | ❌ W0 | ⬜ pending |
| T2.1 | 91-02 | 2 | EXTR-01, EXTR-05 | T-91-03 (stale profile read) | Extractor runs BEFORE narrator; merged facts persisted; regex floor wins on conflict | unit | `pytest services/backend/tests/test_coach_chat_dual_llm.py::test_extractor_runs_before_narrator -x` | ❌ W0 | ⬜ pending |
| T2.2 | 91-02 | 2 | EXTR-04 | T-91-04 (narrator hallucinates removed tool) | narrator's `stripped_tools` list does NOT contain save_fact/save_insight | unit | `pytest services/backend/tests/test_coach_chat_dual_llm.py::test_narrator_tools_no_save_fact -x` | ❌ W0 | ⬜ pending |
| T2.3 | 91-02 | 2 | EXTR-03 | — | Narrator system prompt has NO « EXTRACTION DE PROFIL » block (string absent) | unit | `pytest services/backend/tests/test_coach_chat_dual_llm.py::test_narrator_prompt_has_no_extraction_directives -x` | ❌ W0 | ⬜ pending |
| T2.4 | 91-02 | 2 | EXTR-06 | — | Per-turn cost regression bounded (mocked tokens, asserts ratio ≤+30% post-mitigations) | integration | `pytest services/backend/tests/integration/test_dual_llm_cost.py -x` | ❌ W0 | ⬜ pending |
| T3.1 | 91-03 | 3 | D-01 (Stage 3 eval gate) | — | 50-fixture eval pack scores Haiku narrator vs Sonnet baseline | eval | `python services/backend/tools/eval_narrator.py --model haiku --fixtures tests/fixtures/narrator_eval_50.jsonl` | ❌ W0 | ⬜ pending |
| T3.2 | 91-03 | 3 | EXTR-07 | — | Maestro G1 multi-fact flow PASSES on booted sim (« j'ai 80k de salaire à Lausanne, je suis né en 1990 » → canton=VD + incomeGrossYearly=80000 + birthYear=1990) | maestro | `bash tools/simulator/walker_audit_tap_render.sh flow_extractor_captures_age_canton` | ❌ W0 | ⬜ pending |
| T-Anti | — | all | All EXTR + 25 existing | — | `tests/test_profile_extractor.py` 25 tests still pass + `test_narrator_refuses_uncited_numbers.py` skip-marked | unit | `pytest services/backend/tests/test_profile_extractor.py tests/test_narrator_refuses_uncited_numbers.py -q` | ✅ existing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `services/backend/tests/test_extractor_schema.py` — Pydantic schema tests for `ExtractedFact` / `ExtractorOutput` (T1.1)
- [ ] `services/backend/tests/test_llm_extractor.py` — happy path + 6 edge cases per RESEARCH §4 Stage 1 T1.3 (T1.2)
- [ ] `services/backend/tests/test_coach_chat_dual_llm.py` — flag-on/off behavior + extractor-before-narrator + tool/prompt diffs (T2.1-T2.3)
- [ ] `services/backend/tests/integration/test_dual_llm_cost.py` — token-count regression test (T2.4)
- [ ] `services/backend/tests/test_narrator_refuses_uncited_numbers.py` — Phase 94 anticipation stub (skip-marked)
- [ ] `services/backend/tools/eval_narrator.py` — eval harness for Stage 3 (T3.1)
- [ ] `services/backend/tests/fixtures/narrator_eval_50.jsonl` — 50 hand-curated turns from PII-scrubbed prod logs (T3.1)
- [ ] `tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml` — Maestro G1 multi-fact flow (T0.3, T3.2)
- [ ] `tests/fixtures/extractor_baseline_2026-05.md` — Stage 0 telemetry baseline summary (D-07)

*Framework install: none — pytest already wired (Phase 90 baseline)*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Stage 3 narrator eval — « tone is on-brand » | D-01, D-06 | Aesthetic/brand judgment cannot be automated; ComplianceGuard pass-rate is automated, on-brand is human | Julien reviews 50 narrator outputs side-by-side (Sonnet vs Haiku) on the eval fixtures; signs off in PR description if Haiku ≥95% comparable |
| G2 Device walkthrough on TestFlight | All EXTR | Per CLAUDE.md §9 0-trust + memory `feedback_device_gates`; Maestro G1 covers sim, G2 covers real device | Julien runs MINT via TestFlight build, sends « j'ai 80k de salaire à Lausanne », verifies profile updates correctly + narrator response quality |
| Stage 0 telemetry baseline — « save_fact under-call rate » | D-07 | Requires reading 7 days of prod Sentry breadcrumbs / log aggregation, narrative summary not check command | Julien (or assistant) greps `profile_extractor: persisted X fact(s)` over 7d, computes empirical under-call rate, writes summary to `tests/fixtures/extractor_baseline_2026-05.md` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s on commit, < 60s on wave
- [ ] `nyquist_compliant: true` set in frontmatter (post-Wave 0 completion)

**Approval:** pending — flip after Wave 0 complete, all task tests green, Maestro G1 PASS, Stage 3 eval ≥95% Sonnet pass-rate, Julien G2 device sign-off
