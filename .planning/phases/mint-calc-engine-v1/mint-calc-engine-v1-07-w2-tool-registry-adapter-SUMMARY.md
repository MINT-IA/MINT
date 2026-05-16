---
phase: mint-calc-engine-v1
plan: 07
wave: 2
subsystem: api
tags: [tool-registry-adapter, vendor-agnostic, anthropic-defer-loading, tool-search-tool, skill-bundle-only, manual-subset, factory, d-ce-01, d-ce-02, runtime-checkable-protocol]

# Dependency graph
requires:
  - phase: mint-calc-engine-v1
    plan: 01
    provides: "shared profile-resolver helpers (no direct reuse here ; Plan 10 W2-04 will pair the adapter with _resolve_defaults at the coach_chat.py dispatch site)"
  - phase: mint-calc-engine-v1
    plan: 05
    provides: "app.calculators.REGISTRY (63 CalculatorMetadata entries) + REVERSE_DEP_MAP — direct consumer for the 63 long-tail tool definitions in AnthropicDeferLoadingAdapter + SkillBundleOnlyAdapter + ManualSubsetAdapter"
provides:
  - "services/backend/app/services/coach/tool_registry/adapter.py — runtime_checkable Protocol with register_tools + latency_tier methods. LatencyTier = Literal['L1','L2','L3'] aligns with Plan 04 LucidityLevel. ToolDefinition TypedDict accepts the full Anthropic-shape kwargset (name/description/input_schema + optional defer_loading + optional type for tool_search_tool_bm25 declaration)."
  - "services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py — DEFAULT adapter. 5 chip-emitters always-on (sourced from coach_tools.COACH_TOOLS at construction time via _load_chip_emitter_descriptions). 63 long-tail calculators from REGISTRY with defer_loading=True. 1 tool_search_tool_bm25_20251119 declaration. beta_header property pinned at 'tool-search-tool-2025-10-19'. v1 templated descriptions for long-tail (Plan 09 LSFin rewrite pending)."
  - "services/backend/app/services/coach/tool_registry/skill_bundle_only_adapter.py — FALLBACK adapter. All calculators always-on (5 chip + 63 long-tail). NO defer_loading key on any tool entry. NO tool_search_tool_bm25 declaration. Bedrock-compatible (RESEARCH §Q-A failure mode 2). Accepts context-bloat tradeoff explicitly per CONTEXT D-CE-01."
  - "services/backend/app/services/coach/tool_registry/manual_subset_adapter.py — BACKUP adapter. Per-intent filter via REGISTRY.life_events_served tags (Plan 05 metadata). 6 intents mapped to life-event sets : retirement→{retirement,buyback} / taxes→{taxes,succession} / housing→{housing} / debt→{debt} / family→{family,marriage,divorce} / career→{career,independent,cross_border}. Empty intents → only 5 chip-emitters."
  - "services/backend/app/services/coach/tool_registry/factory.py — TOOL_REGISTRY_ADAPTER env-flag selector. Default = anthropic_defer_loading (D-CE-01 primary). Invalid value falls back to default + WARNING log breadcrumb (Sentry-compatible). Adapter map : anthropic_defer_loading / skill_bundle_only / manual_subset."
  - "21 contract tests across 5 test files — test_tool_registry_adapter.py (3) + test_anthropic_defer_loading_adapter.py (6) + test_skill_bundle_only_adapter.py (4) + test_manual_subset_adapter.py (4) + test_tool_registry_factory.py (4). 100% green in isolation AND in full backend suite."
  - "Handler-attach pattern for logger-based tests (mirroring test_profile_resolver.py:210-228 convention) — bypasses caplog flake when other suite tests mutate module logger state. Reusable for future tool_registry tests that assert on factory._logger output."
affects: [mint-calc-engine-v1-08-w2-bundles, mint-calc-engine-v1-09-w2-tool-description-rewrite, mint-calc-engine-v1-10-w2-coach-tool-response-v2, mint-calc-engine-v1-11-w2-deprecation-shims]

