description: Résumé du Plan 29, qui ajoute le mode d'emploi humain de MINT.

# Plan 29 — Résumé

## Changements

- Ajout de `.planning/product/mint-mode-emploi-humain.md`.
- Clarification du rôle de `Aujourd'hui`, `Mon Argent`, `Budget`, `Coach` et `Explorer`.
- Formalisation de la chaîne de données : `wizard_answers_v2` → `CoachProfile` → `MintUserState.dataSpineSnapshot`.
- Critère de fonctionnement humain ajouté pour guider les flows Maestro.

## Vérification prévue

- `python3 tools/checks/wiki_lint.py lint`
- `python3 tools/checks/accent_lint_fr.py --file .planning/product/mint-mode-emploi-humain.md`
- `check_banned_terms` sur le contenu créé.
