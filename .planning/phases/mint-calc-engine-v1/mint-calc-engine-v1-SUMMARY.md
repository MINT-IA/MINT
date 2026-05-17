---
phase: mint-calc-engine-v1
plan: PHASE-CLOSE
wave: 4
subsystem: phase-close
tags: [phase-close, mint-calc-engine-v1, lucidite-engine, calc-engine, w0, w1, w2, w3, w4, 5-gate-exit, code-shipped-pending-g2, concern-f, engram-compounding-observable]

# Dependency graph
requires:
  - phase: wave-1c-A3-missing-fields-handshake
    provides: "CoachToolResponse envelope (status=incomplete + missing_fields + hint_fr) cherry-picked verbatim per D-CE-04 — feeds Plan 01 helpers + Plan 10 V2 evolution"
  - phase: 94-citation-gate
    provides: "Closed-world numeric vocabulary + {{cite:<key>}} placeholders — Plan 18 verb gate threads UPSTREAM of citation parser inside _run_narrator_with_gate"
  - phase: 95-dag-invalidation
    provides: "scenarios table with inputs_hash + superseded_by columns — Plan 12 ships the missing composite partial index, Plan 13 ships the read/write cache layer that consumes it, Plan 16 ships GC"
provides:
  - "20 D-CE-XX panel verdicts delivered (table below)"
  - "12 W0 sev-3 endpoint class structurally closed (silent-wrong-tax + null-canton-crash classes)"
  - "26 endpoints grounded via Depends(get_profile_filled) + 422 envelope on missing required fields"
  - "L1/L2/L3/L4 typed lucidity payloads — `recommended_option` does NOT exist at the schema level for L2/L3 (structural enforcement, Plan 04)"
  - "ToolRegistryAdapter Protocol + 3 concrete adapters (AnthropicDeferLoading default + SkillBundleOnly fallback + ManualSubset backup, Plan 07)"
  - "2 new bundles (IndependentTaxBundle + SuccessionDivorceBundle) — bundle count 7 → 9 (D-CE-03, Plan 08)"
  - "61 FR tool descriptions rewritten with rubric lint + 75 art. legal refs across 13 Swiss laws + 30-fixture round-trip pytest (Plan 09)"
  - "CoachToolResponseV2 envelope alongside V1 with latency_tier=Literal[L1,L2,L3] (Parallel Change D-CE-19, Plan 10)"
  - "Composite partial index idx_scenarios_cache_lookup ON scenarios (profile_id, kind, inputs_hash, created_at DESC) WHERE superseded_by IS NULL — Finding 3 closed (Plan 12)"
  - "cache_reader + cache_writer + AsyncSingleflight + get_or_compute (D-CE-12 + Concern E, Plan 13)"
  - "REVERSE_DEP_MAP (146 fields, canton → 25 calcs) + get_reverse_deps(field_name) — D-CE-14 'kills two birds' (Plan 05 seed + Plan 14 contract tests)"
  - "precompute_after_fact_save BackgroundTasks + SLI baseline precision=0.767 / recall=0.900 (D-CE-13 + D-CE-14 SLI, Plan 15)"
  - "Daily GC predicate purge_superseded_scenarios + run_gc.py + railway.cron.json declaration — Finding 4 closed structurally (Plan 16)"
  - "4 Prometheus counters wired (mint_calc_invoke_total / mint_cache_lookup_total / mint_calc_warm_total / mint_zero_citation_total) + /metrics endpoint + inputs_provenance V2 envelope field (D-CE-17, Plan 17)"
  - "D-CE-16 TRIPLE DEFENSE complete : (a) schema-impossibility (Plan 04) + (b) lint extension 11 paraphrase verbs (Plan 18) + (c) runtime fail-closed gate UPSTREAM of citation parser with NFKC + zero-width strip (Plan 18)"
  - "profile_safe_fields_parity.py lefthook-wired SOFT-WARN lint + 45-field baseline drift documented (Concern C, Plan 19) — including dead-COUP-04 partner-aggregate finding"
affects:
  - v2.10-lucidite-engine-milestone
  - backlog-999.4-backend-calc-parity
  - phase-97-maestro-full-power
  - flutter-coach-context-builder-followup
  - railway-cron-service-activation

# Tech tracking
tech-stack:
  added:
    - "prometheus-client>=0.20,<1.0 (Plan 17)"
    - "Alembic p110_scenarios_cache_idx with op.get_context().autocommit_block() PG / CREATE INDEX IF NOT EXISTS SQLite (Plan 12)"
  patterns:
    - "Schema marker `Field(default=None, json_schema_extra={'from_profile': 'canonical_profile_key'})` — 16 cumulative markers across W1 endpoints"
    - "FastAPI Depends(get_profile_filled) + raise_incomplete_as_422 + PROFILE_GROUNDING_STRICT_MODE env flag (D-CE-06 + D-CE-08)"
    - "Pydantic v2 RootModel discriminated union with `Annotated[Union[...], Field(discriminator='status'|'level')]` (A3 envelope + Plan 04 L1-L4 payloads + Plan 10 V2)"
    - "Fowler Parallel Change V1 → V2 alongside (D-CE-19) — V1 classes UNCHANGED, V2 ships next to V1 + feature-flag rollout"
    - "AST scanner emits REGISTRY (D-CE-11) AND REVERSE_DEP_MAP (D-CE-14) from same walk — Override #5 'kills two birds'"
    - "Defense-in-depth triple-gate pattern : schema-impossibility + lint-time + runtime fail-closed (D-CE-16, per arXiv 2504.11168 + 2512.01353 lexical evasion data)"
    - "AsyncSingleflight = defaultdict(asyncio.Lock) keyed by (profile_id, kind, inputs_hash) (Concern E)"
    - "Strangler fig (Fowler) Phase A registry without physical move + Phase B optional consolidation deferred (D-CE-09)"
    - "Engram CLI fallback (`engram save ... --project mint --type ... --topic_key ...`) when MCP tool not exposed in subagent function list — 14+ consecutive plan reuse"

