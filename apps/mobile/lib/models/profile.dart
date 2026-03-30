import 'package:mint_mobile/constants/social_insurance.dart';

enum HouseholdType { single, couple, concubine, family }

enum Goal { house, retire, emergency, invest, optimizeTaxes, other }

/// Statut d'emploi de l'utilisateur
enum EmploymentStatus {
  employee, // Salarié
  selfEmployed, // Indépendant
  mixed, // Mixte (salarié + indépendant)
  student, // Étudiant
  retired, // Retraité
  other, // Autre
}

extension EmploymentStatusExtension on EmploymentStatus {
  String get label {
    switch (this) {
      case EmploymentStatus.employee:
        return 'Salarié(e)';
      case EmploymentStatus.selfEmployed:
        return 'Indépendant(e)';
      case EmploymentStatus.mixed:
        return 'Mixte (salarié + indépendant)';
      case EmploymentStatus.student:
        return 'Étudiant(e)';
      case EmploymentStatus.retired:
        return 'Retraité(e)';
      case EmploymentStatus.other:
        return 'Autre';
    }
  }

  String get value {
    switch (this) {
      case EmploymentStatus.employee:
        return 'employee';
      case EmploymentStatus.selfEmployed:
        return 'self_employed';
      case EmploymentStatus.mixed:
        return 'mixed';
      case EmploymentStatus.student:
        return 'student';
      case EmploymentStatus.retired:
        return 'retired';
      case EmploymentStatus.other:
        return 'other';
    }
  }
}

class Profile {
  final String id;
  final int? birthYear;
  final String? canton;
  final HouseholdType householdType;
  final double? incomeNetMonthly;
  final double? incomeGrossYearly;
  final double? savingsMonthly;
  final double? totalSavings;
  final double? lppInsuredSalary;
  final bool hasDebt;
  final double factfindCompletionIndex;
  final Goal goal;
  final DateTime createdAt;

  // ⭐ Nouveaux champs pour statut d'emploi et 2e pilier
  final EmploymentStatus? employmentStatus;
  final bool? has2ndPillar;
  final String? legalForm; // Pour indépendants
  final double? selfEmployedNetIncome; // Pour indépendants/mixtes
  final bool? hasVoluntaryLpp; // Pour indépendants
  final String? primaryActivity; // Pour mixtes: 'employee' ou 'self_employed'

  // ⭐ Genre (AVS21 transitional reference age, LAVS art. 21 al. 1)
  final String? gender; // 'M', 'F', or null

  // ⭐ Nouveaux champs pour AVS
  final bool? hasAvsGaps;
  final int? avsContributionYears;
  final int? spouseAvsContributionYears;

  // ⭐ Nouveaux champs pour modèle fiscal MVP (Chantier 1)
  final String? commune; // NPA ou nom commune → multiplicateur précis
  final bool isChurchMember; // Impôt ecclésiastique
  final double? wealthEstimate; // Fortune nette estimée → impôt sur la fortune
  final double? pillar3aAnnual; // Versement annuel 3a → déduction fiscale

  Profile({
    required this.id,
    this.birthYear,
    this.canton,
    required this.householdType,
    this.incomeNetMonthly,
    this.incomeGrossYearly,
    this.savingsMonthly,
    this.totalSavings,
    this.lppInsuredSalary,
    this.hasDebt = false,
    this.factfindCompletionIndex = 0.0,
    required this.goal,
    required this.createdAt,
    // Nouveaux paramètres
    this.employmentStatus,
    this.has2ndPillar,
    this.legalForm,
    this.selfEmployedNetIncome,
    this.hasVoluntaryLpp,
    this.primaryActivity,
    this.gender,
    this.hasAvsGaps,
    this.avsContributionYears,
    this.spouseAvsContributionYears,
    this.commune,
    this.isChurchMember = false,
    this.wealthEstimate,
    this.pillar3aAnnual,
  });

