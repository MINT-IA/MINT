# 📋 Synthèse Complète - Intégration Statut d'Emploi & 2e Pilier

## 🎯 Objectif de l'Intégration

Rendre le **statut d'emploi** (salarié vs indépendant) et la **présence du 2e pilier LPP** des axes structurants du wizard Mint, afin de :

1. ✅ **Calculer correctement les plafonds 3a** selon le profil
2. ✅ **Adapter les questions** selon le statut d'emploi
3. ✅ **Créer des rappels proactifs** spécifiques à chaque profil
4. ✅ **Identifier les lacunes de protection** (notamment pour indépendants sans LPP)
5. ✅ **Simplifier l'expérience utilisateur** avec progressive disclosure

---

## 📊 Résumé des Changements

### Fichiers Modifiés

| Fichier | Type | Changements Principaux |
|---------|------|------------------------|
| `WIZARD_SPEC.md` | Mise à jour | + Section "Axes Structurants"<br>+ Profil Minimal : 7 → 9 questions<br>+ Total questions : ~60 → ~65 |
| `WIZARD_QUESTIONS_SPEC.md` | Mise à jour | + `q_has_2nd_pillar` (pivot)<br>+ 11 nouvelles questions conditionnelles<br>+ 4 nouveaux événements de vie<br>+ Règles timeline spécifiques |

### Fichiers Créés

| Fichier | Taille | Description |
|---------|--------|-------------|
| `PILLAR_3A_LIMITS.md` | 9 KB | Plafonds 3a 2023-2026 par statut + règles de calcul |
| `EMPLOYMENT_STATUS_INTEGRATION.md` | 11 KB | Récapitulatif complet de l'intégration + checklist |
| `WIZARD_USER_JOURNEYS.md` | 16 KB | 4 parcours utilisateur détaillés (exemples concrets) |
| `IMPLEMENTATION_GUIDE.md` | 24 KB | Guide technique pour développeurs (code + tests) |
| `WIZARD_FLOW_DIAGRAMS.md` | 37 KB | 7 diagrammes de flux ASCII |
| `EMPLOYMENT_STATUS_README.md` | 11 KB | Index de toute la documentation |

**Total documentation** : ~148 KB (6 nouveaux fichiers + 2 mis à jour)

---

## 🔑 Questions Pivot Ajoutées

### 1. `q_employment_status` (Modifiée)
**Avant** :
- Options : Salarié / Indépendant / Étudiant / Retraité / Autre

**Après** :
- Options : Salarié / Indépendant / **Mixte (salarié + indépendant)** ⭐ / Étudiant / Retraité / Autre
- Tags : `['core', 'all', 'employment', 'pivot']`

### 2. `q_has_2nd_pillar` (Nouvelle)
**Question** : "As-tu une caisse de pension (LPP/2e pilier) via ton activité principale ?"

**Options** :
- Oui
- Non
- Je ne sais pas

**Conditions** : Affichée uniquement si `q_employment_status != student` et `!= retired`

**Impact** : Détermine les plafonds 3a et les besoins de prévoyance

---

## 📋 Nouvelles Questions Conditionnelles

### Branche A : Salarié avec LPP (3 questions)
1. `q_employee_lpp_certificate` : Certificat LPP disponible ?
2. `q_employee_job_change_planned` : Changement d'employeur prévu ?
3. `q_employee_job_change_date` : Date prévue du changement ?

### Branche B : Indépendant sans LPP (4 questions)
1. `q_self_employed_legal_form` : Forme juridique
2. `q_self_employed_net_income` : Revenu net annuel
3. `q_self_employed_voluntary_lpp` : Affiliation LPP volontaire ?
4. `q_self_employed_protection_gap` : Message d'alerte (couverture)

### Branche D/E : Mixte (4 questions)
1. `q_mixed_primary_activity` : Activité principale
2. `q_mixed_employee_has_lpp` : LPP via emploi salarié ?
3. `q_mixed_self_employed_net_income` : Revenu net indépendant
4. `q_mixed_3a_calculation_note` : Message d'information (calcul)

