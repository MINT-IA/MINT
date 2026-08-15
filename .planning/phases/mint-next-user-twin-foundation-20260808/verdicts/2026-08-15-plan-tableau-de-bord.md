# Verdict Codex — axe PLAN : tableau de bord des Legos (2026-08-15)

**REJET.** Deux constats décisifs, tous deux vérifiés.

1. Le BRIEF contient DEUX journaux contradictoires : §6ter liste 11 Legos
   livrés, §6 dit « aucun livré sous ce protocole ». J'avais lu le premier et
   jamais le second. La source que je voulais parser se contredit elle-même.

2. `.planning/journeys/BOARD.md` EST DÉJÀ une vue générée — « Generated from
   issues/*.json. Do not edit directly » — avec état, preuve, dernière
   vérification, artefact et prochaine action. Et `ACTIVE_CONTEXT.md` désigne
   Journey OS comme routeur canonique. Ma proposition construisait une vue
   CONCURRENTE en l'ignorant.

C'est exactement ce que j'ai déconseillé pour Linear le 13 août : « il
doublerait Journey OS et créerait deux états divergents ».

Recadrage exigé avant toute ligne de code : un manifeste structuré canonique,
la suppression des deux journaux contradictoires, la JOINTURE avec Journey OS
et non une vue à côté, et un critère de sortie exécutable (test nommé,
commande --check, gate).

---

## A — Problème et existant

Le besoin est réel : Julien veut savoir ce qui est terminé, bloqué et suivant au moment de piloter MINT (`.planning/decisions/2026-08-15-tableau-de-bord-des-legos.md:19-28`).

Mais le générateur proposé n’a pas de source fiable. `product/mint_next/BRIEF.md` contient deux registres incompatibles :

- §6ter recense les Legos livrés (`BRIEF.md:250-264`) ;
- §6 affirme qu’aucun Lego n’a été livré (`BRIEF.md:305-309`).

Le plan ne dit pas lequel gagne ni comment détecter ce conflit. Scénario observable : Julien ouvre `.planning/LEGOS.md` et voit soit onze Legos, soit zéro, selon le parseur. Le tableau censé rétablir la confiance fabrique une vérité arbitraire.

Il réécrit aussi une capacité existante : `.planning/journeys/BOARD.md:1-7` est déjà une vue générée avec état, preuve et prochaine action. Or `.planning/ACTIVE_CONTEXT.md:18-21` désigne Journey OS comme routeur canonique. Le cadrage l’ignore entièrement.

## B — Sortie et casse

Le critère de sortie n’est pas exécutable. « Un contrôle refuse une divergence » (`…tableau-de-bord-des-legos.md:51-54`) ne nomme ni test, ni commande de check, ni branchement CI/lefthook, ni fixture couvrant :

- les deux journaux concurrents ;
- les doublons et renommages ;
- un Lego actif absent du BRIEF ;
- un reçu ou storyboard inexistant ;
- les statuts incompatibles entre bail et Journey OS.

Le cadrage promet « tous les Legos qu’on va définir » (`:26-28`), puis reconnaît que la file au-delà de Bascule 4 n’existe pas (`:73-78`). Scénario : Julien interprète l’absence d’un Lego futur comme une décision de produit alors qu’elle signifie seulement « donnée non modélisée ».

Le futur parseur Markdown dépend de prose libre et de colonnes contenant déjà des `|`, flèches et historiques (`BRIEF.md:252-264`). Le cadrage reconnaît cette fragilité (`:65-68`) sans la résoudre.

## C — Recadrage exigé

Avant écriture :

1. créer **un manifeste structuré canonique** des Legos, incluant état, ordre futur, storyboard, verdict et reçu ;
2. migrer puis supprimer les deux journaux contradictoires du BRIEF ;
3. définir la jointure avec Journey OS — pas une vue concurrente ;
4. spécifier les règles de déduplication et de priorité des autorités ;
5. nommer les tests, fixtures, commande `--check` et gate CI ;
6. exiger une fixture démontrant qu’une contradiction de source fait échouer la génération.

**REJET — recadrer précisément le modèle de données et le contrat de vérification avant de construire `legos_index.py`.**

