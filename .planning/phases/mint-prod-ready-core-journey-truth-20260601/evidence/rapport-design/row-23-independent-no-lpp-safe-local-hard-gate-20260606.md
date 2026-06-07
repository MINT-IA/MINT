description: Row 23/CJT-063 safe local hard-gate exception for independent/no-LPP Coach fallback guidance.

# Row 23 - Independent No-LPP Safe Local Hard Gate

## Scope

This evidence covers one bounded hard-gate exception:

- archetype: `independent_no_lpp`
- language: `fr`
- user question: `Je suis indépendant sans LPP, combien verser en 3a ?`
- output tier: deterministic local fallback only

The goal is to let a true independent/no-LPP user receive the already-audited
local guidance for this specific safe topic without opening SLM, BYOK,
server-key, anonymous, or generic fallback access for non-calibrated
archetypes.

## Change

- `LocalFallbackService.generateSpecializedFallback(...)` returns nullable
  specialized guidance only.
- The local 3a templates read `pillar3a.income_rate_without_lpp`,
  `pillar3a.max_without_lpp`, and `pillar3a.max_with_lpp` through `reg(...)`,
  preserving local fallback constants only as the offline/cache-miss fallback.
- Generic topics such as `Comment fonctionne le pilier 3a ?` return `null` from
  the specialized API.
- `CoachOrchestrator.generateChat(...)` checks this safe local fallback before
  returning the hard-gate refusal.
- If no specialized safe fallback matches, the original hard-gate refusal still
  fires.
- `CoachOrchestrator.streamChat(...)` also returns `null` for non-calibrated
  archetypes under the hard gate, so a gated user cannot enter SLM streaming
  before the standard hard-gated `generateChat(...)` path.

## Red/Green Proof

Red proof:

```bash
cd apps/mobile
flutter test test/services/coach_hard_gate_killswitch_test.dart \
  --plain-name '4b. enableCoachHardGate=true + independent_no_lpp safe local topic → deterministic fallback'
```

Before the change, the test failed because `independent_no_lpp` was refused
before reaching local fallback.

Green proof:

```bash
cd apps/mobile
flutter test test/services/coach_hard_gate_killswitch_test.dart \
  --plain-name '4b. enableCoachHardGate=true + independent_no_lpp safe local topic → deterministic fallback'
```

Result: `All tests passed`.

Stream red/green proof:

```bash
cd apps/mobile
flutter test test/services/coach_hard_gate_killswitch_test.dart \
  --plain-name '4e. enableCoachHardGate=true + expat_us cannot stream via SLM'
```

Before the stream guard, the test failed because `streamChat(...)` returned a
non-null SLM stream for `expat_us` when SLM flags were enabled.

After the guard, the targeted test passed.

Impact proof:

```bash
cd apps/mobile
flutter test \
  test/services/coach/local_fallback_service_test.dart \
  test/services/coach_orchestrator_test.dart \
  test/services/coach_hard_gate_killswitch_test.dart \
  test/services/coach_orchestrator_archetype_refusal_test.dart
```

Result: `60/60` passed.

Follow-up 2026-06-07:

```bash
cd apps/mobile
flutter test \
  test/services/coach/local_fallback_service_test.dart \
  test/services/coach_hard_gate_killswitch_test.dart \
  test/screens/coach/coach_chat_test.dart
```

Result: `89` passed, `5` existing skipped.

This follow-up also adds a registry-cache regression test proving the local
guidance follows mocked `pillar3a.*` values instead of fixed literals.

## Boundaries

Still open:

- live Coach backend/LLM natural-language scoring for the persona;
- runtime chat flow evidence on iPhone 16e;
- broader independent/no-LPP Coach calibration beyond this local safe topic;
- restart/provenance proof for the persona facts;
- runtime VoiceOver/AX traversal.
