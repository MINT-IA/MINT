# Phase 35 — 3a Comparator Provider Neutrality

## Goal

Turn the 3a comparator from a provider recommendation surface into a neutral educational scenario comparison.

## Scope

- Remove the `RECOMMANDÉ` badge from the VIAC row.
- Replace provider CTA copy with a generic hypothesis-comparison CTA.
- Replace provider-specific highlight labels with scenario labels.
- Add a widget regression test.

## Acceptance Criteria

- The comparator does not render `RECOMMANDÉ`.
- The comparator does not render `Ouvrir mon compte VIAC`.
- The comparator does not frame the gain as `Avec VIAC`.
- It still displays the titres scenario and comparison CTA.
