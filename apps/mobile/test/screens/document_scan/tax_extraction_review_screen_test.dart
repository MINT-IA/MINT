import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/biography_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/screens/document_scan/extraction_review_screen.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/feature_flags.dart';

const _snapshotId = '11111111-1111-4111-8111-111111111111';

class _CoachProfileSpy extends CoachProfileProvider {
  int acceptTaxReviewCalls = 0;
  TaxReviewConfirmation? acceptedConfirmation;

  @override
  Future<void> acceptTaxReview(TaxReviewConfirmation confirmation) async {
    acceptTaxReviewCalls += 1;
    acceptedConfirmation = confirmation;
  }
}

class _BiographySpy extends BiographyProvider {
  int addFactCalls = 0;

  @override
  Future<void> addFact(BiographyFact fact) async {
    addFactCalls += 1;
  }
}

class _ExternalSyncSpy {
  int calls = 0;

  Future<void> call({
    required String documentType,
    required List<Map<String, dynamic>> confirmedFields,
    required double overallConfidence,
  }) async {
    calls += 1;
  }
}

ExtractionResult _taxExtraction() => const ExtractionResult(
      documentType: DocumentType.taxDeclaration,
      fields: [
        ExtractedField(
          fieldName: 'revenu_imposable',
          label: 'Revenu imposable à vérifier',
          value: 98000.0,
          confidence: 0.72,
          sourceText: 'PII-NEVER-SEND',
          needsReview: true,
        ),
      ],
      overallConfidence: 0.72,
      confidenceDelta: 0,
      warnings: [],
      disclaimer: 'Fixture synthétique.',
      sources: [],
    );

TaxExtractionCandidate _candidate(ExtractionResult extraction) =>
    TaxExtractionCandidate.fromExtractionResult(
      extraction,
      snapshotIdFactory: () => _snapshotId,
    );

class _ReviewHarness {
  const _ReviewHarness({
    required this.widget,
    required this.scanSessionId,
  });

  final Widget widget;
  final String scanSessionId;
}

_ReviewHarness _harness({
  required ExtractionResult extraction,
  required TaxExtractionCandidate candidate,
  required _CoachProfileSpy coachProfile,
  required _BiographySpy biography,
  required _ExternalSyncSpy externalSync,
}) {
  final scanSessions = ScanSessionProvider();
  final scanSessionId = scanSessions.retainExtraction(extraction);
  final router = GoRouter(
    initialLocation: '/review',
    routes: [
      GoRoute(
        path: '/review',
        builder: (_, __) => ExtractionReviewScreen(
          scanSessionId: scanSessionId,
          result: extraction,
          taxCandidate: candidate,
          sendScanConfirmation: externalSync.call,
        ),
      ),
      GoRoute(
        path: '/scan/impact',
        builder: (_, __) => const Scaffold(body: Text('impact')),
      ),
    ],
  );

  return _ReviewHarness(
    scanSessionId: scanSessionId,
    widget: MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(value: coachProfile),
        ChangeNotifierProvider<BiographyProvider>.value(value: biography),
        ChangeNotifierProvider<ScanSessionProvider>.value(value: scanSessions),
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
    ),
  );
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _choose(
  WidgetTester tester, {
  required String controlKey,
  required String optionKey,
}) async {
  await _tapKey(tester, controlKey);
  await _tapKey(tester, optionKey);
}

Future<void> _enter(
  WidgetTester tester, {
  required String controlKey,
  required String value,
}) async {
  final finder = find.byKey(Key(controlKey));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pump();
}

