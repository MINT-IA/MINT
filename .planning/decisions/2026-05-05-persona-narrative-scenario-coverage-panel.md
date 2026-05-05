---
date: 2026-05-05
status: Decided
authors: Claude (Product Leader, MINT)
panel: 6 parallel domain experts
supersedes: —
superseded_by: —
related:
  - .planning/decisions/2026-05-04-post-handoff2-sweep-panel.md
  - .planning/deep-audit-2026-04-17/02-persona-journeys.md
  - .planning/wave-0-walkthrough-verite/PLAN.md
  - .planning/MVP-FLOW-walkthrough-2026-04-21.md
---

# Persona Narrative Scenario Coverage — v2.13 architecture decision

## Trigger

Julien (founder) asked « Qu'est-ce que tu penses d'avoir des scripts avec
des scénarios qui couvrent ~80% des besoins des utilisateurs… une
cinquantaine de script, KPI = 100% pass rate ». Explicitly noted « on a
déjà essayé de faire cet exercice par le passé » and asked for an expert
panel to find the trap and avoid it this time.

The corpse of « past attempt » is real and documented (see Postmortem
section below). This decision exists so the v2.13 redo cannot rename
itself out of existence the way Phase 51 → Phase 74 → Phase 80-85 did.

## TL;DR — what we are doing

1. **Build a persona narrative scenario suite as the v2.13 milestone**,
   under the existing v2.12 governance umbrella (« no TestFlight before
   Claude validates app PERFECTLY on simulator »). This is the
   validation layer v2.12 promised but did not staff.
2. **Cap initial scope at 2 personas × 1 scenario × 5 phases = 10 cells**
   (per Phase 51 postmortem). Grow only when 10 cells are nightly-green
   for 5 consecutive nights.
3. **Tooling stack: hybrid 3-layer**.
   - L0 = walker_premier_eclairage.sh (existing, kept as machine of
     truth) — owns flutter build with dart-defines, sim boot, install,
     launch, Sentry pull, artifact bundle.
   - L1 = Maestro YAML flows (`tools/simulator/flows/<persona>.yaml`) —
     in-app tap choreography via semantic locators, NOT pixel coords.
   - L2 = Dart post-run assertion suite (`tools/simulator/assertions/
     <persona>.dart`) — semantic events from MintWalkthroughBreadcrumbs
     + LSFin regex library + financial_core numeric assertions +
     archetype assertion.
4. **LLM is mocked at the boundary.** Recorded-fixture replay-cache
   (`tools/simulator/cache/replay/`). No live network call gates the
   suite. (Hard rule from Phase 51 postmortem — the missing
   ANTHROPIC_API_KEY at the dev backend killed the whole effort.)
