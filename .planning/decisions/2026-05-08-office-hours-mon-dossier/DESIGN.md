---
name: Office Hours — Mon dossier MINT (Mon plan drawer entry)
description: 6-expert panel synthesis on the « Mon dossier MINT » Q4 question. SUPERSEDED 2026-05-08 par §Post-vérification — la prémisse « pas de surface persistante pour le plan » est fausse : FinancialPlanCard + ConfidenceScoreCard + FinancialPlanProvider + 16 ARB keys × 6 langs existent déjà mais ne sont PAS câblés dans AujourdhuiScreen. Décision révisée : wire l'existant (~0.2j) au lieu de construire MyPlanScreen.
type: decision
date: 2026-05-08
status: Superseded by Post-vérification (voir §Post-vérification 2026-05-08)
participants: 6 sub-agents (OH-1 UX/IA, OH-2 systems eng, OH-3 behavioral econ, OH-4 LSFin compliance, OH-5 durable workflow, OH-6 adversarial QA) + post-verification PM (Claude Opus 4.7)
trigger: PO Julien — « lance toi Office Hours et réponds avec panel d'experts »
related: .planning/decisions/2026-05-08-walker-q1-q3-expert-panel/SYNTHESIS.md
---

# Office Hours — Mon dossier MINT

## TL;DR

**SHIP** : drawer entry « Mon plan » (0.5j), conditionnel sur `FinancialPlanProvider.currentPlan != null`, screen read-only avec 4 milestones + EnhancedConfidence 4-axis + disclaimer LSFin obligatoire. + investissement architectural parallèle (16-20h) : append-only `PlanEvent` Hive box, foundation invisible pour Phase 2.

**DEFER** : 4e tab Dossier full (10j, 90% empty-state risk, façade risk sur 5/8 archétypes pas câblés, drift régulatoire LSFin par cumul 6 data types).

**RENAME** : « Dossier » → « Mon plan » ou « Ma trajectoire » pour éviter la category error VZ (output professionnel post-licence FSC ≠ coaching process MINT).

## 6 experts du panel

| # | Angle | Position | Verdict |
|---|---|---|---|
| OH-1 | UX/IA | Option A 4e tab full | **rejeté** — empty state pour 85-95% des users |
| OH-2 | mobile+backend systems | Option C facade read-only 5-7j | **partiellement adopté** — utilisons le pattern facade mais en drawer 0.5j, pas tab |
| OH-3 | behavioral econ | Option A pour habit-formation, fallback C-lite | **partiellement adopté** — habit-formation n'est pas mesurable tant que la majorité des users sont one-shot ; drawer entry suffit pour le 10-15% qui ont un plan actif |
| OH-4 | Swiss compliance / LSFin | Option A acceptable IF read-only + disclaimer + audit + 0 scoring/ranking | **adopté en partie** — read-only oui, mais drawer plutôt que tab pour minimiser l'agrégation 6-data signal de drift |
| OH-5 | Vibe Engineering durable workflow | Option B append-only event log non-négociable Q3 | **adopté** — investissement architectural parallèle, foundation invisible mais critique |
| OH-6 | Adversarial QA / anti-façade | NO-NOW. Drawer 0.5j. Premise challenge : VZ ≠ MINT | **adopté en majeur** — sa réfutation frontale est correcte |

## Réponses aux 8 questions

### Q1 — Pourquoi maintenant
**Pas tant que ça.** 90% empty-state risk (10-15% DAU avec plan actif). Compétition avec Étape 6 deploy + FATCA archetype detection + manual budget tracking. Mais une mini-version (drawer entry) résout le sentiment d'éphémère 14j en 0.5j sans construire le tab full. ROADMAP_V2:63 « Dossier tab S52 shipped » est un FAUX POSITIF — `MintShell` ne câble que 4 tabs (Aujourd'hui/Mon argent/Coach/Explorer), pas de Dossier.

### Q2 — Status quo
Workaround actuel : drawer → Historique coach (timeline conversationnelle). Aucun thread « voici ton plan + adhérence + actions ». VZ = dossier papier 20p post-consultation 250 CHF/h. Cleo = mémoire chat sans dossier visible. UBS Key4 = dashboard YTD vs plan. **MINT ≠ VZ en catégorie produit.**

