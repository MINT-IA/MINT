// Dataviz isolation goldens for the MINT product spine.
//
// These pixel tests are local-only, matching the existing MINT golden policy:
// CI runs the helper contract tests, while macOS-generated PNG masters are
// reviewed in dedicated visual PRs to avoid Linux font-rasterization noise.

@Tags(<String>['local-only'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/arbitrage/breakeven_indicator_widget.dart';
import 'package:mint_mobile/widgets/coach/animated_chiffre.dart';
import 'package:mint_mobile/widgets/coach/mint_trajectory_chart.dart';
import 'package:mint_mobile/widgets/fri_breakdown_bars.dart';

import 'helpers/screen_pump.dart';

Widget _frame(Widget child, {double width = 340}) {
  return SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  );
}

Future<void> _pumpDataviz(
  WidgetTester tester, {
  required Widget child,
}) async {
  await pumpScreen(
    tester,
    device: GoldenDevice.iphone14Pro,
    disableAnimations: true,
    child: child,
  );
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(seconds: 5));
  });
  await tester.pump(const Duration(seconds: 1));
}

CoachProfileProvider _buildGoldenProfileProvider() {
  final provider = CoachProfileProvider();
  provider.updateFromAnswers({
    'q_birth_year': 1977,
    'q_canton': 'VS',
    'q_net_income_period_chf': 8500.0,
    'q_employment_status': 'employee',
    'q_civil_status': 'marie',
    'q_children': 0,
    'q_housing_cost_period_chf': 1800.0,
    'q_has_pension_fund': 'yes',
    'q_has_3a': 'yes',
    'q_3a_annual_contribution': 7258.0,
    'q_emergency_fund': 'yes_3months',
    'q_main_goal': 'financial_health',
  });
  return provider;
}

Future<void> _loadLocalGoldenFont() async {
  final fontFile = File('/System/Library/Fonts/Supplemental/Arial.ttf');
  if (!fontFile.existsSync()) {
    throw StateError('Missing local golden font: ${fontFile.path}');
  }

  final fontBytes = fontFile.readAsBytesSync();
  const families = [
    'MintGoldenArial',
    'Inter',
    'Inter_regular',
    'Inter_500',
    'Inter_600',
    'Inter_700',
    'Inter_italic',
    'Montserrat',
    'Montserrat_700',
    'Montserrat_800',
  ];
  for (final family in families) {
    final loader = FontLoader(family)
      ..addFont(
        Future<ByteData>.value(
          ByteData.sublistView(fontBytes),
        ),
      );
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '/tmp',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider_macos'),
      (MethodCall methodCall) async => '/tmp',
    );
    GoogleFonts.config.allowRuntimeFetching = true;
    HttpOverrides.global = null;
    await _loadLocalGoldenFont();
  });

  group('Dataviz isolation goldens [local-only]', () {
    testWidgets('trajectory chart — iPhone 14 Pro', (tester) async {
      final profile = _buildGoldenProfileProvider().profile!;
      final result = ForecasterService.project(
        profile: profile,
        targetDate: profile.goalA.targetDate,
      );
      await _pumpDataviz(
        tester,
        child: SizedBox(
          width: 390,
          child: MintTrajectoryChart(
            result: result,
            goalALabel: 'Trajectoire',
          ),
        ),
      );
      await expectLater(
        find.byType(MintTrajectoryChart),
        matchesGoldenFile('masters/dataviz_trajectory_iphone14pro.png'),
      );
    });

    testWidgets('FRI breakdown bars — iPhone 14 Pro', (tester) async {
      await _pumpDataviz(
        tester,
        child: _frame(
          const IntrinsicHeight(
            child: FriBreakdownBars(
              liquidite: 18,
              fiscalite: 13,
              retraite: 21,
              risque: 9,
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(FriBreakdownBars),
        matchesGoldenFile('masters/dataviz_fri_breakdown_iphone14pro.png'),
      );
    });

    testWidgets('breakeven indicator — iPhone 14 Pro', (tester) async {
      await _pumpDataviz(
        tester,
        child: _frame(
          const IntrinsicHeight(
            child: BreakevenIndicatorWidget(
              breakevenYear: 11,
              ageRetraite: 65,
              horizon: 25,
              showCalendarYear: false,
              sensitivity: {
                'rendement_plus_1': 24500,
                'rendement_moins_1': -18800,
              },
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(BreakevenIndicatorWidget),
        matchesGoldenFile('masters/dataviz_breakeven_iphone14pro.png'),
      );
    });

    testWidgets('animated financial number — iPhone 14 Pro', (tester) async {
      await _pumpDataviz(
        tester,
        child: _frame(
          DecoratedBox(
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MintColors.lightBorder),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: AnimatedChiffre(
                value: 677847,
                prefix: 'CHF ',
                suffix: '',
                duration: Duration.zero,
                textStyle: TextStyle(
                  color: MintColors.textPrimary,
                  fontFamily: 'MintGoldenArial',
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(AnimatedChiffre),
        matchesGoldenFile('masters/dataviz_animated_chiffre_iphone14pro.png'),
      );
    });
  });
}
