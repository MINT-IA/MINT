# Panel A — Services & Providers façade audit (2026-04-18)

Dev tip : 17d91776 (post-merge PR #355 Wave A-MINIMAL).
Scope : `apps/mobile/lib/services/**` + `apps/mobile/lib/providers/**` + `app.dart` / `main.dart`.
Méthode : grep systématique caller/consumer, hors tests et barrel exports.

## Résumé exécutif

- Services scannés : 250
- Providers scannés : 19 (15 distincts + proxy + sub-classe)
- Façades P0 hard-stop (shippées prod, 0 caller) : **32 items**
- Façades P1 (dette, dormante documentée) : 2 items
- Zones ambiguës : 0 (toutes tranchées)

Les P0 se regroupent en 5 clusters + quelques orphelins isolés :

1. Cluster Anticipation (8 fichiers) — `AnticipationProvider` + tout `services/anticipation/` + `widgets/alert/MintAlertHost`.
2. Cluster Voice (6 fichiers) — `VoiceService`, `VoiceStateMachine`, `PlatformVoiceBackend`, `VoiceChatIntegration`, `VoiceInputButton`, `VoiceOutputButton`.
3. Cluster Recap (3 fichiers) — `recap/weekly_recap_service.dart`, `recap/ai_recap_narrator.dart`, `recap/recap_formatter.dart` + doublon `coach/weekly_recap_service.dart`.
4. Cluster DACH (4 fichiers) — `MultiCountryLifecycleService`, `CountryPensionService`, `GermanyPension`, `AustriaPension`.
5. Cluster B2B / Expert / Agent (6 fichiers) — `B2BOrganizationService`, `WellnessDashboardService`, `InstitutionalApiService`, `PensionFundRegistry`, `AutonomousAgentService`, `AdvisorMatchingService`, `DossierPreparationService`, `SessionSchedulerService`, `LetterGenerationService`, `FormPrefillService`, `AgentValidationGate`.

Orphelins isolés : `JitaiNudgeService`, `AffiliateService`, `CoupleQuestionGenerator`, `AdaptiveChallengeService`, `CommunityChallengeService`, `MilestoneV2Service`, `DailyEngagementService`, `AnnualRefreshService`, `PlanTrackingService`, `FinancialHealthScoreService`, `DashboardProjectionSnapshot`, `BenchmarkService` (racine), `BenchmarkComparisonService`, `BenchmarkOptInService`, `OpenFinanceService`, `BankImportService`, `VisibilityScoreService`, `LlmFailoverService`, `MultiLlmService`, `RagRetrievalService`, `services/coach/coach_narrative_service.dart` (doublon), `UserActivityProvider`, `ContextualCardProvider`, `CoachEntryPayloadProvider`.

---

## P0 — Façades hard-stop

### Providers registered sans consumer prod

#### P0-1 : `UserActivityProvider`
- Fichier : `apps/mobile/lib/providers/user_activity_provider.dart:15`
- Registered : `app.dart:1245-1249` (`ChangeNotifierProvider` + `provider.loadAll()`)
- Consumer grep `UserActivityProvider` hors registration/définition : **0 match** (`apps/mobile/lib/app.dart:1246` + fichier lui-même seulement).
- Méthodes publiques orphelines : `markSimulatorExplored`, `markLifeEventExplored`, `dismissTip`, `snoozeTip`, `isSimulatorExplored`, `isLifeEventExplored`, `isTipActive`, `exploredSimulators`, `exploredLifeEvents`, `dismissedTips`, `snoozedTips`, `loadAll`, `clearAll`.
- Vérification contre-usage : les call-sites exploitent `ReportPersistenceService.markSimulatorExplored` (`budget_screen.dart:87`, `lamal_franchise_screen.dart:39`, `rachat_echelonne_screen.dart:125`, `affordability_screen.dart:47`, `debt_ratio_screen.dart:42`, `simulator_3a_screen.dart:69`). Le provider duplique intégralement cette API (mêmes clés SharedPreferences `_exploredSimulatorsKey = 'explored_simulators_v1'`) sans aucun consommateur.
- Recommandation : DELETE (+ déréférencer `loadAll` dans `app.dart`).

#### P0-2 : `ContextualCardProvider`
- Fichier : `apps/mobile/lib/providers/contextual_card_provider.dart:29`
- Registered : `app.dart:1257`.
- Docstring ligne 19 ment : « Consumers: MintHomeScreen via context.watch<ContextualCardProvider>() ». Grep dans tout `apps/mobile/lib` : **0 consumer réel** (seule mention hors registration = un commentaire dans `services/contextual/card_ranking_service.dart:23` qui dit déjà « NEVER called by »).
- Recommandation : DELETE provider + screener les 6 services dans `services/contextual/` pour cascade.

#### P0-3 : `AnticipationProvider`
- Fichier : `apps/mobile/lib/providers/anticipation_provider.dart:35`
- Registered : `app.dart:1256`.
- API publique : `alertSignals` (Stream), `markDebtCrisis()`, `visibleSignals`, `overflowSignals`, `currentDebtCrisisSignal`.
- Grep `context.watch<AnticipationProvider>|context.read<AnticipationProvider>|Consumer<AnticipationProvider>|Provider.of<AnticipationProvider>` → **0 match**.
- Grep `markDebtCrisis|visibleSignals|overflowSignals` → seulement les définitions internes.
- Consumer attendu `MintAlertHost` : jamais instancié (`MintAlertHost(` appel : aucune occurrence hors sa propre définition ligne 58).
- Recommandation : DELETE provider + cascade services `services/anticipation/` (voir P0-4).

#### P0-4 : Cluster services `anticipation/` (5 fichiers)
- `apps/mobile/lib/services/anticipation/anticipation_engine.dart`
- `apps/mobile/lib/services/anticipation/anticipation_persistence.dart`
- `apps/mobile/lib/services/anticipation/anticipation_ranking.dart`
- `apps/mobile/lib/services/anticipation/anticipation_trigger.dart`
- `apps/mobile/lib/services/anticipation/cantonal_deadlines.dart`
- Grep par classe : tous importés UNIQUEMENT par `providers/anticipation_provider.dart` (lui-même P0-3). `CantonalDeadlines` a 0 import partout.
- Recommandation : DELETE entier.

#### P0-5 : `CoachEntryPayloadProvider`
- Fichier : `apps/mobile/lib/providers/coach_entry_payload_provider.dart:14`
- Registered : `app.dart:1287`.
- API : `setPayload`, `consumePayload`, `pending`.
- Grep `setPayload|consumePayload` hors fichier : **0 match**.
- Docstring promet : « 1. MintHomeScreen sets payload via setPayload ; 2. MintCoachTab reads and clears » — ni l'un ni l'autre n'existe.
- Recommandation : DELETE.

#### P0-6 : `MintAlertHost` + `MintAlertObject` + `MintAlertSignal` widgets
- Fichiers : `apps/mobile/lib/widgets/alert/mint_alert_host.dart`, `mint_alert_object.dart`, `mint_alert_signal.dart`, `voice_resolution_context.dart`.
- Grep `MintAlertHost\(` → 0 (seulement `const MintAlertHost({` dans sa propre définition ligne 58).
- Hors scope strict services/providers mais consume `AnticipationProvider` (P0-3) et `BiographyRepository` → toute la chaîne d'alertes est morte.
- Recommandation : DELETE.

---

### Services publics sans caller prod

#### P0-7 : `JitaiNudgeService`
- Fichier : `apps/mobile/lib/services/coach/jitai_nudge_service.dart:79`
- Grep `JitaiNudgeService` hors définition : **0 match**.
- Recommandation : DELETE. Wave B-minimal ≠ Wave B-full (ROADMAP) — le service n'a jamais été wired.

#### P0-8 : `MilestoneDetectionService`
- Fichier : `apps/mobile/lib/services/milestone_detection_service.dart:124`
- Grep `MilestoneDetectionService.` hors import : **0 caller prod**. Importé uniquement par `widgets/coach/milestone_celebration_sheet.dart:7` qui contient en ligne 17 un commentaire : `// MilestoneDetectionService.detectNew() retourne des resultats.` — aucun appel réel.
- `MilestoneCelebrationSheet` lui-même jamais instancié (grep `MilestoneCelebrationSheet(` → seulement docstrings).
- Recommandation : DELETE service + widget.

#### P0-9 : `AffiliateService`
- Fichier : `apps/mobile/lib/services/affiliate_service.dart:5`
- Grep `AffiliateService.` : **0 match**.
- Recommandation : DELETE.

#### P0-10 : `CoupleQuestionGenerator`
- Fichier : `apps/mobile/lib/services/couple_question_generator.dart:29`
- Grep `CoupleQuestionGenerator` : **0 caller**.
- Recommandation : DELETE.

#### P0-11 : `AdaptiveChallengeService`
- Fichier : `apps/mobile/lib/services/coach/adaptive_challenge_service.dart:127`
- Grep `AdaptiveChallengeService.` : **0 match**.
- Recommandation : DELETE.

#### P0-12 : `CommunityChallengeService`
- Fichier : `apps/mobile/lib/services/coach/community_challenge_service.dart:145`
- Grep `CommunityChallengeService.` : **0 match**.
- Recommandation : DELETE.

#### P0-13 : Cluster Recap (4 fichiers)
- `apps/mobile/lib/services/recap/weekly_recap_service.dart:137` (`WeeklyRecapService`)
- `apps/mobile/lib/services/recap/ai_recap_narrator.dart:18` (`AiRecapNarrator`)
- `apps/mobile/lib/services/recap/recap_formatter.dart:61` (`RecapFormatter`)
- `apps/mobile/lib/services/coach/weekly_recap_service.dart:101` (`WeeklyRecapService` **DOUBLON**)
- Grep `AiRecapNarrator|RecapFormatter|WeeklyRecapService` consumers : seuls inter-imports internes (`ai_recap_narrator` → `weekly_recap_service` ; `recap_formatter` → `weekly_recap_service`). Aucun screen, aucun provider, aucun service externe ne les appelle.
- La double définition `WeeklyRecapService` (deux namespaces différents) est un smell supplémentaire : la version `coach/weekly_recap_service.dart` n'est importée nulle part.
- ADR-20260419 a killé la couche gamification/recap mais le code est resté.
- Recommandation : DELETE les 4 fichiers + le dossier `services/recap/`.

#### P0-14 : `DailyEngagementService`
- Fichier : `apps/mobile/lib/services/daily_engagement_service.dart:27`
- Méthodes publiques : `recordEngagement`, `currentStreak`, `longestStreak`, `hasEngagedToday`, `totalDays`, `recentDates`.
- Grep des callers : **seuls JitaiNudgeService (P0-7) et coach/weekly_recap_service (P0-13) appellent `recentDates`** → callers eux-mêmes façades. Aucune autre méthode publique n'est jamais appelée nulle part.
- Recommandation : DELETE en cascade avec P0-7/P0-13.

#### P0-15 : `AnnualRefreshService`
- Fichier : `apps/mobile/lib/services/annual_refresh_service.dart:88`
- Grep `AnnualRefreshService.` : **0 match**.
- Recommandation : DELETE.

#### P0-16 : `PlanTrackingService`
- Fichier : `apps/mobile/lib/services/plan_tracking_service.dart:51`
- Grep `PlanTrackingService.` : **0 match**.
- Recommandation : DELETE.

#### P0-17 : `FinancialHealthScoreService`
- Fichier : `apps/mobile/lib/services/financial_health_score_service.dart:38`
- Instanciation : `FinancialHealthScoreService(prefs)` — cherché sur tout `apps/mobile` : **seulement dans `test/services/financial_health_score_service_test.dart` (17 occurrences)**. Zéro usage prod. La seule autre référence est une docstring dans `widgets/pulse/fhs_thermometer.dart:113` qui mentionne `kFhsTrendThreshold` mais n'utilise pas le service.
- Recommandation : `@visibleForTesting` la classe entière OU DELETE si FHS n'est plus prévu.

#### P0-18 : `DashboardProjectionSnapshot`
- Fichier : `apps/mobile/lib/services/dashboard_projection_snapshot.dart:14`
- Grep `DashboardProjectionSnapshot` : **0 caller hors fichier**.
- Recommandation : DELETE.

#### P0-19 : `BenchmarkService` (racine)
- Fichier : `apps/mobile/lib/services/benchmark_service.dart:8`
- API : `compareSavings`, etc. Grep `BenchmarkService.` : **0 match**. Ne pas confondre avec `CantonalBenchmarkService` qui est consommé par `cantonal_benchmark_screen.dart`.
- Recommandation : DELETE.

#### P0-20 : `BenchmarkComparisonService` + `BenchmarkOptInService`
- Fichiers : `apps/mobile/lib/services/benchmark/benchmark_comparison_service.dart:95`, `benchmark_opt_in_service.dart:24`.
- Grep : **0 caller chacun**.
- `CantonalBenchmarkData` (`benchmark/cantonal_benchmark_data.dart:78`) : référencé uniquement par `BenchmarkComparisonService` lui-même façade → cluster mort.
- Recommandation : DELETE le dossier `services/benchmark/` entier.

#### P0-21 : `OpenFinanceService`
- Fichier : `apps/mobile/lib/services/openfinance/open_finance_service.dart:283`
- Grep `OpenFinanceService.|OpenFinanceService(` : **0 match**.
- Recommandation : DELETE.

#### P0-22 : `BankImportService`
- Fichier : `apps/mobile/lib/services/bank_import_service.dart:133`
- Grep `BankImportService.|BankImportService(` : **0 match**.
- `bank_import_screen.dart` importe `document_service.dart` PAS `bank_import_service.dart`.
- Recommandation : DELETE.

#### P0-23 : `VisibilityScoreService`
- Fichier : `apps/mobile/lib/services/visibility_score_service.dart:116`
- Grep `VisibilityScoreService.` : **0 match**.
- Recommandation : DELETE.

#### P0-24 : `LlmFailoverService`
- Fichier : `apps/mobile/lib/services/llm/llm_failover_service.dart:158`
- Grep `LlmFailoverService` hors fichier : **0 match** (seule référence extérieure est une docstring interne).
- Note : `ProviderHealthService` (`llm/provider_health_service.dart:140`) et `ResponseQualityMonitor` (`llm/response_quality_monitor.dart:142`) sont EUX consommés par `coach/coach_orchestrator.dart:1355`, donc seul `LlmFailoverService` est façade.
- Recommandation : DELETE ce fichier, garder les 2 autres.

#### P0-25 : `MultiLlmService`
- Fichier : `apps/mobile/lib/services/coach/multi_llm_service.dart:182`
- Grep `MultiLlmService` hors fichier : **0 match**.
- Recommandation : DELETE.

#### P0-26 : `RagRetrievalService`
- Fichier : `apps/mobile/lib/services/coach/rag_retrieval_service.dart:56`
- Grep `RagRetrievalService.` : **0 match**.
- Recommandation : DELETE.

#### P0-27 : Doublon `services/coach/coach_narrative_service.dart`
- Fichier : `apps/mobile/lib/services/coach/coach_narrative_service.dart` (206 lignes, contient `class CoachNarrativeService` + `class CoachNarrativeResult`, méthodes `generateAll`, `generateAllEnhanced`).
- Doublon de `apps/mobile/lib/services/coach_narrative_service.dart` (1458 lignes, version vivante consommée par `widgets/coach/coach_briefing_card.dart:3`, `screens/coach/retirement_dashboard_screen.dart:11`, etc.).
- Grep `import .*coach/coach_narrative_service` : **0 match**. Donc le sous-dossier n'est jamais importé.
- Grep `CoachNarrativeResult|generateAll|generateAllEnhanced` : seules définitions dans le fichier doublon mort.
- Recommandation : DELETE `services/coach/coach_narrative_service.dart`.

---

### Cluster Voice (6 fichiers)

Consommé uniquement par widgets eux-mêmes jamais instanciés.

#### P0-28 : `VoiceInputButton` + `VoiceOutputButton`
- Fichiers : `apps/mobile/lib/widgets/coach/voice_input_button.dart:34`, `voice_output_button.dart:34`.
- Grep `VoiceInputButton(|VoiceOutputButton(` : **0 instantiation** (seules occurrences = docstrings ligne 29 qui montrent un exemple et la propre définition).
- Hors scope strict services/providers mais déclenche cascade P0-29/30/31.

#### P0-29 : `VoiceChatIntegration`
- Fichier : `apps/mobile/lib/services/coach/voice_chat_integration.dart:68`
- Grep `VoiceChatIntegration(|new VoiceChatIntegration|VoiceChatIntegration\.` : **0 match** externe (seulement sa propre définition).
- Recommandation : DELETE.

#### P0-30 : `VoiceService` (coach)
- Fichier : `apps/mobile/lib/services/coach/voice_service.dart`
- Grep `VoiceService\.` : appels uniquement depuis `widgets/coach/voice_input_button.dart:124,145` (P0-28 façade) et `services/voice/platform_voice_backend.dart:33` (P0-31 façade) → tous les callers sont eux-mêmes façade.
- Recommandation : DELETE.

#### P0-31 : `PlatformVoiceBackend`
- Fichier : `apps/mobile/lib/services/voice/platform_voice_backend.dart:58`
- Grep `PlatformVoiceBackend` : **0 match** hors fichier (docstring interne uniquement).
- Recommandation : DELETE.

#### P0-32 : `VoiceStateMachine`
- Fichier : `apps/mobile/lib/services/voice/voice_state_machine.dart:70`
- Utilisé uniquement par `coach/voice_service.dart:168` (P0-30 façade).
- Recommandation : DELETE.

Note : `voice_config.dart` + `RegionalVoiceService` restent WIRED (`context_injector_service.dart:261` appelle `RegionalVoiceService.forCanton`). Ne PAS les supprimer.

---

### Cluster DACH (4 fichiers)

#### P0-33 : `MultiCountryLifecycleService`, `CountryPensionService`, `GermanyPension`, `AustriaPension`
- Fichiers :
  - `apps/mobile/lib/services/dach/multi_country_lifecycle_service.dart:72`
  - `apps/mobile/lib/services/dach/country_pension_service.dart:178`
  - `apps/mobile/lib/services/dach/germany_pension.dart:19`
  - `apps/mobile/lib/services/dach/austria_pension.dart:19`
- Grep des 4 classes hors dossier `dach/` : **0 caller externe**. Seuls inter-imports :
  - `multi_country_lifecycle_service.dart:343-344` appelle `CountryPensionService.getSystem`
  - `country_pension_service.dart:336` appelle `MultiCountryLifecycleService.getPhasesForCountry`
  - `country_pension_service.dart:235,237` référence `GermanyPension.system`, `AustriaPension.system`
- Toute la chaîne est inerte. Wave 4 « Expansion DACH » du ROADMAP_V2.md est en phase 4 (jamais lancée).
- Recommandation : DELETE le dossier `services/dach/` entier.

---

### Cluster B2B / Expert / Agent

#### P0-34 : `B2BOrganizationService`
- Fichier : `apps/mobile/lib/services/b2b/b2b_organization_service.dart`
- Grep `B2BOrganizationService` : **0 match hors fichier**.
- Recommandation : DELETE.

#### P0-35 : `WellnessDashboardService`
- Fichier : `apps/mobile/lib/services/b2b/wellness_dashboard_service.dart:85`
- Grep `WellnessDashboardService.` : **0 match** (seule occurrence = docstring interne ligne 80).
- Recommandation : DELETE.

#### P0-36 : `InstitutionalApiService`
- Fichier : `apps/mobile/lib/services/institutional/institutional_api_service.dart:376`
- Grep `InstitutionalApiService` hors fichier : **0 match**.
- Recommandation : DELETE.

#### P0-37 : `PensionFundRegistry`
- Fichier : `apps/mobile/lib/services/institutional/pension_fund_registry.dart:52`
- Appelé uniquement par `InstitutionalApiService` (P0-36 façade) lignes 243 et 610.
- Recommandation : DELETE en cascade avec P0-36.

#### P0-38 : `AutonomousAgentService`
- Fichier : `apps/mobile/lib/services/agent/autonomous_agent_service.dart:408`
- Grep `AutonomousAgentService.` : **0 match**.
- Recommandation : DELETE.

#### P0-39 : `AdvisorMatchingService`
- Fichier : `apps/mobile/lib/services/advisor/advisor_matching_service.dart:111`
- Grep `AdvisorMatchingService.` : **0 match**. L'enum `AdvisorSpecialization` est utilisé (via `services/expert/advisor_specialization.dart`) mais le service lui-même façade.
- Recommandation : DELETE.

#### P0-40 : `DossierPreparationService` + `SessionSchedulerService`
- Fichiers : `apps/mobile/lib/services/expert/dossier_preparation_service.dart:103`, `session_scheduler_service.dart:115`.
- Grep `DossierPreparationService.|SessionSchedulerService.` : **0 match**.
- Recommandation : DELETE `services/expert/` entier (garder l'enum `AdvisorSpecialization` référencé par `screen_registry.dart:1431`).

#### P0-41 : `FormPrefillService`, `LetterGenerationService`, `AgentValidationGate`
- Fichiers : `apps/mobile/lib/services/agent/form_prefill_service.dart:91`, `letter_generation_service.dart:73`, `agent_validation_gate.dart:93`.
- Grep : les 3 ne sont référencés QUE dans des docstrings (`coach_llm_service.dart:144-145`, `widget_renderer.dart:519`, `document_card.dart:4,5,9`). Aucun appel effectif.
- `DocumentCard` (`widgets/coach/document_card.dart:51`) lui-même jamais instancié (grep `DocumentCard(` → uniquement `const DocumentCard({`).
- Recommandation : DELETE le trio + `DocumentCard`.

#### P0-42 : `MilestoneV2Service`
- Fichier : `apps/mobile/lib/services/gamification/milestone_v2_service.dart:73`
- Grep `MilestoneV2Service.` : **0 match**.
- Recommandation : DELETE.

Note : `SeasonalEventService` (`gamification/seasonal_event_service.dart:89`) est WIRED via `coach/proactive_trigger_service.dart:401` — ne PAS supprimer.

---

## P1 — Dette technique (dormant documenté)

### P1-1 : `scheduleRetentionNotifications` public orphelin
- Fichier : `apps/mobile/lib/services/notification_service.dart:685`
- Méthode publique, 0 caller prod (grep confirme).
- Cohérent avec ADR-20260419 (retention notifications killed) mais code non supprimé.
- Recommandation : DELETE ou `@visibleForTesting` si des tests existent.

### P1-2 : Méthodes privées dormantes de `NotificationService`
- `_scheduleWeeklyRecap` (`notification_service.dart:460`)
- `_scheduleStreakProtection` (`notification_service.dart:628`)
- Marquées `// ignore: unused_element` avec commentaire « Wave A-MINIMAL 2026-04-18: temporarily unreferenced ». Privées donc hors scope strict, mais YAGNI.
- Recommandation : laisser tel quel (intention documentée) ou DELETE si Wave B-full ne reviendra pas.

---

## P2 — YAGNI (suppression préférée, pas bloquant)

Inclus dans les clusters ci-dessus. Tous les items P0 de ce rapport sont en réalité des P2/YAGNI si on ignore le risque de drift. Ils sont classés P0 parce que la doctrine Julien 2026-04-18 (feedback_facade_sans_cablage_absolu.md) impose hard-stop : « APIs publiques sans caller prod = delete ou @visibleForTesting ».

---

## Providers avec lazy par défaut + pas/peu de consumer (vérification doctrinale)

Tous les `ChangeNotifierProvider` standard dans `app.dart:1220-1316` sont `lazy: true` par défaut. La doctrine hard-stop flag `ProxyProvider` lazy sans consumer. Seul un proxy est présent :

- `ChangeNotifierProxyProvider<CoachProfileProvider, MintStateProvider>` (`app.dart:1273`) : lazy par défaut (true). Consumer : `MintStateProvider` est consommé par `budget_screen.dart:107` et le cap banner (cf. commentaire ligne 1266-1271 A2). ✅
- `ChangeNotifierProxyProvider<CoachProfileProvider, NotificationsWiringService>` (`app.dart:1308`) : `lazy: false` explicite (ligne 1309) grâce au fix A2-fix. ✅

Pour `MintStateProvider`, le commentaire A2 (ligne 1262-1272) affirme que l'accès se fait via `budget_screen.dart:107` et le cap banner. À vérifier rapidement (hors scope mais important) : si ces consumers ne lisent pas `state` au moment requis, la doctrine hard-stop impose également `lazy: false`. **Recommandation de suivi** : faire chercher à Panel C ou via grep `context.watch<MintStateProvider>|context.read<MintStateProvider>|Provider.of<MintStateProvider>` pour confirmer que l'instanciation lazy fire bien à temps.

Les 13 ChangeNotifierProvider standards restants sont tous consommés par au moins un screen/widget (AuthProvider, ProfileProvider, BudgetProvider, ByokProvider, DocumentProvider, SubscriptionProvider, HouseholdProvider, CoachProfileProvider, LocaleProvider, SlmProvider, BiographyProvider, FinancialPlanProvider, TimelineProvider). Les 4 ChangeNotifierProvider sans consumer sont les P0-1, P0-2, P0-3, P0-5 déjà listés.

---

## Synthèse par type

| Type | P0 count | Notes |
|------|----------|-------|
| Provider registered sans consumer | 4 | UserActivity, ContextualCard, Anticipation, CoachEntryPayload |
| Service public 0 caller | 28 | Voir détails P0-7→42 |
| Widget façade (hors scope strict mais documenté) | 6 | MintAlertHost, MilestoneCelebrationSheet, VoiceInput/OutputButton, DocumentCard, LetterGeneratorSheet-orphan |

Total fichiers à supprimer ou à `@visibleForTesting` : **≈ 45 fichiers** (services + providers + widgets cascade).

## Recommandation d'ordre d'exécution

1. DELETE les orphelins isolés simples (P0-7, P0-9, P0-10, P0-11, P0-12, P0-15, P0-16, P0-18, P0-19, P0-21, P0-22, P0-23, P0-25, P0-26, P0-27) — 15 fichiers, 0 dépendance.
2. DELETE les clusters cohérents (P0-4 anticipation, P0-13 recap, P0-33 DACH, P0-20 benchmark) — 13 fichiers.
3. DELETE les providers P0-1/2/3/5 + widgets alert (P0-6) — 7 fichiers.
4. DELETE le cluster Voice (P0-28 à 32) — 6 fichiers.
5. DELETE le cluster B2B/Expert/Agent (P0-34 à 42) — 10 fichiers.
6. `@visibleForTesting` `FinancialHealthScoreService` (P0-17) si les 17 tests existants doivent rester.
7. DELETE `MilestoneDetectionService` + `MilestoneCelebrationSheet` (P0-8) en cascade.
8. DELETE ou fix P1-1 `scheduleRetentionNotifications`.

Flutter analyze + flutter test doivent rester verts après chaque groupe (grep + imports inutilisés seront signalés par l'analyzer).
