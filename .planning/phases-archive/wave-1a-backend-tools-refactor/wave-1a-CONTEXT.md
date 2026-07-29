---
name: wave-1a-CONTEXT
description: Locked decisions + source-of-truth refs + canonical references for Wave 1a backend tools refactor. Synthesized from ADR 2026-05-14-wave-plan-final + Sub-agent B audit (28 tools inventory + anti-hallucination infra). 6/7 READ-numeric coach tools must recompute server-side via Python services; CapEngine stays Flutter (option b) per refined effort estimate.
metadata:
  type: context
  phase: wave-1a-backend-tools-refactor
  date: 2026-05-14
  source: PRD-equivalent (ADR + audit) — no /gsd-discuss-phase needed
---

# Phase Wave 1a: Backend Tools Refactor — Context

**Gathered:** 2026-05-14
**Status:** Ready for planning
**Source:** ADR-derived (`.planning/decisions/2026-05-14-wave-plan-final-with-gain-reinvest.md` + `.planning/audit/2026-05-14-coach-tools-inventory.md` sub-agent B)

<domain>
## Phase Boundary

**What Wave 1a delivers:**
- 5/6 READ-numeric coach tools (`get_budget_status`, `get_retirement_projection`, `get_cross_pillar_analysis`, `get_couple_optimization`, `retrieve_memories`) recompute their numeric payload server-side via Python services in `services/backend/app/services/` instead of reading Flutter-injected `ctx` data.
- 1/6 (`get_cap_status`) keeps Flutter source per refined effort decision (option b) BUT gains a runtime garde that rejects `cap_expected_impact` containing CHF without `{{cite:}}`.
- 1/7 (`get_regulatory_constant`) already wired on `RegulatoryRegistry` — Wave 1a only adds confirmation tests (not refactor work).
- All 6 refactored tools emit JSON payloads with `inputs_hash` (SHA-256 of input profile slice) so Phase 95 DAG-INVALIDATION can detect staleness and so Wave 1b can attach `source_kind="tool_call_id"` citations.
- Parity tests Flutter (legacy `_format_*` formatters reading `ctx`) ↔ Python (new server-side) within ±0.01 CHF / ±0.1pt% on the 6 refactored tools, using existing `tests/coach_swiss_parity_v1.yaml` style fixtures (20 paires Q&A scoped to Wave 1c — Wave 1a only ships the parity *infrastructure* and seed fixtures).
- A per-tool rollback flag `COACH_TOOL_SERVER_SIDE_<TOOL_NAME>_ENABLED` (default OFF on prod, ON on staging) for staged rollout — same pattern as `COACH_CITATION_GATE_ENABLED`.

**What Wave 1a does NOT deliver (deferred):**
- Wave 1b infra (extension `CITATION_REGISTRY` with `source_kind="tool_call_id"` + numeric-claim → tool-name dispatcher) — separate phase `wave-1b-planner-refined`.
- Wave 1c (20 paires Q&A parity full suite + FactRef/ProjRef/LegalRef chips visible UI + `COACH_CITATION_GATE_ENABLED` flag flip on prod) — separate phase `wave-1c-citation-gate-ui-parity`.
- CapEngine Flutter → Python port (decided option b — keep Flutter source). If a future ADR re-opens this, it would be a new phase.
- New ARB keys (this phase is pure backend; no UI strings touched).
- Calc-rigor extension to LPP/AVS projection (deferred to backlog 999.4 per CONTEXT 92.5 D-03).

</domain>

<decisions>
## Implementation Decisions

### D-01 — Phase scope = sub-Wave 1a only (no 1b, no 1c)
**Locked.** Wave 1a ships server-side recompute for the 6 tools + parity infra. Wave 1b and 1c are separate GSD phases. Reason: Julien typed `wave-1a` explicitly in the /gsd-plan-phase invocation, and the ADR effort estimate splits 1a / 1b / 1c into discrete deliverables (10.5j / 3.5j / 2-3j).

### D-02 — Per-tool Python service mapping
**Locked from sub-agent B audit Section 4.** Each tool maps to one or more existing Python services. NO new files in `app.services.coach.*` — extend or chain existing services.

