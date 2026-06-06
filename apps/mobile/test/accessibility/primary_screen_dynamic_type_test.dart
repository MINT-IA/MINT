import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/screens/advisor/financial_report_screen_v2.dart';
import 'package:mint_mobile/screens/budget/budget_screen.dart';
import 'package:mint_mobile/screens/document_scan/document_scan_screen.dart';
import 'package:mint_mobile/screens/explore/explorer_screen.dart';
import 'package:mint_mobile/screens/mon_argent/mon_argent_screen.dart';
import 'package:mint_mobile/screens/profile/financial_summary_screen.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCoachProfileProvider extends CoachProfileProvider {
  _FakeCoachProfileProvider(this._profile);

  final CoachProfile? _profile;

  @override
  CoachProfile? get profile => _profile;
}

Widget _localizedHarness(Widget child) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(390, 844),
        textScaler: TextScaler.linear(2.0),
      ),
      child: child,
    ),
  );
}

Future<List<FlutterErrorDetails>> _pumpAndCollectOverflows(
  WidgetTester tester,
  Widget widget,
) async {
  final overflowErrors = <FlutterErrorDetails>[];
  final oldHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) {
      overflowErrors.add(details);
      return;
    }
    oldHandler?.call(details);
  };

  try {
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 1600));
  } finally {
    FlutterError.onError = oldHandler;
  }

  return overflowErrors;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Row 23 primary screens at 200% text scale', () {
    testWidgets('Budget empty state does not overflow', (tester) async {
      final errors = await _pumpAndCollectOverflows(
        tester,
        _localizedHarness(
          ChangeNotifierProvider(
            create: (_) => BudgetProvider(),
            child: const BudgetScreen(
              inputs: BudgetInputs(
                payFrequency: PayFrequency.monthly,
                netIncome: 0,
                housingCost: 0,
                debtPayments: 0,
              ),
            ),
          ),
        ),
      );

      expect(errors, isEmpty, reason: _formatOverflowReason(errors));
    });

    testWidgets('Budget populated independent/no-LPP state does not overflow',
        (tester) async {
      final seed =
          CoachProfileSeeds.registry['independent_no_lpp_income_reality']!;
      final profile = CoachProfile.fromWizardAnswers(
        seed.toWizardAnswers(now: DateTime(2026, 6, 6)),
      );

      final errors = await _pumpAndCollectOverflows(
        tester,
        _localizedHarness(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => BudgetProvider()),
              ChangeNotifierProvider<CoachProfileProvider>.value(
                value: _FakeCoachProfileProvider(profile),
              ),
              ChangeNotifierProvider(create: (_) => MintStateProvider()),
            ],
            child: const BudgetScreen(
              inputs: BudgetInputs(
                payFrequency: PayFrequency.monthly,
                netIncome: 7200,
                housingCost: 1872,
                debtPayments: 0,
                taxProvision: 1350,
                healthInsurance: 420,
                otherFixedCosts: 480,
                isTaxEstimated: true,
                style: BudgetStyle.envelopes3,
              ),
            ),
          ),
        ),
      );

      expect(errors, isEmpty, reason: _formatOverflowReason(errors));
    });

    testWidgets('Rapport populated independent/no-LPP state does not overflow',
        (tester) async {
      final seed =
          CoachProfileSeeds.registry['independent_no_lpp_income_reality']!;

      final errors = await _pumpAndCollectOverflows(
        tester,
        _localizedHarness(
          FinancialReportScreenV2(
            wizardAnswers: seed.toWizardAnswers(now: DateTime(2026, 6, 6)),
          ),
        ),
      );

      expect(errors, isEmpty, reason: _formatOverflowReason(errors));
    });

    testWidgets('Mon Argent missing-data state does not overflow',
        (tester) async {
      final errors = await _pumpAndCollectOverflows(
        tester,
        _localizedHarness(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => BudgetProvider()),
              ChangeNotifierProvider(create: (_) => CoachProfileProvider()),
              ChangeNotifierProvider(create: (_) => MintStateProvider()),
            ],
            child: const MonArgentScreen(),
          ),
        ),
      );

      expect(errors, isEmpty, reason: _formatOverflowReason(errors));
    });

    testWidgets('Profile dossier empty state does not overflow',
        (tester) async {
      final errors = await _pumpAndCollectOverflows(
        tester,
        _localizedHarness(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<CoachProfileProvider>.value(
                value: _FakeCoachProfileProvider(
                  CoachProfile.fromWizardAnswers({}),
                ),
              ),
              ChangeNotifierProvider(create: (_) => AuthProvider()),
            ],
            child: const FinancialSummaryScreen(),
          ),
        ),
      );

      expect(errors, isEmpty, reason: _formatOverflowReason(errors));
    });

    testWidgets('Document scan entry state does not overflow', (tester) async {
      final errors = await _pumpAndCollectOverflows(
        tester,
        _localizedHarness(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CoachProfileProvider()),
              ChangeNotifierProvider(create: (_) => ByokProvider()),
            ],
            child: const DocumentScanScreen(),
          ),
        ),
      );

      expect(errors, isEmpty, reason: _formatOverflowReason(errors));
    });

    testWidgets('Explorer hub grid does not overflow', (tester) async {
      final errors = await _pumpAndCollectOverflows(
        tester,
        _localizedHarness(const ExplorerScreen()),
      );

      expect(errors, isEmpty, reason: _formatOverflowReason(errors));
    });
  });
}

String _formatOverflowReason(List<FlutterErrorDetails> errors) {
  return 'Primary screen must not throw RenderFlex overflow at 200% text '
      'scale:\n${errors.map((e) => e.exceptionAsString()).join('\n')}';
}
