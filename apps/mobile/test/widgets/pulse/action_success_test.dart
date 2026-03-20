import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/widgets/pulse/action_success_sheet.dart';

void main() {
  Widget _wrap(Widget child) {
    return MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: Scaffold(body: child),
      ),
    );
  }

  group('ActionSuccessData', () {
    test('fromCap builds correct data from CapDecision', () {
      final cap = CapDecision(
        id: 'pillar_3a',
        kind: CapKind.optimize,
        priorityScore: 0.8,
        headline: 'Cette année compte encore',
        whyNow: 'Un versement 3a peut encore alléger tes impôts.',
        ctaLabel: 'Simuler mon 3a',
        ctaMode: CtaMode.route,
        ctaRoute: '/pilier-3a',
        expectedImpact: 'jusqu\'à CHF 1\'240',
      );

      final next = CapDecision(
        id: 'lpp_buyback',
        kind: CapKind.optimize,
        priorityScore: 0.6,
        headline: 'Rachat LPP disponible',
        whyNow: 'Tu peux racheter.',
        ctaLabel: 'Simuler un rachat',
        ctaMode: CtaMode.route,
        ctaRoute: '/rachat-lpp',
      );

      final data = ActionSuccessData.fromCap(
        completedCap: cap,
        nextCap: next,
      );

      expect(data.actionLabel, 'Simuler mon 3a');
      expect(data.impactLabel, 'jusqu\'à CHF 1\'240');
      expect(data.nextLabel, 'Rachat LPP disponible');
      expect(data.nextRoute, '/rachat-lpp');
      expect(data.completedCapId, 'pillar_3a');
    });

    test('fromCap handles null nextCap', () {
      final cap = CapDecision(
        id: 'debt_correct',
        kind: CapKind.correct,
        priorityScore: 0.9,
        headline: 'Ta dette pèse',
        whyNow: 'Rembourser.',
        ctaLabel: 'Voir mon plan',
        ctaMode: CtaMode.route,
        ctaRoute: '/debt/repayment',
      );

      final data = ActionSuccessData.fromCap(
        completedCap: cap,
        nextCap: null,
      );

      expect(data.actionLabel, 'Voir mon plan');
      expect(data.nextLabel, isNull);
      expect(data.nextRoute, isNull);
    });
  });

  group('ActionSuccess sheet', () {
    testWidgets('renders action label', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showActionSuccessSheet(
              context,
              const ActionSuccessData(
                actionLabel: 'Versement 3a ajouté',
                impactLabel: 'économie CHF 1\'240',
                nextLabel: 'Vérifier ton LPP',
              ),
            ),
            child: const Text('Show'),
          ),
        ),
      ));

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Versement 3a ajouté'), findsOneWidget);
    });

    testWidgets('renders impact label', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showActionSuccessSheet(
              context,
              const ActionSuccessData(
                actionLabel: 'Action',
                impactLabel: 'CHF 500 économisés',
              ),
            ),
            child: const Text('Show'),
          ),
        ),
      ));

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('CHF 500 économisés'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    });

    testWidgets('renders next step when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showActionSuccessSheet(
              context,
              const ActionSuccessData(
                actionLabel: 'Action',
                nextLabel: 'Prochaine étape',
                nextRoute: '/next',
              ),
            ),
            child: const Text('Show'),
          ),
        ),
      ));

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Prochaine étape'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('hides impact when null', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showActionSuccessSheet(
              context,
              const ActionSuccessData(actionLabel: 'Done'),
            ),
            child: const Text('Show'),
          ),
        ),
      ));

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.trending_up_rounded), findsNothing);
    });

    testWidgets('uses l10n for button and next label', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showActionSuccessSheet(
              context,
              const ActionSuccessData(
                actionLabel: 'Test',
                nextLabel: 'Next',
              ),
            ),
            child: const Text('Show'),
          ),
        ),
      ));

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // "Compris" button (FR l10n for actionSuccessDone)
      expect(find.text('Compris'), findsOneWidget);
      // "La suite" label (FR l10n for actionSuccessNext)
      expect(find.text('La suite'), findsOneWidget);
    });
  });
}
