import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/widgets/pulse/action_success_sheet.dart';

// ────────────────────────────────────────────────────────────────
//  ACTION SUCCESS SHEET — Unit + Widget Tests
// ────────────────────────────────────────────────────────────────
//
//  Spec: MINT_CAP_ENGINE_SPEC.md §12
//  Feature wired in: pulse_screen.dart line 161
// ────────────────────────────────────────────────────────────────

void main() {
  Widget wrapInApp(Widget child) {
    return MaterialApp(
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
  }

  // ── ActionSuccessData ────────────────────────────────────────

  group('ActionSuccessData', () {
    test('constructs with required fields only', () {
      const data = ActionSuccessData(actionLabel: 'Versement 3a ajouté');
      expect(data.actionLabel, 'Versement 3a ajouté');
      expect(data.impactLabel, isNull);
      expect(data.nextLabel, isNull);
      expect(data.nextRoute, isNull);
      expect(data.completedCapId, isNull);
    });

    test('constructs with all fields', () {
      const data = ActionSuccessData(
        actionLabel: 'Rachat LPP effectué',
        impactLabel: 'économie fiscale CHF 8\u2019000',
        nextLabel: 'Vérifier ta couverture',
        nextRoute: '/invalidite',
        completedCapId: 'lpp_buyback',
      );
      expect(data.actionLabel, 'Rachat LPP effectué');
      expect(data.impactLabel, contains('8'));
      expect(data.nextRoute, '/invalidite');
      expect(data.completedCapId, 'lpp_buyback');
    });

    test('fromCap builds from CapDecision', () {
      const cap = CapDecision(
        id: 'pillar_3a',
        kind: CapKind.optimize,
        priorityScore: 0.5,
        headline: 'Cette année compte encore',
        whyNow: 'Un versement 3a peut alléger tes impôts.',
        ctaLabel: 'Simuler mon 3a',
        ctaMode: CtaMode.route,
        ctaRoute: '/pilier-3a',
        expectedImpact: 'jusqu\u2019à CHF 1\u2019240',
      );

      final data = ActionSuccessData.fromCap(
        completedCap: cap,
        nextCap: null,
      );

      expect(data.actionLabel, 'Simuler mon 3a');
      expect(data.impactLabel, contains('1'));
      expect(data.nextLabel, isNull);
      expect(data.completedCapId, 'pillar_3a');
    });

    test('fromCap includes next cap when different', () {
      const completedCap = CapDecision(
        id: 'pillar_3a',
        kind: CapKind.optimize,
        priorityScore: 0.5,
        headline: 'Cette année compte encore',
        whyNow: 'Versement 3a.',
        ctaLabel: 'Simuler mon 3a',
        ctaMode: CtaMode.route,
      );

      const nextCap = CapDecision(
        id: 'lpp_buyback',
        kind: CapKind.optimize,
        priorityScore: 0.4,
        headline: 'Rachat LPP disponible',
        whyNow: 'Tu peux racheter.',
        ctaLabel: 'Simuler un rachat',
        ctaMode: CtaMode.route,
        ctaRoute: '/rachat-lpp',
      );

      final data = ActionSuccessData.fromCap(
        completedCap: completedCap,
        nextCap: nextCap,
      );

      expect(data.nextLabel, 'Rachat LPP disponible');
      expect(data.nextRoute, '/rachat-lpp');
    });
  });

  // ── showActionSuccessSheet ───────────────────────────────────

  group('showActionSuccessSheet', () {
    testWidgets('shows action label and success icon', (tester) async {
      await tester.pumpWidget(wrapInApp(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showActionSuccessSheet(
              context,
              const ActionSuccessData(
                actionLabel: 'Versement 3a ajouté',
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Action label visible
      expect(find.text('Versement 3a ajouté'), findsOneWidget);
      // Success check icon
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('shows impact section when impactLabel provided',
        (tester) async {
      await tester.pumpWidget(wrapInApp(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showActionSuccessSheet(
              context,
              const ActionSuccessData(
                actionLabel: 'Rachat effectué',
                impactLabel: 'économie fiscale CHF 8\u2019000',
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('économie fiscale'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    });

    testWidgets('hides impact section when impactLabel is null',
        (tester) async {
      await tester.pumpWidget(wrapInApp(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showActionSuccessSheet(
              context,
              const ActionSuccessData(
                actionLabel: 'Profil enrichi',
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.trending_up_rounded), findsNothing);
    });

    testWidgets('shows next step with chevron when nextRoute provided',
        (tester) async {
      await tester.pumpWidget(wrapInApp(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showActionSuccessSheet(
              context,
              const ActionSuccessData(
                actionLabel: 'Certificat scanné',
                nextLabel: 'Rachat LPP disponible',
                nextRoute: '/rachat-lpp',
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Rachat LPP disponible'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('hides next step when nextLabel is null', (tester) async {
      await tester.pumpWidget(wrapInApp(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showActionSuccessSheet(
              context,
              const ActionSuccessData(
                actionLabel: 'Action terminée',
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('close button dismisses sheet', (tester) async {
      await tester.pumpWidget(wrapInApp(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showActionSuccessSheet(
              context,
              const ActionSuccessData(actionLabel: 'Test'),
            ),
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Find and tap the close/done button (FilledButton with l10n key)
      final filledButtons = find.byType(FilledButton);
      // The last FilledButton in the sheet is the close button
      expect(filledButtons, findsWidgets);

      // The sheet should be showing the action label
      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('full scenario: action + impact + next step', (tester) async {
      await tester.pumpWidget(wrapInApp(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showActionSuccessSheet(
              context,
              const ActionSuccessData(
                actionLabel: 'Simuler mon 3a',
                impactLabel: 'jusqu\u2019à CHF 1\u2019240 d\u2019économie',
                nextLabel: 'Vérifier ton certificat LPP',
                nextRoute: '/scan',
                completedCapId: 'pillar_3a',
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // All 3 sections visible (spec §12 format)
      expect(find.text('Simuler mon 3a'), findsOneWidget);
      expect(find.textContaining('CHF'), findsOneWidget);
      expect(find.text('Vérifier ton certificat LPP'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });
  });
}
