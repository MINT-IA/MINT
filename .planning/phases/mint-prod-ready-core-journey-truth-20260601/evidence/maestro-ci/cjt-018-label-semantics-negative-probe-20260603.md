# CJT-018 — Label Semantics Candidate Rejected

Date: 2026-06-03  
Simulator: iPhone 17 Pro `B03E429D-0422-4357-B754-536637D979F9`

## Candidate

A reversible candidate kept the existing visual `FilledButton` activation path
inside `_PrimaryButton` and added an optional label-level
`Semantics(identifier:)` for T6:

```dart
_PrimaryButton(
  key: const ValueKey('onboarding-insight-view'),
  label: 'Voir',
  semanticsIdentifier: 'onboarding-insight-view',
  onPressed: () => provider.advance(),
)
```

The key was attached to the inner `Semantics` node so the local Flutter
storyboard test could assert the identifier without replacing the `FilledButton`
or adding a duplicate CTA.

## Static Proof

```bash
cd apps/mobile
flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart \
  --plain-name "Intent retraite: dossier gains one line per tour" \
  --reporter=expanded
flutter analyze \
  lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart \
  test/screens/onboarding/mvp_wedge_storyboard_test.dart
flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart \
  --reporter=expanded
python3 tools/checks/maestro_locator_audit.py
```

Results: targeted storyboard passed; analyze passed; full storyboard passed
(`12 passed`); locator audit passed (`35 flows`, `347 locators`).

## Runtime Result

Artifact folder:

`evidence/maestro-ci/cjt-018-label-semantics-candidate-20260603T103911/`

The proof flow was copied from S005 with only the T6 coordinate fallback changed
to:

```yaml
- tapOn:
    id: "onboarding-insight-view"
```

Maestro failed before `Aujourd'hui`:

```text
[Failed] cjt018_s005_label_semantics_id (42s)
Assertion is false: ".*Aujourd'hui.*" is visible
1/1 Flow Failed
```

Post-failure MCP snapshot exposed:

```text
e15|tap|button|Voir||onboarding-insight-view
```

MCP tap on that target:

```text
elementRef: e15
x: 67
y: 205
screen stayed on T6
```

Screenshot:

`evidence/maestro-ci/cjt-018-label-semantics-candidate-20260603T103911/t6-after-label-semantics-id-tap-still-stuck.jpg`

## Conclusion

This is not a production fix. Label-level semantics kept the visual
`FilledButton`, but iOS still mapped `onboarding-insight-view` to the same upper
non-activating frame.

The candidate was reverted after runtime proof. CJT-018 remains open, and the
next investigation should inspect why the real full-step history leaves the T6
identifier at the upper semantics node.
