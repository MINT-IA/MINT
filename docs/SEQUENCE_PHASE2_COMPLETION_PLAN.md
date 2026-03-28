# Sequence Phase 2 — Completion Plan

> Date : 2026-03-28
> Statut : **COMPLETE** — toutes les étapes livrées, auditées, bugs corrigés.
> PR #182 → dev (feature/S58-chantier1-sequence-live)

---

## Livraison complète

| Composant | Statut | Fichier |
|---|---|---|
| SequenceTemplate (3 V1) | Done | `models/sequence_template.dart` |
| SequenceRun + serialization | Done | `models/sequence_run.dart` |
| SequenceCoordinator.decide() | Done | `services/sequence/sequence_coordinator.dart` |
| SequenceStore (SharedPreferences) | Done | `services/sequence/sequence_store.dart` |
| SequenceChatHandler (bridge) | Done | `services/sequence/sequence_chat_handler.dart` |
| SequenceProgressCard (widget) | Done | `widgets/coach/sequence_progress_card.dart` |
| CapMemory.stepProposals | Done | `services/cap_memory_store.dart` |
| ScreenReturn enrichi (runId/stepId/eventId/stepOutputs) | Done | `models/screen_return.dart` |
| Navigation context (GoRouter.extra) | Done | `screens/coach/coach_chat_screen.dart` |
| Realtime = chemin canonique | Done | `_onRealtimeScreenReturn` in chat |
| Dédup par eventId | Done | `SequenceRun.isEventProcessed` |
| Legacy side effects suppression | Done | Chat handler + realtime suppression in screens |
| SequenceProgressCard dans le chat | Done | `_renderSequenceAction` + `_buildSequenceCard` |
| Observabilité complète | Done | 8 events: started, step_completed, completed, paused, skipped, retry, fallback_used, duplicate_event_dropped |
| 10 écrans Tier A migrés | Done | Voir tableau ci-dessous |
| Service-level integration tests | Done | `test/integration/sequence_e2e_test.dart` (21 tests) |

## Écrans migrés (Tier A)

| Template | Step | Screen | Route | stepOutputs |
|---|---|---|---|---|
| housing_purchase | 1 | AffordabilityScreen | /hypotheque | capacite_achat, fonds_propres_requis |
| housing_purchase | 2 | EplScreen | /epl | montant_epl, impact_rente |
| housing_purchase | 3 | FiscalComparatorScreen | /fiscal | impot_retrait |
| housing_purchase | 4 | _inline_summary | (inline) | — |
| optimize_3a | 1 | Simulator3aScreen | /pilier-3a | contribution_annuelle, economie_fiscale |
| optimize_3a | 2 | StaggeredWithdrawalScreen | /3a-deep/staggered-withdrawal | gain_echelonnement |
| optimize_3a | 3 | RealReturnScreen | /3a-deep/real-return | (last step) |
| retirement_prep | 1 | RetirementDashboardScreen | /retraite | taux_remplacement, gap_mensuel |
| retirement_prep | 2 | RenteVsCapitalScreen | /rente-vs-capital | decision_mixte |
| retirement_prep | 3 | RachatEchelonneScreen | /rachat-lpp | economie_rachat |
| retirement_prep | 4 | OptimisationDecaissementScreen | /decaissement | (educational) |
| retirement_prep | 5 | _inline_summary | (inline) | — |

## Bugs trouvés et corrigés pendant l'audit

| # | Sévérité | Description |
|---|---|---|
| 1 | HAUTE | Double-tap : deux context.push possibles sans guard |
| 2 | HAUTE | Stale step : ancien "Continuer" navigue vers route obsolète |
| 3 | HAUTE | Stuck sequence : pop sans interaction → aucun ScreenReturn émis |
| 4 | HAUTE | Dual emission : realtime + terminal les deux dans le stream en mode séquence |
| 5 | HAUTE | _isSequenceNavigating race : flag set APRÈS async load, pas avant |
| 6 | HAUTE | catchError ne reset pas _isSequenceNavigating → navigation bloquée définitivement |
| 7 | HAUTE | null activeStepId : séquence terminée mais navigation stale permise |
| 8 | HAUTE | tauxRemplacementBase : comparait BRUT retirement vs NET current (inflated ~20-30%) |
| 9 | MOYENNE | Route mismatch : RachatEchelonne emettait /lpp-deep/rachat-echelonne vs GoRouter /rachat-lpp |
| 10 | MOYENNE | Route mismatch : OptimisationDecaissement emettait /optimisation-decaissement vs /decaissement |
| 11 | MOYENNE | StaggeredWithdrawal : canton dropdown ne settait pas _hasUserInteracted |
| 12 | MOYENNE | RealReturn : premier slider ne settait pas _hasUserInteracted |
| 13 | MOYENNE | Affordability : canton dropdown ne settait pas _hasUserInteracted |
| 14 | MOYENNE | RetirementDashboard : emettait completed avec 0 quand projection null |
| 15 | MOYENNE | Template : phantom outputMapping 'calendrier_optimal' sur écran éducatif |

## Limitations V1 restantes (documentées)

- Les tests sont service-level integration, pas widget-level E2E (pas de GoRouter mock + mounted CoachChatScreen)
- Le debounce 2s du realtime peut envoyer "Je viens de simuler..." après consommation séquence
- `step_opened` non émis (l'event serait dans la navigation, pas dans le handler)
