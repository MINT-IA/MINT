import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/services/consent/partner_accountability_binding_store.dart';
import 'package:mint_mobile/services/consent/partner_accountability_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
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
};
const _presentationFactKeys = <LppEvidenceFactKey>{
  LppEvidenceFactKey.vestedBenefitsCapitalChf,
  LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf,
  LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf,
  LppEvidenceFactKey.insuredSalaryAnnualChf,
  LppEvidenceFactKey.maximumBuybackCapitalChf,
};
const _looseLppAnswerKeys = <String>{
  '_coach_avoir_lpp',
  '_coach_avoir_lpp_oblig',
  '_coach_avoir_lpp_suroblig',
  '_coach_salaire_assure',
  '_coach_rachat_maximum',
  '_coach_taux_conversion',
  '_coach_taux_conversion_suroblig',
  '_coach_rendement_caisse',
  '_coach_lpp_source',
  ...legacyPartnerLppAnswerKeys,
};
final _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
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
  int statusReads = 0;

  @override
  Future<void> delete(String endpoint) =>
      throw StateError('Cold reader must not erase the receipt');

  @override
  Future<Map<String, dynamic>> get(String endpoint) async {
    expect(
      endpoint,
      '/partner-accountability/receipts/$runtimeReceiptId/status',
    );
    statusReads += 1;
    return <String, dynamic>{
      'receiptId': runtimeReceiptId,
      'status': 'active',
      'noticeVersion': 'runtime-notice-v1',
      'policyVersion': 'runtime-policy-v1',
      'declaredAt': _runtimeNow.toIso8601String(),
      'expiresAt': _runtimeExpiry.toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) =>
      throw StateError('Cold reader must not create or revoke a receipt');
}

void _expectColdSnapshot(
  LppEvidenceSnapshot snapshot, {
  required String persistedSnapshotId,
}) {
  expect(snapshot.snapshotId, persistedSnapshotId);
  expect(snapshot.snapshotId, matches(_uuidV4Pattern));
  expect(snapshot.snapshotId, isNot(_runtimeAcquisitionId));
  expect(snapshot.facts.keys.toSet(), _expectedFacts.keys.toSet());
  expect(
    snapshot.facts.values.map((fact) => fact.updatedAt).toSet(),
    hasLength(1),
  );
  for (final entry in _expectedFacts.entries) {
    final persisted = snapshot.facts[entry.key];
    expect(persisted, isNotNull, reason: entry.key.wireName);
    final tolerance = entry.key.unit == LppEvidenceUnit.ratio ? 1e-12 : 0.01;
    expect(persisted!.unit, entry.key.unit);
    expect(persisted.value, closeTo(entry.value, tolerance));
    expect(persisted.source, 'certificate');
    expect(persisted.sourceDate, DateTime.utc(2025, 12, 31));
    expect(persisted.ownerKind, LppEvidenceOwnerKind.manualPartner);
    expect(persisted.profileOwnerId, runtimePartnerOwnerId);
    expect(persisted.actorProfileOwnerId, matches(_uuidV4Pattern));
    expect(persisted.profileOwnerId, isNot(persisted.actorProfileOwnerId));
    expect(
      persisted.authorizationMode,
      LppEvidenceAuthorizationMode.manualPartnerDeclaration,
    );
    expect(persisted.authorizationGrantId, isNull);
    expect(persisted.status, LppEvidenceStatus.available);
  }
}

Widget _runtimeApp(CoachProfileProvider provider) => MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>.value(value: provider),
        ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
        ChangeNotifierProvider<SlmProvider>(create: (_) {
          final slmProvider = SlmProvider();
          slmProvider.init();
          return slmProvider;
        }),
      ],
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: RetirementDashboardScreen(),
      ),
    );

