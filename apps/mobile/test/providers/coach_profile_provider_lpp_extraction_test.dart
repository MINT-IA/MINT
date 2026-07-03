import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/data_spine_snapshot.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/data_spine/coach_context_packet_service.dart';
import 'package:mint_mobile/services/data_spine/data_spine_service.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureStorage = <String, String>{};

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorage.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
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

  test('LPP scan confirmation survives reload into Data Spine and coach packet',
      () async {
    final provider = CoachProfileProvider();

    await provider.updateFromLppExtraction([
      const ExtractedField(
        fieldName: 'avoir_lpp_total',
        label: 'Avoir de vieillesse total',
        value: 143288.0,
        confidence: 0.94,
        sourceText: 'Avoir de vieillesse total CHF 143 288',
        needsReview: false,
        profileField: 'avoirLppTotal',
      ),
      const ExtractedField(
        fieldName: 'avoir_lpp_obligatoire',
        label: 'Part obligatoire',
        value: 100000.0,
        confidence: 0.91,
        sourceText: 'Obligatoire CHF 100 000',
        needsReview: false,
        profileField: 'lppObligatoire',
      ),
      const ExtractedField(
        fieldName: 'avoir_lpp_surobligatoire',
        label: 'Part surobligatoire',
        value: 43288.0,
        confidence: 0.90,
        sourceText: 'Surobligatoire CHF 43 288',
        needsReview: false,
        profileField: 'lppSurobligatoire',
      ),
      const ExtractedField(
        fieldName: 'salaire_assure',
        label: 'Salaire assuré',
        value: 88000.0,
        confidence: 0.88,
        sourceText: 'Salaire assure CHF 88 000',
        needsReview: false,
        profileField: 'lppInsuredSalary',
      ),
      const ExtractedField(
        fieldName: 'rachat_maximum',
        label: 'Rachat maximal',
        value: 42000.0,
        confidence: 0.86,
        sourceText: 'Rachat maximal CHF 42 000',
        needsReview: false,
        profileField: 'buybackPotential',
      ),
    ]);

    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['_coach_avoir_lpp'], 143288.0);
    expect(persisted['_coach_avoir_lpp_oblig'], 100000.0);
    expect(persisted['_coach_avoir_lpp_suroblig'], 43288.0);
    expect(persisted['_coach_salaire_assure'], 88000.0);
    expect(persisted['_coach_rachat_maximum'], 42000.0);
    expect(persisted['_coach_lpp_source'], 'document_scan');

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    final profile = reloaded.profile;

    expect(profile, isNotNull);
    expect(profile!.prevoyance.avoirLppTotal, 143288.0);
    expect(profile.prevoyance.avoirLppObligatoire, 100000.0);
    expect(profile.prevoyance.avoirLppSurobligatoire, 43288.0);
    expect(profile.prevoyance.salaireAssure, 88000.0);
    expect(profile.prevoyance.rachatMaximum, 42000.0);
    expect(
      profile.dataSources['prevoyance.avoirLppTotal']?.name,
      'certificate',
    );

    final spine = DataSpineService.fromProfile(
      profile,
      now: DateTime.utc(2026, 6, 3, 8),
    );
    expect(spine.pillars.lpp.totalBalance.value, 143288.0);
    expect(spine.pillars.lpp.totalBalance.state, PillarFactState.known);
    expect(
      spine.pillars.lpp.totalBalance.meta.source?.name,
      'certificate',
    );

    final packet = CoachContextPacketService.fromSpine(spine);
    final lppFact = packet.facts.singleWhere(
      (fact) => fact.id == 'pillar.lpp.total_balance',
    );
    expect(lppFact.value, 143288.0);
    expect(lppFact.source, 'certificate');
    expect(lppFact.confidence, 'known');
    expect(packet.toSafeMap().containsKey('wizard_answers'), isFalse);
  });

  test('wizardAnswersSnapshot is immutable and detached from caller maps',
      () async {
    final provider = CoachProfileProvider();
    final source = <String, dynamic>{
      'q_canton': 'VD',
      'q_property_market_value': 950000,
    };

    provider.updateFromAnswers(source);
    source['q_canton'] = 'GE';

    final snapshot = provider.wizardAnswersSnapshot;
    expect(snapshot['q_canton'], 'VD');
    expect(snapshot['q_property_market_value'], 950000);
    expect(
      () => snapshot['q_canton'] = 'ZH',
      throwsUnsupportedError,
    );
    expect(provider.wizardAnswersSnapshot['q_canton'], 'VD');
  });
}