# Tech tracking
tech-stack:
  added:
    - "typing.Protocol with @runtime_checkable decorator — first use in the coach package. Sister to coach_tools/_response.py RootModel discriminated union but on the abstract-interface axis rather than the data-envelope axis."
    - "typing.TypedDict(total=False) with optional Anthropic-specific keys (defer_loading + type) — accommodates 2 disjoint tool shapes (calculator vs tool_search_tool_bm25 declaration) in one type without union plumbing."
  patterns:
    - "Vendor-agnostic adapter Protocol with 3 concrete implementations + env-flag factory — replicable for future provider abstractions (LLM SDK swap, vector DB swap, OpenAI-vs-Anthropic embeddings, etc.). 50-LOC Protocol + 50-LOC factory + N concrete adapters."
    - "Lazy chip-emitter description sourcing — _load_chip_emitter_descriptions reads COACH_TOOLS at adapter construction time so the source of truth stays in coach_tools.py. SkillBundleOnlyAdapter + ManualSubsetAdapter import _load_chip_emitter_descriptions + _ALWAYS_ON_TOOLS from AnthropicDeferLoadingAdapter, single source for the 5 chip-emitter list across all 3 adapters."
    - "Direct handler-attach for logger-based tests — bypasses pytest caplog when other suite tests mutate module logger propagate/disabled/setLevel. Pattern : subclass logging.Handler with a records list, addHandler to the module logger in try/finally, removeHandler on teardown. Replicates test_profile_resolver.py:210-228 convention."

key-files:
  created:
    - "services/backend/app/services/coach/tool_registry/__init__.py (28 LOC) — re-exports ToolRegistryAdapter + ToolDefinition + LatencyTier + get_tool_registry_adapter"
    - "services/backend/app/services/coach/tool_registry/adapter.py (76 LOC) — Protocol + TypedDict + LatencyTier Literal"
    - "services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py (197 LOC) — DEFAULT adapter"
    - "services/backend/app/services/coach/tool_registry/skill_bundle_only_adapter.py (92 LOC) — FALLBACK adapter"
    - "services/backend/app/services/coach/tool_registry/manual_subset_adapter.py (119 LOC) — BACKUP adapter"
    - "services/backend/app/services/coach/tool_registry/factory.py (63 LOC) — env-flag selector"
    - "services/backend/tests/test_tool_registry_adapter.py (67 LOC, 3 tests)"
    - "services/backend/tests/test_anthropic_defer_loading_adapter.py (110 LOC, 6 tests)"
    - "services/backend/tests/test_skill_bundle_only_adapter.py (67 LOC, 4 tests)"
    - "services/backend/tests/test_manual_subset_adapter.py (77 LOC, 4 tests)"
    - "services/backend/tests/test_tool_registry_factory.py (97 LOC, 4 tests including handler-attach fix)"
  modified: []

key-decisions:
  - "ManualSubsetAdapter filters via REGISTRY.life_events_served tags (Plan 05 metadata) instead of plan's example hardcoded short-name allowlist. Plan's example listed 'avs_estimation', 'lpp_projector', 'rachat_echelonne' etc. — but REGISTRY uses canonical '<file_stem>__<func_qualname>' naming (e.g. avs_estimation_service__AvsEstimationService_estimate). 3/24 plan-listed short-names had zero REGISTRY matches (lpp_projector / fiscal_estimate / unemployment_calculator). Filtering by life_events is robust to Plan 09 metadata retrofits and aligned with D-CE-11 (registry granularity = per-calculator metadata, including life_events_served). Deviation Rule 2 (correctness — short-name allowlist would have failed Test 1 for the dropped intents)."
  - "Direct handler-attach pattern instead of pytest caplog for the invalid-value warning test. caplog passed in isolation (1 test in 0.22s) but failed in full backend suite — test_profile_resolver.py:210-228 explicitly resets its own module logger (disabled=False, propagate=True, setLevel(WARNING)), leaving caplog records empty when test_tool_registry_factory ran after it. Switched to a local _RecordCollector(logging.Handler) subclass attached/detached in try/finally, mirroring the test_profile_resolver convention. Deviation Rule 1 (own-test bug fix in caplog interaction)."
  - "v1 templated descriptions for long-tail tools — 'name — life_events_served : <events>. v1 templated description — Plan 09 LSFin keyword rewrite pending.' Intentional ship-and-iterate per CONTEXT §D-CE-01 line 252 : 'description sourcing v1 = templated FR description ; Plan 09 W2-03 rewrites these to LSFin-quality FR keyword discipline'. Acceptable for Plan 07 ship because Plan 07 ships ABSTRACTION (Protocol + 3 adapters + factory) — Plan 10 wires the adapter into coach_chat.py and Plan 09 rewrites descriptions before staging pilot."
  - "Adapter ship is SCAFFOLDING — adapter NOT wired into coach_chat.py yet. Plan 10 (W2-04 CoachToolResponse V2 latency_tier envelope) is the consumer hook ; Plan 09 (W2-03 description rewrite) lands the LSFin-grade French descriptions before staging pilot. Explicit per <risks> section of PLAN."

