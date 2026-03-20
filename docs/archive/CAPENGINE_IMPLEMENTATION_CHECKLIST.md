# CAPENGINE IMPLEMENTATION CHECKLIST

> Statut: checklist d'implémentation Flutter
> Horizon: Phase 0 -> Phase 1
> Dépend de: `MINT_UX_GRAAL_MASTERPLAN.md`, `MINT_CAP_ENGINE_SPEC.md`, `DESIGN_SYSTEM.md`, `VOICE_SYSTEM.md`
> Objectif: livrer `CapEngine`, refondre `ResponseCardWidget`, puis brancher `Aujourd'hui V5`

---

## 1. But

Cette checklist transforme la vision `plan-first, coach-orchestrated` en chantier Flutter exécutable.

Ordre cible:
1. `CapDecision` + `CapMemoryStore`
2. `CapEngine`
3. `ResponseCardWidget` refondu
4. `Aujourd'hui V5`
5. feedback loop minimal après action

---

## 2. Règles de chantier

- ne pas toucher `coach_llm_service.dart` dans ce chantier
- ne pas coupler ce chantier à la voix temps réel
- ne pas déplacer les calculs métier hors services existants
- ne pas réintroduire de strings hardcodées
- utiliser exclusivement les tokens MINT
- préserver les fallbacks sans BYOK

---

## 3. PR 1 — Cap contracts

### Objectif

Poser le socle de données sans toucher à l'UI.

### Fichiers à créer

- `apps/mobile/lib/models/cap_decision.dart`
- `apps/mobile/lib/services/cap_memory_store.dart`
- `test/services/cap_memory_store_test.dart`

### À implémenter

- `enum CapKind`
- `class CapSignal`
- `class CapMemory`
- `class CapDecision`
- sérialisation JSON simple
- store `SharedPreferences` pour:
  - `lastCapServed`
  - `lastCapDate`
  - `completedActions`
  - `abandonedFlows`
  - `preferredCtaMode`
  - `declaredGoals`
  - `recentFrictionContext`

### DOD

- load/save idempotent
- valeurs par défaut sûres
- tests store verts

---

## 4. PR 2 — CapEngine V1

### Objectif

Produire une priorité unique stable et actionnable.

### Fichiers à créer

- `apps/mobile/lib/services/cap_engine.dart`
- `test/services/cap_engine_test.dart`

### Fichiers à intégrer

- `apps/mobile/lib/services/pulse_hero_engine.dart`
- `apps/mobile/lib/services/response_card_service.dart`
- `apps/mobile/lib/services/financial_core/confidence_scorer.dart`
- `apps/mobile/lib/models/coach_profile.dart`

### À implémenter

- `CapEngine.compute(profile, memory)`
- intégration `ConfidenceScorer.score(profile)`
- intégration `ResponseCardService.generateForPulse(profile, limit: 5)`
- fallback possible via `PulseHeroEngine.compute(profile)`
- priorités:
  - `Complete` si confiance basse + donnée bloquante
  - `Correct` si budget/dette
  - `Secure` si protection/risque
  - `Optimize` si fenêtre fiscale/retraite
  - `Prepare` si life event
- règles:
  - `recency_modifier`
  - `expiry rule`
  - `budget deficit reframing`
  - `never show bad number alone`
  - `proof after narrative`

### DOD

- toujours 1 `CapDecision`
- jamais de cap vide si profil existe
- rotation correcte après répétition
- tests heuristiques verts

---

## 5. PR 3 — ResponseCardWidget refonte

### Objectif

Calmer le dernier gros composant legacy sans casser le coach.

### Fichiers à modifier

- `apps/mobile/lib/widgets/coach/response_card_widget.dart`
- `apps/mobile/lib/models/response_card.dart`
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart`

### Tests

- `test/widgets/coach/response_card_widget_test.dart`

### À implémenter

- introduire variantes:
  - `chat`
  - `compact`
  - `sheet`
- supprimer:
  - largeur fixe
  - bordure gauche agressive
  - badge `+pts`
  - footer sources toujours visible
- déplacer preuve et sources vers une couche secondaire
- garder 1 CTA visible
- utiliser `MintTextStyles` et tokens MINT
- vérifier les semantics

### DOD

- lecture en 3 secondes
- une action visible
- preuve accessible mais non envahissante
- rendu coach plus calme

---

## 6. PR 4 — Aujourd'hui V5

### Objectif

Brancher `CapEngine` dans `Aujourd'hui`.

### Fichiers à créer

- `apps/mobile/lib/widgets/pulse/cap_card.dart`
- `test/widgets/pulse/pulse_screen_test.dart`

### Fichiers à modifier

- `apps/mobile/lib/screens/pulse/pulse_screen.dart`

### À implémenter

- calculer `CapDecision` dans `PulseScreen`
- remplacer la logique d'action prioritaire actuelle
- utiliser:
  - `headline`
  - `why_now`
  - `cta`
  - `expected_impact`
- garder le chiffre dominant actuel
- garder 2 signaux secondaires max
- gérer les 3 modes CTA:
  - `route`
  - `coach`
  - `capture`
- fallback legacy si `CapEngine` échoue

### DOD

- `Aujourd'hui` = 1 phrase + 1 chiffre + 1 action + 2 signaux
- aucun chiffre défavorable seul
- CTA fiable dans les 3 modes
- zéro régression empty state

---

## 7. PR 5 — Action feedback minimal

### Objectif

Rendre le système vivant sans grosse refonte.

### Fichiers à modifier

- `apps/mobile/lib/services/cap_memory_store.dart`
- `apps/mobile/lib/screens/pulse/pulse_screen.dart`
- éventuellement `apps/mobile/lib/providers/coach_profile_provider.dart`

### À implémenter

- `markCompleted`
- `markAbandoned`
- micro feedback dans `Aujourd'hui`:
  - `ajouté récemment`
  - `impact recalculé`
- préparer le retour `what changed`

### DOD

- action complétée visible au retour
- recalcul du cap observable
- pas de duplication de message

---

## 8. Commandes à lancer

```bash
flutter analyze
flutter test test/services/cap_memory_store_test.dart
flutter test test/services/cap_engine_test.dart
flutter test test/widgets/coach/response_card_widget_test.dart
flutter test test/widgets/pulse/pulse_screen_test.dart
```

---

## 9. Risques connus

- `PulseHeroEngine` et `CapEngine` peuvent se marcher dessus
  - décision: `PulseHeroEngine` devient fallback only pour `Aujourd'hui`
- trop de logique dans `PulseScreen`
  - décision: pousser toute décision dans `CapEngine`
- fuite de complexité dans `ResponseCard`
  - décision: ne pas enrichir le modèle tant que la vue ne l'exige pas

---

## 10. Ordre recommandé

1. PR 1
2. PR 2
3. PR 3
4. PR 4
5. PR 5

---

## 11. Critère final de réussite

Le chantier est réussi si:
- `Aujourd'hui` affiche un vrai `Cap du jour`
- la priorité du moment est stable, claire et justifiée
- le coach récupère le contexte sans devenir le point de vérité principal
- les cartes coach n'ont plus la grammaire visuelle legacy
- l'utilisateur voit ce qui a changé après action
