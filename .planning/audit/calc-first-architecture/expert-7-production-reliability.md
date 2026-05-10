---
title: "Expert 7 — Production Reliability for the « calc = source of truth » pivot"
role: senior production / reliability engineer (financial calc CI)
date: 2026-05-09
mode: read-only research
audience: MINT product + eng leadership
status: Proposed
---

## TL;DR

MINT just pivoted to « calc = source of truth, LLM = illumination ». That elevates the calc layer from « one of three correctness sources » to **the one** load-bearing artefact whose correctness Julien stakes the brand on. Our calc CI today is **example-based and one-sided**: ~56 hand-picked unit tests in `calculator_forge_test.dart`, scenario tests in `avs_logic_test.dart`, no `hypothesis` dependency on the backend, no Mobile↔Backend differential harness, no Swiss-admin oracle pinning, and the only golden CI workflow (`golden-document-flow.yml`) is disabled and scoped to document parsing, not calc. Three moves to land in 6 weeks: (1) **Mobile↔Backend parity harness** as a CI gate, (2) **Hypothesis property suite** on the Python side covering 8 mathematical/legal invariants, (3) **ESTV oracle pin** — capture official Swiss-admin calculator outputs as immutable golden vectors. With those three, MINT can claim « calc-first defensible » with deterministic citation.

---

## 1. Grounding — what's actually in the repo

### 1.1 Mobile calc layer (`apps/mobile/lib/services/financial_core/`)

17 Dart files: `avs_calculator.dart`, `lpp_calculator.dart`, `tax_calculator.dart`, `pillar_3a_calculator.dart` (via `financial_core.dart` aggregator), `housing_cost_calculator.dart`, `cross_pillar_calculator.dart`, `arbitrage_engine.dart`, `confidence_scorer.dart`, `monte_carlo_service.dart`, `tornado_sensitivity_service.dart`, `withdrawal_sequencing_service.dart`, etc. Pure static functions, deterministic, well-cited (LAVS art. 21-29, OAVS art. 53, LPP art. 7-8). Example: `AvsCalculator.computeMonthlyRente()` at `apps/mobile/lib/services/financial_core/avs_calculator.dart:29-118` — 90 lines of branching on RAMD, gapFactor, anticipation/déférement, divorce-splitting (LAVS 29quinquies), child-raising credits (LAVS 29sexies), couple cap (LAVS 35).

### 1.2 Backend calc layer (`services/backend/app/services/`)

Mirror surfaces: `retirement/avs_estimation_service.py`, `retirement/lpp_conversion_service.py`, `independants/avs_cotisations_service.py`, `independants/lpp_volontaire_service.py`, `fiscal/wealth_tax_service.py`, `fiscal/cantonal_comparator.py`, `fri/fri_service.py`, plus 30+ life-event services. Same mathematical surface, different language, **no shared schema or test fixture** — only verbal coordination via `decisions/ADR-20260223-unified-financial-engine.md`.

### 1.3 Test layer — the actual baseline

| Surface | File | Style | Count |
|---|---|---|---|
| Forge | `apps/mobile/test/services/financial_core/calculator_forge_test.dart` | example-based, scenario-grouped | 50 (10 scenarios × 5) — 56 `test(` matches, 490 LOC |
| AVS scenarios | `apps/mobile/test/services/avs_logic_test.dart` | example-based | 3 scenarios |
| Pillar 3a | `apps/mobile/test/services/pillar_3a_calculator_test.dart` | example-based | not counted but standard scenario format |
| Tax extended | `apps/mobile/test/services/tax_calculator_extended_test.dart` | example-based | standard |
| FRI | `apps/mobile/test/services/financial_core/fri_calculator_test.dart` | example-based | standard |
| Disability | `apps/mobile/test/domain/disability_gap_calculator_test.dart` | example-based | standard |
| Backend pillar 3a | `services/backend/tests/test_pillar_3a_deep.py` | example-based, pytest | standard |
| Backend LPP | `services/backend/tests/test_lpp_deep.py` | example-based, pytest | standard |

