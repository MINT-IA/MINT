# Phase 29 — LPP buyback simulator fiscal-impact framing

Date: 2026-05-27

## Goal

Remove another user-visible promise frame from the LPP buyback simulation:
`Économie fiscale immédiate`.

## Change

- Replaced the metric label with `Impact fiscal indicatif`.
- Changed the metric icon/color from savings/success to calculate/primary so
  the visual framing no longer implies an acquired gain.
- Added a widget regression test that verifies:
  - the indicative label is rendered;
  - the computed amount remains visible (`CHF 12500` for 50k × 25%);
  - the old immediate-saving label is gone;
  - the savings icon is gone;
  - promise-style fiscal phrases are absent from the widget surface.

## Files

- `apps/mobile/lib/widgets/simulation_widgets.dart`
- `apps/mobile/test/widgets/simulation_widgets_test.dart`

## Verification

- Red-first check: new widget test failed before the label change.
- `flutter test test/widgets/simulation_widgets_test.dart` — PASS.
- `flutter analyze lib/widgets/simulation_widgets.dart test/widgets/simulation_widgets_test.dart` — PASS.
- `git diff --check` — PASS.
- MCP French copy checks on the changed visible copy — clean.
- Claude Opus 4.7 review:
  - Verdict: approve with notes.
  - Blocking findings: none.
  - Applied the visual-framing note by replacing savings/success with
    calculate/primary.

## Self-evaluation

Accuracy/effectiveness: 8.5/10.

Why not 10: this widget still hardcodes French copy and is not yet extracted to
ARB. The change is deliberately scoped to trust framing, not full i18n cleanup.

How to make it 10: migrate the simulation labels to `AppLocalizations`, run ARB
parity across six languages, and add a small scenario table for zero/high
buyback inputs.
