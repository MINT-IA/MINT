# Summary 07 — Readiness dans le coach packet

## TLDR

Le `CoachContextPacket` transmis au coach contient maintenant un bloc `readiness` issu du `DataSpineReadinessDigest`.

## Changements

- Ajout de `CoachReadinessContext` et `CoachReadinessSection`.
- `CoachContextPacket.toSafeMap()` expose désormais :
  - `readiness.overall_status`
  - `readiness.sections[]`
  - `readiness.missing_domains[]`
  - `readiness.next_action_id`
- `CoachContextPacketService.fromSpine()` construit ce bloc depuis `DataSpineReadinessDigestService.fromSpine(spine)`.
- Les tests vérifient :
  - présence du bloc `readiness` dans le packet safe,
  - cas partiel avec piliers/trajectoire manquants,
  - cas budget bloqué avec `stabilize_budget`,
  - propagation via `CoachContextPacketAdapter.fromProfile()`.

## Vérification

- `flutter test test/services/data_spine_readiness_digest_service_test.dart test/services/coach_context_packet_service_test.dart test/services/coach_context_packet_payload_test.dart test/services/coach_context_packet_service_test.dart test/services/data_spine_service_test.dart` — PASS, 30 tests.
- `flutter analyze lib/models/coach_context_packet.dart lib/models/data_spine_snapshot.dart lib/services/data_spine/coach_context_packet_service.dart lib/services/data_spine/data_spine_readiness_digest_service.dart test/services/coach_context_packet_service_test.dart test/services/coach_context_packet_payload_test.dart` — PASS.

## Suite

Plan 08 doit utiliser ce bloc pour rendre le menu éclair readiness-driven, au lieu de choisir les actions par score de confiance et `CapMemory`.
