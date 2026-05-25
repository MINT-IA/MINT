description: Plan 62 aligne le format CHF des openers 3a coach avec le style suisse.

# Summary — Plan 62 Coach 3a Opener CHF Format

## Fait

- `DataDrivenOpenerService` formate les plafonds 3a via `formatChf`.
- `PrecomputedInsight.resolve` formate les paramètres CHF au moment de
  l'affichage, tout en gardant le cache en valeurs brutes.
- Les tests ciblés exigent désormais `7'258` et refusent `7258 CHF`.

## Vérifié

- Premier run TDD attendu : 4 échecs sur les messages encore en `7258 CHF`.
- `flutter test test/services/coach/data_driven_opener_service_test.dart test/services/coach/precomputed_insights_service_test.dart`
  → 32 tests passés.
- `flutter analyze` sur les 4 fichiers touchés → no issues.
- `python3 tools/checks/profile_safe_fields_parity.py --mode profile-safe-fields`
  → `OK (60 fields in sync)`.
- `python3 tools/checks/no_3a_ceiling_as_tax_saving.py`
  → OK.
- `wiki_lint.py lint` → no FAIL-level violations.

## Reste

- Rejouer le flow Maestro budget/coach si la prochaine phase touche encore
  l'opener ou l'écran chat.
- Étendre plus tard le même niveau de formatage aux autres messages coach qui
  injectent des montants depuis des paramètres bruts.