patterns-established:
  - "Vendor-agnostic adapter Protocol pattern for cross-provider abstractions. Replicable for : LLM SDK swap (Anthropic↔OpenAI↔Bedrock), vector DB swap (pgvector↔Pinecone↔Weaviate), embedding provider swap. Shape : runtime_checkable Protocol with N methods + TypedDict for provider-neutral entry shape + factory.py with env-flag dispatch + concrete adapters as siblings under a package directory."
  - "REGISTRY consumer pattern — Plan 07 is the FIRST consumer of app.calculators.REGISTRY (Plan 05 AST scaffold). Pattern : iterate REGISTRY.items() with (name, meta) destructure ; use meta.get('life_events_served', []) as the filter axis ; use meta.get('output_type', default) as the lucidity tier ; never re-derive metadata from file path. Plan 09 + Plan 10 + Plan 14 + Plan 15 will follow."
  - "Logger test robustness — when asserting on a module-level logger output, attach a local _RecordCollector(logging.Handler) directly to the module logger in a try/finally rather than relying on pytest caplog. caplog records can be silenced by other suite tests that mutate module logger state. test_profile_resolver.py:210-228 establishes the convention."

requirements-completed: [D-CE-01, D-CE-02]

# Metrics
duration: ~17min
completed: 2026-05-16
---

# Phase mint-calc-engine-v1 Plan 07: W2 ToolRegistryAdapter + 3 concrete adapters + factory Summary

**Vendor-agnostic `ToolRegistryAdapter` Protocol (D-CE-01) shipped at `services/backend/app/services/coach/tool_registry/` with 3 concrete adapters (`AnthropicDeferLoadingAdapter` default + `SkillBundleOnlyAdapter` fallback + `ManualSubsetAdapter` backup) + `factory.py` env-flag selector. 5 chip-emitters always-on (sourced from `coach_tools.COACH_TOOLS`), 63 long-tail calculators from `app.calculators.REGISTRY` (Plan 05) with `defer_loading=True`, 1 `tool_search_tool_bm25_20251119` declaration on the Anthropic adapter. 21 contract tests across 5 test files (3+6+4+4+4), 100% green in isolation AND in full backend suite (7051 passed = +21 vs Plan 06 baseline 7030, exact match, zero regressions). Banned-terms lint clean (exit 0). Accent FR lint clean (exit 0). Engram observation #129 saved via CLI fallback with prior_finding_refs to #103 (vendor-agnostic refinement) + #128 (Wave 1 closure). Plan 07 ships ABSTRACTION only — NOT wired into coach_chat.py yet (Plan 10 W2-04 is the consumer hook ; Plan 09 W2-03 rewrites descriptions before staging pilot).**

## Performance

- **Duration:** ~17 min
- **Started:** 2026-05-16T19:53:13Z
- **Completed:** 2026-05-16T20:10:02Z (approx)
- **Tasks:** 6/6 (Task 1 Protocol + Task 2 Anthropic + Task 3 SkillBundle + Task 4 ManualSubset + Task 5 factory + Task 6 verification & engram & SUMMARY)
- **Files created:** 11 (6 module files + 5 test files)
- **Files modified:** 0

## Accomplishments

### Task 1 — Protocol + ToolDefinition contract (commits `6f9d3f07` RED → `92e1535c` GREEN)

`services/backend/app/services/coach/tool_registry/adapter.py` (76 LOC) ships :

| Symbol | Shape |
|---|---|
| `LatencyTier` | `Literal["L1", "L2", "L3"]` — aligned with Plan 04 `LucidityLevel` |
| `ToolDefinition` | `TypedDict(total=False)` accepting `name`/`description`/`input_schema`/`defer_loading`/`type` |
| `ToolRegistryAdapter` | `@runtime_checkable Protocol` with `register_tools(turn_context)` + `latency_tier(tool_name)` |

