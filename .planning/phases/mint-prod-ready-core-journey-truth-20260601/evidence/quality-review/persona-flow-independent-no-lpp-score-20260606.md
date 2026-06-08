---
description: Expert-scored persona-flow benchmark record for independent_no_lpp_income_reality after CJT-062 plus Row 23n/q/r follow-up proof.
status: scored-with-gaps
date: 2026-06-08
---

# Persona-Flow Score - independent_no_lpp_income_reality

## Scope

This is the refreshed scored persona-flow benchmark record for
`independent_no_lpp_income_reality` after the Row 23n/q/r follow-up proof.

It uses the original CJT-062 iPhone 16e runtime proof plus the later Row 23
Coach, restart/profile-update, structured provenance, and Budget/Rapport
updated-state regression evidence as observed MINT behavior. It compares that
against public Swiss guidance expectations. It does not close Row 23.

## Persona And Scenario

- Persona: `independent_no_lpp_income_reality`
- Archetype: `independent_no_lpp`
- Canton: `VD`
- Seed: `apps/mobile/lib/services/coach/coach_profile_seeds.dart#independent_no_lpp_income_reality`
- Scenario: income reality, Budget cashflow, 3a ceiling without LPP affiliation
- Route sequence: `/budget` -> `/rapport`
- Maestro flow: `tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_runtime.yaml`
- Original runtime evidence:
  `.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-independent-no-lpp-runtime-strong-20260606T162641/`
- Later Row 23 evidence:
  - `evidence/maestro-ci/row-23-independent-no-lpp-anti-surface-stable-final2-20260607T142509/`
  - `evidence/maestro-ci/row-23-independent-no-lpp-restart-profile-update-20260607T203657/`
  - `evidence/rapport-design/row-23-independent-no-lpp-structured-provenance-20260608.md`
  - `evidence/rapport-design/row-23-independent-no-lpp-budget-rapport-updated-state-semantics-20260608.md`

## Source Evidence

Official/regulatory anchor:

- OFAS/BSV, `Votre cotisation au 3e pilier`:
  https://www.bsv.admin.ch/fr/votre-cotisation-au-3e-pilier
  - Working rule verified on 2026-06-06: with LPP affiliation, the 2026 3a
    ceiling is `CHF 7'258`; without LPP affiliation, the ceiling is `20%` of
    income from gainful activity, capped at `CHF 36'288`.
- MINT regulatory constants MCP, `get_swiss_constants(category: pillar3a)`:
  - `pillar3a.historical_limits.2026 = 7258`
  - `pillar3a.max_without_lpp = 36288`
  - `pillar3a.income_rate_without_lpp = 0.2`

Public Swiss expert-market references used as coverage examples, not as product
recommendations:

- Raiffeisen, `Pilier 3a: montant maximal 2026`:
  https://www.raiffeisen.ch/geneve-lac/fr/clients-prives/prevoyance-et-assurance/montant-maximal.html
  - Distinguishes LPP-affiliated users from independent/no-LPP users and states
    the `20%` / `CHF 36'288` rule for 2026.
- Raiffeisen, `Prévoyance des indépendants`:
  https://www.raiffeisen.ch/rch/fr/connaissances/prevoyance/le-premier-gros-salaire/statut-independant.html
  - Frames independent work as a broader coverage problem: AVS registration,
    facultative 2nd pillar options, 3a, accident and loss-of-income protection.
- Swiss Life, `Pilier 3a: que dois-je savoir?`:
  https://www.swisslife.ch/fr/particuliers/prevoyance-patrimoine/guide/pilier-3a-que-dois-je-savoir.html
  - Notes that without a pension fund, the maximum is `20%` of net income from
    gainful activity up to a fixed maximum, and that several 3a accounts may be
    useful for withdrawal planning.
- VZ VermögensZentrum, `Prévoyance`:
  https://www.vermoegenszentrum.ch/fr/prevoyance
  - Market reference for an expert-style coverage review: protection if illness,
    accident, disability or death occurs; explicit questions include working
    independently and organizing pension coverage.

## Expected Expert-Grade Guidance

A strong Swiss guidance flow for Nadia should cover:

1. Confirm whether she is affiliated to a 2nd pillar institution or not.
2. Explain the applicable 3a ceiling as status-dependent, not salary-dependent.
3. Use her actual monthly income and cashflow instead of a salaried default.
4. Show which data is known, estimated, missing, stale, or user-entered.
5. Separate budget capacity from legal/tax eligibility.
6. Surface the tradeoff between optional LPP affiliation, 3a, liquidity, risk
   cover, and business-income volatility.
7. Avoid provider ranking, product prescription, or investment allocation
   instructions.
8. Offer a next check such as verifying AVS-independent status, taxable net
   income, insurance/risk cover, and whether optional LPP should be explored
   with a qualified specialist.

## Observed MINT Guidance

What the combined proof now shows:

- `/budget` originally used the seeded monthly resources and showed
  `CHF 7'200`.
- Row 23n then proved an updated restart/profile-update chain where
  `96'000 CHF/an` professional income drives Budget `CHF 8'000`, Rapport
  `remaining=13200`, and Coach `13'200 CHF/an`.
- `/budget` no longer shows `Ajouter mon salaire`.
- `/rapport` renders the seeded report, not the empty report.
- `/rapport` shows `Plafond 3a selon affiliation LPP et statut de revenu`.
- The flow asserts no visible `Plafond 3a salarié`, `salarié uniquement`,
  `7’258`, `NaN`, `Infinity`, or Flutter exception strings.