void main() {
  setUp(() {
    FeatureFlags.typedTaxProfile = false;
  });

  tearDown(() {
    FeatureFlags.typedTaxProfile = false;
  });

  testWidgets('typed-tax flag off fails closed at the live confirmation CTA',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final extraction = _taxExtraction();
    final coachProfile = _CoachProfileSpy();
    final biography = _BiographySpy();
    final externalSync = _ExternalSyncSpy();
    final harness = _harness(
      extraction: extraction,
      candidate: _candidate(extraction),
      coachProfile: coachProfile,
      biography: biography,
      externalSync: externalSync,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _tapKey(tester, 'tax_review_confirm_cta');

    expect(coachProfile.acceptTaxReviewCalls, 0);
    expect(biography.addFactCalls, 0);
    expect(
      externalSync.calls,
      0,
      reason: 'tax OCR and facts must cross neither backend nor LLM boundary',
    );
  });

  testWidgets(
      'typed review carries user-corrected metadata once and remains local-only',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FeatureFlags.typedTaxProfile = true;

    final extraction = _taxExtraction();
    final candidate = _candidate(extraction);
    final coachProfile = _CoachProfileSpy();
    final biography = _BiographySpy();
    final externalSync = _ExternalSyncSpy();
    final harness = _harness(
      extraction: extraction,
      candidate: candidate,
      coachProfile: coachProfile,
      biography: biography,
      externalSync: externalSync,
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await _choose(
      tester,
      controlKey: 'tax_review_document_kind',
      optionKey: 'tax_review_document_kind_assessment_notice',
    );
    await _choose(
      tester,
      controlKey: 'tax_review_assessment_status',
      optionKey: 'tax_review_assessment_status_assessed_appealable',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_tax_year',
      value: '2025',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_source_date',
      value: '2026-06-20',
    );
    await _choose(
      tester,
      controlKey: 'tax_review_subject_scope',
      optionKey: 'tax_review_subject_scope_jointly_assessed_couple',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_canton_code',
      value: 'VD',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_municipality_id',
      value: '5586',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_municipality_label',
      value: 'Lausanne',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_cantonal_communal_taxable_income_chf',
      value: '98500',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_federal_taxable_income_chf',
      value: '96200',
    );
    await _enter(
      tester,
      controlKey: 'tax_review_cantonal_communal_assessed_tax_chf',
      value: '14520',
    );
    await _choose(
      tester,
      controlKey: 'tax_review_authority_scope',
      optionKey: 'tax_review_authority_scope_cantonal_communal_combined',
    );
    await _choose(
      tester,
      controlKey: 'tax_review_base_scope',
      optionKey: 'tax_review_base_scope_income_and_wealth',
    );

    await _tapKey(tester, 'tax_review_confirm_cta');

    expect(coachProfile.acceptTaxReviewCalls, 1);
    final confirmation = coachProfile.acceptedConfirmation!;
    expect(confirmation.candidate, same(candidate));
    expect(
      confirmation.candidate.snapshotId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(confirmation.candidate.snapshotId, isNot(harness.scanSessionId));
    expect(confirmation.documentKind, TaxDocumentKind.assessmentNotice);
    expect(
      confirmation.assessmentStatus,
      TaxAssessmentStatus.assessedAppealable,
    );
    expect(confirmation.taxYear, 2025);
    expect(confirmation.sourceDate, DateTime.utc(2026, 6, 20));
    expect(
      confirmation.subjectScope,
      TaxSubjectScope.jointlyAssessedCouple,
    );
    expect(confirmation.cantonCode, 'VD');
    expect(confirmation.municipalityId, '5586');
    expect(confirmation.municipalityLabel, 'Lausanne');
    expect(confirmation.cantonalCommunalTaxableIncomeChf, 98500);
    expect(confirmation.federalTaxableIncomeChf, 96200);
    expect(confirmation.cantonalCommunalAssessedTax?.amountChf, 14520);
    expect(
      confirmation.cantonalCommunalAssessedTax?.authorityScope,
      TaxAuthorityScope.cantonalCommunalCombined,
    );
    expect(
      confirmation.cantonalCommunalAssessedTax?.baseScope,
      TaxBaseScope.incomeAndWealth,
    );
    expect(biography.addFactCalls, 0);
    expect(
      externalSync.calls,
      0,
      reason: 'confirmed tax facts remain local; sourceText is never sent',
    );
  });
}
