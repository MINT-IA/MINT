---
description: Revue méthodologique niveau actuaire/data-science des moteurs fiscaux calibrés (étalon revenu, capital célibataire+marié, gains immobiliers ZH/VD/GE, bande net/brut) — verdicts par moteur avec sondes exécutées, top-3 d'améliorations (IFD marié, post-condition marié≤célibataire, property tests 0→3M) implémenté sur la branche capital-marié le jour même. Les sondes citées vivaient dans le scratchpad de session (éphémère) ; leurs résultats chiffrés sont retranscrits dans la page et re-dérivables des tables committées.
---

# Panel actuariel — revue méthodologique des moteurs fiscaux calibrés

Mandat Julien 2026-07-28 : « assure-toi qu'on a bien des calculs de niveau actuaire / data science senior. »
Deux lentilles appliquées : (A) actuaire senior — interpolation, monotonie, bornes, extrapolation,
arrondis, propagation ; (B) data scientist senior — couverture de validation, jeux de référence,
détection de dérive, propriétés testées mécaniquement.

Rigueur 0-trust : chaque chiffre ci-dessous est une sortie de sonde exécutée, pas une estimation de tête.

## Sondes exécutées (rejouables)

- `/private/tmp/claude-501/-Users-julienbattaglia-Desktop-MINT-nosync/d8bdc5c9-829d-4a32-b89e-e1f3117b0285/scratchpad/probe_actuariat_mb.py` — sections A à D
- `/private/tmp/claude-501/-Users-julienbattaglia-Desktop-MINT-nosync/d8bdc5c9-829d-4a32-b89e-e1f3117b0285/scratchpad/probe2_mb.py` — marginal≥moyen, monotonie du taux moyen, non-monotonie du marginal
- Interpréteur : `/Users/julienbattaglia/.pyenv/versions/3.11.9/bin/python3.11` (le `python3` du shell est < 3.10, `float | None` casse à l'import)
- Tables sources chargées telles quelles depuis les branches : `cc_dev.py` (origin/dev), `cc_marie.py` (origin/codex/journey-os-recalibrage-capital-marie), `immo.py` (origin/codex/journey-os-gains-immo-calibres), `precision.py` (origin/codex/journey-os-drain-precision-service), `consolidated.json` (archive capital marié).

---

## Verdicts par moteur

| Moteur | Branche | Verdict | Fil rouge |
|---|---|---|---|
| 1. Étalon revenu (interp. 130 pts + IFD progressif) | origin/dev | **SOLIDE AVEC RÉSERVES** | Invariants de base tenus ; grille 5 pts trop lâche à 150-250k ; marginal non-monotone sur ~6 cantons ; aucun jeu de validation entre points |
| 2. Capital célibataire + marié (table 26×5) | recalibrage-capital-marie | **SOLIDE AVEC RÉSERVES** (fragile en extrapolation) | Invariants tenus aux points de grille ; marié > célibataire au-delà de 1,09M à TI (+23,8% à 2M) NON testé ; résiduel Option B jusqu'à +13,6% (pas 1-5%) |
| 3. Gains immobiliers ZH/VD/GE (barème exact) | gains-immo-calibres | **SOLIDE** | Pas d'interpolation, vecteurs officiels rejoués, verdict « inconnu » honnête ; falaises de durée fidèles mais non annoncées |
| 4. Bande net/brut (plausibilité) | drain-precision-service | **SOLIDE** (adapté à l'usage) | Bande de validation, pas un chiffre affiché ; tolérance 0,05 ; hérite de l'erreur d'interpolation de l'étalon mais faible enjeu |

---

## Moteur 1 — Étalon revenu (origin/dev)

Mécanisme : IFD calculé **exactement** par tranches (`FEDERAL_BRACKETS`, `estimate_income_tax_parts`), part
cantonale+communale **interpolée linéairement** sur 5 points (40/70/100/150/250k), extrapolée à la pente du
dernier segment au-delà de 250k, linéaire depuis (0,0) sous 40k. Marié = total × 0.80 (splitting forfaitaire).

### Ce qui tient (preuves)
- **Monotonie** : les 26 tables cantonales sont strictement croissantes sur les 5 points (probe A1 : « ALL 26 OK »).
- **Marginal ≥ moyen** : jamais violé sur `ti ∈ [5k, 1M]`, 26 cantons (probe2 §1 ; les seuls « == » apparaissent sous 40k où la part cantonale est proportionnelle, donc marginal = moyen, ce qui est correct).
- **Taux moyen croissant** : monotone non-décroissant sur les 26 cantons jusqu'à 600k (probe2 §2 ; seul « creux » = FR 12.567 vs 12.568%, soit 0,001 pt de bruit d'arrondi de la fenêtre à 1000 CHF — non matériel).
- **Clamp [0, 0.50]** : **ne se déclenche JAMAIS** pour `ti ≤ 2M`, célibataire et marié, sur les 26 cantons (probe A5). Le clamp est purement défensif ; il ne masque aucune explosion d'extrapolation. Le marginal réel plafonne vers 37-44% (ZH 37,9% ; VD 44,5% ; probe A4).
- **Marié ≤ célibataire pour le revenu** : structurellement garanti — le marié est un facteur scalaire 0.80 appliqué à une interpolation unique, donc pas de croisement possible (contrairement au capital, cf. moteur 2). Rien à tester.

### Réserves (défauts chiffrés)
1. **Grille 5 points trop lâche là où la courbure est forte.** À chaque nœud interne, le taux marginal du modèle
   saute (discontinuité = courbure que l'interpolation linéaire ne voit pas). Sauts cantonaux max mesurés
   (probe A3) : **VS 6,54 pts à 100k**, VD 3,92 pts à 70k, ZH 3,46 pts à 150k, BL 3,21, FR 2,96, ZG 2,94. Le trou
   150→250k fait **100 000 CHF de large** : c'est la zone d'erreur d'interpolation maximale et il n'y a aucun
   point entre les deux.
2. **Marginal NON-monotone (décroissant) sur ~6 cantons** — artefact de calibration ou barème réellement concave.
   Segments non-convexes détectés (probe A2) : VS, FR, NE, ZG, NW, AI (plus OW/UR/SZ quasi-plats = bruit). Effet
   mesuré (probe2 §3-4) : **le marginal VS culmine à 42,08% vers 150k puis REDESCEND à 40,51% à 250k** (chute
   jusqu'à 3,77 pts), ZG −1,82 pt, NW −1,65 pt. Le Valais n'a pas d'impôt dégressif : soit un point de grille
   (VS 150k = 32 371, ou 250k = 59 684) est mal transcrit, soit la grille + interpolation linéaire ne peut pas
   représenter la vraie courbe. Conséquence produit : `estimate_marginal_rate` peut rendre un taux marginal qui
   **baisse** quand le revenu monte — contre-intuitif et potentiellement faux de plusieurs points si affiché.
3. **Aucun jeu de validation indépendant entre les points de grille.** Les « 130 points recapturés à 0 divergence »
   sont un test de **reproductibilité interne** (la table se recalcule elle-même), pas une vérification contre
   l'ESTV entre les nœuds. Le seul oracle indépendant (`test_estv_oracle.py` + fixture `estv_oracle_2025.jsonl`)
   lit une **fixture vide** (0 octet, vérifié `git cat-file`) : les 50 slots `test_mint_matches_estv` **skippent
   tous**, et le lint de fraîcheur `estv_oracle_freshness.py` no-op sur fichier vide. La couche de détection de
   dérive existe mais est **dormante**.
4. **Proxy « imposable ≈ 85% du brut »** : déduction forfaitaire plate de 15%. Les déductions réelles (2e pilier
   déjà hors brut-net, 3a, assurances, frais pro) varient fortement ; documenté dans les docstrings, mais l'écart
   sur un chiffre unique peut être matériel selon le profil.
5. **Mineur** : au-delà de 794k imposable, `FEDERAL_BRACKETS` porte `(inf, 0.1150)` traité comme un taux **marginal**
   de tranche, alors que le 11,5% de l'art. 36 al. 1 est un **plafond de taux moyen**. D'où la légère baisse du
   marginal à 1M (ZH 36,17% vs 37,87% à 300k, probe A4). N'affecte que les imposables > 794k.

### Sens de l'erreur d'interpolation
L'intuition « barème progressif convexe → l'interpolation linéaire surestime entre points » n'est **pas
universellement vraie ici** : les tables cantonales ne sont **pas globalement convexes** (probe A2, 6 cantons
concaves au sommet). En zone convexe la corde surestime l'impôt ; en zone concave (VS/ZG/NW top) elle sous-estime.
Le signe de l'erreur est donc **dépendant de la région** — il faut le dire, pas le supposer.

---

## Moteur 2 — Capital célibataire + marié (recalibrage-capital-marie)

Mécanisme : IFD art. 38 = 1/5 du barème revenu (progressif, exact) + part cantonale interpolée sur 5 montants
(100/250/500/750k/1M). Le rabais marié forfaitaire par canton est **remplacé** par une vraie table mariée 26×5
(`CANTONAL_CAPITAL_TAX_MARRIED_CHF`), même grille, même interpolation. Miroir Dart `income_tax_model_v2.dart`
parité exacte (diff vérifiée). **Option B assumée** : l'IFD reste celui du célibataire pour les deux états civils.

### Ce qui tient (preuves)
- **Monotonie** : tables célibataire ET mariée strictement croissantes, 26 cantons (probe B1).
- **Marié ≤ célibataire aux points de grille** : tenu à 24/26 cantons proprement ; **exception SO** (Soleure) où
  le marié dépasse le célibataire de **exactement 1 CHF** à 750k (42 526 vs 42 525) et 1M (56 701 vs 56 700) —
  artefact d'arrondi ESTV documenté dans la table (probe B2).
- **Préservation par l'interpolation — théorème vérifié** : deux interpolations linéaires sur la **même grille**
  ne peuvent se croiser à l'intérieur que si l'ordre est déjà rompu à un point de grille (la différence
  célibataire−marié est linéaire par morceaux ; ≥0 aux deux bornes ⟹ ≥0 sur le segment). Balayage dense
  `[100k, 1M]` pas de 2 500 CHF : **le seul croisement intérieur est SO à 750k**, propagation du 1 CHF ci-dessus
  (probe B3). L'inquiétude « les pentes diffèrent donc ça peut se croiser entre points » ne se matérialise PAS à
  l'intérieur de la grille — uniquement en extrapolation (ci-dessous).

### Réserves (défauts chiffrés)
1. **CROISEMENT EN EXTRAPOLATION > 1M — Tessin (défaut réel).** Au-delà de 1M, le modèle extrapole à la pente du
   dernier segment. La table **célibataire TI** a un segment 750k→1M anormalement plat (43 425→57 900, pente
   0,0579) — c'est une table célibataire **non-convexe/concave au sommet** (probe B6 : TI pentes
   0,0386/0,0608/0,0743/**0,0579**). La table mariée TI extrapole à 0,1003. Résultat (probe B4) : **le marié TI
   dépasse le célibataire dès 1 091 585 CHF de capital**, et via l'étalon complet (IFD inclus) :
   - **TI @ 2M : marié 200 295 > célibataire 161 800 (+38 495 CHF, +23,8%)**
   - **TI @ 3M : marié 323 571 > célibataire 242 700 (+80 871 CHF, +33,3%)**
   Économiquement faux (le marié paierait plus que le célibataire par pur artefact de pente d'extrapolation). VD
   « croise » à 950 millions (pentes égales à l'arrondi = jamais). **Seul TI est réel.** Non détecté par les tests :
   `test_married_not_higher_than_single` n'échantillonne **que les 5 montants de grille** (tous ≤ 1M, où l'ordre
   tient) et tolère `married <= single + 1.0` (le +1 CHF de SO est absorbé, pas signalé).
2. **Résiduel Option B jusqu'à +13,6%, pas 1-5%.** L'étalon applique l'IFD **célibataire** aux retraits mariés,
   alors que l'archive `consolidated.json` contient déjà l'IFD marié (art. 36 al. 2, splitting). Écarts IFD
   (probe B5) : 100k → single 537 / marié 363 (Δ 174) ; 500k → 10 501 / 10 176 (Δ 325) ; 1M → 23 000 / 23 000
   (Δ 0, plafond 11,5%). Comme l'IFD est une **grande part d'un petit total** à bas montant, le résiduel en % est
   maximal en bas de grille dans les cantons à faible fiscalité :
   - **SZ @ 100k : +13,6%** (surestimation de 174 CHF sur un vrai total marié de 1 280)
   - **ZG @ 100k : +9,1%** ; SH +8,0% ; AI +6,7% ; FR/GE +6,4% ; NW +6,1% ; GR +5,7%
   - au-dessus de 250k le résiduel retombe sous ~3% ; nul à 1M.
   L'hypothèse « résiduel 1-5% » du mandat est **fausse pour les petits retraits** : c'est jusqu'à **+13,6%**, et
   ça surestime toujours l'impôt marié — donc **sous-estime** l'attrait d'un retrait en capital pour un couple à
   pot modeste (majorité des cas), ce qui peut inverser un verdict rente-vs-capital ou bloc-vs-étalé.
3. **SO : invariant marié ≤ célibataire cassé de 1 CHF** aux points de grille (voir plus haut). Impact économique
   nul, mais c'est un invariant rompu que le test verrouille avec une tolérance `+1.0` au lieu de le corriger.
4. **Tables célibataire non-convexes** (probe B6 : TI, VS, GR, NE, SZ, SO, SH…) → l'extrapolation au-delà de 1M
   est peu fiable partout où le dernier segment est concave (cause racine du croisement TI).

---

## Moteur 3 — Gains immobiliers ZH/VD/GE (gains-immo-calibres)

Mécanisme : **barème exact, aucune interpolation.** ZH = tarif progressif par tranches de gain (§225 StG) +
majoration courte durée + rabais longue durée ; VD = taux dégressif par durée (25 lignes, art. 72, double comptage
occupation) ; GE = taux dégressif par durée (7 lettres, art. 84). Hors ZH/VD/GE : verdict « mécanisme » (renvoi au
calculateur cantonal, pas de chiffre) ou « inconnu ». **Jamais de montant fabriqué.**

### Ce qui tient (preuves)
- **ZH tarif monotone croissant** sur [0, 200k] (probe C2). Taux effectif ZH 23,8% à 50k → 34,7% à 200k → 38,9%
  à 1M, asymptote 40% (probe C5) — forme progressive saine.
- **Pas d'erreur numérique** : taux × gain (VD/GE) et somme de tranches (ZH) sont exacts. Les vecteurs officiels du
  tableau B ZH sont rejoués dans les tests (design cité dans la docstring).
- **Honnêteté du périmètre** : BE/LU/BS = « mécanisme » sans chiffre ; autres = « inconnu ». Défendable.

### Réserves (mineures, fidèles à la loi)
1. **Falaises de durée non annoncées.** Les barèmes VD/GE sont des **fonctions en escalier par année pleine**. Sur
   un gain constant de 500k (probe C3) : **GE 24 ans → 25 ans fait chuter l'impôt de 50 000 à 10 000 CHF (−40 000
   pour une année de plus)** ; VD va de 30% (0 an) à 7% (24 ans). Fidèle au droit, mais la résolution est
   **l'année entière** : un détenteur à 24 ans + 11 mois est traité à 24 ans (10%) alors qu'il est à un mois du
   seuil des 2%. La proximité d'un seuil de durée n'est **pas remontée** à l'utilisateur — enjeu de lucidité, pas
   de calcul.
2. **Franchise ZH = falaise de 440 CHF** (probe C1) : gain 4 999 → 0 CHF, gain 5 000 → 440 CHF (impôt sur le gain
   entier). C'est cohérent avec une **Freigrenze** (seuil), pas une Freibetrag (déduction). À **vérifier sur la
   source primaire** §225 StG : si c'est une Freibetrag, le code surtaxe autour de 5 000.

---

## Moteur 4 — Bande net/brut de plausibilité (drain-precision-service)

Mécanisme : `_net_gross_ratio_band` retourne `(ratio_min, ratio_max)`. `ratio_max = 1 − charges sociales min`
(AVS/AI/APG + AC plafonnée, LPP nulle) ; `ratio_min = 1 − charges max (LPP 18% + ANP/IJM 2%) − taux moyen d'impôt`,
ce dernier tiré de l'étalon `estimate_income_tax(salary × 0.85)` rapporté au brut. Tolérance ±0.05.

### Verdict : SOLIDE (adapté à l'usage)
- C'est une **bande de validation** (déclenche une alerte de cohérence si le net saisi sort de la bande), **pas un
  chiffre affiché**. La précision requise est faible ; la tolérance 0.05 absorbe l'erreur d'interpolation héritée
  de l'étalon.
- Suppression correcte de l'ancienne table cantonale scalaire (0.74-0.83 sans source) qui confondait net de fiche
  et net après impôt à la source. La bande dérivée est plus honnête.
- Pas de double application du 0.85 (l'étalon prend l'imposable ; la bande applique 0.85 puis appelle l'étalon —
  vérifié, cohérent avec `estimate_income_tax_on_rente` et `CantonalComparator.estimate_tax`).
- Réserve mineure : `avg_tax_rate` utilise le barème **célibataire** — acceptable pour un **plancher** de bande.

---

## Transverse — périmètre communal

L'étalon ne porte que le **chef-lieu**. Pour une commune non chef-lieu, l'écart vient du Steuerfuss communal
(COMMUNE_DATA ZH : chef-lieu ~119% vs communes basses ~72-80%). Ordre de grandeur (probe D) : si la part communale
≈ moitié de la ligne cantonale+communale, un passage 119→80% ampute cette moitié de ~33%, soit **~15-20% de la
ligne cantonale+communale ZH**. C'est **énoncé qualitativement** à l'utilisateur (DISCLAIMER + checklist « Vérifier
le taux d'imposition exact de ta future commune ») mais la **magnitude n'est pas chiffrée**, et une comparaison
chef-lieu contre chef-lieu peut induire en erreur sur une simulation de déménagement (commune basse d'un canton
cher → chef-lieu d'un canton bon marché).

---

## Améliorations priorisées (défaut → impact chiffré → effort)

| # | Défaut | Impact chiffré (sonde) | Effort |
|---|---|---|---|
| 1 | Étalon capital applique l'IFD célibataire aux mariés (Option B) | Surestime le marié **jusqu'à +13,6%** (SZ 100k), +9,1% ZG, +6-8% cantons bas ; retombe <3% >250k (B5) | **FAIBLE** — l'IFD marié 5 points est **déjà dans `consolidated.json`** ; ajouter une table + interpolation identique |
| 2 | Croisement marié > célibataire en extrapolation TI >1,09M | **+23,8% à 2M, +33,3% à 3M** (B4) | **FAIBLE** — post-condition `married = min(married, single)` OU borner la pente d'extrapolation mariée à celle du célibataire |
| 3 | Tests de propriété échantillonnent **uniquement les points de grille** | N'a détecté ni TI (B4) ni la non-monotonie VS (A2) ni SO (masqué par tolérance +1) | **FAIBLE-MOYEN** — tests type Hypothesis sur le domaine continu (0 → 3M) : monotonie, marié≤célibataire, marginal≥moyen, marginal∈[0,0.50] |
| 4 | Oracle ESTV indépendant **dormant** (fixture vide) | 50 slots skippés ; lint fraîcheur no-op ; aucune détection de rupture de barème au refresh annuel | **MOYEN** — peupler `estv_oracle_2025.jsonl` avec les points calibrés + `expected_capture_date` (capture Playwright, gate Julien) |
| 5 | Grille lâche 150-250k (revenu) et >1M (capital) | Saut marginal jusqu'à **6,54 pts** au nœud (A3) ; extrapolation capital peu fiable (B6) | **MOYEN** — ajouter 1 colonne ESTV (revenu 200k ; capital 400k + 2M) ; divise ~par 2 l'erreur max |
| 6 | Marginal non-monotone VS/ZG/NW (barème concave ou point mal transcrit) | Marginal VS **−3,77 pts** de 150k à 250k (probe2 §3-4) | **MOYEN** — recouper VS 150k/250k vs points ESTV intermédiaires ; corriger le point OU documenter un barème réellement dégressif |
| 7 | Incertitude communale non chiffrée ; falaises de durée immo non remontées | Communal ~15-20% de la ligne ZH (D) ; GE 24→25 ans = −40 000 CHF sur 500k (C3) | **MOYEN** — bande d'incertitude communale + drapeau « proximité seuil de durée » |
| 8 | SO marié = célibataire +1 CHF (invariant cassé, toléré) | 1 CHF (négligeable) mais invariant rompu verrouillé par tolérance | **TRIVIAL** — inclus dans le clamp #2 |

## Top 3 (meilleur ratio valeur/effort)

1. **Interpoler l'IFD marié (5 points déjà collectés).** Effort FAIBLE, données prêtes dans `consolidated.json`.
   Supprime un biais **jusqu'à +13,6%** qui touche **tout retrait en capital marié**, pire sur les petits pots
   (la majorité). Meilleur ratio du lot.
2. **Post-condition `married ≤ single` + borne de pente d'extrapolation.** Une ligne. Élimine le croisement TI
   (**+23,8% à 2M**) et absorbe proprement le +1 CHF de SO. Corrige un verdict qualitativement faux.
3. **Tests de propriété sur le domaine continu (0 → 3M).** Effort FAIBLE-MOYEN, valeur élevée : aurait attrapé TI,
   SO et la non-monotonie VS **automatiquement**, et devient le filet mécanique du refresh annuel — exactement ce
   qu'un data scientist senior exige avant de faire confiance à une table calibrée.

## Ce qui est déjà de bon niveau (à ne pas dégrader)
- IFD calculé exactement par tranches (pas interpolé) — la moitié « fédérale » de chaque chiffre est exacte.
- Taux marginal = **dérivée** de l'étalon, jamais une table parallèle (le lint `no_cantonal_rate_table.py` +
  triage AnnAssign #1095 verrouillent ça) — élimine la classe de bug « 8 tables qui divergent ».
- Gains immobiliers ZH/VD/GE = barème exact + vecteurs officiels rejoués + verdict « inconnu » honnête hors
  périmètre. C'est le moteur le plus propre du lot.
- Clamp [0,0.50] jamais actif dans la plage plausible = garde-fou sain, pas un cache-misère.
