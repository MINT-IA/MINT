# Sequence Phase 2 — Completion Plan

> Date : 2026-03-27
> Statut : **TODO** — fondations posées, orchestration chat à finaliser
> Prérequis : Phase 1 (modèles, coordinator, store) + Phase 2 partielle (handler, widget, startSequence hook)

---

## Ce qui est livré

| Composant | Statut | Fichier |
|---|---|---|
| SequenceTemplate (3 V1) | Done | `models/sequence_template.dart` |
| SequenceRun + serialization | Done | `models/sequence_run.dart` |
| SequenceCoordinator.decide() | Done | `services/sequence/sequence_coordinator.dart` |
| SequenceStore (SharedPreferences) | Done | `services/sequence/sequence_store.dart` |
| SequenceChatHandler (bridge) | Done | `services/sequence/sequence_chat_handler.dart` |
| SequenceProgressCard (widget) | Done | `widgets/coach/sequence_progress_card.dart` |
| CapMemory.stepProposals | Done | `services/cap_memory_store.dart` |
| ScreenReturn.stepOutputs | Done | `models/screen_return.dart` |
| startSequence hook en production | Done | `screens/coach/coach_chat_screen.dart` |
| 60+ tests | Done | `test/services/sequence/`, `test/widgets/coach/`, `test/services/cap_memory_step_proposals_test.dart` |

## Ce qui manque (architecture cible)

### 1. ScreenReturn enrichi avec identifiants de séquence

```dart
class ScreenReturn {
  // ... champs existants ...
  final String? runId;      // Identifiant du run en cours
  final String? stepId;     // Identifiant de l'étape dans le run
  final String? eventId;    // UUID unique pour déduplication idempotente
}
```

**Pourquoi** : le realtime stream ne sait pas actuellement quel run/step a produit le ScreenReturn. Sans ces champs, la dédup est approximative.

### 2. Passage du contexte séquence dans la navigation

```dart
await context.push(route, extra: {
  'prefill': prefill,
  'runId': run.runId,           // NOUVEAU
  'stepId': step.id,            // NOUVEAU
  'stepOrdinal': step.order,    // NOUVEAU
});
```

Les écrans liseent ces champs et les incluent dans leur `ScreenReturn` émis.

### 3. Realtime = chemin canonique UNIQUE

`_onRealtimeScreenReturn` est le seul consumer de séquence. Il vérifie `runId + stepId + eventId` dans le ScreenReturn et délègue au coordinator.

`_handleRouteReturn` ne traite les séquences que comme fallback explicite :
- Si aucun ScreenReturn canonique n'a été reçu pour ce `runId + stepId`
- Dans une fenêtre contrôlée
- Ou si l'écran n'est pas encore migré au contrat riche (Tier B)

### 4. Déduplication par eventId

```dart
// Dans SequenceStore ou un Set<String> borné en mémoire
final _processedEventIds = <String>{};

bool isDuplicate(String eventId) {
  if (_processedEventIds.contains(eventId)) return true;
  _processedEventIds.add(eventId);
  // Trim to last 20 to avoid unbounded growth
  if (_processedEventIds.length > 20) {
    _processedEventIds.remove(_processedEventIds.first);
  }
  return false;
}
```

### 5. State machine explicite

Déjà en place dans `SequenceRun` et `SequenceCoordinator`. Pas de changement nécessaire — juste s'assurer qu'aucune transition implicite n'existe en dehors du coordinator.

### 6. Suppression des side effects legacy en mode séquence

Quand le coordinator a traité un retour, `_handleRouteReturn` ne doit PAS :
- Appeler `CapMemoryStore.markCompleted/markAbandoned`
- Sauvegarder un `CoachInsight`
- Ajouter un message fallback
- Déclencher un milestone pulse

Ces actions sont gérées par le coordinator + `_renderSequenceAction`.

### 7. Tiers d'écrans

| Tier | Contrat | Écrans |
|---|---|---|
| **A** | ScreenReturn canonique avec `runId`, `stepId`, `eventId`, `stepOutputs` | Écrans migrés (Phase 3) |
| **B** | ScreenReturn simple (pas de `runId`/`stepId`) | Écrans legacy, fallback via `_handleRouteReturn` |

### 8. Observabilité

Logger chaque transition via `AnalyticsService.trackEvent()` :
- `sequence_started` (runId, templateId)
- `step_opened` (runId, stepId, route)
- `step_completed` (runId, stepId, outputs count)
- `step_abandoned` (runId, stepId)
- `sequence_paused` (runId, reason)
- `sequence_completed` (runId, step count, duration)
- `fallback_used` (runId, stepId, reason)
- `duplicate_event_dropped` (runId, stepId, eventId)

### 9. SequenceProgressCard rendu dans le chat

Quand `AdvanceAction` est rendu, le chat insère un `SequenceProgressCard` avec :
- Barre de progression
- Label de l'étape suivante
- Bouton "Continuer" → navigue vers la route
- Bouton "Quitter le parcours" → `SequenceChatHandler.quitSequence()`

---

## Plan d'exécution

| Étape | Effort | Risque |
|---|---|---|
| 1. Enrichir ScreenReturn (runId, stepId, eventId) | Petit | Backward-compatible (nullable) |
| 2. Passer le contexte séquence dans RouteSuggestionCard.extra | Petit | Aucun — champs optionnels |
| 3. Migrer 1 écran Tier A (/hypotheque) | Moyen | Limité à 1 écran |
| 4. Implémenter dédup par eventId | Petit | Aucun |
| 5. Supprimer legacy side effects en mode séquence | Moyen | Nécessite guard sync fiable |
| 6. Rendre SequenceProgressCard dans le chat | Moyen | UI intégration |
| 7. Ajouter observabilité | Petit | Fire-and-forget analytics |
| 8. Migrer les 2 autres écrans (3a, retraite) | Moyen | Répétition de l'étape 3 |

---

## Limitations V1 actuelles (documentées)

- Le debounce 2s du realtime peut envoyer "Je viens de simuler..." après consommation séquence
- Le fallback `_handleRouteReturn` laisse passer les legacy side effects si la séquence n'est pas encore démarrée (race condition sur tap ultra-rapide)
- Pas de SequenceProgressCard rendu dans le chat (juste des messages texte)
- Pas d'eventId pour dédup idempotente
- Pas de logging d'observabilité
- 8 strings hardcodées FR (dette i18n)
