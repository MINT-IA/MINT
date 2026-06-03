---
description: Negative runtime probe combining explicit CTA semantics with no AnimatedSwitcher for CJT-018.
status: evidence
date: 2026-06-03
---

# CJT-018 — Explicit Semantics Without AnimatedSwitcher

## Scope

This reversible probe combined the two relevant conditions needed to test the
transition hypothesis:

- explicit `Semantics(identifier: 'onboarding-insight-view')` around the T6
  `Voir` CTA;
- no `AnimatedSwitcher` around the step subtree.

The visual screen remained the same: same card, same bottom CTA, same dossier
strip, same spacing. The code was reverted after the runtime proof.

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
  `cjt-018-semantics-no-switcher-probe-20260603T094542/`.
- Result: `EXIT_CODE=1`, JUnit failure
  `Assertion is false: ".*Aujourd'hui.*" is visible`.

Post-failure runtime inspection:

```text
targets: e17|tap|button|Voir||
text: Avant de te montrer…
text: MOYENNE SUISSE
text: Trois scènes, trois chiffres — la réalité de ta tranche.
text: TON DOSSIER
```

Manual MCP tap:

```text
tap e17 -> x=67, y=205
screen remains on Avant de te montrer…
```

## Conclusion

Removing `AnimatedSwitcher` is not sufficient. With an explicit identifier,
Maestro can reach the T6 id path, but activation still resolves to the same bad
upper point (`x=67,y=205`) and does not advance to `Aujourd'hui`.

CJT-018 remains open. The next credible work should inspect how the T6 CTA's
semantics rectangle is computed inside `_StepScaffold` / `Expanded` / `Column`
with `Spacer`, or create a reduced MINT-shaped repro that adds those factors one
at a time.
