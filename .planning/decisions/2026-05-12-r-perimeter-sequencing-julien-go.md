---
description: ADR — Julien validates 3 of 5 panel-synthesis decisions, rejects 2. R1-R5 sequencing locked, P001 architectural fix deferred to v2.10, Apple Sign-In becomes primary auth, no Maestro Cloud budget, no second Mac mini. Full orchestrator autonomy granted to land R2+R3+R4 via GSD.
type: decision
phase: 97-95
authority: julien-go-2026-05-12T09:55Z
status: Decided
created: 2026-05-12
---

# ADR — R-perimeter sequencing GO (Julien 2026-05-12T09:55Z)

## Decision

Julien validates 3 of 5 panel-synthesis open decisions, rejects 2 :

| # | Decision | Vote | Effect |
|---|---|---|---|
| 1 | R-perimeter sequencing R1 → R2 → (R3 ∥ R4) → soak → ship | **GO** | Product features (R2) before tests of those features (R3+R4). |
| 2 | P001 H1-only ship + defer H2-H5 architectural narrator fix to v2.10 | **GO** | v2.9 ships at 18-22% gate-correct ; FALLBACK_TEMPLATED_TEXT is the runtime safety net ; LSFin compliance preserved via banned-claim regex + accent FR lint. |
| 3 | Apple Sign-In primary + email-password retired from user-visible auth | **GO** | -1 step friction, no breach surface from password storage. Email-password stays as dev-flag for CI tests only. |
| 4 | Maestro Cloud $99/mo passive fallback budget on Mac mini outage | **NO-GO** | Strict free-tier discipline. Mac mini self-hosted is the only substrate. |
| 5 | Second Mac mini (~CHF 550) as warm-spare runner | **NO-GO** | Single mini is sufficient. Reconsider only if MTBF data shows real SPOF impact. |

## Authority and full-autonomy grant

> *« Pour le reste, tu peux continuer en full autonomy, même pour la phase GSD, tu peux y aller full autonomy, tu es l'orchestrateur, tu as les pleins pouvoirs là-dessus. »*

The orchestrator (Claude Opus 4.7) has full PM authority to :
- Land R2 (P001 H1-only + P002 + SessionReport + ConsentService) via GSD Phase 97.5.
- Land R3 (Tier 1 smoke flow) + R4 (Surface regression catalogue) via GSD Phase 98 in parallel where possible.
- Decide architectural tradeoffs inside each perimeter using the same 7-expert panel pattern.
- Open / merge PRs against dev and dev → staging without per-PR approval gates.
- Update BUGS-REGISTRY rows + cycle artefacts unilaterally.

## Cycle exit conditions for v2.9 ship

D-30 from Phase 97 CONTEXT (locked) :
- ALL 5 gates green × all 8 archetypes
- 7-day staging soak with zero LSFin violation
- Zero unhandled exception in Sentry over the soak
- Zero visual drift > 1% on golden screens
- NO « approved-with-issues » disposition admitted

These exit conditions stay locked. R5 (time-travel + Clock refactor) is officially deferred to v2.10 ; its absence does NOT block the v2.9 ship per D-30.

## Counter-arguments and data gaps

**Counter-arguments :**

- *« Strict free-tier on Maestro Cloud + single Mac mini = real SPOF risk during the 7-day soak »* — true. Julien accepted the risk. Mitigation : the soak runs continuously ; if the mini drops we restart the soak window. Cost = ~7 days of calendar slippage MAX, not unrecoverable.
- *« Deferring P001 architectural fix means LSFin gate-correct stays at 18-22% on prod »* — true. Mitigation : the FALLBACK_TEMPLATED_TEXT path is the compliance safety net (no narrator output without citation). The user-visible degradation is acceptable for v2.9 educational scope ; v2.10 attacks the gate-correct directly.
- *« Retiring email-password is a breaking change for existing accounts »* — partly true. Existing email-password accounts continue to work for login ; only the SIGN-UP path retires the option. Migration path : magic-link reset for users who want passwordless. Document in PRD.

**Data gaps :**

- Mac mini MTBF on the actual hardware : no historical data. The « 1-2 outages/month » estimate is industry-average, MINT-specific TBD.
- Number of existing email-password accounts on staging + prod : not measured. If significant, retire-from-UI may need a notice period.
- Magic-link delivery rate (spam folder drop-off) on Swiss email providers (Bluewin, GMX-CH, ProtonMail) : not benchmarked.
- Apple Sign-In adoption rate among MINT's 18-99 target (older users may not have Apple IDs) : unknown.

## Next action

Orchestrator proceeds autonomously :
1. Finish PR #573 (P003 cycle) — CI green + merge to dev + sync dev → staging + Railway redeploy + L3 re-curl + Julien sim re-test for Pillar 6 dims 3+4.
2. Run Pillar 0.a scout walkthrough on post-P003 staging (validates P003 + surfaces masked-until-now defects).
3. Open GSD Phase 97.5 via `/gsd-plan-phase` for R2 product completeness.
4. Iterate R3 + R4 in parallel where dependency graph allows.