**Total** : 11 nouvelles questions (dont 2 messages d'information)

---

## 💰 Plafonds 3a par Statut (2025)

| Statut | Condition LPP | Plafond | Règle de Calcul |
|--------|---------------|---------|-----------------|
| **Salarié** | Avec LPP | **CHF 7'258** | Fixe |
| Salarié | Sans LPP | CHF 36'288 | 20% net, plafonné |
| **Indépendant** | Avec LPP | **CHF 7'258** | Fixe |
| **Indépendant** | Sans LPP | **CHF 36'288** | **20% net, plafonné** |
| **Mixte** | Avec LPP | **CHF 7'258** | Fixe |
| Mixte | Sans LPP | CHF 36'288 | 20% net total, plafonné |

**Formule 20% net** : `plafond = min(revenu_net_AVS * 0.20, 36'288)`

**Exemple** :
- Revenu net CHF 80'000 → 20% = **CHF 16'000** ✓
- Revenu net CHF 200'000 → 20% = CHF 40'000 → Plafonné à **CHF 36'288**

---

## 📅 Timeline Items Créés

### Pour Tous
- **Décembre** : "Optimiser versement 3a"
- **Janvier** : "Revue plan + bénéficiaires/assurances"

### Spécifiques Salariés avec LPP
- **Annuel** : "Évaluer potentiel rachat LPP"
- **30 jours avant changement** : "Préparer transfert LPP + mise à jour 3a"

### Spécifiques Indépendants sans LPP
- **Décembre** : "Optimiser montant 3a (20% net, plafond)"
- **Annuel** : "Revoir couverture protection (décès/invalidité)"
- **Tous les 2 ans** : "Évaluer opportunité affiliation LPP volontaire"

### Spécifiques Mixtes
- **Novembre** : "Vérifier calcul correct plafond 3a (statut mixte)"
- **Annuel** : "Bilan fiscal complexe (revenus multiples)"

---

## 🎭 Événements de Vie Ajoutés

| Événement | Questions Delta | Timeline Items |
|-----------|----------------|----------------|
| `employmentStatusChange` | 4 questions | 3 items (30, 60, 90j) |
| `lppAffiliation` | 3 questions | 2 items (immédiat, 30j) |
| `lppDisaffiliation` | 3 questions | 2 items (immédiat, 30j) |

**Total** : 3 nouveaux événements (+ `selfEmployment` enrichi)

---

## 📈 Impact sur l'Expérience Utilisateur

### Nombre de Questions Affichées

| Profil | Avant | Après | Différence |
|--------|-------|-------|------------|
| Salarié + LPP | ~25 | ~23 | **-2** ✓ |
| Indépendant - LPP | ~25 | ~25 | **0** ✓ |
| Mixte + LPP | ~25 | ~25 | **0** ✓ |

**Moyenne** : ~24 questions (au lieu de ~25-30)

### Progressive Disclosure
- ✅ **Chaque question est pertinente** selon le profil
- ✅ **Pas de questions inutiles** affichées
- ✅ **Parcours adapté dynamiquement** selon les réponses

### Précision des Recommandations
- ✅ **Plafonds 3a corrects** selon le statut
- ✅ **Alertes protection** pour indépendants sans LPP
- ✅ **Rappels proactifs** spécifiques à chaque profil

---

## 🔧 Implémentation Technique

### Modèles de Données

```dart
// Enum EmploymentStatus (mis à jour)
enum EmploymentStatus {
  employee,
  selfEmployed,
  mixed,        // ⭐ NOUVEAU
  student,
  retired,
  other,
}

// UserProfile (nouveaux champs)
class UserProfile {
  final bool? has2ndPillar;                // ⭐ NOUVEAU
  final String? legalForm;                 // ⭐ NOUVEAU
  final double? selfEmployedNetIncome;     // ⭐ NOUVEAU
  final bool? hasVoluntaryLpp;             // ⭐ NOUVEAU
  final String? primaryActivity;           // ⭐ NOUVEAU
  
  // Méthode calculée
  double get pillar3aLimit { ... }
}

// Enum LifeEventType (nouveaux événements)
enum LifeEventType {
  // ... événements existants
  employmentStatusChange,      // ⭐ NOUVEAU
  lppAffiliation,              // ⭐ NOUVEAU
  lppDisaffiliation,           // ⭐ NOUVEAU
}
```

### Configuration JSON

```json
{
  "pillar_3a_limits": {
    "2025": {
      "employee_with_lpp": {
        "limit": 7258,
        "calculation": "fixed"
      },
      "self_employed_without_lpp": {
        "limit": 36288,
        "calculation": "percentage",
        "percentage": 0.20
      }
      // ... autres configurations
    }
  }
}
```

### Classe `Pillar3aCalculator`

```dart
class Pillar3aCalculator {
  static double calculateLimit({
    required int year,
    required EmploymentStatus employmentStatus,
    required bool has2ndPillar,
    double? netIncomeAVS,
  }) {
    // Logique de calcul selon le profil
  }
  
  static String getDynamic3aSubtitle({
    required EmploymentStatus employmentStatus,
    required bool? has2ndPillar,
    required int year,
  }) {
    // Retourne le subtitle adapté
  }
}
```

---

## ✅ Checklist d'Implémentation

### Phase 1 : Modèles ✅ (Spec complète)
- [x] Ajouter `mixed` à `EmploymentStatus`
- [x] Ajouter champs au modèle `UserProfile`
- [x] Ajouter événements à `LifeEventType`

### Phase 2 : Configuration ✅ (Spec complète)
- [x] Créer fichier `pillar_3a_limits.json`
- [x] Spécifier classe `Pillar3aCalculator`
- [x] Définir tests unitaires

### Phase 3 : Logique Wizard ✅ (Spec complète)
- [x] Spécifier classe `WizardQuestionConditions`
- [x] Définir toutes les conditions d'affichage
- [x] Documenter tous les parcours

### Phase 4 : Timeline ✅ (Spec complète)
- [x] Spécifier classe `TimelineItemFactory`
- [x] Définir delta-sessions pour événements
- [x] Documenter règles de création

### Phase 5 : Documentation ✅ (Complète)
- [x] Créer guide d'implémentation
- [x] Créer exemples de parcours
- [x] Créer diagrammes de flux
- [x] Créer README récapitulatif

### Phase 6 : Implémentation Code ⏳ (À faire)
- [ ] Implémenter modèles de données
- [ ] Implémenter `Pillar3aCalculator`
- [ ] Implémenter logique conditionnelle
- [ ] Implémenter création timeline items
- [ ] Écrire tests unitaires
- [ ] Écrire tests E2E

**Progression** : 5/6 phases complètes (83%)

---

## 📚 Documentation Créée

### Fichiers de Référence
1. **EMPLOYMENT_STATUS_README.md** (11 KB)
   - Index de toute la documentation
   - Vue d'ensemble des changements
   - Prochaines étapes

2. **PILLAR_3A_LIMITS.md** (9 KB)
   - Plafonds 2023-2026 par statut
   - Règles de calcul détaillées
   - Format JSON pour implémentation

### Fichiers de Spécification
3. **WIZARD_SPEC.md** (11 KB, mis à jour)
   - Section "Axes Structurants"
   - Structure du wizard mise à jour
   - Effets sur la timeline

4. **WIZARD_QUESTIONS_SPEC.md** (49 KB, mis à jour)
   - 12 nouvelles questions
   - 4 nouveaux événements
   - Règles timeline spécifiques

### Fichiers d'Implémentation
5. **IMPLEMENTATION_GUIDE.md** (24 KB)
   - Architecture complète
   - Code prêt à l'emploi
   - Tests unitaires

6. **EMPLOYMENT_STATUS_INTEGRATION.md** (11 KB)
   - Récapitulatif de l'intégration
   - Checklist d'implémentation
   - Impact UX

### Fichiers d'Exemples
7. **WIZARD_USER_JOURNEYS.md** (16 KB)
   - 4 parcours utilisateur détaillés
   - Comparaison des profils
   - Notes d'implémentation

8. **WIZARD_FLOW_DIAGRAMS.md** (37 KB)
   - 7 diagrammes de flux ASCII
   - Visualisation de la logique
   - Légende et utilisation

**Total** : 8 fichiers, ~148 KB de documentation

---

## 🎯 Bénéfices de l'Intégration

### Pour les Utilisateurs
- ✅ **Plafonds 3a corrects** selon leur statut réel
- ✅ **Recommandations pertinentes** adaptées à leur situation
- ✅ **Alertes protection** pour ceux qui en ont besoin
- ✅ **Rappels proactifs** spécifiques à leur profil
- ✅ **Parcours optimisé** (pas de questions inutiles)

### Pour le Produit
- ✅ **Précision accrue** des calculs et recommandations
- ✅ **Couverture complète** de tous les profils (salarié/indépendant/mixte)
- ✅ **Proactivité renforcée** avec timeline items spécifiques
- ✅ **Conformité fiscale** avec règles suisses 2025

### Pour l'Équipe
- ✅ **Documentation exhaustive** (148 KB)
- ✅ **Code prêt à l'emploi** (classes, fonctions, tests)
- ✅ **Parcours testables** (4 exemples détaillés)
- ✅ **Maintenance facilitée** (plafonds centralisés)

---

## 🚀 Prochaines Étapes Recommandées

### Semaine 1-2 : Implémentation Backend
1. Créer fichier `assets/config/pillar_3a_limits.json`
2. Implémenter classe `Pillar3aCalculator`
3. Ajouter champs au modèle `UserProfile`
4. Écrire tests unitaires

### Semaine 3-4 : Implémentation Frontend
1. Modifier `q_employment_status` (ajouter "Mixte")
2. Créer `q_has_2nd_pillar` et 11 nouvelles questions
3. Implémenter logique conditionnelle
4. Implémenter subtitle dynamique

### Semaine 5 : Timeline & Événements
1. Implémenter `TimelineItemFactory`
2. Créer delta-sessions pour événements
3. Tester création automatique de timeline items

### Semaine 6 : Tests & Validation
1. Tests unitaires (backend)
2. Tests d'intégration (wizard)
3. Tests E2E (4 parcours)
4. Validation avec profils réels

**Durée totale estimée** : 6 semaines (1.5 mois)

---

## 📞 Support

Pour toute question sur cette intégration :
- **Documentation** : Voir `EMPLOYMENT_STATUS_README.md`
- **Implémentation** : Voir `IMPLEMENTATION_GUIDE.md`
- **Exemples** : Voir `WIZARD_USER_JOURNEYS.md`
- **Diagrammes** : Voir `WIZARD_FLOW_DIAGRAMS.md`

---

## 🎉 Conclusion

L'intégration du **statut d'emploi** et du **2e pilier LPP** comme axes structurants du wizard Mint est maintenant **complètement spécifiée** et **prête à être implémentée**.

**Points clés** :
- ✅ **2 questions pivot** ajoutées
- ✅ **11 nouvelles questions** conditionnelles
- ✅ **3 nouveaux événements** de vie
- ✅ **Plafonds 3a corrects** pour tous les profils
- ✅ **Timeline proactive** adaptée à chaque statut
- ✅ **148 KB de documentation** complète

**Prochaine étape** : Implémentation du code selon le guide technique fourni.

---

**Document créé le** : 2026-01-11  
**Dernière mise à jour** : 2026-01-11  
**Auteur** : Antigravity (Google Deepmind)  
**Version** : 1.0 (Spécification complète)
