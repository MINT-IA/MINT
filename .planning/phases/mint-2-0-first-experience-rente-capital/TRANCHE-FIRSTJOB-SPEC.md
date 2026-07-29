---
description: "SPEC exécutable de la tranche verticale firstJob (Phase 1' du plan MINT-utilisable v2.1). Chaque exigence est testable. Base statique : dev@519975788 (registre 12D) + lecture worktree principal 2026-07-29. Intègre le verdict métier/lois mint-swiss-brain (2026-07-29) en §2.4 et la décision T2 actée (atterrissage par intention de persona). Le flow d'acceptation firstjob_tranche_acceptance_red.yaml est ROUGE par construction (boutons absents) : c'est le test AVANT code."
---

# SPEC — TRANCHE VERTICALE firstJob (Phase 1')

> Cadre : plan « MINT utilisable » v2.1, North star + Phase 1' + grille 12D +
> seuils go/no-go. Registre statique `REGISTRE-ECRANS-6D.md` (dev@519975788).
> Doctrine : 0-TRUST (§9 CLAUDE.md) — aucune affirmation « prêt/marche » sans
> citation `path:ligne` / sortie de commande / snapshot sim.
> Ce document SPECIFIE ; il ne CODE pas. Le code = Phase 2'.

## 0. Résumé exécutif (décisions clés)

| # | Décision | Ancrage repo |
|---|---|---|
| D1 | `/first-job` n'est PAS derrière un flag booléen : la route existe et n'est joignable que via le hub Explorer. Le lanceur de life event du dashboard est une **façade non montée**. « Activer le gate » = **monter le lanceur sur /home** + **ajouter un handoff coach**, pas basculer un flag. | `app.dart:1285-1287`, `app.dart:814`, `life_event_suggestions.dart:186` (0 appelant), `aujourdhui_screen.dart` (nav → `/coach/chat` seul) |
| D2 | Le net first-job est **L1 (mobile-canonical, offline)** : il reste dans `financial_core`/`FirstJobService`. La parité backend n'est PAS requise pour L1 (CLAUDE.md règle 4). Le défaut n'est pas « pas de backend », c'est un **calcul local qui contredit l'étalon dans le même écran**. | `first_job_service.dart` (importe `constants/social_insurance.dart`), `first_job_screen.dart:481-520` vs `:473-479` |
| D3 | `MoneyTruthReceipt` **n'existe pas** — à créer. Il **enveloppe** une valeur L1 avec sa provenance et réutilise l'infra existante (`compute_inputs_hash`, `ProjectionAuditRecord`, `L1ChiffrePayload`, `EnhancedConfidence`). Il est **persisté ET propagé** (dashboard ↔ coach ↔ logs). | `inputs_hash.py:58`, `projection_audit_record.py:69-71`, `_payload.py:100-113`, `confidence_scorer.dart:995` |
| D4 | Appareil de lucidité **absent sur l'output** : le gate d'ENTREE a déjà ses « pourquoi » (`firstJobGateWhySalaire/Age/Canton`), mais la valeur de SORTIE n'a ni confidence, ni bande d'incertitude, ni millésime. | `first_job_screen.dart:315,322,329` ; registre Lucid `défaut(0)` / Temps `RT(0)` ligne 110 |
| D5 | Deux entrées manquent dans le parcours cible, pas une : `/home → /first-job` ET `/first-job → /coach/chat`. | grep nav `first_job_screen.dart` = 0 `context.go` |
| T2 | **ACTÉE (2026-07-29)** — règle « **atterrissage par intention de persona** » : la bifurcation de fin d'onboarding atterrit sur la surface qui répond à l'intention déclarée. Persona **firstJob** (jeune actif ≤ 28) → **shell canonique `/home`** (le premier chiffre vit sur la carte life event + `/first-job`). Persona **rente-vs-capital** → la **decision room** `/retraite/rente-vs-capital` reste son atterrissage (salvage01 inchangé). Ni régression de salvage01, ni room imposée au persona firstJob. | §1 T2 ; salvage01 (`salvage01_retraite_onboarding_coach.yaml`) ; `REGISTRE-ECRANS-6D.md` |

---

## 1. Parcours cible + déclencheurs UI (exigence par transition)

Parcours (North star) : `landing (/)` → `onboarding (/onb)` → `aujourdhui (/home)`
→ `first-job (/first-job)` → `coach (/coach/chat)`.

| # | Transition | Déclencheur UI exact | État aujourd'hui | Exigence / câblage |
|---|---|---|---|---|
| T0 | app → `/` | cold launch, install neuf | OK — `landing_screen.dart` (`/`, 🟢) | Assert : landing rend « Parle à Mint ». |
| T1 | `/` → `/onb` | tap CTA « Parle à Mint » | OK — flux `/start`→`/onb` éprouvé (salvage01) | Le shell `/onb` (`onboarding_shell_screen.dart`, 🟢) est le **canonique** (registre §0 : ~10 variantes → 1 shell + 9 redirects `legacyRedirectHit`). Aucun re-design onboarding dans cette tranche. |
| T2 | `/onb` → `/home` | dernier pas d'onboarding (bifurcation) **flush dossier → `/home`** | Partiel — salvage01 route la bifurcation vers une *decision room* (`/retraite/rente-vs-capital`) | **Décision ACTÉE (§0 T2)** : atterrissage **par intention de persona**. Pour le persona firstJob (jeune actif ≤ 28), la bifurcation atterrit sur le **shell canonique `/home`** ; la decision room reste l'atterrissage du persona rente-vs-capital. Assert : `home_route_state` visible pour le persona firstJob. |
| **T3** | `/home` → `/first-job` | **tap carte life event « Premier emploi »** | **ABSENT (RED)** — `/home` (`aujourdhui_screen.dart`) ne monte aucun lanceur ; `LifeEventSuggestionsSection` (`life_event_suggestions.dart:186`) a **0 appelant** | **Câblage PR-D** : monter `LifeEventSuggestionsSection` dans le `CustomScrollView` de `aujourdhui_screen.dart` (slivers, région post-timeline ~`:249+`), alimenté depuis `CoachProfileProvider` (age/civilStatus/childrenCount/employmentStatus/monthlyNetIncome/canton). La carte firstJob existe déjà et gate sur `age <= 28` (`life_event_suggestions.dart:103-111`, `route: '/first-job'`). Exposer un noeud Semantics tappable `id: home-lifeevent-card-firstJob`. |
| **T5** | `/first-job` → `/coach/chat` | **tap CTA « Demander au coach »** | **ABSENT (RED)** — 0 `context.go`/`push` dans `first_job_screen.dart` | **Câblage PR-E** : ajouter le CTA `id: firstjob-ask-coach` près du premier éclairage (`first_job_screen.dart` ~`:471+`), `context.go('/coach/chat?...')` avec un `coachChatEntryPayload` portant `receiptId` + `inputsHash` (voir §4). Le coach résout le MEME receipt → MEME chiffre. |

