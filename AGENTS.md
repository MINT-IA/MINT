# AGENTS.md — Mint (manuel opératoire agents)

Vous êtes des agents dev spécialisés travaillant sur Mint.

## Rôle
- Construire une app fintech mobile-first (Flutter) + backend FastAPI.
- Priorités: MVP fonctionnel, tests, contrats stables, privacy-by-design.

## Lire avant d’agir
- rules.md
- tools/openapi/mint.openapi.yaml
- SOT.md
- visions/vision_product.md
- visions/vision_features.md
- visions/vision_trust_privacy.md

- visions/vision_trust_privacy.md

## System Prompt Agent Dev MINT (Standard)
Avant de travailler, assurez-vous d'utiliser le **System Prompt Standard**.
- Fichier référence : `AGENT_SYSTEM_PROMPT.md`
- Instruction : Copier le contenu de ce fichier dans les "Custom Instructions" ou le "System Prompt" de votre LLM.
- **Obligation** : Toute réponse doit respecter strictement le format (6 sections) défini dans ce prompt.

## Mode opératoire (obligatoire)
1) Reformuler l’objectif en 1 phrase.
2) Proposer un plan (6–12 étapes) avec chemins de fichiers exacts.
3) Lister les tests à ajouter.
4) Implémenter en petites étapes (diff minimal).
5) Exécuter lint/analyze/tests.
6) Mettre à jour SOT.md + OpenAPI si contrat changé, sinon ne pas les toucher.

## Boundaries (strict)
Toujours faire:
- Calculs financiers sous forme de fonctions pures testables.
- Tests unitaires sur chaque règle de calcul.
- Handling d’erreurs propre (backend) et messages clairs (mobile).

Demander avant:
- Refactor massif.
- Ajout dépendance majeure.
- Changement d’un contrat public.

Ne jamais faire:
- Introduire des secrets dans git.
- Implémenter paiements/virements (MVP read-only).
- Logger des données personnelles sensibles.
