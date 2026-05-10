---
description: Phase 95 MVP-DAG-INVALIDATION context — answers locked autonomously by PM Claude (Product Leader) from the 3-panel synthesis at `2026-05-10-95-96-autonomous-sequence-master.md`. Gathered via `/gsd-discuss-phase 95 --auto --chain` per Julien's 2026-05-10 autonomous-loop authorization.
---

# Phase 95: MVP-DAG-INVALIDATION - Context

**Gathered:** 2026-05-10 (auto-resolved by PM Claude from master synthesis 3-panel decisions)
**Status:** Ready for planning

<domain>
## Phase Boundary

Add the data-model layer that lets MINT projections invalidate cleanly when inputs change. Concretely : every projection emitted by `arbitrage_engine` + `monte_carlo_service` carries an `inputs_hash` (SHA256 of canonical JSON of the inputs that produced it) and a `superseded_by` pointer (UUID7 of the projection that replaces it when inputs mutate). The wrappers around `financial_core/` emit a `ProjectionGroundingPack` Pydantic v2 model that the narrator consumes through `_substitute_placeholders()` to substitute `{{cite:<key>}}` placeholders with grounded values (with Phase 94 `CITATION_REGISTRY` as fallback during the cohabitation window).

Out of scope (deferred to backlog 999.x): full Pareto front via NSGA-II (999.2), Sobol sensitivity (999.x — needs UI surface), HMM regime-switching Monte Carlo + CVaR + BVG mortality (999.1), full removal of `CITATION_REGISTRY` (deferred to a post-96 cleanup phase to avoid 3-way migration race).

In scope this phase : the bare bones that make Phase 96 narrator citations grounded in actual computed values instead of static-registry descriptions, and that let the DAG mark stale projections « superseded » when inputs change. Pareto reduced to a 3-point scalarisation MVP. Credible intervals via fréquentiste bootstrap on the existing Monte Carlo (Bayesian deferred).

</domain>

<decisions>
## Implementation Decisions

### inputs_hash algorithm
- **D-01:** SHA256 of canonical JSON serialization (RFC 8785 JCS, via the `jcs` Python package) of the input dict. JCS chosen over ad-hoc sort+separator because the spec is explicit about UTF-8 handling, integer/float edge cases, and Unicode normalization. If `jcs` ever becomes a maintenance risk, fallback : recursive key-sort + `json.dumps(separators=(",", ":"), ensure_ascii=False, sort_keys=True)` — documented in plan as the no-dep contingency.
- **D-02:** Floats quantized to `Decimal(2)` (two decimal places) BEFORE canonicalisation, applied via a recursive `_quantize_floats()` walker on the input dict. Eliminates IEEE 754 artifacts (`0.30000000000000004` vs `0.3`) that produce phantom hashes. CHF values quantize naturally to 2 decimals ; percentages already fit. Edge case : `np.float64` from numpy MC outputs must be cast to Python float before quantization (test fixture covers this).
- **D-03:** Python ↔ Dart hash parity validated by `tests/fixtures/hash_parity_50.jsonl` — 50 input dicts, each hashed Python-side AND via `dart compile exe` of `apps/mobile/tools/calc_harness/main.dart`, equality asserted in `tests/test_dag_invalidation/test_hash_parity.py`. Reuses the 92.5 calc_harness pattern. Centime/bps integer-scaling fallback documented in plan if floats prove non-deterministic across runtimes.

