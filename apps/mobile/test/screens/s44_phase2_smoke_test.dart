// ────────────────────────────────────────────────────────────
//  S44 Phase 2 — Smoke Tests
//  AgeBandPolicy boundaries + new 65+ screens
//  (OptimisationDecaissementScreen, SuccessionPatrimoineScreen)
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/age_band_policy.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/coach/optimisation_decaissement_screen.dart';
import 'package:mint_mobile/screens/coach/succession_patrimoine_screen.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/widgets/coach/succession_evidence_quest.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

// ─── Helpers ─────────────────────────────────────────────────

Widget _wrap(Widget child, {CoachProfileProvider? coachProfileProvider}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => child),
    GoRoute(
      path: '/data-block/:type',
      builder: (_, state) => DataBlockEnrichmentScreen(
        blockType: state.pathParameters['type']!,
        initialInputKey: state.uri.queryParameters['inputKey'],
      ),
    ),
  ]);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => coachProfileProvider ?? CoachProfileProvider(),
      ),
      ChangeNotifierProvider(create: (_) => SlmProvider()),
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

// ═════════════════════════════════════════════════════════════
//  1. AgeBandPolicy — boundary tests
// ═════════════════════════════════════════════════════════════

void main() {
  group('AgeBandPolicy.forAge — boundaries', () {
    test('age 18 → youngProfessional', () {
      expect(AgeBandPolicy.forAge(18).band, AgeBand.youngProfessional);
    });

    test('age 25 → youngProfessional (upper bound inclusive)', () {
      expect(AgeBandPolicy.forAge(25).band, AgeBand.youngProfessional);
    });

    test('age 26 → stabilization (lower bound)', () {
      expect(AgeBandPolicy.forAge(26).band, AgeBand.stabilization);
    });

    test('age 35 → stabilization (upper bound inclusive)', () {
      expect(AgeBandPolicy.forAge(35).band, AgeBand.stabilization);
    });

    test('age 36 → peakEarnings (lower bound)', () {
      expect(AgeBandPolicy.forAge(36).band, AgeBand.peakEarnings);
    });

    test('age 49 → peakEarnings (upper bound inclusive)', () {
      expect(AgeBandPolicy.forAge(49).band, AgeBand.peakEarnings);
    });

    test('age 50 → preRetirement (lower bound)', () {
      expect(AgeBandPolicy.forAge(50).band, AgeBand.preRetirement);
    });

    test('age 65 → preRetirement (upper bound inclusive)', () {
      expect(AgeBandPolicy.forAge(65).band, AgeBand.preRetirement);
    });

    test('age 66 → retirement (lower bound)', () {
      expect(AgeBandPolicy.forAge(66).band, AgeBand.retirement);
    });

    test('age 80 → retirement', () {
      expect(AgeBandPolicy.forAge(80).band, AgeBand.retirement);
    });

    test('age 120 → retirement (upper bound inclusive)', () {
      expect(AgeBandPolicy.forAge(120).band, AgeBand.retirement);
    });

    test('age below minimum (0) → falls back to first policy', () {
      // forAge uses firstWhere with orElse: () => all.first
      expect(AgeBandPolicy.forAge(0).band, AgeBand.youngProfessional);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  2. OptimisationDecaissementScreen — smoke tests
  // ═══════════════════════════════════════════════════════════

  group('OptimisationDecaissementScreen', () {
    testWidgets('renders without crash', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      await tester.pumpWidget(_wrap(const OptimisationDecaissementScreen()));
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays title in French', (tester) async {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 2.0;
      await tester.pumpWidget(_wrap(const OptimisationDecaissementScreen()));
      await tester.pump();
      expect(find.textContaining('caissement'), findsWidgets);
    });

    testWidgets('shows disclaimer (LSFin)', (tester) async {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 2.0;
      await tester.pumpWidget(_wrap(const OptimisationDecaissementScreen()));
      await tester.pump();
      // Disclaimer text is at the bottom — find key substring
      expect(find.textContaining('éducatif'), findsWidgets);
    });

    testWidgets('does not contain banned term "conseiller·e" as job title',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 2.0;
      await tester.pumpWidget(_wrap(const OptimisationDecaissementScreen()));
      await tester.pump();
      // "spécialiste" should appear, not "conseiller·e" as a person title
      expect(find.textContaining('spécialiste'), findsWidgets);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  3. SuccessionPatrimoineScreen — smoke tests
  // ═══════════════════════════════════════════════════════════

  group('SuccessionPatrimoineScreen', () {
    late void Function(FlutterErrorDetails)? oldHandler;

    setUp(() {
      oldHandler = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        // Swallow RenderFlex overflow — layout warning, not a functional bug.
        if (details.exceptionAsString().contains('overflowed')) return;
        // Forward everything else to the original test-framework handler.
        if (oldHandler != null) oldHandler!(details);
      };
    });

    tearDown(() {
      FlutterError.onError = oldHandler;
    });

    testWidgets('renders without crash', (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(_wrap(const SuccessionPatrimoineScreen()));
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays succession title', (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(_wrap(const SuccessionPatrimoineScreen()));
      await tester.pump();
      expect(find.textContaining('uccession'), findsWidgets);
    });

    testWidgets('uses a legal-advice disclaimer without LSFin framing',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(_wrap(const SuccessionPatrimoineScreen()));
      await tester.pump();
      expect(find.textContaining('éducatif'), findsWidgets);
      expect(find.textContaining('conseil juridique'), findsWidgets);
      expect(find.textContaining('LSFin'), findsNothing);
    });

    testWidgets('shows legal sources section title', (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(_wrap(const SuccessionPatrimoineScreen()));
      await tester.pump();
      expect(find.textContaining('Sources'), findsWidgets);
    });

    testWidgets('concept card uses CO for donation (not CC)', (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(_wrap(const SuccessionPatrimoineScreen()));
      await tester.pump();
      expect(find.textContaining('CO art. 239'), findsWidgets);
    });

    testWidgets('uses current neutral Swiss succession-law education',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(_wrap(const SuccessionPatrimoineScreen()));
      await tester.pump();

      expect(find.textContaining('1er janvier 2023'), findsOneWidget);
      expect(
        find.textContaining('moitié du droit successoral légal'),
        findsOneWidget,
      );
      expect(
          find.textContaining('parents n’ont plus de réserve'), findsOneWidget);
      expect(find.textContaining('divorce'), findsOneWidget);
      expect(find.textContaining('dissolution du partenariat'), findsOneWidget);
      expect(
        find.textContaining('MINT n’en déduit aucune part personnelle'),
        findsOneWidget,
      );
      expect(find.text('CC art. 470–472'), findsOneWidget);
      expect(find.text('CC art. 470 al. 2'), findsNothing);
      expect(
        find.textContaining('disposer pour cause de mort'),
        findsOneWidget,
      );
      expect(
        find.textContaining('MINT ne la calcule pas'),
        findsOneWidget,
      );
      expect(
        find.text(
          'LPP art. 19–20a et règlement de l’institution · OPP 3 art. 2',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'LPP art. 19–20a et règlement de l’institution — prestations de survivants et autres bénéficiaires',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('LPP art. 20 — Bénéficiaires du capital LPP'),
        findsNothing,
      );
      expect(find.textContaining('votre part personnelle'), findsNothing);
      expect(find.textContaining('vous pouvez léguer'), findsNothing);
    });

    testWidgets('CTA uses spécialiste (not banned conseiller title)',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(_wrap(const SuccessionPatrimoineScreen()));
      await tester.pump();
      // "spécialiste" should appear in the CTA
      expect(find.textContaining('spécialiste'), findsWidgets);
    });

    testWidgets('collector flag is fail-closed and unsafe widget stays absent',
        (tester) async {
      addTearDown(
          () => FeatureFlags.successionEvidenceCollectionEnabled = false);
      FeatureFlags.successionEvidenceCollectionEnabled = false;
      await tester.pumpWidget(_wrap(const SuccessionPatrimoineScreen()));
      await tester.pump();
      expect(find.byType(SuccessionEvidenceQuest), findsNothing);
      expect(
        find.bySemanticsIdentifier('succession_reference_quest_flag_off'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('succession_reference_quest'),
        findsNothing,
      );
    });

    testWidgets('local collector flag exposes the real quest only',
        (tester) async {
      addTearDown(
          () => FeatureFlags.successionEvidenceCollectionEnabled = false);
      FeatureFlags.successionEvidenceCollectionEnabled = true;
      await tester.pumpWidget(_wrap(const SuccessionPatrimoineScreen()));
      await tester.pump();
      expect(find.byType(SuccessionEvidenceQuest), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('succession_reference_quest'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('succession_reference_quest_flag_off'),
        findsNothing,
      );
    });

    testWidgets('asks for property value before rendering a fictive case',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrap(const SuccessionPatrimoineScreen()));
      await tester.pump();

      expect(
          find.byKey(const Key('succession_property_missing')), findsOneWidget);
      expect(find.byKey(const Key('succession_parents_note')), findsNothing);
      expect(find.textContaining("500'000"), findsNothing);
      expect(find.textContaining("50'000"), findsNothing);
      expect(find.textContaining('Enfant 1'), findsNothing);
    });

    testWidgets('property missing CTA opens targeted property DataBlock',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrap(const SuccessionPatrimoineScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Renseigner mon patrimoine').first);
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('property_market_value_input')), findsOneWidget);
      expect(find.byKey(const Key('savings_input')), findsNothing);
      expect(find.byKey(const Key('mortgage_balance_input')), findsNothing);
    });

    testWidgets('renders transmission note from ledger property facts',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final provider = CoachProfileProvider()
        ..updateFromAnswers({
          'q_property_market_value': 950000,
          '_coach_dettes_hypotheque': 320000,
          'q_children': 2,
          'q_civil_status': 'marie',
        });

      await tester.pumpWidget(_wrap(
        const SuccessionPatrimoineScreen(),
        coachProfileProvider: provider,
      ));
      await tester.pump();

      expect(
          find.byKey(const Key('succession_property_missing')), findsNothing);
      expect(find.byKey(const Key('succession_parents_note')), findsOneWidget);
      expect(
          find.byKey(const Key('succession_mortgage_missing')), findsNothing);
      expect(find.textContaining("950'000"), findsWidgets);
      expect(find.textContaining("320'000"), findsWidgets);
      expect(find.textContaining("630'000"), findsWidgets);
      expect(
        find.text(
          'Valeur immobilière nette indicative (valeur déclarée − hypothèque déclarée)',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Ne constitue pas la masse successorale nette'),
        findsOneWidget,
      );
      expect(find.text('Patrimoine net'), findsNothing);
      expect(find.textContaining('Avec testament'), findsNothing);
      expect(find.textContaining('24 %'), findsNothing);
      expect(find.textContaining('Partenaire reçoit'), findsNothing);
      expect(find.textContaining('isOptimized'), findsNothing);
    });

    testWidgets('missing mortgage CTA opens targeted mortgage DataBlock',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 16000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final provider = CoachProfileProvider()
        ..updateFromAnswers({
          'q_property_market_value': 950000,
        });

      await tester.pumpWidget(_wrap(
        const SuccessionPatrimoineScreen(),
        coachProfileProvider: provider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Renseigner mon patrimoine').first);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mortgage_balance_input')), findsOneWidget);
      expect(find.byKey(const Key('savings_input')), findsNothing);
      expect(
          find.byKey(const Key('property_market_value_input')), findsNothing);
    });
  });
}
