description: Row 23/CJT-063 proof that independent/no-LPP can reach /coach/chat for audited local guidance without opening non-calibrated LLM access.

# Row 23 - Independent No-LPP Coach Route UI

## Scope

This evidence covers the route/UI layer after the safe local hard-gate
fallback from Row 23h.

Goal:

- let `independent_no_lpp` render `/coach/chat`;
- build a real `CoachContext(archetype: 'independent_no_lpp')`;
- answer the audited FR no-LPP/3a question through deterministic local
  fallback;
- keep generic `independent_no_lpp` questions refused;
- keep `independent_with_lpp` route-gated so the no-LPP fallback never widens
  to a different pension situation;
- keep `expat_us`, `unknown`, cross-border, and other unsupported archetypes
  routed to `/waitlist` or refused;
- keep SLM streaming closed for non-calibrated archetypes.

## Decision

`independent_no_lpp` is route-accessible but not added to the orchestrator
calibrated set.

That means `/coach/chat` can render for this persona, while
`CoachOrchestrator.generateChat(...)` and `CoachOrchestrator.streamChat(...)`
remain the authority for whether a response may be generated.

The route layer deliberately does not duplicate no-LPP/3a keyword matching.
The only topic exception stays in `LocalFallbackService` through the
orchestrator hard gate.

## Changes

- `evaluateCoachArchetypeGate(...)` now returns `shouldBlock=false` for
  `FinancialArchetype.independentNoLpp`, preserving slug
  `independent_no_lpp` for context/telemetry.
- `/coach/chat` comments now state the separation:
  route-accessible does not mean LLM-calibrated.
- `CoachLlmService.chat(...)` preserves `refused`, `refusalReason`, and
  `degraded` from the orchestrator instead of dropping those fields.
- `CoachChatScreen` suppresses BYOK/server transparency text for hard-gated
  local/refusal answers, avoiding false `API Claude` wording for deterministic
  local fallback.
- Route and integration tests now prove `independent_with_lpp` still reaches
  `/waitlist`, not the no-LPP exception.

## Red Proof

Before the route change:

```bash
cd apps/mobile
flutter test \
  test/router/coach_route_archetype_guard_test.dart \
  test/integration/archetype_hard_gate_integration_test.dart \
  test/services/coach_hard_gate_killswitch_test.dart
```

Result:

- `evaluateCoachArchetypeGate independent_no_lpp ... route reachable` failed
  because `shouldBlock` was still `true`.
- `integration_independent_no_lpp_safe_local_route` failed because the fake
  coach landing was not rendered; route logic still navigated toward waitlist.

## Green Proof

Focused send-path proof:

```bash
cd apps/mobile
flutter test \
  test/router/coach_route_archetype_guard_test.dart \
  test/integration/archetype_hard_gate_integration_test.dart \
  test/services/coach_hard_gate_killswitch_test.dart \
  test/screens/coach/coach_chat_test.dart \
  --plain-name independent_no_lpp
```

Result: `7/7` passed.

Impact proof:

```bash
cd apps/mobile
flutter test \
  test/router/coach_route_archetype_guard_test.dart \
  test/integration/archetype_hard_gate_integration_test.dart \
  test/services/coach_hard_gate_killswitch_test.dart \
  test/screens/coach/coach_chat_test.dart \
  test/services/coach/local_fallback_service_test.dart \
  test/services/coach_orchestrator_test.dart \
  test/services/coach_orchestrator_archetype_refusal_test.dart
```

Result: `123` passed, `5` skipped existing tests.

Covered assertions:

- route helper allows `independent_no_lpp`;
- integration route renders coach shell, not `/waitlist`;
- route helper and integration route still block `independent_with_lpp`;
- `expat_us` and `unknown` remain gated;
- `independent_no_lpp` cannot stream through SLM;
- real `CoachChatScreen` send-path renders local guidance for
  `Je suis indépendant sans LPP, combien verser en 3a ?`;
- real `CoachChatScreen` generic independent/no-LPP prompt renders the
  hard-gate refusal;
- local/refusal answers do not display `API Claude` transparency text.

## Review

Architecture reviewer recommendation:

- allow `/coach/chat` route access for `independent_no_lpp`;
- do not add `independent_no_lpp` to `_calibratedArchetypes`;
- do not duplicate the specialized keyword matcher in the route layer;
- require route test, send-path UI test, generic-refusal proof, and stream
  closed proof.

The implemented diff follows that recommendation.

## Boundaries

This does not close Row 23 or CJT-063.

Still open:

- broader independent/no-LPP natural-language Coach calibration beyond the
  audited local topic;
- live backend/LLM scoring for calibrated personas;
- restart/provenance proof for persona facts;
- runtime VoiceOver/AX traversal;
- updated persona-flow scoring after this route/UI change.

Follow-up runtime iPhone 16e proof is now recorded separately at
`evidence/rapport-design/row-23-independent-no-lpp-coach-chat-runtime-20260607.md`.
