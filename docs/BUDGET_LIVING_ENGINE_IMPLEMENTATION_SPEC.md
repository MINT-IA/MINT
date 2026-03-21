# BudgetLivingEngine + BudgetSnapshot — Implementation Spec

> Statut: spec technique exécutable
> Rôle: permettre à un agent Flutter d'implémenter `BudgetSnapshot`, `RetirementBudgetService` et `BudgetLivingEngine` sans réinterpréter la vision
> Source de vérité: oui, pour ce chantier
> Dépend de: `CLAUDE.md`, `MINT_UX_GRAAL_MASTERPLAN.md`, `MINT_CAP_ENGINE_SPEC.md`, `BUDGET_VIVANT_ARCHITECTURE.md`
> Ne couvre pas: refonte visuelle complète de `Aujourd'hui`, réécriture du coach, backend

---

## 1. Scope

Ce chantier doit:
- créer un objet unifié `BudgetSnapshot`
- créer un service `RetirementBudgetService`
- créer un orchestrateur `BudgetLivingEngine`
- brancher `Aujourd'hui` sur ce snapshot
- injecter ce snapshot dans le coach

Ce chantier ne doit pas:
- casser le shell 4 onglets
- changer les calculateurs métier centraux
- introduire une seconde source de vérité hors `CoachProfile`
- supprimer des écrans existants

---

## 2. Fichiers à créer

### Modèles
- `apps/mobile/lib/models/budget_snapshot.dart`

### Services
- `apps/mobile/lib/services/retirement_budget_service.dart`
- `apps/mobile/lib/services/budget_living_engine.dart`

### Tests
- `apps/mobile/test/services/retirement_budget_service_test.dart`
- `apps/mobile/test/services/budget_living_engine_test.dart`

---

## 3. Fichiers à modifier

### Intégration
- `apps/mobile/lib/screens/pulse/pulse_screen.dart`
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart`
- `apps/mobile/lib/services/coach_llm_service.dart`

### Optionnel selon architecture existante
- `apps/mobile/lib/providers/coach_profile_provider.dart`

### Tests à réaligner
- `apps/mobile/test/screens/pulse/pulse_screen_test.dart`
- `apps/mobile/test/services/coach_llm_service_test.dart`

---

## 4. Modèle cible

## 4.1 budget_snapshot.dart

```dart
enum BudgetStage {
  presentOnly,
  emergingRetirement,
  fullGapVisible,
}

class PresentBudget {
  final double monthlyIncome;
  final double monthlyCharges;
  final double monthlyFree;

  const PresentBudget({
    required this.monthlyIncome,
    required this.monthlyCharges,
    required this.monthlyFree,
  });
}

class RetirementBudget {
  final double avsMonthly;
  final double lppMonthly;
  final double pillar3aMonthly;
  final double otherMonthly;
  final double monthlyCharges;
  final double monthlyFree;

  const RetirementBudget({
    required this.avsMonthly,
    required this.lppMonthly,
    required this.pillar3aMonthly,
    required this.otherMonthly,
    required this.monthlyCharges,
    required this.monthlyFree,
  });
}

class BudgetGap {
  final double monthlyGap;
  final double ratioRetained;
  final bool isPositive;

  const BudgetGap({
    required this.monthlyGap,
    required this.ratioRetained,
    required this.isPositive,
  });
}

class BudgetCapImpact {
  final String? now;
  final String? later;
  final String? sequence;

  const BudgetCapImpact({
    this.now,
    this.later,
    this.sequence,
  });
}

class BudgetCapSequenceStep {
  final String label;
  final String effect;

  const BudgetCapSequenceStep({
    required this.label,
    required this.effect,
  });
}

class BudgetCapSequence {
  final String title;
  final List<BudgetCapSequenceStep> steps;
  final String? cumulativeBenefit;

  const BudgetCapSequence({
    required this.title,
    required this.steps,
    this.cumulativeBenefit,
  });
}

