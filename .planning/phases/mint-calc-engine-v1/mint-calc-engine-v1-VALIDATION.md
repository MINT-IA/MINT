---
phase: mint-calc-engine-v1
slug: mint-calc-engine-v1
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-16
---

# Phase mint-calc-engine-v1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Source: RESEARCH.md § Validation Architecture (mapped each D-CE-XX to its deterministic validation method).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework (backend)** | pytest 8.x (`services/backend/pyproject.toml`) |
| **Framework (mobile)** | flutter_test (Dart) |
| **Maestro flows** | `tools/simulator/flows/maestro-perfect-set/` |
| **Config file** | `services/backend/pyproject.toml` + `apps/mobile/pubspec.yaml` |
| **Quick run command** | `cd services/backend && python3 -m pytest tests/ -q -x --ff` |
| **Full suite command** | `cd services/backend && python3 -m pytest tests/ -q && cd ../../apps/mobile && flutter analyze && flutter test` |
| **Lint suite** | `python3 tools/checks/banned_terms_python.py services/ && python3 tools/checks/accent_lint_fr.py --scope backend mobile && python3 tools/checks/wiki_lint.py lint` |
| **Estimated runtime (backend full)** | ~180 seconds (6970 tests post-A3 baseline) |
| **Estimated runtime (Maestro G1)** | ~120 seconds per flow |

---

## Sampling Rate

- **After every task commit:** Run `python3 -m pytest tests/<scope> -q -x` (touched-file scope only, fail-fast).
- **After every wave PR:** Full backend suite + flutter analyze + lint suite.
- **Before merging wave PR to dev:** Full suite GREEN + Maestro G1 flow PASS + Julien G2 device sign-off (for waves touching narrator user-visible surfaces).
- **Before `/gsd-verify-work`:** Full suite must be green + all per-D-CE-XX assertions pass.
- **Max feedback latency:** 30 seconds (touched-file scope), 180 seconds (full backend), 300 seconds (full stack).

---

## Per-Task Verification Map

> Mapping from D-CE-XX locked decisions to their deterministic validation. Task IDs allocated by planner; placeholders use `<wave>-<plan>-<task>` skeleton.

### Wave W1 — Grounding + Registry + Lucidity Payloads

