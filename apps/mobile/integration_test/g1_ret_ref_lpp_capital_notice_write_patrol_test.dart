import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/screens/document_scan/document_impact_screen.dart';
import 'package:mint_mobile/screens/document_scan/document_scan_screen.dart';
import 'package:mint_mobile/screens/document_scan/extraction_review_screen.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/g1_ret_ref_lpp_capital_notice_runtime_contract.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
const _backendDocumentId = '81818181-8181-4181-8181-818181818181';
const _numericAcquisitionId = '61616161-6161-4161-8161-616161616161';
const _numericMarker = '%PDF-1.7 MINT synthetic numeric LPP runtime bytes only';
const _planMarker = '%PDF-1.7 MINT synthetic LPP plan runtime bytes only';
final _runtimeNow = DateTime.now().toUtc();
final _sourceDate = DateTime.utc(
  _runtimeNow.subtract(const Duration(days: 1)).year,
  _runtimeNow.subtract(const Duration(days: 1)).month,
  _runtimeNow.subtract(const Duration(days: 1)).day,
);
final _deadlineDate = DateTime.utc(
  _runtimeNow.add(const Duration(days: 30)).year,
  _runtimeNow.add(const Duration(days: 30)).month,
  _runtimeNow.add(const Duration(days: 30)).day,
);

