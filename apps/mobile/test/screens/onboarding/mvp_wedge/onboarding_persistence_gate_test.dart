import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/auth_lifecycle_state.dart';
import 'package:mint_mobile/models/onboarding_intent.dart';
import 'package:mint_mobile/app.dart' show accountLifecycleAndArchetypeRedirect;
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureStorage = <String, String>{};

  setUp(() {
    secureStorage.clear();
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'auth_local_mode': true,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
      final key = call.arguments['key'] as String?;
      switch (call.method) {
        case 'write':
          final value = call.arguments['value'] as String?;
          if (key != null && value != null) secureStorage[key] = value;
          return null;
        case 'read':
          return key == null ? null : secureStorage[key];
        case 'delete':
          if (key != null) secureStorage.remove(key);
          return null;
        case 'deleteAll':
          secureStorage.clear();
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  test('JOS-002A: terminal onboarding persists sealed profile for cold restart',
      () async {
    final onboarding = OnboardingProvider()
      ..setIntent(OnboardingIntent.retraite, 'Ma prévoyance')
      ..setDateOfBirth(DateTime(1981, 6, 15))
      ..setNationality('CH')
      ..setEmploymentStatus('salarie')
      ..setCivilStatus('marie')
      ..setAvsLacunes('no_gaps')
      ..setCanton('VD', 'Vaud')
      ..setNetMonthlyExact(7200)
      ..setWantsDeeper(true);
    final currentSession = CoachProfileProvider();

    await onboarding.completeAndFlushToProfile(currentSession);

    final prefs = await SharedPreferences.getInstance();
    final raw = json.decode(prefs.getString('wizard_answers_v2')!)
        as Map<String, dynamic>;
    expect(raw['q_canton'], 'VD');
    expect(raw['q_date_of_birth'], '__secure__');
    expect(raw['q_birth_year'], '__secure__');
    expect(raw['q_nationality'], '__secure__');
    expect(raw['q_employment_status'], '__secure__');
    expect(raw['q_civil_status'], '__secure__');
    expect(raw['q_avs_lacunes_status'], '__secure__');
    expect(raw['q_net_income_period_chf'], '__secure__');
    expect(raw.containsValue('1981-06-15'), isFalse);
    expect(raw.containsValue('1981-06-15T00:00:00.000'), isFalse);
    expect(raw.containsValue(7200), isFalse);

    final loaded = await ReportPersistenceService.loadAnswers();
    expect(loaded['q_date_of_birth'], '1981-06-15T00:00:00.000');
    expect(loaded['q_canton'], 'VD');
    expect(loaded['q_net_income_period_chf'], 7200);
    expect(loaded['q_employment_status'], 'salarie');
    expect(loaded['q_has_pension_fund'], isTrue);

    final coldStart = CoachProfileProvider();
    await coldStart.loadFromWizard();

    expect(coldStart.profile, isNotNull);
    expect(coldStart.profile!.dateOfBirth, DateTime(1981, 6, 15));
    expect(coldStart.profile!.canton, 'VD');
    expect(coldStart.profile!.nationality, 'CH');
    expect(coldStart.profile!.employmentStatus, 'salarie');
    expect(coldStart.profile!.salaireBrutMensuel, greaterThan(0));
    expect(
      accountLifecycleAndArchetypeRedirect(
        lifecycle: AuthLifecycleState.guestEmpty(installId: 'install-1'),
        location: '/mon-argent',
        path: '/mon-argent',
        topRoute: null,
        profile: coldStart.profile,
        profileSettled: true,
      ),
      isNull,
    );
  });
}
