/// Profil financier etendu pour MINT Coach
///
/// Ce modele sert de base au ForecasterService et au FinancialFitnessScore.
/// Il etend le Profile existant avec : couple, prevoyance detaillee,
/// patrimoine, objectifs, et historique de check-ins mensuels.

/// Sprint C1 — MINT Coach Redesign
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable, listEquals, setEquals;
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/biography/freshness_decay_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_core/income_conversion_calculator.dart';
import 'package:mint_mobile/services/financial_core/swiss_civil_time.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/financial_core/wealth_financial_facts.dart';
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart'
    show VoicePreference;

const coachBackendUnknownPathsKey = '_coach_backend_unknown_paths_v1';
const Object _keepJurisdictionValue = Object();
const Object _keepSpecialistReferenceValue = Object();

DateTime? _parseSupportedAdultBirthDate(
  Object? raw, {
  required DateTime now,
}) {
  if (raw is! String) return null;
  final parsed = SwissCivilTime.parseCanonicalCivilDate(raw);
  if (parsed == null ||
      !SwissCivilTime.isSupportedAdultBirthDate(parsed, now: now)) {
    return null;
  }
  return parsed;
}

LppEvidenceSnapshot? _restoreIndependentManualPartnerFacts(
  LppEvidenceSnapshot? snapshot,
) {
  if (snapshot == null) return null;
  final facts = snapshot.independentFacts;
  return facts.isEmpty
      ? null
      : LppEvidenceSnapshot(
          snapshotId: snapshot.snapshotId,
          facts: Map.unmodifiable(facts),
        );
}

LppEvidenceSnapshot? _mergeCurrentManualPartnerFacts(
  LppEvidenceSnapshot? snapshot,
) {
  if (snapshot == null) return null;
  return LppEvidenceSnapshot(
    snapshotId: snapshot.snapshotId,
    facts: Map.unmodifiable(<LppEvidenceFactKey, LppEvidenceFact>{
      ...snapshot.independentFacts,
      ...snapshot.facts,
    }),
  );
}

// ════════════════════════════════════════════════════════════════
//  ENUMS
// ════════════════════════════════════════════════════════════════

/// Etat civil pour le coach.
///
/// A Swiss-recognized registered partnership stays distinct in the ledger even
/// where a specific legal domain applies the same rule as marriage.
enum CoachCivilStatus {
  celibataire,
  marie,
  registeredPartnership,
  divorce,
  veuf,
  concubinage,
}

/// Niveau de culture financiere de l'utilisateur.
///
/// Derive des questions de calibrage durant l'onboarding.
/// Score 0-1 → beginner, 2 → intermediate, 3 → advanced.
/// Valeur par defaut : beginner (backward-compatible).
enum FinancialLiteracyLevel { beginner, intermediate, advanced }

/// Source d'une donnee financiere dans le profil.
/// Permet de distinguer les valeurs saisies, estimees ou certifiees.
enum ProfileDataSource {
  estimated, // Defaut calcule par MINT (confiance 0.25)
  userInput, // Saisi manuellement (confiance 0.60)
  crossValidated, // Saisie + verification croisee (confiance 0.70)
  certificate, // Extrait d'un certificat scanne (confiance 0.95)
  openBanking, // Données bancaires live bLink/SFTI (confiance 1.00)
}

/// Closed country set supported by the first Swiss frontier contract.
@immutable
final class CountryCode {
  const CountryCode._(this.value);

  static const Set<String> supportedValues = {
    'CH',
    'FR',
    'DE',
    'IT',
    'AT',
    'LI',
  };

  final String value;