| Tool | Python service(s) to chain | Notes |
|---|---|---|
| `get_budget_status` | `app.services.coaching_engine.CoachingEngine.compute_budget_snapshot(profile_id)` (NEW method on existing class) | Existing class; method to add. Uses financial_core port logic (already known FR → Python). |
| `get_retirement_projection` | Chain `app.services.retirement.avs_estimation_service.AvsEstimationService` + `app.services.retirement.lpp_conversion_service.LppConversionService` + `app.services.retirement.retirement_budget_service.RetirementBudgetService` | All 3 services already exist. Wave 1a wires them together with shared profile input. |
| `get_cross_pillar_analysis` | `app.services.arbitrage.allocation_annuelle.compare_allocation_annuelle` + `app.services.arbitrage.rachat_vs_marche` + `app.services.pillar_3a_deep.*` | All exist. `tax_saving_potential` derivation must reuse `financial_core` parity (no re-implementation per CLAUDE.md rule 4). |
| `get_cap_status` | **NOT refactored.** Stays Flutter-sourced via `ctx["cap_*"]`. Garde added: reject response if `cap_expected_impact` contains CHF regex without `{{cite:}}` adjacent. | Option b per refined estimate. Cap is coaching text, not central CHF claim. |
| `get_couple_optimization` | NEW `app.services.couple_optimizer.CoupleOptimizer` port from Flutter | Flutter `CoupleOptimizer` lives in `apps/mobile/lib/services/financial_core/couple_optimizer.dart` (verify path). Port = mirror methods + parity test ±0.01 CHF on `saving_delta`, `monthly_reduction`, `annual_delta`. |
| `get_regulatory_constant` | **Already wired** on `app.services.regulatory.registry.RegulatoryRegistry` (sub-agent B §1 line 39) | NO refactor — only Wave 1c validation. Wave 1a tests confirm dispatcher still routes correctly. |
| `retrieve_memories` | NEW thin wrapper `app.services.memory.retrieve(topic, user_id, k=5)` over existing `ProfileModel.data` + `CoachInsightRecord` DB | Karpathy wiki pattern per memory `project_user_profile_wiki`: per-user pages, BM25 lookup over `(topic + insight body)`, NO vector embedding. Defer pgvector to Wave 2+ if BM25 insufficient. |

### D-03 — Response schema is Pydantic v2 camelCase
**Locked.** Per CLAUDE.md identity §1 (backend AGENT contract: FastAPI + Pydantic v2 camelCase). Each tool defines its response model in `services/backend/app/models/coach_tools/` (new directory) with `model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)`. Examples:

```python
class BudgetSnapshotResponse(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)
    monthly_income: Decimal      # serializes as "monthlyIncome"
    monthly_expenses: Decimal    # serializes as "monthlyExpenses"
    months_liquidity: float
    inputs_hash: str             # SHA-256 hex of profile slice
    computed_at: datetime
```

### D-04 — `inputs_hash` is SHA-256 of canonical-JSON profile slice
**Locked from Phase 95 precedent.** Each tool defines its `_input_slice(profile) -> dict` (the minimal fields it reads), serializes via `rfc8785` canonical JSON, hashes SHA-256 hex. The hash goes into the response. Reuse `app.services.coach.grounding_pack.compute_inputs_hash` if it exists — DO NOT re-implement. Wave 1b will consume this hash to attach `source_kind="tool_call_id"` citations.

### D-05 — Per-tool rollback flag
**Locked.** Settings flag per tool: `COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED`, `_RETIREMENT_PROJECTION_ENABLED`, `_CROSS_PILLAR_ENABLED`, `_COUPLE_OPTIMIZATION_ENABLED`, `_RETRIEVE_MEMORIES_ENABLED`. Default OFF in `settings.py` (pre-stage) ; staging deploy enables them by ENV ; prod stays OFF until Wave 1c validation. Dispatcher in `coach_chat.py` checks flag, falls back to legacy `_format_*(ctx)` if OFF (no breaking change for ongoing traffic).

### D-06 — Parity test infrastructure (Wave 1a delivers infra; Wave 1c delivers 20 paires)
**Locked.** Wave 1a ships:
- `services/backend/tests/test_coach_tools_parity.py` — pytest harness that, for each refactored tool, loads a fixture profile from `services/backend/tests/fixtures/coach_tools_parity_v1.jsonl` (NEW), runs both legacy formatter (passing pre-computed `ctx` from fixture) and new server-side path, asserts numeric fields within tolerance.
- Tolerances: CHF ±0.01, percent ±0.1pt, ratio ±0.001, duration months ±0 (exact).
- Seed corpus: 5 fixtures (1 per refactored tool). Wave 1c extends to 20 paires Q&A.

