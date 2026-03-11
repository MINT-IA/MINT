# Guide d'Implémentation Technique - Statut d'Emploi & 2e Pilier

## Vue d'ensemble

Ce guide technique détaille l'implémentation du système de **statut d'emploi** et **2e pilier LPP** dans le wizard Mint.

**Public cible** : Développeurs Flutter/Dart  
**Prérequis** : Connaissance de base de Flutter, Dart, et de l'architecture Mint

---

## 🛠 Environment Setup & Troubleshooting

### Windows Path Issues
On this specific machine (dev-env-julien), the Flutter SDK is installed in a custom location and requires manual path handling in some shells.

- **Flutter SDK Path**: `C:\flutter`
- **Absolute Command**: If `flutter` is not found, use:
  ```cmd
  C:\flutter\bin\flutter.bat run -d windows
  ```

---

## 🏗️ Architecture

### 1. Modèles de Données

#### Enum `EmploymentStatus`

```dart
enum EmploymentStatus {
  employee,       // Salarié
  selfEmployed,   // Indépendant
  mixed,          // ⭐ NOUVEAU : Mixte (salarié + indépendant)
  student,        // Étudiant
  retired,        // Retraité
  other,          // Autre
}

extension EmploymentStatusExtension on EmploymentStatus {
  String get label {
    switch (this) {
      case EmploymentStatus.employee:
        return 'Salarié';
      case EmploymentStatus.selfEmployed:
        return 'Indépendant';
      case EmploymentStatus.mixed:
        return 'Mixte (salarié + indépendant)';
      case EmploymentStatus.student:
        return 'Étudiant';
      case EmploymentStatus.retired:
        return 'Retraité';
      case EmploymentStatus.other:
        return 'Autre';
    }
  }

  IconData get icon {
    switch (this) {
      case EmploymentStatus.employee:
        return Icons.work;
      case EmploymentStatus.selfEmployed:
        return Icons.business_center;
      case EmploymentStatus.mixed:
        return Icons.work_outline;
      case EmploymentStatus.student:
        return Icons.school;
      case EmploymentStatus.retired:
        return Icons.elderly;
      case EmploymentStatus.other:
        return Icons.more_horiz;
    }
  }
}
```

#### Modèle `UserProfile` (Mise à jour)

```dart
class UserProfile {
  final String id;
  final String canton;
  final int birthYear;
  final HouseholdType householdType;
  final EmploymentStatus employmentStatus; // ⭐ EXISTANT
  final bool? has2ndPillar;                // ⭐ NOUVEAU
  
  // Champs spécifiques selon le statut
  final String? legalForm;                 // ⭐ NOUVEAU (pour indépendants)
  final double? selfEmployedNetIncome;     // ⭐ NOUVEAU (pour indépendants/mixtes)
  final bool? hasVoluntaryLpp;             // ⭐ NOUVEAU (pour indépendants)
  final String? primaryActivity;           // ⭐ NOUVEAU (pour mixtes: 'employee' ou 'self_employed')
  
  // ... autres champs existants
  
  UserProfile({
    required this.id,
    required this.canton,
    required this.birthYear,
    required this.householdType,
    required this.employmentStatus,
    this.has2ndPillar,
    this.legalForm,
    this.selfEmployedNetIncome,
    this.hasVoluntaryLpp,
    this.primaryActivity,
    // ... autres paramètres
  });
  
  // Méthode pour calculer le plafond 3a
  double get pillar3aLimit {
    return Pillar3aCalculator.calculateLimit(
      year: DateTime.now().year,
      employmentStatus: employmentStatus,
      has2ndPillar: has2ndPillar ?? false,
      netIncomeAVS: selfEmployedNetIncome,
    );
  }
  
  // Méthode pour déterminer si l'utilisateur a besoin d'une couverture protection
  bool get needsProtectionCoverage {
    if (employmentStatus == EmploymentStatus.selfEmployed && has2ndPillar == false) {
      return true; // Indépendant sans LPP = pas de couverture automatique
    }
    if (employmentStatus == EmploymentStatus.mixed && has2ndPillar == false) {
      return true; // Mixte sans LPP = couverture partielle
    }
    return false;
  }
  
  // ... autres méthodes
}
```

