import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/navigation/readiness_gate.dart';
import 'package:mint_mobile/services/navigation/screen_registry.dart';

const _missingApi = 'missing-api';

Object? _readDynamic(Object? Function() read) {
  try {
    return read();
  } on NoSuchMethodError {
    return _missingApi;
  }
}

void _expectContract(
  Map<String, Object?> actual,
  Map<String, Object?> expected,
) {
  for (final entry in expected.entries) {
    expect(actual, containsPair(entry.key, entry.value), reason: entry.key);
  }
}

Map<String, dynamic> _jurisdictionAnswers({
  Object? residenceCountry = 'FR',
  Object? workCountry = 'CH',
  Object? workCanton = 'GE',
}) =>
    <String, dynamic>{
      'q_birth_year': 1985,
      'q_residence_country': residenceCountry,
      'q_work_country': workCountry,
      'q_work_canton': workCanton,
    };

Map<String, dynamic> _provenanceAnswers({
  required DateTime updatedAt,
  String source = 'userInput',
  DateTime? sourceDate,
  Object? residenceCountry = 'FR',
  Object? workCountry = 'CH',
  Object? workCanton = 'GE',
}) {
  Map<String, Object?> envelope() => <String, Object?>{
        'source': source,
        'updatedAt': updatedAt.toIso8601String(),
        'sourceDate': sourceDate?.toIso8601String(),
      };

  return <String, dynamic>{
    ..._jurisdictionAnswers(
      residenceCountry: residenceCountry,
      workCountry: workCountry,
      workCanton: workCanton,
    ),
    '__provenance': <String, Object?>{
      'residenceCountry': envelope(),
      'workCountry': envelope(),
      if (workCanton != null) 'workCanton': envelope(),
    },
  };
}

Map<String, Object?> _contract(dynamic profile, DateTime asOf) {
  final evidence = _readDynamic(() => profile.frontierJurisdictionAt(asOf));
  return <String, Object?>{
    'residenceType': _readDynamic(
      () => profile.residenceCountry?.runtimeType.toString(),
    ),
    'residence': _readDynamic(() => profile.residenceCountry?.value),
    'workType': _readDynamic(() => profile.workCountry?.runtimeType.toString()),
    'work': _readDynamic(() => profile.workCountry?.value),
    'cantonType':
        _readDynamic(() => profile.workCanton?.runtimeType.toString()),
    'canton': _readDynamic(() => profile.workCanton?.value),
    'state': evidence == _missingApi
        ? _missingApi
        : _readDynamic(() => (evidence as dynamic).state.name),
    'ready': evidence == _missingApi
        ? _missingApi
        : _readDynamic(() => (evidence as dynamic).jurisdictionReady),
    'crossBorder': evidence == _missingApi
        ? _missingApi
        : _readDynamic(() => (evidence as dynamic).crossBorder),
    'candidate': evidence == _missingApi
        ? _missingApi
        : _readDynamic(
            () => (evidence as dynamic).candidateTaxInstrument?.name,
          ),
    'missing': evidence == _missingApi
        ? const <String>[]
        : List<String>.from(
            _readDynamic(() => (evidence as dynamic).missingFields)
                    as Iterable? ??
                const <String>[],
          ),
    'stale': evidence == _missingApi
        ? const <String>[]
        : List<String>.from(
            _readDynamic(() => (evidence as dynamic).staleFields)
                    as Iterable? ??
                const <String>[],
          ),
  };
}