# Key files
key-files:
  created:
    - services/backend/app/core/profile_resolver.py
    - services/backend/app/models/lucidity/_payload.py
    - services/backend/app/models/coach_tools/_response_v2.py
    - services/backend/app/calculators/_registry.py
    - services/backend/app/services/coach/tool_registry/adapter.py
    - services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py
    - services/backend/app/services/coach/tool_registry/skill_bundle_only_adapter.py
    - services/backend/app/services/coach/tool_registry/manual_subset_adapter.py
    - services/backend/app/services/coach/bundles/independent_tax_bundle.py
    - services/backend/app/services/coach/bundles/succession_divorce_bundle.py
    - services/backend/app/services/cache/cache_reader.py
    - services/backend/app/services/cache/cache_writer.py
    - services/backend/app/services/cache/singleflight.py
    - services/backend/app/services/cache/get_or_compute.py
    - services/backend/app/services/cache/gc_job.py
    - services/backend/app/services/coach/pre_compute.py
    - services/backend/app/services/coach/runtime_verb_gate.py
    - services/backend/app/core/metrics.py
    - services/backend/scripts/run_gc.py
    - services/backend/railway.cron.json
    - services/backend/app/db/migrations/versions/p110_scenarios_cache_idx.py
    - tools/checks/profile_safe_fields_parity.py
  modified:
    - services/backend/app/api/v1/endpoints/coach_chat.py (verb gate wire + V2 envelope + inputs_provenance + /metrics + pre_compute hooks)
    - services/backend/app/api/v1/endpoints/arbitrage.py (Depends(get_profile_filled) on /allocation-annuelle)
    - services/backend/app/api/v1/endpoints/mortgage.py (Depends(get_profile_filled) on /affordability)
    - services/backend/app/api/v1/endpoints/lpp_deep.py (Depends on /rachat-echelonne)
    - services/backend/app/api/v1/endpoints/wealth_tax.py + family.py + life_events.py + arbitrage.py for location-vs-propriete
    - tools/checks/banned_terms_python.py (BANNED_PARAPHRASE_VERBS, NFKC, self-exempt)
    - services/backend/app/services/coach/coach_tools.py (61 FR description rewrites + R1-R5 rubric compliance)
    - services/backend/app/services/coach/bundle_compiler.py (_INTENT_BUNDLES routes to 9 bundles)
    - lefthook.yml (profile_safe_fields_parity SOFT-WARN section + Plan 18 bundles gate)
    - services/backend/pyproject.toml (prometheus-client dep)

# Decisions made (frontmatter)
decisions:
  - "G2 (Julien device sign-off) explicitly DEFERRED — autonomous: false plan, executor cannot self-clear visual gate"
  - "Phase STATUS = ◆ code-shipped on dev, pending operational gates (NOT ✓ SHIPPED) per CLAUDE.md §9.5 — Stage 1 of 4 (PR opened ≠ shipped, tests passing ≠ feature working)"
  - "Engram phase-level save MUST cite ≥10 prior_finding_refs across all 6 wave-close obs + W0 audit obs + panel synthesis obs (Concern F compounding observable per CLAUDE.md §3.5)"

# Metrics
metrics:
  duration_minutes: PLAN-20-OWN-DURATION
  completed_date: 2026-05-17
  total_plans: 20
  total_waves: 4
  cumulative_test_delta: "+234 net new tests (Plan 06 baseline 7030 → Plan 18 final 7264)"
  current_test_count_main_suite: 7264
  current_test_count_zero_regression_vs_baseline: true
---

# Phase mint-calc-engine-v1 — Phase-Close SUMMARY (CODE-SHIPPED ON DEV, PENDING OPERATIONAL GATES)

## TLDR

Phase `mint-calc-engine-v1` ships 20 plans across 4 waves (W1 grounding + L1-L4 payloads + registry — 6 plans / W2 ToolRegistryAdapter + bundles + Tool Search + envelope V2 + deprecation correction — 5 plans / W3 DAG cache + composite index + reverse-dep + pre-compute + GC — 5 plans / W4 metrics + lints + parity + phase close — 4 plans). All 20 D-CE-XX panel verdicts delivered. 12 W0 sev-3 endpoint class (silent-wrong-tax + null-canton-crash) structurally closed. Triple defense on banned verbs (schema + lint + runtime). DAG cache spine wired but dormant pending Railway cron activation. Phase status is **`◆ code-shipped on dev, pending operational gates`** — NOT `✓ SHIPPED`. Per CLAUDE.md §9.5, code merged to `dev` is Stage 1 of 4 ; cannot claim « SHIPPED » without Julien G2 device sign-off + 7 deferred operational gates (Railway cron, Railway adapter env-flip, FR description tone review, Flutter 45-field drift fix incl. dead-COUP-04 partner-aggregate, S12-API consolidation, Railway metrics scraping, endpoint metric fan-out).

## Cumulative metric snapshot (W0 → W4 close)