### 1.1 Où le « gate » firstJob est codé (citation exacte pour la passation)

- Route déclarée : `apps/mobile/lib/app.dart:1285-1287` (`path: '/first-job'` → `FirstJobScreen`).
- Seule entrée existante : `apps/mobile/lib/app.dart:814` — `HubEntry(icon: Icons.school, label: 'Premier emploi', route: '/first-job')` dans le hub `/explore/travail` (onglet 3 Explorer, pas le dashboard).
- Lanceur dashboard **jamais monté** : `apps/mobile/lib/widgets/life_event_suggestions.dart:186` (`LifeEventSuggestionsSection`), carte firstJob `:103-111`. Preuve d'inactivité : `grep -rn "buildLifeEventSuggestions\|LifeEventSuggestionsSection" apps/mobile/lib` ne renvoie que le fichier lui-même (0 point de montage).
- `/home` ne surface AUCUN life event : `apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart` — toutes les navigations pointent `/coach/chat` (`:139,148,203`).
- **Il n'y a donc pas de `firstJobEnabled=false` à basculer.** « gated OFF » = façade non câblée. L'« activation » est une action de **câblage** (PR-D + PR-E), pas de configuration. (Le préfixe ARB `firstJobGate*` désigne le *data-gate de saisie* salaire/âge/canton, pas un feature flag — `app_localizations_fr.dart:3402-3423`.)

---

## 2. Défauts à corriger dans la tranche (chacun = critère d'acceptation)

### 2.1 Chiffres en dur / calcul local contredisant l'étalon (D2, dimension 2)

- **Médiane 6'500 en dur** — `first_job_screen.dart:1387` (`const median = 6500.0`, chip « Médian CH ») + défaut de graine `first_job_screen.dart:50` (`_salaire = 5000`).
  - **Verdict swiss-brain (§2.4.D)** : le 6'500 n'est ni la médiane OFS exacte, ni une médiane d'entrée sourcée — un rond non sourcé, non daté, mal labellisé. La médiane OFS/ESS du salaire brut mensuel (équivalent plein temps, tous secteurs) = **CHF 6'788** (ESS 2022, publiée 2024).
  - Cible du drain : **constante sourcée datée** `ofsSalaireMedianMensuelBrut = 6788` (`source: 'OFS ESS 2022'`, millésime visible) dans `constants/social_insurance.dart` ou un `constants/labor_market.dart` dédié, exposée par `FirstJobService`. La puce est **relabellisée « Médiane CH (tous secteurs) »** — elle ne doit pas laisser croire qu'il s'agit d'un salaire d'entrée. (Option écartée : médiane <30 ans par niveau de formation — pas de source OFS simple ; à revisiter si une source défendable émerge.) La médiane salariale n'est PAS une valeur fiscale (l'étalon ESTV = impôt) → elle vit comme constante datée, pas dans le comparateur fiscal. Le chip lit cette constante, jamais un littéral.
  - `_salaire = 5000` reste une **graine illustrative** (déjà badgée `firstJobIllustrativeBadge`, `:1374`) ; l'exigence est qu'elle soit remplacée par le profil dès qu'il porte `userProvidedFields('salary')` (déjà câblé, `_seedFromProfile` `:234-240`).
  - **Critère d'acceptation A1** : `grep -nE "[^0-9.][0-9]{3,}(\.[0-9])?" apps/mobile/lib/screens/first_job_screen.dart` ne renvoie aucun littéral numérique **user-facing** (bornes de slider min/max tolérées si non affichées). La médiane provient d'un symbole `FirstJobService.*`.

