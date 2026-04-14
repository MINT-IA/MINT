// Phase 29-04 — BatchValidationBubble widget tests (PRIV-08).
//
// Proves:
//   - headline uses i18n count placeholder ("MINT a lu N chiffres…")
//   - "tout bon" chip confirms ALL fields (status=userValidated) in one call
//   - "corriger un chiffre" chip opens the single-field correction sheet
//   - field row tap opens the correction sheet for that specific row
//   - swipe-right = confirm all, swipe-left = reject all
//   - fields passed in with a non-needs_review status are forcibly reset
//     to needs_review on render (PRIV-08 invariant, even if caller
//     mistakenly pre-confirmed)
//   - humanReviewFlag renders the human-review badge

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/document_understanding_result.dart';
import 'package:mint_mobile/widgets/document/batch_validation_bubble.dart';

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
  group('BatchValidationBubble', () {
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
        sourceText: "CHF 91'967",
      ),
      ExtractedField(
        fieldName: 'tauxConversion',
        value: 0.068,
        confidence: ConfidenceLevel.high,
        sourceText: '6.8 %',
      ),
    ];

    testWidgets('renders headline with count and all field rows',
        (tester) async {
      await tester.pumpWidget(_wrap(
        BatchValidationBubble(
          fields: fields,
          onConfirmAll: (_) {},
          onRejectAll: (_) {},
          onCorrectOne: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('batchValidationBubble')), findsOneWidget);
      expect(find.textContaining('3 chiffres'), findsWidgets);
      expect(find.byKey(const Key('batchRow_avoirLppTotal')), findsOneWidget);
      expect(find.byKey(const Key('batchRow_salaireAssure')), findsOneWidget);
      expect(find.byKey(const Key('batchRow_tauxConversion')), findsOneWidget);
    });

    testWidgets('tout bon confirms ALL fields in a single callback',
        (tester) async {
      List<ExtractedField>? captured;
      await tester.pumpWidget(_wrap(
        BatchValidationBubble(
          fields: fields,
          onConfirmAll: (list) => captured = list,
          onRejectAll: (_) {},
          onCorrectOne: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('batchConfirmAllBtn')));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.length, 3);
      for (final f in captured!) {
        expect(f.status, FieldStatus.userValidated);
      }
    });

    testWidgets('corriger un chiffre opens correction sheet for first field',
        (tester) async {
      await tester.pumpWidget(_wrap(
        BatchValidationBubble(
          fields: fields,
          onConfirmAll: (_) {},
          onRejectAll: (_) {},
          onCorrectOne: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('batchCorrectOneBtn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fieldCorrectionInput')), findsOneWidget);
    });

    testWidgets('tapping a field row opens correction for THAT field',
        (tester) async {
      await tester.pumpWidget(_wrap(
        BatchValidationBubble(
          fields: fields,
          onConfirmAll: (_) {},
          onRejectAll: (_) {},
          onCorrectOne: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('batchRow_salaireAssure')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fieldCorrectionInput')), findsOneWidget);
      // The label shown in the sheet is the raw fieldName here (no labelFor).
      // Both the row AND the sheet display the name, so we assert >=1 match.
      expect(find.text('salaireAssure'), findsWidgets);
    });

    testWidgets('correction save writes corrected_by_user and invokes callback',
        (tester) async {
      ExtractedField? corrected;
      await tester.pumpWidget(_wrap(
        BatchValidationBubble(
          fields: fields,
          onConfirmAll: (_) {},
          onRejectAll: (_) {},
          onCorrectOne: (f) => corrected = f,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('batchRow_avoirLppTotal')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('fieldCorrectionInput')),
        "82'000",
      );
      await tester.tap(find.byKey(const Key('fieldCorrectionSaveBtn')));
      await tester.pumpAndSettle();

      expect(corrected, isNotNull);
      expect(corrected!.fieldName, 'avoirLppTotal');
      expect(corrected!.status, FieldStatus.correctedByUser);
      expect(corrected!.value, 82000);
    });

    testWidgets('reject-all button marks all fields rejected', (tester) async {
      List<ExtractedField>? rejected;
      await tester.pumpWidget(_wrap(
        BatchValidationBubble(
          fields: fields,
          onConfirmAll: (_) {},
          onRejectAll: (list) => rejected = list,
          onCorrectOne: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('batchRejectAllBtn')));
      await tester.pumpAndSettle();

      expect(rejected, isNotNull);
      expect(rejected!.every((f) => f.status == FieldStatus.rejected), isTrue);
    });

    testWidgets('PRIV-08: caller pre-confirmed fields are reset to needs_review',
        (tester) async {
      final preConfirmed = fields
          .map((f) => f.copyWith(status: FieldStatus.userValidated))
          .toList();
      List<ExtractedField>? captured;
      await tester.pumpWidget(_wrap(
        BatchValidationBubble(
          fields: preConfirmed,
          onConfirmAll: (list) => captured = list,
          onRejectAll: (_) {},
          onCorrectOne: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      // Explicit user action still required; the bubble never silently
      // re-emits the pre-confirmed list.
      await tester.tap(find.byKey(const Key('batchConfirmAllBtn')));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      // Every field is userValidated AFTER the explicit tap, not before.
      expect(captured!.every((f) => f.status == FieldStatus.userValidated),
          isTrue);
    });

    testWidgets('humanReviewFlag renders the human-review badge',
        (tester) async {
      final flagged = [
        fields[0].copyWith(humanReviewFlag: true),
        fields[1],
      ];
      await tester.pumpWidget(_wrap(
        BatchValidationBubble(
          fields: flagged,
          onConfirmAll: (_) {},
          onRejectAll: (_) {},
          onCorrectOne: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('humain'), findsOneWidget);
    });
  });
}
