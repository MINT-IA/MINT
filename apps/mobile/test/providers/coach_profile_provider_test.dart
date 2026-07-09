import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorage =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorageValues = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorage, (call) async {
    final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
    final key = args['key'] as String?;
    if (call.method == 'write' && key != null) {
      secureStorageValues[key] = args['value'] as String;
      return null;
    }
    if (call.method == 'read' && key != null) return secureStorageValues[key];
    if (call.method == 'readAll') return secureStorageValues;
    if (call.method == 'delete' && key != null) {
      secureStorageValues.remove(key);
      return null;
    }
    if (call.method == 'deleteAll') {
      secureStorageValues.clear();
      return null;
    }
    return null;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorageValues.clear();
  });

  test('updateProfile persists liquid savings on the readable cash key',
      () async {
    final provider = CoachProfileProvider();
    final profile = CoachProfile.defaults().copyWith(
      patrimoine: const PatrimoineProfile(epargneLiquide: 88000),
    );

    provider.updateProfile(profile);
    await Future<void>.delayed(Duration.zero);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_cash_total', 88000));
    expect(answers.containsKey('q_epargne_liquide'), isFalse);
    expect(CoachProfile.fromWizardAnswers(answers).patrimoine.epargneLiquide,
        88000);
  });

  test('updateProfile persists 3a balance on the readable 3a total key',
      () async {
    final provider = CoachProfileProvider();
    final profile = CoachProfile.defaults().copyWith(
      prevoyance: const PrevoyanceProfile(totalEpargne3a: 42000),
    );

    provider.updateProfile(profile);
    await Future<void>.delayed(Duration.zero);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_3a_total', 42000));
    expect(answers.containsKey('q_total_3a'), isFalse);
    expect(CoachProfile.fromWizardAnswers(answers).prevoyance.totalEpargne3a,
        42000);
  });

  test('save_fact wealthEstimate writes its own readable estimate key',
      () async {
    final provider = CoachProfileProvider();

    final applied = await provider.applySaveFact('wealthEstimate', 350000);

    expect(applied, isTrue);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_wealth_estimate', 350000));
    expect(answers.containsKey('q_epargne_liquide'), isFalse);
    expect(provider.profile?.patrimoine.wealthEstimate, 350000);
    expect(provider.profile?.patrimoine.totalPatrimoine, 350000);
  });

  test('save_fact pillar3aBalance writes the readable 3a total key', () async {
    final provider = CoachProfileProvider();

    final applied = await provider.applySaveFact('pillar3aBalance', 42000);

    expect(applied, isTrue);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_3a_total', 42000));
    expect(answers.containsKey('q_total_3a'), isFalse);
    expect(provider.profile?.prevoyance.totalEpargne3a, 42000);
  });

  test('save_fact commune and gender hydrate readable identity keys', () async {
    final provider = CoachProfileProvider();

    final communeApplied = await provider.applySaveFact('commune', 'Lausanne');
    final genderApplied = await provider.applySaveFact('gender', 'F');

    expect(communeApplied, isTrue);
    expect(genderApplied, isTrue);
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_commune', 'Lausanne'));
    expect(answers, containsPair('q_gender', 'F'));
    expect(provider.profile?.commune, 'Lausanne');
    expect(provider.profile?.gender, 'F');
  });

  test('updateProfile persists commune and gender on readable identity keys',
      () async {
    final provider = CoachProfileProvider();
    final profile = CoachProfile.defaults().copyWith(
      commune: 'Lausanne',
      gender: 'F',
    );

    provider.updateProfile(profile);
    await Future<void>.delayed(Duration.zero);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_commune', 'Lausanne'));
    expect(answers, containsPair('q_gender', 'F'));
    final rehydrated = CoachProfile.fromWizardAnswers(answers);
    expect(rehydrated.commune, 'Lausanne');
    expect(rehydrated.gender, 'F');
  });

  test('save_fact employmentRate and annualBonus hydrate income keys',
      () async {
    final provider = CoachProfileProvider();

    expect(await provider.applySaveFact('incomeGrossYearly', 120000), isTrue);
    expect(await provider.applySaveFact('employmentRate', 80), isTrue);
    expect(await provider.applySaveFact('annualBonus', 12000), isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_employment_rate', 80));
    expect(answers, containsPair('q_annual_bonus', 12000));
    expect(provider.profile?.employmentRate, 80);
    expect(provider.profile?.bonusPourcentage, closeTo(10, 0.001));
    expect(provider.profile?.revenuBrutAnnuel, closeTo(132000, 0.001));
    expect(provider.profile?.toCoachingProfile().tauxActivite, 80);
  });

  test('updateProfile preserves 13-month salary, rate, and bonus shape',
      () async {
    final provider = CoachProfileProvider();
    final profile = CoachProfile.defaults().copyWith(
      salaireBrutMensuel: 10000,
      nombreDeMois: 13,
      bonusPourcentage: 5,
      employmentRate: 80,
    );

    provider.updateProfile(profile);
    await Future<void>.delayed(Duration.zero);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_nombre_mois', 13));
    expect(answers, containsPair('q_gross_salary_annual', 130000));
    expect(answers, containsPair('q_employment_rate', 80));
    expect(answers, containsPair('q_annual_bonus', 6500));
    final rehydrated = CoachProfile.fromWizardAnswers(answers);
    expect(rehydrated.salaireBrutMensuel, closeTo(10000, 0.001));
    expect(rehydrated.nombreDeMois, 13);
    expect(rehydrated.employmentRate, 80);
    expect(rehydrated.bonusPourcentage, closeTo(5, 0.001));
    expect(rehydrated.revenuBrutAnnuel, closeTo(136500, 0.001));
  });

  test('updateProfile clears stale employment rate and annual bonus keys',
      () async {
    final provider = CoachProfileProvider();
    final partTimeWithBonus = CoachProfile.defaults().copyWith(
      salaireBrutMensuel: 10000,
      nombreDeMois: 12,
      bonusPourcentage: 10,
      employmentRate: 80,
    );
    final fullTimeWithoutBonus = CoachProfile.defaults().copyWith(
      salaireBrutMensuel: 0,
      nombreDeMois: 12,
      employmentRate: 100,
    );

    provider.updateProfile(partTimeWithBonus);
    await Future<void>.delayed(Duration.zero);
    provider.updateProfile(fullTimeWithoutBonus);
    await Future<void>.delayed(Duration.zero);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers.containsKey('q_employment_rate'), isFalse);
    expect(answers.containsKey('q_annual_bonus'), isFalse);
    expect(answers, containsPair('q_gross_salary_annual', 0));
    final rehydrated = CoachProfile.fromWizardAnswers(answers);
    expect(rehydrated.employmentRate, 100);
    expect(rehydrated.bonusPourcentage, isNull);
    expect(rehydrated.revenuBrutAnnuel, 0);
    expect(rehydrated.toCoachingProfile().tauxActivite, 100);
  });

  test('save_fact AVS gaps and contribution years hydrate AVS keys', () async {
    final provider = CoachProfileProvider();

    expect(await provider.applySaveFact('birthYear', 1970), isTrue);
    expect(await provider.applySaveFact('avsContributionYears', 30), isTrue);
    expect(await provider.applySaveFact('hasAvsGaps', true), isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_avs_contribution_years', 30));
    expect(answers, containsPair('q_avs_lacunes_status', 'unknown'));
    expect(provider.profile?.prevoyance.anneesContribuees, 30);
    expect(provider.profile?.prevoyance.lacunesAVS, 2);
  });

  test('save_fact hasAvsGaps false clears AVS gap status', () async {
    final provider = CoachProfileProvider();

    expect(await provider.applySaveFact('birthYear', 1970), isTrue);
    expect(await provider.applySaveFact('hasAvsGaps', true), isTrue);
    expect(await provider.applySaveFact('hasAvsGaps', false), isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_avs_lacunes_status', 'no_gaps'));
    expect(provider.profile?.prevoyance.lacunesAVS, isNull);
  });

  test('save_fact hasAvsGaps true preserves precise AVS status', () async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers({
      'q_birth_year': 1970,
      'q_avs_lacunes_status': 'lived_abroad',
      'q_avs_years_abroad': 4,
    });

    expect(await provider.applySaveFact('hasAvsGaps', true), isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_avs_lacunes_status', 'lived_abroad'));
    expect(provider.profile?.prevoyance.lacunesAVS, 4);
  });

  test('save_fact hasAvsGaps true preserves arrived-late AVS status',
      () async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers({
      'q_birth_year': 1975,
      'q_avs_lacunes_status': 'arrived_late',
      'q_avs_arrival_year': 2005,
    });

    expect(await provider.applySaveFact('hasAvsGaps', true), isTrue);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers, containsPair('q_avs_lacunes_status', 'arrived_late'));
    expect(answers, containsPair('q_avs_arrival_year', 2005));
    expect(provider.profile?.prevoyance.lacunesAVS, 9);
  });
}
