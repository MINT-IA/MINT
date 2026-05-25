description: Plan 59 ferme le drift `profile_context` détecté entre Flutter et le backend coach.

# Summary — Plan 59 Profile Context Contract Parity

## Fait

- Le lint `profile_safe_fields_parity.py` lit maintenant les maps Dart
  construites par les helpers `buildProfileContext`, pas seulement les maps
  inline `profileContext: { ... }`.
- `CoachContext` mobile expose les champs optionnels déjà acceptés par le
  backend : cap, objectif actif, optimisation couple, source de données et
  contributions planifiées.
- `CoachOrchestrator` émet ces champs uniquement quand ils existent.
- `first_name` n'est plus envoyé dans le `profile_context` backend.
- `financial_summary` reste disponible, mais sans prénom, et est accepté côté
  backend via `_PROFILE_SAFE_FIELDS`.

## Vérifié

- `pytest -q tools/checks/tests/test_profile_safe_fields_parity.py` → 13 tests
  passés.
- `python3 tools/checks/profile_safe_fields_parity.py --mode profile-safe-fields`
  → `OK (60 fields in sync)`.
- `python3 -m pytest tests/coach/test_coach_chat_profile_sanitize_context_packet.py -q`
  → 9 tests passés.
- `flutter test test/services/coach_context_packet_payload_test.dart` → 4 tests
  passés.
- `flutter analyze` sur 6 fichiers touchés → no issues.

## Reste

- Brancher de vraies sources métier dans les nouveaux champs cap/plan/couple
  quand les écrans d'arbitrage et de plan seront traités.
- Exécuter la suite plus large avant push.
