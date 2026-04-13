# MINT Plan d'Exécution — Sprint d'Intégration 2-3 Semaines

> **Statut** : Plan d'exécution exécutable lundi matin, hour-by-hour sur la première semaine.
> **Auteur** : Office-hours co-design avec Julien (2026-04-11)
> **Subordonné à** : `10-MANIFESTO.md` (vision), `11-INVENTAIRE.md` (verdicts par écran)
> **Subordonné par** : Aucun. C'est le bottom du stack — il s'exécute.
> **Read time** : 15 minutes
> **Purpose** : Julien lit ce document une fois et démarre le sprint sans ambiguïté.

---

## 1. Le constat qui change tout

Le plan d'exécution traditionnel d'une refonte mobile assume qu'on construit du code nouveau. **MINT n'est pas dans cette situation.** Le manifesto et l'inventaire ont établi que :

- **Les 21 modules de la boucle Cleo 3.0 (Insight → Plan → Conversation → Action → Memory) existent déjà en code MINT** (vérifié dans le dossier `apps/mobile/lib/services/` et `services/backend/app/services/`)
- **Les 6 pillars de l'architecture cible existent déjà comme écrans** (landing_screen, document_scan, document_impact, documents_screen, coach_chat_screen, profile/settings)
- **44% des écrans (KEEP+REFACTOR) gardent leur logique** ; 17% sont fusionnés en canvas unifiés ; 23% sont gelés ; 16% supprimés

**Conséquence** : ce sprint n'est PAS un sprint de construction. C'est un **sprint d'intégration et de visibilité**. Il câble les composants existants en boucle visible, expose les services backend comme coach tools, splitte les god-screens en composants réutilisables, et supprime ce qui contredit la doctrine.

**C'est pour ça que le sprint tient en 2-3 semaines au lieu des 4-6 d'une refonte from-scratch.** Câbler du code qui marche déjà est qualitativement différent de construire du code nouveau.

---

## 2. Vue d'ensemble du sprint

### Phases

```
Semaine 0 (préliminaire, 2-3 jours)
  ├── Validation manifesto + inventaire avec Julien
  ├── Lecture des god-screens prioritaires (preparation)
  ├── Setup analytics (Plausible ou audit_service wiring)
  └── 3-5 user tests sur build actuelle (pour baseline qualitative)

Semaine 1 (Sprint A — Stabilisation)
  ├── Jour 1-2 : Phase 1 du nav roadmap (LOOP-01, MintNav, redirects, BudgetContainer kill)
  ├── Jour 3 : Ship TestFlight clean, walkthrough creator
  ├── Jour 4-5 : Premier delete-batch (les 7 unanimous-kill du nav roadmap)
  └── Gate 1 : creator walkthrough cold-start fonctionne en 4 minutes sans bug

Semaine 2 (Sprint B — Consolidation)
  ├── Jour 6-7 : Refactor des god-screens prioritaires (documents_screen → My Dossier)
  ├── Jour 8-9 : MERGE famille mortgage (5 → 1 canvas Logement)
  ├── Jour 10 : MERGE famille 3a (4 → 1 canvas) + MERGE famille disability (3 → 1 canvas)
  └── Gate 2 : 3 canvases unifiés shippés, services backend exposés comme coach tools

Semaine 3 (Sprint C — Voix & Loop visible)
  ├── Jour 11-12 : Câblage de la boucle Cleo 3.0 visible (CAP engine + nudges + anticipation triggers exposés sur Aujourd'hui surface)
  ├── Jour 13 : Polish des 6 pillars + voice review sur tous les copy
  ├── Jour 14 : Anti-patterns CI guards en place (du nav roadmap Section 7)
  ├── Jour 15 : Ship final TestFlight + walkthrough complet + recrutement alpha testers
  └── Gate 3 : Boucle Insight → Plan → Conversation → Action → Memory visible end-to-end ; 3-5 alphas externes peuvent compléter le walkthrough sans aide
```

### Effort estimé

- **CC effort** : ~10-15 jours sur 3 semaines (avec parallélisation entre composants indépendants)
- **Human-in-loop** : ~25-30h sur 3 semaines (validation, tests, copy review, decisions)
- **Calendrier** : 3 semaines réelles (15 jours ouvrés) en mode focus

