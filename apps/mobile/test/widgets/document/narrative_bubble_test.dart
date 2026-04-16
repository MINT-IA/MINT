// Phase 28-04 — NarrativeBubble widget tests (narrative + commitment CTA + reject).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
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

void main() {
  testWidgets('NarrativeBubble renders text and fires commitment callback',
      (tester) async {
    String? capturedAction;
    String? capturedWhen;
    await tester.pumpWidget(_wrap(
      NarrativeBubble(
        narrative: 'Plan généreux. Tu pourrais te poser la question en mai.',
        commitment: const {
          'when': 'mai 2026',
          'where': 'à la maison',
          'ifThen': 'si je reçois mon certificat → j\'ouvre MINT',
          'actionLabel': 'Rappelle-moi en mai',
        },
        onCommitmentAccepted: (when, where, ifThen, actionLabel) {
          capturedWhen = when;
          capturedAction = actionLabel;
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Plan généreux'), findsOneWidget);
    expect(find.text('Rappelle-moi en mai'), findsWidgets);

    await tester.tap(find.byKey(const Key('narrativeCommitmentCta')));
    await tester.pumpAndSettle();
    expect(capturedAction, 'Rappelle-moi en mai');
    expect(capturedWhen, 'mai 2026');
  });

  testWidgets('NarrativeBubble omits CTA when no commitment', (tester) async {
    await tester.pumpWidget(_wrap(
      const NarrativeBubble(
        narrative: 'Voici ce que ce document implique pour toi.',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('narrativeCommitmentCta')), findsNothing);
  });

  testWidgets('RejectBubble renders gentle copy + retry CTA',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(_wrap(
      RejectBubble(onRetry: () => retried = true),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ce document ne semble pas financier'),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('rejectRetryButton')));
    expect(retried, isTrue);
  });

  testWidgets('ThirdPartyChip renders question + Yes/No', (tester) async {
    var yes = false;
    var no = false;
    await tester.pumpWidget(_wrap(
      ThirdPartyChip(
        name: 'Lauren',
        onYes: () => yes = true,
        onNo: () => no = true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Lauren'), findsOneWidget);
    expect(find.text('Oui'), findsOneWidget);
    expect(find.text('Non'), findsOneWidget);

    await tester.tap(find.text('Oui'));
    expect(yes, isTrue);
    await tester.tap(find.text('Non'));
    expect(no, isTrue);
  });

  testWidgets('ThirdPartyChip falls back to generic name', (tester) async {
    await tester.pumpWidget(_wrap(
      ThirdPartyChip(name: null, onYes: () {}, onNo: () {}),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining("quelqu'un d'autre"), findsOneWidget);
  });
}
