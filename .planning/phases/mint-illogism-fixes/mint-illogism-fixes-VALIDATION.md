---
phase: mint-illogism-fixes
slug: mint-illogism-fixes
status: planned
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-11
updated: 2026-06-11
---

# Phase mint-illogism-fixes — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (mobile) + Maestro 2.5.1 (device flows) + oracles Python (matrice) |
| **Config file** | `apps/mobile/pubspec.yaml` (existing — no Wave 0 install) |
| **Quick run command** | `cd apps/mobile && flutter test test/services/ test/models/` (sites touchés) |
| **Full suite command** | `cd apps/mobile && flutter analyze && flutter test` |
| **Estimated runtime** | quick ~120 s · full ~600 s |

---

## Sampling Rate

- **After every task commit:** Run quick command + l'oracle de reproduction des lignes de matrice fermées par la tâche
- **After every plan wave:** Full suite + lints (`accent_lint_fr`, `validate_arb_parity`, `check_banned_terms`) + sim walkthrough (build workaround `/tmp/mint_build_ios`)
- **Before `/gsd:verify-work`:** Full suite green + flows Maestro `bug__ILLOG01/02` au statut attendu de la vague + lignes fermées citées dans les SUMMARYs
- **Max feedback latency:** 600 s

---

## Per-Task Verification Map