- **PayslipXRay nourri de ratios fabriqués** — `first_job_screen.dart:481-520` : `netSalary: _salaire * 0.76`, `employerHiddenCost: _salaire * 1.13`, `amount: _salaire * 0.053 / 0.08 / 0.09`. Ces ratios **dupliquent et contredisent** `_result!` (issu de `FirstJobService.analyzeSalary`, `:352`, étalon via `social_insurance.dart`), lui-même correctement injecté dans `SalaryBreakdownWidget` (`:473-479`). **Deux nets différents sur le MEME écran.** Verdict swiss-brain (§2.4.B) : le service calcule net ≈ 90 % (sans impôt source) — le 0.76 présuppose l'impôt à la source pour tous ; le 8 % LPP plat sur brut est fabriqué (art. 16 = 7 % TOTAL 25-34 ans, sur salaire coordonné) ; le 9 % impôt est arbitraire et **faux pour la persona par défaut** (Suisse, non imposée à la source).
  - Cible du drain (mapping swiss-brain §2.4.C) : alimenter `PayslipXRayWidget` depuis les champs de `_result!` — `:483 _salaire*0.76` → `_result!.netEstime` ; `:484 _salaire*1.13` → `_result!.cotisationsEmployeur` ; `:490 _salaire*0.053` → `_result!.avsAiApg` ; `:501 _salaire*0.08` → `_result!.lppEmploye` ; `:513 _salaire*0.09` (ligne impôt source) → **supprimée pour la persona par défaut** ou conditionnée à un flag « imposé·e à la source » (aucune constante canonique n'existe ; barème source = cantonal). Supprimer tout `_salaire * <ratio>`, y compris le fallback `:1276 _salaire*0.85` (troisième ratio net de la même page) → `_result!.netEstime`.
  - Copy associée : le narratif ARB `narrativeFirstJobBody` « net ≈ 75-80 % du brut » présuppose l'impôt source pour tous (persona défaut ≈ 88-90 %) → à corriger dans PR-G (avec re-traduction 6 ARB).
  - **Critère d'acceptation A2 (divergence intra-écran = 0)** : golden test — pour un `salaire` donné, la valeur nette rendue par `PayslipXRayWidget` == `_result!.netEstime` (byte-identity après arrondi). Un seul `id: firstjob-net-value` porte le net ; aucun second noeud net. `grep -n "_salaire \*" apps/mobile/lib/screens/first_job_screen.dart` = 0 occurrence à ratio financier.

### 2.2 Appareil de lucidité absent (D4, dimension 10 + 11)

- État : registre ligne 110 — Lucid `défaut(0)`, Temps `RT(0)`. L'output n'a ni confidence, ni bande, ni millésime. Le gate d'ENTREE a déjà ses « pourquoi » (`:315,322,329`).
- Exigence (PR-C) sur `/first-job`, autour de `_buildPremierEclairage()` (`:788`) :
  1. **Confidence** rendue via l'infra existante `EnhancedConfidence` (`confidence_scorer.dart:995`) — `id: firstjob-confidence-chip`. **Interdit de recréer** un scorer (règle 4 / NEVER #3).
  2. **Bande d'incertitude** sur le net (min/max) — `range` du receipt (§4).
  3. **« Pourquoi ce chiffre »** dépliable listant les hypothèses du receipt (`id: firstjob-why-net` → `firstjob-why-net-body`).
  4. **Millésime + source** visibles — `id: firstjob-source-vintage` (ex. « AVS 2026 · OFS ESS 2022 »).
  - **Critère d'acceptation A3** : le flow `firstjob_tranche_acceptance_red.yaml` §4c voit `firstjob-confidence-chip` + `firstjob-source-vintage` + `firstjob-why-net-body`. Test widget : l'écran chiffré ne rend jamais un net **sans** ces 4 éléments.

### 2.3 États vide / chargement / erreur-réseau (D4, dimension 4)

- État : registre ligne 110 — Log `·EV` (Erreur + Vide présents, **Loading absent**).
- Exigence (PR-F) :
  1. **Loading** : pendant la résolution du profil, indicateur (motif `aujourdhui_screen.dart:161-169`).
  2. **Gate incomplet** : si `_situationGate` incomplet, la carte de situation s'affiche à la place du chiffre (déjà l'intention, `:347-358`) — jamais un chiffre fabriqué. Assert : aucun « CHF » tant que le gate est incomplet.
  3. **Erreur-réseau / anti-critère** : le net first-job est **L1 offline** → il DOIT rester calculé staging coupé. Seul le handoff coach dégrade avec message nommé (`id: coach-offline-degradation`), jamais l'écran vide « Aucune donnée pour l'instant » (régression 2026-05-07).
  4. **Cohérence « premier » emploi** (signalement swiss-brain §2.4.F) : la checklist réutilisée (`JobChangeChecklist`) contient des items 1-2 qui supposent un employeur *précédent* (certificat LPP de l'employeur actuel, transfert de l'*ancien* avoir) — incohérent pour un *premier* emploi. PR-F conditionne ces items à `hasPreviousEmployer` (ou les reformule premier-emploi), sinon la justesse métier des refs légales affichées est compromise.
  - **Critère d'acceptation A4** : bloc ANTI du flow (build `MINT_E2E_STAGING=down`) — `/first-job` montre un « CHF », `/coach/chat` montre `coach-offline-degradation`, `assertNotVisible: "Aucune donnée pour l'instant"`.

### 2.4 Citations de lois et justesse métier (D6, dimension 6) — verdict mint-swiss-brain (2026-07-29, ACTÉ)

