import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/screens/document_scan/document_impact_screen.dart';
import 'package:mint_mobile/screens/document_scan/document_scan_screen.dart';
import 'package:mint_mobile/screens/document_scan/extraction_review_screen.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/services/consent/partner_accountability_binding_store.dart';
import 'package:mint_mobile/services/consent/partner_accountability_service.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
const _sourceDate = '2025-12-31';
const runtimeReceiptId = '11111111-1111-4111-8111-111111111111';
const runtimePartnerOwnerId = '22222222-2222-4222-8222-222222222222';
const _runtimeAcquisitionId = '33333333-3333-4333-8333-333333333333';
final _runtimeNow = DateTime.now().toUtc();
final _runtimeExpiry = _runtimeNow.add(const Duration(days: 365));

const _expectedFacts = <LppEvidenceFactKey, double>{
  LppEvidenceFactKey.vestedBenefitsCapitalChf: 143287.50,
  LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf: 98400,
  LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf: 44887.50,
  LppEvidenceFactKey.insuredSalaryAnnualChf: 72540,
  LppEvidenceFactKey.maximumBuybackCapitalChf: 45000,
  LppEvidenceFactKey.mandatoryConversionRateRatio: 0.068,
  LppEvidenceFactKey.extraMandatoryConversionRateRatio: 0.052,
  LppEvidenceFactKey.retirementPensionAnnualChf: 31450,
  LppEvidenceFactKey.retirementCapitalLumpSumChf: 485200,
  LppEvidenceFactKey.disabilityPensionAnnualChf: 36800,
  LppEvidenceFactKey.disabilityCapitalLumpSumChf: 175000,
  LppEvidenceFactKey.deathCapitalLumpSumChf: 220500,
};

final _externalGate = PartnerAccountabilityExternalGate(
  noticeVersion: 'runtime-notice-v1',
  policyVersion: 'runtime-policy-v1',
  effectiveAt: _runtimeNow.subtract(const Duration(days: 1)),
  expiresAt: _runtimeExpiry,
  controllerIdentity: 'MINT Runtime Synthetic Controller',
  privacyContact: 'privacy-runtime@example.invalid',
  recipient: 'Synthetic local test recipient',
  processingRegions: 'Synthetic runtime only',
  transferMechanism: 'Synthetic injected boundary',
  retentionContract: 'No raw document retention',
  rightsChannel: 'https://example.invalid/runtime-rights',
  aipdDecision: 'Synthetic runtime gate accepted',
);

final class _RuntimeSecureBindingPersistence
    implements PartnerAccountabilityBindingPersistence {
  static const key = 'mint_g1_prov02_patrol_binding_v2';
  static const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  Future<void> delete() => storage.delete(key: key);

  @override
  Future<String?> read() => storage.read(key: key);

  @override
  Future<void> write(String value) => storage.write(key: key, value: value);
}

final class _RuntimePartnerApi implements PartnerAccountabilityApi {
  int receiptCreates = 0;
  int erases = 0;
  int statusReads = 0;

  Map<String, dynamic> _receipt(String receiptId) => <String, dynamic>{
        'receiptId': receiptId,
        'status': 'active',
        'noticeVersion': _externalGate.noticeVersion,
        'policyVersion': _externalGate.policyVersion,
        'declaredAt': _runtimeNow.toIso8601String(),
        'expiresAt': _runtimeExpiry.toIso8601String(),
      };

  @override
  Future<void> delete(String endpoint) async {
    erases += 1;
  }

  @override
  Future<Map<String, dynamic>> get(String endpoint) async {
    statusReads += 1;
    return _receipt(runtimeReceiptId);
  }

  @override
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    receiptCreates += 1;
    expect(body['receiptId'], runtimeReceiptId);
    expect(body['subjectOwnerToken'], runtimePartnerOwnerId);
    expect(body['noticeVersion'], _externalGate.noticeVersion);
    expect(body['policyVersion'], _externalGate.policyVersion);
    return _receipt(runtimeReceiptId);
  }
}

void _expectSnapshot(LppEvidenceSnapshot snapshot) {
  expect(snapshot.facts.keys.toSet(), _expectedFacts.keys.toSet());
  for (final entry in _expectedFacts.entries) {
    final persisted = snapshot.facts[entry.key];
    expect(persisted, isNotNull, reason: entry.key.wireName);
    final tolerance = entry.key.unit == LppEvidenceUnit.ratio ? 1e-12 : 0.01;
    expect(persisted!.unit, entry.key.unit);
    expect(persisted.value, closeTo(entry.value, tolerance));
    expect(persisted.source, 'certificate');
    expect(persisted.sourceDate, DateTime.utc(2025, 12, 31));
    expect(persisted.ownerKind, LppEvidenceOwnerKind.manualPartner);
    expect(
      persisted.authorizationMode,
      LppEvidenceAuthorizationMode.manualPartnerDeclaration,
    );
    expect(persisted.authorizationGrantId, isNull);
    expect(
      persisted.profileOwnerId == persisted.actorProfileOwnerId,
      isFalse,
    );
  }
}