  /// Calcule le plafond 3a selon le profil (OPP3 art. 7).
  ///
  /// - Salarie avec LPP: petit 3a (7'258 CHF)
  /// - Independant sans LPP: grand 3a (20% du revenu net, max 36'288 CHF)
  /// - Etudiants/retraites: 0 CHF
  double get pillar3aLimit {
    if (employmentStatus == null) return 0;

    switch (employmentStatus!) {
      case EmploymentStatus.student:
      case EmploymentStatus.retired:
        return 0;
      case EmploymentStatus.selfEmployed:
        if (has2ndPillar == true) return pilier3aPlafondAvecLpp;
        // Grand 3a: 20% du revenu net, plafonne a 36'288 CHF
        if (selfEmployedNetIncome != null && selfEmployedNetIncome! > 0) {
          final calculated = selfEmployedNetIncome! * pilier3aTauxRevenuSansLpp;
          return calculated < pilier3aPlafondSansLpp
              ? calculated
              : pilier3aPlafondSansLpp;
        }
        return pilier3aPlafondSansLpp;
      case EmploymentStatus.mixed:
        // Mixte: depend de l'activite principale et de la LPP
        if (has2ndPillar == true) return pilier3aPlafondAvecLpp;
        return pilier3aPlafondSansLpp;
      case EmploymentStatus.employee:
      case EmploymentStatus.other:
        return pilier3aPlafondAvecLpp;
    }
  }

  /// Détermine si l'utilisateur a besoin d'une couverture protection
  bool get needsProtectionCoverage {
    if (employmentStatus == EmploymentStatus.selfEmployed &&
        has2ndPillar == false) {
      return true; // Indépendant sans LPP = pas de couverture automatique
    }
    if (employmentStatus == EmploymentStatus.mixed && has2ndPillar == false) {
      return true; // Mixte sans LPP = couverture partielle
    }
    return false;
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      birthYear: json['birthYear'],
      canton: json['canton'],
      householdType: HouseholdType.values.firstWhere(
        (e) => e.name == json['householdType'],
        orElse: () => HouseholdType.single,
      ),
      incomeNetMonthly: json['incomeNetMonthly']?.toDouble(),
      incomeGrossYearly: json['incomeGrossYearly']?.toDouble(),
      savingsMonthly: json['savingsMonthly']?.toDouble(),
      totalSavings: json['totalSavings']?.toDouble(),
      lppInsuredSalary: json['lppInsuredSalary']?.toDouble(),
      hasDebt: json['hasDebt'] ?? false,
      factfindCompletionIndex:
          json['factfindCompletionIndex']?.toDouble() ?? 0.0,
      goal: Goal.values.firstWhere(
        (e) {
          final raw = json['goal'] as String?;
          if (raw == null) return false;
          return e.name == raw ||
              e.name.toLowerCase() == raw.replaceAll('_', '').toLowerCase();
        },
        orElse: () => Goal.other,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      // Nouveaux champs
      employmentStatus: json['employmentStatus'] != null
          ? EmploymentStatus.values.firstWhere(
              (e) => e.value == json['employmentStatus'],
              orElse: () => EmploymentStatus.other,
            )
          : null,
      has2ndPillar: json['has2ndPillar'],
      legalForm: json['legalForm'],
      selfEmployedNetIncome: json['selfEmployedNetIncome']?.toDouble(),
      hasVoluntaryLpp: json['hasVoluntaryLpp'],
      primaryActivity: json['primaryActivity'],
      gender: json['gender'] as String?,
      hasAvsGaps: json['hasAvsGaps'],
      avsContributionYears: json['avsContributionYears'],
      spouseAvsContributionYears: json['spouseAvsContributionYears'],
      commune: json['commune'],
      isChurchMember: json['isChurchMember'] ?? false,
      wealthEstimate: json['wealthEstimate']?.toDouble(),
      pillar3aAnnual: json['pillar3aAnnual']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'birthYear': birthYear,
      'canton': canton,
      'householdType': householdType.name,
      'incomeNetMonthly': incomeNetMonthly,
      'incomeGrossYearly': incomeGrossYearly,
      'savingsMonthly': savingsMonthly,
      'totalSavings': totalSavings,
      'lppInsuredSalary': lppInsuredSalary,
      'hasDebt': hasDebt,
      'factfindCompletionIndex': factfindCompletionIndex,
      'goal': goal.name,
      'createdAt': createdAt.toIso8601String(),
      // Nouveaux champs
      'employmentStatus': employmentStatus?.value,
      'has2ndPillar': has2ndPillar,
      'legalForm': legalForm,
      'selfEmployedNetIncome': selfEmployedNetIncome,
      'hasVoluntaryLpp': hasVoluntaryLpp,
      'primaryActivity': primaryActivity,
      'gender': gender,
      'hasAvsGaps': hasAvsGaps,
      'avsContributionYears': avsContributionYears,
      'spouseAvsContributionYears': spouseAvsContributionYears,
      'commune': commune,
      'isChurchMember': isChurchMember,
      'wealthEstimate': wealthEstimate,
      'pillar3aAnnual': pillar3aAnnual,
    };
  }

