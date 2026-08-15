---
description: Gel et quarantaine de la branche qui empilait trois chantiers — rien n'est supprimé, tout reste atteignable par SHA.
status: Active
date: 2026-08-15
---

# Quarantaine — `codex/journey-os-bascule4-first-open-20260813`

## Pourquoi

Cette branche empile **trois chantiers sans rapport** : la bascule 4 (17
commits), la fondation du jumeau (série F), et une journée de dérive sur un
écran legacy. 106 commits, 179 fichiers.

Elle ne peut pas être fusionnée, et pas seulement par souci de lisibilité.
Le danger est concret et vérifié : `main.dart` lance `TwinBootstrap`, qui
appelle `loadAnswers()`, qui fait écrire un logement wizard legacy dans le
magasin canonique (`secure_wizard_store.dart:1039-1045`), que
`TwinMigration` transforme ensuite en fait du jumeau.

**Une personne qui relance MINT verrait son historique de l'ancien
questionnaire devenir silencieusement une vérité du jumeau, sans l'avoir
demandé.** Cette chaîne est ABSENTE de `dev`.

## Ce qui est gelé

| | |
|---|---|
| Tip | `82307b831bc1734330f5cfa2dee28bec553483a0` |
| Date du gel | 2026-08-15 |
| Branche distante | **conservée**, non supprimée |
| PR | #1251, fermée comme remplacée — non fusionnée |

## Ce qu'elle contient et qui reste à récupérer

1. **Bascule 4** — 5 beats verts sur 8. Reconstruite depuis `dev` dans
   `claude/bascule4-atterrissage-20260815`, par résultat sémantique et non
   par cherry-pick.
2. **Fondation du jumeau** (série F) — registre de faits versionnés, enveloppe,
   frontière de commande, décomposition 3a. Réelle et testée. À recadrer en
   Legos distincts, avec une contrainte non négociable héritée du cadrage
   bascule 4 : **la migration ne doit pas promouvoir les données wizard legacy
   en silence.**
3. **Inventaire de vérité de l'écran de rente** — 15 oracles, 3 défauts réels
   corrigés (hypothèse de carrière tue, statut d'emploi ignoré, 13e rente AVS
   non comptée). Attend son propre cadrage.

## Règle

Rien n'est supprimé tant que ces trois contenus n'ont pas trouvé leur Lego.
Une branche non fusionnée supprimée sans archive devient irrécupérable, et sa
provenance disparaît.
