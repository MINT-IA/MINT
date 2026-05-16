---
description: Phase mint-calc-engine-v1 RESEARCH — HOW-to-implement deep-dive for the 20 D-CE-XX locked decisions. Maps every architectural lock from CONTEXT.md to concrete file/line patterns, library version pins, Pydantic v2 mechanics, Alembic CONCURRENTLY footguns, asyncio singleflight semantics, FastAPI BackgroundTasks lifecycle, AST-scanner skeleton for `_registry.py`, Prometheus naming, and per-wave validation architecture. The 20 decisions are LOCKED — this document gives the planner enough mechanical detail to write file-by-file task lists without re-research.
phase: mint-calc-engine-v1
researched: 2026-05-16
domain: backend (FastAPI / Pydantic v2 / SQLAlchemy 2 / Alembic / Anthropic SDK) + Flutter parity lint + Maestro G1
confidence: HIGH on stack mechanics + Pydantic v2 + Alembic CONCURRENTLY ; MEDIUM on Anthropic Tool Search at MINT scale (no production sample yet) ; LOW on profile-grounded baseline rate (no current measurement — see Open Questions)
---

# Phase mint-calc-engine-v1 — Research

**Researched:** 2026-05-16
**Domain:** Backend (FastAPI / Pydantic v2 / SQLAlchemy 2 / Alembic / Anthropic SDK) + Flutter parity + Maestro G1
**Confidence:** HIGH (stack mechanics) / MEDIUM (Anthropic Tool Search prod fit) / LOW (current profile-grounding baseline)

## TLDR

CONTEXT.md locks **20 D-CE-XX decisions** across 4 problem axes (discoverability / grounding / architecture / DAG) over 5 rolling waves W0→W4 (W0 DONE). This research answers « what's the exact code shape » for the locked decisions, NOT « what should we do ». Everything below cites either (a) a file:line in the MINT codebase already on `dev` or on the A3 branch, (b) verified Anthropic / Pydantic / Alembic / FastAPI documentation, or (c) the locked CONTEXT.md (NOT to be re-litigated).

**Primary recommendation:** open W1 as 3 atomic PRs (Priority 1 endpoints + `_resolve_defaults` helper / Priority 2 + `_registry.py` scaffolding / Priority 3 + lucidity payloads). All other waves depend on W1 PR-1 landing first because the helper is shared. Sub-200-LOC PRs per the Parallel Change posture inherited from D-CE-19.

Two anchor artefacts already exist on `feature/wave-1c-A3-missing-fields-handshake` (sha `dcb79cfd`) that **W1 must import verbatim, not re-write**:
- `services/backend/app/models/coach_tools/_response.py` — the `CoachToolResponse` RootModel discriminated union. Use it as-is for the REST 422 envelope (D-CE-08).
- `services/backend/app/services/coach/profile_extractor.py:_extract_avs_years` — extractor pattern with anchor-mandatory regex (mirror for new W1 extractors if needed).

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

The 20 D-CE-XX decisions from CONTEXT.md §`<decisions>` are LOCKED. Verbatim summary :

| ID | Decision | Locked because |
|---|---|---|
| D-CE-01 | `ToolRegistryAdapter` Protocol + 3 adapters (`AnthropicDeferLoadingAdapter` DEFAULT / `SkillBundleOnlyAdapter` FALLBACK / `ManualSubsetAdapter` BACKUP) selected via env-driven `TOOL_REGISTRY_ADAPTER` flag. Calculator defs stay provider-agnostic. | Vendor lock-in mitigation. CLAUDE.md §1 financial_core SoT. |
| D-CE-02 | Reuse `_classify_user_intent` + `_INTENT_KEYWORDS` at `coach_chat.py:1478-1522` + 1525-1544. Evidence-driven keyword adds only. No ML. | Karpathy #2 simplicity. |
| D-CE-03 | 9 bundles = 7 currently shipped + `IndependentTaxBundle` + `SuccessionDivorceBundle`. | Bundles already in `services/backend/app/services/coach/bundles/` ; cutting would be regression. |
| D-CE-04 | A3's `CoachToolResponse` envelope is canonical for ALL defer-loaded tools (REST + coach dispatcher). | Doctrine unity ; obs #89 prior_finding_refs. |
| D-CE-05 | W0 audit DONE 2026-05-16 (`W0-AUDIT-MATRIX.md`). 49/57 hypothesis C confirmed, 12 sev-3 blockers. | Already executed. |
| D-CE-06 | Profile pre-fill enforcement = defense-in-depth, PRIMARY = server REST (`Depends(get_profile_filled)`), mirror = coach dispatcher, Flutter = UX-only. | Server is the ONLY source of truth for `_user.profile`. |
| D-CE-07 | Schema marker `json_schema_extra={"from_profile": "canton"}` + shared `_resolve_defaults(profile, body, schema_class)` helper. REJECT ContextVar. | Type-safe + explicit + no FastAPI ContextVar leakage. |
| D-CE-08 | Missing required profile field → `CoachToolIncomplete` via HTTP 422 + same A3 envelope. Behind `profile_grounding_strict_mode` flag for Flutter rollout. | Doctrine unity with coach dispatcher. |
| D-CE-09 | Registry-now / consolidate-later (Strangler fig). NO physical move in v1. | Lazy migration ; cost-aware. |
| D-CE-10 | `independants/` canonical + root shim 1 release. Same for `frontalier_service.py`. | Mechanical cleanup ; preserves all callers. |
| D-CE-11 | Per-calc metadata (name / file / `profile_fields_needed` / `life_events_served` / `output_type`) ~57 entries. Auto-generated AST scan. | Same data structure as D-CE-14 (« kills two birds »). |
| D-CE-12 | Cache hash read-side BLOCKING. 5 days. INCLUDES composite index migration `idx_scenarios_cache_lookup (profile_id, kind, inputs_hash, created_at DESC) WHERE superseded_by IS NULL`. NO GC, NO eviction, NO warming in W3-PR1. | Phase 95 left this gap. |
| D-CE-13 | Vague B (post-commit pre-compute) parallel with discoverability AFTER 1 week vague A obs. FastAPI `BackgroundTasks` only. No Celery, no arq. | MINT has no task queue ; ~100 DAU scale ; BackgroundTasks fits. |
| D-CE-14 | Static reverse-dep map `{fact_key → {kind_a, kind_b, ...}}` ~80 entries. AST-generated from `services/backend/app/services/`. SLI : precision ≥ 60% / recall ≥ 70%. | ML / uniform top-N / life-event heuristic all wasteful. |
| D-CE-15 | `LucidityLevel` StrEnum + L1/L2/L3/L4 Pydantic v2 discriminated payloads. `recommended_option`/`best_choice`/`top_pick`/`preferred` FORBIDDEN at type level on L2/L3. Narrative-length-parity validator on `L2ComparePayload.scenarios`. | Schema-impossibility beats doctrine. |
| D-CE-16 | Triple defense banned verbs : schema (D-CE-15) + lint extension + runtime fail-closed (NFKC-normalize, strip zero-width chars). | Lexical guardrails alone have 40-80% false-negative rates. |
| D-CE-17 | Composite scorecard : `profile_grounded_calc_rate ≥ 95%` PRIMARY + counter-metrics. Goodhart-mitigated. | Single-metric collapses ; PM hat reserved revision after first-month baseline. |
| D-CE-18 | 5 sequential waves W0→W4. Rolling wave planning. | Critical path 3-4 weeks. |
| D-CE-19 | Wave 1c-A3 ships in parallel NOW via Fowler Parallel Change. Migration budget ≤200 LOC ≤1 day. | A3 fixes user-visible regression compounding daily. |
| D-CE-20 | W0 Explore-agent VERY THOROUGH 30-60 min + per-wave deepening (5-10 surfaces re-spot-checked at planning time). | DONE for W0 ; the planner of each wave MUST re-spot-check. |

### Claude's Discretion

