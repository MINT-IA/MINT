# RFC : Agent Loop Stateful — Multi-Screen Orchestration

> Date : 2026-03-27
> Statut : **DRAFT** — À valider avant implémentation
> Auteur : Team Lead (S57)
> Dépendances : ChiffreChoc V2, EVI Bridge, Confidence Doctrine (tous livrés)

---

## 1. Problème

Le coach peut aujourd'hui router vers **un seul écran** à la fois. Quand l'utilisateur dit "je veux acheter un appart", le coach ouvre `/hypotheque` et s'arrête là. Il ne peut pas enchaîner : accessibilité → gap fonds propres → EPL → fiscalité retrait.

Ce qui manque :
- **Pas de mémoire de séquence** — chaque écran est indépendant
- **Pas de transfert d'outputs** — l'écran 2 ne sait pas ce que l'écran 1 a calculé
- **Pas de progression visible** — l'utilisateur ne voit pas "étape 2/4"
- **Pas de branching** — le même parcours pour tous les archétypes
- **Pas d'anti-boucle** — si l'écran échoue, rien n'empêche de re-router dessus

---

## 2. Ce qui existe déjà

| Composant | Ce qu'il fait | Limitation |
|---|---|---|
| `RoutePlanner` | Intent → readiness gate → route décision | Stateless, 1 écran à la fois |
| `ScreenRegistry` | 60+ écrans routables, requiredFields, prefill | Pas de graphe de dépendances |
| `CapSequenceEngine` | Plan multi-étapes (retraite, budget, logement) | Hardcodé, pas de branching archetype |
| `CapMemory` | Tracks completedActions, abandonedFlows | Flat list, pas de contexte par étape |
| `ScreenReturn` | outcome (completed/abandoned/changedInputs) | Pas de données de sortie structurées |
| `CoachChatScreen._handleRouteReturn` | Réagit au retour d'un écran | Pas de chaînage vers l'écran suivant |
| `CoachOrchestrator` agent loop | tool_use → execute → re-call LLM | Pas de state machine de parcours |

---

## 3. Design proposé

### 3.1 Concept : Guided Sequence

```
Utilisateur : "Je veux acheter un bien immobilier"
    ↓
Coach (LLM) : "OK, voyons ça en 4 étapes."
    ↓
[SequenceCard: "Parcours achat immobilier" — 0/4 étapes]
    ↓
Étape 1 : /hypotheque (accessibilité) → output: {capaciteAchat: 850000, fondsNecessaires: 170000}
    ↓
Étape 2 : /epl (EPL) → prefill: {fondsNecessaires: 170000} → output: {eplMontant: 50000}
    ↓
Étape 3 : /fiscalite/retrait-capital → prefill: {montantRetrait: 50000} → output: {impotRetrait: 3200}
    ↓
Étape 4 : Coach résumé → "Capacité 850k, EPL 50k, impôt 3200. Ton plan est prêt."
    ↓
[SequenceCard: "Parcours achat immobilier" — 4/4 ✓]
```

### 3.2 Nouveau modèle : GuidedSequence

```dart
/// A multi-screen guided sequence toward a goal.
class GuidedSequence {
  final String id;                    // 'housing_purchase_2026'
  final String goalLabel;             // 'Achat immobilier'
  final List<SequenceStep> steps;     // Ordered steps
  final String archetypeFilter;       // 'all' | 'swiss_native' | 'expat_us'
  final DateTime createdAt;
  final SequenceStatus status;        // active | completed | abandoned | paused
}

class SequenceStep {
  final String id;                    // 'housing_01_affordability'
  final int order;
  final String intentTag;             // 'housing_purchase' (maps to ScreenRegistry)
  final String route;                 // '/hypotheque'
  final StepStatus status;            // pending | active | completed | skipped | blocked
  final Map<String, dynamic> inputFromPrior;  // Pre-filled from previous step outputs
  final Map<String, dynamic> output;  // Captured on completion
  final StepBlockReason? blockReason;
  final String? fallbackRoute;        // If blocked, where to redirect
}

enum StepStatus { pending, active, completed, skipped, blocked }

enum StepBlockReason {
  prerequisiteIncomplete,   // Step N-1 must complete first
  insufficientData,         // Need document scan or profile enrichment
  archetypeNotApplicable,   // Step not relevant for this archetype
  userDeclined,             // User explicitly skipped
}
```

### 3.3 Persistence : SequenceStore

```dart
/// Persists active sequences in SharedPreferences.
/// Lightweight — one sequence active at a time.
class SequenceStore {
  static const _key = 'mint_active_sequence';

  Future<GuidedSequence?> load();
  Future<void> save(GuidedSequence sequence);
  Future<void> clear();

  /// Record step completion with output data.
  Future<void> completeStep(String stepId, Map<String, dynamic> output);

  /// Record step abandonment with friction context.
  Future<void> abandonStep(String stepId, String frictionContext);
}
```

