import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object?> _coldLppContract(CoachProfile profile) {
  Map<String, Object?> fact(
    String path,
    double? value,
  ) {
    return <String, Object?>{
      'value': value,
      'source': profile.dataSources[path]?.name,
      'hasUpdatedAt': profile.dataTimestamps.containsKey(path),
      'hasSourceDateSlot': profile.dataSourceDates.containsKey(path),
      'sourceDate': profile.dataSourceDates[path]?.toIso8601String(),
    };
  }

  return <String, Object?>{
    'retirementPensionAnnual': fact(
      'prevoyance.projectedRenteLpp',
      profile.prevoyance.projectedRenteLpp,
    ),
    'retirementCapitalLumpSum': fact(
      'prevoyance.projectedCapital65',
      profile.prevoyance.projectedCapital65,
    ),
    'disabilityPensionAnnual': fact(
      'prevoyance.disabilityCoverage',
      profile.prevoyance.disabilityCoverage,
    ),
    'deathCapitalLumpSum': fact(
      'prevoyance.deathCoverage',
      profile.prevoyance.deathCoverage,
    ),
  };
}

Map<String, Object?> _expectedFact(double value) => <String, Object?>{
      'value': value,
      'source': ProfileDataSource.certificate.name,
      'hasUpdatedAt': true,
      'hasSourceDateSlot': true,
      'sourceDate': null,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorage =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorageValues = <String, String>{};

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
      final key = args['key'] as String?;
      switch (call.method) {
        case 'write':
          if (key != null) secureStorageValues[key] = args['value'] as String;
          return null;
        case 'read':
          return key == null ? null : secureStorageValues[key];
        case 'readAll':
          return Map<String, String>.from(secureStorageValues);
        case 'delete':
          if (key != null) secureStorageValues.remove(key);
          return null;
        case 'deleteAll':
          secureStorageValues.clear();
          return null;
      }
      return null;
    });
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    secureStorageValues.clear();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, null);
  });

  test('confirmed self LPP projections and provenance survive restart',
      () async {
    await ReportPersistenceService.saveAnswers(<String, dynamic>{
      'q_birth_year': DateTime.now().year - 45,
      'q_canton': 'VD',
      'q_gross_salary_annual': 96000.0,
      'q_civil_status': 'celibataire',
      'q_has_pension_fund': 'yes',
    });
    await ReportPersistenceService.setCompleted(true);

    var writer = CoachProfileProvider();
    await writer.loadFromWizard();
    expect(writer.profile, isNotNull);

    await writer.updateFromLppExtraction(const <ExtractedField>[
      ExtractedField(
        fieldName: 'projected_rente',
        label: 'retirement-pension-fixture',
        value: 31450.0,
        confidence: 0.99,
        sourceText: 'RAW_OCR_RETIREMENT_PENSION_DO_NOT_PERSIST',
        needsReview: false,
        profileField: 'projectedRenteLpp',
      ),
      ExtractedField(
        fieldName: 'projected_capital_65',
        label: 'retirement-capital-fixture',
        value: 485200.0,
        confidence: 0.99,
        sourceText: 'RAW_OCR_RETIREMENT_CAPITAL_DO_NOT_PERSIST',
        needsReview: false,
        profileField: 'projectedCapital65',
      ),
      ExtractedField(
        fieldName: 'disability_coverage',
        label: 'annual-disability-pension-fixture',
        value: 36800.0,
        confidence: 0.99,
        sourceText: 'RAW_OCR_DISABILITY_PENSION_DO_NOT_PERSIST',
        needsReview: false,
        profileField: 'disabilityCoverage',
      ),
      ExtractedField(
        fieldName: 'death_coverage',
        label: 'death-capital-fixture',
        value: 220500.0,
        confidence: 0.99,
        sourceText: 'RAW_OCR_DEATH_CAPITAL_DO_NOT_PERSIST',
        needsReview: false,
        profileField: 'deathCoverage',
      ),
    ]);

    final prefs = await SharedPreferences.getInstance();
    final serialized = <String>[
      prefs.getString('wizard_answers_v2') ?? '',
      ...secureStorageValues.values,
    ].join('\n');
    expect(serialized, isNot(contains('RAW_OCR_')));
    expect(serialized, isNot(contains('sourceText')));
    expect(serialized, isNot(contains('rawOcr')));

    writer.dispose();
    writer = CoachProfileProvider();
    await writer.loadFromWizard();
    final coldProfile = writer.profile;
    expect(coldProfile, isNotNull);

    expect(
      _coldLppContract(coldProfile!),
      <String, Object?>{
        'retirementPensionAnnual': _expectedFact(31450.0),
        'retirementCapitalLumpSum': _expectedFact(485200.0),
        'disabilityPensionAnnual': _expectedFact(36800.0),
        'deathCapitalLumpSum': _expectedFact(220500.0),
      },
      reason: 'confirmed person-owned LPP facts must cross the real '
          'persisted-answer boundary with canonical provenance',
    );
  });
}
