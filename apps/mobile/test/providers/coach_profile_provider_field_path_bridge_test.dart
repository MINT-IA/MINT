import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('mergeAnswers maps depenses field paths to canonical wizard keys',
      () async {
    final provider = CoachProfileProvider();

    await provider.mergeAnswers({
      'q_birth_year': 1990,
      'q_canton': 'VD',
      'fp:depenses.loyer': 1850.0,
      'fp:depenses.assuranceMaladie': 420.0,
      'fp:depenses.transport': 180.0,
    });

    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['_coach_depenses_loyer'], 1850.0);
    expect(persisted['_coach_depenses_assurance'], 420.0);
    expect(persisted['_coach_depenses_transport'], 180.0);
    expect(persisted.containsKey('fp:depenses.loyer'), isFalse);
    expect(persisted.containsKey('fp:depenses.assuranceMaladie'), isFalse);
    expect(persisted.containsKey('fp:depenses.transport'), isFalse);

    final timestamps = persisted['_coach_data_timestamps'] as Map;
    expect(timestamps['depenses.loyer'], isA<String>());
    expect(timestamps['depenses.assuranceMaladie'], isA<String>());
    expect(timestamps['depenses.transport'], isA<String>());

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.profile?.depenses.loyer, 1850.0);
    expect(reloaded.profile?.depenses.assuranceMaladie, 420.0);
    expect(reloaded.profile?.depenses.transport, 180.0);
    expect(
      reloaded.profile?.dataSources['depenses.loyer'],
      ProfileDataSource.userInput,
    );
    expect(
      reloaded.profile?.dataSources['depenses.assuranceMaladie'],
      ProfileDataSource.userInput,
    );
    expect(
      reloaded.profile?.dataTimestamps.containsKey('depenses.loyer'),
      isTrue,
    );
  });

  test('canonical depenses keys count toward onboarding signals', () {
    final provider = CoachProfileProvider();

    provider.updateFromAnswers({
      'q_birth_year': 1990,
      'q_canton': 'VD',
      '_coach_depenses_loyer': 1850.0,
      '_coach_depenses_assurance': 420.0,
    });

    expect(provider.onboardingAnsweredSignals, 4);
  });

  test('updateInline persists loyer and LAMal to canonical depenses keys',
      () async {
    final provider = CoachProfileProvider();
    provider.updateFromAnswers({
      'q_birth_year': 1990,
      'q_canton': 'VD',
      '_coach_depenses_loyer': 1850.0,
      '_coach_depenses_assurance': 420.0,
    });
    await ReportPersistenceService.saveAnswers({
      'q_birth_year': 1990,
      'q_canton': 'VD',
      '_coach_depenses_loyer': 1850.0,
      '_coach_depenses_assurance': 420.0,
    });

    await provider.updateInline(
      loyer: 2100.0,
      assuranceMaladie: 390.0,
    );

    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['_coach_depenses_loyer'], 2100.0);
    expect(persisted['_coach_depenses_assurance'], 390.0);
    expect(persisted.containsKey('q_housing_cost_period_chf'), isFalse);
    expect(persisted.containsKey('q_lamal_premium_monthly_chf'), isFalse);
  });
}
