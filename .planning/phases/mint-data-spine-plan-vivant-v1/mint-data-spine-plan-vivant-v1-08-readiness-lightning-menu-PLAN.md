# Plan 08 — Menu éclair readiness

## TLDR

Utiliser `coach_context_packet.readiness.next_action_id` pour placer la prochaine meilleure action en tête du menu éclair.

- `stabilize_budget` → budget/setup
- `define_target` → profil/bilan
- `complete_situation` → profil/bilan
- `complete_pillar_avs` → scan/avs-guide
- `complete_pillar_lpp` → scan
- `complete_pillar_3a` → scan
- `maintain_plan` → conversation coach

## Scope

- Ajouter un resolver pur qui met l'action readiness en première position.
- Garder l'ancien menu comme fallback.
- Ne pas toucher backend, routes, ni i18n.

## Tests RED

- `stabilize_budget` devient la première action.
- `complete_pillar_avs` route vers `/scan/avs-guide`.
- Readiness absente ou inconnue garde l'ordre fallback.

## Done

- Tests Flutter ciblés verts.
- Analyzer ciblé vert.
- Summary écrit.
- Commit + push + CI verte.