List<Map<String, dynamic>> _syntheticFields() => _expectedFacts.entries
    .map(
      (entry) => <String, dynamic>{
        'fieldName': entry.key.wireName,
        'value': entry.value,
        'confidence': 'high',
        'sourceText': '',
      },
    )
    .toList(growable: false);

GoRouter _runtimeRouter({
  required ScanSessionProvider scanSessions,
  required PartnerAccountabilityBindingStore bindingStore,
  required PartnerAccountabilityService accountabilityService,
  required void Function(String path) onOwnedTemp,
  required void Function(List<ConsentPurpose> purposes) onConsent,
}) =>
    GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => DocumentScanScreen(
            initialType: DocumentType.lppCertificate,
            partnerBindingStore: bindingStore,
            partnerAccountabilityService: accountabilityService,
            partnerExternalGate: _externalGate,
            isAuthenticated: () async => true,
            partnerOwnerIdFactory: () => runtimePartnerOwnerId,
            partnerReceiptIdFactory: () => runtimeReceiptId,
            lppAcquisitionIdFactory: () => _runtimeAcquisitionId,
            now: () => _runtimeNow,
            requireConsent: (context, purposes) async {
              onConsent(purposes);
              return true;
            },
            pickFile: () async {
              final bytes = Uint8List.fromList(
                utf8.encode('%PDF-1.7 MINT synthetic runtime bytes only'),
              );
              return PlatformFile(
                name: 'mint-synthetic-runtime-certificate.pdf',
                size: bytes.length,
                bytes: bytes,
              );
            },
            writeOwnedTempFile: (file, bytes) async {
              onOwnedTemp(file.path);
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
              expect(base64Decode(imageBase64), isNotEmpty);
              expect(documentType, 'lpp_certificate');
              expect(subjectKind, PartnerAccountabilityService.subjectKind);
              expect(receiptId, runtimeReceiptId);
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
              throw StateError('Missing synthetic runtime review payload');
            }
            return ExtractionReviewScreen(
              scanSessionId: id,
              result: payload.extraction,
              lppCandidate: payload.lppCandidate,
              lppAuthorization: payload.lppAuthorization,
              manualPartnerAccountability: payload.manualPartnerAccountability,
              partnerBindingStore: bindingStore,
              partnerAccountabilityService: accountabilityService,
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
              throw StateError('Missing synthetic runtime impact payload');
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

Widget _runtimeApp({
  required GoRouter router,
  required CoachProfileProvider provider,
  required ScanSessionProvider scanSessions,
}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(value: provider),
        ChangeNotifierProvider<ScanSessionProvider>.value(value: scanSessions),
        ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
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
    );

void main() {
  patrolTest(
    'writes synthetic manual-partner LPP through receipt review impact dashboard',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 8)),
    ($) async {
      FeatureFlags.typedLppEvidence = true;
      FeatureFlags.documentLppEvidenceEnabled = true;
      FeatureFlags.partnerLppAccountabilityEnabled = true;
      addTearDown(() {
        FeatureFlags.typedLppEvidence = false;
        FeatureFlags.documentLppEvidenceEnabled = false;
        FeatureFlags.partnerLppAccountabilityEnabled = false;
      });

      await ReportPersistenceService.clearDiagnostic();
      await ReportPersistenceService.saveAnswers({
        'q_birth_year': 1980,
        'q_canton': 'VD',
        'q_civil_status': 'marie',
        'q_partner_birth_year': 1982,
        'q_partner_employment_status': 'salarie',
      });
      await ReportPersistenceService.setMiniOnboardingCompleted(true);

      final securePersistence = _RuntimeSecureBindingPersistence();
      await securePersistence.delete();
      final bindingStore = PartnerAccountabilityBindingStore(
        persistence: securePersistence,
      );
      final partnerApi = _RuntimePartnerApi();
      final accountabilityService =
          PartnerAccountabilityService(api: partnerApi);
      final provider = CoachProfileProvider(
        partnerAccountabilityBindingStore: bindingStore,
        partnerAccountabilityService: accountabilityService,
        now: () => _runtimeNow,
      );
      await provider.loadFromWizard();
      final scanSessions = ScanSessionProvider();
      String? ownedTempPath;
      final consentPurposes = <List<ConsentPurpose>>[];
      final router = _runtimeRouter(
        scanSessions: scanSessions,
        bindingStore: bindingStore,
        accountabilityService: accountabilityService,
        onOwnedTemp: (path) => ownedTempPath = path,
        onConsent: (purposes) => consentPurposes.add(List.of(purposes)),
      );
      addTearDown(router.dispose);
      await $.pumpWidgetAndSettle(
        _runtimeApp(
          router: router,
          provider: provider,
          scanSessions: scanSessions,
        ),
      );

      expect(provider.profile, isNotNull);
      expect(provider.profile!.conjoint, isNotNull);
      expect(provider.profile!.conjoint!.invitationLevel, 'declared');
      await $(#document_scan_lpp_type_selector).waitUntilVisible();

      // Refusal occurs after the live synthetic notice and synthetic auth,
      // before pending binding, receipt creation, picker, bytes or persistence.
      await $(#document_scan_gallery_cta).scrollTo().tap();
      await $(#lpp_acquisition_owner_manual_partner).waitUntilVisible();
      await $(#lpp_acquisition_owner_manual_partner).tap();
      await $(#lpp_partner_notice_continue).waitUntilVisible();
      await $(#lpp_partner_notice_continue).tap();
      await $(#lpp_acquisition_partner_attestation).waitUntilVisible();
      await $(#lpp_acquisition_cancel).tap();
      await $.pumpAndSettle();
      expect(partnerApi.receiptCreates, 0);
      expect(consentPurposes, isEmpty);
      expect(scanSessions.retainedSessionCount, 0);
      expect((await bindingStore.load()).effective, isNull);
      expect(
        provider.reportAnswersSnapshot.containsKey('_coach_lpp_evidence_v1'),
        isFalse,
      );

      // Success repeats the same no-linked-account surface and crosses the
      // receipt, secure pending, exact bytes, review, save and impact joints.
      await $(#document_scan_gallery_cta).scrollTo().tap();
      await $(#lpp_acquisition_owner_manual_partner).waitUntilVisible();
      await $(#lpp_acquisition_owner_manual_partner).tap();
      await $(#lpp_partner_notice_continue).waitUntilVisible();
      await $(#lpp_partner_notice_continue).tap();
      await $(#lpp_acquisition_partner_attestation).waitUntilVisible();
      await $(#lpp_partner_authorization_declaration).tap();
      await $.pump();
      await $(#lpp_partner_authorization_continue).tap();

      await $(#lpp_review_owner_badge).waitUntilVisible();
      expect(partnerApi.receiptCreates, 1);
      expect(partnerApi.erases, 0);
      expect(consentPurposes, const [
        [ConsentPurpose.visionExtraction],
      ]);
      final pending = (await bindingStore.load()).pending;
      expect(pending, isNotNull);
      expect(pending!.receiptId, runtimeReceiptId);
      expect(pending.hasCreatedReceipt, isTrue);

      await $(#lpp_review_source_date).waitUntilVisible();
      await $(#lpp_review_source_date).enterText(_sourceDate);
      await $(#lpp_review_confirm_cta).scrollTo().tap();
      await $(#lpp_impact_retirement_cta).waitUntilVisible();

      final rawRoot = provider.reportAnswersSnapshot['_coach_lpp_evidence_v1'];
      expect(rawRoot, isA<String>());
      final manualOwnerId = LppEvidenceSelector.manualPartnerOwnerId(rawRoot);
      expect(manualOwnerId, runtimePartnerOwnerId);
      final manualPartner = LppEvidenceSelector.selectManualPartner(
        rawRoot,
        expectedOwnerId: manualOwnerId!,
      );
      expect(manualPartner, isNotNull);
      _expectSnapshot(manualPartner!);

      final activeBinding = (await bindingStore.load()).active;
      if (activeBinding == null) fail('Missing active runtime binding');
      expect(activeBinding.receiptId, runtimeReceiptId);
      expect(activeBinding.state, PartnerAccountabilityBindingState.active);
      expect(activeBinding.privacyContact, _externalGate.privacyContact);
      expect(activeBinding.rightsChannel, _externalGate.rightsChannel);
      expect(ownedTempPath, isNotNull);
      expect(File(ownedTempPath!).existsSync(), isFalse);

      await $(#lpp_impact_retirement_cta).scrollTo().tap();
      await $(#retirement_partner_lpp_status_active).waitUntilVisible();
      await $(#retirement_partner_lpp_rights_link).waitUntilVisible();
      expect(scanSessions.retainedSessionCount, 0);
      expect(partnerApi.erases, 0);

      final persistedRoot = rawRoot as String;
      expect(persistedRoot, isNot(contains('sourceText')));
      expect(persistedRoot, isNot(contains('rawOcr')));
      expect(
        persistedRoot,
        isNot(contains('%PDF-1.7 MINT synthetic runtime bytes only')),
      );
    },
  );
}
