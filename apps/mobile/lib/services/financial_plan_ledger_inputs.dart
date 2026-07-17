import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/coach_profile_owner.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/services/financial_core/avs_reference_age.dart';
import 'package:mint_mobile/services/financial_core/swiss_civil_time.dart';

const _fingerprintPrefix = 'mint-plan-dependency:v3:sha256:';
const _calculatorContractVersion =
    'financial-plan-calculator:legal-lpp-2026:v2';
const _salaryPath = 'salaireBrutMensuel';
const _dateOfBirthPath = 'dateOfBirth';
const _genderPath = 'gender';
const _hasPensionFundPath = 'prevoyance.hasPensionFund';
const _lppTotalPath = 'prevoyance.avoirLppTotal';
const _lppMandatoryPath = 'prevoyance.avoirLppObligatoire';
const _lppExtraMandatoryPath = 'prevoyance.avoirLppSurobligatoire';
const _profileSourceAllowlist = <String, Set<ProfileDataSource>>{
  _dateOfBirthPath: {
    ProfileDataSource.userInput,
    ProfileDataSource.certificate,
  },
  _genderPath: {
    ProfileDataSource.userInput,
    ProfileDataSource.certificate,
  },
  _hasPensionFundPath: {ProfileDataSource.userInput},
  _salaryPath: {
    ProfileDataSource.userInput,
    ProfileDataSource.certificate,
  },
};

enum FinancialPlanDependencyBranch {
  general('general'),
  retirementNoLpp('retirementNoLpp'),
  retirementLpp('retirementLpp');

  const FinancialPlanDependencyBranch(this.wireName);
  final String wireName;
}

enum FinancialPlanDependencyBasis {
  none('none'),
  totalLegalSchedule('total/legalSchedule'),
  splitsLegalSchedule('splits/legalSchedule');

  const FinancialPlanDependencyBasis(this.wireName);
  final String wireName;
}

enum FinancialPlanDependencyBlocker {
  affiliation,
  dateOfBirth,
  gender,
  salary,
  lpp,
  legalContract,
  ownerAuthority,
  unexpected,
}

/// Typed preparation blocker used by UI recovery without matching messages.
class FinancialPlanDependencyBlocked extends StateError {
  FinancialPlanDependencyBlocked(this.blocker, String message) : super(message);

  final FinancialPlanDependencyBlocker blocker;

  String get code => 'financial_plan_dependency.${blocker.name}';

  String? get ledgerPath => switch (blocker) {
        FinancialPlanDependencyBlocker.affiliation => _hasPensionFundPath,
        FinancialPlanDependencyBlocker.dateOfBirth => _dateOfBirthPath,
        FinancialPlanDependencyBlocker.gender => _genderPath,
        FinancialPlanDependencyBlocker.salary => _salaryPath,
        FinancialPlanDependencyBlocker.lpp => '_coach_lpp_evidence_v1',
        FinancialPlanDependencyBlocker.legalContract =>
          'regulatory.lpp.legalContract',
        FinancialPlanDependencyBlocker.ownerAuthority => 'profileOwnerId',
        FinancialPlanDependencyBlocker.unexpected => null,
      };

  String? get collectorRoute => switch (blocker) {
        FinancialPlanDependencyBlocker.affiliation =>
          '/data-block/revenu?inputKey=q_has_pension_fund',
        FinancialPlanDependencyBlocker.dateOfBirth =>
          '/data-block/revenu?inputKey=q_date_of_birth',
        FinancialPlanDependencyBlocker.gender =>
          '/data-block/revenu?inputKey=q_gender',
        FinancialPlanDependencyBlocker.salary =>
          '/data-block/revenu?inputKey=q_gross_salary_annual',
        FinancialPlanDependencyBlocker.lpp => '/scan?type=lppCertificate',
        FinancialPlanDependencyBlocker.legalContract ||
        FinancialPlanDependencyBlocker.ownerAuthority ||
        FinancialPlanDependencyBlocker.unexpected =>
          null,
      };
}

/// Exact branch-scoped inputs consumed by one immutable financial scenario.
class FinancialPlanDependencySnapshot {
  static const currentSchemaVersion = 3;
  static const currentOwnedFactMaxAgeMonths = 24;
  static final legalContractValidUntil = SwissCivilTime.utcInstant(
    year: 2027,
    month: 1,
    day: 1,
  );