#### Enum `LifeEventType` (Mise à jour)

```dart
enum LifeEventType {
  // ... événements existants
  newJob,
  salaryIncrease,
  jobLoss,
  marriage,
  separation,
  divorce,
  birth,
  adoption,
  housingPurchase,
  housingSale,
  cantonMove,
  deathOfRelative,
  disability,
  workIncapacity,
  seriousIllness,
  inheritance,
  donation,
  selfEmployment,              // ⭐ EXISTANT
  leasingEnd,
  creditEnd,
  mortgageRenewal,
  
  // ⭐ NOUVEAUX événements
  employmentStatusChange,      // Changement de statut (salarié ↔ indépendant)
  lppAffiliation,              // Affiliation à une caisse LPP
  lppDisaffiliation,           // Sortie d'une caisse LPP
}
```

---

## 💾 Configuration des Plafonds 3a

### Fichier JSON `assets/config/pillar_3a_limits.json`

```json
{
  "pillar_3a_limits": {
    "2026": {
      "employee_with_lpp": {
        "limit": 7258,
        "calculation": "fixed",
        "currency": "CHF"
      },
      "employee_without_lpp": {
        "limit": 36288,
        "calculation": "percentage",
        "percentage": 0.20,
        "base": "net_income_avs",
        "currency": "CHF"
      },
      "self_employed_with_lpp": {
        "limit": 7258,
        "calculation": "fixed",
        "currency": "CHF"
      },
      "self_employed_without_lpp": {
        "limit": 36288,
        "calculation": "percentage",
        "percentage": 0.20,
        "base": "net_income_avs",
        "currency": "CHF"
      },
      "mixed_with_lpp": {
        "limit": 7258,
        "calculation": "fixed",
        "currency": "CHF"
      },
      "mixed_without_lpp": {
        "limit": 36288,
        "calculation": "percentage",
        "percentage": 0.20,
        "base": "net_income_avs_total",
        "currency": "CHF"
      }
    },
    "2025": {
      "employee_with_lpp": {
        "limit": 7258,
        "calculation": "fixed",
        "currency": "CHF"
      },
      "employee_without_lpp": {
        "limit": 36288,
        "calculation": "percentage",
        "percentage": 0.20,
        "base": "net_income_avs",
        "currency": "CHF"
      },
      "self_employed_with_lpp": {
        "limit": 7258,
        "calculation": "fixed",
        "currency": "CHF"
      },
      "self_employed_without_lpp": {
        "limit": 36288,
        "calculation": "percentage",
        "percentage": 0.20,
        "base": "net_income_avs",
        "currency": "CHF"
      },
      "mixed_with_lpp": {
        "limit": 7258,
        "calculation": "fixed",
        "currency": "CHF"
      },
      "mixed_without_lpp": {
        "limit": 36288,
        "calculation": "percentage",
        "percentage": 0.20,
        "base": "net_income_avs_total",
        "currency": "CHF"
      }
    }
  }
}
```

### Classe `Pillar3aCalculator`

```dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

class Pillar3aCalculator {
  static Map<String, dynamic>? _limits;
  
  // Charger les limites depuis le fichier JSON
  static Future<void> loadLimits() async {
    if (_limits != null) return; // Déjà chargé
    
    final String jsonString = await rootBundle.loadString('assets/config/pillar_3a_limits.json');
    final Map<String, dynamic> data = json.decode(jsonString);
    _limits = data['pillar_3a_limits'];
  }
  
  // Calculer le plafond 3a selon le profil
  static double calculateLimit({
    required int year,
    required EmploymentStatus employmentStatus,
    required bool has2ndPillar,
    double? netIncomeAVS,
  }) {
    if (_limits == null) {
      throw Exception('Pillar 3a limits not loaded. Call loadLimits() first.');
    }
    
    // Récupérer les paramètres de l'année
    final yearLimits = _limits![year.toString()];
    if (yearLimits == null) {
      throw Exception('No limits found for year $year');
    }
    
    // Déterminer la clé selon le statut
    String key;
    switch (employmentStatus) {
      case EmploymentStatus.employee:
        key = has2ndPillar ? 'employee_with_lpp' : 'employee_without_lpp';
        break;
      case EmploymentStatus.selfEmployed:
        key = has2ndPillar ? 'self_employed_with_lpp' : 'self_employed_without_lpp';
        break;
      case EmploymentStatus.mixed:
        key = has2ndPillar ? 'mixed_with_lpp' : 'mixed_without_lpp';
        break;
      case EmploymentStatus.student:
      case EmploymentStatus.retired:
      case EmploymentStatus.other:
        return 0; // Pas de plafond 3a pour ces statuts
    }
    
    final config = yearLimits[key];
    if (config == null) {
      throw Exception('No config found for key $key');
    }
    
    // Calculer selon la règle
    if (config['calculation'] == 'fixed') {
      return config['limit'].toDouble();
    } else if (config['calculation'] == 'percentage') {
      if (netIncomeAVS == null || netIncomeAVS == 0) {
        // Si revenu inconnu, retourner le plafond max
        return config['limit'].toDouble();
      }
      final calculated = netIncomeAVS * config['percentage'];
      return min(calculated, config['limit'].toDouble());
    }
    
    return 0;
  }
  
  // Obtenir le subtitle dynamique pour la question 3a
  static String getDynamic3aSubtitle({
    required EmploymentStatus employmentStatus,
    required bool? has2ndPillar,
    required int year,
  }) {
    if (employmentStatus == EmploymentStatus.employee && has2ndPillar == true) {
      final limit = calculateLimit(
        year: year,
        employmentStatus: employmentStatus,
        has2ndPillar: true,
      );
      return "Le 3a te permet de déduire jusqu'à CHF ${limit.toStringAsFixed(0)}/an ($year) de tes impôts.";
    } else if (employmentStatus == EmploymentStatus.selfEmployed && has2ndPillar == false) {
      final limit = calculateLimit(
        year: year,
        employmentStatus: employmentStatus,
        has2ndPillar: false,
      );
      return "Le 3a te permet de déduire jusqu'à 20% de ton revenu net (max CHF ${limit.toStringAsFixed(0)}/an, $year).";
    } else if (employmentStatus == EmploymentStatus.mixed) {
      if (has2ndPillar == true) {
        final limit = calculateLimit(
          year: year,
          employmentStatus: employmentStatus,
          has2ndPillar: true,
        );
        return "Le 3a te permet de déduire jusqu'à CHF ${limit.toStringAsFixed(0)}/an ($year) de tes impôts.";
      } else {
        final limit = calculateLimit(
          year: year,
          employmentStatus: employmentStatus,
          has2ndPillar: false,
        );
        return "Le 3a te permet de déduire jusqu'à 20% de ton revenu net (max CHF ${limit.toStringAsFixed(0)}/an, $year).";
      }
    } else if (employmentStatus == EmploymentStatus.selfEmployed && has2ndPillar == true) {
      final limit = calculateLimit(
        year: year,
        employmentStatus: employmentStatus,
        has2ndPillar: true,
      );
      return "Le 3a te permet de déduire jusqu'à CHF ${limit.toStringAsFixed(0)}/an ($year) de tes impôts.";
    } else {
      return "Le 3a te permet de déduire une partie de tes impôts (plafond selon ton statut).";
    }
  }
}
```

---

## 🎯 Logique Conditionnelle du Wizard

### Classe `WizardQuestionConditions`

