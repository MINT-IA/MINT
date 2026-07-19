import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';
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
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:patrol/patrol.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';

import 'support/g1_ret_ref_pillar3a_beneficiary_runtime_contract.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
const _scanContextId = '11111111-1111-4111-8111-111111111111';
const _contractReferenceId = '22222222-2222-4222-8222-222222222222';
const _documentAuthorityId = '33333333-3333-4333-8333-333333333333';
const _referenceId = '44444444-4444-4444-8444-444444444444';
const _syntheticMarker = 'DOCUMENT SYNTHÉTIQUE — AUCUNE DONNÉE RÉELLE';

final class _SequenceUuid extends Uuid {
  _SequenceUuid(this.values);

  final List<String> values;
  int _index = 0;

  @override
  String v4({Map<String, dynamic>? options, V4Options? config}) =>
      values[_index++];
}

final class _RuntimeLedger extends CoachProfileProvider {
  _RuntimeLedger({
    required this.events,
    required DateTime Function() now,
    required SessionEpoch sessionEpoch,
  }) : super(now: now, sessionEpoch: sessionEpoch);

  final List<String> events;

  @override
  Future<Pillar3aBeneficiaryReceipt> acceptPillar3aBeneficiaryReview(
    Pillar3aBeneficiaryReviewConfirmation confirmation,
  ) async {
    events.add('accept');
    return super.acceptPillar3aBeneficiaryReview(confirmation);
  }
}

final class _RuntimeDocuments extends DocumentProvider {
  _RuntimeDocuments({
    required this.events,
    required DateTime Function() now,
    required SessionEpoch sessionEpoch,
  }) : super(
          now: now,
          sessionEpoch: sessionEpoch,
          uuid: _SequenceUuid(const <String>[_referenceId]),
        );

  final List<String> events;

  @override
  Future<ConfirmedDocumentReference> recordPillar3aBeneficiaryEvidence(
    Pillar3aBeneficiaryReceipt receipt,
  ) async {
    events.add('record');
    return super.recordPillar3aBeneficiaryEvidence(receipt);
  }
}

Future<File> _writeSyntheticPillar3aPdf(Directory directory) async {
  final document = pw.Document();
  document.addPage(
    pw.Page(
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(_syntheticMarker),
          pw.SizedBox(height: 12),
          pw.Text('Confirmation institutionnelle 3a - clause beneficiaire'),
          pw.Text('Institution fictive MINT Runtime, contrat de demonstration'),
          pw.Text('Date de source: 2026-07-18'),
          pw.Text('Date d effet de la designation: 2026-01-15'),
          pw.Text('Aucune identite, aucun rang et aucune quote-part.'),
        ],
      ),
    ),
  );
  final file = File('${directory.path}/mint-synthetic-pillar3a-clause.pdf');
  await file.writeAsBytes(await document.save(), flush: true);
  return file;
}

Map<String, dynamic> _exactAuthorityJson() => <String, dynamic>{
      'schemaVersion': 1,
      'documentAuthorityId': _documentAuthorityId,
      'documentKind': 'confirmationInstitutionnelle',
      'sourceDate': '2026-07-18',
      'legalYear': 2026,
      'institutionAttested': true,
      'contractScoped': true,
      'temporalBasis': <String, dynamic>{
        'kind': 'exactDates',
        'designationEffectiveDate': '2026-01-15',
        'lastAssignmentModificationDate': null,
      },
      'needsReview': true,
    };

