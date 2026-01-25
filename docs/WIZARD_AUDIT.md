# Audit Complet : Wizard Mint (Cercles Herméneutiques)

**Date** : 2026-01-11  
**Objectif** : Finaliser l'app avec cohérence Tout ⇄ Parties ⇄ Retour

---

## 🎯 Cercle 1 : Le "Tout" (Vision Globale)

### Intention Originale
**Mint = Conseiller proactif qui transforme l'ambiguïté en un plan d'actions sûr, compréhensible et exécutable, avec transparence sur conflits/commissions et limites.**

### Invariants (Non-Négociables)
1. **Rapport/Plan comme livrable central** (pas un jeu)
2. **Neutralité & Compliance** (pas d'incitation au risque)
3. **Simplicité** (une métrique, une action)

---

## 📦 Cercle 2 : Les "Parties" (Ce qui a été fait)

### ✅ Fichiers Créés

#### Documentation
1. `docs/decisions/ADR-20260111-wizard-progression-clarte.md` ✅
   - Définit progression de clarté vs gamification
   - Garde-fous Safe Mode
   - Scénarios prudence/central/stress

2. `docs/WIZARD_QUESTIONS_SPEC.md` ✅
   - ~60 questions avec IDs stables
   - Tags, conditions, timeline items
   - Branches par situation/âge/événements

3. `docs/WIZARD_DIDACTIC_EXPLANATIONS.md` ✅
   - Explications par l'exemple
   - Formulations conditionnelles
   - Bifurcation employé/indépendant

4. `docs/WIZARD_SPEC.md` ⚠️
   - Ancienne version (gamification)
   - **À SUPPRIMER ou ARCHIVER**

#### Modèles
5. `apps/mobile/lib/models/wizard_question.dart` ✅
   - Structure de questions
   - Support conditions, validation

6. `apps/mobile/lib/models/clarity_state.dart` ✅
   - Indice de précision (0-100%)
   - Actions prêtes
   - Safe Mode

7. `apps/mobile/lib/models/age_band_policy.dart` ✅
   - Tranches d'âge
   - Événements récurrents
   - Événements de vie

8. `apps/mobile/lib/models/gamification.dart` ❌
   - **À SUPPRIMER** (remplacé par clarity_state.dart)

#### Widgets
9. `apps/mobile/lib/widgets/simulation_widgets.dart` ✅
   - CompoundInterestChart (scénarios prudence/central/stress)
   - LppBuybackSimulation (formulations conditionnelles)

10. `apps/mobile/lib/widgets/interactive_simulations.dart` ✅
    - Interactive3aSimulation (curseurs)
    - InteractiveLppBuybackSimulation (curseurs)

#### Data
11. `apps/mobile/lib/data/wizard_questions.dart` ⚠️
    - Liste exhaustive des questions
    - **MANQUE** : intégration avec WIZARD_QUESTIONS_SPEC.md

---

## 🔄 Cercle 3 : Le "Retour" (Réconciliation)

### ❌ Gaps Identifiés

#### 1. **Incohérence Documentation**
- `WIZARD_SPEC.md` (ancienne version gamification) ≠ `ADR-20260111-wizard-progression-clarte.md`
- **Action** : Supprimer ou archiver `WIZARD_SPEC.md`

#### 2. **Fichier Obsolète**
- `gamification.dart` existe encore
- **Action** : Supprimer `gamification.dart`

#### 3. **Questions Non Implémentées**
- `WIZARD_QUESTIONS_SPEC.md` contient ~60 questions
- `wizard_questions.dart` contient seulement ~20 questions
- **Action** : Générer toutes les questions depuis la spec

#### 4. **Manque Intégration Simulations**
- Simulations interactives créées mais pas intégrées dans le wizard
- **Action** : Créer `WizardQuestionWithSimulation` widget

#### 5. **Manque Timeline Service**
- Timeline items définis mais pas de service pour les gérer
- **Action** : Créer `TimelineService` pour rappels automatiques

#### 6. **Manque Backend Integration**
- Questions définies mais pas d'endpoints backend
- **Action** : Créer endpoints `/sessions/wizard` et `/sessions/timeline`

#### 7. **Manque Tests**
- Aucun test pour Safe Mode
- Aucun test pour partner_handoff
- **Action** : Créer tests de compliance

#### 8. **Manque Aperçu Rapport**
- ADR spécifie "aperçu rapport dès Acte 3"
- **Action** : Créer `ReportPreviewWidget`

---

## 🎯 Plan d'Optimisation & Nettoyage

### Phase 1 : Nettoyage (Priorité Haute)

```bash
# 1. Supprimer fichiers obsolètes
rm docs/WIZARD_SPEC.md  # Ou archiver dans docs/archive/
rm apps/mobile/lib/models/gamification.dart

# 2. Archiver ancienne gamification
mkdir -p docs/archive
mv docs/WIZARD_GAMIFICATION.md docs/archive/ (si existe)
```

### Phase 2 : Génération Questions (Priorité Haute)

**Créer** : `apps/mobile/lib/data/wizard_questions_generated.dart`
- Générer toutes les ~60 questions depuis `WIZARD_QUESTIONS_SPEC.md`
- Inclure explications didactiques depuis `WIZARD_DIDACTIC_EXPLANATIONS.md`
- Intégrer simulations interactives

### Phase 3 : Services Manquants (Priorité Haute)

**Créer** : `apps/mobile/lib/services/timeline_service.dart`
```dart
class TimelineService {
  // Créer timeline items depuis réponses
  List<TimelineItem> generateTimeline(Map<String, dynamic> answers);
  
  // Rappels automatiques
  List<Reminder> getUpcomingReminders();
  
  // Delta sessions
  List<WizardQuestion> getDeltaQuestions(LifeEventType event);
}
```

**Créer** : `apps/mobile/lib/services/wizard_service.dart`
```dart
class WizardService {
  // Filtrage dynamique questions
  List<WizardQuestion> getQuestionsForUser(Profile profile);
  
  // Calcul précision
  ClarityState calculateClarityState(Map<String, dynamic> answers);
  
  // Safe Mode
  bool isSafeModeActive(Map<String, dynamic> answers);
}
```

### Phase 4 : Widgets Manquants (Priorité Moyenne)

**Créer** : `apps/mobile/lib/widgets/wizard_question_widget.dart`
```dart
class WizardQuestionWidget extends StatelessWidget {
  final WizardQuestion question;
  final Function(dynamic) onAnswer;
  
  // Affiche question + simulation interactive si applicable
  // Affiche explication didactique si demandée
}
```

**Créer** : `apps/mobile/lib/widgets/report_preview_widget.dart`
```dart
class ReportPreviewWidget extends StatelessWidget {
  final ClarityState state;
  
  // Aperçu rapport dès Acte 3
  // Top 3 actions
  // Indice de précision
}
```

### Phase 5 : Backend (Priorité Moyenne)

**Créer** : `services/backend/app/routes/wizard.py`
```python
@router.post("/sessions/wizard")
async def create_wizard_session(answers: dict):
    # Sauvegarder réponses
    # Générer timeline items
    # Calculer clarity state
    # Retourner session + rapport

@router.get("/sessions/{session_id}/timeline")
async def get_timeline(session_id: str):
    # Retourner timeline items + rappels
```

### Phase 6 : Tests (Priorité Haute)

**Créer** : `apps/mobile/test/wizard_test.dart`
```dart
// Test Safe Mode
test('Safe Mode: no investment suggestions when debt > 30%', () {
  final answers = {'debt_ratio': 0.35};
  final state = ClarityState.calculate(answers, {});
  final investmentAction = state.actions.firstWhere((a) => a.id == 'investment');
  expect(investmentAction.status, ActionStatus.blocked);
});

// Test partner_handoff
test('partner_handoff: must include disclosure and alternatives', () {
  final report = generateReport(answers);
  final handoff = report.partnerHandoffs.first;
  expect(handoff.disclosure, isNotEmpty);
  expect(handoff.alternatives, isNotEmpty);
});

// Test filtrage questions
test('Questions filtered by age', () {
  final profile = Profile(birthYear: 1995); // 31 ans
  final questions = WizardService.getQuestionsForUser(profile);
  expect(questions.any((q) => q.id == 'q_young_first_job_date'), false);
  expect(questions.any((q) => q.id == 'q_mid_housing_purchase_project'), true);
});
```

---

## 📊 Matrice de Cohérence (Tout ⇄ Parties)

| Invariant | Parties Concernées | Status | Action |
|-----------|-------------------|--------|--------|
| **Rapport central** | ReportPreviewWidget | ❌ Manquant | Créer widget |
| **Neutralité** | Safe Mode tests | ❌ Manquant | Créer tests |
| **Simplicité** | ClarityState | ✅ OK | - |
| **Scénarios prudence/central/stress** | Simulations | ✅ OK | - |
| **Formulations conditionnelles** | Explications | ✅ OK | - |
| **Bifurcation statut** | Interactive3aSimulation | ✅ OK | - |
| **Timeline automatique** | TimelineService | ❌ Manquant | Créer service |
| **Disclaimers** | Toutes simulations | ✅ OK | - |

---

## 🎯 Priorisation (MoSCoW)

### Must Have (Blocker pour MVP)
1. ✅ Supprimer fichiers obsolètes
2. ✅ Générer toutes les questions depuis spec
3. ✅ Créer TimelineService
4. ✅ Créer WizardService
5. ✅ Créer tests Safe Mode
6. ✅ Créer ReportPreviewWidget

### Should Have (Important mais pas blocker)
7. ⏳ Créer backend endpoints
8. ⏳ Intégrer simulations dans wizard
9. ⏳ Créer tests partner_handoff

### Could Have (Nice to have)
10. ⏳ Créer simulations fonds d'urgence
11. ⏳ Créer simulations hypothèque
12. ⏳ Créer simulations leasing

### Won't Have (Phase 2+)
- Événements de vie complexes (immigration, RSU)
- Leaderboard
- Animations avancées

---

## 🚀 Plan d'Exécution (Ordre Logique)

### Étape 1 : Nettoyage (5 min)
```bash
rm docs/WIZARD_SPEC.md
rm apps/mobile/lib/models/gamification.dart
```

### Étape 2 : Génération Questions (30 min)
- Créer `wizard_questions_generated.dart`
- Parser `WIZARD_QUESTIONS_SPEC.md`
- Intégrer explications didactiques

### Étape 3 : Services (45 min)
- Créer `TimelineService`
- Créer `WizardService`
- Intégrer avec `ClarityState`

### Étape 4 : Widgets (30 min)
- Créer `WizardQuestionWidget`
- Créer `ReportPreviewWidget`
- Intégrer simulations interactives

### Étape 5 : Tests (30 min)
- Tests Safe Mode
- Tests filtrage questions
- Tests timeline

### Étape 6 : Backend (45 min)
- Endpoints wizard
- Endpoints timeline
- Intégration avec frontend

### Étape 7 : Intégration Finale (30 min)
- Refaire `advisor_wizard_screen.dart`
- Intégrer tous les composants
- Tests E2E

**Temps total estimé : ~3h30**

---

## ✅ Checklist Finale

### Documentation
- [x] ADR progression de clarté
- [x] Spec questions complète
- [x] Explications didactiques
- [ ] Supprimer docs obsolètes

### Modèles
- [x] WizardQuestion
- [x] ClarityState
- [x] AgeBandPolicy
- [ ] Supprimer Gamification

### Widgets
- [x] SimulationWidgets (statiques)
- [x] InteractiveSimulations (curseurs)
- [ ] WizardQuestionWidget
- [ ] ReportPreviewWidget

### Services
- [ ] TimelineService
- [ ] WizardService

### Backend
- [ ] Endpoints wizard
- [ ] Endpoints timeline

### Tests
- [ ] Safe Mode
- [ ] Filtrage questions
- [ ] Partner handoff
- [ ] Timeline

---

## 🎯 Conclusion

**État actuel** : 60% complet
- ✅ Fondations solides (modèles, simulations, explications)
- ⚠️ Manque intégration (services, widgets, backend)
- ❌ Manque tests compliance

**Prochaine action** : Exécuter Plan d'Exécution (Étapes 1-7)

**Estimation pour MVP complet** : ~3h30 de dev
