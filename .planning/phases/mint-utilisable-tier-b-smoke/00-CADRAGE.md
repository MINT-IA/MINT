---
description: "Cadrage (PAS d'implémentation) de la tranche Tier B smoke du plan « MINT utilisable » v2.1 : les 18 life events, leur route d'entrée réelle, leur couverture Maestro actuelle (1 seul flow CORE seedé — firstJob ; 10 flows legacy deeplink non-gatés ; 5 events sans aucun flow), le critère smoke mécanique (sous-ensemble 5D de la grille 12D), 5 lots de 3-4 events ordonnés valeur × santé AX, les personas seedées disponibles (3 archétypes) et manquantes (cross_border/frontalier bloquant, retraité 65+), avec risques et angles morts."
---

# Tier B smoke — les 18 life events (cadrage)

Base : `.planning/architecture/2026-07-29-PLAN-MINT-UTILISABLE-v2.1.md` (Tiers A/B/C
+ grille écran 12D) et `.planning/audit-etat-des-lieux-2026-07/REGISTRE-ECRANS-12D.md`
(sha figé `dev@5199757` ; dev est maintenant `32d34bc6a` — le registre a vieilli :
la tranche firstJob a migré AppBar, l'AX pilote a touché les écrans du gate, ~15
wrappers racine + ~45 SliverAppBar hors-gate restent).

**Tier B (rappel du plan)** = smoke SANS cul-de-sac sur les 18 life events ×
l'onboarding canonique ; gate de NON-RÉGRESSION rejoué à chaque vague de ship
(Maestro CORE), pas « une fois ». Ce n'est pas le gate de release (c'est Tier A =
la tranche firstJob complète). Ce document cadre uniquement le grain, l'ordre et
les critères ; aucun flow n'est écrit ici.

Le SHA de cadrage : `dev@32d34bc6a28936c1b9794f064a4b23613a55e27d`.

## 1. Les 18 life events — route d'entrée réelle et couverture Maestro

Source enum : `apps/mobile/lib/models/age_band_policy.dart` (`LifeEventType`, 18
valeurs). Routes vérifiées avec builder réel dans `apps/mobile/lib/app.dart`
(`path: '...'`) — **les 18 ont un écran réel** ; le déficit est de couverture flow
+ persona + AX, pas de routing.