### superseded_by ID format
- **D-04:** UUID7 via `uuid.uuid7()` (Python 3.12+, RFC 9562). Time-ordered (first 48 bits = ms since Unix epoch), so `ORDER BY superseded_by ASC` reconstructs the supersession chain without a separate `created_at` column. Random tail (74 bits) makes collisions astronomically improbable.
- **D-05:** Storage : SQLite `TEXT(36)` column (the canonical hyphenated UUID string). The `projections` table gets two new nullable columns : `inputs_hash TEXT NULL` and `superseded_by TEXT NULL`. Both are ADDITIVE — zero default-value backfill on existing rows. Existing rows have `NULL` for both until the next projection touch invokes the new emitter and produces a fresh hash + ID.
- **D-06:** Migration : Alembic additive migration only. Forward (`upgrade head`) adds the two nullable columns ; downgrade (`downgrade -1`) drops them. Verified on a clone of the staging DB snapshot before merging (per sequencing-panel stop-condition #3).

### GroundingPack data contract
- **D-07:** Model name `ProjectionGroundingPack` (Pydantic v2, `frozen=True`, `extra="forbid"`). Lives at `services/backend/app/services/coach/grounding_pack.py` (already stubbed today — the Phase 95 work fills it in).
- **D-08:** Shape (top-level fields, all required unless noted):
  - `inputs_hash: str` — the SHA256 hex of the inputs that produced this pack.
  - `entries: dict[str, GroundingPackEntry]` — keyed by the SAME 18-key citation registry namespace as Phase 94 (e.g. `max_3a_2026`, `lpp_coordination_amount`, etc.) ; each entry is a sub-model with `value: Decimal`, `raw: dict` (the financial_core trace for that value), `source_ref: str` (e.g. `arbitrage_engine.compute_3a_ceiling`), `credible_low: Decimal | None`, `credible_high: Decimal | None`, `staleness_iso: str` (ISO 8601 timestamp).
  - `pareto_points: list[ParetoPoint]` — exactly 3 entries (D-10).
  - `what_ifs: dict[str, GroundingPackEntry]` — exactly 5 entries (D-11).
  - `legal_constraints: list[str]` — list of LIFD/LPP/LSFin article references that apply to this pack's inputs.
  - `superseded_by: str | None` — UUID7 if the pack has been replaced ; None otherwise.
- **D-09:** Cohabitation strategy : `_substitute_placeholders()` in citation_parser performs DOUBLE LOOKUP — first `pack.entries.get(key)`, fallback to `CITATION_REGISTRY.resolve(key)`. Both paths cohabit during Phase 95 + Phase 96 ; `CITATION_REGISTRY` removal is deferred to a post-96 cleanup phase to avoid a 3-way migration race.

### Pareto computation MVP
- **D-10:** 3-point scalarisation on the 3 MINT leviers (3a / rachat-LPP / amortissement-indirect) with 3 fixed pondérations :
  1. `fiscal-pure` : maximize current-year tax savings, ignore liquidity + ruin
  2. `liquidity-prioritized` : balance tax savings with 12-month cash buffer
  3. `ruin-reduction-prioritized` : balance tax savings with terminal-wealth-ruin-prob (P5)
  
  Each weight set produces one `ParetoPoint(weights, allocation, projected_outcomes: dict)`. NSGA-II via `pymoo` deferred to backlog 999.2 (no UI surface to consume the front in Phase 95).
- **D-11:** Sensitivity analysis : uni-variate ±10% per input → 5 `what_ifs` entries. Each entry is a `GroundingPackEntry` with the same shape as `entries`. Full Sobol indices via Saltelli sampling deferred to backlog 999.x (Saltelli needs N×(D+2) evals — overkill MVP, and no UI surface designed to show partial-variance indices yet).

### Credible intervals
- **D-12:** Bootstrap fréquentiste with 200 iterations on the existing `monte_carlo_service.dart` outputs. For each projected value, resample with replacement 200× across the MC trajectories → P5/P95 → populate `credible_low` and `credible_high` on the `GroundingPackEntry`. Narrator MUST annotate emitted intervals with « selon le modèle simplifié actuel » (anti-promise per LSFin — the iid-Gaussian assumption of the current MC is documented as insufficient ; HMM regime-switching is backlog 999.1).

### Plan count and wave split
- **D-13:** 2 plans, 2 waves :
  - **Wave 1 (~2d)** : `inputs_hash` + `superseded_by` + staleness flag on the 4 projection models + Alembic migration + Python ↔ Dart hash parity test fixture. Plan ID 95-01.
  - **Wave 2 (~2d, BLOCKS on Wave 1 merge)** : `ProjectionGroundingPack` emission by `financial_core/` wrappers + `_substitute_placeholders()` double-lookup + `pareto_points` + `what_ifs` + bootstrap CIs + narrator annotation. Plan ID 95-02.
  
  Verification is its own cycle (not a Wave 3) — phase verifier runs after both waves close.

### Compliance gates (pre-merge, both waves)
- **D-14:** Run `tools/checks/banned_terms_python.py` (extend to scan any new bundle prompt_fragment), `tools/checks/pii_fixture_scan.py` (new — greps AHV + phone patterns on every JSONL), `tools/checks/no_legal_admission_in_public_docs.py` (already wired ; verify it fires on ADR commits), `tools/checks/accent_lint_fr.py` (every FR string constant exits 0). Lefthook pre-commit + CI.
- **D-15:** `hash_parity_50.jsonl` — 50/50 fixtures show byte-identical hash Python vs Dart-compiled harness. Failure = blocker.
- **D-16:** G4 regression suite — backend pytest ≥ 6471 baseline (6448 post-94.1 baseline + ~25 new Phase 95 tests).
- **D-17:** G5 schema migration — alembic upgrade head + downgrade head both run clean on a clone of the staging DB snapshot. Manual verification step in PLAN.md, NOT automated this phase (deferred to Phase 96 CI).
- **D-18:** G1 Maestro — N/A for Phase 95 (backend-only). Deferred to Phase 96 G1.

### Claude's Discretion
- Internal class structure of the GroundingPack emitters within `financial_core/` wrappers — planner agent decides whether to introduce a helper module, extend existing classes, etc.
- Exact bootstrap RNG seed strategy — deterministic via `np.random.RandomState(42)` for reproducibility OR per-input seed derived from `inputs_hash` ; planner picks.
- Whether to extend the existing `services/backend/app/services/coach/grounding_pack.py` stub or replace it wholesale ; planner reads the stub first.
- Decimal precision policy for `value` field on `GroundingPackEntry` — `Decimal(2)` for CHF, `Decimal(4)` for percentages ; planner picks the unified policy.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Strategic / architectural anchors
- `.planning/decisions/2026-05-09-calc-first-llm-illumination.md` §N2 — strategic mandate for GroundingPack emission by `arbitrage_engine + monte_carlo_service`, foundational ADR
- `.planning/decisions/2026-05-10-phase-95-architect-panel.md` — full Phase 95 architecture brief (canonical decisions D-01..D-13 derive from this)
- `.planning/decisions/2026-05-10-phase-95-96-sequencing-compliance-panel.md` — compliance gates D-14, sequencing constraints D-13, stop conditions
- `.planning/decisions/2026-05-10-95-96-autonomous-sequence-master.md` — PM master synthesis ; the answer sheet that locked these decisions

### Phase 94 carry-forward (citation gate context)
- `.planning/phases/94-mvp-citation-gate/94-CONTEXT.md` — D-01..D-21 from Phase 94, esp. D-05/D-06 (5 source kinds), D-09 (reprompt grammar), D-14 (eval fixture shape)
- `.planning/phases/94-mvp-citation-gate/94-03-FLAG-FLIP-PROPOSAL.md` — NO-GO + PARTIAL disposition, prod-flip still blocked (informs Phase 95 cohabitation policy D-09)
- `services/backend/app/services/coach/citation_registry.py` line 8 comment — explicit handover « Phase 95 (DAG-INVALIDATION) will replace this module with the `GroundingPack` JSON contract » (the cohabitation policy D-09 supersedes this — replacement deferred post-96)
- `services/backend/app/services/coach/citation_parser.py:263` — `inputs_hash` field stub on `GatedResponse` (Phase 95 W1 populates it)

### Calc-first foundation (Dart financial_core)
- `apps/mobile/lib/services/financial_core/arbitrage_engine.dart` — 3a / rachat-LPP / amortissement comparison ; emits Pareto-eligible allocations
- `apps/mobile/lib/services/financial_core/monte_carlo_service.dart:222-225` — current iid-Gaussian MC implementation ; bootstrap CIs build on this
- `apps/mobile/tools/calc_harness/main.dart` — pure-Dart harness reused for hash-parity testing (pattern from Phase 92.5)
- `.planning/decisions/2026-05-10-pure-dart-calc-harness-extraction.md` — closure plan for the cascade-Flutter tech debt that today blocks `dart compile exe`. If unfixed, hash_parity_50.jsonl harness uses `flutter test` instead of `dart compile exe` (slower but functional)

### Backend / Python infrastructure
- `services/backend/app/services/coach/grounding_pack.py` — empty stub today (Phase 95 W2 fills it)
- `services/backend/app/services/coach/citation_parser.py` `_substitute_placeholders()` — extension point for double-lookup D-09
- `services/backend/app/services/coach/citation_registry.py` — 18-key namespace inherited by `ProjectionGroundingPack.entries` keys
- `services/backend/alembic/` — migration framework for D-06

### Compliance / Swiss
- `CLAUDE.md` §1 banned terms LSFin, §2 accents FR, §9 0-trust protocol
- `.claude/skills/mint-swiss-compliance/SKILL.md` — LSFin enforcement
- `tools/checks/{banned_terms_python,pii_fixture_scan,no_legal_admission_in_public_docs,accent_lint_fr}.py` — lefthook + CI lints
- `docs/AGENTS/swiss-brain.md` — Swiss financial law triplets (LIFD, LPP, AVS) for `legal_constraints` field on GroundingPack

### Phase 96 forward-link (consumer)
- `.planning/decisions/2026-05-10-phase-96-ux-panel.md` — Phase 96 consumes `ProjectionGroundingPack | None` (SOFT dependency per sequencing-panel §1). Phase 95 ships hard, Phase 96 reads.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `services/backend/app/services/coach/grounding_pack.py` — empty Pydantic stub already in the right namespace ; Wave 2 fills it
- `services/backend/app/services/coach/citation_parser.py:263` — `GatedResponse.inputs_hash: str | None = None` already stubbed ; Wave 1 populates it
- `services/backend/app/services/coach/citation_registry.py` — 18-key registry keys = the same namespace for `ProjectionGroundingPack.entries`
- `apps/mobile/tools/calc_harness/main.dart` — pure-Dart harness pattern from Phase 92.5, reusable for `hash_parity_50.jsonl` validation
- `apps/mobile/lib/services/financial_core/monte_carlo_service.dart:222-225` — existing iid-Gaussian MC ; bootstrap CIs wrap this
- `services/backend/alembic/` — migration framework for `inputs_hash` + `superseded_by` columns

### Established Patterns

- Pydantic v2 `frozen=True, extra="forbid"` is the project-wide schema invariant (citation_registry.py:51) — `ProjectionGroundingPack` follows this
- ADDITIVE migrations only (Phase 92 set this precedent) — Phase 95 nullable columns + zero backfill aligns
- Mobile↔Backend differential via `dart compile exe` calc_harness (Phase 92.5) — Phase 95 hash parity reuses the harness
- Closed-world `{{cite:<key>}}` placeholder grammar (Phase 94) — Phase 95 `ProjectionGroundingPack.entries` keys MUST stay within this namespace
- CITATION_REGISTRY 18 keys (Phase 94 Wave 0) — Phase 95 `ProjectionGroundingPack` entries reuse this 18-key key-space, not a new namespace
- Lefthook pre-commit + CI lints — Phase 95 adds 1 new lint (`pii_fixture_scan.py`) ; banned-terms + accent already wired

### Integration Points

- `_substitute_placeholders()` in `services/backend/app/services/coach/citation_parser.py` — double-lookup integration point (D-09) ; Phase 95 W2 inserts the `pack.entries.get(k) or CITATION_REGISTRY.resolve(k)` branch
- `_run_narrator_with_gate()` at `services/backend/app/api/v1/endpoints/coach_chat.py:3339-3376` — wrapper from Phase 94 ; Phase 95 hooks the `ProjectionGroundingPack` parameter through to `_substitute_placeholders()`
- `GatedResponse` Pydantic model in `citation_parser.py:263` — Phase 95 W1 populates `inputs_hash` field
- `tests/fixtures/` namespace — Phase 95 adds `hash_parity_50.jsonl` (50 fixtures for Python↔Dart hash validation)
- `services/backend/alembic/versions/` — Phase 95 W1 adds 1 forward migration + 1 downgrade

</code_context>

<specifics>
## Specific Ideas

- The hash parity test is the highest-risk surface area (R1 from architect panel). The plan must front-load it : if Python and Dart can't agree on hashes, the entire DAG-invalidation contract is unworkable and we must pivot to centime/bps integer-scaling before Wave 2.
- The narrator annotation « selon le modèle simplifié actuel » is the LSFin-compliance escape hatch for bootstrap CIs. This phrasing was vetted by the calc-first ADR (Expert 1 quant-actuarial synthesis) — narrator MUST use it verbatim when emitting bracketed intervals (Wave 2 enforces this via the same `banned_terms_python.py` lint extended to require the annotation when CI fields are non-None).
- 18-key `entries` keyspace coupling : if Phase 96 NarrativeSleeve adds new card types that need new citation keys, the new keys MUST be added to `CITATION_REGISTRY` first, THEN to `ProjectionGroundingPack.entries`. The double-lookup catches the registry case ; the pack-only case fails the gate cleanly.

</specifics>

<deferred>
## Deferred Ideas

- **Full Pareto front via NSGA-II + `pymoo`** — backlog 999.2 (1-2 weeks, coupled with GroundingPack but livrable séparément). Triggered when a UI surface exists to consume the multi-objective front.
- **Sobol sensitivity indices via Saltelli sampling** — backlog 999.x. Needs UI surface designed to show partial-variance indices (« quel input drive le résultat le plus »).
- **HMM regime-switching Monte Carlo + CVaR + BVG mortality** — backlog 999.1 (4-6 weeks isolated). Replaces iid-Gaussian MC ; bootstrap CIs are the bridge until then.
- **Bayesian credible intervals** — deferred indefinitely. No calibrated priors today, fréquentiste bootstrap is the honest MVP.
- **`CITATION_REGISTRY` complete removal** — post-Phase-96 cleanup phase. Phase 95 ships double-lookup cohabitation ; the registry-only fallback path is the bridge while Phase 96 narrator templates ramp.
- **Full Phase 96 CI integration of the schema migration verifier** — deferred to Phase 96 G3 (Phase 95 verifies manually on a staging DB clone).

### Reviewed Todos (not folded)

- `2026-05-05-audit-mint-skills-against-rezvani-5-step-prompt-to-skill-con` (score 0.6, area: tooling) — meta/skills-audit task ; not relevant to Phase 95 DAG-INVALIDATION scope. Better fit : Phase 96 or post-milestone tooling sweep.

</deferred>

---

*Phase: 95-mvp-dag-invalidation*
*Context gathered: 2026-05-10 (auto-resolved by PM Claude from master synthesis)*
