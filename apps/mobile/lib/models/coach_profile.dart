/// Profil financier etendu pour MINT Coach
///
/// Ce modele sert de base au ForecasterService et au FinancialFitnessScore.
/// Il etend le Profile existant avec : couple, prevoyance detaillee,
/// patrimoine, objectifs, et historique de check-ins mensuels.

/// Sprint C1 — MINT Coach Redesign
library;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

// ════════════════════════════════════════════════════════════════
//  ENUMS
// ════════════════════════════════════════════════════════════════

/// Etat civil pour le coach
enum CoachCivilStatus { celibataire, marie, divorce, veuf, concubinage }

/// Source d'une donnee financiere dans le profil.
/// Permet de distinguer les valeurs saisies, estimees ou certifiees.
enum ProfileDataSource {
  estimated, // Defaut calcule par MINT (confiance 0.25)
  userInput, // Saisi manuellement (confiance 0.60)
  crossValidated, // Saisie + verification croisee (confiance 0.70)
  certificate, // Extrait d'un certificat scanne (confiance 0.95)
  openBanking, // Donnees bancaires live bLink/SFTI (confiance 1.00)
}

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
  final String?
      employmentStatus; // 'salarie', 'independant', 'chomage', 'retraite'
  final String? nationality; // ISO 2-letter code, ex "CH", "US", "FR"
  final bool isFatcaResident; // US citizen/green card → FATCA restrictions
  final bool canContribute3a; // false si FATCA resident (certains providers)
  final PrevoyanceProfile? prevoyance;

  /// Age at which the conjoint arrived in Switzerland.
  /// If null, assumes contributions since age 20 (Swiss native).
  final int? arrivalAge;

  /// Target retirement age for the conjoint (58-70).
  /// Null means default (65 ans).
  final int? targetRetirementAge;

  const ConjointProfile({
    this.firstName,
    this.birthYear,
    this.salaireBrutMensuel,
    this.nombreDeMois = 12,
    this.bonusPourcentage,
    this.employmentStatus,
    this.nationality,
    this.isFatcaResident = false,
    this.canContribute3a = true,
    this.prevoyance,
    this.arrivalAge,
    this.targetRetirementAge,
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

  /// Age de retraite effectif (custom ou 65 par defaut).
  int get effectiveRetirementAge => targetRetirementAge ?? 65;

  /// Annees restantes avant retraite.
  int? get anneesAvantRetraite {
    final a = age;
    if (a == null) return null;
    return (effectiveRetirementAge - a).clamp(0, 99);
  }

  /// If FATCA resident but prevoyance.canContribute3a is still true,
  /// returns a corrected copy with canContribute3a = false.
  static PrevoyanceProfile? _enforceFatca3a(
    bool isFatca,
    PrevoyanceProfile? prev,
  ) {
    if (!isFatca || prev == null || !prev.canContribute3a) return prev;
    return PrevoyanceProfile(
      nomCaisse: prev.nomCaisse,
      avoirLppObligatoire: prev.avoirLppObligatoire,
      avoirLppSurobligatoire: prev.avoirLppSurobligatoire,
      avoirLppTotal: prev.avoirLppTotal,
      rachatMaximum: prev.rachatMaximum,
      rachatEffectue: prev.rachatEffectue,
      tauxConversion: prev.tauxConversion,
      tauxConversionSuroblig: prev.tauxConversionSuroblig,
      rendementCaisse: prev.rendementCaisse,
      anneesContribuees: prev.anneesContribuees,
      lacunesAVS: prev.lacunesAVS,
      nombre3a: prev.nombre3a,
      totalEpargne3a: prev.totalEpargne3a,
      comptes3a: prev.comptes3a,
      canContribute3a: false,
    );
  }

  factory ConjointProfile.fromJson(Map<String, dynamic> json) {
    final isFatca = json['isFatcaResident'] ?? false;
    // FATCA invariant: isFatcaResident=true → canContribute3a=false, always.
    final topCanContribute =
        isFatca ? false : (json['canContribute3a'] ?? true);
    PrevoyanceProfile? prev;
    if (json['prevoyance'] != null) {
      prev = PrevoyanceProfile.fromJson(json['prevoyance']);
    }
    prev = _enforceFatca3a(isFatca, prev);
    return ConjointProfile(
      firstName: json['firstName'] as String?,
      birthYear: json['birthYear'] as int?,
      salaireBrutMensuel: (json['salaireBrutMensuel'] as num?)?.toDouble(),
      nombreDeMois: json['nombreDeMois'] ?? 12,
      bonusPourcentage: (json['bonusPourcentage'] as num?)?.toDouble(),
      employmentStatus: json['employmentStatus'] as String?,
      nationality: json['nationality'] as String?,
      isFatcaResident: isFatca,
      canContribute3a: topCanContribute,
      prevoyance: prev,
      arrivalAge: json['arrivalAge'] as int?,
      targetRetirementAge: json['targetRetirementAge'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'birthYear': birthYear,
        'salaireBrutMensuel': salaireBrutMensuel,
        'nombreDeMois': nombreDeMois,
        'bonusPourcentage': bonusPourcentage,
        'employmentStatus': employmentStatus,
        'nationality': nationality,
        'isFatcaResident': isFatcaResident,
        'canContribute3a': canContribute3a,
        'prevoyance': prevoyance?.toJson(),
        'arrivalAge': arrivalAge,
        'targetRetirementAge': targetRetirementAge,
      };

  ConjointProfile copyWith({
    String? firstName,
    int? birthYear,
    double? salaireBrutMensuel,
    int? nombreDeMois,
    double? bonusPourcentage,
    String? employmentStatus,
    String? nationality,
    bool? isFatcaResident,
    bool? canContribute3a,
    PrevoyanceProfile? prevoyance,
    int? arrivalAge,
    int? targetRetirementAge,
  }) {
    final effectiveFatca = isFatcaResident ?? this.isFatcaResident;
    // FATCA invariant: isFatcaResident=true → canContribute3a=false, always.
    final effectiveCan =
        effectiveFatca ? false : (canContribute3a ?? this.canContribute3a);
    final effectivePrev = _enforceFatca3a(
      effectiveFatca,
      prevoyance ?? this.prevoyance,
    );
    return ConjointProfile(
      firstName: firstName ?? this.firstName,
      birthYear: birthYear ?? this.birthYear,
      salaireBrutMensuel: salaireBrutMensuel ?? this.salaireBrutMensuel,
      nombreDeMois: nombreDeMois ?? this.nombreDeMois,
      bonusPourcentage: bonusPourcentage ?? this.bonusPourcentage,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      nationality: nationality ?? this.nationality,
      isFatcaResident: effectiveFatca,
      canContribute3a: effectiveCan,
      prevoyance: effectivePrev,
      arrivalAge: arrivalAge ?? this.arrivalAge,
      targetRetirementAge: targetRetirementAge ?? this.targetRetirementAge,
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
  final double? avoirLppObligatoire; // part obligatoire (taux min 6.8%)
  final double? avoirLppSurobligatoire; // part surobligatoire (taux caisse)
  final double? rachatMaximum; // lacune de rachat totale
  final double? rachatEffectue; // deja rachete
  final double tauxConversion; // taux de la caisse (min legal 6.8%)
  final double? tauxConversionSuroblig; // taux surobligatoire de la caisse
  final double rendementCaisse; // rendement annuel estime de la caisse
  final double? salaireAssure; // salaire assure LPP (from certificate)

  // --- AVS (from extraction) ---
  final double? ramd; // revenu annuel moyen determinant (AVS)

  // --- 3a ---
  final int nombre3a; // nombre de comptes 3a
  final double totalEpargne3a; // solde total 3a
  final List<Compte3a> comptes3a;
  final bool canContribute3a; // false si US citizen/FATCA

  // --- Libre passage ---
  final List<LibrePassageCompte> librePassage;

  const PrevoyanceProfile({
    this.anneesContribuees,
    this.lacunesAVS,
    this.renteAVSEstimeeMensuelle,
    this.nomCaisse,
    this.avoirLppTotal,
    this.avoirLppObligatoire,
    this.avoirLppSurobligatoire,
    this.rachatMaximum,
    this.rachatEffectue,
    this.tauxConversion = 0.068,
    this.tauxConversionSuroblig,
    this.rendementCaisse = 0.02,
    this.salaireAssure,
    this.ramd,
    this.nombre3a = 0,
    this.totalEpargne3a = 0,
    this.comptes3a = const [],
    this.canContribute3a = true,
    this.librePassage = const [],
  });

  /// Total avoir libre passage
  double get totalLibrePassage =>
      librePassage.fold(0.0, (sum, lp) => sum + lp.solde);

  /// Lacune de rachat LPP restante
  double get lacuneRachatRestante {
    return ((rachatMaximum ?? 0) - (rachatEffectue ?? 0))
        .clamp(0, double.infinity);
  }

  /// Rendement moyen pondere des comptes 3a.
  /// Si aucun compte, retourne 0.02 (hypothese conservative).
  double get rendementMoyen3a {
    if (comptes3a.isEmpty || totalEpargne3a <= 0) return 0.02;
    double weightedSum = 0;
    double totalSolde = 0;
    for (final c in comptes3a) {
      weightedSum += c.solde * c.rendementEstime;
      totalSolde += c.solde;
    }
    return totalSolde > 0 ? weightedSum / totalSolde : 0.02;
  }

  factory PrevoyanceProfile.fromJson(Map<String, dynamic> json) {
    return PrevoyanceProfile(
      anneesContribuees: json['anneesContribuees'] as int?,
      lacunesAVS: json['lacunesAVS'] as int?,
      renteAVSEstimeeMensuelle:
          (json['renteAVSEstimeeMensuelle'] as num?)?.toDouble(),
      nomCaisse: json['nomCaisse'] as String?,
      avoirLppTotal: (json['avoirLppTotal'] as num?)?.toDouble(),
      avoirLppObligatoire: (json['avoirLppObligatoire'] as num?)?.toDouble(),
      avoirLppSurobligatoire:
          (json['avoirLppSurobligatoire'] as num?)?.toDouble(),
      rachatMaximum: (json['rachatMaximum'] as num?)?.toDouble(),
      rachatEffectue: (json['rachatEffectue'] as num?)?.toDouble(),
      tauxConversion: (json['tauxConversion'] as num?)?.toDouble() ?? 0.068,
      tauxConversionSuroblig:
          (json['tauxConversionSuroblig'] as num?)?.toDouble(),
      rendementCaisse: (json['rendementCaisse'] as num?)?.toDouble() ?? 0.02,
      salaireAssure: (json['salaireAssure'] as num?)?.toDouble(),
      ramd: (json['ramd'] as num?)?.toDouble(),
      nombre3a: json['nombre3a'] ?? 0,
      totalEpargne3a: (json['totalEpargne3a'] as num?)?.toDouble() ?? 0,
      comptes3a: (json['comptes3a'] as List?)
              ?.map((c) => Compte3a.fromJson(c))
              .toList() ??
          const [],
      canContribute3a: json['canContribute3a'] ?? true,
      librePassage: (json['librePassage'] as List?)
              ?.map((lp) => LibrePassageCompte.fromJson(lp))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'anneesContribuees': anneesContribuees,
        'lacunesAVS': lacunesAVS,
        'renteAVSEstimeeMensuelle': renteAVSEstimeeMensuelle,
        'nomCaisse': nomCaisse,
        'avoirLppTotal': avoirLppTotal,
        'avoirLppObligatoire': avoirLppObligatoire,
        'avoirLppSurobligatoire': avoirLppSurobligatoire,
        'rachatMaximum': rachatMaximum,
        'rachatEffectue': rachatEffectue,
        'tauxConversion': tauxConversion,
        'tauxConversionSuroblig': tauxConversionSuroblig,
        'rendementCaisse': rendementCaisse,
        'salaireAssure': salaireAssure,
        'ramd': ramd,
        'nombre3a': nombre3a,
        'totalEpargne3a': totalEpargne3a,
        'comptes3a': comptes3a.map((c) => c.toJson()).toList(),
        'canContribute3a': canContribute3a,
        'librePassage': librePassage.map((lp) => lp.toJson()).toList(),
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

/// Compte de libre passage (apres changement d'emploi ou lacune LPP).
/// Souvent 10-20% du patrimoine prevoyance des 45-60 ans.
class LibrePassageCompte {
  final String? institution; // ex: "Fondation Libre Passage UBS"
  final double solde;
  final DateTime? dateOuverture;

  const LibrePassageCompte({
    this.institution,
    required this.solde,
    this.dateOuverture,
  });

  factory LibrePassageCompte.fromJson(Map<String, dynamic> json) {
    return LibrePassageCompte(
      institution: json['institution'] as String?,
      solde: (json['solde'] as num).toDouble(),
      dateOuverture: json['dateOuverture'] != null
          ? DateTime.parse(json['dateOuverture'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'institution': institution,
        'solde': solde,
        'dateOuverture': dateOuverture?.toIso8601String(),
      };
}

/// Patrimoine (epargne + investissements + immobilier)
class PatrimoineProfile {
  final double epargneLiquide;
  final double investissements;
  final double? immobilier;
  final InvestmentCurrency deviseInvestissements;
  final String? plateformeInvestissement; // "Interactive Brokers", etc.

  // P2: Housing model fields
  final double? propertyMarketValue;
  final double? mortgageBalance;
  final double? mortgageRate;
  final double? monthlyRent;

  const PatrimoineProfile({
    this.epargneLiquide = 0,
    this.investissements = 0,
    this.immobilier,
    this.deviseInvestissements = InvestmentCurrency.chf,
    this.plateformeInvestissement,
    this.propertyMarketValue,
    this.mortgageBalance,
    this.mortgageRate,
    this.monthlyRent,
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
      propertyMarketValue: (json['propertyMarketValue'] as num?)?.toDouble(),
      mortgageBalance: (json['mortgageBalance'] as num?)?.toDouble(),
      mortgageRate: (json['mortgageRate'] as num?)?.toDouble(),
      monthlyRent: (json['monthlyRent'] as num?)?.toDouble(),
    );
  }

  PatrimoineProfile copyWith({
    double? epargneLiquide,
    double? investissements,
    double? immobilier,
    InvestmentCurrency? deviseInvestissements,
    String? plateformeInvestissement,
    double? propertyMarketValue,
    double? mortgageBalance,
    double? mortgageRate,
    double? monthlyRent,
  }) {
    return PatrimoineProfile(
      epargneLiquide: epargneLiquide ?? this.epargneLiquide,
      investissements: investissements ?? this.investissements,
      immobilier: immobilier ?? this.immobilier,
      deviseInvestissements:
          deviseInvestissements ?? this.deviseInvestissements,
      plateformeInvestissement:
          plateformeInvestissement ?? this.plateformeInvestissement,
      propertyMarketValue: propertyMarketValue ?? this.propertyMarketValue,
      mortgageBalance: mortgageBalance ?? this.mortgageBalance,
      mortgageRate: mortgageRate ?? this.mortgageRate,
      monthlyRent: monthlyRent ?? this.monthlyRent,
    );
  }

  Map<String, dynamic> toJson() => {
        'epargneLiquide': epargneLiquide,
        'investissements': investissements,
        'immobilier': immobilier,
        'deviseInvestissements': deviseInvestissements.name,
        'plateformeInvestissement': plateformeInvestissement,
        'propertyMarketValue': propertyMarketValue,
        'mortgageBalance': mortgageBalance,
        'mortgageRate': mortgageRate,
        'monthlyRent': monthlyRent,
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

  DetteProfile copyWith({
    double? creditConsommation,
    double? leasing,
    double? hypotheque,
    double? autresDettes,
  }) {
    return DetteProfile(
      creditConsommation: creditConsommation ?? this.creditConsommation,
      leasing: leasing ?? this.leasing,
      hypotheque: hypotheque ?? this.hypotheque,
      autresDettes: autresDettes ?? this.autresDettes,
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

  DepensesProfile copyWith({
    double? loyer,
    double? assuranceMaladie,
    double? electricite,
    double? transport,
    double? telecom,
    double? fraisMedicaux,
    double? autresDepensesFixes,
  }) {
    return DepensesProfile(
      loyer: loyer ?? this.loyer,
      assuranceMaladie: assuranceMaladie ?? this.assuranceMaladie,
      electricite: electricite ?? this.electricite,
      transport: transport ?? this.transport,
      telecom: telecom ?? this.telecom,
      fraisMedicaux: fraisMedicaux ?? this.fraisMedicaux,
      autresDepensesFixes: autresDepensesFixes ?? this.autresDepensesFixes,
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
      revenusExceptionnels: (json['revenusExceptionnels'] as num?)?.toDouble(),
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
  final String
      category; // '3a', 'lpp_buyback', 'epargne_libre', 'investissement'
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

  PlannedMonthlyContribution copyWith({
    String? id,
    String? label,
    double? amount,
    String? category,
    bool? isAutomatic,
  }) {
    return PlannedMonthlyContribution(
      id: id ?? this.id,
      label: label ?? this.label,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      isAutomatic: isAutomatic ?? this.isAutomatic,
    );
  }
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
  final String? nationality; // ISO 2-letter code, ex "CH", "US", "FR"
  final CoachCivilStatus etatCivil;
  final int nombreEnfants;

  // === CONJOINT ===
  final ConjointProfile? conjoint;

  // === REVENUS ===
  final double salaireBrutMensuel;
  final int nombreDeMois; // 12, 13, 13.5
  final double? bonusPourcentage;
  final String
      employmentStatus; // 'salarie', 'independant', 'chomage', 'retraite'

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

  /// Age at which the person arrived in Switzerland.
  /// Derived from q_avs_arrival_year in the wizard. Used by
  /// _estimateLppAvoir() to avoid overestimating LPP for expats
  /// who did not contribute from age 25.
  final int? arrivalAge;

  /// Residence permit type (e.g. 'B', 'C', 'L', 'G', 'Swiss').
  /// Mapped from q_residence_permit in the wizard.
  /// Relevant for cross-border workers (permis G) and expats.
  final String? residencePermit;

  /// Family change reported during annual refresh (e.g. 'Mariage', 'Naissance').
  /// Used by CoachingService for life event nudges.
  final String? familyChange;

  /// Target retirement age chosen by the user (58-70).
  /// Null means default (65 ans, age legal AVS).
  /// LAVS art. 40: anticipation possible des 63 ans.
  /// Certaines caisses LPP permettent des 58 ans.
  final int? targetRetirementAge;

  // === SNAPSHOT ===
  /// Day-1 projection snapshot captured at onboarding completion.
  /// Enables before/after comparison on the dashboard (Phase 5).
  /// Null until the first projection is run post-onboarding.
  final Map<String, dynamic>? initialProjectionSnapshot;

  // === META ===
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Source tracking per field (key = field path, value = source).
  /// Ex: {'prevoyance.avoirLppTotal': ProfileDataSource.certificate}
  final Map<String, ProfileDataSource> dataSources;

  CoachProfile({
    this.firstName,
    required this.birthYear,
    required this.canton,
    this.commune,
    this.nationality,
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
    this.arrivalAge,
    this.residencePermit,
    this.familyChange,
    this.targetRetirementAge,
    this.initialProjectionSnapshot,
    Map<String, ProfileDataSource> dataSources = const {},
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        dataSources = _resolveDataSources(dataSources, prevoyance);

  static Map<String, ProfileDataSource> _resolveDataSources(
    Map<String, ProfileDataSource> provided,
    PrevoyanceProfile prevoyance,
  ) {
    final inferred = <String, ProfileDataSource>{};

    // LPP source inference: split fields / insured salary indicate
    // certificate-backed extraction; otherwise fallback to estimated.
    final hasLppCertificateSignals = prevoyance.avoirLppObligatoire != null ||
        prevoyance.avoirLppSurobligatoire != null ||
        prevoyance.salaireAssure != null ||
        prevoyance.tauxConversionSuroblig != null ||
        prevoyance.rachatMaximum != null;

    if (prevoyance.avoirLppTotal != null) {
      inferred['prevoyance.avoirLppTotal'] = hasLppCertificateSignals
          ? ProfileDataSource.certificate
          : ProfileDataSource.estimated;
    }
    if (prevoyance.avoirLppObligatoire != null) {
      inferred['prevoyance.avoirLppObligatoire'] =
          ProfileDataSource.certificate;
    }
    if (prevoyance.avoirLppSurobligatoire != null) {
      inferred['prevoyance.avoirLppSurobligatoire'] =
          ProfileDataSource.certificate;
    }
    if (prevoyance.salaireAssure != null) {
      inferred['prevoyance.salaireAssure'] = ProfileDataSource.certificate;
    }

    // AVS source inference: RAMD / contribution years indicate
    // document-backed values (certificate/extract).
    if (prevoyance.ramd != null) {
      inferred['prevoyance.ramd'] = ProfileDataSource.certificate;
    }
    if (prevoyance.anneesContribuees != null) {
      inferred['prevoyance.anneesContribuees'] = ProfileDataSource.certificate;
    }
    if (prevoyance.lacunesAVS != null) {
      inferred['prevoyance.lacunesAVS'] = ProfileDataSource.certificate;
    }
    if (prevoyance.renteAVSEstimeeMensuelle != null) {
      inferred['prevoyance.renteAVSEstimeeMensuelle'] =
          ProfileDataSource.certificate;
    }

    // Merge: provided entries (e.g. fiscal from extraction) win over inferred
    return {...inferred, ...provided};
  }

  // ════════════════════════════════════════════════════════════════
  //  EQUALITY (version-check for lifecycle dedup — Phase 5)
  // ════════════════════════════════════════════════════════════════
  //
  // Intentional version-check equality for lifecycle dedup.
  // updatedAt changes on every copyWith() call, acting as a version
  // token. This ensures didChangeDependencies() correctly detects
  // ANY profile mutation (even to fields not listed here).
  //
  // Trade-off accepted: two profiles with identical data but different
  // updatedAt are treated as different (causes recomputation). This is
  // preferred over missing a genuine data change.

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachProfile &&
          runtimeType == other.runtimeType &&
          birthYear == other.birthYear &&
          canton == other.canton &&
          salaireBrutMensuel == other.salaireBrutMensuel &&
          employmentStatus == other.employmentStatus &&
          etatCivil == other.etatCivil &&
          nombreEnfants == other.nombreEnfants &&
          targetRetirementAge == other.targetRetirementAge &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        birthYear,
        canton,
        salaireBrutMensuel,
        employmentStatus,
        etatCivil,
        nombreEnfants,
        targetRetirementAge,
        updatedAt,
      );

  // ════════════════════════════════════════════════════════════════
  //  COMPUTED PROPERTIES
  // ════════════════════════════════════════════════════════════════

  /// Age actuel
  int get age => DateTime.now().year - birthYear;

  /// Age de retraite effectif (custom ou 65 par defaut).
  int get effectiveRetirementAge => targetRetirementAge ?? 65;

  /// Annees restantes avant retraite.
  int get anneesAvantRetraite => (effectiveRetirementAge - age).clamp(0, 99);

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
    final breakdown = NetIncomeBreakdown.compute(
      grossSalary: salaireBrutMensuel * 12,
      canton: canton,
      age: age,
    );
    return breakdown.monthlyNetPayslip - totalDepensesMensuelles;
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
      if (ciMonth == expected ||
          ciMonth == DateTime(expected.year, expected.month - 1)) {
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
      .where((c) =>
          c.category == 'epargne_libre' || c.category == 'investissement')
      .fold(0.0, (sum, c) => sum + c.amount);

  /// Est-ce un profil couple ?
  bool get isCouple =>
      etatCivil == CoachCivilStatus.marie ||
      etatCivil == CoachCivilStatus.concubinage;

  /// Copie le profil avec des champs optionnels mis a jour.
  /// Utilise par le annual refresh pour persister updatedAt, prevoyance, etc.
  CoachProfile copyWith({
    String? firstName,
    int? birthYear,
    String? canton,
    String? commune,
    String? nationality,
    CoachCivilStatus? etatCivil,
    int? nombreEnfants,
    ConjointProfile? conjoint,
    double? salaireBrutMensuel,
    int? nombreDeMois,
    double? bonusPourcentage,
    String? employmentStatus,
    DepensesProfile? depenses,
    PrevoyanceProfile? prevoyance,
    PatrimoineProfile? patrimoine,
    DetteProfile? dettes,
    GoalA? goalA,
    List<GoalB>? goalsB,
    List<PlannedMonthlyContribution>? plannedContributions,
    List<MonthlyCheckIn>? checkIns,
    String? housingStatus,
    String? riskTolerance,
    String? realEstateProject,
    List<String>? providers3a,
    int? arrivalAge,
    String? residencePermit,
    String? familyChange,
    int? targetRetirementAge,
    Map<String, dynamic>? initialProjectionSnapshot,
    Map<String, ProfileDataSource>? dataSources,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CoachProfile(
      firstName: firstName ?? this.firstName,
      birthYear: birthYear ?? this.birthYear,
      canton: canton ?? this.canton,
      commune: commune ?? this.commune,
      nationality: nationality ?? this.nationality,
      etatCivil: etatCivil ?? this.etatCivil,
      nombreEnfants: nombreEnfants ?? this.nombreEnfants,
      conjoint: conjoint ?? this.conjoint,
      salaireBrutMensuel: salaireBrutMensuel ?? this.salaireBrutMensuel,
      nombreDeMois: nombreDeMois ?? this.nombreDeMois,
      bonusPourcentage: bonusPourcentage ?? this.bonusPourcentage,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      depenses: depenses ?? this.depenses,
      prevoyance: prevoyance ?? this.prevoyance,
      patrimoine: patrimoine ?? this.patrimoine,
      dettes: dettes ?? this.dettes,
      goalA: goalA ?? this.goalA,
      goalsB: goalsB ?? this.goalsB,
      plannedContributions: plannedContributions ?? this.plannedContributions,
      checkIns: checkIns ?? this.checkIns,
      housingStatus: housingStatus ?? this.housingStatus,
      riskTolerance: riskTolerance ?? this.riskTolerance,
      realEstateProject: realEstateProject ?? this.realEstateProject,
      providers3a: providers3a ?? this.providers3a,
      arrivalAge: arrivalAge ?? this.arrivalAge,
      residencePermit: residencePermit ?? this.residencePermit,
      familyChange: familyChange ?? this.familyChange,
      targetRetirementAge: targetRetirementAge ?? this.targetRetirementAge,
      initialProjectionSnapshot:
          initialProjectionSnapshot ?? this.initialProjectionSnapshot,
      dataSources: dataSources ?? this.dataSources,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Copie le profil avec une nouvelle liste de contributions.
  CoachProfile copyWithContributions(
      List<PlannedMonthlyContribution> contributions) {
    return copyWith(
      plannedContributions: contributions,
      updatedAt: DateTime.now(),
    );
  }

  /// Copie le profil avec une nouvelle liste de check-ins.
  CoachProfile copyWithCheckIns(List<MonthlyCheckIn> newCheckIns) {
    return copyWith(
      checkIns: newCheckIns,
      updatedAt: DateTime.now(),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  BRIDGE → BUDGET
  // ════════════════════════════════════════════════════════════════

  /// Convertit le CoachProfile en BudgetInputs.
  ///
  /// Utile quand on a un CoachProfile mais pas les réponses wizard brutes.
  /// Le revenu net utilise NetIncomeBreakdown (canton + age).
  /// Les dettes mensuelles sont estimées sur 36 mois de remboursement.
  BudgetInputs toBudgetInputs() {
    final breakdown = NetIncomeBreakdown.compute(
      grossSalary: salaireBrutMensuel * 12,
      canton: canton,
      age: age,
    );
    final netMensuel = breakdown.monthlyNetPayslip;
    final monthlyDebt = dettes.totalDettes > 0 ? dettes.totalDettes / 36 : 0.0;
    // Estimer les mois de fonds d'urgence
    final monthlyExpenses = depenses.totalMensuel > 0
        ? depenses.totalMensuel
        : netMensuel * 0.6; // fallback: 60% du net
    final emergencyMonths =
        monthlyExpenses > 0 ? patrimoine.epargneLiquide / monthlyExpenses : 0.0;

    return BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: netMensuel,
      housingCost: depenses.loyer,
      debtPayments: monthlyDebt,
      emergencyFundMonths: emergencyMonths,
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  BRIDGE — CoachingService
  // ════════════════════════════════════════════════════════════════

  /// Convertit ce CoachProfile en CoachingProfile pour CoachingService.
  ///
  /// Remplace la construction inline dans le dashboard (qui avait des bugs:
  /// rachatMaximum au lieu de lacuneRachatRestante, champs manquants).
  CoachingProfile toCoachingProfile() {
    final EmploymentStatus empStatus;
    switch (employmentStatus) {
      case 'independant':
        empStatus = EmploymentStatus.independant;
        break;
      case 'chomage':
      case 'sans_emploi':
        empStatus = EmploymentStatus.sansEmploi;
        break;
      default:
        empStatus = EmploymentStatus.salarie;
    }

    final EtatCivil civilStatus;
    switch (etatCivil) {
      case CoachCivilStatus.marie:
        civilStatus = EtatCivil.marie;
        break;
      case CoachCivilStatus.divorce:
        civilStatus = EtatCivil.divorce;
        break;
      case CoachCivilStatus.veuf:
        civilStatus = EtatCivil.veuf;
        break;
      case CoachCivilStatus.concubinage:
        civilStatus = EtatCivil.concubinage;
        break;
      default:
        civilStatus = EtatCivil.celibataire;
    }

    return CoachingProfile(
      age: age,
      canton: canton,
      revenuAnnuel: revenuBrutAnnuel,
      has3a: prevoyance.nombre3a > 0,
      montant3a: total3aMensuel * 12,
      hasLpp: (prevoyance.avoirLppTotal ?? 0) > 0,
      avoirLpp: prevoyance.avoirLppTotal ?? 0,
      lacuneLpp: prevoyance.lacuneRachatRestante,
      tauxActivite: 100,
      chargesFixesMensuelles: depenses.totalMensuel,
      epargneDispo: patrimoine.epargneLiquide,
      detteTotale: dettes.totalDettes,
      hasBudget: plannedContributions.isNotEmpty,
      employmentStatus: empStatus,
      etatCivil: civilStatus,
      lastCheckInDepensesExceptionnelles:
          checkIns.isNotEmpty ? checkIns.last.depensesExceptionnelles : null,
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
      nationality: json['nationality'] as String?,
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
      goalsB:
          (json['goalsB'] as List?)?.map((g) => GoalB.fromJson(g)).toList() ??
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
      providers3a:
          (json['providers3a'] as List?)?.map((e) => e as String).toList() ??
              const [],
      arrivalAge: json['arrivalAge'] as int?,
      residencePermit: json['residencePermit'] as String?,
      familyChange: json['familyChange'] as String?,
      targetRetirementAge: json['targetRetirementAge'] as int?,
      initialProjectionSnapshot:
          json['initialProjectionSnapshot'] as Map<String, dynamic>?,
      dataSources: (json['dataSources'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              ProfileDataSource.values.firstWhere(
                (e) => e.name == v,
                orElse: () => ProfileDataSource.estimated,
              ),
            ),
          ) ??
          const {},
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'birthYear': birthYear,
        'canton': canton,
        'commune': commune,
        'nationality': nationality,
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
        'plannedContributions':
            plannedContributions.map((c) => c.toJson()).toList(),
        'checkIns': checkIns.map((c) => c.toJson()).toList(),
        'housingStatus': housingStatus,
        'riskTolerance': riskTolerance,
        'realEstateProject': realEstateProject,
        'providers3a': providers3a,
        'arrivalAge': arrivalAge,
        'residencePermit': residencePermit,
        'familyChange': familyChange,
        'targetRetirementAge': targetRetirementAge,
        'initialProjectionSnapshot': initialProjectionSnapshot,
        'dataSources': dataSources.map((k, v) => MapEntry(k, v.name)),
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

    // Convert to monthly net income based on pay frequency
    double monthlyNetIncome;
    if (payFrequency == 'yearly' || payFrequency == 'annuel') {
      monthlyNetIncome = netIncome / 12;
    } else {
      monthlyNetIncome = netIncome;
    }
    // Net → Brut estimation: Swiss social charges ≈ 13%
    // (AVS 5.3% + LPP ~5% + AC ~1.1% + AANP ~1% ≈ 12.5%, arrondi 13%)
    // Source: OFAS barème cotisations 2025. Ceci est une estimation;
    // le taux réel dépend du plan LPP et du canton.
    const double socialChargesRate = 0.13;
    final salaireBrutMensuel = monthlyNetIncome / (1 - socialChargesRate);

    // Employment status mapping
    final employmentRaw = answers['q_employment_status'] as String?;
    final employmentStatus = _parseEmploymentStatus(employmentRaw);

    // ── Depenses ────────────────────────────────────────────
    final housingCost =
        _parseDouble(answers['q_housing_cost_period_chf']) ?? 1500;
    double monthlyHousing;
    if (payFrequency == 'yearly' || payFrequency == 'annuel') {
      monthlyHousing = housingCost / 12;
    } else {
      monthlyHousing = housingCost;
    }

    // Use actual LAMal from onboarding if available, otherwise estimate
    final lamalFromOnboarding =
        _parseDouble(answers['q_lamal_premium_monthly_chf']);
    final assuranceMaladie =
        lamalFromOnboarding ?? _estimateAssuranceMaladie(canton);

    // Tax provision and other fixed costs from onboarding
    final taxProvision = _parseDouble(answers['q_tax_provision_monthly_chf']);
    final otherFixed = _parseDouble(answers['q_other_fixed_costs_monthly_chf']);
    final debtPayments = _parseDouble(answers['q_debt_payments_period_chf']);

    final depenses = DepensesProfile(
      loyer: monthlyHousing,
      assuranceMaladie: assuranceMaladie,
      autresDepensesFixes:
          (taxProvision ?? 0) + (otherFixed ?? 0) + (debtPayments ?? 0) > 0
              ? (taxProvision ?? 0) + (otherFixed ?? 0) + (debtPayments ?? 0)
              : null,
    );

    // ── Prevoyance ──────────────────────────────────────────
    final hasPensionFund = _parseBool(answers['q_has_pension_fund']);
    final lppBuybackAvailable =
        _parseDouble(answers['q_lpp_buyback_available']);
    final has3a = _parseBool(answers['q_has_3a']);
    final contribution3a =
        _parseDouble(answers['q_3a_annual_contribution']) ?? 0;
    final nombre3a =
        _parseInt(answers['q_3a_accounts_count']) ?? (has3a ? 1 : 0);
    final avsLacunesStatus = answers['q_avs_lacunes_status'] as String?;
    // Compute arrivalAge for expats who arrived late in Switzerland.
    // Used by _estimateLppAvoir() to start LPP bonification loop at
    // max(25, arrivalAge) instead of always 25.
    int? computedArrivalAge;
    final int avsGaps;
    switch (avsLacunesStatus) {
      case 'arrived_late':
        final arrivalYear = _parseInt(answers['q_avs_arrival_year']);
        if (arrivalYear != null) {
          computedArrivalAge = arrivalYear - birthYear;
          avsGaps = (arrivalYear - (birthYear + 21)).clamp(0, 44);
        } else {
          avsGaps = 5;
        }
      case 'lived_abroad':
        final yearsAbroad = _parseInt(answers['q_avs_years_abroad']);
        avsGaps = yearsAbroad ?? 3;
      case 'unknown':
        avsGaps = 2; // Estimation conservatrice
      default: // 'no_gaps' ou null
        avsGaps = 0;
    }
    final avsYears = _parseInt(answers['q_avs_contribution_years']);

    // ── Extraction-persisted fields (survive restart) ─────────
    final coachAvoirLppOblig = _parseDouble(answers['_coach_avoir_lpp_oblig']);
    final coachAvoirLppSuroblig =
        _parseDouble(answers['_coach_avoir_lpp_suroblig']);
    final coachTauxConversion = _parseDouble(answers['_coach_taux_conversion']);
    final coachTauxConvSuroblig =
        _parseDouble(answers['_coach_taux_conversion_suroblig']);
    final coachRachatMax = _parseDouble(answers['_coach_rachat_maximum']);
    final coachSalaireAssure = _parseDouble(answers['_coach_salaire_assure']);
    final coachAvsLacunes = _parseInt(answers['_coach_avs_lacunes']);
    final coachAvsRenteEstimee =
        _parseDouble(answers['_coach_avs_rente_estimee']);
    final coachAvsRamd = _parseDouble(answers['_coach_avs_ramd']);

    // Estimate LPP total based on age and salary (rough Swiss average).
    // Si une valeur reelle a ete saisie via annual refresh, on la prefere.
    // For independants without LPP (LPP art. 4): no bonifications estimated.
    // For expats: start bonifications at arrivalAge, not age 25.
    final coachAvoirLpp = _parseDouble(answers['_coach_avoir_lpp']);
    final double estimatedLpp;
    if (coachAvoirLpp != null) {
      estimatedLpp = coachAvoirLpp;
    } else if (!hasPensionFund) {
      // Independant sans LPP ou declaration explicite "pas de caisse"
      estimatedLpp = 0.0;
    } else {
      estimatedLpp = _estimateLppAvoir(age, salaireBrutMensuel,
          arrivalAge: computedArrivalAge);
    }

    // Estimate 3a total from contribution and age
    // Si une valeur reelle a ete saisie via annual refresh, on la prefere
    final reported3aTotal = _parseDouble(answers['q_3a_total']);
    final coachTotal3a = _parseDouble(answers['_coach_total_3a']);
    final estimated3aTotal = reported3aTotal ??
        coachTotal3a ??
        (has3a ? _estimate3aTotal(contribution3a, age) : 0.0);

    final prevoyance = PrevoyanceProfile(
      anneesContribuees: avsYears,
      lacunesAVS: coachAvsLacunes ?? (avsGaps > 0 ? avsGaps : null),
      renteAVSEstimeeMensuelle: coachAvsRenteEstimee,
      avoirLppTotal: estimatedLpp,
      avoirLppObligatoire: coachAvoirLppOblig,
      avoirLppSurobligatoire: coachAvoirLppSuroblig,
      tauxConversion: coachTauxConversion ?? 0.068,
      tauxConversionSuroblig: coachTauxConvSuroblig,
      rachatMaximum: coachRachatMax ?? lppBuybackAvailable,
      salaireAssure: coachSalaireAssure,
      ramd: coachAvsRamd,
      nombre3a: nombre3a,
      totalEpargne3a: estimated3aTotal,
    );

    // ── Patrimoine ──────────────────────────────────────────
    final hasInvestments = _parseBool(answers['q_has_investments']);
    final savingsMonthly = _parseDouble(answers['q_savings_monthly']) ?? 0;

    final estimatedMonthlyExpenses = monthlyHousing + assuranceMaladie;
    final emergencyFundRaw = answers['q_emergency_fund'];
    final cashTotal = _parseDouble(answers['q_cash_total']) ?? 0;
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
          epargneLiquide =
              _parseDouble(emergencyFundRaw) ?? (savingsMonthly * 3);
      }
    } else {
      epargneLiquide = _parseDouble(emergencyFundRaw) ?? (savingsMonthly * 3);
    }
    if (cashTotal > 0) {
      epargneLiquide = cashTotal;
    }

    // Estimation investissements: si l'utilisateur déclare avoir des
    // investissements sans préciser le montant, on estime ~2 mois de revenu
    // net comme ordre de grandeur conservateur.
    final investmentsTotal = _parseDouble(answers['q_investments_total']) ?? 0;
    final estimatedInvestments = investmentsTotal > 0
        ? investmentsTotal
        : (hasInvestments ? (monthlyNetIncome * 2).clamp(0.0, 50000.0) : 0.0);

    final patrimoine = PatrimoineProfile(
      epargneLiquide: epargneLiquide,
      investissements: estimatedInvestments,
      propertyMarketValue: _parseDouble(answers['q_property_market_value']),
      mortgageBalance: _parseDouble(answers['q_mortgage_balance']),
      mortgageRate: _parseDouble(answers['q_mortgage_rate']),
      monthlyRent: _parseDouble(answers['q_monthly_rent']),
    );

    // ── Dettes ──────────────────────────────────────────────
    final hasDebt = _parseBool(answers['q_has_consumer_debt']);
    final debtPaymentsMonthly =
        _parseDouble(answers['q_debt_payments_period_chf']) ?? 0;
    final dettes = (() {
      if (debtPaymentsMonthly > 0) {
        // Proxy conservateur: principal restant ≈ 24 mois de mensualités.
        return DetteProfile(creditConsommation: debtPaymentsMonthly * 24);
      }
      if (hasDebt) {
        // Fallback si uniquement booléen déclaré sans montant.
        return DetteProfile(creditConsommation: salaireBrutMensuel * 12 * 0.05);
      }
      return const DetteProfile();
    })();

    // ── Goal A ──────────────────────────────────────────────
    final mainGoalRaw = answers['q_main_goal'] as String?;
    final targetRetAge = _parseInt(answers['q_target_retirement_age']);
    final goalA =
        _parseGoalA(mainGoalRaw, birthYear, targetRetirementAge: targetRetAge);

    // ── Planned contributions ───────────────────────────────
    // Built from q_savings_allocation (multi-choice) + wizard data
    final contributions = <PlannedMonthlyContribution>[];
    final allocationRaw = answers['q_savings_allocation'];
    final allocations =
        allocationRaw is List ? allocationRaw.cast<String>() : <String>[];

    if (allocations.isNotEmpty && savingsMonthly > 0) {
      // Smart allocation: distribute savings across selected categories
      final monthly3a = contribution3a > 0 ? contribution3a / 12 : 0.0;
      double remaining = savingsMonthly;

      // 1. 3a — if selected and user has 3a contribution
      if (allocations.contains('3a')) {
        final amount3a =
            (monthly3a > 0 ? monthly3a : (remaining * 0.4).clamp(0.0, 604.83))
                .toDouble();
        if (amount3a > 0) {
          contributions.add(PlannedMonthlyContribution(
            id: '3a_user',
            label: '3a ${firstName ?? "Toi"}',
            amount: amount3a,
            category: '3a',
            isAutomatic: false,
          ));
          remaining -= amount3a;
        }
      }

      // 2. LPP buyback — if selected and has buyback available
      if (allocations.contains('lpp_buyback') && remaining > 0) {
        final lppAmount = (remaining * 0.3).clamp(0.0, remaining).toDouble();
        if (lppAmount >= 50) {
          contributions.add(PlannedMonthlyContribution(
            id: 'lpp_buyback_user',
            label: 'Rachat LPP ${firstName ?? "Toi"}',
            amount: lppAmount,
            category: 'lpp_buyback',
            isAutomatic: false,
          ));
          remaining -= lppAmount;
        }
      }

      // 3. Investissement — if selected
      if (allocations.contains('investissement') && remaining > 0) {
        final investAmount = (remaining * 0.5).clamp(0.0, remaining).toDouble();
        if (investAmount >= 50) {
          contributions.add(PlannedMonthlyContribution(
            id: 'invest_user',
            label: 'Investissements',
            amount: investAmount,
            category: 'investissement',
            isAutomatic: false,
          ));
          remaining -= investAmount;
        }
      }

      // 4. Épargne libre — if selected or remaining
      if (allocations.contains('epargne_libre') && remaining > 0) {
        contributions.add(PlannedMonthlyContribution(
          id: 'epargne_user',
          label: 'Épargne libre',
          amount: remaining,
          category: 'epargne_libre',
          isAutomatic: false,
        ));
      }
    } else {
      // Fallback: no allocation question answered — use legacy logic
      if (has3a && contribution3a > 0) {
        contributions.add(PlannedMonthlyContribution(
          id: '3a_user',
          label: '3a ${firstName ?? "Toi"}',
          amount: contribution3a / 12,
          category: '3a',
          isAutomatic: false,
        ));
      }
      if (savingsMonthly > 0 && savingsMonthly > (contribution3a / 12)) {
        final epargneLibre = savingsMonthly - (contribution3a / 12);
        if (epargneLibre > 50) {
          contributions.add(PlannedMonthlyContribution(
            id: 'epargne_user',
            label: 'Épargne libre',
            amount: epargneLibre,
            category: 'epargne_libre',
            isAutomatic: false,
          ));
        }
      }
    }

    // ── Conjoint (partner) data from onboarding ────────────
    ConjointProfile? conjoint;
    final partnerIncome = _parseDouble(answers['q_partner_net_income_chf']);
    if (partnerIncome != null && partnerIncome > 0) {
      // Net -> Brut estimation: same social charges rate as main user
      final partnerBrut = partnerIncome / (1 - socialChargesRate);
      final partnerBirthYear = _parseInt(answers['q_partner_birth_year']);
      final conjEmployment = answers['q_partner_employment_status'] as String?;

      // === Conjoint arrivalAge ===
      // First check for spouse-specific AVS arrival data, then fall back
      // to inferring from user's arrival (common for couples relocating together).
      int? conjointArrivalAge;
      final spouseAvsStatus = answers['q_spouse_avs_lacunes_status'] as String?;
      int spouseAvsGaps = 0;

      // Parse spouse AVS lacunes — same logic as user AVS (LAVS art. 29bis)
      switch (spouseAvsStatus) {
        case 'arrived_late':
          final spouseArrivalYear =
              _parseInt(answers['q_spouse_avs_arrival_year']);
          final spouseBirthYear = partnerBirthYear;
          if (spouseArrivalYear != null && spouseBirthYear != null) {
            conjointArrivalAge = spouseArrivalYear - spouseBirthYear;
            spouseAvsGaps =
                (spouseArrivalYear - (spouseBirthYear + 21)).clamp(0, 44);
          }
        case 'lived_abroad':
          spouseAvsGaps = _parseInt(answers['q_spouse_avs_years_abroad']) ?? 0;
        case 'unknown':
          spouseAvsGaps = 2; // Estimation conservatrice
        default: // 'no_gaps' or null
          spouseAvsGaps = 0;
      }

      // Fall back to user arrivalAge if no spouse-specific data
      if (conjointArrivalAge == null &&
          computedArrivalAge != null &&
          partnerBirthYear != null) {
        final arrivalYear = birthYear + computedArrivalAge;
        conjointArrivalAge = (arrivalYear - partnerBirthYear).clamp(0, 65);
      }

      // === Conjoint LPP estimation ===
      // Independant sans LPP or inactive: no bonifications (LPP art. 4)
      final conjAge = partnerBirthYear != null
          ? DateTime.now().year - partnerBirthYear
          : 35;
      final conjHasLpp =
          conjEmployment != 'independant' && conjEmployment != 'inactive';
      final conjLppEstimate = conjHasLpp
          ? _estimateLppAvoir(conjAge, partnerBrut,
              arrivalAge: conjointArrivalAge)
          : 0.0;

      // === Conjoint FATCA / nationality detection ===
      final conjNationality = answers['q_partner_nationality'] as String?;
      final conjIsFatca = conjNationality == 'US';

      // === Conjoint prevoyance profile ===
      // Propagate FATCA → canContribute3a on PrevoyanceProfile
      // (canonical source for all engines)
      final conjointPrevoyance = PrevoyanceProfile(
        lacunesAVS: spouseAvsGaps > 0 ? spouseAvsGaps : null,
        avoirLppTotal: conjLppEstimate,
        canContribute3a: !conjIsFatca,
      );

      conjoint = ConjointProfile(
        firstName: answers['q_partner_firstname'] as String?,
        birthYear: partnerBirthYear,
        salaireBrutMensuel: partnerBrut,
        employmentStatus: conjEmployment,
        arrivalAge: conjointArrivalAge,
        nationality: conjNationality,
        isFatcaResident: conjIsFatca,
        canContribute3a: !conjIsFatca,
        prevoyance: conjointPrevoyance,
      );
    }

    // ── Timestamps persistes par annual refresh ─────────────
    final savedUpdatedAt = answers['_coach_updated_at'] as String?;
    final savedCreatedAt = answers['_coach_created_at'] as String?;

    // ── Family change persiste par annual refresh ─────────
    final familyChange = answers['_coach_family_change'] as String?;

    // ── Fiscal dataSources (restored from persisted extraction) ──
    final restoredDataSources = <String, ProfileDataSource>{};
    if (answers['_coach_tax_source'] == 'document_scan') {
      if (answers['_coach_tax_revenu_imposable'] != null) {
        restoredDataSources['fiscal.revenuImposable'] =
            ProfileDataSource.certificate;
      }
      if (answers['_coach_tax_fortune_imposable'] != null) {
        restoredDataSources['fiscal.fortuneImposable'] =
            ProfileDataSource.certificate;
      }
      if (answers['_coach_tax_taux_marginal'] != null) {
        restoredDataSources['fiscal.tauxMarginal'] =
            ProfileDataSource.certificate;
      }
      if (answers['_coach_tax_impot_cantonal'] != null ||
          answers['_coach_tax_impot_federal'] != null) {
        restoredDataSources['fiscal.impots'] = ProfileDataSource.certificate;
      }
    }

    return CoachProfile(
      firstName: firstName,
      birthYear: birthYear,
      canton: canton,
      nationality: answers['q_nationality'] as String?,
      etatCivil: etatCivil,
      nombreEnfants: nombreEnfants,
      conjoint: conjoint,
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
      arrivalAge: computedArrivalAge,
      residencePermit: answers['q_residence_permit'] as String?,
      familyChange: familyChange,
      targetRetirementAge: targetRetAge,
      updatedAt:
          savedUpdatedAt != null ? DateTime.tryParse(savedUpdatedAt) : null,
      createdAt:
          savedCreatedAt != null ? DateTime.tryParse(savedCreatedAt) : null,
      dataSources: restoredDataSources,
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

  static GoalA _parseGoalA(String? raw, int birthYear,
      {int? targetRetirementAge}) {
    final effectiveAge = targetRetirementAge ?? 65;
    final retirementYear = birthYear + effectiveAge;
    final retirementDate = DateTime(retirementYear, 12, 31);
    final retirementLabel = 'Retraite a $effectiveAge ans';

    if (raw == null) {
      return GoalA(
        type: GoalAType.retraite,
        targetDate: retirementDate,
        label: retirementLabel,
      );
    }

    switch (raw.toLowerCase()) {
      case 'retirement':
        return GoalA(
          type: GoalAType.retraite,
          targetDate: retirementDate,
          label: retirementLabel,
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
          label: retirementLabel,
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
          label: retirementLabel,
        );
    }
  }

  /// Estime l'avoir LPP total selon l'age et le salaire brut mensuel.
  /// Approximation basee sur les taux de bonification LPP par age.
  /// [arrivalAge]: age d'arrivee en Suisse (si expat). La boucle de
  /// bonification demarre a max(25, arrivalAge) au lieu de toujours 25,
  /// pour ne pas surestimer le LPP des personnes arrivees tardivement.
  static double _estimateLppAvoir(int age, double salaireBrutMensuel,
      {int? arrivalAge}) {
    final salaireBrut = salaireBrutMensuel * 12;
    final salaireCoordonne = (salaireBrut - lppDeductionCoordination)
        .clamp(lppSalaireCoordMin.toDouble(), double.infinity);
    // LPP bonifications start at 25 (LPP art. 7), but only if the person
    // was contributing in Switzerland. Expats start at their arrival age.
    final startAge = arrivalAge != null ? arrivalAge.clamp(25, 65) : 25;
    double total = 0;
    for (int a = startAge; a < age && a < 65; a++) {
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
      'GE': 520,
      'BS': 490,
      'VD': 470,
      'TI': 460,
      'NE': 450,
      'ZH': 440,
      'BE': 410,
      'LU': 380,
      'AG': 400,
      'SG': 370,
      'VS': 380,
      'FR': 390,
      'SO': 400,
      'TG': 370,
      'GR': 350,
      'BL': 430,
      'ZG': 340,
      'SZ': 350,
      'NW': 340,
      'OW': 340,
      'UR': 330,
      'GL': 360,
      'SH': 400,
      'AR': 360,
      'AI': 340,
      'JU': 420,
    };
    return cantonalAverages[canton.toUpperCase()] ?? 400;
  }

  // ════════════════════════════════════════════════════════════════
  //  DEMO PROFILE (Julien + Lauren)
  // ════════════════════════════════════════════════════════════════

  /// Profil demo base sur le scenario Julien+Lauren (fondateur)
  @Deprecated(
      'Use CoachProfileProvider.profile instead. buildDemo() returns fake data.')
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
      targetRetirementAge: 63,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2040, 12, 31),
        label: 'Retraite a 63 ans',
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
