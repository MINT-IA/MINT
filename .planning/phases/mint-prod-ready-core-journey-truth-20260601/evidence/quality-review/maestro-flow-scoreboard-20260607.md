description: Row 23 quality scoreboard for Maestro flows, starting with the independent/no-LPP Coach chat scenario that exposed a misleading 3a tax-impact card.
status: active
date: 2026-06-07

# Maestro Flow Scoreboard - Row 23 Quality Layer

## Purpose

Maestro `tests=1, failures=0` is not enough for MINT. A flow can pass while
the user receives shallow, misleading, or badly prioritized guidance. This
scoreboard adds a quality review layer for runtime flows: flow logic, Swiss
financial relevance, real data use, calculation quality, LSFin boundary, UX,
and accessibility.

Current inventory:

- Command: `rg --files tools/simulator/flows -g '*.yaml'`
- Count on 2026-06-07: `47` Maestro YAML flows.

## Rubric

| Dimension | Weight | What Must Be True |
|---|---:|---|
| Flow logic | 15% | Scenario follows a realistic user objective and checks the actual outcome, not only navigation. |
| Guidance quality | 20% | Content answers the user's question, prioritizes the right next step, and separates rules, assumptions, and missing facts. |
| Simplicity and comprehension | 10% | The screen is readable, not overloaded, and uses direct language. |
| Calculation quality | 15% | Numbers are sourced, stable, unit-correct, and tied to the persona facts. |
| Real data use | 15% | The flow proves seeded/user data is consumed rather than default, salary-only, or LPP-only fallbacks. |
| LSFin boundary | 15% | The output stays educational, avoids product prescription, and does not imply personal suitability. |
| UX/accessibility | 10% | Important content is visible, reachable, and not broken by layout, focus, or text scaling. |

Score caps:

- No runtime evidence: maximum `5/10`.
- Runtime evidence without content/source review: maximum `6/10`.
- Wrong or unexplained financial number: maximum `4/10`.
- Product/provider prescription or personal suitability framing: maximum `6/10`.
- Crash, visible exception, NaN/Infinity, or PII leak: maximum `2/10`.

## First Reviewed Flow

### `flow_row23_independent_no_lpp_coach_chat_runtime.yaml`

Scenario:

- Persona: `independent_no_lpp_income_reality`
- Original prompt: `Je suis indépendant sans LPP, combien verser en 3a ?`
- Context-aware runtime prompt target: `Combien verser en 3a ?`
- Route: `/coach/chat`
- User objective: understand how much can be contributed to 3a as an
  independent person without LPP, and what must be checked before increasing
  contributions.

### Pre-Fix Score

Score: `5.0 / 10`.

Why:

- The local fallback text was directionally useful: 20% of activity income,
  OPP3 cap, AVS-independent status, accident/perte de gain cover, liquidity,
  optional LPP, and LSFin boundary were visible.
- The flow still accepted a generic card below the answer:
  `Versement 3a 2026`, `Impact fiscal indicatif`, `2'218 CHF`.
- That card answered a different question. The user asked contribution
  capacity; the card highlighted a tax impact and created a false hierarchy.
- The number looked precise without showing the chain: professional net income,
  current contributions, remaining legal room, taxable income, and cashflow.
- The Maestro assertion was shallow because it asserted the card id instead of
  rejecting the misleading card hierarchy.

### Fix Applied

Code behavior:

- `ResponseCardService.generateForChat(...)` now suppresses generic 3a and tax
  optimization cards for `FinancialArchetype.independentNoLpp` when the user
  asks a no-LPP 3a capacity question, including fiscal-worded variants.
- `generateForPulse(...)` still keeps the proactive 3a card, where the card is
  a dashboard signal rather than the answer to a capacity question.

Maestro behavior:

- The flow now asserts the specialist no-LPP guidance remains visible.
- It rejects `Versement 3a 2026`, `Impact fiscal indicatif`, and the known bad
  amounts `2'218 CHF`, `7'137 CHF`, and `3'068 CHF`.

### Post-Fix Runtime Score

Score after local fix and iPhone 16e runtime proof: `6.7 / 10`.

Why the score rises:

- The wrong visual hierarchy is removed.
- The runtime flow is now harder to game: it must fail if the generic tax card
  returns.
- The service contract separates chat-answer context from proactive dashboard
  context.

Why this is not yet a high score:

- The screen still needs a better primary action such as `Calculer ma marge 3a`
  with known facts, missing facts, and remaining room.
- The flow does not yet show source/freshness/confidence beside each money
  fact.
- It does not prove restart continuity of the professional net-income source.
- It does not compare 3a, optional LPP, liquidity, risk cover, and income
  volatility as an explicit decision map.
- It does not prove VoiceOver/focus traversal for this answer.

Runtime evidence:

- Flow:
  `tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_coach_chat_runtime.yaml`
- JUnit:
  `evidence/maestro-ci/row-23-independent-no-lpp-card-hierarchy-quality-20260607T095929/result.xml`
- Result: `tests=1`, `failures=0`, device `iPhone 16e - iOS 26.2`.
- Watchdog: `maestro returned 0`.
- Screenshot:
  `evidence/maestro-ci/row-23-independent-no-lpp-card-hierarchy-quality-20260607T095929/runtime-final-screen.jpg`.

### Context-Aware Margin Follow-Up

Score after context-aware local tests, Claude review fixes, and iPhone 16e
runtime proof: `8.2 / 10`.

What changed:

- The local answer now starts with `Marge 3a à vérifier`.
- It shows the scenario formula:
  `min(20 % du revenu déterminant, 36'288 CHF/an) - versements 3a déjà planifiés`.
- It uses persona facts from `CoachContext`:
  professional net income `86'400 CHF/an`, planned 3a payments
  `6'000 CHF/an`, remaining legal margin `11'280 CHF/an`.
- It no longer requires the user prompt to repeat `indépendant sans LPP` when
  the runtime `CoachContext.archetype` already carries that fact.
- The no-income branch now has an explicit anti-hallucination assertion:
  show missing data, do not compute a `marge légale restante`.
- It names missing confirmations: fiscal/AVS determining income,
  AVS-independent status, accident/perte de gain cover, liquidity, and
  possible LPP facultative role.
- The flow now asserts the calculation chain and still rejects the misleading
  tax-impact card hierarchy.
- Claude final review tightened the computed-facts wording: the displayed
  professional base is explicitly a MINT-declared value to confirm as fiscal/AVS
  determining income before treating the remaining margin as reliable.
- The hard-gate no-income path is now covered at orchestrator level: it shows
  missing data and does not invent a computed remaining margin.
- Runtime proof also guards against a shallow pass: it starts from the natural
  prompt `Combien verser en 3a ?`, validates the visible legal/LSFin tail,
  scrolls back to the formula and MINT facts, then scrolls forward to the
  professional checks and cashflow-capacity warning.

Benchmark evidence:

- VZ 2026 3a maximum page distinguishes pension-fund affiliation and states
  the no-LPP rule as 20% of determining income capped at 36'288 CHF; it also
  defines the independent income base as the business result after social
  contributions and tax corrections:
  https://www.vermoegenszentrum.ch/fr/competences/pilier-3a-montant-maximum
- Detailed benchmark artifact:
  `evidence/quality-review/row-23-independent-no-lpp-vz-margin-benchmark-20260607.md`.

Runtime evidence:

- JUnit:
  `evidence/maestro-ci/row-23-independent-no-lpp-vz-margin-quality-20260607T111701-after-claude/result.xml`
- Result: `tests=1`, `failures=0`, device `iPhone 16e - iOS 26.2`.
- Watchdog: `maestro returned 0`.
- Screenshot:
  `evidence/maestro-ci/row-23-independent-no-lpp-vz-margin-quality-20260607T111701-after-claude/runtime-final-capacity-guidance.jpg`.

### Decision-Map Follow-Up

Score after structured decision-map tests and iPhone 16e runtime proof:
`8.6 / 10`.

What changed:

- The answer now separates `Faits MINT`, `Confirmations manquantes`,
  `Carte de décision`, `Comparer avant de verser`, and `Prochaine action
  prudente`.
- The decision map explicitly covers legal 3a margin, monthly capacity, risk
  cover, optional LPP, liquidity, and fiscal checks without ranking a product
  path.
- The local and hard-gate tests reject the previous generic tax-impact card,
  stale amounts, product/provider wording, and overclaiming terms such as
  `meilleur`, `optimal`, or `sans risque`.
- The no-income branch still shows missing data instead of inventing
  `86'400 CHF/an`, `6'000 CHF/an`, or `11'280 CHF/an`.
- The Maestro flow now validates meaning-bearing sections at runtime, not just
  a topic phrase.

Runtime evidence:

- JUnit:
  `evidence/maestro-ci/row-23-independent-no-lpp-decision-map-quality-20260607T124439/result.xml`
- Result: `tests=1`, `failures=0`, device `iPhone 16e - iOS 26.2`.
- Watchdog: `maestro returned 0`.
- Screenshot:
  `evidence/maestro-ci/row-23-independent-no-lpp-decision-map-quality-20260607T124439/runtime-final-decision-map-guidance.jpg`.
- Detail artifact:
  `evidence/rapport-design/row-23-independent-no-lpp-decision-map-guidance-20260607.md`.

Remaining gaps:

- The decision map is still text rendered inside chat, not a dedicated
  structured UI component with field-level provenance.
- Source freshness and field-level provenance are not visible beside each
  money fact.
- Runtime VoiceOver/focus traversal remains open.

## Target State For 10/10 On This Scenario

To reach `10/10`, this scenario needs:

- Runtime-proven primary panel: `Marge 3a à vérifier`, not tax impact.
- Visible formula: `min(20% du revenu déterminant, plafond OPP3 sans LPP) -
  versements 3a déjà planifiés`.
- Known facts: professional net income, planned 3a contributions, LPP status,
  and monthly cashflow.
- Missing facts: taxable independent income, AVS-independent confirmation,
  accident/perte de gain cover, business reserve, optional LPP context.
- Capacity warning: legal room is not the same as monthly affordability.
- Next action: calculate the remaining margin and checks, not simulate a tax
  saving first.
- Accessibility proof: focus order and readable semantics for the answer and
  action.
- Runtime proof after restart and after profile fact update.

## Next Flow Queue

Score the remaining flows in batches, starting with the highest risk:

1. Coach/persona flows that display financial guidance.
2. Budget and Rapport flows that show cashflow, tax, LPP, 3a, or retirement
   numbers.
3. Onboarding/fact-ingestion flows that seed the money truth.
4. Navigation-only smoke flows, with lower priority unless they hide financial
   output.

Row 23 remains `PARTIAL`. This artifact adds a quality operating layer; it does
not close the broader screen/flow review.