  const FinancialPlanDependencySnapshot._({
    required this.profileOwnerId,
    required this.branch,
    required this.basis,
    required this.calculatorContractVersion,
    required this.inputAsOf,
    required this.validUntil,
    required this.fingerprint,
    required this.goalCategory,
    required this.goalAmount,
    required this.targetDate,
    required this.prospectiveLppReturn,
    required this.grossMonthlySalary,
    required this.grossAnnualSalary,
    required this.currentAge,
    required this.dateOfBirth,
    required this.birthYear,
    required this.gender,
    required this.avsReferenceDate,
    required this.hasPensionFund,
    required this.currentLppCapital,
    required this.confidenceLevel,
  });

  final String profileOwnerId;
  int get schemaVersion => currentSchemaVersion;
  final FinancialPlanDependencyBranch branch;
  final FinancialPlanDependencyBasis basis;
  final String calculatorContractVersion;
  final DateTime inputAsOf;
  final DateTime validUntil;
  final String fingerprint;
  final String goalCategory;
  final double goalAmount;
  final DateTime targetDate;
  final double? prospectiveLppReturn;

  final double grossMonthlySalary;
  final double grossAnnualSalary;
  final int currentAge;
  final DateTime? dateOfBirth;
  final int birthYear;
  final String? gender;
  final DateTime? avsReferenceDate;
  final bool hasPensionFund;
  final double? currentLppCapital;
  final double confidenceLevel;

  bool get requiresPostReferenceActivity =>
      branch == FinancialPlanDependencyBranch.retirementLpp &&
      avsReferenceDate != null &&
      targetDate.isAfter(avsReferenceDate!);

  int ageAt(DateTime date) {
    final birthDate = dateOfBirth;
    if (birthDate != null) {
      var age = date.year - birthDate.year;
      if (date.month < birthDate.month ||
          (date.month == birthDate.month && date.day < birthDate.day)) {
        age--;
      }
      return age.clamp(0, 150);
    }
    return (date.year - birthYear).clamp(0, 150);
  }

  bool isRetirementTargetWithinCivilBounds() {
    final birthDate = dateOfBirth;
    if (birthDate == null) return false;
    final minimum = _birthdayAtAge(birthDate, 58);
    final maximum = _birthdayAtAge(birthDate, 70);
    final targetCivil = SwissCivilTime.businessDate(targetDate);
    return !targetCivil.isBefore(minimum) && !targetCivil.isAfter(maximum);
  }

