import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens under test
import 'package:mint_mobile/screens/advisor/financial_report_screen_v2.dart';
import 'package:mint_mobile/screens/open_banking/open_banking_hub_screen.dart';
import 'package:mint_mobile/screens/open_banking/transaction_list_screen.dart';
import 'package:mint_mobile/screens/open_banking/consent_screen.dart';

// Dependencies
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/profile.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

/// Helper to wrap a widget with ProfileProvider.
Widget buildWithProfileProvider(
  Widget child, {
  bool hasDebt = false,
  BudgetProvider? budgetProvider,
}) {
  final provider = ProfileProvider();
  provider.setProfile(Profile(
    id: 'test-profile-001',
    birthYear: 1990,
    canton: 'VD',
    householdType: HouseholdType.single,
    incomeNetMonthly: 6000,
    hasDebt: hasDebt,
    goal: Goal.other,
    createdAt: DateTime(2025, 1, 1),
  ));
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileProvider>.value(value: provider),
        if (budgetProvider != null)
          ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),
      ],
      child: child,
    ),
  );
}

/// Standard test answers for report screens (V2 / FinancialReportScreenV2).
/// Uses String for q_children as expected by ReportBuilder.
Map<String, dynamic> get testAnswersV2 => <String, dynamic>{
      'q_firstname': 'TestUser',
      'q_birth_year': 1990,
      'q_canton': 'VD',
      'q_civil_status': 'single',
      'q_children': '0',
      'q_employment_status': 'employee',
      'q_net_income_period_chf': 6000.0,
      'q_pay_frequency': 'monthly',
      'q_emergency_fund': 'yes_3months',
      'q_has_consumer_debt': 'no',
      'q_housing_status': 'renter',
      'q_housing_cost_period_chf': 1500.0,
      'q_has_pension_fund': 'yes',
      'q_3a_accounts_count': 1,
      'q_3a_providers': ['bank'],
      'q_3a_annual_contribution': 7258.0,
      'q_lpp_buyback_available': 0.0,
      'q_has_investments': 'no',
    };