```dart
class WizardQuestionConditions {
  // Vérifier si une question doit être affichée
  static bool shouldShowQuestion(String questionId, Map<String, dynamic> answers) {
    switch (questionId) {
      // Questions pivot
      case 'q_has_2nd_pillar':
        return _shouldShow_q_has_2nd_pillar(answers);
      
      // Branche Salarié avec LPP
      case 'q_employee_lpp_certificate':
        return _shouldShow_q_employee_lpp_certificate(answers);
      case 'q_employee_job_change_planned':
        return _shouldShow_q_employee_job_change_planned(answers);
      case 'q_employee_job_change_date':
        return _shouldShow_q_employee_job_change_date(answers);
      
      // Branche Indépendant
      case 'q_self_employed_legal_form':
        return _shouldShow_q_self_employed_legal_form(answers);
      case 'q_self_employed_net_income':
        return _shouldShow_q_self_employed_net_income(answers);
      case 'q_self_employed_voluntary_lpp':
        return _shouldShow_q_self_employed_voluntary_lpp(answers);
      case 'q_self_employed_protection_gap':
        return _shouldShow_q_self_employed_protection_gap(answers);
      
      // Branche Mixte
      case 'q_mixed_primary_activity':
        return _shouldShow_q_mixed_primary_activity(answers);
      case 'q_mixed_employee_has_lpp':
        return _shouldShow_q_mixed_employee_has_lpp(answers);
      case 'q_mixed_self_employed_net_income':
        return _shouldShow_q_mixed_self_employed_net_income(answers);
      case 'q_mixed_3a_calculation_note':
        return _shouldShow_q_mixed_3a_calculation_note(answers);
      
      default:
        return true; // Par défaut, afficher la question
    }
  }
  
  // ===== Questions Pivot =====
  
  static bool _shouldShow_q_has_2nd_pillar(Map<String, dynamic> answers) {
    final employmentStatus = answers['q_employment_status'];
    return employmentStatus != 'student' && employmentStatus != 'retired';
  }
  
  // ===== Branche Salarié avec LPP =====
  
  static bool _shouldShow_q_employee_lpp_certificate(Map<String, dynamic> answers) {
    return answers['q_employment_status'] == 'employee' && 
           answers['q_has_2nd_pillar'] == true;
  }
  
  static bool _shouldShow_q_employee_job_change_planned(Map<String, dynamic> answers) {
    return answers['q_employment_status'] == 'employee';
  }
  
  static bool _shouldShow_q_employee_job_change_date(Map<String, dynamic> answers) {
    return answers['q_employee_job_change_planned'] == true;
  }
  
  // ===== Branche Indépendant =====
  
  static bool _shouldShow_q_self_employed_legal_form(Map<String, dynamic> answers) {
    return answers['q_employment_status'] == 'self_employed';
  }
  
  static bool _shouldShow_q_self_employed_net_income(Map<String, dynamic> answers) {
    return answers['q_employment_status'] == 'self_employed' && 
           answers['q_has_2nd_pillar'] == false;
  }
  
  static bool _shouldShow_q_self_employed_voluntary_lpp(Map<String, dynamic> answers) {
    return answers['q_employment_status'] == 'self_employed' && 
           answers['q_has_2nd_pillar'] == false;
  }
  
  static bool _shouldShow_q_self_employed_protection_gap(Map<String, dynamic> answers) {
    return answers['q_employment_status'] == 'self_employed' && 
           answers['q_has_2nd_pillar'] == false &&
           answers['q_self_employed_voluntary_lpp'] == false;
  }
  
  // ===== Branche Mixte =====
  
  static bool _shouldShow_q_mixed_primary_activity(Map<String, dynamic> answers) {
    return answers['q_employment_status'] == 'mixed';
  }
  
  static bool _shouldShow_q_mixed_employee_has_lpp(Map<String, dynamic> answers) {
    return answers['q_employment_status'] == 'mixed';
  }
  
  static bool _shouldShow_q_mixed_self_employed_net_income(Map<String, dynamic> answers) {
    return answers['q_employment_status'] == 'mixed';
  }
  
  static bool _shouldShow_q_mixed_3a_calculation_note(Map<String, dynamic> answers) {
    return answers['q_employment_status'] == 'mixed';
  }
}
```

---

## 📅 Création de Timeline Items

### Classe `TimelineItemFactory`