  factory FinancialPlanDependencySnapshot.fromProfile(
    CoachProfile profile, {
    required String profileOwnerId,
    required String goalCategory,
    required double goalAmount,
    required DateTime targetDate,
    required double? prospectiveLppReturn,
    required LppEvidenceSnapshot? selfLppSnapshot,
    required DateTime now,
  }) {
    if (!isCanonicalUuidV4(profileOwnerId)) {
      throw ArgumentError.value(
        profileOwnerId,
        'profileOwnerId',
        'canonical lowercase UUIDv4 required',
      );
    }
    if (!goalAmount.isFinite || goalAmount <= 0) {
      throw ArgumentError.value(goalAmount, 'goalAmount');
    }
    final inputAsOf = now.toUtc();
    final targetCivil = SwissCivilTime.businessDate(targetDate);
    final inputCivil = SwissCivilTime.civilDate(inputAsOf);
    if (!targetCivil.isAfter(inputCivil)) {
      throw ArgumentError.value(
          targetDate, 'targetDate', 'future date required');
    }

    final isRetirement = goalCategory == 'goal_retirement_plan' ||
        goalCategory == 'goal_pension_opt';
    if (!isRetirement && prospectiveLppReturn != null) {
      throw ArgumentError.value(
        prospectiveLppReturn,
        'prospectiveLppReturn',
        'general scenarios do not consume an LPP return',
      );
    }
    final scenario = <String, Object?>{
      'goalCategory': goalCategory,
      'goalAmount': _finite(goalAmount, 'goalAmount'),
      'targetDate': _businessDate(targetCivil),
    };
    final facts = <Map<String, Object?>>[];
    final regulatory = <String, Object?>{};
    var branch = FinancialPlanDependencyBranch.general;
    var basis = FinancialPlanDependencyBasis.none;
    var validUntil = SwissCivilTime.startOfCivilDate(targetCivil);
    var grossMonthlySalary = 0.0;
    var currentLppCapital = null as double?;
    var hasPensionFund = false;
    var gender = null as String?;
    var avsReferenceDate = null as DateTime?;
    var confidenceLevel = 100.0;

    if (isRetirement) {
      final affiliation = profile.prevoyance.hasPensionFund;
      if (affiliation == null) {
        throw FinancialPlanDependencyBlocked(
          FinancialPlanDependencyBlocker.affiliation,
          'explicit pension-fund affiliation required',
        );
      }
      final affiliationFact = _profileFact(
        profile,
        _hasPensionFundPath,
        affiliation,
        blocker: FinancialPlanDependencyBlocker.affiliation,
        now: inputAsOf,
        requireOwned: true,
        requireCurrent: false,
      );
      facts.add(affiliationFact);
      hasPensionFund = affiliation;

      if (!affiliation) {
        if (prospectiveLppReturn != null) {
          throw ArgumentError.value(
            prospectiveLppReturn,
            'prospectiveLppReturn',
            'retirement scenarios without LPP do not consume an LPP return',
          );
        }
        branch = FinancialPlanDependencyBranch.retirementNoLpp;
        final birthFact = _retirementBirthFact(profile, now: inputAsOf);
        facts.add(birthFact);
        confidenceLevel = _branchConfidence([affiliationFact, birthFact]);
      } else {
        branch = FinancialPlanDependencyBranch.retirementLpp;
        if (!inputAsOf.isBefore(legalContractValidUntil)) {
          throw FinancialPlanDependencyBlocked(
            FinancialPlanDependencyBlocker.legalContract,
            'LPP legal contract expired',
          );
        }
        if (prospectiveLppReturn == null ||
            !prospectiveLppReturn.isFinite ||
            prospectiveLppReturn < 0 ||
            prospectiveLppReturn > 0.10) {
          throw ArgumentError.value(
            prospectiveLppReturn,
            'prospectiveLppReturn',
            'explicit future LPP return between zero and 10% required',
          );
        }
        scenario['prospectiveLppReturn'] = prospectiveLppReturn;
        final birthFact = _retirementBirthFact(profile, now: inputAsOf);
        facts.add(birthFact);

        final profileGender = profile.gender;
        if (profileGender != 'F' && profileGender != 'M') {
          throw FinancialPlanDependencyBlocked(
            FinancialPlanDependencyBlocker.gender,
            'canonical AVS gender required',
          );
        }
        final canonicalGender = profileGender!;
        final genderFact = _profileFact(
          profile,
          _genderPath,
          canonicalGender,
          blocker: FinancialPlanDependencyBlocker.gender,
          now: inputAsOf,
          requireOwned: true,
          requireCurrent: false,
        );
        facts.add(genderFact);
        gender = canonicalGender;
        final referenceDate = AvsReferenceAge.referenceDate(
          dateOfBirth: profile.dateOfBirth,
          birthYear: profile.birthYear,
          gender: canonicalGender,
        );
        if (referenceDate == null) {
          throw FinancialPlanDependencyBlocked(
            FinancialPlanDependencyBlocker.gender,
            'AVS reference date cannot be derived',
          );
        }
        avsReferenceDate = _civilDate(referenceDate);

        grossMonthlySalary = profile.salaireBrutMensuel;
        if (!grossMonthlySalary.isFinite || grossMonthlySalary <= 0) {
          throw FinancialPlanDependencyBlocked(
            FinancialPlanDependencyBlocker.salary,
            'current gross salary required',
          );
        }
        final salaryFact = _profileFact(
          profile,
          _salaryPath,
          grossMonthlySalary,
          blocker: FinancialPlanDependencyBlocker.salary,
          now: inputAsOf,
          requireOwned: true,
          requireCurrent: true,
        );
        facts.add(salaryFact);

        final capital = _selectLppCapital(
          profile,
          selfLppSnapshot,
          profileOwnerId: profileOwnerId,
          now: inputAsOf,
        );
        basis = capital.basis;
        currentLppCapital = capital.value;
        facts.addAll(capital.facts);

        regulatory.addAll(_regulatoryInputs());
        regulatory['avs21.referenceDate'] = _businessDate(avsReferenceDate);
        validUntil = _minimumInstant(<DateTime>[
          SwissCivilTime.startOfCivilDate(targetCivil),
          _nextBirthday(profile.dateOfBirth!, inputAsOf),
          legalContractValidUntil,
          _addCalendarMonths(
            salaryFact['updatedAtInstant']! as DateTime,
            currentOwnedFactMaxAgeMonths,
          ),
          ...capital.facts.map(
            (fact) => _addCalendarMonths(
              fact['updatedAtInstant']! as DateTime,
              currentOwnedFactMaxAgeMonths,
            ),
          ),
        ]);
        confidenceLevel = _branchConfidence([
          affiliationFact,
          birthFact,
          genderFact,
          salaryFact,
          ...capital.facts,
        ]);
      }
    }

    final canonicalFacts = facts
        .map((fact) =>
            Map<String, Object?>.from(fact)..remove('updatedAtInstant'))
        .toList(growable: false);
    final payload = jsonEncode(<String, Object?>{
      'schema': 'mint-plan-dependency',
      'version': currentSchemaVersion,
      'owner': profileOwnerId,
      'scenario': scenario,
      'branch': branch.wireName,
      'basis': basis.wireName,
      'calculatorContractVersion': _calculatorContractVersion,
      'facts': canonicalFacts,
      'regulatory': regulatory,
    });
    final fingerprint =
        '$_fingerprintPrefix${sha256.convert(utf8.encode(payload))}';

    return FinancialPlanDependencySnapshot._(
      profileOwnerId: profileOwnerId,
      branch: branch,
      basis: basis,
      calculatorContractVersion: _calculatorContractVersion,
      inputAsOf: inputAsOf,
      validUntil: validUntil,
      fingerprint: fingerprint,
      goalCategory: goalCategory,
      goalAmount: goalAmount,
      targetDate: targetCivil,
      prospectiveLppReturn: prospectiveLppReturn,
      grossMonthlySalary: grossMonthlySalary,
      grossAnnualSalary: grossMonthlySalary * 12,
      currentAge: _currentAge(profile, inputAsOf),
      dateOfBirth: profile.dateOfBirth,
      birthYear: profile.dateOfBirth?.year ?? 0,
      gender: gender,
      avsReferenceDate: avsReferenceDate,
      hasPensionFund: hasPensionFund,
      currentLppCapital: currentLppCapital,
      confidenceLevel: confidenceLevel,
    );
  }
}