String _civilDate(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

List<Map<String, dynamic>> _syntheticFields() => <Map<String, dynamic>>[
      <String, dynamic>{
        'fieldName': 'avoirLppTotal',
        'value': 143287.50,
        'confidence': 'high',
        'sourceText': '',
      },
      <String, dynamic>{
        'fieldName': 'salaireAssure',
        'value': 72540,
        'confidence': 'high',
        'sourceText': '',
      },
    ];

final class _RuntimeLedger extends CoachProfileProvider {
  _RuntimeLedger({
    required this.events,
    required DateTime Function() now,
    required SessionEpoch sessionEpoch,
  }) : super(now: now, sessionEpoch: sessionEpoch);

  final List<String> events;

  @override
  Future<LppRegulationReceipt> acceptLppRegulationReference(
    LppRegulationReviewConfirmation confirmation,
  ) async {
    events.add('accept_regulation');
    return super.acceptLppRegulationReference(confirmation);
  }

  @override
  Future<LppCapitalNoticeReceipt> acceptLppCapitalNotice(
    LppCapitalNoticeReviewConfirmation confirmation,
  ) async {
    events.add('accept_capital');
    return super.acceptLppCapitalNotice(confirmation);
  }
}

final class _RuntimeDocuments extends DocumentProvider {
  _RuntimeDocuments({
    required this.events,
    required DateTime Function() now,
    required SessionEpoch sessionEpoch,
  }) : super(now: now, sessionEpoch: sessionEpoch);

  final List<String> events;

  @override
  Future<ConfirmedDocumentReference> recordLppRegulation(
    LppRegulationReceipt receipt,
  ) async {
    events.add('record_regulation');
    return super.recordLppRegulation(receipt);
  }

  @override
  Future<ConfirmedDocumentReference> recordLppCapitalNotice(
    LppCapitalNoticeReceipt receipt,
  ) async {
    events.add('record_capital');
    return super.recordLppCapitalNotice(receipt);
  }
}

GoRouter _router({
  required ScanSessionProvider scanSessions,
  required File syntheticPlan,
  required List<List<ConsentPurpose>> consentCalls,
  required List<VaultDocumentType> uploadCalls,
}) =>
    GoRouter(
      initialLocation: '/scan?type=lppCertificate',
      routes: <RouteBase>[
        GoRoute(
          path: '/scan',
          builder: (context, state) {
            final requestedType = state.uri.queryParameters['type'];
            final initialType = DocumentType.values.firstWhere(
              (type) => type.name == requestedType,
              orElse: () => DocumentType.lppCertificate,
            );
            return DocumentScanScreen(
              initialType: initialType,
              lppAcquisitionIdFactory: () => _numericAcquisitionId,
              now: () => _runtimeNow,
              requireConsent: (_, purposes) async {
                if (initialType == DocumentType.lppPlan) {
                  expect(
                    purposes,
                    const <ConsentPurpose>[ConsentPurpose.visionExtraction],
                  );
                }
                consentCalls.add(List<ConsentPurpose>.of(purposes));
                return true;
              },
              pickFile: () async {
                if (initialType == DocumentType.lppPlan) {
                  return PlatformFile(
                    name: 'mint-synthetic-lpp-plan.pdf',
                    path: syntheticPlan.path,
                    size: await syntheticPlan.length(),
                  );
                }
                final bytes = Uint8List.fromList(utf8.encode(_numericMarker));
                return PlatformFile(
                  name: 'mint-synthetic-numeric-lpp.pdf',
                  size: bytes.length,
                  bytes: bytes,
                );
              },
              writeOwnedTempFile: (file, bytes) async {
                await file.writeAsBytes(bytes, flush: true);
              },
              visionExtractor: ({
                required imageBase64,
                required documentType,
                canton,
                languageHint,
                subjectKind,
                receiptId,
              }) async {
                expect(utf8.decode(base64Decode(imageBase64)), _numericMarker);
                expect(documentType, 'lpp_certificate');
                expect(subjectKind, isNull);
                expect(receiptId, isNull);
                return <String, dynamic>{
                  'overallConfidence': 0.99,
                  'extractedFields': _syntheticFields(),
                };
              },
              uploadDocument: (file, {required type}) async {
                expect(type, VaultDocumentType.lppPlan);
                expect(await file.readAsString(), _planMarker);
                uploadCalls.add(type);
                final upload = DocumentUploadResult.fromJson(
                  <String, dynamic>{
                    'id': _backendDocumentId,
                    'document_type': 'lpp_plan',
                    'extracted_fields': <String, dynamic>{},
                    'confidence': 0,
                    'fields_found': 0,
                    'fields_total': 0,
                    'warnings': <String>[],
                    'rag_indexed': false,
                  },
                );
                expect(upload.isExactLppPlanAuthority, isTrue);
                return upload;
              },
            );
          },
        ),
        GoRoute(
          path: '/scan/review',
          builder: (context, state) {
            final scanSessionId = state.uri.queryParameters['scanSessionId'];
            final payload = scanSessions.byId(scanSessionId);
            if (scanSessionId == null || payload == null) {
              throw StateError('Missing volatile LPP review');
            }
            return ExtractionReviewScreen(
              scanSessionId: scanSessionId,
              result: payload.extraction,
              lppCandidate: payload.lppCandidate,
              lppAuthorization: payload.lppAuthorization,
              lppRegulationCandidate: payload.lppRegulationCandidate,
              lppCapitalNoticeCandidate: payload.lppCapitalNoticeCandidate,
              now: () => _runtimeNow,
            );
          },
        ),
        GoRoute(
          path: '/scan/impact',
          builder: (context, state) {
            final scanSessionId = state.uri.queryParameters['scanSessionId'];
            final payload = scanSessions.byId(scanSessionId);
            if (scanSessionId == null || payload?.previousConfidence == null) {
              throw StateError('Missing synthetic numeric LPP impact');
            }
            return DocumentImpactScreen(
              scanSessionId: scanSessionId,
              result: payload!.extraction,
              previousConfidence: payload.previousConfidence!,
            );
          },
        ),
        GoRoute(
          path: '/retraite',
          builder: (context, state) => const RetirementDashboardScreen(),
        ),
      ],
    );

Widget _app({
  required GoRouter router,
  required CoachProfileProvider ledger,
  required DocumentProvider documents,
  required ScanSessionProvider scanSessions,
  required SessionEpoch sessionEpoch,
}) =>
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<CoachProfileProvider>.value(value: ledger),
        ChangeNotifierProvider<DocumentProvider>.value(value: documents),
        ChangeNotifierProvider<ScanSessionProvider>.value(value: scanSessions),
        ChangeNotifierProvider<ByokProvider>(
          create: (_) => ByokProvider(sessionEpoch: sessionEpoch),
        ),
        ChangeNotifierProvider<SlmProvider>(create: (_) {
          final slm = SlmProvider();
          slm.init();
          return slm;
        }),
      ],
      child: MaterialApp.router(
        locale: const Locale('fr'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        routerConfig: router,
      ),
    );

