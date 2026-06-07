description: Row 23/CJT-063 proof that independent/no-LPP 3a room uses a dedicated professional net-income source.

# Row 23 - Independent No-LPP Professional Net Source

## 2026-06-07 Quality Review Caveat

This evidence remains valid for the professional net-income source plumbing, but
its runtime card hierarchy is superseded by
`evidence/quality-review/maestro-flow-scoreboard-20260607.md`.

The captured `Versement 3a 2026` / `Impact fiscal indicatif 2'218 CHF` card is
now treated as a Row 23 quality defect for the no-LPP capacity chat. A user
asking how much to contribute should first receive contribution-margin guidance
and missing-fact checks, not a generic tax-impact card.

## Scope

This closes the local source gap found after the independent/no-LPP Coach
runtime proof: MINT must not use household budget net income as the OPP3 art. 7
income base for a self-employed/no-LPP 3a calculation.

The new mobile source is:

- `q_self_employed_net_income_annual_chf` in `wizard_answers_v2`;
- `CoachProfile.independentNetProfessionalIncomeAnnual`;
- `selfEmployedNetIncome` backend/save-fact mapping into the dedicated key.

It remains distinct from `q_net_income_period_chf` /
`CoachProfile.explicitMonthlyNetIncome`, which is the household monthly
cashflow field used by Budget.

## Code Contract

Changed:

- `apps/mobile/lib/models/coach_profile.dart`
  - adds `independentNetProfessionalIncomeAnnual`;
  - hydrates from `q_self_employed_net_income_annual_chf`;
  - derives a gross work base for calculation engines when this is the only
    independent income source;
  - persists through JSON/copyWith/user-provided fields/data source tracking.
- `apps/mobile/lib/domain/budget/budget_inputs.dart`
  - uses `independentNetProfessionalIncomeAnnual / 12` for independent
    monthly cashflow when no explicit household net or gross salary source
    exists, avoiding a zero-budget regression.
- `apps/mobile/lib/services/financial_core/pillar3a_room_calculator.dart`
  - independent/no-LPP ceiling uses the dedicated annual professional net
    source when present, otherwise keeps the existing gross fallback.
- `apps/mobile/lib/providers/coach_profile_provider.dart`
  - `save_fact.selfEmployedNetIncome` writes the dedicated annual key.
- `apps/mobile/lib/providers/auth_provider.dart`
  - backend profile merge writes the same dedicated annual key.
- `apps/mobile/lib/services/coach/coach_profile_seeds.dart`
  - `independent_no_lpp_income_reality` now carries `86'400 CHF` annual
    professional net income, separate from `7'200 CHF` monthly budget net.
- `docs/data-flow.md`
  - documents the new key and the safe-mapping rule.

## Red/Green Proof

Red before implementation:

```bash
cd apps/mobile
flutter test test/services/financial_core/pillar3a_room_calculator_test.dart \
  test/services/coach_profile_seeds_test.dart \
  test/providers/auth_provider_test.dart \
  test/services/coach_profile_wizard_test.dart
```

Failed because `CoachProfile.independentNetProfessionalIncomeAnnual` did not
exist.

Green after implementation:

- Same focused run: `93/93` passed.
- Impact run:

```bash
flutter test test/services/response_card_service_test.dart \
  test/services/chat/fact_extraction_fallback_test.dart \
  test/providers/coach_profile_provider_secure_failure_test.dart
```

Result: `80/80` passed.

Claude CLI then found a real blocker: after separating
`selfEmployedNetIncome` from `q_net_income_period_chf`, a real profile with
only the dedicated professional net source could still produce zero Budget
cashflow and zero gross work base. Additional red/green proof now covers that:

```bash
flutter test test/services/coach_profile_wizard_test.dart \
  --plain-name "self-employed professional net income derives a gross work base without salary net contamination"
flutter test test/domain/budget/budget_service_test.dart \
  --plain-name "fromCoachProfile uses professional net income when independent gross is absent"
```

The first test failed red with `salaireBrutMensuel == 0.0`, then passed after
deriving `8'800 CHF` monthly gross work base from `96'000 CHF` annual
professional net while keeping `explicitMonthlyNetIncome == null`. The Budget
test proves `BudgetInputs.fromCoachProfile(...)` returns `8'000 CHF` monthly
cashflow from the same dedicated source when gross is absent.

Provider/Auth contracts were also strengthened:

- `applySaveFact.selfEmployedNetIncome` persists only
  `q_self_employed_net_income_annual_chf`;
- it does not create `q_net_income_period_chf` or `q_pay_frequency`;
- the rebuilt profile still yields `8'000 CHF` Budget cashflow and `8'800 CHF`
  gross work base.

Expanded impact run:

```bash
flutter test test/domain/budget/budget_service_test.dart \
  test/services/financial_core/pillar3a_room_calculator_test.dart \
  test/services/coach_profile_seeds_test.dart \
  test/providers/auth_provider_test.dart \
  test/services/coach_profile_wizard_test.dart \
  test/services/response_card_service_test.dart \
  test/services/chat/fact_extraction_fallback_test.dart \
  test/providers/coach_profile_provider_secure_failure_test.dart
```

