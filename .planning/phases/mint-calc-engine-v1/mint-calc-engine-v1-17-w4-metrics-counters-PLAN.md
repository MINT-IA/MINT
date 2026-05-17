---
phase: mint-calc-engine-v1
plan: 17
wave: 4
title: W4 — Prometheus counters + inputs_provenance schema (D-CE-17 composite scorecard)
type: execute
depends_on: [01, 06, 13, 15]
files_modified:
  - services/backend/pyproject.toml
  - services/backend/app/core/metrics.py
  - services/backend/app/main.py
  - services/backend/app/models/coach_tools/_response.py
  - services/backend/app/services/coach/coach_tools.py
  - services/backend/app/core/profile_resolver.py
  - services/backend/tests/test_metrics_endpoint.py
  - services/backend/tests/test_inputs_provenance.py
autonomous: false
requirements: [D-CE-13, D-CE-17]
estimated_duration: 5
must_haves:
  truths:
    - "Open Q1 resolved: Prometheus (preferred) — `prometheus-client>=0.20,<1.0` added"
    - "/metrics endpoint exposes `mint_calc_invoke_total{kind, profile_grounded}`, `mint_cache_lookup_total{kind, hit}`, `mint_calc_warm_total{kind, hit}`, `mint_zero_citation_total`"
    - "`inputs_provenance: dict[field, Literal['user_input', 'default', 'derived']]` field added to V2 envelope (additive)"
    - "Every W1-grounded endpoint emits `inputs_provenance` per-field — auditable per D-CE-17"
    - "profile_grounded_calc_rate measurable via PromQL query"
  artifacts:
    - path: services/backend/app/core/metrics.py
      provides: "Counter + Histogram declarations + /metrics router"
      min_lines: 50
    - path: services/backend/tests/test_inputs_provenance.py
      provides: "Asserts every W1-grounded endpoint emits truthful provenance per field"
      min_lines: 80
  key_links:
    - from: services/backend/app/core/profile_resolver.py
      to: services/backend/app/core/metrics.py
      via: "calc_invoke_total.labels(kind, profile_grounded).inc()"
      pattern: "calc_invoke_total\\.labels"
---

<objective>
Ship D-CE-17 composite scorecard instrumentation. Resolve Open Q1 with Prometheus (preferred path per RESEARCH §Q-H Option 1). Add `inputs_provenance` field to envelope V2 for per-call audit trail of « real profile / default / derived » signal.

Purpose: D-CE-17. Make `profile_grounded_calc_rate` MEASURABLE. PM-reserved threshold revision after first-month baseline (per CONTEXT.md).

Output: Prometheus counters + /metrics endpoint + `inputs_provenance` field + 2 test files. **Requires Julien GO on Prometheus vs Sentry choice (Open Q1).**
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VALIDATION.md
@services/backend/pyproject.toml
@services/backend/app/observability/coach_breadcrumbs.py
@services/backend/app/core/profile_resolver.py
</context>

<interfaces>
<!-- RESEARCH §Q-H Option 1 — Prometheus counters -->

```python
# services/backend/app/core/metrics.py
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

calc_invoke_total = Counter(
    "mint_calc_invoke_total",
    "Calc invocations partitioned by kind and profile-grounding flag",
    labelnames=("kind", "profile_grounded"),
)
cache_lookup_total = Counter(
    "mint_cache_lookup_total",
    "Cache lookups partitioned by kind and hit/miss",
    labelnames=("kind", "hit"),
)
calc_warm_total = Counter(
    "mint_calc_warm_total",
    "Pre-compute warms partitioned by kind and whether next turn used it",
    labelnames=("kind", "hit"),
)
zero_citation_total = Counter(
    "mint_zero_citation_total",
    "Hard floor: 0; alerts on > 0",
)
calc_latency_seconds = Histogram(
    "mint_calc_latency_seconds",
    "Calc compute latency in seconds, partitioned by kind",
    labelnames=("kind",),
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0),
)
```