| Task ID | Plan | Wave | D-CE / Concern | Validates | Test Type | Automated Command | File Exists | Status |
|---------|------|------|----------------|-----------|-----------|-------------------|-------------|--------|
| W1-01-01 | 01 | 1 | D-CE-07 | `_resolve_defaults(profile, body, schema_class)` merges body > profile > default, respects `model_fields_set` | unit | `pytest services/backend/tests/test_profile_resolver.py -q` | ❌ W0 | ⬜ pending |
| W1-01-02 | 01 | 1 | D-CE-06 | `get_profile_filled` FastAPI dependency reads `_user.profile` and injects | unit + integration | `pytest services/backend/tests/test_get_profile_filled.py -q` | ❌ W0 | ⬜ pending |
| W1-01-03 | 01 | 1 | D-CE-08 | `raise_incomplete_as_422` produces correct envelope `{status: incomplete, missing_fields, hint_fr}` | unit | `pytest services/backend/tests/test_profile_resolver.py::test_raise_incomplete_envelope -q` | ❌ W0 | ⬜ pending |
| W1-01-04 | 01 | 1 | Concern D | `client_with_blank_profile()` pytest fixture in conftest.py | infrastructure | `pytest services/backend/tests/conftest.py --collect-only \| grep client_with_blank_profile` | ❌ W0 | ⬜ pending |
| W1-02-01 | 02 | 1 | D-CE-06 + W0 sev-3 #1 | `allocation_annuelle` endpoint reads `_user.profile` for `canton, is_property_owner, taux_hypothecaire, rendement_3a` | contract | `pytest services/backend/tests/test_arbitrage_allocation_annuelle_grounding.py -q` | ❌ W0 | ⬜ pending |
| W1-02-02 | 02 | 1 | D-CE-06 + W0 sev-3 #2 | `affordability_service` endpoint reads `_user.profile` for mortgage type + rate | contract | `pytest services/backend/tests/test_mortgage_affordability_grounding.py -q` | ❌ W0 | ⬜ pending |
| W1-02-03 | 02 | 1 | D-CE-06 + W0 sev-3 #3 | `rachat_echelonne_service` endpoint returns 422 if canton missing (not crash, not VD-default) | contract | `pytest services/backend/tests/test_lpp_rachat_echelonne_grounding.py -q` | ❌ W0 | ⬜ pending |
| W1-03-01 | 03 | 1 | D-CE-06 + W0 sev-3 #4-7 | `wealth_tax_service`, `succession_simulator`, `concubinage_service` (succession), `location_vs_propriete` reject null canton with 422 envelope | contract | `pytest services/backend/tests/test_canton_required_grounding.py -q` | ❌ W0 | ⬜ pending |
| W1-04-01 | 04 | 1 | D-CE-15 | `LucidityLevel` StrEnum + `L1ChiffrePayload` / `L2ComparePayload` / `L3EclairePayload` / `L4InvariantPayload` discriminated union | unit | `pytest services/backend/tests/test_lucidity_payloads.py -q` | ❌ W0 | ⬜ pending |
| W1-04-02 | 04 | 1 | D-CE-15 | `L2ComparePayload` REJECTS `recommended_option` / `best_choice` field at validation time | unit | `pytest services/backend/tests/test_lucidity_payloads.py::test_l2_rejects_ranking_field -q` | ❌ W0 | ⬜ pending |
| W1-04-03 | 04 | 1 | D-CE-15 + Finding 6 | Narrative-length-parity validator on `L2ComparePayload.scenarios` (±15% char count) | unit | `pytest services/backend/tests/test_lucidity_payloads.py::test_l2_length_parity -q` | ❌ W0 | ⬜ pending |
| W1-04-04 | 04 | 1 | Finding 5 | L4 invariant-surfacing wired FIRST (1 endpoint emits `L4InvariantPayload` with `legal_article_ref`) | integration | `pytest services/backend/tests/test_l4_invariant_endpoint.py -q` | ❌ W0 | ⬜ pending |
| W1-05-01 | 05 | 1 | D-CE-11 | `app/calculators/_registry.py` auto-generated from AST scan, ~57 entries | unit | `pytest services/backend/tests/test_calc_registry.py::test_registry_size -q` | ❌ W0 | ⬜ pending |
| W1-05-02 | 05 | 1 | D-CE-11 | Registry entries carry `profile_fields_needed`, `life_events_served`, `output_type` | unit | `pytest services/backend/tests/test_calc_registry.py::test_registry_metadata -q` | ❌ W0 | ⬜ pending |
| W1-06-01 | 06 | 1 | Concern D | All Wave 1 endpoints with `from_profile` markers fail with 422 when invoked via `client_with_blank_profile()` | contract | `pytest services/backend/tests/test_blank_profile_422_contract.py -q` | ❌ W0 | ⬜ pending |

### Wave W2 — Discoverability + Bundles + Tool Search Tool

