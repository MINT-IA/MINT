---
date: 2026-08-15
status: Rejected
authors: Claude, Codex (axe plan), Julien (demande)
panel: 1 axe plan Codex
supersedes: —
superseded_by: —
description: REJETÉE par l'axe plan — la vue existe déjà (BOARD.md, Journey OS) et la source que je voulais parser se contredit elle-même.
related:
  - product/mint_next/BRIEF.md
  - product/mint_next/lego_lease.json
  - .planning/FEUILLE-DE-ROUTE.md
---

# Un tableau de bord des Legos, généré et non tenu

> **REJETÉE le 2026-08-15 par l'axe plan Codex, avant qu'une ligne soit
> écrite.** Deux raisons, vérifiées :
>
> 1. Le BRIEF contient **deux journaux contradictoires** — §6ter liste 11 Legos
>    livrés, §6 dit « aucun livré sous ce protocole ». J'avais lu le premier et
>    jamais le second.
> 2. **`.planning/journeys/BOARD.md` est déjà une vue générée** avec état,
>    preuve, dernière vérification et prochaine action ; Journey OS est le
>    routeur canonique. Ma proposition en construisait une concurrente.
>
> C'est ce que j'ai moi-même déconseillé pour Linear deux jours plus tôt.
> Verdict complet : `.planning/phases/.../verdicts/2026-08-15-plan-tableau-de-bord.md`
>
> **Ce que la demande de Julien devient** : ce n'est pas un tableau de bord
> qui manque, c'est que BOARD.md ne parle pas des Legos et que le BRIEF se
> contredit. Le vrai lot est de réconcilier les deux journaux et de faire
> entrer les Legos dans Journey OS — pas d'ajouter une sixième vue.

## TLDR

Julien ne voit pas où en est MINT. L'information existe — onze Legos
journalisés, un bail, treize storyboards, des verdicts — mais éclatée dans
cinq endroits. On la **génère** en une page, à partir des sources ; on ne crée
pas un sixième document à tenir.

## Contexte

Demande de Julien, 2026-08-15 : « voir la feuille de route avec tous les Legos
qu'on va définir ou qu'on a définis, checker tout ce qui a été fait, l'état
d'avancement ».

Ce qui existe déjà, et qu'il ne voit pas :

| Source | Contenu | Pourquoi invisible |
|---|---|---|
| `BRIEF.md` §6ter | 11 Legos : date, verdicts Codex, état de promotion, reçu runtime | Tableau large, ligne 250 d'un fichier de 350 lignes |
| `lego_lease.json` | Lego actif, 8 beats, preuves, verdicts, chemins autorisés | JSON, lisible par machine |
| `storyboard/*.json` | 13 contrats de surface | Un fichier par surface, aucun index |
| `verdicts/` | Verdicts Codex par beat | Créé aujourd'hui, 3 entrées |
| `FEUILLE-DE-ROUTE.md` | Tranches T1-T4 (cap produit) | Ne parle pas des Legos |

**Le défaut n'est pas le manque de données. C'est qu'aucune vue ne les joint.**

## Décision

Une commande, une page, zéro saisie manuelle.

`python3 tools/checks/legos_index.py` lit les cinq sources et écrit
`.planning/LEGOS.md` : un tableau de tous les Legos — livrés et en cours —
avec pour chacun sa date, son état, son verdict Codex, sa preuve runtime, et
son storyboard. Plus, pour le Lego actif, le détail de ses beats.

**La règle qui rend la chose non contournable** : le fichier porte un
avertissement « généré — ne pas éditer », et un contrôle refuse un
`.planning/LEGOS.md` qui diverge de ce que la commande produirait. Un tableau
de bord qu'on peut retoucher à la main redevient un sixième mensonge.

C'est le motif que MINT applique déjà à `.planning/INDEX.md`, régénéré par
`wiki_lint.py index`. On ne réinvente rien : on étend une pratique qui marche.

**Ce que la page montre en premier, avant les Legos** : ce qui est OUVERT et ce
qui BLOQUE. Un tableau de bord qui commence par les succès est un tableau de
bord qu'on regarde une fois.

## Counter-arguments and data gaps

**Ce que dit la vue opposée la plus forte.** Un générateur est du code à
maintenir, et il casse quand une source change de forme — le journal du BRIEF
est un tableau markdown écrit à la main, donc fragile au parsing. Une vue
écrite à la main serait plus robuste et coûterait dix minutes par Lego. Et
personne n'a demandé un tableau de bord avant aujourd'hui : le besoin est
peut-être conjoncturel — Julien a perdu le fil parce que j'ai dérivé pendant
une journée, pas parce que la structure manque.

**Ce que cette décision ne traite pas.** On n'a aucune mesure de ce que coûte
un Lego en temps réel, ni de la dérive entre budget annoncé et budget consommé
— le BRIEF le note en prose, pas en données. On ne sait pas non plus dire
« ce Lego est en retard » faute de dates cibles. Et rien ici ne dit ce qu'il
reste à faire APRÈS les Legos connus : la file au-delà de la bascule 4 n'existe
pas encore.

**Ce qui changerait cette conclusion.** Si le journal du BRIEF devient une
source structurée (JSON ou frontmatter), le générateur se simplifie de moitié
et le contre-argument « parsing fragile » tombe. Si Julien consulte la page
moins d'une fois par semaine après un mois, elle ne vaut pas son entretien et
doit être supprimée plutôt que maintenue par habitude.

## Sources

- `product/mint_next/BRIEF.md` §5, §6bis, §6ter
- `product/mint_next/lego_lease.json`
- `tools/checks/wiki_lint.py` — le précédent de génération d'index
- Demande verbale de Julien, 2026-08-15

## Status & follow-up

- **Proposed** — à valider par un axe `plan` Codex avant écriture du
  générateur.
- Re-litige : consultation < 1×/semaine après un mois ⇒ suppression.