| Metric | Value | Source | Note |
|---|---|---|---|
| Backend test count (main suite) | **7264 passed, 63 skipped, 3 xfailed** | `cd services/backend && python3 -m pytest tests/ -q` (Plan 20 G4 run) | Delta vs Plan 06 W1-close baseline 7030 = **+234 net new tests** ; 3 xfailed = Plan 09 polish-TODO round-trip fixtures unchanged ; 1 warning = pre-existing `pytest.mark.integration` typo |
| Backend test delta per wave | W1 +83 (6947→7030) · W2 +106 (7030→7136) · W3 +53 (7136→7189) · W4 +75 (7189→7264) | Per-plan SUMMARY blocks | Zero regression at any wave boundary |
| Endpoints grounded with `Depends(get_profile_filled)` | 26 | Plan 06 W1-close + Plans 02/03 totals | Closes the 12 W0 sev-3 (3 priority-1 + 4 priority-2 + 19 sev-2 batch) + the broader sev-2 class |
| `from_profile` schema markers | 16 cumulative | Plan 02 (12) + Plan 03 (4) | One per profile-merged field on grounded request schemas |
| Bundles count | 7 → 9 | Plan 08 (D-CE-03 +IndependentTax +SuccessionDivorce) | _DROP_PRIORITY ∩ _ALWAYS_ON invariant preserved |
| FR tool descriptions rewritten | 61 (5 chip-emitters + 56 long-tail _TOOL_DESCRIPTIONS_FR map) | Plan 09 | 75 art. legal refs across 13 Swiss laws ; 30-fixture round-trip pytest 28 real passes + 2 xfail polish-TODOs ; rubric R1-R4 enforced |
| L1/L2/L3/L4 typed payload classes | 4 + 1 enum + 1 RootModel union | Plan 04 | `recommended_option` field forbidden at schema level on `L2ComparePayload` via Pydantic `extra='forbid'` |
| ToolRegistryAdapter implementations | 3 (AnthropicDeferLoading default + SkillBundleOnly fallback + ManualSubset backup) | Plan 07 | Env flag `TOOL_REGISTRY_ADAPTER=anthropic_defer_loading` ; staging flip deferred to Julien |
| Composite partial index | `idx_scenarios_cache_lookup ON scenarios (profile_id, kind, inputs_hash, created_at DESC) WHERE superseded_by IS NULL` | Plan 12 | Alembic p110 revision, 24-char id (≤32 PG VARCHAR cap), autocommit_block on PG / plain on SQLite |
| Cache layer modules | cache_reader + cache_writer + AsyncSingleflight + get_or_compute | Plan 13 | SQLite warm bench p50=0.167ms / p95=0.188ms / p99=0.237ms ; PG SLO <50ms verified post-deploy via EXPLAIN ANALYZE deferred |
| REVERSE_DEP_MAP size | 146 fields, `canton → 25 calcs`, `age → 6 calcs` | Plan 05 (seed) + Plan 14 (contract tests) | D-CE-14 SLI baseline precision=0.767 (target 0.60, +16.7pp) / recall=0.900 (target 0.70, +20.0pp) |
| Prometheus counters wired | 4 (`mint_calc_invoke_total`, `mint_cache_lookup_total`, `mint_calc_warm_total`, `mint_zero_citation_total`) | Plan 17 | `/metrics` endpoint exposes Prometheus text format ; Railway scraping config DEFERRED |
| Banned-verb defense layers | 3 (schema, lint, runtime) | Plans 04 + 18 | (a) `L2ComparePayload.extra='forbid'` ; (b) `BANNED_PARAPHRASE_VERBS` 11 verbs + NFKC ; (c) `runtime_verb_gate.gate()` UPSTREAM of Phase 94 citation parser inside `_run_narrator_with_gate` with NFKC + zero-width strip + Sentry breadcrumb `coach.verb_gate.fired` |
| `_PROFILE_SAFE_FIELDS` parity baseline drift | **45 fields** (40 server-only + 5 Flutter-only) | Plan 19 baseline run | Includes dead-COUP-04 `partner_declared` + `partner_confidence` finding — see Critical Discoveries section |
| Total commits with `mint-calc-engine-v1` prefix on `dev` | 109 commits | `git log --oneline | grep -i "mint-calc-engine-v1" | wc -l` | Includes 4 setup commits (KILL Phase 96, CONTEXT, RESEARCH, VALIDATION, 20 PLANs scaffold) + 105 per-plan commits |

## Per-D-CE-XX disposition (20 panel verdicts)

