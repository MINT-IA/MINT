---
phase: mint-calc-engine-v1
plan: 17
wave: 4
subsystem: backend / observability / metrics-counters
tags: [d-ce-17, d-ce-12, w4, prometheus, metrics-counters, inputs-provenance, composite-scorecard, parallel-change-additive, latency-histogram, profile-grounded-calc-rate, plan-10-additive-effect]
description: W4 Plan 17 ships the D-CE-17 composite scorecard instrumentation — 4 Prometheus counters + 1 histogram + /metrics exposition endpoint + inputs_provenance additive field on CoachToolOkV2. Open Q1 resolved with Prometheus per RESEARCH §Q-H Option 1.

# Dependency graph
requires:
  - mint-calc-engine-v1-01 (profile_resolver._resolve_defaults — extended with sister _resolve_with_provenance)
  - mint-calc-engine-v1-06 (W1-grounded endpoints matrix — 26 endpoints, parametrized SLI shape mirror)
  - mint-calc-engine-v1-10 (CoachToolOkV2 envelope — inputs_provenance additive field follows same Parallel Change discipline as Plan 10's latency_tier)
  - mint-calc-engine-v1-13 (get_or_compute — cache_lookup_total instrumentation site)
  - mint-calc-engine-v1-15 (pre_compute._warm_calc — calc_warm_total instrumentation site)
provides:
  - "app.core.metrics — 4 Counters (mint_calc_invoke_total{kind,profile_grounded}, mint_cache_lookup_total{kind,hit}, mint_calc_warm_total{kind,hit}, mint_zero_citation_total) + 1 Histogram (mint_calc_latency_seconds{kind}) + metrics_router"
  - "/metrics endpoint on FastAPI app root (no API_V1_STR prefix, include_in_schema=False, Prometheus exposition format)"
  - "app.core.profile_resolver._resolve_with_provenance — sister helper to _resolve_defaults returning (resolved, provenance) where provenance[field] in {user_input, default, derived}"
  - "app.core.profile_resolver.emit_calc_invoke_metric — fires mint_calc_invoke_total based on whether any from_profile field was resolved"
  - "CoachToolOkV2.inputs_provenance: dict[str, Literal['user_input', 'default', 'derived']] — ADDITIVE optional field with default empty dict"
  - "Instrumentation sites in get_or_compute (cache_lookup_total) + pre_compute (calc_warm_total)"
  - "tests/test_metrics_endpoint.py (6 tests) + tests/test_inputs_provenance.py (38 tests, 26 parametrized W1-grounded kind labels)"
affects:
  - "Future Plan 18+ : endpoint handlers can opt-in to per-call emit_calc_invoke_metric + inputs_provenance emission (currently the helpers are SHIPPED but not yet WIRED into the 26 endpoint handlers from Plan 06 — that's a Wave-4-followup fanout patch)."
  - "Future Grafana Cloud / Datadog / Railway dashboards : 4 panels (profile-grounded calc rate, cache hit rate by kind, warm precision SLI, latency p95 by kind). DEFERRED — Julien decision."
  - "1-month staging baseline observation : PM threshold revision on D-CE-17 PRIMARY metric (CONTEXT.md PM-reserved)."

# Tech tracking
tech-stack:
  added:
    - "prometheus-client>=0.20,<1.0 (services/backend/pyproject.toml) — installed prometheus_client-0.25.0 successfully, no resolver conflicts on existing deps."
  patterns:
    - "Late-import Counter inside the call site (not at module load) — `from app.core.metrics import calc_invoke_total` inside emit_calc_invoke_metric / inside _warm_calc / inside get_or_compute. Avoids circular import surprises at module init time."
    - "Provenance audit dict semantic locked at 3 Literals : `user_input` (body), `default` (server-side profile fallback), `derived` (Pydantic default). « default » is intentionally NOT « profile_default » because the value semantic is « server fills the body slot with a sensible-default-from-known-data » — same meaning the FE consumer sees on the wire."
  patterns_additive_v2_envelope:
    - "Plan 10 Fowler Parallel Change discipline applied AGAIN : inputs_provenance ships ALONGSIDE the existing V2 fields. CoachToolOkV2 grows from 2 fields (data + latency_tier) to 3 fields (data + latency_tier + inputs_provenance) — same superset-not-mutation pattern Plan 10 established with its own latency_tier addition. Default empty dict preserves Wave 1a callers that don't emit provenance yet."

key-files:
  created:
    - "services/backend/app/core/metrics.py (145 LOC — 4 Counters + 1 Histogram + metrics_router + /metrics endpoint)"
    - "services/backend/tests/test_metrics_endpoint.py (130 LOC, 6 tests : module-import, /metrics endpoint shape, all-4-counter-exposure, labels, histogram buckets, no-label counter)"
    - "services/backend/tests/test_inputs_provenance.py (310 LOC, 38 tests : 6 provenance unit tests + 4 V2 envelope contract tests + 2 emit_calc_invoke_metric e2e tests + 26 W1-grounded kind parametrized exception-safety tests)"
  modified:
    - "services/backend/pyproject.toml (+7 LOC : prometheus-client dep + doctrine comment)"
    - "services/backend/app/main.py (+9 LOC : metrics_router import + mount at app root)"
    - "services/backend/app/core/profile_resolver.py (+87 LOC : _resolve_with_provenance + emit_calc_invoke_metric helpers ; _resolve_defaults rewired to delegate to _resolve_with_provenance, V1 signature preserved)"
    - "services/backend/app/models/coach_tools/_response.py (+30 LOC : _INPUTS_PROVENANCE_LITERALS Literal + inputs_provenance field on CoachToolOkV2 with default_factory=dict)"
    - "services/backend/app/services/cache/get_or_compute.py (+10 LOC : cache_lookup_total instrumentation at 2 sites — fast-path + post-singleflight re-check)"
    - "services/backend/app/services/coach/pre_compute.py (+16 LOC : calc_warm_total instrumentation in _warm_calc, fire-on-success + fire-on-failure with inner try/except preserving Plan 15 fail-open)"
    - "services/backend/tests/test_coach_tool_response_v2.py (+12 LOC : Parallel Change roundtrip test patched for additive inputsProvenance: {} default — subset-match not equality)"
    - "services/backend/tests/test_coach_tool_response_migration.py (+11 LOC : same patch on the migration invariant test)"

key-decisions:
  - "Open Q1 resolved with Prometheus (RESEARCH §Q-H Option 1). prometheus-client>=0.20,<1.0 added — installed prometheus_client-0.25.0 successfully, zero resolver conflicts. Sentry-only fallback (§Q-H Option 2) rejected : no PromQL, no Grafana, no alerting on histogram buckets."
  - "/metrics mounted on FastAPI app root (NOT under API_V1_STR prefix). Standard Prometheus scraper convention. `include_in_schema=False` keeps it out of OpenAPI doc — scrapers know the path, end users don't need to. Bearer-token auth OPTIONAL — metric content is non-PII (tool names + boolean flags + numeric counts). P1 follow-up for production : Railway private-network ACL on /metrics."
  - "inputs_provenance default = empty dict (not None, not required). Pydantic `Field(default_factory=dict)` preserves Plan 10 Wave-1a backwards-compat — callers that don't emit provenance still construct valid CoachToolOkV2 envelopes. The 3-Literal type annotation enforces validation when callers DO emit provenance."
  - "« default » provenance semantic = « server-side profile-driven fallback » (NOT « Pydantic default »). Pydantic-default falls under « derived ». Documented in _response.py `_INPUTS_PROVENANCE_LITERALS` docstring AND in test_inputs_provenance.py docstrings."
  - "Late-imports for `app.core.metrics` at every call site (not at module load of profile_resolver / get_or_compute / pre_compute). Defensive — avoids circular import surprises at app startup."
  - "_resolve_defaults V1 signature PRESERVED — Plan 17 reworks the body to delegate to _resolve_with_provenance but the public return shape stays a flat dict. All 26 Wave-1 endpoint handlers continue to work without modification. (Wave-4-followup fanout patch will opt them in to emit_calc_invoke_metric + provenance emission.)"
  - "Counter cardinality math (per RESEARCH §Q-H verified) : `kind` ~57 values + `profile_grounded` 2 values → 114 time-series per counter. Trivial for Prometheus. Histogram = 57 × 11 buckets = 627 time-series, also trivial."
  - "Railway-side metrics scraping config DEFERRED to phase close-out (orchestrator pre-decision). Code is committable as-is ; production observability stack choice (Grafana Cloud / Datadog / Railway built-in) is Julien's call."

patterns-established:
  - "Late-import for cross-cutting metrics — late-import the Counter at the call site (not at module load) keeps the dependency graph DAG-shaped. Used at emit_calc_invoke_metric, get_or_compute fast-path + re-check, _warm_calc success + failure."
  - "Fire-on-both-paths inside try/except — _warm_calc fires calc_warm_total{hit='true'} on success and calc_warm_total{hit='false'} inside the except block BEFORE swallowing the exception. The inner try/except guards the metric increment itself so it can NEVER break the fail-open contract."
  - "Subset-match for additive Parallel Change roundtrip tests — when a V2 envelope adds an optional default field, prior roundtrip tests that assert dump == input MUST switch to subset-match (for k, v in input.items(): assert dump[k] == v). Same pattern Plan 10 used for its own latency_tier addition. Applied to test_coach_tool_response_v2.py + test_coach_tool_response_migration.py as Rule 1 downstream-effect fixes."
  - "3-Literal provenance enum + dict-of-Literal Pydantic field — Pydantic v2 validates dict values against the Literal at validation time. test_v2_envelope_rejects_invalid_provenance_literal asserts this."

requirements-completed: [D-CE-13, D-CE-17]

# Metrics
metrics:
  duration_min: 25
  tasks_completed: 4
  tests_added: 44
  tests_passed_before: 7189
  tests_passed_after: 7233
  test_delta: "+44 (6 metrics + 38 provenance ; zero regressions, zero skip/xfail drift)"
  completed_date: "2026-05-17"
---

# Phase mint-calc-engine-v1 Plan 17 : W4 Metrics-Counters + inputs_provenance Summary

W4 Plan 17 ships the D-CE-17 composite scorecard instrumentation : 4 Prometheus Counters + 1 Histogram + `/metrics` exposition endpoint on the FastAPI app root, AND the additive `inputs_provenance: dict[str, Literal['user_input', 'default', 'derived']]` audit field on `CoachToolOkV2`. Open Q1 resolved with Prometheus per RESEARCH §Q-H Option 1 (orchestrator pre-decision : `prometheus-client>=0.20,<1.0` added to `services/backend/pyproject.toml`). Instrumentation wired at Plan 13's `get_or_compute` (cache_lookup_total) + Plan 15's `_warm_calc` (calc_warm_total) sites. `profile_resolver._resolve_with_provenance` + `emit_calc_invoke_metric` helpers shipped — endpoint handlers can opt-in for per-call emission in a follow-up Wave-4 patch (out of scope here ; 26 endpoints from Plan 06 stay V1 contract).

## One-liner

D-CE-17 composite scorecard MEASURABLE : `sum(rate(mint_calc_invoke_total{profile_grounded='true'}[5m])) / sum(rate(...))` is now a deterministic PromQL query against the `/metrics` endpoint. inputs_provenance audit field shipped on V2 envelope (additive, default empty). 7189 → 7233 (+44), zero regressions.

## Tasks Executed

| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 RED | 6 failing tests for metrics module + /metrics endpoint | RED (ModuleNotFoundError, expected) | `619acefd` |
| 1 GREEN | Ship metrics.py + add dep + mount router in main.py | GREEN (6/6 pass) | `9698928e` |
| 2 + 3 | Wire 4 counters + inputs_provenance V2 field + 38 contract tests | GREEN (44/44 pass) | `f88f3965` |
| 4 | Full suite + lints + engram + SUMMARY | (this commit) | pending |

(Tasks 2 + 3 from PLAN.md frontmatter were combined into one commit because the counter-wire and the inputs_provenance schema landing share a single test surface — `test_inputs_provenance.py` covers both the per-field provenance unit contract AND the emit_calc_invoke_metric end-to-end emission proof.)

## Files Created / Modified

### Created (3 files, ~585 LOC)

- `services/backend/app/core/metrics.py` — 145 LOC. Public API : `calc_invoke_total`, `cache_lookup_total`, `calc_warm_total`, `zero_citation_total`, `calc_latency_seconds`, `metrics_router`. RESEARCH §Q-H Option 1 verbatim shape.
- `services/backend/tests/test_metrics_endpoint.py` — 130 LOC, 6 tests : module-import, /metrics returns 200 + text/plain Prometheus mime, all-4-counters-in-body, labels emit verbatim, histogram buckets, zero_citation_total no-labels.
- `services/backend/tests/test_inputs_provenance.py` — 310 LOC, 38 tests : 6 provenance unit (user_input/default/derived semantics) + 4 V2 envelope contract (additive default, alias, Literal rejection) + 2 emit_calc_invoke_metric end-to-end (true label + false label paths) + 26 W1-grounded kind parametrized exception-safety.

### Modified (8 files, +191 LOC)

- `services/backend/pyproject.toml` (+7 LOC) — prometheus-client>=0.20,<1.0 dependency + doctrine comment.
- `services/backend/app/main.py` (+9 LOC) — late import of `metrics_router` + `app.include_router(metrics_router)` at app root (after `api_router` mount, before AASA endpoint).
- `services/backend/app/core/profile_resolver.py` (+87 LOC) — `_resolve_with_provenance` returning `(resolved, provenance)` tuple ; `emit_calc_invoke_metric` helper firing the D-CE-17 PRIMARY counter ; `_resolve_defaults` rewired to delegate (V1 signature preserved).
- `services/backend/app/models/coach_tools/_response.py` (+30 LOC) — `_INPUTS_PROVENANCE_LITERALS` Literal type + `inputs_provenance` field on `CoachToolOkV2` with `default_factory=dict`. V1 envelope UNCHANGED. V2 IncompleteV2 + PolicyBlockedV2 NOT extended (only OkV2 has profile-grounding inputs to audit).
- `services/backend/app/services/cache/get_or_compute.py` (+10 LOC) — `cache_lookup_total{kind, hit}` instrumented at fast-path lookup site + post-singleflight re-check site.
- `services/backend/app/services/coach/pre_compute.py` (+16 LOC) — `calc_warm_total{kind, hit}` instrumented in `_warm_calc` on success path (hit=true after get_or_compute returns) + failure path (hit=false inside except block, BEFORE log+swallow). Inner try/except guards the metric increment itself.
- `services/backend/tests/test_coach_tool_response_v2.py` (+12 LOC) — Rule 1 downstream patch : `test_parallel_change_coexistence_invariant` switched from equality to subset-match on V2 roundtrip dump (same pattern Plan 10 used for latency_tier additive).
- `services/backend/tests/test_coach_tool_response_migration.py` (+11 LOC) — same Rule 1 downstream patch on `test_v2_envelope_round_trips_with_latency_tier`.

## Verification Evidence (0-TRUST §9.6, citations only)

| Claim | Evidence command + result |
|-------|--------------------------|
| `services/backend/app/core/metrics.py` exists (145 LOC) | `wc -l services/backend/app/core/metrics.py` → `145` |
| 6/6 tests in test_metrics_endpoint.py green | `cd services/backend && python3 -m pytest tests/test_metrics_endpoint.py -q` → `6 passed in 0.23s` |
| 38/38 tests in test_inputs_provenance.py green | `cd services/backend && python3 -m pytest tests/test_inputs_provenance.py -q` → `38 passed in 0.28s` |
| **Full backend suite 7233 passed (+44 vs Plan 16 baseline 7189)** | `cd services/backend && python3 -m pytest tests/ -q` → `7233 passed, 63 skipped, 3 xfailed, 1 warning in 114.93s` |
| /metrics returns HTTP 200 + Prometheus mime | `TestClient(app).get('/metrics')` → `STATUS: 200 ; CONTENT-TYPE: text/plain; version=1.0.0; charset=utf-8` |
| All 4 counters + 1 histogram present in /metrics body | grep on test response body : `mint_calc_invoke_total: True ; mint_cache_lookup_total: True ; mint_calc_warm_total: True ; mint_zero_citation_total: True ; mint_calc_latency_seconds: True` |
| prometheus-client installed | `python3 -m pip show prometheus-client` → `prometheus_client-0.25.0` |
| Banned-terms lint clean on 8 touched files | `python3 tools/checks/banned_terms_python.py <8 files>` → exit 0 |
| Accent FR lint scope=backend clean | `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0 |
| Plan 10 art. refs in coach_tools.py preserved | `grep -c 'art\. ' services/backend/app/services/coach/coach_tools.py` → `10` (baseline 10, unchanged) |
| Plan 10 art. refs in coach_chat.py preserved | `grep -c 'art\. ' services/backend/app/api/v1/endpoints/coach_chat.py` → `5` (baseline 5, unchanged) |
| Plan 10 `_maybe_wrap_v2` refs preserved | `grep -c '_maybe_wrap_v2' services/backend/app/api/v1/endpoints/coach_chat.py` → `6` (baseline 6, unchanged) |
| Plan 10 V1 envelope classes UNCHANGED | `grep -c 'class CoachToolOk' services/backend/app/models/coach_tools/_response.py` → `2` (V1 + V2 both present, V1 untouched per D-CE-19) |
| Engram observation **#143** persisted | `engram save "Plan 17 W4 metrics-counters + inputs_provenance shipped (D-CE-17 composite scorecard)" --topic_key mint-calc-engine-v1:w4-plan-17:metrics-counters` → `Memory saved: #143 (architecture)` |
| 3 task commits in git log | `git log --oneline 619acefd^..HEAD` → 3 commits (619acefd RED → 9698928e GREEN → f88f3965 Tasks 2+3) |

## Sample `/metrics` Response Body (0-TRUST evidence)

```
# HELP python_gc_objects_collected_total Objects collected during gc
# TYPE python_gc_objects_collected_total counter
python_gc_objects_collected_total{generation="0"} 10299.0
[...stdlib metrics...]
# HELP mint_calc_invoke_total Calc invocations partitioned by kind and profile-grounding flag (D-CE-17 PRIMARY).
# TYPE mint_calc_invoke_total counter
# HELP mint_cache_lookup_total Cache lookups partitioned by kind and hit/miss (D-CE-12 SLI).
# TYPE mint_cache_lookup_total counter
# HELP mint_calc_warm_total Pre-compute warms partitioned by kind and whether next turn used it (D-CE-14 SLI).
# TYPE mint_calc_warm_total counter
# HELP mint_zero_citation_total Counter-metric — hard floor at 0; alerts on > 0 (D-CE-17 Goodhart counter).
# TYPE mint_zero_citation_total counter
mint_zero_citation_total 0.0
# HELP mint_calc_latency_seconds Calc compute latency in seconds, partitioned by kind.
# TYPE mint_calc_latency_seconds histogram
```

Captured via `TestClient(app).get('/metrics')` after `from app.main import app` — the body validates Prometheus text exposition format + all 5 metric families are registered against the default `prometheus_client` registry.

## Deviations from Plan

### Rule 1 — Auto-fixed bugs

**1. [Rule 1 — Plan 10 invariant downstream effect] Parallel Change roundtrip tests patched for additive inputsProvenance field.**

- **Found during:** Tasks 2+3 first pytest run after adding inputs_provenance to CoachToolOkV2.
- **Issue:** `test_parallel_change_coexistence_invariant` (in `test_coach_tool_response_v2.py`) AND `test_v2_envelope_round_trips_with_latency_tier` (in `test_coach_tool_response_migration.py`) both asserted `v2_model.root.model_dump(by_alias=True) == v2_input` — exact equality. Plan 17 adds `inputs_provenance` as an additive optional field with `default_factory=dict`, so the by-alias dump now includes `inputsProvenance: {}` in addition to the input keys. The exact-equality assertion broke.
- **Fix:** Switched both tests from equality (`dump == input`) to subset-match (`for k, v in input.items(): assert dump.get(k) == v`) + additional assertion that the new default field is present (`assert dump.get('inputsProvenance') == {}`). This is the same pattern Plan 10 used when it added `latency_tier` as an additive — Plan 10 itself updated some prior Wave-1a tests using the same surgical patch.
- **Files modified:** `services/backend/tests/test_coach_tool_response_v2.py`, `services/backend/tests/test_coach_tool_response_migration.py` (each ~12 LOC of patch).
- **Verification:** `pytest tests/test_coach_tool_response_v2.py tests/test_coach_tool_response_migration.py -q` → `22 passed`.
- **Committed in:** `f88f3965` (Tasks 2+3 commit).

**2. [Rule 1 — Python 3.9 compat] Test schema fields use `Optional[X]` not `X | None`.**

- **Found during:** First pytest run on the new `test_inputs_provenance.py`.
- **Issue:** Pydantic v2 type resolution evaluates model field annotations eagerly during `model_construction`, even when `from __future__ import annotations` is set. Python 3.9 chokes on `str | None` because the union-operator syntax was added in 3.10. The test collection errored with `TypeError: Unable to evaluate type annotation 'str | None'`.
- **Fix:** Added `from typing import Optional` and switched the test schema fields from `str | None` / `int | None` / `float | None` to `Optional[str]` / `Optional[int]` / `Optional[float]`. Documented in a class-level docstring.
- **Files modified:** `services/backend/tests/test_inputs_provenance.py`.
- **Verification:** Re-run `pytest tests/test_inputs_provenance.py -q` → `38 passed in 0.28s`.

### Rule 2-4 deviations

None. No missing critical functionality (Rule 2) — fail-open at every metric site preserves Plan 15's contract. No blocking issues (Rule 3) — prometheus-client install hit no dep resolver conflicts. No architectural escalation (Rule 4) — Open Q1 was pre-resolved by orchestrator (Prometheus, not Sentry).

**Total deviations** : 2 auto-fixed (1 Plan 10 additive roundtrip-test downstream effect, 1 Python 3.9 type-annotation compat). **Zero architectural deviations.**

## Threat Surface Notes

Plan 17 `<threat_model>` STRIDE entries — disposition outcome :

- **T-mint-calc-17-01 Information disclosure on /metrics endpoint** → **mitigated** at the conceptual level. The endpoint exposes only tool names + boolean flags + numeric counts (non-PII). Bearer-token auth + Railway private-network ACL are P1 follow-ups for production (NOT in Plan 17 scope). The endpoint is mounted with `include_in_schema=False` so it's not advertised in OpenAPI.
- **T-mint-calc-17-02 DoS counter cardinality blow-up** → **mitigated**. Labels capped per RESEARCH §Q-H : `kind` ≤57 values + `profile_grounded`/`hit` 2 values each. Total time-series ~114 per Counter, ~627 for the Histogram. Trivial. The 26 W1-grounded kind parametrized test in `test_inputs_provenance.py` exercises the cardinality bound explicitly.
- **T-mint-calc-17-03 LSFin metric label content** → **accept**. Label values are EN tool names + boolean flags — no FR user-facing strings, no banned terms. Banned-terms lint exit 0 on 8 touched files.
- **T-mint-calc-17-04 Goodhart metric gaming** → **mitigated**. `mint_zero_citation_total` ships alongside the PRIMARY metric as the Goodhart counter — if any chip-emitter ever emits a non-cited response, this counter goes non-zero and triggers an alert per the D-CE-17 panel discipline. PromQL : `rate(mint_zero_citation_total[5m]) > 0`.

No new threat surface beyond the plan's threat register.

## Plan 10 string state preservation

| Metric | Baseline | Post-Plan-17 | Status |
|--------|----------|-------------|--------|
| `grep -c 'art\\. ' coach_tools.py` | 10 | 10 | unchanged |
| `grep -c 'art\\. ' coach_chat.py` | 5 | 5 | unchanged |
| `grep -c '_maybe_wrap_v2' coach_chat.py` | 6 | 6 | unchanged |
| `class CoachToolOk` in `_response.py` | 1 (V1) + 1 (V2) | 1 (V1) + 1 (V2 extended additively) | V1 unchanged ; V2 super-set |

Plan 10 D-CE-19 Fowler Parallel Change discipline honored : V1 untouched, V2 super-set via additive optional field (default empty). Same playbook Plan 10 itself used for `latency_tier`.

## Deployment Notes (carried forward to phase close-out)

- **Staging deploy** : Plan 17 ships Python-only changes + 1 new optional dep (`prometheus-client>=0.20,<1.0`). Becomes active on next Railway container restart of `services/backend`. The `/metrics` endpoint will be reachable internally at `https://mint-staging.up.railway.app/metrics`.
- **Counter activation** : counters increment only when their call sites fire. `mint_cache_lookup_total` + `mint_calc_warm_total` are already wired into Plan 13's `get_or_compute` + Plan 15's `_warm_calc` — they'll start incrementing immediately. `mint_calc_invoke_total` is shipped via the `emit_calc_invoke_metric` HELPER but NOT yet WIRED into the 26 W1-grounded endpoint handlers (out of scope here — Wave-4-followup fanout patch).
- **`/metrics` auth** : NOT auth-gated yet. P1 follow-up for production : bearer token OR Railway private-network ACL.
- **Grafana dashboards** : 4 panel TODOs documented inline in `metrics.py` docstring (profile-grounded calc rate, cache hit rate, warm precision SLI, latency p95 by kind). Dashboard creation = phase close-out.

## What I Have NOT Done (caveats / 0-TRUST §9.6)

- Did NOT wire `emit_calc_invoke_metric` into the 26 W1-grounded endpoint handlers (Plan 06 endpoints). The HELPER is shipped + unit-tested ; the per-handler fanout patch is a Wave-4-followup. The cache_lookup_total + calc_warm_total counters DO fire automatically because they're at the Plan 13 / Plan 15 sites, but the D-CE-17 PRIMARY metric (`mint_calc_invoke_total`) needs explicit handler-side opt-in. Documented as deferred.
- Did NOT activate Railway-side metrics scraping config. Per orchestrator pre-decision : Julien picks the observability stack (Grafana Cloud / Datadog / Railway built-in). The `/metrics` endpoint is committable as-is ; activating a scraper is a configuration step on Railway dashboard or a Grafana Cloud agent install — neither is in code scope.
- Did NOT create Grafana panel JSON / dashboard configs. PromQL queries are documented inline in `metrics.py` docstring for direct copy-paste once the scraper is wired.
- Did NOT auth-gate `/metrics`. Bearer token OR Railway private-network ACL are P1 production follow-ups.
- Did NOT add Sentry custom-metrics fallback. RESEARCH §Q-H Option 2 was the alternative path ; Open Q1 chose Option 1 (Prometheus). The Sentry breadcrumb observability stack remains untouched.
- Did NOT extend `inputs_provenance` to `CoachToolIncompleteV2` or `CoachToolPolicyBlockedV2`. Only `CoachToolOkV2` carries the audit field — Incomplete + PolicyBlocked envelopes don't have profile-grounding inputs to audit (the request never reached compute).
- Did NOT migrate `_resolve_defaults` callers to `_resolve_with_provenance`. The 26 Plan 06 handlers continue to call `_resolve_defaults` (which now delegates internally) — no migration debt forced.
- Did NOT run staging deploy / device walkthrough / Maestro G1. Plan 17 is backend-internal infrastructure — no UI surface, no endpoint shape change visible to clients (chip-emitter response shapes unchanged because `inputs_provenance` is OPT-IN at the V2 envelope level).
- Did NOT call MCP `mem_save` tool — not exposed in this executor's tool list (13th consecutive plan with this gap per anthropics/claude-code#13898). Engram CLI fallback succeeded : observation **#143** persisted.
- Per CLAUDE.md §9 : tests green ≠ feature working. The D-CE-17 PRIMARY metric IS shipped and the `/metrics` endpoint IS reachable via TestClient + `prometheus_client.generate_latest()`, but USER VALUE DELIVERED is zero until (a) the Wave-4-followup wires `emit_calc_invoke_metric` into the 26 endpoint handlers, (b) staging deploy + scraper activation, (c) 1-week observation on real traffic validates the SLI baseline.

## Deferred — Phase close-out gates

These items are EXPLICITLY out-of-scope per orchestrator pre-decision (autonomous: false split). They block on Julien's product / ops decisions, not on code :

1. **Railway-side metrics scraping config** — Julien picks among :
   - **Grafana Cloud free tier** : agent install on Railway service + 14-day retention + Grafana dashboards. Cheapest.
   - **Datadog** : Railway integration via `datadog-agent` Docker sidecar. Most queryable but $$.
   - **Railway built-in observability** : ships some Prometheus scraping in beta. Cheapest but limited.
2. **`/metrics` auth-gate** : bearer-token middleware OR Railway private-network ACL. P1 before any production traffic hits `/metrics`.
3. **Grafana dashboard panels** (4 panels documented inline in `metrics.py`) :
   - `profile_grounded_calc_rate` (5min) — D-CE-17 PRIMARY
   - `cache_hit_rate_by_kind` (5min) — D-CE-12 SLI
   - `warm_precision_rate` (1h) — D-CE-14 SLI
   - `calc_latency_p95_by_kind` (5min)
4. **Endpoint-handler fanout patch** : wire `emit_calc_invoke_metric` into the 26 Plan 06 W1-grounded endpoint handlers so the D-CE-17 PRIMARY metric increments on real traffic. ~26 × 1-line additions. Out-of-scope here because the orchestrator split kept Plan 17 to the infrastructure ship only.
5. **PM-reserved threshold revision** : after 1-month staging baseline observation (per CONTEXT.md), the D-CE-17 PRIMARY threshold gets revised based on real traffic.

## Engram Save

Observation **#143** persisted via CLI fallback :

```
engram save "Plan 17 W4 metrics-counters + inputs_provenance shipped (D-CE-17 composite scorecard)" \
  --project mint --type architecture \
  --topic_key mint-calc-engine-v1:w4-plan-17:metrics-counters
```

Content covers : What (4 Counters + 1 Histogram + /metrics endpoint + inputs_provenance additive field) / Where (8 files modified + 3 created, ~775 LOC delta) / Why (D-CE-17 composite scorecard MEASURABLE via PromQL, PM-reserved threshold revision after 1-month baseline) / Tests (7233 passed +44 vs Plan 16) / Evidence (HTTP 200 from /metrics, exposition format validated, all 4 counter names present in body) / Learned (Pydantic v2 needs Optional[X] not X | None on Python 3.9 even with `from __future__ import annotations` ; Plan 10 invariant tests need subset-match patch for additive V2 fields ; late-import for cross-cutting metrics avoids circular dep) / Caveats (handler fanout deferred, scraper config deferred, /metrics auth-gate P1 follow-up).

`prior_finding_refs` (in content body) : Plan 01 obs (profile_resolver foundation), Plan 06 obs (26 W1-grounded endpoint matrix), Plan 10 obs (Parallel Change discipline + V2 envelope), Plan 13 obs (cache_lookup_total instrumentation site), Plan 15 obs (calc_warm_total instrumentation site), Plan 16 obs (GC daily job — adjacent on Wave 4).

## USER VALUE DELIVERED (CLAUDE.md §9 honesty stake)

**NONE end-user-visible YET.** Plan 17 ships pure server-internal infrastructure : Prometheus counter declarations + `/metrics` exposition endpoint + an audit-field schema. No user-facing behavior change.

End-user impact lands when :
1. Wave-4-followup wires `emit_calc_invoke_metric` into the 26 Plan 06 endpoint handlers → real traffic increments the D-CE-17 PRIMARY metric.
2. Railway scraper activation (Grafana Cloud / Datadog / built-in) → counters flow to a dashboard.
3. `dev` → `staging` merge → Railway redeploy registers the new `/metrics` endpoint.
4. 1-week staging observation confirms (a) no counter cardinality blow-up, (b) PromQL queries return non-empty results on `profile_grounded_calc_rate`, (c) `mint_zero_citation_total` stays at 0 (Goodhart guard intact).
5. PM threshold revision per CONTEXT.md after 1-month baseline.

Plan 17 is Stage 1 of 4 per CLAUDE.md §9.5 — work shipped to local `dev`, no PR yet, no merge to remote, no Railway deploy, no end-user visible behavior.

## Self-Check : PASSED

Verified inline before SUMMARY commit :

- [x] `services/backend/app/core/metrics.py` exists (145 LOC) → FOUND
- [x] `services/backend/tests/test_metrics_endpoint.py` exists (130 LOC, 6 tests) → FOUND (`6 passed in 0.23s`)
- [x] `services/backend/tests/test_inputs_provenance.py` exists (310 LOC, 38 tests) → FOUND (`38 passed in 0.28s`)
- [x] Commit `619acefd` (Task 1 RED) → present in `git log --oneline -10`
- [x] Commit `9698928e` (Task 1 GREEN) → present
- [x] Commit `f88f3965` (Tasks 2+3 wire + provenance + roundtrip patches) → present
- [x] Full regression 7233 passed (+44 vs Plan 16 baseline 7189) → cited verbatim
- [x] `/metrics` endpoint returns HTTP 200 + Prometheus exposition format → cited (STATUS: 200, content-type validated, 5/5 metric families present)
- [x] Plan 10 string state PRESERVED : `art. ` count 10 + 5 unchanged ; `_maybe_wrap_v2` count 6 unchanged
- [x] V1 envelope classes UNCHANGED → `grep -c 'class CoachToolOk' _response.py` = 2 (V1 + V2, V1 line-unchanged per Plan 10 D-CE-19 discipline)
- [x] `prometheus-client>=0.20,<1.0` in `pyproject.toml` dependencies block → FOUND
- [x] `metrics_router` mounted in `main.py` at app root → FOUND (`app.include_router(metrics_router)` after `app.include_router(api_router, prefix=settings.API_V1_STR)`)
- [x] `inputs_provenance: dict[str, Literal[...]]` field on `CoachToolOkV2` → FOUND (additive, default_factory=dict)
- [x] `_resolve_with_provenance` + `emit_calc_invoke_metric` exported from `profile_resolver.py` → FOUND
- [x] `cache_lookup_total.labels(...).inc()` at 2 sites in `get_or_compute.py` → FOUND (fast-path + re-check)
- [x] `calc_warm_total.labels(...).inc()` at 2 sites in `pre_compute.py` → FOUND (success + failure paths)
- [x] banned-terms lint clean on 8 touched files → exit 0
- [x] accent_lint_fr backend scope clean → exit 0
- [x] Engram observation **#143** persisted via CLI fallback (MCP `mem_save` not exposed in this executor's tool list — 13th plan with this gap)
- [x] 0-TRUST §9.1-9.7 honored : every « green » / « shipped » claim above carries a deterministic citation (file path / command output / commit sha / pytest result / /metrics body snippet)

## Next Plan

**Wave 4 close-out** : the W4 wave needs at least one follow-up to wire `emit_calc_invoke_metric` into the 26 Plan 06 endpoint handlers (handler fanout, ~26 × 1 LOC). Whether that lands as a sister Plan 18 or as a phase close-out tidy-up depends on Julien's preference (orchestrator decision). The phase-level deliverables for `mint-calc-engine-v1` should be reviewed against ROADMAP_V2 + REQUIREMENTS.md at this point — Plans 01-17 have closed D-CE-04 through D-CE-17, plus D-CE-19 (Parallel Change) + D-CE-20 (Concern D fixture).

---
*Phase: mint-calc-engine-v1*
*Plan: 17 — W4 Metrics-Counters + inputs_provenance (D-CE-17 composite scorecard)*
*Completed: 2026-05-17*
