description: Plan 38 ajoute des ancres Maestro stables au chat, surface centrale de navigation entre situation, budget et actions.

# Plan 38 — Ancres Maestro du chat

## Objectif

Rendre le chat vérifiable comme surface de navigation centrale, sans dépendre uniquement des textes français.

## Portée

- Ajouter des `Semantics.identifier` au root du chat.
- Ajouter des identifiants au champ de saisie, au bouton éclair et au bouton d'envoi.
- Ajouter un test widget qui fixe ces ancres.
- Étendre le flow Maestro Mon Argent / Budget pour revenir au chat après relance budget.

## Hors portée

- Pas de refonte du menu éclair.
- Pas de changement LLM.
- Pas de modification des réponses coach.

## Vérification

- Test widget ciblé sur `CoachChatScreen`.
- Analyse Dart ciblée.
- Flow Maestro capable d'asserter `coach_chat_screen`, `coach_input_field`, `coach_lightning_menu_button`, `coach_send_button`.