| # | Event (enum) | Catégorie | Route d'entrée (builder ✓) | Flow Maestro existant | Qualité du flow |
|---|---|---|---|---|---|
| 1 | `marriage` | Famille | `/mariage` | `famille_parcours.yaml` (racine) | legacy deeplink, non-CORE |
| 2 | `divorce` | Famille | `/divorce` | `famille_parcours.yaml` | legacy deeplink, non-CORE |
| 3 | `birth` | Famille | `/naissance` | `famille_parcours.yaml` | legacy deeplink, non-CORE |
| 4 | `concubinage` | Famille | `/concubinage` | `parcours_secondaires.yaml` (racine) | legacy deeplink, non-CORE |
| 5 | `deathOfRelative` | Famille | `/life-event/deces-proche` | **AUCUN** (exclu explicitement de `parcours_secondaires`) | — |
| 6 | `firstJob` | Professionnel | `/first-job` | `maestro-perfect-set/flow_firstjob_tranche_acceptance_seeded.yaml` | **CORE seedé, locators sémantiques, node-count prouvé** ✓✓ |
| 7 | `newJob` | Professionnel | `/simulator/job-comparison` | `travail_triad.yaml` (racine) | legacy deeplink, non-CORE |
| 8 | `selfEmployment` | Professionnel | `/segments/independant` | `perfect-set/flow_row23_independent_no_lpp_*` (×3, seedé) | perfect-set MAIS vise coach/budget, pas l'écran-event |
| 9 | `jobLoss` | Professionnel | `/unemployment` | `travail_triad.yaml` | legacy deeplink, non-CORE |
| 10 | `retirement` | Professionnel | `/retraite` | `salvage01_retraite_onboarding_coach.yaml` + `perfect-set/flow_mint2_first_experience_rente_capital_entry`, `flow_row17_rente_vs_capital_*` | mixte (1 racine + perfect-set rente/capital) |
| 11 | `housingPurchase` | Patrimoine | `/hypotheque` | `logement_succession_parcours.yaml` (racine) | legacy deeplink, non-CORE |
| 12 | `housingSale` | Patrimoine | `/life-event/housing-sale` | **AUCUN** | — |
| 13 | `inheritance` | Patrimoine | `/succession` | `logement_succession_parcours.yaml` | legacy deeplink, non-CORE |
| 14 | `donation` | Patrimoine | `/life-event/donation` | **AUCUN** | — |
| 15 | `disability` | Santé | `/invalidite` | **AUCUN** (exclu explicitement de `parcours_secondaires`) | — |
| 16 | `cantonMove` | Mobilité | `/life-event/demenagement-cantonal` | **AUCUN** (exclu explicitement) | — |
| 17 | `countryMove` | Mobilité | `/expatriation` | `parcours_secondaires.yaml` + `lauren_expat_us.yaml` / `perfect-set/flow_hardgate_expat_us.yaml` | legacy deeplink + perfect-set expat_us |
| 18 | `debtCrisis` | Crise | `/debt/ratio` (+ `/check/debt`, `/debt/help`, `/debt/repayment`, `/budget`) | `perfect-set/flow_b14_debt_intent_no_mortgage`, `flow_row23_budget_shortfall_runtime`, `flow_mon_argent_budget_setup_spine` | perfect-set MAIS surfaces budget adjacentes, pas l'écran-event |

### Synthèse de couverture

- **1 event** a un flow **Tier-B-grade** (CORE, seedé, locators sémantiques,
  assertion node-count) : `firstJob`. C'est l'étalon à copier.
- **10 events** n'ont qu'un flow **legacy deeplink racine** (`famille_parcours`,
  `logement_succession_parcours`, `travail_triad`, `parcours_secondaires`) :
  `mintapp:///` documenté **sim-instable** (SafariViewService crash sur sim
  long-bootée), seedé `swiss_native` UNIQUEMENT, **référencé par aucun tier de
  `maestro_sweep.sh`** → ne tourne en gate nulle part aujourd'hui. Les réutiliser
  tels quels = théâtre de test.
- **2 events** (`selfEmployment`, `debtCrisis`) ont des flows perfect-set seedés
  mais qui visent une surface adjacente (coach/budget), pas l'écran-event canonique.
- **5 events** n'ont **AUCUN** flow : `deathOfRelative`, `housingSale`, `donation`,
  `disability`, `cantonMove`. Les trois « life-event premium »
  (`deces-proche`, `demenagement-cantonal`, `invalidite`) sont explicitement
  exclus du header de `parcours_secondaires.yaml`.

Le vrai travail Tier B = **porter les 18 en flows seedés à locators sémantiques
depuis /home** (patron firstJob), les faire entrer dans un tier de sweep, avec
assertion node-count — pas « activer un flow existant ».

## 2. Critère smoke — sous-ensemble 5D de la grille 12D

La grille du plan a 12 dimensions. Le smoke n'en retient que le sous-ensemble
**mécaniquement vérifiable à runtime en boîte-noire** ; les 7 autres (D5 doublons,
D6 métier/lois, D8 perf, D9 design-system, D10 lucidité, D11 temps, D12 privacy)
restent aux gates Tier C / revue par écran, hors smoke.

