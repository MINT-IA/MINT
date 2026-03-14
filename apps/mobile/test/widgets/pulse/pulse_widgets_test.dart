import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/visibility_score_service.dart';
import 'package:mint_mobile/widgets/pulse/visibility_score_card.dart';
import 'package:mint_mobile/widgets/pulse/pulse_action_card.dart';
import 'package:mint_mobile/widgets/pulse/comprendre_section.dart';
import 'package:mint_mobile/widgets/pulse/pulse_disclaimer.dart';

// ────────────────────────────────────────────────────────────────
//  PULSE WIDGETS — Unit & Widget Tests
// ────────────────────────────────────────────────────────────────

/// Wraps [child] in a MaterialApp with French localization delegates.
Widget _l10nApp(Widget child) {
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

VisibilityScore _makeScore({
  double total = 72,
  int percentage = 72,
  String narrative = 'Bonne visibilit\u00e9\u00a0!',
  List<VisibilityAxis>? axes,
  List<VisibilityAction>? actions,
  String? coupleWeakName,
  double? coupleWeakScore,
}) {
  return VisibilityScore(
    total: total,
    percentage: percentage,
    narrative: narrative,
    axes: axes ??
        const [
          VisibilityAxis(
            id: 'liquidite',
            label: 'Liquidit\u00e9',
            icon: 'wallet',
            score: 20,
            maxScore: 25,
            status: 'complete',
            hint: 'Complet',
          ),
          VisibilityAxis(
            id: 'retraite',
            label: 'Retraite',
            icon: 'beach_access',
            score: 15,
            maxScore: 25,
            status: 'partial',
            hint: 'Ajoute ton certificat LPP',
          ),
          VisibilityAxis(
            id: 'fiscalite',
            label: 'Fiscalit\u00e9',
            icon: 'receipt',
            score: 22,
            maxScore: 25,
            status: 'complete',
            hint: 'Complet',
          ),
          VisibilityAxis(
            id: 'securite',
            label: 'S\u00e9curit\u00e9',
            icon: 'shield',
            score: 15,
            maxScore: 25,
            status: 'partial',
            hint: 'Indique ta situation familiale',
          ),
        ],
    actions: actions ?? const [],
    coupleWeakName: coupleWeakName,
    coupleWeakScore: coupleWeakScore,
  );
}

void main() {
  // ────────────────────────────────────────────────────────────
  //  VISIBILITY SCORE CARD
  // ────────────────────────────────────────────────────────────

  group('VisibilityScoreCard', () {
    testWidgets('renders score percentage', (tester) async {
      final score = _makeScore(percentage: 72);
      await tester.pumpWidget(
        _l10nApp(VisibilityScoreCard(score: score)),
      );
      await tester.pumpAndSettle();

      expect(find.text('72%'), findsOneWidget);
    });

    testWidgets('renders 4 axis labels', (tester) async {
      final score = _makeScore();
      await tester.pumpWidget(
        _l10nApp(VisibilityScoreCard(score: score)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Liquidit\u00e9'), findsOneWidget);
      expect(find.text('Retraite'), findsOneWidget);
      expect(find.text('Fiscalit\u00e9'), findsOneWidget);
      expect(find.text('S\u00e9curit\u00e9'), findsOneWidget);
    });

    testWidgets('renders axis scores as "X/25"', (tester) async {
      final score = _makeScore();
      await tester.pumpWidget(
        _l10nApp(VisibilityScoreCard(score: score)),
      );
      await tester.pumpAndSettle();

      expect(find.text('20/25'), findsOneWidget); // Liquidite
      expect(find.text('15/25'), findsWidgets); // Retraite + Securite
      expect(find.text('22/25'), findsOneWidget); // Fiscalite
    });

    testWidgets('renders narrative text', (tester) async {
      final score = _makeScore(narrative: 'Bonne visibilit\u00e9\u00a0!');
      await tester.pumpWidget(
        _l10nApp(VisibilityScoreCard(score: score)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bonne visibilit\u00e9\u00a0!'), findsOneWidget);
    });

    testWidgets('renders title "Visibilit\u00e9 financi\u00e8re"', (tester) async {
      final score = _makeScore();
      await tester.pumpWidget(
        _l10nApp(VisibilityScoreCard(score: score)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Visibilit\u00e9 financi\u00e8re'), findsOneWidget);
    });

    testWidgets('shows couple alert when gap > 15', (tester) async {
      final score = _makeScore(
        total: 75,
        coupleWeakName: 'Lauren',
        coupleWeakScore: 45,
      );
      await tester.pumpWidget(
        _l10nApp(VisibilityScoreCard(score: score)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Lauren'), findsOneWidget);
      expect(find.textContaining('45'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('hides couple alert when gap <= 15', (tester) async {
      final score = _makeScore(
        total: 75,
        coupleWeakName: 'Lauren',
        coupleWeakScore: 65, // gap = 10 < 15
      );
      await tester.pumpWidget(
        _l10nApp(VisibilityScoreCard(score: score)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('hides couple alert when no couple data', (tester) async {
      final score = _makeScore(); // no couple
      await tester.pumpWidget(
        _l10nApp(VisibilityScoreCard(score: score)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('renders 4 progress bars', (tester) async {
      final score = _makeScore();
      await tester.pumpWidget(
        _l10nApp(VisibilityScoreCard(score: score)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
    });
  });

  // ────────────────────────────────────────────────────────────
  //  PULSE ACTION CARD
  // ────────────────────────────────────────────────────────────

  group('PulseActionCard', () {
    const action = VisibilityAction(
      id: 'lpp',
      title: 'Ajoute ton certificat LPP',
      subtitle: 'Scanne ou saisis les donnees de ta caisse',
      route: '/lpp-deep/rachat',
      icon: 'account_balance',
      category: 'lpp',
      impactPoints: 18,
    );

    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(
        _l10nApp(const PulseActionCard(action: action)),
      );

      expect(find.text('Ajoute ton certificat LPP'), findsOneWidget);
      expect(find.textContaining('Scanne'), findsOneWidget);
    });

    testWidgets('renders impact badge with points', (tester) async {
      await tester.pumpWidget(
        _l10nApp(const PulseActionCard(action: action)),
      );

      expect(find.text('+18 pts'), findsOneWidget);
    });

    testWidgets('renders category icon', (tester) async {
      await tester.pumpWidget(
        _l10nApp(const PulseActionCard(action: action)),
      );

      expect(find.byIcon(Icons.account_balance), findsOneWidget);
    });

    testWidgets('renders forward arrow', (tester) async {
      await tester.pumpWidget(
        _l10nApp(const PulseActionCard(action: action)),
      );

      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
    });
  });

  // ────────────────────────────────────────────────────────────
  //  COMPRENDRE SECTION
  // ────────────────────────────────────────────────────────────

  group('ComprendreSection', () {
    testWidgets('renders section title', (tester) async {
      await tester.pumpWidget(
        _l10nApp(const SingleChildScrollView(child: ComprendreSection())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Comprendre'), findsOneWidget);
      expect(find.text('Explore tes simulateurs'), findsOneWidget);
    });

    testWidgets('renders 5 items', (tester) async {
      await tester.pumpWidget(
        _l10nApp(const SingleChildScrollView(child: ComprendreSection())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rente ou capital\u00a0?'), findsOneWidget);
      expect(find.text('Simuler un rachat LPP'), findsOneWidget);
      expect(find.text('Explorer mon 3a'), findsOneWidget);
      expect(find.text('Mon budget mensuel'), findsOneWidget);
      expect(find.text('Acheter un bien\u00a0?'), findsOneWidget);
    });

    testWidgets('renders 5 forward arrows', (tester) async {
      await tester.pumpWidget(
        _l10nApp(const SingleChildScrollView(child: ComprendreSection())),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_forward_ios), findsNWidgets(5));
    });

    testWidgets('items display proper accented French text', (tester) async {
      await tester.pumpWidget(
        _l10nApp(const SingleChildScrollView(child: ComprendreSection())),
      );
      await tester.pumpAndSettle();

      // Subtitles with correct French accents (é, è, ô, etc.)
      expect(find.textContaining('D\u00e9couvre'), findsNWidgets(2));
      expect(find.textContaining('capacit\u00e9'), findsOneWidget);
      expect(find.textContaining('d\u00e9penses'), findsOneWidget);
      expect(find.textContaining('\u00e9conomie'), findsOneWidget);
    });

    testWidgets('each item navigates to the correct route when tapped',
        (tester) async {
      String? lastPushedRoute;

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              body: SingleChildScrollView(child: ComprendreSection()),
            ),
          ),
          // Catch-all routes for each ComprendreSection item
          GoRoute(
            path: '/arbitrage/rente-vs-capital',
            builder: (_, __) {
              lastPushedRoute = '/arbitrage/rente-vs-capital';
              return const SizedBox();
            },
          ),
          GoRoute(
            path: '/lpp-deep/rachat',
            builder: (_, __) {
              lastPushedRoute = '/lpp-deep/rachat';
              return const SizedBox();
            },
          ),
          GoRoute(
            path: '/simulator/3a',
            builder: (_, __) {
              lastPushedRoute = '/simulator/3a';
              return const SizedBox();
            },
          ),
          GoRoute(
            path: '/budget',
            builder: (_, __) {
              lastPushedRoute = '/budget';
              return const SizedBox();
            },
          ),
          GoRoute(
            path: '/mortgage/affordability',
            builder: (_, __) {
              lastPushedRoute = '/mortgage/affordability';
              return const SizedBox();
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        routerConfig: router,
      ));
      await tester.pumpAndSettle();

      // Tap "Rente ou capital ?" → /arbitrage/rente-vs-capital
      await tester.tap(find.text('Rente ou capital\u00a0?'));
      await tester.pumpAndSettle();
      expect(lastPushedRoute, '/arbitrage/rente-vs-capital');

      // Go back and tap next item
      router.go('/');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simuler un rachat LPP'));
      await tester.pumpAndSettle();
      expect(lastPushedRoute, '/lpp-deep/rachat');

      router.go('/');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Explorer mon 3a'));
      await tester.pumpAndSettle();
      expect(lastPushedRoute, '/simulator/3a');

      router.go('/');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mon budget mensuel'));
      await tester.pumpAndSettle();
      expect(lastPushedRoute, '/budget');

      router.go('/');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Acheter un bien\u00a0?'));
      await tester.pumpAndSettle();
      expect(lastPushedRoute, '/mortgage/affordability');
    });

    testWidgets('subtitles are educational (no banned terms)', (tester) async {
      await tester.pumpWidget(
        _l10nApp(const SingleChildScrollView(child: ComprendreSection())),
      );
      await tester.pumpAndSettle();

      // Educational verbs: "Compare", "Découvre", "Visualise", "Estime"
      expect(find.textContaining('Compare'), findsOneWidget);
      expect(find.textContaining('D\u00e9couvre'), findsNWidgets(2));
      expect(find.textContaining('Visualise'), findsOneWidget);
      expect(find.textContaining('Estime'), findsOneWidget);
    });
  });

  // ────────────────────────────────────────────────────────────
  //  PULSE DISCLAIMER
  // ────────────────────────────────────────────────────────────

  group('PulseDisclaimer', () {
    testWidgets('renders disclaimer text', (tester) async {
      await tester.pumpWidget(
        _l10nApp(const PulseDisclaimer()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Outil \u00e9ducatif'), findsOneWidget);
      expect(find.textContaining('LSFin art.'), findsOneWidget);
    });

    testWidgets('renders info icon', (tester) async {
      await tester.pumpWidget(
        _l10nApp(const PulseDisclaimer()),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('always renders LSFin reference', (tester) async {
      await tester.pumpWidget(
        _l10nApp(const PulseDisclaimer()),
      );
      await tester.pumpAndSettle();

      // LSFin reference must always be visible (compliance requirement)
      expect(find.textContaining('LSFin'), findsOneWidget);
      expect(find.textContaining('art.'), findsOneWidget);
    });

    testWidgets('contains "ne constitue pas un conseil"', (tester) async {
      await tester.pumpWidget(
        _l10nApp(const PulseDisclaimer()),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Ne constitue pas un conseil'),
        findsOneWidget,
      );
    });
  });
}
