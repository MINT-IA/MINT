---
description: "Inventaire du cluster 12D V2-2 « Segments risque » (expat / frontalier / invalidité ×3 / gender_gap). Écrans #1 (expat) + frontalier traités à fond dans la PR fix(segments) ; les 4 autres écrans inventoriés (écarts chiffrés D2/D3/D6/D5) + résiduels expat/frontalier documentés. Étalons backend cartographiés AVANT jugement (leçon V2-1)."
---

# Cluster 12D V2-2 — Segments à risque : inventaire

TLDR : `expat_screen` (#1 top-défauts) et `frontalier_screen` sont drainés à
fond dans la PR `fix(segments): cluster 12D V2-2` — le bloc Tab 2 expat (échéances
+ droits perdus, la dette LOT-3) passe en ARB ×6, le pourcentage de réduction AVS
devient **dérivé du registre** (fin du littéral nu ~2.3 % / −23 %), les libellés
de charges frontalier sont localisés, et les deux surfaces reçoivent une **bande
de confiance MintTrameConfiance** (D10) qui nomme les facteurs non modélisés
(barème A/B/C, quasi-résident, revenu annuel moyen). Le reste du cluster
(invalidité ×3 + gender_gap) et les résiduels expat/frontalier sont documentés
ici. **Leçon V2-1 appliquée** : l'étalon backend a été cartographié AVANT de juger
chaque calcul — la découverte structurante est que le calcul frontalier mobile
n'est **PAS** un miroir du backend (voir §Étalons).

## Étalons backend cartographiés (leçon V2-1 : chercher AVANT de juger)

| Domaine | Étalon backend | Miroir mobile ? | Verrou D2 correct |
|---|---|---|---|
| Expat / forfait / AVS gap | `services/backend/app/services/expat/expat_service.py` | `expat_service.dart` (partiel) | disclaimers + confiance (modèle éducatif) |
| Frontalier impôt source | `services/backend/app/services/expat/frontalier_service.py` | **NON — divergent** (cf. ci-dessous) | confiance + honnêteté du modèle, PAS parité |
| Invalidité (gap/insurance/self-emp) | `services/backend/app/services/disability_gap_service.py` | **NON appelé** (calcul inline) | drain vers service partagé + parité |
| Gender gap | `services/backend/app/services/gender_gap_service.py` | `GenderGapService` (`segments_service.dart`) — **miroir aligné** | déjà propre |

**Découverte structurante (frontalier)** : le commentaire de `expat_service.dart:40`
dit explicitement « Mobile source tax uses **simplified flat rates** per canton.
Backend frontalier_service.py uses **progressive brackets** with cantonal
multipliers … local service is for educational quick estimates only. TODO: wire
mobile to backend ». Donc `ExpatService.calculateSourceTax` (taux plat par canton)
et le backend (barèmes progressifs A/B/C) sont **intentionnellement divergents** —
une « fixture de parité » py↔dart échouerait *par conception*. Le verrou D2 correct
n'est pas la parité mais **l'honnêteté du modèle** (bande de confiance qui nomme le
barème réel non modélisé). NB : `journey_os_check.py` étiquette `expat_service.dart`
« miroir dart du calcul frontalier (parité py↔dart) » — **cette étiquette est
trompeuse** au vu du code ; à réconcilier (le calcul *charges sociales* est aligné,
le calcul *impôt source* ne l'est pas).

## Écrans traités À FOND (cette PR)

### `expat_screen.dart` (#1 top-défauts, score 37)

| Dimension | Avant | Après |
|---|---|---|
| **D3 Texte** | Bloc Tab 2 (3 `ExpatDeadline` + 5 `ExpatRight` + `destination`) codé FR en dur, avec un `lint-ignore: no_hardcoded_fr` explicite (LOT 3) sur le libellé LAMal | 25 chaînes → ARB ×6 (`expatDeadline*`, `expatRight*`, `expatDestinationAbroad`) ; **lint-ignore supprimé** |
| **D2 Calc** | `impact: '… réduit ta rente AVS de ~2.3%. 10 ans = −23% à vie.'` — littéral nu, divergent du service | `l.expatRightAvsImpact(perYear, tenYear)` où `perYear/tenYear` sont **dérivés** de `ExpatService.reductionPerMissingYear` (= 1 / `avs.full_contribution_years`) → même source que la carte de lacune AVS (Tab 3), plus aucun risque écran↔écran |
| **D6 Lois** | legalRefs inline (identifiants, locale-indépendants) | conservés comme données (non traduisibles) — non regardés par no_hardcoded_fr |
| **D10 Lucidité** | 0 appareil de confiance | `MintTrameConfiance.detail` sur la lacune AVS (Tab 3) — hypothèse `expatAvsConfidenceMessage` (modèle linéaire simplifié) |

### `frontalier_screen.dart` (post-#1115)

| Dimension | Avant | Après |
|---|---|---|
| **D3 Texte** | `_buildForeignChargeRows` affichait les clés techniques brutes (`vieillesse_base`, `krankenversicherung`, `csg_crds` → snake_case) ; `'LPP (est.)'` codé en dur | helper `_foreignChargeLabel` → 6 libellés de concept localisés (`frontalierCharge*`) ; `'LPP (est.)'` → ARB |
| **D2 Calc** | taux plat simplifié (divergent backend) sans qualification | inchangé (correct comme *modèle éducatif*), mais **honnêteté** ajoutée via D10 |
| **D10 Lucidité** | 0 appareil de confiance | `MintTrameConfiance.detail` sur l'impôt source (non-Tessin) — hypothèse `frontalierSourceTaxConfidenceMessage` : le barème prélevé dépend de la **situation familiale** (A/B/C) ; le **quasi-résident** est un mécanisme SÉPARÉ (taxation ordinaire ultérieure), pas une sélection de barème (correction Codex) |

**Métier (Codex borné)** : FATCA/expat_us = résident fiscal US → le retrait
3a/LPP au départ peut recevoir un **traitement fiscal / de reporting US distinct**
(selon le statut et le véhicule) ; à vérifier au cas par cas, pas un « exit event »
générique. Le service porte déjà un `usPersonWarning` (`expat_service.dart:698`,
formulé de façon catégorique — à assouplir) que l'écran ne surface pas encore
(résiduel). NB : le **WEP est abrogé** (Social Security Fairness Act) → ne PAS
présenter le WEP comme un risque actuel. Frontalier GE célibataire sans charge =
**barème A0** (≈ 11,31 % GE 2026), **pas C** (C = couple à deux revenus) — le modèle
plat + facteur marié ne distingue pas A/B/C, ce que la bande de confiance nomme
désormais ; le statut quasi-résident, lui, ouvre une taxation ordinaire ultérieure
(déductions) sans changer le barème prélevé.

## Écrans INVENTORIÉS (non traités — écarts chiffrés)

### `disability/disability_insurance_screen.dart` (score 27) — pire offenseur D3 du cluster
- **D3** : 9 littéraux FR user-facing (`disability_insurance_screen.dart:60-112`), ex. `'80% salaire — 720 jours (assurance collective)'` (:60), `'Rente ≈ 40% salaire coordonné (LPP art. 23)'` (:71). Pas de `lint-ignore`. Disclaimer/sources déjà localisés (:196-201).
- **D2** : naked `coordinated * 0.40 / 12` (:141, LPP invalidité 40 %), `* 0.7` (dépenses, :75/:125), table de franchise en dur (:149-156). Importe `social_insurance.dart` pour les *constantes* mais réinvente les *formules*.
- **D6** : `'LAMal art. 67-77'` (:94), `'LAI art. 28'` (:101), `'LPP art. 23-26'` (:108).
- **D5** : **ne calcule via AUCUN service** — diverge du backend `disability_gap_service.py` (plat 0.80 vs échelle cantonale employeur).

### `disability/disability_gap_screen.dart` (post-#1142) — le hub de duplication D5
- **D3** : 0 chaîne runtime FR (tout via `S.of(context)!.disabilityGap*`).
- **D2** : `_grossMonthly * 0.80` (:86/:89, backend a `IJM_COVERAGE_RATE=0.80`), `coordinated * 0.40 / 12` (:99), `* 1.5` facteur croissance auto-labellisé « approximation » (:150/:163), `* 0.5` (:155/:321), `65 - _age` (:142/:156).
- **D6** : `'LAMal art. 67-77'` (:205), `'LAI art. 28'` (:212), `'LPP art. 23-26'` (:219).
- **D5** : `0.40/12`, `_overallGrade`, échelle mois-de-réserve, `_fmtChf`, hypothèse `* 0.70` **dupliqués** avec `disability_insurance` — aucun module partagé malgré `social_insurance.dart` + backend `disability_gap_service.py`.

### `disability/disability_self_employed_screen.dart`
- **D3** : 0 chaîne FR (tout via `disabilitySelfEmployed*`).
- **D2** : `_monthlyRevenue * 0.70` (:63/:68), `* 3` « hypothèse 3 mois » (:69), défaut `8000` (:31).
- **D5** : `_fmtChf` dupliqué (3e copie) ; logique « indépendant = 0 CHF » réimplémentée visuellement (`DisabilityRedScreenWidget`) au lieu d'appeler `disability_gap_service.py` (branche self-employed).

### `gender_gap_screen.dart` — LE BON PATRON (propre D2/D3/D5/D6)
- **D3/D2/D5/D6 : CLEAN.** Tout passe par `GenderGapService` (`segments_service.dart`, `projectedReturn=0.015`, `dureeRetraiteAnnees=20`), qui **miroite** le backend `gender_gap_service.py`. Aucun littéral nu, aucune duplication, refs légales via `rec.source`. Le seul `lint-ignore` (:355) est `prefer_mint_text_style`, pas `no_hardcoded_fr`. **C'est le modèle à répliquer pour les 3 écrans invalidité.**

## Doublon D5 « C5-disability à 3 têtes » — verdict

Les 3 écrans invalidité partagent la même formule LPP-invalidité (`coordinated *
0.40 / 12`), le même scorer `_overallGrade`, la même échelle mois-de-réserve et 3
copies de `_fmtChf`, **sans module partagé**, et **divergent du backend**
`disability_gap_service.py` (plat 0.80 vs échelle cantonale). **Action recommandée
(unité future dédiée)** : extraire un service invalidité mobile unique (patron
`GenderGapService`) drainé/miroir de `disability_gap_service.py`, poser une fixture
de parité, puis re-câbler les 3 écrans. Le gate de non-régression = un smoke seedé
invalidité (à créer — aucune persona invalidité seedée n'existe aujourd'hui).

## Résiduels expat / frontalier (dette documentée, hors périmètre de cette PR)

1. **i18n service-side expat** : `ExpatService.disclaimer`, `planDeparture` (titres
   /sous-titres de checklist), `estimateAvsGap`/`checkQuasiResident`/`simulate90DayRule`
   (recommandations) restent en FR codé dur côté service (grandfathered, non
   ajoutés → no_hardcoded_fr `--added-only` vert). Draîner exige de restructurer le
   service pour retourner des clés (ou résoudre à l'écran) — unité séparée.
2. **`usPersonWarning` non surfacé** : le service porte l'avertissement FATCA
   (`expat_service.dart:698`) mais `_buildDepartChecklist` (expat_screen) ne l'affiche
   pas. Le libellé service est catégorique (« exit event IRS ») → à reformuler en
   « traitement fiscal/reporting US potentiellement distinct, à vérifier selon statut
   et véhicule » AVANT de le surfacer pour la persona `expat_us` (valeur métier élevée,
   unité dédiée ; nécessite que l'écran connaisse le statut US-person via l'archétype).
3. **Étiquette journey_os trompeuse** : `expat_service.dart` est marqué « parité
   py↔dart » alors que l'impôt source diverge par conception — corriger le commentaire.
4. **Wire-to-backend frontalier** : le TODO `expat_service.dart:44` (câbler l'impôt
   source au backend progressif) reste ouvert — la bande de confiance est le
   garde-fou honnête en attendant.

## Preuve (0-trust)

- Tests : `expat_v22_i18n_test.dart` (3 : Tab 2 localisé + AVS dérivé + bande MTC),
  `frontalier_v22_test.dart` (2 : bande MTC source + libellés charges localisés) —
  5/5 verts. Non-régression : `expat_gate_test.dart` 42/42, suites countdown/rights/
  service/persona verts.
- `flutter analyze` : clean. Gates : `arb_parity` (6 langues, 7264 clés),
  `banned_terms_arb`, `no_hardcoded_fr --added-only`, `accent_lint --added-only`,
  `no_legacy_confidence_render`, `no_implicit_bloom_strategy`, `journey_os_check` —
  tous exit 0.
- Générés l10n : diff **100 % additif** (909 insertions, 0 suppression — reflow
  dartfmt évité par graft).