| Task ID | Plan | Wave | D-CE / Concern | Validates | Test Type | Automated Command | File Exists | Status |
|---------|------|------|----------------|-----------|-----------|-------------------|-------------|--------|
| W2-01-01 | 01 | 2 | D-CE-01 | `ToolRegistryAdapter` Protocol defined with `register_tools(turn_context) -> list[ToolDefinition]` + `latency_tier(tool_name)` | unit | `pytest services/backend/tests/test_tool_registry_adapter.py::test_protocol -q` | ❌ W0 | ⬜ pending |
| W2-01-02 | 01 | 2 | D-CE-01 | `AnthropicDeferLoadingAdapter` registers 5 chip-emitters with `defer_loading: false` and 52 long-tail with `defer_loading: true` | unit | `pytest services/backend/tests/test_anthropic_defer_loading_adapter.py -q` | ❌ W0 | ⬜ pending |
| W2-01-03 | 01 | 2 | D-CE-01 | `SkillBundleOnlyAdapter` falls back to bundle-compiled prompts under all-57 visibility | unit | `pytest services/backend/tests/test_skill_bundle_only_adapter.py -q` | ❌ W0 | ⬜ pending |
| W2-01-04 | 01 | 2 | D-CE-01 | `ManualSubsetAdapter` filters tools per `_TOOL_ELIGIBLE_INTENTS` | unit | `pytest services/backend/tests/test_manual_subset_adapter.py -q` | ❌ W0 | ⬜ pending |
| W2-01-05 | 01 | 2 | D-CE-01 | Adapter selected by `TOOL_REGISTRY_ADAPTER` env var (default `anthropic_defer_loading`) | unit + integration | `pytest services/backend/tests/test_tool_registry_factory.py -q` | ❌ W0 | ⬜ pending |
| W2-02-01 | 02 | 2 | D-CE-03 | `IndependentTaxBundle` registered in `_INTENT_BUNDLES`, citation grammar exposed | unit | `pytest services/backend/tests/bundles/test_independent_tax_bundle.py -q` | ❌ W0 | ⬜ pending |
| W2-02-02 | 02 | 2 | D-CE-03 | `SuccessionDivorceBundle` registered, CC art. 122-124 + 467-469 references in citation pointers | unit | `pytest services/backend/tests/bundles/test_succession_divorce_bundle.py -q` | ❌ W0 | ⬜ pending |
| W2-03-01 | 03 | 2 | Concern A | Tool description rubric applied — each calc tool's `description` contains French keywords + LSFin-lucidity vocabulary | lint | `python3 tools/checks/tool_description_rubric.py services/backend/app/services/coach/coach_tools.py` | ❌ W0 | ⬜ pending |
| W2-03-02 | 03 | 2 | Concern A | Tool Search round-trip: 30 French user messages → expected tool in top-3 results | integration | `pytest services/backend/tests/test_tool_search_round_trip.py -q` | ❌ W0 | ⬜ pending |
| W2-04-01 | 04 | 2 | Concern B | `CoachToolResponse` envelope V2 with `latency_tier: Literal["L1","L2","L3"]` field, V1 → V2 migration | unit + Parallel Change | `pytest services/backend/tests/test_coach_tool_response_v2.py -q` | ❌ W0 | ⬜ pending |
| W2-05-01 | 05 | 2 | D-CE-10 | `independants/` is canonical, root `independant_service.py` is shim with DeprecationWarning | grep + unit | `grep -E "DeprecationWarning\|warnings.warn" services/backend/app/services/independant_service.py && pytest services/backend/tests/test_independant_shim.py -q` | ❌ W0 | ⬜ pending |
| W2-05-02 | 05 | 2 | D-CE-10 | `expat/frontalier_service.py` canonical, root `frontalier_service.py` shimmed | grep + unit | `grep -E "DeprecationWarning\|warnings.warn" services/backend/app/services/frontalier_service.py && pytest services/backend/tests/test_frontalier_shim.py -q` | ❌ W0 | ⬜ pending |

### Wave W3 — DAG Cache + Pre-Compute + GC