inputs_provenance schema (D-CE-17):
```python
# Extended in CoachToolOkV2.data["inputs_provenance"]:
inputs_provenance: dict[str, Literal["user_input", "default", "derived"]]
```
</interfaces>

<tasks>

<task id="W4-01-00" type="checkpoint:decision" gate="blocking">
  <decision>Open Q1: Prometheus vs Sentry for metrics instrumentation</decision>
  <context>
    Per RESEARCH §Q-H:
    - **Option 1 (Prometheus)**: new dep `prometheus-client>=0.20,<1.0`, new /metrics endpoint, PromQL queries possible, Grafana dashboards. ~50 LOC.
    - **Option 2 (Sentry)**: reuse existing `coach_breadcrumbs.py`, no new dep, no Grafana — just Sentry « Custom Metrics » feature. Cheaper but less queryable.

    VALIDATION.md default if unresolved: Sentry (no new dep).
  </context>
  <options>
    <option id="prometheus">
      <name>Prometheus (preferred per RESEARCH §Q-H)</name>
      <pros>PromQL queries + Grafana dashboards + standard observability stack</pros>
      <cons>+1 dep, +1 endpoint, requires Prometheus scraper config on Railway</cons>
    </option>
    <option id="sentry">
      <name>Sentry-only (VALIDATION.md fallback)</name>
      <pros>No new dep, reuse existing observability, simpler</pros>
      <cons>No PromQL, no Grafana, harder to alert on histogram buckets</cons>
    </option>
  </options>
  <resume-signal>Reply with: "prometheus" or "sentry"</resume-signal>
</task>

<task id="W4-01-01" type="auto" tdd="true">
  <name>Task 1: metrics.py module + /metrics endpoint (or Sentry path)</name>
  <files>services/backend/pyproject.toml, services/backend/app/core/metrics.py, services/backend/app/main.py, services/backend/tests/test_metrics_endpoint.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-H
    - services/backend/app/observability/coach_breadcrumbs.py (Sentry pattern precedent)
    - services/backend/pyproject.toml (current deps)
    - services/backend/app/main.py (router registration pattern)
  </read_first>
  <behavior>
    - Test 1: `from app.core.metrics import calc_invoke_total, cache_lookup_total, ...` succeeds.
    - Test 2: `GET /metrics` returns 200 + `Content-Type: text/plain; version=0.0.4; charset=utf-8` (Prometheus mime).
    - Test 3: `calc_invoke_total.labels(kind="lpp_rachat", profile_grounded="true").inc()` then `GET /metrics` body contains `mint_calc_invoke_total{kind="lpp_rachat",profile_grounded="true"} 1.0`.
    - Test 4: `zero_citation_total` is exposed.
    - Test 5: Histogram buckets present.
  </behavior>
  <action>
    **If "prometheus" path:**

    1. Add `prometheus-client>=0.20,<1.0` to `services/backend/pyproject.toml` `[project.dependencies]`.
    2. Create `app/core/metrics.py` per RESEARCH §Q-H Option 1 (verbatim).
    3. Register `metrics_router` in `app/main.py`:
       ```python
       from app.core.metrics import metrics_router
       app.include_router(metrics_router)
       ```
    4. 5 tests in `test_metrics_endpoint.py`.

    **If "sentry" path:**

    1. Skip dep addition.
    2. Create `app/core/metrics.py` with Sentry-tagged wrapper functions:
       ```python
       def increment_calc_invoke(kind: str, profile_grounded: bool) -> None:
           emit_coach_tool_breadcrumb(
               tool_name=kind, ..., extra_tags={"calc_invoke": "true", "profile_grounded": str(profile_grounded).lower()}
           )
       ```
    3. Tests assert Sentry breadcrumb emission via mock.

    Document chosen path explicitly in SUMMARY.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_metrics_endpoint.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - Module importable
    - 5 tests green
    - If prometheus: `curl localhost:8000/metrics` (in test) returns Prometheus exposition format
    - If sentry: Sentry breadcrumb mock asserts on 4 distinct tag patterns
  </acceptance_criteria>
  <done>Metrics live</done>
</task>

