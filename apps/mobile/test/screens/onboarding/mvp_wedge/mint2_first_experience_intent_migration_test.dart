import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/onboarding_intent.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

class _CapturingCoachProvider extends CoachProfileProvider {
  Map<String, dynamic>? flushedAnswers;
  CoachProfile? _fakeProfile;

  @override
  CoachProfile? get profile => _fakeProfile;

  @override
  bool get hasProfile => _fakeProfile != null;

  @override
  Future<void> mergeAnswers(Map<String, dynamic> partial) async {
    flushedAnswers = Map<String, dynamic>.from(partial);
    _fakeProfile = CoachProfile.fromWizardAnswers(partial);
  }

  @override
  void updateFromAnswers(Map<String, dynamic> answers) {
    flushedAnswers = Map<String, dynamic>.from(answers);
    _fakeProfile = CoachProfile.fromWizardAnswers(answers);
  }
}

Future<Map<String, dynamic>> _flushLegacyIntent(
  OnboardingIntent intent,
) async {
  final provider = OnboardingProvider();
  provider.setIntent(intent, intent.name);
  provider.setDateOfBirth(DateTime(1988, 4, 12));
  provider.setNetMonthlyRange(7000, 7500);

  final coach = _CapturingCoachProvider();
  await provider.completeAndFlushToProfile(coach);
  return coach.flushedAnswers!;
}

Future<Map<String, dynamic>> _flushAxesAfterSignalInterest() async {
  final provider = OnboardingProvider();
  provider.setAxisV2(
    OnboardingAxisV2.logementSignal,
    'Logement : 2e / 3e pilier',
  );
  provider.setAxisV2(
    OnboardingAxisV2.fiscalSignal,
    '3a et rachats : impact fiscal',
  );
  provider.setAxisV2(
    OnboardingAxisV2.lppRenteCapital,
    '2e pilier : rente ou capital',
  );
  provider.setDateOfBirth(DateTime(1988, 4, 12));
  provider.setNetMonthlyRange(7000, 7500);

  final coach = _CapturingCoachProvider();
  await provider.completeAndFlushToProfile(coach);
  return coach.flushedAnswers!;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    FlutterSecureStorage.setMockInitialValues({});
    FeatureFlags.enableMint2FirstExperienceEntry = false;
  });

  test('default-off flush keeps legacy intent without v2 axis keys', () async {
    final flushed = await _flushLegacyIntent(OnboardingIntent.retraite);

    expect(flushed['onb_intent'], OnboardingIntent.retraite.name);
    expect(flushed, isNot(contains('legacy_onb_intent')));
    expect(flushed, isNot(contains('onb_axis_schema_version')));
    expect(flushed, isNot(contains('onb_axis_v2')));
    expect(flushed, isNot(contains('onb_signal_axes_v2')));
  });

  test('flagged legacy onb_intent stores axis metadata outside wizard answers',
      () async {
    FeatureFlags.enableMint2FirstExperienceEntry = true;
    final cases = <OnboardingIntent, String>{
      OnboardingIntent.retraite: 'lpp_rente_capital',
      OnboardingIntent.achat: 'logement_signal',
      OnboardingIntent.impots: 'fiscal_signal',
      OnboardingIntent.explorer: 'legacy_explore_needs_choice',
    };

    for (final entry in cases.entries) {
      final flushed = await _flushLegacyIntent(entry.key);

      expect(flushed['onb_intent'], entry.key.name);
      expect(flushed, isNot(contains('legacy_onb_intent')));
      expect(flushed, isNot(contains('onb_axis_schema_version')));
      expect(flushed, isNot(contains('onb_axis_v2')));
      expect(flushed, isNot(contains('onb_signal_axes_v2')));

      final handoff = await ReportPersistenceService.loadMint2AxisHandoff();
      expect(handoff['legacy_onb_intent'], entry.key.name);
      expect(handoff['onb_axis_schema_version'], 2);
      expect(handoff['onb_axis_v2'], entry.value);
    }
  });

  test('signal axis interests survive when user continues with live LPP',
      () async {
    FeatureFlags.enableMint2FirstExperienceEntry = true;
    final flushed = await _flushAxesAfterSignalInterest();

    expect(flushed, isNot(contains('legacy_onb_intent')));
    expect(flushed, isNot(contains('onb_axis_schema_version')));
    expect(flushed, isNot(contains('onb_axis_v2')));
    expect(flushed, isNot(contains('onb_signal_axes_v2')));

    final handoff = await ReportPersistenceService.loadMint2AxisHandoff();
    expect(handoff['onb_axis_v2'], 'lpp_rente_capital');
    expect(handoff['onb_axis_schema_version'], 2);
    expect(
      handoff['onb_signal_axes_v2'],
      <String>['logement_signal', 'fiscal_signal'],
    );
  });
}
