---
description: Constat §3.4 du hand-off 2026-07-27 pour expat/frontalier_service — le champ base_rate (26/26, 24 citations légales) est CONFIRMÉ jamais lu par rejeu — le calcul vivant est « progressif × multiplier » ; et LAMAL_PRIMES_MENSUELLES étiquetée « adulte franchise 300, OFSP 2025 » ressemble à une moyenne toutes-franchises mal étiquetée (GE 580 contre ~586 toutes-franchises et 722-819 en franchise 300 réelle). Suppression du champ mort exécutable ; le sort des primes LAMal est une décision 🔴.
---

# Constat — frontalier_service : base_rate mort, primes LAMal mal étiquetées

Deux lignes du tableau §3.4 du hand-off `2026-07-27-HANDOFF.md`, même
fichier (`services/backend/app/services/expat/frontalier_service.py`).
Phase 1 (« prouver ») seulement — la phase 2 (« décider ») reste 🔴.

## 1. `base_rate` de CANTON_SOURCE_TAX_RATES — jamais lu, confirmé

Le rapport d'agent (« champ supposé jamais lu ») est **rejoué et confirmé** :

- La table (`:62`) n'a **aucun lecteur hors du fichier** (grep
  `CANTON_SOURCE_TAX_RATES` sur `app/` + `tests/` : zéro hit externe).
- Dans le fichier, elle est lue une seule fois (`:419`), et seuls deux
  champs sont consommés : `special` (`:422` — régimes GE/TI) et
  `multiplier` (`:457`). **`base_rate` n'est lu nulle part.**
- Le calcul vivant est `_calculate_source_tax_progressive(salaire_imposable)
  × multiplier` (`:456-458`) : le « taux de base 4.5 % » décoré de 24
  citations d'ordonnances cantonales (StG-ZH § 95, LI-VD art. 174…) ne
  nourrit aucun chiffre affiché.
- La surface existe : endpoint `expat.py:82 calculate_source_tax`
  (kind `source_tax`). Le widget mobile précis n'a pas été retracé
  jusqu'au rendu — borne honnête de ce constat.

**Verdict base_rate** : suppression du champ mort exécutable **sans
décision produit** (aucun affichage ne change), sur le modèle de la
suppression `rachat_echelonne` (#1073). Attention en l'implémentant :
les citations légales par canton documentent AUSSI le `multiplier` vivant
— les conserver sur la table, ne supprimer que les paires
`"base_rate": …`. L'entrée du garde `no_cantonal_rate_table` reste
légitime tant que la table (multiplier) vit.

## 2. LAMAL_PRIMES_MENSUELLES — l'étiquette ne correspond pas au profil

La table (`:233`, 26/26 cantons) annonce « prime mensuelle moyenne
adulte, franchise 300 CHF — Source : OFSP, primes LAMal 2025 » et
alimente un chiffre affiché : `compare_lamal_options` (`:769`) → prime
mensuelle/annuelle du choix LAMal du frontalier (avec réduction −25 %
pour les moins de 26 ans, `:771-772`).

Vérification directionnelle sur deux cantons (sources secondaires 2026,
web du 2026-07-27) :

| Canton | Table (« franchise 300, 2025 ») | Observé |
|---|---|---|
| GE | 580 | moyenne adulte **toutes franchises** ≈ 586 ; en **franchise 300** réelle, caisses à 722-819 CHF/mois |
| ZH | 460 | ≈ 485 CHF/mois pour un profil franchise **2500** médecin de famille (2026) — la franchise 300 standard est nettement au-dessus |

Lecture : les valeurs de la table collent à la **moyenne toutes
franchises**, pas au profil « franchise 300 » qu'elles annoncent — pour ce
profil, elles sous-estiment la prime de l'ordre de 20-40 %. Les montants
ronds (580, 540, 520…) confirment l'estimation grossière.

**Limite** : comparaison faite contre des sources secondaires 2026
(comparateurs), pas contre le CSV primaire OFSP/priminfo 2025 au franc —
c'est le premier geste de l'unité de décision (la donnée est ouverte,
opendata.swiss / priminfo.admin.ch).

**Verdict LAMal** : 🔴 décision produit requise (hand-off §3.4 phase 2) :
recalibrer sur la donnée primaire OFSP (et quel millésime — 2026 est
publié), ré-étiqueter honnêtement (« moyenne toutes franchises »), ou
remplacer le chiffre par une plage sourcée. Retirer sans remplacer
casserait la comparaison LAMal/assurance-résidence — le reproche « produit
vide » de l'audit s'applique.

## 3. Croisements avec les constats existants

- La recommandation user-facing `:466-469` emploie `{:,.0f}` (virgule US)
  — déjà inventorié dans le constat formatage (#1074).
- `:515` et `:519` portent « specialiste » sans accent — déjà inventorié
  dans le constat DISCLAIMER (#1074).

Sources web : [compassurance — primes Genève 2026](https://compassurance.ch/primes-assurance-maladie-geneve-2026-comparatif/) · [Polia — LAMal Zurich](https://polia.ch/lamal/zurich/lamal-admin/) · [hellosafe — prix assurance maladie](https://hellosafe.ch/assurance-maladie/prix)