| Task ID | Plan | Wave | D-CE / Concern | Validates | Test Type | Automated Command | File Exists | Status |
|---------|------|------|----------------|-----------|-----------|-------------------|-------------|--------|
| W3-01-01 | 01 | 3 | D-CE-12 | Alembic migration creates composite index `idx_scenarios_cache_lookup (profile_id, kind, inputs_hash, created_at DESC) WHERE superseded_by IS NULL` | migration | `cd services/backend && alembic upgrade head && psql -c "\\d+ scenarios" \| grep idx_scenarios_cache_lookup` | ❌ W0 | ⬜ pending |
| W3-01-02 | 01 | 3 | D-CE-12 | `EXPLAIN ANALYZE` of cache-lookup query shows Index Scan, not Seq Scan | sql | `psql -c "EXPLAIN ANALYZE SELECT * FROM scenarios WHERE profile_id = $1 AND kind = $2 AND inputs_hash = $3 AND superseded_by IS NULL ORDER BY created_at DESC LIMIT 1" \| grep "Index Scan"` | ❌ W0 | ⬜ pending |
| W3-01-03 | 01 | 3 | D-CE-12 | Migration uses `op.get_context().autocommit_block()` (CONCURRENTLY-safe) | grep | `grep "autocommit_block" services/backend/migrations/versions/*scenarios_cache_lookup*.py` | ❌ W0 | ⬜ pending |
| W3-02-01 | 02 | 3 | D-CE-12 | `cache_reader.lookup(profile_id, kind, inputs_hash)` returns hit within 50 ms (warm) | benchmark | `pytest-benchmark services/backend/tests/bench_cache_reader.py::test_lookup_p95 --benchmark-min-time=0.1` | ❌ W0 | ⬜ pending |
| W3-02-02 | 02 | 3 | D-CE-12 + Concern E | Singleflight `asyncio.Lock` dict prevents stampede on cold cache | concurrency | `pytest services/backend/tests/test_cache_singleflight.py -q` | ❌ W0 | ⬜ pending |
| W3-03-01 | 03 | 3 | D-CE-14 | `app/calculators/_reverse_deps.py` maps `{fact_key → {kind_a, kind_b, ...}}`, ~80 entries, AST-derived from `_registry.py` | unit | `pytest services/backend/tests/test_reverse_deps.py -q` | ❌ W0 | ⬜ pending |
| W3-04-01 | 04 | 3 | D-CE-13 | `BackgroundTasks` scheduled on `save_fact`/`save_insight` invocation, top-3 calcs pre-computed | integration | `pytest services/backend/tests/test_pre_compute_background.py -q` | ❌ W0 | ⬜ pending |
| W3-04-02 | 04 | 3 | D-CE-14 SLI | `mint_calc_warm_total{hit=true}` / `mint_calc_warm_total` precision ≥ 60%, recall ≥ 70% on synthetic profile mutations | benchmark | `pytest services/backend/tests/test_warm_precision_recall.py -q` | ❌ W0 | ⬜ pending |
| W3-05-01 | 05 | 3 | Finding 4 | GC daily job deletes `superseded_by IS NOT NULL AND created_at < now() - interval '30 days'` rows | sql + cron | `psql -c "SELECT count(*) FROM scenarios WHERE superseded_by IS NOT NULL AND created_at < now() - interval '30 days'"` should return 0 after job runs | ❌ W0 | ⬜ pending |

### Wave W4 — Metrics + Lints + Verbs

| Task ID | Plan | Wave | D-CE / Concern | Validates | Test Type | Automated Command | File Exists | Status |
|---------|------|------|----------------|-----------|-----------|-------------------|-------------|--------|
| W4-01-01 | 01 | 4 | D-CE-17 PRIMARY | `mint_calc_invoke_total{kind, profile_grounded}` Prometheus counter exposed (or Sentry equivalent — see Open Q1) | metric | `curl localhost:8000/metrics \| grep mint_calc_invoke_total` (or `curl localhost:8000/metrics` if Sentry path) | ❌ W0 | ⬜ pending |
| W4-01-02 | 01 | 4 | D-CE-17 counter-metric | `mint_zero_citation_total` counter — hard floor on hallucination rate (every emitted number citation-gated) | metric | `curl localhost:8000/metrics \| grep mint_zero_citation_total` | ❌ W0 | ⬜ pending |
| W4-01-03 | 01 | 4 | D-CE-17 | `inputs_provenance: dict[field, Literal["user_input", "default", "derived"]]` logged per calc invocation | unit + log | `pytest services/backend/tests/test_inputs_provenance.py -q` | ❌ W0 | ⬜ pending |
| W4-02-01 | 02 | 4 | D-CE-16(b) | `banned_terms_python.py` extended with 11 paraphrase verbs (« le plus pertinent », « plus avantageux », etc.) | lint | `python3 -c "from tools.checks.banned_terms_python import BANNED_TERMS; assert 'le plus pertinent' in BANNED_TERMS"` | ❌ W0 | ⬜ pending |
| W4-02-02 | 02 | 4 | D-CE-16(c) | Runtime banned-verb gate normalizes NFKC + strips zero-width, falls back to template if match | unit | `pytest services/backend/tests/test_runtime_banned_verb_gate.py -q` | ❌ W0 | ⬜ pending |
| W4-03-01 | 03 | 4 | Concern C | `profile_safe_fields_parity.py` lint asserts Flutter `coach_context_builder.dart` mirrors server `_PROFILE_SAFE_FIELDS` | lint | `python3 tools/checks/profile_safe_fields_parity.py` (exit 0) | ❌ W0 | ⬜ pending |
| W4-04-01 | 04 | 4 | Concern F | Engram findings per closed wave include `topic_key: calc_engine:<wave>:*` + `prior_finding_refs` linking W0 / A3 / panel synthesis | doc + manual | wave-close SUMMARY.md includes engram obs IDs with cross-refs | manual | ⬜ pending |

