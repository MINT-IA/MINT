description: Plan 35 corrige le calcul des mois de matelas de sécurité dans le whisper Mon Argent.

# Plan 35 — Mon Argent emergency months

## Contexte

Le whisper Mon Argent calculait les mois de matelas de sécurité en divisant l'épargne liquide par le revenu net mensuel. Cela sous-estime la durée réelle quand les charges fixes connues sont plus basses que le revenu, et brouille le lien entre budget structuré et lucidité utilisateur.

## Objectif

Utiliser les charges essentielles connues comme dénominateur du calcul, avec repli sur le revenu net uniquement si aucune charge n'est disponible.

## Portée

- Ajouter un test pur sur `CoachWhisperService`.
- Corriger la règle de calcul du matelas de sécurité.
- Ne pas modifier les écrans ni les chaînes existantes dans cette phase.

## Vérification prévue

- `flutter test test/services/mon_argent_coach_whisper_service_test.dart`
- `flutter test test/services/mon_argent_coach_whisper_service_test.dart test/widgets/mon_argent_budget_summary_card_test.dart test/screens/mon_argent_screen_test.dart`
- `flutter analyze lib/services/mon_argent/coach_whisper_service.dart test/services/mon_argent_coach_whisper_service_test.dart`