CONTEXT.md does not enumerate Claude-discretion zones explicitly. The implicit discretion areas are :
- File names + internal organization within the locked module paths (`services/backend/app/services/coach/tool_registry/` / `services/backend/app/calculators/_registry.py` / etc.).
- Order of W1 sub-PRs as long as `_resolve_defaults` ships in PR-1 (helper-then-callers ordering required).
- Specific test file names, as long as they follow the FLAT `tests/test_*.py` convention (Wave 1c-A3 set the precedent — see CONTEXT.md §code_context W4 surface).
- Specific Prometheus metric name suffixes (e.g. `_total` vs `_count`) as long as the label cardinality stays low.
- Whether to ship banned-verb runtime gate as a Phase 94 sister at `_run_narrator_with_gate` or a separate post-citation-gate filter (engineering choice).
- W2 tool description rewrite copy (must contain the FR keyword discipline mandated by Concern A ; specific wording is Claude's).

### Deferred Ideas (OUT OF SCOPE)

Verbatim from CONTEXT.md §`<deferred>`. Planner MUST refuse any task that re-introduces these :
- 3 truly absent calculators (quasi-résident frontalier / bouclier fiscal GE-VD-VS / Sàrl-vs-RI + dividende-vs-salaire).
- Physical consolidation to `app/calculators/<domain>/<calc>.py` (D-CE-09 Phase B, post-v1).
- ML-based pre-compute selection (D-CE-14 stays static v1).
- Real-time event-bus / cascade DAG (Q-13 rejected for v1).
- Open Banking pre-fill.
- Flutter screen redesigns (Flutter UX-only per D-CE-06).
- Phase 96 chat-as-verb destination doctrine (KILLED 2026-05-16).
- Tab Coach removal.
- `turns/user/week` north-star metric (replaced by D-CE-17 composite).
- Narrator hot-fix prompt patching for banned verbs (replaced by D-CE-15 schema + D-CE-16 triple defense).
- Anthropic-only lock-in (D-CE-01 adapter abstracts).
- New financial domains (crypto, alternative assets…).
- Phase 92.5 full 200-fixture parity coverage (deferred to backlog 999.4).
- Wave 1c-A3 envelope re-write (preserved verbatim from A3 branch).

</user_constraints>

<phase_requirements>
## Phase Requirements

REQUIREMENTS.md does NOT exist for this phase. Per the orchestrator brief, the **20 D-CE-XX in CONTEXT.md ARE the requirements**. The 12 sev-3 blockers from `W0-AUDIT-MATRIX.md` Recommended Fix Priority Order map directly to W1 task IDs.

| ID | Description | Research support |
|---|---|---|
| D-CE-01 | ToolRegistryAdapter Protocol + 3 adapters | §Q-A Anthropic Tool Search + adapter skeleton |
| D-CE-06 | Server-side enforcement at REST endpoints | §Q-B `_resolve_defaults` mechanics + FastAPI Depends |
| D-CE-07 | `json_schema_extra={"from_profile": "field"}` + helper | §Q-B Pydantic v2 model_fields runtime extraction |
| D-CE-08 | `CoachToolIncomplete` 422 envelope | §Q-B existing `_response.py` import |
| D-CE-11 | Per-calculator registry index from AST scan | §Q-G AST scanner skeleton |
| D-CE-12 | Composite index `(profile_id, kind, inputs_hash, created_at DESC)` via Alembic CONCURRENTLY | §Q-D autocommit_block pattern |
| D-CE-13 | FastAPI BackgroundTasks for pre-compute | §Q-E lifecycle + cancellation semantics |
| D-CE-14 | Reverse-dep map = D-CE-11 registry | §Q-G dep-map generation from AST |
| D-CE-15 | L1/L2/L3/L4 typed payloads | §Q-C discriminated union exact syntax |
| D-CE-16 | Triple defense banned verbs | §Q-C ConfigDict(extra="forbid") + NFKC |
| D-CE-17 | Composite scorecard | §Q-H Prometheus naming + label cardinality |
| W1 12 sev-3 priorities | grounded endpoints (Priority 1/2/3 from W0) | §Q-B endpoint pattern + §Q-I validation pytest |
| W2 9 bundles + 3 adapters | bundle_compiler extension | §Q-F filesystem auto-discovery |
| W3 cache + GC + singleflight | scenarios cache layer | §Q-D + §Q-E |
| W4 metrics + lints + parity | Prometheus counters + parity lint | §Q-H + Concern C |

</phase_requirements>

## Project Constraints (from CLAUDE.md)

The planner MUST verify task plans against these directives. Violations BLOCK the phase exit.

| # | Directive | Where it applies in this phase |
|---|---|---|
| 1 | LSFin banned terms NEVER in user-facing text : « garanti / optimal / meilleur / certain / assuré / sans risque / parfait » → use « pourrait / envisager / adapté ». Lint = `tools/checks/banned_terms_python.py`. | W2 tool description copy (FR keyword rubric) ; W4 banned-verb lint extension (D-CE-16) ; L2-L3 payload field validators (D-CE-15 schema impossibility). |
| 2 | Accents 100% FR mandatory. `creer → créer`, `eclairage → éclairage`. Lint = `tools/checks/accent_lint_fr.py`. | Every new prose string this phase ships : `hint_fr`, `disclaimer`, bundle prompts. |
| 3 | MINT ≠ retirement app. 18 life events equally weighted. | W2 bundle naming / description rubric MUST NOT skew « retraite-first ». Tool description for `get_retirement_projection` already exists ; new bundle copy for divorce / succession / independant gets equal weight. |
| 4 | financial_core/ reuse mandatory. NEVER re-implement `_calculate*` in services. ADR `decisions/ADR-20260223-unified-financial-engine.md`. | W1 grounding fix: wrap existing `_compute_*` helpers in `_resolve_defaults` — DO NOT re-implement. W1 12 sev-3 fixes touch ONLY the endpoint args resolution, NOT the service compute math. |
| 5 | i18n required. `AppLocalizations.of(context)!.key`. 6 ARB files (fr/en/de/es/it/pt). | This phase is backend-heavy and Flutter UX-only (D-CE-06). No new ARB keys EXPECTED (Concern C parity lint reads existing keys only). If W4 surfaces a Flutter copy change for `CoachToolIncomplete` UX, ARB parity gate applies. |
| 6 | 0-TRUST. Banned without deterministic citation : « shipped / closed / ready / works / validated / green / PROVISIONALLY READY ». PR opened ≠ shipped. | Each wave PR body uses « PR opened / pytest exit 0 / lints exit 0 » only. G1 Maestro + G3 dev CI + G4 regression + G5 LSFin+accent+ARB gates apply per the 5-gate exit contract. |
| 7 | Karpathy #1-4 : think before code / simplicity / surgical / goal-driven verify. | Each W1 fix is a `_resolve_defaults` insertion + 1 pytest, no adjacent refactors. The 9-bundle / 3-adapter / typed-payload code MUST be only what CONTEXT.md locks. |
| 8 | Wiki schema : counter-arguments mandatory on `.planning/decisions/*.md` ; TLDR mandatory on `.planning/**/*.md`. | All new ADRs this phase produces (e.g. W2 `latency_tier` Concern B ADR) MUST have counter-arguments + data gaps section. |
| 9 | 0-TRUST §9.5 : 4-stage shipping pipeline. PR opened = stage 1/4. Post-merge sim verification = « works ». | Each wave's SUMMARY.md / VERIFICATION-REPORT.html runs the 5-gate ladder at stage 3-4. |

## Counter-arguments and data gaps

**Counter-argument 1 :** « `_resolve_defaults` is a 15-LOC helper — researching it for 100 lines is over-engineering theatre. »
- Rebuttal : the helper is 15 LOC ; what fails is the 12 sev-3 endpoint integrations + the contract tests + the `model_fields_set` vs `None` subtlety (verified in §Q-B). Without this section the planner ships endpoints that pass the 422 check on happy-path test fixtures but bypass profile grounding in real traffic (Concern D). The Wave 1c-A3 dispatcher integration cost 9 commits — the REST surface has 11+ endpoint files to patch, similar care needed.

**Counter-argument 2 :** « Anthropic Tool Search Tool documentation cited here may be stale by the time W2 ships. »
- Rebuttal : the beta header `tool-search-tool-2025-10-19` has been stable ~7 months. D-CE-01's adapter abstraction is the mitigation. The research notes the SDK shape verified 2026-05-16 and pins the exact `extra_headers` + `defer_loading: True` + `tool_search_tool_bm25_20251119` patterns. If Anthropic ships v2026-11, only `AnthropicDeferLoadingAdapter` needs touch ; other adapters absorb the rollback.

**Counter-argument 3 :** « D-CE-14 reverse-dep map is hand-written ~80 entries — an AST scanner is over-spec for that size. »
- Rebuttal : D-CE-11 mandates the **same data structure** (« kills two birds »). The AST scanner is required for D-CE-11's ~57 entries with profile-field discovery. The reverse-dep map's 80 entries are a side-output of the same scan. Hand-writing the registry once = drift bait.

**Counter-argument 4 :** « FastAPI BackgroundTasks lose state on shutdown — D-CE-13 picks the wrong primitive. »
- Rebuttal : D-CE-13 is BLOCKING locked. Pre-compute is best-effort warming, NOT durable work. Loss on shutdown = next-turn cache miss = acceptable degradation. Durability would force Celery/arq which CONTEXT.md explicitly forbids. See §Q-E for the explicit acceptance.

**Counter-argument 5 :** « D-CE-15 typed payloads (L1/L2/L3/L4) force migration cost on the 5 chip-emitters' current return types. »
- Rebuttal : the 5 chip-emitters already wrap their data in `CoachToolOk.data: dict[str, Any]` (A3 envelope). The L1-L4 layer goes INSIDE `data` (as `data["lucidity"]: L1ChiffrePayload`-shaped). Existing test fixtures stay valid because they assert on `data["x"]` keys, NOT on lucidity-payload shape. Migration is W1-final additive, not breaking.

**Data gaps :**
- No baseline measurement of `profile_grounded_calc_rate` exists today. The 95% target (D-CE-17) is panel-extrapolated. W4 MUST ship the counter FIRST, then measure 1 month, then revise the threshold per PM-hat reservation in CONTEXT.md §D-CE-17.
- No latency benchmark exists for the 11 REST endpoints (W0 audit gap §Counter-argument 3 there). W1 PR-1 SHOULD ship a `pytest-benchmark` baseline for the 3 Priority-1 endpoints so W3's 50ms cache-lookup SLO has a comparison.
- Anthropic Tool Search Tool at MINT's `~100 DAU` × `Sonnet 4.5 narrator` scale has no prior MINT pilot. W2 ships staging-first behind `TOOL_REGISTRY_ADAPTER=anthropic_defer_loading` flag with `p95_latency` Prometheus histogram before prod flip.
- `bundle_compiler._INTENT_BUNDLES` mapping at `bundle_compiler.py:45-52` was NOT audited for current correctness (CONTEXT.md §Data gaps). W2 task 1 = single-iteration audit pass before adding the 2 new bundles.

---

## Q-A — Anthropic Tool Search Tool : production patterns

### Exact request shape

The Anthropic Messages API supports `defer_loading: true` per-tool when the `anthropic-beta` header includes `tool-search-tool-2025-10-19`. Tools marked `defer_loading: true` are NOT included in the initial system prompt — instead, a `tool_search_tool_bm25_20251119` is injected, which Claude invokes to BM25-search the deferred tools and load 3-5 `tool_reference` blocks just-in-time.

```python
# AnthropicDeferLoadingAdapter.register_tools() canonical shape — 2026-05-16 verified.
# Source : platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool
#          (CITED — direct doc) + Medium Anthropic announcement.
# Pin : anthropic>=0.40.0,<1.0.0 already in pyproject.toml.

from anthropic import Anthropic

client = Anthropic()

tools = [
    # 5 chip-emitters stay always-on (sub-500ms L1 budget per CONTEXT.md §Latency contract).
    {"name": "get_budget_status", "description": "...", "input_schema": {...}},
    {"name": "get_retirement_projection", "description": "...", "input_schema": {...}},
    {"name": "get_cross_pillar_analysis", "description": "...", "input_schema": {...}},
    {"name": "get_cap_status", "description": "...", "input_schema": {...}},
    {"name": "get_couple_optimization", "description": "...", "input_schema": {...}},
    # 52 long-tail calculators get defer_loading: True.
    # Description MUST carry Concern A's French keyword discipline.
    {
        "name": "divorce_simulator",
        "description": "Simule l'impact financier d'un divorce ou d'une séparation : "
                       "splitting AVS (LAVS art. 29sexies), partage LPP (CC art. 122-124), "
                       "pension alimentaire, partage des avoirs, régime matrimonial.",
        "input_schema": {...},
        "defer_loading": True,
    },
    # ... 51 more deferred tools
    # The Tool Search Tool itself (server-side, no MINT code needed beyond declaration).
    {
        "type": "tool_search_tool_bm25_20251119",
        "name": "tool_search_tool_bm25",
    },
]

resp = client.messages.create(
    model="claude-sonnet-4-5",
    max_tokens=4096,
    tools=tools,
    messages=[{"role": "user", "content": "..."}],
    extra_headers={"anthropic-beta": "tool-search-tool-2025-10-19"},
)
```
*[CITED: docs.litellm.ai/docs/providers/anthropic_tool_search ; platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool ; medium.com/@DebaA/anthropic-just-shipped-the-fix-for-tool-definition-bloat-77464c8dbec9]*

### Cache invalidation interaction

Defer-loaded tools are **cache-preserving** : the initial prompt (system + first user message) is unchanged when a deferred tool is later loaded via `tool_reference` blocks. Anthropic explicitly designed this so prompt-cache TTL (5 min default) is NOT invalidated by mid-turn tool expansion. Adapter implication : MINT's existing prompt-cache headers stay valid ; W2's `AnthropicDeferLoadingAdapter` does NOT need to call `bust_cache()` on tool expansion. *[CITED: anthropic.com/engineering/advanced-tool-use]*

### Round-trip test pattern

Concern A mandates a round-trip fixture. Pattern :

```python
# tests/test_tool_search_round_trip.py — Concern A fixture (W2)
import pytest
from unittest.mock import AsyncMock, patch

# 30 representative French user messages mapped to expected top-3 tool names
ROUND_TRIP_FIXTURES: list[tuple[str, list[str]]] = [
    ("si je divorce demain, que se passe-t-il ?", ["divorce_simulator", "succession_simulator", "get_couple_optimization"]),
    ("je veux racheter ma LPP", ["lpp_rachat_echelonne", "get_cross_pillar_analysis", "epl_service"]),
    ("frontalier vaudois, FATCA", ["frontalier_service", "expat_service", "wealth_tax_service"]),
    # ... 27 more
]

@pytest.mark.parametrize("user_message,expected_top_3", ROUND_TRIP_FIXTURES)
def test_tool_search_returns_relevant_tool_in_top_3(user_message, expected_top_3, client_with_blank_profile):
    """Assert AnthropicDeferLoadingAdapter surfaces at least one expected tool in top-3."""
    # Use mock Anthropic client per services/backend/tests/coach/test_claude_retry.py:30-60 pattern
    with patch("app.services.coach.tool_registry.anthropic_defer_loading_adapter.Anthropic") as MockClient:
        # Mock returns a tool_search_tool_bm25 result envelope
        MockClient.return_value.messages.create = AsyncMock(return_value=...)
        result = client_with_blank_profile.post("/api/v1/coach/chat", json={"message": user_message})
    top_3 = _extract_tool_names_from_search_result(result.json())
    assert any(tool in expected_top_3 for tool in top_3), (
        f"User message '{user_message}' should surface at least one of {expected_top_3} "
        f"in top-3, got {top_3}"
    )
```

**Provenance :** `[CITED: docs.litellm.ai]` confirms the BM25 ranking ; Maestro side covered by G1 flow `tools/simulator/flows/maestro-perfect-set/coach_tool_search_round_trip.yaml` per W2 plan.

### Failure modes

Documented failure modes from public sources :
1. **No match** : Tool Search returns 0 references → narrator falls back to system-prompt-only tools (the 5 chip-emitters). Implication for MINT : the 5 always-on chip-emitters MUST cover the « base case » so a Tool Search miss doesn't strand the user. Already true (D-CE-04 + W0 audit row 46-50). *[CITED: blog.arcade.dev/anthropic-tool-search-claude-mcp-runtime]*
2. **Bedrock incompatibility** : `tool_search_tool_bm25` references generate `tool_reference` blocks that some Bedrock providers reject. Adapter implication : `SkillBundleOnlyAdapter` (D-CE-01 fallback) MUST be the env-flag default if MINT pivots to Bedrock. *[CITED: github.com/anthropics/claude-code/issues/25212]*
3. **Cold turn latency** : Tool Search adds 200-400ms on the first user-message-classifying turn. Concern B `latency_tier` field on `CoachToolResponse` is the mitigation — Flutter routes the result to a 2-8s narrative loader, not the L1 chip surface. Implementation : extend `CoachToolResponse` envelope with `latency_tier: Literal["L1","L2","L3"]` in W2 (Parallel Change V2 per D-CE-19).

**Confidence :** MEDIUM — Anthropic docs verified, but no MINT-scale (~100 DAU + Sonnet 4.5 + ~57 tools) production sample exists. **Mitigation :** W2 staging pilot + p95 histogram before prod flip.

---

## Q-B — `_resolve_defaults` + Pydantic v2 mechanics

### Extract `json_schema_extra` at runtime

In Pydantic v2, the canonical access pattern is `Model.model_fields["field_name"].json_schema_extra`. This is a class attribute (NOT an instance attribute), so `_resolve_defaults` can iterate WITHOUT instantiating the schema. *[CITED: pydantic.dev/docs/validation/latest/concepts/fields/]*

```python
# Verified Pydantic v2 access — 2026-05-16
from pydantic import BaseModel, Field

class RachatEchelonneRequest(BaseModel):
    canton: str | None = Field(default=None, json_schema_extra={"from_profile": "canton"})
    age: int | None = Field(default=None, json_schema_extra={"from_profile": "age"})
    salary: int | None = Field(default=None)  # no profile marker

# Runtime extraction
for name, field_info in RachatEchelonneRequest.model_fields.items():
    extra = field_info.json_schema_extra or {}
    if isinstance(extra, dict) and "from_profile" in extra:
        print(name, "→ profile.", extra["from_profile"])
# Outputs:
# canton → profile.canton
# age    → profile.age
```

Note : as of Pydantic 2.9+, `json_schema_extra` from `Annotated[...]` types is **merged additively** rather than overridden. *[CITED: pydantic.dev/docs/validation/latest/concepts/json_schema/]* Our schemas don't use Annotated metadata stacking — the `Field(json_schema_extra=...)` path is the only path we need.

### `_resolve_defaults` canonical implementation

```python
# services/backend/app/core/profile_resolver.py — NEW file in W1 PR-1.
from typing import Any, NoReturn

from fastapi import HTTPException, Depends, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.auth import require_current_user
from app.core.database import get_db
from app.models.user import User
from app.models.profile_model import ProfileModel
from app.models.coach_tools._response import CoachToolIncomplete

# D-CE-07 — explicit metadata, NOT ContextVar.
# D-CE-06 — server is PRIMARY, Flutter is UX-only.


def _resolve_defaults(
    profile_data: dict[str, Any] | None,
    body: BaseModel,
    schema_class: type[BaseModel],
) -> dict[str, Any]:
    """Return merged kwargs : body values WIN over profile ; profile fills unset/None.

    Order of precedence (verified per pydantic.dev model_fields_set docs 2026-05-16):
      1. body explicitly set + non-None    → use body value
      2. body explicitly set to None       → use body value (None) — explicit clear
      3. body NOT set (default applied)    → if json_schema_extra.from_profile and
                                              profile_data has the key, fill from profile
      4. body not set + no profile mapping → use Pydantic default (None)

    NOTE per pydantic.dev/docs/.../concepts/fields/ : `body.model_fields_set`
    returns the set of fields the CLIENT explicitly sent (including null).
    Fields with their default value applied are NOT in `model_fields_set`.
    Source: pythontutorials.net blog 2026 verified.
    """
    if profile_data is None:
        profile_data = {}

    resolved: dict[str, Any] = {}
    body_set = body.model_fields_set  # set of field names the CLIENT sent

    for name, field_info in schema_class.model_fields.items():
        if name in body_set:
            # Client explicitly set this field (even to None) → respect that.
            resolved[name] = getattr(body, name)
            continue

        # Client did NOT send this field (or sent it but Pydantic applied default).
        extra = field_info.json_schema_extra or {}
        profile_key = extra.get("from_profile") if isinstance(extra, dict) else None
        if profile_key and profile_key in profile_data and profile_data[profile_key] is not None:
            resolved[name] = profile_data[profile_key]
        else:
            # Fall through to Pydantic default (already on the body model).
            resolved[name] = getattr(body, name)

    return resolved


def _required_profile_fields_missing(
    resolved: dict[str, Any],
    schema_class: type[BaseModel],
) -> list[str]:
    """Return list of profile-mapped field names that are still None after resolve.

    Only fields with json_schema_extra={'from_profile': '<key>'} AND default=None
    are considered « required-via-profile ». Other None fields are intentional
    (e.g. optional override).
    """
    missing: list[str] = []
    for name, field_info in schema_class.model_fields.items():
        extra = field_info.json_schema_extra or {}
        if isinstance(extra, dict) and "from_profile" in extra:
            if resolved.get(name) is None:
                missing.append(extra["from_profile"])  # report profile key, not body field
    # D-CE-08 conversational handshake cap = 3.
    return missing[:3]


def raise_incomplete_as_422(
    missing_fields: list[str],
    hint_fr: str,
) -> NoReturn:
    """Raise HTTPException(422) carrying the A3 CoachToolIncomplete envelope.

    Reuses the existing Wave 1c-A3 envelope at app.models.coach_tools._response
    (verbatim, no rewrite — D-CE-04). Body shape matches the coach-dispatcher
    return shape so Flutter has a single contract for both surfaces.
    """
    incomplete = CoachToolIncomplete(
        missing_fields=missing_fields,
        hint_fr=hint_fr,
    )
    raise HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        detail=incomplete.model_dump(by_alias=True),
    )


def get_profile_filled(
    user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    """FastAPI dependency : return the authenticated user's profile data dict.

    Returns `{}` if no profile exists (anonymous user is impossible here —
    `require_current_user` already 401's). The endpoint uses this dict +
    `_resolve_defaults` to fill body defaults.

    Lifecycle : per-request. SQLAlchemy session is the same one `get_db`
    yields ; profile is read once per request, no per-call cache needed.
    """
    profile = (
        db.query(ProfileModel)
        .filter(ProfileModel.user_id == user.id)
        .order_by(ProfileModel.updated_at.desc())
        .first()
    )
    return profile.data if profile and profile.data else {}
```

**Provenance verified :**
- `ProfileModel.data` is `MutableDict.as_mutable(JSONEncodedDict)` per `services/backend/app/models/profile_model.py:37` — `.data` is a plain `dict[str, Any]`.
- `require_current_user` returns `User` at `services/backend/app/core/auth.py:111`.
- `get_db` yields a `Session` at `services/backend/app/core/database.py:35`.
- `CoachToolIncomplete` exists at `services/backend/app/models/coach_tools/_response.py` (A3 branch, sha `a55b5469`) — 422 detail must be the model_dump_json output to preserve Pydantic v2 camelCase aliasing.

### Endpoint integration pattern

```python
# services/backend/app/api/v1/endpoints/lpp_deep.py — Priority 1 W1 fix.
# CURRENT (broken per W0 audit row 14, sev-3) :
#   No profile read. Body.canton defaults to None → service crashes or uses « VD » → wrong tax brackets.
# FIXED :

from app.core.profile_resolver import (
    _resolve_defaults,
    _required_profile_fields_missing,
    get_profile_filled,
    raise_incomplete_as_422,
)
from app.schemas.lpp_deep import RachatEchelonneRequest

@router.post("/rachat-echelonne", response_model=RachatEchelonneResponse)
@limiter.limit("10/minute")
def lpp_deep_rachat_echelonne(
    request: Request,
    body: RachatEchelonneRequest,
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> RachatEchelonneResponse:
    resolved = _resolve_defaults(profile_data, body, RachatEchelonneRequest)
    missing = _required_profile_fields_missing(resolved, RachatEchelonneRequest)
    if missing:
        # D-CE-08 — 422 with structured envelope.
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr=(
                "Pour estimer ton rachat LPP étalonné, j'ai besoin de "
                "ton canton et de ton revenu annuel imposable. Tu peux me les partager ?"
            ),
        )

    # Wrap existing _compute helper (CLAUDE.md §1 financial_core SoT — no re-implementation).
    result = compute_rachat_echelonne(**resolved)
    return _result_to_response(result, RachatEchelonneResponse)
```

### `model_fields_set` for « None vs missing » distinction

Verified per pythontutorials.net 2026 + pydantic.dev concepts/fields :
- `body.model_fields_set` ⊆ Pydantic v2 field names.
- A name is in the set ↔ the client explicitly sent the field in the request body (even if value is `null`).
- A name is NOT in the set ↔ Pydantic applied the default (likely `None` from `Field(default=None, ...)`).

This is **critical** for the « body wins over profile » precedence rule. Naive `if body.canton is not None` would silently override a user who explicitly sent `null` to clear a profile-derived default.

### `Depends(get_profile_filled)` lifecycle

FastAPI resolves `Depends` per-request. `get_db` (yield-style dependency at `services/backend/app/core/database.py:35`) shares the same `Session` with `get_profile_filled` — no extra DB connection, no transaction nesting. Profile is read once per request, cached implicitly in the function-local `profile_data` variable. *[VERIFIED: fastapi.tiangolo.com/tutorial/dependencies/]*

**Confidence :** HIGH on mechanics ; MEDIUM on edge cases around explicit-None semantics (one targeted contract test per endpoint — Concern D pattern — covers it).

---

## Q-C — Pydantic v2 discriminated union patterns (D-CE-15)

### Exact syntax

```python
# services/backend/app/models/lucidity/_payload.py — NEW W1 file.
from __future__ import annotations

from enum import StrEnum
from typing import Annotated, Any, Literal, Union

from pydantic import BaseModel, ConfigDict, Field, RootModel, model_validator


class LucidityLevel(StrEnum):
    L1 = "L1"
    L2 = "L2"
    L3 = "L3"
    L4 = "L4"


class _LucidityBase(BaseModel):
    """Shared base for L1-L4 payloads. extra=forbid kills paraphrase injection."""
    model_config = ConfigDict(extra="forbid", frozen=True)


class L1ChiffrePayload(_LucidityBase):
    """L1 = atomic chiffrage. « Voici X CHF. » No ranking, no comparison."""
    level: Literal[LucidityLevel.L1] = LucidityLevel.L1
    value: float
    unit_fr: str   # « CHF/mois », « % », « ans »
    citation_key: str   # tool_<name> per Phase 94 closed-world


class _Scenario(_LucidityBase):
    label_fr: str
    value: float
    narrative_fr: str
    citation_key: str


class L2ComparePayload(_LucidityBase):
    """L2 = compare. « Voici 3 scénarios A=X B=Y C=Z. » Ranking field DOES NOT EXIST.

    The forbidden field names (`recommended_option`, `best_choice`, `top_pick`,
    `preferred`) are NOT declared. `model_config.extra="forbid"` causes Pydantic
    v2 to raise ValidationError if any of these names appear in input — D-CE-16(a)
    schema-impossibility layer.
    """
    level: Literal[LucidityLevel.L2] = LucidityLevel.L2
    scenarios: list[_Scenario] = Field(..., min_length=2, max_length=4)

    @model_validator(mode="after")
    def _enforce_narrative_length_parity(self) -> "L2ComparePayload":
        """D-CE-15 — within ±15% character count.

        Reason : 3 scenarios of 200/50/50 words = de facto ranking (LSFin art. 8
        « presented as pertinent for a precise person »). Type-level enforcement
        kills the paraphrase ranking creep before the payload leaves the calculator.
        """
        lengths = [len(s.narrative_fr) for s in self.scenarios]
        if not lengths:
            return self
        avg = sum(lengths) / len(lengths)
        for i, ln in enumerate(lengths):
            if abs(ln - avg) > 0.15 * avg:
                raise ValueError(
                    f"L2 narrative length parity violated : scenario[{i}] = {ln} chars, "
                    f"avg = {avg:.0f}, max delta = {0.15 * avg:.0f}. "
                    f"All scenarios must be within ±15% of avg character count "
                    f"(D-CE-15 narrative parity validator)."
                )
        return self


class L3EclairePayload(_LucidityBase):
    """L3 = éclairer l'arbitrage caché. « Si tu choisis A, ça change ton 3a, ton impôt et ta dette. »"""
    level: Literal[LucidityLevel.L3] = LucidityLevel.L3
    primary_choice_fr: str
    cascade_effects: list[dict[str, Any]]   # {area_fr, delta_value, delta_unit_fr, citation_key}
    horizon_years: int


class L4InvariantPayload(_LucidityBase):
    """L4 = surfacer les invariants. « Quel que soit le scénario, plafond 33% LCC. »

    Per CONTEXT.md §Finding 5 : MINT's strongest LSFin moat. Ship FIRST in W1.
    """
    level: Literal[LucidityLevel.L4] = LucidityLevel.L4
    legal_article_ref: str = Field(..., min_length=5)   # « LCC art. 28 », « LIFD art. 33 »
    condition_text_fr: str = Field(..., min_length=20)


# The discriminated union itself.
LucidityPayload = RootModel[
    Annotated[
        Union[L1ChiffrePayload, L2ComparePayload, L3EclairePayload, L4InvariantPayload],
        Field(discriminator="level"),
    ]
]
```

### `model_config = ConfigDict(extra="forbid")`

Pydantic v2 enforces `extra="forbid"` at validation time (NOT at instantiation time). Tests must construct `L2ComparePayload.model_validate({"level":"L2","scenarios":[...], "recommended_option":"A"})` to verify rejection. Direct `L2ComparePayload(level="L2", scenarios=[...], recommended_option="A")` raises a different error (kwargs validation). *[CITED: pydantic.dev/docs/validation/latest/api/config/]*

### `@model_validator(mode="after")` pattern

`mode="after"` runs the validator AFTER all fields are parsed and individually validated. The validator receives the model instance (typed `Self`) and returns it (or raises). Required for cross-field invariants like the narrative-length parity check above. *[CITED: pydantic.dev/docs/validation/latest/concepts/validators/]*

**Confidence :** HIGH. Verified Pydantic v2 patterns 2026-05-16 ; precedent in MINT codebase = `services/backend/app/models/coach_tools/_response.py` (A3 envelope uses same discriminator pattern on `status` field).

### Integration with existing `CoachToolOk.data`

The 5 chip-emitters return `CoachToolOk(data={...})`. The L1-L4 layer goes inside `data`:

```python
# Within _compute_retirement_projection :
ok = CoachToolOk(data={
    "rente_avs_chf_monthly": 2300,
    "lucidity": L1ChiffrePayload(
        value=2300, unit_fr="CHF/mois", citation_key="tool_get_retirement_projection"
    ).model_dump(),
    ...
})
```

This is **additive, non-breaking** for existing fixtures. The 5 chip-emitters' contract tests still assert on `data["rente_avs_chf_monthly"]` ; they MAY add `data["lucidity"]` assertions if/when they migrate.

---

## Q-D — PostgreSQL composite index + Alembic CONCURRENTLY

### The footgun

`CREATE INDEX CONCURRENTLY` cannot run inside a transaction block. Alembic wraps every migration in `BEGIN ... COMMIT` by default. Naive `op.execute("CREATE INDEX CONCURRENTLY ...")` fails with `ERROR: CREATE INDEX CONCURRENTLY cannot run inside a transaction block`. *[CITED: lyjia.us/blog/p/alembic-migrations-outside-transaction-block + sqlalchemy.github.io/alembic/discussions/1461]*

### Canonical fix — `autocommit_block()`

Alembic exposes `op.get_context().autocommit_block()` (context manager) which ends the surrounding transaction, executes the wrapped statements in autocommit mode, and re-opens a transaction afterwards. Same primitive used in `pg_enum_add_value` migrations.

```python
# services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py — W3 new.
"""Phase mint-calc-engine-v1 W3 — D-CE-12 composite index for cache lookup.

Revision ID: p110_scenarios_cache_lookup_index
Revises:     p97_snapshots_fk_and_server_defaults

Adds the composite partial index Phase 95 left missing :
  (profile_id, kind, inputs_hash, created_at DESC) WHERE superseded_by IS NULL

Without this, the read-side cache lookup is a seq-scan and MAKES performance
WORSE for power users (Phase 95 critical gap, panel Finding 3).

Footgun mitigation : CREATE INDEX CONCURRENTLY cannot run in a transaction.
Alembic's autocommit_block() wraps the call cleanly.
"""
from alembic import op


revision = "p110_scenarios_cache_lookup_index"
down_revision = "p97_snapshots_fk_and_server_defaults"
branch_labels = None
depends_on = None


INDEX_NAME = "idx_scenarios_cache_lookup"


def upgrade() -> None:
    # SQLite has no CONCURRENTLY ; skip in test env.
    bind = op.get_bind()
    if bind.dialect.name != "postgresql":
        # SQLite path : plain index, no partial WHERE clause if dialect
        # doesn't support it. Used only by pytest with in-memory SQLite.
        op.execute(
            f"CREATE INDEX IF NOT EXISTS {INDEX_NAME} "
            f"ON scenarios (profile_id, kind, inputs_hash, created_at)"
        )
        return

    # PostgreSQL — production path with CONCURRENTLY + partial index.
    with op.get_context().autocommit_block():
        op.execute(
            f"""
            CREATE INDEX CONCURRENTLY IF NOT EXISTS {INDEX_NAME}
            ON scenarios (profile_id, kind, inputs_hash, created_at DESC)
            WHERE superseded_by IS NULL
            """
        )


def downgrade() -> None:
    with op.get_context().autocommit_block():
        op.execute(f"DROP INDEX CONCURRENTLY IF EXISTS {INDEX_NAME}")
```

**Provenance :**
- `p95_dag_invalidation.py` (`services/backend/alembic/versions/p95_dag_invalidation.py`) is the precedent additive migration for `scenarios` — same `inspector` idempotency pattern.
- Alembic ≥ 1.13 supports `autocommit_block()` — pyproject.toml pins `alembic>=1.13.0,<2.0.0`. Verified.
- `IF NOT EXISTS` for CONCURRENTLY indexes : supported on PG 9.6+, all Railway envs run PG 14+. *[CITED: postgresql.org/docs/current/sql-createindex.html]*

### Backfill consideration

At 100 DAU × 57 calcs × 1 year = 5.8M rows projected (CONTEXT.md §Finding 4). Even if scenarios grows that fast, CONCURRENTLY scales : it does a 2-pass build without blocking writes. On a 5.8M row table on Railway hardware, expect ~5-10 min wall-clock. Run during low-traffic window (Sentry traffic dashboard shows trough 03-06 CET). No application-side backfill needed — the index covers existing rows automatically once built.

### Verification query

```sql
-- Pre-deploy : assert seq-scan today.
EXPLAIN ANALYZE
SELECT * FROM scenarios
WHERE profile_id = '<uuid>'
  AND kind = 'lpp_rachat'
  AND inputs_hash = 'abc123...'
  AND superseded_by IS NULL
ORDER BY created_at DESC LIMIT 1;
-- Expected pre-deploy : Seq Scan on scenarios + Filter on conditions.

-- Post-deploy : assert Index Scan.
-- Expected : Index Scan using idx_scenarios_cache_lookup on scenarios
--            Index Cond: ((profile_id = '...') AND (kind = '...') AND (inputs_hash = '...'))
--            Filter: (superseded_by IS NULL)
```

W3 PR ships this verification in `services/backend/tests/test_scenarios_cache_index.py::test_explain_analyze_uses_index` (PostgreSQL-only ; SQLite test path skips with `pytest.skip("postgres only")`).

**Confidence :** HIGH. Alembic autocommit_block pattern is documented + multiple credible sources confirm. `psycopg2-binary>=2.9.9` in pyproject.toml supports the dialect path natively.

---

## Q-E — FastAPI BackgroundTasks vs APScheduler vs cron (D-CE-13)

### BackgroundTasks lifecycle + cancellation

FastAPI BackgroundTasks (from Starlette) execute **AFTER the response is sent** in the same event loop. Lifecycle :
- Scheduled at request-handler time via `background_tasks.add_task(fn, *args)`.
- Run after `response.send()` completes.
- Share the request's `asyncio` task context (gotcha : if FastAPI shuts down mid-task, the task is cancelled with `CancelledError` ; no built-in retry).
- No persistence : tasks are in-process and lost on `uvicorn`/`gunicorn` worker restart.

For D-CE-13 (pre-compute « top 3 likely-needed calcs ») this lifecycle is **acceptable** : pre-compute is best-effort cache warming, NOT durable work. A miss = next-turn cache miss = compute on demand. *[CITED: fastapi.tiangolo.com/tutorial/background-tasks/ + medium.com/@rasifrazak123/fastapi-scheduling-background-tasks-backgroundtasks-vs-apscheduler-vs-celery]*

### Pre-compute wiring

```python
# services/backend/app/services/coach/pre_compute.py — W3 NEW.
from fastapi import BackgroundTasks
from sqlalchemy.orm import Session
from app.calculators._registry import get_reverse_dep_map   # D-CE-14
from app.services.cache.cache_writer import write_to_cache


async def precompute_after_fact_save(
    background_tasks: BackgroundTasks,
    fact_key: str,
    fact_value: object,
    profile_id: str,
    db: Session,
) -> None:
    """Schedule top-3 calc warming after save_fact() lands.

    Pure scheduling — no compute here. The actual compute happens AFTER
    the user-facing response is sent.
    """
    affected_kinds = get_reverse_dep_map().get(fact_key, set())
    if not affected_kinds:
        return  # nothing to warm

    # D-CE-14 — cap to top 3 to bound BackgroundTasks fan-out.
    for kind in list(affected_kinds)[:3]:
        background_tasks.add_task(
            _warm_calc, profile_id=profile_id, kind=kind, db=db,
        )


async def _warm_calc(profile_id: str, kind: str, db: Session) -> None:
    """Singleflight-protected warm-path. See Q-E.singleflight below."""
    # ... see singleflight pattern next.
```

### Singleflight `asyncio.Lock` dict — Concern E

Cache stampede on cold-start : 10 simultaneous users requesting same calc → 10 PG roundtrips + 10 compute fan-outs. Mitigation = in-process singleflight keyed by `(profile_id, kind, inputs_hash)`. The race condition the planner must guard against = **2 concurrent calls creating the same dict key**.

```python
# services/backend/app/services/cache/singleflight.py — W3 NEW.
import asyncio
from collections import defaultdict
from contextlib import asynccontextmanager
from typing import AsyncIterator, Hashable


class AsyncSingleflight:
    """Per-key asyncio.Lock dict with safe key creation.

    Pattern verified per dataleadsfuture.com 2026 « Mastering Synchronization
    Primitives in Python Asyncio » + oneuptime.com 2026 request coalescing.

    The trap : `if key not in self._locks: self._locks[key] = asyncio.Lock()`
    is a race when 2 tasks check `not in` simultaneously. Fix : use
    defaultdict(asyncio.Lock) — defaultdict.__getitem__ is NOT atomic in
    general, but the GIL makes it atomic for the dict slot insertion in
    CPython. Verified : defaultdict + Lock() construction in __missing__
    runs while GIL held → safe.
    """

    def __init__(self) -> None:
        self._locks: defaultdict[Hashable, asyncio.Lock] = defaultdict(asyncio.Lock)

    @asynccontextmanager
    async def acquire(self, key: Hashable) -> AsyncIterator[None]:
        lock = self._locks[key]
        async with lock:
            yield
        # NOTE : we intentionally do NOT pop the lock after release.
        # Eviction by LRU lives in cache_reader, not here. ~57 calcs × ~100
        # active profiles = 5.7K locks max ; ~1 KB each ; acceptable.


_singleflight = AsyncSingleflight()


async def get_or_compute(
    profile_id: str,
    kind: str,
    inputs_hash: str,
    compute_fn,
    db,
):
    """Read-through cache with singleflight."""
    cached = await cache_reader.read(profile_id, kind, inputs_hash, db)
    if cached is not None:
        return cached

    key = (profile_id, kind, inputs_hash)
    async with _singleflight.acquire(key):
        # Re-check under lock — another task may have populated the cache.
        cached = await cache_reader.read(profile_id, kind, inputs_hash, db)
        if cached is not None:
            return cached
        result = await compute_fn()
        await cache_writer.write(profile_id, kind, inputs_hash, result, db)
        return result
```

*[CITED: docs.python.org/3/library/asyncio-sync.html ; dataleadsfuture.com 2026 ; oneuptime.com 2026-01-25 request coalescing]*

**Race rebuttal on `defaultdict` :** under CPython GIL, `defaultdict.__getitem__` invoking `__missing__` (which calls the default_factory `asyncio.Lock()`) is atomic for the slot insertion. Two concurrent `__getitem__` for the same missing key get the **same Lock instance**. Verified across the singleflight references cited. For asyncio (single-threaded by default), this is even simpler : no preemption during synchronous dict access.

### APScheduler vs cron for GC (Concern E + Finding 4)

D-CE-12 punts GC to W3. The W3 plan needs to choose : APScheduler in-process vs Railway scheduled deploy (cron-like).

**Trade-off table :**

| Property | APScheduler (`apscheduler.schedulers.background.BackgroundScheduler`) | Railway cron (deploy `cron: "0 3 * * *"` on a worker) |
|---|---|---|
| Persistence on restart | Lose jobs unless `SQLAlchemyJobStore` configured | Persisted (Railway managed) |
| MINT scale | OK (~100 DAU, 1 daily job) | Trivially OK |
| Deployment complexity | 1 line in `app/main.py` lifespan | 1 line in `railway.json` |
| Coupling to API process | Tight (shares Python interpreter) | Loose (separate worker) |
| Observability | Sentry breadcrumbs via existing helper | Railway logs + Sentry init in worker |
| 2-replica safety | Run job N times = race on `DELETE FROM scenarios` | Run job exactly 1× (Railway scheduler guarantee) |

**Recommendation :** Railway cron. 2-replica race on the GC `DELETE` is a real production concern even at low scale — D-CE-12 acceptance criteria implicitly assume single-execution semantics. Railway's scheduled deploy primitive runs the worker once per cron tick. Cost = 1 separate `railway.json` service entry + `gc_job.py` standalone script with `if __name__ == "__main__"` shim. Verified : MINT's Railway setup at `services/backend/railway.json` already has multi-service support (per memory `reference_infra_access.md`).

If the planner prefers in-process : APScheduler `BackgroundScheduler` with `SQLAlchemyJobStore` and a deploy-time leader-election flag (`MINT_GC_LEADER=1` on exactly one replica). Adds complexity ; recommend cron.

*[CITED: sentry.io/answers/schedule-tasks-with-fastapi/ + rajansahu713.medium.com/implementing-background-job-scheduling-in-fastapi-with-apscheduler]*

**Confidence :** HIGH on BackgroundTasks lifecycle ; MEDIUM on Railway cron choice (decision is Claude's discretion per the spec but needs operator review when W3 plans).

---

## Q-F — `bundle_compiler.py` extension (D-CE-03)

### Public API

Already verified at `services/backend/app/services/coach/bundle_compiler.py` (read in full above).

- **Single entrypoint :** `compile_bundles(intents: Iterable[str], ctx: Optional[CoachContext] = None, language: str = "fr") -> CompiledBundle`.
- **Bundle registry :** static dict `_INTENT_BUNDLES` at line 45-52. Maps each of the 6 canonical intents (retirement / taxes / housing / debt / family / career) to a list of bundle CLASSES (not instances).
- **Always-on bundles :** `_ALWAYS_ON` list at line 58-61 — `ComplianceNarratorBundle` + `LifeEventRouterBundle`.
- **Drop priority :** `_DROP_PRIORITY` list at line 65-70 — right-to-left dropping when over `_TOKEN_BUDGET = 8000`.
- **Test invariant (module-import-time) :** `_DROP_PRIORITY ∩ _ALWAYS_ON == set()` enforced via `assert` at line 76-78.

### Bundle class contract

Per `services/backend/app/services/coach/bundles/_base.py` :

```python
class BundleBase(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")
    name: str                  # kebab-case identifier
    prompt_fragment: str       # markdown text, joined by _FRAGMENT_SEPARATOR
    allowed_tools: list[str]   # union'd into compiled.allowed_tools
    citation_allowlist: list[str]   # union'd into compiled.citation_allowlist
```

Plus declared slot constraint : the assembled prompt's `{slot}` placeholders must be subset of `_DECLARED_SLOTS` (7 slots, frozen at line 99-107). New bundles MUST NOT introduce a new slot, OR the planner adds it to `_DECLARED_SLOTS` AND wires it through `claude_coach_service._build_prompt`.

### Adding `IndependentTaxBundle` + `SuccessionDivorceBundle`

Two NEW files in `services/backend/app/services/coach/bundles/` :

```python
# services/backend/app/services/coach/bundles/independent_tax_bundle.py — W2 NEW.
from app.services.coach.bundles._base import BundleBase


class IndependentTaxBundle(BundleBase):
    """W2 D-CE-03 — bundle scaffolding for indépendant users.

    Matrix domain 8 has 2❌ absent items (Sàrl-vs-RI + dividende-vs-salaire).
    Even without the calculators, the bundle scaffolds the narrator's
    coaching register for indépendants.
    """

    def __init__(self) -> None:
        super().__init__(
            name="independent-tax",
            prompt_fragment=(
                "## Indépendant / Sàrl\n"
                "Si l'utilisatrice ou l'utilisateur évoque son statut indépendant, sa Sàrl, "
                "ou un arbitrage dividende-vs-salaire, garde le registre éducatif. "
                "Cite LAVS art. 8 (cotisations indépendant), LPP art. 4 (LPP volontaire), "
                "LIFD art. 33 al. 1 let. d (déductions 3a + LPP rachat).\n\n"
                "Outils disponibles : `avs_cotisations_independants`, `pillar_3a_indep`, "
                "`lpp_volontaire`, `ijm_service`.\n"
            ),
            allowed_tools=[
                "avs_cotisations_independants",
                "pillar_3a_indep",
                "lpp_volontaire",
                "ijm_service",
            ],
            citation_allowlist=[
                "tool_avs_cotisations_independants",
                "tool_pillar_3a_indep",
                "tool_lpp_volontaire",
                "tool_ijm_service",
            ],
        )
```

```python
# services/backend/app/services/coach/bundles/succession_divorce_bundle.py — W2 NEW.
# Analogous structure. Cites :
# - CC art. 122-124 (régime matrimonial)
# - LAVS art. 29sexies (splitting AVS)
# - CC art. 462 (droit du conjoint survivant)
# - CC art. 467-469 (réserves héréditaires)
# Tools : divorce_simulator, succession_simulator, concubinage_compare.
```

Then patch `bundle_compiler.py` imports + `_INTENT_BUNDLES` + `_DROP_PRIORITY` :

```python
# bundle_compiler.py change set — W2 patch.
from app.services.coach.bundles import (
    ...,
    IndependentTaxBundle,        # NEW
    SuccessionDivorceBundle,     # NEW
)

# Add to BOTH 'family' and 'career' intents :
_INTENT_BUNDLES = {
    "retirement": [Pillar3aOptimizerBundle, LppProjectorBundle],
    "taxes":      [TaxExplainerBundle, Pillar3aOptimizerBundle, IndependentTaxBundle],   # +IndependentTax
    "housing":    [MortgageStressorBundle, TaxExplainerBundle],
    "debt":       [MortgageStressorBundle, ComplianceNarratorBundle],
    "family":     [LifeEventRouterBundle, ComplianceNarratorBundle, SuccessionDivorceBundle],  # +Succession
    "career":     [LppProjectorBundle, LifeEventRouterBundle, IndependentTaxBundle],     # +IndependentTax
}

# Add to drop priority right-to-left (NEW bundles drop FIRST under budget pressure) :
_DROP_PRIORITY = [
    IndependentTaxBundle,       # NEW — drop first
    SuccessionDivorceBundle,    # NEW — drop second
    MortgageStressorBundle,
    TaxExplainerBundle,
    LppProjectorBundle,
    Pillar3aOptimizerBundle,
]
```

The new bundles also need their entries in `services/backend/app/services/coach/bundles/__init__.py` exports. Filesystem auto-discovery is NOT used today — `__init__.py` lists exports explicitly. Pattern : add 2 lines mirroring existing entries.

**Tests to add :**
- `services/backend/tests/bundles/test_independent_tax_bundle.py` — frozen+extra=forbid invariants per existing `test_bundle_contract.py` precedent.
- `services/backend/tests/bundles/test_succession_divorce_bundle.py` — same.
- Extend `services/backend/tests/bundles/test_bundle_compiler.py::test_intent_to_bundles_mapping` with the 2 new bundle-intent pairs.

**Confidence :** HIGH. Pattern verified in-repo at `services/backend/app/services/coach/bundles/{compliance_narrator,life_event_router,lpp_projector,mortgage_stressor,pillar3a_optimizer,tax_explainer,citation_grammar}.py`.

---

## Q-G — AST scanner for `_registry.py` (D-CE-11 + D-CE-14)

### What we're detecting

Per D-CE-11 each calc registry entry needs : `name`, `file`, `profile_fields_needed`, `life_events_served`, `output_type`. Per D-CE-14 the reverse-dep map is `{fact_key → {kind_a, kind_b, ...}}` — sourced from the SAME scan output.

### Scanner skeleton

```python
# tools/generate_calc_registry.py — W2 NEW. Run via `python3 tools/generate_calc_registry.py`.
# Outputs : services/backend/app/calculators/_registry.py
#
# CI gate (lefthook): re-run on every push that touches services/backend/app/services/.
# If the regenerated file differs from the committed file, fail the build —
# « stale registry » lint.
import ast
from pathlib import Path

ROOT = Path("services/backend/app/services")

# Naming heuristic for « this function is a calculator » per the matrix audit :
# - module-level functions named `compute_*` OR `simulate_*` OR `compare_*`
# - that accept primitive args (no Pydantic schema) per the existing service-layer pattern
# Verified via grep across the 11 service dirs : `compare_allocation_annuelle`,
# `simulate_rachat_echelonne`, `compute_rachat_echelonne`, etc.
CALCULATOR_FUNC_PREFIXES = ("compute_", "simulate_", "compare_")


def find_calculators_in_module(path: Path) -> list[dict]:
    """Walk one .py file and emit a list of calc-entry dicts."""
    source = path.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(path))
    calculators: list[dict] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.FunctionDef):
            continue
        if not any(node.name.startswith(prefix) for prefix in CALCULATOR_FUNC_PREFIXES):
            continue

        # Profile fields needed = args of the function, minus self/cls/db.
        arg_names = [
            a.arg for a in node.args.args
            if a.arg not in ("self", "cls", "db")
        ]
        # Life events served = grep TODO heuristic, refined in PR review.
        life_events = _heuristic_life_events_from_module(path)
        # Output type = L1/L2/L3/L4 from a `# @lucidity: L2` magic comment
        # (panel decision : explicit magic comment > inferred — Karpathy #1).
        output_type = _scan_for_lucidity_marker(node, source)

        calculators.append({
            "name": f"{path.stem}_{node.name}",
            "file": str(path.relative_to(Path("services/backend"))),
            "profile_fields_needed": arg_names,
            "life_events_served": life_events,
            "output_type": output_type,
        })
    return calculators


def _scan_for_lucidity_marker(node: ast.FunctionDef, source: str) -> str:
    """Scan for `# @lucidity: L<N>` decorator comment immediately above the def."""
    lines = source.splitlines()
    start_line = node.lineno - 1
    for i in range(start_line - 1, max(start_line - 5, -1), -1):
        if "# @lucidity:" in lines[i]:
            return lines[i].split("# @lucidity:")[1].strip()
    return "L1"  # default


def _heuristic_life_events_from_module(path: Path) -> list[str]:
    """Map module path to life-event tags. Drift-resistant : grep'able."""
    # services/lpp_deep/ → retirement, buyback
    # services/family/  → family, marriage, divorce
    # services/mortgage/→ housing
    # services/fiscal/  → taxes
    # services/expat/   → cross_border
    # services/independants/ → independent
    # services/divorce_simulator.py → family, divorce
    # services/succession_simulator.py → family, succession
    # services/debt_prevention/ → debt
    # services/retirement/ → retirement
    # services/arbitrage/ → cross_cutting
    domain = path.parent.name
    mapping = {
        "lpp_deep":        ["retirement", "buyback"],
        "family":          ["family", "marriage"],
        "mortgage":        ["housing"],
        "fiscal":          ["taxes"],
        "expat":           ["cross_border"],
        "independants":    ["independent"],
        "retirement":      ["retirement"],
        "debt_prevention": ["debt"],
        "arbitrage":       ["cross_cutting"],
        "unemployment":    ["career"],
        "services":        [],  # root services
    }
    return mapping.get(domain, [])


def generate_registry() -> dict[str, dict]:
    registry: dict[str, dict] = {}
    for py_path in ROOT.rglob("*.py"):
        if py_path.name.startswith("_") or py_path.name == "__init__.py":
            continue
        for entry in find_calculators_in_module(py_path):
            registry[entry["name"]] = entry
    return registry


def generate_reverse_dep_map(registry: dict[str, dict]) -> dict[str, set[str]]:
    """D-CE-14 — fact_key → set of calc kinds that depend on it.

    Same data, inverted index. ~80 entries projected per CONTEXT.md §Override #5.
    """
    rev: dict[str, set[str]] = {}
    for name, entry in registry.items():
        for field in entry["profile_fields_needed"]:
            rev.setdefault(field, set()).add(name)
    return rev


if __name__ == "__main__":
    registry = generate_registry()
    rev = generate_reverse_dep_map(registry)
    # Emit Python file with both data structures :
    # services/backend/app/calculators/_registry.py
    # ...
```

*[CITED: docs.python.org/3/library/ast.html + greentreesnakes.readthedocs.io/en/latest/manipulating.html]*

### Pre-commit / lefthook lint

```yaml
# lefthook.yml addition — W2.
pre-commit:
  commands:
    calc_registry_freshness:
      glob: "services/backend/app/services/**/*.py"
      run: |
        python3 tools/generate_calc_registry.py > /tmp/regenerated.py
        diff /tmp/regenerated.py services/backend/app/calculators/_registry.py || {
          echo "ERROR: calc registry is stale. Re-run python3 tools/generate_calc_registry.py and commit." >&2
          exit 1
        }
```

**Confidence :** MEDIUM. The AST walk pattern is solid ; the `_scan_for_lucidity_marker` magic-comment scanner is a planner-side choice (alternative : decorator `@lucidity(LucidityLevel.L2)` is more discoverable but requires runtime introspection at import time). Recommend magic-comment for the v1 scan — simpler, no import dep, easy to grep, planner can revisit.

---

## Q-H — Prometheus metrics in MINT backend (D-CE-13, D-CE-17)

### Current state

`grep -rn "prometheus\|Counter\|Histogram" services/backend/app/` returns ONE hit — `coach_chat.py:3524` is a local int counter for unknown tool calls, NOT a Prometheus metric. There is NO `prometheus_client` instrumentation in the codebase today. Observability today = Sentry breadcrumbs only (`services/backend/app/observability/coach_breadcrumbs.py`).

### Two options for W4 metrics

**Option 1 : Add `prometheus_client` + expose `/metrics` endpoint.**

```python
# services/backend/pyproject.toml — W4 addition.
"prometheus-client>=0.20,<1.0",

# services/backend/app/core/metrics.py — W4 NEW.
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi import APIRouter, Response

# D-CE-13 + audit data source — share key with W3 cache hit/miss counter.
calc_invoke_total = Counter(
    "mint_calc_invoke_total",
    "Calc invocations partitioned by kind and profile-grounding flag",
    labelnames=("kind", "profile_grounded"),  # 2 labels → bounded cardinality
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
    "Counter-metric : hard floor at 0 ; alerts on > 0",
)
calc_latency_seconds = Histogram(
    "mint_calc_latency_seconds",
    "Calc compute latency in seconds, partitioned by kind",
    labelnames=("kind",),
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0),
)

metrics_router = APIRouter()


@metrics_router.get("/metrics", include_in_schema=False)
def prometheus_metrics() -> Response:
    """Prometheus scrape endpoint. Auth: bearer token via Railway-provided env."""
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)
```

**Label cardinality :**
- `kind` : ~57 distinct values (1 per calculator) → bounded.
- `profile_grounded` : `"true"` | `"false"` → 2 values.
- `hit` : `"true"` | `"false"` → 2 values.
- Total time-series : ~57 × 2 = 114 per counter ; ~57 × 11 buckets = 627 for histogram. Trivial for Prometheus.

**Option 2 : Sentry-only metrics via the existing breadcrumb pattern.**

Reuse `emit_coach_tool_breadcrumb` with `extra_tags={"profile_grounded": "true"}`. Sentry's « Custom Metrics » feature ingests breadcrumb tags. Tradeoff : no Grafana panel, no PromQL. Recommendation : Option 1 for W4, Sentry parallel for incident triage.

### Grafana panel example

```promql
# Hit rate over 5min window — drives D-CE-12 SLI 60% → 80% target.
sum(rate(mint_cache_lookup_total{hit="true"}[5m])) by (kind)
  /