GoRouter _router({
  required ScanSessionProvider scanSessions,
  required File syntheticPdf,
  required List<List<ConsentPurpose>> consentCalls,
  required List<String> visionCalls,
  required List<String> uploadAttempts,
  required DateTime now,
}) =>
    GoRouter(
      initialLocation: '/retraite',
      routes: <RouteBase>[
        GoRoute(
          path: '/retraite',
          builder: (_, __) => const RetirementDashboardScreen(),
        ),
        GoRoute(
          path: '/scan',
          builder: (_, state) => DocumentScanScreen(
            initialType: DocumentType.pillar3aBeneficiaryClause,
            scanContextId: state.uri.queryParameters['scanContextId'],
            returnUri: state.uri.queryParameters['returnUri'],
            now: () => now,
            requireConsent: (_, purposes) async {
              expect(
                purposes,
                const <ConsentPurpose>[
                  ConsentPurpose.visionExtraction,
                  ConsentPurpose.transferUsAnthropic,
                ],
              );
              consentCalls.add(List<ConsentPurpose>.of(purposes));
              return true;
            },
            pickFile: () async => PlatformFile(
              name: 'mint-synthetic-pillar3a-clause.pdf',
              path: syntheticPdf.path,
              size: await syntheticPdf.length(),
            ),
            visionExtractor: ({
              required imageBase64,
              required documentType,
              canton,
              languageHint,
              subjectKind,
              receiptId,
            }) async {
              final bytes = base64Decode(imageBase64);
              expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
              expect(bytes.length, greaterThan(1000));
              expect(documentType, 'pillar_3a_beneficiary_clause');
              expect(subjectKind, isNull);
              expect(receiptId, isNull);
              visionCalls.add(documentType);
              return _exactAuthorityJson();
            },
            uploadDocument: (file, {required type}) async {
              uploadAttempts.add(type.name);
              throw StateError('Unexpected vault upload for exact 3a PDF');
            },
          ),
        ),
        GoRoute(
          path: '/scan/review',
          builder: (_, state) {
            final scanSessionId = state.uri.queryParameters['scanSessionId'];
            final payload = scanSessions.byId(scanSessionId);
            if (scanSessionId == null || payload == null) {
              throw StateError('Missing volatile exact 3a review');
            }
            return ExtractionReviewScreen(
              scanSessionId: scanSessionId,
              result: payload.extraction,
              pillar3aBeneficiaryCandidate:
                  payload.pillar3aBeneficiaryCandidate,
              pillar3aScanContextId: payload.pillar3aScanContextId,
              pillar3aReturnUri: payload.pillar3aReturnUri,
              now: () => now,
            );
          },
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
    'writes one exact pillar 3a beneficiary reference through real screens',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 8)),
    ($) async {
      FeatureFlags.typedLppEvidence = true;
      FeatureFlags.documentLppEvidenceEnabled = true;
      FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = true;
      addTearDown(() {
        FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;
        FeatureFlags.documentLppEvidenceEnabled = false;
        FeatureFlags.typedLppEvidence = false;
      });

      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(g1Pillar3aBeneficiaryWriterPidKey);
      await ReportPersistenceService.clearDiagnostic();
      await DocumentReferenceStore().save(const <ConfirmedDocumentReference>[]);
      await ReportPersistenceService.saveAnswers(<String, dynamic>{
        'q_birth_year': 1980,
        'q_canton': 'VD',
        'q_civil_status': 'celibataire',
        'q_has_pension_fund': 'yes',
        '__provenance': <String, dynamic>{},
      });

      final syntheticDirectory =
          await Directory.systemTemp.createTemp('mint-pillar3a-runtime-');
      final syntheticPdf = await _writeSyntheticPillar3aPdf(syntheticDirectory);
      addTearDown(() async {
        if (await syntheticDirectory.exists()) {
          await syntheticDirectory.delete(recursive: true);
        }
      });

      final now = DateTime.now().toUtc();
      final sessionEpoch = SessionEpoch();
      final events = <String>[];
      final ledger = _RuntimeLedger(
        events: events,
        now: () => now,
        sessionEpoch: sessionEpoch,
      );
      final documents = _RuntimeDocuments(
        events: events,
        now: () => now,
        sessionEpoch: sessionEpoch,
      )..bindLedger(ledger);
      final scanSessions = ScanSessionProvider(
        sessionEpoch: sessionEpoch,
        uuid: _SequenceUuid(
          const <String>[_scanContextId, _contractReferenceId],
        ),
      );
      final consentCalls = <List<ConsentPurpose>>[];
      final visionCalls = <String>[];
      final uploadAttempts = <String>[];
      final router = _router(
        scanSessions: scanSessions,
        syntheticPdf: syntheticPdf,
        consentCalls: consentCalls,
        visionCalls: visionCalls,
        uploadAttempts: uploadAttempts,
        now: now,
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

      await $(#retirement_pillar3a_beneficiary_insert_cta).scrollTo().tap();
      await $(#document_scan_pillar3a_beneficiary_clause_type_selector)
          .waitUntilVisible();
      await $(#document_scan_gallery_cta).scrollTo().tap();
      await $(find.bySemanticsIdentifier('pillar3a_beneficiary_review_screen'))
          .waitUntilVisible();
      expect(consentCalls, hasLength(1));
      expect(visionCalls, const <String>['pillar_3a_beneficiary_clause']);
      expect(uploadAttempts, isEmpty, reason: 'raw PDF must never enter vault');

      final routeUri = router.routeInformationProvider.value.uri;
      final scanSessionId = routeUri.queryParameters['scanSessionId'];
      final retained = scanSessions.byId(scanSessionId);
      expect(retained, isNotNull);
      expect(
        retained?.pillar3aBeneficiaryCandidate?.authority.documentKind,
        Pillar3aBeneficiaryAuthorityDocumentKind.confirmationInstitutionnelle,
      );

      await $(#pillar3a_beneficiary_relation_current_active_unpaid)
          .scrollTo()
          .tap();
      await $(#pillar3a_beneficiary_confirm_cta).scrollTo().tap();
      await $(find.bySemanticsIdentifier(
        'retirement_pillar3a_beneficiary_reference_consumer',
      )).waitUntilVisible();

      expect(events, const <String>['accept', 'record']);
      expect(scanSessions.byId(scanSessionId), isNull);
      expect(scanSessions.retainedSessionCount, 0);
      expect(scanSessions.retainedPillar3aBeneficiaryScanIntentCount, 0);
      expect(router.routeInformationProvider.value.uri.path, '/retraite');

      final persistedAnswers = await ReportPersistenceService.loadAnswers();
      final rootJson =
          persistedAnswers[Pillar3aBeneficiaryEvidenceRoot.answerKey];
      final root = Pillar3aBeneficiaryEvidenceRoot.fromJsonString(
        rootJson,
        now: () => now,
      );
      expect(root, isNotNull);
      expect(root?.contracts, hasLength(1));
      expect(
        root?.contracts.single.relation,
        Pillar3aBeneficiaryRelation.currentActiveUnpaid,
      );
      final references = await DocumentReferenceStore().load();
      expect(references, hasLength(1));
      expect(references.single.referenceId, _referenceId);
      expect(
        references.single.contractReferenceId,
        root?.contracts.single.contractReferenceId,
      );
      expect(
        references.single.documentAuthorityId,
        root?.contracts.single.documentAuthorityId,
      );

      final wizardCache = jsonDecode(
        preferences.getString('wizard_answers_v2')!,
      ) as Map<String, dynamic>;
      expect(
        wizardCache[Pillar3aBeneficiaryEvidenceRoot.answerKey],
        '__secure__',
      );
      final durablePayload = jsonEncode(<Object?>[
        rootJson,
        references.map((reference) => reference.toJson()).toList(),
        wizardCache,
      ]);
      final rawPdfBase64 = base64Encode(await syntheticPdf.readAsBytes());
      for (final forbidden in <String>[
        _syntheticMarker,
        'Institution fictive MINT Runtime',
        'clause beneficiaire',
        'sourceText',
        'rawOcr',
        'raw OCR',
        'ocr',
        '.pdf',
        rawPdfBase64,
      ]) {
        expect(durablePayload, isNot(contains(forbidden)));
      }
      expect(
          preferences.getString(DocumentReferenceStore.storageKey), isNotNull);
      expect(
        await preferences.setInt(g1Pillar3aBeneficiaryWriterPidKey, pid),
        isTrue,
      );
      expect(preferences.getInt(g1Pillar3aBeneficiaryWriterPidKey), pid);
    },
  );
}
