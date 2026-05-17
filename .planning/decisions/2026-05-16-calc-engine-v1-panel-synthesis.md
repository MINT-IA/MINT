---
name: calc-engine-v1-panel-synthesis-2026-05-16
description: Synthesis of 6 expert panels' verdicts on the 20 discuss-phase questions for mint-calc-engine-v1. 11 overrides of the PM's recommended options + 6 critical findings the PM missed (Anthropic Tool Search Tool primitive shipped Oct 2025, bundle_compiler.py already shipped with 7 bundles, scenarios table missing composite index, no GC, L4 invariants should ship FIRST not last, L2 ranking creep is highest LSFin risk, profile-grounding instrumentation needed FIRST).
status: Decided 2026-05-16 by 6-panel expert consensus
date: 2026-05-16
authors: Claude (Product Lead) synthesizing 6 parallel expert panels (ai-engineer + backend-architect + architect-review + performance-engineer + business-analyst + product-manager leads). Founder-delegated decision per session 2026-05-16.
metadata:
  type: decision
  topic_key: calc_engine:panel_synthesis:2026_05_16
related:
  - [[calc-engine-matrix-2026-05-16]]
  - [[phase-96-killed-2026-05-16]]
  - [[wave-1c-A3-CONTEXT]]
---

# calc-engine-v1 — 6-panel synthesis (Q-01 → Q-20 verdicts)

## TLDR

6 expert panels (4 hats each, WebSearch mandatory) deliberated the 20 discuss-phase questions in parallel. They issued **11 overrides** of my PM recommendations and surfaced **6 critical findings I missed**. The most important finding: **Phase 93.5 `bundle_compiler.py` is already shipped with 7 bundles** (`compliance_narrator`, `life_event_router`, `lpp_projector`, `mortgage_stressor`, `pillar3a_optimizer`, `tax_explainer`, plus `citation_grammar`) — I wasn't aware. Second: Anthropic shipped `defer_loading: true` + Tool Search Tool (beta `tool-search-tool-2025-10-19`) in October 2025; this is the production primitive that replaces the homemade-bundle-only strategy. Combine: defer-loading for tool registration, bundle compiler for prompt fragments — orthogonal axes, both needed.

## Counter-arguments and data gaps

**Counter-argument 1 :** « 6 panels = expensive overkill for 20 questions. »
- Rebuttal : the 11 overrides changed downstream architecture materially (Tool Search Tool, typed lucidity payloads, dep-driven warming, parallel-change A3 ship). A single PM decision would have shipped wrong on at least Q-01, Q-03, Q-07, Q-13, Q-14, Q-15, Q-17, Q-19, Q-20. Cost-benefit favorable.

**Counter-argument 2 :** « Override #1 (Tool Search Tool) depends on an Anthropic beta header `tool-search-tool-2025-10-19` — what if Anthropic deprecates? »
- Rebuttal : the panel mitigation is « feature-flag the registration so we can hot-toggle ». Beta header has been stable since Oct 2025 (~7 months). Risk acceptable.

**Counter-argument 3 :** « Override #11 (ship A3 NOW with Parallel Change) creates rebase debt if calc-engine W1 changes the envelope. »
- Rebuttal : panel proved migration cost is ≤200 LOC, ≤1 dev day, Parallel Change pattern (Fowler). Cost of holding A3 = compounding trust-collapse on empty-message regression hitting users daily.

**Data gaps :**
- Did NOT verify that Anthropic `tool-search-tool-2025-10-19` works with Sonnet 4.5 in production at MINT's scale (~100 DAU). Mitigation : pilot on staging, measure latency overhead before locking.
- Did NOT measure baseline calc latency p95 for the 5 chip-emitters. Q-12 SLO targets (60 → 80 % hit rate) are panel-extrapolated, not data-validated. Mitigation : first vague A PR includes a pytest-benchmark baseline.
- Did NOT audit `bundle_compiler.py:_INTENT_BUNDLES` mapping for current correctness. Mitigation : W0 audit covers this.

## The 20 verdicts table

Legend : 🟢 confirmed PM's option | 🔴 OVERRIDDEN | 🟡 refined or hybrid

