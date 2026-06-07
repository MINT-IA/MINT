---
description: Row 23 proof that the independent/no-LPP Coach 3a fallback exposes provenance and freshness limits for its money facts.
---

# Row 23 - Independent/No-LPP Coach Provenance And Freshness

Date: 2026-06-07

## Scope

Persona: `independent_no_lpp_income_reality`.

Route: `/coach/chat`.

Prompt: `Combien verser en 3a ?`

This follow-up adds a visible `Provenance et fraîcheur` section to the audited
local Coach 3a answer. It does not pretend that MINT has a field-level update
timestamp inside the fallback response. Instead, it names the available source
and explicitly says that the date by field is not shown in this chat.

## Contract

When the professional income source is known, the response labels it:

- `revenu professionnel: saisie dans MINT`
- `versements 3a planifiés: saisie dans MINT` when
  `q_3a_annual_contribution` explicitly tagged `plannedContributions.3a`
- `versements 3a planifiés: plan MINT` when the planned 3a amount exists
  without source metadata
- `date par champ non affichée`

When source metadata is not available, the response says:

- `revenu professionnel: source non affichée`

When professional income is missing, the response still refuses to compute a
remaining margin and labels the missing fact instead of inventing a number.

## Proof

TDD red proof first failed on the missing provenance/freshness section.

Green proof:

- `flutter test test/services/coach/local_fallback_service_test.dart test/services/coach_profile_wizard_test.dart test/services/data_spine_service_test.dart test/services/coach_context_packet_payload_test.dart test/services/coach_hard_gate_killswitch_test.dart test/screens/coach/coach_chat_test.dart`
- Result: `163` passed, `5` existing skips.

Additional 3a provenance proof:

- `CoachProfile.fromWizardAnswers(...)` now tags
  `plannedContributions.3a` as `ProfileDataSource.userInput` only when
  `q_3a_annual_contribution` is explicitly present and positive.
- Automatic allocation-created 3a contributions remain untagged, avoiding a
  false user-source claim.
- `DataSpineService` reads the same `plannedContributions.3a` source for the
  annual 3a contribution fact.

Runtime proof:

- Flow: `tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_coach_chat_runtime.yaml`
- Evidence: `evidence/maestro-ci/row-23-independent-no-lpp-anti-surface-stable-final2-20260607T142509/`
- Result: `tests=1`, `failures=0`
- Device: `iPhone 16e - iOS 26.2`
- Watchdog: `maestro returned 0`
- Strict assertions: reject `plan MINT`, `source non affichée`, tax-impact
  cards, stale precise amounts, product/open-account wording, overclaiming
  terms, and runtime error markers.
- Screenshot: `row23-independent-no-lpp-coach-local-guidance.png`

## Remaining Gap

This is still a text-level provenance statement. A `10/10` flow needs a
structured UI component with per-field source, timestamp, confidence, and a
profile-update/restart proof.

Row 23 remains `PARTIAL`.
