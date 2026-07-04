import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/financial_report.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/screens/advisor/financial_report_screen_v2.dart';
import 'package:mint_mobile/screens/advisor/report_route_screen.dart';
import 'package:mint_mobile/services/dossier/dossier_payload_service.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('loads rapport from persisted answers without route extra',
      (tester) async {
    Map<String, dynamic>? savedAnswers;

    await tester.pumpWidget(
      _wrap(
        ReportRouteScreen(
          loadAnswers: () async => _answersWithoutOwner,
          resolveOwnerId: () async => 'local_demo_report_route_owner',
          saveAnswers: (answers) async {
            savedAnswers = Map<String, dynamic>.from(answers);
          },
          timeout: const Duration(seconds: 2),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(FinancialReportScreenV2), findsOneWidget);
    final report = tester.widget<FinancialReportScreenV2>(
      find.byType(FinancialReportScreenV2),
    );
    expect(
      report.wizardAnswers['_coach_profile_owner_id'],
      'local_demo_report_route_owner',
    );
    expect(savedAnswers?['_coach_profile_owner_id'],
        'local_demo_report_route_owner');
    final context = tester.element(find.byType(ReportRouteScreen));
    expect(find.text(S.of(context)!.reportTonPlanMint), findsOneWidget);
  });

  testWidgets('resolves and persists pending local owner before dossier build',
      (tester) async {
    Map<String, dynamic>? savedAnswers;

    await tester.pumpWidget(
      _wrap(
        ReportRouteScreen(
          loadAnswers: () async => _answersWithPendingOwner,
          resolveOwnerId: () async => 'local_demo_report_route_owner',
          saveAnswers: (answers) async {
            savedAnswers = Map<String, dynamic>.from(answers);
          },
          timeout: const Duration(seconds: 2),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final report = tester.widget<FinancialReportScreenV2>(
      find.byType(FinancialReportScreenV2),
    );
    expect(
      report.wizardAnswers['_coach_profile_owner_id'],
      'local_demo_report_route_owner',
    );
    expect(savedAnswers?['_coach_profile_owner_id'],
        'local_demo_report_route_owner');
    expect(_findSemanticsIdentifier('report_dossier_transmit_property_card'),
        findsOneWidget);
  });

  testWidgets('copies valid legacy owner without resolving a new one',
      (tester) async {
    var resolverCalled = false;
    Map<String, dynamic>? savedAnswers;

    await tester.pumpWidget(
      _wrap(
        ReportRouteScreen(
          loadAnswers: () async => _answersWithLegacyOwner,
          resolveOwnerId: () async {
            resolverCalled = true;
            return 'local_demo_should_not_be_used';
          },
          saveAnswers: (answers) async {
            savedAnswers = Map<String, dynamic>.from(answers);
          },
          timeout: const Duration(seconds: 2),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final report = tester.widget<FinancialReportScreenV2>(
      find.byType(FinancialReportScreenV2),
    );
    expect(resolverCalled, isFalse);
    expect(report.wizardAnswers['_coach_profile_owner_id'],
        'local_demo_legacy_owner');
    expect(savedAnswers?['_coach_profile_owner_id'], 'local_demo_legacy_owner');
  });

  testWidgets('direct report screen defers dossiers until owner is resolved',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        FinancialReportScreenV2(
          wizardAnswers: _answersWithPendingOwner,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(FinancialReportScreenV2));
    expect(find.text(S.of(context)!.reportTonPlanMint), findsOneWidget);
    expect(_findSemanticsIdentifier('report_dossier_first_salary_tax_card'),
        findsNothing);
    expect(_findSemanticsIdentifier('report_dossier_buy_property_card'),
        findsNothing);
    expect(_findSemanticsIdentifier('report_dossier_transmit_property_card'),
        findsNothing);
  });

  testWidgets('times out to retryable error instead of a permanent spinner',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        ReportRouteScreen(
          loadAnswers: () => Completer<Map<String, dynamic>>().future,
          timeout: const Duration(milliseconds: 1),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump();

    final context = tester.element(find.byType(ReportRouteScreen));
    expect(
      find.text(S.of(context)!.financialReportLoadErrorTitle),
      findsOneWidget,
    );
    expect(find.text(S.of(context)!.commonRetry), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('error back button falls back to home', (tester) async {
    final router = GoRouter(
      initialLocation: '/rapport',
      routes: [
        GoRoute(
          path: '/rapport',
          builder: (_, __) => ReportRouteScreen(
            loadAnswers: () => Completer<Map<String, dynamic>>().future,
            timeout: const Duration(milliseconds: 1),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('home destination')),
        ),
      ],
    );

    await tester.pumpWidget(_wrapRouter(router));
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(find.text('home destination'), findsOneWidget);
  });

  testWidgets('priority 3a action exposes a stable id and reaches 3a',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final router = GoRouter(
      initialLocation: '/rapport',
      routes: [
        GoRoute(
          path: '/rapport',
          builder: (_, __) => const FinancialReportScreenV2(
            wizardAnswers: _answers,
          ),
        ),
        GoRoute(
          path: '/pilier-3a',
          builder: (_, __) =>
              const Scaffold(body: Text('pilier3a destination')),
        ),
        GoRoute(
          path: '/budget',
          builder: (_, __) => const Scaffold(body: Text('budget destination')),
        ),
        GoRoute(
          path: '/coach/chat',
          builder: (_, __) => const Scaffold(body: Text('coach destination')),
        ),
      ],
    );

    await tester.pumpWidget(_wrapRouter(router));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final cta = _findSemanticsIdentifier('report_action_pillar3a_cta');
    expect(_findSemanticsIdentifier('report_action_pillar3a_card'),
        findsOneWidget);
    expect(cta, findsOneWidget);

    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(find.text('pilier3a destination'), findsOneWidget);
  });

  testWidgets('PDF export CTA invokes the report exporter', (tester) async {
    FinancialReport? exportedReport;

    await tester.pumpWidget(
      _wrap(
        FinancialReportScreenV2(
          wizardAnswers: _answers,
          exportPdf: (report) async {
            exportedReport = report;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final exportCta = _findSemanticsIdentifier('report_export_pdf_cta');
    expect(exportCta, findsOneWidget);

    await tester.tap(exportCta);
    await tester.pumpAndSettle();

    expect(exportedReport, isNotNull);
    expect(exportedReport!.profile.canton, 'VD');
    expect(exportedReport!.priorityActions, isNotEmpty);
  });

  testWidgets('typed dossier export CTA invokes the dossier exporter',
      (tester) async {
    final exportedDossierIds = <String>[];
    DossierPayload? lastExportedDossier;
    List<int>? lastPdfBytes;

    await tester.pumpWidget(
      _wrap(
        FinancialReportScreenV2(
          wizardAnswers: _answers,
          exportDossierPdf: (dossier) async {
            final errors = _schemaErrors(dossier.caseId, dossier.toJson());
            expect(errors, isEmpty);
            final bytes = await PdfService.buildDossierPayloadPdfBytes(
              dossier,
              compress: false,
            );
            expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
            expect(latin1.decode(bytes, allowInvalid: true), contains('%%EOF'));
            exportedDossierIds.add(dossier.caseId);
            lastExportedDossier = dossier;
            lastPdfBytes = bytes;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    const expectedDossiers = [
      (
        caseId: 'first_salary_tax',
        cardId: 'report_dossier_first_salary_tax_card',
        exportId: 'report_dossier_first_salary_tax_export_cta',
      ),
      (
        caseId: 'buy_property',
        cardId: 'report_dossier_buy_property_card',
        exportId: 'report_dossier_buy_property_export_cta',
      ),
      (
        caseId: 'transmit_property',
        cardId: 'report_dossier_transmit_property_card',
        exportId: 'report_dossier_transmit_property_export_cta',
      ),
    ];

    for (final expected in expectedDossiers) {
      expect(_findSemanticsIdentifier(expected.cardId), findsOneWidget);
      expect(_findSemanticsIdentifier(expected.exportId), findsOneWidget);
    }

    for (final expected in expectedDossiers) {
      final exportCta = _findSemanticsIdentifier(expected.exportId);
      await tester.ensureVisible(exportCta);
      await tester.tap(exportCta);
      await tester.pumpAndSettle();
    }

    expect(exportedDossierIds,
        ['first_salary_tax', 'buy_property', 'transmit_property']);
    expect(lastExportedDossier, isNotNull);
    expect(lastExportedDossier!.caseId, 'transmit_property');
    expect(lastExportedDossier!.pdfSectionId, 'dossier_transmit_property');
    expect(lastExportedDossier!.nextQuestions, isNotEmpty);
    expect(lastPdfBytes, isNotNull);
    expect(lastPdfBytes!.length, greaterThan(1000));
  });

  testWidgets('PDF export failure shows a recoverable snackbar',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        FinancialReportScreenV2(
          wizardAnswers: _answers,
          exportPdf: (_) async => throw StateError('share failed'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(FinancialReportScreenV2));
    await tester.tap(_findSemanticsIdentifier('report_export_pdf_cta'));
    await tester.pump();

    expect(
      find.text(S.of(context)!.financialReportExportError),
      findsOneWidget,
    );
  });
}

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => ProfileProvider(),
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: child,
    ),
  );
}

Widget _wrapRouter(GoRouter router) {
  return ChangeNotifierProvider(
    create: (_) => ProfileProvider(),
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

Finder _findSemanticsIdentifier(String identifier) {
  return find.bySemanticsIdentifier(identifier);
}

List<String> _schemaErrors(String caseId, Map<String, dynamic> payload) {
  final schema = jsonDecode(
    File('../../docs/codex/dossier_stubs/dossier_$caseId.schema.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  return DossierPayloadSchemaValidator.validateJsonAgainstSchema(
    payload: payload,
    schema: schema,
  );
}

const _answers = <String, dynamic>{
  '_coach_profile_owner_id': 'local_demo_fixture_owner',
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

final _answersWithoutOwner = Map<String, dynamic>.from(_answers)
  ..remove('_coach_profile_owner_id');

final _answersWithPendingOwner = Map<String, dynamic>.from(_answers)
  ..['_coach_profile_owner_id'] = 'local_demo_pending';

final _answersWithLegacyOwner = Map<String, dynamic>.from(_answers)
  ..['_coach_profile_owner_id'] = 'local_demo_pending'
  ..['_profile_owner_id'] = 'local_demo_legacy_owner';
