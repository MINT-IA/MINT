description: Row 23/CJT-063 local Coach fallback proof for an independent/no-LPP natural-language 3a question.

# Row 23 - Independent No-LPP Coach Fallback Guidance

## Scope

This evidence covers the local FR chat fallback response used by
`CoachOrchestrator.generateChat` when SLM, BYOK, server-key, and anonymous tiers
are unavailable or skipped.

Question covered:

```text
Je suis indépendant sans LPP, combien verser en 3a ?
```

This is not a live backend/LLM semantic eval. It is a deterministic local
contract that prevents the fallback layer from answering an explicit
independent/no-LPP 3a question with the generic salaried/LPP 3a template.

## Change

- `LocalFallbackService` now detects the combined natural-language pattern:
  independent/freelance + no LPP + 3a.
- That pattern takes precedence over the generic `3a` topic.
- `CoachOrchestrator.generateChat` now calls the local FR fallback at the final
  fallback tier, so this contract is no longer a dead service-only proof.
- The specific fallback covers:
  - independent/no-LPP status;
  - 3a ceiling based on declared net activity income;
  - monthly budget capacity as a separate question;
  - AVS-independent status;
  - taxable income for tax impact;
  - accident/loss-of-income cover;
  - liquidity under variable income;
  - optional LPP, 3a, and cash reserves as a tradeoff.
- The regression test also guards against `7 258`, `salarié`, `ouvre`, and
  `fintech` in this answer.
- A negative test verifies that an independent user declaring LPP does not get
  the no-LPP fallback.
- A conflicting-wording test verifies that positive LPP affiliation suppresses
  the no-LPP fallback even if the message also contains an unclear
  `pas de caisse de pension` phrase.
- A wording-variant test verifies that `freelance` + `pas de caisse de
  pension` also reaches the specific no-LPP guidance.
- A detected-topic override test verifies that upstream topic detection can
  target the same specific guidance directly.
- A detected-topic precedence test verifies that `independent_no_lpp_3a` wins
  over a generic `3a` topic when both are supplied by upstream detection.
- The global fallback disclaimer and banned-terms sweeps now include the new
  independent/no-LPP trigger phrase.

## Red/Green Proof

Red proof:

```bash
cd apps/mobile
flutter test test/services/coach/local_fallback_service_test.dart \
  --plain-name 'scores independent no-LPP 3a question as expert guidance'
```

Before the change, the test failed because the answer used the generic 3a
template and did not contain `revenu net d'activité`.

Green proof:

```bash
cd apps/mobile
flutter test test/services/coach/local_fallback_service_test.dart \
  --plain-name 'scores independent no-LPP 3a question as expert guidance'
```

Result: `All tests passed`.

Impact proof:

```bash
cd apps/mobile
flutter test \
  test/services/coach/local_fallback_service_test.dart \
  test/services/coach_orchestrator_test.dart
```

Result: `42/42` passed.

## Boundaries

This improves the deterministic fallback layer only.

Still open:

- live Coach backend/LLM natural-language scoring;
- runtime chat flow evidence for the same question;
- independent/no-LPP archetype gate expansion or explicit calibrated-path
  proof, because the current chat hard gate still protects non-`swiss_native`
  archetypes unless the kill switch is disabled;
- source/provenance/restart proof for the persona facts;
- runtime VoiceOver/AX traversal.
