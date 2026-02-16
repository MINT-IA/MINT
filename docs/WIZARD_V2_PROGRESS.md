# 🚀 REFONTE WIZARD V2 - PROGRESSION

**Démarré le** : 18 janvier 2026, 16:35  
**Approche** : Théorie des Cercles appliquée au développement

---

## ✅ CERCLE 1 : FONDATIONS - TERMINÉ (100%)

### Modèles de Données Créés

1. **`lib/models/circle_score.dart`** ✅
   - `CircleScore` : Score par cercle (1-4)
   - `FinancialHealthScore` : Score global
   - `ScoreItem` : Item individuel de scoring
   - Enums : `ScoreLevel`, `ItemStatus`

2. **`lib/models/financial_report.dart`** ✅
   - `FinancialReport` : Rapport exhaustif final
   - `UserProfile` : Profil utilisateur enrichi
   - `TaxSimulation` : Simulation fiscale
   - `RetirementProjection` : Projection retraite
   - `Pillar3aAnalysis` : Analyse 3a
   - `LppBuybackStrategy` : Stratégie rachat LPP
   - `ActionItem`, `Roadmap` : Recommandations

---

## 🔄 CERCLE 2 : SERVICES CORE - EN COURS (40%)

### Services Créés

1. **`lib/services/circle_scoring_service.dart`** ✅
   - Calcul score par cercle (1-4)
   - Génération recommandations
   - Top 3 priorités

### Services à Créer

2. **`lib/services/financial_report_service.dart`** ⏳
   - Génération rapport exhaustif
   - Intégration scoring + simulations
   - Format export (Markdown/HTML)

3. **`lib/services/tax_calculator_service_v2.dart`** ⏳
   - Calcul fiscal cantonalisé précis
   - Simulation rachat LPP
   - Marginal vs effectif rate

4. **`lib/services/retirement_projection_service.dart`** ⏳
   - Projection capital LPP + 3a
   - Estimation rentes AVS/LPP
   - Taux de remplacement

5. **`lib/services/pillar3a_optimizer_service.dart`** ⏳
   - Comparaison VIAC vs Banque vs Assurance
   - Calcul optimisation multi-comptes retrait
   - Projection rendements

---

## ⏸️ CERCLE 3 : WIDGETS ÉDUCATIFS - À FAIRE (0%)

### Widgets à Créer

1. **`lib/widgets/comparators/pillar3a_comparator_widget.dart`**
   - Tableau comparatif VIAC / Finpension / Banque / Assurance
   - Projection 30 ans
   - CTA "Ouvre ton compte"

2. **`lib/widgets/simulators/lpp_buyback_simulator_widget.dart`**
   - Input : âge, montant rachetable, revenu, canton
   - Output : Planning année par année
   - Économie fiscale totale

3. **`lib/widgets/projections/retirement_timeline_widget.dart`**
   - Frise temporelle jusqu'à 65 ans
   - Jalons (rachats LPP, max 3a, etc.)
   - Capital estimé à chaque étape

4. **`lib/widgets/educational/emergency_fund_widget.dart`**
   - Calcul 3-6 mois de charges
   - Où placer le fonds
   - Stratégie constitution

---

## ⏸️ CERCLE 4 : INTÉGRATION WIZARD - À FAIRE (0%)

### Refactoring à Faire

1. **`lib/data/wizard_questions_v2.dart`**
   - Nouveau flow 25 questions
   - Logique conditionnelle (skip LPP si indépendant, etc.)
   - Explications intégrées

2. **`lib/screens/advisor/advisor_wizard_screen_v2.dart`**
   - Gestion état scoring en temps réel
   - Barre progression par cercle
   - Popup intermédiaire intelligent

3. **`lib/screens/advisor/advisor_report_screen_v2.dart`**
   - Affichage rapport exhaustif
   - Navigation par cercles
   - Export PDF

4. **`lib/widgets/report/circle_score_card.dart`**
   - Card visuelle par cercle
   - % + gauge + items
   - Recommandations

5. **`lib/widgets/report/action_priority_card.dart`**
   - Top 3 actions
   - Impact CHF estimé
   - CTA

---

## 📊 PROGRESSION GLOBALE

```
┌─────────────────────────────────────────────┐
│ CERCLE 1 - FONDATIONS      │ 100% ████████ │
│ CERCLE 2 - SERVICES CORE   │  40% ████░░░░ │
│ CERCLE 3 - WIDGETS ÉDUCATIFS│   0% ░░░░░░░░ │
│ CERCLE 4 - INTÉGRATION     │   0% ░░░░░░░░ │
├─────────────────────────────────────────────┤
│ TOTAL                      │  35% ████░░░░ │
└─────────────────────────────────────────────┘
```

---

## 🎯 PROCHAINES ÉTAPES (Ordre Optimal)

### Immédiat
1. ✅ Terminer CERCLE 2 (Services Core)
   - [ ] `financial_report_service.dart`
   - [ ] `tax_calculator_service_v2.dart`
   - [ ] `retirement_projection_service.dart`
   - [ ] `pillar3a_optimizer_service.dart`

### Court Terme
2. Créer CERCLE 3 (Widgets Éducatifs clés)
   - [ ] Comparateur 3a VIAC vs Banque
   - [ ] Simulateur rachat LPP

### Moyen Terme  
3. Refactorer CERCLE 4 (Intégration Wizard)
   - [ ] `wizard_questions_v2.dart`
   - [ ] `advisor_report_screen_v2.dart`

---

## 🐛 BUGS BLOQUANTS V1 À CORRIGER EN PARALLÈLE

1. **Question revenu en double** → RÉSOLU ✅
2. **LPP auto-détecté si salarié** → À implémenter
3. **Popup intermédiaire cassé** → Refonte V2
4. **Widget 3a sans projections** → Widget V2 à créer

---

## 💾 COMMITS RECOMMANDÉS

```bash
git checkout -b feature/wizard-v2-circles

# CERCLE 1
git add lib/models/circle_score.dart
git add lib/models/financial_report.dart
git commit -m "feat(models): Add Circle Scoring & Financial Report models (V2)"

# CERCLE 2
git add lib/services/circle_scoring_service.dart
git commit -m "feat(services): Add Circle Scoring Service with recommendations"

# ... (à suivre pour chaque cercle)
```

---

## 📝 NOTES IMPORTANTES

- **Ne PAS casser V1** : Créer fichiers `_v2` en parallèle
- **Tests** : Créer tests unitaires pour chaque service
- **Documentation** : Chaque widget doit avoir dartdoc
- **Performance** : Services scoring = O(n) linéaire, pas de calculs lourds

---

**Dernière mise à jour** : 18 janvier 2026, 16:40