*Status legend: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky · 🔁 in progress*

---

## Wave 0 Requirements

### Files / dependencies that DO NOT EXIST today and must be created in W1 (foundation)

- [ ] `services/backend/app/core/profile_resolver.py` — `_resolve_defaults`, `get_profile_filled`, `_required_profile_fields_missing`, `raise_incomplete_as_422`
- [ ] `services/backend/app/models/lucidity/_payload.py` — `LucidityLevel`, `L1ChiffrePayload`, `L2ComparePayload`, `L3EclairePayload`, `L4InvariantPayload`
- [ ] `services/backend/app/calculators/_registry.py` — auto-generated registry (AST-scanned)
- [ ] `services/backend/tests/conftest.py` extension — `client_with_blank_profile()` fixture (Concern D)
- [ ] `services/backend/tests/test_profile_resolver.py` — W1-01-01..03 stubs
- [ ] `services/backend/tests/test_get_profile_filled.py` — W1-01-02 stub
- [ ] `services/backend/tests/test_lucidity_payloads.py` — W1-04-01..03 stubs
- [ ] `services/backend/tests/test_calc_registry.py` — W1-05-01..02 stubs
- [ ] `services/backend/tests/test_blank_profile_422_contract.py` — W1-06-01 stub

### Files / dependencies for W2

- [ ] `services/backend/app/services/coach/tool_registry/adapter.py` (Protocol)
- [ ] `services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py`
- [ ] `services/backend/app/services/coach/tool_registry/skill_bundle_only_adapter.py`
- [ ] `services/backend/app/services/coach/tool_registry/manual_subset_adapter.py`
- [ ] `services/backend/app/services/coach/tool_registry/factory.py` (env-flag selector)
- [ ] `services/backend/app/services/coach/bundles/independent_tax_bundle.py`
- [ ] `services/backend/app/services/coach/bundles/succession_divorce_bundle.py`
- [ ] `tools/checks/tool_description_rubric.py` (Concern A lint)
- [ ] `services/backend/tests/test_tool_registry_adapter.py` + per-adapter tests
- [ ] `services/backend/tests/test_tool_search_round_trip.py` (30 French messages → top-3 results)
- [ ] `services/backend/tests/test_coach_tool_response_v2.py` (Concern B envelope V2)

### Files / dependencies for W3

- [ ] `services/backend/migrations/versions/<NNNN>_scenarios_cache_lookup_index.py` (Alembic, autocommit_block)
- [ ] `services/backend/app/services/cache/cache_reader.py` + `cache_writer.py`
- [ ] `services/backend/app/services/cache/gc_job.py` (Railway cron or APScheduler — see Open Q4)
- [ ] `services/backend/app/services/coach/pre_compute.py` (BackgroundTasks scheduler)
- [ ] `services/backend/app/calculators/_reverse_deps.py` (AST-derived inverted index from registry)
- [ ] `services/backend/tests/test_cache_singleflight.py` (Concern E)
- [ ] `services/backend/tests/test_reverse_deps.py`
- [ ] `services/backend/tests/test_pre_compute_background.py`
- [ ] `services/backend/tests/test_warm_precision_recall.py` (D-CE-14 SLI)

### Files / dependencies for W4

