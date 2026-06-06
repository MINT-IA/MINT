# Row 23 — Growth Priority Guidance Boundary — 2026-06-06

## Scope

Follow-up to the CJT-051/CJT-052 Claude review trail. The next adjacent source
recommendation in `CircleScoringService` still used directive and
optimization-framed language:

- `Développe ta stratégie d'investissement une fois Cercles 1-2 optimisés`

This proof covers the generated growth/investment source priority. It does not
claim a full investment flow, portfolio simulator, or per-archetype suitability
review.

## Change

- Reframed the source priority to evaluation/guidance language:
  - `Évalue un cadre d’investissement une fois protection et prévoyance clarifiées`
- Added a generated-priority test proving the growth priority contains
  `évalue` and `investissement`, and does not contain `développe`, `optimisé`,
  or `optimiser`.

## Mechanical Proof

Red proof:

```bash
cd apps/mobile
flutter test test/services/circle_scoring_service_test.dart --plain-name "growth priority"
```

The new guard failed because the generated priority still contained
`Développe...` and `optimisés`.

Green proof:

```bash
cd apps/mobile
flutter test test/services/circle_scoring_service_test.dart --plain-name "growth priority"
flutter test test/services/circle_scoring_service_test.dart
flutter analyze lib/services/circle_scoring_service.dart test/services/circle_scoring_service_test.dart

cd ../..
python3 tools/checks/banned_terms_python.py apps/mobile/lib/services/circle_scoring_service.dart apps/mobile/test/services/circle_scoring_service_test.dart
python3 tools/checks/mint_quality_os_check.py
python3 tools/checks/cjt_context_guard.py
./tools/mint-routes check
python3 tools/checks/maestro_locator_audit.py
git diff --check
```

Results:

- Focused growth-priority guard passed (`1` test).
- Full `circle_scoring_service_test.dart` passed (`34` tests).
- Targeted analyze passed with no issues.
- LSFin banned-term scan, Quality OS check, CJT context guard, route parity,
  Maestro locator audit, and `git diff --check` passed.

## Runtime Guidance Quality Review

- `user-visible outcome`: generated priorities no longer tell the user to
  develop an investment strategy as an immediate directive.
- `guidance quality`: the new copy asks the user to evaluate an investment
  framework after protection and pension foundations are clarified.
- `non-advice boundary`: the copy does not select products, prescribe an
  allocation, or claim an optimized outcome.
- `remaining qualitative gaps`: no runtime screenshot/VoiceOver proof, no
  portfolio-flow review, and no persona-specific investment suitability scoring.

## Review Layer

- Claude CLI review returned `NO BLOCKING FINDINGS`.
- Claude noted the first positive assertion could be stricter because `évalue`
  also appears in 3a recommendations. The test was tightened to assert the exact
  generated growth-priority sentence.

## Decision

CJT-053 is locally fixed for the generated growth priority guidance boundary.

Row 23 remains `PARTIAL`: this removes one source-copy defect, but it does not
prove full Rapport content quality, investment-flow quality, VoiceOver
traversal, runtime PDF export, or per-archetype financial guidance quality.