void main() {
  patrolTest(
    'cold process verifies receipt then renders strict partner LPP dashboard',
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

      final securePersistence = _RuntimeSecureBindingPersistence();
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
      expect(partnerApi.statusReads, 1);
      expect(provider.profile, isNotNull);
      await $.pumpWidgetAndSettle(_runtimeApp(provider));

      final answers = provider.reportAnswersSnapshot;
      final rawRoot = answers['_coach_lpp_evidence_v1'];
      expect(rawRoot, isA<String>());
      final persistedRoot = rawRoot as String;
      final root = LppEvidenceRoot.fromJsonString(persistedRoot);
      expect(root, isNotNull);
      expect(root!.self, isNull);
      expect(root.manualPartner, isNotNull);
      expect(root.legacyPartnerQuarantine, isNull);
      final persistedSnapshotId = root.manualPartner!.snapshotId;
      expect(LppEvidenceSelector.selectSelf(rawRoot), isNull);
      final manualOwnerId = LppEvidenceSelector.manualPartnerOwnerId(rawRoot);
      expect(manualOwnerId, runtimePartnerOwnerId);
      final manualPartner = LppEvidenceSelector.selectManualPartner(
        rawRoot,
        expectedOwnerId: runtimePartnerOwnerId,
        now: () => _runtimeNow,
      );
      expect(manualPartner, isNotNull);
      _expectColdSnapshot(
        manualPartner!,
        persistedSnapshotId: persistedSnapshotId,
      );

      final binding = provider.partnerLppAccountabilityBinding;
      expect(binding, isNotNull);
      expect(binding!.receiptId, runtimeReceiptId);
      expect(binding.manualPartnerOwnerId, runtimePartnerOwnerId);
      expect(binding.state, PartnerAccountabilityBindingState.active);
      expect(binding.lastVerifiedAt, _runtimeNow);
      expect(binding.expiresAt, _runtimeExpiry);
      expect(provider.partnerLppAccountabilityState,
          PartnerAccountabilityBindingState.active);

      final hydratedProfile = provider.profile!;
      expect(hydratedProfile.conjoint, isNotNull);
      expect(hydratedProfile.conjoint!.invitationLevel, 'declared');
      for (final key in _presentationFactKeys) {
        final hydratedSelf = hydratedProfile.prevoyance.lppEvidenceFact(key);
        final hydratedPartner =
            hydratedProfile.conjoint!.prevoyance?.lppEvidenceFact(key);
        expect(hydratedSelf, isNull, reason: key.profilePath);
        expect(hydratedPartner, isNotNull,
            reason: key.manualPartnerProfilePath);
        expect(hydratedPartner!.value, closeTo(_expectedFacts[key]!, 0.01));
        expect(
          hydratedProfile.dataSources[key.manualPartnerProfilePath],
          ProfileDataSource.certificate,
        );
        expect(
          hydratedProfile.dataTimestamps[key.manualPartnerProfilePath],
          isNotNull,
        );
        expect(
          hydratedProfile.dataSourceDates[key.manualPartnerProfilePath],
          DateTime.utc(2025, 12, 31),
        );
        expect(
          hydratedProfile.conjoint!.prevoyance!.lppEvidenceStatus(key),
          LppEvidenceStatus.available,
        );
      }

      for (final looseKey in _looseLppAnswerKeys) {
        expect(answers.containsKey(looseKey), isFalse, reason: looseKey);
      }
      final backendSafe = ReportPersistenceService.backendSafeAnswers(answers);
      expect(backendSafe.containsKey('_coach_lpp_evidence_v1'), isFalse);
      expect(
        backendSafe.keys.toSet().intersection(_looseLppAnswerKeys),
        isEmpty,
      );
      expect(jsonDecode(persistedRoot), isA<Map<String, dynamic>>());
      expect(persistedRoot, isNot(contains('"sourceText"')));
      expect(persistedRoot, isNot(contains('"rawOcr"')));
      expect(
        persistedRoot,
        isNot(contains('%PDF-1.7 MINT synthetic runtime bytes only')),
      );

      await $(#retirement_partner_lpp_status_active).waitUntilVisible();
      await $(#retirement_partner_lpp_rights_link).waitUntilVisible();
      expect(partnerApi.statusReads, 1);
    },
  );
}
