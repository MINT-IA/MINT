# Row 23 — Rapport Runtime Accessibility Proof — 2026-06-06

## Scope

Follow-up to the Row 23 primary-screen design/accessibility gap for `/rapport`.
The runtime snapshot found two icon-only app-bar actions exposed as unnamed
buttons. That made the Bilan/Rapport screen harder to understand with assistive
technology and weaker as a financial synthesis surface.

This proof covers `/rapport` app-bar action labels only. It does not close the
full Row 23 focus-order and content-quality audit across all primary screens.

## Change

- The `/rapport` back action now exposes the localized `Retour` semantics label
  and matching tooltip, while preserving an explicit semantic tap action.
- The `/rapport` PDF/share action now exposes the localized
  `Exporter le bilan en PDF` semantics label and matching tooltip, while
  preserving an explicit semantic tap action.
- The label is present in all 6 ARB locales and regenerated localization files.
- A widget regression asserts the two icon-only app-bar actions are discoverable
  by semantics label, have the button role, and expose `SemanticsAction.tap`.

## Mechanical Proof

Commands and runtime checks run after the fix:

```bash
cd apps/mobile
flutter gen-l10n
flutter test test/screens/advisor_banking_smoke_test.dart --plain-name "labels icon-only app bar actions for accessibility"
flutter test test/screens/advisor_banking_smoke_test.dart test/app_rapport_route_budget_test.dart
flutter analyze lib/screens/advisor/financial_report_screen_v2.dart test/screens/advisor_banking_smoke_test.dart
python3 ../../tools/checks/arb_parity.py --arb-dir lib/l10n
flutter build ios --simulator --debug --dart-define=MINT_DISABLE_BETA_MODAL=true
```

Results:

- Focused accessibility widget test: passed.
- Rapport route/screen suite: `47` tests passed.
- Targeted Flutter analyze: no issues.
- ARB parity: `6` locales, `6874` keys each.
- Initial simulator build failed on generated `CodeSign` xattrs; after
  cleaning only `build/ios/iphonesimulator`, the simulator build passed.
- Installed and launched on iPhone 17 Pro simulator
  `B03E429D-0422-4357-B754-536637D979F9`.
- Runtime snapshot for `mintapp:///rapport` now exposes:
  - `button|Exporter le bilan en PDF`
  - `button|Retour`
  - no unnamed app-bar action target.
- Saved accessibility tree:
  `evidence/maestro-ci/row-23-coach-rapport-runtime-accessibility-20260606T085850/04-rapport-runtime-accessibility-describe-all.json`
  contains `role_description:"button"` with `AXLabel:"Retour"` and
  `AXLabel:"Exporter le bilan en PDF"`.
- Accessibility reviewer initially blocked a label-only wrapper because
  `excludeSemantics` without `onTap` could remove semantic activation. The
  final implementation adds explicit `Semantics.onTap` and the regression now
  asserts `SemanticsAction.tap`.

Evidence folder:

`evidence/maestro-ci/row-23-coach-rapport-runtime-accessibility-20260606T085850/`

Screenshots:

- `01-coach-runtime-accessibility.jpg`
- `02-rapport-runtime-accessibility.jpg`
- `03-rapport-runtime-accessibility-fixed.jpg`
- `04-rapport-runtime-accessibility-describe-all.json`

## Runtime Guidance Quality Review

- `mechanical proof`: widget semantics regression, targeted analyze, ARB parity,
  simulator build, install, deep link, runtime snapshot, and screenshot capture
  all cover the changed `/rapport` action labels and semantic tap actions.
- `user-visible outcome`: a user reaching `/rapport` can identify the back
  action and PDF/export action by name instead of encountering unlabeled
  controls.
- `guidance quality`: the first viewport still presents one immediate adjustment
  plus a transparency/compliance block with hypotheses, conflicts, and
  limitations.
- `non-absurd`: no dead app-bar action, no route mismatch, and no duplicated
  visible Budget/Mon Argent dashboard surface was introduced.
- `inclusive`: the action labels are role-neutral. The visible assumptions still
  include a `Plafond 3a salarié` line, which is a remaining content-quality item
  to review when non-salaried archetypes are proven end to end.
- `financial trust`: the screen remains an educational Bilan/export surface and
  does not turn the PDF action into a personalized recommendation.
- `remaining qualitative gaps`: full Coach/Rapport focus order, VoiceOver
  traversal, PDF export runtime sharing, non-salaried report assumptions, and
  all-primary-screen content scoring remain open.

## Decision

CJT-048 is locally fixed for the `/rapport` app-bar accessibility defect.
Row 23 remains `PARTIAL`: this proof reduces the Rapport runtime accessibility
gap, but it does not prove the full Row 23 design/content/accessibility target.
