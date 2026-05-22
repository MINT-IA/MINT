/// Phase 01.5 W02-T03 — UsTaxPersonScreen tests.
///
/// 5 behaviors covered:
///   1. renders the FR question
///   2. renders the EN question
///   3. tap Yes → CoachProfileProvider.usTaxPerson = true
///   4. tap No  → CoachProfileProvider.usTaxPerson = false
///   5. info-icon tooltip / dialog reveals FATCA explanation copy
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/us_tax_person_screen.dart';
import 'package:provider/provider.dart';

Widget _wrap({
  required Widget child,
  Locale locale = const Locale('fr'),
  CoachProfileProvider? provider,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider ?? CoachProfileProvider(),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('UsTaxPersonScreen', () {
    testWidgets('renders the question in French', (tester) async {
      var answered = false;
      await tester.pumpWidget(
        _wrap(
          child: UsTaxPersonScreen(
            onAnswered: (_) => answered = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Es-tu citoyen ou résident fiscal aux États-Unis ?'),
        findsOneWidget,
      );
      expect(answered, isFalse);
    });

    testWidgets('renders the question in English', (tester) async {
      await tester.pumpWidget(
        _wrap(
          locale: const Locale('en'),
          child: UsTaxPersonScreen(onAnswered: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Are you a US citizen or US tax resident?'),
        findsOneWidget,
      );
    });

    testWidgets('tap Yes writes usTaxPerson=true to provider + invokes onAnswered(true)',
        (tester) async {
      final provider = CoachProfileProvider();
      bool? receivedAnswer;
      await tester.pumpWidget(
        _wrap(
          provider: provider,
          child: UsTaxPersonScreen(
            onAnswered: (a) => receivedAnswer = a,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('us-tax-person-yes')));
      // Let the async mergeAnswers complete.
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(receivedAnswer, isTrue);
      expect(provider.profile?.usTaxPerson, isTrue);
    });

    testWidgets('tap No writes usTaxPerson=false to provider + invokes onAnswered(false)',
        (tester) async {
      final provider = CoachProfileProvider();
      bool? receivedAnswer;
      await tester.pumpWidget(
        _wrap(
          provider: provider,
          child: UsTaxPersonScreen(
            onAnswered: (a) => receivedAnswer = a,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('us-tax-person-no')));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(receivedAnswer, isFalse);
      expect(provider.profile?.usTaxPerson, isFalse);
    });

    testWidgets('info icon reveals FATCA tooltip dialog with explanation',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: UsTaxPersonScreen(onAnswered: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the info button to surface the FATCA tooltip.
      await tester.tap(find.byKey(const ValueKey('us-tax-person-info')));
      await tester.pumpAndSettle();

      // The tooltip dialog mentions FATCA (a fixed acronym, present in
      // every locale's copy block).
      expect(
        find.textContaining('FATCA'),
        findsOneWidget,
      );
    });
  });
}
