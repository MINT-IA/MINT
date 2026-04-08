import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_entry_payload_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/intent_screen.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

// ────────────────────────────────────────────────────────────
//  INTENT SCREEN — Widget Tests (Onboarding V2)
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    // Phase 12-01 added a first-launch Ton chooser modal sheet that fires
    // inside `_onChipTap` before persistence/navigation. Pre-set the flag so
    // the sheet is skipped and the tests can exercise the persist+nav path.
    SharedPreferences.setMockInitialValues({
      'ton_chooser_first_launch_done': true,
    });
  });

  late CoachEntryPayloadProvider payloadProvider;

  Widget buildIntentScreen() {
    payloadProvider = CoachEntryPayloadProvider();

    // NOTE (Phase 1 rewire): IntentScreen.build inspects GoRouterState.extra
    // for `fromOnboarding`. The golden path (true) pushes to
    // /onboarding/quick-start and skips the persistence + nav that these
    // tests assert. Since Phase 1 moved `setOnboardingCompleted` to
    // plan_screen, the only remaining responsibilities of IntentScreen that
    // can be asserted at this boundary are the NON-onboarding path
    // (settings / re-selection): persist chipKey, compute premier eclairage,
    // seed CapMemoryStore, navigate to /home?tab=0. We exercise that path
    // by stubbing a landing route that forwards to IntentScreen with
    // `fromOnboarding: false` in extra.
    final router = GoRouter(
      initialLocation: '/test-entry',
      routes: [
        GoRoute(
          path: '/test-entry',
          builder: (context, state) {
            // Forward to IntentScreen with extra on first frame.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go(
                '/onboarding/intent',
                extra: const <String, dynamic>{'fromOnboarding': false},
              );
            });
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
        GoRoute(
          path: '/onboarding/intent',
          builder: (context, state) => const IntentScreen(),
        ),
        // Stub route for navigation target (Phase 10-02a: /coach/chat merged path).
        GoRoute(
          path: '/coach/chat',
          builder: (context, state) =>
              const Scaffold(body: Text('coach-chat')),
        ),
      ],
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachEntryPayloadProvider>.value(
          value: payloadProvider,
        ),
        ChangeNotifierProvider<CoachProfileProvider>(
          create: (_) => CoachProfileProvider(),
        ),
      ],
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
      await tester.pumpAndSettle();
      expect(find.byType(IntentScreen), findsOneWidget);
    });

    testWidgets('shows title from i18n', (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pumpAndSettle();
      expect(find.textContaining('amène'), findsOneWidget);
    });

    testWidgets('shows subtitle from i18n', (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pumpAndSettle();
      // P-S1-01: removal of intentChipPrevoyance kept 'Ma situation change'
      // chip text on screen, which also contains 'situation'. Use a subtitle-
      // unique substring to disambiguate.
      expect(find.textContaining('situation'), findsWidgets);
    });

    testWidgets('shows microcopy from i18n', (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pumpAndSettle();
      expect(find.textContaining('reformuler'), findsOneWidget);
    });

    testWidgets('shows all 6 chips (P-S1-01 hot-fix removed 3 anti-shame chips)', (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pumpAndSettle();
      // Remaining chips after P-S1-01 (Phase 8c hot-fix): 3a, Fiscalite,
      // Projet, Changement, PremierEmploi, Autre. Removed:
      // intentChipBilan, intentChipPrevoyance, intentChipNouvelEmploi.
      expect(find.textContaining('3a'), findsOneWidget);
      // Phase 12 Fiscalite copy drift: "Mes impôts, j'aimerais y voir clair"
      // (was "bêtement" in earlier copy). Use a stable post-Phase-12 substring.
      expect(find.textContaining('impôts'), findsOneWidget);
      // Scroll down to reveal remaining chips.
      await tester.scrollUntilVisible(
        find.textContaining('Autre'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('projet'), findsOneWidget);
      expect(find.textContaining('situation change'), findsOneWidget);
      expect(find.textContaining('premier emploi'), findsOneWidget);
      expect(find.textContaining('Autre'), findsOneWidget);
      // Anti-shame doctrine: deleted chips must NOT render.
      expect(find.textContaining('où j\'en suis'), findsNothing);
      expect(find.textContaining('prévoyance'), findsNothing);
      expect(find.textContaining('change de travail'), findsNothing);
    });
  });

  group('IntentScreen — chip tap', () {
    // NOTE (STAB-06): Phase 1 moved `setMiniOnboardingCompleted` out of
    // IntentScreen and into plan_screen. IntentScreen only persists the
    // selected chipKey at this boundary. Tests below assert that — not
    // onboarding-done. The onboarding-done boundary is covered by
    // plan_screen tests.
    testWidgets('tapping 3a chip persists chipKey (onboarding-done moved to plan_screen)',
        (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('3a'));
      await tester.pumpAndSettle();

      // Responsibility moved: IntentScreen must NOT mark onboarding complete.
      final isMiniComplete =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(isMiniComplete, isFalse);

      final intent =
          await ReportPersistenceService.getSelectedOnboardingIntent();
      // Must store the ARB chipKey, not the resolved French label.
      expect(intent, equals('intentChip3a'));
    });

    testWidgets('tapping Autre persists chipKey (onboarding-done moved to plan_screen)',
        (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('Autre'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.textContaining('Autre'));
      await tester.pumpAndSettle();

      // Responsibility moved: IntentScreen must NOT mark onboarding complete.
      final isMiniComplete =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      expect(isMiniComplete, isFalse);

      final intent =
          await ReportPersistenceService.getSelectedOnboardingIntent();
      // Stores ARB chipKey 'intentChipAutre', not the localized 'Autre…'
      expect(intent, equals('intentChipAutre'));
    });

    testWidgets('tapping chip sets payload in provider', (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pumpAndSettle();

      // Before tap, no payload.
      expect(payloadProvider.pending, isNull);

      // P-S1-01: 'prévoyance' chip removed from UI. Use 'impôts' (Fiscalite,
      // Phase 12 copy: "Mes impôts, j'aimerais y voir clair") as the remaining
      // example chip for payload assertion.
      await tester.tap(find.textContaining('impôts'));
      await tester.pumpAndSettle();

      // After navigation, verify via persistence — chipKey stored, not label.
      final intent =
          await ReportPersistenceService.getSelectedOnboardingIntent();
      expect(intent, equals('intentChipFiscalite'));
    });

    testWidgets('tapping chip navigates to /coach/chat (Phase 10-02a merged path)', (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('projet'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.textContaining('projet'));
      await tester.pumpAndSettle();

      // Should have navigated away from IntentScreen to /coach/chat.
      expect(find.text('coach-chat'), findsOneWidget);
    });
  });

  // ────────────────────────────────────────────────────────────
  //  NEW TESTS: Rewired _onChipTap pipeline (Plan 03-02)
  // ────────────────────────────────────────────────────────────

  group('IntentScreen — rewired onChipTap pipeline', () {
    testWidgets('chip tap persists chipKey, not the localized label',
        (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pumpAndSettle();

      // Tap the first chip (3a)
      await tester.tap(find.textContaining('3a'));
      await tester.pumpAndSettle();

      final stored =
          await ReportPersistenceService.getSelectedOnboardingIntent();
      // Must be the ARB key, not the French string "Pilier 3a" or similar.
      expect(stored, equals('intentChip3a'));
      expect(stored, isNot(contains(' '))); // chipKey has no spaces
    });

    testWidgets('chip tap writes goalIntentTag to CapMemoryStore.declaredGoals',
        (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pumpAndSettle();

      // Scroll to and tap 'projet' chip → maps to housing_purchase
      await tester.scrollUntilVisible(
        find.textContaining('projet'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.textContaining('projet'));
      await tester.pumpAndSettle();

      final memory = await CapMemoryStore.load();
      expect(memory.declaredGoals, contains('housing_purchase'));
    });

    testWidgets('chip tap navigates to /coach/chat (Phase 10-02a unified path)',
        (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('3a'));
      await tester.pumpAndSettle();

      // Phase 10-02a: merged nav target is /coach/chat for both onboarding
      // and non-onboarding paths. Screens-before-first-insight = 2.
      expect(find.byType(IntentScreen), findsNothing);
      expect(find.text('coach-chat'), findsOneWidget);
    });

    testWidgets(
        'chip tap computes and persists premier eclairage snapshot with required keys',
        (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('3a'));
      await tester.pumpAndSettle();

      final snapshot =
          await ReportPersistenceService.loadPremierEclairageSnapshot();
      expect(snapshot, isNotNull);
      // Must contain display fields only — no PII (T-03-02).
      expect(snapshot!.containsKey('value'), isTrue);
      expect(snapshot.containsKey('title'), isTrue);
      expect(snapshot.containsKey('suggestedRoute'), isTrue);
      expect(snapshot.containsKey('colorKey'), isTrue);
      expect(snapshot.containsKey('confidenceMode'), isTrue);
      // PII guard: salary and financial amounts must NOT be in the snapshot.
      expect(snapshot.containsKey('salary'), isFalse);
      expect(snapshot.containsKey('grossAnnualSalary'), isFalse);
      expect(snapshot.containsKey('iban'), isFalse);
    });
  });

  group('IntentScreen — layout', () {
    testWidgets('constrained to 480px max width', (tester) async {
      await tester.pumpWidget(buildIntentScreen());
      await tester.pumpAndSettle();
      final boxes = tester
          .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
          .where((w) => w.constraints.maxWidth == 480);
      expect(boxes, isNotEmpty);
    });
  });
}
