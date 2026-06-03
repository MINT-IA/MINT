# CJT-018 — Strict Semantics With AnimatedSwitcher

Date: 2026-06-03  
Simulator: iPhone 17 Pro `B03E429D-0422-4357-B754-536637D979F9`

## Probe

A reversible candidate kept the real T6 layout and the real `AnimatedSwitcher`,
but moved the T6 CTA key/id to a strict semantics wrapper:

```dart
Semantics(
  key: const ValueKey('onboarding-insight-view'),
  container: true,
  identifier: 'onboarding-insight-view',
  label: 'Voir',
  button: true,
  onTap: provider.advance,
  child: ExcludeSemantics(
    child: _PrimaryButton(
      label: 'Voir',
      onPressed: () => provider.advance(),
    ),
  ),
)
```

The visual CTA stayed unchanged. The code was reverted after runtime proof.

## Static Proof

```bash
cd apps/mobile
flutter analyze lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart
flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart --reporter=expanded
```

Result: analyze passed; storyboard test passed (`12 passed`).

## Runtime Result

Artifact folder:

`evidence/maestro-ci/cjt-018-strict-semantics-switcher-probe-20260603T102457/`

S005 with only the T6 coordinate fallback replaced by
`id: "onboarding-insight-view"` failed:

```text
[Failed] cjt018_strict_switcher_s005_id (41s)
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

`evidence/maestro-ci/cjt-018-strict-semantics-switcher-probe-20260603T102457/t6-after-strict-id-tap-still-stuck.jpg`

## Conclusion

This is not a production fix. Strict CTA semantics with the real
`AnimatedSwitcher` exposes the identifier, but the activation frame is still the
upper non-activating text-sized area.

The next useful investigation is not another wrapper on the CTA. It should
inspect stale or retained semantics across the previous onboarding steps, or use
a structural lifecycle fix that forces the old step semantics to leave the iOS
accessibility tree before T6.
