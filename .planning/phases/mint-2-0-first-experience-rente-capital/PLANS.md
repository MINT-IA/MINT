# Mint 2.0 First Experience Rente/Capital — Plans

## Phase Gate

This phase is open for planning only until:

- `STATE-TABLE.md` covers lifecycle, auth/reset, simulator, and iPhone 13 mini layout risks;
- `golden-onboarding-archetypes.md` defines the first scoring set;
- the live door has a contract test plan before UI work;
- the implementation branch/worktree is clean or scoped to this phase;
- Claude review of the workflow doc has no unresolved P1.
- Claude review of this phase contract has no unresolved P1.

Claude workflow review status: `PASS_WITH_FIXES`, P1 fixes incorporated in `docs/MINT_AGENT_WORKFLOW.md`.
Claude phase review status: `PASS_WITH_FIXES`, P1 fixes incorporated here.

## Slice Order

1. `01-contract-before-code`
2. `02-entry-and-three-axes-code-map`
3. `02a-data-dictionary-onboarding-profile`
4. `02b-existing-variable-coverage-map`
5. `03-rente-capital-data-readiness`
6. `04-rente-capital-result-provenance`
7. `05-dossier-navigation-and-account-handoff`
8. `06-simulator-and-gates`

Slice 2 is now proposed as a code-mapped plan. Product code still requires a
separate implementation branch after this plan is accepted.

Slice 2 precondition adds the proposed user-variable dictionary and progressive
profile contract:
`mint-2-0-first-experience-rente-capital-02a-data-dictionary-onboarding-profile-PLAN.md`.
It exists because onboarding/profile implementation must know which fields are
canonical, which keys are deprecated aliases, which constants are versioned,
and which fields are too early for signal axes.
This precondition governs the data/profile contract before Slice 2B onward; the
existing implementation label "Slice 2A" remains the calculator-boundary work
defined in the code-map plan.

The coverage map for that precondition is:
`mint-2-0-first-experience-rente-capital-02b-existing-variable-coverage-map-PLAN.md`.
It records the current repo surfaces and open mismatches so the future runtime
dictionary is a binding/check layer, not a duplicate profile or constants
library.

## Slice 1 — Contract Before Code

File: `mint-2-0-first-experience-rente-capital-01-contract-before-code-PLAN.md`

Goal: create the testable contract that prevents another clipped, premature, or invented first experience.

Exit criteria:

- state table accepted;
- golden fixtures accepted;
- exact first live flow defined;
- non-live axes explicitly blocked from calculation;
- iPhone 13 mini verification path named;
- no code modified.

## Implementation Rule After Slice 1

Implementation must be delegated in small tasks:

1. specialist agent writes or patches;
2. Codex reviews diff and runs local checks;
3. Claude CLI red-team reviews meaningful behavior or architecture;
4. simulator evidence is captured before any "ready" claim.

No slice may close with only screenshots, only tests, or only a written rationale.

## Slice 2 Preconditions

Before code in Slice 2, use
`mint-2-0-first-experience-rente-capital-02-entry-and-three-axes-code-map-PLAN.md`
with:

- exact files to touch, including landing/entry screen and route wiring;
- data dictionary bindings for backend profile keys, `save_fact`, wizard keys,
  `CoachProfile` paths, sensitive-storage coverage, and per-axis readiness;
- coverage-map reconciliation for existing profile/save_fact/onboarding,
  secure-storage, and regulatory-key mismatches;
- explicit reuse of `/rente-vs-capital` rather than a new screen;
- binding calculator-boundary decision for `rente_vs_capital_calculator.dart` vs `financial_core/arbitrage_engine.dart`;
- explicit chat guard and dossier-independence tests;
- versioned persistence and legacy-intent migration tests;
- feature flag `FeatureFlags.enableMint2FirstExperienceEntry` default off;
- widget test asserting three axes visible;
- negative tests asserting signalétique axes do not calculate and do not collect detailed unused data;
- Maestro flow `flow_mint2_first_experience_rente_capital_entry.yaml` starting with `launchApp: { clearState: true }`;
- iPhone 13 mini screenshot or snapshot requirement.
