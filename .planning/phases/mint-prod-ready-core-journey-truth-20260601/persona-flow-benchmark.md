# Persona-Flow Benchmark

Date: 2026-06-06
Status: Seed framework, not a closure gate yet
Owner: Quality OS / Team Lead

## Purpose

This benchmark turns MINT's felt quality problem into a repeatable review
system. Each scored scenario must answer one question:

> For this persona, did MINT produce a clear, useful, Swiss-specific guidance
> flow grounded in the user's real data, without drifting into regulated advice?

The benchmark complements the screen and flow review HTML files. It does not
replace Maestro, Flutter tests, the Journey Truth Matrix, BUG-TRACKER, or
expert review. It prevents "the locator passed" from being mistaken for "the
journey is good".

## Scope Cap

Do not start with all screens and all personas.

Seed wave:

- 2 personas
- 1 scenario per persona
- 5 checkpoints per scenario
- 10 scored cells total

Expansion rule:

- Expand only after the seed wave has clean evidence, bugs logged for every
  P0/P1 gap, and two consecutive review cycles with no unresolved methodology
  blocker.
- Do not grow beyond 12-20 active cells until the scoring, evidence, and bug
  loop are mechanical.

This follows the existing milestone lesson: focused single-persona walkthroughs
ship; large archetype matrices drift.

## Source Policy

Each benchmark scenario should use public and auditable sources:

- at least one official or regulatory anchor when the topic touches Swiss law,
  tax, pension, insurance, privacy, or compliance;
- at least two public Swiss expert-market references when comparing the kind of
  guidance a user could receive from established actors;
- MINT's own financial-core calculation contract when the app computes a
  number;
- no proprietary advice, private client material, or unverified institution
  claims;
- no ranking of third-party providers as better or worse for the user.

Provider references are used to define coverage expectations, not to recommend
their products. Provider pages are market examples, not legal authority.

Persona benchmarks must use synthetic personas only. Do not store real user
profiles, transcripts, scans, IBANs, employer names, addresses, exact real
balances, or partner data. If a benchmark uses a cloud model, record provider,
purpose, model, timestamp, and sanitized excerpts only.

## Required Evidence Per Scored Flow

A flow score is invalid without:

- persona id, archetype, canton/status, and scenario;
- route sequence or Maestro flow id;
- runtime artifact folder with screenshots when UI behavior is claimed;
- Flutter/backend/unit tests when calculation or persistence behavior is
  claimed;
- data facts used by the flow, with source/freshness/confidence when available;
- expected expert-guidance coverage;
- MINT observed coverage;
- compliance boundary check;
- UX clarity and load review;
- calculation/provenance review;
- bugs opened or linked for every P0/P1 gap;
- reviewer panel status, including Claude CLI status.

Service-level golden persona tests can seed scenarios, but they do not count as
full runtime proof.

## Scoring Dimensions

Total score is 1-10. A 10/10 flow must satisfy every dimension.

| Dimension | Weight | 10/10 signal |
|---|---:|---|
| Runtime completion | 10% | Flow completes on device/simulator with clean wrapper status, no placeholder, no crash, no stale screenshot reuse. |
| Persona fit and inclusion | 15% | Reacts to the persona's real Swiss situation instead of assuming a Swiss salaried default; asks the right missing question when needed. |
| Data truth and continuity | 15% | Uses the persona's actual facts, shows source/freshness/confidence for important numbers, survives restart when persistence is part of the claim. |
| Calculation quality | 15% | Computed numbers match financial-core/backend contracts and expose assumptions, limits, and Swiss legal anchors. |
| Swiss expert coverage and logic | 20% | Covers constraints, tradeoffs, alternatives, missing data, and next checks that a strong Swiss guide would raise for that persona. |
| UX clarity and next action | 10% | The user understands what changed, why it matters, what is uncertain, and the next useful action without excess text or role confusion. |
| FINMA/LSFin-safe boundary | 10% | Guidance stays educational/simulational, avoids prescriptive product selection, and hands off heavy or irreversible decisions. |
| Accessibility/localization | 5% | Primary content and actions are accessible, robust to text scale, localized, and not clipped or overlapped. |