**Negative findings (what's NOT there)** — confirmed by repo grep:

- `grep -rn "hypothesis\|@given\|@property" services/backend/tests/` → **zero hits**.
- `grep -rn "differential\|parity\|golden" services/backend/tests/ \| grep -i "calc\|avs\|lpp\|pillar\|tax"` → **zero hits**.
- `grep -i hypothesis services/backend/requirements*.txt` → **zero hits** (Hypothesis is not even a dev dep).
- `.github/workflows/golden-document-flow.yml` is the only « golden » workflow. It's `workflow_dispatch` only (manually triggered), `continue-on-error: true`, and was disabled 2026-04-16 with note « cassettes stale, warn-only, costs 1h per push ». And it's about Vision/document parsing, not calc engines.

So today's calc CI = **example-based unit tests in two languages, with no cross-language oracle, no property generator, no external reference, no canary on numerical drift**. That was sufficient when LLM/UI/calc shared the « source of truth » burden. After the 2026-05-09 pivot it's no longer sufficient — the brand-defending claim « calc = source of truth » now has only example tests behind it.

---

## 2. SOTA reference scan (≥4 citations)

### 2.1 Property-Based Testing (PBT) for financial systems

Hypothesis (Python) is the canonical Python PBT framework, originated in QuickCheck (Haskell, Claessen & Hughes 2000). PBT shifts from « what should happen for this input » to « what should always be true regardless of input » — it generates hundreds of randomised cases per run and shrinks failures to minimal counter-examples. Strongly recommended for systems where edge-case discovery matters (cryptography, compilers, finance). For financial domain specifically, properties typically encoded are: monotonicity (more contributions → ≥ rente), bounds (rente ∈ [min, max]), conservation (split + recombine = identity, modulo rounding), and idempotence of pure-function chains. ([hypothesis.works](https://hypothesis.works/articles/what-is-property-based-testing/), [zetcode.com](https://zetcode.com/terms-testing/property-based-testing/), [seas.upenn.edu](https://www.seas.upenn.edu/~cis1940/fall16/lectures/10-testing.html))

### 2.2 Differential / cross-implementation testing

Differential testing runs the same input through two independent implementations and asserts they agree (modulo a documented tolerance). For MINT this is **the natural fit**: Mobile (Dart) and Backend (Python) implement the same Swiss legal surface. Today they drift silently because no test compares them. The fintech-testing literature emphasises differential and parity testing as core CI gates for any system with multi-language calc reimplementation, and notes that automation in CI is the only way to keep two surfaces from drifting. ([devassure.io fintech testing 2025](https://www.devassure.io/blog/fintech-application-testing/), [hypertest.co regression for fintech](https://www.hypertest.co/api-testing/regression-testing-for-fintech-apps))

### 2.3 Golden tests / snapshot regression

Golden tests freeze a known-good output for a known input and fail loudly on any unexpected change. For finance, the failure mode they catch is **silent numerical drift** — a refactor that changes a rounding step, a constants update that shifts a bracket boundary, a Newton-Raphson iteration cap nudged. Golden tests are most valuable when (a) automated in CI, (b) covering a representative input distribution, (c) the golden outputs are rotated against an external oracle on a known cadence (else they ossify into « what we shipped », not « what's correct »). Calling them golden « datasets » in the LLM-eval literature is the same idea generalised. ([shaped.ai golden tests](https://www.shaped.ai/blog/golden-tests-in-ai), [casperblockchain golden tests](https://medium.com/casperblockchain/golden-tests-e521077ae235), [thegreenreport drift detection](https://www.thegreenreport.blog/articles/detecting-data-drift-a-qa-engineers-guide-to-statistical-validation/detecting-data-drift-a-qa-engineers-guide-to-statistical-validation.html))

### 2.4 Reference oracle — Swiss tax administration

ESTV (Eidgenössische Steuerverwaltung / Administration fédérale des contributions) publishes an official Swiss tax calculator at `swisstaxcalculator.estv.admin.ch` with a delegate API at `/delegate/ost-integration/v1/lg-proxy/operation/c3b67379_ESTV`. Community SDKs exist by reverse-engineering. The honest framing: it's not an officially-documented public API, but it is the Swiss-admin authoritative computation surface — perfect oracle for golden vectors covering income tax, wealth tax, capital benefits from pensions, all municipalities. Pinning a corpus of (input, expected) pairs sourced from this calculator gives MINT external grounding instead of « correct = matches our own implementation ». ([estv.admin.ch tax calculator](https://www.estv.admin.ch/en/tax-calculator-calculate-taxes), [devbrains/swisstaxcalculator](https://github.com/devbrains-com/swisstaxcalculator))

### 2.5 SOTA frontier — deterministic simulation testing (DST)

The frontier (FoundationDB → TigerBeetle → Antithesis) wraps the entire system in a deterministic simulator: clocks, threading, RNG, network — all controllable. Bugs reproduce perfectly. Antithesis raised $105M Series A led by Jane Street in Dec 2025 specifically to commercialise this for finance/AI infra. **Aspirational, not a 6-week move for MINT** — calls out direction-of-travel for a calc layer that wants to claim « zero silent regression ». ([antithesis.com DST](https://antithesis.com/docs/resources/deterministic_simulation_testing/), [warpstream blog DST](https://www.warpstream.com/blog/deterministic-simulation-testing-for-our-entire-saas), [Jane Street Series A press](https://www.prnewswire.com/news-releases/jane-street-leads-antithesiss-105m-series-a-to-make-deterministic-simulation-testing-the-new-standard-302631076.html))

---

## 3. The three questions

### Q1 — What's missing in MINT's calc-correctness CI to make « calc = source of truth » a credible claim?

Three concrete gaps, ranked by brand-risk:

**Gap A — No Mobile↔Backend differential harness.** Two implementations of LAVS art. 21-35 exist (Dart `AvsCalculator.computeMonthlyRente`, Python `AvsEstimationService`). They were synced once, by hand, and there is no CI gate that fires when one drifts. The 2026-02-23 ADR pinned « source of truth = backend » verbally, but verbal pinning + zero parity tests = silent drift waiting to happen. **Brand-risk if Julien sim shows X CHF and the backend report shows X+47 CHF on the same profile.**

**Gap B — No property tests on number invariants.** All 50+ calc tests are example-based: « given specific inputs, expect specific output ». That doesn't prove monotonicity, doesn't prove bounds-respect, doesn't prove the couple-cap is always ≤ 150% of individual max, doesn't prove rente ≥ 0 across the entire input space. PBT with `hypothesis` would generate thousands of cases per run and shrink failures — and Hypothesis isn't even installed.

**Gap C — No external reference oracle.** Today « correct » = « matches our own constants and our own table lookups ». A typo in `Echelle 44` data, an off-by-one in a bracket boundary, a stale 2024 RAMD constant — none of these are caught because the test asserts what we wrote, against what we wrote. ESTV publishes a Swiss-admin authoritative calculator. Not pinning golden vectors against it means our « source of truth » is self-referential.

Secondary gaps (lower priority, list-exhaustive): no canton-by-canton coverage matrix; no LPP plan-type matrix (cash-balance vs primat-prestations); no ARB-key parity for calc explainers; no pass/fail dashboard at PR-time; no « 13e rente » feature-flag golden (active/inactive duality); no cross-pillar coherence test (3a + LPP + AVS sum vs cross_pillar_calculator total).

### Q2 — Top SOTA reference for high-confidence financial calc CI

[**Antithesis Deterministic Simulation Testing**](https://antithesis.com/docs/resources/deterministic_simulation_testing/) — takeaway: « the frontier of financial-system correctness is a deterministic simulator that compresses years of stress into hours and reproduces bugs perfectly; not adopting it tomorrow is fine, but pretending you have brand-defending calc reliability without at least the three layers below it (PBT + differential + golden-with-external-oracle) is hand-waving ».

For pragmatic 6-week targets, **the actually-actionable SOTA reference is the [Hypothesis property-based testing playbook](https://hypothesis.works/articles/what-is-property-based-testing/)** — takeaway: « shift from example-based to property-based for number-heavy code; the speed-up in bug discovery on edge cases pays for itself within the first 2-3 properties on a calc engine ».

### Q3 — Three calc-reliability moves to land in the next 6 weeks

**Move 1 — Mobile↔Backend differential harness (Week 1-2)**
- Pin 200 frozen profile fixtures (canton × age × civil_status × income_band × archetype), JSON in `services/backend/tests/fixtures/calc_parity/`.
- Write a Python harness that runs each fixture through `AvsEstimationService`, `LppDeepService`, `Pillar3aService`, `WealthTaxService`, and emits a `parity_baseline.json`.
- Write a Dart test in `apps/mobile/test/services/financial_core/parity_test.dart` that loads the same fixtures, runs them through `AvsCalculator`, `LppCalculator`, `Pillar3aCalculator`, `TaxCalculator`, and asserts each numeric field matches within tolerance (CHF ±1 for amounts > 1k, ±0.05 for amounts < 1k).
- Tolerance is explicit, documented, regression-failed in CI. Drift is now visible.
- **Citation when shipped:** `parity_baseline.json` sha + Dart test exit 0 + GH Actions run URL.

**Move 2 — Hypothesis property suite (Week 2-3)**
- Add `hypothesis>=6.100` to `services/backend/requirements-dev.txt`.
- New file `services/backend/tests/properties/test_avs_properties.py` with these eight invariants encoded as `@given` strategies:
  1. **Bounds**: `0 <= rente_mensuelle <= 2520` for all reasonable inputs.
  2. **Monotonicity in income**: ∀ s1 < s2 (within RAMD bracket), `rente(s1) <= rente(s2)`.
  3. **Monotonicity in contribution years**: ∀ y1 < y2, `rente(...years=y1) <= rente(...years=y2)`.
  4. **Couple cap**: ∀ user, conjoint, married → `total_couple <= 150% × 2520 × (13 if 13e else 12)`.
  5. **Anticipation reduction sign**: ∀ retirementAge < refAge → `rente <= rente_at_refAge` (penalty never positive).
  6. **Deferral bonus sign**: symmetrically.
  7. **Rounding sanity**: `roundTo5Centimes(x)` ≡ `x` mod 0.05.
  8. **Annual rente identity**: `annualRente(m, include13eme=False) == 12*m`.
- Mirror the relevant ones in Dart via `package:test` parameterised tests (Dart has no Hypothesis, but seeded `Random()` + 1000 iterations approximates).
- **Citation when shipped:** `pytest tests/properties/ -q --hypothesis-show-statistics` exit 0, with statistics block pasted in PR.

**Move 3 — ESTV / official-source golden corpus (Week 3-6)**
- Capture a corpus of 50 (input, expected) tax pairs from `swisstaxcalculator.estv.admin.ch` covering: (a) 5 representative cantons (VD/GE/ZH/BE/TI), (b) income brackets {30k, 60k, 90k, 150k, 250k}, (c) civil-status × kids matrix.
- Capture them once, manually if API is unstable, freeze in `services/backend/tests/fixtures/oracle/estv_2025.json` with provenance metadata: `{captured_at, captured_by, source_url, tax_year, fragility_note}`.
- Add `test_oracle_estv.py` that runs each fixture through MINT's `WealthTaxService` + `cantonal_comparator` and asserts CHF ±5 (canton-level computation is famously non-linear, ±5 is the realistic bar).
- Add a yearly recapture issue template `.github/ISSUE_TEMPLATE/recapture_estv_oracle.md` to fire each January when constants update — the corpus must rotate or it ossifies.
- **Citation when shipped:** `estv_2025.json` sha + recapture issue created + test passing in CI on a fresh checkout.

After M1+M2+M3 land, the « calc = source of truth » claim has 3 deterministic citations: parity test green, property suite green with statistics, oracle suite green against ESTV-derived ground truth. That is the bar for « calc-first defensible ».

---

## 4. Top counter-argument — over-engineering CI as a velocity tax

The honest counter: « 200 fixtures + 8 properties + 50 ESTV vectors = ~258 new test artefacts, all of which Julien now has to maintain when LAVS art. 34 changes (13e rente January 2027), when Echelle 44 ratchets in 2026/2028, when a canton tweaks its tax multiplier. The maintenance burden could exceed the bug-prevention benefit. PBT also has a known failure mode: properties that are too lax (« rente >= 0 ») pass trivially and create false-confidence; properties that are too tight reject legitimate refactors and create churn ».

**The right « confidence-per-test » dial:**

1. **PBT properties only on invariants the legal text actually guarantees** — bounds (LAVS art. 34), monotonicity (LAVS art. 29 — gap-factor is linear in years), couple cap (LAVS art. 35). Don't write a property for « rente increases smoothly across RAMD bracket boundaries » because Echelle 44 has step discontinuities and that's *correct* behaviour.

2. **Differential parity only on the function-level public API** — `AvsCalculator.computeMonthlyRente` outputs vs `AvsEstimationService.estimate(...).rente_mensuelle`. Don't parity-test internal helpers; they're allowed to diverge as long as the public surface agrees.

3. **Golden oracle vectors only on shapes the ESTV calculator covers** — income tax, wealth tax, capital. Don't try to golden-pin LPP plan-type quirks where the oracle doesn't help and the maintenance burden is high.

4. **Tolerance is the lever** — CHF ±1 on rentes > 1k, ±5 on canton-level tax, ±0.05 on small amounts. Tight enough to catch silent drift, loose enough to allow legitimate Newton-Raphson convergence variation.

5. **Triage failures by impact, not by count** — a property failure on « anticipation never increases rente » is brand-killing. A golden drift of CHF 4 on a canton tax in TI on a CHF 34k profile is not. CI should distinguish them (block-vs-warn).

The goal is not « more tests ». It's three independent grounding axes (cross-impl, math-invariant, external oracle) so the « source of truth » claim isn't self-referential. Three is the floor. Beyond ~10 properties / ~300 fixtures / ~100 oracle vectors, marginal confidence-per-test plateaus.

---

## 5. Three concrete proposals for MINT's roadmap

### Proposal 1 — Phase « Calc-CI Foundations » (6 weeks, owner: backend lead + Julien)

Land Move 1 + Move 2 + Move 3 above as a single GSD phase. Exit criteria:
- `apps/mobile/test/services/financial_core/parity_test.dart` exists, green, reads from `services/backend/tests/fixtures/calc_parity/parity_baseline.json` (200 fixtures).
- `services/backend/tests/properties/` directory with ≥ 8 property tests, all green, statistics block in PR description.
- `services/backend/tests/fixtures/oracle/estv_2025.json` with ≥ 50 vectors and provenance metadata; `test_oracle_estv.py` green.
- New CI job `calc-correctness-gate` in `ci.yml` that runs parity + properties + oracle, BLOCKS merge on any failure.
- README badge « calc-correctness: 3-axis green » with last-run timestamp.

Cost: ~40 eng-hours backend, ~20 eng-hours mobile, ~10 hours manual ESTV capture. Risk: ESTV API instability — mitigation = manual capture into JSON, accept 1× year recapture cost.

### Proposal 2 — Add « calc-CI gate » to PERIMETERS.md as a 6th mechanical gate

Today PERIMETERS.md tracks 5 mechanical gates (G1 sim walker, G2 device by Julien, G3 dev CI, G4 regression tests, G5 LSFin+accent+ARB lint). Add **G6 calc-correctness** = parity + properties + oracle suites green on the perimeter's branch. Any perimeter that touches `financial_core/` or `services/backend/app/services/{retirement,fiscal,fri,independants}/` cannot reach « PROVISIONALLY READY » without G6 explicit citation. This wires the 0-trust §9 protocol directly into calc reliability — no « calc shipped » without G6 deterministic evidence.

### Proposal 3 — Introduce an annual « calc rebase » ritual + ADR

Constants change (RAMD, BVG-LPP coordination deduction, AVS reference age cohorts, 13e rente activation, canton multipliers). MINT today has no ritualised process for re-grounding the constants and re-capturing the oracle. Propose:
- New ADR `decisions/ADR-2026Q3-calc-rebase-ritual.md` documenting an annual January cycle: (a) re-read OFAS Memento 6.01 + ESTV constant updates, (b) update `apps/mobile/lib/constants/social_insurance.dart` + Python mirror, (c) re-capture ESTV oracle vectors, (d) re-run full property suite for unexpected failures (the suite should pass — if it fails, that's a finding worth investigating before shipping), (e) bump pubspec version with `calc-year=2026` tag.
- Recurring GitHub issue scheduled for Jan 5 each year. Owner = product (Julien decides if a constant change needs user-facing communication beyond the calc).

This is the discipline that distinguishes a one-off CI build from a calc layer that stays defensible across years of legal change.

---

## 6. Citations summary (≥4)

1. [Hypothesis — what is property-based testing](https://hypothesis.works/articles/what-is-property-based-testing/) — PBT framework canon, generators + shrinking.
2. [ZetCode — PBT tutorial 2025](https://zetcode.com/terms-testing/property-based-testing/) — practical 2025 best-practices summary.
3. [Antithesis — deterministic simulation testing](https://antithesis.com/docs/resources/deterministic_simulation_testing/) — frontier reference for finance correctness.
4. [Jane Street leads Antithesis $105M Series A](https://www.prnewswire.com/news-releases/jane-street-leads-antithesiss-105m-series-a-to-make-deterministic-simulation-testing-the-new-standard-302631076.html) — Dec 2025 funding signal that DST is the SOTA direction.
5. [Shaped.ai — golden tests](https://www.shaped.ai/blog/golden-tests-in-ai) — snapshot regression + drift detection in CI.
6. [Casper blockchain — golden tests](https://medium.com/casperblockchain/golden-tests-e521077ae235) — golden-master technique.
7. [DevAssure — fintech application testing 2025](https://www.devassure.io/blog/fintech-application-testing/) — fintech CI/regression playbook.
8. [HyperTest — fintech regression testing](https://www.hypertest.co/api-testing/regression-testing-for-fintech-apps) — regression as a CI gate for finance.
9. [ESTV — Swiss tax calculator](https://www.estv.admin.ch/en/tax-calculator-calculate-taxes) — Swiss-admin authoritative source for tax oracle.
10. [devbrains/swisstaxcalculator on GitHub](https://github.com/devbrains-com/swisstaxcalculator) — reverse-engineered API client, useful pattern for capture script.
11. [The Green Report — drift detection](https://www.thegreenreport.blog/articles/detecting-data-drift-a-qa-engineers-guide-to-statistical-validation/detecting-data-drift-a-qa-engineers-guide-to-statistical-validation.html) — KS test + statistical drift, applicable to numerical golden corpora.
12. [WarpStream — DST for entire SaaS](https://www.warpstream.com/blog/deterministic-simulation-testing-for-our-entire-saas) — case study, DST as a real-world cost-justified investment.

---

## 7. Counter-arguments and data gaps (wiki-lint requirement)

**Counter-argument** (already addressed §4): over-engineering CI is itself a brand-risk via velocity tax + churn from over-tight properties. Mitigation: 3-axis floor, not « more is better »; tolerances calibrated to real Swiss-law non-linearities; triage block-vs-warn.

**Data gap A** — I did not run the test suites to count current pass rate or baseline number of « number-touching » tests. The 56-test count for `calculator_forge_test.dart` is a `grep -c "test"` count, not a `flutter test` exit count. A fuller audit would run both suites and produce a precise baseline.

**Data gap B** — I did not verify ESTV API stability empirically. Community SDKs warn « can break at any time ». The proposal pivots to manual JSON capture if the API proves unstable; that's a contingency, not a verified plan. A first-week task in the phase would be: hit the delegate URL with 5 sample requests and assess.

**Data gap C** — I did not benchmark Python `hypothesis` runtime cost. With 8 properties × default 100 examples × ~10ms per call ≈ 8 seconds. Probably fine for CI but the actual cost depends on how nested the strategies are. Worth a 30-min benchmark before committing CI minutes to it.

**Data gap D** — I assume Mobile↔Backend already implements the *same* legal surface for the 4 main calculators. If a quick audit shows e.g. backend `LppDeepService` has features mobile `LppCalculator` doesn't, the differential harness needs scoping logic (assert-on-shared-fields, document divergences). That's a pre-Move-1 audit task.

---

*end report — 2026-05-09 — Expert 7 / production reliability*
