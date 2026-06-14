# Mint 2.0 First Experience Rente/Capital - Slice 2 Code Map Plan

Status: Proposed planning artifact. Product code is out of scope for this PR.
Branch: `codex/mint-2-slice-2-code-map-plan-20260614`.

Evidence: Claude CLI review returned `GO WITH FIXES` on 2026-06-14 and the fixes
below incorporate its B1/B2/B3/P1/P2 findings.
Caveat: this file is a planning contract only; no mobile behavior changes until
a separate implementation branch starts from `dev`.

## Objective

Prepare the first product implementation slice for Mint 2.0 without creating a
new product surface. The future implementation must make `/onb` show three
Swiss life-event axes and send only the live rente/capital axis into the
canonical `/rente-vs-capital` surface. Logement and fiscal remain signalétique:
they can explain and notify, but they cannot collect unused detailed data,
invoke calculators, or show financial numbers.

## Non-Goals

- No product code in this planning PR.
- No new route for the first experience.
- No new rente/capital screen.
- No new calculator.
- No chat-first product path.
- No account-first gate before the live value or missing-fields response.
- No detailed logement or fiscal collection until their own live phases exist.

## Code Evidence Read

- `apps/mobile/lib/app.dart:344` redirects `/start` to `/onb`; `:352` builds
  `OnboardingShellScreen`; `:820` builds `/rente-vs-capital`; `:825` and `:832`
  preserve legacy redirects into `/rente-vs-capital`.
- `apps/mobile/lib/routes/route_metadata.dart:122` documents `/start`;
  `:129` documents `/onb`; the route registry is parity-checked by
  `tools/mint-routes`.
- `apps/mobile/lib/router/route_scope.dart:15` says authenticated routes accept
  signed-in or local anonymous users, so the future "no account gate before
  value" proof must exercise local anonymous, not just public `/onb`.
- `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart:102`
  dispatches the onboarding step machine; `_IntentsStep` is the current T2 UI.
- `apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_provider.dart:424`
  flushes answers through `ReportPersistenceService.saveAnswers` and
  `CoachProfileProvider.mergeAnswers`; `:428` persists `onb_intent`.
- `apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart:542` calls
  `ApiService.compareRenteVsCapital`; `:561` falls back to
  `ArbitrageEngine.compareRenteVsCapital`; this fallback cannot stay silent in
  the Mint 2.0 live path.
- `apps/mobile/lib/services/financial_core/arbitrage_engine.dart:90` is the
  mobile L1 comparison entry point and already emits result metadata through
  `ArbitrageResult`.
- `apps/mobile/lib/domain/rente_vs_capital_calculator.dart:107` is a parallel
  pure Dart calculator still covered by tests; it needs a binding disposition
  before UI code routes any Mint 2.0 traffic.
- `apps/mobile/lib/services/feature_flags.dart:104` contains the existing
  `enableMvpWedgeOnboarding` flag; `:167` applies backend overrides through
  `applyFromMap`.
- `tools/simulator/flows/maestro-perfect-set/flow_row17_rente_vs_capital_*`
  deeplink `/rente-vs-capital`; they do not prove first-entry from clear state.

Reproducible grep commands:

```bash
rg -n "path: '/start'|path: '/onb'|path: '/rente-vs-capital'|path: '/arbitrage/rente-vs-capital'|path: '/simulator/rente-capital'" apps/mobile/lib/app.dart
rg -n "OnboardingIntent|ReportPersistenceService|onb_intent" apps/mobile/lib/screens/onboarding/mvp_wedge apps/mobile/lib/models/onboarding_intent.dart apps/mobile/lib/services/report_persistence_service.dart
rg -n "ApiService\\.compareRenteVsCapital|ArbitrageEngine\\.compareRenteVsCapital|computeRenteVsCapital|catch \\(_\\)" apps/mobile/lib/screens/arbitrage apps/mobile/lib/services/financial_core apps/mobile/lib/domain
rg -n "enableMvpWedgeOnboarding|applyFromMap|enableExplorerRetraite" apps/mobile/lib/services/feature_flags.dart apps/mobile/lib/routes/route_metadata.dart
```

## Binding Decisions For Slice 2

