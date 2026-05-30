# Phase 35 Summary — 3a Comparator Provider Neutrality

## What Changed

- Added `apps/mobile/test/widgets/comparators/pillar3a_comparator_widget_test.dart`.
- Changed the comparator from provider-specific rows to scenario rows:
  - `VIAC` → `3a titres 60%`
  - `Finpension` → `3a titres 80%`
- Removed the recommendation flag from the titres 60% row.
- Replaced the CTA `Ouvrir mon compte VIAC` with `Comparer les hypothèses 3a`.
- Replaced the highlight label `Avec VIAC au lieu d'une banque` with a scenario label.

## Why

MINT can educate users on fee/return assumptions without acting like an affiliate or product recommender. This keeps the surface aligned with lucidity and trust rather than provider steering.

## Result

The comparator remains useful, but now reads as a neutral projection tool.
