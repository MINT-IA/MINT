---
description: Negative runtime probes for CJT-018 onboarding T6 CTA accessibility identifier geometry.
status: evidence
date: 2026-06-03
---

# CJT-018 — Semantics Negative Probes

## Scope

Two reversible probes tested whether CJT-018 could be fixed without changing
the onboarding visual design:

1. global `SemanticsBinding.instance.ensureSemantics()` in `main.dart`;
2. `ExcludeSemantics(child: DossierStrip())` around the bottom dossier strip.

Both probes were reverted. No production UI/layout change survived.

## Design Constraint

The onboarding flow remains a Design System v2 Form Screen: progressive
disclosure, one bottom CTA, no duplicate hidden CTA, no visual move to match a
bad AX frame. The design-system reviewer explicitly rejected moving, duplicating,
hiding, or visually faking the CTA for Maestro.

## Probe 1 — Global Ensure Semantics

Change tested:

```dart
WidgetsFlutterBinding.ensureInitialized();
SemanticsBinding.instance.ensureSemantics();
```

Runtime proof:

- Build: clean iOS simulator debug build after `flutter clean`.
- xattrs workaround: a temporary watcher stripped `com.apple.provenance` /
  FinderInfo from generated iOS products so Xcode codesign could complete.
- App installed on `iPhone 17 Pro - iOS 26.2 - B03E429D-0422-4357-B754-536637D979F9`.
- Flow: S005 with only the T6 fallback changed from `point: "50%,71%"` to
  `id: "onboarding-insight-view"`.
- Evidence folder:
  `cjt-018-ensure-semantics-clean-probe-20260603T093134/`.
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

Conclusion: forcing global semantics did not fix the wrong-frame bug. It made
the expected identifier unavailable in this runtime path.

## Probe 2 — Exclude Dossier Strip Semantics

Change tested:

```dart
if (step != OnboardingStep.entry)
  const ExcludeSemantics(child: DossierStrip()),
```

Static proof:

```bash
cd apps/mobile
flutter analyze lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart
flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart --reporter=expanded
```

Result: analyze passed; storyboard test passed (`12 passed`).

Runtime proof:

- Build: iOS simulator debug build with the same xattrs workaround.
- App installed on `iPhone 17 Pro - iOS 26.2 - B03E429D-0422-4357-B754-536637D979F9`.
- Flow: S005 with only the T6 fallback changed from `point: "50%,71%"` to
  `id: "onboarding-insight-view"`.
- Evidence folder: `cjt-018-exclude-dossier-probe-20260603T093439/`.
- Result: `EXIT_CODE=1`, JUnit failure
  `Element not found: Id matching regex: onboarding-insight-view`.

Post-failure runtime snapshot:

```text
targets: e15|tap|button|Voir||
text: Avant de te montrer…
text: MOYENNE SUISSE
text: Trois scènes, trois chiffres — la réalité de ta tranche.
```

Conclusion: excluding the strip semantics removed the dossier AX subtree, but
the T6 CTA still did not expose the expected identifier. This probe is not a
production fix, and it would also weaken access to the visible dossier preview.

## Next Credible Probe

The next reversible probe should target the T5→T6 transition itself, not visual
layout:

- keep the current visual T6 design unchanged;
- keep one real bottom CTA;
- isolate whether `AnimatedSwitcher` / `KeyedSubtree(ValueKey(step))` retains
  stale or merged semantics on T6;
- rerun the same S005 id proof and capture `snapshot_ui` before and after the
  failing/passing tap.

The coordinate fallback remains in active flows until `onboarding-insight-view`
can be tapped by id and the flow reaches `Aujourd'hui`, `card_cap_du_jour`, and
`mint_card_action_bar`.