### D-07 — `retrieve_memories` BM25 over wiki, not pgvector
**Locked from memory `project_user_profile_wiki` (Julien 2026-05-13).** Implementation: per-user index `app.services.memory.bm25_index(user_id)` over `(insight.body, insight.topic_tags)` from `CoachInsightRecord` rows. Return top-k=5 by BM25 score with `score >= 0.3` floor. If no results, fall back to `ProfileModel.data` keys matching `topic`. NO LLM call, NO vector embedding.

### D-08 — Dispatcher placement: extend `coach_chat.py` formatters
**Locked.** Each refactored tool gets a sibling `_compute_<tool_name>(profile_id, ctx)` function next to the existing `_format_<tool_name>(ctx)` in `coach_chat.py:2249-2471`. Dispatcher checks `settings.COACH_TOOL_SERVER_SIDE_<NAME>_ENABLED` and calls the new path if ON, legacy `_format_*` if OFF. The new path internally calls `app.services.*` (chained per D-02), packages the Pydantic response with `inputs_hash`, and returns JSON-serialized string.

### D-09 — `get_cap_status` garde (not refactor)
**Locked.** No server-side recompute. Add `_validate_cap_response(rendered_text)` middleware: if `rendered_text` matches `_RE_CURRENCY` (from `citation_parser.py:68-91`) AND no `{{cite:<key>}}` within ±80 chars, replace the offending CHF token with `[montant indisponible]` and emit Sentry breadcrumb `coach.cap.cap_chf_uncited`. Default ON for Wave 1a (independent flag `COACH_CAP_CHF_GARDE_ENABLED`, default ON).

### D-10 — No new ARB keys / no UI changes
**Locked.** Wave 1a is pure backend. Any user-facing copy stays unchanged (the formatters today emit French strings; the Python services emit the same French strings via existing `services/backend/app/i18n/` if present, else verbatim from formatter template literals copied byte-identical). NO `flutter gen-l10n`. NO ARB diff.

### D-11 — Test budgets
**Locked.** Wave 1a adds:
- ≥18 unit tests on `app.services.couple_optimizer.*` (port-from-Flutter parity)
- ≥10 unit tests on `app.services.memory.retrieve` (BM25 ranking + floor)
- ≥8 integration tests in `test_coach_tools_parity.py` (5 seed fixtures × 6 tools = up to 30 cases ; minimum 8 covering Julien + Lauren goldens × 4 tools).
- ≥5 tests on the `get_cap_status` CHF-garde (cite present / absent / boundary).
- All flow through existing `services/backend/tests/conftest.py` Pydantic setup ; new fixtures in `services/backend/tests/fixtures/coach_tools_parity_v1.jsonl`.
- **Total new backend tests target: ≥50.** Aligns with CLAUDE.md §4 dev rule "≥10 unit/service" applied across 5 services.

### D-12 — Atomic per-tool plan structure
**Locked.** ONE plan per refactored tool (5 plans for 5 refactored tools) + 1 plan for `get_cap_status` garde + 1 plan for parity infra + 1 plan for rollout/5-gate close + 1 Wave-0 scaffolding plan = **9 plans total** (8 user-facing + 1 Wave-0 prerequisite added during checker iteration 1 to eliminate parallel-write races on shared files). Each plan is autonomous (no checkpoint, except plan-08), wave-parallelizable where independent. Dependency graph:
- **Wave 0 (parallel-safe scaffolding):** plan-00 (creates `coach_tools/` + `memory/` + `couple_optimizer/` package markers, adds all 6 settings flags as ONE block, establishes dispatcher slot in `coach_chat.py`, ships `emit_coach_tool_breadcrumb` + `hash_profile_id` shared helpers).
- **Wave 1 (parallel — true parallel-safe after plan-00):** plan-01 (`budget`), plan-02 (`retirement`), plan-03 (`cross_pillar`), plan-04 (`couple_optimization` port), plan-05 (`retrieve_memories`), plan-06 (`cap_status` garde). All 6 depend_on `[wave-1a-00]`. Each inserts into pre-existing slots, no shared-file race.
- **Wave 2 (serial, depends Wave 1):** plan-07 (`coach_tools_parity_v1.jsonl` fixtures + harness — needs all tools ready).
- **Wave 3 (close-out, depends Wave 2):** plan-08 (rollout flags wiring + 5-gate close + SUMMARY.md).