`__init__.py` re-exports `ToolRegistryAdapter` + `ToolDefinition` + `LatencyTier` + `get_tool_registry_adapter`. 3 contract tests : public-symbol import, Protocol structural satisfaction via `isinstance`, ToolDefinition Anthropic-shape kwargs acceptance.

### Task 2 — AnthropicDeferLoadingAdapter (commits `b3f5b5c4` RED → `f520978d` GREEN)

`anthropic_defer_loading_adapter.py` (197 LOC) ships the DEFAULT adapter per D-CE-01 :

- **5 chip-emitters always-on** — descriptions sourced from `coach_tools.COACH_TOOLS` at adapter construction via `_load_chip_emitter_descriptions()`. Names : `get_budget_status`, `get_retirement_projection`, `get_cross_pillar_analysis`, `get_cap_status`, `get_couple_optimization`.
- **63 long-tail calculators from REGISTRY** — all carry `defer_loading=True`. Anthropic's BM25 search-tool loads 3-5 of them just-in-time per turn (cache-preserving per RESEARCH §Q-A).
- **1 `tool_search_tool_bm25_20251119` declaration** — server-side BM25 retrieval primitive ; MINT only declares it.
- **`beta_header` property** pinned at `tool-search-tool-2025-10-19` (stable since Oct 2025).
- v1 templated descriptions for long-tail (`<name> — life_events_served : <events>. profile_fields_needed : <fields>. v1 templated description — Plan 09 LSFin keyword rewrite pending.`). Plan 09 W2-03 rewrites these.

6 contract tests covering the shape, always-on absence-of-`defer_loading`, long-tail presence-of-`defer_loading=True`, exactly-one tool_search declaration, `latency_tier` for chip/long-tail/unknown, beta_header constant.

### Task 3 — SkillBundleOnlyAdapter (commits `6f26743c` RED → `bf134afe` GREEN)

`skill_bundle_only_adapter.py` (92 LOC) ships the FALLBACK adapter :

- Registers ALL calculators always-on (5 chip + 63 long-tail).
- **No `defer_loading` key on any tool entry** — pre-Anthropic-beta semantics.
- **No `tool_search_tool_bm25` declaration** — Bedrock-compatible.
- Reuses `_ALWAYS_ON_TOOLS` frozenset + `_load_chip_emitter_descriptions` from `anthropic_defer_loading_adapter` — single source of truth for the 5 chip-emitter list across all 3 adapters.

4 contract tests : all-calcs-always-on, no defer_loading, no tool_search, latency_tier consistency.

### Task 4 — ManualSubsetAdapter (commits `8f1cd590` RED → `6e80cdbf` GREEN)

`manual_subset_adapter.py` (119 LOC) ships the BACKUP adapter with per-intent filter :

- Per-intent filter via `REGISTRY.life_events_served` tags (Plan 05 metadata).
- 6 intents mapped to life-event sets :

| Intent | Life events |
|---|---|
| `retirement` | `{retirement, buyback}` |
| `taxes` | `{taxes, succession}` |
| `housing` | `{housing}` |
| `debt` | `{debt}` |
| `family` | `{family, marriage, divorce}` |
| `career` | `{career, independent, cross_border}` |

- Empty intents → only 5 chip-emitters baseline.
- **Deviation Rule 2** : switched from plan's hardcoded short-name allowlist (`avs_estimation`, `lpp_projector`, ...) to life_events filter — see Decisions Made #1.

4 contract tests : retirement intent includes chip+retirement-calcs, empty intents returns only chip-emitters, latency_tier consistency, housing-intent bonus.

### Task 5 — factory env-flag selector (commits `0096f82d` RED → `1e917eb3` GREEN → `f78f4518` caplog fix)

`factory.py` (63 LOC) ships :

- `get_tool_registry_adapter() -> ToolRegistryAdapter` reads `TOOL_REGISTRY_ADAPTER` env var.
- Default = `anthropic_defer_loading` (D-CE-01 primary).
- Adapter map : `anthropic_defer_loading` → `AnthropicDeferLoadingAdapter` / `skill_bundle_only` → `SkillBundleOnlyAdapter` / `manual_subset` → `ManualSubsetAdapter`.
- Invalid value → default + WARNING log breadcrumb (Sentry-compatible).