| Gate | Dimension 12D | Critère | Seuil pass/fail mécanique |
|---|---|---|---|
| **C1 Atteignable** | D1 Route | route atteinte depuis `/home` avec persona seedée | Depuis le shell seedé (`/home`), taper la carte life event (`homeLifeEventCardIdentifier`) OU, si la persona ne la suggère pas, le deeplink canonique `mintapp:///<route>` → `assertVisible: id: <event>-anchor` sous 8 s. **FAIL** si l'ancre n'apparaît pas. |
| **C2 Non-vide + chiffré** | D2 Calculs / D4 Logique | rendu non-vide avec ≥1 chiffre calculé, jamais « Aucune donnée » | `assertVisible` sur ≥1 ancre-résultat chiffrée (ex. `firstjob-net-value`) **ET** `assertNotVisible` des sentinelles vides : `Aucune donnée`, `Aucune donnée pour l'instant`, `Définis ton budget`. **PASS** = ancre présente + sentinelle absente. |
| **C3 Zéro terme banni** | D3 Texte (LSFin) | aucun terme banni à l'écran | `assertNotVisible` (regex) des 7 termes bannis : `garanti\|optimal\|meilleur\|certain\|assuré\|sans risque\|parfait`. **FAIL** si l'un est visible. Miroir runtime de `check_banned_terms`. |
| **C4 Pas de cul-de-sac** | D1 / D4 | back + CTA fonctionnels | Back → `assertVisible` d'une ancre `/home` (retour sans crash) ; CTA primaire (coach / creuser) → `assertVisible` d'un écran cible non-erreur. **PASS** = les deux. |
| **C5 Arbre AX non effondré** | D7 A11y | arbre AX au repos non effondré (comptage `maestro hierarchy`) | Dump `maestro hierarchy` → compte de nœuds **au repos** ≥ seuil. Seuil = **plancher dur ≥ 25 nœuds** (un arbre effondré par wrapper racine SliverAppBar tombe bien en dessous) **puis baseline gelée par écran** au 1er vert (ex. firstJob : repos 53 → 58 après scroll) → seuil devient `max(25, 0.9 × baseline)`. |

**Verdict smoke d'un event** = C1 ∧ C2 ∧ C3 ∧ C4 verts. **C5 est un gate
DIAGNOSTIC, pas un bloqueur de ship** : les écrans à wrapper racine restant
échouent C5 par construction — **c'est le SIGNAL voulu** qui priorise les tranches
AX (dimension 7, propriété `ax-pilote`/`appbar-gate`). Chaque C5 rouge est consigné
Journey OS comme dette AX ordonnée, il ne barre pas le passage Tier B (gate de
non-régression), il alimente la file AX.

## 3. Lots — 3-4 events par PR de flows, ordonnés valeur × santé AX

`firstJob` n'est pas un lot : c'est le **patron** (build seedé + locators
sémantiques + ancre-résultat + assertion node-count) que chaque nouveau flow smoke
copie. Grain = 3-4 events/PR pour rester revert-able et gate-able (doctrine train de
fusion : 1 unité = 1 branche = 1 PR).