class BudgetSnapshot {
  final PresentBudget present;
  final RetirementBudget? retirement;
  final BudgetGap? gap;
  final CapDecision cap;
  final BudgetCapImpact? capImpact;
  final BudgetCapSequence? capSequence;
  final int confidenceScore;
  final BudgetStage stage;
  final GoalA? activeGoal;
  final List<CapSignal> supportingSignals;
  final DateTime computedAt;

  const BudgetSnapshot({
    required this.present,
    required this.retirement,
    required this.gap,
    required this.cap,
    required this.capImpact,
    required this.capSequence,
    required this.confidenceScore,
    required this.stage,
    this.activeGoal,
    required this.supportingSignals,
    required this.computedAt,
  });
}
```

### Règles
- `RetirementBudget` peut être `null`
- `BudgetGap` peut être `null`
- `cap` est toujours présent
- `capImpact` peut être `null` si le cap est purement `Complete`
- `capSequence` est rare en V1, surtout pour LPP / 3a / fiscal

---

## 5. RetirementBudgetService

## 5.1 Rôle

Transformer la projection retraite existante en budget mensuel lisible.

### Entrées
- `CoachProfile profile`
- `ProjectionResult projection`
- `int confidenceScore`

### Sortie
- `RetirementBudget?`

### Interface

```dart
abstract final class RetirementBudgetService {
  static RetirementBudget? compute({
    required CoachProfile profile,
    required ProjectionResult? projection,
    required int confidenceScore,
  });
}
```

## 5.2 Règles V1

### Revenu retraite
- `avsMonthly` depuis la projection existante
- `lppMonthly` depuis la projection existante
- `pillar3aMonthly`:
  - utiliser l'annualisation existante si disponible
  - sinon `0`
- `otherMonthly`:
  - `0` en V1 si pas de source fiable

### Charges retraite
Heuristique V1 acceptable:
- partir des charges actuelles connues
- exclure les éléments purement actifs si défendable plus tard
- ou utiliser une réduction prudente explicite

Règle:
- le service doit documenter que `monthlyCharges` est une estimation éducative

### monthlyFree

```text
monthlyFree = avsMonthly + lppMonthly + pillar3aMonthly + otherMonthly - monthlyCharges
```

## 5.3 Garde-fous

- si `confidenceScore < 45`, retourner une sortie prudente ou `null`
- si `projection == null`, retourner `null`
- si le profil manque trop de données retraite, retourner `null`
- ne pas produire une précision artificielle sans certificat LPP

---

## 6. BudgetLivingEngine

## 6.1 Interface

```dart
abstract final class BudgetLivingEngine {
  static BudgetSnapshot compute({
    required CoachProfile profile,
    required DateTime now,
    CapMemory? memory,
  });
}
```

## 6.2 Dépendances

- `BudgetService`
- `ForecasterService`
- `RetirementBudgetService`
- `FinancialFitnessService` ou `ConfidenceScorer` selon le point d'entrée le plus fiable
- `CapEngine`

## 6.3 Pipeline

1. calculer `PresentBudget`
2. calculer `ProjectionResult`
3. calculer `confidenceScore`
4. calculer `RetirementBudget?`
5. calculer `BudgetGap?`
6. appeler `CapEngine`
7. dériver `BudgetCapImpact?`
8. dériver `BudgetCapSequence?`
9. choisir `BudgetStage`
10. retourner `BudgetSnapshot`

---

## 7. PresentBudget

## 7.1 Source

Utiliser [BudgetService](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/domain/budget/budget_service.dart) si possible.

Si le service existant ne retourne pas directement le trio:
- `monthlyIncome`
- `monthlyCharges`
- `monthlyFree`

alors créer un adapter minimal dans `BudgetLivingEngine`, pas un second service.

## 7.2 Règle

Le budget présent doit rester le plus concret possible:
- revenu mensuel
- charges mensuelles
- libre mensuel

Pas de score au centre.
Pas de ratio abstrait comme héro.

---

## 8. BudgetGap

## 8.1 Calcul

Seulement si:
- `RetirementBudget != null`
- confiance suffisante

```text
monthlyGap = present.monthlyFree - retirement.monthlyFree
ratioRetained = retirement.monthlyFree / present.monthlyFree
isPositive = monthlyGap <= 0
```

## 8.2 Règles

- si `present.monthlyFree <= 0`, `ratioRetained` doit être traité prudemment
- si l'écart n'est pas défendable, on masque le `gap`
- on ne montre pas un `gap` si la base retraite est trop faible en confiance

---

## 9. BudgetStage

## 9.1 presentOnly

Conditions:
- profil présent
- confiance faible
- ou retraite non calculable

UI:
- hero = budget actuel
- retraite absente ou ultra discrète
- cap de complétude ou premier levier

## 9.2 emergingRetirement

Conditions:
- retraite calculable
- confiance moyenne

UI:
- budget retraite visible
- `gap` encore prudent
- mention de confiance explicite

## 9.3 fullGapVisible

Conditions:
- retraite calculable
- confiance suffisante
- `gap` défendable

UI:
- budget actuel
- budget retraite
- gap
- cap relié au gap

---

## 10. capImpact

## 10.1 Rôle

Traduire le cap dans le langage du budget et du temps.

## 10.2 Interface

```dart
BudgetCapImpact? _deriveCapImpact({
  required CoachProfile profile,
  required CapDecision cap,
  required BudgetSnapshotDraft draft,
});
```

## 10.3 V1

Gérer explicitement seulement quelques cas:
- `pillar_3a`
- `lpp_buyback`
- `couple_lpp_buyback`
- `couple_3a`
- `budget_deficit`
- `replacement_rate`

Exemples:
- `now`: `~CHF 2'800 d'impôt en moins cette année`
- `later`: `écart retraite réduit de 12%`
- `sequence`: `~CHF 8'500 cumulés sur 3 ans`

