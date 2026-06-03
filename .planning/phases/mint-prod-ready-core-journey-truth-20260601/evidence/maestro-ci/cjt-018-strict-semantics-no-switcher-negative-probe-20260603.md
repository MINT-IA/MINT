---
description: Negative runtime probe combining strict CTA semantics and no AnimatedSwitcher for CJT-018.
status: evidence
date: 2026-06-03
---

# CJT-018 — Strict Semantics Without AnimatedSwitcher

## Scope

This reversible probe matched the passing minimal repro more closely:

- no `AnimatedSwitcher` around the step subtree;
- `Semantics(container: true, identifier:, label:, button:, onTap:)` around the
  T6 CTA;
- `ExcludeSemantics` around the visual `FilledButton`.

The visual T6 layout stayed unchanged. The code was reverted after runtime proof.

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
  `cjt-018-strict-semantics-no-switcher-probe-20260603T095153/`.
- Result: `EXIT_CODE=1`, JUnit failure
  `Assertion is false: ".*Aujourd'hui.*" is visible`.

Post-failure runtime snapshot:

```text
targets: e15|tap|button|Voir||onboarding-insight-view
text: Avant de te montrer…
text: MOYENNE SUISSE
text: Trois scènes, trois chiffres — la réalité de ta tranche.
text: TON DOSSIER
```

Manual MCP tap:

```text
tap e15 -> x=67, y=205
screen remains on Avant de te montrer…
```

## Conclusion

The strict semantics wrapper exposes the identifier, but the iOS activation
point still resolves to the upper card area. Removing `AnimatedSwitcher` plus
adding a strict semantic action is still not enough.

CJT-018 remains open. The next useful step is a reduced MINT-shaped repro that
adds the remaining MINT-specific factors one by one: `_StepScaffold`,
`DossierStrip` implementation details, and exact `SafeArea` / screen sizing.
