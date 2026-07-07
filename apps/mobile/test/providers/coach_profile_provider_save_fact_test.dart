import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockSecureStorage = <String, String>{};

  setUp(() {
    mockSecureStorage.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        final key = call.arguments['key'] as String?;
        switch (call.method) {
          case 'write':
            final value = call.arguments['value'] as String?;
            if (key != null && value != null) mockSecureStorage[key] = value;
            return null;
          case 'read':
            return key == null ? null : mockSecureStorage[key];
          case 'delete':
            if (key != null) mockSecureStorage.remove(key);
            return null;
          case 'deleteAll':
            mockSecureStorage.clear();
            return null;
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  Future<CoachProfile> profileAfterSaveFacts(
    List<MapEntry<String, dynamic>> facts,
  ) async {
    final provider = CoachProfileProvider();
    for (final fact in facts) {
      expect(
        await provider.applySaveFact(fact.key, fact.value),
        isTrue,
        reason: '${fact.key} should be mapped by applySaveFact',
      );
    }
    expect(provider.profile, isNotNull);
    expect(await ReportPersistenceService.loadAnswers(), isNotEmpty);
    return provider.profile!;
  }

  test(
      'save_fact identity, revenue, goals, and self-employment hydrate profile',
      () async {
    final profile = await profileAfterSaveFacts([
      const MapEntry('birthYear', 1985),
      const MapEntry('canton', 'VD'),
      const MapEntry('commune', 'Lausanne'),
      const MapEntry('gender', 'F'),
      const MapEntry('incomeGrossYearly', 120000.0),
      const MapEntry('employmentRate', 80.0),
      const MapEntry('annualBonus', 12000.0),
      const MapEntry('goal', 'house'),
      const MapEntry('selfEmployedNetIncome', 90000.0),
    ]);

    final json = profile.toJson();
    expect(profile.commune, 'Lausanne');
    expect(profile.gender, 'F');
    expect(json['employmentRate'], 80.0);
    expect(json['annualBonus'], 12000.0);
    expect(profile.goalA.type, GoalAType.achatImmo);
    expect(profile.employmentStatus, 'independant');
    expect(json['selfEmployedNetIncome'], 90000.0);
  });

  test('save_fact LPP, debt, and AVS keys hydrate profile', () async {
    final profile = await profileAfterSaveFacts([
      const MapEntry('birthYear', 1980),
      const MapEntry('has2ndPillar', false),
      const MapEntry('hasVoluntaryLpp', true),
      const MapEntry('hasDebt', true),
      const MapEntry('totalDebt', 24000.0),
      const MapEntry('hasAvsGaps', true),
      const MapEntry('avsContributionYears', 20),
    ]);

    expect(profile.prevoyance.avoirLppTotal, 0);
    expect(profile.prevoyance.toJson()['hasVoluntaryLpp'], true);
    expect(profile.dettes.hasDette, isTrue);
    expect(profile.dettes.totalDettes, 24000.0);
    expect(profile.dettes.toJson()['declaredTotalDebt'], 24000.0);
    expect(profile.prevoyance.lacunesAVS, greaterThan(0));
    expect(profile.prevoyance.anneesContribuees, 20);
  });

  test('save_fact spouse keys hydrate conjoint profile', () async {
    final profile = await profileAfterSaveFacts([
      const MapEntry('birthYear', 1980),
      const MapEntry('spouseIncomeNetMonthly', 5500.0),
      const MapEntry('spouseBirthYear', 1982),
      const MapEntry('spouseAvsContributionYears', 22),
    ]);

    expect(profile.conjoint, isNotNull);
    expect(profile.conjoint!.birthYear, 1982);
    expect(profile.conjoint!.salaireBrutMensuel, closeTo(6321.84, 0.01));
    expect(profile.conjoint!.prevoyance!.anneesContribuees, 22);
  });

  test('save_fact spouse identity and AVS keys hydrate without spouse income',
      () async {
    final profile = await profileAfterSaveFacts([
      const MapEntry('birthYear', 1980),
      const MapEntry('spouseBirthYear', 1982),
      const MapEntry('spouseAvsContributionYears', 22),
    ]);

    expect(profile.conjoint, isNotNull);
    expect(profile.conjoint!.birthYear, 1982);
    expect(profile.conjoint!.salaireBrutMensuel, 0);
    expect(profile.conjoint!.prevoyance!.anneesContribuees, 22);
  });

  test('save_fact backend goal values do not collapse to retirement', () async {
    final cases = {
      'house': GoalAType.achatImmo,
      'retire': GoalAType.retraite,
      'emergency': GoalAType.custom,
      'invest': GoalAType.independance,
      'optimize_taxes': GoalAType.custom,
      'other': GoalAType.custom,
    };

    for (final entry in cases.entries) {
      final profile = await profileAfterSaveFacts([
        const MapEntry('birthYear', 1985),
        MapEntry('goal', entry.key),
      ]);
      expect(profile.goalA.type, entry.value, reason: entry.key);
    }
  });

  test('save_fact self-employed income clears stale gross salary only when safe',
      () async {
    final independent = await profileAfterSaveFacts([
      const MapEntry('birthYear', 1985),
      const MapEntry('incomeGrossYearly', 120000.0),
      const MapEntry('selfEmployedNetIncome', 90000.0),
    ]);

    expect(independent.employmentStatus, 'independant');
    expect(independent.selfEmployedNetIncome, 90000.0);
    expect(independent.salaireBrutMensuel, closeTo(8620.69, 0.01));

    mockSecureStorage.clear();
    SharedPreferences.setMockInitialValues({});
    final provider = CoachProfileProvider();
    expect(await provider.applySaveFact('birthYear', 1985), isTrue);
    expect(await provider.applySaveFact('incomeGrossYearly', 60000.0), isTrue);
    expect(await provider.applySaveFact('employmentStatus', 'mixed'), isTrue);
    expect(
      await provider.applySaveFact('selfEmployedNetIncome', 96000.0),
      isTrue,
    );

    expect(provider.profile!.employmentStatus, 'mixte');
    expect(provider.profile!.selfEmployedNetIncome, 96000.0);
  });

  test('save_fact savings, wealth, and 3a keys stay distinct', () async {
    final profile = await profileAfterSaveFacts([
      const MapEntry('birthYear', 1985),
      const MapEntry('pillar3aBalance', 42000.0),
      const MapEntry('totalSavings', 30000.0),
      const MapEntry('wealthEstimate', 250000.0),
    ]);

    final patrimoineJson = profile.patrimoine.toJson();
    expect(profile.prevoyance.totalEpargne3a, 42000.0);
    expect(profile.patrimoine.epargneLiquide, 30000.0);
    expect(patrimoineJson['wealthEstimate'], 250000.0);
    expect(profile.patrimoine.totalPatrimoine, 250000.0);
  });

  test('wealth estimate is gross estimate, not a cap on detailed components',
      () async {
    final profile = CoachProfile.fromWizardAnswers({
      'q_birth_year': 1985,
      'q_wealth_estimate': 250000.0,
      'q_cash_total': 30000.0,
      'q_investments_total': 300000.0,
    });

    expect(profile.patrimoine.wealthEstimate, 250000.0);
    expect(profile.patrimoine.totalPatrimoine, 330000.0);
  });
}