void main() {
  final asOf = DateTime.utc(2026, 7, 17, 12);

  test('RED harness reads the real production sources', () {
    expect(CoachProfile.defaults().canton, isEmpty);
    expect(File('lib/models/coach_profile.dart').existsSync(), isTrue);
    expect(File('lib/screens/frontalier_screen.dart').existsSync(), isTrue);
  });

  test('three jurisdiction value objects are typed, nullable, and distinct',
      () {
    final dynamic known = CoachProfile.fromWizardAnswers(
      _jurisdictionAnswers(),
      now: () => asOf,
    );
    final dynamic empty = CoachProfile.defaults();

    _expectContract(
      _contract(known, asOf),
      <String, Object?>{
        'residenceType': 'CountryCode',
        'residence': 'FR',
        'workType': 'CountryCode',
        'work': 'CH',
        'cantonType': 'SwissCantonCode',
        'canton': 'GE',
      },
    );
    _expectContract(
      _contract(empty, asOf),
      <String, Object?>{
        'residence': null,
        'work': null,
        'canton': null,
        'ready': false,
        'crossBorder': null,
      },
    );
  });

  test('canonical answer keys own markers, source, timestamp, and date slot',
      () {
    final profile = CoachProfile.fromWizardAnswers(
      _jurisdictionAnswers(),
      now: () => asOf,
    );

    for (final path in const <String>{
      'residenceCountry',
      'workCountry',
      'workCanton',
    }) {
      expect(profile.userProvidedFields, contains(path), reason: path);
      expect(
        profile.dataSources[path],
        ProfileDataSource.userInput,
        reason: path,
      );
      expect(profile.dataTimestamps[path], asOf, reason: path);
      expect(profile.dataSourceDates, contains(path), reason: path);
      expect(profile.dataSourceDates[path], isNull, reason: path);
    }
    expect(_contract(profile, asOf)['state'], 'known');
  });

  test('each required jurisdiction fails closed without invented defaults', () {
    final cases = <({
      Object? residence,
      Object? work,
      Object? canton,
      String missing,
    })>[
      (residence: null, work: 'CH', canton: 'GE', missing: 'residenceCountry'),
      (residence: 'FR', work: null, canton: 'GE', missing: 'workCountry'),
      (residence: 'FR', work: 'CH', canton: null, missing: 'workCanton'),
    ];

    for (final fixture in cases) {
      final profile = CoachProfile.fromWizardAnswers(
        _jurisdictionAnswers(
          residenceCountry: fixture.residence,
          workCountry: fixture.work,
          workCanton: fixture.canton,
        ),
        now: () => asOf,
      );
      final contract = _contract(profile, asOf);
      expect(contract['state'], 'missing', reason: fixture.missing);
      expect(contract['ready'], isFalse, reason: fixture.missing);
      expect(contract['crossBorder'], isNull, reason: fixture.missing);
      expect(contract['candidate'], isNull, reason: fixture.missing);
      expect(contract['missing'], contains(fixture.missing));
    }

    final nonSwissWork = CoachProfile.fromWizardAnswers(
      _jurisdictionAnswers(
        residenceCountry: 'CH',
        workCountry: 'FR',
        workCanton: null,
      ),
      now: () => asOf,
    );
    expect(_contract(nonSwissWork, asOf)['ready'], isTrue);
    expect(_contract(nonSwissWork, asOf)['crossBorder'], isTrue);
    expect(_contract(nonSwissWork, asOf)['state'], 'specialistOnly');
  });

  test('domestic, Geneva CDI, and 1983 candidate remain distinct', () {
    Map<String, Object?> read(String residence, String canton) => _contract(
          CoachProfile.fromWizardAnswers(
            _jurisdictionAnswers(
              residenceCountry: residence,
              workCountry: 'CH',
              workCanton: canton,
            ),
            now: () => asOf,
          ),
          asOf,
        );

    _expectContract(
      read('CH', 'GE'),
      <String, Object?>{
        'ready': true,
        'crossBorder': false,
        'candidate': 'domestic',
      },
    );
    _expectContract(
      read('FR', 'GE'),
      <String, Object?>{
        'ready': true,
        'crossBorder': true,
        'candidate': 'cdi1966Article17',
      },
    );
    _expectContract(
      read('FR', 'VD'),
      <String, Object?>{
        'ready': true,
        'crossBorder': true,
        'candidate': 'accord1983Candidate',
      },
    );
  });

  test('permit, nationality, residence canton, and status infer nothing', () {
    final legacy = CoachProfile.fromWizardAnswers(<String, dynamic>{
      'q_birth_year': 1985,
      'q_residence_permit': 'G',
      'q_nationality': 'FR',
      'q_canton': 'GE',
      'q_employment_status': 'frontalier',
    });
    _expectContract(
      _contract(legacy, asOf),
      <String, Object?>{
        'residence': null,
        'work': null,
        'canton': null,
        'ready': false,
        'crossBorder': null,
      },
    );
  });

  test('names and unknown jurisdiction codes are rejected', () {
    final invalid = CoachProfile.fromWizardAnswers(
      _jurisdictionAnswers(
        residenceCountry: 'France',
        workCountry: 'XX',
        workCanton: 'ZZ',
      ),
    );
    expect(_contract(invalid, asOf)['residence'], isNull);
    expect(_contract(invalid, asOf)['work'], isNull);
    expect(_contract(invalid, asOf)['canton'], isNull);
  });

  test('JSON reconstruction preserves jurisdiction values and provenance', () {
    final dynamic profile = CoachProfile.fromWizardAnswers(
      _jurisdictionAnswers(),
      now: () => asOf,
    );
    final json = profile.toJson() as Map<String, dynamic>;
    expect(json['residenceCountry'], 'FR');
    expect(json['workCountry'], 'CH');
    expect(json['workCanton'], 'GE');

    final restored = CoachProfile.fromJson(json);
    expect(_contract(restored, asOf), _contract(profile, asOf));
  });

  test('copyWith preserves jurisdiction facts and supports explicit clearing',
      () {
    final dynamic profile = CoachProfile.fromWizardAnswers(
      _jurisdictionAnswers(),
      now: () => asOf,
    );
    final dynamic unchanged = profile.copyWith();
    expect(_contract(unchanged, asOf), _contract(profile, asOf));

    final dynamic cleared = _readDynamic(
      () => profile.copyWith(workCanton: null),
    );
    expect(cleared, isNot(_missingApi));
    expect(_contract(cleared, asOf)['canton'], isNull);
    expect(cleared.dataSources, isNot(contains('workCanton')));
    expect(cleared.dataTimestamps, isNot(contains('workCanton')));
    expect(cleared.dataSourceDates, isNot(contains('workCanton')));
  });

  test('accepted provenance is required and future timestamps fail closed', () {
    for (final source in const ['estimated', 'openBanking']) {
      final profile = CoachProfile.fromWizardAnswers(
        _provenanceAnswers(updatedAt: asOf, source: source),
        now: () => asOf,
      );
      expect(_contract(profile, asOf)['ready'], isFalse, reason: source);
      expect(_contract(profile, asOf)['candidate'], isNull, reason: source);
    }

    final future = CoachProfile.fromWizardAnswers(
      _provenanceAnswers(
        updatedAt: asOf.add(const Duration(days: 1)),
      ),
      now: () => asOf,
    );
    expect(_contract(future, asOf)['ready'], isFalse);
    expect(_contract(future, asOf)['candidate'], isNull);

    for (final source in const ['userInput', 'certificate']) {
      final profile = CoachProfile.fromWizardAnswers(
        _provenanceAnswers(updatedAt: asOf, source: source),
        now: () => asOf,
      );
      expect(_contract(profile, asOf)['ready'], isTrue, reason: source);
    }
  });

  test('country facts have no TTL but work canton crosses stale at 783 days',
      () {
    CoachProfile profile({
      required int countryDays,
      required int cantonDays,
      DateTime? sourceDate,
    }) {
      Map<String, Object?> envelope(int days) => <String, Object?>{
            'source': 'userInput',
            'updatedAt': asOf.subtract(Duration(days: days)).toIso8601String(),
            'sourceDate': sourceDate?.toIso8601String(),
          };

      return CoachProfile.fromWizardAnswers(<String, dynamic>{
        ..._jurisdictionAnswers(),
        '__provenance': <String, Object?>{
          'residenceCountry': envelope(countryDays),
          'workCountry': envelope(countryDays),
          'workCanton': envelope(cantonDays),
        },
      }, now: () => asOf);
    }

    final at782 = profile(
      countryDays: 2000,
      cantonDays: 782,
      sourceDate: asOf.subtract(const Duration(days: 5000)),
    );
    expect(_contract(at782, asOf)['state'], 'known');
    expect(_contract(at782, asOf)['ready'], isTrue);

    final at783 = profile(countryDays: 2000, cantonDays: 783);
    expect(_contract(at783, asOf)['state'], 'stale');
    expect(_contract(at783, asOf)['ready'], isFalse);
    expect(_contract(at783, asOf)['crossBorder'], isNull);
    expect(_contract(at783, asOf)['candidate'], isNull);
    expect(_contract(at783, asOf)['stale'], contains('workCanton'));
  });

  test('permit G cannot fabricate 3a eligibility', () {
    final profile = CoachProfile.defaults().copyWith(
      residencePermit: 'G',
      salaireBrutMensuel: 10000,
      prevoyance: const PrevoyanceProfile(canContribute3a: false),
    );
    expect(profile.canContribute3a, isFalse);
  });

  test('permit G without canonical jurisdictions is only partial readiness',
      () {
    final profile = CoachProfile.defaults().copyWith(residencePermit: 'G');
    final entry = MintScreenRegistry.findByIntentStatic('cross_border')!;
    final readiness = ReadinessGate.check(entry, profile);
    expect(readiness.level, ReadinessLevel.partial);
    expect(
      readiness.missingFields,
      containsAll(<String>[
        'residenceCountry',
        'workCountry',
        'workCanton',
      ]),
    );
  });

  test('live screen quarantines invented defaults and legal calculators', () {
    final screen =
        File('lib/screens/frontalier_screen.dart').readAsStringSync();
    for (final forbidden in const <String>[
      'ExpatService',
      'calculateSourceTax',
      'simulate90DayRule',
      'compareSocialCharges',
      "String _taxCanton = 'GE'",
      'double _taxSalary = 7000',
      'int _bureauDays = 180',
      'int _homeOfficeDays = 40',
      "String _chargesCountry = 'France'",
    ]) {
      expect(screen, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('free-margin engine does not route permit G into a tax approximation',
      () {
    final cap =
        File('lib/services/cap_sequence_engine.dart').readAsStringSync();
    expect(cap, isNot(contains('isCrossBorder: profile.isCrossBorder')));
  });

  test('net-income engine contains no flat frontier withholding table', () {
    final tax = File('lib/services/financial_core/tax_calculator.dart')
        .readAsStringSync();
    expect(tax, isNot(contains('baseWithholdingRates')));
    expect(tax, isNot(contains('bool isCrossBorder = false')));
  });
}