  static CountryCode? tryParse(Object? raw) {
    if (raw is! String || !supportedValues.contains(raw)) return null;
    return CountryCode._(raw);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CountryCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Closed set of all 26 Swiss canton codes.
@immutable
final class SwissCantonCode {
  const SwissCantonCode._(this.value);

  static const Set<String> supportedValues = {
    'AG',
    'AI',
    'AR',
    'BE',
    'BL',
    'BS',
    'FR',
    'GE',
    'GL',
    'GR',
    'JU',
    'LU',
    'NE',
    'NW',
    'OW',
    'SG',
    'SH',
    'SO',
    'SZ',
    'TG',
    'TI',
    'UR',
    'VD',
    'VS',
    'ZG',
    'ZH',
  };

  final String value;

  static SwissCantonCode? tryParse(Object? raw) {
    if (raw is! String || !supportedValues.contains(raw)) return null;
    return SwissCantonCode._(raw);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SwissCantonCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

enum FrontierJurisdictionState {
  missing,
  stale,
  known,
  specialistOnly;

  // A concrete getter (rather than only Dart's static enum extension) keeps
  // the evidence contract introspectable through dynamic compatibility gates.
  String get name => switch (this) {
        missing => 'missing',
        stale => 'stale',
        known => 'known',
        specialistOnly => 'specialistOnly',
      };
}

enum FrontierTaxInstrument {
  domestic,
  cdi1966Article17,
  accord1983Candidate;

  String get name => switch (this) {
        domestic => 'domestic',
        cdi1966Article17 => 'cdi1966Article17',
        accord1983Candidate => 'accord1983Candidate',
      };
}

/// Deterministic, calculation-free jurisdiction evidence for frontier routing.
@immutable
final class FrontierJurisdictionEvidence {
  FrontierJurisdictionEvidence({
    required this.state,
    required this.jurisdictionReady,
    required this.crossBorder,
    required this.candidateTaxInstrument,
    List<String> missingFields = const [],
    List<String> staleFields = const [],
  })  : missingFields = List.unmodifiable(missingFields),
        staleFields = List.unmodifiable(staleFields);

  final FrontierJurisdictionState state;
  final bool jurisdictionReady;
  final bool? crossBorder;
  final FrontierTaxInstrument? candidateTaxInstrument;
  final List<String> missingFields;
  final List<String> staleFields;
}

/// Type d'objectif principal (Goal A)
enum GoalAType { retraite, achatImmo, independance, debtFree, custom }

/// User-declared AVS gap state. The status never fabricates a year count.
enum AvsGapStatus { noGaps, arrivedLate, livedAbroad, unknown }

/// Canonical Data Ledger paths for official AVS pension amounts.
///
/// This contract identifies the fields required by complete retirement-income
/// projections; it does not certify that either amount is available.
abstract final class AvsOfficialPensionEvidence {
  static const selfFieldPath = 'prevoyance.renteAVSEstimeeMensuelle';
  static const spouseFieldPath = 'conjoint.prevoyance.renteAVSEstimeeMensuelle';
}

/// Certificate-backed AVS gap readiness for one profile household.
///
/// Declared statuses and unverified numeric values remain visible in the
/// profile, but never become certified years through this contract.
@immutable
final class AvsGapEvidence {
  static const selfFieldPath = 'prevoyance.lacunesAVS';
  static const spouseFieldPath = 'conjoint.prevoyance.lacunesAVS';

  final int? selfCertifiedYears;
  final int? spouseCertifiedYears;

  /// Whether a second owner is needed to form a household total.
  ///
  /// This reflects profile context only. It neither requires account linking
  /// nor treats the absence of a linked spouse object as financial evidence.
  final bool spouseRequired;

  /// Whether the confirmed civil status is marriage-equivalent for AVS.
  ///
  /// This is only the status axis; it does not prove concurrent pensions,
  /// separation status, scales, percentages, or payable cap readiness.
  final bool maritalCapApplicable;
  final AvsGapStatus? declaredStatus;
  final List<String> missingFieldPaths;

  AvsGapEvidence({
    required this.selfCertifiedYears,
    required this.spouseCertifiedYears,
    required this.spouseRequired,
    required this.maritalCapApplicable,
    required this.declaredStatus,
    required List<String> missingFieldPaths,
  }) : missingFieldPaths = List.unmodifiable(missingFieldPaths);

  bool get selfReady => selfCertifiedYears != null;

  /// Readiness for a total that combines every owner in the household context.
  bool get householdTotalReady =>
      selfReady && (!spouseRequired || spouseCertifiedYears != null);

  /// Backward-compatible alias for household-total readiness.
  ///
  /// Consumers must not interpret this as readiness for an individual result
  /// or as proof that the AVS marital cap applies.
  bool get householdReady => householdTotalReady;

  /// Whether the gap-evidence prerequisite is ready for a marital-cap flow.
  ///
  /// The cap itself still requires the legal and pension inputs deliberately
  /// kept outside this narrow evidence envelope.
  bool get maritalCapReady => maritalCapApplicable && householdTotalReady;
}

/// Devise des investissements
enum InvestmentCurrency { chf, usd, eur }

/// Archetype financier de l'utilisateur.
///
/// Determine les calculs LPP/AVS/3a et les alertes pertinentes.
/// Voir ADR-20260223-archetype-driven-retirement.md.
enum FinancialArchetype {
  /// Suisse natif, arrive avant 22 ans, bonifications LPP depuis 25 ans.
  swissNative,

  /// Expat EU/AELE, arrive apres 20 ans, totalisation periodes EU.
  expatEu,

  /// Expat hors EU, arrive apres 20 ans, pas de convention bilaterale.
  expatNonEu,

  /// US citizen/green card, FATCA, PFIC, double taxation.
  expatUs,

  /// Independant avec LPP (caisse facultative, solde reel).
  independentWithLpp,

  /// Independant sans LPP, 3a max = 36'288 CHF.
  independentNoLpp,

  /// Frontalier permis G, LPP suisse, impot source.
  crossBorder,

  /// Suisse de retour apres sejour a l'etranger, libre passage + lacunes.
  returningSwiss,
}

// ════════════════════════════════════════════════════════════════
//  SOUS-MODELES
// ════════════════════════════════════════════════════════════════

/// Profil du conjoint (si marie ou concubinage)
class ConjointProfile {
  final String? firstName;
  final int? birthYear;
  final DateTime? dateOfBirth;
  final String? gender; // 'M', 'F', or null (AVS21 reference age)
  final double? salaireBrutMensuel;
  final double nombreDeMois; // 12, 13, 13.5
  final double? bonusPourcentage;
  final String?
      employmentStatus; // 'salarie', 'independant', 'chomage', 'retraite'
  final String? nationality; // ISO 2-letter code, ex "CH", "US", "FR"
  final bool isFatcaResident; // US citizen/green card → FATCA restrictions
  final bool canContribute3a; // false si FATCA resident (certains providers)
  final PrevoyanceProfile? prevoyance;

  /// Canton of residence of the conjoint (ISO 2-letter, e.g. "VS", "ZH").
  /// Null if same as the primary user or unknown.
  final String? canton;

  /// Number of children for this conjoint (for allocations familiales, etc.).
  /// Null if unknown.
  final int? nombreEnfants;

  /// Patrimoine du conjoint (epargne, investissements).
  /// Null si non renseigne — Liquidite axis sera sous-evalue.
  final PatrimoineProfile? patrimoine;

  /// Age at which the conjoint arrived in Switzerland.
  /// If null, assumes contributions since age 20 (Swiss native).
  final int? arrivalAge;

  /// Target retirement age for the conjoint (58-70).
  /// Null means default (65 ans).
  final int? targetRetirementAge;

  /// Invitation / linking level for couple data sharing.
  /// - 'declared': user declared conjoint data manually (estimated confidence)
  /// - 'invited': invitation sent (5 questions, no account needed)
  /// - 'linked': both accounts linked (synced data)
  final String invitationLevel;

  const ConjointProfile({
    this.firstName,
    this.birthYear,
    this.dateOfBirth,
    this.gender,
    this.salaireBrutMensuel,
    this.nombreDeMois = 12.0,
    this.bonusPourcentage,
    this.employmentStatus,
    this.nationality,
    this.isFatcaResident = false,
    this.canContribute3a = true,
    this.prevoyance,
    this.canton,
    this.nombreEnfants,
    this.patrimoine,
    this.arrivalAge,
    this.targetRetirementAge,
    this.invitationLevel = 'declared',
  });

  /// Revenu brut annuel estime
  double get revenuBrutAnnuel {
    if (salaireBrutMensuel == null) return 0;
    final base = salaireBrutMensuel! * nombreDeMois;
    final bonus = (bonusPourcentage ?? 0) / 100 * base;
    return base + bonus;
  }

  /// Age actuel — prefers dateOfBirth (exact month/day), falls back to birthYear.
  /// Aligned with CoachProfile.age to avoid inconsistencies.
  int? get age {
    if (dateOfBirth != null) {
      final now = DateTime.now();
      int a = now.year - dateOfBirth!.year;
      if (now.month < dateOfBirth!.month ||
          (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
        a--;
      }
      return a.clamp(0, 150);
    }
    if (birthYear == null) return null;
    final currentYear = DateTime.now().year;
    if (birthYear! < 1900 || birthYear! > currentYear - 10) return null;
    return currentYear - birthYear!;
  }

  /// Age de retraite effectif (custom ou 65 par defaut).
  int get effectiveRetirementAge => targetRetirementAge ?? 65;

  /// Annees restantes avant retraite.
  int? get anneesAvantRetraite {
    final a = age;
    if (a == null) return null;
    return (effectiveRetirementAge - a).clamp(0, 99);
  }

  /// FATCA residents cannot contribute to 3a with most providers.
  /// Only a minority (e.g. Raiffeisen) accepts US persons (LSFin compliance).
  static PrevoyanceProfile? _enforceFatca3a(
    bool isFatca,
    PrevoyanceProfile? prev,
  ) {
    if (!isFatca || prev == null) return prev;
    final json = prev.toJson();
    json['canContribute3a'] = false;
    return PrevoyanceProfile.fromJson(json);
  }

  factory ConjointProfile.fromJson(Map<String, dynamic> json) {
    final isFatca = json['isFatcaResident'] ?? false;
    // FIX-089: FATCA doesn't block 3a if the person has Swiss employment income
    // (AVS-contributing salary in Switzerland). Only block if purely non-Swiss income.
    final hasSwissIncome =
        ((json['revenuBrutAnnuel'] as num?)?.toDouble() ?? 0) > 0;
    final topCanContribute =
        json['canContribute3a'] ?? (!isFatca || hasSwissIncome);
    PrevoyanceProfile? prev;
    if (json['prevoyance'] != null) {
      prev = PrevoyanceProfile.fromJson(json['prevoyance']);
    }
    prev = _enforceFatca3a(isFatca, prev);
    return ConjointProfile(
      firstName: json['firstName'] as String?,
      birthYear: json['birthYear'] as int?,
      dateOfBirth: _parseSupportedAdultBirthDate(
        json['dateOfBirth'],
        now: DateTime.now(),
      ),
      gender: json['gender'] as String?,
      salaireBrutMensuel: (json['salaireBrutMensuel'] as num?)?.toDouble(),
      nombreDeMois: (json['nombreDeMois'] as num?)?.toDouble() ?? 12.0,
      bonusPourcentage: (json['bonusPourcentage'] as num?)?.toDouble(),
      employmentStatus: json['employmentStatus'] as String?,
      nationality: json['nationality'] as String?,
      isFatcaResident: isFatca,
      canContribute3a: topCanContribute,
      prevoyance: prev,
      canton: json['canton'] as String?,
      nombreEnfants: json['nombreEnfants'] as int?,
      patrimoine: json['patrimoine'] != null
          ? PatrimoineProfile.fromJson(json['patrimoine'])
          : null,
      arrivalAge: json['arrivalAge'] as int?,
      targetRetirementAge: json['targetRetirementAge'] as int?,
      invitationLevel: json['invitationLevel'] as String? ?? 'declared',
    );
  }

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'birthYear': birthYear,
        'dateOfBirth': dateOfBirth?.toIso8601String().split('T').first,
        'gender': gender,
        'salaireBrutMensuel': salaireBrutMensuel,
        'nombreDeMois': nombreDeMois,
        'bonusPourcentage': bonusPourcentage,
        'employmentStatus': employmentStatus,
        'nationality': nationality,
        'isFatcaResident': isFatcaResident,
        'canContribute3a': canContribute3a,
        'prevoyance': prevoyance?.toJson(),
        'canton': canton,
        'nombreEnfants': nombreEnfants,
        'patrimoine': patrimoine?.toJson(),
        'arrivalAge': arrivalAge,
        'targetRetirementAge': targetRetirementAge,
        'invitationLevel': invitationLevel,
      };

  ConjointProfile copyWith({
    String? firstName,
    int? birthYear,
    DateTime? dateOfBirth,
    String? gender,
    double? salaireBrutMensuel,
    double? nombreDeMois,
    double? bonusPourcentage,
    String? employmentStatus,
    String? nationality,
    bool? isFatcaResident,
    bool? canContribute3a,
    PrevoyanceProfile? prevoyance,
    String? canton,
    int? nombreEnfants,
    PatrimoineProfile? patrimoine,
    int? arrivalAge,
    int? targetRetirementAge,
    String? invitationLevel,
  }) {
    final effectiveFatca = isFatcaResident ?? this.isFatcaResident;
    // FATCA hard block: US persons cannot contribute to 3a (LSFin compliance).
    final effectiveCan =
        effectiveFatca ? false : (canContribute3a ?? this.canContribute3a);
    final effectivePrev = _enforceFatca3a(
      effectiveFatca,
      prevoyance ?? this.prevoyance,
    );
    return ConjointProfile(
      firstName: firstName ?? this.firstName,
      birthYear: birthYear ?? this.birthYear,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      salaireBrutMensuel: salaireBrutMensuel ?? this.salaireBrutMensuel,
      nombreDeMois: nombreDeMois ?? this.nombreDeMois,
      bonusPourcentage: bonusPourcentage ?? this.bonusPourcentage,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      nationality: nationality ?? this.nationality,
      isFatcaResident: effectiveFatca,
      canContribute3a: effectiveCan,
      prevoyance: effectivePrev,
      canton: canton ?? this.canton,
      nombreEnfants: nombreEnfants ?? this.nombreEnfants,
      patrimoine: patrimoine ?? this.patrimoine,
      arrivalAge: arrivalAge ?? this.arrivalAge,
      targetRetirementAge: targetRetirementAge ?? this.targetRetirementAge,
      invitationLevel: invitationLevel ?? this.invitationLevel,
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
  final double? rachatEffectue; // déjà racheté (montant CHF cumulé)
  final bool? hasPensionFund; // user-declared LPP eligibility
  final bool? hasVoluntaryLpp; // prevoyance facultative for independants
  /// Historique daté des rachats LPP (ordre chronologique, plus récent en
  /// dernier). swiss-brain Q4 2026-04-18 : le blocage 3 ans (LPP art. 79b
  /// al. 3, confirmé par ATF 142 II 399 + ATF 148 II 189) part de la date
  /// du DERNIER rachat et s'applique à TOUT versement capital, pas
  /// seulement au montant racheté. Sans date précise on ne peut pas
  /// calculer le jour de déblocage ni alerter sur la reprise fiscale AFC.
  final List<DateTime> dateRachats;
  final double tauxConversion; // taux de la caisse (min legal 6.8%)
  final double? tauxConversionSuroblig; // taux surobligatoire de la caisse
  final double rendementCaisse; // rendement annuel estime de la caisse
  final bool rendementCaisseConnu;
  final double? salaireAssure; // salaire assure LPP (from certificate)
  final double?
      bonificationRate; // taux bonification total (from certificate, e.g. CPE 24%)

  // --- AVS (from extraction) ---
  final double? ramd; // revenu annuel moyen determinant (AVS)
  final int?
      bonificationsEducatives; // LAVS art. 29sexies (years of child-rearing credits)

  // --- LPP certificate projections (from extraction, not computed) ---
  final double? projectedRenteLpp; // Rente projetée à 65 (from certificate)
  final double? projectedCapital65; // Capital projeté à 65 (from certificate)
  final double? disabilityCoverage; // Prestation invalidité (from certificate)
  final double? lppDisabilityCapital; // Capital invalidité distinct (lump sum)
  final double? deathCoverage; // Prestation décès (from certificate)
  final Map<LppEvidenceFactKey, LppEvidenceFact> _lppEvidenceFacts;

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
    this.hasPensionFund,
    this.hasVoluntaryLpp,
    this.dateRachats = const [],
    this.tauxConversion = lppTauxConversionMinDecimal,
    this.tauxConversionSuroblig,
    double? rendementCaisse,
    bool? rendementCaisseConnu,
    this.salaireAssure,
    this.bonificationRate,
    this.ramd,
    this.bonificationsEducatives,
    this.projectedRenteLpp,
    this.projectedCapital65,
    this.disabilityCoverage,
    this.lppDisabilityCapital,
    this.deathCoverage,
    Map<LppEvidenceFactKey, LppEvidenceFact> lppEvidenceFacts = const {},
    this.nombre3a = 0,
    this.totalEpargne3a = 0,
    this.comptes3a = const [],
    this.canContribute3a = true,
    this.librePassage = const [],
  })  : rendementCaisse = rendementCaisse ?? 0.02,
        rendementCaisseConnu = rendementCaisseConnu ?? rendementCaisse != null,
        _lppEvidenceFacts = lppEvidenceFacts;

  LppEvidenceFact? lppEvidenceFact(LppEvidenceFactKey key) =>
      _lppEvidenceFacts[key];

  LppEvidenceStatus? lppEvidenceStatus(LppEvidenceFactKey key) =>
      _lppEvidenceFacts[key]?.status;

  /// Total avoir libre passage
  double get totalLibrePassage =>
      librePassage.fold(0.0, (sum, lp) => sum + lp.solde);

  /// Lacune de rachat LPP restante
  double get lacuneRachatRestante {
    return ((rachatMaximum ?? 0) - (rachatEffectue ?? 0))
        .clamp(0, double.infinity);
  }

  /// True when LPP data comes from a scanned certificate (not estimated).
  ///
  /// Checks for caisse-specific fields that only exist on real certificates:
  /// salaireAssure, avoirLppObligatoire, or tauxConversionSuroblig.
  /// When false, LPP projections use legal minimums and should display
  /// a precision warning (taux de remplacement may be significantly higher).
  bool get isLppFromCertificate =>
      salaireAssure != null ||
      avoirLppObligatoire != null ||
      tauxConversionSuroblig != null ||
      bonificationRate != null;

  /// True when LPP data exists but is estimated (not from certificate).
  /// This is the condition where MINT should show "estimation basée sur
  /// les minimums LPP" and prompt for certificate scan.
  bool get isLppEstimated =>
      avoirLppTotal != null && avoirLppTotal! > 0 && !isLppFromCertificate;

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
      hasPensionFund: json['hasPensionFund'] as bool?,
      hasVoluntaryLpp: json['hasVoluntaryLpp'] as bool?,
      dateRachats: (json['dateRachats'] as List?)
              ?.map((s) => DateTime.parse(s as String))
              .toList() ??
          const [],
      tauxConversion: (json['tauxConversion'] as num?)?.toDouble() ??
          lppTauxConversionMinDecimal,
      tauxConversionSuroblig:
          (json['tauxConversionSuroblig'] as num?)?.toDouble(),
      rendementCaisse: (json['rendementCaisse'] as num?)?.toDouble(),
      // Legacy JSON always serialized the old 2% sentinel. Absence of the
      // explicit marker therefore remains an assumption, not a known fact.
      rendementCaisseConnu: json['rendementCaisseConnu'] as bool? ?? false,
      salaireAssure: (json['salaireAssure'] as num?)?.toDouble(),
      bonificationRate: (json['bonificationRate'] as num?)?.toDouble(),
      ramd: (json['ramd'] as num?)?.toDouble(),
      bonificationsEducatives: json['bonificationsEducatives'] as int?,
      projectedRenteLpp: (json['projectedRenteLpp'] as num?)?.toDouble(),
      projectedCapital65: (json['projectedCapital65'] as num?)?.toDouble(),
      disabilityCoverage: (json['disabilityCoverage'] as num?)?.toDouble(),
      lppDisabilityCapital: (json['lppDisabilityCapital'] as num?)?.toDouble(),
      deathCoverage: (json['deathCoverage'] as num?)?.toDouble(),
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

  PrevoyanceProfile copyWith({
    int? anneesContribuees,
    int? lacunesAVS,
    double? renteAVSEstimeeMensuelle,
    String? nomCaisse,
    double? avoirLppTotal,
    double? avoirLppObligatoire,
    double? avoirLppSurobligatoire,
    double? rachatMaximum,
    double? rachatEffectue,
    bool? hasPensionFund,
    bool? hasVoluntaryLpp,
    List<DateTime>? dateRachats,
    double? tauxConversion,
    double? tauxConversionSuroblig,
    double? rendementCaisse,
    bool? rendementCaisseConnu,
    double? salaireAssure,
    double? bonificationRate,
    double? ramd,
    int? bonificationsEducatives,
    double? projectedRenteLpp,
    double? projectedCapital65,
    double? disabilityCoverage,
    double? lppDisabilityCapital,
    double? deathCoverage,
    Map<LppEvidenceFactKey, LppEvidenceFact>? lppEvidenceFacts,
    int? nombre3a,
    double? totalEpargne3a,
    List<Compte3a>? comptes3a,
    bool? canContribute3a,
    List<LibrePassageCompte>? librePassage,
  }) {
    return PrevoyanceProfile(
      anneesContribuees: anneesContribuees ?? this.anneesContribuees,
      lacunesAVS: lacunesAVS ?? this.lacunesAVS,
      renteAVSEstimeeMensuelle:
          renteAVSEstimeeMensuelle ?? this.renteAVSEstimeeMensuelle,
      nomCaisse: nomCaisse ?? this.nomCaisse,
      avoirLppTotal: avoirLppTotal ?? this.avoirLppTotal,
      avoirLppObligatoire: avoirLppObligatoire ?? this.avoirLppObligatoire,
      avoirLppSurobligatoire:
          avoirLppSurobligatoire ?? this.avoirLppSurobligatoire,
      rachatMaximum: rachatMaximum ?? this.rachatMaximum,
      rachatEffectue: rachatEffectue ?? this.rachatEffectue,
      hasPensionFund: hasPensionFund ?? this.hasPensionFund,
      hasVoluntaryLpp: hasVoluntaryLpp ?? this.hasVoluntaryLpp,
      dateRachats: dateRachats ?? this.dateRachats,
      tauxConversion: tauxConversion ?? this.tauxConversion,
      tauxConversionSuroblig:
          tauxConversionSuroblig ?? this.tauxConversionSuroblig,
      rendementCaisse: rendementCaisse ?? this.rendementCaisse,
      rendementCaisseConnu: rendementCaisseConnu ?? this.rendementCaisseConnu,
      salaireAssure: salaireAssure ?? this.salaireAssure,
      bonificationRate: bonificationRate ?? this.bonificationRate,
      ramd: ramd ?? this.ramd,
      bonificationsEducatives:
          bonificationsEducatives ?? this.bonificationsEducatives,
      projectedRenteLpp: projectedRenteLpp ?? this.projectedRenteLpp,
      projectedCapital65: projectedCapital65 ?? this.projectedCapital65,
      disabilityCoverage: disabilityCoverage ?? this.disabilityCoverage,
      lppDisabilityCapital: lppDisabilityCapital ?? this.lppDisabilityCapital,
      deathCoverage: deathCoverage ?? this.deathCoverage,
      lppEvidenceFacts: lppEvidenceFacts ?? _lppEvidenceFacts,
      nombre3a: nombre3a ?? this.nombre3a,
      totalEpargne3a: totalEpargne3a ?? this.totalEpargne3a,
      comptes3a: comptes3a ?? this.comptes3a,
      canContribute3a: canContribute3a ?? this.canContribute3a,
      librePassage: librePassage ?? this.librePassage,
    );
  }

  /// Replaces only the calculator-facing fields owned by typed LPP evidence.
  ///
  /// AVS, 3a, libre-passage and other runtime state stay on this instance;
  /// nullable LPP fields follow [authoritativeLpp] exactly so stale certificate
  /// values can be cleared rather than retained by the ordinary copyWith API.
  PrevoyanceProfile withLppEvidenceProjectionFrom(
    PrevoyanceProfile authoritativeLpp,
  ) {
    return PrevoyanceProfile(
      anneesContribuees: anneesContribuees,
      lacunesAVS: lacunesAVS,
      renteAVSEstimeeMensuelle: renteAVSEstimeeMensuelle,
      nomCaisse: nomCaisse,
      avoirLppTotal: authoritativeLpp.avoirLppTotal,
      avoirLppObligatoire: authoritativeLpp.avoirLppObligatoire,
      avoirLppSurobligatoire: authoritativeLpp.avoirLppSurobligatoire,
      rachatMaximum: authoritativeLpp.rachatMaximum,
      rachatEffectue: rachatEffectue,
      hasPensionFund: hasPensionFund,
      hasVoluntaryLpp: hasVoluntaryLpp,
      dateRachats: dateRachats,
      tauxConversion: authoritativeLpp.tauxConversion,
      tauxConversionSuroblig: authoritativeLpp.tauxConversionSuroblig,
      rendementCaisse: rendementCaisse,
      rendementCaisseConnu: rendementCaisseConnu,
      salaireAssure: authoritativeLpp.salaireAssure,
      bonificationRate: bonificationRate,
      ramd: ramd,
      bonificationsEducatives: bonificationsEducatives,
      projectedRenteLpp: authoritativeLpp.projectedRenteLpp,
      projectedCapital65: authoritativeLpp.projectedCapital65,
      disabilityCoverage: authoritativeLpp.disabilityCoverage,
      lppDisabilityCapital: authoritativeLpp.lppDisabilityCapital,
      deathCoverage: authoritativeLpp.deathCoverage,
      lppEvidenceFacts: authoritativeLpp._lppEvidenceFacts,
      nombre3a: nombre3a,
      totalEpargne3a: totalEpargne3a,
      comptes3a: comptes3a,
      canContribute3a: canContribute3a,
      librePassage: librePassage,
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
        'hasPensionFund': hasPensionFund,
        'hasVoluntaryLpp': hasVoluntaryLpp,
        'dateRachats': dateRachats.map((d) => d.toIso8601String()).toList(),
        'tauxConversion': tauxConversion,
        'tauxConversionSuroblig': tauxConversionSuroblig,
        'rendementCaisse': rendementCaisse,
        'rendementCaisseConnu': rendementCaisseConnu,
        'salaireAssure': salaireAssure,
        'bonificationRate': bonificationRate,
        'ramd': ramd,
        'bonificationsEducatives': bonificationsEducatives,
        'projectedRenteLpp': projectedRenteLpp,
        'projectedCapital65': projectedCapital65,
        'disabilityCoverage': disabilityCoverage,
        'lppDisabilityCapital': lppDisabilityCapital,
        'deathCoverage': deathCoverage,
        'nombre3a': nombre3a,
        'totalEpargne3a': totalEpargne3a,
        'comptes3a': comptes3a.map((c) => c.toJson()).toList(),
        'canContribute3a': canContribute3a,
        'librePassage': librePassage.map((lp) => lp.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrevoyanceProfile &&
          runtimeType == other.runtimeType &&
          anneesContribuees == other.anneesContribuees &&
          lacunesAVS == other.lacunesAVS &&
          renteAVSEstimeeMensuelle == other.renteAVSEstimeeMensuelle &&
          nomCaisse == other.nomCaisse &&
          avoirLppTotal == other.avoirLppTotal &&
          avoirLppObligatoire == other.avoirLppObligatoire &&
          avoirLppSurobligatoire == other.avoirLppSurobligatoire &&
          rachatMaximum == other.rachatMaximum &&
          rachatEffectue == other.rachatEffectue &&
          hasPensionFund == other.hasPensionFund &&
          hasVoluntaryLpp == other.hasVoluntaryLpp &&
          listEquals(dateRachats, other.dateRachats) &&
          tauxConversion == other.tauxConversion &&
          tauxConversionSuroblig == other.tauxConversionSuroblig &&
          rendementCaisse == other.rendementCaisse &&
          rendementCaisseConnu == other.rendementCaisseConnu &&
          salaireAssure == other.salaireAssure &&
          bonificationRate == other.bonificationRate &&
          ramd == other.ramd &&
          nombre3a == other.nombre3a &&
          totalEpargne3a == other.totalEpargne3a &&
          canContribute3a == other.canContribute3a &&
          bonificationsEducatives == other.bonificationsEducatives &&
          projectedRenteLpp == other.projectedRenteLpp &&
          projectedCapital65 == other.projectedCapital65 &&
          disabilityCoverage == other.disabilityCoverage &&
          lppDisabilityCapital == other.lppDisabilityCapital &&
          deathCoverage == other.deathCoverage &&
          listEquals(comptes3a, other.comptes3a) &&
          listEquals(librePassage, other.librePassage);

  @override
  int get hashCode => Object.hashAll([
        anneesContribuees,
        lacunesAVS,
        renteAVSEstimeeMensuelle,
        nomCaisse,
        avoirLppTotal,
        avoirLppObligatoire,
        avoirLppSurobligatoire,
        rachatMaximum,
        rachatEffectue,
        hasPensionFund,
        hasVoluntaryLpp,
        Object.hashAll(dateRachats),
        tauxConversion,
        tauxConversionSuroblig,
        rendementCaisse,
        rendementCaisseConnu,
        salaireAssure,
        bonificationRate,
        ramd,
        nombre3a,
        totalEpargne3a,
        canContribute3a,
        bonificationsEducatives,
        projectedRenteLpp,
        projectedCapital65,
        disabilityCoverage,
        lppDisabilityCapital,
        deathCoverage,
        comptes3a.length,
        librePassage.length,
      ]);
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
      provider: (json['provider'] as String?) ?? 'Inconnu',
      solde: (json['solde'] as num?)?.toDouble() ?? 0.0,
      rendementEstime: (json['rendementEstime'] as num?)?.toDouble() ?? 0.04,
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'solde': solde,
        'rendementEstime': rendementEstime,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Compte3a &&
          provider == other.provider &&
          solde == other.solde &&
          rendementEstime == other.rendementEstime;

  @override
  int get hashCode => Object.hash(provider, solde, rendementEstime);
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
      solde: (json['solde'] as num?)?.toDouble() ?? 0.0,
      dateOuverture: json['dateOuverture'] != null
          ? (DateTime.tryParse(json['dateOuverture'] ?? '') ?? DateTime.now())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'institution': institution,
        'solde': solde,
        'dateOuverture': dateOuverture?.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibrePassageCompte &&
          institution == other.institution &&
          solde == other.solde &&
          dateOuverture == other.dateOuverture;

  @override
  int get hashCode => Object.hash(institution, solde, dateOuverture);
}

/// Patrimoine (epargne + investissements + immobilier)
class PatrimoineProfile {
  final double epargneLiquide;
  final double investissements;
  final double? immobilier;

  /// Broad user-supplied wealth estimate. Treat as an aggregate fallback, never
  /// as an additive asset component. Because users may answer all-in, consumers
  /// that add explicit LPP/3a values must compare totals with max(), not sum.
  final double? wealthEstimate;
  final InvestmentCurrency deviseInvestissements;
  final String? plateformeInvestissement; // "Interactive Brokers", etc.

  // P2: Housing model fields
  final double? propertyMarketValue;
  final double? mortgageBalance;
  final double? mortgageRate;
  final double? monthlyRent;

  // S45: Immobilier enrichi
  final String? propertyDescription; // "Appt 4.5p, Sion (VS)"

  // CAL-03: Calculator write-back fields (from /hypotheque calculator)
  final double?
      mortgageCapacity; // Computed max mortgage capacity from calculator
  final double?
      estimatedMonthlyPayment; // Computed monthly payment from calculator

  const PatrimoineProfile({
    this.epargneLiquide = 0,
    this.investissements = 0,
    this.immobilier,
    this.wealthEstimate,
    this.deviseInvestissements = InvestmentCurrency.chf,
    this.plateformeInvestissement,
    this.propertyMarketValue,
    this.mortgageBalance,
    this.mortgageRate,
    this.monthlyRent,
    this.propertyDescription,
    this.mortgageCapacity,
    this.estimatedMonthlyPayment,
  });

  /// Valeur immobilière effective (propertyMarketValue si renseigné, sinon legacy immobilier).
  double get immobilierEffectif => propertyMarketValue ?? immobilier ?? 0;

  /// Valeur nette immobilière = valeur marché - hypothèque restante.
  double get immobilierNet => WealthFinancialFacts.propertyNetValue(
        propertyValue: immobilierEffectif,
        mortgageBalance: mortgageBalance ?? 0,
      );

  /// Loan-to-Value ratio (FINMA/ASB). 0 if no property.
  double get loanToValue =>
      immobilierEffectif > 0 ? (mortgageBalance ?? 0) / immobilierEffectif : 0;

  double get detailedAssetTotal =>
      epargneLiquide + investissements + immobilierEffectif;

  /// Gross-asset reconciliation for patrimoine views. Domain flows that need a
  /// net estate mass must build their own reconciliation with debt context.
  WealthReconciliation get wealthReconciliation =>
      WealthFinancialFacts.reconcileAggregate(
        cash: epargneLiquide,
        investments: investissements,
        propertyValue: immobilierEffectif,
        wealthEstimate: wealthEstimate,
      );

  /// Patrimoine brut total. Use the broad estimate as an aggregate total, not
  /// as an asset component, so it never double-counts detailed values.
  double get totalPatrimoine => wealthReconciliation.resolvedTotal;

  /// Patrimoine net (brut - dettes). Dettes passed via parameter since
  /// PatrimoineProfile doesn't hold a reference to DetteProfile.
  double patrimoineNet(double totalDettes) => WealthFinancialFacts.netWealth(
        totalAssets: totalPatrimoine,
        totalDebts: totalDettes,
      );

  factory PatrimoineProfile.fromJson(Map<String, dynamic> json) {
    return PatrimoineProfile(
      epargneLiquide: (json['epargneLiquide'] as num?)?.toDouble() ?? 0,
      investissements: (json['investissements'] as num?)?.toDouble() ?? 0,
      immobilier: (json['immobilier'] as num?)?.toDouble(),
      wealthEstimate: (json['wealthEstimate'] as num?)?.toDouble(),
      deviseInvestissements: InvestmentCurrency.values.firstWhere(
        (e) => e.name == json['deviseInvestissements'],
        orElse: () => InvestmentCurrency.chf,
      ),
      plateformeInvestissement: json['plateformeInvestissement'] as String?,
      propertyMarketValue: (json['propertyMarketValue'] as num?)?.toDouble(),
      mortgageBalance: (json['mortgageBalance'] as num?)?.toDouble(),
      mortgageRate: (json['mortgageRate'] as num?)?.toDouble(),
      monthlyRent: (json['monthlyRent'] as num?)?.toDouble(),
      propertyDescription: json['propertyDescription'] as String?,
      mortgageCapacity: (json['mortgageCapacity'] as num?)?.toDouble(),
      estimatedMonthlyPayment:
          (json['estimatedMonthlyPayment'] as num?)?.toDouble(),
    );
  }

  PatrimoineProfile copyWith({
    double? epargneLiquide,
    double? investissements,
    double? immobilier,
    double? wealthEstimate,
    InvestmentCurrency? deviseInvestissements,
    String? plateformeInvestissement,
    double? propertyMarketValue,
    double? mortgageBalance,
    double? mortgageRate,
    double? monthlyRent,
    String? propertyDescription,
    double? mortgageCapacity,
    double? estimatedMonthlyPayment,
  }) {
    return PatrimoineProfile(
      epargneLiquide: epargneLiquide ?? this.epargneLiquide,
      investissements: investissements ?? this.investissements,
      immobilier: immobilier ?? this.immobilier,
      wealthEstimate: wealthEstimate ?? this.wealthEstimate,
      deviseInvestissements:
          deviseInvestissements ?? this.deviseInvestissements,
      plateformeInvestissement:
          plateformeInvestissement ?? this.plateformeInvestissement,
      propertyMarketValue: propertyMarketValue ?? this.propertyMarketValue,
      mortgageBalance: mortgageBalance ?? this.mortgageBalance,
      mortgageRate: mortgageRate ?? this.mortgageRate,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      propertyDescription: propertyDescription ?? this.propertyDescription,
      mortgageCapacity: mortgageCapacity ?? this.mortgageCapacity,
      estimatedMonthlyPayment:
          estimatedMonthlyPayment ?? this.estimatedMonthlyPayment,
    );
  }

  Map<String, dynamic> toJson() => {
        'epargneLiquide': epargneLiquide,
        'investissements': investissements,
        'immobilier': immobilier,
        'wealthEstimate': wealthEstimate,
        'deviseInvestissements': deviseInvestissements.name,
        'plateformeInvestissement': plateformeInvestissement,
        'propertyMarketValue': propertyMarketValue,
        'mortgageBalance': mortgageBalance,
        'mortgageRate': mortgageRate,
        'monthlyRent': monthlyRent,
        'propertyDescription': propertyDescription,
        'mortgageCapacity': mortgageCapacity,
        'estimatedMonthlyPayment': estimatedMonthlyPayment,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatrimoineProfile &&
          runtimeType == other.runtimeType &&
          epargneLiquide == other.epargneLiquide &&
          investissements == other.investissements &&
          immobilier == other.immobilier &&
          wealthEstimate == other.wealthEstimate &&
          deviseInvestissements == other.deviseInvestissements &&
          plateformeInvestissement == other.plateformeInvestissement &&
          propertyMarketValue == other.propertyMarketValue &&
          mortgageBalance == other.mortgageBalance &&
          mortgageRate == other.mortgageRate &&
          monthlyRent == other.monthlyRent &&
          propertyDescription == other.propertyDescription &&
          mortgageCapacity == other.mortgageCapacity &&
          estimatedMonthlyPayment == other.estimatedMonthlyPayment;

  @override
  int get hashCode => Object.hashAll([
        epargneLiquide,
        investissements,
        immobilier,
        wealthEstimate,
        deviseInvestissements,
        plateformeInvestissement,
        propertyMarketValue,
        mortgageBalance,
        mortgageRate,
        monthlyRent,
        propertyDescription,
        mortgageCapacity,
        estimatedMonthlyPayment,
      ]);
}

/// Dettes — enriched with rates, terms, monthly payments (S45).
///
/// Two categories:
/// - Structural debt (hypothèque) — adossée à un actif, intérêts déductibles
/// - Consumer debt (crédit conso, leasing) — priorité remboursement
class DetteProfile {
  final double? creditConsommation;
  final double? leasing;
  final double? hypotheque;
  final double? autresDettes;

  // S45: Enrichment fields (optional, progressively filled)
  final double? tauxHypotheque; // Taux d'intérêt hypothécaire (%)
  final double? tauxCreditConso; // Taux d'intérêt crédit conso (%)
  final double? tauxLeasing; // Taux leasing (%)
  final double? mensualiteHypotheque; // Charge mensuelle hypothèque
  final double? mensualiteCreditConso; // Mensualité crédit conso
  final double? mensualiteLeasing; // Mensualité leasing
  final DateTime? echeanceHypotheque; // Échéance renouvellement hypo
  final DateTime? echeanceCreditConso; // Fin de remboursement
  final DateTime? echeanceLeasing; // Fin du leasing
  final int? rangHypotheque; // 1er ou 2ème rang
  final bool amortissementIndirect; // Via 3a (true) ou direct (false)

  const DetteProfile({
    this.creditConsommation,
    this.leasing,
    this.hypotheque,
    this.autresDettes,
    this.tauxHypotheque,
    this.tauxCreditConso,
    this.tauxLeasing,
    this.mensualiteHypotheque,
    this.mensualiteCreditConso,
    this.mensualiteLeasing,
    this.echeanceHypotheque,
    this.echeanceCreditConso,
    this.echeanceLeasing,
    this.rangHypotheque,
    this.amortissementIndirect = false,
  });

  double get totalDettes =>
      (creditConsommation ?? 0) +
      (leasing ?? 0) +
      (hypotheque ?? 0) +
      (autresDettes ?? 0);

  bool get hasDette => totalDettes > 0;

  /// Total charge mensuelle de toutes les dettes.
  double get totalMensualite =>
      (mensualiteHypotheque ?? 0) +
      (mensualiteCreditConso ?? 0) +
      (mensualiteLeasing ?? 0);

  /// Dettes "toxiques" (consommation) — priorité de remboursement.
  double get detteConsommation => WealthFinancialFacts.consumerDebt(
        consumerCredit: creditConsommation ?? 0,
        leasing: leasing ?? 0,
      );

  /// Dettes structurelles (hypothèque) — adossées à un actif.
  double get detteStructurelle => hypotheque ?? 0;

  /// Taux le plus élevé parmi les dettes conso — cible de remboursement.
  double? get tauxMaxConsommation {
    final taux = <double>[];
    if (tauxCreditConso != null && (creditConsommation ?? 0) > 0) {
      taux.add(tauxCreditConso!);
    }
    if (tauxLeasing != null && (leasing ?? 0) > 0) taux.add(tauxLeasing!);
    if (taux.isEmpty) return null;
    return taux.reduce((a, b) => a > b ? a : b);
  }

  /// Intérêts hypothécaires annuels (déductibles fiscalement, LIFD art. 33).
  double get interetsHypothecairesAnnuels =>
      (hypotheque ?? 0) * (tauxHypotheque ?? 0) / 100;

  factory DetteProfile.fromJson(Map<String, dynamic> json) {
    return DetteProfile(
      creditConsommation: (json['creditConsommation'] as num?)?.toDouble(),
      leasing: (json['leasing'] as num?)?.toDouble(),
      hypotheque: (json['hypotheque'] as num?)?.toDouble(),
      autresDettes: (json['autresDettes'] as num?)?.toDouble(),
      tauxHypotheque: (json['tauxHypotheque'] as num?)?.toDouble(),
      tauxCreditConso: (json['tauxCreditConso'] as num?)?.toDouble(),
      tauxLeasing: (json['tauxLeasing'] as num?)?.toDouble(),
      mensualiteHypotheque: (json['mensualiteHypotheque'] as num?)?.toDouble(),
      mensualiteCreditConso:
          (json['mensualiteCreditConso'] as num?)?.toDouble(),
      mensualiteLeasing: (json['mensualiteLeasing'] as num?)?.toDouble(),
      echeanceHypotheque: json['echeanceHypotheque'] != null
          ? DateTime.tryParse(json['echeanceHypotheque'] as String)
          : null,
      echeanceCreditConso: json['echeanceCreditConso'] != null
          ? DateTime.tryParse(json['echeanceCreditConso'] as String)
          : null,
      echeanceLeasing: json['echeanceLeasing'] != null
          ? DateTime.tryParse(json['echeanceLeasing'] as String)
          : null,
      rangHypotheque: json['rangHypotheque'] as int?,
      amortissementIndirect: json['amortissementIndirect'] as bool? ?? false,
    );
  }

  DetteProfile copyWith({
    double? creditConsommation,
    double? leasing,
    double? hypotheque,
    double? autresDettes,
    double? tauxHypotheque,
    double? tauxCreditConso,
    double? tauxLeasing,
    double? mensualiteHypotheque,
    double? mensualiteCreditConso,
    double? mensualiteLeasing,
    DateTime? echeanceHypotheque,
    DateTime? echeanceCreditConso,
    DateTime? echeanceLeasing,
    int? rangHypotheque,
    bool? amortissementIndirect,
  }) {
    return DetteProfile(
      creditConsommation: creditConsommation ?? this.creditConsommation,
      leasing: leasing ?? this.leasing,
      hypotheque: hypotheque ?? this.hypotheque,
      autresDettes: autresDettes ?? this.autresDettes,
      tauxHypotheque: tauxHypotheque ?? this.tauxHypotheque,
      tauxCreditConso: tauxCreditConso ?? this.tauxCreditConso,
      tauxLeasing: tauxLeasing ?? this.tauxLeasing,
      mensualiteHypotheque: mensualiteHypotheque ?? this.mensualiteHypotheque,
      mensualiteCreditConso:
          mensualiteCreditConso ?? this.mensualiteCreditConso,
      mensualiteLeasing: mensualiteLeasing ?? this.mensualiteLeasing,
      echeanceHypotheque: echeanceHypotheque ?? this.echeanceHypotheque,
      echeanceCreditConso: echeanceCreditConso ?? this.echeanceCreditConso,
      echeanceLeasing: echeanceLeasing ?? this.echeanceLeasing,
      rangHypotheque: rangHypotheque ?? this.rangHypotheque,
      amortissementIndirect:
          amortissementIndirect ?? this.amortissementIndirect,
    );
  }

  Map<String, dynamic> toJson() => {
        'creditConsommation': creditConsommation,
        'leasing': leasing,
        'hypotheque': hypotheque,
        'autresDettes': autresDettes,
        'tauxHypotheque': tauxHypotheque,
        'tauxCreditConso': tauxCreditConso,
        'tauxLeasing': tauxLeasing,
        'mensualiteHypotheque': mensualiteHypotheque,
        'mensualiteCreditConso': mensualiteCreditConso,
        'mensualiteLeasing': mensualiteLeasing,
        'echeanceHypotheque': echeanceHypotheque?.toIso8601String(),
        'echeanceCreditConso': echeanceCreditConso?.toIso8601String(),
        'echeanceLeasing': echeanceLeasing?.toIso8601String(),
        'rangHypotheque': rangHypotheque,
        'amortissementIndirect': amortissementIndirect,
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
      targetDate: DateTime.tryParse(json['targetDate'] ?? '') ?? DateTime.now(),
      targetAmount: (json['targetAmount'] as num?)?.toDouble(),
      label: (json['label'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'targetDate': targetDate.toIso8601String(),
        'targetAmount': targetAmount,
        'label': label,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalA &&
          type == other.type &&
          targetDate == other.targetDate &&
          targetAmount == other.targetAmount &&
          label == other.label;

  @override
  int get hashCode => Object.hash(type, targetDate, targetAmount, label);
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
      label: (json['label'] as String?) ?? '',
      targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0.0,
      targetDate: json['targetDate'] != null
          ? (DateTime.tryParse(json['targetDate'] ?? '') ?? DateTime.now())
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalB &&
          label == other.label &&
          targetAmount == other.targetAmount &&
          targetDate == other.targetDate &&
          priority == other.priority;

  @override
  int get hashCode => Object.hash(label, targetAmount, targetDate, priority);
}

/// Check-in mensuel (une "activite" au sens TrainerRoad)
class MonthlyCheckIn {
  final DateTime month; // premier jour du mois
  final Map<String, double> versements; // '3a_julien': 604.83, etc.
  final double? depensesExceptionnelles;
  final double? revenusExceptionnels;
  final String? note;
  final DateTime completedAt;

  /// FRI score snapshot at check-in time (0-100). Null for legacy check-ins.
  final double? friScore;

  /// Financial Fitness Score at check-in time (0-100). Null for legacy check-ins.
  final int? fitnessScore;

  const MonthlyCheckIn({
    required this.month,
    required this.versements,
    this.depensesExceptionnelles,
    this.revenusExceptionnels,
    this.note,
    required this.completedAt,
    this.friScore,
    this.fitnessScore,
  });

  /// Total des versements du mois
  double get totalVersements =>
      versements.values.fold(0.0, (sum, v) => sum + v);

  factory MonthlyCheckIn.fromJson(Map<String, dynamic> json) {
    return MonthlyCheckIn(
      month: DateTime.tryParse(json['month'] ?? '') ?? DateTime.now(),
      versements: Map<String, double>.from(
        (json['versements'] as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ),
      ),
      depensesExceptionnelles:
          (json['depensesExceptionnelles'] as num?)?.toDouble(),
      revenusExceptionnels: (json['revenusExceptionnels'] as num?)?.toDouble(),
      note: json['note'] as String?,
      completedAt:
          DateTime.tryParse(json['completedAt'] ?? '') ?? DateTime.now(),
      friScore: (json['friScore'] as num?)?.toDouble(),
      fitnessScore: json['fitnessScore'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'month': month.toIso8601String(),
        'versements': versements,
        'depensesExceptionnelles': depensesExceptionnelles,
        'revenusExceptionnels': revenusExceptionnels,
        'note': note,
        'completedAt': completedAt.toIso8601String(),
        'friScore': friScore,
        'fitnessScore': fitnessScore,
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
      id: (json['id'] as String?) ??
          'unknown_${DateTime.now().millisecondsSinceEpoch}',
      label: (json['label'] as String?) ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: (json['category'] as String?) ?? 'other',
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedMonthlyContribution &&
          id == other.id &&
          amount == other.amount &&
          category == other.category;

  @override
  int get hashCode => Object.hash(id, amount, category);
}

// ════════════════════════════════════════════════════════════════
//  MODELE PRINCIPAL : CoachProfile
// ════════════════════════════════════════════════════════════════

enum TaxDocumentKind {
  taxpayerReturn,
  provisionalBill,
  assessmentNotice,
  finalTaxBill,
  unknown,
}

enum TaxAssessmentStatus {
  selfDeclared,
  provisional,
  assessedAppealable,
  contested,
  inForce,
  unknown,
}

enum TaxSubjectScope { individual, jointlyAssessedCouple, unknown }

enum TaxAuthorityScope {
  cantonalOnly,
  communalOnly,
  cantonalCommunalCombined,
  federalDirect,
  unknown,
}

enum TaxBaseScope {
  incomeOnly,
  wealthOnly,
  incomeAndWealth,
  totalInvoice,
  unknown,
}

enum TaxSnapshotField {
  cantonalCommunalTaxableIncomeChf,
  federalTaxableIncomeChf,
  cantonalCommunalTaxableWealthChf,
  cantonalCommunalAssessedTax,
  federalDirectAssessedTax,
  explicitMarginalIncomeTaxRate,
  explicitAverageIncomeTaxRate,
}

const _taxUnset = Object();

T _requiredEnum<T extends Enum>(List<T> values, dynamic raw, String field) {
  if (raw is! String) throw FormatException('Missing $field');
  for (final value in values) {
    if (value.name == raw) return value;
  }
  throw FormatException('Invalid $field');
}

@immutable
final class AssessedTaxAmount {
  final double amountChf;
  final TaxAuthorityScope authorityScope;
  final TaxBaseScope baseScope;

  AssessedTaxAmount({
    required this.amountChf,
    required this.authorityScope,
    required this.baseScope,
  }) {
    if (!amountChf.isFinite || amountChf < 0) {
      throw ArgumentError.value(
        amountChf,
        'amountChf',
        'finite non-negative amount required',
      );
    }
  }

  factory AssessedTaxAmount.fromJson(Map<String, dynamic> json) {
    final amount = (json['amountChf'] as num?)?.toDouble();
    if (amount == null || !amount.isFinite || amount < 0) {
      throw const FormatException('Invalid assessed tax amount');
    }
    return AssessedTaxAmount(
      amountChf: amount,
      authorityScope: _requiredEnum(
        TaxAuthorityScope.values,
        json['authorityScope'],
        'authorityScope',
      ),
      baseScope: _requiredEnum(
        TaxBaseScope.values,
        json['baseScope'],
        'baseScope',
      ),
    );
  }

  AssessedTaxAmount copyWith({
    double? amountChf,
    TaxAuthorityScope? authorityScope,
    TaxBaseScope? baseScope,
  }) {
    return AssessedTaxAmount(
      amountChf: amountChf ?? this.amountChf,
      authorityScope: authorityScope ?? this.authorityScope,
      baseScope: baseScope ?? this.baseScope,
    );
  }

  Map<String, dynamic> toJson() => {
        'amountChf': amountChf,
        'authorityScope': authorityScope.name,
        'baseScope': baseScope.name,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssessedTaxAmount &&
          amountChf == other.amountChf &&
          authorityScope == other.authorityScope &&
          baseScope == other.baseScope;

  @override
  int get hashCode => Object.hash(amountChf, authorityScope, baseScope);
}

@immutable
final class TaxSnapshot {
  static final RegExp uuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static const Set<String> provenanceLeafPaths = {
    'taxYear',
    'basedOnTaxYear',
    'sourceDate',
    'documentKind',
    'assessmentStatus',
    'inForceAttested',
    'subjectScope',
    'cantonCode',
    'municipalityId',
    'municipalityLabel',
    'cantonalCommunalTaxableIncomeChf',
    'federalTaxableIncomeChf',
    'cantonalCommunalTaxableWealthChf',
    'cantonalCommunalAssessedTax.amountChf',
    'cantonalCommunalAssessedTax.authorityScope',
    'cantonalCommunalAssessedTax.baseScope',
    'federalDirectAssessedTax.amountChf',
    'federalDirectAssessedTax.authorityScope',
    'federalDirectAssessedTax.baseScope',
    'explicitMarginalIncomeTaxRate',
    'explicitAverageIncomeTaxRate',
  };

  final String snapshotId;
  final String profileOwnerId;
  final int? taxYear;
  final int? basedOnTaxYear;
  final DateTime? sourceDate;
  final TaxDocumentKind documentKind;
  final TaxAssessmentStatus assessmentStatus;
  final bool inForceAttested;
  final TaxSubjectScope subjectScope;
  final String? cantonCode;
  final String? municipalityId;
  final String? municipalityLabel;
  final double? cantonalCommunalTaxableIncomeChf;
  final double? federalTaxableIncomeChf;
  final double? cantonalCommunalTaxableWealthChf;
  final AssessedTaxAmount? cantonalCommunalAssessedTax;
  final AssessedTaxAmount? federalDirectAssessedTax;
  final double? explicitMarginalIncomeTaxRate;
  final double? explicitAverageIncomeTaxRate;
  final DateTime updatedAt;

  TaxSnapshot({
    required this.snapshotId,
    required this.profileOwnerId,
    required this.taxYear,
    required this.basedOnTaxYear,
    required this.sourceDate,
    required this.documentKind,
    required this.assessmentStatus,
    this.inForceAttested = false,
    required this.subjectScope,
    required this.cantonCode,
    required this.municipalityId,
    required this.municipalityLabel,
    required this.cantonalCommunalTaxableIncomeChf,
    required this.federalTaxableIncomeChf,
    required this.cantonalCommunalTaxableWealthChf,
    required this.cantonalCommunalAssessedTax,
    required this.federalDirectAssessedTax,
    required this.explicitMarginalIncomeTaxRate,
    required this.explicitAverageIncomeTaxRate,
    required this.updatedAt,
  }) {
    if (!uuidV4Pattern.hasMatch(snapshotId)) {
      throw ArgumentError.value(snapshotId, 'snapshotId', 'UUIDv4 required');
    }
    if (profileOwnerId.isEmpty) {
      throw ArgumentError.value(profileOwnerId, 'profileOwnerId');
    }
    if (cantonCode != null && !sortedCantonCodes.contains(cantonCode)) {
      throw ArgumentError.value(
        cantonCode,
        'cantonCode',
        'canonical Swiss canton code required',
      );
    }
    validateRuntimeFacts(
      documentKind: documentKind,
      assessmentStatus: assessmentStatus,
      cantonalCommunalTaxableIncomeChf: cantonalCommunalTaxableIncomeChf,
      federalTaxableIncomeChf: federalTaxableIncomeChf,
      cantonalCommunalTaxableWealthChf: cantonalCommunalTaxableWealthChf,
      cantonalCommunalAssessedTax: cantonalCommunalAssessedTax,
      federalDirectAssessedTax: federalDirectAssessedTax,
      explicitMarginalIncomeTaxRate: explicitMarginalIncomeTaxRate,
      explicitAverageIncomeTaxRate: explicitAverageIncomeTaxRate,
    );
  }

  static bool hasValidTaxYears({
    required int? taxYear,
    required int? basedOnTaxYear,
    required TaxDocumentKind documentKind,
    required int currentYear,
  }) {
    bool inCivilRange(int? year) =>
        year == null || year >= 1900 && year <= currentYear;
    if (!inCivilRange(taxYear) || !inCivilRange(basedOnTaxYear)) return false;
    if (documentKind == TaxDocumentKind.provisionalBill &&
        taxYear != null &&
        basedOnTaxYear != null &&
        basedOnTaxYear > taxYear) {
      return false;
    }
    return true;
  }

  static void validateTaxYears({
    required int? taxYear,
    required int? basedOnTaxYear,
    required TaxDocumentKind documentKind,
    required int currentYear,
  }) {
    if (taxYear != null && (taxYear < 1900 || taxYear > currentYear)) {
      throw ArgumentError.value(
        taxYear,
        'taxYear',
        'civil tax year between 1900 and $currentYear required',
      );
    }
    if (basedOnTaxYear != null &&
        (basedOnTaxYear < 1900 || basedOnTaxYear > currentYear)) {
      throw ArgumentError.value(
        basedOnTaxYear,
        'basedOnTaxYear',
        'civil tax year between 1900 and $currentYear required',
      );
    }
    if (documentKind == TaxDocumentKind.provisionalBill &&
        taxYear != null &&
        basedOnTaxYear != null &&
        basedOnTaxYear > taxYear) {
      throw ArgumentError.value(
        basedOnTaxYear,
        'basedOnTaxYear',
        'provisional reference year cannot exceed taxYear',
      );
    }
  }

  static void validateRuntimeFacts({
    required TaxDocumentKind documentKind,
    required TaxAssessmentStatus assessmentStatus,
    required double? cantonalCommunalTaxableIncomeChf,
    required double? federalTaxableIncomeChf,
    required double? cantonalCommunalTaxableWealthChf,
    required AssessedTaxAmount? cantonalCommunalAssessedTax,
    required AssessedTaxAmount? federalDirectAssessedTax,
    required double? explicitMarginalIncomeTaxRate,
    required double? explicitAverageIncomeTaxRate,
  }) {
    if (!_isValidDocumentStatus(documentKind, assessmentStatus)) {
      throw ArgumentError(
        'Invalid tax document/status pair: '
        '${documentKind.name}/${assessmentStatus.name}',
      );
    }
    _validateFinite(
      cantonalCommunalTaxableIncomeChf,
      'cantonalCommunalTaxableIncomeChf',
    );
    _validateFinite(
      federalTaxableIncomeChf,
      'federalTaxableIncomeChf',
    );
    _validateFinite(
      cantonalCommunalTaxableWealthChf,
      'cantonalCommunalTaxableWealthChf',
    );
    if (cantonalCommunalTaxableWealthChf != null &&
        cantonalCommunalTaxableWealthChf < 0) {
      throw ArgumentError.value(
        cantonalCommunalTaxableWealthChf,
        'cantonalCommunalTaxableWealthChf',
        'non-negative taxable wealth required',
      );
    }
    _validateRate(explicitMarginalIncomeTaxRate, 'marginal rate');
    _validateRate(explicitAverageIncomeTaxRate, 'average rate');
    if (cantonalCommunalAssessedTax?.authorityScope ==
        TaxAuthorityScope.federalDirect) {
      throw ArgumentError.value(
        cantonalCommunalAssessedTax!.authorityScope,
        'cantonalCommunalAssessedTax.authorityScope',
        'cantonal or communal authority required',
      );
    }
    if (federalDirectAssessedTax != null &&
        federalDirectAssessedTax.authorityScope !=
            TaxAuthorityScope.federalDirect) {
      throw ArgumentError.value(
        federalDirectAssessedTax.authorityScope,
        'federalDirectAssessedTax.authorityScope',
        'federalDirect authority required',
      );
    }
    if (federalDirectAssessedTax != null &&
        federalDirectAssessedTax.baseScope != TaxBaseScope.incomeOnly &&
        federalDirectAssessedTax.baseScope != TaxBaseScope.unknown) {
      throw ArgumentError.value(
        federalDirectAssessedTax.baseScope,
        'federalDirectAssessedTax.baseScope',
        'federal direct tax supports incomeOnly or unknown only',
      );
    }
  }

  static bool _isValidDocumentStatus(
    TaxDocumentKind kind,
    TaxAssessmentStatus status,
  ) {
    return switch (kind) {
      TaxDocumentKind.taxpayerReturn =>
        status == TaxAssessmentStatus.selfDeclared,
      TaxDocumentKind.provisionalBill =>
        status == TaxAssessmentStatus.provisional,
      TaxDocumentKind.assessmentNotice =>
        status == TaxAssessmentStatus.assessedAppealable ||
            status == TaxAssessmentStatus.contested ||
            status == TaxAssessmentStatus.inForce,
      TaxDocumentKind.finalTaxBill ||
      TaxDocumentKind.unknown =>
        status == TaxAssessmentStatus.unknown,
    };
  }

  static void _validateFinite(double? value, String label) {
    if (value != null && !value.isFinite) {
      throw ArgumentError.value(value, label, 'finite value required');
    }
  }

  static void _validateRate(double? rate, String label) {
    if (rate != null && (!rate.isFinite || rate < 0 || rate > 1)) {
      throw ArgumentError.value(rate, label, 'ratio 0...1 required');
    }
  }

  factory TaxSnapshot.fromJson(Map<String, dynamic> json) {
    final id = json['snapshotId'];
    final owner = json['profileOwnerId'];
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    if (id is! String || owner is! String || updatedAt == null) {
      throw const FormatException('Invalid tax snapshot identity');
    }
    DateTime? parseOptionalDate(dynamic raw) {
      if (raw == null) return null;
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed == null) throw const FormatException('Invalid sourceDate');
      return parsed;
    }

    double? parseOptionalDouble(dynamic raw) {
      if (raw == null) return null;
      if (raw is! num) throw const FormatException('Invalid tax number');
      final value = raw.toDouble();
      if (!value.isFinite) throw const FormatException('Invalid tax number');
      return value;
    }

    AssessedTaxAmount? parseAmount(dynamic raw) {
      if (raw == null) return null;
      if (raw is! Map) throw const FormatException('Invalid tax amount');
      return AssessedTaxAmount.fromJson(Map<String, dynamic>.from(raw));
    }

    return TaxSnapshot(
      snapshotId: id,
      profileOwnerId: owner,
      taxYear: json['taxYear'] as int?,
      basedOnTaxYear: json['basedOnTaxYear'] as int?,
      sourceDate: parseOptionalDate(json['sourceDate']),
      documentKind: _requiredEnum(
        TaxDocumentKind.values,
        json['documentKind'],
        'documentKind',
      ),
      assessmentStatus: _requiredEnum(
        TaxAssessmentStatus.values,
        json['assessmentStatus'],
        'assessmentStatus',
      ),
      inForceAttested: json.containsKey('inForceAttested')
          ? switch (json['inForceAttested']) {
              final bool value => value,
              _ => throw const FormatException('Invalid inForceAttested'),
            }
          : false,
      subjectScope: _requiredEnum(
        TaxSubjectScope.values,
        json['subjectScope'],
        'subjectScope',
      ),
      cantonCode: json['cantonCode'] as String?,
      municipalityId: json['municipalityId'] as String?,
      municipalityLabel: json['municipalityLabel'] as String?,
      cantonalCommunalTaxableIncomeChf:
          parseOptionalDouble(json['cantonalCommunalTaxableIncomeChf']),
      federalTaxableIncomeChf:
          parseOptionalDouble(json['federalTaxableIncomeChf']),
      cantonalCommunalTaxableWealthChf:
          parseOptionalDouble(json['cantonalCommunalTaxableWealthChf']),
      cantonalCommunalAssessedTax:
          parseAmount(json['cantonalCommunalAssessedTax']),
      federalDirectAssessedTax: parseAmount(json['federalDirectAssessedTax']),
      explicitMarginalIncomeTaxRate:
          parseOptionalDouble(json['explicitMarginalIncomeTaxRate']),
      explicitAverageIncomeTaxRate:
          parseOptionalDouble(json['explicitAverageIncomeTaxRate']),
      updatedAt: updatedAt,
    );
  }

  TaxSnapshot copyWith({
    String? snapshotId,
    String? profileOwnerId,
    Object? taxYear = _taxUnset,
    Object? basedOnTaxYear = _taxUnset,
    Object? sourceDate = _taxUnset,
    TaxDocumentKind? documentKind,
    TaxAssessmentStatus? assessmentStatus,
    bool? inForceAttested,
    TaxSubjectScope? subjectScope,
    Object? cantonCode = _taxUnset,
    Object? municipalityId = _taxUnset,
    Object? municipalityLabel = _taxUnset,
    Object? cantonalCommunalTaxableIncomeChf = _taxUnset,
    Object? federalTaxableIncomeChf = _taxUnset,
    Object? cantonalCommunalTaxableWealthChf = _taxUnset,
    Object? cantonalCommunalAssessedTax = _taxUnset,
    Object? federalDirectAssessedTax = _taxUnset,
    Object? explicitMarginalIncomeTaxRate = _taxUnset,
    Object? explicitAverageIncomeTaxRate = _taxUnset,
    DateTime? updatedAt,
  }) {
    T? value<T>(Object? next, T? current) =>
        identical(next, _taxUnset) ? current : next as T?;
    return TaxSnapshot(
      snapshotId: snapshotId ?? this.snapshotId,
      profileOwnerId: profileOwnerId ?? this.profileOwnerId,
      taxYear: value<int>(taxYear, this.taxYear),
      basedOnTaxYear: value<int>(basedOnTaxYear, this.basedOnTaxYear),
      sourceDate: value<DateTime>(sourceDate, this.sourceDate),
      documentKind: documentKind ?? this.documentKind,
      assessmentStatus: assessmentStatus ?? this.assessmentStatus,
      inForceAttested: inForceAttested ?? this.inForceAttested,
      subjectScope: subjectScope ?? this.subjectScope,
      cantonCode: value<String>(cantonCode, this.cantonCode),
      municipalityId: value<String>(municipalityId, this.municipalityId),
      municipalityLabel:
          value<String>(municipalityLabel, this.municipalityLabel),
      cantonalCommunalTaxableIncomeChf: value<double>(
        cantonalCommunalTaxableIncomeChf,
        this.cantonalCommunalTaxableIncomeChf,
      ),
      federalTaxableIncomeChf:
          value<double>(federalTaxableIncomeChf, this.federalTaxableIncomeChf),
      cantonalCommunalTaxableWealthChf: value<double>(
        cantonalCommunalTaxableWealthChf,
        this.cantonalCommunalTaxableWealthChf,
      ),
      cantonalCommunalAssessedTax: value<AssessedTaxAmount>(
        cantonalCommunalAssessedTax,
        this.cantonalCommunalAssessedTax,
      ),
      federalDirectAssessedTax: value<AssessedTaxAmount>(
        federalDirectAssessedTax,
        this.federalDirectAssessedTax,
      ),
      explicitMarginalIncomeTaxRate: value<double>(
        explicitMarginalIncomeTaxRate,
        this.explicitMarginalIncomeTaxRate,
      ),
      explicitAverageIncomeTaxRate: value<double>(
        explicitAverageIncomeTaxRate,
        this.explicitAverageIncomeTaxRate,
      ),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'snapshotId': snapshotId,
        'profileOwnerId': profileOwnerId,
        'taxYear': taxYear,
        'basedOnTaxYear': basedOnTaxYear,
        'sourceDate': sourceDate?.toIso8601String(),
        'documentKind': documentKind.name,
        'assessmentStatus': assessmentStatus.name,
        'inForceAttested': inForceAttested,
        'subjectScope': subjectScope.name,
        'cantonCode': cantonCode,
        'municipalityId': municipalityId,
        'municipalityLabel': municipalityLabel,
        'cantonalCommunalTaxableIncomeChf': cantonalCommunalTaxableIncomeChf,
        'federalTaxableIncomeChf': federalTaxableIncomeChf,
        'cantonalCommunalTaxableWealthChf': cantonalCommunalTaxableWealthChf,
        'cantonalCommunalAssessedTax': cantonalCommunalAssessedTax?.toJson(),
        'federalDirectAssessedTax': federalDirectAssessedTax?.toJson(),
        'explicitMarginalIncomeTaxRate': explicitMarginalIncomeTaxRate,
        'explicitAverageIncomeTaxRate': explicitAverageIncomeTaxRate,
        'updatedAt': updatedAt.toIso8601String(),
      };

  Object? provenanceValue(String leafPath) {
    return switch (leafPath) {
      'taxYear' => taxYear,
      'basedOnTaxYear' => basedOnTaxYear,
      'sourceDate' => sourceDate?.toIso8601String(),
      'documentKind' => documentKind.name,
      'assessmentStatus' => assessmentStatus.name,
      'inForceAttested' => inForceAttested ? true : null,
      'subjectScope' => subjectScope.name,
      'cantonCode' => cantonCode,
      'municipalityId' => municipalityId,
      'municipalityLabel' => municipalityLabel,
      'cantonalCommunalTaxableIncomeChf' => cantonalCommunalTaxableIncomeChf,
      'federalTaxableIncomeChf' => federalTaxableIncomeChf,
      'cantonalCommunalTaxableWealthChf' => cantonalCommunalTaxableWealthChf,
      'cantonalCommunalAssessedTax.amountChf' =>
        cantonalCommunalAssessedTax?.amountChf,
      'cantonalCommunalAssessedTax.authorityScope' =>
        cantonalCommunalAssessedTax?.authorityScope.name,
      'cantonalCommunalAssessedTax.baseScope' =>
        cantonalCommunalAssessedTax?.baseScope.name,
      'federalDirectAssessedTax.amountChf' =>
        federalDirectAssessedTax?.amountChf,
      'federalDirectAssessedTax.authorityScope' =>
        federalDirectAssessedTax?.authorityScope.name,
      'federalDirectAssessedTax.baseScope' =>
        federalDirectAssessedTax?.baseScope.name,
      'explicitMarginalIncomeTaxRate' => explicitMarginalIncomeTaxRate,
      'explicitAverageIncomeTaxRate' => explicitAverageIncomeTaxRate,
      _ => null,
    };
  }

  bool semanticallyEquals(TaxSnapshot other) =>
      taxYear == other.taxYear &&
      basedOnTaxYear == other.basedOnTaxYear &&
      sourceDate == other.sourceDate &&
      documentKind == other.documentKind &&
      assessmentStatus == other.assessmentStatus &&
      inForceAttested == other.inForceAttested &&
      subjectScope == other.subjectScope &&
      cantonCode == other.cantonCode &&
      municipalityId == other.municipalityId &&
      municipalityLabel == other.municipalityLabel &&
      cantonalCommunalTaxableIncomeChf ==
          other.cantonalCommunalTaxableIncomeChf &&
      federalTaxableIncomeChf == other.federalTaxableIncomeChf &&
      cantonalCommunalTaxableWealthChf ==
          other.cantonalCommunalTaxableWealthChf &&
      cantonalCommunalAssessedTax == other.cantonalCommunalAssessedTax &&
      federalDirectAssessedTax == other.federalDirectAssessedTax &&
      explicitMarginalIncomeTaxRate == other.explicitMarginalIncomeTaxRate &&
      explicitAverageIncomeTaxRate == other.explicitAverageIncomeTaxRate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxSnapshot &&
          snapshotId == other.snapshotId &&
          profileOwnerId == other.profileOwnerId &&
          updatedAt == other.updatedAt &&
          semanticallyEquals(other);

  @override
  int get hashCode => Object.hashAll([
        snapshotId,
        profileOwnerId,
        taxYear,
        basedOnTaxYear,
        sourceDate,
        documentKind,
        assessmentStatus,
        inForceAttested,
        subjectScope,
        cantonCode,
        municipalityId,
        municipalityLabel,
        cantonalCommunalTaxableIncomeChf,
        federalTaxableIncomeChf,
        cantonalCommunalTaxableWealthChf,
        cantonalCommunalAssessedTax,
        federalDirectAssessedTax,
        explicitMarginalIncomeTaxRate,
        explicitAverageIncomeTaxRate,
        updatedAt,
      ]);
}

@immutable
final class FiscalProfile {
  final List<TaxSnapshot> snapshots;
  final Set<String> provenanceValidatedSnapshotIds;
  final bool legacyDataNeedsReview;

  const FiscalProfile.empty()
      : snapshots = const [],
        provenanceValidatedSnapshotIds = const {},
        legacyDataNeedsReview = false;

  FiscalProfile({
    List<TaxSnapshot> snapshots = const [],
    Set<String>? provenanceValidatedSnapshotIds,
    this.legacyDataNeedsReview = false,
  })  : snapshots = List.unmodifiable(snapshots),
        provenanceValidatedSnapshotIds = Set.unmodifiable(
          provenanceValidatedSnapshotIds ?? const <String>{},
        );

  factory FiscalProfile.fromJson(Map<String, dynamic> json) {
    final rawSnapshots = json['snapshots'];
    if (rawSnapshots is! List) {
      throw const FormatException('Invalid fiscal snapshots');
    }
    return FiscalProfile(
      snapshots: rawSnapshots.map((raw) {
        if (raw is! Map) throw const FormatException('Invalid tax snapshot');
        return TaxSnapshot.fromJson(Map<String, dynamic>.from(raw));
      }).toList(),
      legacyDataNeedsReview: json['legacyDataNeedsReview'] == true,
    );
  }

  FiscalProfile copyWith({
    List<TaxSnapshot>? snapshots,
    Set<String>? provenanceValidatedSnapshotIds,
    bool? legacyDataNeedsReview,
  }) {
    return FiscalProfile(
      snapshots: snapshots ?? this.snapshots,
      provenanceValidatedSnapshotIds:
          provenanceValidatedSnapshotIds ?? this.provenanceValidatedSnapshotIds,
      legacyDataNeedsReview:
          legacyDataNeedsReview ?? this.legacyDataNeedsReview,
    );
  }

  Map<String, dynamic> toJson() => {
        'snapshots': snapshots.map((snapshot) => snapshot.toJson()).toList(),
        'legacyDataNeedsReview': legacyDataNeedsReview,
      };

  bool containsSnapshot(String snapshotId) =>
      snapshots.any((snapshot) => snapshot.snapshotId == snapshotId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FiscalProfile &&
          legacyDataNeedsReview == other.legacyDataNeedsReview &&
          setEquals(provenanceValidatedSnapshotIds,
              other.provenanceValidatedSnapshotIds) &&
          listEquals(snapshots, other.snapshots);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(snapshots),
        Object.hashAllUnordered(provenanceValidatedSnapshotIds),
        legacyDataNeedsReview,
      );
}

enum FiscalSnapshotQueryIntent { precise, latestCompleteness }

@immutable
final class FiscalSnapshotQuery {
  final FiscalSnapshotQueryIntent intent;
  final TaxSnapshotField requestedField;
  final int? taxYear;
  final String? cantonCode;
  final String? municipalityId;
  final TaxSubjectScope? subjectScope;
  final TaxAuthorityScope? authorityScope;
  final TaxBaseScope? baseScope;

  factory FiscalSnapshotQuery.precise({
    required TaxSnapshotField requestedField,
    required int taxYear,
    required TaxSubjectScope subjectScope,
    required String cantonCode,
    String? municipalityId,
    TaxAuthorityScope? authorityScope,
    TaxBaseScope? baseScope,
    DateTime Function()? now,
  }) {
    final currentYear = SwissCivilTime.civilDate((now ?? DateTime.now)()).year;
    if (taxYear < 1900 || taxYear > currentYear) {
      throw ArgumentError.value(taxYear, 'taxYear', 'valid tax year required');
    }
    if (subjectScope == TaxSubjectScope.unknown) {
      throw ArgumentError.value(
        subjectScope,
        'subjectScope',
        'confirmed subject scope required',
      );
    }
    if (!sortedCantonCodes.contains(cantonCode)) {
      throw ArgumentError.value(
        cantonCode,
        'cantonCode',
        'canonical Swiss canton code required',
      );
    }
    return FiscalSnapshotQuery._(
      intent: FiscalSnapshotQueryIntent.precise,
      requestedField: requestedField,
      taxYear: taxYear,
      cantonCode: cantonCode,
      municipalityId: municipalityId,
      subjectScope: subjectScope,
      authorityScope: authorityScope,
      baseScope: baseScope,
    );
  }

  const FiscalSnapshotQuery.latestCompleteness({
    required this.requestedField,
  })  : intent = FiscalSnapshotQueryIntent.latestCompleteness,
        taxYear = null,
        cantonCode = null,
        municipalityId = null,
        subjectScope = null,
        authorityScope = null,
        baseScope = null;

  const FiscalSnapshotQuery._({
    required this.intent,
    required this.requestedField,
    required this.taxYear,
    required this.cantonCode,
    required this.municipalityId,
    required this.subjectScope,
    required this.authorityScope,
    required this.baseScope,
  });
}

enum FiscalSelectionStatus { available, availableNeedsConfirmation, partialAsk }

@immutable
final class FiscalSelectionResult {
  final FiscalSelectionStatus status;
  final TaxSnapshot? snapshot;
  final List<String> conflictingSnapshotIds;

  FiscalSelectionResult._({
    required this.status,
    required this.snapshot,
    List<String> conflictingSnapshotIds = const [],
  }) : conflictingSnapshotIds = List.unmodifiable(conflictingSnapshotIds);

  factory FiscalSelectionResult.available(TaxSnapshot snapshot) =>
      FiscalSelectionResult._(
        status: FiscalSelectionStatus.available,
        snapshot: snapshot,
      );

  factory FiscalSelectionResult.availableStatusOnly() =>
      FiscalSelectionResult._(
        status: FiscalSelectionStatus.available,
        snapshot: null,
      );

  factory FiscalSelectionResult.availableNeedsConfirmation(
    TaxSnapshot snapshot,
  ) =>
      FiscalSelectionResult._(
        status: FiscalSelectionStatus.availableNeedsConfirmation,
        snapshot: snapshot,
      );

  factory FiscalSelectionResult.partialAsk(
          {List<String> conflicts = const []}) =>
      FiscalSelectionResult._(
        status: FiscalSelectionStatus.partialAsk,
        snapshot: null,
        conflictingSnapshotIds: conflicts,
      );
}

abstract final class FiscalSnapshotSelector {
  /// Selects the one validated, in-force assessment that may back the
  /// specialist tax-decision reference. Unlike a completeness query, this
  /// does not require any calculator-facing amount.
  static FiscalSelectionResult _selectLatestTaxDecisionReference(
    FiscalProfile fiscal, {
    DateTime Function()? now,
  }) {
    if (!FeatureFlags.typedTaxProfile) {
      return FiscalSelectionResult.partialAsk();
    }
    final current = (now ?? DateTime.now)();
    final today = _civilDay(current);
    final eligible = fiscal.snapshots.where((snapshot) {
      if (!fiscal.provenanceValidatedSnapshotIds
          .contains(snapshot.snapshotId)) {
        return false;
      }
      if (snapshot.documentKind != TaxDocumentKind.assessmentNotice ||
          snapshot.assessmentStatus != TaxAssessmentStatus.inForce ||
          !snapshot.inForceAttested ||
          snapshot.sourceDate == null ||
          snapshot.taxYear == null ||
          snapshot.subjectScope == TaxSubjectScope.unknown ||
          snapshot.cantonCode == null ||
          !sortedCantonCodes.contains(snapshot.cantonCode) ||
          snapshot.updatedAt.toUtc().isAfter(current.toUtc())) {
        return false;
      }
      if (!TaxSnapshot.hasValidTaxYears(
        taxYear: snapshot.taxYear,
        basedOnTaxYear: snapshot.basedOnTaxYear,
        documentKind: snapshot.documentKind,
        currentYear: today.year,
      )) {
        return false;
      }
      return !_civilDay(snapshot.sourceDate!).isAfter(today);
    }).toList();
    if (eligible.isEmpty) return FiscalSelectionResult.partialAsk();

    eligible.sort(_compareRankThenTechnical);
    final best = eligible.first;
    final sameRank = eligible
        .where((candidate) =>
            candidate.taxYear == best.taxYear &&
            candidate.assessmentStatus == best.assessmentStatus &&
            candidate.sourceDate == best.sourceDate)
        .toList();
    if (sameRank.any((candidate) => !candidate.semanticallyEquals(best))) {
      return FiscalSelectionResult.partialAsk(
        conflicts: sameRank.map((snapshot) => snapshot.snapshotId).toList(),
      );
    }
    sameRank.sort(_compareTechnical);
    return FiscalSelectionResult.available(sameRank.first);
  }

  static FiscalSelectionResult selectAssessedBaseline(
    FiscalProfile fiscal,
    FiscalSnapshotQuery query, {
    DateTime Function()? now,
  }) {
    if (!FeatureFlags.typedTaxProfile) {
      return FiscalSelectionResult.partialAsk();
    }
    final today = _civilDay((now ?? DateTime.now)());
    final eligible = fiscal.snapshots.where((snapshot) {
      if (!fiscal.provenanceValidatedSnapshotIds
          .contains(snapshot.snapshotId)) {
        return false;
      }
      if (snapshot.documentKind != TaxDocumentKind.assessmentNotice) {
        return false;
      }
      if (snapshot.assessmentStatus == TaxAssessmentStatus.inForce &&
          !snapshot.inForceAttested) {
        return false;
      }
      if (!TaxSnapshot.hasValidTaxYears(
        taxYear: snapshot.taxYear,
        basedOnTaxYear: snapshot.basedOnTaxYear,
        documentKind: snapshot.documentKind,
        currentYear: today.year,
      )) {
        return false;
      }
      if (snapshot.sourceDate case final sourceDate?
          when _civilDay(sourceDate).isAfter(today)) {
        return false;
      }
      if (snapshot.assessmentStatus != TaxAssessmentStatus.inForce &&
          snapshot.assessmentStatus != TaxAssessmentStatus.assessedAppealable) {
        return false;
      }
      if (snapshot.taxYear == null ||
          snapshot.subjectScope == TaxSubjectScope.unknown ||
          snapshot.cantonCode == null ||
          !sortedCantonCodes.contains(snapshot.cantonCode)) {
        return false;
      }
      if (query.intent == FiscalSnapshotQueryIntent.precise) {
        if (query.taxYear == null ||
            query.subjectScope == null ||
            query.subjectScope == TaxSubjectScope.unknown ||
            query.cantonCode == null ||
            !sortedCantonCodes.contains(query.cantonCode) ||
            query.authorityScope == TaxAuthorityScope.unknown ||
            query.baseScope == TaxBaseScope.unknown) {
          return false;
        }
        if (snapshot.taxYear != query.taxYear ||
            snapshot.subjectScope != query.subjectScope ||
            snapshot.cantonCode != query.cantonCode) {
          return false;
        }
        if (query.municipalityId != null &&
            snapshot.municipalityId != query.municipalityId) {
          return false;
        }
      }
      if (!_matchesRequestedField(snapshot, query)) return false;
      return true;
    }).toList();
    if (eligible.isEmpty) return FiscalSelectionResult.partialAsk();

    eligible.sort(_compareRankThenTechnical);
    final best = eligible.first;
    final sameRank = eligible
        .where((candidate) =>
            candidate.taxYear == best.taxYear &&
            candidate.assessmentStatus == best.assessmentStatus &&
            candidate.sourceDate == best.sourceDate)
        .toList();
    if (sameRank.any((candidate) => !candidate.semanticallyEquals(best))) {
      return FiscalSelectionResult.partialAsk(
        conflicts: sameRank.map((snapshot) => snapshot.snapshotId).toList(),
      );
    }
    sameRank.sort(_compareTechnical);
    if (best.sourceDate == null) {
      if (query.intent == FiscalSnapshotQueryIntent.latestCompleteness) {
        return FiscalSelectionResult.partialAsk();
      }
      return FiscalSelectionResult.availableNeedsConfirmation(sameRank.first);
    }
    if (query.intent == FiscalSnapshotQueryIntent.latestCompleteness) {
      return FiscalSelectionResult.availableStatusOnly();
    }
    return FiscalSelectionResult.available(sameRank.first);
  }

  static DateTime _civilDay(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  static bool _matchesRequestedField(
    TaxSnapshot snapshot,
    FiscalSnapshotQuery query,
  ) {
    // A negative taxable income may represent a carried loss. Preserve it in
    // the ledger, but do not consume it until label/canton/ruleset semantics
    // exist to distinguish that legal meaning from a malformed baseline.
    return switch (query.requestedField) {
      TaxSnapshotField.cantonalCommunalTaxableIncomeChf =>
        snapshot.cantonalCommunalTaxableIncomeChf != null &&
            snapshot.cantonalCommunalTaxableIncomeChf! >= 0,
      TaxSnapshotField.federalTaxableIncomeChf =>
        snapshot.federalTaxableIncomeChf != null &&
            snapshot.federalTaxableIncomeChf! >= 0,
      TaxSnapshotField.cantonalCommunalTaxableWealthChf =>
        snapshot.cantonalCommunalTaxableWealthChf != null,
      TaxSnapshotField.cantonalCommunalAssessedTax =>
        _matchesCantonalAssessedTax(snapshot, query),
      TaxSnapshotField.federalDirectAssessedTax =>
        _matchesFederalAssessedTax(snapshot, query),
      TaxSnapshotField.explicitMarginalIncomeTaxRate =>
        snapshot.explicitMarginalIncomeTaxRate != null,
      TaxSnapshotField.explicitAverageIncomeTaxRate =>
        snapshot.explicitAverageIncomeTaxRate != null,
    };
  }

  static bool _matchesCantonalAssessedTax(
    TaxSnapshot snapshot,
    FiscalSnapshotQuery query,
  ) {
    final amount = snapshot.cantonalCommunalAssessedTax;
    if (amount == null ||
        query.authorityScope == null ||
        query.baseScope == null ||
        !_isCanonicalCantonalAmount(amount)) {
      return false;
    }
    return amount.authorityScope == query.authorityScope &&
        amount.baseScope == query.baseScope;
  }

  static bool _matchesFederalAssessedTax(
    TaxSnapshot snapshot,
    FiscalSnapshotQuery query,
  ) {
    final amount = snapshot.federalDirectAssessedTax;
    if (amount == null ||
        query.authorityScope == null ||
        query.baseScope == null ||
        amount.authorityScope != TaxAuthorityScope.federalDirect ||
        amount.baseScope != TaxBaseScope.incomeOnly) {
      return false;
    }
    return query.authorityScope == TaxAuthorityScope.federalDirect &&
        query.baseScope == TaxBaseScope.incomeOnly;
  }

  static bool _isCanonicalCantonalAmount(AssessedTaxAmount amount) {
    final authorityIsCanonical = switch (amount.authorityScope) {
      TaxAuthorityScope.cantonalOnly ||
      TaxAuthorityScope.communalOnly ||
      TaxAuthorityScope.cantonalCommunalCombined =>
        true,
      TaxAuthorityScope.federalDirect || TaxAuthorityScope.unknown => false,
    };
    final baseIsCanonical = switch (amount.baseScope) {
      TaxBaseScope.incomeOnly ||
      TaxBaseScope.wealthOnly ||
      TaxBaseScope.incomeAndWealth =>
        true,
      TaxBaseScope.totalInvoice || TaxBaseScope.unknown => false,
    };
    return authorityIsCanonical && baseIsCanonical;
  }

  static int _statusRank(TaxAssessmentStatus status) =>
      status == TaxAssessmentStatus.inForce ? 0 : 1;

  static int _compareRankThenTechnical(TaxSnapshot a, TaxSnapshot b) {
    final year = b.taxYear!.compareTo(a.taxYear!);
    if (year != 0) return year;
    final status = _statusRank(a.assessmentStatus)
        .compareTo(_statusRank(b.assessmentStatus));
    if (status != 0) return status;
    final aDate = a.sourceDate;
    final bDate = b.sourceDate;
    if (aDate == null && bDate != null) return 1;
    if (aDate != null && bDate == null) return -1;
    if (aDate != null && bDate != null) {
      final sourceDate = bDate.compareTo(aDate);
      if (sourceDate != 0) return sourceDate;
    }
    return _compareTechnical(a, b);
  }

  static int _compareTechnical(TaxSnapshot a, TaxSnapshot b) {
    final updatedAt = b.updatedAt.compareTo(a.updatedAt);
    if (updatedAt != 0) return updatedAt;
    return a.snapshotId.compareTo(b.snapshotId);
  }
}

/// Closed specialist-reference kinds accepted by the RET-REF-01 ledger.
enum SpecialistReferenceKind {
  lppRegulation,
  lppCapitalNotice,
  pillar3aBeneficiaryClause,
  taxAssessmentDecision,
}

/// Precision state at an explicit evaluation instant.
enum SpecialistReferenceState {
  known,
  missing,
  stale,
  conflict,
  invalid;

  /// Concrete getter because RET-REF callers may cross a dynamic boundary.
  String get name => switch (this) {
        known => 'known',
        missing => 'missing',
        stale => 'stale',
        conflict => 'conflict',
        invalid => 'invalid',
      };
}

/// Metadata-only link to specialist-grade evidence.
///
/// This value object deliberately contains no filename, local path, OCR text,
/// financial value, or document bytes. Construction from persisted JSON is
/// strict and fail-closed so an unknown key cannot become a second ledger.
@immutable
final class SpecialistReferenceEvidence {
  static final RegExp _uuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static const Set<String> _commonKeys = {
    'referenceId',
    'kind',
    'ownerKind',
    'source',
    'sourceDate',
    'legalYear',
    'confirmedAt',
  };

  final String referenceId;
  final SpecialistReferenceKind kind;
  final LppEvidenceOwnerKind ownerKind;
  final ProfileDataSource source;
  final DateTime sourceDate;
  final int legalYear;
  final DateTime confirmedAt;
  final DateTime? deadlineDate;
  final String? contractReferenceId;
  final int? taxYear;
  final String? jurisdiction;
  final TaxSubjectScope? subject;

  const SpecialistReferenceEvidence._({
    required this.referenceId,
    required this.kind,
    required this.ownerKind,
    required this.source,
    required this.sourceDate,
    required this.legalYear,
    required this.confirmedAt,
    this.deadlineDate,
    this.contractReferenceId,
    this.taxYear,
    this.jurisdiction,
    this.subject,
  });

  /// Rebuilds the derived specialist link from the canonical typed ledger.
  /// The caller must supply a [FiscalProfile] whose provenance IDs have
  /// already passed the exact cold/live validation boundary.
  static SpecialistReferenceEvidence? latestTaxDecisionFromValidatedFiscal(
    FiscalProfile fiscal, {
    DateTime Function()? now,
  }) {
    final selection = FiscalSnapshotSelector._selectLatestTaxDecisionReference(
      fiscal,
      now: now,
    );
    final snapshot = selection.snapshot;
    if (selection.status != FiscalSelectionStatus.available ||
        snapshot == null) {
      return null;
    }
    return SpecialistReferenceEvidence._(
      referenceId: snapshot.snapshotId,
      kind: SpecialistReferenceKind.taxAssessmentDecision,
      ownerKind: LppEvidenceOwnerKind.self,
      source: ProfileDataSource.certificate,
      sourceDate: snapshot.sourceDate!,
      legalYear: snapshot.taxYear!,
      confirmedAt: snapshot.updatedAt.toUtc(),
      taxYear: snapshot.taxYear,
      jurisdiction: snapshot.cantonCode,
      subject: snapshot.subjectScope,
    );
  }

  /// Parses one field against its expected kind and exact key allowlist.
  static SpecialistReferenceEvidence? tryFromJson(
    Object? raw, {
    required SpecialistReferenceKind expectedKind,
    DateTime? now,
  }) {
    if (raw is! Map) return null;
    final json = <String, Object?>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) return null;
      json[entry.key as String] = entry.value;
    }

    final extraKeys = switch (expectedKind) {
      SpecialistReferenceKind.lppRegulation => const <String>{},
      SpecialistReferenceKind.lppCapitalNotice => const {'deadlineDate'},
      SpecialistReferenceKind.pillar3aBeneficiaryClause => const {
          'contractReferenceId'
        },
      SpecialistReferenceKind.taxAssessmentDecision => const {
          'taxYear',
          'jurisdiction',
          'subject'
        },
    };
    if (!setEquals(json.keys.toSet(), {..._commonKeys, ...extraKeys})) {
      return null;
    }

    final referenceId = json['referenceId'];
    final kindName = json['kind'];
    final ownerKind = LppEvidenceOwnerKind.fromWireName(json['ownerKind']);
    final sourceName = json['source'];
    final sourceDateRaw = json['sourceDate'];
    final legalYear = json['legalYear'];
    final confirmedAtRaw = json['confirmedAt'];
    if (referenceId is! String ||
        !_uuidV4Pattern.hasMatch(referenceId) ||
        kindName != expectedKind.name ||
        ownerKind == null ||
        sourceName != ProfileDataSource.certificate.name ||
        sourceDateRaw is! String ||
        legalYear is! int ||
        legalYear < 1900 ||
        legalYear > 9999 ||
        confirmedAtRaw is! String) {
      return null;
    }

    final sourceDate = _parseCivilDate(sourceDateRaw);
    final confirmedAt = DateTime.tryParse(confirmedAtRaw);
    if (sourceDate == null ||
        confirmedAt == null ||
        confirmedAt.toUtc().toIso8601String() != confirmedAtRaw) {
      return null;
    }
    final current = now ?? DateTime.now();
    if (SwissCivilTime.isFutureCivilDate(sourceDate, now: current) ||
        confirmedAt.isAfter(current.toUtc())) {
      return null;
    }

    DateTime? deadlineDate;
    String? contractReferenceId;
    int? taxYear;
    String? jurisdiction;
    TaxSubjectScope? subject;
    switch (expectedKind) {
      case SpecialistReferenceKind.lppRegulation:
        break;
      case SpecialistReferenceKind.lppCapitalNotice:
        final rawDeadline = json['deadlineDate'];
        if (rawDeadline is! String) return null;
        deadlineDate = _parseCivilDate(rawDeadline);
        if (deadlineDate == null) return null;
      case SpecialistReferenceKind.pillar3aBeneficiaryClause:
        final rawContractReferenceId = json['contractReferenceId'];
        if (rawContractReferenceId is! String ||
            !_uuidV4Pattern.hasMatch(rawContractReferenceId)) {
          return null;
        }
        contractReferenceId = rawContractReferenceId;
      case SpecialistReferenceKind.taxAssessmentDecision:
        final rawTaxYear = json['taxYear'];
        final rawJurisdiction = json['jurisdiction'];
        final rawSubject = json['subject'];
        final parsedSubject = rawSubject is String
            ? TaxSubjectScope.values
                .where((value) => value != TaxSubjectScope.unknown)
                .where((value) => value.name == rawSubject)
                .firstOrNull
            : null;
        if (rawTaxYear is! int ||
            rawTaxYear < 1900 ||
            rawTaxYear != legalYear ||
            rawJurisdiction is! String ||
            !sortedCantonCodes.contains(rawJurisdiction) ||
            parsedSubject == null) {
          return null;
        }
        taxYear = rawTaxYear;
        jurisdiction = rawJurisdiction;
        subject = parsedSubject;
    }

    return SpecialistReferenceEvidence._(
      referenceId: referenceId,
      kind: expectedKind,
      ownerKind: ownerKind,
      source: ProfileDataSource.certificate,
      sourceDate: sourceDate,
      legalYear: legalYear,
      confirmedAt: confirmedAt,
      deadlineDate: deadlineDate,
      contractReferenceId: contractReferenceId,
      taxYear: taxYear,
      jurisdiction: jurisdiction,
      subject: subject,
    );
  }

  static DateTime? _parseCivilDate(String raw) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return null;
    return SwissCivilTime.parseCanonicalCivilDate(raw);
  }

  /// Returns known only for evidence applicable at [asOf].
  SpecialistReferenceState stateAt(
    DateTime asOf, {
    TaxSnapshot? taxSnapshot,
    Iterable<SpecialistReferenceEvidence> conflictingReferences = const [],
  }) {
    if (SwissCivilTime.isFutureCivilDate(sourceDate, now: asOf) ||
        confirmedAt.isAfter(asOf.toUtc())) {
      return SpecialistReferenceState.invalid;
    }
    final hasConflict = conflictingReferences.any(
      (peer) =>
          peer != this &&
          peer.kind == kind &&
          peer.ownerKind == ownerKind &&
          peer.legalYear == legalYear,
    );
    if (hasConflict) return SpecialistReferenceState.conflict;

    final civilAsOf = SwissCivilTime.civilDate(asOf);
    if (deadlineDate != null &&
        SwissCivilTime.businessDate(deadlineDate!).isBefore(civilAsOf)) {
      return SpecialistReferenceState.stale;
    }
    if (kind == SpecialistReferenceKind.taxAssessmentDecision) {
      if (taxSnapshot == null) return SpecialistReferenceState.missing;
      final coherent = taxSnapshot.snapshotId == referenceId &&
          taxYear == legalYear &&
          taxSnapshot.taxYear == taxYear &&
          taxSnapshot.cantonCode == jurisdiction &&
          taxSnapshot.subjectScope == subject &&
          taxSnapshot.sourceDate != null &&
          SwissCivilTime.businessDate(taxSnapshot.sourceDate!) ==
              SwissCivilTime.businessDate(sourceDate) &&
          taxSnapshot.updatedAt.toUtc() == confirmedAt.toUtc() &&
          taxSnapshot.documentKind == TaxDocumentKind.assessmentNotice &&
          taxSnapshot.assessmentStatus == TaxAssessmentStatus.inForce &&
          taxSnapshot.inForceAttested;
      if (!coherent) return SpecialistReferenceState.conflict;
    }
    return SpecialistReferenceState.known;
  }

  bool precisionReadyAt(
    DateTime asOf, {
    TaxSnapshot? taxSnapshot,
    Iterable<SpecialistReferenceEvidence> conflictingReferences = const [],
  }) =>
      stateAt(
        asOf,
        taxSnapshot: taxSnapshot,
        conflictingReferences: conflictingReferences,
      ) ==
      SpecialistReferenceState.known;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'referenceId': referenceId,
        'kind': kind.name,
        'ownerKind': ownerKind.wireName,
        'source': source.name,
        'sourceDate': sourceDate.toIso8601String().split('T').first,
        'legalYear': legalYear,
        'confirmedAt': confirmedAt.toIso8601String(),
        if (deadlineDate != null)
          'deadlineDate': deadlineDate!.toIso8601String().split('T').first,
        if (contractReferenceId != null)
          'contractReferenceId': contractReferenceId,
        if (taxYear != null) 'taxYear': taxYear,
        if (jurisdiction != null) 'jurisdiction': jurisdiction,
        if (subject != null) 'subject': subject!.name,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpecialistReferenceEvidence &&
          referenceId == other.referenceId &&
          kind == other.kind &&
          ownerKind == other.ownerKind &&
          source == other.source &&
          sourceDate == other.sourceDate &&
          legalYear == other.legalYear &&
          confirmedAt == other.confirmedAt &&
          deadlineDate == other.deadlineDate &&
          contractReferenceId == other.contractReferenceId &&
          taxYear == other.taxYear &&
          jurisdiction == other.jurisdiction &&
          subject == other.subject;

  @override
  int get hashCode => Object.hash(
        referenceId,
        kind,
        ownerKind,
        source,
        sourceDate,
        legalYear,
        confirmedAt,
        deadlineDate,
        contractReferenceId,
        taxYear,
        jurisdiction,
        subject,
      );
}

/// Profil financier complet pour MINT Coach.
///
/// Contient toutes les données nécessaires au ForecasterService
/// et au FinancialFitnessScore. Persiste localement (SharedPreferences
/// ou Hive) et peut etre exporte en JSON.
class CoachProfile {
  /// Schema version for migration support.
  /// Increment when breaking changes are made to serialization format.
  static const int schemaVersion = 1;

  // === IDENTITE ===
  final String? firstName;
  final int birthYear;
  final DateTime? dateOfBirth;
  final String canton;
  final String? commune;
  final String? nationality; // ISO 2-letter code, ex "CH", "US", "FR"

  /// Declared residence and work jurisdictions. No legacy field can populate
  /// these facts because nationality, permit and residence canton are not
  /// unambiguous jurisdiction evidence.
  final CountryCode? residenceCountry;
  final CountryCode? workCountry;
  final SwissCantonCode? workCanton;
  final CoachCivilStatus etatCivil;

  /// True when a legacy civil-status token is too ambiguous to classify.
  ///
  /// While true, no marriage/cohabitation legal predicate may activate. The
  /// raw token is retained separately so the user can reconfirm it.
  final bool civilStatusNeedsConfirmation;
  final String? civilStatusRawValue;
  final int nombreEnfants;

  // === CONJOINT ===
  final ConjointProfile? conjoint;

  // === REVENUS ===
  final double salaireBrutMensuel;
  final double? monthlyNetIncomeDeclared; // CHF/month, direct user net income
  final double? monthlyTaxProvisionDeclared; // CHF/month, direct tax provision
  final double nombreDeMois; // 12, 13, 13.5
  final double? bonusPourcentage;
  final double employmentRate; // 0.0-100.0 (%), default full-time
  final String
      employmentStatus; // 'salarie', 'independant', 'chomage', 'retraite'
  final double? selfEmployedNetIncome; // CHF/year for independants
  final double? companyProfitAnnual; // CHF/year SA/Sarl distributable envelope
  final int? unemploymentContributionMonths; // LACI months in last 2 years

  /// Exact annual 3a contribution declared by the user. Null is unknown.
  final double? pillar3aAnnualContribution;

  /// Exact monthly savings flow declared by the user. Null is unknown.
  final double? monthlySavingsContribution;

  /// Explicit 3a-presence fact. Null means the question was not answered.
  final bool? hasPillar3a;

  /// Typed AVS gap answer, distinct from certified numeric gap years.
  final AvsGapStatus? avsGapStatus;

  // === DEPENSES ===
  final DepensesProfile depenses;

  // === PREVOYANCE ===
  final PrevoyanceProfile prevoyance;

  // === PATRIMOINE ===
  final PatrimoineProfile patrimoine;

  // === DETTES ===
  final DetteProfile dettes;

  // === FISCALITE ===
  final FiscalProfile fiscal;

  // === REFERENCES SPECIALISTES (metadata only) ===
  final SpecialistReferenceEvidence? lppRegulationReference;
  final SpecialistReferenceEvidence? lppCapitalNoticeDeadline;
  final SpecialistReferenceEvidence? pillar3aBeneficiaryClause;
  final SpecialistReferenceEvidence? latestTaxDecisionReference;

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

  /// Gender: 'M', 'F', or null (unknown).
  /// Used for AVS21 transitional reference age calculation.
  /// Women born 1961-1963 have transitional ages (LAVS art. 21 al. 1).
  final String? gender;

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

  /// Per-field update timestamps for freshness scoring (S46).
  /// Key = same field path as dataSources, value = when the value was last set.
  /// Fields absent from this map default to profile.createdAt for decay calc.
  final Map<String, DateTime> dataTimestamps;

  /// Date carried by the underlying source, distinct from when MINT saved it.
  ///
  /// Every persisted provenance entry owns this slot, including an explicit
  /// null when no document or source date was supplied by the writer.
  final Map<String, DateTime?> dataSourceDates;

  /// Fields explicitly provided by the user (vs computed defaults).
  /// Used by the profile drawer to avoid showing phantom data like
  /// a default canton ('ZH') the user never entered.
  /// Populated by [fromWizardAnswers] based on actual wizard answer keys.
  final Set<String> userProvidedFields;

  // === CALIBRAGE ===
  /// Niveau de culture financiere, derive des 3 questions de calibrage
  /// en fin d'onboarding. Backward-compatible : absent → beginner.
  final FinancialLiteracyLevel financialLiteracyLevel;

  /// User's primary focus/intention — drives adaptive Pulse hero.
  /// Set during onboarding FocusSelector, changeable from Pulse.
  /// Format: '{category}_{subcategory}' e.g. 'proteger_retraite'.
  final String? primaryFocus;

  // === VOICE CURSOR (Phase 02-03 — see voice_cursor_contract.dart) ===
  /// User-chosen tone preference (soft / direct / unfiltered).
  /// Default: direct (per ROADMAP). Surfaced in Phase 12 "Ton" chooser.
  final VoicePreference voiceCursorPreference;

  /// Rolling 7-day N5 emission counter for cap enforcement.
  /// Phase 11 VOICE-09 moves this to server-authoritative; this phase
  /// only persists the field. Default: 0.
  final int n5IssuedThisWeek;

  /// Timestamp when fragile mode was entered (auto or user-declared).
  /// Null = fragile mode not active. When non-null, voice cursor caps at N3
  /// (see fragilityCap rule in voice_cursor_contract.dart).
  final DateTime? fragileModeEnteredAt;

  /// Phase 11 (VOICE-09/10) — rolling 30-day gravity event log.
  /// Each entry: {"ts": ISO8601 String, "gravity": "G1"|"G2"|"G3"}.
  /// Server-authoritative: client mirrors for offline read-only display;
  /// the fragility detector lives backend-side (fragility_detector_service).
  /// No PII: only the gravity label + timestamp are persisted.
  final List<Map<String, dynamic>> recentGravityEvents;

  CoachProfile({
    this.firstName,
    required this.birthYear,
    this.dateOfBirth,
    required this.canton,
    this.commune,
    this.nationality,
    this.residenceCountry,
    this.workCountry,
    this.workCanton,
    this.etatCivil = CoachCivilStatus.celibataire,
    this.civilStatusNeedsConfirmation = false,
    this.civilStatusRawValue,
    this.nombreEnfants = 0,
    this.conjoint,
    required this.salaireBrutMensuel,
    this.monthlyNetIncomeDeclared,
    this.monthlyTaxProvisionDeclared,
    this.nombreDeMois = 12.0,
    this.bonusPourcentage,
    this.employmentRate =
        IncomeConversionCalculator.fullTimeEmploymentRatePercent,
    this.employmentStatus = 'salarie',
    this.selfEmployedNetIncome,
    this.companyProfitAnnual,
    this.unemploymentContributionMonths,
    this.pillar3aAnnualContribution,
    this.monthlySavingsContribution,
    this.hasPillar3a,
    this.avsGapStatus,
    this.depenses = const DepensesProfile(),
    this.prevoyance = const PrevoyanceProfile(),
    this.patrimoine = const PatrimoineProfile(),
    this.dettes = const DetteProfile(),
    this.fiscal = const FiscalProfile.empty(),
    this.lppRegulationReference,
    this.lppCapitalNoticeDeadline,
    this.pillar3aBeneficiaryClause,
    this.latestTaxDecisionReference,
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
    this.gender,
    this.targetRetirementAge,
    this.initialProjectionSnapshot,
    Map<String, ProfileDataSource> dataSources = const {},
    this.dataTimestamps = const {},
    this.dataSourceDates = const {},
    bool inferDataSources = true,
    this.userProvidedFields = const {},
    DateTime? createdAt,
    DateTime? updatedAt,
    this.financialLiteracyLevel = FinancialLiteracyLevel.beginner,
    this.primaryFocus,
    this.voiceCursorPreference = VoicePreference.direct,
    this.n5IssuedThisWeek = 0,
    this.fragileModeEnteredAt,
    this.recentGravityEvents = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        dataSources = inferDataSources
            ? _resolveDataSources(dataSources, prevoyance)
            : Map<String, ProfileDataSource>.from(dataSources);

  /// Minimal profile with all zeros — means "unknown, ask the user".
  /// Never lies about age, canton, or income.
  factory CoachProfile.defaults() => CoachProfile(
        birthYear: 0,
        canton: '',
        salaireBrutMensuel: 0,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2040),
          label: '',
        ),
      );

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

    // A populated AVS value is not evidence of its provenance. Mini-onboarding
    // and legacy hydration can populate these fields from calculations or
    // user input, so only an explicit document writer may upgrade the source.
    if (prevoyance.ramd != null) {
      inferred['prevoyance.ramd'] = ProfileDataSource.estimated;
    }
    if (prevoyance.renteAVSEstimeeMensuelle != null) {
      inferred['prevoyance.renteAVSEstimeeMensuelle'] =
          ProfileDataSource.estimated;
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
          firstName == other.firstName &&
          birthYear == other.birthYear &&
          dateOfBirth == other.dateOfBirth &&
          canton == other.canton &&
          commune == other.commune &&
          nationality == other.nationality &&
          residenceCountry == other.residenceCountry &&
          workCountry == other.workCountry &&
          workCanton == other.workCanton &&
          etatCivil == other.etatCivil &&
          civilStatusNeedsConfirmation == other.civilStatusNeedsConfirmation &&
          civilStatusRawValue == other.civilStatusRawValue &&
          nombreEnfants == other.nombreEnfants &&
          conjoint == other.conjoint &&
          salaireBrutMensuel == other.salaireBrutMensuel &&
          monthlyNetIncomeDeclared == other.monthlyNetIncomeDeclared &&
          monthlyTaxProvisionDeclared == other.monthlyTaxProvisionDeclared &&
          nombreDeMois == other.nombreDeMois &&
          bonusPourcentage == other.bonusPourcentage &&
          employmentRate == other.employmentRate &&
          employmentStatus == other.employmentStatus &&
          selfEmployedNetIncome == other.selfEmployedNetIncome &&
          companyProfitAnnual == other.companyProfitAnnual &&
          unemploymentContributionMonths ==
              other.unemploymentContributionMonths &&
          pillar3aAnnualContribution == other.pillar3aAnnualContribution &&
          monthlySavingsContribution == other.monthlySavingsContribution &&
          hasPillar3a == other.hasPillar3a &&
          avsGapStatus == other.avsGapStatus &&
          depenses == other.depenses &&
          prevoyance == other.prevoyance &&
          patrimoine == other.patrimoine &&
          dettes == other.dettes &&
          fiscal == other.fiscal &&
          lppRegulationReference == other.lppRegulationReference &&
          lppCapitalNoticeDeadline == other.lppCapitalNoticeDeadline &&
          pillar3aBeneficiaryClause == other.pillar3aBeneficiaryClause &&
          latestTaxDecisionReference == other.latestTaxDecisionReference &&
          goalA == other.goalA &&
          listEquals(goalsB, other.goalsB) &&
          listEquals(plannedContributions, other.plannedContributions) &&
          listEquals(checkIns, other.checkIns) &&
          housingStatus == other.housingStatus &&
          riskTolerance == other.riskTolerance &&
          realEstateProject == other.realEstateProject &&
          listEquals(providers3a, other.providers3a) &&
          arrivalAge == other.arrivalAge &&
          residencePermit == other.residencePermit &&
          familyChange == other.familyChange &&
          gender == other.gender &&
          targetRetirementAge == other.targetRetirementAge &&
          voiceCursorPreference == other.voiceCursorPreference &&
          n5IssuedThisWeek == other.n5IssuedThisWeek &&
          fragileModeEnteredAt == other.fragileModeEnteredAt &&
          listEquals(recentGravityEvents, other.recentGravityEvents) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hashAll([
        firstName,
        birthYear,
        dateOfBirth,
        canton,
        commune,
        nationality,
        residenceCountry,
        workCountry,
        workCanton,
        etatCivil,
        civilStatusNeedsConfirmation,
        civilStatusRawValue,
        nombreEnfants,
        conjoint,
        salaireBrutMensuel,
        monthlyNetIncomeDeclared,
        monthlyTaxProvisionDeclared,
        nombreDeMois,
        bonusPourcentage,
        employmentRate,
        employmentStatus,
        selfEmployedNetIncome,
        companyProfitAnnual,
        unemploymentContributionMonths,
        pillar3aAnnualContribution,
        monthlySavingsContribution,
        hasPillar3a,
        avsGapStatus,
        depenses,
        prevoyance,
        patrimoine,
        dettes,
        fiscal,
        lppRegulationReference,
        lppCapitalNoticeDeadline,
        pillar3aBeneficiaryClause,
        latestTaxDecisionReference,
        goalA,
        goalsB.length,
        plannedContributions.length,
        checkIns.length,
        housingStatus,
        riskTolerance,
        realEstateProject,
        providers3a.length,
        arrivalAge,
        residencePermit,
        familyChange,
        gender,
        targetRetirementAge,
        voiceCursorPreference,
        n5IssuedThisWeek,
        fragileModeEnteredAt,
        recentGravityEvents.length,
        createdAt,
        updatedAt,
      ]);

  // ════════════════════════════════════════════════════════════════
  //  COMPUTED PROPERTIES
  // ════════════════════════════════════════════════════════════════

  /// Age actuel — précis au jour si dateOfBirth est disponible,
  /// sinon fallback sur birthYear (précision ±1 an).
  /// CHAOS-3: Guard against invalid birthYear (e.g. 2100) producing negative age.
  /// B6-minimal (2026-04-18): this getter preserves the legacy
  /// "0 = data not available" sentinel for back-compat with readiness
  /// gates. NEW consumers should prefer [ageOrNull] which returns `null`
  /// on missing/invalid data so age-dependent logic can skip explicitly
  /// rather than silently computing with `age=0`.
  int get age {
    final a = ageOrNull;
    return a ?? 0;
  }

  /// Nullable age — returns `null` when birthYear/dateOfBirth are missing
  /// or invalid (e.g. future dates, birthYear < 1900, age > 150).
  ///
  /// Adopted by Wave B-minimal (2026-04-18) to replace the `age == 0`
  /// sentinel pattern that was silently corrupting age-dependent
  /// calculations (CapEngine rules `age >= 45`, simulators age comparisons,
  /// AVS contribution projections). Consumers MUST branch explicitly on
  /// null to either skip the age-dependent rule or prompt the user for
  /// their birth year.
  ///
  /// Sources: Panel 7 Perfection Gap finding #7, Panel archi review
  /// 2026-04-18 (30+ call-sites consume `profile.age` without null guard),
  /// Panel adversaire BUG 4 (CapEngine 10 call-sites).
  int? get ageOrNull {
    if (dateOfBirth != null) {
      final now = DateTime.now();
      int a = now.year - dateOfBirth!.year;
      if (now.month < dateOfBirth!.month ||
          (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
        a--;
      }
      // Invalid range (future dates clamp negative, impossibly old
      // exceeds 150): treat as "unknown".
      if (a < 0 || a > 150) return null;
      return a;
    }
    final currentYear = DateTime.now().year;
    // birthYear == 0 is the CoachProfile default (unset); treat as missing.
    if (birthYear == 0) return null;
    if (birthYear < 1900 || birthYear > currentYear + 1) return null;
    // Still allow currentYear - 10 .. currentYear + 1 window for newborns
    // (age can legitimately be < 10). But block truly-future birthYears.
    final age = currentYear - birthYear;
    if (age < 0 || age > 150) return null;
    return age;
  }

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

  /// Revenu brut annuel du couple.
  ///
  /// P2-19: When etatCivil == marie but conjoint == null, we return
  /// only the main user's income (safe fallback — never assume spouse income).
  double get revenuBrutAnnuelCouple =>
      revenuBrutAnnuel + (conjoint?.revenuBrutAnnuel ?? 0);

  /// P2-19: True when user declares married/concubinage but has no spouse data.
  /// Consumers should show a warning and avoid assuming spouse income/AVS rights.
  bool get isMissingConjointData => isCouple && conjoint == null;

  /// Permit/status may open a targeted collection flow, but prove no legal or
  /// financial jurisdiction by themselves.
  bool get hasCrossBorderProductContext =>
      residencePermit?.toUpperCase() == 'G' || employmentStatus == 'frontalier';

  /// Backward-compatible boolean for consumers that cannot represent unknown.
  /// Only complete, current canonical evidence may return true.
  bool get isCrossBorder =>
      frontierJurisdictionAt(DateTime.now()).crossBorder == true;

  /// Evaluate canonical frontier jurisdiction evidence at an explicit instant.
  ///
  /// This selects at most a candidate legal instrument. It never computes a
  /// tax result and never infers facts from permit, nationality or canton of
  /// residence.
  FrontierJurisdictionEvidence frontierJurisdictionAt(DateTime now) {
    final requiredPaths = <String>[
      'residenceCountry',
      'workCountry',
      if (workCountry?.value == 'CH') 'workCanton',
    ];
    final missing = <String>[];
    final stale = <String>[];

    Object? valueFor(String path) => switch (path) {
          'residenceCountry' => residenceCountry,
          'workCountry' => workCountry,
          'workCanton' => workCanton,
          _ => null,
        };

    for (final path in requiredPaths) {
      final source = dataSources[path];
      final timestamp = dataTimestamps[path];
      final known = valueFor(path) != null &&
          userProvidedFields.contains(path) &&
          (source == ProfileDataSource.userInput ||
              source == ProfileDataSource.certificate) &&
          timestamp != null &&
          !timestamp.isAfter(now) &&
          dataSourceDates.containsKey(path);
      if (!known) {
        missing.add(path);
        continue;
      }
      if (path == 'workCanton' &&
          FreshnessDecayService.annualNeedsRefresh(timestamp, now)) {
        stale.add(path);
      }
    }

    if (missing.isNotEmpty) {
      return FrontierJurisdictionEvidence(
        state: FrontierJurisdictionState.missing,
        jurisdictionReady: false,
        crossBorder: null,
        candidateTaxInstrument: null,
        missingFields: missing,
      );
    }
    if (stale.isNotEmpty) {
      return FrontierJurisdictionEvidence(
        state: FrontierJurisdictionState.stale,
        jurisdictionReady: false,
        crossBorder: null,
        candidateTaxInstrument: null,
        staleFields: stale,
      );
    }

    final residence = residenceCountry!.value;
    final work = workCountry!.value;
    final crossBorder = residence != work;
    if (residence == 'CH' && work == 'CH') {
      return FrontierJurisdictionEvidence(
        state: FrontierJurisdictionState.known,
        jurisdictionReady: true,
        crossBorder: false,
        candidateTaxInstrument: FrontierTaxInstrument.domestic,
      );
    }
    if (residence == 'FR' && work == 'CH' && workCanton?.value == 'GE') {
      return FrontierJurisdictionEvidence(
        state: FrontierJurisdictionState.known,
        jurisdictionReady: true,
        crossBorder: true,
        candidateTaxInstrument: FrontierTaxInstrument.cdi1966Article17,
      );
    }
    const accord1983Cantons = {
      'BE',
      'SO',
      'BS',
      'BL',
      'VD',
      'VS',
      'NE',
      'JU',
    };
    if (residence == 'FR' &&
        work == 'CH' &&
        accord1983Cantons.contains(workCanton?.value)) {
      return FrontierJurisdictionEvidence(
        state: FrontierJurisdictionState.known,
        jurisdictionReady: true,
        crossBorder: true,
        candidateTaxInstrument: FrontierTaxInstrument.accord1983Candidate,
      );
    }
    return FrontierJurisdictionEvidence(
      state: FrontierJurisdictionState.specialistOnly,
      jurisdictionReady: true,
      crossBorder: crossBorder,
      candidateTaxInstrument: null,
    );
  }

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
      // Dart normalizes month=0 → Dec of prev year, so this is safe in January.
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

  /// Detects the user's financial archetype.
  ///
  /// Basee sur nationalite, arrivalAge, employmentStatus, residencePermit.
  /// Voir ADR-20260223-archetype-driven-retirement.md.
  FinancialArchetype get archetype {
    // Cross-border: permis G
    if (residencePermit == 'G') return FinancialArchetype.crossBorder;

    // US citizen / FATCA
    if (nationality == 'US') return FinancialArchetype.expatUs;

    // Independent (check LPP status)
    if (employmentStatus == 'independant') {
      final hasLpp =
          prevoyance.avoirLppTotal != null && prevoyance.avoirLppTotal! > 0;
      return hasLpp
          ? FinancialArchetype.independentWithLpp
          : FinancialArchetype.independentNoLpp;
    }

    // Swiss native: nationality CH and arrived before 22 (or no arrival age)
    final isSwiss = nationality == null || nationality == 'CH';
    final arrivedEarly = arrivalAge == null || arrivalAge! < 22;

    if (isSwiss && arrivedEarly) return FinancialArchetype.swissNative;

    // Swiss returning after time abroad
    if (isSwiss && !arrivedEarly) return FinancialArchetype.returningSwiss;

    // EU/AELE expat
    const euCountries = {
      'AT',
      'BE',
      'BG',
      'HR',
      'CY',
      'CZ',
      'DK',
      'EE',
      'FI',
      'FR',
      'DE',
      'GR',
      'HU',
      'IS',
      'IE',
      'IT',
      'LV',
      'LI',
      'LT',
      'LU',
      'MT',
      'NL',
      'NO',
      'PL',
      'PT',
      'RO',
      'SK',
      'SI',
      'ES',
      'SE',
    };
    if (nationality != null && euCountries.contains(nationality)) {
      return FinancialArchetype.expatEu;
    }

    return FinancialArchetype.expatNonEu;
  }

  /// Whether the main user can contribute to pillar 3a.
  ///
  /// Returns false for US citizens/green card holders (FATCA — most 3a
  /// providers refuse US persons per LSFin compliance).
  /// Also delegates to [PrevoyanceProfile.canContribute3a] which may be
  /// set independently (e.g. when profile is loaded from a certificate).
  bool get canContribute3a {
    // US citizens with FATCA: blocked (most Swiss providers refuse)
    if (archetype == FinancialArchetype.expatUs) return false;
    if (nationality == 'US') return false;
    return prevoyance.canContribute3a;
  }

  /// Product/household context, not a legal-calculation predicate.
  bool get hasPartnerContext =>
      !civilStatusNeedsConfirmation &&
      (etatCivil == CoachCivilStatus.marie ||
          etatCivil == CoachCivilStatus.registeredPartnership ||
          etatCivil == CoachCivilStatus.concubinage);

  /// AVS marriage-equivalent civil status.
  ///
  /// This predicate deliberately says nothing about entitlement, scales,
  /// pension percentages, or judicial separation.
  bool get isAvsMarriageEquivalent =>
      !civilStatusNeedsConfirmation &&
      (etatCivil == CoachCivilStatus.marie ||
          etatCivil == CoachCivilStatus.registeredPartnership);

  bool get isAvsCohabiting =>
      !civilStatusNeedsConfirmation &&
      etatCivil == CoachCivilStatus.concubinage;

  /// Backward-compatible product-context alias.
  ///
  /// Financial/legal callers must use their domain-specific predicate rather
  /// than assuming every partner context follows marriage rules.
  bool get isCouple => hasPartnerContext;

  /// Canonical certificate-only readiness for AVS gap-sensitive consumers.
  AvsGapEvidence get avsGapEvidence {
    final selfYears = prevoyance.lacunesAVS;
    final selfCertified = selfYears != null &&
            selfYears >= 0 &&
            selfYears <= 44 &&
            dataSources[AvsGapEvidence.selfFieldPath] ==
                ProfileDataSource.certificate
        ? selfYears
        : null;

    final spouseRequired = isCouple;
    final spouseYears = conjoint?.prevoyance?.lacunesAVS;
    final spouseCertified = spouseYears != null &&
            spouseYears >= 0 &&
            spouseYears <= 44 &&
            dataSources[AvsGapEvidence.spouseFieldPath] ==
                ProfileDataSource.certificate
        ? spouseYears
        : null;

    final missingFieldPaths = <String>[
      if (selfCertified == null) AvsGapEvidence.selfFieldPath,
      if (spouseRequired && spouseCertified == null)
        AvsGapEvidence.spouseFieldPath,
    ];

    return AvsGapEvidence(
      selfCertifiedYears: selfCertified,
      spouseCertifiedYears: spouseCertified,
      spouseRequired: spouseRequired,
      maritalCapApplicable: isAvsMarriageEquivalent,
      declaredStatus: avsGapStatus,
      missingFieldPaths: missingFieldPaths,
    );
  }

  /// SafeMode activation flag — ACTIVE when ANY of three signals is true.
  ///
  /// Authoritative rule: RULES.md §1 (2026-04-18). Threshold = 0.33 (ASB 2014).
  ///
  /// Signal A — Consumer debt stress (binary wizard keys stored in dettes):
  ///   hasDette on creditConsommation/leasing > 0 (proxy for consumer debt).
  /// Signal B — Consumer debt-to-income ratio > 0.33 (ASB affordability).
  ///   Mortgage excess (above 0.33 × brut) also contributes if it pushes the
  ///   combined consumer ratio past 0.33.
  /// Signal C — Emergency fund shortfall (months_liquidity < 3).
  ///
  /// Edge cases per RULES.md §1:
  ///   E1: retiree — income ratios stay unavailable until the mobile model has
  ///       a reviewed official-pension evidence envelope.
  ///   E2: individual gate — no cross-spouse contamination.
  ///   E4: student (zero income, no debt, no housing) → false (vacuous).
  bool get isInDebtCrisis {
    // ── Signal A — consumer debt present (structural proxy) ──────────────────
    final hasConsumerDebt =
        (dettes.creditConsommation != null && dettes.creditConsommation! > 0) ||
            (dettes.leasing != null && dettes.leasing! > 0) ||
            (dettes.autresDettes != null && dettes.autresDettes! > 0);
    if (hasConsumerDebt) return true;

    // ── Net monthly income (E1: retiree, E4: student guard) ─────────────────
    double? netMensuel;
    if (salaireBrutMensuel > 0) {
      final breakdown = NetIncomeBreakdown.compute(
        grossSalary: salaireBrutMensuel * nombreDeMois,
        canton: canton,
        age: age,
      );
      netMensuel = breakdown.monthlyNetPayslip;
    } else if (employmentStatus == 'independant' &&
        selfEmployedNetIncome != null &&
        selfEmployedNetIncome! > 0) {
      netMensuel = selfEmployedNetIncome! / 12.0;
    } else if (employmentStatus == 'retraite') {
      // E1 — neither a legacy AVS amount nor LPP alone proves total retiree
      // income. Keep Signal B unavailable, but continue to explicit Signal C.
      netMensuel = null;
    } else {
      // E4 — zero income, no consumer debt, no housing → inactive (vacuous)
      return false;
    }

    // ── Signal B — consumer ratio > 0.33 (ASB 2014) ─────────────────────────
    if (netMensuel != null && netMensuel > 0) {
      final consumerMonthly = (dettes.mensualiteCreditConso ?? 0.0) +
          (dettes.mensualiteLeasing ?? 0.0);

      // Mortgage excess: only the portion above 0.33 × brut counts
      double mortgageExcess = 0.0;
      final brutMonthly = salaireBrutMensuel;
      if (brutMonthly > 0) {
        final mortgageCap = brutMonthly * 0.33;
        final mortgageMonthly = dettes.mensualiteHypotheque ?? 0.0;
        mortgageExcess = math.max(0.0, mortgageMonthly - mortgageCap);
      }

      final ratio = (consumerMonthly + mortgageExcess) / netMensuel;
      if (ratio > 0.33) return true;
    }

    // ── Signal C — emergency fund shortfall (< 3 months) ────────────────────
    const expenseFieldPaths = <String>{
      'depenses.loyer',
      'depenses.assuranceMaladie',
      'depenses.electricite',
      'depenses.transport',
      'depenses.telecom',
      'depenses.fraisMedicaux',
      'depenses.autresDepensesFixes',
    };
    final hasDeclaredRetireeExpenses =
        userProvidedFields.contains('monthlyExpenses') ||
            expenseFieldPaths.any((path) {
              final source = dataSources[path];
              return source != null && source != ProfileDataSource.estimated;
            });
    final monthlyExpenses = netMensuel != null
        ? (depenses.totalMensuel > 0 ? depenses.totalMensuel : netMensuel * 0.6)
        : (hasDeclaredRetireeExpenses ? depenses.totalMensuel : 0.0);
    if (monthlyExpenses > 0) {
      final monthsLiquidity = patrimoine.epargneLiquide / monthlyExpenses;
      if (monthsLiquidity < 3) return true;
    }

    return false;
  }

  /// Copie le profil avec des champs optionnels mis a jour.
  /// Utilise par le annual refresh pour persister updatedAt, prevoyance, etc.
  CoachProfile copyWith({
    String? firstName,
    int? birthYear,
    DateTime? dateOfBirth,
    String? canton,
    String? commune,
    String? nationality,
    Object? residenceCountry = _keepJurisdictionValue,
    Object? workCountry = _keepJurisdictionValue,
    Object? workCanton = _keepJurisdictionValue,
    CoachCivilStatus? etatCivil,
    bool? civilStatusNeedsConfirmation,
    String? civilStatusRawValue,
    int? nombreEnfants,
    ConjointProfile? conjoint,
    double? salaireBrutMensuel,
    double? monthlyNetIncomeDeclared,
    double? monthlyTaxProvisionDeclared,
    double? nombreDeMois,
    double? bonusPourcentage,
    double? employmentRate,
    String? employmentStatus,
    double? selfEmployedNetIncome,
    double? companyProfitAnnual,
    int? unemploymentContributionMonths,
    double? pillar3aAnnualContribution,
    double? monthlySavingsContribution,
    bool? hasPillar3a,
    AvsGapStatus? avsGapStatus,
    DepensesProfile? depenses,
    PrevoyanceProfile? prevoyance,
    PatrimoineProfile? patrimoine,
    DetteProfile? dettes,
    FiscalProfile? fiscal,
    Object? lppRegulationReference = _keepSpecialistReferenceValue,
    Object? lppCapitalNoticeDeadline = _keepSpecialistReferenceValue,
    Object? pillar3aBeneficiaryClause = _keepSpecialistReferenceValue,
    Object? latestTaxDecisionReference = _keepSpecialistReferenceValue,
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
    String? gender,
    int? targetRetirementAge,
    Map<String, dynamic>? initialProjectionSnapshot,
    Map<String, ProfileDataSource>? dataSources,
    Map<String, DateTime>? dataTimestamps,
    Map<String, DateTime?>? dataSourceDates,
    Set<String>? userProvidedFields,
    DateTime? createdAt,
    DateTime? updatedAt,
    FinancialLiteracyLevel? financialLiteracyLevel,
    String? primaryFocus,
    VoicePreference? voiceCursorPreference,
    int? n5IssuedThisWeek,
    DateTime? fragileModeEnteredAt,
    List<Map<String, dynamic>>? recentGravityEvents,
  }) {
    final changesResidenceCountry =
        !identical(residenceCountry, _keepJurisdictionValue);
    final changesWorkCountry = !identical(workCountry, _keepJurisdictionValue);
    final changesWorkCanton = !identical(workCanton, _keepJurisdictionValue);
    final effectiveResidenceCountry = changesResidenceCountry
        ? residenceCountry as CountryCode?
        : this.residenceCountry;
    final effectiveWorkCountry =
        changesWorkCountry ? workCountry as CountryCode? : this.workCountry;
    final effectiveWorkCanton =
        changesWorkCanton ? workCanton as SwissCantonCode? : this.workCanton;
    final effectiveDataSources =
        Map<String, ProfileDataSource>.from(dataSources ?? this.dataSources);
    final effectiveDataTimestamps =
        Map<String, DateTime>.from(dataTimestamps ?? this.dataTimestamps);
    final effectiveDataSourceDates =
        Map<String, DateTime?>.from(dataSourceDates ?? this.dataSourceDates);
    final effectiveUserProvidedFields =
        Set<String>.from(userProvidedFields ?? this.userProvidedFields);
    void purgeJurisdiction(String path) {
      effectiveDataSources.remove(path);
      effectiveDataTimestamps.remove(path);
      effectiveDataSourceDates.remove(path);
      effectiveUserProvidedFields.remove(path);
    }

    if (changesResidenceCountry && effectiveResidenceCountry == null) {
      purgeJurisdiction('residenceCountry');
    }
    if (changesWorkCountry && effectiveWorkCountry == null) {
      purgeJurisdiction('workCountry');
    }
    if (changesWorkCanton && effectiveWorkCanton == null) {
      purgeJurisdiction('workCanton');
    }
    final effectiveCivilStatus = etatCivil ?? this.etatCivil;
    final effectiveCivilStatusNeedsConfirmation =
        civilStatusNeedsConfirmation ??
            (etatCivil != null ? false : this.civilStatusNeedsConfirmation);
    final preservesPartnerFacts = effectiveCivilStatusNeedsConfirmation ||
        effectiveCivilStatus == CoachCivilStatus.marie ||
        effectiveCivilStatus == CoachCivilStatus.registeredPartnership ||
        effectiveCivilStatus == CoachCivilStatus.concubinage;
    return CoachProfile(
      firstName: firstName ?? this.firstName,
      birthYear: birthYear ?? this.birthYear,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      canton: canton ?? this.canton,
      commune: commune ?? this.commune,
      nationality: nationality ?? this.nationality,
      residenceCountry: effectiveResidenceCountry,
      workCountry: effectiveWorkCountry,
      workCanton: effectiveWorkCanton,
      etatCivil: effectiveCivilStatus,
      civilStatusNeedsConfirmation: effectiveCivilStatusNeedsConfirmation,
      civilStatusRawValue: effectiveCivilStatusNeedsConfirmation
          ? (civilStatusRawValue ?? this.civilStatusRawValue)
          : null,
      nombreEnfants: nombreEnfants ?? this.nombreEnfants,
      // A confirmed non-partner status clears partner facts. Ambiguous legacy
      // status preserves them while every legal partner predicate stays false.
      conjoint: (etatCivil != null && !preservesPartnerFacts)
          ? null
          : (conjoint ?? this.conjoint),
      salaireBrutMensuel: salaireBrutMensuel ?? this.salaireBrutMensuel,
      monthlyNetIncomeDeclared:
          monthlyNetIncomeDeclared ?? this.monthlyNetIncomeDeclared,
      monthlyTaxProvisionDeclared:
          monthlyTaxProvisionDeclared ?? this.monthlyTaxProvisionDeclared,
      nombreDeMois: nombreDeMois ?? this.nombreDeMois,
      bonusPourcentage: bonusPourcentage ?? this.bonusPourcentage,
      employmentRate: employmentRate ?? this.employmentRate,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      selfEmployedNetIncome:
          selfEmployedNetIncome ?? this.selfEmployedNetIncome,
      companyProfitAnnual: companyProfitAnnual ?? this.companyProfitAnnual,
      unemploymentContributionMonths:
          unemploymentContributionMonths ?? this.unemploymentContributionMonths,
      pillar3aAnnualContribution:
          pillar3aAnnualContribution ?? this.pillar3aAnnualContribution,
      monthlySavingsContribution:
          monthlySavingsContribution ?? this.monthlySavingsContribution,
      hasPillar3a: hasPillar3a ?? this.hasPillar3a,
      avsGapStatus: avsGapStatus ?? this.avsGapStatus,
      depenses: depenses ?? this.depenses,
      prevoyance: prevoyance ?? this.prevoyance,
      patrimoine: patrimoine ?? this.patrimoine,
      dettes: dettes ?? this.dettes,
      fiscal: fiscal ?? this.fiscal,
      lppRegulationReference:
          identical(lppRegulationReference, _keepSpecialistReferenceValue)
              ? this.lppRegulationReference
              : lppRegulationReference as SpecialistReferenceEvidence?,
      lppCapitalNoticeDeadline:
          identical(lppCapitalNoticeDeadline, _keepSpecialistReferenceValue)
              ? this.lppCapitalNoticeDeadline
              : lppCapitalNoticeDeadline as SpecialistReferenceEvidence?,
      pillar3aBeneficiaryClause:
          identical(pillar3aBeneficiaryClause, _keepSpecialistReferenceValue)
              ? this.pillar3aBeneficiaryClause
              : pillar3aBeneficiaryClause as SpecialistReferenceEvidence?,
      latestTaxDecisionReference:
          identical(latestTaxDecisionReference, _keepSpecialistReferenceValue)
              ? this.latestTaxDecisionReference
              : latestTaxDecisionReference as SpecialistReferenceEvidence?,
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
      gender: gender ?? this.gender,
      targetRetirementAge: targetRetirementAge ?? this.targetRetirementAge,
      initialProjectionSnapshot:
          initialProjectionSnapshot ?? this.initialProjectionSnapshot,
      dataSources: effectiveDataSources,
      dataTimestamps: effectiveDataTimestamps,
      dataSourceDates: effectiveDataSourceDates,
      inferDataSources: false,
      userProvidedFields: effectiveUserProvidedFields,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      financialLiteracyLevel:
          financialLiteracyLevel ?? this.financialLiteracyLevel,
      primaryFocus: primaryFocus ?? this.primaryFocus,
      voiceCursorPreference:
          voiceCursorPreference ?? this.voiceCursorPreference,
      n5IssuedThisWeek: n5IssuedThisWeek ?? this.n5IssuedThisWeek,
      fragileModeEnteredAt: fragileModeEnteredAt ?? this.fragileModeEnteredAt,
      recentGravityEvents: recentGravityEvents ?? this.recentGravityEvents,
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

  /// Compatibility facade for consumers that start from a [CoachProfile].
  ///
  /// Projection logic stays in one place so debt tools cannot drift from the
  /// budget, MintState, or the declared tax and partner-income facts.
  BudgetInputs toBudgetInputs() => BudgetInputs.fromCoachProfile(this);

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
      case CoachCivilStatus.registeredPartnership:
        civilStatus = EtatCivil.registeredPartnership;
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
      has3a: hasPillar3a ?? prevoyance.nombre3a > 0,
      montant3a: pillar3aAnnualContribution ?? total3aMensuel * 12,
      hasLpp: (prevoyance.avoirLppTotal ?? 0) > 0,
      avoirLpp: prevoyance.avoirLppTotal ?? 0,
      lacuneLpp: prevoyance.lacuneRachatRestante,
      tauxActivite: employmentRate,
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
    // Schema migration: handle older versions if needed.
    final version = json['schemaVersion'] as int? ?? 0;
    // Version 0 (pre-schema) and version 1 share the same format.
    // Future migrations: if (version < 2) { ... migrate fields ... }
    assert(version <= schemaVersion,
        'CoachProfile schema version $version is newer than supported $schemaVersion');
    final serializedCivilStatus = json['etatCivil'] as String?;
    final retainedCivilStatusRaw =
        json['civilStatusRawValue'] as String? ?? serializedCivilStatus;
    final civilStatusNeedsConfirmation =
        (json['civilStatusNeedsConfirmation'] as bool? ?? false) ||
            _isAmbiguousCivilStatus(retainedCivilStatusRaw);
    return CoachProfile(
      firstName: json['firstName'] as String?,
      birthYear: (json['birthYear'] as int?) ?? 1980,
      dateOfBirth: _parseSupportedAdultBirthDate(
        json['dateOfBirth'],
        now: DateTime.now(),
      ),
      canton: (json['canton'] as String?) ?? 'ZH',
      commune: json['commune'] as String?,
      nationality: json['nationality'] as String?,
      residenceCountry: CountryCode.tryParse(json['residenceCountry']),
      workCountry: CountryCode.tryParse(json['workCountry']),
      workCanton: SwissCantonCode.tryParse(json['workCanton']),
      etatCivil: civilStatusNeedsConfirmation
          ? CoachCivilStatus.celibataire
          : _parseCivilStatus(serializedCivilStatus),
      civilStatusNeedsConfirmation: civilStatusNeedsConfirmation,
      civilStatusRawValue:
          civilStatusNeedsConfirmation ? retainedCivilStatusRaw : null,
      nombreEnfants: json['nombreEnfants'] ?? 0,
      conjoint: json['conjoint'] != null
          ? ConjointProfile.fromJson(json['conjoint'])
          : null,
      salaireBrutMensuel: (json['salaireBrutMensuel'] as num?)?.toDouble() ?? 0,
      monthlyNetIncomeDeclared:
          (json['monthlyNetIncomeDeclared'] as num?)?.toDouble(),
      monthlyTaxProvisionDeclared:
          (json['monthlyTaxProvisionDeclared'] as num?)?.toDouble(),
      nombreDeMois: (json['nombreDeMois'] as num?)?.toDouble() ?? 12.0,
      bonusPourcentage: (json['bonusPourcentage'] as num?)?.toDouble(),
      employmentRate: IncomeConversionCalculator.clampEmploymentRatePercent(
        (json['employmentRate'] as num?)?.toDouble(),
      ),
      employmentStatus:
          _parseEmploymentStatus(json['employmentStatus'] as String?),
      selfEmployedNetIncome:
          (json['selfEmployedNetIncome'] as num?)?.toDouble(),
      companyProfitAnnual: (json['companyProfitAnnual'] as num?)?.toDouble(),
      unemploymentContributionMonths:
          json['unemploymentContributionMonths'] as int?,
      pillar3aAnnualContribution:
          (json['pillar3aAnnualContribution'] as num?)?.toDouble(),
      monthlySavingsContribution:
          (json['monthlySavingsContribution'] as num?)?.toDouble(),
      hasPillar3a: json['hasPillar3a'] as bool?,
      avsGapStatus: _parseAvsGapStatus(json['avsGapStatus'] as String?),
      lppRegulationReference: SpecialistReferenceEvidence.tryFromJson(
        json['lppRegulationReference'],
        expectedKind: SpecialistReferenceKind.lppRegulation,
      ),
      lppCapitalNoticeDeadline: SpecialistReferenceEvidence.tryFromJson(
        json['lppCapitalNoticeDeadline'],
        expectedKind: SpecialistReferenceKind.lppCapitalNotice,
      ),
      pillar3aBeneficiaryClause: SpecialistReferenceEvidence.tryFromJson(
        json['pillar3aBeneficiaryClause'],
        expectedKind: SpecialistReferenceKind.pillar3aBeneficiaryClause,
      ),
      latestTaxDecisionReference: SpecialistReferenceEvidence.tryFromJson(
        json['latestTaxDecisionReference'],
        expectedKind: SpecialistReferenceKind.taxAssessmentDecision,
      ),
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
      goalA: json['goalA'] != null
          ? GoalA.fromJson(json['goalA'])
          : GoalA(
              type: GoalAType.retraite, targetDate: DateTime(2035), label: ''),
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
      gender: json['gender'] as String?,
      targetRetirementAge: json['targetRetirementAge'] as int?,
      initialProjectionSnapshot:
          json['initialProjectionSnapshot'] as Map<String, dynamic>?,
      dataSources: <String, ProfileDataSource>{
        for (final entry
            in ((json['dataSources'] as Map<String, dynamic>?) ?? const {})
                .entries)
          if (!entry.key.startsWith('fiscal.'))
            entry.key: ProfileDataSource.values.firstWhere(
              (source) => source.name == entry.value,
              orElse: () => ProfileDataSource.estimated,
            ),
      },
      dataTimestamps: <String, DateTime>{
        for (final entry
            in ((json['dataTimestamps'] as Map<String, dynamic>?) ?? const {})
                .entries)
          if (!entry.key.startsWith('fiscal.'))
            entry.key: DateTime.tryParse(entry.value as String? ?? '') ??
                DateTime.now(),
      },
      dataSourceDates: <String, DateTime?>{
        for (final entry
            in ((json['dataSourceDates'] as Map<String, dynamic>?) ?? const {})
                .entries)
          if (!entry.key.startsWith('fiscal.'))
            entry.key: entry.value == null
                ? null
                : DateTime.tryParse(entry.value.toString()),
      },
      inferDataSources: !json.containsKey('dataSources'),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      financialLiteracyLevel: FinancialLiteracyLevel.values.firstWhere(
        (e) => e.name == json['financialLiteracyLevel'],
        orElse: () => FinancialLiteracyLevel.beginner,
      ),
      primaryFocus: json['primaryFocus'] as String?,
      voiceCursorPreference:
          _parseVoicePreference(json['voiceCursorPreference']),
      n5IssuedThisWeek: (json['n5IssuedThisWeek'] as int?) ?? 0,
      fragileModeEnteredAt: json['fragileModeEnteredAt'] != null
          ? DateTime.tryParse(json['fragileModeEnteredAt'] as String)
          : null,
      recentGravityEvents: (json['recentGravityEvents'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      userProvidedFields: (json['userProvidedFields'] as List?)
              ?.map((e) => e as String)
              .toSet() ??
          const {},
    );
  }

  /// Parse VoicePreference from JSON; legacy/missing/invalid → direct (default).
  static VoicePreference _parseVoicePreference(dynamic raw) {
    if (raw == null) return VoicePreference.direct;
    final s = raw.toString();
    for (final v in VoicePreference.values) {
      if (v.name == s) return v;
    }
    // Invalid value: fall back to default. Phase 11 will log this.
    return VoicePreference.direct;
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'firstName': firstName,
        'birthYear': birthYear,
        'dateOfBirth': dateOfBirth?.toIso8601String().split('T').first,
        'canton': canton,
        'commune': commune,
        'nationality': nationality,
        'residenceCountry': residenceCountry?.value,
        'workCountry': workCountry?.value,
        'workCanton': workCanton?.value,
        'etatCivil': etatCivil.name,
        'civilStatusNeedsConfirmation': civilStatusNeedsConfirmation,
        'civilStatusRawValue': civilStatusRawValue,
        'nombreEnfants': nombreEnfants,
        'conjoint': conjoint?.toJson(),
        'salaireBrutMensuel': salaireBrutMensuel,
        'monthlyNetIncomeDeclared': monthlyNetIncomeDeclared,
        'monthlyTaxProvisionDeclared': monthlyTaxProvisionDeclared,
        'nombreDeMois': nombreDeMois,
        'bonusPourcentage': bonusPourcentage,
        'employmentRate': employmentRate,
        'employmentStatus': employmentStatusToCanonical(employmentStatus),
        'selfEmployedNetIncome': selfEmployedNetIncome,
        'companyProfitAnnual': companyProfitAnnual,
        'unemploymentContributionMonths': unemploymentContributionMonths,
        'pillar3aAnnualContribution': pillar3aAnnualContribution,
        'monthlySavingsContribution': monthlySavingsContribution,
        'hasPillar3a': hasPillar3a,
        'avsGapStatus': _avsGapStatusToCanonical(avsGapStatus),
        'lppRegulationReference': lppRegulationReference?.toJson(),
        'lppCapitalNoticeDeadline': lppCapitalNoticeDeadline?.toJson(),
        'pillar3aBeneficiaryClause': pillar3aBeneficiaryClause?.toJson(),
        'latestTaxDecisionReference': latestTaxDecisionReference?.toJson(),
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
        'gender': gender,
        'targetRetirementAge': targetRetirementAge,
        'initialProjectionSnapshot': initialProjectionSnapshot,
        'dataSources': <String, String>{
          for (final entry in dataSources.entries)
            if (!entry.key.startsWith('fiscal.')) entry.key: entry.value.name,
        },
        'dataTimestamps': <String, String>{
          for (final entry in dataTimestamps.entries)
            if (!entry.key.startsWith('fiscal.'))
              entry.key: entry.value.toIso8601String(),
        },
        'dataSourceDates': <String, String?>{
          for (final entry in dataSourceDates.entries)
            if (!entry.key.startsWith('fiscal.'))
              entry.key: entry.value?.toIso8601String(),
        },
        'userProvidedFields': userProvidedFields.toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'financialLiteracyLevel': financialLiteracyLevel.name,
        'primaryFocus': primaryFocus,
        'voiceCursorPreference': voiceCursorPreference.name,
        'n5IssuedThisWeek': n5IssuedThisWeek,
        'fragileModeEnteredAt': fragileModeEnteredAt?.toIso8601String(),
        'recentGravityEvents': recentGravityEvents,
      };

  // ════════════════════════════════════════════════════════════════
  //  FACTORY: FROM WIZARD ANSWERS
  // ════════════════════════════════════════════════════════════════

  /// Construit un CoachProfile a partir des reponses du wizard.
  ///
  /// Mapping des 27 cles wizard → champs CoachProfile.
  /// Pour les champs que le wizard ne collecte pas, des estimations
  /// raisonnables sont utilisees (standards suisses).
  factory CoachProfile.fromWizardAnswers(
    Map<String, dynamic> answers, {
    DateTime Function()? now,
    PartnerAccountabilityBinding? partnerAccountabilityBinding,
    bool enforcePartnerAccountability = false,
  }) {
    bool hasResolvedAnswer(String key) =>
        answers.containsKey(key) &&
        answers[key] != null &&
        answers[key] != '__secure__';
    final backendUnknownPaths = (answers[coachBackendUnknownPathsKey] is List)
        ? (answers[coachBackendUnknownPathsKey] as List)
            .whereType<String>()
            .toSet()
        : const <String>{};
    bool isBackendUnknown(String path) => backendUnknownPaths.contains(path);

    var fiscal = _fiscalFromWizardAnswers(answers);
    // ── Identite ────────────────────────────────────────────
    final firstName = answers['q_firstname'] as String?;
    // CHAOS-78: Never default to 1990 — unknown birthYear stays 0
    // (age getter returns 0 for invalid birthYear, signaling "data missing").
    final birthYear = _parseInt(answers['q_birth_year']) ?? 0;
    final dobRaw = answers['q_date_of_birth'];
    final ageNow = (now ?? DateTime.now)();
    final dateOfBirth = _parseSupportedAdultBirthDate(
      dobRaw,
      now: ageNow,
    );
    final rawCanton = answers['q_canton'];
    final resolvedCanton = rawCanton is String
        ? resolveCanton(rawCanton)
        : const ResolvedCanton(
            code: cantonFallbackDefault,
            isResolved: false,
          );
    final canton = resolvedCanton.code;
    final commune = answers['q_commune'] as String?;
    final residenceCountry =
        CountryCode.tryParse(answers['q_residence_country']);
    final workCountry = CountryCode.tryParse(answers['q_work_country']);
    final workCanton = SwissCantonCode.tryParse(answers['q_work_canton']);
    final gender = answers['q_gender'] as String?;
    // Use precise age from dateOfBirth if available
    final int age;
    if (dateOfBirth != null) {
      age = ageNow.year -
          dateOfBirth.year -
          ((ageNow.month < dateOfBirth.month ||
                  (ageNow.month == dateOfBirth.month &&
                      ageNow.day < dateOfBirth.day))
              ? 1
              : 0);
    } else if (birthYear >= 1900) {
      age = ageNow.year - birthYear;
    } else {
      // No birth data available — age 0 signals "data missing" to readiness gates.
      age = 0;
    }

    // Civil status mapping
    final civilStatusRaw = answers['q_civil_status'] as String?;
    final civilStatusNeedsConfirmation =
        _isAmbiguousCivilStatus(civilStatusRaw);
    final etatCivil = civilStatusNeedsConfirmation
        ? CoachCivilStatus.celibataire
        : _parseCivilStatus(civilStatusRaw);

    // Children
    final childrenRaw = answers['q_children'];
    final nombreEnfants = _parseInt(childrenRaw) ?? 0;

    // ── Revenus ─────────────────────────────────────────────
    // FIX-P0-2: Normalize to lowercase — "Yearly" (capitalized) was not
    // recognized, causing annual salary to be treated as monthly.
    final payFrequency = (answers['q_pay_frequency'] as String?)
            ?.toLowerCase() ??
        (answers.containsKey('q_self_employed_income') ? 'yearly' : 'monthly');
    final selfEmployedNetIncome =
        _parseDouble(answers['q_self_employed_income']);
    final companyProfitAnnual =
        _parseDouble(answers['q_company_profit_annual_chf']);
    final netIncomeRaw = _parseDouble(answers['q_net_income_period_chf']);
    final netIncome = netIncomeRaw ?? selfEmployedNetIncome ?? 5000;

    // Convert to monthly net income based on pay frequency
    double monthlyNetIncome;
    if (payFrequency == 'yearly' || payFrequency == 'annuel') {
      monthlyNetIncome = netIncome / 12;
    } else {
      monthlyNetIncome = netIncome;
    }
    final monthlyNetIncomeDeclared = netIncomeRaw == null
        ? null
        : (payFrequency == 'yearly' || payFrequency == 'annuel')
            ? netIncomeRaw / 12
            : netIncomeRaw;
    // Prefer direct gross salary when stored by updateFromSmartFlow
    // (avoids net→gross roundtrip rounding: 120'000 → net → 113'793 brut).
    // Fallback: net → brut via Swiss social charges ≈ 13%.
    // (AVS 5.3% + LPP ~5% + AC ~1.1% + AANP ~1% ≈ 12.5%, arrondi 13%)
    // Source: OFAS barème cotisations 2025. Ceci est une estimation;
    // le taux réel dépend du plan LPP et du canton.
    const double socialChargesRate =
        IncomeConversionCalculator.fallbackSwissSocialChargesRate;
    final nombreDeMois = IncomeConversionCalculator.normalizeAnnualSalaryMonths(
      _parseDouble(answers['q_nombre_mois']),
    );
    final grossSalaryDirect = _parseDouble(answers['q_gross_salary_annual']);
    final salaireBrutMensuel = grossSalaryDirect != null
        ? IncomeConversionCalculator.monthlyGrossFromAnnualGross(
            grossSalaryDirect,
            months: nombreDeMois,
          )
        : monthlyNetIncome / (1 - socialChargesRate);
    final employmentRate =
        IncomeConversionCalculator.clampEmploymentRatePercent(
      _parseDouble(answers['q_employment_rate']),
    );
    final annualBonus = _parseDouble(answers['q_annual_bonus']);
    final annualBaseSalary = IncomeConversionCalculator.annualGrossFromMonthly(
      monthlyGross: salaireBrutMensuel,
      months: nombreDeMois,
    );
    final bonusPourcentage =
        IncomeConversionCalculator.bonusPercentageFromAnnualBonus(
              annualBonus: annualBonus,
              annualBaseSalary: annualBaseSalary,
            ) ??
            _parseDouble(answers['q_bonus_percentage']);

    // Employment status mapping
    final employmentRaw = (answers['q_employment_status'] as String?) ??
        (selfEmployedNetIncome != null ? 'independant' : null);
    final employmentStatus = _parseEmploymentStatus(employmentRaw);
    final unemploymentContributionMonthsRaw =
        _parseInt(answers['q_unemployment_contribution_months']);
    final unemploymentContributionMonths =
        unemploymentContributionMonthsRaw?.clamp(0, 24).toInt();

    // ── Depenses ────────────────────────────────────────────
    final parsedHousingCost =
        _parseDouble(answers['q_housing_cost_period_chf']);
    final explicitHousingCost = parsedHousingCost != null &&
            parsedHousingCost.isFinite &&
            parsedHousingCost >= 0
        ? parsedHousingCost
        : null;
    final housingCost = explicitHousingCost ?? 1500;
    final housingFrequency = answers['q_housing_pay_frequency'] as String?;
    double monthlyHousing;
    if (housingFrequency == 'yearly' || housingFrequency == 'annuel') {
      monthlyHousing = housingCost / 12;
    } else {
      monthlyHousing = housingCost;
    }

    // Use actual LAMal from onboarding if available, otherwise estimate
    final parsedLamalFromOnboarding =
        _parseDouble(answers['q_lamal_premium_monthly_chf']);
    final lamalFromOnboarding = parsedLamalFromOnboarding != null &&
            parsedLamalFromOnboarding.isFinite &&
            parsedLamalFromOnboarding >= 0
        ? parsedLamalFromOnboarding
        : null;
    final assuranceMaladie =
        lamalFromOnboarding ?? _estimateAssuranceMaladie(canton);

    // Tax provision and other fixed costs are separate canonical facts.
    final monthlyTaxProvisionDeclared =
        _parseDouble(answers['q_tax_provision_monthly_chf']);
    final otherFixed = _parseDouble(answers['q_other_fixed_costs_monthly_chf']);

    // _coach_depenses_* keys are written by updateInline() for fields that
    // have no canonical wizard question (electricite, transport, telecom,
    // fraisMedicaux, autresDepensesFixes). They survive app restarts.
    final depenses = DepensesProfile(
      loyer: monthlyHousing,
      assuranceMaladie: assuranceMaladie,
      electricite: _parseDouble(answers['_coach_depenses_electricite']),
      transport: _parseDouble(answers['_coach_depenses_transport']),
      telecom: _parseDouble(answers['_coach_depenses_telecom']),
      fraisMedicaux: _parseDouble(answers['_coach_depenses_frais_medicaux']),
      autresDepensesFixes:
          otherFixed ?? _parseDouble(answers['_coach_depenses_autres']),
    );

    // ── Prevoyance ──────────────────────────────────────────
    final hasVoluntaryLpp = answers.containsKey('q_has_voluntary_lpp')
        ? _parseBool(answers['q_has_voluntary_lpp'])
        : null;
    final hasPensionFund = answers.containsKey('q_has_pension_fund')
        ? _parseBool(answers['q_has_pension_fund'])
        : hasVoluntaryLpp;
    final lppBuybackAvailable =
        _parseDouble(answers['q_lpp_buyback_available']);
    final has3a = answers.containsKey('q_has_3a')
        ? _parseBool(answers['q_has_3a'])
        : null;
    final contribution3a =
        _parseDouble(answers['q_3a_annual_contribution']) ?? 0;
    final explicit3aAccounts = _parseInt(answers['q_3a_accounts_count']);
    final nombre3a =
        has3a == false ? 0 : explicit3aAccounts ?? (has3a == true ? 1 : 0);
    final avsLacunesStatus = answers['q_avs_lacunes_status'] as String?;
    // Compute arrivalAge for expats who arrived late in Switzerland.
    // Used by _estimateLppAvoir() to start LPP bonification loop at
    // max(25, arrivalAge) instead of always 25.
    int? computedArrivalAge;
    switch (avsLacunesStatus) {
      case 'arrived_late':
        final arrivalYear = _parseInt(answers['q_avs_arrival_year']);
        if (arrivalYear != null) {
          computedArrivalAge = arrivalYear - birthYear;
        }
      case 'lived_abroad':
      case 'unknown':
      case 'no_gaps':
      case 'no':
      default:
    }
    final rawAvsYears = _parseInt(answers['q_avs_contribution_years']);
    // P1-6: AVS contribution years can't exceed (age - 20) — contributions
    // start at ~20 (LAVS art. 3). Also capped at 44 (max duree cotisation).
    final avsYears = rawAvsYears?.clamp(0, (age - 20).clamp(0, 44));

    // ── Extraction-persisted fields (survive restart) ─────────
    final hasTypedLppRoot = FeatureFlags.typedLppEvidence &&
        answers.containsKey('_coach_lpp_evidence_v1');
    final typedLppSelf = FeatureFlags.typedLppEvidence
        ? LppEvidenceSelector.selectSelf(
            answers['_coach_lpp_evidence_v1'],
            now: now,
          )
        : null;
    final expectedManualPartnerOwnerId = FeatureFlags.typedLppEvidence
        ? LppEvidenceSelector.manualPartnerOwnerId(
            answers['_coach_lpp_evidence_v1'],
          )
        : null;
    final expectedManualPartnerSnapshotId = FeatureFlags.typedLppEvidence
        ? LppEvidenceSelector.manualPartnerSnapshotId(
            answers['_coach_lpp_evidence_v1'],
          )
        : null;
    final accountabilityOwnerMatches = !enforcePartnerAccountability ||
        expectedManualPartnerOwnerId != null &&
            expectedManualPartnerSnapshotId != null &&
            partnerAccountabilityBinding?.manualPartnerOwnerId ==
                expectedManualPartnerOwnerId &&
            partnerAccountabilityBinding?.lppSnapshotId ==
                expectedManualPartnerSnapshotId &&
            partnerAccountabilityBinding!.isCurrentAt(
              (now ?? DateTime.now)().toUtc(),
            );
    final rawTypedLppManualPartner = expectedManualPartnerOwnerId == null
        ? null
        : LppEvidenceSelector.selectManualPartner(
            answers['_coach_lpp_evidence_v1'],
            expectedOwnerId: expectedManualPartnerOwnerId,
            now: now,
          );
    final typedLppManualPartner = accountabilityOwnerMatches
        ? _mergeCurrentManualPartnerFacts(rawTypedLppManualPartner)
        : _restoreIndependentManualPartnerFacts(rawTypedLppManualPartner);
    double? availableLppValue(LppEvidenceFact? fact) {
      if (fact == null || fact.status != LppEvidenceStatus.available) {
        return null;
      }
      return fact.value;
    }

    double? typedLppValue(LppEvidenceFactKey key) =>
        availableLppValue(typedLppSelf?.facts[key]);
    double? typedManualPartnerLppValue(LppEvidenceFactKey key) =>
        availableLppValue(typedLppManualPartner?.facts[key]);
    final coachAvoirLppOblig = hasTypedLppRoot
        ? typedLppValue(LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf)
        : _parseDouble(answers['_coach_avoir_lpp_oblig']);
    final coachAvoirLppSuroblig = hasTypedLppRoot
        ? typedLppValue(
            LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf,
          )
        : _parseDouble(answers['_coach_avoir_lpp_suroblig']);
    final parsedCoachTauxConversion = hasTypedLppRoot
        ? typedLppValue(LppEvidenceFactKey.mandatoryConversionRateRatio)
        : _parseDouble(answers['_coach_taux_conversion']);
    final coachTauxConversion = parsedCoachTauxConversion != null &&
            parsedCoachTauxConversion.isFinite &&
            parsedCoachTauxConversion > 0
        ? parsedCoachTauxConversion
        : null;
    final coachTauxConvSuroblig = hasTypedLppRoot
        ? typedLppValue(
            LppEvidenceFactKey.extraMandatoryConversionRateRatio,
          )
        : _parseDouble(answers['_coach_taux_conversion_suroblig']);
    final coachRachatMax = hasTypedLppRoot
        ? typedLppValue(LppEvidenceFactKey.maximumBuybackCapitalChf)
        : _parseDouble(answers['_coach_rachat_maximum']);
    final coachSalaireAssure = hasTypedLppRoot
        ? typedLppValue(LppEvidenceFactKey.insuredSalaryAnnualChf)
        : _parseDouble(answers['_coach_salaire_assure']);
    final coachRendementCaisse = hasTypedLppRoot
        ? typedLppValue(LppEvidenceFactKey.fundReturnRateRatio)
        : _parseDouble(answers['_coach_rendement_caisse']);
    final coachAvsLacunes = _parseInt(answers['_coach_avs_lacunes']);
    final coachAvsRenteEstimee =
        _parseDouble(answers['_coach_avs_rente_estimee']);
    final coachAvsRamd = _parseDouble(answers['_coach_avs_ramd']);
    final coachAvsBonificationsEducatives =
        _parseInt(answers['_coach_avs_bonifications_educatives']);

    // Estimate LPP total based on age and salary (rough Swiss average).
    // Si une valeur reelle a ete saisie via annual refresh, on la prefere.
    // For independants without LPP (LPP art. 4): no bonifications estimated.
    // For expats: start bonifications at arrivalAge, not age 25.
    final coachAvoirLpp = hasTypedLppRoot
        ? typedLppValue(LppEvidenceFactKey.vestedBenefitsCapitalChf)
        : _parseDouble(answers['_coach_avoir_lpp']);
    final double? estimatedLpp;
    if (coachAvoirLpp != null) {
      estimatedLpp = coachAvoirLpp;
    } else if (hasTypedLppRoot) {
      estimatedLpp = null;
    } else if (hasPensionFund == false) {
      // Independent without LPP or explicit no-pension-fund declaration.
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
        (has3a == true ? _estimate3aTotal(contribution3a, age) : 0.0);

    final prevoyance = PrevoyanceProfile(
      anneesContribuees: avsYears,
      lacunesAVS: coachAvsLacunes,
      renteAVSEstimeeMensuelle: coachAvsRenteEstimee,
      avoirLppTotal: estimatedLpp,
      avoirLppObligatoire: coachAvoirLppOblig,
      avoirLppSurobligatoire: coachAvoirLppSuroblig,
      hasPensionFund: hasPensionFund,
      hasVoluntaryLpp: hasVoluntaryLpp,
      tauxConversion: coachTauxConversion ?? lppTauxConversionMinDecimal,
      tauxConversionSuroblig: coachTauxConvSuroblig,
      rachatMaximum: coachRachatMax ?? lppBuybackAvailable,
      rendementCaisse: coachRendementCaisse,
      salaireAssure: coachSalaireAssure,
      projectedRenteLpp:
          typedLppValue(LppEvidenceFactKey.retirementPensionAnnualChf),
      projectedCapital65:
          typedLppValue(LppEvidenceFactKey.retirementCapitalLumpSumChf),
      disabilityCoverage:
          typedLppValue(LppEvidenceFactKey.disabilityPensionAnnualChf),
      lppDisabilityCapital:
          typedLppValue(LppEvidenceFactKey.disabilityCapitalLumpSumChf),
      deathCoverage: typedLppValue(LppEvidenceFactKey.deathCapitalLumpSumChf),
      lppEvidenceFacts: typedLppSelf?.facts ?? const {},
      ramd: coachAvsRamd,
      bonificationsEducatives: coachAvsBonificationsEducatives,
      nombre3a: nombre3a,
      totalEpargne3a: estimated3aTotal,
    );

    // ── Patrimoine ──────────────────────────────────────────
    final hasInvestments = _parseBool(answers['q_has_investments']);
    final savingsMonthly = _parseDouble(answers['q_savings_monthly']) ?? 0;

    final estimatedMonthlyExpenses = monthlyHousing + assuranceMaladie;
    final emergencyFundRaw = answers['q_emergency_fund'];
    final explicitCashTotal = _parseDouble(answers['q_cash_total']);
    final wealthEstimate = _parseDouble(answers['q_wealth_estimate']);
    double epargneLiquide;
    if (emergencyFundRaw is String) {
      switch (emergencyFundRaw.toLowerCase()) {
        case 'yes_6months':
          epargneLiquide = estimatedMonthlyExpenses * 6;
        case 'yes_3months':
          epargneLiquide = estimatedMonthlyExpenses * 3.0;
        case 'no':
          // User declares no emergency fund — use 1 month of savings as
          // conservative floor (0 would break liquidity ratios).
          epargneLiquide = savingsMonthly * 1;
        default:
          epargneLiquide =
              _parseDouble(emergencyFundRaw) ?? (savingsMonthly * 3);
      }
    } else {
      epargneLiquide = _parseDouble(emergencyFundRaw) ?? (savingsMonthly * 3);
    }
    if (answers.containsKey('q_cash_total') &&
        explicitCashTotal != null &&
        explicitCashTotal >= 0) {
      epargneLiquide = explicitCashTotal;
    }

    // Estimation investissements: si l'utilisateur déclare avoir des
    // investissements sans préciser le montant, on estime ~2 mois de revenu
    // net comme ordre de grandeur conservateur.
    final investmentsTotal = _parseDouble(answers['q_investments_total']) ?? 0;
    final estimatedInvestments = investmentsTotal > 0
        ? investmentsTotal
        : (hasInvestments ? (monthlyNetIncome * 2).clamp(0.0, 50000.0) : 0.0);

    // The richer `_coach_` key is canonical, while `q_mortgage_balance` is a
    // migration alias. A conflicting value can only win through field-level
    // chronology; storage-key priority and map order are never tie-breakers.
    final legacyMortgage = _parseDouble(answers['q_mortgage_balance']);
    final canonicalMortgage = _parseDouble(answers['_coach_dettes_hypotheque']);
    final mortgageTimestamps = answers['_coach_data_timestamps'];
    DateTime? mortgageTimestamp(String key) {
      if (mortgageTimestamps is! Map) return null;
      return DateTime.tryParse(mortgageTimestamps[key]?.toString() ?? '');
    }

    final DateTime? legacyMortgageAt = mortgageTimestamp('q_mortgage_balance');
    final DateTime? canonicalMortgageAt =
        mortgageTimestamp('_coach_dettes_hypotheque');
    final double? resolvedMortgageBalance;
    if (legacyMortgage == null) {
      resolvedMortgageBalance = canonicalMortgage;
    } else if (canonicalMortgage == null ||
        legacyMortgage == canonicalMortgage) {
      resolvedMortgageBalance = legacyMortgage;
    } else if (legacyMortgageAt == null && canonicalMortgageAt != null) {
      resolvedMortgageBalance = canonicalMortgage;
    } else if (legacyMortgageAt != null && canonicalMortgageAt == null) {
      resolvedMortgageBalance = legacyMortgage;
    } else if (legacyMortgageAt != null && canonicalMortgageAt != null) {
      final chronology = legacyMortgageAt.compareTo(canonicalMortgageAt);
      resolvedMortgageBalance = chronology > 0
          ? legacyMortgage
          : chronology < 0
              ? canonicalMortgage
              : null;
    } else {
      resolvedMortgageBalance = null;
    }

    final patrimoine = PatrimoineProfile(
      epargneLiquide: epargneLiquide,
      investissements: estimatedInvestments,
      wealthEstimate: wealthEstimate,
      propertyMarketValue: _parseDouble(answers['q_property_market_value']),
      mortgageBalance: resolvedMortgageBalance,
      mortgageRate: _parseDouble(answers['q_mortgage_rate']),
      monthlyRent: _parseDouble(answers['q_monthly_rent']),
    );

    // ── Dettes ──────────────────────────────────────────────
    final hasDebt = _parseBool(answers['q_has_consumer_debt']);
    final debtPaymentsMonthly =
        _parseDouble(answers['q_debt_payments_period_chf']) ?? 0;
    final legacyLeasingPaymentMonthly =
        _parseDouble(answers['q_leasing_monthly']) ?? 0;
    // _coach_dettes_* keys are written by updateInline() and survive restarts.
    // They override the wizard proxy estimates (debtPayments × 24 heuristic).
    final inlineHypotheque = resolvedMortgageBalance;
    final inlineCreditConso = _parseDouble(answers['_coach_dettes_credit']);
    final inlineLeasing = _parseDouble(answers['_coach_dettes_leasing']);
    final inlineAutresDettes = _parseDouble(answers['_coach_dettes_autres']);
    final hasInlineDettes = inlineHypotheque != null ||
        inlineCreditConso != null ||
        inlineLeasing != null ||
        inlineAutresDettes != null;
    final monthlyConsumerDebtPayment =
        debtPaymentsMonthly > 0 ? debtPaymentsMonthly : null;
    final monthlyLeasingPayment =
        debtPaymentsMonthly > 0 || legacyLeasingPaymentMonthly <= 0
            ? null
            : legacyLeasingPaymentMonthly;
    final dettes = (() {
      if (hasInlineDettes) {
        return DetteProfile(
          hypotheque: inlineHypotheque,
          creditConsommation: inlineCreditConso,
          leasing: inlineLeasing,
          autresDettes: inlineAutresDettes,
          mensualiteCreditConso: monthlyConsumerDebtPayment,
          mensualiteLeasing: monthlyLeasingPayment,
        );
      }
      if (debtPaymentsMonthly > 0) {
        // Proxy conservateur: principal restant ≈ 24 mois de mensualités.
        return DetteProfile(
          creditConsommation: debtPaymentsMonthly * 24,
          mensualiteCreditConso: debtPaymentsMonthly,
        );
      }
      if (monthlyLeasingPayment != null) {
        // Legacy wizard key: lease principal is unknown, so keep the same
        // conservative 24-month proxy used for the aggregate debt payment.
        return DetteProfile(
          leasing: monthlyLeasingPayment * 24,
          mensualiteLeasing: monthlyLeasingPayment,
        );
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

    // Planned contributions are an explicit plan aggregate, persisted and
    // restored independently by CoachProfileProvider. A declared 3a payment,
    // a monthly savings fact, or an allocation preference must never fabricate
    // a plan entry during answer-map reconstruction.
    final contributions = <PlannedMonthlyContribution>[];

    // Restore the dedicated inline LPP-buyback plan write. Unlike the direct
    // savings facts above, this field explicitly owns a planned contribution.
    final coachRachatLppMensuel =
        _parseDouble(answers['_coach_rachat_lpp_mensuel']);
    if (coachRachatLppMensuel != null && coachRachatLppMensuel > 0) {
      contributions.add(PlannedMonthlyContribution(
        id: 'lpp_buyback_user',
        label: 'Rachat LPP',
        amount: coachRachatLppMensuel,
        category: 'lpp_buyback',
        isAutomatic: false,
      ));
    }

    // ── Conjoint (partner) data from onboarding ────────────
    ConjointProfile? conjoint;
    final partnerIncome = _parseDouble(answers['q_partner_net_income_chf']);
    final partnerBirthYear = _parseInt(answers['q_partner_birth_year']);
    final rawSpouseAvsYears =
        _parseInt(answers['q_spouse_avs_contribution_years']);
    final conjEmployment = answers['q_partner_employment_status'] as String?;
    final conjNationality = answers['q_partner_nationality'] as String?;
    final partnerChildren = _parseInt(answers['q_partner_enfants']);
    final hasPartnerData = (partnerIncome != null && partnerIncome > 0) ||
        partnerBirthYear != null ||
        rawSpouseAvsYears != null ||
        (conjEmployment?.isNotEmpty ?? false) ||
        (conjNationality?.isNotEmpty ?? false) ||
        partnerChildren != null ||
        typedLppManualPartner != null;
    if (hasPartnerData) {
      // Net -> Brut estimation: same social charges rate as main user
      final partnerBrut = partnerIncome != null && partnerIncome > 0
          ? partnerIncome / (1 - socialChargesRate)
          : null;

      // === Conjoint arrivalAge ===
      // First check for spouse-specific AVS arrival data, then fall back
      // to inferring from user's arrival (common for couples relocating together).
      int? conjointArrivalAge;
      final spouseAvsStatus = answers['q_spouse_avs_lacunes_status'] as String?;

      // A declared arrival can locate the spouse's Swiss chronology, but it
      // cannot certify AVS gap years. Only a spouse CI/certificate may do so.
      if (spouseAvsStatus == 'arrived_late') {
        final spouseArrivalYear =
            _parseInt(answers['q_spouse_avs_arrival_year']);
        if (spouseArrivalYear != null && partnerBirthYear != null) {
          conjointArrivalAge = spouseArrivalYear - partnerBirthYear;
        }
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
      final conjLppEstimate = conjHasLpp && partnerBrut != null
          ? _estimateLppAvoir(conjAge, partnerBrut,
              arrivalAge: conjointArrivalAge)
          : 0.0;

      // === Conjoint FATCA / nationality detection ===
      final conjIsFatca = conjNationality == 'US';

      // === Conjoint prevoyance profile ===
      // FATCA hard block: most providers refuse US persons (LSFin compliance).
      final spouseAvsYearsMax = partnerBirthYear != null
          ? (DateTime.now().year - partnerBirthYear - 20).clamp(0, 44)
          : 44;
      final spouseAvsYears =
          rawSpouseAvsYears?.clamp(0, spouseAvsYearsMax).toInt();
      final conjointPrevoyance = PrevoyanceProfile(
        anneesContribuees: spouseAvsYears,
        avoirLppTotal: hasTypedLppRoot
            ? typedManualPartnerLppValue(
                LppEvidenceFactKey.vestedBenefitsCapitalChf,
              )
            : conjLppEstimate,
        avoirLppObligatoire: typedManualPartnerLppValue(
          LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf,
        ),
        avoirLppSurobligatoire: typedManualPartnerLppValue(
          LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf,
        ),
        salaireAssure: typedManualPartnerLppValue(
          LppEvidenceFactKey.insuredSalaryAnnualChf,
        ),
        rachatMaximum: typedManualPartnerLppValue(
          LppEvidenceFactKey.maximumBuybackCapitalChf,
        ),
        tauxConversion: typedManualPartnerLppValue(
              LppEvidenceFactKey.mandatoryConversionRateRatio,
            ) ??
            lppTauxConversionMinDecimal,
        tauxConversionSuroblig: typedManualPartnerLppValue(
          LppEvidenceFactKey.extraMandatoryConversionRateRatio,
        ),
        // A certificate-level caisse rate is not a person-owned fact. Keep it
        // in review/ledger quarantine, never in calculator-facing scalars.
        rendementCaisse: null,
        projectedRenteLpp: typedManualPartnerLppValue(
          LppEvidenceFactKey.retirementPensionAnnualChf,
        ),
        projectedCapital65: typedManualPartnerLppValue(
          LppEvidenceFactKey.retirementCapitalLumpSumChf,
        ),
        disabilityCoverage: typedManualPartnerLppValue(
          LppEvidenceFactKey.disabilityPensionAnnualChf,
        ),
        lppDisabilityCapital: typedManualPartnerLppValue(
          LppEvidenceFactKey.disabilityCapitalLumpSumChf,
        ),
        deathCoverage: typedManualPartnerLppValue(
          LppEvidenceFactKey.deathCapitalLumpSumChf,
        ),
        lppEvidenceFacts: typedLppManualPartner == null
            ? const {}
            : Map.unmodifiable(
                Map<LppEvidenceFactKey, LppEvidenceFact>.of(
                  typedLppManualPartner.facts,
                )..remove(LppEvidenceFactKey.fundReturnRateRatio),
              ),
        canContribute3a: !conjIsFatca,
      );

      conjoint = ConjointProfile(
        firstName: answers['q_partner_firstname'] as String?,
        birthYear: partnerBirthYear,
        gender: answers['q_partner_gender'] as String?,
        salaireBrutMensuel: partnerBrut,
        employmentStatus: conjEmployment,
        arrivalAge: conjointArrivalAge,
        nationality: conjNationality,
        isFatcaResident: conjIsFatca,
        canContribute3a: !conjIsFatca,
        prevoyance: conjointPrevoyance,
        canton: answers['q_partner_canton'] as String?,
        nombreEnfants: partnerChildren,
      );
    }

    // ── Timestamps persistes par annual refresh ─────────────
    final savedUpdatedAt = answers['_coach_updated_at'] as String?;
    final savedCreatedAt = answers['_coach_created_at'] as String?;

    // ── Family change persiste par annual refresh ─────────
    final familyChange = answers['_coach_family_change'] as String?;

    // `__provenance` is the canonical persisted envelope. Its presence is an
    // authority boundary: malformed or missing entries fail closed instead of
    // being upgraded from legacy source markers.
    final hasCanonicalProvenance = answers.containsKey('__provenance') ||
        hasTypedLppRoot ||
        backendUnknownPaths.isNotEmpty;
    final canonicalSources = <String, ProfileDataSource>{};
    final canonicalTimestamps = <String, DateTime>{};
    final canonicalSourceDates = <String, DateTime?>{};
    final canonicalMentionedPaths = <String>{};
    if (hasTypedLppRoot) {
      canonicalMentionedPaths.addAll(
        LppEvidenceFactKey.values.map((key) => key.profilePath),
      );
      canonicalMentionedPaths.addAll(
        LppEvidenceFactKey.values.map((key) => key.manualPartnerProfilePath),
      );
    }
    final rawProvenance = answers['__provenance'];
    if (rawProvenance is Map) {
      for (final entry in rawProvenance.entries) {
        final fieldPath = entry.key.toString();
        if (fieldPath.startsWith('fiscal.')) {
          final segments = fieldPath.split('.');
          final snapshotId = segments.length >= 4 ? segments[2] : null;
          final leafPath =
              segments.length >= 4 ? segments.sublist(3).join('.') : null;
          final snapshot = snapshotId == null
              ? null
              : fiscal.snapshots
                  .where((value) => value.snapshotId == snapshotId)
                  .firstOrNull;
          final allowed = FeatureFlags.typedTaxProfile &&
              segments.length >= 4 &&
              segments[0] == 'fiscal' &&
              segments[1] == 'snapshots' &&
              snapshot != null &&
              leafPath != null &&
              TaxSnapshot.provenanceLeafPaths.contains(leafPath) &&
              (leafPath == 'sourceDate' ||
                  snapshot.provenanceValue(leafPath) != null);
          if (!allowed) continue;
        }
        if (hasTypedLppRoot) {
          final lppKey = LppEvidenceFactKey.values
              .where(
                (key) =>
                    key.profilePath == fieldPath ||
                    key.manualPartnerProfilePath == fieldPath,
              )
              .firstOrNull;
          if (lppKey != null) continue;
        }
        canonicalMentionedPaths.add(fieldPath);
        final envelope = entry.value;
        if (envelope is! Map || !envelope.containsKey('sourceDate')) continue;
        final sourceName = envelope['source']?.toString();
        final source = ProfileDataSource.values
            .where((candidate) => candidate.name == sourceName)
            .firstOrNull;
        final updatedAt =
            DateTime.tryParse(envelope['updatedAt']?.toString() ?? '');
        if (source == null || updatedAt == null) continue;
        final rawSourceDate = envelope['sourceDate'];
        final parsedSourceDate = rawSourceDate == null
            ? null
            : DateTime.tryParse(rawSourceDate.toString());
        if (rawSourceDate != null && parsedSourceDate == null) continue;
        canonicalSources[fieldPath] = source;
        canonicalTimestamps[fieldPath] = updatedAt;
        canonicalSourceDates[fieldPath] = parsedSourceDate;
      }
    }
    if (typedLppSelf != null) {
      for (final entry in typedLppSelf.facts.entries) {
        final path = entry.key.profilePath;
        final fact = entry.value;
        canonicalSources[path] = fact.source == 'certificate'
            ? ProfileDataSource.certificate
            : ProfileDataSource.userInput;
        canonicalTimestamps[path] = fact.updatedAt;
        canonicalSourceDates[path] = fact.sourceDate;
      }
    }
    if (typedLppManualPartner != null) {
      for (final entry in typedLppManualPartner.facts.entries) {
        final path = entry.key.manualPartnerProfilePath;
        final fact = entry.value;
        canonicalSources[path] = fact.source == 'certificate'
            ? ProfileDataSource.certificate
            : ProfileDataSource.userInput;
        canonicalTimestamps[path] = fact.updatedAt;
        canonicalSourceDates[path] = fact.sourceDate;
      }
    }
    fiscal = fiscal.copyWith(
      provenanceValidatedSnapshotIds:
          _validatedFiscalSnapshotIds(fiscal, rawProvenance, now: now),
    );
    final latestTaxDecisionReference =
        SpecialistReferenceEvidence.latestTaxDecisionFromValidatedFiscal(
      fiscal,
      now: now,
    );

    // ── Legacy dataSources (migration input only) ────────────────
    final restoredDataSources = <String, ProfileDataSource>{};
    if (residenceCountry != null && !isBackendUnknown('residenceCountry')) {
      restoredDataSources['residenceCountry'] = ProfileDataSource.userInput;
    }
    if (workCountry != null && !isBackendUnknown('workCountry')) {
      restoredDataSources['workCountry'] = ProfileDataSource.userInput;
    }
    if (workCanton != null && !isBackendUnknown('workCanton')) {
      restoredDataSources['workCanton'] = ProfileDataSource.userInput;
    }
    if (answers.containsKey('q_avs_contribution_years') && avsYears != null) {
      restoredDataSources['prevoyance.anneesContribuees'] =
          ProfileDataSource.userInput;
    }
    if (answers.containsKey('q_avs_lacunes_status') &&
        _parseAvsGapStatus(avsLacunesStatus) != null) {
      restoredDataSources['avsGapStatus'] = ProfileDataSource.userInput;
    }
    if (coachAvsLacunes != null) {
      restoredDataSources['prevoyance.lacunesAVS'] =
          ProfileDataSource.estimated;
    }
    if (answers['_coach_lpp_source'] == 'document_scan') {
      const lppAnswerPaths = <String, String>{
        '_coach_avoir_lpp': 'prevoyance.avoirLppTotal',
        '_coach_avoir_lpp_oblig': 'prevoyance.avoirLppObligatoire',
        '_coach_avoir_lpp_suroblig': 'prevoyance.avoirLppSurobligatoire',
        '_coach_taux_conversion': 'prevoyance.tauxConversion',
        '_coach_taux_conversion_suroblig': 'prevoyance.tauxConversionSuroblig',
        '_coach_rachat_maximum': 'prevoyance.rachatMaximum',
        '_coach_salaire_assure': 'prevoyance.salaireAssure',
        '_coach_rendement_caisse': 'prevoyance.rendementCaisse',
      };
      for (final entry in lppAnswerPaths.entries) {
        if (answers[entry.key] != null) {
          restoredDataSources[entry.value] = ProfileDataSource.certificate;
        }
      }
    }
    if (answers['_coach_blink_source'] == 'open_banking') {
      const bankingAnswerPaths = <String, String>{
        'q_cash_total': 'patrimoine.epargneLiquide',
        '_coach_investissements': 'patrimoine.investissements',
        '_coach_total_3a': 'prevoyance.totalEpargne3a',
        '_coach_depenses_loyer': 'depenses.loyer',
        '_coach_depenses_assurance': 'depenses.assuranceMaladie',
        '_coach_depenses_electricite': 'depenses.electricite',
        '_coach_depenses_transport': 'depenses.transport',
        '_coach_depenses_telecom': 'depenses.telecom',
        '_coach_depenses_frais_medicaux': 'depenses.fraisMedicaux',
        '_coach_dettes_hypotheque': 'dettes.hypotheque',
      };
      for (final entry in bankingAnswerPaths.entries) {
        if (answers[entry.key] != null) {
          restoredDataSources[entry.value] = ProfileDataSource.openBanking;
        }
      }
    }
    final cashSourceName = answers['_coach_cash_total_source']?.toString();
    final cashSource = ProfileDataSource.values
        .where((candidate) => candidate.name == cashSourceName)
        .firstOrNull;
    if (answers['q_cash_total'] != null && cashSource != null) {
      restoredDataSources['patrimoine.epargneLiquide'] = cashSource;
    }
    if (monthlyTaxProvisionDeclared != null) {
      restoredDataSources['monthlyTaxProvisionDeclared'] =
          ProfileDataSource.userInput;
    }

    // S47: Build initial dataTimestamps for all populated fields.
    // Use persisted updatedAt as base (reflects when data was actually entered),
    // falling back to now for first-time creation.
    final baseTimestamp = savedUpdatedAt != null
        ? (DateTime.tryParse(savedUpdatedAt) ?? DateTime.now())
        : DateTime.now();
    final initialTimestamps = <String, DateTime>{
      if ((hasResolvedAnswer('q_net_income_period_chf') ||
              hasResolvedAnswer('q_gross_salary_annual') ||
              hasResolvedAnswer('q_self_employed_income')) &&
          !isBackendUnknown('salaireBrutMensuel') &&
          !isBackendUnknown('monthlyNetIncomeDeclared'))
        'salaireBrutMensuel': baseTimestamp,
      if (monthlyTaxProvisionDeclared != null)
        'monthlyTaxProvisionDeclared': baseTimestamp,
      if ((answers.containsKey('q_birth_year') ||
              answers.containsKey('q_date_of_birth')) &&
          !isBackendUnknown('birthYear') &&
          !isBackendUnknown('dateOfBirth'))
        'age': baseTimestamp,
      if (resolvedCanton.isResolved && !isBackendUnknown('canton'))
        'canton': baseTimestamp,
      if (residenceCountry != null && !isBackendUnknown('residenceCountry'))
        'residenceCountry': ageNow,
      if (workCountry != null && !isBackendUnknown('workCountry'))
        'workCountry': ageNow,
      if (workCanton != null && !isBackendUnknown('workCanton'))
        'workCanton': ageNow,
      if (answers.containsKey('q_civil_status')) 'etatCivil': baseTimestamp,
      if ((answers.containsKey('_coach_avoir_lpp') ||
              answers.containsKey('q_avoir_lpp')) &&
          prevoyance.avoirLppTotal != null &&
          !isBackendUnknown('prevoyance.avoirLppTotal'))
        'prevoyance.avoirLppTotal': baseTimestamp,
      if ((answers.containsKey('q_3a_total') ||
              answers.containsKey('_coach_total_3a')) &&
          prevoyance.totalEpargne3a >= 0 &&
          !isBackendUnknown('prevoyance.totalEpargne3a'))
        'prevoyance.totalEpargne3a': baseTimestamp,
      if (answers.containsKey('q_avs_contribution_years') &&
          prevoyance.anneesContribuees != null)
        'prevoyance.anneesContribuees': baseTimestamp,
      if (answers.containsKey('q_avs_lacunes_status') &&
          _parseAvsGapStatus(avsLacunesStatus) != null)
        'avsGapStatus': baseTimestamp,
      if (answers.containsKey('_coach_avs_lacunes') &&
          prevoyance.lacunesAVS != null)
        'prevoyance.lacunesAVS': baseTimestamp,
      if (answers.containsKey('_coach_avs_rente_estimee') &&
          prevoyance.renteAVSEstimeeMensuelle != null)
        'prevoyance.renteAVSEstimeeMensuelle': baseTimestamp,
      if (coachTauxConversion != null)
        'prevoyance.tauxConversion': baseTimestamp,
      if (answers.containsKey('q_cash_total'))
        'patrimoine.epargneLiquide': baseTimestamp,
      if (answers.containsKey('q_investments_total') &&
          patrimoine.investissements >= 0)
        'patrimoine.investissements': baseTimestamp,
      if (explicitHousingCost != null) 'depenses.loyer': baseTimestamp,
      if (lamalFromOnboarding != null)
        'depenses.assuranceMaladie': baseTimestamp,
      if (answers.containsKey('q_3a_annual_contribution'))
        'pillar3aAnnualContribution': baseTimestamp,
      if (answers.containsKey('q_savings_monthly'))
        'monthlySavingsContribution': baseTimestamp,
    };

    // Restore persisted timestamps from answers (written by updateInline /
    // extraction methods). These override the base timestamp for fields that
    // were individually refreshed.
    final persistedTs = answers['_coach_data_timestamps'];
    if (persistedTs is Map) {
      for (final entry in persistedTs.entries) {
        final dt = DateTime.tryParse(entry.value.toString());
        final field = entry.key.toString();
        // A stale timestamp must not authenticate a display fallback after
        // the corresponding persisted answer became corrupt or unreadable.
        if (field == 'canton' && !resolvedCanton.isResolved) continue;
        if (field == 'depenses.loyer' && explicitHousingCost == null) continue;
        if (field == 'depenses.assuranceMaladie' &&
            lamalFromOnboarding == null) {
          continue;
        }
        if (field == 'prevoyance.tauxConversion' &&
            coachTauxConversion == null) {
          continue;
        }
        if (dt != null) initialTimestamps[field] = dt;
      }
    }
    final legacyResolvedSources =
        _resolveDataSources(restoredDataSources, prevoyance)
          ..removeWhere((path, _) => isBackendUnknown(path));
    final restoredDataSourceDates = <String, DateTime?>{
      for (final fieldPath in legacyResolvedSources.keys) fieldPath: null,
    };
    final effectiveSources = <String, ProfileDataSource>{
      for (final entry in legacyResolvedSources.entries)
        if (!canonicalMentionedPaths.contains(entry.key))
          entry.key: entry.value,
      ...canonicalSources,
    }..removeWhere((path, _) => isBackendUnknown(path));
    final effectiveTimestamps = <String, DateTime>{
      for (final entry in initialTimestamps.entries)
        if (!canonicalMentionedPaths.contains(entry.key))
          entry.key: entry.value,
      ...canonicalTimestamps,
    }..removeWhere(
        (path, _) =>
            isBackendUnknown(path) ||
            path == 'age' &&
                (isBackendUnknown('birthYear') ||
                    isBackendUnknown('dateOfBirth')),
      );
    final effectiveSourceDates = <String, DateTime?>{
      for (final entry in restoredDataSourceDates.entries)
        if (!canonicalMentionedPaths.contains(entry.key))
          entry.key: entry.value,
      ...canonicalSourceDates,
    }..removeWhere((path, _) => isBackendUnknown(path));

    // ── Track which fields the user explicitly provided ──
    // Used by profile drawer to avoid showing phantom default data.
    final provided = <String>{};
    if (firstName != null &&
        firstName.isNotEmpty &&
        !isBackendUnknown('firstName')) {
      provided.add('firstName');
    }
    if ((answers.containsKey('q_birth_year') ||
            answers.containsKey('q_date_of_birth')) &&
        !isBackendUnknown('birthYear') &&
        !isBackendUnknown('dateOfBirth')) {
      provided.add('age');
    }
    if (resolvedCanton.isResolved && !isBackendUnknown('canton')) {
      provided.add('canton');
    }
    if (residenceCountry != null && !isBackendUnknown('residenceCountry')) {
      provided.add('residenceCountry');
    }
    if (workCountry != null && !isBackendUnknown('workCountry')) {
      provided.add('workCountry');
    }
    if (workCanton != null && !isBackendUnknown('workCanton')) {
      provided.add('workCanton');
    }
    if (answers.containsKey('q_commune')) provided.add('commune');
    if (answers.containsKey('q_gender') && !isBackendUnknown('gender')) {
      provided.add('gender');
    }
    if ((answers.containsKey('q_employment_status') ||
            hasResolvedAnswer('q_self_employed_income')) &&
        !isBackendUnknown('employmentStatus')) {
      provided.add('employmentStatus');
    }
    if (answers.containsKey('q_children')) provided.add('children');
    if (answers.containsKey('q_housing_status')) {
      provided.add('housingStatus');
    }
    if (explicitHousingCost != null) {
      provided.add('housingCost');
    }
    if (answers.containsKey('q_debt_payments_period_chf') ||
        answers.containsKey('q_leasing_monthly')) {
      provided.add('monthlyDebtPayments');
    }
    if (answers.containsKey('q_has_consumer_debt') ||
        answers.containsKey('q_has_leasing')) {
      provided.add('hasDebt');
    }
    if ((hasResolvedAnswer('q_net_income_period_chf') ||
            hasResolvedAnswer('q_gross_salary_annual')) &&
        !isBackendUnknown('salaireBrutMensuel') &&
        !isBackendUnknown('monthlyNetIncomeDeclared')) {
      provided.add('salary');
    }
    if (hasResolvedAnswer('q_net_income_period_chf') &&
        !isBackendUnknown('monthlyNetIncomeDeclared')) {
      provided.add('netIncome');
    }
    if (hasResolvedAnswer('q_gross_salary_annual') &&
        !isBackendUnknown('salaireBrutMensuel')) {
      provided.add('grossSalaryAnnual');
    }
    if (monthlyTaxProvisionDeclared != null) {
      provided.add('monthlyTaxProvisionDeclared');
    }
    if (hasResolvedAnswer('q_self_employed_income')) {
      provided.add('selfEmployedNetIncome');
    }
    if (hasResolvedAnswer('q_company_profit_annual_chf')) {
      provided.add('companyProfitAnnual');
    }
    if (answers.containsKey('q_unemployment_contribution_months')) {
      provided.add('unemploymentContributionMonths');
    }
    if (answers.containsKey('q_has_pension_fund')) {
      provided.add('hasPensionFund');
    }
    if (answers.containsKey('q_has_voluntary_lpp')) {
      provided.add('hasVoluntaryLpp');
    }
    if (answers.containsKey('q_has_3a') ||
        answers.containsKey('q_3a_accounts_count')) {
      provided.add('has3a');
    }
    if (answers.containsKey('q_3a_annual_contribution')) {
      provided.add('pillar3aAnnualContribution');
    }
    if (answers.containsKey('q_savings_monthly')) {
      provided.add('monthlySavingsContribution');
    }
    if (answers.containsKey('q_cash_total') ||
        answers.containsKey('q_emergency_fund')) {
      provided.add('liquidSavings');
    }
    // Some high-stakes flows need an explicit cash amount, including a known
    // zero balance, not the emergency-fund heuristic covered by liquidSavings.
    final explicitCashTotalForMarker = _parseDouble(answers['q_cash_total']);
    if (answers.containsKey('q_cash_total') &&
        explicitCashTotalForMarker != null &&
        explicitCashTotalForMarker >= 0) {
      provided.add('liquidSavingsAmount');
    }
    final explicitInvestmentsTotal =
        _parseDouble(answers['q_investments_total']);
    if (explicitInvestmentsTotal != null && explicitInvestmentsTotal > 0) {
      provided.add('investments');
    }
    if (answers.containsKey('q_wealth_estimate')) {
      provided.add('wealthEstimate');
    }
    if (answers.containsKey('q_property_market_value')) {
      provided.add('propertyMarketValue');
    }
    if (resolvedMortgageBalance != null) {
      provided.add('mortgageBalance');
    }
    if (explicitHousingCost != null && lamalFromOnboarding != null) {
      provided.add('monthlyExpenses');
    }
    if (answers.containsKey('q_employment_rate')) {
      provided.add('employmentRate');
    }
    if (answers.containsKey('q_annual_bonus')) {
      provided.add('bonusPourcentage');
    }
    if (coachTauxConversion != null) {
      provided.add('conversionRate');
    }
    if (answers.containsKey('q_civil_status')) {
      provided.add('civilStatus');
    }
    if (answers.containsKey('q_nationality')) {
      provided.add('nationality');
    }

    return CoachProfile(
      firstName: firstName,
      birthYear: birthYear,
      dateOfBirth: dateOfBirth,
      canton: canton,
      commune: commune,
      nationality: answers['q_nationality'] as String?,
      residenceCountry: residenceCountry,
      workCountry: workCountry,
      workCanton: workCanton,
      etatCivil: etatCivil,
      civilStatusNeedsConfirmation: civilStatusNeedsConfirmation,
      civilStatusRawValue: civilStatusNeedsConfirmation ? civilStatusRaw : null,
      nombreEnfants: nombreEnfants,
      conjoint: conjoint,
      salaireBrutMensuel: salaireBrutMensuel,
      monthlyNetIncomeDeclared: monthlyNetIncomeDeclared,
      monthlyTaxProvisionDeclared: monthlyTaxProvisionDeclared,
      nombreDeMois: nombreDeMois,
      bonusPourcentage: bonusPourcentage,
      employmentRate: employmentRate,
      employmentStatus: employmentStatus,
      selfEmployedNetIncome: selfEmployedNetIncome,
      companyProfitAnnual: companyProfitAnnual,
      unemploymentContributionMonths: unemploymentContributionMonths,
      pillar3aAnnualContribution:
          answers.containsKey('q_3a_annual_contribution')
              ? _parseDouble(answers['q_3a_annual_contribution'])
              : null,
      monthlySavingsContribution: answers.containsKey('q_savings_monthly')
          ? _parseDouble(answers['q_savings_monthly'])
          : null,
      hasPillar3a: has3a,
      avsGapStatus: _parseAvsGapStatus(avsLacunesStatus),
      latestTaxDecisionReference: latestTaxDecisionReference,
      depenses: depenses,
      prevoyance: prevoyance,
      patrimoine: patrimoine,
      dettes: dettes,
      fiscal: fiscal,
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
      gender: gender,
      targetRetirementAge: targetRetAge,
      updatedAt:
          savedUpdatedAt != null ? DateTime.tryParse(savedUpdatedAt) : null,
      createdAt:
          savedCreatedAt != null ? DateTime.tryParse(savedCreatedAt) : null,
      dataSources:
          hasCanonicalProvenance ? effectiveSources : restoredDataSources,
      dataTimestamps:
          hasCanonicalProvenance ? effectiveTimestamps : initialTimestamps,
      dataSourceDates: hasCanonicalProvenance
          ? effectiveSourceDates
          : restoredDataSourceDates,
      inferDataSources: !hasCanonicalProvenance,
      userProvidedFields: provided,
      financialLiteracyLevel: FinancialLiteracyLevel.values.firstWhere(
        (e) => e.name == answers['_coach_financial_literacy_level'],
        orElse: () => FinancialLiteracyLevel.beginner,
      ),
      primaryFocus: answers['q_primary_focus'] as String?,
    );
  }

  static FiscalProfile _fiscalFromWizardAnswers(
    Map<String, dynamic> answers,
  ) {
    if (!FeatureFlags.typedTaxProfile) return const FiscalProfile.empty();
    final raw = answers['_coach_tax_snapshots_v1'];
    if (raw is! String) return const FiscalProfile.empty();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const FiscalProfile.empty();
      final root = Map<String, dynamic>.from(decoded);
      if (root.length != 3 ||
          root['schemaVersion'] != 1 ||
          !root.containsKey('snapshots') ||
          !root.containsKey('legacyQuarantine')) {
        return const FiscalProfile.empty();
      }
      final rawSnapshots = root['snapshots'];
      if (rawSnapshots is! List) return const FiscalProfile.empty();
      final snapshots = <TaxSnapshot>[];
      final ids = <String>{};
      String? profileOwnerId;
      for (final rawSnapshot in rawSnapshots) {
        if (rawSnapshot is! Map) return const FiscalProfile.empty();
        final snapshot =
            TaxSnapshot.fromJson(Map<String, dynamic>.from(rawSnapshot));
        if (!ids.add(snapshot.snapshotId)) return const FiscalProfile.empty();
        profileOwnerId ??= snapshot.profileOwnerId;
        if (snapshot.profileOwnerId != profileOwnerId) {
          return const FiscalProfile.empty();
        }
        snapshots.add(snapshot);
      }

      final rawQuarantine = root['legacyQuarantine'];
      var legacyDataNeedsReview = false;
      if (rawQuarantine != null) {
        if (rawQuarantine is! Map) return const FiscalProfile.empty();
        final quarantine = Map<String, dynamic>.from(rawQuarantine);
        final reasons = quarantine['reasonCodes'];
        final values = quarantine['values'];
        final quarantinedAt =
            DateTime.tryParse(quarantine['quarantinedAt']?.toString() ?? '');
        if (quarantine.length != 4 ||
            quarantine['legacySchemaVersion'] != 0 ||
            reasons is! List ||
            reasons.isEmpty ||
            reasons.any((reason) => reason is! String) ||
            values is! Map ||
            values.keys.any(
              (key) =>
                  key is! String ||
                  !key.startsWith('_coach_tax_') ||
                  key == '_coach_tax_snapshots_v1',
            ) ||
            quarantinedAt == null) {
          return const FiscalProfile.empty();
        }
        legacyDataNeedsReview = values.isNotEmpty;
      }
      return FiscalProfile(
        snapshots: snapshots,
        legacyDataNeedsReview: legacyDataNeedsReview,
      );
    } on Object {
      return const FiscalProfile.empty();
    }
  }

  static Set<String> _validatedFiscalSnapshotIds(
    FiscalProfile fiscal,
    dynamic rawProvenance, {
    DateTime Function()? now,
  }) {
    if (rawProvenance is! Map) return const {};
    final provenance = <String, dynamic>{
      for (final entry in rawProvenance.entries)
        entry.key.toString(): entry.value,
    };
    final validated = <String>{};
    final currentDay = _civilDay((now ?? DateTime.now)());
    for (final snapshot in fiscal.snapshots) {
      if (snapshot.assessmentStatus == TaxAssessmentStatus.inForce &&
          !snapshot.inForceAttested) {
        continue;
      }
      if (!TaxSnapshot.hasValidTaxYears(
        taxYear: snapshot.taxYear,
        basedOnTaxYear: snapshot.basedOnTaxYear,
        documentKind: snapshot.documentKind,
        currentYear: currentDay.year,
      )) {
        continue;
      }
      if (snapshot.sourceDate case final sourceDate?
          when _civilDay(sourceDate).isAfter(currentDay)) {
        continue;
      }
      final prefix = 'fiscal.snapshots.${snapshot.snapshotId}.';
      final expectedPaths = <String>{
        for (final leafPath in TaxSnapshot.provenanceLeafPaths)
          if (leafPath == 'sourceDate' ||
              snapshot.provenanceValue(leafPath) != null)
            '$prefix$leafPath',
      };
      final actualPaths = provenance.keys
          .where((fieldPath) => fieldPath.startsWith(prefix))
          .toSet();
      if (!setEquals(expectedPaths, actualPaths)) continue;
      if (expectedPaths.every(
        (fieldPath) => _isExactFiscalProvenanceEnvelope(
          provenance[fieldPath],
          snapshot,
          fieldPath.substring(prefix.length),
        ),
      )) {
        validated.add(snapshot.snapshotId);
      }
    }
    return Set.unmodifiable(validated);
  }

  static bool _isExactFiscalProvenanceEnvelope(
    dynamic rawEnvelope,
    TaxSnapshot snapshot,
    String leafPath,
  ) {
    if (rawEnvelope is! Map ||
        rawEnvelope.length != 3 ||
        !rawEnvelope.containsKey('source') ||
        !rawEnvelope.containsKey('updatedAt') ||
        !rawEnvelope.containsKey('sourceDate')) {
      return false;
    }
    final expectedSource = switch (leafPath) {
      'inForceAttested' => ProfileDataSource.userInput,
      'assessmentStatus'
          when snapshot.assessmentStatus == TaxAssessmentStatus.inForce =>
        ProfileDataSource.userInput,
      _ => switch (snapshot.documentKind) {
          TaxDocumentKind.assessmentNotice => ProfileDataSource.certificate,
          TaxDocumentKind.taxpayerReturn => ProfileDataSource.userInput,
          TaxDocumentKind.provisionalBill ||
          TaxDocumentKind.finalTaxBill ||
          TaxDocumentKind.unknown =>
            ProfileDataSource.estimated,
        },
    };
    if (rawEnvelope['source'] != expectedSource.name) return false;

    final rawUpdatedAt = rawEnvelope['updatedAt'];
    if (rawUpdatedAt is! String) return false;
    final updatedAt = DateTime.tryParse(rawUpdatedAt);
    if (updatedAt == null || !updatedAt.isAtSameMomentAs(snapshot.updatedAt)) {
      return false;
    }

    final rawSourceDate = rawEnvelope['sourceDate'];
    if (snapshot.sourceDate == null) return rawSourceDate == null;
    if (rawSourceDate is! String) return false;
    final sourceDate = DateTime.tryParse(rawSourceDate);
    return sourceDate != null &&
        sourceDate.isAtSameMomentAs(snapshot.sourceDate!);
  }

  static DateTime _civilDay(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

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

  static AvsGapStatus? _parseAvsGapStatus(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'no':
      case 'no_gaps':
        return AvsGapStatus.noGaps;
      case 'arrived_late':
        return AvsGapStatus.arrivedLate;
      case 'lived_abroad':
        return AvsGapStatus.livedAbroad;
      case 'yes':
      case 'unknown':
        return AvsGapStatus.unknown;
      default:
        return null;
    }
  }

  static String? _avsGapStatusToCanonical(AvsGapStatus? status) =>
      switch (status) {
        AvsGapStatus.noGaps => 'no_gaps',
        AvsGapStatus.arrivedLate => 'arrived_late',
        AvsGapStatus.livedAbroad => 'lived_abroad',
        AvsGapStatus.unknown => 'unknown',
        null => null,
      };

  static CoachCivilStatus _parseCivilStatus(String? raw) {
    if (raw == null) return CoachCivilStatus.celibataire;
    switch (raw.trim().toLowerCase()) {
      case 'marie':
      case 'marié': // lint-ignore: accepted legacy input
      case 'married':
        return CoachCivilStatus.marie;
      case 'registered_partner':
      case 'registered_partnership':
      case 'registeredpartnership':
      case 'partenariat_enregistre':
      case 'partenariat_enregistré': // lint-ignore: accepted input alias
        return CoachCivilStatus.registeredPartnership;
      case 'divorce':
      case 'divorcé': // lint-ignore: accepted legacy input
      case 'divorced':
        return CoachCivilStatus.divorce;
      case 'veuf':
      case 'veuve':
      case 'widowed':
        return CoachCivilStatus.veuf;
      case 'concubinage':
      case 'cohabiting':
        return CoachCivilStatus.concubinage;
      default:
        return CoachCivilStatus.celibataire;
    }
  }

  static bool _isAmbiguousCivilStatus(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'partenariat':
      case 'pacs':
      case 'civil_union':
      case 'civil union':
      case 'foreign_civil_union':
      case 'foreign_registered_partner':
      case 'foreign_registered_partnership':
        return true;
      default:
        return false;
    }
  }

  static String _parseEmploymentStatus(String? raw) {
    if (raw == null) return 'salarie';
    switch (raw.toLowerCase()) {
      case 'employee':
      case 'salarie':
      case 'salarié': // lint-ignore: accepted legacy input
        return 'salarie';
      case 'self_employed':
      case 'independant':
      case 'indépendant': // lint-ignore: accepted legacy input
        return 'independant';
      case 'retired':
      case 'retraite':
      case 'retraité': // lint-ignore: accepted legacy input
        return 'retraite';
      case 'student':
      case 'etudiant':
      case 'étudiant': // lint-ignore: accepted legacy input
        return 'etudiant';
      case 'unemployed':
      case 'chomage':
      case 'chômage': // lint-ignore: accepted legacy input
        return 'chomage';
      case 'mixed':
      case 'mixte':
        return 'mixte';
      case 'frontalier':
        return 'frontalier';
      default:
        return 'salarie';
    }
  }

  /// Map internal French employment status to canonical English (backend Profile API dialect).
  /// Use when syncing CoachProfile data back to the backend Profile endpoint.
  static String employmentStatusToCanonical(String status) => switch (status) {
        'salarie' => 'employee',
        'independant' => 'self_employed',
        'retraite' => 'retired',
        'etudiant' => 'student',
        'chomage' => 'unemployed',
        'mixte' => 'mixed',
        _ => status,
      };

  /// Map canonical English employment status (backend Profile API) to internal French.
  /// Use when receiving data from the backend Profile endpoint.
  static String employmentStatusFromCanonical(String status) =>
      switch (status) {
        'employee' => 'salarie',
        'self_employed' => 'independant',
        'retired' => 'retraite',
        'student' => 'etudiant',
        'unemployed' => 'chomage',
        _ => status,
      };

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
      final taux = getLppBonificationRate(a);
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
        gender: 'F',
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
        nomCaisse: 'Caisse des Electriciens', // lint-ignore: demo seed
        avoirLppTotal: 300000,
        rachatMaximum: 300000,
        rachatEffectue: 0,
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
