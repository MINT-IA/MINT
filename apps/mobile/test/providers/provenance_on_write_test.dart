import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _ProfileValueReader = Object? Function(CoachProfile profile);

Future<CoachProfileProvider> _seededProvider() async {
  await ReportPersistenceService.saveAnswers({
    'q_birth_year': DateTime.now().year - 45,
    'q_canton': 'VD',
    'q_gross_salary_annual': 96000,
    'q_civil_status': 'celibataire',
    'q_has_pension_fund': 'yes',
  });
  await ReportPersistenceService.setCompleted(true);

  final provider = CoachProfileProvider();
  await provider.loadFromWizard();
  expect(provider.profile, isNotNull);
  return provider;
}

void _expectSourceDateSlot(
  CoachProfile profile,
  String fieldPath, {
  required Object? expected,
}) {
  final serialized = profile.toJson();
  expect(
    serialized,
    contains('dataSourceDates'),
    reason: '$fieldPath must serialize a nullable sourceDate slot',
  );
  final rawDates = serialized['dataSourceDates'];
  expect(
    rawDates,
    isA<Map>(),
    reason: 'dataSourceDates must be a per-field map',
  );
  final dates = rawDates! as Map;
  expect(
    dates.containsKey(fieldPath),
    isTrue,
    reason: '$fieldPath must be present even when sourceDate is null',
  );
  expect(dates[fieldPath], expected);
}

Future<void> _expectAtomicColdRoundTrip({
  required CoachProfileProvider writer,
  required String fieldPath,
  required ProfileDataSource expectedSource,
  required Object? expectedValue,
  required _ProfileValueReader readValue,
  required DateTime writeStartedAt,
  required DateTime writeCompletedAt,
}) async {
  final immediate = writer.profile!;
  expect(
    readValue(immediate),
    expectedValue,
    reason: '$fieldPath value must be visible after the awaited write',
  );
  expect(
    immediate.dataSources[fieldPath],
    expectedSource,
    reason: '$fieldPath source must be committed with its value',
  );
  final immediateUpdatedAt = immediate.dataTimestamps[fieldPath];
  expect(
    immediateUpdatedAt,
    isNotNull,
    reason: '$fieldPath needs its own updatedAt',
  );
  expect(immediateUpdatedAt!.isBefore(writeStartedAt), isFalse);
  expect(immediateUpdatedAt.isAfter(writeCompletedAt), isFalse);
  _expectSourceDateSlot(immediate, fieldPath, expected: null);

  final coldProvider = CoachProfileProvider();
  await coldProvider.loadFromWizard();
  final cold = coldProvider.profile;
  expect(cold, isNotNull, reason: '$fieldPath must survive a cold hydration');
  expect(
    readValue(cold!),
    expectedValue,
    reason: '$fieldPath value changed after cold hydration',
  );
  expect(
    cold.dataSources[fieldPath],
    expectedSource,
    reason: '$fieldPath source was not durably persisted',
  );
  expect(
    cold.dataTimestamps[fieldPath],
    immediateUpdatedAt,
    reason: '$fieldPath updatedAt was regenerated instead of rehydrated',
  );
  _expectSourceDateSlot(cold, fieldPath, expected: null);
}

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
    SharedPreferences.setMockInitialValues({});
    secureStorageValues.clear();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, null);
  });

  test('manual housing fact commits value and provenance atomically', () async {
    final provider = await _seededProvider();
    final startedAt = DateTime.now();

    await provider.mergeAnswers({'q_property_market_value': 1250000.0});

    final completedAt = DateTime.now();
    await _expectAtomicColdRoundTrip(
      writer: provider,
      fieldPath: 'patrimoine.propertyMarketValue',
      expectedSource: ProfileDataSource.userInput,
      expectedValue: 1250000.0,
      readValue: (profile) => profile.patrimoine.propertyMarketValue,
      writeStartedAt: startedAt,
      writeCompletedAt: completedAt,
    );
  });

  test('confirmed LPP certificate fact commits value and provenance atomically',
      () async {
    final provider = await _seededProvider();
    final startedAt = DateTime.now();

    await provider.updateFromLppExtraction(const [
      ExtractedField(
        fieldName: 'salaire_assure',
        label: 'Salaire assuré',
        value: 84000.0,
        confidence: 0.96,
        sourceText: 'Salaire assuré 84 000',
        needsReview: false,
        profileField: 'lppInsuredSalary',
      ),
    ]);

    final completedAt = DateTime.now();
    await _expectAtomicColdRoundTrip(
      writer: provider,
      fieldPath: 'prevoyance.salaireAssure',
      expectedSource: ProfileDataSource.certificate,
      expectedValue: 84000.0,
      readValue: (profile) => profile.prevoyance.salaireAssure,
      writeStartedAt: startedAt,
      writeCompletedAt: completedAt,
    );
  });

  test('open-banking liquidity fact commits value and provenance atomically',
      () async {
    final provider = await _seededProvider();
    final startedAt = DateTime.now();

    await provider.updateFromOpenBanking(
      accounts: const [
        {'accountType': 'checking', 'balance': 17500.0},
      ],
      categoryTotals: const {},
    );

    final completedAt = DateTime.now();
    await _expectAtomicColdRoundTrip(
      writer: provider,
      fieldPath: 'patrimoine.epargneLiquide',
      expectedSource: ProfileDataSource.openBanking,
      expectedValue: 17500.0,
      readValue: (profile) => profile.patrimoine.epargneLiquide,
      writeStartedAt: startedAt,
      writeCompletedAt: completedAt,
    );
  });

  test('coach gross-income fact commits value and provenance atomically',
      () async {
    final provider = await _seededProvider();
    final startedAt = DateTime.now();

    final applied = await provider.applySaveFact('incomeGrossYearly', 132000.0);

    expect(applied, isTrue, reason: 'canonical coach fact must be accepted');
    final completedAt = DateTime.now();
    await _expectAtomicColdRoundTrip(
      writer: provider,
      fieldPath: 'salaireBrutMensuel',
      expectedSource: ProfileDataSource.userInput,
      expectedValue: 11000.0,
      readValue: (profile) => profile.salaireBrutMensuel,
      writeStartedAt: startedAt,
      writeCompletedAt: completedAt,
    );
  });
}
