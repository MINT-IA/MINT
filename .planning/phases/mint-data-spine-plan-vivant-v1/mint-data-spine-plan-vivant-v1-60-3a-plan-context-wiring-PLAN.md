description: Plan 60 câble les versements planifiés et la contribution 3a annuelle dans le contexte coach live.

# Plan 60 — 3a Plan Context Wiring

## Pourquoi

Le contrat `profile_context` accepte maintenant les champs de plan, mais le
chemin live ne les remplit pas encore. Le coach peut donc parler de 3a ou de
trajectoire sans recevoir la contribution annuelle réellement planifiée.

## Scope

- Exposer `pillar.3a.annual_contribution` dans le paquet structuré
  `coach_context_packet`.
- Ajouter `annual_3a_contribution` aux `knownValues` des chemins live.
- Transmettre les versements planifiés sous une forme sans identité explicite.
- Réutiliser le même mapper pour `CoachLlmService`, l'écran chat et la
  narration.

## Hors scope

- Ne pas modifier le calcul fiscal 3a lui-même.
- Ne pas créer un nouvel écran budget ou situation financière.
- Ne pas modifier les flux Maestro dans cette phase.

## Vérification

- `flutter test test/services/data_spine_service_test.dart test/services/coach_context_packet_service_test.dart test/services/coach_context_packet_payload_test.dart`
- `flutter test test/services/coach_orchestrator_test.dart test/services/coach_narrative_profile_context_test.dart test/services/coach_context_packet_payload_test.dart`
- `flutter analyze` sur les fichiers Dart touchés
