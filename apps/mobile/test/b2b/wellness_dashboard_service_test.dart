import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/b2b/wellness_dashboard_service.dart';

/// Helper: create N anonymized employee data entries with reasonable defaults.
List<AnonymizedEmployeeData> _makeData(
  int n, {
  double fhs = 65.0,
  double conf = 55.0,
  bool has3a = true,
  double epargne = 12.0,
  List<String> topics = const ['avs', 'lpp'],
}) {
  return List.generate(
    n,
    (_) => AnonymizedEmployeeData(
      fhsScore: fhs,
      confidenceScore: conf,
      has3a: has3a,
      epargneRate: epargne,
      viewedTopics: topics,
    ),
  );
}

void main() {
  final fixedNow = DateTime(2026, 3, 18, 10, 0);
  const orgA = 'org_alpha_001';
  const orgB = 'org_beta_002';

  group('WellnessDashboardService', () {
    test('generate aggregate with 15 participants returns valid result',
        () async {
      final data = _makeData(15, fhs: 70.0, conf: 60.0);
      final agg = await WellnessDashboardService.generateAggregate(
        organizationId: orgA,
        data: data,
        now: fixedNow,
      );
      expect(agg, isNotNull);
      expect(agg!.totalParticipants, 15);
      expect(agg.avgFhsScore, closeTo(70.0, 0.01));
      expect(agg.avgConfidenceScore, closeTo(60.0, 0.01));
    });

    test('generate aggregate with 5 participants returns null (privacy)',
        () async {
      final data = _makeData(5);
      final agg = await WellnessDashboardService.generateAggregate(
        organizationId: orgA,
        data: data,
        now: fixedNow,
      );
      expect(agg, isNull);
    });

    test('privacy threshold: exactly 10 participants is valid', () async {
      final data = _makeData(10);
      final agg = await WellnessDashboardService.generateAggregate(
        organizationId: orgA,
        data: data,
        now: fixedNow,
      );
      expect(agg, isNotNull);
      expect(agg!.totalParticipants, 10);
    });

    test('avg FHS computed correctly with mixed values', () async {
      final data = [
        ...List.generate(
          5,
          (_) => const AnonymizedEmployeeData(fhsScore: 80.0, has3a: true),
        ),
        ...List.generate(
          5,
          (_) => const AnonymizedEmployeeData(fhsScore: 60.0, has3a: false),
        ),
      ];
      final agg = await WellnessDashboardService.generateAggregate(
        organizationId: orgA,
        data: data,
        now: fixedNow,
      );
      expect(agg, isNotNull);
      expect(agg!.avgFhsScore, closeTo(70.0, 0.01));
    });

    test('3a participation rate computed correctly', () async {
      final data = [
        ...List.generate(
          7,
          (_) => const AnonymizedEmployeeData(fhsScore: 65.0, has3a: true),
        ),
        ...List.generate(
          3,
          (_) => const AnonymizedEmployeeData(fhsScore: 65.0, has3a: false),
        ),
      ];
      final agg = await WellnessDashboardService.generateAggregate(
        organizationId: orgA,
        data: data,
        now: fixedNow,
      );
      expect(agg, isNotNull);
      // 7/10 = 70%
      expect(agg!.participation3aRate, closeTo(70.0, 0.01));
    });

    test('top topics aggregated and sorted by count', () async {
      final data = [
        ...List.generate(
          6,
          (_) => const AnonymizedEmployeeData(
            fhsScore: 65.0,
            viewedTopics: ['avs', 'lpp'],
          ),
        ),
        ...List.generate(
          4,
          (_) => const AnonymizedEmployeeData(
            fhsScore: 65.0,
            viewedTopics: ['3a', 'avs'],
          ),
        ),
      ];
      final agg = await WellnessDashboardService.generateAggregate(
        organizationId: orgA,
        data: data,
        now: fixedNow,
      );
      expect(agg, isNotNull);
      expect(agg!.topTopics['avs'], 10); // all 10 viewed avs
      expect(agg.topTopics['lpp'], 6);
      expect(agg.topTopics['3a'], 4);
      // avs should be first (highest count)
      expect(agg.topTopics.keys.first, 'avs');
    });

    test('disclaimer always present', () async {
      final data = _makeData(10);
      final agg = await WellnessDashboardService.generateAggregate(
        organizationId: orgA,
        data: data,
        now: fixedNow,
      );
      expect(agg, isNotNull);
      expect(agg!.disclaimer, isNotEmpty);
      expect(agg.disclaimer, contains('anonymisées'));
      expect(agg.disclaimer, contains('LSFin'));
    });

    test('no individual data in output', () async {
      final data = _makeData(12, fhs: 72.5, conf: 58.3);
      final agg = await WellnessDashboardService.generateAggregate(
        organizationId: orgA,
        data: data,
        now: fixedNow,
      );
      expect(agg, isNotNull);
      // AggregatedWellness has no fields for individual records.
      // Verify the type doesn't expose a list of employees.
      expect(agg, isA<AggregatedWellness>());
      // Ensure generatedAt is a timestamp, not employee data.
      expect(agg!.generatedAt, contains('2026'));
    });

    test('no names, emails, or IDs in any field', () async {
      final data = _makeData(10);
      final agg = await WellnessDashboardService.generateAggregate(
        organizationId: orgA,
        data: data,
        now: fixedNow,
      );
      expect(agg, isNotNull);
      final str = '${agg!.disclaimer} ${agg.generatedAt}';
      expect(str.contains('@employee'), isFalse);
      expect(str.contains('emp_'), isFalse);
    });

    test('empty data list returns null', () async {
      final agg = await WellnessDashboardService.generateAggregate(
        organizationId: orgA,
        data: [],
        now: fixedNow,
      );
      expect(agg, isNull);
    });

    test('all participants have null FHS returns null', () async {
      final data = List.generate(
        10,
        (_) => const AnonymizedEmployeeData(has3a: false),
      );
      final agg = await WellnessDashboardService.generateAggregate(
        organizationId: orgA,
        data: data,
        now: fixedNow,
      );
      expect(agg, isNull);
    });

    test('no banned terms in output', () async {
      final data = _makeData(15);
      final agg = await WellnessDashboardService.generateAggregate(
        organizationId: orgA,
        data: data,
        now: fixedNow,
      );
      expect(agg, isNotNull);
      final text = agg!.disclaimer.toLowerCase();
      expect(text.contains('garanti'), isFalse);
      expect(text.contains('certain'), isFalse);
      expect(text.contains('sans risque'), isFalse);
      expect(text.contains('optimal'), isFalse);
    });

    // ═══════════════════════════════════════════════════════════════
    //  ADVERSARIAL TESTS — Compliance Hardener + Test Generation
    // ═══════════════════════════════════════════════════════════════

    group('Privacy — adversarial', () {
      test('9 participants returns null (below minimum)', () async {
        final data = _makeData(9);
        final agg = await WellnessDashboardService.generateAggregate(
          organizationId: orgA,
          data: data,
          now: fixedNow,
        );
        expect(agg, isNull, reason: 'Privacy: <10 participants must block');
      });

      test('1 participant returns null', () async {
        final data = _makeData(1);
        final agg = await WellnessDashboardService.generateAggregate(
          organizationId: orgA,
          data: data,
          now: fixedNow,
        );
        expect(agg, isNull);
      });

      test('isPrivacySafe returns false for 9, true for 10', () {
        expect(WellnessDashboardService.isPrivacySafe(9), isFalse);
        expect(WellnessDashboardService.isPrivacySafe(10), isTrue);
        expect(WellnessDashboardService.isPrivacySafe(0), isFalse);
        expect(WellnessDashboardService.isPrivacySafe(-1), isFalse);
      });

      test('kMinParticipants constant is 10', () {
        expect(kMinParticipants, 10);
      });
    });

    group('Data isolation — adversarial', () {
      test('organizationId is stored in aggregate output', () async {
        final data = _makeData(10);
        final agg = await WellnessDashboardService.generateAggregate(
          organizationId: orgA,
          data: data,
          now: fixedNow,
        );
        expect(agg, isNotNull);
        expect(agg!.organizationId, orgA);
      });

      test('different orgs get different organizationId in output', () async {
        final dataA = _makeData(10, fhs: 80.0);
        final dataB = _makeData(10, fhs: 50.0);

        final aggA = await WellnessDashboardService.generateAggregate(
          organizationId: orgA,
          data: dataA,
          now: fixedNow,
        );
        final aggB = await WellnessDashboardService.generateAggregate(
          organizationId: orgB,
          data: dataB,
          now: fixedNow,
        );

        expect(aggA, isNotNull);
        expect(aggB, isNotNull);
        expect(aggA!.organizationId, orgA);
        expect(aggB!.organizationId, orgB);
        expect(aggA.organizationId, isNot(equals(aggB.organizationId)));
        // Data is distinct
        expect(aggA.avgFhsScore, isNot(equals(aggB.avgFhsScore)));
      });

      test('empty organizationId returns null (data isolation guard)',
          () async {
        final data = _makeData(10);
        final agg = await WellnessDashboardService.generateAggregate(
          organizationId: '',
          data: data,
          now: fixedNow,
        );
        expect(agg, isNull,
            reason: 'Empty orgId = data isolation violation');
      });

      test('whitespace-only organizationId returns null', () async {
        final data = _makeData(10);
        final agg = await WellnessDashboardService.generateAggregate(
          organizationId: '   ',
          data: data,
          now: fixedNow,
        );
        expect(agg, isNull,
            reason: 'Whitespace orgId = data isolation violation');
      });
    });

    group('Edge cases — scale', () {
      test('10000 employees aggregates correctly', () async {
        final data = _makeData(10000, fhs: 72.0, conf: 55.0, epargne: 15.0);
        final agg = await WellnessDashboardService.generateAggregate(
          organizationId: orgA,
          data: data,
          now: fixedNow,
        );
        expect(agg, isNotNull);
        expect(agg!.totalParticipants, 10000);
        expect(agg.avgFhsScore, closeTo(72.0, 0.01));
        expect(agg.avgConfidenceScore, closeTo(55.0, 0.01));
        expect(agg.avgEpargneRate, closeTo(15.0, 0.01));
      });

      test('single employee (below threshold) returns null', () async {
        final data = _makeData(1, fhs: 99.0);
        final agg = await WellnessDashboardService.generateAggregate(
          organizationId: orgA,
          data: data,
          now: fixedNow,
        );
        expect(agg, isNull);
      });

      test('all null scores except fhs still produces aggregate', () async {
        final data = List.generate(
          10,
          (_) => const AnonymizedEmployeeData(fhsScore: 50.0),
        );
        final agg = await WellnessDashboardService.generateAggregate(
          organizationId: orgA,
          data: data,
          now: fixedNow,
        );
        expect(agg, isNotNull);
        expect(agg!.avgFhsScore, closeTo(50.0, 0.01));
        expect(agg.avgConfidenceScore, 0.0);
        expect(agg.avgEpargneRate, 0.0);
      });

      test('mixed null and non-null fhs averages only non-null', () async {
        final data = [
          ...List.generate(
            5,
            (_) => const AnonymizedEmployeeData(fhsScore: 80.0),
          ),
          ...List.generate(
            5,
            (_) => const AnonymizedEmployeeData(fhsScore: null),
          ),
        ];
        // 5 non-null fhs out of 10 total
        final agg = await WellnessDashboardService.generateAggregate(
          organizationId: orgA,
          data: data,
          now: fixedNow,
        );
        expect(agg, isNotNull);
        // avg should be 80.0 (only the 5 with fhs)
        expect(agg!.avgFhsScore, closeTo(80.0, 0.01));
      });

      test('zero 3a participation returns 0 rate', () async {
        final data = _makeData(10, has3a: false);
        final agg = await WellnessDashboardService.generateAggregate(
          organizationId: orgA,
          data: data,
          now: fixedNow,
        );
        expect(agg, isNotNull);
        expect(agg!.participation3aRate, 0.0);
      });

      test('100% 3a participation returns 100 rate', () async {
        final data = _makeData(10, has3a: true);
        final agg = await WellnessDashboardService.generateAggregate(
          organizationId: orgA,
          data: data,
          now: fixedNow,
        );
        expect(agg, isNotNull);
        expect(agg!.participation3aRate, closeTo(100.0, 0.01));
      });
    });

    group('Compliance — disclaimer and banned terms', () {
      test('disclaimer contains educational notice', () async {
        final data = _makeData(10);
        final agg = await WellnessDashboardService.generateAggregate(
          organizationId: orgA,
          data: data,
          now: fixedNow,
        );
        expect(agg!.disclaimer, contains('ducatif'));
        expect(agg.disclaimer, contains('ne constitue pas un conseil'));
      });

      test('disclaimer mentions minimum participants', () async {
        final data = _makeData(10);
        final agg = await WellnessDashboardService.generateAggregate(
          organizationId: orgA,
          data: data,
          now: fixedNow,
        );
        expect(agg!.disclaimer, contains('$kMinParticipants'));
      });

      test('kDisclaimer has NBSP before colon', () {
        expect(
          WellnessDashboardService.kDisclaimer,
          contains('\u00a0'),
        );
      });
    });
  });
}
