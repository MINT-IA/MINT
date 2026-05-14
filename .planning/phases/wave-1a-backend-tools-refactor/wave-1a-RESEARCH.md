---
name: wave-1a-RESEARCH
description: Research for Wave 1a backend tools refactor. Primary source is sub-agent B audit (2026-05-14-coach-tools-inventory.md) — Wave 0 deliverable that already inventoried 28 tools + anti-hallucination infra (95% cabled). This RESEARCH.md pulls forward the planning-relevant sections and adds Validation Architecture for Nyquist gate.
metadata:
  type: research
  phase: wave-1a-backend-tools-refactor
  date: 2026-05-14
  primary_source: .planning/audit/2026-05-14-coach-tools-inventory.md
---

# Wave 1a Research

> **Note on research provenance:** Sub-agent B already produced a 188-line audit (`.planning/audit/2026-05-14-coach-tools-inventory.md`) covering all 28 coach tools, Wave 1a/b/c scope refinement, and anti-hallucination infra coverage (~85% cabled). That document IS the research output. This RESEARCH.md surfaces the planning-relevant sections + adds Validation Architecture (Nyquist gate D-08).

## Section 0 — How to read this phase

1. **Read first:** `.planning/audit/2026-05-14-coach-tools-inventory.md` (sub-agent B audit, comprehensive)
2. **Then read:** This RESEARCH.md for Validation Architecture
3. **Then read:** `wave-1a-CONTEXT.md` for locked decisions D-01 → D-17

## Section 1 — What the audit settled

Verbatim recap from sub-agent B audit:
- **6/7 READ-numeric tools confirmed Y refactor:** `get_budget_status`, `get_retirement_projection`, `get_cross_pillar_analysis`, `get_cap_status`, `get_couple_optimization`, `retrieve_memories`.
- **1/7 already wired:** `get_regulatory_constant` → `RegulatoryRegistry`.
- **2/6 blocked on Python equivalent:** `get_cap_status` (option b decided in CONTEXT D-09), `get_couple_optimization` (option a port decided in CONTEXT D-02).
- **Effort refined:** ~10.5 j total Wave 1a (vs design doc "1 sem" — re-aligned upward).
- **Wave 1b is 85% câblé** under different names (`HallucinationDetector` S34 + `citation_parser.gate` Phase 94 + bundles Phase 93.5).

## Section 2 — Tool-by-tool implementation pattern

For each of the 6 refactored tools, the pattern is:

```
coach_chat.py (dispatcher)
  ├─ check settings.COACH_TOOL_SERVER_SIDE_<NAME>_ENABLED
  ├─ if OFF → return _format_<tool>(ctx)   [legacy path]
  └─ if ON  →
       1. fetch ProfileModel via profile_id
       2. call chained app.services.* method(s)
       3. compute inputs_hash via rfc8785 + SHA-256
       4. wrap in Pydantic v2 camelCase response
       5. emit Sentry breadcrumb coach.tool.<name>.invoked
       6. return response.model_dump_json(by_alias=True)
```

## Section 3 — Failure modes the planner must address

From sub-agent B Section 7 caveats:

1. **`COACH_CITATION_GATE_ENABLED` prod state unknown** (audit caveat §7.7). Wave 1a must NOT depend on this flag — staged rollout uses per-tool flags D-05 instead.
2. **`memory_block` provenance unclear** in legacy `_handle_retrieve_memories`. Wave 1a plan-05 (`retrieve_memories`) must define a stable contract for what the wrapper expects and produces — verified by parity test.
3. **`tax_saving_potential` derivation** in legacy `_format_cross_pillar_analysis(ctx)` may come from Flutter financial_core. Wave 1a plan-03 must confirm Python `arbitrage/*` services produce equivalent value, else add a derivation method.
4. **`claude_coach_service.py` legacy path** (lines not lu by audit) may call `ComplianceGuard.validate` on output — Wave 1a server-side path must NOT bypass it.
5. **Sentry helper availability** — sub-agent B did not confirm if a stable Sentry breadcrumb helper exists. Plan-08 (rollout) verifies and wires it (S98 observability fallout).

## Section 4 — Build vs reuse summary

