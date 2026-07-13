# Sequence Phase 2 — Completion Plan

> Date : 2026-03-28
> Statut : **HISTORIQUE / SUPERSEDED** — ce document enregistre ce qui avait
> été déclaré livré dans la PR #182; il ne décrit plus le wiring runtime actuel.
> PR #182 → dev (feature/S58-chantier1-sequence-live)

> **Réalité G1 au commit `9851a8315` (2026-07-13).** Le runtime est en
> quarantaine derrière `FeatureFlags.enableGuidedSequences`, local-only et à
> `false` par défaut. Aucun caller de production ne démarre une séquence.
> `SequenceProgressCard`, `SequenceMessagePayload`, `SequenceSummaryBuilder`,
> leurs tests et le pipeline résumé/progression ont été supprimés comme façades
> sans câblage. `outputMapping` et le prefill inter-écrans ont été supprimés;
> les `requiredOutputKeys` doivent être présents et utilisables avant toute
> progression. Les tests service qui activent explicitement le flag prouvent le
> socle isolé, pas un parcours utilisateur livré.

---

## Livraison déclarée en mars 2026 (historique)

| Composant | État G1 actuel | Fichier / preuve |
|---|---|---|
| SequenceTemplate | Socle conservé; outputs requis, sans mapping de prefill | `models/sequence_template.dart` |
| SequenceRun + serialization | Socle conservé mais aucun run ne démarre en production | `models/sequence_run.dart` |
| SequenceCoordinator.decide() | Socle conservé; outputs requis validés fail-closed | `services/sequence/sequence_coordinator.dart` |
| SequenceStore (SharedPreferences) | Store conservé; les entrées gatées ne chargent pas un run obsolète lorsque le flag est off | `services/sequence/sequence_store.dart` |
| SequenceChatHandler (bridge) | Quarantiné par le kill switch local-only | `services/sequence/sequence_chat_handler.dart` |
| SequenceProgressCard (widget) | **Supprimé en G1** — aucun consumer produit | commit `9851a8315` |
| CapMemory.stepProposals | Socle conservé; pas une preuve de parcours actif | `services/cap_memory_store.dart` |
| ScreenReturn enrichi (runId/stepId/eventId/stepOutputs) | Contrat conservé | `models/screen_return.dart` |
| Navigation context | Identifiants éphémères seulement; aucun domain prefill | gate `no_domain_data_in_extra_test.dart` |
| Realtime | Handler présent mais inactif sans démarrage produit et flag activé | `_onRealtimeScreenReturn` in chat |
| Dédup par eventId | Socle conservé | `SequenceRun.isEventProcessed` |
| Legacy side effects suppression | Testée dans le harnais isolé; aucun claim runtime A→Z | tests sequence ciblés |
| Résumé/progression dans le chat | **Supprimés en G1** — payload, builder et renderer orphelins | commit `9851a8315` |
| Observabilité | Événements de service conservés; pas de preuve d'émission par un flow produit | tests ciblés |
| Écrans Tier A | Contrats d'outputs historiques; pas un parcours actif | tableau ci-dessous |
| Service-level integration tests | Harnais flag-on seulement | `test/integration/sequence_e2e_test.dart` |

## Écrans déclarés migrés (inventaire historique)

Ce tableau reste utile comme candidat de réactivation. Il ne prouve ni un
point d'entrée UI start/resume, ni une progression visible, ni un résumé rendu.
Les colonnes `stepOutputs` représentent désormais des outputs à valider, pas
des données à transporter vers l'écran suivant.

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

## Conditions obligatoires avant réactivation

- un vrai point d'entrée UI démarre une séquence et une UI permet de reprendre
  explicitement un run persisté;
- chaque étape valide ses `requiredOutputKeys` avant toute mutation ou avance;
- aucun domain prefill ne traverse les routes: les écrans relisent le Data
  Ledger et les paramètres de navigation restent des IDs/enums éphémères;
- une progression, un bouton Continuer/Quitter et le résumé final ont chacun un
  renderer **et** un caller produit réels;
- les tests couvrent le joint UI start → navigation → ScreenReturn → validation
  → resume → completion, sans double consommation ni effet legacy parallèle;
- Maestro prouve le parcours utilisateur et Patrol prouve les entrées P0;
- le kill switch reste local-only et `false` tant que ces gates ne sont pas
  toutes vertes.
