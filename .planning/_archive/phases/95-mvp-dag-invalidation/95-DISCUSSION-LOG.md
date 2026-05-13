---
description: Phase 95 discuss-phase audit trail — fully auto-resolved by PM Claude (Product Leader) using 3-panel synthesis as the answer source. NOT consumed by downstream agents ; audit trail only.
---

# Phase 95: MVP-DAG-INVALIDATION - Discussion Log (Auto-Resolved)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-10
**Phase:** 95-mvp-dag-invalidation
**Mode:** auto (--auto --chain via `/gsd-discuss-phase 95 --auto --chain`)
**Resolved by:** PM Claude (Product Leader, autonomous loop per Julien 2026-05-10) drawing from 3-panel synthesis at `.planning/decisions/2026-05-10-95-96-autonomous-sequence-master.md`
**Areas analyzed:** Hash algorithm, ID generation, GroundingPack shape, Pareto computation, sensitivity analysis, credible intervals, wave split, compliance gates, integration strategy

---

## Auto-Resolution Methodology

Per `/gsd-discuss-phase` workflow `--auto` mode : « for each discussion question, choose the recommended option (first option, or the one marked "recommended") without using AskUserQuestion. Log each auto-selected choice inline so the user can review decisions in the context file ».

This file logs the alternatives considered and the recommended option auto-selected, drawn from the 3 expert panels convened earlier this session (commit `0302fb9b`) :

1. **95-architect panel** (`2026-05-10-phase-95-architect-panel.md`) — DAG architecture brief
2. **96-ux panel** (`2026-05-10-phase-96-ux-panel.md`) — downstream consumer constraints
3. **sequencing-compliance panel** (`2026-05-10-phase-95-96-sequencing-compliance-panel.md`) — cross-phase risk + pre-merge gates

The PM master synthesis (`2026-05-10-95-96-autonomous-sequence-master.md`) lists every decision with counter-arguments and data gaps already documented. This log mirrors those decisions per the GSD audit-trail convention.

---

## Hash algorithm (D-01..D-03)

| Option | Description | Selected |
|--------|-------------|----------|
| SHA256(JCS canonical JSON) + Decimal(2) quantization | RFC 8785 canonical form ; eliminates IEEE 754 artifacts ; Python ↔ Dart parity via `dart compile exe` harness | ✓ |
| SHA256(json.dumps with sort_keys) + ad-hoc float handling | Lighter (stdlib only) but unspecified handling of float edge cases | |
| Centime/bps integer scaling | Fallback if floats prove non-deterministic ; documented in plan as contingency | |

**Auto-resolved:** SHA256(JCS) + Decimal(2). 95-architect panel §1.
**Rationale:** JCS is the explicit deterministic-hash spec ; `jcs` PyPI package mature ; Decimal(2) covers CHF precision needs ; centime fallback documented as plan B if hash parity fails.

---

## ID format for superseded_by (D-04..D-05)

| Option | Description | Selected |
|--------|-------------|----------|
| UUID7 (Python 3.12+, RFC 9562) | Time-ordered ; `ORDER BY superseded_by` reconstructs chain ; 74-bit random tail | ✓ |
| Monotonic counter | Simpler but requires sticky session / DB autoincrement coupling | |
| Time-based (ms since epoch) | Collision risk under load | |

**Auto-resolved:** UUID7. 95-architect panel §2.
**Rationale:** Time-ordered means no separate `created_at` column ; Python 3.12+ already deployed ; SQLite TEXT(36) storage matches the existing project conventions.

---

## Migration strategy (D-06)

| Option | Description | Selected |
|--------|-------------|----------|
| ADDITIVE nullable columns + zero backfill | New rows get populated by the new emitter ; old rows stay NULL until touched | ✓ |
| ADDITIVE + lazy backfill on read | Reads of old rows trigger hash computation ; more complex | |
| Forced backfill migration | Compute all hashes at migration time ; slow on large tables | |

**Auto-resolved:** ADDITIVE + zero backfill. 95-architect panel §2 + sequencing-panel §2.
**Rationale:** Phase 92 set the additive-migration precedent ; zero backfill = zero risk of breaking existing profiles. Downside : reading an old projection returns `inputs_hash=NULL` which the cohabitation strategy (D-09) handles via CITATION_REGISTRY fallback.