1. Reuse `/onb` and `/rente-vs-capital`.
   The future implementation changes the current T2 intent step under `/onb`
   behind a new flag. It does not add `/mint-2`, `/first-experience`, or a
   second rente/capital route.

2. Pin the three axes.
   Canonical axis ids:
   `lpp_rente_capital`, `logement_signal`, `fiscal_signal`.
   User-facing FR labels go through ARB/i18n and must preserve the contract
   taxonomy: 2e pilier rente/capital, logement, fiscal.

3. Version persistence instead of mutating the old enum silently.
   Add a future persisted field `onb_axis_v2` plus
   `onb_axis_schema_version = 2`. Keep `onb_intent` only as a compatibility
   bridge for existing consumers. Legacy values map as follows:
   `retraite -> lpp_rente_capital`, `achat -> logement_signal`,
   `impots -> fiscal_signal`, `explorer -> legacy_explore_needs_choice`.
   Existing `explorer` profiles must not crash, auto-route to a live calculator,
   or disappear from the dossier.

4. Bind the calculator source of truth before UI work.
   `financial_core/arbitrage_engine.dart` is the mobile L1 source of truth for
   the live rente/capital path. `ApiService.compareRenteVsCapital` may remain a
   backend comparison path only when its response carries an equivalent receipt.
   `domain/rente_vs_capital_calculator.dart` must receive no new caller. The
   first implementation PR must either delete it after migrating tests, or
   demote it to an adapter with an equivalence test against `ArbitrageEngine`.

5. Remove silent fallback semantics from the live proof.
   If backend comparison fails and local L1 renders a number, the receipt must
   show calculation origin, version, assumptions, sources, readiness, and
   missing fields. If that receipt cannot be produced, no number renders.

6. Keep chat out of the product core.
   Slice 2 does not implement chat behavior. It must add guard tests proving
   chat invokes no calculator, renders no financial number for this flow, and
   can only navigate or explain. The dossier must persist without chat.

7. Name the feature flag and kill behavior.
   Future flag: `FeatureFlags.enableMint2FirstExperienceEntry = false`.
   The flag gates only the new three-axis T2. When false or killed, `/onb`
   keeps the current four-intent behavior. Tests must prove the flag is wired
   through `applyFromMap` and is not bypassed by `/start`.

8. Account handoff happens after value.
   Local anonymous users must reach either a provenance-tagged result or a
   missing-fields response before any account handoff. The account handoff then
   preserves or discards the local dossier only after explicit user choice.

## Future PR Sequence

1. Slice 2A: calculator-boundary decision and tests.
   Files to touch: `rente_vs_capital_screen.dart`,
   `financial_core/arbitrage_engine.dart`,
   `domain/rente_vs_capital_calculator.dart`, existing RvC tests.
   Tests: `arbitrage_engine_rvc_boundary_test.dart`,
   `rente_vs_capital_receipt_gate_test.dart`.
   Acceptance: one mobile L1 source is named, backend/local origins are visible,
   missing fields block numbers, and the domain calculator is deleted or
   adapter-scoped with equivalence coverage.

2. Slice 2B: flag and persistence migration.
   Files to touch: `feature_flags.dart`, `onboarding_provider.dart`,
   `onboarding_intent.dart` or a new axis model, `report_persistence_service.dart`
   only if the versioned field needs explicit helpers.
   Tests: `feature_flags_mint2_first_experience_test.dart`,
   `mint2_first_experience_intent_migration_test.dart`.
   Acceptance: flag default false, `applyFromMap` strict-bool behavior, old
   `onb_intent` values migrate deterministically, and `explorer` requires a new
   choice instead of routing to a live calculation. The migration test must
   assert `explorer -> legacy_explore_needs_choice` by name.

3. Slice 2C: three-axis T2 UI behind the flag, plus chat guard.
   Files to touch: `onboarding_shell_screen.dart`, `dossier_strip.dart` only if
   dossier display needs a new row, six ARB files:
   `app_fr.arb`, `app_en.arb`, `app_de.arb`, `app_es.arb`, `app_it.arb`,
   `app_pt.arb`.
   Tests: `mint2_first_experience_axes_test.dart`,
   `mint2_first_experience_signal_axes_test.dart`,
   `mint2_first_experience_iphone13mini_layout_test.dart`,
   `mint2_chat_navigation_guard_test.dart`.
   Acceptance: all three axes are visible at 375pt width with no overflow;
   logement and fiscal show explicit signalétique status, invoke zero
   calculators, and show zero financial numbers. Chat invokes no calculator,
   shows no financial number, and only navigates or explains. Changed FR copy
   passes accent lint in addition to ARB parity.