> Rempli par gsd-planner 2026-06-11. Oracle = la reproduction de la ligne matrice re-run ;
> parité = `financial_parity_test.dart` ; maestro = flows régression. PT = test de parité.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-T1 | 01 | 1 | MATRIX-salarie_swiss-1, cadre_divorce_hypo-2, returning_swiss_gaps-3/-4, jeune_diplome-1 | T-ILF-01-01 | parité avoir LPP au centime | parity (RED Wave 0) | `cd apps/mobile && flutter test test/services/financial_parity_test.dart` | ❌ W0 | ⬜ pending |
| 01-T2 | 01 | 1 | MATRIX-independent_no_lpp-4, expat_us-3, frontalier-2/-5, couple_acheteurs-2 | T-ILF-01-01 | clamp 64260 + 1.25% partout | parity+oracle | `cd apps/mobile && flutter test test/services/financial_parity_test.dart && flutter analyze` | ❌ W0 | ⬜ pending |
| 02-T1 | 02 | 2 | MATRIX-salarie_swiss-4, independent_no_lpp-5, expat_us-4, frontalier-3, cadre_divorce_hypo-3, couple_acheteurs-3, returning_swiss_gaps-5, D4 | T-ILF-02-01 | un taux de conversion par cas | parity+oracle+panel | `cd apps/mobile && flutter test test/services/financial_parity_test.dart` | ❌ W0 | ⬜ pending |
| 02-T2 | 02 | 2 | MATRIX-§2-rachat | T-ILF-02-01 | impact rachat base unique | parity | `cd apps/mobile && flutter test test/services/` | ❌ W0 | ⬜ pending |
| 03-T1 | 03 | 3 | MATRIX-salarie_swiss-5, independent_no_lpp-6, expat_us-5, frontalier-4, cadre_divorce_hypo-4, jeune_diplome-3, couple_acheteurs-4, returning_swiss_gaps-6, D3, §2-retraite | T-ILF-03-01 | dénominateur NET unique | parity+oracle | `cd apps/mobile && flutter test test/services/financial_parity_test.dart` | ✅ replacement_rate.dart | ✅ done (206bb7c02) — parité W3 18/18, analyze clean |
| 03-T2 | 03 | 3 | MATRIX-§2-marge-libre | T-ILF-03-01 | net via NetIncomeBreakdown partout | parity | `cd apps/mobile && flutter test test/services/` | ✅ groupe « Base nette » | ✅ done (b4a41718c) — services 5836/5836, analyze clean |
| 04-T1 | 04 | 4 | MATRIX-independent_no_lpp-1/-2 | T-ILF-04-01 | plafond indépendant base NET | parity+oracle | `cd apps/mobile && flutter test test/services/financial_parity_test.dart` | ✅ groupe « Plafond 3a indépendant » (4 cas) | ✅ done (37a6221ad) — parité W4 22/22, services 5840/5840, analyze clean |
| 05-T1 | 05 | 5 | MATRIX-salarie_swiss-2/-3 | T-ILF-05-01 | isMarried transmis | parity+oracle | `cd apps/mobile && flutter test test/services/financial_parity_test.dart` | ✅ groupe « Économie 3a (marié) » (4 cas) | ✅ done (d0a852d18) — parité W5 4/4, W1-W5 26/26, services 5844/5844, analyze clean |
| 05-T2 | 05 | 5 | W1 device-proof | — | valeurs uniques à l'écran | sim walkthrough | `ls .planning/_walker/illogism-fixes/w1/*.png` | ⬜ README repro | ⏳ DEFERRED-TO-ORCHESTRATOR (d755c06af) — build iOS impossible depuis worktree isolé ; repro `.planning/_walker/illogism-fixes/w1/README.md` |
| 06-T1 | 06 | 6 | MATRIX-D1 | T-ILF-06-01 | q_* via SecureWizardStore, zéro log | widget | `cd apps/mobile && flutter test test/screens/` | ❌ | ⬜ pending |
| 06-T2 | 06 | 6 | MATRIX-D1 | T-ILF-06-01 | grep-gate zéro log/analytics sur q_* | widget+lint+panel | `cd apps/mobile && flutter test && python3 tools/checks/accent_lint_fr.py` | ❌ | ⬜ pending |
| 07-T1 | 07 | 7 | MATRIX-independent_no_lpp-3 | T-ILF-07-01 | prédicat LPP=0 unique | parity+oracle | `cd apps/mobile && flutter test test/services/financial_parity_test.dart` | ✅ archetype_predicates.dart + groupe « Gates LPP » (3 cas) | ✅ done (a2b15b16a) — parité 29/29, analyze lib clean, ArchetypePredicates câblé dans les 2 moteurs |
| 07-T2 | 07 | 7 | MATRIX-cadre_divorce_hypo-1 | T-ILF-07-01 | divorcé jamais estimé | parity+oracle | `cd apps/mobile && flutter test` | ✅ groupe « Gate divorce » (4 cas) + lppEstimationBlocked + ARB ×6 | ✅ done (c1581d227) — parité 33/33, services 5851/5851, models 277/277, analyze lib clean, ARB parity 6903 keys, banned-terms clean |
| 08-T1 | 08 | 8 | MATRIX-expat_us-1 | T-ILF-08-01 | gate FATCA global, pas de bypass | widget (redirect) | `cd apps/mobile && flutter test test/screens/fatca_gate_test.dart` | ✅ archetype_route_gate.dart + fatca_gate_test.dart (7 cas) ; branche dans app.dart redirect authenticated | ✅ done (a931b6a0a) — fatca_gate 7/7, analyze clean, coach point-defense conservé (defense-in-depth) |
| 08-T2 | 08 | 8 | MATRIX-expat_us-2, frontalier-1 | T-ILF-08-02 | compute archétype-aware | parity+oracle+sim | `cd apps/mobile && flutter test && flutter analyze` | ✅ ArchetypePredicates.canContribute3a (SoT unique) + compute() canContribute3a + groupe « W6 Éligibilité 3a » (6 cas) | ✅ done (eeffec4ae) — parité 39/39, suite 9368 pass/0 fail, analyze clean ; **sim W2 device-proof déféré à l'orchestrateur** (worktree build constraint) |
| 09-T1 | 09 | 7 | MATRIX-D6 (diagnostic) | T-ILF-09-01 | cause racine citée file:line + RED reproductible | semantics (RED) | `cd apps/mobile && flutter test test/screens/rente_vs_capital_semantics_test.dart` | ✅ test/screens/rente_vs_capital_semantics_test.dart (2 cas) — RED reproduit le contrat de bord (identifier sur la feuille du titre, pas un conteneur ancêtre du body) | ✅ done (3405f83e7) — cause racine = identifier sur SliverAppBar title leaf, pas de `Semantics(container, explicitChildNodes)` screen-root (cf. mon_argent / budget) ; arbre Dart sain, collapse iOS-bridge |
| 09-T2 | 09 | 7 | MATRIX-D6 | T-ILF-09-01 | arbre AX peuplé | semantics+maestro+panel | `maestro test tools/simulator/flows/regression/bug__ILLOG02__rvc_ax_tree_empty.yaml` | ✅ 2 tests semantics + 27 smoke arbitrage green ; **maestro EXIT 0 WARM + COLD (iPhone 16e, iOS 26.2)** ; `idb describe-all` 29 éléments (était 1) | ✅ done (15a877bc6 + fcfa53c7d) — screen-root Semantics(container, explicitChildNodes) + per-field Semantics(container, label)+ExcludeSemantics ; flow regex `\(CHF\)` (Rule-1) ; analyze 0 issue ; aucun ARB modifié |
| 10-T1 | 10 | 8 | MATRIX-D5 | T-ILF-10-01 | fiction ≠ réel | widget | `cd apps/mobile && flutter test test/screens/rente_vs_capital_defaults_test.dart` | ✅ 4 cas (état vide sans profil ; certificat 500000/150000/37000 supprimés ; prefill estimé préservé) + 27 smoke arbitrage green | ✅ done (4068ba429 RED + 45963a677 GREEN) — contrôleurs vides + `_hasUsableInputs` guard + `_buildEmptyStateHint` (`renteVsCapitalEmptyState` ×6 ARB) ; survivants 6.8/5.0 = minima LPP statutaires ; analyze 0 issue ; parité ARB 6/6 ; accents FR clean |
| 10-T2 | 10 | 8 | MATRIX-D5 / ILLOG-01 | T-ILF-10-01 | flow gate | maestro | `maestro test tools/simulator/flows/regression/bug__ILLOG01__rvc_fiction_defaults.yaml` | ✅ **EXIT 0 COLD (post-reboot) + WARM** (iPhone 16e, iOS 26.2) — `350000`+`100000` NOT visible ; `bug__ILLOG02` EXIT 0 (non-régression) ; capture `.planning/_walker/illogism-fixes/w3/w3-rvc-empty-state.png` | ✅ done (45963a677) — D5 + ILLOG-01 fermés ; idb describe-all montre l'état vide « Complète ton profil… » + 0 fiction ; panel design 4-lentilles PASS |
| 11-T1 | 11 | 9 | MATRIX-D12 | T-ILF-11-02 | une source de confiance | unit | `cd apps/mobile && flutter test test/services/` | ✅ test/services/confidence/confidence_source_unification_test.dart (3 cas) | ✅ done (43f32b713 RED + e37c67ce5 GREEN) — racine 44/50/30 = 3 moteurs (ConfidenceScorer.scoreEnhanced.combined 44 ; ArbitrageEngine._computeArbitrageConfidence 50 floor ; ConfidenceBreakdown.overall orphelin). RvC reçoit canonicalConfidence (= EnhancedConfidence.combined) ; plancher 50.0 retiré → inversion fiction>réel fermée ; financial_core 577/577, confidence 17/17, analyze clean |
| 11-T2 | 11 | 9 | MATRIX-D2, jeune_diplome-5 | T-ILF-11-01 | hero gated <50, tag estimé | widget+sim | `cd apps/mobile && flutter test test/widgets/home_hero_confidence_test.dart` | ✅ home_hero_confidence_test.dart (4 cas, 3 états + rétro-compat) | ✅ done (ad2e4c86e RED + fe676d0f2 GREEN) — ChatFactCard FactConfidenceState (known/estimated/gated) appliquant SOT §5 ; câblé sur EnhancedConfidence.combined dans widget_renderer._buildFactCard ; liquidité estimée taguée (jeune_diplome-5) ; 5 clés ARB ×6 (parité 6909, banned-terms clean, accents FR clean) ; **sim W3 device-proof déféré à l'orchestrateur** (worktree .nosync build constraint, cf. 05/06/07/08) |
| 12-T1 | 12 | 10 | MATRIX-cadre_divorce_hypo-5 | T-ILF-12-01 | split borné mariage | unit+oracle | `cd apps/mobile && flutter test test/services/life_events_divorce_test.dart` | ✅ life_events_divorce_test.dart (5 cas : transfert=68125 plus jamais 168125 ; null→incomplet ; clamp 0) | ✅ done (ac7b1efc7 RED + b142e235a GREEN) — acquis_i = max(0, avoir actuel − avoir au mariage) ; transfert = (acquis1−acquis2)/2 ; DivorceInput.avoirAuMariage1/2 + LppSplitResult.acquisConjoint1/2/isIncomplete ; commentaire CC 122/LFLP 22a ; 46/46 verts, analyze clean ; grep total-split → vide |
| 12-T2 | 12 | 10 | MATRIX-cadre_divorce_hypo-5 | T-ILF-12-02 | avoir au mariage demandé | widget+panel | `cd apps/mobile && flutter test && python3 tools/checks/accent_lint_fr.py` | ✅ divorce_simulator_screen_test.dart (2 cas : champ présent + état donnée requise) | ✅ done (86d6d7b1a RED + 21d791005 GREEN) — 2 champs « avoir au mariage » câblés ; LPP card état incomplet ; pré-fill gated isLppFromCertificate ; 4 clés ARB ×6 + gen-l10n ; screens 877/877, services 5870/5870, analyze lib clean ; ARB parité 6914, banned-terms clean, accents FR exit 0 ; panel 4-lentilles inline PASS ; **device-proof w4/ déféré orchestrateur** (NO_BOOTED_SIM + worktree .nosync) |
| 13-T1 | 13 | 11 | MATRIX-returning_swiss_gaps-1, §2-AVS | T-ILF-13-01 | lacunes plumbées | parity+oracle | `cd apps/mobile && flutter test test/services/financial_parity_test.dart` | ✅ test/services/financial_parity_test.dart « Parity W4 — Rente AVS » (4 cas) | ✅ done (e201cf8d6) — minimal_profile plumbe arrivalAge/lacunes/anneesContribuees à AvsCalculator (gapFactor honoré, fin de 2520 forcé) ; coach_profile_provider dérive avant l'appel ; cap_sequence._estimateAvsMonthly délègue à AvsCalculator (suppr. formule plate 2520×years/44, seul littéral restant en commentaire ligne 612) ; parity 43/43, analyze 4 fichiers clean, accents FR exit 0 |
| 13-T2 | 13 | 11 | MATRIX-returning_swiss_gaps-2, jeune_diplome-2 | T-ILF-13-01 | scène honnête + hypothèse | widget+sim+panel | `cd apps/mobile && flutter test && flutter analyze` | ✅ test/screens/onboarding/mvp_wedge_storyboard_test.dart « W4 — Scène rente_trouée honnête » (3 cas) | ✅ done (d85263019) — scène AVS via AvsCalculator AVEC arrivalAge/lacunes + LPP via LppCalculator.projectToRetirement (suppr. forfait 0.34, seuls commentaires restants) ; étiquette « hypothèse : carrière complète » (gapFactor=1.0 ET âge<30) ; provider getters avsArrivalAge/avsGaps (même dérivation que CoachProfile.fromWizardAnswers) ; ARB ×6 onboardingSceneFullCareerAssumption + gen-l10n (parité 6915) ; storyboard 61/61, analyze full clean, accents FR exit 0, banned-terms ARB clean ; **device-proof w4/ + panel design déférés orchestrateur** (NO_BOOTED_SIM, précédent W1) |
| 14-T1 | 14 | 12 | MATRIX-D10 (diagnostic) | T-ILF-14-01 | — | grep/diagnostic | `grep -rn "marge" apps/mobile/lib/services/budget_living_engine.dart` | ✅ | ✅ done — site réel = `context_injector_service.dart:331` (BUDGET VIVANT injecte « Marge libre 1541/mois » sans plafond → LLM dérive « verser 1541 en 3a » ≈ 2.55× le plafond 7258). Cap 2 « 3a_max » de budget_living_engine plafonnait déjà ; les openers budgetRoom/savingsOpportunity/deadlineUrgency aussi. Le trou = l'injection brute de la marge libre |
| 14-T2 | 14 | 12 | MATRIX-D10 | T-ILF-14-01 | suggestion ≤ plafond restant | unit+oracle+sim | `cd apps/mobile && flutter test test/services/suggestion_3a_cap_test.dart` | ✅ suggestion_3a_cap_test.dart (8 cas) | ✅ done (24688cc9f RED + 1f4318519 GREEN) — `BudgetLivingEngine.cappedMonthly3aSuggestion = min(margeDisponible, plafondRestant/moisRestants)` via `Pillar3aRoomCalculator.remainingAnnualRoom` (archétype-aware, net-base indépendant plan 04, FATCA-gated 0 plan 08) ; room 0 → 0 (US person / plafond atteint = AUCUNE suggestion) ; câblé dans le bloc BUDGET VIVANT du context injector ; 8/8 verts, services 5882/5882, analyze clean, accents FR exit 0, banned-terms clean ; **device-proof sim w4/ déféré orchestrateur** (NO_BOOTED_SIM + worktree .nosync build constraint, précédent W1-W4) |
| 15-T1 | 15 | 12 | MATRIX-couple_acheteurs-1 | T-ILF-15-01 | revenu ménage unique | widget+oracle+panel | `cd apps/mobile && flutter test test/screens/affordability_prefill_test.dart` | ❌ | ⬜ pending |
| 15-T2 | 15 | 12 | MATRIX-W4-citation-LCC | T-ILF-15-02 | citation vérifiée | grep+pytest | `grep -c "LCC" services/backend/app/api/v1/endpoints/lucidity.py` | ✅ | ⬜ pending |
| 16-T1 | 16 | 13 | MATRIX-D7/D8 (diagnostic) | T-ILF-16-01 | — | diagnostic | `grep -n "Provider" apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart` | ✅ | ✅ done — D7 racine = prédicat d'état vide `(!hasProfile \|\| _projection == null)` (retirement_dashboard_screen.dart:374) confond « pas de profil » et « projection échouée » : le dashboard lit DÉJÀ le MÊME `CoachProfileProvider` que /home (lignes 113, 372), donc un profil hydraté (avoir LPP affiché par /home) + `_projection==null` (catch ligne 156) retombe en State C → « 4 infos suffisent » (dashboardQuickStartBody, app_fr.arb:669). D8 racine = CTA `_buildOnboardingHero` → `context.go('/coach/chat')` (ligne 946, home coach sans formulaire) ; cible vivante = `/onb` → OnboardingShellScreen (app.dart:354-356, steps age/canton/revenue) |
| 16-T2 | 16 | 13 | MATRIX-D7, D8 | T-ILF-16-01/-02 | source unique + CTA vivant | widget+sim+panel | `cd apps/mobile && flutter test test/screens/retirement_dashboard_profile_test.dart` | ✅ retirement_dashboard_profile_test.dart (3 cas : profil hydraté → pas d'état vide ; profil vide → état vide ; tap CTA → /onb avec champ de saisie) | ✅ done (0216687b7 RED + 25f392057 GREEN) — D7 : State C onboarding ne s'affiche QUE si `!hasProfile` ; profil hydraté + projection échouée → `_buildProjectionUnavailable` (retry + Mes données), plus jamais l'onboarding trompeur. D8 : CTA `Key('state_c_start_cta')` → `context.go('/onb')`. 2 clés ARB ×6 (dashboardProjectionUnavailable{Title,Body}) + gen-l10n ; tests 3/3 + 5 existants, analyze 2 fichiers clean, ARB parité 6919, banned-terms clean, accents FR exit 0 ; **device-proof sim w5/ + panel design déférés orchestrateur** (worktree .nosync build constraint, précédent W1-W4) |
| 17-T1 | 17 | 14 | MATRIX-D9 | T-ILF-17-01 | hypothèses what-if étiquetées | widget+sim+panel | `cd apps/mobile && flutter test test/screens/mariage_whatif_labels_test.dart` | ❌ | ⬜ pending |
| 17-T2 | 17 | 14 | MATRIX-D11, i18n hardcode + clôture phase | T-ILF-17-02 | labels localisés | grep+maestro+sim D1-D12+panel | `cd apps/mobile && flutter gen-l10n && flutter analyze && flutter test` | ❌ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `apps/mobile/test/services/financial_parity_test.dart` — squelette des tests de parité W1 (Plan 01 Task 1 — une quantité = tous chemins d'appel = même valeur)
- [ ] Re-run baseline des oracles de la matrice (état RED documenté avant fix — Plan 01 Task 1 commit message)
- [x] Flows Maestro `bug__ILLOG01/02` RED confirmés sur build courant (fait 2026-06-11, run ~/.maestro/tests/2026-06-11_065259)

## Couverture des 44 findings + D1-D12 (audit planner)

- **Plans 01-05 (W1)** : 27 DIVERGENT (avoir LPP, rente/conversion, remplacement, plafond 3a, économie 3a) + §2 marge-libre/rachat/AVS-composition/retraite-composition par extension de cause racine.
- **Plans 06-08 (W2)** : 10 ILLOGICAL_FOR_ARCHETYPE (D1 racine, gates LPP=0/divorcé/frontalier/FATCA).
- **Plans 09-11 (W3+ILLOG02)** : D2, D5, D6, D12, jeune_diplome-5, flows ILLOG01/02.
- **Plans 12-15 (W4)** : cadre_divorce_hypo-5, returning_swiss_gaps-1/-2, jeune_diplome-2, D10, couple_acheteurs-1, citation LCC.
- **Plans 16-17 (W5)** : D7, D8, D9, D11, i18n hardcode.
- **SOURCED (5, contrôles négatifs)** : salarie_swiss-6, cadre_divorce_hypo-6, jeune_diplome-1, jeune_diplome-4, couple_acheteurs-5 — anti-régression encodée dans les tests de parité (plans 01, 04, 15).
- **§1 doublons d'écrans** : hors scope phase (observations, pas dans les 44 — CONTEXT boundary).