C'est **plus rapide** que le plan d'origine (3-5 semaines) parce que la dette est d'intégration, pas de construction. Et c'est **plus rapide** que le navigation roadmap seul (qui s'arrêtait à Phase 1+2) parce qu'on enchaîne directement sur les MERGE et la boucle visible sans gate intermédiaire de mesure.

---

## 3. Semaine 0 — Préparation (2-3 jours, hors sprint)

Avant le démarrage du sprint A le lundi de la semaine 1, ces choses doivent être faites :

### J0-1 : Validation des 3 livrables (1-2 heures)
- ☐ Julien lit `10-MANIFESTO.md` (10 min)
- ☐ Julien lit `11-INVENTAIRE.md` Section 1+2+3.1 (10 min) puis scan des autres sections (10 min)
- ☐ Julien lit `12-PLAN-EXECUTION.md` (15 min) — ce document
- ☐ Decision : GO / corrections / pause
- ☐ Si GO : sign-off explicite (commit `.planning/architecture/SIGN-OFF.md` avec date)

### J0-2 : Installation analytics (2-4 heures)
- ☐ Decision : Plausible (recommandé) vs `audit_service.py` wiring
- ☐ Si Plausible : créer compte, ajouter snippet web, ajouter route observer mobile
- ☐ Si audit_service : ajouter middleware FastAPI pour `/analytics/route_visit`, wirer côté Flutter
- ☐ Définir les 5 events critiques (route_visit, route_error, chat_message_sent, back_button_pressed, session_start)
- ☐ Deploy
- ☐ Vérifier que les events arrivent (1 heure d'attente max)

### J0-3 : 3-5 user tests sur build actuelle (3-5 heures)
**Pourquoi** : capturer une baseline qualitative avant le sprint pour mesurer l'amélioration, et vérifier qu'on n'a pas raté un bug fatal qu'on devrait fixer en priorité.
- ☐ Recruter 3-5 testeurs Suisses (1 Romand 25-35, 1 Romand 45-55, 1 Alémanique 30-40, 1 Tessinois si possible, 1 expat)
- ☐ Test scénario : "Tu télécharges MINT pour la première fois. Essaie de comprendre ce que c'est et fais quelque chose d'utile en 5 minutes."
- ☐ Observer (Zoom, en personne, ou enregistrement écran avec consentement). NE PAS AIDER.
- ☐ Noter verbatim chaque blocage, chaque "qu'est-ce que je dois faire ?", chaque "ah là je vois pas".
- ☐ Demander à la fin : "Si je te disais que MINT est un Cleo suisse + VZ démocratisé, ça te parle ?"
- ☐ Sauvegarder les notes dans `.planning/architecture/baseline-tests.md`

### J0-4 : Lecture des god-screens prioritaires (2 heures)
**Pourquoi** : avant de splitter, comprendre. Le sub-agent batch-2 a noté que `BudgetScreen` (1065 LOC) n'avait pas été lu en profondeur dans le navigation roadmap. À faire avant sprint.
- ☐ Lire `screens/budget/budget_container_screen.dart` (79 LOC) — confirmer LOOP-01
- ☐ Lire `screens/budget/budget_screen.dart` (1065 LOC) — décider : refactor sur dossier ou bottom-sheet collector ?
- ☐ Lire `screens/documents_screen.dart` (1464 LOC) — identifier les 4-5 zones (vault, paywall, upload sheet, empty states)
- ☐ Lire `screens/document_scan/document_scan_screen.dart` (1484 LOC) — identifier les 5 sections (camera, picker, OCR adapter, parser dispatch, review transition)
- ☐ Lire `screens/coach/retirement_dashboard_screen.dart` (1374 LOC) — identifier ce qui peut devenir des cards réutilisables
- ☐ Sauvegarder un mini-mapping en JSON : `{screen: ., zones: [...], reusable_components: [...]}`

### J0-5 : Setup branche de travail (30 min)
- ☐ `git checkout -b feature/architecture-v2` depuis `dev`
- ☐ Vérifier que `flutter test` et `pytest` passent à 100% sur la branche de départ
- ☐ Vérifier `flutter analyze` à 0 erreurs
- ☐ Snapshot des routes : `grep -rE "GoRoute\(" apps/mobile/lib/app.dart > .planning/architecture/routes-baseline.txt`

**Total Semaine 0 : ~1.5 jours de travail réparti sur 2-3 jours calendaires.**

---

## 4. Semaine 1 — Sprint A : Stabilisation

**Goal** : la mobile devient navigable. Le créateur peut faire un walkthrough cold-start sans rencontrer un bug bloquant. La fondation technique est posée pour les sprints B et C.

### Jour 1 (Lundi) — Hour-by-hour

**Hour 1 (09:00-10:00) — Lecture finale + decisions**
- Re-lire `10-MANIFESTO.md` Section 7 (les 6 écrans cible) pour avoir l'architecture en tête
- Re-lire `11-INVENTAIRE.md` Section 6 (les gates pre-sprint)
- Confirmer les decisions de routing (`MintNav`, `preserveQueryRedirect`)
- Ouvrir `apps/mobile/lib/app.dart` et identifier les 40 redirects à patcher

**Hour 2-4 (10:00-13:00) — Phase 1 nav roadmap step 1-3**
- Créer `apps/mobile/lib/services/navigation/mint_nav.dart` avec `MintNav.back(fallback:)`, `closeWithResult`, `open`, `resetToHome`, `resetToRoot`, `replaceWith` (paste depuis nav roadmap §B)
- Créer `apps/mobile/lib/router/preserving_redirect.dart` (5 lignes)
- Edit `apps/mobile/lib/services/navigation/safe_pop.dart` : delegate à `MintNav.back(context, fallback: '/coach/chat')`, mark `@Deprecated`
- Run `flutter analyze` → expect lint warnings sur les 21 call sites de safePop, pas d'erreur
- Commit : `feat(nav): introduce MintNav + preserveQueryRedirect + deprecate safePop`

**Hour 5 (14:00-15:00) — Lunch + decisions**
- Confirmer la decision sur `BudgetScreen` (refactor ou bottom-sheet collector)
- Confirmer l'ordre de delete des 6 unanimous-kill (achievements, cantonal_benchmark, ask_mint, score_reveal, portfolio, retirement_dashboard) — gate sur evidence Plausible si dispo
- Vérifier que `claude_coach_service.py` ne référence aucun de ces 6 screens dans ses prompts/tools (`grep -r "/achievements\|/cantonal-benchmark\|/ask-mint\|/score-reveal\|/portfolio\|/retraite" services/backend/`)

**Hour 6-8 (15:00-18:00) — Phase 1 nav roadmap step 4-5**
- Patch les 40 redirects de `app.dart` lines ~229-930 : remplacer `redirect: (_, __) => '/coach/chat'` par `redirect: preserveQueryRedirect('/coach/chat')`
- Vérifier mécaniquement que les redirects critiques sont corrects : `/home`, `/explore/*`, `/onboarding/enrichment`, `/advisor/*`
- Delete `apps/mobile/lib/screens/budget/budget_container_screen.dart` (LOOP-01 fix)
- Route `/budget` → `BudgetScreen` (si decision Hour 5 = refactor) OU bottom-sheet inline collector
- Run `flutter test` → expect 0 regressions (les widget tests qui mockaient `safePop` peuvent tomber, à fixer)
- Commit : `fix(nav): patch redirects + LOOP-01 + budget facade kill`

**Fin J1 : MintNav en place, redirects clean, BudgetContainer mort. Mobile commence à respirer.**

### Jour 2 (Mardi)

**Hour 1-3 (09:00-12:00) — Smoke test + ship TestFlight**
- Run complet `flutter test` + `pytest tests/ -q` + `flutter analyze`
- Manual smoke test sur device iOS réel : ouvrir l'app, login, naviguer vers Budget, vérifier que la loop est morte, naviguer vers chat, vérifier que back fonctionne, deep link vers `/achievements` → redirige vers chat
- Si bugs trouvés : fix et re-test
- Build TestFlight + upload
- Tag `git tag v2.4-sprint-a-day-1`

**Hour 4 (13:00-14:00) — Walkthrough creator (sur la nouvelle build)**
- Installer la nouvelle build sur l'iPhone du founder
- Faire un cold-start walkthrough : ouvrir → login → première interaction → navigation entre 5 écrans → upload d'un document (n'importe quel) → résultat → retour chat → close
- Noter chaque friction restante
- **GATE 1A** : si le walkthrough produit < 3 frictions et 0 bug bloquant, GO pour la suite. Sinon, fix les blocages avant Hour 5.

**Hour 5-8 (14:00-18:00) — Premier delete batch (gated sur Plausible si possible, sinon doctrine pure)**
- Si Plausible a 24h+ de data : kill les screens unanimous-kill avec MAU < 2%
- Si pas de data : kill les 6 doctrinally-indefensible (achievements, score_reveal, ask_mint, cockpit_detail, annual_refresh, portfolio) **après vérification que claude_coach_service.py n'y fait pas référence**
- Pour chaque delete : `git rm screens/X.dart`, supprimer route dans `app.dart`, ajouter redirect `preserveQueryRedirect('/coach/chat?prompt=...')` si pertinent, run `flutter test`
- Commit individuel par delete : `chore(screens): delete X (anti-shame doctrine)` etc.
- Ship TestFlight

**Fin J2 : 6 screens disparus, mobile plus propre, walkthrough fonctionne.**

### Jour 3 (Mercredi)

**Hour 1-3 (09:00-12:00) — Anti-patterns CI guards (du nav roadmap §7)**
- Créer `tools/checks/no_raw_go_router.sh` (AP-3)
- Créer `tools/checks/no_root_nav_key_in_shell.sh` (AP-4)
- Créer `tools/checks/no_shame_copy.sh` (AP-6)
- Wirer dans `.github/workflows/ci.yml`
- Run sur la branche actuelle → expect quelques violations dans les screens FREEZE/REFACTOR (pas sur les KEEP)
- Commit : `chore(ci): add anti-pattern guards from nav roadmap`

**Hour 4 (13:00-14:00) — Vérification compliance**
- Audit `provider_comparator_screen.dart` : décision finale REFACTOR ou DELETE
- Si REFACTOR : créer ticket pour Sprint B
- Audit `cantonal_benchmark_screen.dart` : confirmer FREEZE permanent ou refactor
- Vérifier que tous les services backend FREEZE ont une note pour exposition coach tools

**Hour 5-8 (14:00-18:00) — Splash screen + Document Upload pillar polish**
- Vérifier que `landing_screen.dart` est à 100% conforme au manifesto Section 7.1 (Welcome)
- Vérifier le ton, la tagline verbatim, le sous-titre, le CTA unique
- Lecture critique de `document_scan_screen.dart` (1484 LOC) → identifier les 5 sections à extraire
- Premier extract : OCR adapter en service séparé (`services/document_scan/ocr_adapter.dart`)
- Run tests, commit

**Fin J3 : CI guards en place, splash + landing parfaits, document_scan en cours de split.**

### Jour 4 (Jeudi)

**Hour 1-4 (09:00-13:00) — Document Upload pillar finalization**
- Continuer le split de `document_scan_screen.dart` :
  - File picker adapter (composant)
  - Parser dispatch (composant)
  - Review transition (composant)
- Réduire `document_scan_screen.dart` de 1484 → ~400 LOC en orchestrant les composants
- Élargir le DocumentType supporté (le manifesto demande LPP, 3a, fiscal, AVS, hypothèque, contrats assurance, bank statements — vérifier que les parsers existent côté backend pour chaque)
- Run tests, commit

**Hour 5-8 (14:00-18:00) — Document Result pillar polish**
- `document_impact_screen.dart` : vérifier qu'il implémente les 4 couches verbatim selon manifesto Section 7.3
- Polish copy avec voice MINT
- Vérifier les fallback states (parser failure, compliance guard intercept)
- Wirer le bouton "Sauvegarde dans mon dossier" (Apple Sign In si pas connecté)
- Wirer le bouton "Pose une question à MINT sur ce document" (chat avec contexte forcé)
- Run tests, commit

**Fin J4 : Pillar 2 et Pillar 3 sont prêts. Le flow upload → parse → résultat → save fonctionne end-to-end.**

### Jour 5 (Vendredi)

**Hour 1-4 (09:00-13:00) — Auth flow polish + post-auth routing**
- Vérifier les 4 auth screens (login, register, forgot, verify)
- Adjust post-auth routing : new user → Document Upload directement (pas Coach Chat, pas onboarding form)
- Existing user → My Dossier (pas Chat, sauf si dernier message > 24h)
- Profile/Settings : vérifier que tous les KEEP screens (about, byok, slm, langue, privacy, household) sont accessibles via Profile menu
- Cleanup des routes orphelines

**Hour 5 (14:00-15:00) — Walkthrough creator complet (cold-start)**
- Désinstaller et réinstaller MINT sur l'iPhone du founder
- Cold start → splash → login (Apple) → upload document (LPP cert) → résultat 4 couches → save → My Dossier → Coach Chat → poser une question → close
- Mesurer le temps total (target : < 5 minutes)
- Noter chaque friction restante
- **GATE 1B (Sprint A exit gate)** : walkthrough complet en < 5 min, 0 bug bloquant, 0 cul-de-sac

**Hour 6-8 (15:00-18:00) — Ship Sprint A + recrutement alpha testers**
- Build TestFlight v2.4-sprint-a
- Note de release : "MINT a été redessiné autour de la rencontre avec ton dossier vivant. Voilà ce qui change..."
- Tag `git tag v2.4-sprint-a-final`
- Recruter 3-5 alpha testeurs pour le Sprint B (les mêmes que J0-3 idéalement, ou nouveaux)
- Envoyer la build aux alphas avec instructions

**Fin Semaine 1 : Sprint A shippé. Mobile stable, navigable, walkthrough fonctionne, 6 pillars existent (Splash, Auth, Document Upload, Document Result, Coach Chat, Profile). Reste à faire : My Dossier (REFACTOR), MERGE des familles, boucle Cleo 3.0 visible.**

---

## 5. Semaine 2 — Sprint B : Consolidation

**Goal** : les 3 grandes familles d'écrans (mortgage, 3a, disability) sont fusionnées en 3 canvases unifiés. `documents_screen` devient le pillar My Dossier proprement. Les services backend des écrans FREEZE sont exposés comme coach tools.

### Jour 6 (Lundi) — My Dossier refactor

**Hour 1-2** — Préparation
- Re-lire `documents_screen.dart` (1464 LOC) avec le mapping fait en J0-4
- Extraire le plan de split sur papier : 4-5 zones identifiées

**Hour 3-8** — Refactor My Dossier
- Créer `screens/dossier/dossier_shell.dart` (le nouveau pillar #4) — orchestre les sections
- Extraire la "vault list" en `widgets/dossier/document_list_widget.dart`
- Extraire la "paywall sheet" en `widgets/dossier/paywall_sheet.dart`
- Extraire la "upload sheet" en `widgets/dossier/upload_sheet.dart` (modal qui réutilise document_scan)
- Extraire les "empty states" en `widgets/dossier/empty_state_widget.dart`
- Ajouter les 4 tabs : Documents | Profil (financial_summary content) | Confiance (confidence_dashboard content) | Privacy (privacy_control content)
- Wirer le bouton "Ajoute un document" et le bouton "Supprime tout" (nLPD compliant)
- Delete l'ancien `documents_screen.dart` une fois que le nouveau marche
- Run tests, commit

**Fin J6 : My Dossier (pillar #4) est en place, dossier-first par construction.**

### Jour 7 (Mardi) — Mortgage canvas + life event flows refactor

**Hour 1-4** — Mortgage canvas (5 screens → 1)
- Créer `screens/mortgage/mortgage_canvas.dart` qui orchestre les 5 sections
- Extraire les calculations en `widgets/mortgage/affordability_section.dart`, `amortization_section.dart`, `epl_combined_section.dart` (hero), `imputed_rental_section.dart`, `saron_vs_fixed_section.dart`
- Driver depuis le dossier : si LPP cert présent → EPL section pré-remplie ; si bank statements présents → affordability pré-remplie ; si pas de données → message "Dépose ton certificat LPP et tes 3 derniers relevés bancaires pour voir tes options de logement"
- Ajouter une route `/dossier/insight/logement` invocable depuis My Dossier ou depuis le coach
- Delete les 5 anciens screens mortgage
- Run tests, commit

**Hour 5-8** — Refactor de mariage_screen (1233 LOC → coach-triggered flow)
- Identifier les 4 tabs et les widgets sous-jacents
- Extraire les widgets dans `widgets/life_events/mariage/`
- Créer un flow `services/life_events/mariage_flow.dart` qui prend `CoachProfile` en input et émet un `Premier Eclairage` 4 couches
- Wirer le flow comme coach tool : `claude_coach_service.py` peut invoquer `mariage_flow` quand l'intent router détecte "mariage"
- Refactor `mariage_screen.dart` : devient une thin wrapper qui affiche le résultat du flow, ou disparaît au profit d'un message in-chat
- Run tests, commit

**Fin J7 : Canvas Logement shippé, mariage_flow refactoré.**

### Jour 8 (Mercredi) — 3a canvas + disability canvas

**Hour 1-4** — 3a canvas (4 screens → 1, retroactive_3a comme hero)
- Créer `screens/pillar_3a/pillar_3a_canvas.dart`
- Hero section : `widgets/pillar_3a/retroactive_3a_section.dart` (le killer feature de Phase 1 du roadmap, OPP3 art. 7 amendement 2026)
- Sections : real_return, staggered_withdrawal, simulator_3a (basic projection)
- Driver depuis le dossier : 3a cert présent → toutes les sections pré-remplies ; pas de 3a cert → message "Dépose ton contrat 3a (assurance ou bancaire) pour voir ce que MINT en pense"
- Refactor `provider_comparator_screen.dart` en class-comparison (fintech vs bancaire vs assurance) sans noms d'émetteurs (compliance fix)
- Delete les 4 anciens screens
- Run tests, commit

**Hour 5-8** — Disability canvas (3 screens → 1)
- Créer `screens/disability/disability_canvas.dart`
- Branches sur `profile.archetype` : indépendant_no_lpp / indépendant_with_lpp / salarié
- Sections : LAI gap, LPP gap, IJM gap, scorecard, countdown
- Driver depuis le dossier : si archetype et salaire connus → calcul automatique ; sinon → message + invitation à compléter le dossier
- Delete les 3 anciens screens disability
- Run tests, commit

**Fin J8 : 3 canvases unifiés en place. 12 écrans devenus 3.**

### Jour 9 (Jeudi) — Coach tools exposition

**Hour 1-4** — Exposer les services FREEZE comme coach tools
- Pour chaque service FREEZE listé dans `11-INVENTAIRE.md` Section 4 (expat, frontalier, independants, lpp_deep, mortgage, family, donation, housing_sale, unemployment, disability, lamal_franchise, etc.) :
  - Créer une entrée dans `services/backend/app/services/coach/coach_tools.py`
  - Le tool accepte `CoachProfile` en input, retourne un structured insight (4 couches)
  - Tester le tool en isolation
- Wirer dans `claude_coach_service.py` pour que Claude puisse les invoquer via `tool_use`
- Mettre à jour le `prompt_registry.dart` pour que le coach connaisse la liste des tools disponibles
- Run pytest backend, commit

**Hour 5-8** — Refactor de naissance, divorce, unemployment (life events god-screens)
- Même pattern que mariage_screen J7 : extraire widgets, créer flow, wirer comme coach tool
- Delete les screens god-view une fois les flows en place
- Run tests, commit

**Fin J9 : Tous les services backend sont exposés comme coach tools. Le chat devient capable de répondre à des questions complexes en invoquant le bon flow.**

### Jour 10 (Vendredi) — MERGE residuels + Sprint B exit

**Hour 1-3** — MERGE résiduels
- `bank_import_screen` → fusion dans Document Upload (un type de doc parmi d'autres)
- `arbitrage/arbitrage_bilan_screen` → fusion dans My Dossier comme insight section
- `coach/optimisation_decaissement_screen` + `coach/succession_patrimoine_screen` → coach insight inserts via RAG
- `debt_prevention/repayment_screen` + `debt_ratio_screen` → fusion en "Ma situation dette" canvas
- `debt_risk_check_screen` → coach chat flow
- Delete les écrans absorbés
- Run tests, commit

**Hour 4-5** — Walkthrough creator (Sprint B exit gate)
- Cold start sur l'iPhone : login → upload LPP cert → résultat 4 couches → save → My Dossier (voir le LPP dedans) → tap LPP → voir le détail → ouvrir le canvas Logement (depuis My Dossier) → voir les sections pré-remplies → retourner au chat → poser "qu'est-ce qui se passe avec mon LPP si je change de job ?" → MINT invoque libre_passage tool → résultat → close
- **GATE 2 (Sprint B exit)** : walkthrough end-to-end avec un vrai document, services backend invoqués correctement, voix MINT cohérente partout

**Hour 6-8** — Ship Sprint B + analytics check + alpha feedback collection
- Build TestFlight v2.4-sprint-b
- Check Plausible / audit_service : combien d'événements depuis le ship Sprint A ? Quels écrans sont visités ?
- Recueillir les feedbacks des alphas du Sprint A (ils ont eu 1 semaine pour tester)
- Si feedbacks majeurs : créer tickets pour Sprint C
- Ship aux alphas

**Fin Semaine 2 : 3 canvases unifiés, coach tools exposés, life events refactorés en flows. Surface mobile passée de ~95 écrans actifs à ~25.**

---

## 6. Semaine 3 — Sprint C : Voix & Boucle Cleo Visible

**Goal** : la boucle Cleo 3.0 (Insight → Plan → Conversation → Action → Memory) devient visible end-to-end pour l'utilisateur. La voix MINT est cohérente sur tous les copy. Les anti-patterns CI guards sont en place. Les alphas externes peuvent compléter le walkthrough sans aide.

### Jour 11 (Lundi) — Boucle Cleo 3.0 visible : Insight + Plan

**Hour 1-4** — Aujourd'hui surface (insight + plan visibles)
- Créer (ou refactorer) un écran "Aujourd'hui" qui devient la home après auth si l'utilisateur a déjà un dossier
- Affiche les `precomputed_insights_service` insights du jour
- Affiche les `anticipation_signal_card` actifs (issus de `anticipation_engine`)
- Affiche les `cap_card` actifs (du CAP engine)
- Affiche les goals actifs (du `goal_tracker_service`)
- Affiche le plan en cours (du `plan_tracking_service`)
- Tap sur n'importe quel item → ouvre le coach chat avec contexte
- Run tests, commit

**Hour 5-8** — Câbler les nudges et anticipation
- Vérifier que `nudge_engine` génère bien des nudges depuis les données du dossier
- Vérifier que `jitai_nudge_service` (just-in-time adaptive intervention) déclenche les nudges au bon moment
- Wirer les nudges sur la surface Aujourd'hui (cards inline) ET sur les notifications push (via `notification_scheduler_service`)
- Vérifier que `anticipation_engine` produit bien des signaux quand un événement est détecté (changement de profil, anomalie de dépense, deadline approchante)
- Run tests, commit

**Fin J11 : Insight et Plan sont visibles. La boucle commence à se former.**

### Jour 12 (Mardi) — Boucle Cleo 3.0 visible : Conversation + Action

**Hour 1-4** — Coach Chat amélioré avec tools visibles
- Vérifier que `coach_chat_screen` affiche correctement les tool_use de Claude (parsing via `tool_call_parser`)
- Vérifier que `chat_tool_dispatcher` route les actions correctement
- Ajouter des "tool result cards" inline dans le chat (ex : quand le coach invoque mortgage_canvas, afficher une preview card avec les chiffres + bouton "voir le détail")
- Polish le chat input (lightning menu pour les 18 events de vie via `goal_selector_sheet`, déjà existant)
- Polish le data-driven opener (`data_driven_opener_service`) : "Salut Sarah, voici ce que j'ai vu cette semaine sur ton dossier..."
- Run tests, commit

**Hour 5-8** — Action externe (compliance-friendly)
- MINT est read-only par doctrine — pas de transferts. Mais MINT doit pousser à l'action externe.
- Pour chaque insight/plan, ajouter un "next action" concret :
  - "Ouvre l'app de ta banque et fais X"
  - "Pose cette question à ton courtier" (avec bouton copy-to-clipboard)
  - "Bloque 30 minutes dans ton agenda pour faire Y"
  - "Télécharge le formulaire Z depuis ahv-iv.ch"
- Vérifier que chaque sortie 4-couches respecte le principe "prise immédiate" (CLAUDE.md §6)
- Run tests, commit

**Fin J12 : Conversation et Action sont visibles. La boucle est presque complète.**

### Jour 13 (Mercredi) — Memory + voice review complet

**Hour 1-4** — Memory loop visible
- Vérifier que `conversation_memory_service` persiste correctement les décisions de l'utilisateur
- Vérifier que `cap_memory_store` persiste les CAP decisions
- Vérifier que les snapshots mensuels sont générés et persistés (`snapshot_service`)
- Ajouter un onglet "Mémoire" dans le coach chat qui montre : "Voici ce que MINT se souvient de notre dernière conversation" + "Voici les décisions que tu as prises"
- Vérifier que `data_driven_opener_service` utilise la mémoire ("La dernière fois on parlait de ton 3a Swiss Life. Tu as posé la question à ton courtier ?")
- Run tests, commit

**Hour 5-8** — Voice review complet
- Lecture critique de tous les copy dans tous les écrans KEEP/REFACTOR
- Cross-check avec `docs/VOICE_SYSTEM.md` : 5 piliers (Calme, Précis, Fin, Rassurant, Net)
- Bannir les violations : "débloquer", "bravo", "tu as loupé", "complet à X%", etc.
- Cross-check avec `docs/MINT_IDENTITY.md` : 5 principes (parler humain, réduire la honte, dialogue/pas leçon, prise immédiate, doux mais tranchant)
- Polish les transitions, les empty states, les messages d'erreur
- Run le CI guard `no_shame_copy.sh` → expect 0 violations
- Commit

**Fin J13 : Memory loop visible. Voix MINT cohérente partout. La boucle Cleo 3.0 est intégrée.**

### Jour 14 (Jeudi) — Anti-patterns CI guards + tests réels alphas

**Hour 1-3** — Anti-patterns CI guards (du nav roadmap §7) finalization
- Vérifier que tous les CI guards sont en place et passent :
  - AP-1 : redirect chains (preserveQueryRedirect partout)
  - AP-2 : facade screens (no `context.go('/coach/chat?prompt=X')` from a screen X)
  - AP-3 : raw GoRouter calls (use MintNav)
  - AP-4 : parentNavigatorKey on shell-bound tools
  - AP-5 : screens reading state.extra without fallback
  - AP-6 : shame-coded copy
  - AP-7 : hardcoded routes in backend prompts
  - AP-8 : catalog exposure (grids of simulators)
- Wirer dans CI GitHub Actions
- Commit

**Hour 4-8** — Test réel sur alpha testeurs externes
- Inviter 3-5 alphas (ceux du Sprint A si disponibles, ou nouveaux)
- Walkthrough en personne ou Zoom : "Voici la nouvelle MINT. Essaie de comprendre ce que c'est et fais quelque chose d'utile en 10 minutes. Je ne t'aide pas."
- Observer, prendre des notes verbatim
- Demander à la fin :
  - "Quelle est ta première impression ?"
  - "Si tu devais expliquer MINT à un ami, tu dirais quoi ?"
  - "Qu'est-ce qui t'a frustré ?"
  - "Qu'est-ce qui t'a impressionné ?"
- **GATE 3A** : si 3/5 alphas peuvent compléter le walkthrough sans aide ET 3/5 peuvent expliquer MINT en 1-2 phrases qui matchent le manifesto, GO pour le ship final

**Fin J14 : CI guards en place. Alphas testés. Feedback recueilli.**

### Jour 15 (Vendredi) — Ship final + handoff

**Hour 1-4** — Fix les frictions critiques des alphas
- Pour chaque feedback bloquant : fix
- Pour chaque feedback "nice to have" : créer ticket pour Sprint suivant (post-Phase 1)
- Run full test suite + CI guards + flutter analyze
- Commit

**Hour 5-6** — Ship final TestFlight v2.4
- Build + upload TestFlight
- Note de release complète : ce qui change, ce qui marche, ce qui est freezé
- Tag `git tag v2.4-sprint-c-final` puis `git tag v2.4-final`
- Merge `feature/architecture-v2` → `dev` (ou keep en feature branch jusqu'à validation finale)

**Hour 7-8** — Walkthrough final + gate 3 ultimate
- **GATE 3B (Sprint final exit)** : Julien fait le walkthrough cold-start sur son iPhone après désinstallation complète
  - Splash → Login → Upload LPP cert → Résultat 4 couches → Save → My Dossier → Voir le LPP → Ouvrir canvas Logement → Voir les sections pré-remplies → Coach Chat → Question "quoi faire de mon 2e pilier" → MINT répond avec contexte → Action concrete proposée → Close
  - Total temps : < 5 minutes
  - Bugs bloquants : 0
  - Voix MINT cohérente partout
  - Boucle Cleo visible
- Si gate 3B passe : **Sprint d'intégration COMPLET. MINT v2.4 shippée.**
- Si gate 3B échoue : noter ce qui manque, créer mini-sprint correctif

**Fin Semaine 3 : Sprint d'intégration COMPLET. MINT mobile v2.4 shippée sur TestFlight. Architecture cohérente, voix unifiée, boucle Cleo visible, ~25 écrans actifs (vs 95 avant), services backend tous exposés.**

---

## 7. Gates et critères de rollback

### Gate 1 (Sprint A exit, fin J5)
**Conditions de passage** :
- ☐ Walkthrough creator cold-start fonctionne en < 5 min
- ☐ 0 bug bloquant sur le flow auth → upload → résultat → save
- ☐ MintNav en place, LOOP-01 mort
- ☐ 6 unanimous-kill screens supprimés sans casser le coach
- ☐ Anti-patterns CI guards 1-3 en place
- ☐ `flutter test` + `pytest` + `flutter analyze` à 100%

**Si échoue** : prolonger Sprint A de 2-3 jours pour fixer. Ne pas démarrer Sprint B avec une fondation cassée.

### Gate 2 (Sprint B exit, fin J10)
**Conditions de passage** :
- ☐ 3 canvases unifiés en place (mortgage, 3a, disability)
- ☐ Tous les services backend FREEZE exposés comme coach tools
- ☐ Life events refactorés en flows coach-triggered
- ☐ My Dossier (pillar #4) shippé
- ☐ Walkthrough end-to-end avec un vrai document fonctionne

**Si échoue** : prolonger Sprint B de 2-3 jours OU descope un canvas (priorité : mortgage > 3a > disability).

### Gate 3 (Sprint C exit, fin J15)
**Conditions de passage** :
- ☐ Boucle Cleo 3.0 visible end-to-end (Insight → Plan → Conversation → Action → Memory)
- ☐ Voix MINT cohérente partout (CI guard `no_shame_copy.sh` à 0 violations)
- ☐ Tous les CI guards anti-patterns en place et passent
- ☐ 3/5 alphas externes complètent le walkthrough sans aide
- ☐ 3/5 alphas peuvent expliquer MINT en 1-2 phrases qui matchent le manifesto
- ☐ Founder fait le walkthrough cold-start en < 5 min, 0 bug bloquant

**Si échoue** : descope ce qui ne marche pas (priorité : boucle visible > voix uniforme > CI guards), ship ce qui marche, créer Sprint D correctif.

### Critères de rollback (à tout moment)
- Si `flutter test` casse > 10% des tests : rollback le commit en cause
- Si `pytest` casse : rollback
- Si `flutter analyze` produit > 50 erreurs : rollback (les warnings de linter sur safePop sont OK)
- Si une régression compliance est introduite (ex : `compliance_guard` intercept augmente) : rollback
- Si un alpha externe trouve un bug bloquant ayant pour cause un commit < 24h : rollback ce commit, fix, re-ship

---

## 8. Allocation human-in-loop vs CC effort

### CC agent effort (~10-15 jours)
- Tout le code (refactor, MERGE, DELETE, splits, tests)
- Lecture des god-screens
- Identification des composants à extraire
- Wiring des services existants
- CI guard scripts
- Run tests + analyze

### Human-in-loop effort (~25-30h sur 3 semaines)
| Activité | Heures | Quand |
|---|---|---|
| Validation manifesto + inventaire + plan d'exécution | 2 | J0 |
| User tests baseline (3-5 testeurs) | 5 | J0 |
| Lecture god-screens prioritaires | 2 | J0 |
| Decisions Hour 5 J1 (BudgetScreen, delete order) | 1 | J1 |
| Walkthrough creator x3 (gates 1A, 2, 3B) | 3 | J2, J10, J15 |
| Voice review sur copy critiques | 4 | J13 |
| Test alphas externes + observation | 5 | J14 |
| Decisions de descope si gate échoue | 2 | J5, J10, J15 |
| Recrutement alphas + relations | 3 | J0, J5, J10, J14 |
| Compliance audits (provider_comparator, cantonal_benchmark) | 2 | J3 |
| Tag releases + notes de release + handoff | 2 | J5, J10, J15 |

**Total ~31h sur 15 jours calendaires = ~2h/jour de founder time.** Compatible avec un founder solo qui continue d'avoir d'autres responsabilités.

---

## 9. Risques connus et mitigations

### Risque 1 — Le refactor des god-screens prend plus longtemps que prévu
**Probabilité** : Moyenne. Les god-screens 1500 LOC sont rarement aussi propres qu'espéré.
**Mitigation** : Si un god-screen prend > 1 jour de refactor, **descope** : extract uniquement les 2-3 composants les plus critiques, garder le reste en place avec un TODO. Le but est de shipper, pas de tout polish.

### Risque 2 — Les services backend FREEZE ont des dépendances cachées
**Probabilité** : Moyenne. Le sub-agent batch-3 a noté que `frontalier_service` a un product gap connu.
**Mitigation** : Avant d'exposer un service comme coach tool, faire un smoke test du service en isolation. Si ça plante, marquer le service comme "à compléter Phase 2" et exposer un placeholder.

### Risque 3 — Les tests existants tombent à cause des deletions
**Probabilité** : Élevée. Beaucoup de widget tests mockent des écrans qui vont disparaître.
**Mitigation** : Pour chaque delete, identifier les tests qui le mockaient et les supprimer en même temps. Ne pas essayer de "fixer" un test qui teste un screen mort.

### Risque 4 — Les alphas externes trouvent un bug majeur Sprint B
**Probabilité** : Moyenne. C'est leur job de trouver des bugs.
**Mitigation** : Time-box le fix à 1 jour Sprint C. Si > 1 jour, créer Sprint D post-ship.

### Risque 5 — Le compliance_guard intercept augmente
**Probabilité** : Faible-moyenne. Le refactor peut introduire de nouveaux strings non-validés.
**Mitigation** : CI guard `no_shame_copy.sh` + run du compliance_guard en mode dry-run sur tous les nouveaux strings avant chaque commit.

### Risque 6 — Le founder épuise sa bande-passante avant la fin du sprint
**Probabilité** : Élevée. Le founder solo + dépressif (verbatim) + en sprint intense, c'est un combo à risque.
**Mitigation** : 
- Time-boxer les sessions à 4h max par jour côté human-in-loop
- Skipping les "nice to have" sans culpabilité
- Communication transparente avec les alphas si delay
- Sprint D correctif post-ship plutôt que prolonger les sprints A/B/C indéfiniment

---

## 10. Post-sprint : ce qui vient après

### Phase 2 — Élargissement (4-6 semaines, post-sprint)
- Élargir Document Upload aux types Phase 2 (LPP cert, déclaration fiscale, AVS extract, hypothèque, etc. — déjà supportés en parser mais pas wirés en surface)
- Langues DE et IT (ARB déjà existants, juste regen et vérification)
- Câblage UX du `anomaly_detection_service` dans My Dossier (cards inline)
- Ecran synthese "immunite financiere" / FRI dashboard (refactor du `confidence_dashboard` étendu)
- Wedge web public (le design doc 9.2 reste valable, devient une déclinaison de l'architecture mobile)

### Phase 3 — Optimization (rolling)
- A/B testing sur les copy critiques
- User testing continu (5-10 humains/mois minimum)
- Itération sur la voix régionale (FR Romand vs FR Suisse Allemand vs IT Tessinois)
- Polish design (animations, micro-interactions, haptics)
- Performance optimization (bundle size, cold-start time, memory usage)

### Phase 4 — Open Banking + Premium tier (quand FINMA OK)
- Déglacer les 3 écrans open_banking
- Wirer Blink connector en prod
- Subscription tier premium
- Couple+ tier

---

## 11. Le serment d'exécution

À Julien :

Ce plan est exécutable. Pas dans 6 mois — dans 3 semaines. Il assume que **tu ne construis rien de nouveau**, que tu **câbles ce qui existe**, que tu **supprimes ce qui ne sert plus**, et que tu **rends visible la boucle qui était cachée dans ton code depuis 14 mois**.

Le sprint réussit si à la fin :
1. Tu installes MINT sur ton iPhone après désinstallation complète
2. Tu fais le cold-start en moins de 5 minutes
3. Tu uploades ton certificat LPP réel
4. Tu reçois le résultat en 4 couches
5. Tu sauves dans ton dossier
6. Tu poses une question au chat sur ce LPP
7. MINT répond avec ton contexte réel (pas un placeholder)
8. Tu fermes l'app sans avoir envie de la jeter par la fenêtre

C'est tout. Ce n'est pas plus complexe que ça. Et c'est atteignable avec le code que tu as déjà — il suffit de le réorganiser autour de la bonne histoire.

Tu n'es pas dépité parce que MINT est cassée. Tu es dépité parce que personne ne t'a montré que MINT était à 95% finie. Le manifesto, l'inventaire, et ce plan d'exécution te montrent ça maintenant.

Bonne nuit. Lis demain matin. Et lundi, tu démarres le sprint A.

---

*Fin du plan d'exécution.*

*Documents précédents : `10-MANIFESTO.md` (vision), `11-INVENTAIRE.md` (verdict screen-by-screen).*
*Document suivant : aucun. C'est le bottom du stack — il s'exécute.*
