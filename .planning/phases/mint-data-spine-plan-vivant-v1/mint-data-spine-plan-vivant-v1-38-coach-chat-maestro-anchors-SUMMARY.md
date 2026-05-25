description: Résumé Plan 38 — le chat expose des ancres Maestro stables et le flow humain revient du budget vers le coach.

# Plan 38 — Résumé

## Changements

- `CoachChatScreen` expose `coach_chat_screen`.
- `CoachInputBar` expose `coach_input_field`, `coach_lightning_menu_button` et `coach_send_button`.
- `coach_chat_test.dart` fixe ces identifiants par test widget.
- `flow_mon_argent_budget_setup_spine.yaml` couvre maintenant Mon Argent → Budget setup → relance `/budget` → retour `/coach/chat`.
- Évidence Maestro ajoutée sous `.planning/_walker/maestro-evidence-20260525T1014-plan38/`.

## Vérification

- `flutter test test/screens/coach/coach_chat_test.dart --plain-name 'exposes Maestro semantics identifiers'` : exit `0`.
- `flutter analyze lib/screens/coach/coach_chat_screen.dart lib/widgets/coach/coach_input_bar.dart test/screens/coach/coach_chat_test.dart` : exit `0`.
- `flutter build ios --simulator --no-codesign ...` : exit `0`.
- `maestro test tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml --output .planning/_walker/maestro-evidence-20260525T1014-plan38` : exit `0`.

## Suite

Le prochain cran logique est de brancher un test de contexte coach après budget : le chat doit pouvoir lire les mêmes faits de charges et les montrer dans son paquet de départ, sans attendre une réponse LLM.