sum(rate(mint_cache_lookup_total[5m])) by (kind)

# Profile-grounded calc rate, the D-CE-17 primary metric.
sum(rate(mint_calc_invoke_total{profile_grounded="true"}[5m]))
  /
sum(rate(mint_calc_invoke_total[5m]))
# Alerting threshold : < 0.95 over 30min = page oncall.

# D-CE-14 warm precision SLI :
sum(rate(mint_calc_warm_total{hit="true"}[1h]))
  /
sum(rate(mint_calc_warm_total[1h]))
# Target : ≥ 0.60.
```

**Confidence :** HIGH on label-cardinality math + bucket choice. MEDIUM on Sentry-vs-Prometheus operator preference — planner SHOULD confirm with Julien before W4 PR-1.

---

## Q-I — Validation Architecture (Nyquist enabled)

### Test framework

| Property | Value |
|---|---|
| Framework | pytest 8.0+ + `pytest-asyncio` 0.23+ + `pytest-cov` 5.0+ + `hypothesis>=6.111` (per `services/backend/pyproject.toml` `[project.optional-dependencies].dev`) |
| Config file | `services/backend/pyproject.toml` `[tool.pytest.ini_options]` (verified) + `services/backend/tests/conftest.py` |
| Quick run command | `cd services/backend && python3 -m pytest tests/test_<file>.py -q` |
| Full suite command | `cd services/backend && python3 -m pytest tests/ -q` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test type | Automated command | File exists? |
|---|---|---|---|---|
| D-CE-01 | AnthropicDeferLoadingAdapter produces correct request body | unit | `pytest tests/test_tool_registry_adapter.py::test_anthropic_defer_loading_request_shape -x` | ❌ Wave 0 — W2 creates |
| D-CE-01 | SkillBundleOnlyAdapter falls back when env flag set | unit | `pytest tests/test_tool_registry_adapter.py::test_skill_bundle_only_fallback -x` | ❌ W2 |
| D-CE-01 | Round-trip : 30 FR fixtures → expected tool in top-3 (Concern A) | integration | `pytest tests/test_tool_search_round_trip.py -x` | ❌ W2 |
| D-CE-06 | `Depends(get_profile_filled)` returns profile.data | unit | `pytest tests/test_profile_resolver.py::test_get_profile_filled_returns_dict -x` | ❌ W1 PR-1 |
| D-CE-07 | `_resolve_defaults` body > profile > default precedence | unit | `pytest tests/test_profile_resolver.py::test_resolve_defaults_precedence -x` | ❌ W1 PR-1 |
| D-CE-07 | `_resolve_defaults` distinguishes explicit-None from unset | unit | `pytest tests/test_profile_resolver.py::test_resolve_defaults_explicit_none_vs_unset -x` | ❌ W1 PR-1 |
| D-CE-08 | Missing required profile field → 422 with CoachToolIncomplete envelope | contract | `pytest tests/test_lpp_deep_endpoint_grounding.py::test_blank_profile_yields_422 -x` | ❌ W1 — 1 per endpoint |
| D-CE-08 | `client_with_blank_profile()` fixture (Concern D) | fixture | `pytest tests/conftest.py --collect-only -q \| grep client_with_blank_profile` | ❌ W1 PR-1 |
| D-CE-11 | `_registry.py` is fresh against AST scan | lint | `python3 tools/generate_calc_registry.py > /tmp/r.py && diff /tmp/r.py services/backend/app/calculators/_registry.py` | ❌ W2 |
| D-CE-11 | Registry exports ≥ 57 entries | unit | `pytest tests/test_registry.py::test_registry_has_57_calculators -x` | ❌ W2 |
| D-CE-12 | Composite index exists post-migration | integration (PG-only) | `pytest tests/test_scenarios_cache_index.py::test_index_exists -x` | ❌ W3 |
| D-CE-12 | `EXPLAIN ANALYZE` shows Index Scan, not Seq Scan | integration (PG-only) | `pytest tests/test_scenarios_cache_index.py::test_explain_analyze_uses_index -x` | ❌ W3 |
| D-CE-12 | Cache reader sub-50ms p95 on 1k rows | benchmark | `pytest tests/test_cache_reader.py --benchmark-only` | ❌ W3 |
| D-CE-13 | `BackgroundTasks` warm-path fires after fact save | unit | `pytest tests/test_pre_compute.py::test_save_fact_schedules_top_3_warms -x` | ❌ W3 |
| D-CE-13 | Singleflight collapses concurrent warms (Concern E) | concurrency | `pytest tests/test_singleflight.py::test_10_concurrent_calls_to_same_key_executes_once -x` | ❌ W3 |
| D-CE-14 | Reverse-dep map matches AST scan | unit | `pytest tests/test_reverse_dep_map.py::test_reverse_dep_map_consistent_with_registry -x` | ❌ W3 |
| D-CE-15 | `L2ComparePayload` rejects `recommended_option` field | unit | `pytest tests/test_lucidity_payloads.py::test_l2_rejects_recommended_option -x` | ❌ W1 |
| D-CE-15 | Narrative-length parity validator fires on > ±15% delta | unit | `pytest tests/test_lucidity_payloads.py::test_l2_narrative_length_parity_validator -x` | ❌ W1 |
| D-CE-15 | `L4InvariantPayload` requires `legal_article_ref` | unit | `pytest tests/test_lucidity_payloads.py::test_l4_requires_legal_article_ref -x` | ❌ W1 |
| D-CE-16 | Lint extension catches paraphrase verbs | unit | `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/some_test_doc.py` (exit 1 on hit) | ❌ W4 — extend existing |
| D-CE-16 | Runtime gate fails closed with NFKC normalization | unit | `pytest tests/test_banned_verbs_runtime_gate.py::test_zero_width_char_evasion_blocked -x` | ❌ W4 |
| D-CE-17 | Prometheus `/metrics` exposes `mint_calc_invoke_total` | integration | `pytest tests/test_metrics_endpoint.py::test_calc_invoke_counter_exposed -x` | ❌ W4 |
| D-CE-17 | Profile-grounded label is correct | unit | `pytest tests/test_metrics_endpoint.py::test_profile_grounded_label_truthful -x` | ❌ W4 |
| Concern C | Flutter ↔ server `_PROFILE_SAFE_FIELDS` parity | lint | `python3 tools/checks/profile_safe_fields_parity.py` (exit 1 on drift) | ❌ W4 |
| W1 Priority 1 | `allocation_annuelle` grounded | contract | `pytest tests/test_arbitrage_endpoint_grounding.py::test_allocation_annuelle_uses_profile_canton -x` | ❌ W1 PR-1 |
| W1 Priority 1 | `affordability_service` grounded | contract | `pytest tests/test_mortgage_endpoint_grounding.py::test_affordability_uses_profile_canton -x` | ❌ W1 PR-1 |
| W1 Priority 1 | `rachat_echelonne_service` grounded | contract | `pytest tests/test_lpp_deep_endpoint_grounding.py::test_rachat_echelonne_uses_profile_canton -x` | ❌ W1 PR-1 |
| W1 Priority 2 | `wealth_tax_service` grounded + no null-canton crash | contract | `pytest tests/test_fiscal_endpoint_grounding.py::test_wealth_tax_null_canton_returns_422 -x` | ❌ W1 PR-2 |
| W1 Priority 2 | `succession_simulator` grounded | contract | `pytest tests/test_succession_endpoint_grounding.py::test_succession_uses_profile_canton -x` | ❌ W1 PR-2 |
| W1 Priority 2 | `concubinage_service` (succession variant) grounded | contract | `pytest tests/test_family_endpoint_grounding.py::test_concubinage_succession_uses_profile_canton -x` | ❌ W1 PR-2 |
| W1 Priority 2 | `location_vs_propriete` grounded | contract | `pytest tests/test_arbitrage_endpoint_grounding.py::test_location_vs_propriete_uses_profile -x` | ❌ W1 PR-2 |
| W1 Priority 3 | 5-6 endpoints per PR, batch grounding contract tests | contract | (per PR) | ❌ W1 PR-3..N |
| G1 Maestro | `coach_tool_search_round_trip.yaml` walks 5 representative FR queries | e2e | `tools/simulator/walker_audit_tap_render.sh tools/simulator/flows/maestro-perfect-set/coach_tool_search_round_trip.yaml` | ❌ W2 |

### Sampling rate

- **Per task commit (W1-W4) :** `cd services/backend && python3 -m pytest tests/test_<the_touched_file>.py -q` — sub-30s on most files.
- **Per wave merge :** `cd services/backend && python3 -m pytest tests/ -q` — current baseline ~6900+ tests in ~110s per STATE.md.
- **Phase gate :** full suite green + 5-gate exit (G1 Maestro + G2 Julien sim + G3 dev CI + G4 regression + G5 LSFin+accent+ARB) before `/gsd-verify-work`.

### Wave 0 Gaps

- [ ] `services/backend/app/core/profile_resolver.py` — covers D-CE-06+07+08 (W1 PR-1 creates).
- [ ] `services/backend/tests/conftest.py::client_with_blank_profile()` fixture — Concern D pattern (W1 PR-1 adds).
- [ ] `services/backend/app/models/lucidity/_payload.py` — covers D-CE-15 (W1 PR-3 creates).
- [ ] `services/backend/tests/test_lucidity_payloads.py` — covers D-CE-15 (W1 PR-3 creates).
- [ ] `services/backend/app/services/coach/tool_registry/` — directory + 3 adapter modules (W2 creates).
- [ ] `services/backend/tests/test_tool_search_round_trip.py` — Concern A fixture (W2 creates).
- [ ] `services/backend/app/calculators/_registry.py` — D-CE-11 + D-CE-14 (W2 creates via `tools/generate_calc_registry.py`).
- [ ] `services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py` — D-CE-12 (W3 creates).
- [ ] `services/backend/app/services/cache/{cache_reader,cache_writer,singleflight}.py` — D-CE-12 + Concern E (W3 creates).
- [ ] `services/backend/app/services/coach/pre_compute.py` — D-CE-13 (W3 creates).
- [ ] `services/backend/app/core/metrics.py` — D-CE-17 (W4 creates).
- [ ] `tools/checks/profile_safe_fields_parity.py` — Concern C (W4 creates).
- [ ] `services/backend/app/services/coach/bundles/{independent_tax_bundle,succession_divorce_bundle}.py` — D-CE-03 (W2 creates).
- [ ] Framework install : `prometheus-client>=0.20,<1.0` to `pyproject.toml` (W4 adds).

*Existing test infrastructure :* pytest with 6900+ tests, flat `tests/test_*.py` convention (Wave 1c-A3 set precedent ; see CONTEXT.md §code_context `services/backend/tests/test_calc_engine_blank_profile.py` mention).

---

## Don't Hand-Roll

| Problem | DON'T build | USE instead | Why |
|---|---|---|---|
| Per-key async singleflight | `dict[key, Lock]` with `if not in` check | `defaultdict(asyncio.Lock)` (Q-E) | The « not in » check races under contention. GIL atomicity on dict slot insert is the right primitive. *[CITED: dataleadsfuture.com asyncio sync primitives]* |
| Body-vs-profile precedence merge | Hand-roll `if body.X is not None else profile.X` | `_resolve_defaults` helper using `model_fields_set` | Hand-roll loses « client explicitly sent null » signal. See Q-B. |
| Alembic concurrent index | Raw `op.execute("CREATE INDEX CONCURRENTLY ...")` | `op.get_context().autocommit_block()` wrapper | Naked execute fails with « cannot run inside transaction ». Q-D. |
| Pydantic discriminated union | Manual `if status == "ok" then Ok elif ...` | `RootModel[Annotated[Union[...], Field(discriminator="status")]]` | Type-checker support + automatic JSON schema. A3 already uses this pattern. |
| FR keyword tool discovery | Hand-classify each user message | Anthropic Tool Search Tool BM25 | Production primitive, cache-preserving. Q-A. |
| Banned-verb regex without normalization | `re.search(r"meilleur", text)` | NFKC-normalize + strip zero-width chars THEN regex | Lexical guardrails have 40-80% false-negative on paraphrase (arXiv 2504.11168). |
| Daily GC cron in-process | APScheduler with leader election | Railway scheduled deploy primitive | 2-replica race on `DELETE` is real ; Railway gives 1×-exactly. |
| Calc registry maintenance | Hand-write registry entries | AST scan in `tools/generate_calc_registry.py` + lefthook freshness lint | Drift is inevitable ; auto-gen avoids the inevitable. |
| Round-trip tool search test | Mock the whole Anthropic SDK | Use `services/backend/tests/coach/test_claude_retry.py` `AsyncMock`/`patch.object` pattern | Precedent verified in repo at line 30-60. |
| Sentry tagging for new tools | Reinvent breadcrumb pattern | `emit_coach_tool_breadcrumb()` at `services/backend/app/observability/coach_breadcrumbs.py` | D-15 5-kwarg invariant ; existing tooling. |

**Key insight :** every adapter / helper / migration pattern in this phase has a documented precedent in MINT (CoachToolResponse envelope, A3 dispatcher, citation_grammar, p95_dag_invalidation, bundle_compiler, coach_breadcrumbs) or in upstream docs (Pydantic v2, Alembic, Anthropic SDK, FastAPI). Re-implementing any of these is Karpathy #3 violation.

---

## Common Pitfalls

### Pitfall 1 — `_resolve_defaults` overrides explicit-None
**What goes wrong :** client sends `{"canton": null}` to explicitly clear a value. Naive `_resolve_defaults` reads profile.canton instead.
**Why it happens :** `if body.canton is not None` confuses « unset » with « explicit null ».
**How to avoid :** use `body.model_fields_set` to detect explicit-set vs default-applied (Q-B).
**Warning signs :** contract test « explicit-None override » fires.

### Pitfall 2 — `CREATE INDEX CONCURRENTLY` in default Alembic transaction
**What goes wrong :** migration fails with `ERROR: CREATE INDEX CONCURRENTLY cannot run inside a transaction block`.
**Why it happens :** Alembic wraps every migration in `BEGIN ... COMMIT`.
**How to avoid :** `with op.get_context().autocommit_block(): ...` (Q-D).
**Warning signs :** SQLite tests pass (no CONCURRENTLY support) but PostgreSQL CI fails.

### Pitfall 3 — Adding bundle to `_DROP_PRIORITY` AND `_ALWAYS_ON`
**What goes wrong :** module-import-time `assert` at `bundle_compiler.py:76-78` fires.
**Why it happens :** new bundle author forgets the disjoint invariant.
**How to avoid :** read the assert before adding to `_DROP_PRIORITY` (Q-F).
**Warning signs :** `python3 -c "import app.services.coach.bundle_compiler"` fails.

### Pitfall 4 — Anthropic Tool Search beta header missing
**What goes wrong :** `defer_loading: true` is silently ignored ; tool descriptions bloat the system prompt back to ~30K tokens.
**Why it happens :** `anthropic-beta` header forgotten on the API call.
**How to avoid :** centralize in `AnthropicDeferLoadingAdapter` ; never call `client.messages.create` directly in production paths.
**Warning signs :** prompt-token Sentry breadcrumb exceeds expected baseline.

### Pitfall 5 — Pydantic v2 `model_validator(mode="after")` returns wrong type
**What goes wrong :** validator returns `None` instead of `self` → model is silently dropped.
**Why it happens :** copy-paste from a Pydantic v1 example where validators returned the validated value.
**How to avoid :** declare `-> Self` return type ; always `return self` at end of `mode="after"` validator (Q-C).
**Warning signs :** `L2ComparePayload.model_validate({...})` returns `None` instead of an instance.

### Pitfall 6 — BackgroundTasks fire-and-forget exception swallowed
**What goes wrong :** pre-compute task raises `KeyError` ; FastAPI swallows exception ; cache stays cold ; no Sentry capture.
**Why it happens :** BackgroundTasks runs outside the request-handler exception filter.
**How to avoid :** wrap every task body in `try/except` → `sentry_sdk.capture_exception(exc)` ; never let task crash silently.
**Warning signs :** Grafana shows `mint_calc_warm_total` flat at 0 while `mint_calc_invoke_total` rising.

### Pitfall 7 — `model_fields_set` excludes fields with `default_factory`
**What goes wrong :** field declared with `default_factory=lambda: profile_data["canton"]` — Pydantic considers it « set » by default. Breaks the precedence rule.
**Why it happens :** ContextVar / default_factory pattern (D-CE-07 explicitly REJECTS).
**How to avoid :** stay on `Field(default=None, json_schema_extra={"from_profile": "..."})` per D-CE-07.
**Warning signs :** explicit-None override test fails for fields with default_factory.

### Pitfall 8 — Profile data dict shape drift
**What goes wrong :** `_resolve_defaults` looks up `profile_data["canton"]` but the profile uses `profile_data["canton_residence"]`.
**Why it happens :** Flutter side renames field, server-side `_PROFILE_SAFE_FIELDS` adds new alias, `from_profile` markers point to old name.
**How to avoid :** Concern C parity lint (W4) enforces server↔Flutter naming.
**Warning signs :** silent miss (resolved[name] = None for fields the profile has).

### Pitfall 9 — Tool Search BM25 ranking sensitive to description length
**What goes wrong :** terse 1-line descriptions rank below verbose ones for the same keyword density.
**Why it happens :** BM25 saturates ; verbose descriptions get higher tf-idf for less-common terms.
**How to avoid :** target 80-200 char descriptions, French keyword discipline per Concern A.
**Warning signs :** round-trip test surface a tool in 4th-7th position instead of top-3.

### Pitfall 10 — Singleflight `_locks` dict unbounded memory
**What goes wrong :** every unique `(profile_id, kind, inputs_hash)` triple gets a Lock that never evicts.
**Why it happens :** Q-E pattern intentionally does NOT pop on release.
**How to avoid :** ~57 calcs × ~100 active profiles × ~bounded distinct hashes = upper bound ~6K Locks ≈ 6 MB. Acceptable. If load grows 10× past 60K, add an LRU eviction layer in `cache_reader`.
**Warning signs :** `_locks` dict size > 10K after sustained traffic.

---

## Code Examples (canonical patterns)

### Endpoint with grounding (W1)

```python
# services/backend/app/api/v1/endpoints/lpp_deep.py — W1 Priority 1.
# Pre-existing module ; the change is ADDITIVE (no rewrite of business logic).
from app.core.profile_resolver import (
    _resolve_defaults, _required_profile_fields_missing,
    get_profile_filled, raise_incomplete_as_422,
)


