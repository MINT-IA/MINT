phase: mon-argent-budget-cleanup-v2
plan: 39
title: Remove inline chat tone chips
branch: codex/mon-argent-budget-cleanup-v2
date: 2026-05-27

# Phase 39 — Remove inline chat tone chips

The Coach could show `Comment je te parle ?` with `Doux / Direct / Sans filtre`
chips immediately under a data-driven opener. In a financial lucidity flow, that
competes with the user's freshest financial fact and reads like UI clutter.

## Changes

- New Coach sessions now use the default direct cash level without showing the
  inline tone picker.
- Existing saved cash-level preferences still load and suppress the picker.
- The tone chooser components remain available outside the chat surface; this
  phase removes the interruptive inline prompt only.
- The money-trust Maestro flow now guards that Budget -> Mon Argent -> Rapport
  -> Coach does not render the tone chips.

## Verification

- `cd apps/mobile && flutter test test/screens/coach/chat_tone_preference_test.dart`
  - Result: `3 passed`.
- `cd apps/mobile && flutter analyze lib/screens/coach/coach_chat_screen.dart test/screens/coach/chat_tone_preference_test.dart`
  - Result: no issues.
- `bash tools/simulator/maestro_env.sh check-syntax tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`
  - Result: OK.
- `python3 tools/checks/maestro_locator_audit.py tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`
  - Result: all locators resolve.
- `CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --debug --no-codesign --dart-define=MINT_E2E_ARCHETYPE=julien_swiss --dart-define=MINT_DISABLE_BETA_MODAL=true && xcrun simctl install booted build/ios/iphonesimulator/Runner.app`
  - Result: build/install OK.
- `MINT_WALKER_ARTIFACTS=.planning/walker/maestro-flows/money-trust-chain/20260527T154354Z ... flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`
  - Result: passed in 1m02s.
- Claude Opus 4.7 review via `claude -p ... --system-prompt ... --model opus`
  - Result: no blockers; scoped follow-ups applied.
- `MINT_WALKER_ARTIFACTS=.planning/walker/maestro-flows/money-trust-chain/20260527T155156Z ... flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml`
  - Result: passed in 1m02s after dead-code cleanup and anchored chip assertions.
