import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/arbitrage/breakeven_indicator_widget.dart';
import 'package:mint_mobile/widgets/coach/mint_trajectory_chart.dart';
import 'package:mint_mobile/widgets/fri_breakdown_bars.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';

import 'helpers/screen_pump.dart';

void main() {
  group('Infra-G5 dataviz contract gate', () {
    testWidgets('renders the live dataviz surfaces without layout failures',
        (tester) async {
      await _pumpDataviz(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MintTrajectoryChart(
              result: _projectionFixture(),
              goalALabel: 'Retraite 65 ans',
            ),
            const SizedBox(height: 24),
            const FriBreakdownBars(
              liquidite: 18,
              fiscalite: 11,
              retraite: 20,
              risque: 9,
            ),
            const SizedBox(height: 24),
            const BreakevenIndicatorWidget(
              breakevenYear: 9,
              ageRetraite: 65,
              horizon: 25,
              showCalendarYear: false,
              sensitivity: {
                'rendement_plus_1': 12000,
                'rendement_moins_1': -9000,
              },
            ),
            const SizedBox(height: 24),
            const MintResultHeroCard(
              eyebrow: 'Premier éclairage',
              primaryValue: "CHF 12'400",
              primaryLabel: 'impact annuel estimé',
              secondaryValue: "CHF 1'030",
              secondaryLabel: 'par mois',
              narrative: 'Ce nombre sert à préparer une discussion structurée.',
              accentColor: MintColors.primary,
            ),
          ],
        ),
      );

      expect(find.byType(MintTrajectoryChart), findsOneWidget);
      expect(find.byType(FriBreakdownBars), findsOneWidget);
      expect(find.byType(BreakevenIndicatorWidget), findsOneWidget);
      expect(find.byType(MintResultHeroCard), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(4));

      for (final text in [
        'Ta trajectoire',
        'Optimiste',
        'Base',
        'Prudent',
        'Liquidité',
        'Fiscalité',
        'Retraite',
        'Risque',
        '18/25',
        '11/25',
        '20/25',
        '9/25',
        "CHF 12'400",
        "CHF 1'030",
        'Premier éclairage',
      ]) {
        expect(find.text(text), findsWidgets);
      }

      expect(find.textContaining('74 ans'), findsOneWidget);
      expect(find.textContaining('Rendement +1 %'), findsOneWidget);
      expect(find.byIcon(Icons.swap_vert_rounded), findsOneWidget);
      _expectNoFlutterException(tester);
    });
  });
}

Future<void> _pumpDataviz(WidgetTester tester, Widget child) {
  return pumpScreen(
    tester,
    device: GoldenDevice.iphone14Pro,
    disableAnimations: true,
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(width: 342, child: child),
      ),
    ),
  );
}

void _expectNoFlutterException(WidgetTester tester) {
  final exception = tester.takeException();
  expect(
    exception,
    isNull,
    reason: exception is FlutterError ? exception.toStringDeep() : null,
  );
}

ProjectionResult _projectionFixture() {
  ProjectionScenario scenario(String label, double multiplier) {
    final points = List.generate(10, (index) {
      final capital = 100000 + (index * 18000 * multiplier);
      return ProjectionPoint(
          date: DateTime.utc(2026 + index),
          capitalCumule: capital,
          contributionMensuelle: 700,
          rendementCumule: capital * 0.12);
    });

    return ProjectionScenario(
      label: label,
      points: points,
      capitalFinal: points.last.capitalCumule,
      revenuAnnuelRetraite: points.last.capitalCumule * 0.04,
      decomposition: const {
        'avs': 43000,
        'lpp': 24000,
        '3a': 8000,
        'libre': 12000,
      },
    );
  }

  return ProjectionResult(
      prudent: scenario('Prudent', 0.75),
      base: scenario('Base', 1),
      optimiste: scenario('Optimiste', 1.35),
      tauxRemplacementBase: 64,
      milestones: [
        ProjectionMilestone(
            date: DateTime.utc(2030), label: "150'000 CHF", amount: 150000),
      ],
      disclaimer: 'Projection pedagogique',
      sources: const ['fixture Infra-G5'],
      confidenceScore: 80);
}
