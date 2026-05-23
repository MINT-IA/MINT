# Summary 08 — Menu éclair readiness

## Résultat

Le menu éclair utilise maintenant `coach_context_packet.readiness.next_action_id` pour placer la prochaine meilleure action en tête.

## Changements

- Ajout de `LightningMenuReadinessResolver`, un resolver pur et testé.
- Passage de la readiness depuis `CoachChatScreen` vers `LightningMenu`.
- Mapping readiness vers routes existantes : budget, bilan profil, scan AVS, scan documents, ou conversation coach.
- Fallback conservé sur l'ancien ordre du menu quand la readiness est absente ou inconnue.

## Vérification locale

- `flutter test test/widgets/coach/lightning_menu_readiness_resolver_test.dart test/services/coach_context_packet_payload_test.dart test/services/data_spine_readiness_digest_service_test.dart test/screens/coach/coach_chat_test.dart`
  - `+50 ~5: All tests passed!`
- `flutter analyze lib/widgets/coach/lightning_menu.dart lib/screens/coach/coach_chat_screen.dart test/widgets/coach/lightning_menu_readiness_resolver_test.dart`
  - `No issues found!`

## Limite volontaire

Cette phase ne nettoie pas encore toutes les étiquettes d'action visibles ni le vocabulaire du menu. Elle raccorde d'abord la priorité du menu à la data-spine. Le nettoyage UX des libellés et du menu éclair doit suivre dans une phase séparée.
