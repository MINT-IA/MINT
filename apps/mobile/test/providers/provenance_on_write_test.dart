import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _ProfileValueReader = Object? Function(CoachProfile profile);

final class _TrackingLppPersistence implements LppProfilePersistence {
  int loadCalls = 0;
  int saveCalls = 0;
  Map<String, dynamic> answers = <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> loadAnswers() async {
    loadCalls += 1;
    return Map<String, dynamic>.from(answers);
  }

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    saveCalls += 1;
    answers = Map<String, dynamic>.from(next);
  }
}

Future<CoachProfileProvider> _seededProvider({
  LppProfilePersistence? lppProfilePersistence,
}) async {
  await ReportPersistenceService.saveAnswers({
    'q_birth_year': DateTime.now().year - 45,
    'q_canton': 'VD',
    'q_gross_salary_annual': 96000,
    'q_civil_status': 'celibataire',
    'q_has_pension_fund': 'yes',
  });
  await ReportPersistenceService.setCompleted(true);

  final provider = CoachProfileProvider(
    lppProfilePersistence: lppProfilePersistence,
  );
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
  DateTime? expectedSourceDate,
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
  _expectSourceDateSlot(
    immediate,
    fieldPath,
    expected: expectedSourceDate?.toIso8601String(),
  );

  final persistedAnswers = await ReportPersistenceService.loadAnswers();
  final rawProvenance = persistedAnswers['__provenance'];
  expect(rawProvenance, isA<Map>());
  final rawEnvelope = (rawProvenance! as Map)[fieldPath];
  expect(rawEnvelope, isA<Map>());
  final envelope = Map<String, dynamic>.from(rawEnvelope! as Map);
  expect(
    envelope.keys.toSet(),
    {'source', 'updatedAt', 'sourceDate'},
    reason: '$fieldPath must use the one canonical provenance shape',
  );
  expect(envelope['source'], expectedSource.name);
  expect(envelope['updatedAt'], immediateUpdatedAt.toIso8601String());
  expect(envelope['sourceDate'], expectedSourceDate?.toIso8601String());

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
  _expectSourceDateSlot(
    cold,
    fieldPath,
    expected: expectedSourceDate?.toIso8601String(),
  );
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
    final previousValue = provider.profile!.patrimoine.propertyMarketValue;
    var notifications = 0;
    provider.addListener(() => notifications++);

    final write = provider.mergeAnswers({
      'q_property_market_value': 1250000.0,
    });

    expect(provider.profile!.patrimoine.propertyMarketValue, previousValue);
    expect(notifications, 0, reason: 'merge must not publish before save');
    await write;
    expect(notifications, 1, reason: 'merge publishes one durable snapshot');

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
    FeatureFlags.typedLppEvidence = true;
    addTearDown(() => FeatureFlags.typedLppEvidence = false);
    final provider = await _seededProvider();
    final startedAt = DateTime.now();
    final sourceDate = DateTime.utc(2026, 6, 30);

    await provider.acceptLppReview(
      LppReviewConfirmation.self(
        sourceDate: sourceDate,
        facts: const {
          LppEvidenceFactKey.insuredSalaryAnnualChf: LppReviewedFact(
            value: 84000.0,
            unit: LppEvidenceUnit.chfPerYear,
          ),
        },
      ),
    );

    final completedAt = DateTime.now();
    await _expectAtomicColdRoundTrip(
      writer: provider,
      fieldPath: 'prevoyance.salaireAssure',
      expectedSource: ProfileDataSource.certificate,
      expectedValue: 84000.0,
      readValue: (profile) => profile.prevoyance.salaireAssure,
      writeStartedAt: startedAt,
      writeCompletedAt: completedAt,
      expectedSourceDate: sourceDate,
    );
    expect(
      provider.profile!.prevoyance.lppEvidenceStatus(
        LppEvidenceFactKey.insuredSalaryAnnualChf,
      ),
      LppEvidenceStatus.available,
    );
  });

  test('direct incoherent LPP review rejects before persistence or publication',
      () async {
    FeatureFlags.typedLppEvidence = true;
    addTearDown(() => FeatureFlags.typedLppEvidence = false);
    final persistence = _TrackingLppPersistence();
    final provider = await _seededProvider(
      lppProfilePersistence: persistence,
    );
    final previousProfile = provider.profile;
    final previousAnswers = provider.reportAnswersSnapshot;
    var notifications = 0;
    provider.addListener(() => notifications++);

    for (final facts in <Map<LppEvidenceFactKey, LppReviewedFact>>[
      const {
        LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
          value: 100000,
          unit: LppEvidenceUnit.chf,
          corrected: true,
        ),
        LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf: LppReviewedFact(
          value: 100001,
          unit: LppEvidenceUnit.chf,
          corrected: true,
        ),
      },
      const {
        LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
          value: 100000,
          unit: LppEvidenceUnit.chf,
          corrected: true,
        ),
        LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf: LppReviewedFact(
          value: 60000,
          unit: LppEvidenceUnit.chf,
          corrected: true,
        ),
        LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf:
            LppReviewedFact(
          value: 39998,
          unit: LppEvidenceUnit.chf,
          corrected: true,
        ),
      },
    ]) {
      await expectLater(
        provider.acceptLppReview(
          LppReviewConfirmation.self(
            facts: facts,
            sourceDate: null,
          ),
        ),
        throwsArgumentError,
      );
    }

    expect(persistence.loadCalls, 0);
    expect(persistence.saveCalls, 0);
    expect(notifications, 0);
    expect(identical(provider.profile, previousProfile), isTrue);
    expect(provider.reportAnswersSnapshot, previousAnswers);
  });

  test('direct LPP review accepts tolerance and partial balance sets',
      () async {
    FeatureFlags.typedLppEvidence = true;
    addTearDown(() => FeatureFlags.typedLppEvidence = false);
    final persistence = _TrackingLppPersistence();
    final provider = await _seededProvider(
      lppProfilePersistence: persistence,
    );

    await provider.acceptLppReview(
      const LppReviewConfirmation.self(
        sourceDate: null,
        facts: {
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
            value: 100000,
            unit: LppEvidenceUnit.chf,
            corrected: true,
          ),
          LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf: LppReviewedFact(
            value: 60000,
            unit: LppEvidenceUnit.chf,
            corrected: true,
          ),
          LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf:
              LppReviewedFact(
            value: 39999,
            unit: LppEvidenceUnit.chf,
            corrected: true,
          ),
        },
      ),
    );
    await provider.acceptLppReview(
      const LppReviewConfirmation.self(
        sourceDate: null,
        facts: {
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
            value: 100000,
            unit: LppEvidenceUnit.chf,
            corrected: true,
          ),
          LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf: LppReviewedFact(
            value: 60000,
            unit: LppEvidenceUnit.chf,
            corrected: true,
          ),
        },
      ),
    );

    expect(persistence.loadCalls, 2);
    expect(persistence.saveCalls, 2);
  });

  test('open-banking liquidity fact commits value and provenance atomically',
      () async {
    final provider = await _seededProvider();
    final startedAt = DateTime.now();
    final previousValue = provider.profile!.patrimoine.epargneLiquide;
    var notifications = 0;
    provider.addListener(() => notifications++);

    final write = provider.updateFromOpenBanking(
      accounts: const [
        {'accountType': 'checking', 'balance': 17500.0},
      ],
      categoryTotals: const {},
    );

    expect(provider.profile!.patrimoine.epargneLiquide, previousValue);
    expect(
      notifications,
      0,
      reason: 'Open Banking must not publish before the atomic save',
    );
    await write;
    expect(
      notifications,
      1,
      reason: 'Open Banking publishes one durable snapshot',
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

  test('generic writer preserves an explicit source date', () async {
    final provider = await _seededProvider();
    final sourceDate = DateTime.utc(2025, 12, 31);
    final startedAt = DateTime.now();

    await provider.mergeAnswersWithProvenance(
      {'q_property_market_value': 980000.0},
      source: ProfileDataSource.certificate,
      sourceDate: sourceDate,
    );

    final completedAt = DateTime.now();
    await _expectAtomicColdRoundTrip(
      writer: provider,
      fieldPath: 'patrimoine.propertyMarketValue',
      expectedSource: ProfileDataSource.certificate,
      expectedSourceDate: sourceDate,
      expectedValue: 980000.0,
      readValue: (profile) => profile.patrimoine.propertyMarketValue,
      writeStartedAt: startedAt,
      writeCompletedAt: completedAt,
    );
  });

  test('frequency without an amount cannot create income provenance', () async {
    final provider = await _seededProvider();

    await provider.mergeAnswers({'q_pay_frequency': 'yearly'});

    expect(provider.profile!.monthlyNetIncomeDeclared, isNull);
    expect(
      provider.profile!.dataSources['monthlyNetIncomeDeclared'],
      isNull,
    );
    final answers = await ReportPersistenceService.loadAnswers();
    final provenance = answers['__provenance']! as Map;
    expect(provenance.containsKey('monthlyNetIncomeDeclared'), isFalse);
  });

  test('clearing a mortgage alias preserves the canonical value provenance',
      () async {
    final originalAt = DateTime.utc(2026, 2, 3, 4, 5, 6);
    await ReportPersistenceService.saveAnswers({
      'q_birth_year': 1981,
      'q_canton': 'VD',
      'q_mortgage_balance': 420000.0,
      '_coach_dettes_hypotheque': 420000.0,
      '__provenance': {
        'dettes.hypotheque': {
          'source': ProfileDataSource.userInput.name,
          'updatedAt': originalAt.toIso8601String(),
          'sourceDate': null,
        },
      },
    });
    final provider = CoachProfileProvider();
    await provider.loadFromWizard();

    await provider.mergeAnswers({'q_mortgage_balance': null});

    expect(provider.profile!.dettes.hypotheque, 420000.0);
    expect(
      provider.profile!.dataSources['dettes.hypotheque'],
      ProfileDataSource.userInput,
    );
    expect(provider.profile!.dataTimestamps['dettes.hypotheque'], originalAt);
    final answers = await ReportPersistenceService.loadAnswers();
    final provenance = answers['__provenance']! as Map;
    expect(provenance['dettes.hypotheque'], isNotNull);
    expect(provenance.containsKey('patrimoine.mortgageBalance'), isFalse);
  });

  test('explicit cash source also drives the legacy cash marker', () async {
    final provider = await _seededProvider();

    await provider.mergeAnswersWithProvenance(
      {'q_cash_total': 31000.0},
      source: ProfileDataSource.openBanking,
    );

    final answers = await ReportPersistenceService.loadAnswers();
    expect(
      answers['_coach_cash_total_source'],
      ProfileDataSource.openBanking.name,
    );
  });

  test('inline cash edit persists provenance before publishing', () async {
    final provider = await _seededProvider();
    final previousValue = provider.profile!.patrimoine.epargneLiquide;
    final startedAt = DateTime.now();
    var notifications = 0;
    provider.addListener(() => notifications++);

    final write = provider.updateInline(epargneLiquide: 22500.0);

    expect(provider.profile!.patrimoine.epargneLiquide, previousValue);
    expect(notifications, 0,
        reason: 'inline edit must not publish before save');
    await write;
    expect(notifications, 1, reason: 'inline edit publishes one durable state');

    final completedAt = DateTime.now();
    await _expectAtomicColdRoundTrip(
      writer: provider,
      fieldPath: 'patrimoine.epargneLiquide',
      expectedSource: ProfileDataSource.userInput,
      expectedValue: 22500.0,
      readValue: (profile) => profile.patrimoine.epargneLiquide,
      writeStartedAt: startedAt,
      writeCompletedAt: completedAt,
    );
  });

  test('AVS certificate years persist provenance before publishing', () async {
    final provider = await _seededProvider();
    final previousValue = provider.profile!.prevoyance.anneesContribuees;
    final startedAt = DateTime.now();
    var notifications = 0;
    provider.addListener(() => notifications++);

    final write = provider.updateFromAvsExtraction(const [
      ExtractedField(
        fieldName: 'annees_contribution',
        label: 'Années de contribution',
        value: 24,
        confidence: 0.98,
        sourceText: '24 années de cotisations',
        needsReview: false,
        profileField: 'avsContributionYears',
      ),
    ]);

    expect(provider.profile!.prevoyance.anneesContribuees, previousValue);
    expect(notifications, 0, reason: 'AVS scan must not publish before save');
    await write;
    expect(notifications, 1, reason: 'AVS scan publishes one durable state');

    final completedAt = DateTime.now();
    await _expectAtomicColdRoundTrip(
      writer: provider,
      fieldPath: 'prevoyance.anneesContribuees',
      expectedSource: ProfileDataSource.certificate,
      expectedValue: 24,
      readValue: (profile) => profile.prevoyance.anneesContribuees,
      writeStartedAt: startedAt,
      writeCompletedAt: completedAt,
    );
  });

  test('inline gross salary persists exact annual fact without inventing net',
      () async {
    await ReportPersistenceService.saveAnswers({
      'q_birth_year': DateTime.now().year - 45,
      'q_canton': 'VD',
      'q_gross_salary_annual': 104000.0,
      'q_nombre_mois': 13.0,
    });
    await ReportPersistenceService.setCompleted(true);
    final provider = CoachProfileProvider();
    await provider.loadFromWizard();
    final startedAt = DateTime.now();

    await provider.updateInline(salaireBrutMensuel: 9200.0);

    final completedAt = DateTime.now();
    expect(provider.profile!.salaireBrutMensuel, 9200.0);
    expect(provider.profile!.nombreDeMois, 13.0);
    expect(secureStorageValues['q_gross_salary_annual'], '119600.0');
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_gross_salary_annual'], 119600.0);
    expect(answers['q_nombre_mois'], 13.0);
    expect(
      answers.containsKey('q_net_income_period_chf'),
      isFalse,
      reason: 'editing gross income must not fabricate a declared net fact',
    );
    await _expectAtomicColdRoundTrip(
      writer: provider,
      fieldPath: 'salaireBrutMensuel',
      expectedSource: ProfileDataSource.userInput,
      expectedValue: 9200.0,
      readValue: (profile) => profile.salaireBrutMensuel,
      writeStartedAt: startedAt,
      writeCompletedAt: completedAt,
    );
  });

  test('AVS education credits persist as a certificate fact', () async {
    final provider = await _seededProvider();
    final startedAt = DateTime.now();

    await provider.updateFromAvsExtraction(const [
      ExtractedField(
        fieldName: 'bonifications_educatives',
        label: 'Bonifications éducatives',
        value: 6,
        confidence: 0.97,
        sourceText: '6 années de bonifications éducatives',
        needsReview: false,
        profileField: 'bonificationsEducatives',
      ),
    ]);

    final completedAt = DateTime.now();
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['_coach_avs_bonifications_educatives'], 6);
    await _expectAtomicColdRoundTrip(
      writer: provider,
      fieldPath: 'prevoyance.bonificationsEducatives',
      expectedSource: ProfileDataSource.certificate,
      expectedValue: 6,
      readValue: (profile) => profile.prevoyance.bonificationsEducatives,
      writeStartedAt: startedAt,
      writeCompletedAt: completedAt,
    );
  });

  test('known no-debt facts persist boolean and zero-payment provenance',
      () async {
    final provider = await _seededProvider();
    final startedAt = DateTime.now();

    await provider.mergeAnswers({
      'q_has_consumer_debt': false,
      'q_debt_payments_period_chf': 0.0,
    });

    final completedAt = DateTime.now();
    await _expectAtomicColdRoundTrip(
      writer: provider,
      fieldPath: 'dettes.hasDette',
      expectedSource: ProfileDataSource.userInput,
      expectedValue: false,
      readValue: (profile) => profile.dettes.hasDette,
      writeStartedAt: startedAt,
      writeCompletedAt: completedAt,
    );
    await _expectAtomicColdRoundTrip(
      writer: provider,
      fieldPath: 'dettes.totalMensualite',
      expectedSource: ProfileDataSource.userInput,
      expectedValue: 0.0,
      readValue: (profile) => profile.dettes.totalMensualite,
      writeStartedAt: startedAt,
      writeCompletedAt: completedAt,
    );
  });

  test('known debt and payment persist getter-backed provenance', () async {
    final provider = await _seededProvider();
    final startedAt = DateTime.now();

    await provider.mergeAnswers({
      'q_has_consumer_debt': true,
      'q_debt_payments_period_chf': 650.0,
    });

    final completedAt = DateTime.now();
    await _expectAtomicColdRoundTrip(
      writer: provider,
      fieldPath: 'dettes.hasDette',
      expectedSource: ProfileDataSource.userInput,
      expectedValue: true,
      readValue: (profile) => profile.dettes.hasDette,
      writeStartedAt: startedAt,
      writeCompletedAt: completedAt,
    );
    await _expectAtomicColdRoundTrip(
      writer: provider,
      fieldPath: 'dettes.totalMensualite',
      expectedSource: ProfileDataSource.userInput,
      expectedValue: 650.0,
      readValue: (profile) => profile.dettes.totalMensualite,
      writeStartedAt: startedAt,
      writeCompletedAt: completedAt,
    );
  });

  test('salary certificate persists canonical facts before publishing',
      () async {
    await ReportPersistenceService.saveAnswers({
      'q_birth_year': DateTime.now().year - 45,
      'q_canton': 'VD',
      'q_gross_salary_annual': 96000.0,
      'q_nombre_mois': 12.0,
      'q_annual_bonus': 24000.0,
    });
    await ReportPersistenceService.setCompleted(true);
    final provider = CoachProfileProvider();
    await provider.loadFromWizard();
    final previousSalary = provider.profile!.salaireBrutMensuel;
    final previousMonths = provider.profile!.nombreDeMois;
    final startedAt = DateTime.now();
    var notifications = 0;
    provider.addListener(() => notifications++);

    final write = provider.updateFromSalaryExtraction(const [
      ExtractedField(
        fieldName: 'salaire_brut_mensuel',
        label: 'Salaire brut mensuel',
        value: 9500.0,
        confidence: 0.99,
        sourceText: 'Salaire mensuel 9 500',
        needsReview: false,
        profileField: 'salaireBrutMensuel',
      ),
      ExtractedField(
        fieldName: 'nombre_mois',
        label: 'Nombre de mois',
        value: 13,
        confidence: 0.99,
        sourceText: '13 salaires',
        needsReview: false,
        profileField: 'nombreDeMois',
      ),
      ExtractedField(
        fieldName: 'bonus_pourcentage',
        label: 'Bonus',
        value: 8.0,
        confidence: 0.95,
        sourceText: 'Bonus 8 %',
        needsReview: false,
        profileField: 'bonusPourcentage',
      ),
    ]);

    expect(provider.profile!.salaireBrutMensuel, previousSalary);
    expect(provider.profile!.nombreDeMois, previousMonths);
    expect(notifications, 0, reason: 'salary scan must save before publish');
    await write;
    expect(notifications, 1, reason: 'salary scan publishes one durable state');

    final completedAt = DateTime.now();
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_gross_salary_annual'], 123500.0);
    expect(answers['q_nombre_mois'], 13);
    expect(answers['q_bonus_percentage'], 8.0);
    expect(
      answers.containsKey('q_annual_bonus'),
      isFalse,
      reason: 'the percentage certificate supersedes stale annual bonus CHF',
    );
    expect(answers.containsKey('q_monthly_gross_salary_chf'), isFalse);
    expect(answers.containsKey('q_salary_months'), isFalse);
    expect(answers.containsKey('q_net_income_period_chf'), isFalse);
    await _expectAtomicColdRoundTrip(
      writer: provider,
      fieldPath: 'salaireBrutMensuel',
      expectedSource: ProfileDataSource.certificate,
      expectedValue: 9500.0,
      readValue: (profile) => profile.salaireBrutMensuel,
      writeStartedAt: startedAt,
      writeCompletedAt: completedAt,
    );
    await _expectAtomicColdRoundTrip(
      writer: provider,
      fieldPath: 'nombreDeMois',
      expectedSource: ProfileDataSource.certificate,
      expectedValue: 13.0,
      readValue: (profile) => profile.nombreDeMois,
      writeStartedAt: startedAt,
      writeCompletedAt: completedAt,
    );
    await _expectAtomicColdRoundTrip(
      writer: provider,
      fieldPath: 'bonusPourcentage',
      expectedSource: ProfileDataSource.certificate,
      expectedValue: 8.0,
      readValue: (profile) => profile.bonusPourcentage,
      writeStartedAt: startedAt,
      writeCompletedAt: completedAt,
    );
  });

  test('partial canonical envelope falls back field-by-field and fails closed',
      () {
    final canonicalAt = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final legacyAt = DateTime.utc(2025, 6, 7, 8, 9, 10);
    final profile = CoachProfile.fromWizardAnswers({
      'q_birth_year': 1980,
      'q_canton': 'VD',
      'q_gross_salary_annual': 96000,
      'q_property_market_value': 900000,
      '_coach_avoir_lpp': 210000,
      '_coach_salaire_assure': 84000,
      '_coach_lpp_source': 'document_scan',
      '_coach_data_timestamps': {
        'prevoyance.avoirLppTotal': legacyAt.toIso8601String(),
        'prevoyance.salaireAssure': legacyAt.toIso8601String(),
      },
      '__provenance': {
        'patrimoine.propertyMarketValue': {
          'source': ProfileDataSource.userInput.name,
          'updatedAt': canonicalAt.toIso8601String(),
          'sourceDate': null,
        },
        'prevoyance.salaireAssure': {
          'source': ProfileDataSource.certificate.name,
          'updatedAt': canonicalAt.toIso8601String(),
          // Missing sourceDate makes this mentioned path malformed.
        },
      },
    });

    expect(
      profile.dataSources['patrimoine.propertyMarketValue'],
      ProfileDataSource.userInput,
    );
    expect(
      profile.dataTimestamps['patrimoine.propertyMarketValue'],
      canonicalAt,
    );
    expect(
      profile.dataSources['prevoyance.avoirLppTotal'],
      ProfileDataSource.certificate,
      reason: 'an unrelated legacy path must survive a partial envelope',
    );
    expect(profile.dataTimestamps['prevoyance.avoirLppTotal'], legacyAt);
    expect(
      profile.dataSources['prevoyance.salaireAssure'],
      isNull,
      reason: 'a malformed canonical record blocks same-path legacy fallback',
    );
    expect(profile.dataTimestamps['prevoyance.salaireAssure'], isNull);
  });

  test('clearing a value prunes its provenance record', () async {
    final provider = await _seededProvider();
    await provider.mergeAnswers({'q_property_market_value': 910000.0});

    await provider.mergeAnswers({'q_property_market_value': null});

    expect(provider.profile!.patrimoine.propertyMarketValue, isNull);
    expect(
      provider.profile!.dataSources['patrimoine.propertyMarketValue'],
      isNull,
    );
    final answers = await ReportPersistenceService.loadAnswers();
    final provenance = answers['__provenance']! as Map;
    expect(provenance.containsKey('patrimoine.propertyMarketValue'), isFalse);
  });
}
