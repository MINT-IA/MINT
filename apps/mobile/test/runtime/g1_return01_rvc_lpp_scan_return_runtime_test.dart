import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Patrol owns the flagged exact-SHA native RVC return journey', () {
    final source = File(
      'integration_test/g1_return01_rvc_lpp_scan_return_patrol_test.dart',
    );
    expect(source.existsSync(), isTrue);
    final contents = source.readAsStringSync();
    for (final anchor in const <String>[
      'const MintApp()',
      "FeatureFlags.typedLppEvidence = true",
      "FeatureFlags.documentLppEvidenceEnabled = true",
      "FeatureFlags.typedLppEvidence = false",
      "FeatureFlags.documentLppEvidenceEnabled = false",
      'final semantics = \$.tester.ensureSemantics()',
      'semantics.dispose',
      "const Key('indicatif_banner_lpp_cta')",
      "const Key('data_block_lpp_scan_cta')",
      "const Key('document_scan_lpp_example_cta')",
      "const Key('lpp_acquisition_self_continue')",
      "const Key('lpp_review_confirm_cta')",
      "const Key('lpp_impact_retirement_cta')",
      '44e89678edff36f64383a75c37bdcaa3c7ca49e7cb7242a3bb9c1371df9780f2',
      "'scanSessionId': scanSessionId!",
      "'scanReturnId': scanReturnId!",
      "'mint-g1-return01-rvc-lpp-visual-ready-v1.marker'",
    ]) {
      expect(contents, contains(anchor), reason: anchor);
    }
  });

  test('Maestro only attaches to the Patrol-owned final visual state', () {
    final flow = File(
      '.maestro/g1_return01_rvc_lpp_scan_return.yaml',
    );
    expect(flow.existsSync(), isTrue);
    final contents = flow.readAsStringSync();
    expect(contents, contains('appId: ch.mint.app'));
    expect(contents, contains('id: "rvc_screen"'));
    expect(
        contents, contains('takeScreenshot: g1_return01_rvc_lpp_exact_return'));
    for (final forbidden in const <String>[
      'launchApp',
      'stopApp',
      'clearState',
      'openLink',
    ]) {
      expect(contents, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