---

## GroundingPack shape (D-07..D-09)

| Option | Description | Selected |
|--------|-------------|----------|
| Pydantic v2 `ProjectionGroundingPack` (frozen, extra=forbid) with entries/pareto/what_ifs/legal_constraints | Strict schema ; matches Phase 94 invariant ; introspectable | ✓ |
| Plain dict[str, Any] | More flexible but loses schema validation | |
| Protobuf | Stronger versioning story but adds binary build step | |

**Auto-resolved:** Pydantic v2 with strict schema. 95-architect panel §3.
**Rationale:** Existing `grounding_pack.py` stub already in the right namespace ; project convention is Pydantic v2 frozen+forbid (citation_registry.py:51 set the pattern) ; introspectability helps `_substitute_placeholders()` lookup.

---

## Pareto computation (D-10)

| Option | Description | Selected |
|--------|-------------|----------|
| 3-point scalarisation (fiscal / liquidity / ruin-reduction weights) | 3 fixed pondérations on 3 leviers ; produces exactly 3 ParetoPoint ; ~50 LOC | ✓ |
| NSGA-II via `pymoo` | True multi-objective optimization ; 1-2 weeks scope ; needs UI surface | |
| Single-objective scalar (terminal wealth) | Today's baseline ; not a Pareto front | |

**Auto-resolved:** 3-point scalarisation MVP. 95-architect panel §4. NSGA-II deferred to backlog 999.2.
**Rationale:** Phase 96 narrator needs at most a « top 3 levier choices » list to illuminate — full NSGA-II output has no UI surface to consume yet. Deferred to 999.2 once Phase 96 + future UI exists.

---

## Sensitivity analysis (D-11)

| Option | Description | Selected |
|--------|-------------|----------|
| Uni-variate ±10% per input → 5 what_ifs entries | Lightweight ; ~30 LOC ; directly consumable by narrator | ✓ |
| Sobol indices via Saltelli sampling | N×(D+2) evals = overkill MVP ; needs UI surface to consume | |
| Morris elementary effects | Mid-weight ; still needs UI consumption surface | |

**Auto-resolved:** Uni-variate ±10%. 95-architect panel §5. Sobol deferred to backlog 999.x.
**Rationale:** Same logic as Pareto — Phase 96 narrator needs « si tu changes X de +10% le résultat bouge de Y », not partial-variance attribution. Sobol enters when there's a UI surface (tornado chart, sensitivity heatmap) to consume the indices.

---

## Credible intervals (D-12)

| Option | Description | Selected |
|--------|-------------|----------|
| Fréquentiste bootstrap 200 iter on existing MC | P5/P95 ; honest about iid-Gaussian assumption | ✓ |
| Bayesian credible intervals with calibrated prior | Strong theory but no calibrated prior today ; deferred to backlog 999.1 HMM | |
| Analytical CI from MC variance | Faster but assumes Gaussian residuals (often violated in financial outputs) | |

**Auto-resolved:** Fréquentiste bootstrap. 95-architect panel §6.
**Rationale:** Existing MC service is iid-Gaussian (insufficient per Expert 1 of calc-first ADR but live in prod). Bootstrap is the most honest add-on without a calibrated prior. Narrator annotation « selon le modèle simplifié actuel » discloses the assumption gap to the user (LSFin-compliant).

---

## Wave split (D-13)

| Option | Description | Selected |
|--------|-------------|----------|
| 2 plans / 2 waves (W1 hash+migration, W2 emission+lookup) | ~2+2d ; clean dependency boundary ; verifier separate | ✓ |
| 1 plan monolith | Less ceremony but harder to roll back if hash parity fails | |
| 3 plans (W1 hash, W2 emission, W3 verification) | Verifier-as-wave is non-standard ; verification is its own cycle | |

**Auto-resolved:** 2+2d wave split. 95-architect panel §7.
**Rationale:** Clean rollback boundary at Wave 1 close (if Python↔Dart hash parity fails we pivot before Wave 2). Verifier runs separately per workflow convention.

---

## Compliance gates (D-14..D-18)

