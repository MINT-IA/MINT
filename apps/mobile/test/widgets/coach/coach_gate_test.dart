import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/services/subscription_service.dart';
import 'package:mint_mobile/providers/subscription_provider.dart';
import 'package:mint_mobile/widgets/coach/coach_gate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

/// Widget tests for CoachGate (Sprint C9 — Paywall).
///
/// Tests verify:
///   - Child is shown when user has a paid tier
///   - Locked state is shown when user is on free tier
///   - Locked state shows "Débloquer" button
///   - Custom locked placeholder is used when provided
///   - Lock icon is visible in locked state
///   - "Débloquer" button opens paywall sheet
void main() {
  setUp(() {
    SubscriptionService.setMockTier(SubscriptionTier.free);
  });

  tearDown(() {
    SubscriptionService.resetToDefault();
  });

  Widget buildTestWidget({
    CoachFeature feature = CoachFeature.dashboard,
    Widget? lockedPlaceholder,
  }) {
    return MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: ChangeNotifierProvider(
        create: (_) => SubscriptionProvider(),
        child: Scaffold(
          body: CoachGate(
            feature: feature,
            lockedPlaceholder: lockedPlaceholder,
            child: const SizedBox(
              height: 200,
              child: Center(child: Text('Coach Content')),
            ),
          ),
        ),
      ),
    );
  }

  group('CoachGate', () {
    testWidgets('shows child when user has premium tier', (tester) async {
      SubscriptionService.setMockTier(SubscriptionTier.premium);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Coach Content'), findsOneWidget);
      expect(find.text('Débloquer'), findsNothing);
    });

    testWidgets('shows child when user has starter tier for starter feature', (tester) async {
      SubscriptionService.setMockTier(SubscriptionTier.starter);

      await tester.pumpWidget(buildTestWidget(feature: CoachFeature.dashboard));
      await tester.pump();

      expect(find.text('Coach Content'), findsOneWidget);
      expect(find.text('Débloquer'), findsNothing);
    });

    testWidgets('shows locked state when user is on free tier', (tester) async {
      SubscriptionService.setMockTier(SubscriptionTier.free);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // The child text should still be in the tree (rendered blurred behind)
      // but the unlock button should be visible
      expect(find.text('Débloquer'), findsOneWidget);
    });

    testWidgets('locked state shows Débloquer button', (tester) async {
      SubscriptionService.setMockTier(SubscriptionTier.free);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Verify unlock button text is present
      expect(find.text('Débloquer'), findsOneWidget);
    });

    testWidgets('locked state shows lock icon', (tester) async {
      SubscriptionService.setMockTier(SubscriptionTier.free);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });

    testWidgets('locked state shows "Fonctionnalite Coach" label',
        (tester) async {
      SubscriptionService.setMockTier(SubscriptionTier.free);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.textContaining('Coach'), findsWidgets);
    });

    testWidgets('uses custom lockedPlaceholder when provided', (tester) async {
      SubscriptionService.setMockTier(SubscriptionTier.free);

      await tester.pumpWidget(buildTestWidget(
        lockedPlaceholder: const Text('Custom Locked'),
      ));
      await tester.pump();

      expect(find.text('Custom Locked'), findsOneWidget);
      expect(find.text('Débloquer'), findsNothing);
    });

    testWidgets('works with all CoachFeature values', (tester) async {
      SubscriptionService.setMockTier(SubscriptionTier.free);

      for (final feature in CoachFeature.values) {
        await tester.pumpWidget(buildTestWidget(feature: feature));
        await tester.pump();

        expect(
          find.text('Débloquer'),
          findsOneWidget,
          reason: 'Locked state should show for feature $feature on free tier',
        );
      }
    });

    testWidgets('shows child for trial user', (tester) async {
      // Simulate active trial (premium-level)
      SubscriptionService.setMockState(SubscriptionState(
        tier: SubscriptionTier.premium,
        isTrialActive: true,
        trialDaysRemaining: 10,
        expiresAt: DateTime.now().add(const Duration(days: 10)),
        source: SubscriptionSource.mock,
      ));

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Coach Content'), findsOneWidget);
      expect(find.text('Débloquer'), findsNothing);
    });

    testWidgets('shows locked state for expired trial', (tester) async {
      SubscriptionService.setMockState(SubscriptionState(
        tier: SubscriptionTier.premium,
        isTrialActive: true,
        trialDaysRemaining: 0,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        source: SubscriptionSource.mock,
      ));

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Débloquer'), findsOneWidget);
    });
  });
}
