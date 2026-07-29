---
description: Triage des 10 tables de chiffres par canton révélées quand le garde no_cantonal_rate_table a été étendu aux affectations annotées (AnnAssign, PR #1088) ; verdict par table (SUPPRIMER / DRAINER / RECALIBRER / CONSERVER SOURCÉE) avec preuve et ordre de résorption. Statut : Proposed.
last_updated: 2026-07-28
---

# Triage des tables cantonales révélées par l'extension AnnAssign

**Statut : Proposed.** Ce document est un état des lieux, pas une décision. Aucun
code n'a été modifié ici. Les branches déjà ouvertes sont citées telles quelles.

## Contexte

`tools/checks/no_cantonal_rate_table.py` refuse toute affectation d'un
dictionnaire indexé par code cantonal dont les valeurs portent un nombre, hors
liste d'autorisation. Sa doctrine : un taux cantonal est une **dérivée** du
modèle fiscal calibré ESTV
(`services/backend/app/services/fiscal/cantonal_comparator.py` —
`estimate_marginal_rate`, `estimate_income_tax`, `estimate_capital_withdrawal_tax`),
pas une constante saisie à la main. Deux surfaces qui stockent chacune leur
propre table finissent par répondre différemment à la même question.

Dans le socle actuel (`origin/dev`), le garde ne parcourt que les `ast.Assign`.
Les 10 tables ci-dessous sont écrites en `ast.AnnAssign` (affectation annotée,
p.ex. `TAUX: Dict[str, float] = {...}`) : elles étaient invisibles du garde.
L'extension `AnnAssign` (PR #1088) les fait apparaître. Ce triage décide, pour
chacune, si la donnée est fabriquée/dérivable ou un fait statutaire sourçable.

> Réserve de méthode : la PR #1088 n'est pas dans la base de ce worktree
> (`origin/dev`). Je n'ai donc pas pu exécuter le garde étendu ici pour confirmer
> mécaniquement la liste exacte des 10 ; elle est reconstruite par grep + la
> spéc de la tâche. Voir « Contre-arguments et data gaps ».

## Verdict par table

| # | Table (`path:ligne`) | Source déclarée | Usages / surface | Verdict | Preuve clé | Effort |
|---|---|---|---|---|---|---|
| 1 | `donation_service.py:56` `TAUX_DONATION_CANTONAL` | « taux plats non sourcés » (aveu dans le commentaire de remplacement) | verdict donation succession | **DRAINER — déjà fait, en vol** | Supprimée sur `origin/codex/journey-os-socle-succession-code-impl` (PR #1087) ; remplacée par `fiscal.succession_donation_socle.verdict` | — (merge) |
| 2 | `precision/precision_service.py:247` `_MARGINAL_RATES_BY_CANTON` | « estimated marginal tax rates by canton and income bracket » | validation profil (precision) | **DRAINER — déjà fait, en vol** | Supprimée sur `origin/codex/journey-os-drain-precision-service` ; remplacée par `estimate_marginal_rate` | — (merge) |
| 3 | `housing_sale_service.py:52` `TAUX_PLUS_VALUE_IMMOBILIERE` | barème plus-value par durée | impôt sur les gains immobiliers | **DRAINER — déjà fait, en vol** | Supprimée sur `origin/codex/journey-os-gains-immo-calibres` (PR #1090) ; remplacée par `fiscal.gains_immobiliers_calibres.verdict_gain_immobilier` | — (merge) |
| 4 | `constants/social_insurance.py:396` `MARRIED_CAPITAL_TAX_DISCOUNT_BY_CANTON` | lois fiscales cantonales (ZH §37, BE art. 44, LU §58, ZG §36, VD art. 49, GE LIPP art. 41, VS art. 33b, TI art. 38), valeurs 2026 ~250k | coefficient marié appliqué au capital retiré (2e/3e pilier) | **RECALIBRER** | 8/26 cantons tabulés + fallback inventé `0.82` pour les 18 restants (`social_insurance.py:407`) ; nourrit l'étalon lui-même (`cantonal_comparator.py:233`) + miroir mobile (`social_insurance.dart:467`) | M |
| 5 | `family/naissance_service.py:63` `ALLOCATIONS_ENFANT_PAR_CANTON` | OFAS/BSV « Genres et montants des allocations familiales 2026 », Stand 12.12.2025 | estimation allocations familiales | **CONSERVER SOURCÉE** | 26/26 valeurs de base identiques à mon extraction vérifiée du PDF officiel OFAS ([[reference-allocations-familiales-cantons-2026]]) | S (allowlist) |
| 6 | `family/naissance_service.py:75` `ALLOCATIONS_FORMATION_PAR_CANTON` | idem OFAS/BSV 2026 | idem | **CONSERVER SOURCÉE** | 26/26 valeurs de base identiques à l'extraction OFAS ; corrige déjà l'ancien modèle « enfant + 50 » (delta réel 0→150) | S (allowlist) |
| 7 | `fiscal/commune_service.py:90` `COMMUNE_DATA` | « Publications officielles cantonales 2025 » (sans date de collecte ni méthode de vérif) | endpoint `/communes` : liste, tri par multiplicateur, lookup NPA | **CONSERVER SOURCÉE (non-barème)** avec lacune de provenance | Ce sont des noms + NPA + Steuerfuss communal (coefficient statutaire) ; dimension intra-cantonale que l'étalon (chef-lieu) ne porte pas → non dérivable. L'endpoint expose le coefficient, jamais un CHF (`communes.py:162`) | S (allowlist) / L (revérifier ~100 valeurs) |
| 8 | `precision/precision_service.py:233` `_CANTON_NET_RATIO` | « approximate net-to-gross ratios » | validation croisée brut↔net du salaire déclaré (tolérance ±8%) | **DRAINER** | Résidu laissé par `drain-precision-service` (qui a drainé #2 mais pas #8) ; le ratio net = 1 − impôt/brut − cotisations sociales, dérivable de `estimate_income_tax` + constantes AVS/AC/LPP | M |
| 9 | `rag/cantonal_knowledge.py:46` `_TAX_SPECIFICS` | « Charge fiscale AFC 2024 » + lois cantonales | **injecté dans le prompt système du coach** (`rag/guardrails.py:661`) | **DRAINER (champs numériques) + CONSERVER (faits qualitatifs)** | `guardrails.py:661` injecte `marginal_rate_pct` tel quel dans le contexte LLM ; écart mesuré contre l'étalon +3,5 à +12,8 points (voir plus bas) | M — **P1** |
| 10 | `rag/cantonal_knowledge.py:228` `_HOUSING_MARKET` | OFS Statistique des loyers 2024, SNB Bulletin 2024 | injecté dans le prompt système du coach (`rag/guardrails.py:673`) | **CONSERVER SOURCÉE** avec nettoyage | Statistiques OFS (loyer médian, prix/m², vacance) — hors champ fiscal, non dérivables de l'étalon. Mais `avg_mortgage_rate_pct = 1.8` est identique pour les 26 cantons : ce n'est pas un fait cantonal | S |

## Détail des cas qui demandent une décision

### #9 `_TAX_SPECIFICS` — le plus urgent (P1)

`rag/guardrails.py:659-669` enrichit le prompt système du coach avec, pour le
canton de l'utilisateur :
`f"Taux marginal cantonal+communal (approx.): {tax['marginal_rate_pct']}%"`.

Mesure déterministe (fonctions réelles de l'étalon, revenu imposable 100k,
célibataire), `path:ligne` `cantonal_comparator.py:288` :

| Canton | `_TAX_SPECIFICS.marginal_rate_pct` | Étalon marginal @100k | Écart |
|---|---|---|---|
| ZH | 32,5 | 25,4 | +7,1 |
| BE | 41,5 | 30,4 | +11,1 |
| VD | 41,5 | 31,8 | +9,7 |
| GE | 44,0 | 31,2 | +12,8 |
| VS | 36,0 | 31,1 | +4,9 |
| TI | 33,5 | 30,0 | +3,5 |
| ZG | 22,5 | 17,1 | +5,4 |

La table dit au coach qu'un profil genevois à 100k a un taux marginal de 44 %,
alors que le modèle calibré ESTV en donne ~31 %. C'est précisément la situation
« deux surfaces, deux réponses » que le garde existe pour empêcher, sauf qu'ici
la surface contaminée est le coach lui-même. `wealth_tax_rate_permille` (injecté
ligne 664) double par ailleurs `wealth_tax_service.EFFECTIVE_WEALTH_TAX_RATES_500K`
(déjà à l'autorisation comme étalon), et `rank_income_tax` est un tri dérivable
de l'étalon.

Chemin proposé : dans `guardrails`, remplacer l'injection de `marginal_rate_pct`
par un appel à `estimate_marginal_rate(revenu, canton)` ; retirer les champs
numériques de `_TAX_SPECIFICS`. **Conserver** les faits qualitatifs statutaires
(`capital_gains_tax`, `inheritance_tax_direct_heirs`, `gift_tax_direct_heirs`,
`notable_deductions`, `source`) : ce ne sont pas des chiffres, ils ne relèvent
pas du garde et ne sont pas dérivables de l'étalon.

### #8 `_CANTON_NET_RATIO` — résidu du drainage precision

`origin/codex/journey-os-drain-precision-service` a drainé `_MARGINAL_RATES_BY_CANTON`
(#2) vers l'étalon dans le même fichier, mais a laissé `_CANTON_NET_RATIO`
intact (`precision_service.py:233`, consommé lignes 378 et 576). Le ratio
net/brut se décompose en (1 − taux d'impôt sur le revenu − taux de cotisations
sociales). Le premier terme varie par canton et est dérivable de
`estimate_income_tax` ; le second est quasi invariant (constantes AVS/AI/APG,
AC, LPP, LAA). Verdict : DRAINER, en prolongeant le même drainage — la table est
une approximation là où l'étalon donne le chiffre par construction.

### #4 `MARRIED_CAPITAL_TAX_DISCOUNT_BY_CANTON` — recalibrer via ESTV

Le coefficient marié (0,70→0,82) multiplie la part cantonale du retrait en
capital (`cantonal_comparator.py:233`). Deux faiblesses : (a) seulement 8/26
cantons tabulés, les 18 autres retombant sur un `0.82` empirique inventé
(`social_insurance.py:407`) ; (b) même les 8 valeurs sont un point unique
(~250k) saisi depuis les lois, pas une dérivée mesurée.

Le socle `CANONICAL_CAPITAL_TAX_CHF` a été collecté pour **célibataire** via
l'API ESTV `API_calculateManyCapitalTaxes` (outil de capture présent :
`services/backend/tests/scripts/capture_estv_oracle.py`, artefacts
`constants-audit/capital_tax_2026/`). Chemin proposé : re-collecter les mêmes
points en **marié**, puis dériver le coefficient (marié/célibataire) au lieu de
le saisir — même patron que la collecte -2i2. Le `0.82` pour 18 cantons
disparaît alors. Repli si l'API n'expose pas l'état civil sur le capital :
downgrade vers CONSERVER SOURCÉE (8 cantons) en retirant le fallback inventé.

### #7 `COMMUNE_DATA` — non-barème légitime, provenance à compléter

L'étalon ESTV encode la charge cantonale+communale **du chef-lieu** de chaque
canton. `COMMUNE_DATA` porte la variation **intra-cantonale** (p.ex. ZH :
Steuerfuss 119 à Zürich-ville, 88 à Küsnacht, 80 à Zollikon — `commune_service.py:96,110,111`)
que l'étalon ne capture pas : il n'y a rien vers quoi la « drainer ». C'est,
au sens de la doctrine du garde, une table de noms + NPA + un coefficient
statutaire (Steuerfuss/multiplicateur), pas un barème qui diverge de l'étalon.
L'endpoint affiche le coefficient et son amplitude, jamais un montant en CHF
(`communes.py:162-167`), sous disclaimer LSFin (`commune_service.py:29`).

Verdict : CONSERVER SOURCÉE (autorisation comme non-barème), mais la source est
générique (« publications cantonales 2025 ») sans date de collecte ni méthode
de vérification — les deux exigences que le garde impose à un étalon assumé.
Pour la promouvoir en étalon il faudrait dater et revérifier les ~100 valeurs
(effort L) ; pour l'autoriser comme non-barème documenté, effort S.

### #10 `_HOUSING_MARKET` — statistiques OFS, hors champ fiscal

Loyers médians, prix/m², taux de vacance : faits OFS, non dérivables de
l'étalon fiscal, injectés au coach pour les questions logement
(`guardrails.py:671-677`). Verdict CONSERVER SOURCÉE, avec un nettoyage :
`avg_mortgage_rate_pct = 1.8` est identique pour les 26 cantons — le taux
hypothécaire n'est pas une donnée cantonale et vieillit vite ; il devrait être
une constante nationale unique datée, pas une colonne par canton. Ajouter une
date de collecte sur le bloc OFS.

### #5 / #6 `ALLOCATIONS_*_PAR_CANTON` — faits statutaires vérifiés

Les 26 valeurs de base des deux tables coïncident exactement avec mon extraction
vérifiée du PDF officiel OFAS/BSV 2026 (Stand 12.12.2025,
[[reference-allocations-familiales-cantons-2026]]). Ce ne sont pas des taux
fiscaux et ne se dérivent pas de l'étalon ; ce sont des montants légaux publiés
annuellement, de la même famille que `LAMAL_PRIMES_MENSUELLES` ou
`CANTON_SOURCE_TAX_RATES` déjà à l'autorisation. Verdict : CONSERVER SOURCÉE,
autorisation comme étalon (source primaire + date de collecte présentes). Les
modulations par âge (ZH/LU/ZG) et par rang (FR/VD/VS/NE/GE) restent documentées
comme non modélisées (simplification éducative assumée).

## Ordre de résorption proposé (valeur / effort)

1. **#9 `_TAX_SPECIFICS` (P1)** — valeur haute, effort M. Seule table qui
   empoisonne directement le coach, écart mesuré jusqu'à +12,8 points. Le
   drainage se concentre sur `guardrails.py` (un point d'injection) + retrait
   des champs numériques ; les faits qualitatifs restent.
2. **#8 `_CANTON_NET_RATIO`** — valeur moyenne, effort M. Même fichier qu'une
   branche en vol ; à traiter dans le sillage de `drain-precision-service`.
3. **#4 `MARRIED_CAPITAL_TAX_DISCOUNT`** — valeur moyenne, effort M. Une passe
   de collecte ESTV réutilise un patron existant ; tue le fallback `0.82`.
4. **Régularisation d'autorisation (pas de changement de calcul)** — effort S :
   #5, #6 (vérifiées → autorisation comme étalons), #7 (autorisation non-barème
   + date de collecte à ajouter), #10 (bloc OFS daté + taux hypothécaire sorti
   du per-canton).
5. **Suivi de merge uniquement** — #1, #2, #3 : déjà drainées sur des branches
   ouvertes ; rien à refaire, ne pas rouvrir.

## Contre-arguments et data gaps

- **Liste des 10 non confirmée mécaniquement ici.** Le garde étendu (PR #1088)
  n'est pas dans `origin/dev` ; je n'ai pas exécuté sa détection AnnAssign dans
  ce worktree. La liste vient de la spéc + grep. Un lecteur devrait rejouer le
  garde étendu sur la base cible avant d'agir.
- **Écart #9 mesuré, mais pas à périmètre strictement identique.** J'ai comparé
  un `marginal_rate_pct` étiqueté « cantonal+communal » contre le marginal de
  l'étalon qui **inclut** l'IFD fédéral. Si la table exclut vraiment le fédéral,
  l'écart réel est encore plus grand (l'étalon « cantonal+communal seul » serait
  plus bas). Dans les deux lectures la table surestime ; +12,8 est une borne
  basse. Mesure sur 7 cantons, pas les 26.
- **#7 non revérifiée sur le fond.** Le verdict CONSERVER suppose que les ~100
  Steuerfuss sont des faits statutaires globalement corrects ; je ne les ai pas
  recoupés contre les publications communales 2025. Contre-argument : si des
  multiplicateurs sont périmés, le message « choisir la bonne commune peut
  réduire tes impôts » pourrait induire en erreur — atténué par le fait que
  l'endpoint montre un coefficient (pas un CHF) sous disclaimer.
- **#5/#6 : base seule.** Un enfant zurichois de plus de 12 ans ouvre 268, pas
  215 ; la table de base sous-estime pour ces profils. La modulation est
  documentée comme non modélisée, mais c'est une simplification, pas une donnée
  exacte pour tous les cas.
- **#4 : faisabilité de la collecte ESTV mariée à confirmer.** Le verdict
  RECALIBRER suppose que `API_calculateManyCapitalTaxes` accepte l'état civil
  sur le capital. Si non, repli documenté ci-dessus.
- **Statut Proposed.** Aucun de ces verdicts n'est arrêté ; ils cadrent des PR
  de résorption à ouvrir séparément, une table à la fois, chacune retirant son
  entrée de l'autorisation du garde.
