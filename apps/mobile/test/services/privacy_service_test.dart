import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/privacy_service.dart';

/// Unit tests for PrivacyService
///
/// Tests the privacy/data management service that handles nLPD compliance:
///   - Data categories (required vs optional)
///   - Consent status logic
///   - Export summary generation
///   - Disclaimer and legal sources
void main() {
  group('Data categories', () {
    test('has exactly 8 data categories (F3-4)', () {
      expect(PrivacyService.dataCategories.length, 8);
    });

    test('each category has all required fields', () {
      for (final cat in PrivacyService.dataCategories) {
        expect(cat.containsKey('id'), true,
            reason: 'Category missing id: $cat');
        expect(cat.containsKey('label'), true,
            reason: 'Category missing label: $cat');
        expect(cat.containsKey('description'), true,
            reason: 'Category missing description: $cat');
        expect(cat.containsKey('legalBasis'), true,
            reason: 'Category missing legalBasis: $cat');
        expect(cat.containsKey('required'), true,
            reason: 'Category missing required: $cat');
        expect(cat.containsKey('retentionDays'), true,
            reason: 'Category missing retentionDays: $cat');
      }
    });

    test('all category IDs are unique', () {
      final ids =
          PrivacyService.dataCategories.map((c) => c['id'] as String).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('category IDs match expected set (F3-4)', () {
      final ids =
          PrivacyService.dataCategories.map((c) => c['id'] as String).toSet();
      expect(
          ids,
          containsAll([
            'core_profile',
            'byok_data_sharing',
            'snapshot_storage',
            'analytics',
            'coaching_notifications',
            'open_banking',
            'document_upload',
            'rag_queries',
          ]));
    });

    test('retention days are positive integers for all categories', () {
      for (final cat in PrivacyService.dataCategories) {
        final days = cat['retentionDays'] as int;
        expect(days, greaterThan(0),
            reason: 'Category ${cat['id']} has non-positive retention');
      }
    });
  });

  group('Required vs optional categories', () {
    test('core_profile is the only required category', () {
      final required = PrivacyService.requiredCategories;
      expect(required.length, 1);
      expect(required.first['id'], 'core_profile');
    });

    test('there are exactly 7 optional categories (F3-4)', () {
      final optional = PrivacyService.optionalCategories;
      expect(optional.length, 7);
    });

    test('optional categories do not include core_profile', () {
      final optionalIds =
          PrivacyService.optionalCategories.map((c) => c['id']).toSet();
      expect(optionalIds.contains('core_profile'), false);
    });

    test('required + optional equals total categories', () {
      expect(
        PrivacyService.requiredCategories.length +
            PrivacyService.optionalCategories.length,
        PrivacyService.dataCategories.length,
      );
    });
  });

  group('Consent status', () {
    test('required categories always have consented=true', () {
      final status = PrivacyService.getConsentStatus();
      final coreProfile =
          status.firstWhere((s) => s['id'] == 'core_profile');
      expect(coreProfile['consented'], true);
      expect(coreProfile['canRevoke'], false);
    });

    test('optional categories default to consented=false', () {
      final status = PrivacyService.getConsentStatus();
      final analytics = status.firstWhere((s) => s['id'] == 'analytics');
      expect(analytics['consented'], false);
      expect(analytics['canRevoke'], true);
    });

    test('custom consents override optional defaults', () {
      final consents = {'analytics': true, 'open_banking': true};
      final status = PrivacyService.getConsentStatus(
        currentConsents: consents,
      );
      final analytics = status.firstWhere((s) => s['id'] == 'analytics');
      final openBanking =
          status.firstWhere((s) => s['id'] == 'open_banking');
      final ragQueries =
          status.firstWhere((s) => s['id'] == 'rag_queries');
      expect(analytics['consented'], true);
      expect(openBanking['consented'], true);
      expect(ragQueries['consented'], false);
    });

    test('custom consents cannot override required category', () {
      final consents = {'core_profile': false};
      final status = PrivacyService.getConsentStatus(
        currentConsents: consents,
      );
      final coreProfile =
          status.firstWhere((s) => s['id'] == 'core_profile');
      // Required categories remain consented=true regardless
      expect(coreProfile['consented'], true);
    });

    test('returns same number of items as dataCategories', () {
      final status = PrivacyService.getConsentStatus();
      expect(status.length, PrivacyService.dataCategories.length);
    });
  });

  group('Export summary generation', () {
    test('generates valid export summary with profile data', () {
      final summary = PrivacyService.generateExportSummary(
        profileId: 'test-123',
        profileData: {
          'birthYear': 1990,
          'canton': 'VD',
          'income': 80000,
        },
      );
      expect(summary['profileId'], 'test-123');
      expect(summary['format'], 'JSON');
      expect(summary['exportDate'], isNotEmpty);
      expect(summary['dataCategories'], contains('core_profile'));
      expect(summary['disclaimer'], isNotEmpty);
      expect(summary['sources'], isNotEmpty);
    });

    test('export includes analytics when enabled', () {
      final summary = PrivacyService.generateExportSummary(
        profileId: 'test-456',
        profileData: {
          'birthYear': 1985,
          'analyticsEnabled': true,
        },
      );
      final cats = summary['dataCategories'] as List<String>;
      expect(cats, contains('analytics'));
    });

    test('export with empty profile has no data categories', () {
      final summary = PrivacyService.generateExportSummary(
        profileId: 'test-empty',
        profileData: {},
      );
      final cats = summary['dataCategories'] as List<String>;
      expect(cats, isEmpty);
    });

    test('export date is valid ISO 8601', () {
      final summary = PrivacyService.generateExportSummary(
        profileId: 'test-date',
        profileData: {'birthYear': 1990},
      );
      final dateStr = summary['exportDate'] as String;
      expect(() => DateTime.parse(dateStr), returnsNormally);
    });
  });

  group('Category lookup', () {
    test('getCategoryById returns correct category', () {
      final cat = PrivacyService.getCategoryById('open_banking');
      expect(cat, isNotNull);
      expect(cat!['label'], 'Donnees bancaires (bLink)');
    });

    test('getCategoryById returns null for unknown ID', () {
      final cat = PrivacyService.getCategoryById('nonexistent');
      expect(cat, isNull);
    });

    test('getRetentionDays returns correct value', () {
      expect(PrivacyService.getRetentionDays('analytics'), 90);
      expect(PrivacyService.getRetentionDays('open_banking'), 30);
      expect(PrivacyService.getRetentionDays('core_profile'), 365);
    });

    test('getRetentionDays returns null for unknown ID', () {
      expect(PrivacyService.getRetentionDays('nonexistent'), isNull);
    });
  });

  group('Consent validation', () {
    test('validates required consents are present', () {
      final valid = PrivacyService.validateRequiredConsents(
        {'core_profile': true},
      );
      expect(valid, true);
    });

    test('fails validation when required consent is missing', () {
      final valid = PrivacyService.validateRequiredConsents({});
      expect(valid, false);
    });

    test('fails validation when required consent is false', () {
      final valid = PrivacyService.validateRequiredConsents(
        {'core_profile': false},
      );
      expect(valid, false);
    });
  });

  group('Disclaimer and sources', () {
    test('disclaimer mentions nLPD', () {
      expect(PrivacyService.disclaimer, contains('nLPD'));
    });

    test('disclaimer mentions data not sold', () {
      expect(PrivacyService.disclaimer, contains('jamais vendues'));
    });

    test('sources list is not empty', () {
      expect(PrivacyService.sources, isNotEmpty);
    });

    test('sources contain key nLPD articles', () {
      final sourcesJoined = PrivacyService.sources.join(' ');
      expect(sourcesJoined, contains('art. 6'));
      expect(sourcesJoined, contains('art. 25'));
      expect(sourcesJoined, contains('art. 28'));
      expect(sourcesJoined, contains('art. 32'));
    });

    test('sources contain OPDo reference', () {
      final sourcesJoined = PrivacyService.sources.join(' ');
      expect(sourcesJoined, contains('OPDo'));
    });
  });
}
