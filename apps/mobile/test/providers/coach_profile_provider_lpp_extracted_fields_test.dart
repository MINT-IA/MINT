// DOCS-01 (Phase 92) — golden test for the typed-vault → CoachProfile
// converter `CoachProfileProvider.updateFromLppExtractedFields`.
//
// The constants below are extracted manually from
// services/backend/tests/test_extractor_julien_cpe_golden.py so that a
// backend regression cannot mask a Flutter converter bug. DO NOT import
// values from a shared fixture — keep this test self-contained.
//
// Risk mitigated : converter mapping drift (LppExtractedFields →
// profileField). If the mapping ever silently changes, the assertions
// below break.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mirror the secure-storage / SharedPreferences scaffolding used by the
  // existing tax-extraction converter test
  // (test/providers/coach_profile_provider_tax_extraction_test.dart).
  final Map<String, String> mockSecureStorage = {};

  setUp(() {
    mockSecureStorage.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        switch (call.method) {
          case 'write':
            final key = call.arguments['key'] as String;
            final value = call.arguments['value'] as String?;
            if (value != null) {
              mockSecureStorage[key] = value;
            }
            return null;
          case 'read':
            final key = call.arguments['key'] as String;
            return mockSecureStorage[key];
          case 'delete':
            final key = call.arguments['key'] as String;
            mockSecureStorage.remove(key);
            return null;
          case 'deleteAll':
            mockSecureStorage.clear();
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

  group('CoachProfileProvider.updateFromLppExtractedFields (DOCS-01)', () {
    // Anchored on backend golden : test_extractor_julien_cpe_golden.py.
    // Touch nothing here without re-anchoring against that file first.
    const julienCpe = LppExtractedFields(
      avoirVieillesseTotal: 70376.60,
      avoirObligatoire: 30243.80,
      avoirSurobligatoire: 40132.80,
      salaireAssure: 91967.0,
      rachatMaximum: 539413.70,
      // Conversion rates : pass percentage form ; the existing switch in
      // updateFromLppExtraction divides by 100 (6.8 → 0.068).
      tauxConversionObligatoire: 6.8,
      tauxConversionSurobligatoire: 6.0,
      remunerationRate: 2.0,
      cotisationEmploye: 13960.20,
      cotisationEmployeur: 15414.00,
      renteInvalidite: 55188.0,
      capitalDeces: 100000.0,
    );

    test('populates CoachProfile.prevoyance with the canonical CPE values',
        () async {
      final provider = CoachProfileProvider();
      await provider.updateFromLppExtractedFields(julienCpe);

      final profile = provider.profile;
      expect(profile, isNotNull,
          reason:
              'Bootstrap should auto-create CoachProfile.defaults() so vault upload lands somewhere.');

      // Money values within 1 CHF tolerance of backend golden.
      expect(profile!.prevoyance.avoirLppTotal, closeTo(70376.60, 1.0));
      expect(profile.prevoyance.avoirLppObligatoire, closeTo(30243.80, 1.0));
      expect(profile.prevoyance.avoirLppSurobligatoire, closeTo(40132.80, 1.0));
      expect(profile.prevoyance.salaireAssure, closeTo(91967.0, 1.0));
      expect(profile.prevoyance.rachatMaximum, closeTo(539413.70, 1.0));
      expect(profile.prevoyance.disabilityCoverage, closeTo(55188.0, 1.0));
      expect(profile.prevoyance.deathCoverage, closeTo(100000.0, 1.0));

      // Rates : pre-/100 division is the existing switch's contract. The
      // wrapper passes percentage values, so the stored rate is /100.
      expect(profile.prevoyance.tauxConversion, closeTo(0.068, 1e-6));
      expect(profile.prevoyance.tauxConversionSuroblig, closeTo(0.060, 1e-6));
      expect(profile.prevoyance.rendementCaisse, closeTo(0.02, 1e-6));
    });

    test('tags data sources as certificate-confirmed', () async {
      final provider = CoachProfileProvider();
      await provider.updateFromLppExtractedFields(julienCpe);

      final sources = provider.profile!.dataSources;
      expect(sources['prevoyance.avoirLppTotal'], ProfileDataSource.certificate);
      expect(sources['prevoyance.avoirLppObligatoire'],
          ProfileDataSource.certificate);
      expect(sources['prevoyance.salaireAssure'],
          ProfileDataSource.certificate);
      expect(sources['prevoyance.rachatMaximum'],
          ProfileDataSource.certificate);
    });

    test('stamps dataTimestamps so confidence is auto-invalidated', () async {
      // EnhancedConfidenceService reads dataTimestamps to detect freshness ;
      // by stamping them, confidence is invalidated for free — no explicit
      // invalidateConfidence() call needed.
      final provider = CoachProfileProvider();
      await provider.updateFromLppExtractedFields(julienCpe);

      final ts = provider.profile!.dataTimestamps;
      expect(ts.containsKey('prevoyance.avoirLppTotal'), isTrue);
      expect(ts.containsKey('prevoyance.salaireAssure'), isTrue);
      expect(ts['prevoyance.avoirLppTotal'], isA<DateTime>());
    });

    test('null fields are skipped gracefully (no crash, no overwrite)',
        () async {
      final provider = CoachProfileProvider();
      // Only one field present : avoirVieillesseTotal. All others null.
      await provider.updateFromLppExtractedFields(
        const LppExtractedFields(avoirVieillesseTotal: 12345.0),
      );

      final profile = provider.profile!;
      expect(profile.prevoyance.avoirLppTotal, closeTo(12345.0, 1.0));
      // Skipped fields stay at default (null on a fresh defaults() profile).
      expect(profile.prevoyance.salaireAssure, isNull);
      expect(profile.prevoyance.rachatMaximum, isNull);
    });

    test('empty payload is a no-op merge (still safe)', () async {
      final provider = CoachProfileProvider();
      await provider.updateFromLppExtractedFields(const LppExtractedFields());

      // Profile is bootstrapped (defaults()) but no LPP fields land.
      expect(provider.profile, isNotNull);
      expect(provider.profile!.prevoyance.avoirLppTotal, isNull);
    });
  });
}
