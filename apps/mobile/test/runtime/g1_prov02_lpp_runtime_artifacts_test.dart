import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Maestro proves exact LPP default-off and stale deep-link recovery', () {
    final flow = File('.maestro/g1_prov02_lpp_flag_off.yaml');
    expect(flow.existsSync(), isTrue);
    final contents = flow.readAsStringSync();
    for (final anchor in const [
      'appId: ch.mint.app',
      'clearState: true',
      'mint:///scan?type=lppCertificate',
      'document_scan_lpp_type_selector',
      'scan_review_recovery_cta',
      'scan_impact_recovery_cta',
    ]) {
      expect(contents, contains(anchor), reason: anchor);
    }
  });

  test('Patrol writer injects the complete synthetic partner boundary', () {
    final source = File(
      'integration_test/g1_prov02_lpp_persistence_write_patrol_test.dart',
    );
    expect(source.existsSync(), isTrue);
    final contents = source.readAsStringSync();
    for (final anchor in const [
      "FeatureFlags.typedLppEvidence = true",
      "FeatureFlags.documentLppEvidenceEnabled = true",
      "FeatureFlags.partnerLppAccountabilityEnabled = true",
      'PartnerAccountabilityExternalGate(',
      'effectiveAt: _runtimeNow.subtract(const Duration(days: 1))',
      'expiresAt: _runtimeExpiry',
      'PartnerAccountabilityService(api: partnerApi)',
      'PartnerAccountabilityBindingStore(',
      'persistence: securePersistence',
      'isAuthenticated: () async => true',
      '#document_scan_gallery_cta',
      '#lpp_acquisition_owner_manual_partner',
      '#lpp_partner_notice_continue',
      '#lpp_acquisition_partner_attestation',
      '#lpp_acquisition_cancel',
      '#lpp_partner_authorization_declaration',
      '#lpp_partner_authorization_continue',
      '#lpp_review_owner_badge',
      '#lpp_review_source_date',
      '#lpp_review_confirm_cta',
      '#lpp_impact_retirement_cta',
      '#retirement_partner_lpp_status_active',
      'retainedSessionCount, 0',
      'LppEvidenceSelector.selectManualPartner',
      'LppEvidenceAuthorizationMode.manualPartnerDeclaration',
      'authorizationGrantId, isNull',
      'activeBinding.receiptId, runtimeReceiptId',
      'activeBinding.state, PartnerAccountabilityBindingState.active',
      'File(ownedTempPath!).existsSync(), isFalse',
      "const _sourceDate = '2025-12-31'",
    ]) {
      expect(contents, contains(anchor), reason: anchor);
    }
    final refusal = contents.indexOf('#lpp_acquisition_cancel');
    final success = contents.indexOf('#lpp_partner_authorization_declaration');
    final review = contents.indexOf('#lpp_review_confirm_cta');
    final dashboard = contents.indexOf('#retirement_partner_lpp_status_active');
    expect(refusal, greaterThanOrEqualTo(0));
    expect(success, greaterThan(refusal));
    expect(review, greaterThan(success));
    expect(dashboard, greaterThan(review));
    for (final forbidden in const [
      'acceptLppReview(',
      'MINT_LPP_PRIVATE_MANIFEST',
      'Télécharger le certificat de prévoyance.pdf',
      'Certificat_Lauren.jpeg',
      'MintApp()',
      'DateTime.utc(2027, 7, 15)',
    ]) {
      expect(contents, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('Patrol cold reader injects status verification and visible dashboard',
      () {
    final source = File(
      'integration_test/g1_prov02_lpp_persistence_read_patrol_test.dart',
    );
    expect(source.existsSync(), isTrue);
    final contents = source.readAsStringSync();
    for (final anchor in const [
      "FeatureFlags.typedLppEvidence = true",
      "FeatureFlags.documentLppEvidenceEnabled = true",
      "FeatureFlags.partnerLppAccountabilityEnabled = true",
      'PartnerAccountabilityService(api: partnerApi)',
      'PartnerAccountabilityBindingStore(',
      'persistence: securePersistence',
      'provider.loadFromWizard()',
      'partnerApi.statusReads, 1',
      'PartnerAccountabilityBindingState.active',
      'LppEvidenceRoot.fromJsonString',
      'LppEvidenceSelector.selectManualPartner',
      'manualPartner, isNotNull',
      'legacyPartnerQuarantine, isNull',
      'LppEvidenceAuthorizationMode.manualPartnerDeclaration',
      'authorizationGrantId, isNull',
      'ReportPersistenceService.backendSafeAnswers',
      '#retirement_partner_lpp_status_active',
      '#retirement_partner_lpp_rights_link',
      'DateTime.utc(2025, 12, 31)',
      "'\"sourceText\"'",
      "'\"rawOcr\"'",
    ]) {
      expect(contents, contains(anchor), reason: anchor);
    }
    for (final forbidden in const [
      'acceptLppReview(',
      'saveAnswers(',
      'enterText(',
      'MINT_LPP_PRIVATE_MANIFEST',
      'MintApp()',
    ]) {
      expect(contents, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('Patrol Vision fixture retains exact backend fact scope and units', () {
    const backendVisionFields = <String, String>{
      'vestedBenefitsCapitalChf': 'avoirLppTotal',
      'mandatoryVestedBenefitsCapitalChf': 'avoirLppObligatoire',
      'extraMandatoryVestedBenefitsCapitalChf': 'avoirLppSurobligatoire',
      'insuredSalaryAnnualChf': 'salaireAssure',
      'maximumBuybackCapitalChf': 'rachatMaximum',
    };
    const unsupportedBackendVisionFacts = <String>[
      'mandatoryConversionRateRatio',
      'extraMandatoryConversionRateRatio',
      'retirementPensionAnnualChf',
      'retirementCapitalLumpSumChf',
      'disabilityPensionAnnualChf',
      'disabilityCapitalLumpSumChf',
      'deathCapitalLumpSumChf',
    ];
    for (final path in const [
      'integration_test/g1_prov02_lpp_persistence_write_patrol_test.dart',
      'integration_test/g1_prov02_lpp_persistence_read_patrol_test.dart',
    ]) {
      final contents = File(path).readAsStringSync();
      for (final factKey in backendVisionFields.keys) {
        expect(contents, contains('LppEvidenceFactKey.$factKey'), reason: path);
      }
      for (final factKey in unsupportedBackendVisionFacts) {
        expect(
          contents,
          isNot(contains('LppEvidenceFactKey.$factKey')),
          reason: path,
        );
      }
      expect(contents, contains('persisted!.unit, entry.key.unit'));
      expect(
        contents,
        contains('entry.key.unit == LppEvidenceUnit.ratio ? 1e-12 : 0.01'),
      );
      expect(contents, contains('final _runtimeNow = DateTime.now().toUtc();'));
      expect(
        contents,
        contains(
          'final _runtimeExpiry = '
          '_runtimeNow.add(const Duration(days: 365));',
        ),
      );
      expect(
        contents,
        isNot(contains('final _runtimeNow = DateTime.utc(2026, 7, 15, 9);')),
      );
      expect(contents, isNot(contains('DateTime.utc(2027, 7, 15, 9)')));
    }

    final writer = File(
      'integration_test/g1_prov02_lpp_persistence_write_patrol_test.dart',
    ).readAsStringSync();
    for (final entry in backendVisionFields.entries) {
      expect(
        writer,
        contains(
          RegExp(
            'LppEvidenceFactKey\\.${entry.key}:\\s*\'${entry.value}\'',
          ),
        ),
        reason: entry.key,
      );
    }
    expect(writer, isNot(contains("'fieldName': entry.key.wireName")));
  });

  test('Patrol wrappers expose writer then cold reader', () {
    expect(
      File('test/patrol/g1_prov02_lpp_persistence_write_runtime_test.dart')
          .readAsStringSync(),
      contains(
        '../../integration_test/g1_prov02_lpp_persistence_write_patrol_test.dart',
      ),
    );
    expect(
      File('test/patrol/g1_prov02_lpp_persistence_read_runtime_test.dart')
          .readAsStringSync(),
      contains(
        '../../integration_test/g1_prov02_lpp_persistence_read_patrol_test.dart',
      ),
    );
  });
}
