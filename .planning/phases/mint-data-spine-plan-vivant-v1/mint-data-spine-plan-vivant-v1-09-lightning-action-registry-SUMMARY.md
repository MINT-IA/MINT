# Summary 09 — Registry actions menu éclair

## Résultat

Le menu éclair distingue maintenant l'ID interne d'une action de son prompt chat ou de sa route.

## Changements

- Ajout de `LightningMenuActionIds`.
- Ajout de `LightningMenuItem.id`.
- Déduplication readiness par ID interne.
- Tests empêchant la fuite d'un `next_action_id` comme payload visible.
- Routes readiness inchangées.

## Vérification locale

- `flutter test test/widgets/coach/lightning_menu_readiness_resolver_test.dart test/services/coach_context_packet_payload_test.dart test/services/data_spine_readiness_digest_service_test.dart test/screens/coach/coach_chat_test.dart`
  - `+51 ~5: All tests passed!`
- `flutter analyze lib/widgets/coach/lightning_menu.dart test/widgets/coach/lightning_menu_readiness_resolver_test.dart`
  - `No issues found!`

## Limite volontaire

Cette phase ne réécrit pas encore les microcopies du menu. Elle rend d'abord le modèle d'action propre pour que les prochains changements UX ne cassent pas le routage.