  Profile copyWith({
    String? id,
    int? birthYear,
    String? canton,
    HouseholdType? householdType,
    double? incomeNetMonthly,
    double? incomeGrossYearly,
    double? savingsMonthly,
    double? totalSavings,
    double? lppInsuredSalary,
    bool? hasDebt,
    double? factfindCompletionIndex,
    Goal? goal,
    DateTime? createdAt,
    // Nouveaux paramètres
    EmploymentStatus? employmentStatus,
    bool? has2ndPillar,
    String? legalForm,
    double? selfEmployedNetIncome,
    bool? hasVoluntaryLpp,
    String? primaryActivity,
    String? gender,
    bool? hasAvsGaps,
    int? avsContributionYears,
    int? spouseAvsContributionYears,
    String? commune,
    bool? isChurchMember,
    double? wealthEstimate,
    double? pillar3aAnnual,
  }) {
    return Profile(
      id: id ?? this.id,
      birthYear: birthYear ?? this.birthYear,
      canton: canton ?? this.canton,
      householdType: householdType ?? this.householdType,
      incomeNetMonthly: incomeNetMonthly ?? this.incomeNetMonthly,
      incomeGrossYearly: incomeGrossYearly ?? this.incomeGrossYearly,
      savingsMonthly: savingsMonthly ?? this.savingsMonthly,
      totalSavings: totalSavings ?? this.totalSavings,
      lppInsuredSalary: lppInsuredSalary ?? this.lppInsuredSalary,
      hasDebt: hasDebt ?? this.hasDebt,
      factfindCompletionIndex:
          factfindCompletionIndex ?? this.factfindCompletionIndex,
      goal: goal ?? this.goal,
      createdAt: createdAt ?? this.createdAt,
      // Nouveaux champs
      employmentStatus: employmentStatus ?? this.employmentStatus,
      has2ndPillar: has2ndPillar ?? this.has2ndPillar,
      legalForm: legalForm ?? this.legalForm,
      selfEmployedNetIncome:
          selfEmployedNetIncome ?? this.selfEmployedNetIncome,
      hasVoluntaryLpp: hasVoluntaryLpp ?? this.hasVoluntaryLpp,
      primaryActivity: primaryActivity ?? this.primaryActivity,
      gender: gender ?? this.gender,
      hasAvsGaps: hasAvsGaps ?? this.hasAvsGaps,
      avsContributionYears: avsContributionYears ?? this.avsContributionYears,
      spouseAvsContributionYears:
          spouseAvsContributionYears ?? this.spouseAvsContributionYears,
      commune: commune ?? this.commune,
      isChurchMember: isChurchMember ?? this.isChurchMember,
      wealthEstimate: wealthEstimate ?? this.wealthEstimate,
      pillar3aAnnual: pillar3aAnnual ?? this.pillar3aAnnual,
    );
  }
}