void main() {
  patrolTest(
    'acquires numeric self LPP then one capital notice through native UI',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 8)),
    ($) async {
      FeatureFlags.typedLppEvidence = true;
      FeatureFlags.documentLppEvidenceEnabled = true;
      FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;
      FeatureFlags.lppRegulationReferenceEnabled = true;
      addTearDown(() {
        FeatureFlags.typedLppEvidence = false;
        FeatureFlags.documentLppEvidenceEnabled = false;
        FeatureFlags.lppCapitalNoticeDeadlineEnabled = false;
        FeatureFlags.lppRegulationReferenceEnabled = false;
      });

      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(g1LppCapitalNoticeWriterPidKey);
      await ReportPersistenceService.clearDiagnostic();
      await DocumentReferenceStore().save(const <ConfirmedDocumentReference>[]);
      await ReportPersistenceService.saveAnswers(<String, dynamic>{
        'q_birth_year': 1980,
        'q_canton': 'VD',
        'q_civil_status': 'celibataire',
        'q_has_pension_fund': 'yes',
      });
      await ReportPersistenceService.setMiniOnboardingCompleted(true);

      final syntheticDirectory =
          await Directory.systemTemp.createTemp('mint-lpp-capital-runtime-');
      final syntheticPlan = File('${syntheticDirectory.path}/regulation.pdf');
      await syntheticPlan.writeAsString(_planMarker, flush: true);
      addTearDown(() async {
        if (await syntheticDirectory.exists()) {
          await syntheticDirectory.delete(recursive: true);
        }
      });

      final sessionEpoch = SessionEpoch();
      final events = <String>[];
      final ledger = _RuntimeLedger(
        events: events,
        now: () => _runtimeNow,
        sessionEpoch: sessionEpoch,
      );
      final documents = _RuntimeDocuments(
        events: events,
        now: () => _runtimeNow,
        sessionEpoch: sessionEpoch,
      )..bindLedger(ledger);
      final scanSessions = ScanSessionProvider(sessionEpoch: sessionEpoch);
      final consentCalls = <List<ConsentPurpose>>[];
      final uploadCalls = <VaultDocumentType>[];
      final router = _router(
        scanSessions: scanSessions,
        syntheticPlan: syntheticPlan,
        consentCalls: consentCalls,
        uploadCalls: uploadCalls,
      );
      addTearDown(ledger.dispose);
      addTearDown(documents.dispose);
      addTearDown(scanSessions.dispose);
      addTearDown(router.dispose);

      await ledger.loadFromWizard();
      await documents.hydrateReferences();
      await $.pumpWidgetAndSettle(
        _app(
          router: router,
          ledger: ledger,
          documents: documents,
          scanSessions: scanSessions,
          sessionEpoch: sessionEpoch,
        ),
      );

      await $(#document_scan_lpp_type_selector).waitUntilVisible();
      expect(
        find.bySemanticsIdentifier('document_scan_lpp_example_cta'),
        findsOneWidget,
      );
      await $(#document_scan_gallery_cta).scrollTo().tap();
      await $(#lpp_acquisition_self_continue).waitUntilVisible();
      await $(#lpp_acquisition_self_continue).tap();
      await $(#lpp_review_source_date).waitUntilVisible();
      await $(#lpp_review_source_date).enterText(_civilDate(_sourceDate));
      await $(#lpp_review_confirm_cta).scrollTo().tap();
      await $(#lpp_impact_retirement_cta).scrollTo().tap();
      await $.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/retraite');

      final numericSnapshot = LppEvidenceSelector.selectSelf(
        ledger.reportAnswersSnapshot['_coach_lpp_evidence_v1'],
        now: () => _runtimeNow,
      );
      expect(numericSnapshot, isNotNull);
      if (numericSnapshot == null) fail('Missing numeric self LPP snapshot');
      expect(numericSnapshot.facts.keys.toSet(), <LppEvidenceFactKey>{
        LppEvidenceFactKey.vestedBenefitsCapitalChf,
        LppEvidenceFactKey.insuredSalaryAnnualChf,
      });

      router.go('/scan?type=lppPlan');
      await $.pumpAndSettle();
      await $(#document_scan_lpp_plan_type_selector).waitUntilVisible();
      await $(#document_scan_gallery_cta).scrollTo().tap();
      await $(#lpp_regulation_review_source_date).waitUntilVisible();

      expect(
        consentCalls.last,
        const <ConsentPurpose>[ConsentPurpose.visionExtraction],
      );
      expect(uploadCalls, const <VaultDocumentType>[VaultDocumentType.lppPlan]);
      final routeUri = router.routeInformationProvider.value.uri;
      expect(routeUri.queryParameters.keys, const <String>{'scanSessionId'});
      final scanSessionId = routeUri.queryParameters['scanSessionId'];
      expect(scanSessionId, isNotNull);
      final retained = scanSessions.byId(scanSessionId);
      expect(retained, isNotNull);
      if (retained == null) fail('Missing volatile capital notice candidate');
      expect(retained.lppRegulationCandidate, isNotNull);
      expect(retained.lppCapitalNoticeCandidate, isNotNull);
      expect(
        retained.lppCapitalNoticeCandidate!.expectedSnapshotId,
        numericSnapshot.snapshotId,
      );
      expect(retained.extraction.documentType, DocumentType.lppPlan);
      expect(retained.extraction.fields, isEmpty);

      await $(#lpp_regulation_review_source_date).enterText(
        _civilDate(_sourceDate),
      );
      await $(#lpp_regulation_review_legal_year).enterText(
        '${_sourceDate.year}',
      );
      await $(#lpp_regulation_fund_relation_current).scrollTo().tap();
      await $(#lpp_capital_notice_deadline_question).waitUntilVisible();
      await $(#lpp_capital_notice_deadline_field).enterText(
        _civilDate(_deadlineDate),
      );
      await $(#lpp_regulation_review_confirm_cta).scrollTo().tap();

      expect(events, const <String>[
        'accept_regulation',
        'record_regulation',
        'accept_capital',
        'record_capital',
      ]);
      expect(scanSessions.byId(scanSessionId), isNull);
      final candidate = ledger.profile!.lppCapitalNoticeDeadline;
      expect(candidate, isNotNull);
      final resolved = documents.resolveLppCapitalNotice(candidate);
      expect(resolved, isNotNull);
      expect(resolved!.deadlineDate, _deadlineDate);
      final reference = documents.byId(candidate!.referenceId);
      expect(reference, isNotNull);
      expect(reference!.snapshotId, numericSnapshot.snapshotId);
      expect(reference.kind, LppCapitalNoticeDeadline.kind);
      expect(reference.ownerKind, LppEvidenceOwnerKind.self);
      final capitalBanner = find.byKey(
        const Key('retirement_lpp_capital_notice_deadline_education_known'),
      );
      expect(capitalBanner, findsOneWidget);
      expect(
        find.bySemanticsIdentifier(
          'retirement_lpp_capital_notice_deadline_education',
        ),
        findsOneWidget,
      );
      final retirementScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
        description: 'vertical retirement dashboard Scrollable',
      );
      expect(retirementScrollable, findsOneWidget);
      await $.tester.scrollUntilVisible(
        capitalBanner,
        -300,
        scrollable: retirementScrollable,
      );
      await $.tester.ensureVisible(capitalBanner);
      await $.pumpAndSettle();
      await $(capitalBanner).waitUntilVisible();

      final encodedReferences = preferences.getString(
        DocumentReferenceStore.storageKey,
      );
      expect(encodedReferences, isNotNull);
      expect(encodedReferences, isNot(contains(_numericMarker)));
      expect(encodedReferences, isNot(contains(_planMarker)));
      expect(encodedReferences, isNot(contains('sourceText')));
      final encodedLedger =
          ledger.reportAnswersSnapshot['_coach_lpp_evidence_v1'] as String;
      expect(encodedLedger, isNot(contains(_numericMarker)));
      expect(encodedLedger, isNot(contains(_planMarker)));
      expect(encodedLedger, isNot(contains('rawOcr')));
      expect(
        await preferences.setInt(g1LppCapitalNoticeWriterPidKey, pid),
        isTrue,
      );
      expect(preferences.getInt(g1LppCapitalNoticeWriterPidKey), pid);
    },
  );
}
