/// Profil financier etendu pour MINT Coach
///
/// Ce modele sert de base au ForecasterService et au FinancialFitnessScore.
/// Il etend le Profile existant avec : couple, prevoyance detaillee,
/// patrimoine, objectifs, et historique de check-ins mensuels.

/// Sprint C1 — MINT Coach Redesign
library;

import 'package:mint_mobile/domain/budget/budget_inputs.dart';

// ════════════════════════════════════════════════════════════════
//  ENUMS
// ════════════════════════════════════════════════════════════════

/// Etat civil pour le coach
enum CoachCivilStatus { celibataire, marie, divorce, veuf, concubinage }

/// Type d'objectif principal (Goal A)
enum GoalAType { retraite, achatImmo, independance, debtFree, custom }

/// Devise des investissements
enum InvestmentCurrency { chf, usd, eur }

// ════════════════════════════════════════════════════════════════
//  SOUS-MODELES
// ════════════════════════════════════════════════════════════════

/// Profil du conjoint (si marie ou concubinage)
class ConjointProfile {
  final String? firstName;
  final int? birthYear;
  final double? salaireBrutMensuel;
  final int nombreDeMois; // 12, 13, 13.5
  final double? bonusPourcentage;
  final String? nationality; // ISO 2-letter code, ex "CH", "US", "FR"
  final bool isFatcaResident; // US citizen/green card → FATCA restrictions
  final bool canContribute3a; // false si FATCA resident (certains providers)
  final PrevoyanceProfile? prevoyance;

  const ConjointProfile({
    this.firstName,
    this.birthYear,
    this.salaireBrutMensuel,
    this.nombreDeMois = 12,
    this.bonusPourcentage,
    this.nationality,
    this.isFatcaResident = false,
    this.canContribute3a = true,
    this.prevoyance,
  });

  /// Revenu brut annuel estime
  double get revenuBrutAnnuel {
    if (salaireBrutMensuel == null) return 0;
    final base = salaireBrutMensuel! * nombreDeMois;
    final bonus = (bonusPourcentage ?? 0) / 100 * base;
    return base + bonus;
  }

  /// Age actuel
  int? get age {
    if (birthYear == null) return null;
    return DateTime.now().year - birthYear!;
  }

  /// Annees restantes avant retraite (65 ans)
  int? get anneesAvantRetraite {
    final a = age;
    if (a == null) return null;
    return (65 - a).clamp(0, 99);
  }