| Option | Description | Selected |
|--------|-------------|----------|
| 5 gates : banned-terms + PII + no-legal-admission + accent + hash-parity + pytest baseline + manual schema-migration | All pre-merge ; lefthook + CI ; sequencing-panel §4-7 | ✓ |
| Minimal : just banned-terms + pytest | Faster but skips compliance defense | |
| Maximal : add G1 Maestro + G2 Julien sim | Phase 95 is backend-only ; G1/G2 deferred to Phase 96 | |

**Auto-resolved:** 7-gate compliance stack. Sequencing-panel §4-7.
**Rationale:** Phase 95 is backend-only ; G1 Maestro + G2 device gates don't apply (no UI surface yet). G3 dev CI + G4 regression suite + G5 lint stack cover the surface this phase touches.

---

## Cohabitation strategy (D-09)

| Option | Description | Selected |
|--------|-------------|----------|
| Double-lookup : pack.entries first, CITATION_REGISTRY fallback | Cohabitation during Phase 95 + 96 ; removes registry post-96 | ✓ |
| Hard cut : remove CITATION_REGISTRY in Phase 95 W2 | 3-way migration race (gate + registry + pack) ; fragile | |
| Pack-only : delete registry, force all callers to pack | Same as #2, even more invasive | |

**Auto-resolved:** Double-lookup cohabitation. 95-architect panel §3 + sequencing-panel §1.
**Rationale:** 3 systems must agree on the keyspace (Phase 94 gate, Phase 95 pack, Phase 96 narrator). Migrating 2 simultaneously is invasive ; cohabitation defers the registry-removal race to a post-96 cleanup phase when both downstream systems are proven.

---

## Phase 95 → Phase 96 dependency (informs D-09)

| Option | Description | Selected |
|--------|-------------|----------|
| Phase 96 ships with `GroundingPack | None` SOFT dependency | Phase 96 W1 Flutter UI ships without 95 ; W2 backend hard-blocks on 95 merge | ✓ |
| Phase 96 hard-blocks on Phase 95 GO-prod | Adds 2-4 weeks wall-clock dependency | |
| Phase 96 ships without GroundingPack consumption (defers to 97) | Loses the calc-first narrative wiring for the chat-as-verb release | |

**Auto-resolved:** SOFT dependency. Sequencing-panel §1.
**Rationale:** Decouples wall-clock for Phase 96 W1 ; one-line if-branch in `_substitute_placeholders()` is trivial to remove later.

---

## Claude's Discretion

The following items were not user-facing decisions but PLAN-level details intentionally left for the planner agent :

- Internal class structure of `ProjectionGroundingPack` emitters within `financial_core/` wrappers
- Bootstrap RNG seed strategy (deterministic vs per-input-derived)
- Decimal precision policy per field (`Decimal(2)` for CHF, `Decimal(4)` for percentages)
- Whether to extend the existing `grounding_pack.py` stub or replace it wholesale

The planner reads the stub first and decides per Karpathy #2 simplicity-first.

## Deferred Ideas (carried to backlog 999.x)

- Full Pareto via NSGA-II — backlog 999.2
- Sobol sensitivity — backlog 999.x
- HMM Monte Carlo + CVaR + BVG mortality — backlog 999.1
- Bayesian credible intervals — deferred indefinitely
- Complete CITATION_REGISTRY removal — post-96 cleanup phase
- Phase 96 CI integration of schema-migration verifier — Phase 96 G3

## Auto-Resolved Items Summary

| Area | Auto-selected | Source panel |
|------|---------------|--------------|
| Hash algorithm | SHA256(JCS) + Decimal(2) | 95-architect §1 |
| ID format | UUID7 + SQLite TEXT(36) | 95-architect §2 |
| Migration | ADDITIVE nullable + zero backfill | 95-architect §2 + sequencing §2 |
| GroundingPack | Pydantic v2 frozen+forbid | 95-architect §3 |
| Pareto | 3-point scalarisation MVP | 95-architect §4 |
| Sensitivity | Uni-variate ±10% (5 what_ifs) | 95-architect §5 |
| CIs | Fréquentiste bootstrap 200 | 95-architect §6 |
| Wave split | 2 plans, 2 waves | 95-architect §7 |
| Compliance | 7 pre-merge gates | sequencing §4-7 |
| Cohabitation | Double-lookup, defer registry removal | 95-architect §3 + sequencing §1 |
| 95↔96 dep | SOFT dependency | sequencing §1 |

All decisions traceable to the master synthesis with counter-arguments + data gaps already documented.
