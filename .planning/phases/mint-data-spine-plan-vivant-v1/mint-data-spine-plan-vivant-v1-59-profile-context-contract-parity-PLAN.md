description: Plan 59 synchronise le contrat `profile_context` entre Flutter et le backend coach.

# Plan 59 — Profile Context Contract Parity

## Pourquoi

Le hook `profile_safe_fields_parity.py` signalait un drift massif entre les
champs acceptés par le backend coach et les champs envoyés côté Flutter. Une
partie du drift était réelle, une autre venait du lint qui ne lisait pas les
helpers Dart `buildProfileContext`.

## Scope

- Corriger l'extraction du lint pour lire les maps construites par les helpers
  `*_buildProfileContext*`.
- Retirer les champs d'identité envoyés inutilement dans `profile_context`.
- Ajouter au `CoachContext` mobile les champs optionnels que le backend accepte
  déjà pour le cap, le plan, le couple et les contributions planifiées.
- Garder `financial_summary` sans identité explicite et le whitelister côté
  backend.

## Vérification

- `pytest -q tools/checks/tests/test_profile_safe_fields_parity.py`
- `python3 tools/checks/profile_safe_fields_parity.py --mode profile-safe-fields`
- `python3 -m pytest tests/coach/test_coach_chat_profile_sanitize_context_packet.py -q`
- `flutter test test/services/coach_context_packet_payload_test.dart`
- `flutter analyze` sur les fichiers touchés
