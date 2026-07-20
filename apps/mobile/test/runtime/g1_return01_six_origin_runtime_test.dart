import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('versioned Patrol target owns the five non-RVC runtime stages', () {
    const target = 'integration_test/g1_return01_six_origin_patrol_test.dart';
    const wrapper = 'test/patrol/g1_return01_six_origin_runtime_test.dart';
    expect(File(target).existsSync(), isTrue, reason: target);
    expect(File(wrapper).existsSync(), isTrue, reason: wrapper);

    final source = _read(target);
    for (final anchor in const <String>[
      "String.fromEnvironment('MINT_G1_RETURN01_STAGE')",
      "String.fromEnvironment('MINT_G1_RETURN01_SOURCE_SHA')",
      "'work_save'",
      "'housing_cancel'",
      "'disability_validation_cancel'",
      "'succession_save'",
      "'frontalier_inline'",
      'const MintApp()',
      'testOnlyRootRouter.go',
      "const Key('first_job_enrich_profile_cta')",
      "const Key('mortgage_enrich_profile_cta')",
      "const Key('disability_gap_enrich_cta')",
      "const Key('succession_property_missing')",
      "const Key('frontier_residence_country_field')",
      "const Key('frontier_work_country_field')",
      "const Key('frontier_work_canton_field')",
      'ReportPersistenceService.loadAnswers()',
      "'returnUri'",
      "'/data-block/revenu'",
      "'/data-block/patrimoine'",
      r'mint-g1-return01-$_stage-witness-v1.json',
      "'schemaVersion': 1",
      "'caseId': 'G1-RETURN-01'",
      "'syntheticDataOnly': true",
      "'collectorRouteVerified'",
      "'routeAfterVerified': proof.routeAfterVerified",
      "'storeWriteVerified'",
      "'storeUnchangedVerified'",
      "'validationRetainedVerified'",
      "'noDataBlockVerified'",
      "'frontalierCanonicalWritesVerified'",
      'rename(witness.path)',
      'final class _StageProof',
      '_writeWitness(witness, proof)',
      'proof.collectorRouteVerified',
      'proof.storeWriteVerified',
      'proof.storeUnchangedVerified',
      'proof.validationRetainedVerified',
      'proof.noDataBlockVerified',
      'proof.frontalierCanonicalWritesVerified',
    ]) {
      expect(source, contains(anchor), reason: anchor);
    }
    for (final forbidden in const <String>[
      'g1_return01_rvc_lpp_scan_return_patrol_test.dart',
      'debugFailure',
      'forceFailure',
      'failureInjection',
      'returnUri=https',
      'visual-ready',
      'visualReady',
      'Duration(seconds: 90)',
      'const collector = _stage',
      'const storeWrite = _stage',
      'const storeUnchanged =',
      'const validationRetained = _stage',
      'const frontalier = _stage',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(_read(wrapper), contains(target.split('/').last));
  });

  test('Housing Patrol taps the actionable notice descendant', () {
    final source = _read(
      'integration_test/g1_return01_six_origin_patrol_test.dart',
    );
    final start = source.indexOf('Future<_StageProof> _runHousingCancel');
    final end = source.indexOf(
      'Future<_StageProof> _runDisabilityValidationCancel',
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final housing = source.substring(start, end);

    final notice = housing.indexOf(
      "final housingNotice = find.byKey(const Key('mortgage_enrich_profile_cta'))",
    );
    final typeAssertion = housing.indexOf(
      r'expect($.tester.widget(housingNotice), isA<MintConfidenceNotice>())',
    );
    final descendant = housing.indexOf(
      'final housingCta = find.descendant(',
    );
    final exactlyOne = housing.indexOf(
      'expect(housingCta, findsOneWidget)',
    );
    final scroll = housing.indexOf(r'await $(housingNotice).scrollTo()');
    final tap = housing.indexOf(r'await $(housingCta).tap()');
    final collector = housing.indexOf('final collectorRouteVerified');

    expect(typeAssertion, greaterThan(notice));
    expect(descendant, greaterThan(typeAssertion));
    expect(exactlyOne, greaterThan(descendant));
    expect(scroll, greaterThan(exactlyOne));
    expect(tap, greaterThan(scroll));
    expect(collector, greaterThan(tap));
    expect(housing, isNot(contains(r'await $(cta).scrollTo().tap()')));
    expect(
      housing,
      isNot(contains(r'await $(housingNotice).scrollTo().tap()')),
    );
  });

  test('installed-app Maestro flows use stable production selectors', () {
    const flows = <String, List<String>>{
      '.maestro/g1_return01_work_return.yaml': <String>[
        'first_job_enrich_profile_cta',
        'salary_input',
        'salary_save_cta',
        'first_job_result_cards',
      ],
      '.maestro/g1_return01_housing_cancel_return.yaml': <String>[
        'mortgage_enrich_profile_cta',
        'salary_input',
        'mortgage_enrich_profile_cta',
      ],
      '.maestro/g1_return01_disability_return.yaml': <String>[
        'disability_gap_enrich_cta',
        'birth_year_input',
        'disability_gap_ledger_facts',
      ],
      '.maestro/g1_return01_succession_return.yaml': <String>[
        'succession_property_missing',
        'property_market_value_input',
        'patrimoine_save_cta',
      ],
      '.maestro/g1_return01_frontalier_inline.yaml': <String>[
        'frontier_residence_country_field',
        'frontier_work_country_field',
        'frontier_work_canton_field',
        'frontier_jurisdiction_known_state',
      ],
    };

    for (final entry in flows.entries) {
      expect(File(entry.key).existsSync(), isTrue, reason: entry.key);
      final source = _read(entry.key);
      expect(source, contains('appId: ch.mint.app'), reason: entry.key);
      expect(source, contains('openLink: "mint:///'), reason: entry.key);
      expect(source, contains('visible: "Ouvrir"'), reason: entry.key);
      expect(source, contains('visible: "Open"'), reason: entry.key);
      for (final selector in entry.value) {
        expect(source, contains('id: "$selector"'),
            reason: '${entry.key}: $selector');
      }
      expect(source, isNot(contains('clearState: true')), reason: entry.key);
      expect(source, isNot(contains('returnUri=')), reason: entry.key);
    }
  });

  test('Maestro waits on visible route anchors before scrolling to CTAs', () {
    const cases = <String, (String, String)>{
      '.maestro/g1_return01_work_return.yaml': (
        'first_job_ledger_facts',
        'first_job_enrich_profile_cta',
      ),
      '.maestro/g1_return01_housing_cancel_return.yaml': (
        'mortgage_afford_result',
        'mortgage_enrich_profile_cta',
      ),
    };

    for (final entry in cases.entries) {
      final source = _read(entry.key);
      final anchor = entry.value.$1;
      final cta = entry.value.$2;
      final waitAnchor = source.indexOf(
        '- extendedWaitUntil:\n    visible:\n      id: "$anchor"',
      );
      final scrollCta = source.indexOf(
        '- scrollUntilVisible:\n    element:\n      id: "$cta"',
      );

      expect(waitAnchor, greaterThanOrEqualTo(0), reason: entry.key);
      expect(scrollCta, greaterThan(waitAnchor), reason: entry.key);
      expect(
        source,
        isNot(contains(
          '- extendedWaitUntil:\n    visible:\n      id: "$cta"',
        )),
        reason: entry.key,
      );
    }
  });

  test('fresh-install Maestro flows wait for router readiness before links',
      () {
    for (final path in const <String>[
      '.maestro/g1_return01_work_return.yaml',
      '.maestro/g1_return01_succession_return.yaml',
    ]) {
      final source = _read(path);
      final launch = source.indexOf('- launchApp');
      final landingReady = source.indexOf(
        '- extendedWaitUntil:\n    visible:\n      id: "landing_route"',
      );
      final openLink = source.indexOf('- openLink:');

      expect(launch, greaterThanOrEqualTo(0), reason: path);
      expect(landingReady, greaterThan(launch), reason: path);
      expect(openLink, greaterThan(landingReady), reason: path);
    }
  });
}