4 contract tests : default = anthropic, env-driven selection for skill_bundle_only / manual_subset, invalid value fallback + warning log. The 4th test required a caplog-flake fix (commit `f78f4518`) — see Decisions Made #2.

### Task 6 — Verification + engram + SUMMARY

- 5 Plan-07 test files green in isolation : `21 passed in 0.30s`
- Full backend suite : `7051 passed, 62 skipped, 1 xfailed, 1 warning in 113.87s` — net delta vs Plan 06 baseline (`7030 passed`) = `+21 passed` (exact match for 21 new Plan 07 tests, zero regressions, zero new skips).
- Banned-terms lint on all 11 new files : exit 0.
- Accent FR lint scope=backend : exit 0.
- Engram observation **#129** saved via CLI fallback (MCP `mem_save` tool not exposed in this executor — same gap noted in 6 prior plan SUMMARYs ; CLI `engram save` works against the live `~/.engram/engram.db` per CLAUDE.md §3).

## Task Commits

1. **Task 1 RED** — `6f9d3f07` (test : 3 failing Protocol tests)
2. **Task 1 GREEN** — `92e1535c` (feat : Protocol + ToolDefinition shipped)
3. **Task 2 RED** — `b3f5b5c4` (test : 6 failing Anthropic adapter tests)
4. **Task 2 GREEN** — `f520978d` (feat : AnthropicDeferLoadingAdapter shipped)
5. **Task 3 RED** — `6f26743c` (test : 4 failing SkillBundleOnly tests)
6. **Task 3 GREEN** — `bf134afe` (feat : SkillBundleOnlyAdapter shipped)
7. **Task 4 RED** — `8f1cd590` (test : 4 failing ManualSubset tests)
8. **Task 4 GREEN** — `6e80cdbf` (feat : ManualSubsetAdapter shipped)
9. **Task 5 RED** — `0096f82d` (test : 4 failing factory tests)
10. **Task 5 GREEN** — `1e917eb3` (feat : factory env-flag selector shipped)
11. **Task 5 fix** — `f78f4518` (fix : caplog flake in full suite — handler-attach pattern)

**Plan metadata commit:** pending (this SUMMARY + STATE.md + ROADMAP.md update + verification HTML row).

## Files Created/Modified

- `services/backend/app/services/coach/tool_registry/__init__.py` (created, 28 LOC) — package init + public re-exports
- `services/backend/app/services/coach/tool_registry/adapter.py` (created, 76 LOC) — Protocol + TypedDict
- `services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py` (created, 197 LOC) — DEFAULT
- `services/backend/app/services/coach/tool_registry/skill_bundle_only_adapter.py` (created, 92 LOC) — FALLBACK
- `services/backend/app/services/coach/tool_registry/manual_subset_adapter.py` (created, 119 LOC) — BACKUP
- `services/backend/app/services/coach/tool_registry/factory.py` (created, 63 LOC) — env-flag selector
- `services/backend/tests/test_tool_registry_adapter.py` (created, 67 LOC, 3 tests)
- `services/backend/tests/test_anthropic_defer_loading_adapter.py` (created, 110 LOC, 6 tests)
- `services/backend/tests/test_skill_bundle_only_adapter.py` (created, 67 LOC, 4 tests)
- `services/backend/tests/test_manual_subset_adapter.py` (created, 77 LOC, 4 tests)
- `services/backend/tests/test_tool_registry_factory.py` (created, 97 LOC, 4 tests + caplog fix)

**Total : 11 files created, 0 modified. ~993 LOC across module + tests.**

## Decisions Made

