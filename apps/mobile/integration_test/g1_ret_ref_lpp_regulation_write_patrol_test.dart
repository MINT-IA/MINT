import 'dart:io';

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

import 'support/g1_ret_ref_lpp_regulation_runtime_contract.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
const _backendDocumentId = '91919191-9191-4191-8191-919191919191';
const _rawMarker = '%PDF-1.7 MINT synthetic LPP regulation runtime bytes only';
final _runtimeNow = DateTime.now().toUtc();
final _sourceDate = DateTime.utc(
  _runtimeNow.subtract(const Duration(days: 1)).year,
  _runtimeNow.subtract(const Duration(days: 1)).month,
  _runtimeNow.subtract(const Duration(days: 1)).day,
);

String _civilDate(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

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
    events.add('accept');
    return super.acceptLppRegulationReference(confirmation);
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
    events.add('record');
    return super.recordLppRegulation(receipt);
  }
}

GoRouter _router({
  required ScanSessionProvider scanSessions,
  required File syntheticPlan,
  required List<List<ConsentPurpose>> consentCalls,
  required List<VaultDocumentType> uploadCalls,
}) =>
    GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => DocumentScanScreen(
            initialType: DocumentType.lppPlan,
            requireConsent: (_, purposes) async {
              // Runtime contract: expect(purposes, const <ConsentPurpose>[ConsentPurpose.visionExtraction]);
              expect(
                purposes,
                const <ConsentPurpose>[ConsentPurpose.visionExtraction],
              );
              consentCalls.add(List<ConsentPurpose>.of(purposes));
              return true;
            },
            pickFile: () async => PlatformFile(
              name: 'mint-synthetic-regulation.pdf',
              path: syntheticPlan.path,
              size: await syntheticPlan.length(),
            ),
            uploadDocument: (file, {required type}) async {
              expect(type, VaultDocumentType.lppPlan);
              expect(await file.readAsString(), _rawMarker);
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
          ),
        ),
        GoRoute(
          path: '/scan/review',
          builder: (context, state) {
            final scanSessionId = state.uri.queryParameters['scanSessionId'];
            final payload = scanSessions.byId(scanSessionId);
            if (scanSessionId == null || payload == null) {
              throw StateError('Missing volatile LPP regulation review');
            }
            return ExtractionReviewScreen(
              scanSessionId: scanSessionId,
              result: payload.extraction,
              lppRegulationCandidate: payload.lppRegulationCandidate,
              now: () => _runtimeNow,
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
    'acquires one synthetic LPP regulation without a numeric snapshot',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 8)),
    ($) async {
      FeatureFlags.typedLppEvidence = true;
      FeatureFlags.documentLppEvidenceEnabled = true;
      FeatureFlags.lppRegulationReferenceEnabled = true;
      addTearDown(() {
        FeatureFlags.typedLppEvidence = false;
        FeatureFlags.documentLppEvidenceEnabled = false;
        FeatureFlags.lppRegulationReferenceEnabled = false;
      });

      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(g1LppRegulationWriterPidKey);
      await ReportPersistenceService.clearDiagnostic();
      await DocumentReferenceStore().save(const <ConfirmedDocumentReference>[]);
      await ReportPersistenceService.saveAnswers(<String, dynamic>{
        'q_birth_year': 1980,
        'q_canton': 'VD',
        'q_civil_status': 'celibataire',
        'q_has_pension_fund': 'yes',
      });

      final syntheticDirectory =
          await Directory.systemTemp.createTemp('mint-lpp-regulation-runtime-');
      final syntheticPlan = File('${syntheticDirectory.path}/regulation.pdf');
      await syntheticPlan.writeAsString(_rawMarker, flush: true);
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
      expect(
        ledger.currentLppSnapshot(LppEvidenceOwnerKind.self),
        isNull,
        reason: 'the writer must prove regulation-only first acquisition',
      );
      await $.pumpWidgetAndSettle(
        _app(
          router: router,
          ledger: ledger,
          documents: documents,
          scanSessions: scanSessions,
          sessionEpoch: sessionEpoch,
        ),
      );

      await $(#document_scan_lpp_plan_type_selector).waitUntilVisible();
      await $(#document_scan_gallery_cta).scrollTo().tap();
      await $(#lpp_regulation_review_source_date).waitUntilVisible();

      expect(
        consentCalls,
        const <List<ConsentPurpose>>[
          <ConsentPurpose>[ConsentPurpose.visionExtraction],
        ],
      );
      expect(uploadCalls, const <VaultDocumentType>[VaultDocumentType.lppPlan]);
      final routeUri = router.routeInformationProvider.value.uri;
      expect(routeUri.queryParameters.keys, const <String>{'scanSessionId'});
      final scanSessionId = routeUri.queryParameters['scanSessionId'];
      expect(scanSessionId, isNotNull);
      expect(scanSessionId, isNot(contains(_backendDocumentId)));
      final retained = scanSessions.byId(scanSessionId);
      expect(retained, isNotNull);
      if (retained == null) fail('Missing volatile LPP regulation candidate');
      expect(retained.lppRegulationCandidate, isNotNull);
      expect(retained.extraction.documentType, DocumentType.lppPlan);
      expect(retained.extraction.fields, isEmpty);

      await $(#lpp_regulation_review_source_date).enterText(
        _civilDate(_sourceDate),
      );
      await $(#lpp_regulation_review_legal_year).enterText(
        '${_sourceDate.year}',
      );
      await $(#lpp_regulation_fund_relation_current).scrollTo().tap();
      await $(#lpp_regulation_review_confirm_cta).scrollTo().tap();
      await $(#retirement_lpp_regulation_reference_education)
          .waitUntilVisible();

      expect(events, const <String>['accept', 'record']);
      expect(scanSessions.byId(scanSessionId), isNull);
      final currentSnapshot = ledger.currentLppSnapshot(
        LppEvidenceOwnerKind.self,
      );
      expect(currentSnapshot, isNull);
      final candidate = ledger.profile!.lppRegulationReference;
      expect(candidate, isNotNull);
      final dynamic typedCandidate = candidate;
      expect(typedCandidate.fundRelationship.wireName, 'currentFund');
      final reference = documents.byId(candidate!.referenceId);
      expect(reference, isNotNull);
      expect(reference!.kind, ConfirmedDocumentReference.lppRegulationKind);
      final dynamic typedReference = reference;
      expect(typedReference.snapshotId, isNull);
      expect(reference.ownerKind, LppEvidenceOwnerKind.self);
      expect(reference.confirmedAt, candidate.confirmedAt);
      expect(documents.resolveLppRegulation(candidate), isNotNull);

      final encodedReferences = preferences.getString(
        DocumentReferenceStore.storageKey,
      );
      expect(encodedReferences, isNotNull);
      expect(encodedReferences, isNot(contains(_rawMarker)));
      expect(encodedReferences, isNot(contains(_backendDocumentId)));
      final encodedLedger =
          ledger.reportAnswersSnapshot['_coach_lpp_evidence_v1'] as String;
      expect(encodedLedger, isNot(contains(_rawMarker)));
      expect(encodedLedger, isNot(contains(_backendDocumentId)));
      expect(encodedLedger, isNot(contains('documentSha256')));
      expect(
        await preferences.setInt(g1LppRegulationWriterPidKey, pid),
        isTrue,
      );
      expect(preferences.getInt(g1LppRegulationWriterPidKey), pid);
    },
  );
}
