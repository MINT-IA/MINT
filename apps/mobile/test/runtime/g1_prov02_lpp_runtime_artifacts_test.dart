import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Maestro proves exact LPP default-off and stale deep-link recovery', () {
    final flow = File('.maestro/g1_prov02_lpp_flag_off.yaml');
    expect(flow.existsSync(), isTrue);
    expect(flow.readAsStringSync(), '''appId: ch.mint.app
---
# G1-PROV-02: production-default flags hide LPP before acquisition, while
# volatile review and impact deep links recover safely after process loss.
- launchApp:
    clearState: true
- openLink: "mint:///scan?type=lppCertificate"
- assertVisible:
    id: "document_scan_capture_cta"
- assertNotVisible:
    id: "document_scan_lpp_type_selector"
- assertNotVisible:
    id: "document_scan_lpp_example_cta"
- assertNotVisible:
    id: "lpp_review_confirm_cta"
- takeScreenshot: g1_prov02_lpp_flag_off
- openLink: "mint:///scan/review?scanSessionId=prov02-stale-review"
- assertVisible:
    id: "scan_review_recovery_cta"
- takeScreenshot: g1_prov02_lpp_stale_review
- tapOn:
    id: "scan_review_recovery_cta"
- assertVisible:
    id: "document_scan_capture_cta"
- openLink: "mint:///scan/impact?scanSessionId=prov02-stale-impact"
- assertVisible:
    id: "scan_impact_recovery_cta"
- takeScreenshot: g1_prov02_lpp_stale_impact
- tapOn:
    id: "scan_impact_recovery_cta"
- assertVisible:
    id: "home_route"
''');
  });

  test('Patrol writer uses only the checked-in synthetic scan surface', () {
    final source = File(
      'integration_test/g1_prov02_lpp_persistence_write_patrol_test.dart',
    );
    expect(source.existsSync(), isTrue);
    final contents = source.readAsStringSync();
    for (final anchor in const [
      "FeatureFlags.typedLppEvidence = true",
      "FeatureFlags.documentLppEvidenceEnabled = true",
      "#document_scan_lpp_type_selector).waitUntilVisible()",
      "#document_scan_lpp_type_selector).tap()",
      "#document_scan_lpp_example_cta",
      "'q_partner_birth_year': 1982",
      "'q_partner_employment_status': 'salarie'",
      "invitationLevel, 'declared'",
      "#lpp_acquisition_owner_manual_partner",
      "#lpp_acquisition_partner_attestation",
      "#lpp_acquisition_cancel",
      "retainedSessionCount, 0",
      "#lpp_acquisition_partner_attest_confirm",
      "#lpp_review_owner_badge",
      "#lpp_review_restart_owner_cta",
      "#lpp_review_source_date",
      "#lpp_review_confirm_cta",
      "document_impact_return_cta",
      "LppEvidenceSelector.selectManualPartner",
      "LppEvidenceAuthorizationMode.manualPartnerDeclaration",
      "authorizationGrantId, isNull",
      "#lpp_acquisition_owner_self",
      "LppEvidenceSelector.selectSelf",
      "LppEvidenceSelector.selectSelf",
      "LppEvidenceFactKey.vestedBenefitsCapitalChf",
      "LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf",
      "LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf",
      "LppEvidenceFactKey.insuredSalaryAnnualChf",
      "LppEvidenceFactKey.maximumBuybackCapitalChf",
      "LppEvidenceFactKey.mandatoryConversionRateRatio",
      "LppEvidenceFactKey.extraMandatoryConversionRateRatio",
      "LppEvidenceFactKey.retirementPensionAnnualChf",
      "LppEvidenceFactKey.retirementCapitalLumpSumChf",
      "LppEvidenceFactKey.disabilityPensionAnnualChf",
      "LppEvidenceFactKey.disabilityCapitalLumpSumChf",
      "LppEvidenceFactKey.deathCapitalLumpSumChf",
      "const _sourceDate = '2025-12-31'",
    ]) {
      expect(contents, contains(anchor), reason: anchor);
    }
    expect(contents, isNot(contains('acceptLppReview(')));
    expect(contents, isNot(contains('#lpp_review_subject_self')));
    expect(contents, isNot(contains('#lpp_review_subject_manual_partner')));
    expect(contents, isNot(contains('File(')));
    expect(contents, isNot(contains('Directory.')));
  });

  test('Patrol writer proves the partner impact CTA tap before deep linking',
      () {
    final contents = File(
      'integration_test/g1_prov02_lpp_persistence_write_patrol_test.dart',
    ).readAsStringSync();
    final partnerImpactStart = contents.indexOf(
      "find.bySemanticsIdentifier('document_impact_return_cta')",
    );
    final selfAcquisitionStart = contents.indexOf(
      "'mint:///scan?type=lppCertificate'",
      partnerImpactStart,
    );

    expect(partnerImpactStart, greaterThanOrEqualTo(0));
    expect(selfAcquisitionStart, greaterThan(partnerImpactStart));
    final partnerImpactSegment =
        contents.substring(partnerImpactStart, selfAcquisitionStart);
    final tapIndex = RegExp(
          r"find\.bySemanticsIdentifier\('document_impact_return_cta'\)\)\s*"
          r'\.scrollTo\(\)\s*'
          r'\.tap\(\);',
        ).firstMatch(partnerImpactSegment)?.start ??
        -1;
    final settleIndex = partnerImpactSegment.indexOf(
      r'await $.pumpAndSettle();',
    );
    final discardedSessionIndex = partnerImpactSegment.indexOf(
      'expect(scanSessions.retainedSessionCount, 0);',
    );
    final removedCtaIndex = RegExp(
          r"expect\(\s*find\.bySemanticsIdentifier\('document_impact_return_cta'\),\s*"
          r'findsNothing,?\s*\);',
        ).firstMatch(partnerImpactSegment)?.start ??
        -1;

    expect(tapIndex, greaterThanOrEqualTo(0));
    expect(settleIndex, greaterThan(tapIndex));
    expect(discardedSessionIndex, greaterThan(settleIndex));
    expect(removedCtaIndex, greaterThan(discardedSessionIndex));
  });

  test('Patrol writer makes the final self impact CTA visible', () {
    final contents = File(
      'integration_test/g1_prov02_lpp_persistence_write_patrol_test.dart',
    ).readAsStringSync();
    final selfAcquisitionStart = contents.indexOf(
      '#lpp_acquisition_owner_self',
    );
    final selfImpactFlowStart = contents.indexOf(
      r'await $(#lpp_review_confirm_cta).scrollTo().tap();',
      selfAcquisitionStart,
    );
    final selfLedgerAssertionStart = contents.indexOf(
      "rawRoot = provider.reportAnswersSnapshot['_coach_lpp_evidence_v1']",
      selfImpactFlowStart,
    );

    expect(selfAcquisitionStart, greaterThanOrEqualTo(0));
    expect(selfImpactFlowStart, greaterThan(selfAcquisitionStart));
    expect(selfLedgerAssertionStart, greaterThan(selfImpactFlowStart));
    expect(
      contents.substring(selfImpactFlowStart, selfLedgerAssertionStart),
      matches(
        RegExp(
          r'final selfImpactCta\s*=\s*\$\('
          r"find\.bySemanticsIdentifier\('document_impact_return_cta'\)\);\s*"
          r'await selfImpactCta\.scrollTo\(\);\s*'
          r'await selfImpactCta\.waitUntilVisible\(\);',
        ),
      ),
    );
  });

  test('Patrol cold reader validates 12 facts and five presentation facts', () {
    final source = File(
      'integration_test/g1_prov02_lpp_persistence_read_patrol_test.dart',
    );
    expect(source.existsSync(), isTrue);
    final contents = source.readAsStringSync();
    for (final anchor in const [
      "FeatureFlags.typedLppEvidence = true",
      "FeatureFlags.documentLppEvidenceEnabled = true",
      "provider.waitForReportAnswers()",
      "LppEvidenceSelector.selectSelf",
      "LppEvidenceFactKey.vestedBenefitsCapitalChf",
      "LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf",
      "LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf",
      "LppEvidenceFactKey.insuredSalaryAnnualChf",
      "LppEvidenceFactKey.maximumBuybackCapitalChf",
      "LppEvidenceFactKey.mandatoryConversionRateRatio",
      "LppEvidenceFactKey.extraMandatoryConversionRateRatio",
      "LppEvidenceFactKey.retirementPensionAnnualChf",
      "LppEvidenceFactKey.retirementCapitalLumpSumChf",
      "LppEvidenceFactKey.disabilityPensionAnnualChf",
      "LppEvidenceFactKey.disabilityCapitalLumpSumChf",
      "LppEvidenceFactKey.deathCapitalLumpSumChf",
      "LppEvidenceRoot.fromJsonString",
      "LppEvidenceSelector.selectManualPartner",
      "manualPartner, isNotNull",
      "legacyPartnerQuarantine, isNull",
      "LppEvidenceAuthorizationMode.self",
      "LppEvidenceAuthorizationMode.manualPartnerDeclaration",
      "authorizationGrantId, isNull",
      "ReportPersistenceService.backendSafeAnswers",
      "'\"sourceText\"'",
      "'\"rawOcr\"'",
      "DateTime.utc(2025, 12, 31)",
    ]) {
      expect(contents, contains(anchor), reason: anchor);
    }
    expect(contents, isNot(contains('ReportPersistenceService.clear')));
    expect(contents, isNot(contains('File(')));
    expect(contents, isNot(contains('Directory.')));
  });

  test('Patrol fact oracles use exact ratio tolerance and canonical units', () {
    for (final path in const [
      'integration_test/g1_prov02_lpp_persistence_write_patrol_test.dart',
      'integration_test/g1_prov02_lpp_persistence_read_patrol_test.dart',
    ]) {
      final contents = File(path).readAsStringSync();
      expect(contents, contains('persisted!.unit, entry.key.unit'),
          reason: path);
      expect(
        contents,
        contains(
          'entry.key.unit == LppEvidenceUnit.ratio ? 1e-12 : 0.01',
        ),
        reason: path,
      );
    }
  });

  test('Patrol wrappers expose writer then cold reader to configured directory',
      () {
    expect(
      File('test/patrol/g1_prov02_lpp_persistence_write_runtime_test.dart')
          .readAsStringSync(),
      contains(
        "../../integration_test/g1_prov02_lpp_persistence_write_patrol_test.dart",
      ),
    );
    expect(
      File('test/patrol/g1_prov02_lpp_persistence_read_runtime_test.dart')
          .readAsStringSync(),
      contains(
        "../../integration_test/g1_prov02_lpp_persistence_read_patrol_test.dart",
      ),
    );
    expect(
        File('pubspec.yaml').readAsStringSync(),
        contains(
          'test_directory: test/patrol',
        ));
  });
}
