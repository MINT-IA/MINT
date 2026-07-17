import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('jurisdictions and provenance persist atomically across cold rebuild',
      () async {
    final now = DateTime.utc(2026, 7, 17, 12);
    await ReportPersistenceService.setCompleted(true);
    final writer = CoachProfileProvider(now: () => now);
    addTearDown(writer.dispose);

    await writer.mergeAnswers(<String, dynamic>{
      'q_residence_country': 'FR',
      'q_work_country': 'CH',
      'q_work_canton': 'GE',
    });

    expect(writer.profile!.residenceCountry?.value, 'FR');
    expect(writer.profile!.workCountry?.value, 'CH');
    expect(writer.profile!.workCanton?.value, 'GE');
    final persisted = await ReportPersistenceService.loadAnswers();
    final provenance = persisted['__provenance']! as Map;
    for (final path in const <String>{
      'residenceCountry',
      'workCountry',
      'workCanton',
    }) {
      expect(provenance[path], isA<Map>(), reason: path);
      expect((provenance[path] as Map)['source'], 'userInput', reason: path);
      expect((provenance[path] as Map)['updatedAt'], now.toIso8601String(),
          reason: path);
      expect((provenance[path] as Map).containsKey('sourceDate'), isTrue,
          reason: path);
    }

    final cold = CoachProfileProvider(now: () => now);
    addTearDown(cold.dispose);
    await cold.loadFromWizard();
    expect(cold.profile!.frontierJurisdictionAt(now).jurisdictionReady, isTrue);
    expect(cold.profile!.residenceCountry?.value, 'FR');
    expect(cold.profile!.workCountry?.value, 'CH');
    expect(cold.profile!.workCanton?.value, 'GE');
  });

  test('clearing a jurisdiction removes its value and provenance durably',
      () async {
    final now = DateTime.utc(2026, 7, 17, 12);
    await ReportPersistenceService.setCompleted(true);
    final writer = CoachProfileProvider(now: () => now);
    addTearDown(writer.dispose);
    await writer.mergeAnswers(<String, dynamic>{
      'q_residence_country': 'FR',
      'q_work_country': 'CH',
      'q_work_canton': 'GE',
    });

    await writer.mergeAnswers(<String, dynamic>{'q_work_canton': null});

    expect(writer.profile!.workCanton, isNull);
    expect(writer.profile!.dataSources, isNot(contains('workCanton')));
    expect(writer.profile!.dataTimestamps, isNot(contains('workCanton')));
    expect(writer.profile!.dataSourceDates, isNot(contains('workCanton')));
    expect(writer.profile!.userProvidedFields, isNot(contains('workCanton')));
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted, isNot(contains('q_work_canton')));
    expect(
      persisted['__provenance'] as Map,
      isNot(contains('workCanton')),
    );

    final cold = CoachProfileProvider(now: () => now);
    addTearDown(cold.dispose);
    await cold.loadFromWizard();
    expect(cold.profile!.workCanton, isNull);
    expect(
        cold.profile!.frontierJurisdictionAt(now).jurisdictionReady, isFalse);
  });

  test('invalid jurisdiction code is rejected before any mutation', () async {
    final now = DateTime.utc(2026, 7, 17, 12);
    await ReportPersistenceService.setCompleted(true);
    final provider = CoachProfileProvider(now: () => now);
    addTearDown(provider.dispose);
    await provider.mergeAnswers(<String, dynamic>{
      'q_residence_country': 'FR',
      'q_work_country': 'CH',
      'q_work_canton': 'GE',
    });
    final before = await ReportPersistenceService.loadAnswers();

    for (final invalid in const <Map<String, dynamic>>[
      <String, dynamic>{'q_residence_country': 'France'},
      <String, dynamic>{'q_work_country': 'XX'},
      <String, dynamic>{'q_work_canton': 'ZZ'},
    ]) {
      await expectLater(
        provider.mergeAnswers(invalid),
        throwsArgumentError,
      );
    }

    expect(await ReportPersistenceService.loadAnswers(), before);
    expect(provider.profile!.residenceCountry?.value, 'FR');
    expect(provider.profile!.workCountry?.value, 'CH');
    expect(provider.profile!.workCanton?.value, 'GE');
  });
}