1. **ManualSubsetAdapter filters via `REGISTRY.life_events_served` instead of hardcoded short-name allowlist.** Plan's example mapping listed short-names (`avs_estimation`, `lpp_projector`, `rachat_echelonne`, …) but REGISTRY entries use canonical `<file_stem>__<func_qualname>` naming (Plan 05 SUMMARY §Decisions). Validated with a 1-line script : 3/24 plan-listed short-names had ZERO REGISTRY matches (`lpp_projector`, `fiscal_estimate`, `unemployment_calculator`). Filtering by `life_events_served` is robust to Plan 09 metadata retrofits and aligned with D-CE-11 registry-granularity contract.
2. **Direct handler-attach pattern for the invalid-value warning test.** pytest `caplog` worked in isolation (1 test in 0.22s) but failed in the full backend suite — `test_profile_resolver.py:210-228` explicitly resets its own module logger (`disabled=False`, `propagate=True`, `setLevel(WARNING)`), leaving `caplog` records empty when `test_tool_registry_factory` ran after it. Switched to a local `_RecordCollector(logging.Handler)` subclass attached/detached in try/finally, mirroring the `test_profile_resolver` convention.
3. **v1 templated descriptions for long-tail.** `<name> — life_events_served : <events>. profile_fields_needed : <fields>. v1 templated description — Plan 09 LSFin keyword rewrite pending.` Intentional ship-and-iterate per CONTEXT §D-CE-01 line 252. Plan 09 W2-03 rewrites all 63 descriptions with LSFin-grade French keyword discipline.
4. **Adapter is SCAFFOLDING only — NOT wired into `coach_chat.py` yet.** Plan 10 (W2-04 CoachToolResponse V2 `latency_tier` envelope) is the consumer hook. Plan 09 (W2-03 description rewrite) lands LSFin-grade French descriptions before staging pilot. Explicit per PLAN `<risks>` section.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Correctness] ManualSubsetAdapter mapping switched from short-name allowlist to life_events filter**

- **Found during:** Task 4 design (pre-test write)
- **Issue:** Plan's stub for `_PER_INTENT_TOOLS` listed short-names (`avs_estimation`, `lpp_projector`, `rachat_echelonne`, …) that do NOT match Plan 05 REGISTRY canonical naming (`<file_stem>__<func_qualname>`). 3/24 short-names had zero REGISTRY matches.
- **Fix:** Renamed `_PER_INTENT_TOOLS` to `_PER_INTENT_LIFE_EVENTS`. Maps each intent to a `frozenset[str]` of life-event tags. Filters REGISTRY by `meta.get("life_events_served", []) & allowed_events`. Plan-listed dropped tools surface automatically via their life-event tags.
- **Files modified:** `services/backend/app/services/coach/tool_registry/manual_subset_adapter.py` (constant rename + filter logic).
- **Verification:** 4 tests green (including `test_intent_retirement_includes_chip_emitters_and_retirement_calcs` + `test_intent_housing_returns_housing_calcs`).
- **Committed in:** `6e80cdbf` (Task 4 GREEN).

**2. [Rule 1 - Bug] caplog flake in full backend suite (Task 5 follow-up)**

- **Found during:** Task 6 full-suite verification
- **Issue:** `test_invalid_value_falls_back_to_default_with_warning` passed in isolation (`1 passed in 0.22s`) but failed in the full backend suite (`7050 passed, 1 failed`). Root cause : `test_profile_resolver.py:210-228` runs before our test and resets its own module logger ; pytest caplog's root-logger handler doesn't capture our `factory._logger` warnings under that ordering.
- **Fix:** Local `_RecordCollector(logging.Handler)` subclass directly attached to `factory._logger` in `try/finally`. `factory._logger.setLevel(WARNING)` + `disabled=False` + `propagate=True` force-reset on entry. `removeHandler` on teardown. Mirrors `test_profile_resolver.py:210-228` convention.
- **Files modified:** `services/backend/tests/test_tool_registry_factory.py` (test 4 only — 9 lines deleted, 37 added).
- **Verification:** Full backend suite `7051 passed, 62 skipped, 1 xfailed, 1 warning in 113.87s` — exact +21 vs Plan 06 baseline 7030, zero regressions.
- **Committed in:** `f78f4518`.

---

**Total deviations:** 2 auto-fixed (1 Rule 2 correctness — mapping axis switch ; 1 Rule 1 bug — test caplog flake).
**Impact on plan:** Both are correctness fixes. Deviation #1 prevents 3/24 silent test failures (intents would emit chip-emitters only when long-tail was expected). Deviation #2 prevents 1 full-suite regression. Neither changes the plan's user-facing contract or the 3-adapter Protocol shape.

## Issues Encountered