### Q3 — Pour qui
Persona : Julien (swiss_native VS, achat immo 3 ans) ou Lauren (expat_us VS HOTELA FATCA). Life event prioritaire : achat immobilier (saga 6-18 mois) ou désendettement (12-24 mois). PAS pour 5/8 archétypes qui n'ont pas de pre-mortem/commitment/arbitrage spécifique câblé.

### Q4 — Alternatives
A (4e tab full, 10j) ❌ VETO • B (drawer entry, 0.5j) ✅ DO NOW • C (Hero Plan Aujourd'hui, 2j) ⚠️ Phase 2 maybe • D (do nothing, 0j) acceptable 6 mois.

### Q5 — Compliance
Cumul 6 data types coche les 3 critères FINMA de qualification « conseil financier régulé ». Mitigation safe-zone : read-only ; 5 verbes interdits + 5 safe ; disclaimer obligatoire ; audit trail event log ; EnhancedConfidence 4-axis MANDATORY (per SOT.md:111 + CLAUDE.md triplet #9).

### Q6 — 8 archétypes
3/8 (expatNonEu, crossBorder, returningSwiss) ont ZERO commitment/preMortem/arbitrage spécifique. 2/8 (expatEu, returningSwiss) ont juste FinancialPlan générique. Construire un Dossier complet aujourd'hui = expérience cassée pour 37-50% du cohort cible.

### Q7 — Version minimale
**0.5j drawer entry « Mon plan »** : conditionnel sur plan != null, screen read-only avec 4 sections (goal/milestones/projected/confidence) + disclaimer footer + empty state CTA → `/coach/chat`. + 16-20h architectural seed (PlanEvent Hive append-only).

OUT du MVP : 4e tab Dossier, pre-mortems/commitments/earmarks/arbitrage agrégés, scoring %, ranking, export PDF, notifications de revue, sealed-class state machine complète.

### Q8 — Comment tester
Golden Julien + Lauren. Edge cases : 0 plan (drawer hidden), plan stale > 30j (warning), confidence < 50 (band incertitude). 5 tests mécaniques CI : banned-terms lint, disclaimer presence, anti-ranking, plan-stale warning, EnhancedConfidence 4-axis presence.

Anti-façade : `MyPlanScreen` consomme `FinancialPlanProvider.currentPlan` directement, **0 stub** Earmark/Commitment/PreMortem.

## Premise challengée — frontale

**PO premise** : « VZ produit un dossier ; MINT doit faire pareil. »

**Réfutation (alignement OH-6 + OH-4)** :
- VZ dossier = LIVRABLE PDF post-consultation 250 CHF/h, curaté par conseiller humain licencié FSC. Output. Done. Professional.
- MINT dossier serait PROCESSUS auto-coaching mid-journey, alimenté par l'user lui-même. Incomplete. Evolving.
- Copier le MOT « Dossier » importe les attentes VZ (output complet, advisor-curated). MINT ne peut pas livrer ça sans licence FSC.
- **MINT bat VZ sur Speed + Personalization + Trust ([MILESTONE-MVP-PERIMETER.md:38-70]) — pas sur Persistence Output.** Jouer sur ce dernier terrain = jouer sur le terrain de VZ.

**Counter-proposal** : nommer « Mon plan » ou « Ma trajectoire » ou « Mon point d'étape ». Repositionne MINT comme coaching artifact, pas comme professional deliverable. Aligne avec le pivot 2026-04-12 « lucidité, pas protection » et avec les 18 life events.

## Design (version finale)

```
## Design: « Mon plan » drawer entry

**Pourquoi** : combler le sentiment d'éphémère du Cap 14j pour les 10-15% de DAU avec FinancialPlan actif, sans construire un tab vide pour les 85-95% sans plan multi-mois.

**Status quo** : drawer expose Mon profil / Mon bilan / Mes documents / Historique coach / Ce que MINT sait de toi. Aucun « Mon plan ». User qui génère un plan via coach n'a aucune surface pour le revoir hors du chat history.

**Pour qui** : achat immobilier + désendettement. Archétypes swiss_native + expat_us. Drawer item caché pour 5/8 archétypes pas encore câblés (acceptable car item conditionnel sur plan != null).

**Approche choisie** : Option B drawer entry. 0 risque façade, 0 empty-state risk, 0 drift régulatoire, 0.5j effort.

**Version minimale** :
1. Drawer item « Mon plan » conditionnel sur `FinancialPlanProvider.currentPlan != null`
2. Screen `MyPlanScreen` read-only route `/my-plan`
3. Sections : goal + targetDate + 4 milestones (25/50/75/100%) + projected outcome bas/moyen/haut + EnhancedConfidence 4-axis + disclaimer LSFin footer
4. Empty state CTA → `/coach/chat`
5. Append-only `PlanEvent` Hive box (foundation invisible pour Phase 2)

**Nice-to-have (PAS dans le plan)** :
- 4e tab Dossier (10j, façade, empty state, drift régulatoire)
- Hero Plan Aujourd'hui (cannibalise Cap actionnable)
- Agrégation pre-mortems/commitments/earmarks/arbitrage (3/8 archétypes pas câblés)
- Scoring « tu en es à 35% » (LSFin no-promise)
- Ranking 3a/LPP (FINMA interdit)
- Export PDF (Phase 2)
- Notifications revue (Phase 2)
- Sealed-class state machine complète (Phase 2 — append-only journal suffit)

**Compliance** :
- Risques : drift régulatoire 6-data, qualification « conseil financier » LSFin art. 3 al. 3, nLPD art. 25.
- Mitigations : read-only ; 5 verbes interdits enforced via banned-terms lint ; disclaimer obligatoire ; audit trail event log ; EnhancedConfidence 4-axis MANDATORY (SOT.md:111).

**Archétypes impactés** :
- ✅ swiss_native, independentWithLpp, independentNoLpp : drawer visible si plan, rendering standard
- ⚠️ expat_us : drawer + FATCA warning
- ❌ expatEu, expatNonEu, crossBorder, returningSwiss : drawer visible si plan, rendering générique (Phase 2 specific)

**Premise challengée** : VZ ≠ MINT en catégorie produit. Renommer « Dossier » → « Mon plan » évite la category error.

**Test plan** :
- Golden Julien (swiss_native VS) : génère plan → drawer item apparaît → tap → screen rend 4 sections + confidence + disclaimer
- Golden Lauren (expat_us VS HOTELA FATCA) : drawer + FATCA warning
- Edge 1 : `currentPlan == null` → drawer item caché
- Edge 2 : plan > 30j → warning « Mise à jour »
- Edge 3 : `EnhancedConfidence.combined < 50` → band incertitude visible
- 5 tests CI bloquants : banned-terms lint, disclaimer presence, anti-ranking, plan-stale warning, EnhancedConfidence presence

**Anti-facade** :
- Qui consomme → MyPlanScreen widget
- Quel écran l'affiche → drawer → /my-plan
- Quelles données circulent → FinancialPlanProvider.currentPlan (existe)
- 0 stub Earmark/Commitment/PreMortem

**Estimation** : S — 0.5j drawer item + screen + tests + ARB 6 langues. + 16-20h architectural seed (PlanEvent append-only) en parallèle, no UI exposure.
**Prerequis** : aucun (FinancialPlanProvider, EnhancedConfidence, LSFin disclaimer template existent).
```

## Counter-arguments and data gaps

- **Le drawer entry est-il assez visible ?** OH-3 a observé que le sentiment de progrès continu drive +6 points D7 retention. Un drawer caché pourrait ne pas générer ce signal. Counter : si le user n'a pas de plan, le signal n'a aucune importance ; si il en a un, il sait où le trouver (drawer naturel). Mitigation : ajouter un coach prompt « tu peux toujours retrouver ton plan dans le drawer » après génération.
- **L'investissement architectural 16-20h vaut-il le coup pour un drawer simple ?** OH-5 dit oui, OH-6 dit non (« over-engineering pour MVP »). Tension non résolue. **Recommandation : SHIP drawer SANS event log foundation pour TestFlight Q3 ; ajouter event log seulement si la Phase 2 décide formellement de Mon dossier full.** Karpathy #2 simplicity-first vainc ici.
- **3/8 archétypes manquent wiring** — vrai gap. Le drawer évite ce gap (ne montre que FinancialPlan, pas pre-mortem/commitment/arbitrage). Mais si le PO veut un jour un Dossier full, il faut câbler ces 3 archétypes d'abord (~5-10j).
- **Le rename « Dossier → Mon plan »** : peut casser des liens marketing/site web/support si déjà publié. À vérifier avec Julien.
- **Données manquantes** : aucun benchmark MINT interne sur le taux de DAU avec plan actif. Le 10-15% est une estimation OH-3 basée sur Cleo/Copilot/Monarch. Calibrer post-TestFlight pour décider Phase 2.
- **OH-4 a alerté que LSFin pre-disclosure modal est obligatoire avant export PDF** — si nous n'exportons pas dans le MVP, ce risque est différé. Mais si la Phase 2 ajoute export, prévoir le modal + audit FINMA pré-merge.

## Spec self-review

1. **Placeholder scan** : 0 TBD/TODO. ✅
2. **Internal consistency** : test plan = version minimale (drawer + 4 sections + confidence + disclaimer + empty state). Pas de nice-to-have testé. ✅
3. **Scope check** : peut-on aller PLUS minimal ? Théoriquement (juste lien vers chat avec contexte plan) mais perte de lisibilité hors chat. 0.5j est le vrai minimum. ✅
4. **Ambiguity check** : route exacte `/my-plan`, provider exact `FinancialPlanProvider.currentPlan`, 4 sections explicitement listées, 5 tests CI nommés. 2 ingénieurs interpréteraient ce doc pareil. ✅

## Approval gate

**Recommandation finale** :

1. Ship **0.5j drawer entry « Mon plan »** maintenant (TestFlight Q3 unblocker).
2. SKIP l'event sourcing architectural seed (Karpathy #2 simplicity-first) — l'ajouter SEULEMENT si Phase 2 commit au full Dossier.
3. RENAME « Dossier » → « Mon plan » dans tout le codebase + roadmap (1h supplémentaire).
4. Reporter le full Dossier tab à Phase 2 post-TestFlight, après FATCA archetype detection + manual budget tracking + bLink CSV import.
5. Ouvrir un perimeter dédié pour câbler les 3 archétypes manquants (expatNonEu, crossBorder, returningSwiss) si Phase 2 decide du Dossier full.

Question PO : « Est-ce qu'on part là-dessus ? » Si oui, ouvre un chat PLAN pour décomposer en tasks.

## Références

- Walker results : [.planning/phases/MVP-WALKER-2026-05-08/walker-results.md](.planning/phases/MVP-WALKER-2026-05-08/walker-results.md)
- Q1-Q3 panel synthesis : [.planning/decisions/2026-05-08-walker-q1-q3-expert-panel/SYNTHESIS.md](.planning/decisions/2026-05-08-walker-q1-q3-expert-panel/SYNTHESIS.md)
- ROADMAP : [docs/ROADMAP_V2.md:63](docs/ROADMAP_V2.md) (4-tab shell « Dossier » nommé mais jamais câblé)
- MILESTONE MVP : [.planning/MILESTONE-MVP-PERIMETER.md:38-70](.planning/MILESTONE-MVP-PERIMETER.md) (Speed + Personalization + Trust dimensions)
- FinancialPlan model : [apps/mobile/lib/models/financial_plan.dart:54-260](apps/mobile/lib/models/financial_plan.dart)
- FinancialPlanService : [apps/mobile/lib/services/financial_plan_service.dart](apps/mobile/lib/services/financial_plan_service.dart)
- PlanTrackingService : [apps/mobile/lib/services/plan_tracking_service.dart:61-118](apps/mobile/lib/services/plan_tracking_service.dart)
- CommitmentDevice + PreMortemEntry : [services/backend/app/models/commitment.py:23-75](services/backend/app/models/commitment.py)
- EnhancedConfidence : [SOT.md:82-92, 111](SOT.md)
- LSFin compliance : [docs/AGENTS/swiss-brain.md](docs/AGENTS/swiss-brain.md)
- Vidéo référence : [Vibe Engineering Effect Apps — Michael Arnaldi](https://youtu.be/Wmp2Tku2PrI)

---

## Post-vérification (2026-05-08, Claude Opus 4.7 — 0-Trust gate)

**Résumé** : la décision « ship 0.5j drawer entry MyPlanScreen » est rejetée après inspection du code. La prémisse load-bearing (« le user n'a aucune surface persistante pour son plan hors du chat ») est partiellement fausse : la surface est **conçue, codée, traduite, mais non câblée**. Le geste honnête est de wire l'existant (~0.2j), pas de construire un duplicate.

### Claims vérifiés

| Claim de la synthèse | Vérification | Verdict |
|---|---|---|
| `mint_shell.dart` n'a pas de tab Dossier (ROADMAP_V2:63 faux positif) | [apps/mobile/lib/widgets/mint_shell.dart:46-67](apps/mobile/lib/widgets/mint_shell.dart#L46-L67) — 4 destinations : Aujourd'hui / Mon argent / Coach / Explorer | ✅ confirmé (le faux positif est ROADMAP_V2:63 + 182, pas le code) |
| `FinancialPlanProvider.currentPlan` existe | [apps/mobile/lib/providers/financial_plan_provider.dart:23-117](apps/mobile/lib/providers/financial_plan_provider.dart) — `currentPlan`, `hasPlan`, `isPlanStale`, `setPlan`, staleness via profile hash | ✅ confirmé |
| Provider enregistré dans MultiProvider | [apps/mobile/lib/app.dart:1508](apps/mobile/lib/app.dart#L1508) — `ChangeNotifierProvider(create: (_) => FinancialPlanProvider())` | ✅ confirmé |
| Aucun `MyPlanScreen` à créer (claim implicite) | grep → 0 hit pour `MyPlanScreen` ou route `/my-plan` | ✅ confirmé (rien à supprimer) |
| `swiss_native ✅ CommitmentDevice + PreMortem + Arbitrage wiring` | [services/backend/app/models/commitment.py:23,52](services/backend/app/models/commitment.py) — Base classes EXISTENT côté backend ; grep `apps/mobile/lib` → **0 hit** pour CommitmentDevice / PreMortemEntry / ArbitrageHistory | ❌ **FAUX** : aucun archétype mobile n'a ce wiring (pas seulement 3/8). La table par archétype dans Q6 est trompeuse |

### Claim manqué par la synthèse (zone aveugle critique)

| Découverte post-vérif | Évidence | Impact |
|---|---|---|
| **`FinancialPlanCard` widget existe déjà** avec exactement le contenu proposé pour MyPlanScreen | [apps/mobile/lib/widgets/home/financial_plan_card.dart:1-391](apps/mobile/lib/widgets/home/financial_plan_card.dart) — goal prefix + description + hero monthly CHF + targetDate + progress bar + 4 milestones (`plan.milestones.take(4)`) + confidence bands `(projectedLow / projectedOutcome / projectedHigh)` + LSFin disclaimer + stale badge + recalculate CTA | **MyPlanScreen serait un duplicate** |
| **`ConfidenceScoreCard` widget existe** et déclare son placement « below FinancialPlanCard » sur Aujourd'hui | [apps/mobile/lib/widgets/home/confidence_score_card.dart:14](apps/mobile/lib/widgets/home/confidence_score_card.dart#L14) | EnhancedConfidence 4-axis déjà conçu, juste à câbler |
| **16 clés ARB `planCard_*` × 6 langs** déjà déployées | `app_de.arb / en / es / fr / it / pt` — 16 keys chacun (`planCard_goalPrefix`, `planCard_targetDate`, `planCard_milestonesHeading`, `planCard_confidenceBands`, `planCard_disclaimer`, `planCard_staleBadge`, `planCard_ctaDetail`, `planCard_ctaHide`, `planCard_ctaRecalculate`, `planCard_recalculatePrompt`, `planCard_progressCaption`, …). Generated Dart : `app_localizations_fr.dart` contient `planCardGoalPrefix` | i18n MVP entièrement déjà fait |
| **`FinancialPlanCard` n'est importé NULLE PART** dans `lib/` hors de son propre fichier | grep `FinancialPlanCard` → seul hit = sa propre définition + une référence-commentaire dans `confidence_score_card.dart` | **Façade-sans-câblage, NEVER #6 violation** |
| `AujourdhuiScreen` n'importe ni FinancialPlanCard, ni ConfidenceScoreCard, ni FinancialPlanProvider | [apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart:12-30](apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart) — imports actuels = CapDuJourBanner, CommitmentsAndCheckinsCard, CleoLoopIndicator, TensionCardWidget, MonthHeaderWidget, TimelineNodeWidget | Pure dead code à câbler |

### Conséquence sur la décision

La synthèse précédente a sauté l'étape « grep avant proposer » (CLAUDE.md NEVER #6). En conséquence :

- **Option B (drawer entry MyPlanScreen, 0.5j) : REJETÉE.** Construire ce screen serait un duplicate de FinancialPlanCard, plus 16 clés ARB redondantes × 6 langs, plus une route nouvelle. Karpathy #2 simplicity-first viole.
- **Option B' (corrected) : ADOPTÉE.** Wire l'existant `FinancialPlanCard` + `ConfidenceScoreCard` dans `AujourdhuiScreen`, conditionnel sur `context.watch<FinancialPlanProvider>().hasPlan`. Placement = entre `CapDuJourBanner` et `CommitmentsAndCheckinsCard` (cohérent avec la docstring du widget : « between Section 1 (ChiffreVivant) and Section 2 (ItineraireAlternatif) »).
- **Effort réel : ~0.2j.** Add 3 imports + 1 Consumer/Selector wrapper + 2 Sliver inserts + recalculate-prompt callback (route vers `/coach/chat?prefill=...` si pas déjà câblé). + run `flutter analyze` + `flutter test` + golden Julien/Lauren.
- **Tests existants à vérifier** : `find apps/mobile/test -name "*financial_plan_card*"` retourne 0 — pas de widget tests aujourd'hui. Phase 26 wiring → ajouter 3 widget tests (rendu avec plan, rendu vide, rendu stale).
- **ROADMAP_V2 fix** : lignes 63 + 182 disent encore « 4-tab shell (Aujourd'hui/Coach/Explorer/Dossier) ». Fix doc en 5 min : remplacer « Dossier » par « Mon argent » pour matcher mint_shell.dart. Pas de category error VZ à éviter parce que la 4e tab Dossier n'existe ni dans le code ni dans l'UX réelle.

### Décision révisée (Critical PM, anti-sycophancy)

1. **WIRE** `FinancialPlanCard` + `ConfidenceScoreCard` dans `AujourdhuiScreen`, conditionnel `hasPlan` (~0.2j + 3 widget tests).
2. **FIX DOC** ROADMAP_V2.md:63 + 182 — remplacer « Dossier » par « Mon argent ». Le « rename Dossier → Mon plan » de la synthèse devient sans objet : il n'y a aucun rename à propager (pas de tab, pas de string user-visible « Dossier ») hors roadmap.
3. **VETO confirmé** sur la 4e tab Dossier full (toujours valide : empty state + facade risk + drift LSFin).
4. **SKIP** event sourcing seed (PlanEvent Hive append-only) — Karpathy #2 simplicity-first reste, et le wiring ci-dessus n'introduit AUCUN nouveau modèle.
5. **DEFER** archetype-specific wiring (CommitmentDevice / PreMortemEntry / ArbitrageHistory côté mobile) à un perimeter dédié POST-TestFlight. Aujourd'hui : 0/8 archétypes câblés, pas 5/8 — faut être honnête.

### Sim survival test (per CLAUDE.md §9.4)

Si Julien ouvre la sim après le wiring :
- User avec plan généré : il voit la card sur Aujourd'hui entre Cap du jour et Commitments. Hero CHF/mois, 4 milestones, confidence bands, disclaimer LSFin, badge stale si profil changé. Survie ✅.
- User sans plan : la card est hidden via `hasPlan` gate, pas d'empty state intrusive. Survie ✅.
- User déjà sur Aujourd'hui aujourd'hui : voit la même chose qu'avant + nouvelle card si plan existe. Pas de régression. Survie ✅.

### Scope deferred — perimeter à ouvrir si Phase 2 commit au full Dossier

- Wire CommitmentDevice côté mobile (model + provider + service) → 8 archétypes, pas 0
- Wire PreMortemEntry idem
- Wire ArbitrageHistory idem
- Construire alors un Dossier hub qui agrège ces 4 streams (FinancialPlan + Commitment + PreMortem + Arbitrage) — décider drawer vs tab à ce moment, pas avant
- Réévaluer compliance LSFin (drift régulatoire 6-data) une fois qu'il y a vraiment 6 streams agrégés

### Counter-arguments and data gaps (post-vérif)

- **« Wire 0.2j est trop minime pour passer office-hours »** : exact, le geste minimum est ce qu'il faut (Karpathy #2). Le travail réel d'office-hours était de DÉCOUVRIR que le drawer est inutile, pas d'écrire un design doc complexe. Anti-sycophancy : le rapport de la valeur fournie n'est pas le volume de markdown, c'est le code que tu n'écris PAS.
- **« Pourquoi FinancialPlanCard n'a-t-il jamais été câblé ? »** : data gap. Probablement Phase 26 (le commentaire dit « Phase 4 — no check-ins yet ») a livré les widgets sans wiring final, ou un revert. À investiguer dans `git log -- apps/mobile/lib/widgets/home/financial_plan_card.dart` mais hors scope office-hours.
- **« Si on wire, ça change la hauteur de Aujourd'hui — golden screenshots ? »** : oui, golden Julien (swiss_native) + Lauren (expat_us) existants vont casser. Update goldens dans le même PR. Walker rebaseline post-merge.
- **« Recalculate CTA pré-rempli i18n + Threat T-04-10 »** : la docstring de `FinancialPlanCard` cite déjà « Threat T-04-10 : "Recalculer" passes a pre-formatted i18n prompt via [onRecalculate] ; the user must explicitly tap Send in the coach. » Le wiring doit garder ce contrat : `onRecalculate: (prompt) => context.go('/coach/chat?prefill=$prompt')` ou équivalent — vérifier si la route accepte un prefill query param.
- **Empty state pour 85-95% sans plan** : le `hasPlan` gate hide la card entièrement. Pas d'« onglet vide » qui dégrade le trust. Le risque empty-state qu'OH-6 utilisait pour vetoer la 4e tab est neutralisé par le wiring conditionnel.
- **Ranking / scoring** : le widget n'affiche aucun ranking, aucun pourcentage de progrès vivant (le 0% est hardcoded car « Phase 4 : no check-ins yet »). LSFin safe-zone respectée.
- **Banned-terms** : ARB keys déjà passées par le lint `accent_lint_fr.py` + `no_hardcoded_fr.py` au commit. Re-vérifier `tools/checks/banned_terms_arb.py` sur les 16 keys × 6 langs avant push.

### Approval gate — révisé

**Recommandation finale (Critical PM, anti-sycophancy enforced)** :

1. ✅ **GO** : wire FinancialPlanCard + ConfidenceScoreCard dans AujourdhuiScreen (~0.2j + 3 widget tests + golden updates).
2. ✅ **GO** : fix ROADMAP_V2.md:63 + 182 (« Dossier » → « Mon argent ») — 5 min.
3. ❌ **NO** au drawer entry MyPlanScreen (duplicate).
4. ❌ **NO** au 4e tab Dossier full (veto confirmé).
5. ❌ **NO** au event sourcing PlanEvent seed (Karpathy #2).
6. ⏸️ **DEFER** archetype-specific commitments/pre-mortems/arbitrage à perimeter dédié post-TestFlight.

**Status** : décision Proposed → ready for execution gate. Prochain artefact : un perimeter MVP-PERIMETER ou phase GSD micro pour le wiring (préfère perimeter 5-gate per memory `feedback_perimeter_5_gates.md`). NE PAS ouvrir de PLAN GSD theater pour 0.2j de wiring.

### Citations 0-Trust (per CLAUDE.md §9.6)

```
Evidence — FinancialPlanCard exists but unwired :
  apps/mobile/lib/widgets/home/financial_plan_card.dart:32 (class definition)
  grep "FinancialPlanCard" apps/mobile/lib/ → 0 hits outside its own file
Evidence — ConfidenceScoreCard exists, planned below FinancialPlanCard :
  apps/mobile/lib/widgets/home/confidence_score_card.dart:14
Evidence — FinancialPlanProvider in MultiProvider tree :
  apps/mobile/lib/app.dart:1508
Evidence — 16 ARB planCard_* keys × 6 langs :
  apps/mobile/lib/l10n/app_{de,en,es,fr,it,pt}.arb (grep -c planCard = 16 each)
Evidence — AujourdhuiScreen does NOT import FinancialPlanCard :
  apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart:12-30 (no FinancialPlan import)
Evidence — mint_shell has 4 tabs Aujourd'hui/MonArgent/Coach/Explorer (no Dossier) :
  apps/mobile/lib/widgets/mint_shell.dart:46-67
Evidence — ROADMAP_V2 contradicts code on tab 4 :
  docs/ROADMAP_V2.md:63 + 182 say « Dossier » ; mint_shell.dart says « Mon argent »

Caveat — what I have NOT checked :
  - git log of FinancialPlanCard (when/why it was left unwired — not in office-hours scope)
  - whether /coach/chat route accepts a prefill query param for recalculate CTA
  - whether widget tests exist (find returned 0 hits — to verify before wiring)
  - whether golden screenshots will need rebaseline (probable, not yet run)
  - sim run post-wiring (not done — wiring not yet implemented, this is decision-stage only)
```
