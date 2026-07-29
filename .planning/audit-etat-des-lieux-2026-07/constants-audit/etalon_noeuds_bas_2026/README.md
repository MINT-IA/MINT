---
description: Étalon ESTV des nœuds bas (15k/25k/35k) ajoutés à CANTONAL_COMMUNAL_TAX_CHF pour corriger la surestimation d'impôt cantonal sous 40k (finding INC-1 de l'oracle #1098).
---

# Étalon revenu — nœuds bas (< 40k) — collecte 2026-07-28

## TLDR

Sous l'ancien premier nœud de la grille revenu (40'000 CHF), le modèle
cantonal interpolait linéairement l'impôt **depuis (0, 0)**. Comme la plupart
des cantons ont un **seuil non imposable** (l'impôt est nul ou quasi nul
jusqu'à ~15'000 CHF de revenu imposable), cette droite **surestimait** l'impôt
cantonal jusqu'à **+59.8 %** (GE 30k : MINT 2'780 vs ESTV 1'739). C'est le
finding **INC-1** de l'oracle ESTV (PR #1098).

Cette collecte capture, pour les **26 chefs-lieux**, l'impôt cantonal+communal
réel à des revenus imposables bas, et sert à étendre la grille de calibration
vers le bas avec **3 nouveaux nœuds : 15'000 / 25'000 / 35'000 CHF**.

## Ce qui est archivé

- `consolidated.json` :
  - `meta` — source, profil, année fiscale, méthode, résultat de la porte
    d'intégrité.
  - `node_integrity_gate` — pour CHAQUE canton, la reproduction des 5 nœuds
    committés (`cantonal_communal`) à +/-1 CHF **avant** d'accepter le moindre
    point bas. 26/26 cantons dans la porte, 0 abandonné.
  - `points_chf_cantonal_communal` / `ifd_chf` — les captures brutes ESTV à
    10k / 15k / 20k / 25k / 30k / 35k.
  - `added_nodes_for_table` — les 3 valeurs (15k/25k/35k) injectées par canton
    dans `CANTONAL_COMMUNAL_TAX_CHF`.
  - `measured_error_vs_estv` — erreur relative du modèle AVANT / APRÈS, aux
    points diagnostic 10k/20k/30k. 30k n'est **pas** un nœud : c'est une
    mesure d'interpolation honnête au point exact du finding INC-1.

## Méthode (0-trust)

API JSON officielle ESTV `swisstaxcalculator` (opération
`API_calculateSimpleTaxes`), le même endpoint que la calibration committée et
l'oracle. Profil : célibataire, sans enfant, sans confession (`Confession1=4`),
fortune 0, taxe personnelle incluse. `cantonal_communal = IncomeTaxCanton +
IncomeTaxCity + PersonalTax + IncomeTaxChurch`. Année 2026 partout **sauf SG et
TI = 2025** (l'ESTV n'a pas encore publié leur barème 2026 ; identique à la
table committée). Porte d'intégrité : un canton qui ne reproduit pas ses 5
nœuds committés à +/-1 CHF est abandonné (aucune donnée inventée).

## Amélioration mesurée (INC-1, revenu imposable 30'000)

| Canton | ESTV | ancien modèle | ancien écart | nouveau modèle | nouvel écart |
|--------|-----:|--------------:|-------------:|---------------:|-------------:|
| GE     | 1739 | 2779.5        | +59.8 %      | 1789.0         | +2.9 %       |
| BL     | 1749 | 2684.2        | +53.5 %      | 1811.5         | +3.6 %       |
| GR     | 1534 | 2322.8        | +51.4 %      | 1551.5         | +1.1 %       |
| TI     | 1902 | 2790.0        | +46.7 %      | 2030.5         | +6.8 %       |

Sur les 26 chefs-lieux à 30k, l'erreur maximale du nouveau modèle est **6.76 %
(TI)** ; 25/26 sont sous 4 %.

## Limite résiduelle (dite, pas cachée)

**Résiduel connu accepté — TI 30k = +6.8 %.** C'est le seul chef-lieu au-dessus
de la bande ~5 % à 30k (barème TI 2025 très convexe entre 25k et 35k, où 30k est
un point interpolé et non un nœud). Ramené de +46.7 % (ancien modèle) à +6.8 % ;
les 25 autres cantons sont sous 4 %. Non corrigé plus finement à dessein (un nœud
30k dédié « collerait au test » sans améliorer la courbe ailleurs).

Le nouveau nœud le plus bas est 15'000 CHF. Deux zones gardent une erreur
**relative** plus élevée, sur des montants d'impôt **faibles en absolu** :

1. **Sous 15k** (`[0, 15k]`, interpolation linéaire depuis (0,0)) : correcte
   pour les cantons à seuil (BL, GR : 0 à 15k) ; pour les cantons quasi
   linéaires sans seuil (BE, BS, OW, UR) l'écart au point 10k reste < ~10 %.
2. **`[15k, 25k]` (genou post-seuil)** : là où le barème cantonal est le plus
   convexe. Au point 20k, l'erreur relative peut rester élevée (GE +135 %, GR
   +93 %, BL +20 %) parce que l'impôt y est de l'ordre de **quelques dizaines à
   quelques centaines de CHF** : l'erreur absolue reste < ~260 CHF, soit
   < ~1.5 % du revenu. TI 20k passe même en sous-estimation (-7.4 %). **Aucune
   promesse de précision au centime dans ce genou** : c'est une estimation
   éducative (LSFin), pas un conseil fiscal.

## Reproduire

Depuis un environnement avec accès réseau ESTV, mêmes conventions que
`services/backend/tests/scripts/capture_estv_oracle.py`. Si l'API ESTV est
indisponible : ne rien inventer, documenter l'échec, ré-essayer.