None blocking. The caplog flake (Deviation #2) cost ~5 min of investigation + fix.

## 0-Trust Evidence (CLAUDE.md §9.6)

| Claim | Evidence |
|---|---|
| Protocol + ToolDefinition importable | `cd services/backend && python3 -c "from app.services.coach.tool_registry import ToolRegistryAdapter, ToolDefinition, LatencyTier; print('OK')"` → `OK` |
| `@runtime_checkable` decorator present | `grep -c "@runtime_checkable" services/backend/app/services/coach/tool_registry/adapter.py` → `1` |
| AnthropicDeferLoadingAdapter Tool Search declaration | `grep -c "tool_search_tool_bm25_20251119" services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py` → `3` (constant decl + docstring refs) |
| `_ALWAYS_ON_TOOLS` frozen sentinel present | `grep -c "_ALWAYS_ON_TOOLS" services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py` → `5` |
| ManualSubsetAdapter has per-intent mapping | `grep -c "_PER_INTENT_LIFE_EVENTS\|_PER_INTENT_TOOLS" services/backend/app/services/coach/tool_registry/manual_subset_adapter.py` → `2` |
| factory default selector returns Anthropic | `cd services/backend && python3 -c "from app.services.coach.tool_registry.factory import get_tool_registry_adapter; a = get_tool_registry_adapter(); print(type(a).__name__)"` → `AnthropicDeferLoadingAdapter` |
| 21 Plan 07 tests green in isolation | `cd services/backend && python3 -m pytest tests/test_tool_registry_adapter.py tests/test_anthropic_defer_loading_adapter.py tests/test_skill_bundle_only_adapter.py tests/test_manual_subset_adapter.py tests/test_tool_registry_factory.py -q` → `21 passed in 0.30s` |
| Full backend suite 7051 passed (+21 vs Plan 06) | Pre-Plan-07 : `7030 passed, 62 skipped, 1 xfailed`. Post-Plan-07 : `7051 passed, 62 skipped, 1 xfailed, 1 warning in 113.87s`. Net delta = +21 (exact match for 21 new tests, zero regressions). |
| Banned-terms lint clean on all 11 new files | `python3 tools/checks/banned_terms_python.py <11 files>` → exit 0 |
| Accent FR lint scope=backend clean | `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0 |
| Engram observation #129 saved | `engram save "Plan 07 W2 ToolRegistryAdapter shipped" ... --topic_key mint-calc-engine-v1:w2-plan-07:tool-registry-adapter` → `Memory saved: #129 "Plan 07 W2 ToolRegistryAdapter shipped — 3-adapter pattern + factory" (architecture)` |

**Caveats (what I have NOT checked) :**

- Did NOT wire the adapter into `coach_chat.py` — that's Plan 10 (W2-04 latency_tier envelope V2). This plan is the abstraction + 3 implementations, not the dispatch-site wire-up.
- Did NOT rewrite the 63 long-tail tool descriptions to LSFin-grade French — that's Plan 09 (W2-03 description rewrite + Concern A round-trip fixture). v1 ships templated descriptions.
- Did NOT verify Anthropic Tool Search Tool actually surfaces the expected tool in top-3 for a representative French user message — that's Plan 09's round-trip fixture (`test_tool_search_round_trip.py`) which requires the LSFin description rewrite first.
- Did NOT run a staging pilot — RESEARCH §Q-A data gap acknowledges no MINT-scale prod sample exists. Plan 10 (or later) ships staging pilot behind `TOOL_REGISTRY_ADAPTER=anthropic_defer_loading` flag with p95 histogram.
- Did NOT cross-walk all 63 long-tail descriptions for banned-terms — current templated descriptions are pure metadata interpolation (no LSFin-banned verbs by construction) but Plan 09 will run `check_banned_terms()` on every rewritten description.
- USER VALUE DELIVERED : zero end-user-visible change yet. Adapter scaffolding is plumbing for Plan 10 (W2-04 wire-up). Stage 1 of 4 per CLAUDE.md §9.5 (PRs not yet opened — direct commits on `dev` branch per plan sequential model).
- MCP `mem_save` tool was NOT in the executor scope (same gap as 6 prior plan SUMMARYs) ; engram save succeeded via CLI fallback (`engram save ... --project mint --type architecture --topic_key ...` → `Memory saved: #129`).

## Engram Save Status

**Saved via CLI fallback :**
- `obs_id`: **#129**
- `title`: "Plan 07 W2 ToolRegistryAdapter shipped — 3-adapter pattern + factory"
- `type`: `architecture`
- `topic_key`: `mint-calc-engine-v1:w2-plan-07:tool-registry-adapter`
- `project`: `mint`
- `prior_finding_refs`: #103 (vendor-agnostic adapter refinement, mentioned in content body) + #128 (Wave 1 closure handoff)
- Content: full What/Where/Why/Tests/Learned/Prior-refs body, ~3.5 KB

**MCP route :** `mcp__plugin_engram_engram__mem_save` NOT exposed in this executor agent's tool list (CLI fallback path documented in CLAUDE.md §3 — `~/.engram/engram.db` is the live DB shared with `engram serve` + `engram mcp` daemons).

## Wave 2 Next Steps

- **Plan 08 — `w2-bundles`** : Adds 2 new bundles (`IndependentTaxBundle` + `SuccessionDivorceBundle`) to reach the 9-bundle target per D-CE-03. Bundle compiler is already shipped (`bundle_compiler.py:29-92`) ; the new bundles plug into `_INTENT_BUNDLES` mapping.
- **Plan 09 — `w2-tool-description-rewrite`** : Rewrites all 63 long-tail tool descriptions with LSFin-grade French keyword discipline (Concern A) + ships the `test_tool_search_round_trip.py` round-trip fixture (30 representative French messages → expected top-3 tool names). Consumes the templated v1 descriptions Plan 07 shipped.
- **Plan 10 — `w2-coach-tool-response-v2`** : Adds `latency_tier: Literal["L1","L2","L3"]` field to the `CoachToolResponse` envelope (Concern B). Wires `get_tool_registry_adapter()` into `coach_chat.py` dispatcher. First user-visible plan from W2 (chip vs narrative loader routing).
- **Plan 11 — `w2-deprecation-shims`** : Migrates root-level `independant_service.py` + `frontalier_service.py` to canonical `independants/` + `expat/` sub-directories with `DeprecationWarning` shims (D-CE-10).

## Next Plan Readiness

- Plan 07 complete : adapter abstraction + 3 implementations + factory ready for Plan 10 consumption.
- Next plan : **Plan 08 — `w2-bundles`** (bundles for narrator prompt scaffolding ; orthogonal to tool registry per D-CE-01 line 83).
- W2 wave-close is gated by Plan 11 ; W3 (DAG cache + pre-compute + GC) starts after.

## Self-Check: PASSED

- [x] `services/backend/app/services/coach/tool_registry/__init__.py` exists (28 LOC).
- [x] `services/backend/app/services/coach/tool_registry/adapter.py` exists (76 LOC).
- [x] `services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py` exists (197 LOC).
- [x] `services/backend/app/services/coach/tool_registry/skill_bundle_only_adapter.py` exists (92 LOC).
- [x] `services/backend/app/services/coach/tool_registry/manual_subset_adapter.py` exists (119 LOC).
- [x] `services/backend/app/services/coach/tool_registry/factory.py` exists (63 LOC).
- [x] `services/backend/tests/test_tool_registry_adapter.py` exists (3 tests, 67 LOC).
- [x] `services/backend/tests/test_anthropic_defer_loading_adapter.py` exists (6 tests, 110 LOC).
- [x] `services/backend/tests/test_skill_bundle_only_adapter.py` exists (4 tests, 67 LOC).
- [x] `services/backend/tests/test_manual_subset_adapter.py` exists (4 tests, 77 LOC).
- [x] `services/backend/tests/test_tool_registry_factory.py` exists (4 tests + caplog fix, 97 LOC).
- [x] Commits `6f9d3f07` / `92e1535c` / `b3f5b5c4` / `f520978d` / `6f26743c` / `bf134afe` / `8f1cd590` / `6e80cdbf` / `0096f82d` / `1e917eb3` / `f78f4518` all in `git log`.
- [x] 21 tests green in isolation : `21 passed in 0.30s`.
- [x] Full backend suite : `7051 passed, 62 skipped, 1 xfailed, 1 warning in 113.87s` — exact +21 vs Plan 06 baseline 7030, zero regressions.
- [x] Banned-terms lint clean on all 11 new files : exit 0.
- [x] Accent FR lint scope=backend clean : exit 0.
- [x] Engram observation #129 saved via CLI fallback.

---
*Phase: mint-calc-engine-v1*
*Plan: 07 — W2 ToolRegistryAdapter + 3 concrete adapters + factory*
*Completed: 2026-05-16*