void main() {
  // Ensure large viewport to avoid overflow errors in tests.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ===========================================================================
  // 4. FINANCIAL REPORT SCREEN V2
  // ===========================================================================
  group('FinancialReportScreenV2', () {
    testWidgets('renders without crashing', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: testAnswersV2),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(FinancialReportScreenV2), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows app bar with flash synthesis title', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: testAnswersV2),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Ton Bilan Flash'), findsWidgets);
    });

    testWidgets('labels icon-only app bar actions for accessibility',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          buildWithProfileProvider(
            FinancialReportScreenV2(wizardAnswers: testAnswersV2),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 5));

        final backAction = find.bySemanticsLabel('Retour');
        final exportAction = find.bySemanticsLabel('Exporter le bilan en PDF');
        expect(backAction, findsOneWidget);
        expect(exportAction, findsOneWidget);
        expect(
            tester.getSemantics(backAction).flagsCollection.isButton, isTrue);
        expect(
            tester.getSemantics(exportAction).flagsCollection.isButton, isTrue);
        expect(
          tester
              .getSemantics(backAction)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        expect(
          tester
              .getSemantics(exportAction)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('groups report sections for accessible traversal',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          buildWithProfileProvider(
            FinancialReportScreenV2(wizardAnswers: testAnswersV2),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 5));

        final synthesis = tester
            .getSemantics(find.byKey(const Key('report_synthesis_summary')));
        expect(synthesis.identifier, 'report_synthesis_summary');
        expect(synthesis.label, contains('Bilan Flash'));
        expect(synthesis.label, contains('VD'));

        final compliance = tester
            .getSemantics(find.byKey(const Key('report_compliance_summary')));
        expect(compliance.identifier, 'report_compliance_summary');
        expect(compliance.label, contains('Transparence'));
        expect(compliance.label, contains('Hypothèses'));
        expect(compliance.label, contains('Conflits'));
        expect(compliance.label, contains('Limitations'));

        final disclaimer = tester
            .getSemantics(find.byKey(const Key('report_disclaimer_summary')));
        expect(disclaimer.identifier, 'report_disclaimer_summary');
        expect(disclaimer.label, contains('Mention légale'));
        expect(disclaimer.label, contains('ne constitue pas'));
        expect(find.bySemanticsLabel('\u2022'), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('export action reports thrown PDF export failures',
        (tester) async {
      final previousPrintingPlatform = PrintingPlatform.instance;
      final printingPlatform =
          _CaptureSharePdfPrintingPlatform(failSharePdf: true);
      PrintingPlatform.instance = printingPlatform;
      addTearDown(() => PrintingPlatform.instance = previousPrintingPlatform);

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: testAnswersV2),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.widgetWithIcon(IconButton, Icons.share));
      for (var i = 0; i < 200 && printingPlatform.sharePdfCalls == 0; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(printingPlatform.sharePdfCalls, 1);
      expect(
        find.text(
          'Export PDF indisponible pour le moment. Réessaie depuis le bilan.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('export action shares a concrete PDF document', (tester) async {
      final previousPrintingPlatform = PrintingPlatform.instance;
      final printingPlatform = _CaptureSharePdfPrintingPlatform();
      PrintingPlatform.instance = printingPlatform;
      addTearDown(() => PrintingPlatform.instance = previousPrintingPlatform);

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: testAnswersV2),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.widgetWithIcon(IconButton, Icons.share));
      for (var i = 0; i < 30 && printingPlatform.sharePdfCalls == 0; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(printingPlatform.sharePdfCalls, 1);
      expect(printingPlatform.filename, 'mint_report_v2.pdf');
      expect(printingPlatform.bytes, isNotNull);
      expect(printingPlatform.bytes!.length, greaterThan(1024));
      expect(printingPlatform.bytes!.take(5), [37, 80, 68, 70, 45]); // %PDF-
    });

    testWidgets('displays synthesis header', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: testAnswersV2),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Bonjour'), findsNothing);
      expect(find.textContaining('Ton Bilan Flash'), findsWidgets);
      expect(find.textContaining('base'), findsWidgets);
    });

    testWidgets('renders synthesis instead of duplicated budget dashboard',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: testAnswersV2),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Ton Bilan Flash'), findsWidgets);
      expect(find.textContaining('Ton Budget'), findsNothing);
      expect(find.textContaining('constants_version'), findsNothing);
      expect(find.textContaining('lpp_conversion_rate'), findsNothing);
      expect(find.textContaining('avs_max_monthly'), findsNothing);
      expect(find.textContaining('pillar3a_max'), findsNothing);
    });

    testWidgets('keeps report assumptions income-status neutral',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final answers = Map<String, dynamic>.from(testAnswersV2)
        ..['q_employment_status'] = 'independant'
        ..['q_3a_annual_contribution'] = 5000.0;

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: answers),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.text('Plafond 3a selon affiliation LPP et statut de revenu'),
        findsOneWidget,
      );
      expect(find.textContaining('Plafond 3a salarié'), findsNothing);
      expect(find.textContaining('7’258'), findsNothing);
    });

    testWidgets('surfaces independent no-LPP guidance before generic 3a CTA',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final answers = Map<String, dynamic>.from(testAnswersV2)
        ..['q_employment_status'] = 'independant'
        ..['q_has_pension_fund'] = 'no'
        ..['q_emergency_fund'] = 'yes_6months'
        ..['q_has_consumer_debt'] = 'no'
        ..['q_3a_accounts_count'] = 0
        ..['q_3a_annual_contribution'] = 0.0
        ..['q_lpp_buyback_available'] = 0.0
        ..['q_avs_lacunes_status'] = 'no_gaps';

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: answers),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.text('Clarifier mon statut indépendant avant d’augmenter le 3a'),
        findsOneWidget,
      );
      expect(find.textContaining('statut AVS d’indépendant'), findsOneWidget);
      expect(find.textContaining('revenu net imposable'), findsOneWidget);
      expect(find.textContaining('couverture accident'), findsOneWidget);
      expect(find.textContaining('liquidité nécessaire'), findsOneWidget);
      expect(find.textContaining('revenus varient'), findsOneWidget);
      for (final fragment in [
        'Plafond 3a salarié',
        '7’258',
        'ouvrir',
        'Ouvre',
        'fintech',
        'UBS',
        'Raiffeisen',
        'Swiss Life',
        '60% actions',
      ]) {
        expect(find.textContaining(fragment), findsNothing, reason: fragment);
      }
    });

    testWidgets('keeps duplicated money sections out of rapport',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: testAnswersV2),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final synthesis = find.textContaining('Ton Bilan Flash').first;
      final cta = find.text('Commencer');
      expect(find.textContaining('Tes 3 Actions Prioritaires'), findsNothing);
      expect(synthesis, findsOneWidget);
      expect(cta, findsOneWidget);
      expect(find.textContaining('Ton Budget'), findsNothing);
    });

    testWidgets('rapport does not surface implausible captured budget amounts',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final answers = Map<String, dynamic>.from(testAnswersV2)
        ..['q_net_income_period_chf'] = 5379.0
        ..['q_housing_cost_period_chf'] = 19272200.0
        ..['q_lamal_premium_monthly_chf'] = 420420.0;

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: answers),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining("19'272'200"), findsNothing);
      expect(find.textContaining("420'420"), findsNothing);
      expect(find.textContaining("5'379"), findsNothing);
    });

    testWidgets('rapport leaves legacy budget income details to money screens',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final answers = Map<String, dynamic>.from(testAnswersV2)
        ..['q_net_income_period_chf'] = null
        ..['q_net_income_monthly'] = 5000.0
        ..['q_pay_frequency'] = 'yearly'
        ..['q_housing_cost_period_chf'] = 2200.0
        ..['q_tax_provision_monthly_chf'] = 458.0
        ..['q_lamal_premium_monthly_chf'] = 420.0
        ..['q_debt_payments_period_chf'] = 0.0
        ..['q_other_fixed_costs_monthly_chf'] = 0.0;

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: answers),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Ton Bilan Flash'), findsWidgets);
      expect(find.textContaining('Ton Budget'), findsNothing);
      expect(find.textContaining('Charges fixes totales'), findsNothing);
      expect(find.textContaining("5'000"), findsNothing);
      expect(find.textContaining("3'078"), findsNothing);
      expect(find.textContaining("1'922"), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rapport accepts BudgetProvider fallback without rendering it',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final budgetProvider = BudgetProvider();
      await budgetProvider.setInputs(
        const BudgetInputs(
          payFrequency: PayFrequency.monthly,
          netIncome: 5000.0,
          housingCost: 2200.0,
          debtPayments: 0.0,
          taxProvision: 458.0,
          healthInsurance: 420.0,
        ),
      );
      final answers = Map<String, dynamic>.from(testAnswersV2)
        ..remove('q_canton')
        ..remove('q_tax_provision_monthly_chf')
        ..['q_net_income_period_chf'] = null
        ..['q_pay_frequency'] = 'yearly'
        ..['q_housing_cost_period_chf'] = 2200.0
        ..['q_lamal_premium_monthly_chf'] = 420.0
        ..['q_debt_payments_period_chf'] = 0.0
        ..['q_other_fixed_costs_monthly_chf'] = 0.0;

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: answers),
          budgetProvider: budgetProvider,
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Ton Bilan Flash'), findsWidgets);
      expect(find.textContaining('Ton Budget'), findsNothing);
      expect(find.textContaining('Charges fixes totales'), findsNothing);
      expect(find.textContaining("5'000"), findsNothing);
      expect(find.textContaining("3'078"), findsNothing);
      expect(find.textContaining("1'922"), findsNothing);
      expect(find.textContaining("3'267"), findsNothing);
      expect(find.textContaining("1'733"), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rapport accepts canonical BudgetSnapshot without rendering it',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const snapshot = BudgetSnapshot(
        present: PresentBudget(
          monthlyNet: 5000.0,
          monthlyHousing: 2200.0,
          monthlyDebt: 0.0,
          monthlyTax: 458.0,
          monthlyHealth: 420.0,
          monthlyOtherFixed: 0.0,
          monthlyCharges: 3078.0,
          monthlySavings: 0.0,
          monthlyFree: 1922.0,
        ),
        capImpacts: [],
        stage: BudgetStage.presentOnly,
        confidenceScore: 80,
      );

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(
            wizardAnswers: testAnswersV2,
            budgetSnapshot: snapshot,
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Ton Bilan Flash'), findsWidgets);
      expect(find.textContaining('Ton Budget'), findsNothing);
      expect(find.textContaining('Charges fixes totales'), findsNothing);
      expect(find.textContaining("5'000"), findsNothing);
      expect(find.textContaining("3'078"), findsNothing);
      expect(find.textContaining("1'922"), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rapport keeps signed monthly deficit out of recap',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final answers = Map<String, dynamic>.from(testAnswersV2)
        ..['q_net_income_period_chf'] = 3000.0
        ..['q_housing_cost_period_chf'] = 2500.0
        ..['q_tax_provision_monthly_chf'] = 600.0
        ..['q_lamal_premium_monthly_chf'] = 420.0
        ..['q_debt_payments_period_chf'] = 0.0
        ..['q_other_fixed_costs_monthly_chf'] = 0.0;

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: answers),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Ton Budget'), findsNothing);
      expect(find.textContaining("CHF\u00a0-520"), findsNothing);
      expect(find.textContaining("CHF\u00a00"), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('safe-mode reasons accept persisted debt as numeric string',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final answers = Map<String, dynamic>.from(testAnswersV2)
        ..['q_debt_payments_period_chf'] = '150'
        ..['q_emergency_fund'] = 'yes_6months';

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: answers),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(FinancialReportScreenV2), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('priority action omits gain chip when fiscal impact is zero',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final answers = Map<String, dynamic>.from(testAnswersV2)
        ..['q_net_income_period_chf'] = 0.0
        ..['q_emergency_fund'] = 'yes_6months'
        ..['q_3a_accounts_count'] = 0
        ..['q_3a_annual_contribution'] = 0.0
        ..['q_lpp_buyback_available'] = 0.0;

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: answers),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(FinancialReportScreenV2), findsOneWidget);
      expect(find.textContaining('+CHF'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('retirement card accepts persisted AVS years as strings',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final answers = Map<String, dynamic>.from(testAnswersV2)
        ..['q_birth_year'] = '1990'
        ..['q_avs_lacunes_status'] = 'arrived_late'
        ..['q_avs_arrival_year'] = '2015'
        ..['q_avs_years_abroad'] = '3'
        ..['q_first_employment_year'] = '2012';

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: answers),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(FinancialReportScreenV2), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rapport leaves detailed 3a deductible room to 3a screens',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final answers = Map<String, dynamic>.from(testAnswersV2)
        ..['q_has_3a'] = 'no'
        ..['q_3a_accounts_count'] = 0
        ..['q_3a_annual_contribution'] = 0.0
        ..['q_gross_salary_annual'] = 84000.0;

      await tester.pumpWidget(
        buildWithProfileProvider(
          FinancialReportScreenV2(wizardAnswers: answers),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Ton Bilan Flash'), findsWidgets);
      expect(find.textContaining("CHF 7'258/an"), findsNothing);
      expect(find.textContaining("jusqu'à CHF 7"), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // 6. OPEN BANKING HUB SCREEN
  // ===========================================================================
  group('OpenBankingHubScreen', () {
    testWidgets('renders without crashing', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(OpenBankingHubScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows FINMA gate banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // i18n: openBankingFinmaGate with accents
      expect(find.textContaining('FINMA'), findsWidgets);
    });

    testWidgets('shows DEMO badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // i18n: demo mode label
      expect(find.textContaining('monstration'), findsWidgets);
    });

    testWidgets('displays Open Banking header', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Open Banking'), findsWidgets);
    });

    testWidgets('shows connected accounts section title', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('COMPTES CONNECTES'), findsOneWidget);
      expect(find.text('APERCU FINANCIER'), findsOneWidget);
    });

    testWidgets('displays mock bank accounts', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Should show mock bank names in account cards
      expect(find.textContaining('UBS'), findsWidgets);
      expect(find.textContaining('PostFinance'), findsWidgets);
    });

    testWidgets('shows bLink badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('bLink'), findsOneWidget);
    });

    testWidgets('has disclaimer section', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: OpenBankingHubScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.textContaining('consultation'),
        findsWidgets,
      );
    });
  });

  // ===========================================================================
  // 7. TRANSACTION LIST SCREEN
  // ===========================================================================
  group('TransactionListScreen', () {
    testWidgets('renders without crashing', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(TransactionListScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows FINMA gate banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('FINMA'), findsWidgets);
    });

    testWidgets('shows DEMO badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('monstration'), findsWidgets);
    });

    testWidgets('shows TRANSACTIONS title in app bar', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('ransaction'), findsWidgets);
    });

    testWidgets('displays period selector', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('mois'), findsWidgets);
    });

    testWidgets('shows category filters', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Toutes'), findsOneWidget);
    });

    testWidgets('displays monthly summary section', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // The monthly summary is far down the scroll; check it exists in the tree
      expect(find.textContaining('ynth'), findsWidgets);
    });

    testWidgets('has disclaimer section', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: TransactionListScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.textContaining('consultation'),
        findsWidgets,
      );
    });
  });

  // ===========================================================================
  // 8. CONSENT SCREEN
  // ===========================================================================
  group('ConsentScreen', () {
    testWidgets('renders without crashing', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(ConsentScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows FINMA gate banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('FINMA'), findsWidgets);
    });

    testWidgets('shows CONSENTEMENTS title in app bar', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('onsentement'), findsWidgets);
    });

    testWidgets('displays active consents section', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('CONSENTEMENTS ACTIFS'), findsOneWidget);
    });

    testWidgets('displays consent cards with bank names', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Mock consents include UBS, PostFinance, Raiffeisen
      expect(find.text('UBS'), findsOneWidget);
      expect(find.text('PostFinance'), findsOneWidget);
      expect(find.text('Raiffeisen'), findsOneWidget);
    });

    testWidgets('shows revocation buttons for active consents', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // All 3 mock consents are active, so 3 revoke buttons
      expect(find.textContaining('voquer'), findsWidgets);
    });

    testWidgets('shows nLPD info card', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Tes droits (nLPD)'), findsOneWidget);
    });

    testWidgets('has add consent button', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Ajouter un consentement'), findsOneWidget);
    });

    testWidgets('has disclaimer section', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.textContaining('consultation'),
        findsWidgets,
      );
    });

    testWidgets('shows scope labels on consent cards', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConsentScreen(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Autorisations'), findsWidgets);
      expect(find.text('Comptes'), findsWidgets);
      expect(find.text('Soldes'), findsWidgets);
    });
  });
}