### 3.4 Orchestration : SequenceAgent

```dart
/// Decides what happens after each step return.
///
/// Pure function — no side effects, fully testable.
class SequenceAgent {

  /// Given current sequence state + step outcome, decide next action.
  static SequenceAction decide(GuidedSequence sequence, ScreenReturn stepReturn) {
    final currentStep = sequence.steps.firstWhere((s) => s.status == StepStatus.active);

    switch (stepReturn.outcome) {
      case ScreenOutcome.completed:
        // Mark step completed, find next non-blocked step
        final nextStep = _findNextStep(sequence, currentStep);
        if (nextStep != null) {
          return SequenceAction.advance(
            nextStep: nextStep,
            prefill: _buildPrefill(sequence, nextStep),
            progressLabel: '${_completedCount(sequence) + 1}/${sequence.steps.length}',
          );
        }
        return SequenceAction.complete(summary: _buildSummary(sequence));

      case ScreenOutcome.abandoned:
        // Don't re-propose same step immediately — offer alternatives
        return SequenceAction.pause(
          message: 'Pas de souci. On peut continuer plus tard.',
          canResume: true,
        );

      case ScreenOutcome.changedInputs:
        // Re-evaluate: prior step outputs may be invalidated
        return SequenceAction.reEvaluate(
          invalidatedSteps: _findInvalidated(sequence, stepReturn.updatedFields),
        );
    }
  }

  /// Anti-boucle : never propose the same step more than 2x in a session.
  static bool _shouldSkip(GuidedSequence sequence, SequenceStep step) {
    final attempts = sequence.steps
        .where((s) => s.id == step.id && s.status == StepStatus.completed)
        .length;
    return attempts >= 2;
  }
}

/// What the agent decides after a step.
sealed class SequenceAction {
  const SequenceAction._();

  /// Advance to the next step (auto or user-prompted).
  const factory SequenceAction.advance({
    required SequenceStep nextStep,
    required Map<String, dynamic> prefill,
    required String progressLabel,
  }) = _Advance;

  /// Sequence complete — show summary.
  const factory SequenceAction.complete({required String summary}) = _Complete;

  /// User abandoned — pause and offer resumption.
  const factory SequenceAction.pause({
    required String message,
    required bool canResume,
  }) = _Pause;

  /// Profile changed — re-evaluate affected steps.
  const factory SequenceAction.reEvaluate({
    required List<String> invalidatedSteps,
  }) = _ReEvaluate;
}
```

### 3.5 Coach Chat intégration

L'intégration dans `CoachChatScreen` :

```
1. Coach détecte l'intention multi-étapes (LLM retourne un tool_use avec sequence_id)
2. SequenceStore.load() — reprendre une séquence existante ou en créer une nouvelle
3. Afficher SequenceProgressCard (barre de progression + étape courante)
4. Ouvrir l'écran de l'étape courante (via RoutePlanner, avec prefill des outputs précédents)
5. Au retour : SequenceAgent.decide() → action
6. Si advance → afficher message de transition + ouvrir étape suivante
7. Si complete → afficher résumé + célébration
8. Si pause → stocker dans SequenceStore pour reprise future
9. Si reEvaluate → recalculer les étapes affectées
```

### 3.6 Output transfer entre étapes

Le mécanisme de transfert d'outputs entre écrans :

```dart
/// Each simulator screen can return structured outputs via ScreenReturn.
/// The SequenceAgent merges these outputs into the prefill of the next step.
///
/// Example flow:
/// Step 1 (/hypotheque) returns: {capacite_achat: 850000, fonds_propres_requis: 170000}
/// Step 2 (/epl) receives prefill: {montant_necessaire: 170000}
/// Step 2 (/epl) returns: {montant_epl: 50000, impact_rente: -200}
/// Step 3 (/fiscal) receives prefill: {montant_retrait: 50000}
```

Chaque `SequenceStep` déclare un `outputMapping` :

```dart
/// Maps output keys from this step to input keys of the next step.
/// Example: {'capacite_achat': 'montant_bien_cible', 'fonds_propres_requis': 'montant_necessaire'}
final Map<String, String> outputMapping;
```

---

## 4. Séquences pré-définies (V1)

Pour le premier prototype, 3 séquences hardcodées :

### 4.1 Achat immobilier (4 étapes)