<task id="W4-01-02" type="auto" tdd="true">
  <name>Task 2: Wire counters into W1 endpoints (profile_grounded label)</name>
  <files>services/backend/app/core/profile_resolver.py, services/backend/app/services/coach/coach_tools.py</files>
  <read_first>
    - services/backend/app/core/profile_resolver.py (helpers from Plan 01)
    - services/backend/app/core/metrics.py (just created)
    - services/backend/app/services/coach/coach_tools.py (5 chip-emitters)
  </read_first>
  <behavior>
    - Test 1: Calling a W1-grounded endpoint increments `mint_calc_invoke_total{kind="<endpoint_name>", profile_grounded="true"}` when profile fills the missing fields.
    - Test 2: Calling same endpoint with body fully provided (body wins, profile NOT consulted) increments `profile_grounded="false"` label.
    - Test 3: Chip-emitter `get_budget_status` increments with truthful label.
  </behavior>
  <action>
    Add metric emission in `_resolve_defaults` helper or as a sister `_emit_metrics` call right after the helper returns:

    ```python
    # profile_resolver.py — surgical addition (or new helper)
    def emit_calc_invoke_metric(kind: str, resolved: dict, schema_class) -> None:
        """D-CE-17 metric: profile_grounded is true if ANY from_profile field was filled from profile."""
        any_grounded = False
        for name, field_info in schema_class.model_fields.items():
            extra = field_info.json_schema_extra or {}
            if isinstance(extra, dict) and "from_profile" in extra:
                # If resolved value differs from body default AND came from profile, counted as grounded
                if resolved.get(name) is not None:
                    any_grounded = True
                    break
        from app.core.metrics import calc_invoke_total  # late import to avoid circular
        calc_invoke_total.labels(kind=kind, profile_grounded=str(any_grounded).lower()).inc()
    ```

    Endpoint callers add 1 line after `_resolve_defaults`:
    ```python
    emit_calc_invoke_metric(kind="allocation_annuelle", resolved=resolved, schema_class=AllocationAnnuelleRequest)
    ```

    For the 5 chip-emitters in `coach_tools.py`, add similar emission.

    3 integration tests in test_metrics_endpoint.py (or sister test file).
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_metrics_endpoint.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - 3 wire-up tests green
    - `grep -c "calc_invoke_total\|emit_calc_invoke_metric" services/backend/app/api/v1/endpoints/ services/backend/app/services/coach/ -r 2>&1 | grep -v ":0$"` returns ≥5 lines (5 chip-emitters + ≥some endpoints)
  </acceptance_criteria>
  <done>Counter wired</done>
</task>

<task id="W4-01-03" type="auto" tdd="true">
  <name>Task 3: inputs_provenance field on CoachToolOkV2.data</name>
  <files>services/backend/app/services/coach/coach_tools.py, services/backend/app/core/profile_resolver.py, services/backend/tests/test_inputs_provenance.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VALIDATION.md W4-01-03
    - services/backend/app/models/coach_tools/_response.py (V2 envelope)
    - Plan 10 chip-emitter migrations
  </read_first>
  <behavior>
    - Test 1: `get_budget_status` returns `CoachToolOkV2(data={..., "inputs_provenance": {"canton": "user_input", "age": "user_input", ...}}, latency_tier="L1")`.
    - Test 2: When profile fills a missing body field, provenance for that field = `"default"` (filled-from-profile) — semantic choice: « default » in this context = « server-side fallback ». Document in SUMMARY.
    - Test 3: All `from_profile`-marked fields appear in `inputs_provenance` keys.
    - Test 4: Provenance values are exactly one of `"user_input"`, `"default"`, `"derived"` (3-literal enum).
  </behavior>
  <action>
    Build `inputs_provenance` dict alongside `_resolve_defaults` return:

    ```python
    # profile_resolver.py — extend helper
    def _resolve_with_provenance(
        profile_data: dict, body: BaseModel, schema_class,
    ) -> tuple[dict, dict[str, str]]:
        """Variant of _resolve_defaults returning provenance dict too."""
        if profile_data is None:
            profile_data = {}
        resolved = {}
        provenance = {}
        body_set = body.model_fields_set
        for name, field_info in schema_class.model_fields.items():
            extra = field_info.json_schema_extra or {}
            profile_key = extra.get("from_profile") if isinstance(extra, dict) else None
            if name in body_set:
                resolved[name] = getattr(body, name)
                provenance[name] = "user_input"
            elif profile_key and profile_data.get(profile_key) is not None:
                resolved[name] = profile_data[profile_key]
                provenance[name] = "default"   # server-side fallback from profile
            else:
                resolved[name] = getattr(body, name)
                provenance[name] = "derived"   # Pydantic default
        return resolved, provenance
    ```

    Pass `inputs_provenance` through to `CoachToolOkV2.data["inputs_provenance"]`.

    4 tests in `test_inputs_provenance.py`.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_inputs_provenance.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - 4 tests green
    - `grep -c "inputs_provenance" services/backend/app/services/coach/coach_tools.py` returns ≥5 (5 chip-emitters)
    - `grep -c "_resolve_with_provenance\|inputs_provenance" services/backend/app/core/profile_resolver.py` returns ≥1
  </acceptance_criteria>
  <done>Provenance field shipping</done>