5. **5 must-pass-before-TestFlight scripts = the journalist defense
   set**. Sofia (indép sans LPP), Lauren (« c'est garanti combien »),
   Anna (deuil 23h), Jennifer (FATCA + 3a), Pierre (rente vs capital
   irreversibility). If those 5 are green and walker is green, MINT
   ships TestFlight. Quality stamp is computed on top, not gating.

## Why this and not «50 scripts»

50 scripts is the Phase 51 trap. Phase 51 (Apr 30 - May 2 2026) targeted
8 archetypes × 7 phases × 6 events = 336 cells, closed `gaps_found`
with 3/5 archetypes × 3/7 phases captured. Phase 74 cut to 4 archetypes
× 1 scenario; STILL required four "walker fix" phases (51-07, 53,
54.1, 82, 85) to keep working. The pattern is clear: **single-persona
narrative walkthroughs produced real findings; multi-archetype
scripted matrices produced 'gaps_found' and got renamed**.

50 is the destination. 10 is the Phase 1 deliverable. Anything bigger
than 10 before nightly-green proves the architecture was the wrong
guess again.

## Panel synthesis

Six experts ran in parallel on 2026-05-05.

### Expert #1 — CI infra cost realist

Verdict: **AFFORDABLE**. Realistic monthly burn ~$80 (Sonnet, cached).
Worst case ~$250 (Opus, uncached, 5 reruns/wk). Mac mini home is
sunk-cost (LaunchAgent + tmux + caffeinate already running). GH
Actions macOS is FREE on public repo. R2 bucket `mint-goldens/`
($0.015/GB/mo, zero egress) holds 50 × 5 × 6 langs × 2 themes = 5.4 GB
goldens. Realistic flake target <3% per script, <8% suite-level. Sim
warm-pool + LLM replay-cache are the two biggest flake mitigations.

Build it. Ship the manifest schema, R2 bucket, replay-cache before
scaling past 10 scripts.

### Expert #2 — E2E architecture (mobile QA)

Verdict: **GO-WITH-MODIFICATIONS**. Pure 50-script suite is the
death-spiral framing every postmortem warns about. Three failure modes
named: maintenance death spiral, hardcoded selectors against localized
UI, scripts that prove navigation but not finance correctness.

Recommended: 12 = 8 archetypes × canonical scenario + 4 hostile
composites (Thomas divorce+debt, Elena returning_swiss, Lauren
expat_us, Marco expat_eu+EPL). 3-layer hybrid (walker / Patrol Dart /
sampled visual). Each script asserts ≥1 numeric checkpoint from
`financial_core/` + ≥1 LSFin assertion + archetype assertion.

### Expert #3 — Storytelling / narrative persona designer

Verdict: 2D matrix HAPPY × FRICTION × BLOCKER × 8 surfaces (Premier
Éclairage cold-start, Housing decision, 3a/LPP rachat, Family
transitions, Career/income shock, Tax & cross-border, Retirement
runway, Onboarding & re-entry). 24 cells filled, ~50 stories total
because high-traffic cells get 2-3 archetype variants.

3-layer story spec: Persona Fixture (versioned JSON) / Narrative
Invariants (Gherkin Given-When-Then on semantic predicates) / Surface
Bindings (auto-regenerated from screen_registry + Semantics labels).
Tests bind to L1 + L2 only.

5 must-pass-pre-TestFlight (journalist defense): A5 Sofia, C3 Lauren,
D5 Anna, F4 Jennifer, G2 Pierre. Each story FAILS only if MINT
promises returns / ranks products / strands user / leaves user without
agency. **« Defer is a passing resolution »** — the brand line « Voir
clair, décider seul » means agency ≥ conversion.

### Expert #4 — Build vs adopt (Maestro vs walker vs Patrol)

Verdict: **HYBRID — keep walker as machine-of-truth shell, adopt
Maestro YAML as the persona DSL**. Not pure Patrol (lock-in, young
framework, breaks phantom contract plumbing). Not pure walker (1800-2400
LoC of new bash, pixel-coord maintenance bomb at 50 scripts × 7-12
steps each ≈ 400-600 hardcoded taps). Not pure Maestro (cannot drive
flutter build dart-defines, no SSIM perceptual diff).

Seam: walker.sh keeps dart-defines / sim boot / install / launch /
Sentry pull; delegates the in-app journey to `maestro test
<flow>.yaml --device booted`; resumes triage emit + AUDIT_TAP_RENDER
table on exit. Persona authoring becomes ~25 lines YAML per scenario
(tapOn:, inputText:, assertVisible:, assertScreenshot:) — Julien-
readable, no Dart, no pixel calibration. 50 scripts × ~25 lines =
~1,250 LoC YAML vs 2,000+ LoC bash.

Migration: 3-4 eng-days. Single biggest risk: Maestro semantic
locators silently break when a Flutter widget loses its Semantics
wrapper. Mitigation: ship `tools/checks/maestro_locator_audit.py` in
the same PR — fails CI when any `tapOn:` literal stops resolving to
a Semantics node.

### Expert #5 — Swiss financial scenario coverage

Verdict: 50 canonical scenarios named, organized by archetype × life-
event with one-line success criterion each. 18 life events ranked by
Swiss-prevalence × MINT-fit (3a #1, LPP job change #2, rent vs buy #3,
tax declaration #4, etc.). LSFin assertion library (regex)
materialized for: banned lexicon (garanti / optimal / sans risque /
parfait), issuer naming (Swiss Life / Generali / VIAC / Frankly /
finpension — must NEVER appear), personalised recommendation
(souscris / achète / tu devrais), defamation (arnaque / escroc),
promise of returns (rapportera / tu gagneras), CHF-must-have-band,
confidence + uncertainty present, FR accent integrity, no retirement-
first framing.

Top 10 journalist-defense scripts: 1, 8, 11, 17, 20, 25, 36, 45, 46,
48 (3a flagship, FATCA, expat WEF, frontalier 3a, indé plafond,
retrait capital, PDF analyse, ranking refusal, garantie refusal,
retirement-capital irreversibility).

5 most dangerous scenarios + mitigation pattern: post-generation
regex gate blocks send + retries with constrained prompt; ISSUERS
regex strip + replace with « ce type de produit »; deterministic
refusal template + 4-layer reframe; archetype-triggered hard handoff
template; scenario-tagged compliance lint + irreversibility disclosure
mandatory.

### Expert #6 — Postmortem of past attempt

Past attempt corpus FOUND, organs still in fridge:
- Phase 51 (Apr 30 - May 2 2026): walker.sh `--archetype` (8 slugs),
  test_walker_archetype.sh, 36 walker run dirs in `.planning/walker/`.
  Closed `gaps_found`. Commit 7660aa4f verbatim: « ANTHROPIC_API_KEY
  is empty in the dev backend env. ~10min investigation across local
  filesystem, Keychain, Railway CLI, Anthropic CLI dirs - no key
  locally provisioned. This is OPERATIONAL, not architectural - blocks
  phases 02-06 across all 3 mandatory archetypes uniformly. »
- Phase 74 / v2.11 (later): walker_premier_eclairage tooling, 4
  archetypes, single scenario. Required Phase 82 + 83 + 85 + 87 to
  stay alive. Coordinate-drift cycle.
- Pattern: « single-persona narrative walkthroughs produced real
  findings; multi-archetype scripted matrices produced 'gaps_found'
  and got renamed ».

6 redo recommendations:
1. Cap at 2 personas × 1 scenario × 5 phases = 10 cells (not 210).
2. Mock the LLM/backend at the boundary. Recorded fixtures.
3. Assert on Sentry breadcrumbs + ARB keys, not screenshot SHA.
4. Run on every PR (CI lane), not as phase milestone.
5. Burn orphan plumbing OR commit to reusing it. No half-alive state.
6. Pick stable selector strategy and lock it. Pixel coords are how
   Phase 51 + 74 + 82 + 85 all bled out.

## Decision (synthesis, my call as Product Leader)

### Tooling

- **Walker stays as L0 build/seed/Sentry layer.** Reuse, do not burn.
  walker_premier_eclairage.sh just shipped its first GREEN run today
  on julien_swiss (6/6 captures, 82s, exit 0). That is a real proof
  point — discarding it would be exactly the « rename instead of
  declare dead » anti-pattern Phase 51 fell into.
- **Maestro YAML for L1 in-app choreography.** Expert #4 wins over
  Expert #2's Patrol-Dart pick because (a) Julien is solo-maintainer
  and YAML is more readable than Dart driver code, (b) Maestro
  preserves the phantom contract plumbing walker owns, (c) Patrol's
  CI flakiness reports are concerning for a 50-script target.
- **Dart assertion suite for L2 post-run.** This is where
  Patrol-style logic comes back: assertions read `MintWalkthrough
  Breadcrumbs`, scan rendered text for LSFin regex (Expert #5's
  library), call `financial_core/` calculators to validate numbers.
  These are ordinary Dart tests, NOT Patrol — they read artifacts
  walker dropped to disk.
- **LLM replay-cache.** `MINT_LLM_CACHE=replay` mode reads from
  `tools/simulator/cache/replay/<persona>/<turn>.json`. `record` mode
  populates the cache from one live run. Suite runs in `replay` mode
  by default — no live API calls. Live mode is opt-in for weekly LLM
  regression run (Expert #1's recommendation).
- **R2 bucket `mint-goldens/`** for goldens. NOT git, NOT git-lfs.
- **`tools/checks/maestro_locator_audit.py`** as blocking lint.

### Number / scope ramp

- **Phase 90** (v2.13 floor): 2 personas × 1 scenario × 5 checkpoints
  = 10 cells. julien_swiss + lauren_expat_us, Premier Éclairage
  scenario, 5 Maestro flow steps each. Maestro adoption + replay-
  cache + R2 bucket + locator audit lint shipped here. **Exit 90 with
  10 cells nightly-green for 5 consecutive nights.**
- **Phase 91**: 8 archetypes × canonical scenario each = 8 scripts.
  Per Expert #2's « if this works, persona works » set. Numeric
  assertions wired to financial_core (AvsCalculator, LppCalculator,
  TaxCalculator).
- **Phase 92**: 5 journalist-defense scripts (Expert #3's set:
  Sofia, Lauren, Anna, Jennifer, Pierre). Plus the 5 most-dangerous
  with their mitigation regex gates. **This phase = the TestFlight
  ship gate.**
- **Phase 93**: grow toward Expert #5's 50-scenario matrix only if
  Phases 90-92 are stable. Stop when journalist-defensible (no new
  story would change the safety profile).

### KPI

- KPI = pass rate on the 13-script suite (10 from Phase 90 + 8 from
  Phase 91 deduped + 5 from Phase 92 deduped). Not « 50 ». 50 is the
  growth target, not the launch gate.
- Per-script success = ≥1 narrative invariant resolved AND ≥1 numeric
  assertion AND ≥1 LSFin regex assertion AND ≥1 archetype assertion.
- Suite-level pass rate target: 100% nightly. Flake budget per script:
  ≤3% (auto-retry once, quarantine after 3 consecutive flakes).
- TestFlight ship gate: 5 journalist-defense scripts green for 5
  consecutive nights AND walker green AND `flutter analyze` clean
  AND `pytest -q` clean.

### Hard scope guards (so v2.13 cannot become Phase 51)

1. NO new persona added to the suite before all current personas are
   nightly-green for 5 nights.
2. NO life-events × archetypes matrix expansion before 10 cells are
   stable.
3. ANY backend dependency MUST have a recorded-fixture mock. No
   ANTHROPIC_API_KEY check should be able to gate a script run.
4. NO « walker overhaul » phase. If coords drift, fix at the locator
   layer (Maestro semantic) — that's the whole point of the redo.
5. NO « delegated_via_substitute » markdown. A script either passes
   or it fails; there is no third state.
6. Each phase has a HARD STOP at scope cap. Phase 90 ships with 10
   cells, period. If the cells reveal new bugs, those become Phase
   91 backlog, not Phase 90 expansion.

## What we explicitly are NOT doing

- Not building a 50-script suite up-front.
- Not migrating to Patrol.
- Not deleting walker.sh.
- Not gating CI on live LLM calls.
- Not asserting on screenshot SHA as primary gate (Sentry breadcrumb
  + LSFin regex + financial_core numeric is the gate).
- Not staging the persona suite as a one-shot phase milestone — it's
  a CI lane that runs nightly and grows incrementally.

## Sources

- /Users/julienbattaglia/Desktop/MINT.nosync/.planning/walker/
  (36 run dirs from past attempt, kept as evidence not deleted)
- /Users/julienbattaglia/Desktop/MINT.nosync/tools/simulator/walker.sh
- /Users/julienbattaglia/Desktop/MINT.nosync/tools/simulator/walker_premier_eclairage.sh
- /Users/julienbattaglia/Desktop/MINT.nosync/.planning/deep-audit-2026-04-17/02-persona-journeys.md
- /Users/julienbattaglia/Desktop/MINT.nosync/.planning/wave-0-walkthrough-verite/PLAN.md
- /Users/julienbattaglia/Desktop/MINT.nosync/.planning/MVP-FLOW-walkthrough-2026-04-21.md
- /Users/julienbattaglia/Desktop/MINT.nosync/CLAUDE.md (banned-terms + 5 TOP rules)
- /Users/julienbattaglia/Desktop/MINT.nosync/docs/MINT_IDENTITY.md
- /Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/services/coach/coach_orchestrator.dart
- /Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile/lib/models/coach_profile.dart
  (FinancialArchetype enum, 8 values)

External:
- Maestro: assertScreenshot reference, iOS sim + idb support, Flutter platform support
- Patrol: pub.dev page + community flakiness reports
- Anthropic API pricing 2026 (Sonnet 4.6 / Opus 4.7)
- GitHub Actions 2026 pricing changes for public repos
- TestDino flaky-test benchmark (industry baseline 4.5-26%)