4. Slice 2D: live axis bridge to `/rente-vs-capital`.
   Files to touch: `onboarding_provider.dart`, `app.dart` only if routing extra
   shape changes, `route_metadata.dart` only if route metadata changes,
   `rente_vs_capital_screen.dart`.
   Tests: `mint2_first_experience_route_scope_test.dart`,
   `rente_vs_capital_prefill_test.dart`, `rente_vs_capital_defaults_test.dart`.
   Acceptance: local anonymous can choose the live axis and reach a result or
   missing-fields response without account creation; legacy redirects still
   target `/rente-vs-capital`.

5. Slice 2E: dossier continuity and account handoff.
   Files to touch: onboarding provider/screen and existing account handoff
   service only if reuse requires wiring.
   Tests: `mint2_dossier_persistence_test.dart`,
   `register_account_entry_test.dart` additions.
   Acceptance: selected axis and answers survive app restart outside chat;
   reset clears the local diagnostic; account handoff appears only after value
   or missing-fields response.

6. Slice 2F: runtime proof.
   File to add:
   `tools/simulator/flows/maestro-perfect-set/flow_mint2_first_experience_rente_capital_entry.yaml`.
   Flow contract: `launchApp: { clearState: true }` -> `/start` -> `/onb` ->
   three axes visible -> tap 2e pilier rente/capital -> no account gate ->
   result or missing-fields response with receipt -> account handoff.
   Acceptance: iPhone 13 mini simulator proof is captured. Row17 deeplink flows
   remain useful RvC checks, but they do not count as first-entry proof.

## Verification Matrix

| Contract clause | Future test/proof |
|---|---|
| Three axes visible | `mint2_first_experience_axes_test.dart` and 375pt layout test |
| Rente/capital only live | signalétique negative test plus RvC route scope test |
| Logement/fiscal signalétique only | zero calculator calls, zero financial numbers, not-live copy |
| No number without receipt | `rente_vs_capital_receipt_gate_test.dart` |
| Provenance/readiness/version/missing fields together | receipt gate test blocks incomplete values |
| No silent fallback | calculator-boundary test asserts origin and version on local fallback |
| Chat navigation/orchestration only | `mint2_chat_navigation_guard_test.dart` |
| Dossier independent from chat | restart persistence test with no chat interaction |
| No account gate before value | local-anonymous route/scope and handoff-after-value tests |
| Legacy intent migration | versioned `onb_axis_v2` migration test |
| i18n/ARB | `flutter gen-l10n` plus ARB parity across six ARB files |
| iPhone 13 mini proof | Maestro clear-state flow plus 375pt widget/golden test |

## Planning PR Verification

Run before reporting this planning PR:

```bash
git diff --check -- .planning/ACTIVE_CONTEXT.json .planning/phases/mint-2-0-first-experience-rente-capital
python3 tools/checks/no_legal_admission_in_public_docs.py --paths .planning/phases/mint-2-0-first-experience-rente-capital
git diff --name-only -- apps services tools docs rules.md AGENTS.md CLAUDE.md
python3 tools/checks/active_context_guard.py
python3 tools/checks/phase_contract_guard.py
python3 tools/checks/mint_rules_guard.py
python3 tools/checks/agent_reference_guard.py
python3 tools/checks/claude_hooks_guard.py
python3 tools/checks/verify_phase_acceptance.py
python3 -m pytest tools/checks/tests/test_active_context_guard.py tools/checks/tests/test_phase_contract_guard.py tools/checks/tests/test_mint_rules_guard.py tools/checks/tests/test_agent_reference_guard.py tools/checks/tests/test_claude_hooks_guard.py tools/checks/tests/test_verify_phase_acceptance.py -q
```

`required_phase_files` stays limited to canonical `CONTEXT.md`, `SPEC.md`,
`PLAN.md`, and `VERIFICATION.md`; this slice plan is registered through
`PLANS.md` and `.planning/INDEX.md`.

Product code remains blocked unless these planning checks pass and Julien gives
GO for the implementation sequence.