```dart
class TimelineItemFactory {
  // Créer les timeline items selon le profil
  static List<TimelineItem> createTimelineItems(UserProfile profile, Map<String, dynamic> answers) {
    final items = <TimelineItem>[];
    
    // Items communs à tous
    items.addAll(_createCommonItems(profile, answers));
    
    // Items spécifiques selon le statut d'emploi
    if (profile.employmentStatus == EmploymentStatus.employee && profile.has2ndPillar == true) {
      items.addAll(_createEmployeeWithLppItems(profile, answers));
    } else if (profile.employmentStatus == EmploymentStatus.selfEmployed && profile.has2ndPillar == false) {
      items.addAll(_createSelfEmployedWithoutLppItems(profile, answers));
    } else if (profile.employmentStatus == EmploymentStatus.mixed) {
      items.addAll(_createMixedItems(profile, answers));
    }
    
    return items;
  }
  
  // Items communs
  static List<TimelineItem> _createCommonItems(UserProfile profile, Map<String, dynamic> answers) {
    final items = <TimelineItem>[];
    
    // Rappel annuel 3a (décembre)
    items.add(TimelineItem(
      date: DateTime(DateTime.now().year, 12, 1),
      category: 'pension',
      status: 'upcoming',
      label: 'Optimiser versement 3a',
      description: 'Vérifier que tu as maximisé ton versement 3a avant la fin de l\'année',
      recurrence: RecurrenceType.yearly,
    ));
    
    // Revue annuelle plan
    items.add(TimelineItem(
      date: DateTime(DateTime.now().year + 1, 1, 15),
      category: 'general',
      status: 'upcoming',
      label: 'Revue plan + bénéficiaires/assurances',
      description: 'Bilan annuel de ton plan financier et mise à jour des bénéficiaires',
      recurrence: RecurrenceType.yearly,
    ));
    
    return items;
  }
  
  // Items pour salariés avec LPP
  static List<TimelineItem> _createEmployeeWithLppItems(UserProfile profile, Map<String, dynamic> answers) {
    final items = <TimelineItem>[];
    
    // Rappel rachat LPP (annuel)
    items.add(TimelineItem(
      date: DateTime(DateTime.now().year, 11, 1),
      category: 'pension',
      status: 'upcoming',
      label: 'Évaluer potentiel rachat LPP',
      description: 'Vérifier ton certificat LPP et évaluer l\'opportunité d\'un rachat',
      recurrence: RecurrenceType.yearly,
    ));
    
    // Rappel changement d'emploi (si planifié)
    if (answers['q_employee_job_change_planned'] == true && answers['q_employee_job_change_date'] != null) {
      final changeDate = answers['q_employee_job_change_date'] as DateTime;
      items.add(TimelineItem(
        date: changeDate.subtract(const Duration(days: 30)),
        category: 'pension',
        status: 'upcoming',
        label: 'Préparer transfert LPP + mise à jour 3a',
        description: 'Planifier le transfert de ton LPP vers le nouvel employeur',
        recurrence: RecurrenceType.once,
      ));
    }
    
    return items;
  }
  
  // Items pour indépendants sans LPP
  static List<TimelineItem> _createSelfEmployedWithoutLppItems(UserProfile profile, Map<String, dynamic> answers) {
    final items = <TimelineItem>[];
    
    // Rappel optimisation 3a (décembre, spécifique)
    items.add(TimelineItem(
      date: DateTime(DateTime.now().year, 12, 1),
      category: 'pension',
      status: 'upcoming',
      label: 'Optimiser montant 3a (20% net, plafond)',
      description: 'Calculer et verser le montant optimal de 3a (20% de ton revenu net)',
      recurrence: RecurrenceType.yearly,
    ));
    
    // Rappel couverture protection (annuel)
    items.add(TimelineItem(
      date: DateTime(DateTime.now().year, 6, 1),
      category: 'insurance',
      status: 'upcoming',
      label: 'Revoir couverture protection (décès/invalidité)',
      description: 'Sans LPP, tu n\'as pas de couverture automatique. Vérifier tes assurances',
      recurrence: RecurrenceType.yearly,
    ));
    
    // Rappel LPP volontaire (tous les 2 ans)
    items.add(TimelineItem(
      date: DateTime(DateTime.now().year, 3, 1),
      category: 'pension',
      status: 'upcoming',
      label: 'Évaluer opportunité affiliation LPP volontaire',
      description: 'Vérifier si une affiliation LPP volontaire serait avantageuse',
      recurrence: RecurrenceType.biennial,
    ));
    
    return items;
  }
  
  // Items pour statut mixte
  static List<TimelineItem> _createMixedItems(UserProfile profile, Map<String, dynamic> answers) {
    final items = <TimelineItem>[];
    
    // Rappel vérification calcul 3a (novembre)
    items.add(TimelineItem(
      date: DateTime(DateTime.now().year, 11, 15),
      category: 'pension',
      status: 'upcoming',
      label: 'Vérifier calcul correct plafond 3a (statut mixte)',
      description: 'Avec un statut mixte, vérifier que ton plafond 3a est correctement calculé',
      recurrence: RecurrenceType.yearly,
    ));
    
    // Rappel bilan fiscal complexe (annuel)
    items.add(TimelineItem(
      date: DateTime(DateTime.now().year, 10, 1),
      category: 'tax',
      status: 'upcoming',
      label: 'Bilan fiscal complexe (revenus multiples)',
      description: 'Avec des revenus salariés + indépendants, planifier ta déclaration fiscale',
      recurrence: RecurrenceType.yearly,
    ));
    
    return items;
  }
}

enum RecurrenceType {
  once,
  yearly,
  biennial,
  quarterly,
}
```