## Persona Comprehension Check

For each scenario, a target user should be able to answer these in about 20
seconds from the flow:

1. What is the main thing MINT is telling me?
2. What data did MINT use?
3. What is missing or uncertain?
4. What is the next useful action?
5. What decision is still mine?

If the answer needs an external explanation, the flow is not 10/10. Novice
personas need jargon translated inline. Expert personas need assumptions
inspectable. Sensitive contexts need structure without judgment.

## Score Caps

These caps prevent inflated scores:

- Missing runtime proof caps the flow at 5/10.
- Runtime proof without an expert-reference artifact caps the flow at 6/10.
- Missing calculation source or assumptions caps the flow at 7/10.
- Any materially wrong calculation caps the flow at 4/10.
- Any salary-only, Swiss-native-only, or retirement-first assumption that does
  not fit the persona caps the flow at 7/10.
- Regulated-advice wording, provider ranking, or product prescription caps the
  flow at 6/10 and opens a compliance bug.
- Product/brand recommendation, ISIN/ticker advice, buy/sell/choose language,
  return promise, read/write financial action, unsafe logging, or PII leak
  fails the benchmark at 0/10.
- Banned LSFin terms, social comparison, ranked providers/options, a
  single-number projection without uncertainty, or treating a provider source
  as legal authority caps the flow at 4/10.
- Missing LSFin educational disclaimer, missing assumptions for a financial
  number, missing official source for a legal/tax/pillar claim, or missing
  conflict/referral disclosure where a provider appears caps the flow at 6/10.
- If the flow does not use real persona data when it is available, cap at 6/10.
- If the user must re-enter data already captured elsewhere, cap at 6/10.
- If a flow opens a calculator or tool without explaining why it matters for
  the persona now, cap at 5/10.
- If Coach-linked guidance is not evaluated from natural language, cap the
  Coach-linked flow at 7/10.
- If an unsupported persona receives ungated guidance, hard-fail release claims
  for that scenario.
- If a P0/P1 gap is found but not logged in BUG-TRACKER, cap at 6/10.
- If Claude CLI or specialist review is unavailable, cap the Quality OS
  confidence for that lot and state the missing review explicitly.

Compliance caps apply before averaging. A green Maestro/JUnit run cannot lift a
flow above a compliance or privacy cap.

## Seed Personas

The first seed should cover both an existing testable route and a known product
risk.

1. `sophie_housing_purchase`
   - Existing seed: `apps/mobile/test/journeys/sophie_golden_path_test.dart`
   - Risk: housing purchase combines cashflow, pension withdrawal, taxes,
     affordability, and irreversible decisions.
   - Candidate route chain: onboarding or Coach intent -> `/budget` ->
     `/profile/bilan` -> `/rapport` -> relevant simulator.

2. `independent_no_lpp_income_reality`
   - Existing seed: missing canonical runtime fixture.
   - Risk: MINT must not assume employee salary, LPP affiliation, or standard
     3a ceiling.
   - Candidate route chain: Coach or setup -> `/budget` -> `/rapport` ->
     `/mortgage/amortization` or `/pilier-3a` depending on scenario.

The missing independent-no-LPP fixture is itself a benchmark gap. It should be
added before the benchmark claims representative coverage.

## Record Template

For every scored flow, record:

- `benchmark_id`
- `persona_id`
- `scenario`
- `matrix_rows`
- `bug_ids`
- `route_sequence`
- `maestro_flow`
- `runtime_evidence`
- `test_evidence`
- `source_evidence`
- `expected_guidance`
- `mint_observed_guidance`
- `scores_by_dimension`
- `score_caps_applied`
- `final_score`
- `missing_to_10`
- `reviewers`
- `claude_cli_status`
- `decision`

## Closure Rule

This benchmark can raise confidence and prioritize work. It cannot close a
matrix row by itself. A row still needs the row-specific runtime, test,
accessibility, localization, data, and release evidence defined in the Journey
Truth Matrix.
