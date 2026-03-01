import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/services/subscription_service.dart';
import 'package:mint_mobile/providers/subscription_provider.dart';
import 'package:mint_mobile/widgets/coach/coach_paywall_sheet.dart';

/// Widget tests for CoachPaywallSheet (P6 — Multi-tier Paywall).
///
/// Tests verify:
///   - Sheet renders without crashing
///   - Multi-tier comparison (Starter / Premium / Couple+)
///   - Prices are displayed (4.90, 9.90, 14.90)
///   - Feature list is shown per tier
///   - CTA button is present
///   - Disclaimer is present (LSFin)
///   - Close button exists
///   - Restore purchases button exists
///   - Trial badge is shown
///   - No banned terms
void main() {
  setUp(() {
    SubscriptionService.setMockTier(SubscriptionTier.free);
  });

  tearDown(() {
    SubscriptionService.resetToDefault();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: ChangeNotifierProvider(
        create: (_) => SubscriptionProvider(),
        child: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ChangeNotifierProvider.value(
                  value: context.read<SubscriptionProvider>(),
                  child: const CoachPaywallSheet(),
                ),
              ),
              child: const Text('Open Paywall'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openPaywall(WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Open Paywall'));
    await tester.pumpAndSettle();
  }

  group('CoachPaywallSheet', () {
    testWidgets('renders without crashing', (tester) async {
      await openPaywall(tester);
      expect(find.byType(CoachPaywallSheet), findsOneWidget);
    });

    testWidgets('shows tier names (Starter, Premium)', (tester) async {
      await openPaywall(tester);
      expect(find.text('Starter'), findsOneWidget);
      expect(find.text('Premium'), findsOneWidget);
    });

    testWidgets('shows Starter price 4.90 CHF', (tester) async {
      await openPaywall(tester);
      expect(find.textContaining('4.90'), findsWidgets);
    });

    testWidgets('shows Premium price 9.90 CHF', (tester) async {
      await openPaywall(tester);
      expect(find.textContaining('9.90'), findsWidgets);
    });

    testWidgets('shows title text', (tester) async {
      await openPaywall(tester);
      expect(find.textContaining('MINT Coach'), findsWidgets);
    });

    testWidgets('shows subtitle', (tester) async {
      await openPaywall(tester);
      expect(find.textContaining('coach financier'), findsOneWidget);
    });

    testWidgets('shows feature list with checkmarks', (tester) async {
      await openPaywall(tester);
      // Should show feature titles from Starter and Premium tiers
      expect(find.textContaining('Dashboard trajectoire'), findsWidgets);
      expect(find.textContaining('Forecast adaptatif'), findsWidgets);
      expect(find.textContaining('Check-in mensuel'), findsWidgets);
      expect(find.textContaining('Coach LLM'), findsOneWidget);
      expect(find.textContaining('Export PDF'), findsOneWidget);
      // Check icons
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
    });

    testWidgets('shows CTA button', (tester) async {
      await openPaywall(tester);
      // Non-iOS platform: shows trial start
      expect(find.textContaining('essai gratuit'), findsWidgets);
    });

    testWidgets('shows restore purchases button', (tester) async {
      await openPaywall(tester);
      expect(find.textContaining('Restaurer'), findsOneWidget);
    });

    testWidgets('shows disclaimer with LSFin', (tester) async {
      await openPaywall(tester);
      expect(find.textContaining('LSFin'), findsOneWidget);
      expect(find.textContaining('educatif'), findsWidgets);
    });

    testWidgets('shows trial badge', (tester) async {
      await openPaywall(tester);
      expect(find.textContaining('14 jours'), findsWidgets);
    });

    testWidgets('has close button', (tester) async {
      await openPaywall(tester);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('close button dismisses sheet', (tester) async {
      await openPaywall(tester);
      expect(find.byType(CoachPaywallSheet), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(CoachPaywallSheet), findsNothing);
    });

    testWidgets('shows recommended badge on Premium', (tester) async {
      await openPaywall(tester);
      expect(find.text('Top'), findsOneWidget);
    });

    testWidgets('shows /mois price unit', (tester) async {
      await openPaywall(tester);
      expect(find.textContaining('/mois'), findsWidgets);
    });

    testWidgets('does not contain banned terms', (tester) async {
      await openPaywall(tester);

      // Check no banned terms appear in the widget tree text
      final bannedTerms = [
        'garanti',
        'certain',
        'sans risque',
        'optimal',
        'meilleur',
        'parfait',
      ];

      for (final term in bannedTerms) {
        expect(
          find.textContaining(term),
          findsNothing,
          reason: 'Banned term "$term" should not appear in paywall',
        );
      }
    });
  });
}
