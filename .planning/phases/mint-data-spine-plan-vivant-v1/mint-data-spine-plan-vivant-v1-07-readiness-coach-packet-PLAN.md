# Plan 07 — Readiness dans le coach packet

## TLDR

Brancher le `DataSpineReadinessDigest` dans le `CoachContextPacket` déjà transmis au backend, afin que le chat voie explicitement l'état `ready/partial/blocked`, les sections concernées, les domaines manquants et la prochaine action canonique.

## Contexte

Plan 06 a ajouté un digest déterministe de readiness à partir du `DataSpineSnapshot`.
Le chemin live chat existe déjà :

`CoachProfile -> DataSpineService -> CoachContextPacketService -> CoachContext.coachContextPacket -> CoachOrchestrator.profile_context.coach_context_packet`

La suite logique est donc d'enrichir ce packet, pas de créer un nouveau canal ni une nouvelle persistance.

## Scope

- Ajouter un bloc `readiness` au `CoachContextPacket.toSafeMap()`.
- Construire ce bloc depuis `DataSpineReadinessDigestService.fromSpine(spine)`.
- Garder un format stable et sans données brutes :
  - `overall_status`
  - `sections[]` avec `id`, `status`, `known_count`, `missing_count`
  - `missing_domains[]`
  - `next_action_id`
- Vérifier que `CoachContextPacketAdapter.fromProfile(profile)` expose ce bloc.
- Ne pas modifier le menu éclair dans ce plan.
- Ne pas modifier la navigation ni le backend.

## Tests RED

1. `CoachContextPacketService.fromSpine(...).toSafeMap()` contient `readiness`.
2. Un profil incomplet expose `overall_status=partial`, `missing_domains` avec les piliers/trajectoire, et `next_action_id=define_target`.
3. Un budget négatif expose `overall_status=blocked` et `next_action_id=stabilize_budget`.
4. Le payload adapter contient `coach_context_packet.readiness` et n'expose pas de données raw.

## Done

- Tests ciblés Flutter verts.
- Analyzer ciblé vert.
- Plan résumé écrit.
- Commit atomique poussé sur `dev`.
