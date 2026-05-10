---
phase: 94
slug: mvp-citation-gate
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-10
---

# Phase 94 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `94-RESEARCH.md` §Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 8.x + pytest-asyncio 0.23+ + hypothesis ≥6.111 (already in `services/backend/pyproject.toml:50-56`) |
| **Config file** | `services/backend/pyproject.toml` (`[tool.pytest.ini_options]` line 108) |
| **Quick run command** | `cd services/backend && python3 -m pytest tests/test_citation_gate/ -q -x` |
| **Full suite command** | `cd services/backend && python3 -m pytest tests/ -q --ignore=tests/integration` |
| **Estimated runtime** | quick ~5s · full ~3–5 min |

---

## Sampling Rate

- **After every task commit:** `cd services/backend && python3 -m pytest tests/test_citation_gate/ -q -x`
- **After every plan wave:** `cd services/backend && python3 -m pytest tests/ -q --ignore=tests/integration` — must be ≥6251 (Phase 93.5 baseline) + new tests
- **Before `/gsd-verify-work 94`:** Stage 3 eval pack ≥95% Sonnet / ≥90% Haiku + Maestro G1 PASS + full suite green
- **Max feedback latency:** ≤30s for `tests/test_citation_gate/`, ≤300s for full suite

---

## Per-Task Verification Map

