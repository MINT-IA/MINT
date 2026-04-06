import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/anticipation/anticipation_trigger.dart';
import 'package:mint_mobile/services/anticipation/anticipation_signal.dart';

void main() {
  group('AnticipationTrigger', () {
    test('has exactly 5 values', () {
      expect(AnticipationTrigger.values.length, 5);
    });

    test('contains all expected values', () {
      expect(
        AnticipationTrigger.values.map((e) => e.name).toSet(),
        {
          'fiscal3aDeadline',
          'cantonalTaxDeadline',
          'lppRachatWindow',
          'salaryIncrease3aRecalc',
          'ageMilestoneLppBonification',
        },
      );
    });
  });

  group('AlertTemplate', () {
    test('has exactly 5 values', () {
      expect(AlertTemplate.values.length, 5);
    });

    test('contains all expected values matching triggers', () {
      expect(
        AlertTemplate.values.map((e) => e.name).toSet(),
        {
          'fiscal3aDeadline',
          'cantonalTaxDeadline',
          'lppRachatWindow',
          'salaryIncrease3aRecalc',
          'ageMilestoneLppBonification',
        },
      );
    });
  });

  group('AnticipationSignal', () {
    late AnticipationSignal signal;

    setUp(() {
      signal = AnticipationSignal(
        id: 'fiscal3aDeadline_20261215',
        template: AlertTemplate.fiscal3aDeadline,
        titleKey: 'anticipation3aDeadlineTitle',
        factKey: 'anticipation3aDeadlineFact',
        sourceRef: 'OPP3 art.\u00a07',
        simulatorLink: '/pilier-3a',
        priorityScore: 0.0,
        expiresAt: DateTime(2027, 1, 1),
        params: {'days': '16', 'limit': "7'258", 'year': '2026'},
      );
    });

    test('stores all required fields', () {
      expect(signal.id, 'fiscal3aDeadline_20261215');
      expect(signal.template, AlertTemplate.fiscal3aDeadline);
      expect(signal.titleKey, 'anticipation3aDeadlineTitle');
      expect(signal.factKey, 'anticipation3aDeadlineFact');
      expect(signal.sourceRef, 'OPP3 art.\u00a07');
      expect(signal.simulatorLink, '/pilier-3a');
      expect(signal.priorityScore, 0.0);
      expect(signal.expiresAt, DateTime(2027, 1, 1));
      expect(signal.params, {'days': '16', 'limit': "7'258", 'year': '2026'});
    });

    test('params is nullable', () {
      final noParams = AnticipationSignal(
        id: 'test_20261215',
        template: AlertTemplate.lppRachatWindow,
        titleKey: 'testTitle',
        factKey: 'testFact',
        sourceRef: 'LPP art.\u00a079b',
        simulatorLink: '/lpp-rachat',
        priorityScore: 0.0,
        expiresAt: DateTime(2027, 1, 1),
      );
      expect(noParams.params, isNull);
    });

    test('equality based on id', () {
      final same = AnticipationSignal(
        id: 'fiscal3aDeadline_20261215',
        template: AlertTemplate.fiscal3aDeadline,
        titleKey: 'different',
        factKey: 'different',
        sourceRef: 'different',
        simulatorLink: '/different',
        priorityScore: 99.0,
        expiresAt: DateTime(2099, 1, 1),
      );
      expect(signal, equals(same));
      expect(signal.hashCode, equals(same.hashCode));
    });

    test('inequality for different ids', () {
      final different = AnticipationSignal(
        id: 'cantonalTaxDeadline_20261215',
        template: AlertTemplate.fiscal3aDeadline,
        titleKey: 'anticipation3aDeadlineTitle',
        factKey: 'anticipation3aDeadlineFact',
        sourceRef: 'OPP3 art.\u00a07',
        simulatorLink: '/pilier-3a',
        priorityScore: 0.0,
        expiresAt: DateTime(2027, 1, 1),
      );
      expect(signal, isNot(equals(different)));
    });

    test('copyWith updates priorityScore', () {
      final ranked = signal.copyWith(priorityScore: 85.0);
      expect(ranked.priorityScore, 85.0);
      expect(ranked.id, signal.id);
      expect(ranked.template, signal.template);
      expect(ranked.titleKey, signal.titleKey);
    });
  });
}
