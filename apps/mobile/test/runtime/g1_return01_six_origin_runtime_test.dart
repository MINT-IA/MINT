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
      "bool.fromEnvironment('MINT_TEST_FIRST_JOB')",
      "'work_save'",
      "'housing_cancel'",
      "'disability_validation_cancel'",
      "'succession_save'",
      "'frontalier_inline'",
      'const MintApp()',
      'testOnlyRootRouter.go',
      "const Key('first_job_enrich_profile_cta')",
      "const Key('first_job_salary_authority')",
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
      "const Key('first_job_result_cards')",
      "const Key('first_job_ledger_facts')",
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
    final scroll = housing.indexOf(r'await $(housingNotice).scrollTo()');
    final presence = housing.indexOf(
      'expect(housingNotice, findsOneWidget)',
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
    final tap = housing.indexOf(r'await $(housingCta).tap()');
    final collector = housing.indexOf('final collectorRouteVerified');

    expect(scroll, greaterThan(notice));
    expect(presence, greaterThan(scroll));
    expect(typeAssertion, greaterThan(presence));
    expect(descendant, greaterThan(typeAssertion));
    expect(exactlyOne, greaterThan(descendant));
    expect(tap, greaterThan(exactlyOne));
    expect(collector, greaterThan(tap));
    expect(housing, isNot(contains(r'await $(cta).scrollTo().tap()')));
    expect(
      housing,
      isNot(contains(r'await $(housingNotice).scrollTo().tap()')),
    );
  });

  test(
      'Patrol teardown preserves only the Housing seed consumed by Maestro while pre-clear remains',
      () {
    final source = _read(
      'integration_test/g1_return01_six_origin_patrol_test.dart',
    );
    const seededStages = "const _maestroSeedStages = <String>{\n"
        "  'housing_cancel',\n"
        "};";
    expect(source, contains(seededStages));
    expect(RegExp("'housing_cancel'").allMatches(seededStages), hasLength(1));
    for (final unseededStage in const <String>[
      'work_save',
      'disability_validation_cancel',
      'succession_save',
      'frontalier_inline',
    ]) {
      expect(seededStages, isNot(contains("'$unseededStage'")));
    }

    final teardown = source.indexOf('addTearDown(() async {');
    final conditional = source.indexOf(
      'if (!_maestroSeedStages.contains(_stage))',
      teardown,
    );
    final teardownClear = source.indexOf(
      'await ReportPersistenceService.clearDiagnostic();',
      conditional,
    );
    final teardownEnd = source.indexOf('});', teardownClear);
    final preStageClear = source.indexOf(
      'await ReportPersistenceService.clearDiagnostic();',
      teardownEnd,
    );
    final stageDispatch = source.indexOf('final proof = await switch (_stage)');

    expect(teardown, greaterThanOrEqualTo(0));
    expect(conditional, greaterThan(teardown));
    expect(teardownClear, greaterThan(conditional));
    expect(teardownEnd, greaterThan(teardownClear));
    expect(preStageClear, greaterThan(teardownEnd));
    expect(stageDispatch, greaterThan(preStageClear));
  });

  test('installed-app Maestro flows use stable bounded-proof selectors', () {
    const flows = <String, List<String>>{
      '.maestro/g1_return01_work_return.yaml': <String>[
        'first_job_enrich_profile_cta',
        'salary_input',
        'salary_save_cta',
        'first_job_salary_authority',
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
      if (entry.key.endsWith('g1_return01_frontalier_inline.yaml')) {
        expect(source, contains('clearState: true'), reason: entry.key);
      } else {
        expect(source, isNot(contains('clearState: true')), reason: entry.key);
      }
      expect(source, isNot(contains('returnUri=')), reason: entry.key);
    }
    expect(
      _read('.maestro/g1_return01_work_return.yaml'),
      contains('Build contract: --dart-define=MINT_TEST_FIRST_JOB=true'),
    );
  });

  test('cancel Maestro flows tap the collector return action', () {
    for (final path in const <String>[
      '.maestro/g1_return01_housing_cancel_return.yaml',
      '.maestro/g1_return01_disability_return.yaml',
    ]) {
      final source = _read(path);
      expect(
        source,
        contains(
          '- tapOn:\n    id: "data_block_cancel_return_cta"',
        ),
        reason: path,
      );
      expect(source, isNot(contains('\n- back\n')), reason: path);
    }
  });

  test('Disability Maestro seeds salary before opening the real origin', () {
    final source = _read('.maestro/g1_return01_disability_return.yaml');
    final mortgage = source.indexOf('- openLink: "mint:///hypotheque"');
    final mortgageReady = source.indexOf(
      'id: "mortgage_afford_result"',
      mortgage,
    );
    final mortgageCta = source.indexOf(
      'id: "mortgage_enrich_profile_cta"',
      mortgageReady,
    );
    final salaryInput = source.indexOf('id: "salary_input"', mortgageCta);
    final salaryValue = source.indexOf('- inputText: "96000"', salaryInput);
    final salarySave = source.indexOf('id: "salary_save_cta"', salaryValue);
    final mortgageCtaReadyAfterSave = source.indexOf(
      '- extendedWaitUntil:\n    visible:\n      id: "mortgage_enrich_profile_cta"',
      salarySave,
    );
    final invalidite = source.indexOf(
      '- openLink: "mint:///invalidite"',
      mortgageCtaReadyAfterSave,
    );
    final disabilityReady = source.indexOf(
      'id: "disability_gap_ledger_facts"',
      invalidite,
    );
    final birthYear = source.indexOf('id: "birth_year_input"', disabilityReady);
    final invalidValue = source.indexOf('- inputText: "1800"', birthYear);
    final cancel = source.indexOf(
      'id: "data_block_cancel_return_cta"',
      invalidValue,
    );

    expect(mortgage, greaterThanOrEqualTo(0));
    expect(mortgageReady, greaterThan(mortgage));
    expect(mortgageCta, greaterThan(mortgageReady));
    expect(salaryInput, greaterThan(mortgageCta));
    expect(salaryValue, greaterThan(salaryInput));
    expect(salarySave, greaterThan(salaryValue));
    expect(mortgageCtaReadyAfterSave, greaterThan(salarySave));
    expect(invalidite, greaterThan(mortgageCtaReadyAfterSave));
    expect(disabilityReady, greaterThan(invalidite));
    expect(birthYear, greaterThan(disabilityReady));
    expect(invalidValue, greaterThan(birthYear));
    expect(cancel, greaterThan(invalidValue));
    expect(RegExp('- inputText: "96000"').allMatches(source), hasLength(1));
    expect(
      RegExp('id: "mortgage_afford_result"').allMatches(source),
      hasLength(1),
      reason: 'Only the initial Mortgage arrival uses the top result anchor',
    );
    for (final forbidden in const <String>[
      'clearState: true',
      'returnUri=',
      'SharedPreferences',
      'flutter_secure_storage',
      'Keychain',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('Maestro waits on visible route anchors before scrolling to CTAs', () {
    final work = _read('.maestro/g1_return01_work_return.yaml');
    final workReady = work.indexOf(
      '- extendedWaitUntil:\n    visible:\n'
      '      id: "first_job_enrich_profile_cta"',
    );
    final workTap = work.indexOf(
      '- tapOn:\n    id: "first_job_enrich_profile_cta"',
    );
    final salaryAuthority = work.indexOf(
      '- extendedWaitUntil:\n    visible:\n'
      '      id: "first_job_salary_authority"',
      workTap,
    );

    expect(workReady, greaterThanOrEqualTo(0));
    expect(workTap, greaterThan(workReady));
    expect(salaryAuthority, greaterThan(workTap));
    expect(work, isNot(contains('first_job_ledger_facts')));
    expect(work, isNot(contains('first_job_result_cards')));

    const cases = <String, (String, String)>{
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

  test('both First Job Patrol targets require the bounded compile-time gate',
      () {
    for (final path in const <String>[
      'integration_test/g1_return01_first_job_return_patrol_test.dart',
      'integration_test/g1_return01_six_origin_patrol_test.dart',
    ]) {
      final source = _read(path);
      expect(source, contains("bool.fromEnvironment('MINT_TEST_FIRST_JOB')"),
          reason: path);
      expect(source, contains('FeatureFlags.enableFirstJobScreen'),
          reason: path);
      expect(source, contains('--dart-define=MINT_TEST_FIRST_JOB=true'),
          reason: path);
      expect(source, contains("const Key('first_job_salary_authority')"),
          reason: path);
      expect(source, isNot(contains("const Key('first_job_result_cards')")),
          reason: path);
      expect(source, isNot(contains("const Key('first_job_ledger_facts')")),
          reason: path);
    }
  });

  test('First Job runtime anchor is live and runner wires the bounded build',
      () {
    final screen = _read('lib/screens/first_job_screen.dart');
    expect(
      screen,
      contains("key: const Key('first_job_salary_authority')"),
    );
    expect(
      screen,
      contains("identifier: 'first_job_salary_authority'"),
    );
    expect(
      screen,
      contains("identifier: 'first_job_enrich_profile_cta'"),
    );

    final runner = _read('../../tools/simulator/patrol_return01_six_origin.sh');
    for (final anchor in const <String>[
      'first_job_app=',
      'flutter build ios --simulator --debug '
          '--dart-define=MINT_TEST_FIRST_JOB=true',
      'work_save)\n      overlay_app=\$first_job_app',
      'work_save) first_job_define=(--dart-define=MINT_TEST_FIRST_JOB=true)',
      r'"${first_job_define[@]}"',
      "work_save) printf '%s\\n' 'first_job_salary_authority'",
    ]) {
      expect(runner, contains(anchor), reason: anchor);
    }
  });

  test('fresh-install Maestro flows wait for router readiness before links',
      () {
    for (final path in const <String>[
      '.maestro/g1_return01_work_return.yaml',
      '.maestro/g1_return01_succession_return.yaml',
      '.maestro/g1_return01_frontalier_inline.yaml',
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

  test('overlay Maestro flows wait for router readiness before links', () {
    const cases = <String, String>{
      '.maestro/g1_return01_housing_cancel_return.yaml':
          'mortgage_afford_result',
      '.maestro/g1_return01_disability_return.yaml':
          'disability_gap_ledger_facts',
    };

    for (final entry in cases.entries) {
      final source = _read(entry.key);
      final launch = source.indexOf('- launchApp');
      final landingReady = source.indexOf(
        '- extendedWaitUntil:\n    visible:\n      id: "landing_route"',
      );
      final openLink = source.indexOf('- openLink:');
      final routeReady = source.indexOf(
        '- extendedWaitUntil:\n    visible:\n      id: "${entry.value}"',
      );

      expect(launch, greaterThanOrEqualTo(0), reason: entry.key);
      expect(landingReady, greaterThan(launch), reason: entry.key);
      expect(openLink, greaterThan(landingReady), reason: entry.key);
      expect(routeReady, greaterThan(openLink), reason: entry.key);
    }
  });

  test(
      'Frontalier Maestro creates FR CH GE through production UI then proves cold readback',
      () {
    final source = _read('.maestro/g1_return01_frontalier_inline.yaml');

    final freshLaunch = source.indexOf(
      '- launchApp:\n    clearState: true',
    );
    final firstOpen = source.indexOf(
      '- openLink: "mint:///segments/frontalier"',
      freshLaunch,
    );
    final residenceTap = source.indexOf(
      '- tapOn:\n    id: "frontier_residence_country_field"',
      firstOpen,
    );
    final france = source.indexOf(
      '- tapOn:\n    text: "France.*FR"',
      residenceTap,
    );
    final workTap = source.indexOf(
      '- tapOn:\n    id: "frontier_work_country_field"',
      france,
    );
    final switzerland = source.indexOf(
      '- tapOn:\n    text: "Suisse.*CH"',
      workTap,
    );
    final cantonTap = source.indexOf(
      '- tapOn:\n    id: "frontier_work_canton_field"',
      switzerland,
    );
    final geneva = source.indexOf(
      '- tapOn:\n    text: "GE"',
      cantonTap,
    );
    final firstKnown = source.indexOf(
      'id: "frontier_jurisdiction_known_state"',
      geneva,
    );
    final stop = source.indexOf('- stopApp', firstKnown);
    final coldLaunch = source.indexOf(
      '- launchApp:\n    clearState: false',
      stop,
    );
    final secondOpen = source.indexOf(
      '- openLink: "mint:///segments/frontalier"',
      coldLaunch,
    );
    final secondResidence = source.indexOf(
      'id: "frontier_residence_country_field"',
      secondOpen,
    );
    final readbackFrance = source.indexOf(
      'text: "France.*FR"',
      secondResidence,
    );
    final readbackSwitzerland = source.indexOf(
      'text: "Suisse.*CH"',
      readbackFrance,
    );
    final readbackGeneva = source.indexOf(
      'text: "GE"',
      readbackSwitzerland,
    );
    final secondKnown = source.indexOf(
      'id: "frontier_jurisdiction_known_state"',
      readbackGeneva,
    );

    expect(freshLaunch, greaterThanOrEqualTo(0));
    expect(firstOpen, greaterThan(freshLaunch));
    expect(residenceTap, greaterThan(firstOpen));
    expect(france, greaterThan(residenceTap));
    expect(workTap, greaterThan(france));
    expect(switzerland, greaterThan(workTap));
    expect(cantonTap, greaterThan(switzerland));
    expect(geneva, greaterThan(cantonTap));
    expect(firstKnown, greaterThan(geneva));
    expect(stop, greaterThan(firstKnown));
    expect(coldLaunch, greaterThan(stop));
    expect(secondOpen, greaterThan(coldLaunch));
    expect(secondResidence, greaterThan(secondOpen));
    expect(readbackFrance, greaterThan(secondResidence));
    expect(readbackSwitzerland, greaterThan(readbackFrance));
    expect(readbackGeneva, greaterThan(readbackSwitzerland));
    expect(secondKnown, greaterThan(readbackGeneva));
    expect(
      RegExp('openLink: "mint:///segments/frontalier"').allMatches(source),
      hasLength(2),
    );
    for (final forbidden in const <String>[
      'SharedPreferences',
      'flutter_secure_storage',
      'Keychain',
      'wizard_answers_v2',
      'q_residence_country',
      'q_work_country',
      'q_work_canton',
      'inputText:',
      'runScript:',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