| Req ID | Plan | Wave | Behavior | Test Type | Automated Command | Status |
|--------|------|------|----------|-----------|-------------------|--------|
| GATE-01 | 94-01 | 0 | 5 number-family regex coverage (CHF/EUR/USD, %, legal article, duration, regulatory constant) | unit | `pytest tests/test_citation_gate/test_number_detection.py -x` | ⬜ pending |
| GATE-01 | 94-01 | 0 | Property — no number escapes detection (`hypothesis`) | property | `pytest tests/test_citation_gate/test_number_detection.py::test_property_all_numbers_detected -x` | ⬜ pending |
| GATE-01 | 94-01 | 0 | Regex-engine smoke — ≤50ms on raw `finditer` over 200-token input (gate-level p95 lands in Wave 1, see D-17 row) | unit | `pytest tests/test_citation_gate/test_regex_engine_performance.py -x` | ⬜ pending |
| GATE-02 | 94-01 | 0 | `CitationSource` Pydantic frozen, extra=forbid | unit | `pytest tests/test_citation_gate/test_registry_contract.py -x` | ⬜ pending |
| GATE-02 | 94-01 | 0 | `CITATION_REGISTRY` keys ⊆ union of bundles' `citation_allowlist` | invariant | `pytest tests/test_citation_gate/test_registry_contract.py::test_registry_subset_of_bundle_allowlists -x` | ⬜ pending |
| GATE-02 | 94-01 | 0 | No recursive citation keys | unit | `pytest tests/test_citation_gate/test_registry_contract.py::test_no_recursive_keys -x` | ⬜ pending |
| GATE-03 | 94-02 | 1 | Retry-once budget never exceeds 1 | unit | `pytest tests/test_citation_gate/test_retry_flow.py::test_max_one_retry -x` | ⬜ pending |
| GATE-03 | 94-02 | 1 | Reprompt addendum text matches D-09 verbatim | unit | `pytest tests/test_citation_gate/test_retry_flow.py::test_reprompt_addendum_verbatim -x` | ⬜ pending |
| GATE-03 | 94-02 | 1 | Fallback text matches D-10 verbatim (no template variables) | unit | `pytest tests/test_citation_gate/test_fallback.py::test_fallback_verbatim -x` | ⬜ pending |
| GATE-04 | 94-02 | 1 | `(vous\|tu)\s+(ferez\|...)\s+\d` rejected EVEN WITH citation | unit | `pytest tests/test_citation_gate/test_banned_claims.py::test_affirmative_verb_with_citation -x` | ⬜ pending |
| GATE-04 | 94-02 | 1 | Banned-claim retry reprompts at the conditional (D-13) | unit | `pytest tests/test_citation_gate/test_banned_claims.py::test_d13_reprompt_keeps_citation -x` | ⬜ pending |
| D-03 | 94-01 | 0 | Meta-quote / negation correctness (port 15 tests from Wave 4) | unit | `pytest tests/test_citation_gate/test_meta_helpers.py -x` | ⬜ pending |
| D-07 | 94-02 | 1 | Flag-ON intersect with `compiled.citation_allowlist` | integration | `pytest tests/test_citation_gate/test_bundle_intersect.py -x` | ⬜ pending |
| D-07 | 94-02 | 1 | Flag-OFF fallback to global `CITATION_REGISTRY` | integration | `pytest tests/test_citation_gate/test_global_registry_fallback.py -x` | ⬜ pending |
| D-18 | 94-02 | 1 | Sentry breadcrumb non-PII counts/labels only | unit | `pytest tests/test_citation_gate/test_telemetry.py -x` | ⬜ pending |
| D-19 | 94-02 | 1 | `COACH_CITATION_GATE_ENABLED` flag in config (default false) | unit | `pytest tests/test_citation_gate/test_config.py -x` | ⬜ pending |
| D-20 | 94-02 | 1 | Flag-OFF byte-identity vs captured snapshots (mirror Phase 93.5-02 Task 3) | snapshot | `pytest tests/test_citation_gate/test_byte_identity_flag_off.py -x` | ⬜ pending |
| D-17 | 94-02 | 1 | gate() end-to-end p95 ≤50ms on 4kB FR narrative (H3 fix iter 1 — gate-level perf, not just regex primitives) | unit | `pytest tests/test_citation_gate/test_gate_performance.py -x` | ⬜ pending |
| D-04#4 | 94-02 | 1 | Placeholder-body strip — digits inside `{{cite:<key>}}` are exempt (M3 fix iter 1) | unit | `pytest tests/test_citation_gate/test_number_detection.py::test_d04_exception_4_placeholder_body_stripped -x` | ⬜ pending |
| H1 | 94-02 | 1 | `_compiled_bundle = None` upstream initializer — wrapper does NOT raise NameError on flag-OFF / except / elif / else paths | integration | `pytest tests/test_citation_gate/test_bundle_intersect.py::test_compiled_bundle_none_on_compile_failure_does_not_raise tests/test_citation_gate/test_bundle_intersect.py::test_compiled_bundle_none_on_flag_off tests/test_citation_gate/test_bundle_intersect.py::test_compiled_bundle_none_on_dual_llm_branch -x` | ⬜ pending |
| M2 | 94-02 | 1 | Documented v1 banned-claim regex false-negatives (3rd-person, infinitive, garanti routed to compliance_guard) | unit | `pytest tests/test_citation_gate/test_banned_claims.py::test_known_v1_banned_claim_false_negatives -x` | ⬜ pending |
| GATE-01..04 | 94-03 | 2 | Stage 3 50-fixture pack ≥95% Sonnet / ≥90% Haiku | live eval | `python3 -m tools.eval_narrator --model sonnet --fixtures tests/fixtures/citation_gate_eval_50.jsonl --out eval-runs/94-eval-sonnet-gate-on.json --gate=on` | ⬜ pending |
| D-16 | 94-03 | 2 | Maestro G1 — profile-empty user asks "combien je gagne" → no CHF number | manual+sim | `tools/simulator/walker_audit_tap_render.sh tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `services/backend/tests/test_citation_gate/__init__.py`
- [ ] `services/backend/tests/test_citation_gate/test_number_detection.py` — GATE-01 (D-02 5-family regex + hypothesis property)
- [ ] `services/backend/tests/test_citation_gate/test_meta_helpers.py` — D-03 (port 15 tests from `test_eval_narrator_meta_scorer.py`)
- [ ] `services/backend/tests/test_citation_gate/test_registry_contract.py` — GATE-02 (D-05/D-06 frozen schema)
- [ ] `services/backend/tests/test_citation_gate/test_regex_engine_performance.py` — D-17 sanity on raw regex passes only (H3 fix iter 1 — renamed from test_performance.py ; the gate-level perf test lands in Wave 1)
- [ ] `services/backend/tests/test_citation_gate/test_byte_identity_flag_off.py` — D-20 (snapshot test)
- [ ] No new framework install required.

## Wave 1 Requirements

- [ ] `services/backend/tests/test_citation_gate/test_retry_flow.py` — GATE-03 (D-08/D-09)
- [ ] `services/backend/tests/test_citation_gate/test_fallback.py` — GATE-03 (D-10)
- [ ] `services/backend/tests/test_citation_gate/test_banned_claims.py` — GATE-04 (D-12/D-13) + M2 v1-scope false-negative regression (iter 1)
- [ ] `services/backend/tests/test_citation_gate/test_bundle_intersect.py` — D-07 flag-ON + H1 regression suite (3 tests covering flag-OFF / KeyError / elif paths — iter 1)
- [ ] `services/backend/tests/test_citation_gate/test_global_registry_fallback.py` — D-07 flag-OFF
- [ ] `services/backend/tests/test_citation_gate/test_telemetry.py` — D-18 breadcrumb hygiene
- [ ] `services/backend/tests/test_citation_gate/test_gate_performance.py` — D-17 end-to-end p95 ≤50ms (H3 fix iter 1 — gate-level perf)
- [ ] EXTEND `services/backend/tests/test_citation_gate/test_number_detection.py` (file authored in Wave 0) with `test_d04_exception_4_placeholder_body_stripped` (M3 fix iter 1)

## Wave 2 Requirements

- [ ] `services/backend/tests/fixtures/citation_gate_eval_50.jsonl` — D-14 (50 fixtures with `expected_gate_outcome:` field)
- [ ] `services/backend/tools/eval_narrator.py` — extend with `--gate={on,off}` flag
- [ ] `tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml` — D-16

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 50-fixture live eval ≥95% Sonnet / ≥90% Haiku | GATE-01..04 | Requires real Anthropic API | (1) `railway variables get ANTHROPIC_API_KEY --service backend-staging`, (2) export, (3) run eval-narrator with `--gate=on` and `--gate=off`, (4) compare against thresholds |
| Maestro G1 walkthrough on iPhone 17 Pro sim — profile-empty user asks "combien je gagne ?" → no fabricated CHF number | D-16 | Device-side render verifies UX of fallback text | Run `tools/simulator/walker_audit_tap_render.sh tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml` ; assert exit 0 + describe-all output contains the templated fallback text without `\d+\s*CHF` |
| 4-week staging soak — `coach.citation_gate.fallback` rate ≤2% | D-21 sunset | Wall-clock + real-traffic; cannot run inline | After Plan 94-03 lands and flag flipped ON staging, pull Sentry breadcrumbs filtered `category:coach.citation_gate.*` from T+0 to T+28d ; if fallback rate ≤2%, propose flag flip-on prod + bypass code removal |

---

## Validation Sign-Off

- [ ] Every Plan task has `<verify><automated>` pointing at one row above OR is listed under Wave 0/1/2 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without an automated verify
- [ ] Wave 0/1/2 cover all MISSING test files
- [ ] No watch-mode flags in commands (`-x` exits on first failure, deterministic)
- [ ] Feedback latency: ≤30s quick run, ≤300s full suite — within budget
- [ ] `nyquist_compliant: true` will be set in frontmatter after Plan 94-01 Task 4 completes (mirror Phase 93.5-01 Task 4 pattern)

**Approval:** pending