| ID | Decision | Wave | Delivered by | Disposition |
|---|---|---|---|---|
| D-CE-01 | `ToolRegistryAdapter` Protocol + 3 concrete adapters vendor-agnostic | W2 | Plan 07 (commits 6f9d3f07 → f78f4518) | ✓ shipped (default adapter active ; staging env-flip DEFERRED to Julien) |
| D-CE-02 | User-intent → bundle routing reuses `_classify_user_intent` | W2 | Plan 08 (bundle_compiler `_INTENT_BUNDLES` mapping 9-bundle) | ✓ shipped |
| D-CE-03 | 9 bundles at v1 = 7 currently shipped + 2 new gap-fills | W2 | Plan 08 (`IndependentTaxBundle` + `SuccessionDivorceBundle`) | ✓ shipped (bundle count 7 → 9 ; 25 new tests) |
| D-CE-04 | A3 = pattern; calc-engine-v1 inherits `CoachToolResponse` envelope | W1 | Plan 01 (verbatim cherry-pick + `app.models.coach_tools.__init__.py` re-exports 4 classes) | ✓ shipped |
| D-CE-05 | Audit hypothesis C = 1.5-day hybrid scan, falsifiable at n=15 | W0 | W0-AUDIT-MATRIX.md (49/57 confirmed, 12 sev-3, 23 sev-2, 18 sev-1, 4 sev-0) | ✓ shipped pre-Plan-01 |
| D-CE-06 | Profile pre-fill enforcement = defense-in-depth, PRIMARY at REST endpoints | W1 | Plans 02/03/06 (26 endpoints + `Depends(get_profile_filled)` + `_resolve_defaults` + coach dispatcher mirror) | ✓ shipped |
| D-CE-07 | Schema marker `{from_profile: "field"}` in `json_schema_extra` + shared `_resolve_defaults` | W1 | Plan 01 (`profile_resolver.py` 5-fn module) + Plan 02-06 (16 markers across 26 endpoints) | ✓ shipped |
| D-CE-08 | Missing required profile field → `CoachToolIncomplete` + 422 envelope | W1 | Plan 01 (`raise_incomplete_as_422` helper + `PROFILE_GROUNDING_STRICT_MODE` env flag) | ✓ shipped |
| D-CE-09 | File structure = Phase A registry index (no physical move) + Phase B optional consolidation later | W1 | Plan 05 (`app/calculators/_registry.py` AST-generated 63 calcs × 12 domains) | ✓ shipped (Phase A) ; Phase B (physical move) DEFERRED post-v1 |
| D-CE-10 | Duplicates `independant_service.py` + `frontalier_service.py` → migrate + deprecate | W2 | Plan 11 SCOPE CORRECTION (W0-AUDIT-MATRIX rows 32+35 RECLASSIFIED — not shims, sister S12 services with different APIs) | ⚠ scope-corrected (orchestrator Option A) — see Critical Discoveries section ; design+migration plan opened as `S12-API-consolidation` in deferred-items.md |
| D-CE-11 | Registry granularity = per-calculator metadata | W1 | Plan 05 (AST emits per-calc `name`/`file`/`profile_fields_needed`/`life_events_served`/`output_type`) | ✓ shipped |
| D-CE-12 | Cache hash read-side Phase 1 BLOCKING with composite index migration | W3 | Plan 12 (composite partial index Alembic p110) + Plan 13 (cache_reader/writer + AsyncSingleflight + get_or_compute) | ✓ shipped (Finding 3 closed) ; EXPLAIN ANALYZE on Railway PG DEFERRED |
| D-CE-13 | Post-commit pre-compute parallel with discoverability via FastAPI BackgroundTasks | W3 | Plan 15 (`precompute_after_fact_save` sync scheduler / async worker, wired into `save_fact` + `save_insight` AFTER profile.data commit) | ✓ shipped (SLI precision=0.767, recall=0.900) |
| D-CE-14 | Pre-compute selection = top-3 via static reverse-dep map | W3 | Plan 05 (REVERSE_DEP_MAP seed alongside REGISTRY, Override #5 'kills two birds') + Plan 14 (7 contract tests) + Plan 15 (consumer wire-up) | ✓ shipped ; ML scoring DEFERRED to backlog if SLI drifts below target |
| D-CE-15 | Lucidity framework = typed Pydantic discriminated payloads (ranking field FORBIDDEN by type) | W1 | Plan 04 (`L1ChiffrePayload` / `L2ComparePayload` (extra='forbid' + narrative-length-parity validator) / `L3EclairePayload` / `L4InvariantPayload` w/ `legal_article_ref` mandatory) | ✓ shipped |
| D-CE-16 | Banned-verbs enforcement = triple defense (schema + lint + runtime) | W1 + W4 | (a) Plan 04 schema-impossibility, (b) Plan 18 11 paraphrase verbs lint extension + NFKC, (c) Plan 18 `runtime_verb_gate.py` UPSTREAM of citation parser | ✓ shipped (triple defense complete) |
| D-CE-17 | North-star metric = composite scorecard, Goodhart-mitigated | W4 | Plan 17 (4 Counters + `/metrics` endpoint + `inputs_provenance: dict[field, Literal['user_input','default','derived']]` on V2 envelope) | ✓ shipped (instrumentation) ; Grafana panels + 95% target threshold DEFERRED post-baseline-measurement |
| D-CE-18 | Phase shape = single `mint-calc-engine-v1` with 4 sequential rolling-wave waves | (meta) | Plan 20 (this close-out) confirms the shape held end-to-end | ✓ shipped |
| D-CE-19 | Wave 1c-A3 ship strategy = open PR NOW, Parallel Change pattern | W2 | Plan 10 (`CoachToolResponseV2` alongside V1 with `latency_tier=Literal[L1,L2,L3]` + 5 chip-emitter migration behind `COACH_TOOL_RESPONSE_V2_ENABLED` flag, V1 retirement DEFERRED) | ✓ shipped Parallel Change V1→V2 ; V1 retirement DEFERRED post-phase |
| D-CE-20 | W0 audit = Explore agent VERY THOROUGH 30-60 min + per-wave deepening | (meta) | W0-AUDIT-MATRIX.md + W1/W2/W3/W4 per-plan SUMMARY blocks | ✓ shipped |

## Per-Concern disposition (A-F)

| Concern | Description | Delivered by | Disposition |
|---|---|---|---|
| **A** | Tool naming + description discipline (W2 hard blocker) | Plan 09 — `tool_description_rubric.py` (R1 FR verb, R2 FR text accent, R3 legal/domain keyword, R4 min 80 char length) + 61 FR rewrites + 30-fixture round-trip pytest | ✓ shipped ; FR tone review of 3 sampled descriptions DEFERRED |
| **B** | `latency_tier` field on `CoachToolResponse` | Plan 10 — `CoachToolResponseV2` Pydantic v2 RootModel discriminated union with `latency_tier: Literal["L1","L2","L3"]` REQUIRED on Ok variant (Parallel Change V1→V2 D-CE-19) | ✓ shipped ; Flutter routing doctrine DOCUMENTED, consumer-side wiring DEFERRED (Plan 19 follow-up overlaps) |
| **C** | Flutter `ProfileProvider` vs server `_PROFILE_SAFE_FIELDS` parity | Plan 19 — `tools/checks/profile_safe_fields_parity.py` (296 LOC) AST extractor + Dart regex on 4 call-sites + lefthook SOFT-WARN | ✓ shipped (lint live, lefthook wired) ; 45-field baseline drift fix DEFERRED to Flutter follow-up PR (includes critical dead-COUP-04) |
| **D** | Test fixtures bypassing `_user.profile` (Karpathy #4 reproduce-the-bug-first) | Plan 01 — `client_with_blank_profile()` pytest fixture in `services/backend/tests/conftest.py` + Plan 06 — 26-parametrized blank-profile 422 contract test | ✓ shipped |
| **E** | Cache stampede on cold-start | Plan 13 — `AsyncSingleflight` = `defaultdict(asyncio.Lock)` keyed by `(profile_id, kind, inputs_hash)` ; headline `test_concurrent_cold_cache_compute_fn_called_once_singleflight` verified `compute_fn.calls == 1` across 10 concurrent tasks | ✓ shipped |
| **F** | Engram memory discipline per wave (compounding observable per CLAUDE.md §3.5) | All 19 prior plans + this phase-close (Plan 20) — every plan ends with `engram save ... --topic_key mint-calc-engine-v1:<wave>:<sub_area>:<specific>` with `prior_finding_refs` ≥ 1 | ✓ shipped (CLI fallback used 14+ consecutive times due to MCP exposure mismatch — see Lessons Learned) |

## Per-Finding disposition (W0 audit Findings 1-6)

| Finding | Source | Disposition | Closed by |
|---|---|---|---|
| **F1** | `bundle_compiler.py` already shipped with 7 bundles (D-CE-03 Override #2) | ✓ acknowledged | Plan 08 ships 2 gap-fill bundles ON TOP of existing 7 → 9 total ; did NOT regress to 6 |
| **F2** | Coach-side 5 chip-emitters scored 5/5 grounded but no `_PROFILE_SAFE_FIELDS` cross-walk | ✓ closed structurally | Plan 19 ships the parity lint (Concern C) ; 45-field baseline drift documented |
| **F3** | Missing composite index Phase 95 forgot — without it cache-lookup is a seq-scan | ✓ closed structurally | Plan 12 ships Alembic p110 `idx_scenarios_cache_lookup` partial composite index |
| **F4** | `scenarios` table row growth unbounded without GC | ✓ closed structurally (code) ; ⏳ activation DEFERRED | Plan 16 ships `purge_superseded_scenarios()` + `run_gc.py` + `railway.cron.json` (cron declaration committed, Railway service activation requires Julien GO) |
| **F5** | L4 invariants are MINT's strongest LSFin moat — should ship FIRST in W1 (panel priority refinement) | ✓ shipped first | Plan 04 ships L1-L4 payloads with L4InvariantPayload `legal_article_ref` mandatory, used as wedge for L2/L3 |
| **F6** | L2→L3 ranking creep is highest LSFin risk surface | ✓ closed structurally | Plan 04 ships `L2ComparePayload` with `extra='forbid'` (Pydantic config) blocking `recommended_option` etc. fields at schema level + Plan 18 ships runtime verb gate as belt-and-suspenders |

## Critical Discoveries (P1 follow-on items)

### 1. Plan 19 — Dead COUP-04 partner-aggregate flow

Plan 19's first lint run surfaced that `partner_declared` + `partner_confidence` are spread Flutter-side into the `profileContext` payload (added by Phase 16 COUP-04 in `coach_chat_api_service.dart:94-97`) but **NOT present in server `_PROFILE_SAFE_FIELDS` at `coach_chat.py:957`**. The server silently drops both keys. The whole COUP-04 partner-aggregate flow into coach context is **dead**. The narrator never sees a partner-aware fact when COUP-04 was the explicit reason for adding these keys.

**Severity** : P1 (silent functional regression, NOT a crash) — discovered as a side-product of Plan 19's parity lint, NOT a Plan 19 deliverable.
**Fix path** : Flutter follow-up PR — either (a) add `partner_declared` + `partner_confidence` to server `_PROFILE_SAFE_FIELDS` (preferred, restores COUP-04 intent) or (b) drop both keys Flutter-side (regression-confirms COUP-04 abandonment, decision required).
**Documented** : `mint-calc-engine-v1-19-w4-profile-safe-fields-parity-SUMMARY.md` §"CRITICAL flag for follow-up" + this section.

### 2. Plan 11 — SCOPE CORRECTION (W0 audit misclassification)

Plan 11 W2 deprecation-shims was scoped against W0-AUDIT-MATRIX rows 32+35, which labelled `services/backend/app/services/independant_service.py` and `services/backend/app/services/frontalier_service.py` as « deprecated shims routing to canonical sub-dirs (D-CE-10) ». Pre-flight grep + API surface audit (2026-05-16) proved this was a **misclassification** : the ROOT files are sister Sprint S12 services with monolithic `IndependantService.analyze()` / `FrontalierService.analyze()` APIs ; the sub-dir « canonical » modules (S18 `independants/`, S23 `expat/`) are completely different surfaces with per-function calculators (no `.analyze()` method, naming collision on `class FrontalierService`).

A `from <canonical> import *` shim would break `app.api.v1.endpoints.segments` either at FastAPI boot (independant — `ImportError` because S18 `__init__.py.__all__` doesn't export the S12 symbols) or at runtime via `AttributeError` (frontalier — homonymous class, different methods).

**Disposition** : Orchestrator chose Option A (scope correction). Shipped : W0-AUDIT-MATRIX rows 32+35 RECLASSIFIED with explicit markers + S12-lineage module docstrings on both root files (zero behavioral change) + design+migration plan deferred to `deferred-items.md` as `S12-API-consolidation`.

## 5-gate exit contract status (Plan 20 close-out run)

| Gate | Status | Evidence |
|---|---|---|
| **G1 Maestro** | ⏭ SKIPPED — no booted sim available at executor run time | `xcrun simctl list devices booted` → `-- iOS 26.2 --` (no actual device booted) ; Maestro CLI installed at `/Users/julienbattaglia/.maestro/bin/maestro` but `flow_card_action_intent_bar.yaml` + Plan 09 `coach_tool_search_round_trip.yaml` require sim. Documented as standard caveat per executor protocol. |
| **G2 Julien device sign-off** | ⏳ **DEFERRED** — autonomous: false plan, executor cannot self-clear | Walkthrough steps documented in « Deferred — Phase ship-readiness gates » below |
| **G3 dev CI commit sha trail** | ✓ PASS | `git log --oneline | grep -i "mint-calc-engine-v1" | wc -l` → `109` commits ; first commit `91b741ed docs(calc-engine-v1): KILL Phase 96 chat-as-verb + open mint-calc-engine-v1 discuss-phase` ; latest commit before Plan 20 docs commit `91fe510e docs(mint-calc-engine-v1-19): complete W4 profile_safe_fields parity lint plan` ; no holes between Plan 01 and Plan 19 commits (per-plan SUMMARY blocks all cite their commit shas, verified by `git log` matches) |
| **G4 Regression** | ✓ PASS | `cd services/backend && python3 -m pytest tests/ -q` → `7264 passed, 63 skipped, 3 xfailed, 1 warning in 117.22s` — matches Plan 18 baseline (Plan 19 = test-only +11 lint tests already counted in baseline run) ; zero regression vs Plan 18 |
| **G5 Lints** | ✓ PASS (with documented scope) | (a) `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/bundles/ services/backend/app/services/coach/runtime_verb_gate.py` → exit 0 (Plan 18 lefthook gate scope, the production-narrator emit path). Full `services/backend/` traversal includes test fixtures + LSFin meta-mentions + .venv noise but script exits 0 (informational warnings only). (b) `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0. (c) `python3 tools/checks/tool_description_rubric.py services/backend/app/services/coach/coach_tools.py` → exit 0 (rubric R1-R4 warnings on 3 long-tail entries — Plan 09 polish-TODO baseline, NOT a regression). (d) `python3 tools/checks/profile_safe_fields_parity.py` → exit 0 (SOFT mode per Plan 19 lefthook wiring `|| true` ; reports 45-field drift baseline, does NOT fail the gate). |

## Wave-close engram doctrine roll-up

Per Concern F (CLAUDE.md §3.5 compounding observable), every wave-close + plan-close persisted a finding to engram with `topic_key: mint-calc-engine-v1:<wave>:<sub_area>:<specific>` and `prior_finding_refs` linking back to the W0 audit observations + panel synthesis + prior wave-close obs.

| Wave / Plan | Engram obs ID | Type | Topic key |
|---|---|---|---|
| W0 (panel synthesis) | **#103** | architecture | `calc_engine:panel_synthesis:20_d_ce_xx_verdicts` |
| W0 audit per-calc findings | #104-107 | discovery | `calc_engine:audit_hypothesis_c:<calc_slug>` (12 sev-3 calcs) |
| W1 wave-close (Plan 06) | **#128** | decision | `mint-calc-engine-v1:w1-wave-close:plans-01-06-grounding-l4-registry` |
| W2 individual plan obs | #129 / #130 / #131 / #132 / #134 / #135 | architecture | per Plan 07/08/09/10/11 |
| W2 wave-close (Plan 11 close-out) | **#136** | decision | `mint-calc-engine-v1:w2-wave-close:plans-07-11` |
| W3 individual plan obs | #137 / #138 / #139 / #140 / #141 | architecture | per Plan 12/13/14/15/16 |
| W3 wave-close (Plan 16 close-out) | **#142** | decision | `mint-calc-engine-v1:w3-wave-close:plans-12-16` |
| W4 individual plan obs | **#143** (Plan 17) / **#144** (Plan 18) / **#145** (Plan 19) | architecture / pattern | per plan |
| W4 wave-close + phase-close (Plan 20) | **#146 (this plan)** | architecture | `mint-calc-engine-v1:phase-close:shipped-pending-G2` |

Total `prior_finding_refs` collected for phase-close engram save : **≥10 obs** (6 wave-close + W0 audit obs + panel synthesis + W2/W3/W4 individual plan obs) — Concern F compounding observable proof.

## Deferred — Phase ship-readiness gates

These 8 items are required before this phase can claim « SHIPPED » per CLAUDE.md §9.5. Stage 1 of 4 (code on `dev`) is complete ; Stages 2-4 (CI green merge to `staging` → merge to `main` → post-merge sim verification) require Julien action.

1. **G2 — Julien device sign-off (TestFlight or booted sim).** Walkthrough steps :
   1. Boot iOS sim or open TestFlight on physical device.
   2. Launch MINT.
   3. **Scenario A — coach grounding** : Ask coach « combien je gagne ? » → narrator MUST emit L1 chip with `{{cite:<key>}}` placeholder (Phase 94 + Plan 17 inputs_provenance preserved). Sentry breadcrumb `coach.verb_gate.fired` MUST be 0.
   4. **Scenario B — 422 envelope** : Trigger divorce flow with profile-incomplete (no `canton`) → server returns 422 with `missingFields=["canton"]` and `hintFr` (D-CE-08 strict mode, Plan 01).
   5. **Scenario C — L4 invariant** : Tap a L4 mortgage-cap invariant → reads « 33% LCC plafond » in clean FR with `legal_article_ref` shown (Plan 04 L4InvariantPayload).
   6. **Scenario D — Tool Search round-trip** : Send « si je divorce demain » → `divorce_simulator` surfaces in top-3 results (Plan 09 round-trip pytest live verification).
   7. **Scenario E — banned verb fallback** : Adversarial input forcing narrator to emit « tu devrais » → `runtime_verb_gate.gate()` triggers fallback `"Je n'ai pas cette donnée pour l'instant."` (Plan 18 layer c).
   8. Check Sentry over a 30-min session window for new error classes touching the W1-W4 modules.
   - Reply « shipped » to close ; reply « blocked at scenario X: <reason> » to re-open specific plan.

2. **Plan 09 Task 5b — staging pilot Railway env-flip.** Set `TOOL_REGISTRY_ADAPTER=anthropic_defer_loading` on `mint-staging.up.railway.app` via Railway CLI or dashboard. Pilots the Anthropic Tool Search Tool beta header `tool-search-tool-2025-10-19` against the 56 long-tail calc tool descriptions live. Verification : check `/metrics` for `mint_calc_invoke_total` distribution shift toward long-tail kinds.

3. **Plan 09 Task 5a — FR tone review of 3 sampled tool descriptions.** Sample 3 of the 61 rewritten descriptions, review for tone consistency with `docs/VOICE_SYSTEM.md`. Owner : Julien.

4. **Plan 11 — S12 vs S18/S23 API consolidation decision.** Open at `.planning/deferred-items.md` → `S12-API-consolidation` section. Requires panel synthesis (Karpathy architect + backend-architect + python-pro) on monolithic-vs-granular tradeoff + naming-collision resolution for `class FrontalierService` (S12 vs S23). Owner : Julien post-phase.

5. **Plan 16 — Railway cron activation.** Cron declaration `services/backend/railway.cron.json` is committed but NOT activated. Steps :
   1. Julien creates a Railway service in `mint-staging` (or `mint-prod`) project.
   2. Set Config-as-code Path to `services/backend/railway.cron.json`.
   3. One-shot dry-run : `railway run -- python scripts/run_gc.py --dry-run`.
   4. One-shot live run : `railway run -- python scripts/run_gc.py`.
   5. Let cron auto-fire at `0 3 * * *` UTC.
   - Until activated, `scenarios` table grows unbounded after 30+ days of production traffic. Plan 16's purge predicate is dormant.

6. **Plan 17 — Railway-side metrics scraping config.** `/metrics` endpoint is live but no Grafana Cloud / Datadog / Railway built-in scraper is configured to pull it. Counters increment in-memory but observability dashboards see nothing. Owner : Julien (decision on scraping vendor).

7. **Plan 17 — Endpoint fanout follow-up.** `emit_calc_invoke_metric()` helper is wired but only firing from a subset of W1-grounded endpoints. The 26 W1-grounded endpoints need a 1-LOC `emit_calc_invoke_metric(kind=..., profile_grounded=True)` call AFTER successful compute. Estimated : ~26 × 1 LOC + 26 unit tests. Owner : follow-up PR.

8. **Plan 19 — Flutter-side 45-field drift fix.** Includes the CRITICAL dead-COUP-04 partner-aggregate finding (see Critical Discoveries §1). Steps : add 40 server-side fields to `_PROFILE_SAFE_FIELDS` (or accept the gap as documented Flutter-only design) + decide on COUP-04 partner-aggregate flow (restore vs abandon). Promote lefthook gate from SOFT to HARD after baseline is zeroed. Owner : Flutter+backend follow-up PR.

## Counter-arguments and data gaps

**Counter-argument 1 :** « 20 plans is over-engineering for a phase that doesn't add new calculators. Could have been 6-8 plans. »
- Rebuttal : Each plan corresponds to a panel-locked D-CE-XX decision + a falsifiable acceptance criterion. Compressing to 6-8 plans would have either (a) batched independent decisions into multi-week mega-PRs (violates « one atomic unit per turn » memory `feedback_gstack_skills_step_by_step.md`) or (b) skipped Concern E (cache stampede), Concern D (blank-profile fixture), Concern C (parity lint) — all of which surfaced real defects. Plan 11 SCOPE CORRECTION alone justified the per-plan granularity (a batched W2 plan would have shipped the broken shim).

**Counter-argument 2 :** « The 45-field Plan 19 baseline drift means Concern C parity is broken on day one. Phase shouldn't close. »
- Rebuttal : The parity lint is LIVE and SOFT-WARN per Plan 19 design ; the baseline drift is now observable + documented. Closing the phase WITHOUT the lint live would have left the drift invisible. Plan 19 deliverable is the lint, not the zeroed baseline ; the baseline fix is a Flutter follow-up PR (deferred item #8). The dead-COUP-04 finding is a P1 surface for the follow-up, NOT a blocker for the phase-close — Plan 19 surfaced it, which is the lint's purpose.

**Counter-argument 3 :** « D-CE-17's 95% `profile_grounded_calc_rate` target is panel-extrapolated, not data-validated. Phase closes without proof the SLO is achievable. »
- Rebuttal : This is CONTEXT.md §D-CE-17 « PM hat reserved revision after first-month baseline » acknowledged from day one. Plan 17 ships the instrumentation ; first-month baseline measurement (target window : early v2.10 production usage) becomes the data anchor. SLO threshold revision is post-phase work, NOT a Plan 17 / 20 deliverable.

**Counter-argument 4 :** « Engram MCP exposure mismatch persisted for 14+ consecutive plans without escalation. Concern F compounding observable proof is via CLI fallback, not MCP. »
- Rebuttal : Acknowledged. The CLI fallback writes to the same `~/.engram/engram.db` as the MCP daemon per GSD upstream pattern (CLAUDE.md §3.5 + PR #2074 anthropics/claude-code#13898). Findings ARE saved, `prior_finding_refs` chains ARE intact, observability is preserved. The MCP exposure mismatch is a Claude Code subagent-tools-whitelist limitation, NOT an engram limitation. Tracked in CLAUDE.md §3 + `feedback_persistent_specialist_agents_gap.md` memory — not in scope for this phase to fix.

**Data gaps remaining :**

- Did NOT EXPLAIN ANALYZE Plan 12's composite index on Railway PG14+ — SQLite test path covers structure + existence + idempotence only. Action : on first staging deploy after merge, run `EXPLAIN (ANALYZE, BUFFERS) SELECT ... FROM scenarios WHERE profile_id=? AND kind=? AND inputs_hash=? AND superseded_by IS NULL ORDER BY created_at DESC LIMIT 1` and confirm `Index Scan using idx_scenarios_cache_lookup`.
- Did NOT measure end-to-end coach turn latency p50/p95 with V2 envelope + verb gate + citation parser stacked. Action : Plan 17 metrics will reveal once Grafana panels exist post-defer #6.
- Did NOT run Maestro G1 walker against ANY of the 5 scenarios documented in deferred item #1 — sim was not booted at executor run time. Action : Julien runs G1 + G2 together.
- Did NOT verify the 8 deferred operational gates do not interact destructively (e.g. activating cron #5 while metrics scraping #6 is still off — counters increment for `mint_calc_invoke_total` but nobody reads them). Acceptable risk : counters are in-process memory, no external dependency.

## Lessons learned (per CLAUDE.md §8 wiki schema)

1. **Plan 11 scope correction is the proof Concern D fixtures matter.** A pre-flight grep + API surface audit caught a W0 audit misclassification before it shipped broken code. The « reproduce the bug first » discipline (Karpathy #4) prevented a FastAPI boot failure.

2. **Override #5 « kills two birds » saved a wave.** Plan 05 emitting BOTH `REGISTRY` (D-CE-11) AND `REVERSE_DEP_MAP` (D-CE-14) from the same AST walk meant Plan 14 (W3) was 95% test-only (the data structure already existed). Without the override, W3 would have shipped a duplicate scanner.

3. **Engram CLI fallback is operational.** 14+ consecutive plans saved via `engram save ...` CLI when MCP `mem_save` tool wasn't exposed to subagents. Writes to same DB. Per CLAUDE.md §3.5 + GSD upstream PR #2074 pattern.

4. **Triple defense on banned verbs is the only paraphrase-resistant design.** Per arXiv 2504.11168 + 2512.01353, lexical guardrails alone fail at 40-80% paraphrase + 100% character injection. Plan 04 schema-impossibility is the only structurally paraphrase-resistant layer ; Plan 18 lint + runtime are belt-and-suspenders for paths above it.

5. **« autonomous: false » is the right setting when Stage 4 verification requires human judgment.** This phase-close plan correctly identifies G2 as DEFERRED. CLAUDE.md §9.5's 4-stage shipping pipeline is honored : Stage 1 (PR opened) = ⏳ Stage 2 (CI green) = ⏳ Stage 3 (Merged) = ⏳ Stage 4 (Post-merge sim verification) = ⏳.

## Self-Check: PASSED

Verified 2026-05-17 by Plan 20 executor with deterministic checks (per CLAUDE.md §9 0-TRUST).

| Claim | Evidence command + result |
|-------|---------------------------|
| `mint-calc-engine-v1-SUMMARY.md` exists ≥80 lines | `wc -l .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-SUMMARY.md` → **312 lines** (target ≥80 ✓) |
| `mint-calc-engine-v1-VERIFICATION-REPORT.html` exists ≥100 lines | `wc -l .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VERIFICATION-REPORT.html` → **541 lines** (target ≥100 ✓) |
| ROADMAP.md milestone marker flipped 🚧 → ◆ | `grep -c "◆.*v2.10.*Lucidité Engine" .planning/ROADMAP.md` → `1` ✓ |
| ROADMAP.md phase status block updated | `grep -c "mint-calc-engine-v1.*code-shipped on dev" .planning/ROADMAP.md` → `1` ✓ |
| ROADMAP.md Plan 20 checkbox ticked | `grep "x.*mint-calc-engine-v1-20" .planning/ROADMAP.md` → `[x] mint-calc-engine-v1-20-w4-wave-close-engram-doctrine-PLAN.md — Phase close: ...` ✓ |
| STATE.md frontmatter status flipped to `phase-closed-pending-operational-gates` | `grep "phase-closed-pending-operational-gates" .planning/STATE.md` → `status: phase-closed-pending-operational-gates` ✓ |
| Engram phase-level obs saved | `engram save ... --project mint --type architecture --topic_key mint-calc-engine-v1:phase-close:shipped-pending-G2` → `Memory saved: #146 "mint-calc-engine-v1 phase-close — ◆ code-shipped on dev, 20/20 plans, pending G2 + 7 operational gates" (architecture)` ✓ |
| Engram obs ≥10 prior_finding_refs | obs #146 content cites: #103 + #117/#118 + #128 (W1) + #134/#135 + #136 (W2) + #137/#138/#139/#140/#141 + #142 (W3) + #143/#144/#145 (W4 plans) = **15 prior obs referenced** (target ≥10 ✓) |
| G3 commit sha trail | `git log --oneline | grep -i "mint-calc-engine-v1" | wc -l` → **109** ; first `91b741ed` (KILL Phase 96 + open phase) ; latest `91fe510e` (Plan 19 docs commit) — no holes ✓ |
| G4 backend regression | `cd services/backend && python3 -m pytest tests/ -q` → `7264 passed, 63 skipped, 3 xfailed, 1 warning in 117.22s` — zero regression vs Plan 18 baseline ✓ |
| G5 banned_terms_python (bundles + verb gate scope) | `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/bundles/ services/backend/app/services/coach/runtime_verb_gate.py` → exit 0 ✓ |
| G5 accent_lint_fr backend | `python3 tools/checks/accent_lint_fr.py --scope backend` → exit 0 ✓ |
| G5 tool_description_rubric | `python3 tools/checks/tool_description_rubric.py services/backend/app/services/coach/coach_tools.py` → exit 0 (Plan 09 polish-TODO warnings baseline) ✓ |
| G5 profile_safe_fields_parity (Plan 19 SOFT mode) | `python3 tools/checks/profile_safe_fields_parity.py` → exit 0 (SOFT, reports 45-field baseline drift, does NOT fail) ✓ |

**What I HAVE NOT done (per CLAUDE.md §9.7 « I don't know » is the highest-quality answer) :**

- Did NOT run G2 device sign-off — `autonomous: false` plan, executor cannot self-clear visual gate. Walkthrough steps documented in § Deferred item #1.
- Did NOT run G1 Maestro walker — no booted sim at executor run time (`xcrun simctl list devices booted` → header only). Re-runnable by Julien.
- Did NOT push to remote (`origin/dev`) — per CLAUDE.md no-push-without-explicit-OK rule + executor protocol.
- Did NOT merge `dev` → `staging` — Stage 2 of 4 per CLAUDE.md §9.5 ; Julien decision.
- Did NOT activate Railway cron service (Plan 16 deferred item #5).
- Did NOT flip staging env-flag `TOOL_REGISTRY_ADAPTER=anthropic_defer_loading` (Plan 09 deferred item #2).
- Did NOT fix the 45-field Flutter drift incl. dead-COUP-04 (Plan 19 deferred item #8 — surfaced by parity lint, requires follow-up PR).
- Did NOT consolidate S12 vs S18/S23 API (Plan 11 deferred item #4 — design+migration plan).
- Did NOT measure end-to-end coach turn latency p50/p95 with V2 envelope + verb gate + citation parser stacked — Plan 17 metrics scrape needed first (deferred item #6).
- Did NOT EXPLAIN ANALYZE Plan 12's composite index on Railway PG14+ — SQLite test path covers structure + existence + idempotence only.
- Did NOT call MCP `mem_save` tool — used `engram save` CLI fallback (15th consecutive plan with MCP exposure mismatch in subagent tool whitelist per GSD upstream PR #2074 pattern). Same DB written.

## Next phase pointer

Per CONTEXT.md §"Out of scope" + ROADMAP.md backlog 999.x, candidate next-phase work in priority order :

1. **Flutter `_PROFILE_SAFE_FIELDS` 45-field drift fix + COUP-04 partner-aggregate decision PR.** Smallest follow-up, unblocks the SOFT→HARD lefthook promotion. Estimated : 1 plan, ~6h.
2. **Backlog 999.4 — Backend calc-parity scaffold (post-TestFlight).** Python port of the 3 locked Dart calculator methods (`AvsCalculator.computeMonthlyRente` + `LppCalculator.projectToRetirement` + `RetirementTaxCalculator.capitalWithdrawalTax` projection wrapper, ~1227 LOC) so `services/backend/tests/fixtures/calc_diff_v1.jsonl` extends from 80-100 fixtures to 200. Trigger : Phase 94 §3 CalcTrace OR TestFlight unblocks. Estimated : 4-6d.
3. **ML reverse-dep map iter 2.** If Plan 15 SLI baseline (precision=0.767, recall=0.900) drifts below target after first month of production, replace the static `REVERSE_DEP_MAP` with an ML-learned mapping from `mint_calc_warm_total{hit}` history.
4. **Phase 97 MVP-PARFAIT-MAESTRO-FULL-POWER.** Maestro-driven on-device ground-truth + reachability + 8-archetype matrix + CI gates. Pre-existing ROADMAP placeholder, depends on Phase 96 (KILLED) successor work — likely opens after `v2.10 Lucidité Engine` ships its final operational gates.

---

*Phase mint-calc-engine-v1 SUMMARY generated 2026-05-17 by Plan 20 executor. Status : **`◆ code-shipped on dev, pending operational gates`**. Per CLAUDE.md §9.5 (0-TRUST 4-stage shipping pipeline), this phase has completed Stage 1 of 4. Cannot claim `SHIPPED` without G2 + 7 deferred operational gates.*