Si inconnu:
- `null` plutôt qu'une phrase faible

---

## 11. capSequence

## 11.1 Rôle

Montrer une stratégie courte, pas juste un levier ponctuel.

## 11.2 V1

Ne gérer explicitement que:
- `rachats LPP échelonnés`
- éventuellement `versements 3a répétés`

## 11.3 Exemple

```dart
BudgetCapSequence(
  title: 'Rachats LPP échelonnés',
  steps: const [
    BudgetCapSequenceStep(
      label: 'Cette année',
      effect: '~CHF 2\'800 d’impôt en moins',
    ),
    BudgetCapSequenceStep(
      label: 'Année suivante',
      effect: 'nouveau rachat selon ton TMI',
    ),
    BudgetCapSequenceStep(
      label: 'À la retraite',
      effect: 'écart réduit de 12%',
    ),
  ],
  cumulativeBenefit: '~CHF 8\'500 cumulés sur 3 ans',
)
```

Règles:
- max 3 étapes
- pas de plan sur 15 ans
- pas de stratégie si la confiance ne le justifie pas

---

## 12. Intégration dans PulseScreen

## 12.1 Rôle

[PulseScreen](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/pulse/pulse_screen.dart) devient consommateur principal de `BudgetSnapshot`.

## 12.2 Ce qu'il faut remplacer

Remplacer progressivement:
- `_cachedProjection` + `_cachedFri` + `_cachedCap` comme trio de lecture

Par:
- `_cachedSnapshot`

## 12.3 État cible

```dart
BudgetSnapshot? _cachedSnapshot;
```

## 12.4 Build

Le build lit:
- `snapshot.present.monthlyFree`
- `snapshot.retirement?.monthlyFree`
- `snapshot.gap`
- `snapshot.cap`
- `snapshot.capImpact`
- `snapshot.capSequence`
- `snapshot.confidenceScore`

## 12.5 V1 visuel minimal

Le hero est **contextuel au goal actif**, pas toujours le libre mensuel:
- si `GoalA.retraite` → hero = gap ou libre retraite
- si `GoalA.debtFree` → hero = marge à retrouver
- si `GoalA.achatImmo` → hero = capacité d'achat
- si pas de goal déclaré → hero = `monthlyFree` présent (sol neutre)

Autres éléments:
- bloc retraite secondaire si dispo
- ligne `gap` si `fullGapVisible`
- carte cap enrichie avec `impact_now` / `impact_later`

---

