import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/widgets/coach/chat_data_capture.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';

// ────────────────────────────────────────────────────────────
//  CHAT DATA CAPTURE TESTS — CHAT-04 (Phase 3)
//
//  Verifies:
//  1. parseAge handles "49", "J'ai 49 ans", invalid input
//  2. parseCanton handles "VS", "Valais", "valais"
//  3. parseSalary handles "120000", "120'000", "CHF 120'000"
//  4. missingFields returns only unknown fields (pre-fill rule)
//  5. Invalid input returns null (not crash)
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CHAT-04: ChatDataCaptureHandler.parseAge', () {
    test('parses plain number "49"', () {
      expect(ChatDataCaptureHandler.parseAge('49'), equals(49));
    });

    test('parses "J\'ai 49 ans"', () {
      expect(ChatDataCaptureHandler.parseAge('J\'ai 49 ans'), equals(49));
    });

    test('parses "25"', () {
      expect(ChatDataCaptureHandler.parseAge('25'), equals(25));
    });

    test('rejects "pizza" (non-numeric)', () {
      expect(ChatDataCaptureHandler.parseAge('pizza'), isNull);
    });

    test('rejects age < 16', () {
      expect(ChatDataCaptureHandler.parseAge('5'), isNull);
    });

    test('rejects age > 120', () {
      expect(ChatDataCaptureHandler.parseAge('200'), isNull);
    });
  });

  group('CHAT-04: ChatDataCaptureHandler.parseCanton', () {
    test('parses abbreviation "VS"', () {
      expect(ChatDataCaptureHandler.parseCanton('VS'), equals('VS'));
    });

    test('parses lowercase abbreviation "vs"', () {
      expect(ChatDataCaptureHandler.parseCanton('vs'), equals('VS'));
    });

    test('parses full name "Valais"', () {
      expect(ChatDataCaptureHandler.parseCanton('Valais'), equals('VS'));
    });

    test('parses accent-insensitive "geneve"', () {
      expect(ChatDataCaptureHandler.parseCanton('geneve'), equals('GE'));
    });

    test('parses "Zurich"', () {
      expect(ChatDataCaptureHandler.parseCanton('Zurich'), equals('ZH'));
    });

    test('returns null for unknown canton', () {
      expect(ChatDataCaptureHandler.parseCanton('Paris'), isNull);
    });
  });

  group('CHAT-04: ChatDataCaptureHandler.parseSalary', () {
    test('parses plain number "120000"', () {
      expect(ChatDataCaptureHandler.parseSalary('120000'), equals(120000));
    });

    test('parses Swiss format "120\'000"', () {
      expect(ChatDataCaptureHandler.parseSalary("120'000"), equals(120000));
    });

    test('parses with CHF prefix "CHF 120\'000"', () {
      expect(ChatDataCaptureHandler.parseSalary("CHF 120'000"), equals(120000));
    });

    test('parses "67000"', () {
      expect(ChatDataCaptureHandler.parseSalary('67000'), equals(67000));
    });

    test('rejects negative values', () {
      expect(ChatDataCaptureHandler.parseSalary('-50000'), isNull);
    });

    test('rejects non-numeric "beaucoup"', () {
      expect(ChatDataCaptureHandler.parseSalary('beaucoup'), isNull);
    });
  });

  group('CHAT-04: ChatDataCaptureHandler.missingFields', () {
    test('null profile returns all fields', () {
      final missing = ChatDataCaptureHandler.missingFields(null);
      expect(missing, containsAll([
        CaptureField.age,
        CaptureField.canton,
        CaptureField.salary,
      ]));
    });

    test('complete profile returns empty list', () {
      final provider = CoachProfileProvider();
      provider.updateFromAnswers({
        'q_birth_year': 1977,
        'q_canton': 'VS',
        'q_net_income_period_chf': 9080,
      });
      final missing = ChatDataCaptureHandler.missingFields(provider.profile);
      expect(missing, isEmpty);
    });

    test('profile with only age returns canton + salary', () {
      final provider = CoachProfileProvider();
      provider.updateFromAnswers({
        'q_birth_year': 1977,
        'q_canton': '',
        'q_net_income_period_chf': 0.0,
      });
      final missing = ChatDataCaptureHandler.missingFields(provider.profile);
      expect(missing, contains(CaptureField.canton));
      expect(missing, contains(CaptureField.salary));
      expect(missing, isNot(contains(CaptureField.age)));
    });
  });

  group('CHAT-04: Questions and re-ask messages', () {
    test('each field has a question', () {
      for (final field in CaptureField.values) {
        expect(
          ChatDataCaptureHandler.questionFor(field).isNotEmpty,
          isTrue,
          reason: '$field should have a question',
        );
      }
    });

    test('each field has a re-ask message', () {
      for (final field in CaptureField.values) {
        expect(
          ChatDataCaptureHandler.reaskFor(field).isNotEmpty,
          isTrue,
          reason: '$field should have a re-ask message',
        );
      }
    });
  });
}