| Lot | Events | Valeur | Personas | Note AX / flow |
|---|---|---|---|---|
| **B1 — Famille** | `marriage`, `birth`, `divorce`, `concubinage` | haute (émotionnelle) ; legacy `famille_parcours`/`parcours_secondaires` à porter en seedé/sémantique | `julien_swiss` (swiss_native) ; `couple_acheteurs_lausanne` pour le couple | Écrans famille probablement SliverAppBar → C5 pilote la file AX |
| **B2 — Travail** | `newJob`, `jobLoss`, `selfEmployment`, `retirement` | haute ; seeds prêts (`independent_no_lpp` pour selfEmployment) ; `/retraite/rente-vs-capital` déjà migré AppBar | `julien_swiss`, `independent_no_lpp_income_reality`, + **retraité 65+ manquant** | rvc AX-sain = vert rapide ; vérifier que selfEmployment atteint `/segments/independant`, pas juste le coach |
| **B3 — Logement & Patrimoine** | `housingPurchase`, `inheritance`, `housingSale`, `donation` | haute (housing/impôts) | `couple_acheteurs_lausanne`, `cadre_40_55_lpp_rachat` | `housingSale` + `donation` = **création complète** (aucun flow aujourd'hui) |
| **B4 — Décès / Santé / Mobilité domestique** | `deathOfRelative`, `disability`, `cantonMove` | moyenne | `julien_swiss` | Cluster « life-event premium » AUCUN flow + exclu AX → **C5 rouge attendu = signal AX**, à faire après migration `ax-pilote` |
| **B5 — Crise & International** | `debtCrisis`, `countryMove` (+ couverture archétype cross_border) | moyenne-haute | `independent_no_lpp` (debt shortfall), `julien_expat_us` (expat), + **NOUVELLE seed cross_border/frontalier (bloquant)** | vérifier que debtCrisis atteint `/debt/ratio`, pas juste `/budget` |

**Ordre par défaut = B1 → B2 → B3 → B4 → B5** (valeur d'abord). **MAIS** avant de
figer l'exécution : tirer le map AppBar/SliverAppBar par écran-event depuis
`appbar-gate`/`ax-pilote` et **front-loader le lot dont les écrans sont déjà
migrés AppBar** (verts rapides, comme firstJob et rvc). Le registre 12D est au sha
`5199757` ; il ne reflète plus les migrations AX post-dev@32d34bc6a — ne pas
figer l'ordre sur lui.

## 4. Personas seedées — disponibles et manquantes

**Mécanisme de seed** (`apps/mobile/lib/services/coach/coach_profile_seeds.dart`
+ `apps/mobile/lib/providers/auth_provider.dart`) : build-time
`--dart-define=MINT_E2E_ARCHETYPE=<slug|seedKey>` + `MINT_E2E_PROOF_ANCHORS=true`,
**double-gardé `kReleaseMode`** (mort en release). Le build seedé boote directement
un shell guest navigable (`guestEmpty ⇒ allowsMainNavigation`) : les proofs sim
atteignent les écrans authentifiés sans dérouler l'onboarding. `forcedArchetypeSlug()`
résout d'abord `registry[slug]` (clé de seed), sinon `byArchetype(slug)` (alias
d'archétype). **Contrainte : 1 build = 1 seed** → chaque persona seedée = un tier
de sweep dédié (comme `fatca` et `firstjob` déjà séparés dans `maestro_sweep.sh`).

**Disponibles — 8 clés de seed :**

| Clé de seed | Âge | Canton | Archétype |
|---|---|---|---|
| `julien_swiss` | 36 | VD | swiss_native |
| `couple_acheteurs_lausanne` | 33 | VD | swiss_native |
| `jeune_diplome_zurich` | 25 | ZH | swiss_native |
| `cadre_40_55_lpp_rachat` | 48 | GE | swiss_native |
| `cadre_salarie_lpp_suisse_ready` | 33 | VS | swiss_native |
| `cadre_3a_contributing` | 42 | VD | swiss_native |
| `julien_expat_us` | 38 | GE | expat_us |
| `independent_no_lpp_income_reality` | 39 | VD | independent_no_lpp |

**Alias d'archétype (`byArchetype`, 3)** : `swiss_native`→`julien_swiss`,
`expat_us`→`julien_expat_us`, `independent_no_lpp`→`independent_no_lpp_income_reality`.
**Archétypes réellement couverts : 3** — swiss_native, expat_us, independent_no_lpp.

**Manquantes (à créer pour couvrir 18 × archétype) :**

1. **`cross_border` / frontalier — BLOQUANT.** La route `/segments/frontalier`
   existe et est deeplinkée dans `parcours_secondaires`, mais **aucune seed** :
   `byArchetype('cross_border')` = `null` (pas d'arm par défaut) → le build boote
   un shell navigable **sans profil** → **C2 échoue** (aucun chiffre). Le plan
   Phase 1' nomme explicitement `frontalier` pour Tier B smoke. À créer (Lot B5).
2. **Retraité 65+.** Aucune seed au-dessus de 48 ans → l'event `retirement`
   (`/retraite`) sur une persona active donne des projections, pas une rente en
   régime. Recommandé : seed âge 66+ (Lot B2).
3. *(optionnel)* **Famille avec enfant** — pour `birth` (allocations familiales)
   et le quotient familial du `marriage` ; `couple_acheteurs_lausanne` est un
   couple mais l'attribut « enfant » n'est pas garanti — à vérifier (Lot B1/B3).
4. *(optionnel)* **`expat_eu`** — archétype produit (Règle 7) mais **non requis**
   Tier B (seul `expat_us` l'est).

## 5. Risques et angles morts

- **Legacy ≠ Tier B.** Les 10 flows racine sont deeplink `mintapp:///`
  (sim-instables), seed `swiss_native` only, absents de tout tier de sweep, sans
  assertion node-count → ne satisfont ni « sans cul-de-sac » ni « AX non
  effondré ». Les garder = théâtre. Il faut les **réécrire** en seedé/sémantique.
- **C5 sans baseline gelée = bruit.** Un seuil universel unique casse (écrans
  riches vs pauvres). D'où plancher dur ≥ 25 + baseline gelée par écran au 1er vert.
- **Registre 12D périmé.** Sha `5199757` ; firstJob + rvc ont migré AppBar depuis.
  Le map AppBar/SliverAppBar par écran-event DOIT être re-tiré (`appbar-gate`/
  `ax-pilote`) avant de figer l'ordre des lots, sinon on met un lot AX-mort en
  tête et on perd le « vert rapide ».
- **Écran-event vs surface adjacente.** `selfEmployment` et `debtCrisis` : les
  flows perfect-set existants visent coach/budget, pas `/segments/independant` /
  `/debt/ratio`. Le smoke doit atteindre l'écran-event canonique.
- **Reachability profile-driven.** La carte life event de `/home`
  (`homeLifeEventSuggestions(profile)`) dépend du profil seedé : la persona d'un lot
  doit soit suggérer l'event visé, soit le smoke passe par le deeplink canonique
  (comme `travail_triad`). À décider flow par flow.
- **Coût build/CI.** 1 build = 1 seed → 5 lots × plusieurs personas = plusieurs
  tiers de sweep dédiés à budgéter (précédents `fatca`/`firstjob`).
- **`newJob` sans écran dédié** — mappé sur `/simulator/job-comparison` ; vérifier
  que c'est le canonique voulu ou s'il reste couvert par firstJob/onboarding.

### Contre-arguments

- *« Réutiliser les flows racine suffit pour Tier B. »* — Faux : ils ne tournent
  dans aucun tier, sont sim-fragiles, 0 couverture archétype, pas de node-count.
- *« Couvrir les 18 d'un coup. »* — Non : 1 build = 1 seed + design panel par
  écran + Codex par diff → le grain 3-4 events/PR reste revert-able et gate-able.

### Angles morts / trous de données (non résolus ici)

- Statut AppBar/SliverAppBar exact par écran-event (18) — dépendance
  `appbar-gate`/`ax-pilote`.
- Présence d'un attribut « enfant » dans les seeds famille — non vérifié en détail.
- Contenu chiffré réel rendu par écran-event sur staging (C2) — suppose backend
  staging à jour (`/api/v1/lucidity/receipts`) ; **non exécuté** (cadrage, pas de
  sim). 0-trust : ce document est un cadrage, aucune assertion « marche » n'y est
  faite.

## 6. Dépendances de séquencement

- **Tier A (firstJob) d'abord.** Le plan verrouille : rien ne ship sans Tier A
  vert ; Tier B se verrouille après. Ce cadrage prépare la tranche en parallèle,
  contre le harnais firstJob prouvé.
- **Sortie Tier B** = C1-C4 verts sur les 18 dans un tier de sweep dédié (nouveau
  `--tier tierb`, ou repli dans `default`/`all` une fois les seeds prêts) ; C5
  rouges consignés Journey OS comme file AX priorisée.
