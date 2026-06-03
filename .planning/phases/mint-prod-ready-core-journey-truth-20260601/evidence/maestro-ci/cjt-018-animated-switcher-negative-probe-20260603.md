---
description: Negative runtime probe removing AnimatedSwitcher from onboarding shell for CJT-018.
status: evidence
date: 2026-06-03
---

# CJT-018 — AnimatedSwitcher Negative Probe

## Scope

This reversible probe tested whether the T5→T6 transition wrapper caused the
bad or missing iOS accessibility identifier for the T6 `Voir` CTA.

Temporary change:

```dart
Expanded(
  child: KeyedSubtree(
    key: ValueKey(step),
    child: _stepWidget(step),
  ),
),
```

The original `AnimatedSwitcher(duration: 220ms, child: KeyedSubtree(...))` was
restored after the runtime result.

## Static Proof

```bash
cd apps/mobile
flutter analyze lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart
flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart --reporter=expanded
```

Result: analyze passed; storyboard test passed (`12 passed`).

## Runtime Proof

- Build: iOS simulator debug build with temporary xattrs cleanup watcher.
- Device: `iPhone 17 Pro - iOS 26.2 - B03E429D-0422-4357-B754-536637D979F9`.
- Flow: S005 with only the T6 fallback changed from `point: "50%,71%"` to
  `id: "onboarding-insight-view"`.
- Evidence folder:
  `cjt-018-no-animated-switcher-probe-20260603T094037/`.
- Result: `EXIT_CODE=1`, JUnit failure
  `Element not found: Id matching regex: onboarding-insight-view`.

Post-failure runtime snapshot:

```text
targets: e15|tap|button|Voir||
text: Avant de te montrer…
text: MOYENNE SUISSE
text: Trois scènes, trois chiffres — la réalité de ta tranche.
text: TON DOSSIER
```

## Conclusion

Removing `AnimatedSwitcher` did not expose the expected T6 CTA identifier and
did not make the S005 id path reach `Aujourd'hui`.

CJT-018 remains open. The coordinate fallback remains necessary in active
Maestro flows until a runtime-proofed fix makes `onboarding-insight-view`
tap by id through to `Aujourd'hui`, `card_cap_du_jour`, and
`mint_card_action_bar`.
