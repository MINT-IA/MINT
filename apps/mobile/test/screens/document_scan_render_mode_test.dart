// Phase 28-04 — render_mode integration test for DocumentResultView.
//
// Drives DocumentResultView with synthetic Stream<DocumentEvent> sequences
// and asserts the correct bubble is shown for each render_mode, that the
// third-party chip surfaces when expected, and that needs_full_review
// auto-opens the sheet.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/document_event.dart';
import 'package:mint_mobile/widgets/document/ask_question_bubble.dart';
import 'package:mint_mobile/widgets/document/confirm_extraction_bubble.dart';
import 'package:mint_mobile/widgets/document/document_result_view.dart';
import 'package:mint_mobile/widgets/document/narrative_bubble.dart';
import 'package:mint_mobile/widgets/document/reject_bubble.dart';
import 'package:mint_mobile/widgets/document/third_party_chip.dart';

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

Stream<DocumentEvent> _streamOf(List<DocumentEvent> events) {
  final c = StreamController<DocumentEvent>();
  () async {
    for (final e in events) {
      c.add(e);
      await Future<void>.delayed(Duration.zero);
    }
    await c.close();
  }();
  return c.stream;
}

void main() {
  testWidgets('confirm + low-stakes done → ConfirmExtractionBubble shown, no sheet',
      (tester) async {
    await tester.pumpWidget(_wrap(DocumentResultView(
      autoOpenSheet: true,
      stream: _streamOf([
        const StageEvent(stage: 'received'),
        const StageEvent(stage: 'classify_confirmed', payload: {
          'document_class': 'lpp_certificate',
          'summary': 'CPE Plan Maxi',
        }),
        const FieldEvent(
          name: 'avoirLppTotal',
          value: 70377,
          confidence: 'high',
          sourceText: '',
        ),
        const DoneEvent(
          renderMode: 'confirm',
          overallConfidence: 0.92,
          extractionStatus: 'success',
        ),
      ]),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmExtractionBubble), findsOneWidget);
    expect(find.byKey(const Key('extractionReviewSheet')), findsNothing);
  });

  testWidgets(
      'confirm + high-stakes low-conf field → sheet auto-opens',
      (tester) async {
    await tester.pumpWidget(_wrap(DocumentResultView(
      stream: _streamOf([
        const FieldEvent(
          name: 'tauxConversion',
          value: 6.8,
          confidence: 'medium',
          sourceText: '',
        ),
        const DoneEvent(
          renderMode: 'confirm',
          overallConfidence: 0.95,
        ),
      ]),
    )));
    // Pump until the post-frame callback fires the sheet.
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('extractionReviewSheet')), findsOneWidget);
  });

  testWidgets('ask render_mode → AskQuestionBubble shown', (tester) async {
    await tester.pumpWidget(_wrap(DocumentResultView(
      stream: _streamOf([
        const FieldEvent(
          name: 'avoirLppTotal',
          value: 70377,
          confidence: 'high',
          sourceText: '',
        ),
        const DoneEvent(
          renderMode: 'ask',
          overallConfidence: 0.85,
          questionsForUser: ['Quel est ton salaire annuel ?'],
        ),
      ]),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(AskQuestionBubble), findsOneWidget);
  });

  testWidgets('narrative render_mode + commitment → NarrativeBubble with CTA',
      (tester) async {
    await tester.pumpWidget(_wrap(DocumentResultView(
      autoOpenSheet: false,
      onCommitmentAccepted: (_, __, ___, ____) {},
      stream: _streamOf([
        const NarrativeEvent(
          text: 'Plan généreux. Tu pourrais te poser la question en mai.',
          commitment: {
            'when': 'mai 2026',
            'where': 'à la maison',
            'ifThen': 'si je reçois mon certif → j\'ouvre MINT',
            'actionLabel': 'Rappelle-moi en mai',
          },
        ),
        const DoneEvent(
          renderMode: 'narrative',
          overallConfidence: 0.5,
        ),
      ]),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(NarrativeBubble), findsOneWidget);
    expect(find.byKey(const Key('narrativeCommitmentCta')), findsOneWidget);
    // No sheet because not high-stakes (no extracted fields).
    expect(find.byKey(const Key('extractionReviewSheet')), findsNothing);
  });

  testWidgets('reject render_mode → RejectBubble shown, no sheet',
      (tester) async {
    await tester.pumpWidget(_wrap(DocumentResultView(
      autoOpenSheet: false,
      stream: _streamOf([
        const DoneEvent(
          renderMode: 'reject',
          overallConfidence: 0.0,
          extractionStatus: 'rejected_local',
        ),
      ]),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(RejectBubble), findsOneWidget);
    expect(find.byKey(const Key('extractionReviewSheet')), findsNothing);
  });

  testWidgets('thirdPartyDetected=true + name → ThirdPartyChip rendered above bubble',
      (tester) async {
    await tester.pumpWidget(_wrap(DocumentResultView(
      autoOpenSheet: false,
      stream: _streamOf([
        const FieldEvent(
          name: 'avoirLppTotal',
          value: 19620,
          confidence: 'high',
          sourceText: '',
        ),
        const DoneEvent(
          renderMode: 'confirm',
          overallConfidence: 0.95,
          thirdPartyDetected: true,
          thirdPartyName: 'Lauren',
        ),
      ]),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(ThirdPartyChip), findsOneWidget);
    expect(find.byType(ConfirmExtractionBubble), findsOneWidget);
    expect(find.textContaining('Lauren'), findsWidgets);
  });
}
