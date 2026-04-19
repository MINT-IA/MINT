# MINT Roadmap — Daily Compagnon (2026-04-18)

## Contexte

Session autonome 2026-04-18. 5 panels d'experts ont audité MINT :
1. **Panel UX** (verdict Wave 11 REWORK) — cliché Cleo/Monzo, viole chat-silent, inverse loop Cleo 3.0
2. **Panel Architecture** (verdict Wave 11 REWORK) — duplication Python/Dart, prompt cache wipe, agent loop amnesia
3. **Panel Contrarien** — thèse "MINT événementiel, pas daily" (contestée par Julien, daily tranché)
4. **Panel Daily-loop** — 80% du code existe, 5 call-sites dormants
5. **Panel Codebase inventory** — 14 CustomPainters, 25+ simulateurs, 18 life events, FRI shadow mode
6. **Panel Simulation 3 mois** — friction concrète, Julien revient ~20-25% seul post-J+30
7. **Panel Perfection Gap** — 60 findings (10 P0 top + 22 P0 correctness + 28 P1 + 10 P2)

## Doctrine (tranchée par Julien)

1. **Daily compagnon** — pas événementiel. MINT aiguille en continu.
2. **Zéro feature nouvelle** — câbler ce qui est codé, finir ce qui est posé, sortir du shadow ce qui est caché.
3. **Zéro dette tolérée** — chaque Wave production-ready avant la suivante.
4. **Preuve par device** — chaque Wave se termine walkthrough iPhone 17 Pro + AX tree.
5. **Source légale ou magic number = P0 explicite**.

## Les 5 call-sites dormants (source : Panel Daily-loop)

1. `NotificationService.scheduleCoachingReminders(profile)` on profile-ready — API 895 lignes, seul `.init()` appelé
2. `CapEngine.compute(profile)` dans `aujourdhui_screen.dart` — 1334 lignes, seul caller `budget_screen.dart:179`
3. `JitaiNudgeService.evaluateNudges(profile)` — 10 triggers JITAI, 0 consumer
4. `MilestoneDetectionService.detectNew()` post-scan/checkin — 0 consumer
5. `scheduleRetentionNotifications(taxSaving3a)` à la fin onboarding avec vraie valeur — null silent fail

## Les 6 Waves séquentielles

### Wave A — Câblage dormant (4-6h, 1 PR)

Goal : transformer MINT d'app-musée à compagnon qui aiguille. Branche les 5 moteurs + 3 prerequis P0 du panel 7.