({
  FinancialPlanDependencyBasis basis,
  double value,
  List<Map<String, Object?>> facts,
}) _selectLppCapital(
  CoachProfile profile,
  LppEvidenceSnapshot? snapshot, {
  required String profileOwnerId,
  required DateTime now,
}) {
  if (snapshot == null || snapshot.facts.isEmpty) {
    throw FinancialPlanDependencyBlocked(
      FinancialPlanDependencyBlocker.lpp,
      'strict self LPP snapshot required',
    );
  }
  for (final fact in snapshot.facts.values) {
    if (fact.ownerKind != LppEvidenceOwnerKind.self ||
        fact.profileOwnerId != profileOwnerId ||
        fact.actorProfileOwnerId != profileOwnerId) {
      throw FinancialPlanDependencyBlocked(
        FinancialPlanDependencyBlocker.lpp,
        'strict self LPP owner mismatch',
      );
    }
  }

  final total = snapshot.facts[LppEvidenceFactKey.vestedBenefitsCapitalChf];
  final mandatory =
      snapshot.facts[LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf];
  final extra =
      snapshot.facts[LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf];
  if (total != null &&
      mandatory != null &&
      extra != null &&
      (total.value - mandatory.value - extra.value).abs() > 1) {
    throw FinancialPlanDependencyBlocked(
      FinancialPlanDependencyBlocker.lpp,
      'incoherent strict LPP capital facts',
    );
  }

  if (total != null) {
    final fact = _strictLppFact(
      profile,
      _lppTotalPath,
      total,
      now: now,
    );
    return (
      basis: FinancialPlanDependencyBasis.totalLegalSchedule,
      value: total.value,
      facts: [fact],
    );
  }
  if (mandatory == null || extra == null) {
    throw FinancialPlanDependencyBlocked(
      FinancialPlanDependencyBlocker.lpp,
      'complete strict LPP splits required',
    );
  }
  final mandatoryFact = _strictLppFact(
    profile,
    _lppMandatoryPath,
    mandatory,
    now: now,
  );
  final extraFact = _strictLppFact(
    profile,
    _lppExtraMandatoryPath,
    extra,
    now: now,
  );
  const envelopeKeys = <String>['source', 'sourceDate', 'updatedAt'];
  if (envelopeKeys.any((key) => mandatoryFact[key] != extraFact[key])) {
    throw FinancialPlanDependencyBlocked(
      FinancialPlanDependencyBlocker.lpp,
      'strict LPP splits do not share one review envelope',
    );
  }
  return (
    basis: FinancialPlanDependencyBasis.splitsLegalSchedule,
    value: mandatory.value + extra.value,
    facts: [mandatoryFact, extraFact],
  );
}

