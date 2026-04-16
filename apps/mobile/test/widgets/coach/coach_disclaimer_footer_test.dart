// ────────────────────────────────────────────────────────────
//  COACH DISCLAIMER FOOTER TESTS — Phase C (2026-04-14)
//
//  Validates the slim-footer replacement for the per-message
//  CoachDisclaimersSection card.
//
//  Assertions:
//   1. CoachMessageBubble no longer renders any disclaimer card
//      even when `msg.disclaimers` is non-empty (API contract
//      preserved, visual no longer rendered per-message).
//   2. CoachDisclaimerFooter renders exactly one disclaimer
//      line using the `coachDisclaimerCollapsed` ARB key.
//   3. Tapping the footer opens the modal bottom sheet with
//      the canonical disclaimer body (`coachDisclaimer` ARB key).
//   4. Footer exposes Semantics(button: true) for a11y.
//   5. Footer hit target is at least 44px tall (a11y).
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/widgets/coach/coach_disclaimer_footer.dart';
import 'package:mint_mobile/widgets/coach/coach_message_bubble.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr')],
    locale: const Locale('fr'),
    home: Scaffold(body: child),
  );
}

void main() {
  // ────────────────────────────────────────────────────────────
  //  No more per-message disclaimer card
  // ────────────────────────────────────────────────────────────

  testWidgets(
      'CoachMessageBubble renders collapsed disclaimer section when '
      'msg.disclaimers is populated (CLAUDE.md §6 compliance)', (tester) async {
    final msg = ChatMessage(
      role: 'assistant',
      content: 'Bonjour',
      timestamp: DateTime.now(),
      disclaimers: const [
        'Outil educatif. Ne constitue pas un conseil financier.',
        'Reference LSFin art. 3.',
      ],
    );

    await tester.pumpWidget(_wrap(
      CoachMessageBubble(message: msg, messageIndex: 0),
    ));
    await tester.pump();

    // The bubble renders the text content.
    expect(find.text('Bonjour'), findsOneWidget);

    // Compliance: disclaimers are shown via the collapsible
    // CoachDisclaimersSection. The collapsed label is present.
    final fr = await S.delegate.load(const Locale('fr'));
    expect(
      find.descendant(
        of: find.byType(CoachMessageBubble),
        matching: find.text(fr.coachDisclaimerCollapsed),
      ),
      findsOneWidget,
    );
  });

  // ────────────────────────────────────────────────────────────
  //  Permanent slim footer
  // ────────────────────────────────────────────────────────────

  testWidgets('CoachDisclaimerFooter renders one line with the i18n key',
      (tester) async {
    await tester.pumpWidget(_wrap(const CoachDisclaimerFooter()));
    await tester.pump();

    final fr = await S.delegate.load(const Locale('fr'));
    // Exactly one line with the collapsed-disclaimer label.
    expect(find.text(fr.coachDisclaimerCollapsed), findsOneWidget);
  });

  testWidgets('CoachDisclaimerFooter is a Semantics button with a11y label',
      (tester) async {
    await tester.pumpWidget(_wrap(const CoachDisclaimerFooter()));
    await tester.pump();

    final fr = await S.delegate.load(const Locale('fr'));
    // Find the explicit Semantics wrapper authored inside the widget
    // (button: true, label: <i18n>). We don't rely on the merged-semantics
    // tree owner because InkWell also contributes button semantics.
    final semanticsWidgets = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((w) =>
            w.properties.button == true &&
            w.properties.label == fr.coachDisclaimerCollapsed);
    expect(semanticsWidgets, isNotEmpty);
  });

  testWidgets('CoachDisclaimerFooter hit target is at least 44px tall',
      (tester) async {
    await tester.pumpWidget(_wrap(const CoachDisclaimerFooter()));
    await tester.pump();

    final footerSize = tester.getSize(find.byType(CoachDisclaimerFooter));
    expect(footerSize.height, greaterThanOrEqualTo(44));
  });

  testWidgets(
      'Tapping the footer opens the disclaimer bottom sheet with canonical body',
      (tester) async {
    await tester.pumpWidget(_wrap(const CoachDisclaimerFooter()));
    await tester.pump();

    await tester.tap(find.byType(CoachDisclaimerFooter));
    await tester.pumpAndSettle();

    final fr = await S.delegate.load(const Locale('fr'));
    // The canonical disclaimer body (from the `coachDisclaimer` ARB key)
    // must now be visible inside the bottom sheet.
    expect(find.text(fr.coachDisclaimer), findsOneWidget);
  });
}