- The Coach natural prompt `Combien verser en 3a ?` now produces the audited
  `Marge 3a à vérifier` answer with formula, MINT facts, confirmations
  manquantes, decision map, comparison checks, and cautious next action.
- Row 23q renders structured source, freshness, confidence, and update date for
  the key Coach facts when metadata exists.
- Row 23r adds Budget/Rapport widget-level regression coverage for the updated
  independent/no-LPP values and rejects stale salaried/LPP figures.
- Row 23c proves that the generated PDF text keeps the same independent/no-LPP
  verification guidance and rejects account-opening or provider/product
  framing for this persona.
- Row 23t deduplicates the Budget next-action semantics so the no-LPP/AI
  context, CTA, and `~70 %` impact are exposed once instead of repeating the
  command, while preserving the tap action.
- Row 23u adds a Budget capacity guard for the independent/no-LPP persona,
  carrying the Rapport checks for AVS-independent status, taxable income,
  monthly budget capacity under income volatility, risk cover, optional LPP,
  3a, and liquidity into the Budget surface.
- Row 23v proves that the Budget capacity guard is visible in the canonical
  iPhone 16e simulator route flow and that its copied runtime text rejects
  salary-only, product/provider, and fixed-allocation fragments.
- Row 23w locally quantifies the Budget guard with `CHF 11'280/an` legal 3a
  room, `CHF 940/mois` monthly equivalent, and `CHF 2'578/mois` current Budget
  free cashflow, while warning that legal room is not monthly capacity.

What remains weak:

- Budget/Rapport still do not have the same natural-language guidance depth as
  the audited Coach answer, though Budget now has a simulator-proven and
  locally quantified no-LPP capacity guard.
- The flow does not ask or prove AVS-independent status, taxable net income, or
  whether the current `CHF 6'000` 3a contribution is sustainable in cashflow.
- No VoiceOver/focus traversal proves that the important content is accessible.
- No live backend/LLM path has been scored for the persona; the current scored
  Coach proof is the deterministic local fallback path.
- Budget/Rapport guidance depth still remains lower than the audited Coach
  answer, even after the Budget action semantics and capacity-guard cleanup.

## Scores

| Dimension | Weight | Score | Rationale |
|---|---:|---:|---|
| Runtime completion | 10% | 9.0 | iPhone 16e Maestro proofs cover the original route, Coach guidance, restart/profile-update continuity, and the Budget capacity guard with JUnit `tests=1`, `failures=0`, watchdog `0`. |
| Persona fit and inclusion | 15% | 8.5 | The flow no longer falls back to a salaried/LPP assumption and CoachContext can carry independent/no-LPP without the user restating it. |
| Data truth and continuity | 15% | 8.5 | Row 23n proves updated value continuity across Coach, Budget, and Rapport; Row 23q adds structured source/freshness/confidence/date in Coach. |
| Calculation quality | 15% | 8.5 | 3a ceiling logic is status-aware and backed by contracts; remaining caveat is that determining AVS/taxable independent income still needs confirmation. |
| Swiss expert coverage and logic | 20% | 8.0 | The audited Coach answer now covers optional LPP, liquidity, risk cover, income volatility, and fiscal/AVS confirmations; Budget/Rapport remain thinner. |
| UX clarity and next action | 10% | 8.0 | The user gets a margin, facts, missing confirmations, decision map, comparison checks, and a cautious next action. |
| FINMA/LSFin-safe boundary | 10% | 8.5 | The observed copy is educational, avoids provider ranking/product prescription, and rejects the previous misleading tax-impact card hierarchy. |
| Accessibility/localization | 5% | 6.0 | Widget-level semantics exist for Budget/Rapport and localized FR copy is covered, but real VoiceOver/focus traversal is still absent. |

Weighted score before cap: `8.28 / 10`.

Score caps applied:

- Cap `8/10`: Budget/Rapport route-chain quality is still lower than the
  audited Coach answer and has no physical-device VoiceOver traversal.
- Cap `8/10`: live backend/LLM scoring remains unproven for this persona.

Final score: `8.0 / 10`.

## Compliance Boundary

MINT should keep this as guidance:

- explain rules and assumptions;
- identify missing information;
- show scenario impact;
- suggest checks to discuss with qualified specialists when needed.

MINT should not:

- rank providers;
- tell the user to open a specific product;
- choose an investment allocation;
- promise tax savings or returns;
- imply that maximizing 3a is automatically the right decision.

Mechanical checks already run during this lot:

- MCP `check_banned_terms` on representative FR benchmark phrasing: clean.
- MCP `check_accent_patterns` on representative FR benchmark phrasing: clean.

## Bugs And Tracking

- Linked closed bug: `CJT-062` for the runtime fixture.
- New open gap: `CJT-063` for independent/no-LPP expert-guidance depth.

`CJT-063` is a P1 quality gap, not a local crash. It should remain open until
the persona flow proves physical-device VoiceOver traversal, live backend/LLM
scoring, and Budget/Rapport guidance depth for the same persona.

## Decision

Record status: `scored_with_gaps`.

This record raises Quality OS confidence because the flow is now scored against
the right kind of Swiss guidance. It does not raise Row 23 above `PARTIAL`.