Map<String, Object?> _strictLppFact(
  CoachProfile profile,
  String path,
  LppEvidenceFact fact, {
  required DateTime now,
}) {
  final profileValue = switch (path) {
    _lppTotalPath => profile.prevoyance.avoirLppTotal,
    _lppMandatoryPath => profile.prevoyance.avoirLppObligatoire,
    _lppExtraMandatoryPath => profile.prevoyance.avoirLppSurobligatoire,
    _ => null,
  };
  if (profileValue != fact.value ||
      profile.dataSources[path]?.name != fact.source ||
      profile.dataTimestamps[path]?.toUtc() != fact.updatedAt.toUtc() ||
      profile.dataSourceDates[path]?.toUtc() != fact.sourceDate?.toUtc()) {
    throw FinancialPlanDependencyBlocked(
      FinancialPlanDependencyBlocker.lpp,
      'profile and strict LPP snapshot metadata mismatch',
    );
  }
  if (!_isOwnedSource(profile.dataSources[path]) ||
      !_isCurrentAnnualFact(fact.updatedAt, now)) {
    throw FinancialPlanDependencyBlocked(
      FinancialPlanDependencyBlocker.lpp,
      'strict LPP capital is not current owned evidence',
    );
  }
  if (fact.sourceDate != null &&
      SwissCivilTime.isFutureCivilDate(fact.sourceDate!, now: now)) {
    throw FinancialPlanDependencyBlocked(
      FinancialPlanDependencyBlocker.lpp,
      'future LPP source date',
    );
  }
  return <String, Object?>{
    'path': path,
    'value': _finite(fact.value, path),
    'source': fact.source,
    'updatedAt': _canonicalInstant(fact.updatedAt),
    'sourceDate': _canonicalSourceDate(fact.sourceDate),
    'updatedAtInstant': fact.updatedAt.toUtc(),
  };
}

Map<String, Object?> _profileFact(
  CoachProfile profile,
  String path,
  Object value, {
  required FinancialPlanDependencyBlocker blocker,
  required DateTime now,
  required bool requireOwned,
  required bool requireCurrent,
}) {
  final source = profile.dataSources[path];
  final updatedAt = profile.dataTimestamps[path]?.toUtc();
  final sourceDate = profile.dataSourceDates[path];
  final allowedSources = _profileSourceAllowlist[path];
  if (requireOwned &&
      (allowedSources == null ||
          source == null ||
          !allowedSources.contains(source) ||
          updatedAt == null)) {
    throw FinancialPlanDependencyBlocked(
      blocker,
      '$path source is outside its ledger allowlist',
    );
  }
  if (updatedAt != null && updatedAt.isAfter(now)) {
    throw FinancialPlanDependencyBlocked(
      blocker,
      '$path has a future update time',
    );
  }
  if (sourceDate != null &&
      SwissCivilTime.isFutureCivilDate(sourceDate, now: now)) {
    throw FinancialPlanDependencyBlocked(
      blocker,
      '$path has a future source date',
    );
  }
  if (requireCurrent &&
      (updatedAt == null || !_isCurrentAnnualFact(updatedAt, now))) {
    throw FinancialPlanDependencyBlocked(
      blocker,
      '$path is older than 24 months',
    );
  }
  return <String, Object?>{
    'path': path,
    'value': value is num ? _finite(value.toDouble(), path) : value,
    'source': source?.name,
    'updatedAt': _canonicalInstant(updatedAt),
    'sourceDate': _canonicalSourceDate(sourceDate),
    if (updatedAt != null) 'updatedAtInstant': updatedAt,
  };
}

