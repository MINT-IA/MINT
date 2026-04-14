// Phase 28-04 — AskQuestionBubble widget tests.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/document_understanding_result.dart';
import 'package:mint_mobile/widgets/document/ask_question_bubble.dart';

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
  group('AskQuestionBubble', () {
    testWidgets(
        'renders confirmed field chips + question inputs and submits answers',
        (tester) async {
      Map<int, String>? captured;
      await tester.pumpWidget(_wrap(
        AskQuestionBubble(
          confirmedFields: const [
            ExtractedField(
              fieldName: 'avoirLppTotal',
              value: 70377,
              confidence: ConfidenceLevel.high,
              sourceText: '',
            ),
          ],
          questions: const [
            'Quel est ton salaire annuel ?',
            'Quel est ton avoir 3a ?',
          ],
          onAnswer: (m) => captured = m,
        ),
      ));
      await tester.pumpAndSettle();

      // Header + confirmed chip + questions visible.
      expect(find.textContaining("J'ai presque tout"), findsOneWidget);
      expect(find.textContaining('avoirLppTotal'), findsOneWidget);
      expect(find.text('Quel est ton salaire annuel ?'), findsOneWidget);
      expect(find.text('Quel est ton avoir 3a ?'), findsOneWidget);

      // Type into the first input only.
      await tester.enterText(find.byKey(const Key('askQuestionInput_0')),
          '120000');
      await tester.tap(find.byKey(const Key('askQuestionSubmit')));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured![0], '120000');
      expect(captured!.containsKey(1), isFalse); // empty input skipped
    });
  });
}
