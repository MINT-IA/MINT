---
phase: mint-data-spine-plan-vivant-v1
plan: 05
type: ui-maestro
wave: 5
depends_on:
  - mint-data-spine-plan-vivant-v1-04-ui-maestro-proof-PLAN.md
files_modified:
  - apps/mobile/lib/providers/coach_profile_provider.dart
  - apps/mobile/lib/screens/coach/coach_chat_screen.dart
  - apps/mobile/lib/services/coach/coach_profile_seeds.dart
  - apps/mobile/lib/services/data_spine/coach_packet_insight_presenter.dart
  - apps/mobile/lib/widgets/coach/coach_packet_insight_card.dart
  - apps/mobile/test/services/coach_packet_insight_presenter_test.dart
  - apps/mobile/test/services/coach_profile_seeds_test.dart
  - apps/mobile/test/widgets/coach/coach_packet_insight_card_test.dart
  - tools/simulator/flows/maestro-perfect-set/
autonomous: false
requirements:
  - REQ-DSP-05
must_haves:
  truths:
    - "Plan 05 must prove a visible user-facing behavior, not just payload wiring."
    - "The visible explanation must be grounded in `coach_context_packet` facts and missing fields."
    - "Maestro proof must cover persistence/relaunch/chat explanation on the iPhone simulator."
---

# Plan 05 — Visible Packet-Backed Maestro Proof

## Objective

Add one small visible coach surface that demonstrates the live data spine:
the coach should explain at least one known packet fact and one missing field or
next question, then Maestro must prove the flow after app relaunch.

## Tasks

### Task 1 — Choose the narrow visible surface

Pick the least invasive existing coach screen/card seam. Do not introduce a new
route unless reuse is impossible.

### Task 2 — TDD the visible packet behavior

Add a widget/service test proving the visible copy or action model is derived
from `coach_context_packet`, not raw wizard maps or hardcoded fixtures.

### Task 3 — Implement the UI seam

Render one packet-backed explanation or card state. Keep legacy chat behavior
compatible.

### Task 4 — Maestro proof

Add a flow under `tools/simulator/flows/maestro-perfect-set/` that:

- enters or restores enough profile/budget data to produce a packet;
- relaunches the app;
- opens the coach path;
- asserts the visible explanation uses the expected known fact and missing field.

### Task 5 — Close-out

Run focused Flutter tests, simulator proof, and update the phase summary.

## Non-Goals

- No navigation rewrite.
- No broad budget UI redesign.
- No new financial calculation.

## Close-Out — 2026-05-23

Status: CLOSED.

Implemented:

- Added a `CoachPacketInsightPresenter` that reads only the safe
  `coach_context_packet` map and selects one visible known fact plus one next
  planning field.
- Added `CoachPacketInsightCard` and rendered it in the coach silent opener.
- Added `CoachProfileSeed.toWizardAnswers()` and a debug/e2e-only
  `CoachProfileProvider` bridge so `MINT_E2E_ARCHETYPE=julien_swiss` hydrates
  a real `CoachProfile` for simulator proof without writing production
  persistence.
- Added Maestro flow
  `tools/simulator/flows/maestro-perfect-set/flow_data_spine_visible_coach_packet.yaml`.

Verification:

- `flutter analyze lib/providers/coach_profile_provider.dart lib/screens/coach/coach_chat_screen.dart lib/services/coach/coach_profile_seeds.dart lib/services/data_spine/coach_packet_insight_presenter.dart lib/widgets/coach/coach_packet_insight_card.dart test/services/coach_profile_seeds_test.dart test/widgets/coach/coach_packet_insight_card_test.dart`
  -> No issues found.
- `flutter test test/services/coach_profile_seeds_test.dart test/services/coach_packet_insight_presenter_test.dart test/widgets/coach/coach_packet_insight_card_test.dart test/services/coach_context_packet_service_test.dart test/services/coach_context_packet_payload_test.dart`
  -> All tests passed.
- Simulator build/install/run:
  `flutter build ios --simulator --debug --no-codesign --dart-define=MINT_E2E_ARCHETYPE=julien_swiss --dart-define=MINT_DISABLE_BETA_MODAL=true`
  plus Maestro on iPhone 17 Pro iOS 26.2.
- Maestro run `2026-05-23_175006` passed:
  `Point de départ`, `Déjà clair`, and `Prochaine pièce` visible before and
  after relaunch.

Operational note:

- Simulator build still requires the local codesign shim and xattr cleanup:
  `PATH="$PWD/../../tools/simulator/codesign_shim:$PATH"` and
  `xattr -cr "$HOME/development/flutter/bin/cache/artifacts/engine"`.
