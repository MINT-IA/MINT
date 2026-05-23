# Plan 09 — Registry actions menu éclair

## TLDR

Séparer l'identité interne des actions du menu éclair de leur prompt visible ou de leur route.

## Problème

`LightningMenuItem.action` sert à la fois de message chat, de route et parfois d'identifiant de déduplication. Ce mélange rend le menu fragile et favorise les fuites de libellés techniques dans l'UX.

## Scope

- Ajouter des IDs d'action stables pour le menu éclair.
- Garder les routes et prompts existants.
- Faire dédupliquer la readiness par ID interne, pas par libellé.
- Ne pas toucher backend, routes, ni i18n.

## Tests RED

- Une action readiness ne doit pas utiliser son `next_action_id` comme message visible.
- La déduplication doit fonctionner par ID interne.
- Les routes readiness existantes restent inchangées.

## Done

- Tests ciblés verts.
- Analyzer ciblé vert.
- Summary écrit.
- Commit + push + CI verte.