| Layer | Reuse | Build new |
|---|---|---|
| Number extraction (regex) | `HallucinationDetector` patterns + `citation_parser` regex | — |
| Citation gate runtime | `citation_parser.gate` | — |
| Closed-world registry | `CitationRegistry` baseline 18 keys | Wave 1b extends (NOT Wave 1a) |
| Retry / re-prompt | `_run_narrator_with_gate` | — |
| Honest fallback | `FALLBACK_TEMPLATED_TEXT` | — |
| Budget snapshot service | `CoachingEngine` class exists | NEW `compute_budget_snapshot` method |
| Retirement projection service | 3 services exist | NEW chaining function |
| Cross-pillar analysis | `arbitrage/*` + `pillar_3a_deep/*` exist | NEW chaining + `tax_saving_potential` derivation if missing |
| CoupleOptimizer | Flutter source only | **NEW Python port** (parity ±0.01 CHF) |
| Memory retrieval | `ProfileModel.data` + `CoachInsightRecord` rows | **NEW BM25 wrapper** `app.services.memory.bm25_index` |
| Inputs hash | `grounding_pack.compute_inputs_hash` (Phase 95) | — |
| Response schemas | Pydantic v2 helpers exist | NEW per-tool models in `app/models/coach_tools/` |

## Validation Architecture (Nyquist gate D-08)

> Required structure per workflow step 5.5. This drives `VALIDATION.md` creation.

### Validation surfaces

Wave 1a has 3 validation surfaces:

1. **Unit-test surface** — per-service Python services (`CoupleOptimizer` port, `bm25_index`, `compute_budget_snapshot`, chained retirement projection).
2. **Parity surface** — Flutter legacy formatter vs Python server-side compute, on 5 seed fixture profiles.
3. **Integration surface** — end-to-end dispatcher path with flag ON, asserting Pydantic response shape + `inputs_hash` presence + Sentry breadcrumb emission.

### Sampling rule (Nyquist)

For each refactored tool, the parity surface MUST include at minimum:
- **1 Julien-archetype fixture** (cross-border worker, age ~32, married, mid-income).
- **1 Lauren-archetype fixture** (independent_no_lpp, age ~28, single, freelance income).
- **1 edge case** — boundary value chosen per-tool:
  - `get_budget_status`: monthly_expenses > monthly_income (negative surplus, months_liquidity = 0).
  - `get_retirement_projection`: age = 65 (rente immediate), replacement_ratio < 50%.
  - `get_cross_pillar_analysis`: profile with `lpp_buyback_max = 0` (no buyback room).
  - `get_couple_optimization`: profile with `couple_optimization = null` (single user).
  - `retrieve_memories`: empty `CoachInsightRecord` table for user (fallback to ProfileModel.data).
  - `get_cap_status`: cap text containing CHF without `{{cite:}}` (garde must redact).

This 3-fixture-per-tool minimum × 6 tools = 18 parity cases, satisfies the "≥10 unit/service" CLAUDE.md §4 rule when combined with per-service unit tests.

### Acceptance criteria (mechanical, gate-able)

| Criterion | Verifiable via |
|---|---|
| Per-tool Python service exists and is importable | `python -c "from app.services.X import Y"` exits 0 |
| Response Pydantic model defined per tool | `grep -r "class.*Response.*BaseModel" services/backend/app/models/coach_tools/ \| wc -l` ≥ 5 |
| Dispatcher reads flag | `grep -c "COACH_TOOL_SERVER_SIDE_.*_ENABLED" services/backend/app/api/v1/endpoints/coach_chat.py` ≥ 5 |
| Parity test harness exists | `test -f services/backend/tests/test_coach_tools_parity.py` |
| Seed fixtures present | `wc -l services/backend/tests/fixtures/coach_tools_parity_v1.jsonl` ≥ 18 |
| All parity tests pass | `pytest services/backend/tests/test_coach_tools_parity.py -q` exit 0 |
| Full backend suite ≥ 6617 | `pytest services/backend/ -q` exit 0 with count ≥ 6617 |
| Banned-terms lint clean on touched files | `python tools/checks/banned_terms_python.py services/backend/app/services/{coaching_engine,memory,couple_optimizer}.py services/backend/app/services/retirement/*.py services/backend/app/services/arbitrage/*.py` exit 0 |
| Accent lint clean | `python tools/checks/accent_lint_fr.py <touched files>` exit 0 |
| No new ARB diff | `git diff --stat apps/mobile/lib/l10n/` empty |
| Sentry breadcrumbs emitted in integration test | `grep -c "coach.tool.*.invoked" <test capture>` ≥ 5 |

### What CANNOT be auto-validated (G2 device only)

- Real coach chat session on staging triggering each of the 5 tools and observing the response includes `inputs_hash` + correct numeric values. Wave 1a deliverable: Maestro flow `coach_tools_server_side_smoke.yaml` (G1) that scripts this; Julien G2 confirmation post-merge.

---

*Research synthesis: 2026-05-14. Primary research artifact remains `.planning/audit/2026-05-14-coach-tools-inventory.md` (sub-agent B Wave 0 deliverable).*
