import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/widgets/coach/chat_consent_chip.dart';
import 'package:mint_mobile/services/consent_manager.dart';

// ────────────────────────────────────────────────────────────
//  INLINE CONSENT TESTS — CHAT-03 (Phase 3)
//
//  Verifies:
//  1. ChatConsentChip renders human sentence + accept/decline chips
//  2. Tapping accept calls onAccept callback
//  3. Tapping decline calls onDecline callback
//  4. Each ConsentType has a distinct human sentence
//  5. ConsentManager persists consent via SharedPreferences
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CHAT-03: ChatConsentChip', () {
    testWidgets('renders human sentence and both chips for byokDataSharing',
        (tester) async {
      bool accepted = false;
      bool declined = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatConsentChip(
              consentType: ConsentType.byokDataSharing,
              onAccept: () => accepted = true,
              onDecline: () => declined = true,
            ),
          ),
        ),
      );

      // Human sentence is visible
      expect(
        find.textContaining('personnaliser mes r\u00e9ponses'),
        findsOneWidget,
      );

      // Both chips are visible
      expect(find.text('Oui, c\u2019est bon'), findsOneWidget);
      expect(find.text('Non merci'), findsOneWidget);

      // Neither callback fired yet
      expect(accepted, isFalse);
      expect(declined, isFalse);
    });

    testWidgets('tapping accept calls onAccept', (tester) async {
      bool accepted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatConsentChip(
              consentType: ConsentType.byokDataSharing,
              onAccept: () => accepted = true,
              onDecline: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Oui, c\u2019est bon'));
      expect(accepted, isTrue);
    });

    testWidgets('tapping decline calls onDecline', (tester) async {
      bool declined = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatConsentChip(
              consentType: ConsentType.ragQueries,
              onAccept: () {},
              onDecline: () => declined = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Non merci'));
      expect(declined, isTrue);
    });

    test('each ConsentType has a distinct human sentence', () {
      final sentences = <String>{};
      for (final type in ConsentType.values) {
        final sentence = ChatConsentChip.sentenceFor(type);
        expect(sentence.isNotEmpty, isTrue,
            reason: '$type should have a non-empty sentence');
        expect(sentences.add(sentence), isTrue,
            reason: '$type sentence should be unique');
      }
      // All 7 consent types covered
      expect(sentences.length, equals(ConsentType.values.length));
    });

    test('ConsentManager persists consent via SharedPreferences', () async {
      // Initially not granted
      expect(
        await ConsentManager.isConsentGiven(ConsentType.byokDataSharing),
        isFalse,
      );

      // Grant consent
      await ConsentManager.updateConsent(ConsentType.byokDataSharing, true);
      expect(
        await ConsentManager.isConsentGiven(ConsentType.byokDataSharing),
        isTrue,
      );

      // Revoke
      await ConsentManager.updateConsent(ConsentType.byokDataSharing, false);
      expect(
        await ConsentManager.isConsentGiven(ConsentType.byokDataSharing),
        isFalse,
      );
    });
  });
}