> Source : revue mint-swiss-brain livrée le 2026-07-29 (vérification Fedlex /
> ESTV / BSV / info-lpp, sources citées dans le rapport d'agent). Ce verdict
> REMPLACE la délégation « en cours » de la v1 de cette spec. PR-H implémente.

#### 2.4.A Verdict par citation de loi (8 refs à l'écran)

| # | Citation (path:ligne) | Verdict | Correction actée |
|---|---|---|---|
| 1 | `LAVS art. 5` — `first_job_screen.dart:495` (ligne payslip AVS/AI/APG 5.3 %) | **Imprécise** — LAVS art. 5 ne couvre que l'AVS (4.35 % part salarié) ; le 5.3 % agrège AVS + AI (LAI art. 3) 0.7 % + APG (LAPG art. 27) 0.25 %. Le chiffre est juste, la citation unique sous-attribue. | Reformuler : « LAVS art. 5 · LAI art. 3 · LAPG art. 27 ». |
| 2 | `LPP art. 16` — `:506` (ligne payslip LPP **8.0 %** du brut) | **Inexacte** — art. 16 pour 25-34 ans = **7 % TOTAL** (part salarié ≈ 3.5 %) sur le **salaire coordonné**, pas le brut. Le 8 % plat est fabriqué et sur-évalue. Le service, lui, calcule juste via `getLppBonificationRate`. | Drainer la ligne vers `_result!.lppEmploye` (PR-A) ; la citation art. 16 reste, adossée au calcul du service. |
| 3 | `LIFD art. 83` — `:518` (ligne payslip « Impôt à la source » **9.0 %**) | **Citation exacte, application imprécise** — art. 83 = imposition à la source des travailleurs étrangers sans permis C ; le 9 % plat est arbitraire ET la ligne s'affiche pour la persona par défaut (Suisse) qui n'est PAS imposée à la source → net faux pour le cas standard. | Supprimer la ligne pour la persona par défaut ou la conditionner à un flag « imposé·e à la source » (PR-A). |
| 4 | `LPP art. 3 — libre passage` — `:540` (checklist « Demande ton certificat LPP ») | **Inexacte** — le libre passage relève de la **LFLP** (RS 831.42), pas de LPP art. 3 (assujettissement de certains groupes). Droit à la prestation de sortie = LFLP art. 2. | → **`LFLP art. 2`**. |
| 5 | `OLP art. 3 — délai de transfert` — `:549` (checklist, deadline « 30 jours ») | **Inexacte** — OLP art. 3 = « transmission de données médicales », aucun rapport. Le transfert à l'institution supplétive = LFLP art. 4 al. 2 (6 mois-2 ans). Le « 30 jours » est aussi faux (pas de délai statutaire de 30 j). | → **`LFLP art. 4 al. 2`** + revoir le deadline affiché. |
| 6 | `LAMal art. 3` — `:557` (checklist « Informe ton assurance… couverture collective », deadline « 1 mois ») | **Inexacte** — art. 3 = obligation de s'assurer. Le passage collective → individuelle en fin de rapports de travail = LAMal art. 71 (ce qui rend le « 1 mois » cohérent avec art. 71, pas art. 3). | → **`LAMal art. 71`**. |
| 7 | `OPP3 art. 1` — `:563` (checklist « Continue tes versements 3a — déductions ») | **Imprécise** — art. 1 = formes reconnues ; la revendication porte sur la déduction fiscale = OPP3 art. 7. Priorité basse. | → **`OPP3 art. 7`**. |
| 8 | `'LAMal'` — `:1291` (token dans les exemples budget 50/30/20) | **N/A** — simple label compté par le grep du registre, pas une citation. | Aucune. |

- Services nourriciers : `first_job_service.dart:117` (`LAVS art. 3, 5`) et `:119` (`LPP art. 2, 7`) **exacts** ; backend `onboarding_service.py:18-22,97-104` (LAVS art. 5, LACI art. 3, LAA art. 91, LPP art. 2/7/8/16, OPP3 art. 7 al. 1, LAMal art. 61-65) **tous exacts**. Les citations inexactes n'existent QUE dans les `legalRef` en dur de l'écran.
- Chiffres registry vérifiés exacts 2026 (seuil LPP 22'680, coordination 26'460, salaire coordonné 3'780/64'260, assuré max 90'720, 3a 7'258, AC 148'200, bonifications 7/10/15/18, franchises 300→2'500, quote-part 700). Littéraux service à drainer vers constantes existantes : `_avsAiApgRate=0.053` → `avsCotisationSalarie` ; `700.0` → `lamalQuotePartMax` ; estimations LAMal (`380.0`, `0.06`, `0.017`) → constantes datées « estimation » (priminfo).

#### 2.4.B Frictions LSFin signalées (à corriger PR-G, verdict d2-juriste-lsfin non bloquant D6)

- Badge **« TOP »** sur la franchise 2500 (`firstJobTopBadge`, `:998`) + `noteLamal` (« la franchise 2500 est souvent plus avantageuse ») : bascule d'un scénario vers une recommandation → reformuler en comparaison neutre (« souvent choisie par… », « à comparer »).
- Backend `alerte_assurance_vie` **nomme des produits** (Finpension / VIAC / frankly) : recommandation nominative → reformuler en critère générique (« un compte 3a à frais bas »), aucun nom de produit.
- Aucun terme banni détecté dans la copy user (baseline lint = 0) ; verbes de lucidité présents (« À ENVISAGER », « Compare », « estimation »).

#### 2.4.C Critère d'acceptation A5 (mécanique, remplace le A5 v1)

1. `grep -n "LPP art. 3\|OLP art. 3\|LAMal art. 3'" apps/mobile/lib/screens/first_job_screen.dart` = 0 occurrence ; les refs `LFLP art. 2`, `LFLP art. 4 al. 2`, `LAMal art. 71`, `OPP3 art. 7` présentes sur les items de checklist correspondants.
2. La ligne payslip AVS porte la triple ref « LAVS art. 5 · LAI art. 3 · LAPG art. 27 ».
3. `grep -rn "Finpension\|VIAC\|frankly" services/backend/app/` = 0 dans la copy user-facing ; `firstJobTopBadge` supprimé ou reformulé sans superlatif.
4. Le verdict swiss-brain (ce §) est consigné Journey OS avant le vert Tier A.

### 2.5 i18n / accents / LSFin (D3, dimension 3)

- 6 strings FR en dur sur `/first-job` (registre ligne 110 : `défaut(6)`, dont les refs légales `:495-557`) + les nouveaux labels (CTA coach, chip confidence, source) + les corrections de copy §2.4 (narratif 75-80 %, badge TOP, refs légales corrigées).
- Exigence (PR-G) : toute string user-facing via `AppLocalizations`, 6 ARB, `flutter gen-l10n`, `validate_arb_parity()`. Accents 100 % FR (`tools/checks/accent_lint_fr.py`). Zéro terme banni LSFin.
  - **Critère d'acceptation A6** : `validate_arb_parity()` OK sur les 6 langues, `accent_lint_fr.py` exit 0, `check_banned_terms` = 0 sur le diff.

---

## 3. Flow Maestro cible — `tools/simulator/flows/firstjob_tranche_acceptance_red.yaml`

- **Rouge aujourd'hui par construction** : RED-1 (`home-lifeevent-card-firstJob` inexistante) et RED-2 (`firstjob-ask-coach` inexistant). C'est le test d'acceptation AVANT code. Il vire au vert quand PR-D + PR-E câblent les deux entrées ; PR-I retire alors le suffixe `_red` + le marqueur de skip.
- **Hors de tout runner vert par défaut, par construction** :
  - `maestro_sweep.sh` sélectionne ses flows par **listes explicites** (`FLOWS_E2E/REGRESSION/PERFECT/DEEPLINK`, `maestro_sweep.sh:63-107`) — ce flow n'y est PAS ajouté tant qu'il est rouge.
  - `mint2_quality_gate.sh` référence 3 flows nommés (`:18-20`) — pas celui-ci.
  - `maestro_locator_audit.py` scanne `flows/**/*.yaml` (`:443`) : le header du flow porte le marqueur `maestro_locator_audit: skip` (précédent : `flow_card_action_intent_bar.yaml:33`) car ses `id:` sont le CONTRAT à câbler, pas des locators existants. PR-D/E/C retirent le skip en câblant les ids.
- **Refuse le raccourci deeplink** de `travail_triad.yaml` : marche le parcours réel (le deeplink masquerait le défaut d'entrée).
- Locators **sémantiques** (text / `id:` d'arbre a11y), zéro pixel — les point-taps de `salvage01` sont un défaut D7 que la tranche corrige.
- Couvre : parcours complet T0→T5 + parité dashboard↔coach (§5c) + **anti-critère** (bloc ANTI, staging coupé → L1 offline survit, coach dégrade proprement).
- **Isolation du rouge (acté après revue Codex)** : un run RED n'est une preuve
  que s'il échoue **exclusivement** sur RED-1 (`home-lifeevent-card-firstJob`)
  ou RED-2 (`firstjob-ask-coach`). Un échec sur un pas d'onboarding `onb-*`
  (hors-tranche, fallback point-tap toléré) est un run INVALIDE à re-tenter,
  pas une preuve RED. Avant de citer un run RED comme évidence : (1) le
  segment T0→T2 doit avoir été prouvé vert au moins une fois (salvage01 ou
  fixture de seed firstJob déterministe — livrable harnais PR-D), (2) le JUnit
  doit montrer l'échec sur l'id RED annoncé, pas avant.

### 3.1 Contrat testIDs (livrable des PR de câblage)

| testID (id: arbre a11y) | Écran | PR | Existe ? |
|---|---|---|---|
| `home_route_state` | /home | PR-D | à ajouter |
| `home-lifeevent-card-firstJob` | /home | PR-D | à ajouter (RED-1) |
| `first_job_screen` | /first-job | PR-C | à ajouter (motif `rvc` `rente_vs_capital_screen`) |
| `firstjob-premier-eclairage-value` | /first-job | PR-A | à ajouter |
| `firstjob-net-value` | /first-job | PR-A | à ajouter (source unique du net) |
| `firstjob-confidence-chip` | /first-job | PR-C | à ajouter |
| `firstjob-source-vintage` | /first-job | PR-C | à ajouter |
| `firstjob-why-net` / `-body` | /first-job | PR-C | à ajouter |
| `firstjob-ask-coach` | /first-job | PR-E | à ajouter (RED-2) |
| `coach_chat_screen` | /coach/chat | — | à vérifier runtime |
| `coach-offline-degradation` | /coach/chat | PR-F | à ajouter |
| `onb-*` (choix onboarding) | /onb | hors-tranche | décision onboarding-canonique |

> Les `onb-*` sont listés pour rendre le flow sémantique de bout en bout, mais
> leur câblage relève de la **décision onboarding-canonique** (Phase 1', panel
> produit), PAS de cette tranche. Tant qu'ils ne sont pas exposés, le harnais
> tolère un fallback point-tap documenté sur ces pas SEULEMENT.

---

## 4. `MoneyTruthReceipt` v1 — schéma, emplacement, propagation, assertion

### 4.1 Schéma minimal mais complet

Champs (camelCase côté transport ; le backend Pydantic v2 sérialise camelCase) :

```
MoneyTruthReceipt v1
  claimId        : str      # id stable du claim, ex. "firstjob.net_salary.v1"
  receiptId      : str      # uuid unique par calcul
  inputs         : object   # inputs normalisés {salaireBrutMensuel, age, canton,
                            #                     tauxActivite, etatCivil}
  inputsHash     : str      # sha256 des inputs canonicalisés (reuse compute_inputs_hash)
  jurisdiction   : str      # "CH-<canton>", ex. "CH-VD"
  taxYear        : int      # millésime fiscal/référence, ex. 2026
  base           : enum     # {"brut","net"} — base de la valeur
  civilStatus    : str      # état civil (impacte barème)
  assumptions    : string[] # hypothèses éditables ("tauxActivite=100%", "3a plafond salarié", ...)
  engine         : str      # "financial_core.first_job_service" | id service backend
  engineVersion  : str      # constants_version_hash + app_version
  rounding       : str      # règle, ex. "CHF arrondi au 1" / "arrondi 5 CHF"
  sources        : object[] # [{id:"ofs_ess", label:"OFS ESS", vintage:2022}, {id:"avs", ...:2026}]
  value          : float    # LE chiffre
  range          : object?  # {low, high} bande d'incertitude — nullable en général,
                            # REQUIS pour claimId "firstjob.net_salary.v1" (A3 l'affiche)
  confidence     : object?  # résumé EnhancedConfidence {combined, axes} — nullable en
                            # général, REQUIS pour "firstjob.net_salary.v1" (A3)
  computedAt     : str      # iso8601
```

Contraintes de type (miroir de la doctrine `_payload.py`) : `extra=forbid`,
`frozen=True`, `value` et `range.low/high` `float`, `taxYear` `1900..2100`,
`sources` `min_length=1`, `base` littéral fermé. **Interdit** tout champ de
classement (`recommended*`, `best*`, `optimal*`) — cohérent NEVER #5 / LSFin.

Précisions actées après revue Codex (2026-07-29) :

- **`taxYear` = millésime des règles de cotisation appliquées** (ex. 2026).
  Les millésimes de statistiques (OFS ESS 2022) vivent dans `sources[].vintage`,
  jamais dans `taxYear` — pas de mélange fiscal/statistique.
- **`range` pour `firstjob.net_salary.v1`** : bande définie par les hypothèses
  non confirmées du gate (ex. taux d'activité, 13e salaire) — chaque borne est
  un recalcul du service avec l'hypothèse basse/haute, PAS un pourcentage
  arbitraire. La liste des hypothèses bornantes est figée dans PR-B et citée
  dans `assumptions`.
- **`confidence`** : mapping déclaré PR-B des champs `userProvidedFields` vers
  les 4 axes `EnhancedConfidence` existants (completeness×accuracy×freshness×
  understanding) — pas de nouvel axe, pas de nouveau scorer.
- **Canonicalisation du hash** : PR-B livre ≥10 fixtures JSON cross-language
  (mêmes inputs → même `inputsHash` attendu, octet pour octet) exécutées par
  pytest ET flutter test — c'est le test de parité Dart/Python du miroir.

### 4.2 Où il vit (backend canonical + miroir Dart)

- **Backend (modèle canonique du contrat)** : `services/backend/app/models/lucidity/money_truth_receipt.py` (NOUVEAU), même style que `_payload.py`. Le receipt **accompagne** un `L1ChiffrePayload` dans l'enveloppe `CoachToolOk.data` (le receipt = provenance de la valeur L1). Il ne remplace pas le discriminateur ; il l'enrichit.
- **Miroir Dart (émetteur L1)** : `apps/mobile/lib/services/financial_core/money_truth_receipt.dart` (NOUVEAU), classe immuable produite par `FirstJobService.analyzeSalary` **à côté** de `FirstJobResult` (nouvelle signature retournant `(FirstJobResult, MoneyTruthReceipt)` ou un `FirstJobResult` portant `receipt`). Sérialisation JSON **byte-alignée** sur le backend (mêmes clés camelCase).
- **Réutilisation obligatoire (pas de réinvention)** :
  - `inputsHash` ← `services/backend/app/services/coach/inputs_hash.py:58` `compute_inputs_hash` (miroir Dart identique sur les mêmes champs).
  - Persistance ← `ProjectionAuditRecord` (`projection_audit_record.py`) : mapping `inputsHash→scenario_inputs_hash`, `hash(value)→output_hash`, `engineVersion→constants_version_hash`+`app_version`, `source='mobile_l1'`, via l'endpoint existant `/v1/audit/mobile-session-*`.
  - `confidence` ← `EnhancedConfidence` (`confidence_scorer.dart:995`), pas de nouveau scorer.

### 4.3 Comment dashboard / coach / logs le portent

- **Dashboard (/first-job)** : `_buildPremierEclairage` lit `receipt.value` (net), `receipt.range` (bande), `receipt.sources`+`taxYear` (millésime), `receipt.confidence` (chip). Le net affiché **est** `receipt.value` — pas un recalcul.
- **Handoff coach** : le CTA `firstjob-ask-coach` passe `receiptId` + `inputsHash` dans le `coachChatEntryPayload` (query `/coach/chat?...`). Le coach **résout le même receipt** (via l'audit record persisté) et rend `receipt.value` — jamais un recalcul divergent.
- **Contrat store → resolve (acté après revue Codex, PR-B/PR-E)** — passer un
  `receiptId` en query ne suffit pas à le rendre résolvable ; le contrat est :
  1. **Écriture** (PR-B) : POST idempotent sur l'endpoint audit existant —
     clé d'idempotence = `inputsHash` + `receiptId` ; ré-émission = no-op.
  2. **Lecture** (PR-E) : résolution par `receiptId` **scopée au propriétaire**
     (même `hash_profile_id` / session anonyme) ; l'accès croisé renvoie
     not-found, jamais le receipt d'autrui — test pytest d'accès croisé requis.
  3. **Receipt pas encore synchronisé** (mobile offline → tap coach immédiat) :
     le payload d'entrée porte AUSSI les inputs normalisés ; le coach répond
     depuis le payload et marque le receipt `pending` — jamais d'erreur nue,
     jamais de recalcul avec d'autres inputs.
  4. **TTL** : durée de rétention alignée sur `ProjectionAuditRecord` (pas de
     nouveau régime) ; un receipt expiré = not-found propre + invite à
     recalculer sur `/first-job`.
- **Logs backend** : breadcrumbs non-PII portent `receiptId` + `inputsHash` (`hash_profile_id` pattern, `hashing.py`) ; aucune donnée financière en clair (D12, nLPD).

### 4.4 Assertion de bout en bout (« même chiffre »)

- Définition (plan) : même chiffre = mêmes inputs + même définition + même moteur ⇒ même résultat après arrondi. Un snapshot mensuel et une projection annuelle ONT le droit de différer.
- **Maestro** (boîte noire) : parité visible — le net copié sur `/first-job` (`firstjob-net-value`) apparaît à l'identique dans la réponse coach (flow §5c).
- **Golden / pytest** (déterministe) : pour un couple `inputs` donné, `receipt_dashboard.inputsHash == receipt_coach.inputsHash` ET `round(receipt_dashboard.value) == round(receipt_coach.value)`. Assertion **côté serveur** (harnais rejouant profil×question sur staging, capture du receipt brut) — pas seulement « une trace existe ».
  - **Critère d'acceptation A7 (divergence claims↔outputs = 0)** : la suite golden échoue si les deux `inputsHash` diffèrent ou si les valeurs arrondies divergent.

---

## 5. Seuils go/no-go → méthode de mesure concrète sur sim

Repris du plan Phase 1' (chiffrés AVANT baseline ; la baseline mesurée ne peut que RESSERRER, jamais relâcher sans décision écrite).

| Seuil | Valeur | Méthode de mesure (sim) |
|---|---|---|
| Taps jusqu'au premier chiffre | ≤ 12 | Compte des actions `tapOn` du flow de T0 à `firstjob-premier-eclairage-value` (onboarding compris). Compté dans le JUnit du flow. |
| Temps jusqu'au premier chiffre | ≤ 90 s | Horodatage `launchApp` → première visibilité de `firstjob-premier-eclairage-value` (budget déjà affirmé par `salvage01` header). Mesuré via `measure_cold_launch.sh` + timestamps Maestro. |
| p95 réponse coach | < 2,5 s hors LLM · < 10 s avec | Harnais pytest rejouant **N ≥ 30 tours** sur staging (1 tour de warm-up exclu de la stat), mesure p95 latence backend (hors LLM) + bout-en-bout (avec LLM). Pas mesurable dans Maestro seul. |
| Divergence claims↔outputs | 0 | A2 (intra-écran) + A7 (dashboard↔coach), golden. Un seul écart ⇒ no-go. |
| Crash-free du parcours | > 99,5 % | Sweep Maestro CORE **N = 20 runs consécutifs** (protocole PR-I ; 20/20 requis — au moins 1 crash sur 20 ⇒ sous le seuil) ; détecteur PNG-dupliqué sha256 = échec dur ; reboot sim avant sweep (mitigation crash iOS, memory). |

---

## 6. Découpage en PRs — Phase 2' (ordonné, 1 unité = 1 branche = 1 PR)

Règles : petites, atomiques, revertables ; design panel AVANT push d'écran ;
Codex/adversarial borné 330 s sur chaque diff ; 5 gates ; 1 périmètre à la fois.

| PR | Titre | Portée (1 unité) | Critère de sortie 12D partiel |
|---|---|---|---|
| **PR-A** | Drain calculs first-job | `PayslipXRayWidget` nourri de `_result!` (supprime `_salaire*0.76/1.13/0.053/0.08/0.09` + fallback `0.85`) ; ligne impôt source conditionnée ; médiane 6500 → `FirstJobService` const OFS ESS 2022 = 6'788 relabellisée ; `first_job_screen`/`firstjob-net-value` testIDs | **D2** vert : A1 (0 littéral user-facing) + A2 (divergence intra-écran = 0, golden) |
| **PR-B** | MoneyTruthReceipt v1 | modèle backend `money_truth_receipt.py` + miroir `money_truth_receipt.dart` + `FirstJobService` l'émet + persistance via audit endpoint (reuse `compute_inputs_hash` + `ProjectionAuditRecord`) | **D2 + D11** : receipt porte `sources`/`taxYear`/`inputsHash` ; golden asserte les champs ; ≥10 tests unit |
| **PR-C** | Appareil de lucidité first-job | `EnhancedConfidence` chip + bande d'incertitude (`receipt.range`) + « pourquoi ce chiffre » + `firstjob-source-vintage` | **D10 + D11** : A3 ; jamais de net sans les 4 éléments (test widget) |
| **PR-D** | Câblage /home → /first-job | monter `LifeEventSuggestionsSection` sur `aujourdhui_screen.dart` ; `home_route_state` + `home-lifeevent-card-firstJob` (noeud Semantics tappable) | **D1 + D7** : route joignable, back-nav, pas de dead-onTap ; tap sémantique sans point-tap (RED-1 → vert) |
| **PR-E** | Handoff coach porteur du receipt | CTA `firstjob-ask-coach` → `/coach/chat` avec `receiptId`+`inputsHash` ; le coach résout le même receipt | **D1 + D2** : A7 (parité dashboard↔coach, golden serveur) ; RED-2 → vert |
| **PR-F** | États + anti-critère réseau + cohérence checklist | Loading ajouté ; `coach-offline-degradation` ; L1 offline survit staging coupé ; items checklist « ancien employeur » conditionnés `hasPreviousEmployer` | **D4** : A4 (bloc ANTI vert, `assertNotVisible: "Aucune donnée pour l'instant"`) |
| **PR-G** | i18n / accents / LSFin | 6 strings en dur + nouveaux labels + copy corrigée (narratif 75-80 %, badge TOP neutre, produits nommés retirés) → ARB 6 langues, `gen-l10n`, parité, accents, termes bannis | **D3** : A6 (`validate_arb_parity` OK, `accent_lint_fr` exit 0, `check_banned_terms`=0) + A5.3 |
| **PR-H** | Corrections lois (verdict swiss-brain §2.4) | appliquer les corrections ACTÉES : `LFLP art. 2` (item libre passage), `LFLP art. 4 al. 2` (délai transfert, deadline revu), `LAMal art. 71` (collective→individuelle), `OPP3 art. 7` (déduction 3a), triple ref « LAVS art. 5 · LAI art. 3 · LAPG art. 27 » ; drainer `_avsAiApgRate`→`avsCotisationSalarie`, `700.0`→`lamalQuotePartMax` | **D6** : A5.1 + A5.2 + A5.4 (verdict consigné Journey OS) |
| **PR-I** | Flow CORE vert + Patrol câblé | `firstjob_tranche_acceptance_red.yaml` renommé (suffixe `_red` + skip locator retirés) passe VERT après A→H ; Patrol invariants câblés en CI (livrable, pas acquis) | **North star Tier A** vert sur sim (preuves citées) + **G2 device Julien** |

> Dépendances : PR-A précède PR-B (le receipt enveloppe la valeur drainée) ;
> PR-B précède PR-C/E (confidence + parité lisent le receipt) ; PR-D et PR-E
> sont les deux entrées RED ; PR-I clôt (dépend de A→H). PR-G et PR-H peuvent
> tourner en parallèle des autres (surfaces disjointes). PR-H et PR-A se
> partagent `first_job_screen.dart` : PR-A d'abord (le drain supprime les
> lignes payslip fabriquées que PR-H aurait sinon re-citées).
>
> Découpage fin (acté après revue Codex) : si le diff de **PR-B** dépasse la
> règle de taille dynamique, il se scinde dans cet ordre — B1 contrat +
> fixtures cross-language ; B2 émission mobile ; B3 store/resolve backend
> (contrat §4.3). Idem **PR-E** : E1 navigation + payload ; E2 résolution
> serveur + golden A7. Chaque sous-PR reste revertable seule.

---

## 7. Ce qui N'EST PAS dans cette tranche (anti-scope, Karpathy #2/#3)

- Pas de re-cartographie (réutiliser registre + ROUTE-MAP + JOURNEY-TRUTH-MATRIX).
- Pas de re-design onboarding (décision onboarding-canonique = pas séparé).
- Pas de backend income étalon pour le net first-job (L1 reste mobile-canonical ;
  la fixture de parité income du plan Phase 2' est une exigence **distincte**,
  pas un pré-requis de cette tranche).
- Pas de drain des 6 tables grandfathered (Phase 2' §Gap métier n°1, séparé).
- Pas d'estimation cantonale d'impôt à la source (la ligne payslip est
  supprimée/conditionnée, pas ré-implémentée — barème source = cantonal,
  hors périmètre L1 de cette tranche).
- Matrice archétype × event : firstJob×swiss_native est la tranche ; frontalier /
  independent_no_lpp / expat_us produisent « données manquantes : X » nommé
  (jamais un cul-de-sac muet), exercés une fois — pas approfondis ici.

---

## 8. Validation (Codex borné 330 s, 2026-07-29)

> **Note Codex : 8/10** — « excellente base d'implémentation », no-go Phase 2'
> tant que les 3 premiers manques ne sont pas fermés. Verdict intégral et
> intégrations ci-dessous (0-trust symétrique : chaque manque a une réponse
> tracée dans la spec ou un renvoi explicite).

| # | Manque relevé (gravité Codex) | Traitement dans cette spec |
|---|---|---|
| 1 | (Bloquant) Tranche non enregistrée dans le contexte canonique — `journey_os_check` rejetait le fichier hors whitelist | Fermé **dans la PR de filage** : entrées ALLOW ajoutées à `tools/checks/journey_os_check.py` pour la spec + le flow ; la consignation Journey OS du verdict lois reste exigée par **A5.4** avant le vert Tier A. |
| 2 | (Critique) « le coach résout le receipt » sans contrat de stockage/lecture (ownership, TTL, pending, idempotence) | Fermé : **§4.3 contrat store → resolve** (4 clauses : idempotence, scoping propriétaire + test d'accès croisé, cas `pending` non synchronisé, TTL aligné `ProjectionAuditRecord`). Porté par PR-B/PR-E. |
| 3 | (Critique) Le flow RED peut échouer avant RED-1/RED-2 (onboarding `onb-*` hors-tranche, fallback point-tap fragile) | Fermé : **§3 « Isolation du rouge »** — un run RED n'est une preuve que s'il échoue sur l'id RED annoncé ; T0→T2 prouvé vert avant citation ; fixture de seed firstJob = livrable harnais PR-D. |
| 4 | (Élevé) `range`/`confidence` nullables mais exigés par A3 ; pas d'algo de bande ; `taxYear` mélange fiscal/statistique ; pas de vecteurs de parité hash | Fermé : **§4.1 « Précisions actées »** — `range`+`confidence` REQUIS pour `firstjob.net_salary.v1`, bande = recalculs par hypothèses bornantes, `taxYear` = cotisations seulement (statistiques dans `sources[].vintage`), ≥10 fixtures JSON cross-language pytest+flutter. |
| 5 | (Élevé) PR-B/PR-E trop couplées ; `N` non défini pour p95/crash-free | Fermé partiellement (Karpathy #2, pas de sur-découpage a priori) : **§6 note de découpage fin** B1/B2/B3 + E1/E2 si la règle de taille le demande ; **§5** fixe N ≥ 30 tours (p95, warm-up exclu) et N = 20 runs consécutifs (crash-free). |

Caveat 0-TRUST : cette validation porte sur la SPEC (document), pas sur le
code — aucun des critères A1-A7 n'est vert aujourd'hui, et le flow
d'acceptation est ROUGE par construction. « Fermé » ci-dessus = « spécifié et
testable », jamais « implémenté ».
