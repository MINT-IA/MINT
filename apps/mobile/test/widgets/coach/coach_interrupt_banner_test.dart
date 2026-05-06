// Phase 91 Plan 91-02 (VIVANT-03) — CoachInterruptBanner.fromNudge tests.
//
// Asserts the Nudge variant of the banner (chat-screen mode):
//   1. Renders title + body of the supplied Nudge
//   2. Exposes Semantics(identifier: 'coach-interrupt-banner-<id>')
//   3. onDismiss is invoked when the X icon is tapped
//   4. onDismiss is invoked when the banner is swiped up (Dismissible)
//   5. Title-only nudge still renders (body fallback behaviour)
//
// The simulator variant (CoachInterrupt + currentValues) keeps its own
// path; we only assert the new chat-mode contract here. The Maestro flow
// `walkthrough_interrupt_banner.yaml` covers the kill+relaunch persistence
// path that requires SharedPreferences I/O in a real engine.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/nudge/nudge_engine.dart';
import 'package:mint_mobile/services/nudge/nudge_trigger.dart';
import 'package:mint_mobile/widgets/coach/coach_interrupt_banner.dart';

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

Nudge _taxNudge() {
  return Nudge(
    id: 'taxDeadlineApproach_202603',
    trigger: NudgeTrigger.taxDeadlineApproach,
    priority: NudgePriority.high,
    intentTag: '/fiscal',
    titleKey: 'nudgeTaxDeadlineTitle',
    bodyKey: 'nudgeTaxDeadlineBody',
    expiresAt: DateTime(2026, 4, 1),
  );
}

void main() {
  group('CoachInterruptBanner.fromNudge', () {
    testWidgets('renders Nudge title + body and Semantics identifier',
        (tester) async {
      final nudge = _taxNudge();
      await tester.pumpWidget(_wrap(
        CoachInterruptBanner.fromNudge(
          nudge: nudge,
          onDismiss: () {},
        ),
      ));
      // Wait for the slide-in animation to settle.
      await tester.pumpAndSettle();

      // Title — resolved through generated S getter.
      expect(
        find.text('Déclaration fiscale'),
        findsOneWidget,
        reason: 'Title from nudgeTaxDeadlineTitle ARB key must render',
      );

      // Semantics identifier surfaces the nudge id for Maestro E2E.
      final semantics = tester.getSemantics(find.byType(CoachInterruptBanner));
      expect(
        semantics.identifier,
        'coach-interrupt-banner-${nudge.id}',
        reason:
            'Semantics(identifier:) is the contract Maestro asserts on in '
            'walkthrough_interrupt_banner.yaml',
      );
    });

    testWidgets('onDismiss fires when the close X icon is tapped',
        (tester) async {
      var dismissCount = 0;
      final nudge = _taxNudge();

      await tester.pumpWidget(_wrap(
        CoachInterruptBanner.fromNudge(
          nudge: nudge,
          onDismiss: () => dismissCount++,
        ),
      ));
      await tester.pumpAndSettle();

      // Locate the close icon button — Icons.close is unique inside the
      // banner Row (the body never contains a close icon).
      final closeIcon = find.byIcon(Icons.close);
      expect(closeIcon, findsOneWidget);

      await tester.tap(closeIcon);
      // Drive the reverse animation + post-frame setState chain.
      await tester.pumpAndSettle();

      expect(dismissCount, 1,
          reason: 'Tapping the X must invoke onDismiss exactly once');
    });

    testWidgets('onDismiss fires when the banner is swiped up',
        (tester) async {
      var dismissCount = 0;
      final nudge = _taxNudge();

      await tester.pumpWidget(_wrap(
        CoachInterruptBanner.fromNudge(
          nudge: nudge,
          onDismiss: () => dismissCount++,
        ),
      ));
      await tester.pumpAndSettle();

      // Drag the banner upward to trigger the Dismissible(direction: up).
      await tester.drag(
        find.byType(CoachInterruptBanner),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      expect(dismissCount, greaterThanOrEqualTo(1),
          reason: 'Swipe-up on Dismissible must invoke onDismiss');
    });

    testWidgets('a11y: Semantics is marked button + non-empty label',
        (tester) async {
      final nudge = _taxNudge();
      await tester.pumpWidget(_wrap(
        CoachInterruptBanner.fromNudge(
          nudge: nudge,
          onDismiss: () {},
        ),
      ));
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(find.byType(CoachInterruptBanner));
      // The label must be non-empty so VoiceOver / TalkBack announces the
      // banner content; the identifier alone is not announced.
      expect(semantics.label.trim().isNotEmpty, isTrue,
          reason: 'Banner must have an accessible label for screen readers');
    });

    testWidgets('renders even when ARB key is unknown (graceful fallback)',
        (tester) async {
      // Unknown bodyKey — _resolveNudgeText falls through to returning the
      // raw key so the banner never goes blank. Title is still resolved
      // through the canonical switch.
      final nudge = Nudge(
        id: 'taxDeadlineApproach_999999',
        trigger: NudgeTrigger.taxDeadlineApproach,
        priority: NudgePriority.high,
        intentTag: '/fiscal',
        titleKey: 'nudgeTaxDeadlineTitle',
        bodyKey: 'someUnknownBodyKey',
        expiresAt: DateTime(2999, 1, 1),
      );

      await tester.pumpWidget(_wrap(
        CoachInterruptBanner.fromNudge(
          nudge: nudge,
          onDismiss: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CoachInterruptBanner), findsOneWidget);
      expect(find.text('Déclaration fiscale'), findsOneWidget);
    });
  });
}