@router.post("/rachat-echelonne", response_model=RachatEchelonneResponse)
@limiter.limit("10/minute")
def lpp_deep_rachat_echelonne(
    request: Request,
    body: RachatEchelonneRequest,
    _user: User = Depends(require_current_user),
    profile_data: dict = Depends(get_profile_filled),
) -> RachatEchelonneResponse:
    resolved = _resolve_defaults(profile_data, body, RachatEchelonneRequest)
    missing = _required_profile_fields_missing(resolved, RachatEchelonneRequest)
    if missing:
        raise_incomplete_as_422(
            missing_fields=missing,
            hint_fr="Pour estimer ton rachat LPP étalonné, j'ai besoin de ton canton et de ton revenu annuel imposable.",
        )
    result = compute_rachat_echelonne(**resolved)
    return _result_to_response(result, RachatEchelonneResponse)
```

### Contract test using `client_with_blank_profile()` (W1)

```python
# services/backend/tests/test_lpp_deep_endpoint_grounding.py — Concern D pattern.
import pytest


@pytest.fixture
def client_with_blank_profile(client, db_session):
    """Build a logged-in TestClient where the user's profile.data == {}."""
    user = _create_test_user(db_session)
    profile = ProfileModel(user_id=user.id, data={})   # ← KEY : empty dict
    db_session.add(profile)
    db_session.commit()
    client.cookies.set("session", _make_session_cookie(user.id))
    return client


