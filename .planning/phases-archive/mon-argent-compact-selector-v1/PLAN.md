description: Make Mon Argent section navigation usable on compact devices.

# Phase mon-argent-compact-selector-v1

## Goal

Remove the small-screen discoverability risk introduced by the five-section
Mon Argent money map, without creating a new data model or changing financial
calculations.

## Context

PR #674 made Mon Argent a five-section journey:

1. Aujourd'hui
2. Mois
3. Patrimoine
4. Prevoyance
5. Futur

Claude Opus approved the PR but called out a real follow-up: the tests needed
`ensureVisible('Futur')`, which is a sign that the selector may be hidden on
compact devices. For a money-map screen, the user must understand that all five
sections exist.

## Scope

- Keep `SegmentedButton` on normal/wide widths.
- Render compact two-row `ChoiceChip` navigation on narrow widths.
- Preserve the existing Maestro and semantics anchors:
  - `mon_argent_section_selector`
  - `mon_argent_section_{section.name}`
- Add widget coverage proving the Futur section is directly reachable on a
  compact 320px width.

## Out Of Scope

- No new financial read model.
- No new persisted state.
- No trust-chip implementation yet.
- No budget redesign.
- No generated l10n line-ending cleanup.

## Verification

- `cd apps/mobile && flutter analyze --no-fatal-infos lib/screens/mon_argent/mon_argent_screen.dart test/screens/mon_argent_screen_test.dart`
- `cd apps/mobile && flutter test test/screens/mon_argent_screen_test.dart`
- `mint_tools.validate_arb_parity`
- Maestro flow `flow_mon_argent_budget_setup_spine.yaml` after tests pass.