### D-13 — Banned-terms + accent + LSFin guardrails
**Locked.** ALL emitted strings (server-side payloads) MUST pass `tools/checks/banned_terms_python.py` + `tools/checks/accent_lint_fr.py` lint (CLAUDE.md rules 1, 2, 5). The Python services that render user-facing French strings copy them VERBATIM from the legacy `_format_*` formatters to guarantee byte-identical output (zero LSFin regression risk). Plan-08 (5-gate close) explicitly runs both lints on the diff.

### D-14 — 5-gate exit per Wave 1a phase close
**Locked from memory `feedback_perimeter_5_gates`.** No "ready" claim before all 5 gates green:
- **G1** — Maestro flow `tools/simulator/flows/maestro-perfect-set/coach_tools_server_side_smoke.yaml` (NEW, single flow that taps a coach card invoking each refactored tool with staging flag ON, captures responses).
- **G2** — Julien device walkthrough on TestFlight (`feature/S99.1-…` merged to dev → staging build).
- **G3** — dev CI green (`flutter analyze`, `flutter test`, `pytest -q`, schemathesis on touched routes if any new endpoints added — Wave 1a doesn't add endpoints, but dispatcher path adds JSON contract).
- **G4** — Regression: backend ≥ baseline (currently ~6567 from STATE.md) + 50 new = target ≥6617 pytest passed. Flutter regression unchanged (this is backend-only).
- **G5** — LSFin banned-terms lint + accent_lint_fr.py + (N/A for Wave 1a since no ARB diff) `validate_arb_parity` confirmation that ARB count unchanged.

### D-15 — Sentry breadcrumbs per tool dispatch
**Locked.** Each server-side tool path emits `coach.tool.<name>.invoked` with `inputs_hash`, `profile_id_hashed`, `elapsed_ms`, `flag_state` (ON/OFF). Reuse `app.observability.sentry` helper if exists. Aligns with Phase S98 observability infra.

### D-16 — Tool input contract is `(profile_id, ctx)`
**Locked.** Each `_compute_<tool>(profile_id, ctx)` reads `profile_id` from request (`coach_chat.py` request body field; verify name during planning), fetches `ProfileModel.get(profile_id)` via DB session, passes profile to chained services. `ctx` is still passed in case fallback to legacy `_format_*` is needed (rollback flag OFF). Profile fetch is read-only — no DB writes in Wave 1a.

### D-17 — No port of CapEngine
**Locked option b.** Sub-agent B estimated 3-5 j for port. ADR decided keep-Flutter to bank effort. Future re-litigation only if `coach.cap.cap_chf_uncited` Sentry breadcrumb fires > 5/day on prod for ≥1 week (re-open via `/gsd-add-phase` of `wave-1a.5-cap-engine-port`).

### Claude's Discretion
- Pydantic model field naming inside services (Python idiomatic) — camelCase only at API surface via `to_camel` alias generator.
- BM25 library choice for `retrieve_memories` — recommend `rank_bm25` (battle-tested, pure Python, no native deps for Railway compat) ; alternatives `whoosh` or pure-numpy if `rank_bm25` fails Railway build.
- Exact `_input_slice(profile)` fields per tool — derive from what the legacy `_format_*` reads from `ctx`, mirror it 1:1, validated by parity test.
- Fixture profile structure for `coach_tools_parity_v1.jsonl` — extend existing `calc_diff_v1.jsonl` shape if compatible, else parallel format.
- Whether to use existing `ToolCategory` enum extension for the new "server-side READ" sub-category vs introducing a per-tool flag — recommend per-tool flag (simpler, granular rollback).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Wave plan + ADR scope
- `.planning/decisions/2026-05-14-wave-plan-final-with-gain-reinvest.md` — Wave 0-4 final plan, locked 2026-05-14 by Julien.
- `.planning/audit/2026-05-14-coach-tools-inventory.md` — Sub-agent B audit (28 tools + anti-hallucination infra audit). **PRIMARY RESEARCH ARTIFACT — read first.**
- `.planning/decisions/2026-05-14-ds-v2-propagation-wave-1-5-bigbang.md` — Wave 1.5 frame (NOT this phase's scope, but context for "what comes after Wave 1a").

### Coach tools source-of-truth code (read-only refs)
- `services/backend/app/services/coach/coach_tools.py:126-1188` — 28 tools schema (single source of truth).
- `services/backend/app/api/v1/endpoints/coach_chat.py:1871-2098` — dispatcher (`_handle_*` per tool).
- `services/backend/app/api/v1/endpoints/coach_chat.py:2249-2471` — formatters (`_format_*` per tool). **This is where Wave 1a adds `_compute_*` siblings.**

### Anti-hallucination infra (consumers of Wave 1a outputs)
- `services/backend/app/services/coach/hallucination_detector.py` — consumes `known_values` dict (Wave 1a produces it).
- `services/backend/app/services/coach/citation_parser.py:524-710` — Phase 94 gate (Wave 1b extends with `source_kind="tool_call_id"`).
- `services/backend/app/services/coach/citation_registry.py:54` — `source_kind` enum (Wave 1b extension target).
- `services/backend/app/services/coach/grounding_pack.py` — Phase 95 `inputs_hash` pattern.

### Python services Wave 1a chains
- `services/backend/app/services/coaching_engine.py` — `CoachingEngine` (add `compute_budget_snapshot`).
- `services/backend/app/services/retirement/avs_estimation_service.py`
- `services/backend/app/services/retirement/lpp_conversion_service.py`
- `services/backend/app/services/retirement/retirement_budget_service.py`
- `services/backend/app/services/arbitrage/allocation_annuelle.py`
- `services/backend/app/services/arbitrage/rachat_vs_marche.py`
- `services/backend/app/services/pillar_3a_deep/` (whole package)
- `services/backend/app/services/regulatory/registry.py` — `RegulatoryRegistry` (already wired for `get_regulatory_constant`).

### Flutter source to mirror (CoupleOptimizer port)
- `apps/mobile/lib/services/financial_core/couple_optimizer.dart` (verify exact path during plan).

### Profile + memory layer
- `services/backend/app/models/profile.py` — `ProfileModel`.
- `services/backend/app/models/coach_insight.py` — `CoachInsightRecord`.

### Project rules
- `CLAUDE.md` §1 (identity) — backend = FastAPI + Pydantic v2 camelCase.
- `CLAUDE.md` §4 (dev rules) — tests ≥10/service, `flutter analyze` + `pytest -q` green.
- `CLAUDE.md` rule 1 (banned terms LSFin) — verbatim copy from legacy formatters to guarantee compliance.
- `CLAUDE.md` rule 2 (accents FR) — apply `accent_lint_fr.py`.
- `CLAUDE.md` rule 4 (financial_core reuse) — DO NOT re-implement `_calculate*` ; reuse Python `app.services.{retirement,arbitrage,pillar_3a_deep}` which already mirror financial_core logic for backend.
- `CLAUDE.md` §9 (0-trust protocol) — claims require deterministic citation ; PR opened ≠ shipped.

### Memory (Julien preferences applicable here)
- `feedback_perimeter_5_gates` — 5-gate close-out mandatory.
- `feedback_pre_push_checklist` — sig change → grep callers + regen + full test before push.
- `feedback_audit_corpus_before_patching` — Wave 1a outputs feed Wave 1c parity tests ; design corpus first.
- `feedback_gsd_workflow_default` — multi-perimeter work via GSD per phase artifact stack.
- `project_user_profile_wiki` — `retrieve_memories` is BM25 over wiki, not pgvector.
- `feedback_app_targets_staging_always` — staging deploy = Railway `mint-staging.up.railway.app` ; flag tests staging-first.

</canonical_refs>

<specifics>
## Specific Ideas

### Pydantic v2 response schema example (D-03)
```python
# services/backend/app/models/coach_tools/budget_snapshot.py
from decimal import Decimal
from datetime import datetime
from pydantic import BaseModel, ConfigDict
from fastapi.encoders import jsonable_encoder
from app.utils.case import to_camel  # existing helper, verify path

class BudgetSnapshotResponse(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)
    monthly_income: Decimal
    monthly_expenses: Decimal
    monthly_surplus: Decimal
    months_liquidity: float
    inputs_hash: str
    computed_at: datetime
```

### Dispatcher pattern in coach_chat.py (D-08)
```python
# coach_chat.py near line ~2240 (above _format_* group)
def _compute_budget_status(profile_id: str, ctx: dict) -> str:
    from app.core.config import settings
    if not settings.COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED:
        return _format_budget_status(ctx)  # legacy fallback
    profile = ProfileModel.get(profile_id)
    snapshot = CoachingEngine(profile).compute_budget_snapshot()
    response = BudgetSnapshotResponse(
        monthly_income=snapshot.income,
        monthly_expenses=snapshot.expenses,
        monthly_surplus=snapshot.income - snapshot.expenses,
        months_liquidity=snapshot.months_liquidity,
        inputs_hash=compute_inputs_hash({"income": float(snapshot.income), "expenses": float(snapshot.expenses)}),
        computed_at=datetime.utcnow(),
    )
    sentry_breadcrumb("coach.tool.budget_status.invoked", {
        "inputs_hash": response.inputs_hash,
        "elapsed_ms": ...,
    })
    return response.model_dump_json(by_alias=True)
```

### CapEngine garde regex (D-09)
```python
# coach_chat.py — middleware after _format_cap_status
from app.services.coach.citation_parser import _RE_CURRENCY  # reuse Phase 94 regex
def _validate_cap_response(rendered: str) -> str:
    for match in _RE_CURRENCY.finditer(rendered):
        window = rendered[max(0, match.start()-80) : match.end()+80]
        if "{{cite:" not in window:
            sentry_breadcrumb("coach.cap.cap_chf_uncited", {"snippet": window[:120]})
            rendered = rendered[:match.start()] + "[montant indisponible]" + rendered[match.end():]
    return rendered
```

### Parity fixture format (D-06)
```jsonl
{"fixture_id":"julien_v1","tool":"get_budget_status","profile":{...full ProfileModel slice...},"ctx_legacy":{"monthly_income":"7500.00","monthly_expenses":"5200.00",...},"expected":{"monthly_surplus":"2300.00","months_liquidity":4.6}}
```

### Tolerances (D-06)
- `Decimal` CHF fields: `abs(legacy - new) <= Decimal("0.01")`
- `float` percent fields: `abs(legacy - new) <= 0.1`
- `float` ratio fields: `abs(legacy - new) <= 0.001`
- Duration months `int`: exact equality.

### `retrieve_memories` BM25 (D-07)
```python
# app/services/memory/bm25.py
from rank_bm25 import BM25Okapi
def retrieve(topic: str, user_id: str, k: int = 5) -> list[InsightHit]:
    rows = CoachInsightRecord.query.filter_by(user_id=user_id).limit(500).all()
    corpus = [r.body + " " + " ".join(r.topic_tags or []) for r in rows]
    bm25 = BM25Okapi([c.split() for c in corpus])
    scores = bm25.get_scores(topic.split())
    ranked = sorted(zip(rows, scores), key=lambda x: -x[1])[:k]
    return [InsightHit(record=r, score=float(s)) for r, s in ranked if s >= 0.3]
```

</specifics>

<deferred>
## Deferred Ideas

- **CapEngine Flutter → Python port** — option b chosen, deferred. Re-litigation trigger: Sentry breadcrumb `coach.cap.cap_chf_uncited` > 5/day for ≥1 week.
- **pgvector for `retrieve_memories`** — BM25 first per Julien wiki preference. pgvector deferred to Wave 2+ if BM25 recall insufficient (measure via Wave 1c eval).
- **20 paires Q&A parity test suite** — Wave 1c scope. Wave 1a delivers infra (harness + 5 seed fixtures), Wave 1c extends.
- **`source_kind="tool_call_id"` CITATION_REGISTRY entries** — Wave 1b scope (consumes Wave 1a `inputs_hash` outputs).
- **Numeric-claim → tool-name dispatcher** — Wave 1b scope.
- **FactRef/ProjRef/LegalRef UI chips** — Wave 1c scope (Flutter).
- **Flag flip on prod** — Wave 1c. Wave 1a staging-only.
- **LPP/AVS calc-rigor extension (200-fixture)** — backlog 999.4 (Phase 92.6). Wave 1a uses existing 80-100 fixture surface only.

</deferred>

---

*Phase: wave-1a-backend-tools-refactor*
*Context gathered: 2026-05-14 via ADR Express Path (no /gsd-discuss-phase needed — scope locked in `.planning/decisions/2026-05-14-wave-plan-final-with-gain-reinvest.md` + sub-agent B audit)*
