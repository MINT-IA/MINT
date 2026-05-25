description: Plan 60 relie les versements 3a planifiés au contexte coach live.

# Summary — Plan 60 3a Plan Context Wiring

## Fait

- `coach_context_packet` expose maintenant
  `pillar.3a.annual_contribution`.
- Les chemins live `CoachLlmService` et `CoachChatScreen` ajoutent
  `annual_3a_contribution` aux `knownValues`.
- Les versements planifiés sont transmis au backend sous une forme sans id ni
  libellé utilisateur : catégorie, montant mensuel, montant annuel, automaticité.
- `CoachNarrativeService` réutilise le même mapper de profil pour garder les
  surfaces coach alignées.

## Vérifié

- `flutter test test/services/data_spine_service_test.dart test/services/coach_context_packet_service_test.dart test/services/coach_context_packet_payload_test.dart`
  → 26 tests passés.
- `flutter test test/services/coach_orchestrator_test.dart test/services/coach_narrative_profile_context_test.dart test/services/coach_context_packet_payload_test.dart`
  → 22 tests passés.
- `flutter analyze` sur les 8 fichiers Dart touchés → no issues.
- `python3 tools/checks/profile_safe_fields_parity.py --mode profile-safe-fields`
  → `OK (60 fields in sync)`.
- Les 5 design lints → clean.
- `wiki_lint.py` → no FAIL-level violations.

## Reste

- Lancer un flux Maestro centré sur coach → 3a → budget pour vérifier la
  cohérence affichée, pas seulement le contrat de données.
- Continuer le câblage des autres champs métier : cap, couple, budget et
  trajectoire planifiée.
