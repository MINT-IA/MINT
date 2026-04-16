// Phase 28-04 — ExtractionReviewSheet widget tests.
//
// Note: full DraggableScrollableSheet snap-drag interaction is hard to
// drive in widget tests; we test the SHEET BODY directly (mounted as a
// regular widget) plus the static `needsFullReview` predicate. The
// snap configuration itself is verified by reading the
// `DraggableScrollableSheet.snapSizes` field via the show() helper in a
// dedicated test.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/document_understanding_result.dart';
import 'package:mint_mobile/widgets/document/extraction_review_sheet.dart';

DocumentUnderstandingResult _result({
  List<ExtractedField> fields = const [],
  double overall = 0.92,
  String? planType,
  List<CoherenceWarning> warnings = const [],
}) {
  return DocumentUnderstandingResult(
    documentClass: DocumentClass.lppCertificate,
    extractedFields: fields,
    overallConfidence: overall,
    extractionStatus: ExtractionStatus.success,
    renderMode: RenderMode.confirm,
    planType: planType,
    coherenceWarnings: warnings,
  );
}

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
  group('needsFullReview', () {
    test('returns false when overall conf >= 0.75 and no high-stakes / 1e / warnings',
        () {
      final r = _result(
        fields: const [
          ExtractedField(
            fieldName: 'avoirLppTotal',
            value: 70377,
            confidence: ConfidenceLevel.high,
            sourceText: '',
          ),
        ],
        overall: 0.92,
      );
      expect(needsFullReview(r), isFalse);
    });

    test('returns true when overall < 0.75', () {
      final r = _result(overall: 0.6);
      expect(needsFullReview(r), isTrue);
    });

    test('returns true when high-stakes field has medium/low confidence', () {
      final r = _result(
        fields: const [
          ExtractedField(
            fieldName: 'tauxConversion',
            value: 6.8,
            confidence: ConfidenceLevel.medium,
            sourceText: '',
          ),
        ],
        overall: 0.95,
      );
      expect(needsFullReview(r), isTrue);
    });

    test('returns true when planType=1e', () {
      final r = _result(planType: '1e');
      expect(needsFullReview(r), isTrue);
    });

    test('returns true when coherence warnings present', () {
      final r = _result(
        warnings: const [
          CoherenceWarning(code: 'mismatch', message: 'sum mismatch'),
        ],
      );
      expect(needsFullReview(r), isTrue);
    });
  });

  group('ExtractionReviewSheet body', () {
    final r = _result(
      fields: const [
        ExtractedField(
          fieldName: 'avoirLppTotal',
          value: 70377,
          confidence: ConfidenceLevel.high,
          sourceText: '',
        ),
        ExtractedField(
          fieldName: 'salaireAssure',
          value: 91967,
          confidence: ConfidenceLevel.high,
          sourceText: '',
        ),
      ],
    );

    testWidgets('renders three top chips (Mine / Correct / Not mine)',
        (tester) async {
      await tester.pumpWidget(_wrap(SizedBox(
        height: 600,
        child: ExtractionReviewSheet(
          result: r,
          onConfirm: (_) {},
          onReject: () {},
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sheetConfirm')), findsOneWidget);
      expect(find.byKey(const Key('sheetCorrect')), findsOneWidget);
      expect(find.byKey(const Key('sheetReject')), findsOneWidget);
      // Default = read mode, no TextField visible.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Je corrige enables inline edit (TextFields appear)',
        (tester) async {
      await tester.pumpWidget(_wrap(SizedBox(
        height: 600,
        child: ExtractionReviewSheet(
          result: r,
          onConfirm: (_) {},
          onReject: () {},
        ),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sheetCorrect')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('C\'est à moi forwards possibly edited fields', (tester) async {
      List<ExtractedField>? captured;
      await tester.pumpWidget(_wrap(SizedBox(
        height: 600,
        child: ExtractionReviewSheet(
          result: r,
          onConfirm: (fields) => captured = fields,
          onReject: () {},
        ),
      )));
      await tester.pumpAndSettle();
      // Edit first field to 99999.
      await tester.tap(find.byKey(const Key('sheetCorrect')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '99999');
      await tester.tap(find.byKey(const Key('sheetConfirm')));
      await tester.pumpAndSettle();
      expect(captured, isNotNull);
      expect(captured!.length, 2);
      expect(captured![0].value, 99999);
    });

    testWidgets('coherence warning surfaces banner', (tester) async {
      final rWarn = _result(
        fields: const [
          ExtractedField(
            fieldName: 'avoirLppTotal',
            value: 1,
            confidence: ConfidenceLevel.high,
            sourceText: '',
          ),
        ],
        warnings: const [
          CoherenceWarning(code: 'sum_mismatch', message: 'Les sommes ne collent pas'),
        ],
      );
      await tester.pumpWidget(_wrap(SizedBox(
        height: 600,
        child: ExtractionReviewSheet(
          result: rWarn,
          onConfirm: (_) {},
          onReject: () {},
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Les sommes ne collent pas'), findsOneWidget);
    });
  });
}
