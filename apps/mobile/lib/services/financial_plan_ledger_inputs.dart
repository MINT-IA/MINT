import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';

const _planInputFingerprintPrefix = 'mint-plan-input:v2:sha256:';

const _salaryPath = 'salaireBrutMensuel';
const _cantonPath = 'canton';
const _dateOfBirthPath = 'dateOfBirth';
const _birthYearPath = 'birthYear';
const _lppTotalPath = 'prevoyance.avoirLppTotal';
const _lppMandatoryPath = 'prevoyance.avoirLppObligatoire';
const _lppExtraMandatoryPath = 'prevoyance.avoirLppSurobligatoire';
const _lppReturnPath = 'prevoyance.rendementCaisse';
const _lppReturnKnownPath = 'prevoyance.rendementCaisseConnu';
const _hasPensionFundPath = 'prevoyance.hasPensionFund';
const _insuredSalaryPath = 'prevoyance.salaireAssure';
const _bonificationRatePath = 'prevoyance.bonificationRate';
const _pillar3aPath = 'prevoyance.totalEpargne3a';
const _effectiveAgePath = 'derived.effectiveAge';
const _confidencePath = 'derived.enhancedConfidenceCombined';

/// Immutable Data Ledger snapshot used by plan generation and staleness.
///
/// Partial LPP facts remain nullable. Calculator-facing salary and
/// bonification overrides cross this boundary only when their value, source,
/// capture time and source date form a current owned fact.
class FinancialPlanLedgerInputs {
  /// Canonical current-fact window for annual pension-fund inputs.
  ///
  /// This matches the 24-month boundary after which ConfidenceScorer moves an
  /// annual fact out of its current/semi-current bands. Older certificate
  /// values remain in the ledger but cannot override legal projection bases.
  static const int currentOwnedFactMaxAgeMonths = 24;

  final double grossMonthlySalary;

  /// Retained for ledger inspection only. It is not an LPP projection input.
  final double salaryMonths;
  final double grossAnnualSalary;
  final String canton;
  final int currentAge;
  final DateTime? dateOfBirth;
  final int birthYear;
  final DateTime capturedAt;
  final bool hasPensionFund;
  final double? lppTotal;
  final double? lppMandatoryBalance;
  final double? lppExtraMandatoryBalance;
  final double? currentLppCapital;
  final double pillar3aTotal;
  final double caisseReturn;
  final bool caisseReturnKnown;
  final double? insuredSalaryAnnual;
  final double? bonificationRate;
  final double confidenceLevel;
  final String fingerprint;

  const FinancialPlanLedgerInputs._({
    required this.grossMonthlySalary,
    required this.salaryMonths,
    required this.grossAnnualSalary,
    required this.canton,
    required this.currentAge,
    required this.dateOfBirth,
    required this.birthYear,
    required this.capturedAt,
    required this.hasPensionFund,
    required this.lppTotal,
    required this.lppMandatoryBalance,
    required this.lppExtraMandatoryBalance,
    required this.currentLppCapital,
    required this.pillar3aTotal,
    required this.caisseReturn,
    required this.caisseReturnKnown,
    required this.insuredSalaryAnnual,
    required this.bonificationRate,
    required this.confidenceLevel,
    required this.fingerprint,
  });

  bool get usesDeclaredInsuredSalary => insuredSalaryAnnual != null;

  bool get usesDeclaredBonificationRate => bonificationRate != null;

  int ageAt(DateTime date) {
    final birthDate = dateOfBirth;
    if (birthDate != null) {
      var age = date.year - birthDate.year;
      final beforeBirthday = date.month < birthDate.month ||
          (date.month == birthDate.month && date.day < birthDate.day);
      if (beforeBirthday) age--;
      return age.clamp(0, 150);
    }
    return (date.year - birthYear).clamp(0, 150);
  }