- [ ] `services/backend/app/core/metrics.py` extension (or new) for `mint_calc_invoke_total`, `mint_zero_citation_total`, `mint_cache_lookup_total`, `mint_calc_warm_total`
- [ ] `prometheus-client` dependency added to `services/backend/pyproject.toml` (OR Sentry fallback per Open Q1)
- [ ] `tools/checks/banned_terms_python.py` extension (11 paraphrase verbs)
- [ ] `services/backend/app/services/coach/runtime_verb_gate.py` (D-CE-16(c))
- [ ] `tools/checks/profile_safe_fields_parity.py` (Concern C)
- [ ] `services/backend/tests/test_inputs_provenance.py`
- [ ] `services/backend/tests/test_runtime_banned_verb_gate.py`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| L4 invariant surfacing reads as « the thing nobody tells you » in French | Finding 5 + D-CE-15 + voice doctrine | Subjective French tone (vocabulary, register, conciseness) — no automated lint can score voice | Julien reads 5 sample L4 invariants emitted by the L4 endpoint and confirms they sound like Mint (legal article ref + plain French + non-promissory) |
| Tool Search produces good top-3 for ambiguous French queries (« si je quitte la Suisse ») | D-CE-01 + Concern A | Discrete tool ranking — automated round-trip fixture validates known queries, but new ambiguity classes need human judgment | Julien types 10 « hard » queries on staging, confirms top-3 contains the right tool |
| Composite scorecard panel in Grafana reads usefully | D-CE-17 + W4 | Dashboard layout subjective | Julien reviews Grafana dashboard post-W4 ship, confirms panels readable + counters trustworthy |
| Pre-push 5-agent panel verdict on each wave PR | CLAUDE.md §3.5 routing rules | Multi-agent panel is semi-deterministic but final BLOCKED/MAJOR/MINOR call needs human reconciliation | Per memory `feedback_design_panel_before_push`: spawn `code-reviewer + architect-review + security-auditor + qa-expert + test-automator` (+ wave-specific specialists) ; apply I-11 severity ladder ; Julien approves PR open |
| Device G2 walkthrough on TestFlight for waves touching narrator user-visible surfaces (W1 ranking-field rejection, W2 tool description rewrites, W4 banned-verb runtime gate) | 5-gate exit contract G2 | Real-device behavior on real network with real Anthropic API key cannot be simulated mechanically | Julien runs the Maestro perfect-set on his device post-merge to staging, confirms narrator coaching register intact + no LSFin-banned-term leakage + no ranking creep |

---

## Open Questions (carried from RESEARCH.md, to resolve at wave-planning time)

| # | Question | Resolves at | Default if not resolved |
|---|---|---|---|
| Q1 | Prometheus vs Sentry custom metrics for D-CE-17 instrumentation | W4 planning | Sentry fallback (no new dep, custom tags on `coach_breadcrumbs.py`) |
| Q2 | Pre-commit lefthook freshness lint for `_registry.py` vs CI-only | W1-05 planning | CI-only (faster pre-commit, registry can regenerate lazily) |
| Q3 | W2 `latency_tier` envelope V2 — drop-in vs Parallel Change | W2-04 planning | Parallel Change (V1 → V2 migration in separate PR per D-CE-19 pattern) |
| Q4 | Reverse-dep-map handling of derived fields (e.g. `marital_status` → `lpp_rachat_calculator` via tax bracket coupling) | W3-03 planning | Direct deps only in v1, follow-up TODO if `mint_calc_warm.recall < 70%` |
| Q5 | W4 banned-verb runtime gate placement BEFORE vs AFTER Phase 94 citation gate | W4-02 planning | BEFORE (catch ranking words before citation substitution to avoid double-template fallback) |
| Q6 | D-CE-08 `profile_grounding_strict_mode` rollout staging duration | W1-06 planning + post-merge | 1 release on staging strict=true → 1 release on production strict=false → flip production strict=true |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies declared
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all « ❌ W0 » MISSING references (14+ files identified above)
- [ ] No watch-mode flags (`--watch`, `--re-run`) in any test command
- [ ] Feedback latency < 30s per touched-file scope, < 300s per full suite
- [ ] Manual-only behaviors enumerated with concrete instructions (5 above)
- [ ] Per-D-CE-XX mapping complete (D-CE-01..D-CE-20 all addressed)
- [ ] `nyquist_compliant: true` set in frontmatter after planner sign-off

**Approval:** pending (will flip to `approved 2026-05-16` once planner produces W1-W4 PLAN.md files honoring the verify map above)

---

## Sources

- `mint-calc-engine-v1-RESEARCH.md` § Validation Architecture (the per-D-CE-XX mapping source)
- `mint-calc-engine-v1-CONTEXT.md` § Code Context (file paths verified)
- `W0-AUDIT-MATRIX.md` § Recommended Fix Priority Order (W1 sev-3 task ordering)
- `wave-1c-A3-PLAN.md` I-11 severity ladder (BLOCKED / CRITICAL / MAJOR / MINOR / SUGGESTION) for pre-push panel discipline
- CLAUDE.md § 3.5 routing rules (panel composition per wave) + § 9 0-TRUST (deterministic citation requirement)
- Memory `feedback_perimeter_5_gates` (G1-G5 exit contract per wave PR)
