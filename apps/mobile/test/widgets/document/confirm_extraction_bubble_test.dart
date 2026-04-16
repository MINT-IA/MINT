// Phase 28-04 — ConfirmExtractionBubble widget tests.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/document_understanding_result.dart';
import 'package:mint_mobile/widgets/document/confirm_extraction_bubble.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  group('ConfirmExtractionBubble', () {
    final fields = const [
      ExtractedField(
        fieldName: 'avoirLppTotal',
        value: 70377,
        confidence: ConfidenceLevel.high,
        sourceText: "CHF 70'377",
      ),
      ExtractedField(
        fieldName: 'salaireAssure',
        value: 91967,
        confidence: ConfidenceLevel.high,
        sourceText: 'CHF 91 967',
      ),
    ];

    testWidgets('renders N field rows + chips with i18n labels',
        (tester) async {
      var corrected = false;
      var confirmed = false;
      await tester.pumpWidget(_wrap(
        ConfirmExtractionBubble(
          fields: fields,
          onConfirm: () => confirmed = true,
          onCorrect: () => corrected = true,
        ),
      ));
      await tester.pumpAndSettle();

      // Both field labels visible.
      expect(find.text('avoirLppTotal'), findsOneWidget);
      expect(find.text('salaireAssure'), findsOneWidget);

      // i18n chips.
      expect(find.text('Tout bon'), findsOneWidget);
      expect(find.text('Je corrige'), findsOneWidget);

      // Header derived from count.
      expect(find.textContaining('2'), findsWidgets);

      // Tap "Je corrige" → onCorrect fires.
      await tester.tap(find.text('Je corrige'));
      expect(corrected, isTrue);
      expect(confirmed, isFalse);

      // Tap "Tout bon" → onConfirm fires.
      await tester.tap(find.text('Tout bon'));
      expect(confirmed, isTrue);
    });

    testWidgets('renders backend summary when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        ConfirmExtractionBubble(
          fields: fields,
          summary: 'CPE Plan Maxi : avoir 70 377, salaire assuré 91 967.',
          onConfirm: () {},
          onCorrect: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('CPE Plan Maxi'), findsOneWidget);
    });
  });
}
