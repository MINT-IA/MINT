---
description: Phase mint-calc-engine-v1 — MINT Lucidité Engine. 20 D-CE-XX decisions LOCKED by 6 expert panels (11 overrides + 6 critical findings). Builds the L1/L2/L3/L4 lucidité layer on top of the 57 already-shipped Swiss financial calculators. Four axes — (A) LLM discoverability via Anthropic Tool Search + ToolRegistryAdapter, (B) real-profile grounding via _resolve_defaults + CoachToolIncomplete (hypothesis C confirmed 86%, 12 sev-3 endpoints SHIP WRONG NUMBERS today), (C) architecture consolidation via auto-registry + strangler-fig moves, (D) DAG action via cache + dep-driven pre-compute + GC. Wave 1c-A3 ships in parallel via Parallel Change pattern.
---

> **Statut : CLOS 2026-07-29** — supersedé par la campagne étalon fiscal (#1060-#1100). La promesse « chiffres justes » (ROADMAP v2.10) est tenue par l'étalon ESTV, pas par les gates opérationnels de mai ; les 7 gates différés sont requalifiés — la plupart sont morts, le vivant a été refait par la campagne. Réconciliation plans 2026-07-29.

# Phase mint-calc-engine-v1: Context (LOCKED)

**Gathered:** 2026-05-16
**Status:** Ready for planning. CONTEXT.md generated mechanically from the 20 D-CE-XX panel decisions per founder-delegated direction 2026-05-16.
**Source of decisions:** 6-panel expert synthesis (4 hats each, WebSearch mandatory) — see [`.planning/decisions/2026-05-16-calc-engine-v1-panel-synthesis.md`](../../decisions/2026-05-16-calc-engine-v1-panel-synthesis.md) for the 20 verdicts table + 11 overrides + 6 critical findings. 11 D-CE-XX overrode PM's recommendations. Founder-signed risk veto on Phase 96 chat-as-verb 2026-05-16 ([`phase-96-killed-2026-05-16.md`](../../decisions/2026-05-16-phase-96-killed.md)).
**Audit input:** W0 audit matrix [`W0-AUDIT-MATRIX.md`](W0-AUDIT-MATRIX.md) — hypothesis C confirmed at 49/57 = 86%, 12 severity-3 blockers identified.
**Source question set:** [`mint-calc-engine-v1-QUESTIONS.json`](mint-calc-engine-v1-QUESTIONS.json) (20 questions answered by panel synthesis, not by direct user input).

## TLDR

MINT has ~57 Swiss financial calculators already shipped across 11 domains. The phase does NOT add new calculators. It makes them (A) **discoverable** to the Sonnet 4.5 narrator via Anthropic Tool Search Tool wrapped in a vendor-agnostic `ToolRegistryAdapter`, (B) **profile-grounded** at every REST endpoint via a shared `_resolve_defaults` helper + `CoachToolIncomplete` handshake (closing the 86%-confirmed hypothesis C gap), (C) **architecturally findable** via a per-calculator registry + strangler-fig consolidation of `independants/` + `expat/`, (D) **DAG-reactive** via a read-side cache hash on `scenarios` (with the missing composite index Phase 95 forgot), pre-computed via a static reverse-dependency map, GC'd to bound table growth. The 4-level lucidité framework (L1 chiffrer / L2 comparer / L3 éclairer / L4 invariants) becomes typed Pydantic discriminated payloads — `recommended_option` literally does not exist at the type level for L2/L3, killing LSFin ranking creep structurally.

Shipped in 5 rolling waves (W0 → W4) over an estimated ~3-4 weeks critical path. Wave 1c-A3 ships **in parallel NOW** via Parallel Change pattern — A3 stops a daily user-visible empty-message regression and migration cost ≤200 LOC if W1 demands envelope evolution.

## Counter-arguments and data gaps

**Counter-argument 1 :** « 20 D-CE-XX decisions + 5 waves + 9 bundles + 3 adapters + L1-L4 typed payloads — this is a v3 architecture for a v1 phase. Cut to W0+W1 only. »
- Rebuttal : the W0 audit found 12 sev-3 endpoints SHIPPING WRONG TAX BRACKETS to ~15-30% of users by canton TODAY (Genevois → VD brackets, frontalier → null-canton crashes). These are incident-level, not improvement-level. W1 is non-negotiable. W2-W4 are the only path to make the calc surface usable by the Sonnet narrator without context bloat. Cutting to W0+W1 leaves the 52 long-tail calculators invisible to the coach indefinitely.

**Counter-argument 2 :** « Anthropic Tool Search Tool `tool-search-tool-2025-10-19` is beta — vendor lock-in + Anthropic-deprecation risk on a financial-app critical path. »
- Rebuttal : D-CE-01 was refined by Julien 2026-05-16 specifically on this concern. Three adapter implementations from day 1 (`AnthropicDeferLoadingAdapter` default + `SkillBundleOnlyAdapter` fallback + `ManualSubsetAdapter` backup) selected by env-flag. Calculator definitions stay provider-agnostic. Beta header has been stable since Oct 2025 (~7 months). Adapter cost ~50 LOC + 1 interface.

**Counter-argument 3 :** « Ship A3 NOW + Parallel Change creates rebase debt if W1 envelope changes. »
- Rebuttal : Panel proof — migration cost ≤200 LOC ≤1 dev day via Fowler Parallel Change pattern. Cost of holding A3 = compounding trust-collapse on empty-message regression hitting users daily.

**Counter-argument 4 :** « Typed L1-L4 discriminated payloads are over-engineering — a doctrine table in ROADMAP.md plus a banned-terms lint achieves the same goal at 10× lower cost. »
- Rebuttal : Phase 96's PAUSE happened because « doctrine says X but code allows Y ». Schema-impossibility (the field `recommended_option` does not exist on `L2ComparePayload`) is structural enforcement that survives prompt-engineer churn, narrator hot-fixes, and unrelated refactors. Doctrine + lint is lexical; types are structural. The two are NOT substitutes (D-CE-15 + D-CE-16 panel verdict = both).

**Counter-argument 5 :** « 9 bundles is regression from 7 currently shipped — DELETE bundles, register all 57 with Tool Search Tool directly. »
- Rebuttal : Tool registration ≠ prompt-fragment composition. Tool Search handles discovery; `bundle_compiler.py` handles per-intent narrator prompt scaffolding (citation grammar pointers, banned-verb reminders, scope-of-action context). Different axes, both needed (Override #1 panel finding).

**Data gaps :**
- Did NOT verify Anthropic `tool-search-tool-2025-10-19` works with Sonnet 4.5 at MINT's scale (~100 DAU). Mitigation : W2 ships pilot on staging + p95 latency baseline + feature flag rollback path.
- Did NOT measure baseline calc latency p95 for the 5 chip-emitters. Q-12 SLO targets (60 → 80% cache hit rate) are panel-extrapolated. Mitigation : W3 ships pytest-benchmark + Grafana panel before locking SLO.
- Did NOT audit `bundle_compiler.py:_INTENT_BUNDLES` mapping for current correctness. Mitigation : W2 task includes a single-iteration audit pass.
- Did NOT verify the 12 severity-3 endpoints are ALL still in production today vs. some being deprecated / unrouted. Mitigation : W1 first task is spot-check `app/api/v1/routes.py` registration before opening the grounding-fix PR.
- Coach-side 5 chip-emitters scored 5/5 grounded in W0 audit — but the audit did NOT cross-walk each tool's `input_schema` vs `_PROFILE_SAFE_FIELDS` at `coach_chat.py:875` to verify sufficient field coverage. Mitigation : W4 metrics wave adds a lint-test that walks the canonical safe-fields list.

<domain>
## Phase Boundary

**This phase delivers** the « MINT Lucidité Engine » on top of the 57 already-shipped Swiss financial calculators (per [`calc-engine-matrix-2026-05-16.md`](../../decisions/2026-05-16-calc-engine-matrix.md)). Four axes — A. LLM-discoverability, B. real-profile grounding, C. architecture findability, D. DAG action — each delivered as a sequential rolling wave (W0 audit / W1 grounding + registry + lucidity payloads / W2 discoverability + bundles + Tool Search Tool / W3 DAG cache + pre-compute + GC / W4 metrics + lints + verbs).

**Does NOT add new calculators in v1.** The 3 truly-absent items (quasi-résident frontalier status, bouclier fiscal GE/VD/VS, Sàrl-vs-RI + dividende-vs-salaire) are deferred to a future phase. The phase makes the EXISTING surface lucidité-grade and LLM-grade.

**Out of scope:**
- New calculators (3 truly absent items, ⚠️ partial completions — `arbitrage/location_vs_propriete.py` enrichment, etc.).
- Open Banking / bank-data ingestion that would pre-fill many profile fields automatically (future milestone; reduces W1 surface).
- Flutter screen redesigns. Flutter is UX-only per D-CE-06 — the ENFORCEMENT point is server-side. Re-mounting screens to consume `CoachToolIncomplete` 422 envelope is OK; redesigning navigation is NOT.
- New financial domains (e.g. crypto, alternative assets). Existing 11 domains.
- Phase 96 chat-as-verb destination doctrine — KILLED 2026-05-16, see [`phase-96-killed-2026-05-16.md`](../../decisions/2026-05-16-phase-96-killed.md).
- Phase 92 fonts/tokens, Phase 93 CTA unification, Phase 91.5 mobile refactor — parallel tracks, not blockers for calc-engine-v1.
- Wave 1c-A3 (5 chip-emitters missing-fields handshake) — D-CE-19 ships A3 in parallel NOW via Parallel Change pattern, NOT folded into calc-engine-v1.
- Real-time event-bus / cascade DAG (Q-13 panel rejected (c) full event-bus as premature). Phase 1 = FastAPI BackgroundTasks only.
- Full 200-fixture parity coverage (Phase 92.5 deferred to backlog 999.4 — not a calc-engine-v1 prerequisite).

</domain>

<decisions>
## Implementation Decisions (LOCKED)

The 20 D-CE-XX decisions are grouped below by the 6 panel question sections : (1) discoverability / (2) profile-grounding / (3) architecture / (4) DAG / (5) lucidité metrics / (6) sequencing.

### Section 1 — LLM Tool Discoverability (Problem A)

#### D-CE-01. Tool registration = `ToolRegistryAdapter` abstraction with 3 concrete adapters (vendor-agnostic)

**From panel Q-01 (ai-engineer + backend-architect + architect-review + python-pro hats) + founder refinement 2026-05-16 (vendor lock-in mitigation).**

- Define `app/services/coach/tool_registry/adapter.py` Protocol :
  - `register_tools(turn_context) -> list[ToolDefinition]` — returns the Anthropic tools array for the current turn.
  - `latency_tier(tool_name) -> Literal["L1", "L2", "L3"]` — informs Flutter rendering surface.
- Three concrete adapters in `app/services/coach/tool_registry/` from day 1 :
  - **(A) `AnthropicDeferLoadingAdapter`** = DEFAULT. Uses `defer_loading: true` per-tool + Tool Search Tool (beta header `tool-search-tool-2025-10-19`). 5 chip-emitters stay `defer_loading: false` (always-on, sub-500ms L1 latency budget). 52 long-tail get `defer_loading: true`. Cache-preserving per Anthropic spec.
  - **(B) `SkillBundleOnlyAdapter`** = FALLBACK if Anthropic deprecates the beta or MINT pivots provider. Registers all 57 via `bundle_compiler.py` compiled prompts (accepts context-bloat cost — Liu 2024 lost-in-the-middle risk acknowledged + documented).
  - **(C) `ManualSubsetAdapter`** = BACKUP. Extends Wave 1c-A2's `_TOOL_ELIGIBLE_TOOL_NAMES` pattern to per-intent tool-array filter. Cheapest, least flexible.
- Adapter selection via env-driven `TOOL_REGISTRY_ADAPTER` flag (default `anthropic_defer_loading`).
- Calculator tool definitions stay provider-agnostic (Pydantic v2 + French description rubric + L1-L4 lucidity payload contracts).
- `bundle_compiler.py` retained orthogonally for prompt-fragment composition under ALL 3 adapters (different axis — prompt scaffolding, not tool registration).
- Pattern alignment with CLAUDE.md §1 financial_core SoT doctrine : the CALCULATORS are SoT, the LLM provider is interchangeable plumbing.

**Rejected alternatives:**
- (a) homemade skill-bundle-only registration — context bloat + Liu 2024 lost-in-the-middle risk on 30K tokens of tool definitions per turn.
- (b) all 57 registered always-on — same context-bloat issue.
- (c) intent classifier → tool subset at runtime via additional LLM call — +1 latency + +1 cost per turn; Sonnet 4.5 picks up tool descriptions better than an intermediate classifier.

**Source:** panel synthesis Q-01 + founder refinement (engram obs #103).

#### D-CE-02. User-intent → bundle routing reuses `_classify_user_intent`

- Reuse existing `_classify_user_intent` at `services/backend/app/api/v1/endpoints/coach_chat.py:944-963` + `_INTENT_KEYWORDS:1500-1565` (6 canonical intents : `retirement`, `taxes`, `debt`, `housing`, `family`, `career`).
- Wave 1c-A2's `_TOOL_ELIGIBLE_INTENTS:1564-1573` heritage preserved.
- **Evidence-driven keyword expansion only** — no new ML classifier, no LLM call for intent classification. Keyword additions justified by `_INTENT_KEYWORDS` audit in W2 task.

**Rejected:** (c) Sonnet/Haiku classification call (cost/latency unfavorable), (d) bulk regex expansion to 200+ keywords (fragile, French-regional gaps).

**Source:** panel synthesis Q-02 (confirmed PM).

#### D-CE-03. 9 bundles at v1 = 7 currently shipped + 2 new gap-fills

**From panel Q-03 (OVERRIDE — PM's « 6 bundles » was REGRESSION vs current state).**

- **CRITICAL discovery (Override #2)**: `services/backend/app/services/coach/bundle_compiler.py` is ALREADY SHIPPED with 7 bundles at `bundles/` sub-directory : `compliance_narrator`, `life_event_router`, `lpp_projector`, `mortgage_stressor`, `pillar3a_optimizer`, `tax_explainer`, `citation_grammar`. `_INTENT_BUNDLES` mapping at `bundle_compiler.py:45-52`.
- v1 adds 2 evidence-gap bundles to reach 9 total :
  - `IndependentTaxBundle` — covers matrix domain 8 (2❌ absent items: Sàrl-vs-RI + dividende-vs-salaire). Even without the calculators, the bundle scaffolds the narrator's coaching register for indépendant users.
  - `SuccessionDivorceBundle` — domains 6+7 are ✅ shipped at calc layer (`divorce_simulator.py`, `succession_simulator.py`) but have NO prompt scaffolding. Bundle adds CC art. 122-124 / LAVS art. 29sexies / CC art. 467-469 citation grammar.
- Each bundle declares : (a) tool allowlist (subset of 57 calc tool names), (b) citation grammar pointers (per Phase 94), (c) banned-verb reminders, (d) scope-of-action context.

**Source:** panel synthesis Q-03 + Finding 1 (bundle_compiler.py already shipped).

#### D-CE-04. A3 = pattern; calc-engine-v1 inherits `CoachToolResponse` envelope

- Wave 1c-A3's `CoachToolResponse` RootModel envelope (Pydantic v2 discriminated union on `status: Literal["ok", "incomplete", "policy_blocked"]`) is the canonical contract for ALL defer-loaded tools registered by W2.
- A3 ships now (D-CE-19); W1+W2 build on A3's envelope.
- The 52 long-tail calculators inherit A3's `CoachToolIncomplete` semantics via the `_resolve_defaults` + `CoachToolIncomplete` handshake at REST endpoints (D-CE-06+07+08).
- Engram obs #89 (Wave 1c-A3 envelope decision) is the predecessor ; calc-engine-v1 findings `prior_finding_refs` MUST cite it.

**Rejected:** (b) divergent contract — doctrine fragmentation risk, (c) re-write A3 = ~30h wasted work, (d) hybrid contract — over-complex.

**Source:** panel synthesis Q-04 (confirmed PM).

### Section 2 — Real-Profile Grounding (Problem B — hypothesis C audit)

#### D-CE-05. Audit hypothesis C = 1.5-day hybrid scan, falsifiable at n=15

- **STATUS: COMPLETED 2026-05-16.** See [`W0-AUDIT-MATRIX.md`](W0-AUDIT-MATRIX.md). Result : 49/57 calculators confirmed (86%), 12 sev-3, 23 sev-2, 18 sev-1, 4 sev-0.
- Methodology : 5 chip-emitters audit (deterministic, 4 hours) + 10 high-value sample (statistical, 1 day) = 1.5 days total. Falsifiable rule : ≥13/15 confirm → broadly true → enforce server-side fix on ALL endpoints (D-CE-06). 8-12/15 → escalate to full 57 audit. ≤7/15 → endpoint-specific bug, fix surgically.
- Falsifiability gate triggered at ≥13/15 confirm → server-side fix on ALL endpoints LOCKED for W1.
- Severity 0-3 per audit hit ; per-row data captured in W0 matrix.

**Source:** panel synthesis Q-05 (refined hybrid).

#### D-CE-06. Profile pre-fill enforcement = defense-in-depth, PRIMARY at REST endpoints

**From panel Q-06 (confirmed PM).**

- **PRIMARY (a)**: server-side at every REST endpoint via `Depends(get_profile_filled)` FastAPI dependency.
- **Mirror (b)**: coach-tool dispatcher (`coach_chat.py` `_dispatch_tool`) applies the same `_resolve_defaults` helper before invoking any tool.
- **(c) Flutter is UX-only, NOT enforcement** : Flutter `ProfileProvider` pulls profile data and pre-fills UI fields, but server cannot trust the body — it must re-read profile and merge. Flutter changes are layout-level, never enforcement-level.
- **Triple defense (d)**: all three layers active. Flutter pre-fills → REST endpoint resolves → coach dispatcher resolves. Each is a fail-closed gate.

**Why server is PRIMARY:** Flutter values can be stale, omitted, or overridden. Coach can hallucinate body content. Only the server controls the `_user.profile` source of truth and the `_resolve_defaults` merge.

**Source:** panel synthesis Q-06 (4/4 hat unanimity).

#### D-CE-07. Schema marker = `{from_profile: "field"}` in `json_schema_extra` + shared `_resolve_defaults` helper

**From panel Q-07 (OVERRIDE — REJECT ContextVar+default_factory).**

- Pattern per field in every Pydantic request schema :
  ```python
  canton: Optional[str] = Field(default=None, json_schema_extra={"from_profile": "canton"})
  ```
- Shared helper `services/backend/app/core/profile_resolver.py:_resolve_defaults(profile, body, schema_class)`. ~15 LOC. Returns the merged dict (body values WIN over profile; profile fills missing).
- Type-safe + explicit + testable in isolation (no FastAPI TestClient needed for unit tests).
- **REJECT (a) ContextVar + default_factory** : documented FastAPI ContextVar pitfalls (issues #4690, #4696, discussions #8628 + #13120). ContextVar set in middleware can leak across requests in shared `asyncio.Task` paths; BackgroundTasks lose context after middleware reset. For a finance app where wrong canton silently produces wrong tax calc, magic-of-invisible-ambient-context is the OPPOSITE of what we want.

**Source:** panel synthesis Q-07 (4/4 unanimity on REJECT ContextVar; engram obs #103).

#### D-CE-08. Missing required profile field → `CoachToolIncomplete` + handshake (REST → 422)

- Generalize Wave 1c-A3 pattern. REST endpoints raise the structured `CoachToolIncomplete` payload via HTTP 422 + same envelope as A3 (`status: incomplete`, `missing_fields: list[str]`, `hint_fr: str`).
- Shared helper `services/backend/app/core/profile_resolver.py:raise_incomplete_as_422(incomplete: CoachToolIncomplete) -> NoReturn` (raises `HTTPException(status_code=422, detail=incomplete.model_dump())`).
- Coach tool dispatcher emits the SAME envelope (already wired in A3).
- Feature flag `profile_grounding_strict_mode` for graceful Flutter rollout — when `false`, endpoints log-warn + fall back to current behavior; when `true`, hard-fail with 422.
- Rollout sequence : staging strict=true → production strict=false (1 release) → production strict=true.

**Source:** panel synthesis Q-08 (3/4 hat unanimity, 1 dissent on feature-flag complexity).

### Section 3 — Architecture Consolidation (Problem C — éparpillée)

#### D-CE-09. File structure = Phase A registry index (no physical move) + Phase B optional consolidation later

**From panel Q-09 (Hybrid c — Strangler fig pattern).**

- **Phase A (this phase, W2):** Add `services/backend/app/calculators/_registry.py` — auto-generated index from a filesystem AST scanner. **NO PHYSICAL MOVE** of existing files. The scanner walks `services/backend/app/services/` and emits per-calculator metadata (D-CE-11).
- **Phase B (deferred, post-v1):** Optional physical consolidation to `services/backend/app/calculators/<domain>/<calc>.py` — done lazily, file-by-file, as each domain gets touched for new work. Strangler fig (Fowler).
- Single import path : `from app.calculators._registry import get_calculator` masks the underlying physical location.
- New calculators (post-v1) MUST land in the canonical `calculators/<domain>/` layout.

**Source:** panel synthesis Q-09.

#### D-CE-10. Duplicates `independant_service.py` + `frontalier_service.py` → migrate + deprecate

- Keep `independants/` (sub-directory) canonical. Root `independant_service.py` becomes a 1-line `from app.services.independants import *` shim for 1 release, then removed in W2 cleanup commit.
- Same for `frontalier_service.py` (root) vs `expat/frontalier_service.py`. Keep `expat/frontalier_service.py` canonical.
- Deprecation banner via `warnings.warn(DeprecationWarning(...))` at shim import.
- All callers grep'd + migrated to canonical path in same W2 PR as the shim.

**Source:** panel synthesis Q-10.

#### D-CE-11. Registry granularity = per-calculator metadata

- Each calc registry entry (auto-generated from filesystem scan) carries :
  - `name: str` — canonical calculator id (e.g. `lpp_rachat_echelonne`, `allocation_annuelle`).
  - `file: str` — relative path `services/backend/app/services/lpp_deep/rachat_echelonne_service.py`.
  - `profile_fields_needed: list[str]` — canonical field names from `_PROFILE_SAFE_FIELDS` (e.g. `["age", "canton", "lpp_balance"]`).
  - `life_events_served: list[str]` — subset of MINT 18 life events (e.g. `["retirement", "buyback"]`).
  - `output_type: Literal["L1", "L2", "L3", "L4"]` — lucidité level produced (per D-CE-15 typed payloads).
- ~57 entries. Generated via AST scanner at build time. CI gate fails on stale registry.
- The registry is ALSO the source for D-CE-14 reverse-dependency map (« kills two birds » per Override #5).

**Source:** panel synthesis Q-11.

### Section 4 — DAG Action on Profile Mutation (Problem D)

#### D-CE-12. Cache hash read-side = Phase 1 BLOCKING, 5 days, with composite index migration

**From panel Q-12 (confirmed PM; Finding 3 — missing composite index is critical gap Phase 95 left).**

- Phase 1 read-side cache hash on `scenarios` table : `(profile_id, kind, inputs_hash, created_at DESC) WHERE superseded_by IS NULL`. Cache lookup query is sub-50ms.
- **Composite index migration MANDATORY in same PR**:
  ```sql
  CREATE INDEX CONCURRENTLY idx_scenarios_cache_lookup
    ON scenarios (profile_id, kind, inputs_hash, created_at DESC)
    WHERE superseded_by IS NULL;
  ```
  Without it, the cache-lookup query is a seq-scan and MAKES performance WORSE for power users. Critical gap Phase 95 left.
- Phase 1 scope :
  - ✅ Read-path cache lookup (matching `inputs_hash`).
  - ✅ Write-path stamp (`inputs_hash` + `superseded_by` on write).
  - ❌ NO GC (deferred to W3).
  - ❌ NO eviction (deferred to W3).
  - ❌ NO warming / pre-compute (deferred to W3 via D-CE-13).
- Singleflight in-process lock (`asyncio.Lock` dict keyed by `(profile_id, kind, inputs_hash)`) to prevent cache stampede on cold-start. 20 LOC. Ship in W3 PR.

**Source:** panel synthesis Q-12 + Finding 3 (composite index gap).

#### D-CE-13. Post-commit pre-compute (vague B) = parallel with discoverability AFTER 1 week of vague A obs

**From panel Q-13 (OVERRIDE — PM's gating on grounding-green was over-conservative).**

- Vague B (post-commit pre-compute of « top 3 likely-needed » calcs) ships **in parallel** with discoverability (W2), AFTER 1 week of vague A telemetry.
- Use FastAPI `BackgroundTasks` (per backend-architect panel infra justification — NOT Celery, NOT arq; current MINT backend has no task queue, BackgroundTasks suffices for v1 scale).
- Trigger : `save_fact` / `save_insight` LLM tool call → BackgroundTask scheduled with top-3 calcs from D-CE-14 reverse-dep map.
- Vague B's `mint_calc_invoke_total{kind, profile_grounded=true|false}` instrumentation BECOMES the audit C data source for ongoing validation (replaces a separate audit sprint).

**Source:** panel synthesis Q-13 (override; engram obs #102).

#### D-CE-14. Pre-compute selection = top-3 via static reverse-dependency map

**From panel Q-14 (OVERRIDE — reverse-dep map NOT ML, NOT uniform top-N, NOT life-event-driven).**

- Static `{fact_key → {kind_a, kind_b, ...}}` reverse-dependency map. Hand-written initially (~80 entries), generated semi-automatically from AST scanner over `services/backend/app/services/`.
- Example : `save_fact(key="commune", value="Lausanne")` invalidates only ~12 of 57 calcs (wealth_tax, allocations_familiales, succession tax, LAMal franchise, ...). Warming `lpp_rachat` or `divorce_simulator` is pure waste — their `inputs_hash` is unchanged by `commune`.
- The dep-map **BECOMES** the calc registry from D-CE-11 (« kills two birds » — same data structure).
- SLI : `mint_calc_warm.precision ≥ 60%` (warmed calcs actually requested next), `mint_calc_warm.recall ≥ 70%` (next-turn requested calcs were pre-warmed).
- Rejected : ML scoring (premature), uniform top-N (waste), life-event heuristic (70% wasted CPU because most calcs don't depend on the field that just changed).

**Source:** panel synthesis Q-14 (override).

### Section 5 — Lucidité Framework & Metrics

#### D-CE-15. Lucidity framework = typed Pydantic discriminated payloads (ranking field FORBIDDEN by type)

**From panel Q-15 (OVERRIDE — typed contract per surface, NOT just doctrine table).**

- Define `app/models/lucidity/_payload.py` :
  - `LucidityLevel` StrEnum (`L1` chiffrer / `L2` comparer / `L3` éclairer / `L4` invariants).
  - `LucidityPayload = RootModel[Annotated[Union[L1ChiffrePayload, L2ComparePayload, L3EclairePayload, L4InvariantPayload], Field(discriminator="level")]]`.
- `L2ComparePayload` REJECTS `recommended_option` / `best_choice` / `top_pick` / `preferred` fields **at the schema level** — paraphrase cannot evade because the FIELD DOES NOT EXIST.
- Narrative-length-parity validator on `L2ComparePayload.scenarios`: all scenarios must be within ±15% character count of each other. A 200/50/50-word triple is de facto ranking (LSFin art. 8 risk) — schema-level validator raises before the payload leaves the calculator.
- `L4InvariantPayload` carries `legal_article_ref: str` (e.g. `"LCC art. 28 + OPP3 art. 2"`) and `condition_text_fr: str` (« quel que soit le scénario, plafond 33% LCC »).
- Schema-level enforcement is structural; D-CE-16 lint-level is lexical. Both shipped.

**Source:** panel synthesis Q-15 (override) + Finding 6 (L2→L3 ranking creep is highest LSFin risk).

#### D-CE-16. Banned-verbs enforcement = triple defense (schema + lint + runtime)

**From panel Q-16 (OVERRIDE — triple defense including schema-impossibility from Q-15).**

- Three layers active in parallel :
  - **(a) Schema-impossibility** — D-CE-15 typed payloads forbid `recommended_option` etc. fields.
  - **(b) Lint-time** — extend `tools/checks/banned_terms_python.py` with paraphrase verbs : « le choix le plus avisé », « le plus pertinent », « plus avantageux que », « nettement plus », « clairement supérieur », « à mon avis », « je pense que tu », « mon conseil serait », « tu devrais », « il faut », « recommandé ».
  - **(c) Runtime gate fail-closed** — narrator output post-citation-gate (Phase 94) runs through banned-verb regex on NFKC-normalized + zero-width-char-stripped text. Match → template fallback (sister to Phase 94 citation gate fallback).
- Lexical guardrails alone have 40-80% false-negative rates on paraphrase (Palo Alto Unit 42, arXiv 2504.11168). 100% evasion via character injection (arXiv 2512.01353). The schema layer is what closes the structural hole.

**Source:** panel synthesis Q-16 (refined triple defense).

#### D-CE-17. North-star metric = composite scorecard, Goodhart-mitigated

**From panel Q-17 (OVERRIDE — composite, NOT single quantified metric).**

- PRIMARY metric : `profile_grounded_calc_rate ≥ 95%` — share of calc invocations that read real `_user.profile` values vs hardcoded defaults.
- Counter-metrics :
  - `citation_chip_coverage ≥ 85%` per coach turn (every emitted number has a `{{cite:<key>}}` chip).
  - `zero_citation_hallucination_rate = 0` — hard floor.
  - `engagement_non_collapse_tripwire` — >20% MoM drop in turns/active-user pages oncall.
- Per-calc invocation logged with `inputs_provenance: dict[field, Literal["user_input", "default", "derived"]]` (schema-typed).
- Goodhart mitigation : paired shadow metrics + tripwire on engagement collapse.

**Note:** 95% target value is panel-extrapolated, NOT data-validated. PM hat reserved revision after first-month baseline. W4 ships baseline measurement; W5 (post-phase) may revise the threshold.

**Source:** panel synthesis Q-17 (composite refinement) + Finding 5 (L4 invariants are MINT's strongest LSFin moat).

### Section 6 — Sequencing & Execution

#### D-CE-18. Phase shape = single `mint-calc-engine-v1` with 4 sequential rolling-wave waves

**From panel Q-18 (confirmed PM).**

- **W0** : Audit (DONE 2026-05-16 — `W0-AUDIT-MATRIX.md`).
- **W1** : Grounding + registry + lucidity payloads. Ships the 12 sev-3 endpoint fixes FIRST (incident-level), then the 23 sev-2 + 18 sev-1 in batches. Adds `_registry.py` scaffolding (D-CE-11), `L1/L2/L3/L4Payload` Pydantic schemas (D-CE-15), `_resolve_defaults` + `get_profile_filled` shared helpers (D-CE-07).
- **W2** : Discoverability + bundles + Tool Search Tool. Ships `ToolRegistryAdapter` + 3 concrete adapters (D-CE-01), 2 new bundles `IndependentTaxBundle` + `SuccessionDivorceBundle` (D-CE-03), tool naming + description rubric (Concern A), `latency_tier` field on `CoachToolResponse` (Concern B), `independant_service.py`/`frontalier_service.py` deprecation (D-CE-10).
- **W3** : DAG cache + pre-compute + GC. Ships read-side cache hash (D-CE-12), composite index migration (Finding 3), reverse-dep map (D-CE-14), GC daily job (Finding 4 — bound `scenarios` row growth), singleflight asyncio.Lock (Concern E).
- **W4** : Metrics + lints + verbs. Ships composite scorecard instrumentation (D-CE-17), banned-verb lint extension (D-CE-16), Flutter↔server `_PROFILE_SAFE_FIELDS` parity lint (Concern C), `client_with_blank_profile()` pytest fixture pattern (Concern D).
- Rolling-wave : each wave's findings inform the next wave's plan (per-wave deepening at planning time per D-CE-20).
- Estimated critical path : ~3-4 weeks if waves run sequentially. Some W2/W3 work can overlap.

**Source:** panel synthesis Q-18.

#### D-CE-19. Wave 1c-A3 ship strategy = open PR NOW, Parallel Change pattern

**From panel Q-19 (OVERRIDE — ship A3 NOW; Parallel Change handles future evolution).**

- A3 plan locked at sha `2e1060a5`. 6/7 tasks executed 2026-05-16 (see HANDOFF addendum). Branch `feature/wave-1c-A3-missing-fields-handshake`.
- Open PR NOW (deferred from prior session). Pre-push 5-agent panel D-A3-10 runs before PR body finalisation.
- **Parallel Change pattern (Fowler) if W1 demands envelope evolution :**
  - W1 introduces `CoachToolResponseV2` alongside V1.
  - Migrate 5 chip-emitters from V1 → V2 in single PR.
  - Retire V1 in separate PR.
  - Migration cost budget : ≤200 LOC, ≤1 dev day.
- Cost of holding A3 = compounding trust-collapse on empty-message regression hitting users daily.

**Source:** panel synthesis Q-19 (override) + HANDOFF doc.

#### D-CE-20. W0 audit = Explore agent VERY THOROUGH 30-60 min + per-wave deepening

**From panel Q-20 (OVERRIDE — 30-60 min, NOT 2-3 day sprint).**

- W0 audit DONE 2026-05-16 (see `W0-AUDIT-MATRIX.md`). Result : 49/57 confirmed, 12 sev-3, 23 sev-2.
- Methodology : Explore agent, VERY THOROUGH, engram-cited findings (`topic_key: calc_engine:audit_hypothesis_c:<calc_slug>`), spot-validated 5-10 surfaces by hand.
- Per-wave deepening : at the start of each wave's planning (W1 plan, W2 plan, etc.), re-spot-check 5-10 surfaces for the wave's specific scope. Adds ~1 hour per wave-planning session.

**Source:** panel synthesis Q-20 (override).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Decisions (source-of-truth)
- [`.planning/decisions/2026-05-16-calc-engine-v1-panel-synthesis.md`](../../decisions/2026-05-16-calc-engine-v1-panel-synthesis.md) — **the 20 D-CE-XX verdicts table + 11 overrides + 6 critical findings. Single most important doc.**
- [`.planning/decisions/2026-05-16-calc-engine-matrix.md`](../../decisions/2026-05-16-calc-engine-matrix.md) — 11-category coverage matrix (57 ✅ / 4 ⚠️ / 3 ❌) + hypothesis C audit plan + 4-level lucidité framework.
- [`.planning/decisions/2026-05-16-phase-96-killed.md`](../../decisions/2026-05-16-phase-96-killed.md) — what was killed, what was preserved (Phases 91 / 93.5 / 94 / 95 survive).
- [`.planning/decisions/2026-05-14-phase-7-ship-or-pause.md`](../../decisions/2026-05-14-phase-7-ship-or-pause.md) — 2026-05-14 PAUSE that preceded the 2026-05-16 KILL. Option C « Coach didactique vivant » direction.

### Audit + sibling phases
- [`.planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md`](W0-AUDIT-MATRIX.md) — 57 calc rows, severity 0-3, 12 sev-3 blockers list, recommended fix priority order.
- [`.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-PLAN.md`](../wave-1c-coach-tool-dispatch-rca/wave-1c-A3-PLAN.md) — 7 tasks, 1848 lines. **CoachToolResponse envelope IS the v1 calc-engine tool-response contract** (D-CE-04).
- [`.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-CONTEXT.md`](../wave-1c-coach-tool-dispatch-rca/wave-1c-A3-CONTEXT.md) — A3 decision detail (`CoachToolResponse`, `MISSING_FIELDS_INSTRUCTION_FR`, server-side fallback floor).
- [`.planning/HANDOFF-2026-05-16-calc-engine-v1.md`](../../HANDOFF-2026-05-16-calc-engine-v1.md) — session handoff with engram obs IDs, A3 addendum (6/7 tasks executed).

### Codebase canonical (W1-W4 implementation MUST read)
- `services/backend/app/api/v1/endpoints/coach_chat.py` — narrator + dispatcher wire site. Lines 944-963 (`_classify_user_intent`), 1500-1565 (`_INTENT_KEYWORDS`), 1564-1573 (`_TOOL_ELIGIBLE_INTENTS`), 875 (`_PROFILE_SAFE_FIELDS`), 2740 (`profile.data` read for retirement projection).
- `services/backend/app/api/v1/endpoints/arbitrage.py:163-213` — the hypothesis C smoking gun (POST `/api/v1/arbitrage/allocation-annuelle` hardcoded defaults).
- `services/backend/app/services/coach/coach_tools.py:637-722` — the 5 chip-emitters (`get_budget_status`, `get_retirement_projection`, `get_cross_pillar_analysis`, `get_cap_status`, `get_couple_optimization`).
- `services/backend/app/services/coach/bundle_compiler.py:29-92` — the 7 currently-shipped bundles + `_INTENT_BUNDLES` mapping at lines 45-52. `bundles/` sub-directory has the 7 bundle files.
- `services/backend/app/models/coach_tools/_response.py` — Wave 1c-A3 `CoachToolResponse` envelope (Pydantic v2 RootModel discriminated union).
- `services/backend/app/services/coach/citation_grammar.py` — TOP/BOTTOM MANDATE block (Phase 94 citation gate + A3 pointer).
- `services/backend/app/services/coach/profile_extractor.py` — A3 added `_extract_avs_years` ; existing `_extract_lpp` at line 407 as pattern.
- `services/backend/app/services/{lpp_deep, fiscal, family, arbitrage, mortgage, expat, independants, retirement, unemployment, debt_prevention, divorce_simulator.py, succession_simulator.py, lamal_franchise_service.py}/` — the 57 calculators.
- `apps/mobile/lib/services/financial_core/` — Dart-side SoT (`avs_calculator.dart`, `lpp_calculator.dart`, `tax_calculator.dart`, `pillar_3a_calculator.dart`). CLAUDE.md §1 financial_core reuse rule.
- `apps/mobile/lib/services/coach/coach_context_builder.dart` — Flutter side of `_PROFILE_SAFE_FIELDS` parity check (Concern C).
- `apps/mobile/lib/services/feature_flags.dart:116` — `chatTabVisible = true` (post-Phase-96-kill). New flag : `profile_grounding_strict_mode` (D-CE-08).
- `tools/checks/banned_terms_python.py` — banned-verb lint (D-CE-16 extension target).
- `tools/checks/accent_lint_fr.py` — accent FR lint (CLAUDE.md rule 2).
- `lefthook.yml` — pre-commit gates wiring.

### Standards + doctrine
- `CLAUDE.md` §1 (financial_core SoT, LSFin banned terms, accent FR, MINT ≠ retirement-first), §3.5 (team agents), §8 (wiki-lint), §9 (0-TRUST).
- `docs/AGENTS/swiss-brain.md` — LSFin banned terms full list + lucidité grammar.
- `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-CONTEXT.md` — parent Wave 1c rationale.
- `.planning/MILESTONE-CHAT-AS-VERB-2026-05-09.archive.md` — superseded chat-as-verb doctrine (preserved as archive).

### External research
- Anthropic Tool Search Tool (beta header `tool-search-tool-2025-10-19`) — primary D-CE-01 primitive.
- Anthropic `defer_loading: true` flag docs.
- Anthropic Skills Guide PDF.
- Liu 2024 ACL Anthology « Lost in the Middle » (long-context attention drift).
- Martin Fowler « Parallel Change » pattern (D-CE-19 migration).
- Pydantic v2 discriminated union docs (D-CE-15, A3 envelope).
- FastAPI ContextVar discussions #4690 / #4696 / #8628 / #13120 (D-CE-07 REJECT rationale).
- Palo Alto Unit 42 + arXiv 2504.11168 + arXiv 2512.01353 (D-CE-16 lexical guardrail evasion rates).
- MLL News LSFin requirements + FINRA 2026 AI Governance + Splunk + Practical DevSecOps Goodhart law (D-CE-17 metric design).

</canonical_refs>

<code_context>
## Codebase touchpoints (verified file:line)

### W1 surface (grounding fix)
- 12 sev-3 endpoints — TOP priority per W0 audit:
  1. `services/backend/app/services/lpp_deep/rachat_echelonne_service.py:58-65` — canton-dependent tax brackets, no fallback.
  2. `services/backend/app/services/fiscal/wealth_tax_service.py` — null canton crashes.
  3. `services/backend/app/services/succession_simulator.py` — null canton crashes (CANTON_SUCCESSION_TAX lookup).
  4. `services/backend/app/services/family/concubinage_service.py` (succession variant) — null canton crashes.
  5. 8 others in `W0-AUDIT-MATRIX.md` Recommended Fix Priority Order.
- New shared utilities to create :
  - `services/backend/app/core/profile_resolver.py` — `get_profile_filled` FastAPI dependency, `_resolve_defaults(profile, body, schema_class)`, `_required_profile_fields_missing(resolved, schema_class)`, `raise_incomplete_as_422(incomplete)`.
- Schema marker pattern (apply to every existing request Pydantic schema in `services/backend/app/schemas/`) :
  ```python
  canton: Optional[str] = Field(default=None, json_schema_extra={"from_profile": "canton"})
  ```

### W1 lucidity payloads
- New file : `services/backend/app/models/lucidity/_payload.py` — `LucidityLevel` StrEnum + `L1ChiffrePayload` / `L2ComparePayload` / `L3EclairePayload` / `L4InvariantPayload` discriminated union.
- `L2ComparePayload.scenarios` narrative-length-parity validator (Pydantic v2 `@model_validator(mode="after")`).

### W2 surface (discoverability)
- New : `services/backend/app/services/coach/tool_registry/adapter.py` (Protocol).
- New : `services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py` (default).
- New : `services/backend/app/services/coach/tool_registry/skill_bundle_only_adapter.py` (fallback).
- New : `services/backend/app/services/coach/tool_registry/manual_subset_adapter.py` (backup).
- Existing : `services/backend/app/services/coach/bundle_compiler.py:29-92` + 7 bundles. Add 2 new bundles `independent_tax_bundle.py` + `succession_divorce_bundle.py` to `services/backend/app/services/coach/bundles/`.
- New : `services/backend/app/calculators/_registry.py` — AST-scanned per-calc metadata index.
- Tool description rewrite (W2 task) for all 57 calcs — French keyword discipline per Concern A. The 5 chip-emitters at `coach_tools.py:637-722` already have descriptions ; expand to include « divorce, séparation, CC art. 122-124 » style keyword vocabulary for discoverability.
- Deprecate-and-migrate : `services/backend/app/services/independant_service.py` (root) → `services/backend/app/services/independants/`. Same for `frontalier_service.py` (root) → `expat/frontalier_service.py`.

### W3 surface (DAG cache)
- Existing : `scenarios` table (Phase 95) with `inputs_hash` + `superseded_by` columns. Missing : composite index.
- New : `services/backend/app/db/migrations/<NNNN>_scenarios_cache_lookup_index.py` (Alembic).
- New : `services/backend/app/services/cache/cache_reader.py` + `cache_writer.py` (singleflight `asyncio.Lock` keyed by `(profile_id, kind, inputs_hash)`).
- New : `services/backend/app/services/cache/gc_job.py` — daily cron via APScheduler or external cron : `DELETE FROM scenarios WHERE superseded_by IS NOT NULL AND created_at < now() - interval '30 days'`.
- New : `services/backend/app/services/coach/pre_compute.py` — reverse-dep map + `BackgroundTasks` scheduling.

### W4 surface (metrics + lints)
- Extend `tools/checks/banned_terms_python.py` with paraphrase verbs (D-CE-16(b)).
- New : `tools/checks/profile_safe_fields_parity.py` — Flutter↔server `_PROFILE_SAFE_FIELDS` parity lint (Concern C).
- New : Prometheus counters via existing `services/backend/app/core/metrics.py` (or sister module) :
  - `mint_calc_invoke_total{kind, profile_grounded}` (D-CE-13 + audit data source).
  - `mint_calc_warm_total{kind, hit}` (D-CE-14 SLI precision/recall).
  - `mint_cache_lookup_total{kind, hit}` (D-CE-12).
  - `mint_zero_citation_total` (D-CE-17 counter-metric).
- New : `services/backend/tests/test_calc_engine_blank_profile.py` — Concern D pattern (`client_with_blank_profile()` fixture, 1 contract test per endpoint to assert 422 fires).

### Coach narrator wire site
- `services/backend/app/api/v1/endpoints/coach_chat.py:_run_narrator_with_gate` — Wave 1c-A3 already wires `tool_results` in return dict. W2 extends this with `latency_tier` field on every emitted `CoachToolResponse` (Concern B).

</code_context>

<specifics>
## Specific ideas (panel concerns to honor)

### Concern A — Tool naming + description discipline (W2 hard blocker)

- Anthropic Tool Search matches against `name` + `description`. MINT's current descriptions at `coach_tools.py:640-717` are English-only and terse.
- W2 mandates a **NAMING-AND-DESCRIPTION RUBRIC** drafted by prompt-engineer agent. Required:
  - French keyword discipline. For `divorce_simulator` to surface when user types « si je divorce demain », description must include « divorce, séparation, CC art. 122-124, splitting AVS, pension alimentaire ».
  - Round-trip test fixture : `test_tool_search_round_trip.py` simulates 30 representative French user messages and asserts the right tool is in the top-3 results for each.

### Concern B — `latency_tier` field on `CoachToolResponse`

- Tool Search adds 200-400 ms latency on rare-intent first turn. Must land in L2-L3 budget (2-8 s narrative loader), not in L1 (<500 ms).
- W2 extends Wave 1c-A3's `CoachToolResponse` envelope to add `latency_tier: Literal["L1", "L2", "L3"]` field.
- Flutter routes the response to the right rendering surface : chip (L1, sub-500ms) vs narrative loader (L2/L3, 2-8s).
- ADR-worthy decision land at start of W2 planning ; the envelope evolution may trigger D-CE-19 Parallel Change path (V1 → V2 of CoachToolResponse).

### Concern C — Flutter `ProfileProvider` vs server `_PROFILE_SAFE_FIELDS` parity

- Server canonical = `_PROFILE_SAFE_FIELDS` at `coach_chat.py:875`. Flutter must mirror exactly.
- W4 ships a lint test `tools/checks/profile_safe_fields_parity.py` that walks the server canonical list and asserts each name maps to a Dart field in `apps/mobile/lib/services/coach/coach_context_builder.dart`.

### Concern D — Test fixtures bypassing `_user.profile`

- Existing pytest fixtures likely construct request bodies with all fields explicit (« happy path »). These PASS the new 422 check (D-CE-08) even though they bypass profile-grounding.
- **Karpathy #4 reproduce-the-bug-first pattern** : W1 adds a `client_with_blank_profile()` pytest fixture in `services/backend/tests/conftest.py`. Use in 1 contract test per fixed endpoint to assert 422 fires when profile fields missing.

### Concern E — Cache stampede on cold-start

- When staging deploys, all caches cold for ~5 min. 10 simultaneous users requesting same calc → 10 PG roundtrips + 10 compute fan-outs.
- Mitigation : in-process singleflight (`asyncio.Lock` dict keyed by `(profile_id, kind, inputs_hash)`). 20 LOC. Ship with W3 vague A PR.

### Concern F — Engram memory discipline per wave

Every wave's findings MUST use :
- `topic_key: calc_engine:<wave>:<sub_area>:<specific>` (agent-agnostic).
- `prior_finding_refs: [...]` linking back to W0 audit matrix observations (#104-107) + A3's `CoachToolResponse` decision (#89) + panel synthesis (#103) + matrix correction (#102) + Phase 96 kill (#95).

**Hard rule** per wave : at least 1 finding per closed sub-task must link to a prior observation. Compounding observable per CLAUDE.md §3.5.

### 4-level lucidité framework (LOCKED — FINMA / LSFin compliant)

| Level | What MINT says | What MINT NEVER says | Surface | Pydantic payload |
|---|---|---|---|---|
| L1 — Chiffrer | « Ta rente AVS projetée à 65 ans est X CHF/mois » | « Cette rente est suffisante / faible / optimale » | Atomic calcs + cartes / simulateurs / widgets inline | `L1ChiffrePayload` |
| L2 — Comparer | « Voici les 3 scénarios chiffrés : A=X, B=Y, C=Z » | « Le scénario B est le meilleur » | Coach narration sur arbitrage | `L2ComparePayload` (NO `recommended_option` field — schema-forbidden) |
| L3 — Éclairer l'arbitrage caché | « Si tu choisis A, ça change ton 3a, ton impôt et ta dette dans 5 ans » | « Tu devrais faire A » | Coach + DAG cascade | `L3EclairePayload` (NO ranking field) |
| L4 — Surfacer les invariants | « Quel que soit le scénario, ta capacité d'emprunt est plafonnée à 33% LCC » | « Cette banque te dira oui / non » | Insights persistants (wiki / `CoachInsightRecord`) | `L4InvariantPayload` (legal_article_ref mandatory) |

Verbes autorisés : *« voici »*, *« si tu fais X, ça donne Y »*, *« 3 options chiffrées »*, *« arbitrage caché »*, *« compte tenu de tes données »*.
Verbes interdits (extend `tools/checks/banned_terms_python.py`) : *« optimal »*, *« meilleur »*, *« garanti »*, *« recommandé »*, *« tu devrais »*, *« certain »*, *« assuré »*, *« le plus pertinent »*, *« plus avantageux »*, *« nettement plus »*, *« clairement supérieur »*, *« mon conseil »*.

### Latency contract

- **Synchronous < 500 ms** : atomic chiffrage (L1) served from `inputs_hash` cache (D-CE-12 read-side).
- **Async with narrative loader 2-8 s** : combinatorial / multi-option arbitrage (L2-L3). The wait IS a feature : signals rigor (Cleo pattern).

### Finding 5 — L4 invariants ship FIRST in W1 (panel priority refinement)

- L4 (« quel que soit le scénario, plafond 33% LCC ») is pure information générale + legal article reference. **Lowest LSFin-risk surface + HIGHEST user-value surface (« the thing nobody tells you »)**.
- Doctrinally aligned with `docs/MINT_IDENTITY.md` (« Mint te dit ce que personne n'a intérêt à te dire »).
- W1 ships L4 invariant-surfacing FIRST, uses it as the wedge for L2/L3 which are higher-risk and need typed payload contract first.

### W0 audit highlights (for W1 task ordering)

Priority order per `W0-AUDIT-MATRIX.md` § Recommended Fix Priority Order :
1. **Priority 1 — BLOCKING for W1 first PR** : `allocation_annuelle`, `affordability_service`, `rachat_echelonne_service`.
2. **Priority 2 — W1 second PR** : `wealth_tax_service`, `succession_simulator`, `concubinage_service` (succession), `location_vs_propriete`.
3. **Priority 3 — W1 final PR** : all other sev-2 calculators (23 total) batched 5-6 per PR.

</specifics>

<deferred>
## Deferred Ideas (NOT in calc-engine-v1)

- **3 truly absent calculators** : quasi-résident frontalier status (>90% CH revenu, >120K brut), bouclier fiscal (plafond GE/VD/VS), Sàrl-vs-RI + dividende-vs-salaire indépendant. These are net-new calculator additions ; v1 explicitly does NOT add calcs. Future phase.
- **Phase 92 fonts/tokens, Phase 93 CTA unification, Phase 91.5 mobile refactor** — parallel tracks, separate worktrees, not blockers.
- **Phase 92.5 full 200-fixture parity coverage** — already deferred to backlog 999.4.
- **Real-time event-bus / cascade DAG** — Q-13 panel rejected (c) full event-bus as premature for v1. v1 uses FastAPI `BackgroundTasks` only.
- **Physical consolidation of services to `app/calculators/<domain>/<calc>.py`** — D-CE-09 Phase B, strangler fig, post-v1.
- **ML-based pre-compute selection** — D-CE-14 stays static reverse-dep map for v1. ML scoring premature.
- **Bouclier fiscal cantonal logic** — depends on canton-specific wealth tax cap policies (GE / VD / VS); future.
- **Open Banking ingestion to pre-fill profile fields** — would reduce W1 surface but out of scope.
- **Flutter screen redesigns** — Flutter is UX-only per D-CE-06.
- **Phase 96 chat-as-verb destination doctrine** — KILLED 2026-05-16.
- **Tab Coach removal / kill-tab** — KILLED 2026-05-16, tab stays.
- **`turns/user/week` north-star metric** — replaced by composite scorecard D-CE-17.
- **Narrator hot-fix to remove ranking language** — handled structurally by D-CE-15 typed payloads + D-CE-16 banned-verb lint, NOT by prompt patching.
- **Anthropic-only lock-in** — D-CE-01 ToolRegistryAdapter abstracts the vendor; calculator definitions stay provider-agnostic.

</deferred>

## Memory Contract (Concern F — hard rule)

Every wave's findings MUST conform to :

| Field | Pattern |
|---|---|
| `project` | `mint` (engram auto-detect from git_remote) |
| `topic_key` | `calc_engine:<wave>:<sub_area>:<specific>` agent-agnostic |
| `prior_finding_refs` | At least 1 ref linking to W0 audit (#104-107) OR A3 envelope (#89) OR panel synthesis (#103) OR matrix correction (#102) OR Phase 96 kill (#95) |
| `type` | `decision` / `discovery` / `bugfix` / `architecture` / `pattern` |

**Wave-close gate** : before each wave's PR opens, the wave's findings must include at least 1 `prior_finding_refs` per major sub-area. Compounding observable per CLAUDE.md §3.5.

## Sources

- 6 expert panels run 2026-05-16 in parallel (ai-engineer + backend-architect + architect-review + performance-engineer + business-analyst + product-manager leads, 4 internal hats each).
- W0 Explore agent audit 2026-05-16 (49/57 confirmed hypothesis C, 12 sev-3 blockers).
- Engram observations #89 (A3 envelope), #94 (A3 5-not-6 chip-emitters), #95 (Phase 96 KILL), #97 (arbitrage.py evidence), #98 (Anthropic Tool Search Tool discovery), #99 (calc-engine grounding panel), #102-107 (architecture + DAG + lucidity + sequencing panels + W0 per-calc findings), #103 (vendor-agnostic adapter refinement), #108 (Wave 1 scope locks ALL endpoints).
- WebSearch citations : Anthropic Tool Search Tool docs (`tool-search-tool-2025-10-19`), Anthropic Skills Guide PDF, Liu 2024 ACL Anthology, Pydantic v2 discriminated union docs, FastAPI ContextVar discussions #4690/4696/8628/13120, Martin Fowler Parallel Change, MLL News LSFin requirements, FINRA 2026 AI Governance, Palo Alto Unit 42 LLM guardrails, arXiv 2504.11168 + 2512.01353, Splunk + Practical DevSecOps Goodhart law.

---

*Phase: mint-calc-engine-v1*
*Context generated mechanically 2026-05-16 from 6-panel synthesis + W0 audit per founder-delegated direction. 11 panel overrides + 6 critical findings preserved verbatim — NOT to be re-litigated.*
