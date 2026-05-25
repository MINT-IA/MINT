description: Résumé du Plan 35, qui aligne le whisper matelas de sécurité sur les charges fixes connues.

# Plan 35 — Mon Argent emergency months summary

## Résultat

Le whisper Mon Argent calcule maintenant les mois de matelas de sécurité avec les charges essentielles connues : logement, LAMal, impôt provisionné, dettes et autres charges fixes. Si aucune charge n'est connue, il garde le repli existant sur le revenu net.

## Changements

- `apps/mobile/lib/services/mon_argent/coach_whisper_service.dart` : ajout d'un helper de dépenses essentielles.
- `apps/mobile/test/services/mon_argent_coach_whisper_service_test.dart` : couverture du cas `5000 CHF` d'épargne liquide et `2000 CHF` de charges fixes, attendu à `2.5 mois`.

## Vérification locale

- `flutter test test/services/mon_argent_coach_whisper_service_test.dart` : réussi.
- `flutter test test/services/mon_argent_coach_whisper_service_test.dart test/widgets/mon_argent_budget_summary_card_test.dart test/screens/mon_argent_screen_test.dart` : réussi.
- `flutter analyze lib/services/mon_argent/coach_whisper_service.dart test/services/mon_argent_coach_whisper_service_test.dart` : réussi.

## Suite

Le cran suivant reste le lien coach ↔ budget détaillé : faire circuler les faits structurés sans réintroduire de champs bruts ou de PII dans le contexte LLM.