| Étape | Route | Input de l'étape précédente | Output |
|---|---|---|---|
| 1. Accessibilité | `/hypotheque` | — | capacité_achat, fonds_propres_requis |
| 2. EPL | `/epl` | fonds_propres_requis | montant_epl, impact_rente |
| 3. Fiscalité retrait | `/fiscalite/retrait-capital` | montant_epl | impot_retrait |
| 4. Résumé coach | (inline) | tous les outputs | — |

### 4.2 Optimisation 3a (3 étapes)

| Étape | Route | Input | Output |
|---|---|---|---|
| 1. Simulateur 3a | `/pilier-3a` | — | contribution_annuelle, economie_fiscale |
| 2. Retrait échelonné | `/3a-deep/staggered-withdrawal` | contribution_annuelle | gain_echelonnement |
| 3. Rendement réel | `/3a-deep/real-return` | contribution_annuelle | rendement_net_inflation |

### 4.3 Préparation retraite (5 étapes)

| Étape | Route | Input | Output |
|---|---|---|---|
| 1. Projection | `/retraite` | — | taux_remplacement, gap_mensuel |
| 2. Rente vs Capital | `/rente-vs-capital` | gap_mensuel | decision_mixte |
| 3. Rachat LPP | `/rachat-lpp` | gap_mensuel | economie_rachat |
| 4. Décaissement | `/decaissement` | decision_mixte | calendrier_optimal |
| 5. Résumé coach | (inline) | tous | — |

---

## 5. Anti-patterns et garde-fous

### 5.1 Anti-boucle
- Jamais plus de 2 tentatives sur la même étape dans une session
- Si l'utilisateur abandonne 2 fois → step marqué `skipped`, on passe au suivant

### 5.2 Anti-forçage
- L'utilisateur peut toujours quitter la séquence ("Je veux faire autre chose")
- Le coach propose, ne force jamais
- Séquence pausée = resumable, pas perdue

### 5.3 Cohérence des données
- Si un output de l'étape 1 est invalidé (profil changé), les étapes suivantes sont re-évaluées
- Le `SequenceAgent.reEvaluate()` marque les étapes affectées comme `pending`

### 5.4 Pas de séquences imbriquées
- V1 : une seule séquence active à la fois
- Si l'utilisateur lance une nouvelle séquence, l'ancienne est pausée

---

## 6. Plan d'implémentation

### Phase 1 : Modèles + Store (1 sprint)
- `GuidedSequence`, `SequenceStep`, `SequenceAction` models
- `SequenceStore` (SharedPreferences)
- `SequenceAgent.decide()` (pure function)
- Tests unitaires (20+)

### Phase 2 : UI + Chat integration (1 sprint)
- `SequenceProgressCard` widget (barre + étape courante)
- `CoachChatScreen` : détection d'intention séquence + rendering
- Modification de `_handleRouteReturn` pour chaîner les étapes
- 1 parcours vertical fonctionnel (achat immobilier)

### Phase 3 : Archetype branching + output transfer (1 sprint)
- `outputMapping` entre étapes
- Branching par archétype (expat_us skip, indep_no_lpp adaptation)
- 3 parcours complets
- Tests d'intégration E2E

---

## 7. Ce qu'on NE fait PAS

- **Pas de multi-séquence simultanée** — V1 = une seule active
- **Pas de séquences dynamiques générées par le LLM** — V1 = 3 séquences hardcodées
- **Pas d'auto-advance sans confirmation** — toujours "Prêt pour l'étape suivante ?"
- **Pas de rollback complet** — si étape 1 est invalidée, on re-propose mais on ne supprime pas les données

---

## 8. Métriques de succès

| Métrique | Baseline (actuel) | Cible |
|---|---|---|
| Écrans visités par session | ~1.5 | 3+ |
| Taux de complétion d'un parcours complet | 0% (pas de parcours) | 40% |
| Temps sur le parcours achat immo | — | < 10 min pour 4 étapes |
| Taux d'abandon après étape 1 | — | < 30% |

---

## 9. Risques

| Risque | Probabilité | Mitigation |
|---|---|---|
| Complexité du state machine | Élevée | SequenceAgent est une pure function, 100% testable |
| Output mapping fragile entre écrans | Moyenne | Typage fort, tests de contrat par séquence |
| UX trop directive ("tunnel") | Moyenne | Toujours proposer, jamais forcer. Bouton "Quitter le parcours" |
| Régression sur le chat existant | Faible | Le chat sans séquence fonctionne exactement comme avant |

---

## 10. Décision requise

Avant de coder :
1. **Approuver les 3 séquences V1** (achat immo, 3a, retraite)
2. **Confirmer l'approche "propose, ne force pas"** — auto-advance avec confirmation
3. **Valider le stockage SharedPreferences** vs backend pour l'état de séquence
4. **Décider** : Phase 1 seule (modèles + tests) ou Phase 1+2 (modèles + UI) dans le prochain sprint ?