class _CaptureSharePdfPrintingPlatform extends PrintingPlatform {
  _CaptureSharePdfPrintingPlatform({this.failSharePdf = false});

  final bool failSharePdf;
  int sharePdfCalls = 0;
  Uint8List? bytes;
  String? filename;

  @override
  Future<PrintingInfo> info() async => PrintingInfo.unavailable;

  @override
  Future<bool> layoutPdf(
    Printer? printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
    bool dynamicLayout,
    bool usePrinterSettings,
    OutputType outputType,
    bool forceCustomPrintPaper,
  ) async =>
      true;

  @override
  Future<List<Printer>> listPrinters() async => [];

  @override
  Future<Printer?> pickPrinter(Rect bounds) async => null;

  @override
  Future<bool> sharePdf(
    Uint8List bytes,
    String filename,
    Rect bounds,
    String? subject,
    String? body,
    List<String>? emails,
  ) async {
    sharePdfCalls += 1;
    if (failSharePdf) {
      throw Exception('PDF share unavailable in test');
    }
    this.bytes = bytes;
    this.filename = filename;
    return true;
  }

  @override
  Future<Uint8List> convertHtml(
    String html,
    String? baseUrl,
    PdfPageFormat format,
  ) async =>
      Uint8List(0);

  @override
  Stream<PdfRaster> raster(
    Uint8List document,
    List<int>? pages,
    double dpi,
  ) async* {}
}
