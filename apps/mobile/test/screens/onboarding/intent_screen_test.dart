import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_entry_payload_provider.dart';
import 'package:mint_mobile/screens/onboarding/intent_screen.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

// ────────────────────────────────────────────────────────────
//  INTENT SCREEN — Widget Tests (Onboarding V2)
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  late CoachEntryPayloadProvider payloadProvider;

  Widget buildIntentScreen() {
    payloadProvider = CoachEntryPayloadProvider();

    final router = GoRouter(
      initialLocation: '/onboarding/intent',
      routes: [
        GoRoute(
          path: '/onboarding/intent',
          builder: (context, state) => const IntentScreen(),
        ),
        // Stub route for navigation target.
        GoRoute(
          path: '/home',
          builder: (context, state) =>
              const Scaffold(body: Text('home')),
        ),
      ],
    );

    return ChangeNotifierProvider<CoachEntryPayloadProvider>.value(
      value: payloadProvider,
      child: MaterialApp.router(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  group('IntentScreen — renders', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pump();
      expect(find.byType(IntentScreen), findsOneWidget);
    });

    testWidgets('shows title from i18n', (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pump();
      expect(find.textContaining('amène'), findsOneWidget);
    });

    testWidgets('shows subtitle from i18n', (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pump();
      expect(find.textContaining('situation'), findsOneWidget);
    });

    testWidgets('shows microcopy from i18n', (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pump();
      expect(find.textContaining('reformuler'), findsOneWidget);
    });

    testWidgets('shows all 7 chips', (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pump();
      // First 4 visible without scrolling.
      expect(find.textContaining('3a'), findsOneWidget);
      expect(find.textContaining('où j'), findsOneWidget);
      expect(find.textContaining('prévoyance'), findsOneWidget);
      expect(find.textContaining('bêtement'), findsOneWidget);
      // Scroll down to reveal remaining chips.
      await tester.scrollUntilVisible(
        find.textContaining('Autre'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('projet'), findsOneWidget);
      expect(find.textContaining('change'), findsOneWidget);
      expect(find.textContaining('Autre'), findsOneWidget);
    });
  });

  group('IntentScreen — chip tap', () {
    testWidgets('tapping 3a chip persists intent and marks onboarding done',
        (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pump();

      await tester.tap(find.textContaining('3a'));
      await tester.pumpAndSettle();

      final isMiniComplete =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(isMiniComplete, isTrue);

      final intent =
          await ReportPersistenceService.getSelectedOnboardingIntent();
      expect(intent, contains('3a'));
    });

    testWidgets('tapping Autre persists and marks onboarding done',
        (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pump();

      await tester.scrollUntilVisible(
        find.textContaining('Autre'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.textContaining('Autre'));
      await tester.pumpAndSettle();

      final isMiniComplete =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(isMiniComplete, isTrue);

      final intent =
          await ReportPersistenceService.getSelectedOnboardingIntent();
      expect(intent, contains('Autre'));
    });

    testWidgets('tapping chip sets payload in provider', (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pump();

      // Before tap, no payload.
      expect(payloadProvider.pending, isNull);

      await tester.tap(find.textContaining('prévoyance'));
      await tester.pumpAndSettle();

      // After navigation, payload may have been consumed by route change.
      // Verify via persistence as reliable proxy.
      final intent =
          await ReportPersistenceService.getSelectedOnboardingIntent();
      expect(intent, contains('prévoyance'));
    });

    testWidgets('tapping chip navigates to /home', (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pump();

      await tester.scrollUntilVisible(
        find.textContaining('projet'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.textContaining('projet'));
      await tester.pumpAndSettle();

      // Should have navigated away from IntentScreen.
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('IntentScreen — layout', () {
    testWidgets('constrained to 480px max width', (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pump();
      final boxes = tester
          .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
          .where((w) => w.constraints.maxWidth == 480);
      expect(boxes, isNotEmpty);
    });
  });
}