Map<String, Object?> _retirementBirthFact(
  CoachProfile profile, {
  required DateTime now,
}) {
  final birthDate = profile.dateOfBirth;
  if (birthDate != null &&
      SwissCivilTime.isSupportedAdultBirthDate(birthDate, now: now)) {
    return _profileFact(
      profile,
      _dateOfBirthPath,
      _businessDate(_civilDate(birthDate)),
      blocker: FinancialPlanDependencyBlocker.dateOfBirth,
      now: now,
      requireOwned: true,
      requireCurrent: false,
    );
  }
  throw FinancialPlanDependencyBlocked(
    FinancialPlanDependencyBlocker.dateOfBirth,
    'exact date of birth required',
  );
}

bool _isOwnedSource(ProfileDataSource? source) =>
    source != null && source != ProfileDataSource.estimated;

bool _isCurrentAnnualFact(DateTime updatedAt, DateTime now) =>
    now.isBefore(_addCalendarMonths(updatedAt.toUtc(), 24));

Map<String, Object?> _regulatoryInputs() => <String, Object?>{
      'lpp.entry_threshold': reg('lpp.entry_threshold', lppSeuilEntree),
      'lpp.coordination_deduction':
          reg('lpp.coordination_deduction', lppDeductionCoordination),
      'lpp.min_coordinated_salary':
          reg('lpp.min_coordinated_salary', lppSalaireCoordMin),
      'lpp.max_coordinated_salary':
          reg('lpp.max_coordinated_salary', lppSalaireCoordMax),
      'lpp.bonification.25_34': lppBonificationsVieillesse['25-34'],
      'lpp.bonification.35_44': lppBonificationsVieillesse['35-44'],
      'lpp.bonification.45_54': lppBonificationsVieillesse['45-54'],
      'lpp.bonification.55_65': lppBonificationsVieillesse['55-65'],
    };

double _branchConfidence(List<Map<String, Object?>> facts) {
  if (facts.isEmpty) return 100;
  final scores = facts.map((fact) {
    return switch (fact['source']) {
      'userInput' => 60.0,
      'crossValidated' => 70.0,
      'certificate' => 95.0,
      'openBanking' => 100.0,
      _ => 0.0,
    };
  });
  return scores.reduce((a, b) => a + b) / scores.length;
}

int _currentAge(CoachProfile profile, DateTime now) {
  final birthDate = profile.dateOfBirth;
  if (birthDate == null) return 0;
  final nowCivil = SwissCivilTime.civilDate(now);
  var age = nowCivil.year - birthDate.year;
  if (nowCivil.month < birthDate.month ||
      (nowCivil.month == birthDate.month && nowCivil.day < birthDate.day)) {
    age--;
  }
  return age.clamp(0, 150);
}

DateTime _addCalendarMonths(DateTime value, int months) {
  final utc = value.toUtc();
  final total = utc.year * 12 + utc.month - 1 + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final maxDay = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(
    year,
    month,
    utc.day.clamp(1, maxDay),
    utc.hour,
    utc.minute,
    utc.second,
    utc.millisecond,
    utc.microsecond,
  );
}

DateTime _nextBirthday(DateTime birthDate, DateTime now) {
  DateTime candidate(int year) {
    final maxDay = DateTime.utc(year, birthDate.month + 1, 0).day;
    return DateTime.utc(year, birthDate.month, birthDate.day.clamp(1, maxDay));
  }

  final nowCivil = SwissCivilTime.civilDate(now);
  var next = candidate(nowCivil.year);
  if (!next.isAfter(nowCivil)) next = candidate(nowCivil.year + 1);
  return SwissCivilTime.startOfCivilDate(next);
}

DateTime _birthdayAtAge(DateTime birthDate, int age) {
  final year = birthDate.year + age;
  final maxDay = DateTime.utc(year, birthDate.month + 1, 0).day;
  return DateTime.utc(
    year,
    birthDate.month,
    birthDate.day.clamp(1, maxDay),
  );
}

DateTime _minimumInstant(List<DateTime> values) =>
    values.reduce((a, b) => a.isBefore(b) ? a : b);

DateTime _civilDate(DateTime value) => SwissCivilTime.businessDate(value);

String _businessDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String? _canonicalSourceDate(DateTime? value) =>
    value == null ? null : _businessDate(_civilDate(value));

String? _canonicalInstant(DateTime? value) => value?.toUtc().toIso8601String();

double _finite(double value, String path) {
  if (!value.isFinite) throw ArgumentError.value(value, path);
  return value == 0 ? 0 : value;
}
