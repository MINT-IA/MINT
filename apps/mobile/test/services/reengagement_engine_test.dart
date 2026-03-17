import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/reengagement_engine.dart';

/// Tests for ReengagementEngine (Sprint S40).
///
/// Validates calendar-triggered messages, personal numbers,
/// time constraints, and compliance (no generic messages).
void main() {
  group('ReengagementEngine — calendar triggers', () {
    test('January generates newYear + quarterlyFri', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 1, 15),
        taxSaving3a: 1820,
        friTotal: 62,
        friDelta: 3,
      );

      final triggers = messages.map((m) => m.trigger).toSet();
      expect(triggers, contains(ReengagementTrigger.newYear));
      expect(triggers, contains(ReengagementTrigger.quarterlyFri));
    });

    test('February generates taxPrep', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 2, 10),
        taxSaving3a: 1500,
      );

      expect(messages.any((m) => m.trigger == ReengagementTrigger.taxPrep),
          true);
      // No quarterly FRI in February
      expect(
          messages
              .any((m) => m.trigger == ReengagementTrigger.quarterlyFri),
          false);
    });

    test('March generates taxDeadline with correct canton', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 3, 10),
        canton: 'VS',
        taxSaving3a: 1000,
      );

      final deadline = messages
          .firstWhere((m) => m.trigger == ReengagementTrigger.taxDeadline);
      expect(deadline.body, contains('VS'));
      expect(deadline.month, 3);
    });

    test('March taxDeadline days count is correct', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 3, 10),
      );

      final deadline = messages
          .firstWhere((m) => m.trigger == ReengagementTrigger.taxDeadline);
      // March has 31 days, day 10 → 21 days left
      expect(deadline.timeConstraint, '21 jours');
    });

    test('October generates threeACountdown + quarterlyFri', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 10, 1),
        taxSaving3a: 1820,
        friTotal: 55,
        friDelta: -2,
      );

      final triggers = messages.map((m) => m.trigger).toSet();
      expect(triggers, contains(ReengagementTrigger.threeACountdown));
      expect(triggers, contains(ReengagementTrigger.quarterlyFri));
    });

    test('November generates threeAUrgency', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 11, 15),
        taxSaving3a: 1820,
      );

      final urgency = messages
          .firstWhere((m) => m.trigger == ReengagementTrigger.threeAUrgency);
      expect(urgency.body, contains('1\'820'));
      expect(urgency.deeplink, '/pilier-3a');
    });

    test('December generates threeAFinal', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 12, 5),
        taxSaving3a: 1820,
      );

      expect(
          messages.any((m) => m.trigger == ReengagementTrigger.threeAFinal),
          true);
      final finalMsg = messages
          .firstWhere((m) => m.trigger == ReengagementTrigger.threeAFinal);
      expect(finalMsg.timeConstraint, 'Dernier mois');
    });

    test('April generates only quarterlyFri', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 4, 15),
        friTotal: 70,
        friDelta: 5,
      );

      expect(messages.length, 1);
      expect(messages.first.trigger, ReengagementTrigger.quarterlyFri);
    });

    test('July generates only quarterlyFri', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 7, 1),
        friTotal: 45,
        friDelta: 0,
      );

      expect(messages.length, 1);
      expect(messages.first.trigger, ReengagementTrigger.quarterlyFri);
    });
  });

  group('ReengagementEngine — personal numbers', () {
    test('messages contain personal CHF amount', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 1, 15),
        taxSaving3a: 1820,
      );

      final newYear = messages
          .firstWhere((m) => m.trigger == ReengagementTrigger.newYear);
      expect(newYear.personalNumber, contains('1\'820'));
    });

    test('quarterly FRI shows score and delta', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 4, 1),
        friTotal: 62,
        friDelta: 3,
      );

      final fri = messages.first;
      expect(fri.body, contains('62'));
      expect(fri.body, contains('+3'));
    });

    test('negative FRI delta shows minus sign', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 4, 1),
        friTotal: 55,
        friDelta: -5,
      );

      final fri = messages.first;
      expect(fri.body, contains('-5'));
    });
  });

  group('ReengagementEngine — CHF formatting', () {
    test('formats thousands with Swiss apostrophe', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 1, 15),
        taxSaving3a: 7258,
      );

      final newYear = messages
          .firstWhere((m) => m.trigger == ReengagementTrigger.newYear);
      expect(newYear.personalNumber, contains("7'258"));
    });

    test('formats zero correctly', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 1, 15),
        taxSaving3a: 0,
      );

      final newYear = messages
          .firstWhere((m) => m.trigger == ReengagementTrigger.newYear);
      expect(newYear.personalNumber, contains('0'));
    });
  });

  group('ReengagementEngine — deeplinks', () {
    test('3a messages link to /pilier-3a', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 10, 1),
        taxSaving3a: 1000,
      );

      final threeA = messages
          .firstWhere((m) => m.trigger == ReengagementTrigger.threeACountdown);
      expect(threeA.deeplink, '/pilier-3a');
    });

    test('tax messages link to /tools', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 2, 1),
      );

      final taxPrep = messages
          .firstWhere((m) => m.trigger == ReengagementTrigger.taxPrep);
      expect(taxPrep.deeplink, '/tools');
    });

    test('quarterly FRI links to /retraite', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 4, 1),
        friTotal: 60,
      );

      expect(messages.first.deeplink, '/retraite');
    });
  });

  group('ReengagementEngine — months without triggers', () {
    test('May generates no messages (no calendar event)', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 5, 15),
        taxSaving3a: 1500,
      );

      expect(messages, isEmpty);
    });

    test('June generates no messages', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 6, 15),
      );

      expect(messages, isEmpty);
    });

    test('August generates no messages', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 8, 15),
      );

      expect(messages, isEmpty);
    });

    test('September generates no messages', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 9, 15),
      );

      expect(messages, isEmpty);
    });
  });

  group('ReengagementEngine — end-of-year countdown', () {
    test('October 1 shows ~91 days remaining', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 10, 1),
      );

      final threeA = messages
          .firstWhere((m) => m.trigger == ReengagementTrigger.threeACountdown);
      // Oct 1 → Dec 31 = 91 days
      expect(threeA.timeConstraint, '91 jours');
    });

    test('November 15 shows ~46 days remaining', () {
      final messages = ReengagementEngine.generateMessages(
        today: DateTime(2026, 11, 15),
      );

      final urgency = messages
          .firstWhere((m) => m.trigger == ReengagementTrigger.threeAUrgency);
      // Nov 15 → Dec 31 = 46 days
      expect(urgency.timeConstraint, '46 jours');
    });
  });
}
