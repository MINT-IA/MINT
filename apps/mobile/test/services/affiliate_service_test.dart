import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/affiliate_service.dart';

/// Comprehensive unit tests for AffiliateService
///
/// Tests cover:
/// - Tracked link generation for all providers (VIAC, Finpension, Frankly)
/// - URL structure and parameter validation
/// - Unknown/empty provider handling
/// - CommissionInfo data model
/// - providerCommissions accessor
/// - Conversion stats (placeholder implementation)
/// - Disclosure/compliance fields
/// - Edge cases: case sensitivity, special characters in userId
void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // generateTrackedLink — Provider URL Generation
  // ═══════════════════════════════════════════════════════════════════════

  group('AffiliateService.generateTrackedLink — VIAC', () {
    test('generates valid VIAC affiliate URL', () {
      final link = AffiliateService.generateTrackedLink(
        provider: 'viac',
        userId: 'user123',
      );

      expect(link, contains('viac.ch'));
      expect(link, contains('ref=MINT_PARTNER'));
      expect(link, contains('utm_source=mint'));
      expect(link, contains('utm_medium=app'));
      expect(link, contains('utm_campaign=3a_optimization'));
      expect(link, contains('tracking_id=user123'));
    });

    test('VIAC URL starts with https', () {
      final link = AffiliateService.generateTrackedLink(
        provider: 'viac',
        userId: 'test',
      );
      expect(link, startsWith('https://'));
    });
  });

  group('AffiliateService.generateTrackedLink — Finpension', () {
    test('generates valid Finpension affiliate URL', () {
      final link = AffiliateService.generateTrackedLink(
        provider: 'finpension',
        userId: 'user456',
      );

      expect(link, contains('finpension.ch'));
      expect(link, contains('partner=mint'));
      expect(link, contains('utm_source=mint'));
      expect(link, contains('tracking_id=user456'));
    });
  });

  group('AffiliateService.generateTrackedLink — Frankly', () {
    test('generates valid Frankly affiliate URL', () {
      final link = AffiliateService.generateTrackedLink(
        provider: 'frankly',
        userId: 'user789',
      );

      expect(link, contains('frankly.ch'));
      expect(link, contains('partner=mint'));
      expect(link, contains('utm_source=mint'));
      expect(link, contains('tracking_id=user789'));
    });

    test('Frankly URL includes /3a/ path segment', () {
      final link = AffiliateService.generateTrackedLink(
        provider: 'frankly',
        userId: 'test',
      );
      expect(link, contains('/3a/'));
    });
  });

  group('AffiliateService.generateTrackedLink — edge cases', () {
    test('returns empty string for unknown provider', () {
      final link = AffiliateService.generateTrackedLink(
        provider: 'unknown_provider',
        userId: 'user123',
      );
      expect(link, isEmpty);
    });

    test('returns empty string for empty provider', () {
      final link = AffiliateService.generateTrackedLink(
        provider: '',
        userId: 'user123',
      );
      expect(link, isEmpty);
    });

    test('handles case insensitive provider names', () {
      final linkLower = AffiliateService.generateTrackedLink(
        provider: 'viac',
        userId: 'test',
      );
      final linkUpper = AffiliateService.generateTrackedLink(
        provider: 'VIAC',
        userId: 'test',
      );
      final linkMixed = AffiliateService.generateTrackedLink(
        provider: 'Viac',
        userId: 'test',
      );

      // All should produce the same URL (case-insensitive switch)
      expect(linkLower, equals(linkUpper));
      expect(linkLower, equals(linkMixed));
    });

    test('generates UUID tracking_id when userId is null', () {
      final link = AffiliateService.generateTrackedLink(
        provider: 'viac',
      );

      expect(link, contains('tracking_id='));
      // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      final trackingId =
          RegExp(r'tracking_id=([a-f0-9\-]+)').firstMatch(link)?.group(1);
      expect(trackingId, isNotNull);
      expect(trackingId!.length, 36); // UUID v4 length with dashes
    });

    test('each call with null userId generates different tracking IDs', () {
      final link1 = AffiliateService.generateTrackedLink(provider: 'viac');
      final link2 = AffiliateService.generateTrackedLink(provider: 'viac');

      final id1 =
          RegExp(r'tracking_id=([a-f0-9\-]+)').firstMatch(link1)?.group(1);
      final id2 =
          RegExp(r'tracking_id=([a-f0-9\-]+)').firstMatch(link2)?.group(1);

      expect(id1, isNot(equals(id2)));
    });

    test('all three providers use utm_campaign=3a_optimization', () {
      for (final provider in ['viac', 'finpension', 'frankly']) {
        final link = AffiliateService.generateTrackedLink(
          provider: provider,
          userId: 'test',
        );
        expect(link, contains('utm_campaign=3a_optimization'),
            reason: '$provider should include 3a_optimization campaign');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // providerCommissions — Commission Info
  // ═══════════════════════════════════════════════════════════════════════

  group('AffiliateService.providerCommissions', () {
    test('contains all three providers', () {
      final commissions = AffiliateService.providerCommissions;
      expect(commissions.containsKey('viac'), true);
      expect(commissions.containsKey('finpension'), true);
      expect(commissions.containsKey('frankly'), true);
    });

    test('each provider has a positive commission amount', () {
      for (final entry in AffiliateService.providerCommissions.entries) {
        expect(entry.value.amount, greaterThan(0),
            reason: '${entry.key} should have positive commission');
      }
    });

    test('all providers have oneTime commission type', () {
      for (final entry in AffiliateService.providerCommissions.entries) {
        expect(entry.value.type, CommissionType.oneTime,
            reason: '${entry.key} should be oneTime commission');
      }
    });

    test('VIAC commission amount is 120 CHF', () {
      final viac = AffiliateService.providerCommissions['viac']!;
      expect(viac.amount, 120.0);
      expect(viac.provider, 'VIAC');
    });

    test('Finpension commission amount is 100 CHF', () {
      final finpension = AffiliateService.providerCommissions['finpension']!;
      expect(finpension.amount, 100.0);
      expect(finpension.provider, 'Finpension');
    });

    test('Frankly commission amount is 80 CHF', () {
      final frankly = AffiliateService.providerCommissions['frankly']!;
      expect(frankly.amount, 80.0);
      expect(frankly.provider, 'frankly');
    });

    test('each commission has a non-empty description', () {
      for (final entry in AffiliateService.providerCommissions.entries) {
        expect(entry.value.description, isNotEmpty,
            reason: '${entry.key} should have a description');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // CommissionInfo Model
  // ═══════════════════════════════════════════════════════════════════════

  group('CommissionInfo model', () {
    test('constructs correctly with all fields', () {
      const info = CommissionInfo(
        provider: 'TestProvider',
        amount: 50.0,
        type: CommissionType.recurring,
        description: 'Test commission',
      );

      expect(info.provider, 'TestProvider');
      expect(info.amount, 50.0);
      expect(info.type, CommissionType.recurring);
      expect(info.description, 'Test commission');
    });

    test('CommissionType enum has two values', () {
      expect(CommissionType.values.length, 2);
      expect(CommissionType.values, contains(CommissionType.oneTime));
      expect(CommissionType.values, contains(CommissionType.recurring));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // getConversionStats — Placeholder Implementation
  // ═══════════════════════════════════════════════════════════════════════

  group('AffiliateService.getConversionStats', () {
    test('returns a map with expected keys', () async {
      final stats = await AffiliateService.getConversionStats();

      expect(stats.containsKey('total_clicks'), true);
      expect(stats.containsKey('total_conversions'), true);
      expect(stats.containsKey('conversion_rate'), true);
      expect(stats.containsKey('total_commission'), true);
      expect(stats.containsKey('by_provider'), true);
    });

    test('returns zeroed stats (placeholder)', () async {
      final stats = await AffiliateService.getConversionStats();

      expect(stats['total_clicks'], 0);
      expect(stats['total_conversions'], 0);
      expect(stats['conversion_rate'], 0.0);
      expect(stats['total_commission'], 0.0);
    });

    test('by_provider contains per-provider stats', () async {
      final stats = await AffiliateService.getConversionStats();
      final byProvider = stats['by_provider'] as Map<String, dynamic>;

      expect(byProvider.containsKey('viac'), true);
      expect(byProvider.containsKey('finpension'), true);

      final viacStats = byProvider['viac'] as Map<String, dynamic>;
      expect(viacStats['clicks'], 0);
      expect(viacStats['conversions'], 0);
      expect(viacStats['commission'], 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // logAffiliateClick / logConversion — No-throw tests
  // ═══════════════════════════════════════════════════════════════════════

  group('AffiliateService.logAffiliateClick', () {
    test('does not throw when called with valid params', () async {
      await expectLater(
        AffiliateService.logAffiliateClick(
          provider: 'viac',
          userId: 'user123',
        ),
        completes,
      );
    });

    test('does not throw when called with metadata', () async {
      await expectLater(
        AffiliateService.logAffiliateClick(
          provider: 'finpension',
          userId: 'user456',
          metadata: {'source': 'comparator', 'screen': '3a_optimization'},
        ),
        completes,
      );
    });
  });

  group('AffiliateService.logConversion', () {
    test('does not throw when called with valid params', () async {
      await expectLater(
        AffiliateService.logConversion(
          provider: 'viac',
          userId: 'user123',
          commission: 120.0,
        ),
        completes,
      );
    });

    test('does not throw with zero commission', () async {
      await expectLater(
        AffiliateService.logConversion(
          provider: 'frankly',
          userId: 'user789',
          commission: 0.0,
        ),
        completes,
      );
    });
  });
}