  factory ConjointProfile.fromJson(Map<String, dynamic> json) {
    return ConjointProfile(
      firstName: json['firstName'] as String?,
      birthYear: json['birthYear'] as int?,
      salaireBrutMensuel: (json['salaireBrutMensuel'] as num?)?.toDouble(),
      nombreDeMois: json['nombreDeMois'] ?? 12,
      bonusPourcentage: (json['bonusPourcentage'] as num?)?.toDouble(),
      nationality: json['nationality'] as String?,
      isFatcaResident: json['isFatcaResident'] ?? false,
      canContribute3a: json['canContribute3a'] ?? true,
      prevoyance: json['prevoyance'] != null
          ? PrevoyanceProfile.fromJson(json['prevoyance'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'birthYear': birthYear,
    'salaireBrutMensuel': salaireBrutMensuel,
    'nombreDeMois': nombreDeMois,
    'bonusPourcentage': bonusPourcentage,
    'nationality': nationality,
    'isFatcaResident': isFatcaResident,
    'canContribute3a': canContribute3a,
    'prevoyance': prevoyance?.toJson(),
  };

  ConjointProfile copyWith({
    String? firstName,
    int? birthYear,
    double? salaireBrutMensuel,
    int? nombreDeMois,
    double? bonusPourcentage,
    String? nationality,
    bool? isFatcaResident,
    bool? canContribute3a,
    PrevoyanceProfile? prevoyance,
  }) {
    return ConjointProfile(
      firstName: firstName ?? this.firstName,
      birthYear: birthYear ?? this.birthYear,
      salaireBrutMensuel: salaireBrutMensuel ?? this.salaireBrutMensuel,
      nombreDeMois: nombreDeMois ?? this.nombreDeMois,
      bonusPourcentage: bonusPourcentage ?? this.bonusPourcentage,
      nationality: nationality ?? this.nationality,
      isFatcaResident: isFatcaResident ?? this.isFatcaResident,
      canContribute3a: canContribute3a ?? this.canContribute3a,
      prevoyance: prevoyance ?? this.prevoyance,
    );
  }
}

/// Informations prevoyance (AVS + LPP + 3a)
class PrevoyanceProfile {
  // --- AVS ---
  final int? anneesContribuees;
  final int? lacunesAVS; // annees manquantes
  final double? renteAVSEstimeeMensuelle;

  // --- LPP ---
  final String? nomCaisse;
  final double? avoirLppTotal; // obligatoire + surobligatoire
  final double? rachatMaximum; // lacune de rachat totale
  final double? rachatEffectue; // deja rachete
  final double tauxConversion; // taux de la caisse (min legal 6.8%)
  final double rendementCaisse; // rendement annuel estime de la caisse

  // --- 3a ---
  final int nombre3a; // nombre de comptes 3a
  final double totalEpargne3a; // solde total 3a
  final List<Compte3a> comptes3a;
  final bool canContribute3a; // false si US citizen/FATCA

  const PrevoyanceProfile({
    this.anneesContribuees,
    this.lacunesAVS,
    this.renteAVSEstimeeMensuelle,
    this.nomCaisse,
    this.avoirLppTotal,
    this.rachatMaximum,
    this.rachatEffectue,
    this.tauxConversion = 0.068,
    this.rendementCaisse = 0.02,
    this.nombre3a = 0,
    this.totalEpargne3a = 0,
    this.comptes3a = const [],
    this.canContribute3a = true,
  });

  /// Lacune de rachat LPP restante
  double get lacuneRachatRestante {
    return ((rachatMaximum ?? 0) - (rachatEffectue ?? 0)).clamp(0, double.infinity);
  }

  factory PrevoyanceProfile.fromJson(Map<String, dynamic> json) {
    return PrevoyanceProfile(
      anneesContribuees: json['anneesContribuees'] as int?,
      lacunesAVS: json['lacunesAVS'] as int?,
      renteAVSEstimeeMensuelle: (json['renteAVSEstimeeMensuelle'] as num?)?.toDouble(),
      nomCaisse: json['nomCaisse'] as String?,
      avoirLppTotal: (json['avoirLppTotal'] as num?)?.toDouble(),
      rachatMaximum: (json['rachatMaximum'] as num?)?.toDouble(),
      rachatEffectue: (json['rachatEffectue'] as num?)?.toDouble(),
      tauxConversion: (json['tauxConversion'] as num?)?.toDouble() ?? 0.068,
      rendementCaisse: (json['rendementCaisse'] as num?)?.toDouble() ?? 0.02,
      nombre3a: json['nombre3a'] ?? 0,
      totalEpargne3a: (json['totalEpargne3a'] as num?)?.toDouble() ?? 0,
      comptes3a: (json['comptes3a'] as List?)
              ?.map((c) => Compte3a.fromJson(c))
              .toList() ??
          const [],
      canContribute3a: json['canContribute3a'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'anneesContribuees': anneesContribuees,
    'lacunesAVS': lacunesAVS,
    'renteAVSEstimeeMensuelle': renteAVSEstimeeMensuelle,
    'nomCaisse': nomCaisse,
    'avoirLppTotal': avoirLppTotal,
    'rachatMaximum': rachatMaximum,
    'rachatEffectue': rachatEffectue,
    'tauxConversion': tauxConversion,
    'rendementCaisse': rendementCaisse,
    'nombre3a': nombre3a,
    'totalEpargne3a': totalEpargne3a,
    'comptes3a': comptes3a.map((c) => c.toJson()).toList(),
    'canContribute3a': canContribute3a,
  };
}

/// Compte 3a individuel
class Compte3a {
  final String provider; // "VIAC", "Finpens", "Banque", etc.
  final double solde;
  final double rendementEstime; // rendement annuel estime

  const Compte3a({
    required this.provider,
    required this.solde,
    this.rendementEstime = 0.04,
  });

  factory Compte3a.fromJson(Map<String, dynamic> json) {
    return Compte3a(
      provider: json['provider'] as String,
      solde: (json['solde'] as num).toDouble(),
      rendementEstime: (json['rendementEstime'] as num?)?.toDouble() ?? 0.04,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'solde': solde,
    'rendementEstime': rendementEstime,
  };
}

/// Patrimoine (epargne + investissements + immobilier)
class PatrimoineProfile {
  final double epargneLiquide;
  final double investissements;
  final double? immobilier;
  final InvestmentCurrency deviseInvestissements;
  final String? plateformeInvestissement; // "Interactive Brokers", etc.

  const PatrimoineProfile({
    this.epargneLiquide = 0,
    this.investissements = 0,
    this.immobilier,
    this.deviseInvestissements = InvestmentCurrency.chf,
    this.plateformeInvestissement,
  });

  double get totalPatrimoine =>
      epargneLiquide + investissements + (immobilier ?? 0);

  factory PatrimoineProfile.fromJson(Map<String, dynamic> json) {
    return PatrimoineProfile(
      epargneLiquide: (json['epargneLiquide'] as num?)?.toDouble() ?? 0,
      investissements: (json['investissements'] as num?)?.toDouble() ?? 0,
      immobilier: (json['immobilier'] as num?)?.toDouble(),
      deviseInvestissements: InvestmentCurrency.values.firstWhere(
        (e) => e.name == json['deviseInvestissements'],
        orElse: () => InvestmentCurrency.chf,
      ),
      plateformeInvestissement: json['plateformeInvestissement'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'epargneLiquide': epargneLiquide,
    'investissements': investissements,
    'immobilier': immobilier,
    'deviseInvestissements': deviseInvestissements.name,
    'plateformeInvestissement': plateformeInvestissement,
  };
}

/// Dettes
class DetteProfile {
  final double? creditConsommation;
  final double? leasing;
  final double? hypotheque;
  final double? autresDettes;

  const DetteProfile({
    this.creditConsommation,
    this.leasing,
    this.hypotheque,
    this.autresDettes,
  });

  double get totalDettes =>
      (creditConsommation ?? 0) +
      (leasing ?? 0) +
      (hypotheque ?? 0) +
      (autresDettes ?? 0);

  bool get hasDette => totalDettes > 0;

  factory DetteProfile.fromJson(Map<String, dynamic> json) {
    return DetteProfile(
      creditConsommation: (json['creditConsommation'] as num?)?.toDouble(),
      leasing: (json['leasing'] as num?)?.toDouble(),
      hypotheque: (json['hypotheque'] as num?)?.toDouble(),
      autresDettes: (json['autresDettes'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'creditConsommation': creditConsommation,
    'leasing': leasing,
    'hypotheque': hypotheque,
    'autresDettes': autresDettes,
  };
}

/// Depenses fixes mensuelles
class DepensesProfile {
  final double loyer;
  final double assuranceMaladie;
  final double? electricite;
  final double? transport;
  final double? telecom;
  final double? fraisMedicaux;
  final double? autresDepensesFixes;

  const DepensesProfile({
    this.loyer = 0,
    this.assuranceMaladie = 0,
    this.electricite,
    this.transport,
    this.telecom,
    this.fraisMedicaux,
    this.autresDepensesFixes,
  });

  double get totalMensuel =>
      loyer +
      assuranceMaladie +
      (electricite ?? 0) +
      (transport ?? 0) +
      (telecom ?? 0) +
      (fraisMedicaux ?? 0) +
      (autresDepensesFixes ?? 0);

  factory DepensesProfile.fromJson(Map<String, dynamic> json) {
    return DepensesProfile(
      loyer: (json['loyer'] as num?)?.toDouble() ?? 0,
      assuranceMaladie: (json['assuranceMaladie'] as num?)?.toDouble() ?? 0,
      electricite: (json['electricite'] as num?)?.toDouble(),
      transport: (json['transport'] as num?)?.toDouble(),
      telecom: (json['telecom'] as num?)?.toDouble(),
      fraisMedicaux: (json['fraisMedicaux'] as num?)?.toDouble(),
      autresDepensesFixes: (json['autresDepensesFixes'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'loyer': loyer,
    'assuranceMaladie': assuranceMaladie,
    'electricite': electricite,
    'transport': transport,
    'telecom': telecom,
    'fraisMedicaux': fraisMedicaux,
    'autresDepensesFixes': autresDepensesFixes,
  };
}

/// Objectif principal (Goal A)
class GoalA {
  final GoalAType type;
  final DateTime targetDate;
  final double? targetAmount; // montant cible si applicable
  final String label;

  const GoalA({
    required this.type,
    required this.targetDate,
    this.targetAmount,
    required this.label,
  });

  /// Mois restants avant la date cible
  int get moisRestants {
    final now = DateTime.now();
    return ((targetDate.year - now.year) * 12 + (targetDate.month - now.month))
        .clamp(0, 9999);
  }

  factory GoalA.fromJson(Map<String, dynamic> json) {
    return GoalA(
      type: GoalAType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => GoalAType.retraite,
      ),
      targetDate: DateTime.parse(json['targetDate']),
      targetAmount: (json['targetAmount'] as num?)?.toDouble(),
      label: json['label'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'targetDate': targetDate.toIso8601String(),
    'targetAmount': targetAmount,
    'label': label,
  };
}

/// Objectif secondaire (Goal B)
class GoalB {
  final String label;
  final double targetAmount;
  final DateTime? targetDate;
  final int priority;

  const GoalB({
    required this.label,
    required this.targetAmount,
    this.targetDate,
    this.priority = 0,
  });

  factory GoalB.fromJson(Map<String, dynamic> json) {
    return GoalB(
      label: json['label'] as String,
      targetAmount: (json['targetAmount'] as num).toDouble(),
      targetDate: json['targetDate'] != null
          ? DateTime.parse(json['targetDate'])
          : null,
      priority: json['priority'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'targetAmount': targetAmount,
    'targetDate': targetDate?.toIso8601String(),
    'priority': priority,
  };
}

/// Check-in mensuel (une "activite" au sens TrainerRoad)
class MonthlyCheckIn {
  final DateTime month; // premier jour du mois
  final Map<String, double> versements; // '3a_julien': 604.83, etc.
  final double? depensesExceptionnelles;
  final double? revenusExceptionnels;
  final String? note;
  final DateTime completedAt;

  const MonthlyCheckIn({
    required this.month,
    required this.versements,
    this.depensesExceptionnelles,
    this.revenusExceptionnels,
    this.note,
    required this.completedAt,
  });

  /// Total des versements du mois
  double get totalVersements =>
      versements.values.fold(0.0, (sum, v) => sum + v);

  factory MonthlyCheckIn.fromJson(Map<String, dynamic> json) {
    return MonthlyCheckIn(
      month: DateTime.parse(json['month']),
      versements: Map<String, double>.from(
        (json['versements'] as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ),
      ),
      depensesExceptionnelles:
          (json['depensesExceptionnelles'] as num?)?.toDouble(),
      revenusExceptionnels:
          (json['revenusExceptionnels'] as num?)?.toDouble(),
      note: json['note'] as String?,
      completedAt: DateTime.parse(json['completedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'month': month.toIso8601String(),
    'versements': versements,
    'depensesExceptionnelles': depensesExceptionnelles,
    'revenusExceptionnels': revenusExceptionnels,
    'note': note,
    'completedAt': completedAt.toIso8601String(),
  };
}

/// Versement mensuel planifie (configuration recurrente)
class PlannedMonthlyContribution {
  final String id; // ex: '3a_julien', 'lpp_buyback_julien', 'ib_julien'
  final String label; // ex: '3a Julien (VIAC)'
  final double amount; // montant mensuel
  final String category; // '3a', 'lpp_buyback', 'epargne_libre', 'investissement'
  final bool isAutomatic; // ordre permanent ou manuel

  const PlannedMonthlyContribution({
    required this.id,
    required this.label,
    required this.amount,
    required this.category,
    this.isAutomatic = false,
  });

  factory PlannedMonthlyContribution.fromJson(Map<String, dynamic> json) {
    return PlannedMonthlyContribution(
      id: json['id'] as String,
      label: json['label'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      isAutomatic: json['isAutomatic'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'amount': amount,
    'category': category,
    'isAutomatic': isAutomatic,
  };
}

// ════════════════════════════════════════════════════════════════
//  MODELE PRINCIPAL : CoachProfile
// ════════════════════════════════════════════════════════════════

/// Profil financier complet pour MINT Coach.
///
/// Contient toutes les donnees necessaires au ForecasterService
/// et au FinancialFitnessScore. Persiste localement (SharedPreferences
/// ou Hive) et peut etre exporte en JSON.
class CoachProfile {
  // === IDENTITE ===
  final String? firstName;
  final int birthYear;
  final String canton;
  final String? commune;
  final CoachCivilStatus etatCivil;
  final int nombreEnfants;

  // === CONJOINT ===
  final ConjointProfile? conjoint;

  // === REVENUS ===
  final double salaireBrutMensuel;
  final int nombreDeMois; // 12, 13, 13.5
  final double? bonusPourcentage;
  final String employmentStatus; // 'salarie', 'independant', 'chomage', 'retraite'

  // === DEPENSES ===
  final DepensesProfile depenses;

  // === PREVOYANCE ===
  final PrevoyanceProfile prevoyance;

  // === PATRIMOINE ===
  final PatrimoineProfile patrimoine;

  // === DETTES ===
  final DetteProfile dettes;

  // === OBJECTIFS ===
  final GoalA goalA;
  final List<GoalB> goalsB;

  // === VERSEMENTS PLANIFIES ===
  final List<PlannedMonthlyContribution> plannedContributions;

  // === HISTORIQUE ===
  final List<MonthlyCheckIn> checkIns;

  // === PROFIL COMPLEMENTAIRE ===
  final String? housingStatus;
  final String? riskTolerance;
  final String? realEstateProject;
  final List<String> providers3a;

  // === META ===
  final DateTime createdAt;
  final DateTime updatedAt;

  CoachProfile({
    this.firstName,
    required this.birthYear,
    required this.canton,
    this.commune,
    this.etatCivil = CoachCivilStatus.celibataire,
    this.nombreEnfants = 0,
    this.conjoint,
    required this.salaireBrutMensuel,
    this.nombreDeMois = 12,
    this.bonusPourcentage,
    this.employmentStatus = 'salarie',
    this.depenses = const DepensesProfile(),
    this.prevoyance = const PrevoyanceProfile(),
    this.patrimoine = const PatrimoineProfile(),
    this.dettes = const DetteProfile(),
    required this.goalA,
    this.goalsB = const [],
    this.plannedContributions = const [],
    this.checkIns = const [],
    this.housingStatus,
    this.riskTolerance,
    this.realEstateProject,
    this.providers3a = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // ════════════════════════════════════════════════════════════════
  //  COMPUTED PROPERTIES
  // ════════════════════════════════════════════════════════════════

  /// Age actuel
  int get age => DateTime.now().year - birthYear;

  /// Annees restantes avant retraite (65 ans)
  int get anneesAvantRetraite => (65 - age).clamp(0, 99);

  /// Revenu brut annuel estime
  double get revenuBrutAnnuel {
    final base = salaireBrutMensuel * nombreDeMois;
    final bonus = (bonusPourcentage ?? 0) / 100 * base;
    return base + bonus;
  }

  /// Revenu brut annuel du couple
  double get revenuBrutAnnuelCouple =>
      revenuBrutAnnuel + (conjoint?.revenuBrutAnnuel ?? 0);

  /// Total depenses fixes mensuelles
  double get totalDepensesMensuelles => depenses.totalMensuel;

  /// Reste a vivre mensuel estime (brut - depenses - cotisations sociales)
  double get resteAVivreMensuel {
    // Approximation: 13% de charges sociales
    final netMensuel = salaireBrutMensuel * 0.87;
    return netMensuel - totalDepensesMensuelles;
  }

  /// Nombre de check-ins completes
  int get checkInsCompletes => checkIns.length;

  /// Serie de mois consecutifs on-track (streak)
  int get streak {
    if (checkIns.isEmpty) return 0;
    final sorted = List<MonthlyCheckIn>.from(checkIns)
      ..sort((a, b) => b.month.compareTo(a.month));
    int count = 0;
    DateTime expected = DateTime(DateTime.now().year, DateTime.now().month);
    for (final ci in sorted) {
      final ciMonth = DateTime(ci.month.year, ci.month.month);
      if (ciMonth == expected || ciMonth == DateTime(expected.year, expected.month - 1)) {
        count++;
        expected = DateTime(ciMonth.year, ciMonth.month - 1);
      } else {
        break;
      }
    }
    return count;
  }

  /// Total des versements mensuels planifies
  double get totalContributionsMensuelles =>
      plannedContributions.fold(0.0, (sum, c) => sum + c.amount);

  /// Total des versements 3a mensuels planifies
  double get total3aMensuel => plannedContributions
      .where((c) => c.category == '3a')
      .fold(0.0, (sum, c) => sum + c.amount);

  /// Total des rachats LPP mensuels planifies
  double get totalLppBuybackMensuel => plannedContributions
      .where((c) => c.category == 'lpp_buyback')
      .fold(0.0, (sum, c) => sum + c.amount);

  /// Total epargne libre mensuelle planifiee
  double get totalEpargneLibreMensuel => plannedContributions
      .where((c) => c.category == 'epargne_libre' || c.category == 'investissement')
      .fold(0.0, (sum, c) => sum + c.amount);

  /// Est-ce un profil couple ?
  bool get isCouple =>
      etatCivil == CoachCivilStatus.marie ||
      etatCivil == CoachCivilStatus.concubinage;

  /// Copie le profil avec une nouvelle liste de contributions
  CoachProfile copyWithContributions(List<PlannedMonthlyContribution> contributions) {
    return CoachProfile(
      firstName: firstName,
      birthYear: birthYear,
      canton: canton,
      commune: commune,
      etatCivil: etatCivil,
      nombreEnfants: nombreEnfants,
      conjoint: conjoint,
      salaireBrutMensuel: salaireBrutMensuel,
      nombreDeMois: nombreDeMois,
      bonusPourcentage: bonusPourcentage,
      employmentStatus: employmentStatus,
      depenses: depenses,
      prevoyance: prevoyance,
      patrimoine: patrimoine,
      dettes: dettes,
      goalA: goalA,
      goalsB: goalsB,
      plannedContributions: contributions,
      checkIns: checkIns,
      housingStatus: housingStatus,
      riskTolerance: riskTolerance,
      realEstateProject: realEstateProject,
      providers3a: providers3a,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  BRIDGE → BUDGET
  // ════════════════════════════════════════════════════════════════

  /// Convertit le CoachProfile en BudgetInputs.
  ///
  /// Utile quand on a un CoachProfile mais pas les réponses wizard brutes.
  /// Le revenu net est estimé à 87% du brut (charges sociales).
  /// Les dettes mensuelles sont estimées sur 36 mois de remboursement.
  BudgetInputs toBudgetInputs() {
    final netMensuel = salaireBrutMensuel * 0.87;
    final monthlyDebt = dettes.totalDettes > 0
        ? dettes.totalDettes / 36
        : 0.0;
    // Estimer les mois de fonds d'urgence
    final monthlyExpenses = depenses.totalMensuel > 0
        ? depenses.totalMensuel
        : netMensuel * 0.6; // fallback: 60% du net
    final emergencyMonths = monthlyExpenses > 0
        ? patrimoine.epargneLiquide / monthlyExpenses
        : 0.0;

    return BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: netMensuel,
      housingCost: depenses.loyer,
      debtPayments: monthlyDebt,
      emergencyFundMonths: emergencyMonths,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  SERIALIZATION
  // ════════════════════════════════════════════════════════════════

  factory CoachProfile.fromJson(Map<String, dynamic> json) {
    return CoachProfile(
      firstName: json['firstName'] as String?,
      birthYear: json['birthYear'] as int,
      canton: json['canton'] as String,
      commune: json['commune'] as String?,
      etatCivil: CoachCivilStatus.values.firstWhere(
        (e) => e.name == json['etatCivil'],
        orElse: () => CoachCivilStatus.celibataire,
      ),
      nombreEnfants: json['nombreEnfants'] ?? 0,
      conjoint: json['conjoint'] != null
          ? ConjointProfile.fromJson(json['conjoint'])
          : null,
      salaireBrutMensuel: (json['salaireBrutMensuel'] as num).toDouble(),
      nombreDeMois: json['nombreDeMois'] ?? 12,
      bonusPourcentage: (json['bonusPourcentage'] as num?)?.toDouble(),
      employmentStatus: json['employmentStatus'] ?? 'salarie',
      depenses: json['depenses'] != null
          ? DepensesProfile.fromJson(json['depenses'])
          : const DepensesProfile(),
      prevoyance: json['prevoyance'] != null
          ? PrevoyanceProfile.fromJson(json['prevoyance'])
          : const PrevoyanceProfile(),
      patrimoine: json['patrimoine'] != null
          ? PatrimoineProfile.fromJson(json['patrimoine'])
          : const PatrimoineProfile(),
      dettes: json['dettes'] != null
          ? DetteProfile.fromJson(json['dettes'])
          : const DetteProfile(),
      goalA: GoalA.fromJson(json['goalA']),
      goalsB: (json['goalsB'] as List?)
              ?.map((g) => GoalB.fromJson(g))
              .toList() ??
          const [],
      plannedContributions: (json['plannedContributions'] as List?)
              ?.map((c) => PlannedMonthlyContribution.fromJson(c))
              .toList() ??
          const [],
      checkIns: (json['checkIns'] as List?)
              ?.map((c) => MonthlyCheckIn.fromJson(c))
              .toList() ??
          const [],
      housingStatus: json['housingStatus'] as String?,
      riskTolerance: json['riskTolerance'] as String?,
      realEstateProject: json['realEstateProject'] as String?,
      providers3a: (json['providers3a'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'birthYear': birthYear,
    'canton': canton,
    'commune': commune,
    'etatCivil': etatCivil.name,
    'nombreEnfants': nombreEnfants,
    'conjoint': conjoint?.toJson(),
    'salaireBrutMensuel': salaireBrutMensuel,
    'nombreDeMois': nombreDeMois,
    'bonusPourcentage': bonusPourcentage,
    'employmentStatus': employmentStatus,
    'depenses': depenses.toJson(),
    'prevoyance': prevoyance.toJson(),
    'patrimoine': patrimoine.toJson(),
    'dettes': dettes.toJson(),
    'goalA': goalA.toJson(),
    'goalsB': goalsB.map((g) => g.toJson()).toList(),
    'plannedContributions': plannedContributions.map((c) => c.toJson()).toList(),
    'checkIns': checkIns.map((c) => c.toJson()).toList(),
    'housingStatus': housingStatus,
    'riskTolerance': riskTolerance,
    'realEstateProject': realEstateProject,
    'providers3a': providers3a,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  // ════════════════════════════════════════════════════════════════
  //  FACTORY: FROM WIZARD ANSWERS
  // ════════════════════════════════════════════════════════════════

  /// Construit un CoachProfile a partir des reponses du wizard.
  ///
  /// Mapping des 27 cles wizard → champs CoachProfile.
  /// Pour les champs que le wizard ne collecte pas, des estimations
  /// raisonnables sont utilisees (standards suisses).
  factory CoachProfile.fromWizardAnswers(Map<String, dynamic> answers) {
    // ── Identite ────────────────────────────────────────────
    final firstName = answers['q_firstname'] as String?;
    final birthYear = _parseInt(answers['q_birth_year']) ?? 1990;
    final canton = (answers['q_canton'] as String?) ?? 'ZH';
    final age = DateTime.now().year - birthYear;

    // Civil status mapping
    final civilStatusRaw = answers['q_civil_status'] as String?;
    final etatCivil = _parseCivilStatus(civilStatusRaw);

    // Children
    final childrenRaw = answers['q_children'];
    final nombreEnfants = _parseInt(childrenRaw) ?? 0;

    // ── Revenus ─────────────────────────────────────────────
    final payFrequency = answers['q_pay_frequency'] as String? ?? 'monthly';
    final netIncome = _parseDouble(answers['q_net_income_period_chf']) ?? 5000;

    // Convert to monthly brut (net → brut ≈ /0.87 for social charges)
    double monthlyNetIncome;
    if (payFrequency == 'yearly' || payFrequency == 'annuel') {
      monthlyNetIncome = netIncome / 12;
    } else {
      monthlyNetIncome = netIncome;
    }
    final salaireBrutMensuel = monthlyNetIncome / 0.87;

    // Employment status mapping
    final employmentRaw = answers['q_employment_status'] as String?;
    final employmentStatus = _parseEmploymentStatus(employmentRaw);

    // ── Depenses ────────────────────────────────────────────
    final housingCost = _parseDouble(answers['q_housing_cost_period_chf']) ?? 1500;
    double monthlyHousing;
    if (payFrequency == 'yearly' || payFrequency == 'annuel') {
      monthlyHousing = housingCost / 12;
    } else {
      monthlyHousing = housingCost;
    }

    // Estimate assurance maladie by canton (average ~400 CHF/month)
    final assuranceMaladie = _estimateAssuranceMaladie(canton);

    final depenses = DepensesProfile(
      loyer: monthlyHousing,
      assuranceMaladie: assuranceMaladie,
    );

    // ── Prevoyance ──────────────────────────────────────────
    final hasPensionFund = _parseBool(answers['q_has_pension_fund']);
    final lppBuybackAvailable = _parseDouble(answers['q_lpp_buyback_available']);
    final has3a = _parseBool(answers['q_has_3a']);
    final contribution3a = _parseDouble(answers['q_3a_annual_contribution']) ?? 0;
    final nombre3a = _parseInt(answers['q_3a_accounts_count']) ?? (has3a ? 1 : 0);
    final avsGaps = _parseInt(answers['q_avs_gaps']) ?? 0;
    final avsYears = _parseInt(answers['q_avs_contribution_years']);

    // Estimate LPP total based on age and salary (rough Swiss average)
    final estimatedLpp = hasPensionFund
        ? _estimateLppAvoir(age, salaireBrutMensuel)
        : 0.0;

    // Estimate 3a total from contribution and age
    final estimated3aTotal = has3a
        ? _estimate3aTotal(contribution3a, age)
        : 0.0;

    final prevoyance = PrevoyanceProfile(
      anneesContribuees: avsYears,
      lacunesAVS: avsGaps > 0 ? avsGaps : null,
      avoirLppTotal: estimatedLpp,
      rachatMaximum: lppBuybackAvailable,
      nombre3a: nombre3a,
      totalEpargne3a: estimated3aTotal,
    );

    // ── Patrimoine ──────────────────────────────────────────
    final hasInvestments = _parseBool(answers['q_has_investments']);
    final savingsMonthly = _parseDouble(answers['q_savings_monthly']) ?? 0;

    final estimatedMonthlyExpenses = monthlyHousing + assuranceMaladie;
    final emergencyFundRaw = answers['q_emergency_fund'];
    double epargneLiquide;
    if (emergencyFundRaw is String) {
      switch (emergencyFundRaw.toLowerCase()) {
        case 'yes_6months':
          epargneLiquide = estimatedMonthlyExpenses * 6;
        case 'yes_3months':
          epargneLiquide = estimatedMonthlyExpenses * 4.5;
        case 'no':
          epargneLiquide = savingsMonthly * 1;
        default:
          epargneLiquide = _parseDouble(emergencyFundRaw) ?? (savingsMonthly * 3);
      }
    } else {
      epargneLiquide = _parseDouble(emergencyFundRaw) ?? (savingsMonthly * 3);
    }

    final patrimoine = PatrimoineProfile(
      epargneLiquide: epargneLiquide,
      investissements: hasInvestments ? 10000 : 0,
    );

    // ── Dettes ──────────────────────────────────────────────
    final hasDebt = _parseBool(answers['q_has_consumer_debt']);
    final dettes = hasDebt
        ? DetteProfile(creditConsommation: salaireBrutMensuel * 12 * 0.08)
        : const DetteProfile();

    // ── Goal A ──────────────────────────────────────────────
    final mainGoalRaw = answers['q_main_goal'] as String?;
    final goalA = _parseGoalA(mainGoalRaw, birthYear);

    // ── Planned contributions ───────────────────────────────
    final contributions = <PlannedMonthlyContribution>[];
    if (has3a && contribution3a > 0) {
      contributions.add(PlannedMonthlyContribution(
        id: '3a_user',
        label: '3a ${firstName ?? "Toi"}',
        amount: contribution3a / 12, // annual → monthly
        category: '3a',
        isAutomatic: false,
      ));
    }
    if (savingsMonthly > 0 && savingsMonthly > (contribution3a / 12)) {
      final epargneLibre = savingsMonthly - (contribution3a / 12);
      if (epargneLibre > 50) {
        contributions.add(PlannedMonthlyContribution(
          id: 'epargne_user',
          label: 'Epargne libre',
          amount: epargneLibre,
          category: 'epargne_libre',
          isAutomatic: false,
        ));
      }
    }

    return CoachProfile(
      firstName: firstName,
      birthYear: birthYear,
      canton: canton,
      etatCivil: etatCivil,
      nombreEnfants: nombreEnfants,
      salaireBrutMensuel: salaireBrutMensuel,
      employmentStatus: employmentStatus,
      depenses: depenses,
      prevoyance: prevoyance,
      patrimoine: patrimoine,
      dettes: dettes,
      goalA: goalA,
      plannedContributions: contributions,
      housingStatus: answers['q_housing_status'] as String?,
      riskTolerance: answers['q_risk_tolerance'] as String?,
      realEstateProject: answers['q_real_estate_project'] as String?,
      providers3a: (answers['q_3a_providers'] is List)
          ? (answers['q_3a_providers'] as List).cast<String>()
          : <String>[],
    );
  }

  // ── Parsing helpers ─────────────────────────────────────────

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == 'oui' || lower == 'yes';
    }
    return false;
  }

  static CoachCivilStatus _parseCivilStatus(String? raw) {
    if (raw == null) return CoachCivilStatus.celibataire;
    switch (raw.toLowerCase()) {
      case 'marie':
      case 'marié':
      case 'married':
        return CoachCivilStatus.marie;
      case 'divorce':
      case 'divorcé':
      case 'divorced':
        return CoachCivilStatus.divorce;
      case 'veuf':
      case 'veuve':
      case 'widowed':
        return CoachCivilStatus.veuf;
      case 'concubinage':
      case 'partenariat':
        return CoachCivilStatus.concubinage;
      default:
        return CoachCivilStatus.celibataire;
    }
  }

  static String _parseEmploymentStatus(String? raw) {
    if (raw == null) return 'salarie';
    switch (raw.toLowerCase()) {
      case 'employee':
      case 'salarie':
      case 'salarié':
        return 'salarie';
      case 'self_employed':
      case 'independant':
      case 'indépendant':
        return 'independant';
      case 'retired':
      case 'retraite':
      case 'retraité':
        return 'retraite';
      case 'student':
      case 'etudiant':
      case 'étudiant':
        return 'etudiant';
      case 'mixed':
      case 'mixte':
        return 'mixte';
      default:
        return 'salarie';
    }
  }

  static GoalA _parseGoalA(String? raw, int birthYear) {
    final retirementYear = birthYear + 65;
    final retirementDate = DateTime(retirementYear, 12, 31);

    if (raw == null) {
      return GoalA(
        type: GoalAType.retraite,
        targetDate: retirementDate,
        label: 'Retraite a 65 ans',
      );
    }

    switch (raw.toLowerCase()) {
      case 'retirement':
        return GoalA(
          type: GoalAType.retraite,
          targetDate: retirementDate,
          label: 'Retraite a 65 ans',
        );
      case 'real_estate':
      case 'house':
      case 'achat_immo':
      case 'achatimmo':
        return GoalA(
          type: GoalAType.achatImmo,
          targetDate: DateTime.now().add(const Duration(days: 365 * 5)),
          label: 'Achat immobilier',
        );
      case 'independence':
      case 'invest':
      case 'independance':
        return GoalA(
          type: GoalAType.independance,
          targetDate: DateTime.now().add(const Duration(days: 365 * 10)),
          label: 'Independance financiere',
        );
      case 'inheritance':
        return GoalA(
          type: GoalAType.retraite,
          targetDate: retirementDate,
          label: 'Transmission de patrimoine',
        );
      case 'project':
        return GoalA(
          type: GoalAType.custom,
          targetDate: DateTime.now().add(const Duration(days: 365 * 3)),
          label: 'Projet personnel',
        );
      case 'debt_free':
      case 'debtfree':
        return GoalA(
          type: GoalAType.debtFree,
          targetDate: DateTime.now().add(const Duration(days: 365 * 3)),
          label: 'Zero dette',
        );
      default:
        return GoalA(
          type: GoalAType.retraite,
          targetDate: retirementDate,
          label: 'Retraite a 65 ans',
        );
    }
  }

  /// Estime l'avoir LPP total selon l'age et le salaire brut mensuel.
  /// Approximation basee sur les taux de bonification LPP par age.
  static double _estimateLppAvoir(int age, double salaireBrutMensuel) {
    final salaireBrut = salaireBrutMensuel * 12;
    final salaireCoordonne = (salaireBrut - 26460).clamp(3780, double.infinity);
    double total = 0;
    for (int a = 25; a < age && a < 65; a++) {
      double taux;
      if (a < 35) {
        taux = 0.07;
      } else if (a < 45) {
        taux = 0.10;
      } else if (a < 55) {
        taux = 0.15;
      } else {
        taux = 0.18;
      }
      total = total * 1.01 + salaireCoordonne * taux; // 1% rendement
    }
    return total;
  }

  /// Estime le total 3a en fonction de la contribution annuelle et de l'age.
  static double _estimate3aTotal(double contributionAnnuelle, int age) {
    if (contributionAnnuelle <= 0) return 0;
    // Estimation: contribution depuis age 25, rendement 2% par an
    final anneesContribution = (age - 25).clamp(0, 40);
    double total = 0;
    for (int i = 0; i < anneesContribution; i++) {
      total = total * 1.02 + contributionAnnuelle;
    }
    return total;
  }

  /// Estime l'assurance maladie mensuelle par canton (moyenne adulte).
  static double _estimateAssuranceMaladie(String canton) {
    // Moyennes approximatives 2025 (franchise 2500, 26+)
    const cantonalAverages = <String, double>{
      'GE': 520, 'BS': 490, 'VD': 470, 'TI': 460, 'NE': 450,
      'ZH': 440, 'BE': 410, 'LU': 380, 'AG': 400, 'SG': 370,
      'VS': 380, 'FR': 390, 'SO': 400, 'TG': 370, 'GR': 350,
      'BL': 430, 'ZG': 340, 'SZ': 350, 'NW': 340, 'OW': 340,
      'UR': 330, 'GL': 360, 'SH': 400, 'AR': 360, 'AI': 340,
      'JU': 420,
    };
    return cantonalAverages[canton.toUpperCase()] ?? 400;
  }

  // ════════════════════════════════════════════════════════════════
  //  DEMO PROFILE (Julien + Lauren)
  // ════════════════════════════════════════════════════════════════

  /// Profil demo base sur le scenario Julien+Lauren (fondateur)
  static CoachProfile buildDemo() {
    return CoachProfile(
      firstName: 'Julien',
      birthYear: 1977,
      canton: 'VS',
      commune: 'Sion',
      etatCivil: CoachCivilStatus.marie,
      nombreEnfants: 0,
      conjoint: const ConjointProfile(
        firstName: 'Lauren',
        birthYear: 1981,
        salaireBrutMensuel: 5000,
        nombreDeMois: 12,
        nationality: 'US',
        isFatcaResident: true,
        canContribute3a: false, // FATCA → certains providers 3a refusent
        prevoyance: PrevoyanceProfile(
          nomCaisse: 'Hotela',
          avoirLppTotal: 50000,
          rachatMaximum: 50000,
          rachatEffectue: 0,
          tauxConversion: 0.068,
          rendementCaisse: 0.015,
          nombre3a: 0,
          totalEpargne3a: 0,
          canContribute3a: false,
          lacunesAVS: 14,
        ),
      ),
      salaireBrutMensuel: 9080,
      nombreDeMois: 13,
      bonusPourcentage: 7,
      employmentStatus: 'salarie',
      depenses: const DepensesProfile(
        loyer: 1980,
        assuranceMaladie: 850,
        electricite: 80,
        transport: 400,
        telecom: 120,
        fraisMedicaux: 50,
        autresDepensesFixes: 300,
      ),
      prevoyance: const PrevoyanceProfile(
        nomCaisse: 'Caisse des Electriciens',
        avoirLppTotal: 300000,
        rachatMaximum: 300000,
        rachatEffectue: 0,
        tauxConversion: 0.068,
        rendementCaisse: 0.02,
        nombre3a: 5,
        totalEpargne3a: 35000,
        comptes3a: [
          Compte3a(provider: 'VIAC', solde: 10000, rendementEstime: 0.045),
          Compte3a(provider: 'VIAC', solde: 8000, rendementEstime: 0.045),
          Compte3a(provider: 'VIAC', solde: 7000, rendementEstime: 0.045),
          Compte3a(provider: 'Finpens', solde: 5000, rendementEstime: 0.05),
          Compte3a(provider: 'Finpens', solde: 5000, rendementEstime: 0.05),
        ],
        canContribute3a: true,
      ),
      patrimoine: const PatrimoineProfile(
        epargneLiquide: 15000,
        investissements: 100000,
        deviseInvestissements: InvestmentCurrency.usd,
        plateformeInvestissement: 'Interactive Brokers',
      ),
      dettes: const DetteProfile(),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2042, 12, 31),
        label: 'Retraite a 65 ans',
      ),
      plannedContributions: const [
        PlannedMonthlyContribution(
          id: '3a_julien',
          label: '3a Julien (VIAC)',
          amount: 604.83,
          category: '3a',
          isAutomatic: true,
        ),
        PlannedMonthlyContribution(
          id: '3a_lauren',
          label: '3a Lauren',
          amount: 604.83,
          category: '3a',
          isAutomatic: true,
        ),
        PlannedMonthlyContribution(
          id: 'lpp_buyback_julien',
          label: 'Rachat LPP Julien',
          amount: 1000,
          category: 'lpp_buyback',
          isAutomatic: false,
        ),
        PlannedMonthlyContribution(
          id: 'lpp_buyback_lauren',
          label: 'Rachat LPP Lauren',
          amount: 500,
          category: 'lpp_buyback',
          isAutomatic: false,
        ),
        PlannedMonthlyContribution(
          id: 'ib_julien',
          label: 'Interactive Brokers',
          amount: 1000,
          category: 'investissement',
          isAutomatic: false,
        ),
        PlannedMonthlyContribution(
          id: 'epargne_lauren',
          label: 'Epargne Lauren',
          amount: 500,
          category: 'epargne_libre',
          isAutomatic: false,
        ),
      ],
    );
  }
}
