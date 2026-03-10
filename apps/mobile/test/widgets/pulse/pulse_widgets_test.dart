import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/visibility_score_service.dart';
import 'package:mint_mobile/widgets/pulse/visibility_score_card.dart';
import 'package:mint_mobile/widgets/pulse/pulse_action_card.dart';
import 'package:mint_mobile/widgets/pulse/comprendre_section.dart';
import 'package:mint_mobile/widgets/pulse/pulse_disclaimer.dart';

// ────────────────────────────────────────────────────────────────
//  PULSE WIDGETS — Unit & Widget Tests
// ────────────────────────────────────────────────────────────────

VisibilityScore _makeScore({
  double total = 72,
  int percentage = 72,
  String narrative = 'Bonne visibilite !',
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
            label: 'Liquidite',
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
            label: 'Fiscalite',
            icon: 'receipt',
            score: 22,
            maxScore: 25,
            status: 'complete',
            hint: 'Complet',
          ),
          VisibilityAxis(
            id: 'securite',
            label: 'Securite',
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
        MaterialApp(home: Scaffold(body: VisibilityScoreCard(score: score))),
      );

      expect(find.text('72%'), findsOneWidget);
    });

    testWidgets('renders 4 axis labels', (tester) async {
      final score = _makeScore();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: VisibilityScoreCard(score: score))),
      );

      expect(find.text('Liquidite'), findsOneWidget);
      expect(find.text('Retraite'), findsOneWidget);
      expect(find.text('Fiscalite'), findsOneWidget);
      expect(find.text('Securite'), findsOneWidget);
    });

    testWidgets('renders axis scores as "X/25"', (tester) async {
      final score = _makeScore();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: VisibilityScoreCard(score: score))),
      );

      expect(find.text('20/25'), findsOneWidget); // Liquidite
      expect(find.text('15/25'), findsWidgets); // Retraite + Securite
      expect(find.text('22/25'), findsOneWidget); // Fiscalite
    });

    testWidgets('renders narrative text', (tester) async {
      final score = _makeScore(narrative: 'Bonne visibilite !');
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: VisibilityScoreCard(score: score))),
      );

      expect(find.text('Bonne visibilite !'), findsOneWidget);
    });

    testWidgets('renders title "Visibilite financiere"', (tester) async {
      final score = _makeScore();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: VisibilityScoreCard(score: score))),
      );

      expect(find.text('Visibilite financiere'), findsOneWidget);
    });

    testWidgets('shows couple alert when gap > 15', (tester) async {
      final score = _makeScore(
        total: 75,
        coupleWeakName: 'Lauren',
        coupleWeakScore: 45,
      );
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: VisibilityScoreCard(score: score))),
      );

      expect(find.textContaining('Lauren'), findsOneWidget);
      expect(find.textContaining('45%'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('hides couple alert when gap <= 15', (tester) async {
      final score = _makeScore(
        total: 75,
        coupleWeakName: 'Lauren',
        coupleWeakScore: 65, // gap = 10 < 15
      );
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: VisibilityScoreCard(score: score))),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('hides couple alert when no couple data', (tester) async {
      final score = _makeScore(); // no couple
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: VisibilityScoreCard(score: score))),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('renders 4 progress bars', (tester) async {
      final score = _makeScore();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: VisibilityScoreCard(score: score))),
      );

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
        MaterialApp(home: Scaffold(body: PulseActionCard(action: action))),
      );

      expect(find.text('Ajoute ton certificat LPP'), findsOneWidget);
      expect(find.textContaining('Scanne'), findsOneWidget);
    });

    testWidgets('renders impact badge with points', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PulseActionCard(action: action))),
      );

      expect(find.text('+18 pts'), findsOneWidget);
    });

    testWidgets('renders category icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PulseActionCard(action: action))),
      );

      expect(find.byIcon(Icons.account_balance), findsOneWidget);
    });

    testWidgets('renders forward arrow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PulseActionCard(action: action))),
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
        const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ComprendreSection()))),
      );

      expect(find.text('Comprendre'), findsOneWidget);
      expect(find.text('Explore tes simulateurs'), findsOneWidget);
    });

    testWidgets('renders 5 items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ComprendreSection()))),
      );

      expect(find.text('Rente ou capital ?'), findsOneWidget);
      expect(find.text('Simuler un rachat LPP'), findsOneWidget);
      expect(find.text('Explorer mon 3a'), findsOneWidget);
      expect(find.text('Mon budget mensuel'), findsOneWidget);
      expect(find.text('Acheter un bien ?'), findsOneWidget);
    });

    testWidgets('renders 5 forward arrows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ComprendreSection()))),
      );

      expect(find.byIcon(Icons.arrow_forward_ios), findsNWidgets(5));
    });

    testWidgets('subtitles are educational (no banned terms)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ComprendreSection()))),
      );

      // Educational verbs: "Compare", "Decouvre", "Visualise", "Estime"
      expect(find.textContaining('Compare'), findsOneWidget);
      expect(find.textContaining('Decouvre'), findsNWidgets(2));
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
        const MaterialApp(home: Scaffold(body: PulseDisclaimer())),
      );

      expect(find.textContaining('Outil educatif'), findsOneWidget);
      expect(find.textContaining('LSFin art. 3'), findsOneWidget);
    });

    testWidgets('renders info icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PulseDisclaimer())),
      );

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('contains "ne constitue pas un conseil"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PulseDisclaimer())),
      );

      expect(
        find.textContaining('Ne constitue pas un conseil'),
        findsOneWidget,
      );
    });
  });
}