| Q | Verdict | Δ vs PM | Confidence | Hat unanimity |
|---|---|---|---|---|
| Q-01 | **Other (e)** — Anthropic `defer_loading: true` + Tool Search Tool for the 52 long-tail; keep 5 chip-emitters always-on; preserve `bundle_compiler.py` for prompt-fragment composition (different axis) | 🔴 | high | 4/4 |
| Q-02 | (a) — Reuse `_classify_user_intent` + evidence-driven keyword expansion only | 🟢 | high | 4/4 |
| Q-03 | **Other (e)** — Keep the 7 currently-shipped bundles + add 2 evidence-gap bundles (`IndependentTaxBundle` + `SuccessionDivorceBundle`) = **9 bundles** total. PM's « 6 bundles » was REGRESSION vs current state | 🔴 | medium | 3/4 |
| Q-04 | (a) — A3 = pattern, calc-engine-v1 generalizes via the same `CoachToolResponse` envelope | 🟢 | high | 4/4 |
| Q-05 | **Hybrid (d)+(b)** — 5 chip-emitters audit first (4h) + 10 high-value sample (1d) = **1.5 days total**, falsifiable at n=15 (≥13 confirm → broadly true) | 🟡 | high | 4/4 |
| Q-06 | (d) defense-in-depth, **PRIMARY = (a)** server-side at every REST endpoint via `Depends(get_profile_filled)`; (b) coach-tool dispatcher mirror; (c) Flutter is UX-only, NOT enforcement | 🟢 | high | 4/4 |
| Q-07 | **(b)** — explicit `{from_profile: "field"}` Pydantic `json_schema_extra` metadata + shared `_resolve_defaults(profile, body, schema_class)` helper. **REJECT (a) ContextVar+default_factory** due to documented FastAPI leakage (issues #4690, #4696, discussion #8628). Type-safe + explicit > implicit | 🔴 | high | 4/4 |
| Q-08 | (a) — `CoachToolIncomplete` + handshake (generalize Wave 1c-A3 pattern), REST callers get same envelope via HTTP 422 + structured body. Feature flag `profile_grounding_strict_mode` for graceful Flutter rollout | 🟢 | medium-high | 3/4 |
| Q-09 | **(c) Hybrid** — registry now (Phase A, no physical move) + physical consolidation optional later (Phase B). Strangler fig pattern | 🟡 | high | (truncated tool output, full reasoning in panel transcript) |
| Q-10 | (a) — Migrate + deprecate (keep `independants/` canonical, root `independant_service.py` becomes shim 1 release then removed) | 🟢 | high | 4/4 |
| Q-11 | (a) — Per-calculator metadata (name, file, profile_fields_needed, life_events_served, output_type) — ~57 entries, auto-generated from filesystem scan | 🟢 | high | 4/4 |
| Q-12 | (a) — Ship Phase 1 BLOCKING — 5 working days, ONLY read-path + write-path-stamping. NO GC, NO eviction, NO warming. Includes composite index migration `idx_scenarios_cache_lookup (profile_id, kind, inputs_hash, created_at DESC) WHERE superseded_by IS NULL` (critical gap Phase 95 left) | 🟢 | high | 4/4 |
| Q-13 | **(b)** — In parallel with discoverability work, AFTER 1 week of vague A obs. PM's (a) gating on audit-C-green is over-conservative; vague B telemetry can validate hypothesis C ITSELF | 🔴 | high | 4/4 |
| Q-14 | **Refined (a)** — Top-3 via **static reverse-dependency map** (`{fact_key → {kind_a, kind_b, ...}}`), NOT ML, NOT uniform top-N, NOT life-event-driven. Dep-map BECOMES the calc registry from Q-11 — kills two birds | 🔴 | high | 4/4 |
| Q-15 | **(b) Refine** — typed contract per surface (`LucidityL1Payload` / L2 / L3 / L4 Pydantic discriminated payloads, ranking field FORBIDDEN by type at L2/L3). NOT just doctrine table | 🔴 | high | 4/4 |
| Q-16 | **(c+) Triple defense** — schema-impossibility (Q-15 typed payloads) + lint-time (`banned_terms_python.py` extension with paraphrase verbs `« le choix le plus avisé »`, `« le plus pertinent »`, etc.) + runtime gate (fail-closed, NFKC-normalized + zero-width-stripped) | 🟡 | high | 4/4 |
| Q-17 | **(d) Composite scorecard** — PRIMARY = profile-grounded calc rate (target ≥95 %), counter-metrics = citation-chip coverage + zero-citation hallucination rate (target 0) + engagement-non-collapse tripwire. Goodhart-mitigated | 🟡 | high (4/4 on structure, 3/4 on 95 % target) | 4/4 structure |
| Q-18 | (a) — Single phase `mint-calc-engine-v1` with 4 sequential **rolling-wave** waves (W0 audit / W1 grounding / W2 discoverability / W3 DAG / W4 metrics) | 🟢 | high | 4/4 |
| Q-19 | **(b)** — Ship A3 **NOW** in parallel (independent surgical PR). Apply **Parallel Change pattern** (Fowler) if calc-engine W1 demands envelope evolution: introduce `CoachToolResponseV2`, migrate 5 chip-emitters in 1 PR, retire V1. Migration cost ≤200 LOC ≤1 day. PM's (a) hold-for-doctrine was over-conservative; empty-message regression compounds daily | 🔴 | high | 4/4 |
| Q-20 | **(d) + (b)** — Spawn Explore agent VERY THOROUGH **30-60 min batched matrix delivery**, NOT 2-3 day sprint. Then per-wave deepening (b) when planning each wave | 🔴 | high | 4/4 |

**Override count : 11 / 20 = 55 %.** Panels overrode majority of PM recommendations.

## The 11 overrides — concentrated rationale

### Override #1 (Q-01) — Anthropic Tool Search Tool replaces homemade-bundle-only

Anthropic shipped `defer_loading: true` + Tool Search Tool (beta header `tool-search-tool-2025-10-19`) in October 2025. Production primitive : full-registry visibility to Claude with per-turn just-in-time loading of long-tail tools. Internal Opus 4.5 eval gain : 79.5 % → 88.1 % on MCP-tool tasks. 85 % token-budget reduction. Defer-loaded tools do NOT invalidate prompt cache. The 5 chip-emitters at `coach_tools.py:637-722` stay `defer_loading: false` (always-on, sub-500ms L1). The 52 long-tail get `defer_loading: true`. The bundle compiler stays for prompt-fragment composition — DIFFERENT axis. Both are needed.

**Founder refinement 2026-05-16 (post-panel)** : Julien raised the vendor lock-in concern. **Refinement to D-CE-01** : wrap the panel verdict behind a `ToolRegistryAdapter` abstraction (3 concrete adapters from day 1 : `AnthropicDeferLoadingAdapter` = default, `SkillBundleOnlyAdapter` = fallback if Anthropic deprecates beta, `ManualSubsetAdapter` = backup). Env-driven feature flag selects adapter. Calculator definitions stay provider-agnostic (Pydantic v2 + FR descriptions). Pattern alignment with CLAUDE.md §1 financial_core SoT doctrine : the CALCULATORS are SoT, the LLM provider is interchangeable plumbing. Adapter cost ~50 LOC + 1 interface, fits within W2 scope. Engram obs #103 has the architectural detail.

### Override #2 (Q-03) — 7 bundles already shipped, not « 6 fresh »

The bundle compiler is at `services/backend/app/services/coach/bundle_compiler.py:29-92` with `_INTENT_BUNDLES` at lines 45-52 mapping the 6 intents to active bundles, and the `bundles/` sub-directory containing 7 bundle files (compliance_narrator, life_event_router, lpp_projector, mortgage_stressor, pillar3a_optimizer, tax_explainer, citation_grammar). Tests at `tests/bundles/test_bundle_compiler.py`. **I was unaware**. PM's « 6 bundles aligned with intents » would have been DELETION of 1 currently-shipped bundle. Evidence-driven gap-fill recommendation : add `IndependentTaxBundle` (matrix domain 8 has 2❌ absent) + `SuccessionDivorceBundle` (matrix domains 6+7 are ✅ shipped at calc layer but have no prompt scaffolding). Total = 9 bundles.

### Override #3 (Q-07) — Explicit metadata, NOT ContextVar

Documented FastAPI ContextVar pitfalls : FastAPI issues #4690, #4696, discussions #8628 + #13120. ContextVar set in middleware can leak across requests in shared `asyncio.Task` paths; BackgroundTasks lose context after middleware reset. For a **finance app where the wrong canton silently produces the wrong tax calc** (LSFin trust collapse), magic-of-invisible-ambient-context is the OPPOSITE of what we want. Explicit > implicit. Pattern : `Field(default=None, json_schema_extra={"from_profile": "canton"})` + `_resolve_defaults(profile, body, schema_class)` helper (15 LOC, type-safe, testable in isolation without FastAPI TestClient).

### Override #4 (Q-13) — Parallel with discoverability, NOT gated on grounding-green

PM was over-conservative gating vague B on « audit C + grounding + discoverability all green ». Panel found that vague B's `mint_calc_invoke_total{kind, profile_grounded=true|false}` instrumentation BECOMES the audit C data source. Ship vague B as the dataset, validate hypothesis C from the Grafana panel, not from a separate audit sprint. Sequencing : Week 1-2 vague A solo with hit-rate telemetry; Week 3+ vague B parallel with discoverability.

### Override #5 (Q-14) — Reverse-dependency map, NOT life-event heuristic

PM's « top-3 likely-needed-next based on current life event context » risks 70 % wasted background CPU because most calculators don't depend on the field that just changed. Panel : static reverse-dependency map `{fact_key → {kind_a, kind_b, ...}}` (hand-written, ~80 entries, generated semi-automatically from AST scanner over `services/backend/app/services/`). Example : `save_fact(key="commune", value="Lausanne")` invalidates only ~12 of 57 calcs (wealth_tax, allocations_familiales, succession tax, LAMal franchise...). Warming LPP rachat or divorce_simulator is pure waste — their `inputs_hash` is unchanged. **The dep-map BECOMES the calc registry from Q-11** — kills two birds. SLI : `mint_calc_warm.precision` ≥ 60 %, `mint_calc_warm.recall` ≥ 70 %.

### Override #6 (Q-15) — Typed lucidity payloads, NOT just doctrine

A doctrine table in ROADMAP.md is exactly the failure mode Phase 96 just demonstrated (« doctrine says X, code allows Y »). Panel : `LucidityLevel` StrEnum + Pydantic v2 discriminated union per level. `L2ComparePayload` REJECTS `recommended_option` / `best_choice` / `top_pick` fields at schema level — paraphrase cannot evade because the FIELD DOES NOT EXIST. Plus narrative-length-parity validator on L2 scenarios (3 scenarios of 200 / 50 / 50 words = de facto ranking = LSFin art. 8 risk). Schema-level enforcement is structural; lint-level is lexical.

### Override #7 (Q-16) — Triple defense including schema-impossibility

Lexical guardrails alone have 40-80 % false-negative rates on paraphrase (Palo Alto Unit 42, arXiv 2504.11168). 100 % evasion via character injection on production guardrails (arXiv 2512.01353). Panel additions to banned-terms : « le choix le plus avisé », « le plus pertinent », « plus avantageux que », « nettement plus », « clairement supérieur », « à mon avis », « je pense que tu », « mon conseil serait ». Runtime gate fail-closed (template fallback like Phase 94 citation gate). NFKC normalization + zero-width-char stripping before regex. Plus the Q-15 schema impossibility (no `recommended_option` field exists in L2 payload).

### Override #8 (Q-17) — Composite scorecard, NOT single metric

Single quantified north-star = Goodhart trap within 1-2 release cycles. Panel : composite = (1) profile-grounded calc rate ≥ 95 % PRIMARY + (2) citation-chip coverage ≥ 85 % counter-metric + (3) hallucination rate = 0 hard floor + (4) engagement-non-collapse weekly tripwire (>20 % drop = paged). Goodhart-mitigated via paired shadow metrics. Each metric has falsifiable target. Per-calc invocation logged with `inputs_provenance: dict[field, "user_input"|"default"|"derived"]` (schema-typed).

### Override #9 (Q-19) — Ship A3 NOW, Parallel Change for migration

A3 fixes a USER-VISIBLE regression (empty-message trust collapse documented in `probe-2026-05-15-A21-2240.json`). Holding A3 ≤3 days = 3 more days of empty coach responses. PM's hold-for-doctrine was over-conservative ; doctrine may NEVER lock in 3 days (W0 audit itself could change doctrine). Parallel Change pattern (Fowler) handles future contract evolution cleanly : ship V1 now, introduce V2 alongside if needed, retire V1 in a separate PR. Migration cost ≤200 LOC ≤1 day.

### Override #10 (Q-20) — 30-60 min Explore agent, NOT 2-3 day sprint

PM's 2-3 day audit sprint is theatre on a problem an Explore agent solves in an hour. The audit is mechanical data-extraction (per calculator : `reads_profile Y/N` + `default_fallback_values` + `flutter_screen_grounded` + `coach_tool_grounded`). Spawn one VERY THOROUGH Explore agent with engram-cited findings (`topic_key: calc_engine:audit_hypothesis_c:<calc_slug>`). Spot-validate 5-10 surfaces by hand. Total time : 90 min. Vault the matrix at `.planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md`.

### Override #11 (Q-05) — 1.5 day audit, NOT 2-3 days

Hybrid : 5 chip-emitters (4 hours, deterministic) + 10 high-value sample (1 day, statistical) = 1.5 days. Falsifiable rule : ≥13/15 confirm → broadly true → enforce server-side fix on ALL endpoints in Q-06. If 8-12/15 confirm → escalate to full 57 audit before locking Q-06. If ≤7/15 → endpoint-specific bug, fix the 7 surgically. Severity-scored 0-3 per audit hit.

## The 6 critical findings I missed

### Finding 1 — `bundle_compiler.py` is already shipped with 7 bundles
Verified at `services/backend/app/services/coach/bundle_compiler.py` and `bundles/` sub-directory. This invalidated PM's Q-03 baseline (« 6 fresh bundles »).

### Finding 2 — Anthropic Tool Search Tool primitive (Oct 2025)
Beta header `tool-search-tool-2025-10-19` + `defer_loading: true` flag. Production-grade, well-documented, cache-preserving. PM was unaware. Changes Q-01 architecture from homemade-only to Anthropic-native + bundle-compiler-as-complement.

### Finding 3 — `scenarios` table missing composite index
Phase 95 shipped the `inputs_hash` + `superseded_by` columns but NOT the composite index `(profile_id, kind, inputs_hash, created_at DESC) WHERE superseded_by IS NULL`. Without it, the cache-lookup query is a seq-scan and MAKES performance worse for power users. Critical gap. Must ship in same PR as Q-12 vague A.

### Finding 4 — No GC strategy for `scenarios` table
PM's matrix mentioned « detection without action » for invalidation but missed the GC angle. Row count grows unbounded (1 row per profile-input-change × 57 calcs × time). At 100 DAU = 16k rows/day = 5.8M rows/year. Daily GC job for `superseded_by IS NOT NULL AND created_at < now() - interval '30 days'` needed.

### Finding 5 — L4 invariants are MINT's strongest LSFin moat
The matrix lists L4 last in importance ordering. Panel : L4 (« quel que soit le scénario, plafond 33 % LCC ») is pure information générale + legal article reference. **Lowest LSFin-risk surface + HIGHEST user-value surface (« the thing nobody tells you »)**. Doctrinally aligned with `MINT_IDENTITY § « Mint te dit ce que personne n'a intérêt à te dire »`. Recommend : ship L4 invariant-surfacing FIRST in calc-engine-v1, use it as the wedge for L2/L3 which are higher-risk and need typed payload contract first.

### Finding 6 — L2 → L3 ranking creep is highest LSFin-finding risk
Auditors will read 3 scenarios where one is described in 200 words and two in 50 words and call it a de facto recommendation (LSFin art. 8 « presented as pertinent for a precise person »). Typed payload with `narrative_length_chars` field per scenario forces parity. This is a TYPE-LEVEL enforcement, not a doctrine check.

## Cross-cutting concerns from the panels

### Concern A — Tool naming + description discipline is a hard blocker
Anthropic Tool Search matches against `name` + `description`. MINT's current descriptions at `coach_tools.py:640-717` are English-only and terse. For defer-loading to find `divorce_simulator` when user asks « si je divorce demain », the description needs keywords « divorce, séparation, CC art. 122-124, splitting AVS, pension alimentaire ». **calc-engine-v1 must mandate a NAMING-AND-DESCRIPTION RUBRIC** drafted by prompt-engineer agent, validated by Tool-Search-Tool round-trip test fixture.

### Concern B — `latency_tier` field on `CoachToolResponse`
Tool Search adds 200-400 ms latency on rare-intent first turn. Must land in L2-L3 budget (2-8 s narrative loader), not in L1 (<500 ms). Add `latency_tier: Literal["L1","L2","L3"]` to `CoachToolResponse` envelope so Flutter can route to the right rendering surface (chip vs narrative-loader). **ADR-worthy decision before PLAN phase.**

### Concern C — Flutter `ProfileProvider` vs server `ProfileModel.data` parity
Server canonical = `_PROFILE_SAFE_FIELDS` (`coach_chat.py:875`). Flutter must mirror exactly. Lint test that walks the server canonical list and asserts each name maps to a Dart field in `apps/mobile/lib/services/coach/coach_context_builder.dart`. Add to W4 metrics + lints wave.

### Concern D — Test fixtures bypassing `_user.profile`
Existing pytest fixtures likely construct request bodies with all fields explicit (« happy path »). These PASS the new 422 check (Q-08) even though they bypass profile-grounding. **Karpathy #4 reproduce-the-bug-first pattern** : add a `client_with_blank_profile()` pytest fixture, use in 1 contract test per endpoint to assert 422 fires.

### Concern E — Cache stampede on cold-start
When staging deploys, all caches cold for ~5 min. 10 simultaneous users requesting same calc → 10 PG roundtrips + 10 compute fan-outs. Mitigation : in-process singleflight (asyncio.Lock dict keyed by `(profile_id, kind, inputs_hash)`). 20 LOC. Ship with vague A.

### Concern F — Engram memory discipline per wave
Every wave's findings must use `topic_key: calc_engine:<wave>:<sub_area>:<specific>` + `prior_finding_refs` linking back to W0 audit matrix observations + A3's `CoachToolResponse` decision obs #89. Make this a hard rule in `mint-calc-engine-v1-CONTEXT.md` § Memory Contract.

## Locked decisions for `mint-calc-engine-v1-CONTEXT.md`

| ID | Decision | Source |
|---|---|---|
| **D-CE-01** | Tool registration via `ToolRegistryAdapter` abstraction (Julien-driven refinement 2026-05-16 — vendor lock-in mitigation). 3 concrete adapters from day 1 : (A) `AnthropicDeferLoadingAdapter` = DEFAULT, uses `defer_loading: true` + Tool Search Tool (beta `tool-search-tool-2025-10-19`), 5 chip-emitters always-on, 52 long-tail defer-loaded ; (B) `SkillBundleOnlyAdapter` = fallback if Anthropic deprecates beta or MINT pivots provider (registers all 57 via skill-bundle compiled prompts, accepts context-bloat cost) ; (C) `ManualSubsetAdapter` = backup (extends Wave 1c-A2 `_TOOL_ELIGIBLE_TOOL_NAMES` pattern to per-intent tool-array filter). Adapter selection via env-driven `TOOL_REGISTRY_ADAPTER` flag. Calculator tool definitions stay provider-agnostic (Pydantic v2 + FR description rubric + L1-L4 lucidity payloads). Bundle compiler `bundle_compiler.py` retained orthogonally for prompt-fragment composition under all 3 adapters. | Q-01 |
| **D-CE-02** | User-intent → bundle routing reuses `_classify_user_intent` + `_INTENT_KEYWORDS` (evidence-driven keyword expansion only, no new ML classifier). | Q-02 |
| **D-CE-03** | 9 bundles at v1 = 7 currently shipped + new `IndependentTaxBundle` + `SuccessionDivorceBundle`. | Q-03 |
| **D-CE-04** | A3 = pattern; calc-engine-v1 inherits `CoachToolResponse` envelope and extends to all defer-loaded tools. | Q-04 |
| **D-CE-05** | Audit hypothesis C = 1.5 day hybrid (5 chip-emitters + 10 sample), falsifiable at n=15. | Q-05 |
| **D-CE-06** | Profile pre-fill enforcement = defense-in-depth, PRIMARY at REST endpoints via `Depends(get_profile_filled)`. Coach-tool dispatcher mirrors. Flutter is UX-only. | Q-06 |
| **D-CE-07** | Schema marker = `{from_profile: "field"}` in `json_schema_extra` + shared `_resolve_defaults` helper. REJECT ContextVar. | Q-07 |
| **D-CE-08** | Missing required profile field → `CoachToolIncomplete` + handshake. REST returns 422 + same envelope. Behind `profile_grounding_strict_mode` flag for Flutter rollout. | Q-08 |
| **D-CE-09** | File structure = Phase A registry index (no physical move) + Phase B optional consolidation later. Strangler fig pattern. | Q-09 |
| **D-CE-10** | Duplicates `independant_service.py` + `independants/` → migrate + deprecate. Keep `independants/` canonical, root shim 1 release, then remove. Same for `frontalier_service.py`. | Q-10 |
| **D-CE-11** | Registry granularity = per-calculator with metadata (name, file, profile_fields_needed, life_events_served, output_type). | Q-11 |
| **D-CE-12** | Cache hash read-side = ship Phase 1 BLOCKING. 5 days. INCLUDES composite index migration (gap Phase 95 left). NO GC, NO eviction, NO warming in Phase 1. | Q-12 |
| **D-CE-13** | Post-commit pre-compute (vague B) parallel with discoverability AFTER 1 week of vague A obs. Use FastAPI `BackgroundTasks` (NOT Celery, NOT arq) per panel infra justification. | Q-13 |
| **D-CE-14** | Pre-compute selection = top-3 via static reverse-dependency map. Map BECOMES the calc registry from D-CE-11. SLI : precision ≥ 60 %, recall ≥ 70 %. | Q-14 |
| **D-CE-15** | Lucidity framework = 4 typed Pydantic discriminated payloads (L1Payload / L2Payload / L3Payload / L4Payload). Ranking field FORBIDDEN by type at L2/L3. Narrative-length-parity validator on L2 scenarios. | Q-15 |
| **D-CE-16** | Banned-verbs enforcement = triple defense (schema-impossibility + lint-time + runtime fail-closed). NFKC-normalize + strip zero-width chars before regex. Extended verb list including paraphrases. | Q-16 |
| **D-CE-17** | North-star metric = composite scorecard. PRIMARY = profile-grounded calc rate ≥ 95 %. Counter-metrics = citation-chip coverage ≥ 85 % + zero-citation hallucination rate = 0 + engagement-non-collapse tripwire (>20 % MoM drop pages). | Q-17 |
| **D-CE-18** | Phase shape = single `mint-calc-engine-v1` with 4 sequential rolling-wave waves : W0 audit / W1 grounding + registry + lucidity payloads / W2 discoverability + bundles + Tool Search Tool / W3 DAG cache + pre-compute + GC / W4 metrics + lints + verbs. | Q-18 |
| **D-CE-19** | Wave 1c-A3 ship strategy = open PR NOW. Parallel Change pattern if W1 demands envelope evolution. Migration cost budget ≤200 LOC ≤1 day. | Q-19 |
| **D-CE-20** | W0 audit = Explore agent VERY THOROUGH 30-60 min batched delivery + per-wave deepening (5-10 surfaces spot-read by hand at each wave's planning time). | Q-20 |

## Founder action items (priority order)

1. **GREEN-LIGHT — Q-19 ship A3 NOW**. Branch `feature/wave-1c-A3-missing-fields-handshake` is ready at sha `2e1060a5`. Need : confirmation to (a) open the PR + spawn the pre-push 5-agent panel per A3 PLAN D-A3-10, (b) accept the Parallel Change migration plan.
2. **GREEN-LIGHT — Q-20 spawn W0 Explore audit agent**. Budget : 60 min, deliverable : `.planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md` with engram-cited findings.
3. **GREEN-LIGHT — D-CE-15 typed lucidity payloads**. Implementation lands in W1; need confirmation the framework refinement (typed schema vs doctrine table) is the lock you want.
4. **CONFIRM target value** — Profile-grounded calc rate ≥ 95 % (D-CE-17). PM hat reserved revision after first-month baseline.
5. **CONFIRM** — Tool Search Tool beta header dependency acceptable (D-CE-01). Mitigation flag in place.

## Sources

- 6 expert panels run in parallel 2026-05-16 (ai-engineer + backend-architect + architect-review + performance-engineer + business-analyst + product-manager leads, with 3-4 internal hats each).
- WebSearch citations : Anthropic Tool Search Tool docs, Anthropic Skills Guide PDF, Liu 2024 ACL Anthology lost-in-the-middle, Pydantic v2 discriminated union docs, FastAPI ContextVar discussions #4690/4696/8628/13120, Martin Fowler Parallel Change, MLL News LSFin requirements, FINRA 2026 AI Governance report, Palo Alto Unit 42 LLM guardrails, arXiv 2504.11168 + 2512.01353 guardrail bypass, Splunk + Practical DevSecOps Goodhart law guidance.
- Engram observations saved : #98 (Anthropic Tool Search Tool discovery), #99 (calc-engine grounding panel), #102 (architecture consolidation panel), #103-105 (DAG triggers + lucidity + sequencing panels — IDs pending mem_save).
- Companion artifacts : `.planning/decisions/2026-05-16-calc-engine-matrix.md`, `.planning/decisions/2026-05-16-phase-96-killed.md`, `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-CONTEXT.md`, `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-QUESTIONS.json`.