  factory FinancialPlanLedgerInputs.fromProfile(
    CoachProfile profile, {
    DateTime? now,
  }) {
    final capturedAt = now ?? DateTime.now();
    final effectiveAgePath =
        profile.dateOfBirth == null ? _birthYearPath : _dateOfBirthPath;
    final effectiveAgeValue = profile.dateOfBirth == null
        ? profile.birthYear
        : _businessDate(profile.dateOfBirth!);
    final currentAge = _currentAge(profile, capturedAt);
    final confidence =
        ConfidenceScorer.scoreEnhanced(profile, now: capturedAt).combined;

    final prevoyance = profile.prevoyance;
    final rawTotal = prevoyance.avoirLppTotal;
    final rawMandatory = prevoyance.avoirLppObligatoire;
    final rawExtraMandatory = prevoyance.avoirLppSurobligatoire;
    final hasPensionFund = prevoyance.hasPensionFund != false;

    _validateNonNegativeFinite(_salaryPath, profile.salaireBrutMensuel);
    _validateNonNegativeFinite(_pillar3aPath, prevoyance.totalEpargne3a);
    for (final entry in <String, double?>{
      _lppTotalPath: rawTotal,
      _lppMandatoryPath: rawMandatory,
      _lppExtraMandatoryPath: rawExtraMandatory,
      _lppReturnPath: prevoyance.rendementCaisse,
      _insuredSalaryPath: prevoyance.salaireAssure,
      _bonificationRatePath: prevoyance.bonificationRate,
    }.entries) {
      _validateNonNegativeFinite(entry.key, entry.value);
    }
    final rawBonification = prevoyance.bonificationRate;
    if (rawBonification != null && rawBonification > 1) {
      throw ArgumentError.value(
        rawBonification,
        _bonificationRatePath,
        'annual rate must be between zero and one',
      );
    }

    double? currentLppCapital;
    if (hasPensionFund) {
      final hasCompleteSplits =
          rawMandatory != null && rawExtraMandatory != null;
      final hasAnyCapitalFact =
          rawTotal != null || rawMandatory != null || rawExtraMandatory != null;
      if (hasAnyCapitalFact &&
          !LppBalanceCoherence.isCoherent({
            if (rawTotal != null)
              LppEvidenceFactKey.vestedBenefitsCapitalChf: rawTotal,
            if (rawMandatory != null)
              LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf:
                  rawMandatory,
            if (rawExtraMandatory != null)
              LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf:
                  rawExtraMandatory,
          })) {
        throw ArgumentError(
          'LPP total and component balances are not coherent within CHF 1',
        );
      }
      currentLppCapital = rawTotal ??
          (hasCompleteSplits ? rawMandatory + rawExtraMandatory : null);
    }

    final insuredSalaryAnnual = _isOwnedCurrentFact(
      profile,
      _insuredSalaryPath,
      prevoyance.salaireAssure,
      capturedAt,
    )
        ? prevoyance.salaireAssure
        : null;
    final bonificationRate = _isOwnedCurrentFact(
      profile,
      _bonificationRatePath,
      prevoyance.bonificationRate,
      capturedAt,
    )
        ? prevoyance.bonificationRate
        : null;
    final caisseReturnKnown = hasPensionFund && prevoyance.rendementCaisseConnu;

    final facts = <Map<String, Object?>>[
      _fingerprintFact(profile, _salaryPath, profile.salaireBrutMensuel),
      _fingerprintFact(profile, _cantonPath, profile.canton),
      _fingerprintFact(
        profile,
        _hasPensionFundPath,
        prevoyance.hasPensionFund,
      ),
      _fingerprintFact(
        profile,
        _lppTotalPath,
        hasPensionFund ? rawTotal : null,
        includeMetadata: hasPensionFund,
      ),
      _fingerprintFact(
        profile,
        _pillar3aPath,
        prevoyance.totalEpargne3a,
      ),
      _fingerprintFact(profile, effectiveAgePath, effectiveAgeValue),
      _fingerprintFact(
        profile,
        _lppMandatoryPath,
        hasPensionFund ? rawMandatory : null,
        includeMetadata: hasPensionFund,
      ),
      _fingerprintFact(
        profile,
        _lppExtraMandatoryPath,
        hasPensionFund ? rawExtraMandatory : null,
        includeMetadata: hasPensionFund,
      ),
      _fingerprintFact(
        profile,
        _lppReturnPath,
        caisseReturnKnown ? prevoyance.rendementCaisse : null,
        includeMetadata: caisseReturnKnown,
      ),
      _fingerprintFact(
        profile,
        _lppReturnKnownPath,
        caisseReturnKnown,
      ),
      _fingerprintFact(
        profile,
        _insuredSalaryPath,
        insuredSalaryAnnual,
        includeMetadata: insuredSalaryAnnual != null,
      ),
      _fingerprintFact(
        profile,
        _bonificationRatePath,
        bonificationRate,
        includeMetadata: bonificationRate != null,
      ),
      <String, Object?>{'path': _effectiveAgePath, 'value': currentAge},
      <String, Object?>{'path': _confidencePath, 'value': confidence},
    ];
    final payload = jsonEncode(<String, Object?>{
      'schema': 'mint-plan-input',
      'version': 2,
      'facts': facts,
    });
    final fingerprint =
        '$_planInputFingerprintPrefix${sha256.convert(utf8.encode(payload))}';

    return FinancialPlanLedgerInputs._(
      grossMonthlySalary: profile.salaireBrutMensuel,
      salaryMonths: profile.nombreDeMois,
      grossAnnualSalary: profile.salaireBrutMensuel * 12,
      canton: profile.canton,
      currentAge: currentAge,
      dateOfBirth: profile.dateOfBirth,
      birthYear: profile.birthYear,
      capturedAt: capturedAt,
      hasPensionFund: hasPensionFund,
      lppTotal: rawTotal,
      lppMandatoryBalance: rawMandatory,
      lppExtraMandatoryBalance: rawExtraMandatory,
      currentLppCapital: currentLppCapital,
      pillar3aTotal: prevoyance.totalEpargne3a,
      caisseReturn: prevoyance.rendementCaisse,
      caisseReturnKnown: caisseReturnKnown,
      insuredSalaryAnnual: insuredSalaryAnnual,
      bonificationRate: bonificationRate,
      confidenceLevel: confidence,
      fingerprint: fingerprint,
    );
  }
}

