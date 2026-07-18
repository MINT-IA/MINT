import 'dart:convert';
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
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
const _rawMarker = '%PDF-1.7 MINT synthetic runtime bytes only';
const _acquisitionId = '61616161-6161-4161-8161-616161616161';
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

GoRouter _router({required ScanSessionProvider scanSessions}) => GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => DocumentScanScreen(
            initialType: DocumentType.lppCertificate,
            lppAcquisitionIdFactory: () => _acquisitionId,
            now: () => _runtimeNow,
            requireConsent: (
              context,
              List<ConsentPurpose> purposes,
            ) async =>
                true,
            pickFile: () async {
              final bytes = Uint8List.fromList(utf8.encode(_rawMarker));
              return PlatformFile(
                name: 'mint-synthetic-runtime-certificate.pdf',
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
              expect(utf8.decode(base64Decode(imageBase64)), _rawMarker);
              expect(documentType, 'lpp_certificate');
              expect(subjectKind, isNull);
              expect(receiptId, isNull);
              return <String, dynamic>{
                'overallConfidence': 0.99,
                'extractedFields': _syntheticFields(),
              };
            },
          ),
        ),
        GoRoute(
          path: '/scan/review',
          builder: (context, state) {
            final id = state.uri.queryParameters['scanSessionId'];
            final payload = scanSessions.byId(id);
            if (id == null || payload == null) {
              throw StateError('Missing synthetic numeric LPP review');
            }
            return ExtractionReviewScreen(
              scanSessionId: id,
              result: payload.extraction,
              lppCandidate: payload.lppCandidate,
              lppAuthorization: payload.lppAuthorization,
              now: () => _runtimeNow,
            );
          },
        ),
        GoRoute(
          path: '/scan/impact',
          builder: (context, state) {
            final id = state.uri.queryParameters['scanSessionId'];
            final payload = scanSessions.byId(id);
            if (id == null || payload?.previousConfidence == null) {
              throw StateError('Missing synthetic numeric LPP impact');
            }
            return DocumentImpactScreen(
              scanSessionId: id,
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
  required CoachProfileProvider provider,
  required DocumentProvider documents,
  required ScanSessionProvider scanSessions,
  required SessionEpoch sessionEpoch,
}) =>
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<CoachProfileProvider>.value(value: provider),
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
    'scans numeric self LPP then records one bounded capital-notice tuple',
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

      await ReportPersistenceService.clearDiagnostic();
      await DocumentReferenceStore().save(const <ConfirmedDocumentReference>[]);
      await ReportPersistenceService.saveAnswers(<String, dynamic>{
        'q_birth_year': 1980,
        'q_canton': 'VD',
        'q_civil_status': 'celibataire',
        'q_has_pension_fund': 'yes',
      });
      await ReportPersistenceService.setMiniOnboardingCompleted(true);

      final sessionEpoch = SessionEpoch();
      final provider = CoachProfileProvider(
        now: () => _runtimeNow,
        sessionEpoch: sessionEpoch,
      );
      final documents = DocumentProvider(sessionEpoch: sessionEpoch)
        ..bindLedger(provider);
      final scanSessions = ScanSessionProvider(sessionEpoch: sessionEpoch);
      final router = _router(scanSessions: scanSessions);
      addTearDown(provider.dispose);
      addTearDown(documents.dispose);
      addTearDown(scanSessions.dispose);
      addTearDown(router.dispose);
      await provider.loadFromWizard();
      await documents.hydrateReferences();
      await $.pumpWidgetAndSettle(
        _app(
          router: router,
          provider: provider,
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
      await $(#lpp_impact_retirement_cta).scrollTo();

      final numericSnapshot = LppEvidenceSelector.selectSelf(
        provider.reportAnswersSnapshot['_coach_lpp_evidence_v1'],
        now: () => _runtimeNow,
      );
      expect(numericSnapshot, isNotNull);
      expect(numericSnapshot!.facts.keys.toSet(), <LppEvidenceFactKey>{
        LppEvidenceFactKey.vestedBenefitsCapitalChf,
        LppEvidenceFactKey.insuredSalaryAnnualChf,
      });

      // No production capital-notice acquisition seam exists.
      // The bounded test-only bridge starts after the real numeric LPP scan.
      final authorityReceipt = await provider.acceptLppRegulationReference(
        LppRegulationReviewConfirmation(
          ownerKind: LppEvidenceOwnerKind.self,
          sourceDate: _sourceDate,
          legalYear: _sourceDate.year,
          fundRelationship: LppFundRelationship.currentFund,
        ),
      );
      await documents.recordLppRegulation(authorityReceipt);
      final noticeReceipt = await provider.acceptLppCapitalNotice(
        LppCapitalNoticeReviewConfirmation(
          ownerKind: LppEvidenceOwnerKind.self,
          authorityReferenceId: authorityReceipt.referenceId,
          sourceDate: _sourceDate,
          legalYear: _sourceDate.year,
          deadlineDate: _deadlineDate,
          expectedSnapshotId: numericSnapshot.snapshotId,
        ),
      );
      final documentReference =
          await documents.recordLppCapitalNotice(noticeReceipt);
      expect(documentReference.referenceId, noticeReceipt.referenceId);
      expect(documentReference.snapshotId, numericSnapshot.snapshotId);
      expect(documentReference.kind, LppCapitalNoticeDeadline.kind);
      expect(documentReference.ownerKind, LppEvidenceOwnerKind.self);
      expect(documentReference.confirmedAt, noticeReceipt.confirmedAt);

      final candidate = provider.profile!.lppCapitalNoticeDeadline;
      expect(candidate, isNotNull);
      expect(
        documents.resolveLppCapitalNotice(candidate)?.referenceId,
        noticeReceipt.referenceId,
      );
      final preferences = await SharedPreferences.getInstance();
      final encodedReferences = preferences.getString(
        DocumentReferenceStore.storageKey,
      );
      expect(encodedReferences, isNotNull);
      expect(encodedReferences, isNot(contains(_rawMarker)));
      expect(encodedReferences, isNot(contains('sourceText')));
      final encodedLedger =
          provider.reportAnswersSnapshot['_coach_lpp_evidence_v1'] as String;
      expect(encodedLedger, isNot(contains(_rawMarker)));
      expect(encodedLedger, isNot(contains('rawOcr')));
    },
  );
}