def test_rachat_echelonne_blank_profile_yields_422(client_with_blank_profile):
    resp = client_with_blank_profile.post(
        "/api/v1/lpp-deep/rachat-echelonne",
        json={"montant_a_racheter": 50000},  # canton intentionally missing
    )
    assert resp.status_code == 422
    detail = resp.json()["detail"]
    assert detail["status"] == "incomplete"
    assert "canton" in detail["missingFields"]   # by_alias=True camelCase
    assert detail["hintFr"].startswith("Pour estimer ton rachat LPP")
```

### Bundle definition (W2)

```python
# services/backend/app/services/coach/bundles/independent_tax_bundle.py — W2.
# See Q-F for full body. The pattern is :
#   subclass(BundleBase) → frozen + extra=forbid (inherited from _base.py)
#   __init__(self) → super().__init__(name=..., prompt_fragment=..., allowed_tools=..., citation_allowlist=...)
```

### Lucidity payload (W1 PR-3)

```python
# services/backend/app/models/lucidity/_payload.py — W1.
# See Q-C for full body. The pattern is :
#   StrEnum LucidityLevel → discriminator values
#   _LucidityBase(BaseModel) with ConfigDict(extra="forbid", frozen=True)
#   L1/L2/L3/L4 subclass _LucidityBase, each with Literal[LucidityLevel.LX] level field
#   LucidityPayload = RootModel[Annotated[Union[...], Field(discriminator="level")]]
```

### Singleflight wrapper (W3)

```python
# services/backend/app/services/cache/singleflight.py — W3.
# See Q-E for full body. The pattern is :
#   AsyncSingleflight with defaultdict(asyncio.Lock)
#   async with _singleflight.acquire(key): re-check cache then compute then write
```

### Alembic CONCURRENTLY (W3)

```python
# services/backend/alembic/versions/p110_scenarios_cache_lookup_index.py — W3.
# See Q-D for full body. The pattern is :
#   if bind.dialect.name != "postgresql": op.execute plain CREATE INDEX IF NOT EXISTS
#   else: with op.get_context().autocommit_block(): op.execute("CREATE INDEX CONCURRENTLY ...")
```

---

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|---|---|---|---|---|
| Python 3.10+ | All backend | ✓ (3.12 in Railway image, 3.9 in `.venv` per `services/backend/.venv/lib/python3.9/...`) | mixed | — |
| PostgreSQL | W3 cache index + GC | ✓ (Railway managed) | 14+ | SQLite for dev tests |
| Anthropic SDK ≥0.40 | W2 ToolRegistryAdapter | ✓ | `anthropic>=0.40.0,<1.0.0` per pyproject.toml | SkillBundleOnly adapter |
| Pydantic v2 ≥2.6 | W1 helpers + W1 lucidity payloads | ✓ | `pydantic>=2.6.0,<3.0.0` | — |
| Alembic ≥1.13 | W3 migration | ✓ | `alembic>=1.13.0,<2.0.0` (autocommit_block supported) | — |
| Sentry SDK 2.53.0 (pinned) | All waves observability | ✓ | exact pin | — |
| Maestro CLI | G1 Maestro flows | ✓ (per memory `reference_maestro_setup.md`) | varies | — |
| idb Companion | G2 sim walkthroughs | ✓ (per `feedback_device_gates.md`) | varies | — |
| Railway scheduled deploy | W3 GC cron | ✓ (Railway tier supports it) | — | APScheduler in-process |
| `prometheus-client` | W4 metrics | ✗ — NOT in pyproject.toml today | — | Sentry breadcrumbs only |
| `pytest-benchmark` | W3 cache p95 perf test | ✗ — NOT in pyproject.toml dev extras | — | Manual `time.perf_counter()` |

**Missing dependencies with fallback :**
- `prometheus-client` : W4 adds it to `pyproject.toml`. If operator declines, fall back to Sentry custom metrics via `extra_tags` on existing breadcrumb (Q-H Option 2).
- `pytest-benchmark` : W3 adds it to dev extras. If operator declines, use manual perf-counter timing in a pytest fixture.

**Missing dependencies with no fallback :** none.

---

## Validation Architecture

> Nyquist enabled per `.planning/config.json` `workflow.nyquist_validation: true`. This block triggers VALIDATION.md creation in plan-phase step 5.5.

### Test Framework

| Property | Value |
|---|---|
| Framework | pytest 8.0+ |
| Config file | `services/backend/pyproject.toml` `[tool.pytest.ini_options]` |
| Quick run | `cd services/backend && python3 -m pytest tests/<file>.py -q` |
| Full suite | `cd services/backend && python3 -m pytest tests/ -q` |
| Baseline | 6900+ tests / ~110s per `.planning/STATE.md` |

### Phase Requirements → Test Map

See Q-I above for the full 30+ row table. Critical paths :

- W1 grounding : 12 endpoint contract tests (one per sev-3 endpoint) using `client_with_blank_profile()` fixture.
- W1 lucidity : 6 Pydantic-payload contract tests (L1 happy / L2 rejects ranking field / L2 narrative parity / L3 cascade / L4 article ref / discriminator routing).
- W2 discoverability : 1 round-trip test with 30 FR fixtures (Concern A) + 3 adapter unit tests (env flag selection).
- W2 bundles : 2 bundle contract tests (frozen + extra forbid) + 1 compiler test (intent → bundle mapping).
- W3 cache : 4 tests (index exists / EXPLAIN ANALYZE / singleflight concurrency / cache reader p95 benchmark).
- W3 pre-compute : 1 test (BackgroundTask scheduled after save_fact) + 1 reverse-dep-map consistency test.
- W4 metrics : 2 tests (counter exposed at `/metrics` + label truthfulness) + 1 zero-citation hard-floor test.
- W4 lints : 1 parity lint + 1 banned-verb lint extension test.

### Sampling Rate

- **Per task commit :** quick run on the touched file.
- **Per wave merge :** full suite (~110s).
- **Phase gate :** full suite green + 5-gate exit (G1 Maestro + G2 Julien sim + G3 dev CI + G4 regression + G5 LSFin+accent+ARB lint) before `/gsd-verify-work`.

### Wave 0 Gaps

(see § Wave 0 Gaps under Q-I — 14 NEW files across the 4 waves)

---

## Security Domain

> `.planning/config.json` does not explicitly set `security_enforcement`. Per the gsd-phase-researcher contract default = enabled. Backend-heavy phase ; security review applies.

### Applicable ASVS categories

| ASVS Category | Applies | Standard control |
|---|---|---|
| V2 Authentication | yes | `require_current_user` at `services/backend/app/core/auth.py:111` — no new auth code in this phase |
| V3 Session Management | no | Session handling unchanged |
| V4 Access Control | yes | `Depends(get_profile_filled)` reads only the authenticated user's profile (filter by `user_id == user.id`). Cross-tenant leak risk = nil |
| V5 Input Validation | yes | Every endpoint already uses Pydantic v2 request schemas ; `_resolve_defaults` adds NO new untrusted-input path |
| V6 Cryptography | no | No new crypto |
| V8 Data Protection | yes | Profile data treated as PII ; existing `_sanitize_profile_context` at `coach_chat.py:892` is the canonical filter ; `_PROFILE_SAFE_FIELDS` (line 851) is the whitelist |
| V9 Communications | no | No new network surface |
| V11 Business Logic | yes | LSFin enforcement via D-CE-15 + D-CE-16 (typed payloads + banned-verb lint + runtime gate) |
| V14 Configuration | yes | New env flags `TOOL_REGISTRY_ADAPTER` (D-CE-01) + `profile_grounding_strict_mode` (D-CE-08). Both default to safe values |

### Known threat patterns for MINT stack

| Pattern | STRIDE | Standard mitigation |
|---|---|---|
| SQL injection via profile field | Tampering | Pydantic v2 validation + SQLAlchemy ORM parametrization (no raw SQL) |
| PII leak via Sentry breadcrumb | Information disclosure | Existing `services/backend/app/core/sentry_scrub.py` filter + `_sanitize_profile_context` whitelist |
| Cross-tenant profile read | Authorization bypass | `get_profile_filled` filters by `user_id == user.id` — verified Q-B |
| Banned-verb evasion via zero-width chars | Spoofing (LSFin) | D-CE-16 runtime gate NFKC-normalizes + strips zero-width chars before regex *[CITED: arXiv 2512.01353]* |
| Tool Search BM25 prompt injection | Spoofing | Anthropic-server-side BM25 ; MINT-side mitigation = Concern A French keyword discipline keeps semantic legitimacy |
| Cache poisoning via `inputs_hash` collision | Tampering | SHA-256 hash space (Phase 95 verified) ; collision improbability |
| BackgroundTask delaying response | DoS | FastAPI BackgroundTasks runs AFTER response.send() ; user-facing latency unaffected |
| Singleflight lock starvation | DoS | In-process per-key Lock ; worst case = N concurrent users on same key wait for 1 compute (~ms-seconds) |

---

## State of the Art

| Old approach | Current approach | When changed | Impact |
|---|---|---|---|
| Hardcoded `canton="VD"` fallback in endpoint | Server-side `_resolve_defaults` + 422 handshake | This phase (W1) | 12 sev-3 endpoints stop shipping wrong tax brackets |
| Pre-load all 57 tools in system prompt | Anthropic `defer_loading: true` + Tool Search Tool BM25 | Oct 2025 (Anthropic) → MINT W2 | 85% token reduction, prompt cache preserved |
| FastAPI ContextVar + default_factory for ambient profile | Explicit `json_schema_extra={"from_profile": "..."}` + helper | D-CE-07 panel override 2026-05-16 | No ContextVar leakage across requests (FastAPI #4690, #4696) |
| Doctrine table for L1/L2/L3 ranking discipline | Pydantic v2 discriminated union with `recommended_option` field FORBIDDEN | D-CE-15 panel override 2026-05-16 | Schema-level enforcement (vs lexical lint only) |
| Lexical banned-verb regex only | Triple defense : schema + lint + NFKC-normalize runtime gate | D-CE-16 panel override 2026-05-16 | Closes 40-80% paraphrase false-negative gap |
| Single north-star « turns/user/week » | Composite scorecard with paired counter-metrics | D-CE-17 panel override 2026-05-16 | Goodhart-mitigated ; engagement collapse tripwire |

**Deprecated / outdated :**
- Phase 96 « chat-as-verb destination » doctrine — KILLED 2026-05-16 ([decisions/2026-05-16-phase-96-killed.md](../../decisions/2026-05-16-phase-96-killed.md)). The narrator wire site at `coach_chat.py` STAYS ; the destination doctrine drops.
- `services/backend/app/services/independant_service.py` (root) — D-CE-10 deprecation shim, 1 release then remove.
- `services/backend/app/services/frontalier_service.py` (root) — same.
- `turns/user/week` north-star — replaced by D-CE-17 composite.

---

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|---|---|---|
| A1 | Anthropic `defer_loading: true` preserves prompt cache at MINT's scale (~100 DAU + Sonnet 4.5). Beta header stable since Oct 2025. | Q-A | Cache-invalidation regression — user-visible latency p95 spike. Mitigation : W2 staging pilot with p95 histogram + feature flag rollback. |
| A2 | Defaultdict(asyncio.Lock) is race-safe under CPython GIL for slot-insertion. | Q-E (singleflight) | Race-on-creation collides → 2 concurrent fan-outs to compute → minor over-allocation, but still correct (cache write idempotent). Risk LOW. |
| A3 | Railway scheduled deploy primitive runs the GC job exactly 1× across replicas. | Q-E (GC cron) | 2× DELETE on same rows → no data loss (DELETE is idempotent) ; some over-deletion noise in Sentry. Risk LOW. |
| A4 | Pydantic v2 `model_fields_set` semantics : « explicitly sent including null » vs « default applied ». | Q-B | Wrong precedence on explicit-None — silent override. Risk MEDIUM. **Mitigation :** dedicated unit test in W1 PR-1 (`test_resolve_defaults_explicit_none_vs_unset`). |
| A5 | The 12 sev-3 endpoints are ALL still in production today (not deprecated mid-flight since W0). | Q-I + W0 audit | Wasted W1 PR if endpoint is unrouted. Risk LOW. **Mitigation :** W1 task 0 = `grep router.include_router` for each endpoint path before opening PR. |
| A6 | `bundle_compiler._INTENT_BUNDLES` mapping at lines 45-52 is correct for current intent set. | Q-F | New bundle adds wrong intent association → bundle never activates. Risk LOW. **Mitigation :** W2 task 1 = audit pass before bundle additions (CONTEXT.md §Data gaps). |
| A7 | The 5 chip-emitters' `_PROFILE_SAFE_FIELDS` coverage at `coach_chat.py:851-889` is sufficient for the 5 tools' input schemas. | Q-I + Concern C | Hidden coverage gap → tool reads field not in safe-fields → silent KeyError or stale value. Risk MEDIUM. **Mitigation :** W4 Concern C parity lint + audit. |
| A8 | The hand-curated W2 round-trip fixtures (30 FR messages) are representative of MINT user traffic. | Q-A + Concern A | False sense of coverage on rare-intent corners. Risk MEDIUM. **Mitigation :** Sentry breadcrumb on every tool_search miss → real-traffic gap detection in W2 obs week. |
| A9 | The L2 narrative-length parity threshold ±15% is the right LSFin-defensible value. | Q-C | Too-strict → calculators can't ship 3-option L2 ; too-loose → ranking creep slips. Risk MEDIUM. **Mitigation :** revisit at W4 baseline measurement ; flag for product review. |
| A10 | `prometheus-client` is the right metrics backend (vs Sentry-only). | Q-H | If operator declines, Sentry custom metrics + extra_tags is the fallback (Q-H Option 2). Risk LOW. **Mitigation :** flag for operator at W4 plan. |
| A11 | The locked `recommended_option` / `best_choice` / `top_pick` / `preferred` field-name list covers all narrator paraphrase paths. | Q-C + D-CE-15 | Future paraphrase verb invents a new field name not in extra=forbid block. Risk LOW (extra=forbid is wildcard-rejecting, not whitelist). |
| A12 | A3 envelope `CoachToolIncomplete` evolves cleanly to V2 (Parallel Change) if W2 needs `latency_tier`. | Concern B | Migration cost overrun beyond 200-LOC budget. Risk LOW (verified A3 plan §Concern B). |

---

## Open Questions (RESOLVED — all 6 routed to specific plans, see planner output 2026-05-16)

1. **`prometheus-client` vs Sentry custom metrics for D-CE-17 ?**
   - What we know : both work ; Prometheus gives Grafana panels + alerting ; Sentry already wired.
   - What's unclear : MINT's current Grafana access + operator pref.
   - **Recommendation :** planner asks Julien at W4 PR-1 plan time.
   - **RESOLVED in:** Plan 17 (W4 metrics counters) carries the decision checkpoint with Julien G2.

2. **Pre-commit lefthook freshness lint for `_registry.py` vs CI-only ?**
   - What we know : lefthook hooks fire per-commit ; CI gates fire per-push.
   - What's unclear : tolerable lefthook latency (AST scan of ~150 files).
   - **Recommendation :** measure ; if AST scan < 2s, lefthook is the right gate ; else CI-only.
   - **RESOLVED in:** Plan 05 (W1 calc registry) carries the measurement task + decision.

3. **W2 `latency_tier` envelope V2 — drop-in vs Parallel Change ?**
   - What we know : A3's envelope is locked at `services/backend/app/models/coach_tools/_response.py` sha `a55b5469`. Adding `latency_tier: Literal["L1","L2","L3"]` to `CoachToolOk` MIGHT be drop-in if existing Flutter parser ignores unknown fields.
   - What's unclear : Flutter's parse strictness on unknown camelCase fields.
   - **Recommendation :** W2 task 0 = test add unknown field to mock response, see if `apps/mobile/lib/widgets/coach/` parser swallows it. If yes → drop-in. If no → Parallel Change V2 per D-CE-19.
   - **RESOLVED in:** Plan 10 (W2 CoachToolResponse V2) ships Parallel Change explicitly per D-CE-19 panel verdict — the drop-in path is rejected by D-CE-19's locked-in « ship V2 alongside V1, retire V1 in separate PR » contract.

4. **Reverse-dep-map handling of derived fields ?**
   - What we know : profile.data has 18-life-event-derived fields (e.g. `replacement_ratio`, `tax_saving_potential`).
   - What's unclear : whether changing `salary` should invalidate calcs that depend on derived `replacement_ratio`. Today the AST scan only sees `replacement_ratio` as the input.
   - **Recommendation :** W2 task = ship the registry with direct deps ; W3 task = surface a follow-up TODO if Sentry shows warm-recall < 70% target.
   - **RESOLVED in:** Plan 14 (W3 reverse-dep-map) ships direct-deps only ; Plan 15 carries the follow-up TODO + the `mint_calc_warm_total{kind, hit}` SLI instrumentation.

5. **W4 banned-verb runtime gate placement : pre-citation-gate or post ?**
   - What we know : Phase 94 citation gate runs at `coach_chat.py:_run_narrator_with_gate`. D-CE-16(c) runtime gate has to sit somewhere on the narrator-output path.
   - What's unclear : whether to chain BEFORE the citation gate (so failures cascade to template fallback) or AFTER (so citation-clean text is verb-validated).
   - **Recommendation :** ship BEFORE — paraphrase verb on naked text is a clearer signal than paraphrase verb post-substitution. Planner verifies with Phase 94 author.
   - **RESOLVED in:** Plan 18 (W4 banned-verb lint + runtime gate) wires BEFORE Phase 94 citation gate per recommendation.

6. **D-CE-08 `profile_grounding_strict_mode` rollout staging ?**
   - What we know : flag default = false, staging strict=true → prod strict=false (1 release) → prod strict=true.
   - What's unclear : exact « 1 release » duration in MINT cadence.
   - **Recommendation :** ship behind flag in W1 with strict=false default ; flip to true on staging at W1 close ; prod flip at W2 close or with W3 PR-1.
   - **RESOLVED in:** Plan 01 (W1 shared helpers) carries the `PROFILE_GROUNDING_STRICT_MODE` env flag wiring + dual-path `raise_incomplete_as_422` ; Plans 02/03/06 inherit + parametrize tests over both modes ; Plan 20 (W4 wave-close) tracks the staging→prod flip cadence as G2 checkpoint.

---

## Sources

### Primary (HIGH confidence — codebase verified 2026-05-16)
- `services/backend/app/api/v1/endpoints/coach_chat.py:851-889` — `_PROFILE_SAFE_FIELDS` canonical
- `services/backend/app/api/v1/endpoints/coach_chat.py:1478-1573` — `_INTENT_KEYWORDS`, `_classify_user_intent`, `_TOOL_ELIGIBLE_*`
- `services/backend/app/api/v1/endpoints/arbitrage.py:163-234` — hypothesis C smoking gun
- `services/backend/app/services/coach/coach_tools.py:637-722` — 5 chip-emitters + get_regulatory_constant
- `services/backend/app/services/coach/bundle_compiler.py:1-269` — full bundle compiler
- `services/backend/app/services/coach/bundles/_base.py` — `BundleBase` contract
- `services/backend/app/models/profile_model.py` — `ProfileModel.data: MutableDict`
- `services/backend/app/core/auth.py:23-129` — `get_current_user` / `require_current_user`
- `services/backend/app/core/database.py:35` — `get_db()` yield-style dependency
- `services/backend/app/models/scenario.py` — scenarios table schema
- `services/backend/alembic/versions/p95_dag_invalidation.py` — additive migration precedent
- `services/backend/app/observability/coach_breadcrumbs.py` — Sentry breadcrumb pattern
- `services/backend/app/models/coach_tools/_response.py` (sha `a55b5469` on `feature/wave-1c-A3-missing-fields-handshake`) — A3 envelope canonical
- `services/backend/pyproject.toml` — dependency pins verified
- `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md` — 20 D-CE-XX
- `.planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md` — 49/57 hypothesis C confirmed
- `.planning/decisions/2026-05-16-calc-engine-v1-panel-synthesis.md` — verdicts table + 11 overrides + 6 findings
- `.planning/decisions/2026-05-16-calc-engine-matrix.md` — 11-domain coverage matrix
- `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A3-PLAN.md` — A3 patterns

### Primary (HIGH confidence — official documentation)
- Anthropic Tool Search Tool : `platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool`
- Anthropic advanced tool use announcement : `anthropic.com/engineering/advanced-tool-use`
- Pydantic v2 fields docs : `pydantic.dev/docs/validation/latest/concepts/fields/`
- Pydantic v2 JSON schema : `pydantic.dev/docs/validation/latest/concepts/json_schema/`
- Pydantic v2 unions / discriminated : `docs.pydantic.dev/latest/concepts/unions/`
- Pydantic v2 config : `docs.pydantic.dev/latest/api/config/`
- FastAPI Background Tasks : `fastapi.tiangolo.com/tutorial/background-tasks/`
- FastAPI dependencies : `fastapi.tiangolo.com/tutorial/dependencies/`
- Python asyncio sync primitives : `docs.python.org/3/library/asyncio-sync.html`
- Python AST : `docs.python.org/3/library/ast.html`
- Alembic CONCURRENTLY : `lyjia.us/blog/p/alembic-migrations-outside-transaction-block`
- PostgreSQL CREATE INDEX : `postgresql.org/docs/current/sql-createindex.html`

### Secondary (MEDIUM confidence — verified against official source)
- LiteLLM Tool Search Tool integration : `docs.litellm.ai/docs/providers/anthropic_tool_search` — confirms beta header + request shape
- Medium @DebaA tool definition bloat fix : `medium.com/@DebaA/anthropic-just-shipped-the-fix-for-tool-definition-bloat-77464c8dbec9`
- Arcade.dev Anthropic Tool Search analysis : `blog.arcade.dev/anthropic-tool-search-claude-mcp-runtime`
- Python tutorials Pydantic detect missing-vs-null : `pythontutorials.net/blog/pydantic-detect-if-a-field-value-is-missing-or-given-as-null/`
- Roman Imankulov FastAPI Pydantic unset values : `roman.pt/posts/handling-unset-values-in-fastapi-with-pydantic/`
- DataLeadsFuture asyncio sync primitives : `dataleadsfuture.com/mastering-synchronization-primitives-in-python-asyncio-a-comprehensive-guide`
- OneUptime request coalescing : `oneuptime.com/blog/post/2026-01-25-request-coalescing/view`
- Sentry FastAPI scheduling answer : `sentry.io/answers/schedule-tasks-with-fastapi/`
- SQLAlchemy Alembic discussion #1461 : `github.com/sqlalchemy/alembic/discussions/1461`
- Rajan Sahu APScheduler + FastAPI : `rajansahu713.medium.com/implementing-background-job-scheduling-in-fastapi-with-apscheduler-6f5fdabf3186`

### Tertiary (LOW confidence — single source / unverified at MINT scale)
- Growth Method « Tool Search Not Ready for Production » : `growthmethod.com/anthropic-tool-search/` — opinion piece, mitigated by D-CE-01 adapter
- Issue #25212 ToolSearch Bedrock incompatibility : `github.com/anthropics/claude-code/issues/25212` — informs SkillBundleOnly fallback choice
- arXiv 2504.11168 + 2512.01353 (lexical guardrail evasion rates) — informs D-CE-16 NFKC normalization

---

## Metadata

**Confidence breakdown :**
- Standard stack mechanics (FastAPI / Pydantic v2 / Alembic / asyncio / Anthropic SDK) : HIGH — verified in pyproject.toml + codebase precedents.
- W1 grounding pattern (`_resolve_defaults` + 422 envelope) : HIGH — A3 envelope already shipped, `model_fields_set` semantics verified.
- W2 ToolRegistryAdapter (Anthropic-side) : MEDIUM — Anthropic docs verified, no MINT-scale pilot.
- W2 bundle_compiler extension : HIGH — full pattern verified in `bundle_compiler.py` + 7 existing bundles.
- W3 cache + index + singleflight : HIGH — Alembic + asyncio patterns verified + scenarios table already exists.
- W4 metrics : MEDIUM — Prometheus-client choice vs Sentry not yet operator-confirmed (Open Question 1).
- W4 banned-verb runtime gate : MEDIUM — placement BEFORE vs AFTER Phase 94 citation gate not yet confirmed (Open Question 5).
- AST scanner : MEDIUM — magic-comment vs decorator choice is planner discretion.
- Lucidity payloads (D-CE-15) : HIGH — Pydantic v2 discriminated union pattern already used in A3 envelope.

**Research date :** 2026-05-16
**Valid until :** 2026-06-16 (30 days — stable backend stack ; Anthropic Tool Search beta header is the main external dependency, monitor anthropic.com changelog).