---

## 🧪 Tests Unitaires

### Test `Pillar3aCalculator`

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pillar3aCalculator', () {
    setUpAll(() async {
      await Pillar3aCalculator.loadLimits();
    });
    
    test('Salarié avec LPP - plafond fixe 2025', () {
      final limit = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: EmploymentStatus.employee,
        has2ndPillar: true,
      );
      expect(limit, 7258.0);
    });
    
    test('Indépendant sans LPP - 20% revenu net (sous plafond)', () {
      final limit = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: EmploymentStatus.selfEmployed,
        has2ndPillar: false,
        netIncomeAVS: 80000,
      );
      expect(limit, 16000.0); // 20% de 80'000
    });
    
    test('Indépendant sans LPP - 20% revenu net (au-dessus plafond)', () {
      final limit = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: EmploymentStatus.selfEmployed,
        has2ndPillar: false,
        netIncomeAVS: 200000,
      );
      expect(limit, 36288.0); // Plafonné à 36'288
    });
    
    test('Mixte avec LPP - plafond fixe', () {
      final limit = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: EmploymentStatus.mixed,
        has2ndPillar: true,
      );
      expect(limit, 7258.0);
    });
    
    test('Étudiant - pas de plafond', () {
      final limit = Pillar3aCalculator.calculateLimit(
        year: 2025,
        employmentStatus: EmploymentStatus.student,
        has2ndPillar: false,
      );
      expect(limit, 0.0);
    });
  });
}
```

---

## 📝 Checklist d'Implémentation

### Phase 1 : Modèles ✅
- [ ] Ajouter `mixed` à l'enum `EmploymentStatus`
- [ ] Ajouter champ `has2ndPillar` à `UserProfile`
- [ ] Ajouter champs spécifiques (`legalForm`, `selfEmployedNetIncome`, etc.)
- [ ] Ajouter nouveaux événements à `LifeEventType`

### Phase 2 : Configuration ✅
- [ ] Créer fichier `assets/config/pillar_3a_limits.json`
- [ ] Implémenter classe `Pillar3aCalculator`
- [ ] Écrire tests unitaires pour `Pillar3aCalculator`

### Phase 3 : Logique Wizard ✅
- [ ] Implémenter classe `WizardQuestionConditions`
- [ ] Modifier widget `WizardQuestion` pour utiliser les conditions
- [ ] Tester tous les parcours (salarié/indépendant/mixte × avec/sans LPP)

### Phase 4 : Timeline ✅
- [ ] Implémenter classe `TimelineItemFactory`
- [ ] Créer delta-sessions pour nouveaux événements
- [ ] Tester création automatique de timeline items

### Phase 5 : UI/UX ✅
- [ ] Implémenter subtitle dynamique pour question 3a
- [ ] Ajouter messages d'information/alerte selon le statut
- [ ] Tester affichage sur différents écrans

### Phase 6 : Tests E2E ✅
- [ ] Tester parcours complet salarié avec LPP
- [ ] Tester parcours complet indépendant sans LPP
- [ ] Tester parcours complet mixte
- [ ] Valider avec cas réels

---

**Document créé le** : 2026-01-11  
**Dernière mise à jour** : 2026-01-11  
**Auteur** : Antigravity (Google Deepmind)