Commits cibles :
- A1: Scan LPP → `CoachInsight` event save (panel simulation, finding doc_impact)
- A2: `scheduleCoachingReminders(profile)` wired on profile-ready + onboarding completion
- A3: `scheduleRetentionNotifications` taxSaving3a null fallback fixé + J+30 dedup si already-scanned
- A4: Post-J+30 cliff tué — `scheduleCheckinReminder` wired weekly lundi 19h
- A5: `save_fact` PII log redaction (Panel 7 P0 #2) — CLAUDE.md §6.7 violation
- A6: `profile.age == 0` sentinel guards (Panel 7 P0 #7) — 5 écrans consumers
- A7: Double `weekly_recap_service.dart` consolidation (Panel 7 P0 #10) — 1 source of truth

Gate sortie A : notification J+1 arrive (device), payload deep-link coach, coach injecte event memory scan. Tests + CI green. Device walkthrough iPhone 17 Pro sim.

### Wave B — Home "Aujourd'hui" orchestrateur (6-8h, 1 PR)

Goal : AujourdhuiScreen devient fil conducteur dynamique avec CapEngine + JITAI + Milestones + WeeklyRecap + Streak.

Commits cibles :
- B1: `CapEngine.compute(profile)` dans aujourdhui_screen — 1 cap du jour banner top
- B2: `JitaiNudgeService.evaluateNudges` → widget banner secondaire contextuel
- B3: `MilestoneDetectionService.detectNew()` post-scan/checkin trigger celebration_sheet
- B4: `WeeklyRecapService` widget lundi matin + notification cross-wire
- B5: `StreakService` streak 0-30j affiché compact sans pression
- B6: Golden test assemblage dynamique Aujourd'hui pour 4 profils (debt-critical, swiss-native-fat3a, expat-us, new-indep)
- B7: Cleanup orphan providers (Panel 7 P0 #4) — UserActivityProvider, ContextualCardProvider, CoachEntryPayloadProvider

Gate sortie B : home Julien J+8 affiche cap "ton 3a pas au max, 90j restants, +5'758 CHF possibles", nudge "Lauren sans 3a — double fiscalité couple", 7j streak, recap semaine dernière.

### Wave C — Continuité scan + coach handoff (4-6h, 1 PR)

Goal : scan n'est plus acte isolé, suggestion chips étendues, landing skip, memory retry.

Commits cibles :
- C1: Post-scan auto-route coach avec opener contextuel "On a lu ton certificat CPE. Voici ce que ça change."
- C2: Suggestion-chip regex étendu — tous 18 life events (naissance, divorce, mariage, emploi, perte emploi, donation, déménagement, invalidité, indépendant, EPL, décès, concubinage)
- C3: Memory timeout 2s → retry 1× back-off 500ms avant fallback silencieux
- C4: Landing skip si `onboarded=true` → `initialLocation: '/home'`
- C5: Onboarding questionnaire minimal 3 inputs (age, canton, revenu) avant landing CTA OU ADR si confirme no-onboarding

Gate sortie C : Julien scanne, est amené au coach qui contextualise. Naissance/divorce chips visibles en chat. Cold restart n'replays pas landing. Memory injection robuste sur réseau flaky.

### Wave D — FRI visible + narrative couple/FATCA (6-8h, 1 PR)

Goal : 2 plus gros assets cachés de MINT deviennent visibles.

Commits cibles :
- D1: `fri_calculator.dart` sort shadow mode — `MintScoreGauge` sur home "Ton indice de résilience financière : 62/100" + drill-down 4 axes L/F/R/S
- D2: Backend system prompt — si `profile.conjoint.archetype == expat_us` ET question rachat/3a/succession, injecter paragraphe asymétrie couple (LFLP, FATCA, IRC §1291)
- D3: ScreenRegistry — rachat_lpp / pillar_3a_overview / lpp_buyback prefill enrichi `conjoint` archetype
- D4: `_buildFactCard` enrichi — source légale + "écart vs ce que ta caisse dirait" quand `ArbitrageSummaryItem.fullResult.advisorDelta` dispo
- D5: Tests narratif couple — 5 questions Julien+Lauren → assert Lauren + FATCA + archétype mentionnés

Gate sortie D : Julien demande "rachat 50k LPP", coach dit "Vu que Lauren est US, ce rachat ne profite qu'à toi. Ta caisse CPE te dirait 'fais-le', la loi dit 'attends 3 ans pour anti-abus'. Écart: CHF 12'000 éco fiscale vs CHF 0 si revente avant 3 ans."

### Wave E — Perfection Gap (8-12h, 1 PR)

Goal : fermer les 60 findings Panel 7 non traités en Waves A-D. Zéro dette résiduelle.

Commits cibles (groupés par type de dette) :
- E1: `resolveCanton()` migration — 26 call-sites (finding #1) passent par helper, UI surface fallback
- E2: `coach_narrative_service.dart:264,932` — `renteFromRAMD` → `computeMonthlyRente` avec contributionYears (finding #3)
- E3: `mariage_screen.dart:94` hardcode 0.068 → `lppTauxConversionMinDecimal` + fix `* 12` ignore `nombreDeMois` (finding #5)
- E4: Archived routes cleanup — `/coach/cockpit`, `/tools`, `/ask-mint` call-sites réécrits vers canoniques (findings #6, #31, #32, #33, #37)
- E5: `save_partner_estimate` fire-and-forget → Future + error surface (finding #8, #19)
- E6: 5 orphan services decision — delete `AdaptiveChallengeService`, `CommunityChallengeService`, `AffiliateService`, `CoupleQuestionGenerator`. `JitaiNudgeService` wired en Wave B (finding #9)
- E7: Sentinels `-1` quota, `'unknown'` canton, `'unknown'` string → typed enums / nullable (findings #11, #12)
- E8: Hardcoded magic numbers — mortgage 0.015 (finding #27, #29), tax fallback 0.12 (finding #28), bayesian 0.05 (finding #21), SWR 0.04 (finding #58), life expectancy 87 (finding #59), inflation 0.015 (finding #60) — centralize or ADR with source
- E9: i18n holes — `widget_renderer.dart` 6+ strings FR (finding #14), `education_content.dart:52` literal (finding #54)
- E10: Compliance parity — mobile `ComplianceGuard` add gerund + IT/ES/PT (findings #17, #46)
- E11: Silent `catch (_) {}` — 24 blocks add debugPrint + sentry breadcrumb (finding #18)
- E12: Vestigial `financial_report_screen_v2.dart` rename → `financial_report_screen.dart` (finding #23)
- E13: Orphan widgets — `temporal_strip.dart`, `what_if_stories_widget.dart`, `horizon_line_widget.dart` delete ou wire (finding #24)
- E14: `marriedCapitalTaxDiscountByCanton` cover 18 missing cantons OU surface fallback flag dans UI (finding #16)
- E15: `print()` replace `debugPrint` (finding #26, #48)
- E16: Retroactive 3a `* 13` fix to `nombreDeMois` (finding #13)
- E17: `toolCalls` defensive snake_case fallback (finding #20)
- E18: A11y — `reducedMotion` check sur 50 animated widgets + Semantics sur 38 coach widgets (findings #51, #52)
- E19: `ListView.builder` migration pour dynamic lists (finding #53)
- E20: Disclaimer footer dedup (finding #55)

Décomposition en sous-commits permise (E1 → 5-8 commits par canton batch).

Gate sortie E : panel 7 re-run → 0 P0, 0 P1, ≤5 P2 residual documentés en ADR.

### Wave F — Device walkthrough release-ready (2-3h, 1 PR final ou promotion)

Goal : preuve par device de l'ensemble A→E.

Commits :
- F1: Demo toggle `settings/debug` charge golden Julien+Lauren en 1 tap
- F2: Walkthrough 12 sessions simulées (J+0 scan → J+90 anniversary) + 2 moments vie (rachat 50k J+20, Lauren enceinte J+50) — screenshots + AX tree dans `.planning/walkthrough-release/`
- F3: CHANGELOG, MEMORY.md handoff final, PR dev → staging

Gate sortie F : MINT installé iPhone pendant 3 mois = aiguillé en continu.

## Ordre & dépendances (RÉVISÉ 2026-04-18 via ADR-20260418-wave-order-daily-loop)

```
Hotfix P0 (save_fact PII) ──► Wave 0 (walkthrough de vérité 90min) ──►
  Wave B-prime (home orchestrateur + age guard + weekly_recap) ──►
  Wave A-prime (notifs wiring + scan event + dedup + cliff) ──►
  Wave C (scan handoff) ──► Wave D (FRI + couple) ──► Wave E (perfection) ──► Wave F (device release)
```

**Réordonnancement** : 3 panels review du PLAN Wave A initial ont tranché REWORK FUNDAMENTAL.
Panel iconoclaste a prouvé par code que home vivant DOIT précéder notifs (aujourdhui_screen.dart 301 lignes avec 0 CapEngine vs cap_engine.dart 1333 lignes prêt). Push sur home mort = désinstall.

Hotfix P0 save_fact PII = chirurgical 20 min, compliance CLAUDE.md §6.7, indépendant du daily-loop.
Wave 0 walkthrough = 90 min max, source de vérité AX tree + screenshots pour Wave B-prime.

Voir `/Users/julienbattaglia/Desktop/MINT/decisions/ADR-20260418-wave-order-daily-loop.md` pour détails.

## Budget temps total

~35-45h travail, 6 PRs shippables. Chaque PR laisse dev green.

## Critères succès mesurables

1. **Rétention** : Julien J+30+ retourne seul ≥60% (vs 20-25% actuel)
2. **Narrative quality** : rachat 50k + Lauren = réponse qui mentionne FATCA, archétype, asymétrie
3. **Home quality** : cap du jour + nudge + milestone + streak visibles à chaque open
4. **Dette** : 0 P0 Panel 7, 0 P1 Panel 7 résiduels
5. **CI** : 10/10 green sur chaque PR
6. **Device** : walkthrough 3 mois simulé ne casse aucun flow