Result: `268/268` passed.

Runtime follow-up after Claude review added a stable semantic id on response
cards:

- `ResponseCardWidget` exposes `response_card_pillar3a` for the 3a card;
- widget proof:
  `flutter test test/widgets/coach/response_card_widget_test.dart --plain-name "exposes stable semantics id for Maestro runtime proof"`;
- this avoids relying on a formatted dynamic amount as a static Maestro
  locator while keeping AX proof for the amount.

Focused card proof:

- the no-LPP 3a card explanation now uses `11'280 CHF` remaining room;
- it does not use the previous `15'600 CHF` gross fallback;
- it does not use the absolute `36'288 CHF` no-LPP ceiling.

## Runtime Proof

Build:

```bash
cd apps/mobile
flutter build ios --simulator --debug \
  --dart-define=MINT_E2E_ARCHETYPE=independent_no_lpp_income_reality \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
```

Result: built `build/ios/iphonesimulator/Runner.app`.

Initial runtime:

```bash
FLOW=tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_coach_chat_runtime.yaml
EVIDENCE=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-independent-no-lpp-professional-net-source-20260607T091054
MAESTRO_HARD_LIMIT=360 MAESTRO_STALL_THRESHOLD=120 MINT_WALKER_ARTIFACTS="$EVIDENCE" \
  bash tools/simulator/maestro_with_watchdog.sh test --format junit --output "$EVIDENCE/result.xml" "$FLOW"
```

Result:

- device: `iPhone 16e - iOS 26.2 - 9C9E9AAE-C3CF-49B8-B06D-625004880A9B`;
- JUnit: `tests=1`, `failures=0`;
- watchdog: `0`;
- elapsed: `32s`;
- evidence:
  `evidence/maestro-ci/row-23-independent-no-lpp-professional-net-source-20260607T091054/`.

The flow is now guarded against both previous visible bad amounts:

- no `7'137 CHF` absolute-ceiling card;
- no `3'068 CHF` gross-fallback card.
- positive assertion for the stable `response_card_pillar3a` runtime card id.

Final runtime rerun after adding the stable response-card id:

```bash
FLOW=tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_coach_chat_runtime.yaml
EVIDENCE=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-23-independent-no-lpp-professional-net-source-20260607T093350-rerun4
MAESTRO_HARD_LIMIT=360 MAESTRO_STALL_THRESHOLD=120 MINT_WALKER_ARTIFACTS="$EVIDENCE" \
  bash tools/simulator/maestro_with_watchdog.sh test --format junit --output "$EVIDENCE/result.xml" "$FLOW"
```

Result:

- device: `iPhone 16e - iOS 26.2 - 9C9E9AAE-C3CF-49B8-B06D-625004880A9B`;
- JUnit: `tests=1`, `failures=0`;
- watchdog: `0`;
- elapsed: `32s`;
- evidence:
  `evidence/maestro-ci/row-23-independent-no-lpp-professional-net-source-20260607T093350-rerun4/`.

Runtime AX snapshot:

- target id: `response_card_pillar3a`;
- label includes:
  `Versement 3a 2026 ... Impact fiscal indicatif 2'218 CHF`;
- copied proof:
  `evidence/maestro-ci/row-23-independent-no-lpp-professional-net-source-20260607T093350-rerun4/runtime-ax-label.txt`;
- Xcode screenshot:
  `evidence/maestro-ci/row-23-independent-no-lpp-professional-net-source-20260607T093350-rerun4/runtime-snapshot-professional-net-source-rerun4.jpg`.
- Maestro screenshot:
  `evidence/maestro-ci/row-23-independent-no-lpp-professional-net-source-20260607T093350-rerun4/row23-independent-no-lpp-coach-local-guidance.png`.

Screenshot proof:

- `evidence/maestro-ci/row-23-independent-no-lpp-professional-net-source-20260607T091054/row23-independent-no-lpp-coach-local-guidance.png`
- `evidence/maestro-ci/row-23-independent-no-lpp-professional-net-source-20260607T091054/runtime-snapshot-professional-net-source.jpg`

The screenshot shows the local Coach guidance references and a `Versement 3a
2026` card with `2'218 CHF` indicative tax impact. This follows the dedicated
source: `86'400 × 20% = 17'280` ceiling, `6'000` planned 3a contribution,
`11'280` remaining deductible room, then MINT's tax-impact estimate.

## Boundaries

This does not close Row 23 or CJT-063.

Still open:

- broader independent/no-LPP natural-language Coach calibration beyond this
  audited local topic;
- live backend/LLM scoring for calibrated personas;
- restart/provenance proof for persona facts beyond the tested persistence
  contracts;
- runtime VoiceOver/AX traversal;
- updated persona-flow scoring after the Coach route/runtime/source changes;
- broader screen and flow quality scoring across the 104-screen inventory.