## 13. Injection dans Coach

## 13.1 Où

- [coach_chat_screen.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/coach/coach_chat_screen.dart)
- [coach_llm_service.dart](/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/services/coach_llm_service.dart)

## 13.2 Règle

Le coach ne recalcule pas lui-même la situation.

Il **appelle** le `BudgetSnapshot` via un tool Claude, pas seulement le reçoit passivement.

## 13.3 Tool Claude

Ajouter dans `coach_tools.py`:

```python
{
    "name": "show_budget_snapshot",
    "description": (
        "Affiche le budget vivant complet: libre aujourd'hui, "
        "libre retraite, gap, confiance et levier. "
        "Utilise quand l'utilisateur demande ou j'en suis, "
        "mon budget, ma situation, combien il me reste."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "present_free": {"type": "number"},
            "retirement_free": {"type": "number"},
            "gap": {"type": "number"},
            "confidence": {"type": "integer"},
            "lever_now": {"type": "string"},
            "lever_later": {"type": "string"},
            "narrative": {"type": "string"},
        },
        "required": ["present_free", "narrative"],
    },
}
```

Le backend compute le BudgetSnapshot et injecte les données dans le contexte.
Claude choisit quand appeler ce tool — pas systématiquement.

## 13.4 Format prompt (en complément du tool)

Ajouter au prompt / contexte:

```text
Budget snapshot:
- Libre aujourd'hui: CHF X/mois
- Libre retraite: CHF Y/mois
- Gap: CHF Z/mois
- Confiance: N%
- Cap actuel: ...
- Impact court terme: ...
- Impact long terme: ...
- Séquence: ...
```

Règle:
- le coach parle dans le langage de la marge et du gap
- il ne remplace pas les chiffres par de l'interprétation floue

---

## 14. Tests

## 14.1 retirement_budget_service_test.dart

Cas minimum:
1. retourne `null` si projection absente
2. retourne `null` si confiance trop faible
3. calcule un budget retraite simple avec AVS + LPP + 3a
4. monthlyFree = revenus - charges
5. reste prudent si certificat absent

## 14.2 budget_living_engine_test.dart

Cas minimum:
1. produit toujours un `BudgetSnapshot`
2. `present` toujours rempli
3. `stage = presentOnly` si retraite indisponible
4. `stage = emergingRetirement` si retraite dispo mais confiance moyenne
5. `stage = fullGapVisible` si gap défendable
6. `gap` bien calculé quand les deux budgets existent
7. `cap` bien propagé
8. `capImpact` peuplé sur un cas 3a ou LPP
9. `capSequence` peuplé sur un cas rachat échelonné

## 14.3 pulse_screen_test.dart

À ajouter / réaligner:
1. affiche le libre mensuel présent comme hero
2. affiche le budget retraite si snapshot stage >= `emergingRetirement`
3. affiche le gap si `fullGapVisible`
4. affiche l'impact court terme / long terme du cap si présent

---

## 15. Ordre recommandé d'implémentation

### PR 1
- `budget_snapshot.dart`
- `retirement_budget_service.dart`
- tests du service

### PR 2
- `budget_living_engine.dart`
- tests engine

### PR 3
- branchement minimal dans `pulse_screen.dart`
- tests widget

### PR 4
- injection dans le coach
- réalignement tests coach

### PR 5
- ajout de `capSequence` sur les premiers cas LPP / 3a

---

## 16. Anti-régressions

- ne pas casser `CapEngine`
- ne pas dupliquer la logique budgétaire déjà dans `BudgetService`
- ne pas créer un snapshot qui ment plus que les services source
- ne pas cacher la confiance ou l'absence de preuve
- ne pas transformer `Aujourd'hui` en tableau comptable dense

---

## 17. Definition of Done

Le chantier est réussi si:
- `Aujourd'hui` peut être alimenté par un objet unique cohérent
- le coach reçoit le même état utilisateur que `Aujourd'hui`
- le gap devient une donnée explicable
- les leviers peuvent être exprimés en `maintenant / plus tard / séquence`
- la vision `budget vivant` devient implémentable sans casser l'architecture actuelle
