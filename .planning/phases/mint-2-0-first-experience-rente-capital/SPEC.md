# Mint 2.0 First Experience Rente/Capital — Proposed Spec

Status: Proposed. Not active until router promotion after explicit GO.

## User Promise

The user opens Mint, sees three Swiss life-event axes, enters
`2e pilier : rente ou capital`, understands what is missing before any amount,
and can find the answer later in a dossier entry with provenance.

## Required Behavior

1. No account gate before value.
2. First surface frames Mint as dossier/navigation, not generic chat.
3. Three axes visible: `2e pilier : rente ou capital`,
   `Logement : 2e / 3e pilier`, `3a et rachats : impact fiscal`.
4. Only rente/capital is live in this phase.
5. Signalétique axes educate, save interest, and offer follow-up; they do not
   calculate, simulate, or collect detailed unused data.
6. Each requested field has a visible reason tied to the next answer.
7. Any visible financial value includes value/range, unit, assumptions, sources,
   readiness/confidence, missing fields, and calculation or constant version.
8. Missing required inputs produce education plus missing fields, not a guessed
   amount.
9. Coach can navigate and explain the dossier; dossier remains independently
   visible and revisitable.
10. Future user-facing strings go through ARB/i18n.

## Forbidden Outputs

Naked financial number; imperative financial instruction; product ranking; tax
promise; fiscal amount from a signalétique axis; housing simulation in this
phase; default LPP amount; rare compliance branch before the event requires it;
account creation as first value moment; silent fallback masking drift; route,
helper, widget, or service without caller; new calculator outside canonical L1
or L2-L4 boundary.

## Synthetic Golden Inputs

Synthetic only, never real user data.

| ID | Situation | Expected axis | Amount? | Expected first answer |
|---|---|---|---|---|
| A01 | 29, first stable job, pension basics | education | No | dossier orientation, follow-up, no calculation |
| A02 | 36, first home in VD, 2e/3e question | logement signalétique | No | tracked housing door, save interest, no simulation |
| A03 | 47, job change, LPP transfer | education or live if explicit | only after live inputs | transfer vs decision clarification, no irrelevant compliance |
| A04 | 58, early-retirement, rente/capital | rente/capital live | yes with required inputs | readiness first, receipt if value/range appears |
| A05 | 63, capital or pension, no figures | rente/capital live | No | tradeoff plus missing fields, no invented LPP |
| A06 | 41, separation, pension question | family/pension education | No | documents and next dossier steps, no formal conclusion |
| A07 | 52, inheritance, tax impact | fiscal signalétique | No | tracked fiscal door, follow option, no tax amount |
| A08 | 39, cross-border/new tax residence | residence facts first | no until facts and engine allow | residence facts before fiscal personalization |

## Negative Cases

| ID | State | Forbidden behavior |
|---|---|---|
| N01 | age/birth date skipped in live door | personalized amount |
| N02 | logement selected | detailed values for unused simulation |
| N03 | fiscal signalétique selected | tax amount |
| N04 | no LPP amount/range | default LPP amount |
| N05 | fresh install with Keychain residue | resurrect old conversation |
| N06 | CHF or percent visible | missing readiness, sources, assumptions, missing fields, or version |
| N07 | coach follow-up after result | answer stored only in chat |
| N08 | iPhone 13 mini viewport | clipped CTA, counter, chip, sheet, or receipt text |

## Acceptance Criteria

Planning: canonical four files exist; no product code or router change; eight
fixtures and eight negative cases exist; receipt requirements are explicit;
signalétique axes have negative coverage; Slice 2 must plan feature flag or
kill switch and iPhone 13 mini proof.

Implementation after promotion: widget/provider tests prove three axes and one
live door; negative tests block signalétique calculations; calculator-boundary
audit names canonical source; Maestro starts from clear state; iPhone 13 mini
snapshot shows no clipping; dossier revisit is separate from chat; account
handoff appears after value.

```verify
# tier: deterministic
active-context: python3 tools/checks/active_context_guard.py
phase-contract: python3 tools/checks/phase_contract_guard.py
no-legal-admission: python3 tools/checks/no_legal_admission_in_public_docs.py --paths .planning/phases/mint-2-0-first-experience-rente-capital
contract-diff-check: git diff --check -- .planning/phases/mint-2-0-first-experience-rente-capital
guard-tests: python3 -m pytest tools/checks/tests/test_phase_contract_guard.py tools/checks/tests/test_verify_phase_acceptance.py -q
# tier: device
iphone-13-mini-runtime: bash tools/simulator/maestro_with_watchdog.sh test tools/simulator/flows/maestro-perfect-set/flow_mint2_first_experience_rente_capital_entry.yaml
```

## Caveat

`verify_phase_acceptance.py` reads the active spec from
`.planning/ACTIVE_CONTEXT.json`. Before router promotion, it proves the active
infra phase only, not this proposed Mint 2.0 contract.