</task>

<task id="W4-01-99" type="auto" tdd="false">
  <name>Task 4: Full suite + engram + Grafana TODO</name>
  <files>(verification + engram)</files>
  <action>
    Engram save:
    - `topic_key: calc_engine:w4:metrics_counters_inputs_provenance`
    - `type: discovery`
    - `prior_finding_refs: [Plan 01 obs, Plan 06 obs (grounding scope), Plan 13 obs (cache), Plan 15 obs (warm), #103 panel synthesis D-CE-17]`
    - Content: « Q1 resolved: <prometheus|sentry>. mint_calc_invoke_total + cache_lookup_total + calc_warm_total + zero_citation_total + calc_latency_seconds counters live. inputs_provenance dict on V2 envelope. profile_grounded_calc_rate measurable per turn. PM threshold revision deferred to 1-month baseline. »

    Grafana TODO (post-W4): wire 4 panels: profile-grounded rate, cache hit rate, warm precision/recall, latency p95 by kind.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - Full suite green
    - Engram saved
    - Q1 resolution noted
  </acceptance_criteria>
  <done>W4-01 closed</done>
</task>

</tasks>

<threat_model>
## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-mint-calc-17-01 | Information disclosure | /metrics endpoint exposure | mitigate | Add bearer-token auth on /metrics (Railway env var). If "prometheus" chosen, document Railway-scraper config. |
| T-mint-calc-17-02 | DoS | counter cardinality blow-up | mitigate | Labels capped: `kind` ≤57 values + `profile_grounded` 2 values. Trivial cardinality. RESEARCH §Q-H verified. |
| T-mint-calc-17-03 | LSFin | metric label content | accept | Labels are tool names + boolean flags. No PII or financial claim. |
| T-mint-calc-17-04 | Goodhart | metric gaming | mitigate | Counter-metrics (zero_citation_total, engagement_non_collapse_tripwire) ship alongside primary metric per D-CE-17. |
</threat_model>

<success_criteria>
- 4 counters + 1 histogram declared
- /metrics endpoint live (or Sentry equivalent)
- inputs_provenance field on V2 envelope
- ≥10 tests green
- Engram + Q1 resolution
</success_criteria>

<risks>
- **Bearer auth on /metrics.** If "prometheus" chosen, /metrics MUST be auth-gated. Add `Depends(require_metrics_bearer)` check before exposing. Documented in SUMMARY as P1.
- **Grafana wiring is post-W4.** Plan 17 only ships the COUNTERS. Dashboard panels = follow-up TODO.
- **« default » provenance label ambiguity.** « default » in inputs_provenance means « server-side fallback from profile » NOT « Pydantic default ». Documented in SUMMARY (semantic choice).
</risks>

<output>
After completion, create `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-17-w4-metrics-counters-SUMMARY.md` including Q1 resolution + Grafana TODO.
</output>
