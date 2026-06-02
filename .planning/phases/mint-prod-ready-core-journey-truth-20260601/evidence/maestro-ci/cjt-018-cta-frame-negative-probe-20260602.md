# CJT-018 — Onboarding CTA AX-frame negative probe

Date: 2026-06-02
Branch: `qa/runtime-navigation-spine-20260602`

## Scope

Follow-up probe for the remaining CJT-018 onboarding CTA debt after intent and
canton ids were runtime-proven.

The target failure is the T6 insight CTA:

- visible screen: `Avant de te montrer…`
- target label: `Voir`
- target id: `onboarding-insight-view`

## Findings

The prior S005 coordinate fallback is still required.

Three candidate fixes were tested and rejected before commit:

1. Wrap `_PrimaryButton` with an explicit `Semantics(identifier:, label:,
   button:, onTap:)` node.
2. Render T6 `_InsightStep` with a bottom-positioned `Stack` instead of a
   `Column` + `Spacer`.
3. Move the `ValueKey` from the `_PrimaryButton` wrapper to the inner
   `FilledButton`.

Results:

- Static Flutter proof passed during the probes:
  `flutter analyze lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart test/screens/onboarding/mvp_wedge_storyboard_test.dart`
- Widget storyboard proof passed during the probes:
  `flutter test test/screens/onboarding/mvp_wedge_storyboard_test.dart`
- Maestro locator audit passed during the probes:
  `python3 tools/checks/maestro_locator_audit.py`
- Runtime S005 remained red for the first two candidates:
  `Assertion is false: ".*Aujourd'hui.*" is visible`
- The third candidate regressed earlier:
  `Element not found: Id matching regex: onboarding-revenue-range-continue`

Runtime inspection after the first two candidates showed the same bad iOS
accessibility geometry:

- `snapshot_ui` exposed a tap target for `onboarding-insight-view`.
- xcodebuildMCP tapped that target at `x=67,y=205`.
- The visible `Voir` button was around the lower part of the screen, above
  `DossierStrip`.
- The app stayed on `Avant de te montrer…`.

This means the issue is not simply "missing identifier" or "identifier on the
wrong wrapper". Flutter/iOS is still exposing the T6 target with a frame that
does not correspond to the visible button.

## Decision

No production code or Maestro flow change was kept from this probe.

CJT-018 remains open. Keep the documented coordinate fallbacks in the active
S005 and perfect-set flows until a new root-cause hypothesis is proven by
runtime Maestro, not just widget tests.

## Next Debug Slice

Use a smaller reproduction before touching the product flow again:

- Build a minimal Flutter screen with the same `Scaffold` + `SafeArea` +
  `Column` + `AnimatedSwitcher` + bottom `DossierStrip` shape.
- Compare iOS AX frames for:
  - plain `FilledButton` keyed directly;
  - `Semantics(identifier:)` wrapper;
  - no `AnimatedSwitcher`;
  - no bottom `DossierStrip`;
  - fixed-height bottom bar.
- Only apply the winning shape to `_InsightStep` after xcodebuildMCP taps the
  id at the visible button coordinates and Maestro S005 reaches `Aujourd'hui`.