String computeProfileHash(CoachProfile profile, {DateTime? now}) =>
    FinancialPlanLedgerInputs.fromProfile(profile, now: now).fingerprint;

int _currentAge(CoachProfile profile, DateTime now) {
  final dateOfBirth = profile.dateOfBirth;
  if (dateOfBirth != null) {
    var age = now.year - dateOfBirth.year;
    final beforeBirthday = now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day);
    if (beforeBirthday) age--;
    return age.clamp(0, 150);
  }
  return (now.year - profile.birthYear).clamp(0, 150);
}

Map<String, Object?> _fingerprintFact(
  CoachProfile profile,
  String path,
  Object? rawValue, {
  bool includeMetadata = true,
}) {
  return <String, Object?>{
    'path': path,
    'value': _canonicalFingerprintValue(rawValue, path),
    'source':
        includeMetadata ? _metadata(profile.dataSources, path)?.name : null,
    'updatedAt': includeMetadata
        ? _canonicalInstant(_metadata(profile.dataTimestamps, path))
        : null,
    'sourceDate': includeMetadata
        ? _canonicalSourceDate(
            _metadata<DateTime?>(profile.dataSourceDates, path),
          )
        : null,
  };
}

bool _isOwnedCurrentFact(
  CoachProfile profile,
  String path,
  double? value,
  DateTime now,
) {
  if (value == null) return false;
  final source = profile.dataSources[path];
  final capturedAt = profile.dataTimestamps[path];
  final sourceAsOf = profile.dataSourceDates[path];
  if (source == null ||
      source == ProfileDataSource.estimated ||
      capturedAt == null ||
      sourceAsOf == null ||
      capturedAt.isAfter(now) ||
      sourceAsOf.isAfter(now)) {
    return false;
  }
  final ageMonths =
      (now.year - sourceAsOf.year) * 12 + now.month - sourceAsOf.month;
  if (ageMonths < FinancialPlanLedgerInputs.currentOwnedFactMaxAgeMonths) {
    return true;
  }
  if (ageMonths > FinancialPlanLedgerInputs.currentOwnedFactMaxAgeMonths) {
    return false;
  }
  return sourceAsOf.day >= now.day;
}

void _validateNonNegativeFinite(String path, double? value) {
  if (value == null) return;
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(
      value,
      path,
      'finite non-negative plan input required',
    );
  }
}

T? _metadata<T>(Map<String, T> metadata, String path) {
  if (metadata.containsKey(path)) return metadata[path];
  if (path == _dateOfBirthPath || path == _birthYearPath) {
    return metadata['age'];
  }
  return null;
}

Object? _canonicalFingerprintValue(Object? value, String path) {
  if (value is double) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, path, 'finite plan input required');
    }
    return value == 0 ? 0.0 : value;
  }
  if (value is num && !value.isFinite) {
    throw ArgumentError.value(value, path, 'finite plan input required');
  }
  return value;
}

String _businessDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String? _canonicalSourceDate(DateTime? value) =>
    value == null ? null : _businessDate(value);

String? _canonicalInstant(DateTime? value) {
  if (value == null) return null;
  final utc = value.toUtc();
  final base = '${utc.year.toString().padLeft(4, '0')}-'
      '${utc.month.toString().padLeft(2, '0')}-'
      '${utc.day.toString().padLeft(2, '0')}T'
      '${utc.hour.toString().padLeft(2, '0')}:'
      '${utc.minute.toString().padLeft(2, '0')}:'
      '${utc.second.toString().padLeft(2, '0')}';
  final micros =
      (utc.millisecond * 1000 + utc.microsecond).toString().padLeft(6, '0');
  return '$base.${micros}Z';
}
