import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/premium/mint_confidence_notice.dart';
import 'package:patrol/patrol.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
const _stage = String.fromEnvironment('MINT_G1_RETURN01_STAGE');
const _sourceSha = String.fromEnvironment('MINT_G1_RETURN01_SOURCE_SHA');
const _supportedStages = <String>{
  'work_save',
  'housing_cancel',
  'disability_validation_cancel',
  'succession_save',
  'frontalier_inline',
};

final class _StageProof {
  const _StageProof({
    required this.stage,
    required this.routeBefore,
    required this.routeAfter,
    required this.collectorRouteVerified,
    required this.routeAfterVerified,
    required this.storeWriteVerified,
    required this.storeUnchangedVerified,
    required this.validationRetainedVerified,
    required this.noDataBlockVerified,
    required this.frontalierCanonicalWritesVerified,
  });

  final String stage;
  final String routeBefore;
  final String routeAfter;
  final bool collectorRouteVerified;
  final bool routeAfterVerified;
  final bool storeWriteVerified;
  final bool storeUnchangedVerified;
  final bool validationRetainedVerified;
  final bool noDataBlockVerified;
  final bool frontalierCanonicalWritesVerified;
}

void main() {
  patrolTest(
    'runs one strict G1-RETURN-01 six-origin v1 stage',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 6)),
    ($) async {
      if (!_supportedStages.contains(_stage)) {
        fail(
          'MINT_G1_RETURN01_STAGE must be exactly one of '
          '${_supportedStages.join(', ')}; got "$_stage"',
        );
      }
      if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(_sourceSha)) {
        fail('MINT_G1_RETURN01_SOURCE_SHA must be lower 40hex');
      }

      final witness = File(
        '${Directory.systemTemp.path}/'
        'mint-g1-return01-$_stage-witness-v1.json',
      );
      addTearDown(() async {
        await ReportPersistenceService.clearDiagnostic();
      });
      if (await witness.exists()) await witness.delete();

      await ReportPersistenceService.clearDiagnostic();
      await ReportPersistenceService.setMiniOnboardingCompleted(true);

      final proof = await switch (_stage) {
        'work_save' => _runWorkSave($),
        'housing_cancel' => _runHousingCancel($),
        'disability_validation_cancel' => _runDisabilityValidationCancel($),
        'succession_save' => _runSuccessionSave($),
        'frontalier_inline' => _runFrontalierInline($),
        _ => throw StateError('unreachable stage $_stage'),
      };
      expect(proof.stage, _stage);

      await _writeWitness(witness, proof);
    },
  );
}

Future<_StageProof> _runWorkSave(PatrolIntegrationTester $) async {
  await $.pumpWidgetAndSettle(const MintApp());
  testOnlyRootRouter.go('/first-job');
  await $.pumpAndSettle();
  final routeBefore = _expectExactRoute('/first-job');

  final cta = find.byKey(const Key('first_job_enrich_profile_cta'));
  await $(cta).scrollTo().tap();
  await $.pumpAndSettle();
  final collectorRouteVerified =
      _expectCollector($, path: '/data-block/revenu', origin: '/first-job');

  await $(find.byKey(const Key('salary_input'))).enterText('96000');
  await $(find.byKey(const Key('canton_picker'))).enterText('GE');
  await $(find.byKey(const Key('birth_year_input'))).enterText('2001');
  await $(find.byKey(const Key('salary_save_cta'))).scrollTo().tap();
  await $.pumpAndSettle();

  final routeAfter = _expectExactRoute('/first-job');
  final persisted = await ReportPersistenceService.loadAnswers();
  final storeWriteVerified = persisted['q_gross_salary_annual'] == 96000.0 &&
      persisted['q_canton'] == 'GE' &&
      persisted['q_birth_year'] == 2001;
  expect(storeWriteVerified, isTrue);
  await _scrollAndWait($, find.byKey(const Key('first_job_result_cards')));
  final routeAfterVerified = routeAfter == routeBefore;
  expect(routeAfterVerified, isTrue);
  return _StageProof(
    stage: 'work_save',
    routeBefore: routeBefore,
    routeAfter: routeAfter,
    collectorRouteVerified: collectorRouteVerified,
    routeAfterVerified: routeAfterVerified,
    storeWriteVerified: storeWriteVerified,
    storeUnchangedVerified: false,
    validationRetainedVerified: false,
    noDataBlockVerified: false,
    frontalierCanonicalWritesVerified: false,
  );
}

Future<_StageProof> _runHousingCancel(PatrolIntegrationTester $) async {
  await ReportPersistenceService.saveAnswers(const <String, dynamic>{
    'q_birth_year': 1985,
  });
  final before = await _canonicalAnswerBytes();
  await $.pumpWidgetAndSettle(const MintApp());
  testOnlyRootRouter.go('/hypotheque');
  await $.pumpAndSettle();
  final routeBefore = _expectExactRoute('/hypotheque');

  final housingNotice = find.byKey(const Key('mortgage_enrich_profile_cta'));
  await $(housingNotice).scrollTo();
  expect(housingNotice, findsOneWidget);
  expect($.tester.widget(housingNotice), isA<MintConfidenceNotice>());
  final housingCta = find.descendant(
    of: housingNotice,
    matching: find.byType(GestureDetector),
  );
  expect(housingCta, findsOneWidget);
  await $(housingCta).tap();
  await $.pumpAndSettle();
  final collectorRouteVerified = _expectCollector(
    $,
    path: '/data-block/revenu',
    origin: '/hypotheque',
    inputKey: 'q_gross_salary_annual',
  );
  await $(find.byKey(const Key('salary_input'))).enterText('96000');
  await _tapCollectorAppBarCancel($);

  final routeAfter = _expectExactRoute('/hypotheque');
  final storeUnchangedVerified =
      _sameBytes(await _canonicalAnswerBytes(), before);
  expect(storeUnchangedVerified, isTrue);
  await _scrollAndWait(
    $,
    find.byKey(const Key('mortgage_enrich_profile_cta')),
  );
  final routeAfterVerified = routeAfter == routeBefore;
  expect(routeAfterVerified, isTrue);
  return _StageProof(
    stage: 'housing_cancel',
    routeBefore: routeBefore,
    routeAfter: routeAfter,
    collectorRouteVerified: collectorRouteVerified,
    routeAfterVerified: routeAfterVerified,
    storeWriteVerified: false,
    storeUnchangedVerified: storeUnchangedVerified,
    validationRetainedVerified: false,
    noDataBlockVerified: false,
    frontalierCanonicalWritesVerified: false,
  );
}

Future<_StageProof> _runDisabilityValidationCancel(
  PatrolIntegrationTester $,
) async {
  await ReportPersistenceService.saveAnswers(<String, dynamic>{
    'q_gross_salary_annual': 96000,
    'q_cash_total': 42000,
    'q_housing_cost_period_chf': 2200,
    'q_lamal_premium_monthly_chf': 420,
    'q_employment_status': 'salarie',
  });
  final before = await _canonicalAnswerBytes();
  await $.pumpWidgetAndSettle(const MintApp());
  testOnlyRootRouter.go('/invalidite');
  await $.pumpAndSettle();
  final routeBefore = _expectExactRoute('/invalidite');

  final cta = find.byKey(const Key('disability_gap_enrich_cta'));
  await $(cta).scrollTo().tap();
  await $.pumpAndSettle();
  final collectorRouteVerified = _expectCollector(
    $,
    path: '/data-block/revenu',
    origin: '/invalidite',
    inputKey: 'q_birth_year',
  );
  final input = find.byKey(const Key('birth_year_input'));
  await $(input).enterText('1800');
  await $(find.byKey(const Key('salary_save_cta'))).scrollTo().tap();
  await $.pumpAndSettle();

  expect(
    _expectCollector(
      $,
      path: '/data-block/revenu',
      origin: '/invalidite',
      inputKey: 'q_birth_year',
    ),
    isTrue,
  );
  final validationStoreUnchanged =
      _sameBytes(await _canonicalAnswerBytes(), before);
  final validationRetainedVerified =
      $.tester.widget<TextField>(input).controller!.text == '1800' &&
          validationStoreUnchanged;
  expect(validationRetainedVerified, isTrue);
  await _tapCollectorAppBarCancel($);

  final routeAfter = _expectExactRoute('/invalidite');
  final storeUnchangedVerified =
      _sameBytes(await _canonicalAnswerBytes(), before);
  expect(storeUnchangedVerified, isTrue);
  await _scrollAndWait(
    $,
    find.byKey(const Key('disability_gap_ledger_facts')),
  );
  final routeAfterVerified = routeAfter == routeBefore;
  expect(routeAfterVerified, isTrue);
  return _StageProof(
    stage: 'disability_validation_cancel',
    routeBefore: routeBefore,
    routeAfter: routeAfter,
    collectorRouteVerified: collectorRouteVerified,
    routeAfterVerified: routeAfterVerified,
    storeWriteVerified: false,
    storeUnchangedVerified: storeUnchangedVerified,
    validationRetainedVerified: validationRetainedVerified,
    noDataBlockVerified: false,
    frontalierCanonicalWritesVerified: false,
  );
}

Future<_StageProof> _runSuccessionSave(PatrolIntegrationTester $) async {
  await ReportPersistenceService.saveAnswers(const <String, dynamic>{
    'q_birth_year': 1955,
  });
  await $.pumpWidgetAndSettle(const MintApp());
  testOnlyRootRouter.go('/succession');
  await $.pumpAndSettle();
  final routeBefore = _expectExactRoute('/succession');

  final missing = find.byKey(const Key('succession_property_missing'));
  await $(missing).scrollTo();
  final cta = find.descendant(
    of: missing,
    matching: find.byType(FilledButton),
  );
  expect(cta, findsOneWidget);
  await $(cta).tap();
  await $.pumpAndSettle();
  final collectorRouteVerified = _expectCollector(
    $,
    path: '/data-block/patrimoine',
    origin: '/succession',
    inputKey: 'q_property_market_value',
  );
  await $(find.byKey(const Key('property_market_value_input')))
      .enterText('950000');
  await $(find.byKey(const Key('patrimoine_save_cta'))).scrollTo().tap();
  await $.pumpAndSettle();

  final routeAfter = _expectExactRoute('/succession');
  final persisted = await ReportPersistenceService.loadAnswers();
  final storeWriteVerified = persisted['q_property_market_value'] == 950000.0;
  expect(storeWriteVerified, isTrue);
  expect(find.byKey(const Key('succession_property_missing')), findsNothing);
  await _scrollAndWait(
    $,
    find.byKey(const Key('succession_mortgage_missing')),
  );
  final routeAfterVerified = routeAfter == routeBefore;
  expect(routeAfterVerified, isTrue);
  return _StageProof(
    stage: 'succession_save',
    routeBefore: routeBefore,
    routeAfter: routeAfter,
    collectorRouteVerified: collectorRouteVerified,
    routeAfterVerified: routeAfterVerified,
    storeWriteVerified: storeWriteVerified,
    storeUnchangedVerified: false,
    validationRetainedVerified: false,
    noDataBlockVerified: false,
    frontalierCanonicalWritesVerified: false,
  );
}

Future<_StageProof> _runFrontalierInline(PatrolIntegrationTester $) async {
  await ReportPersistenceService.saveAnswers(const <String, dynamic>{
    'q_birth_year': 1985,
    'q_residence_permit': 'G',
  });
  await $.pumpWidgetAndSettle(const MintApp());
  testOnlyRootRouter.go('/segments/frontalier');
  await $.pumpAndSettle();
  final routeBefore = _expectExactRoute('/segments/frontalier');
  var noDataBlockVerified = _expectFrontalierInPlace($);

  await _selectCountry($, const Key('frontier_residence_country_field'), 'FR');
  noDataBlockVerified = _expectFrontalierInPlace($) && noDataBlockVerified;
  expect(
    (await ReportPersistenceService.loadAnswers())['q_residence_country'],
    'FR',
  );

  await _selectCountry($, const Key('frontier_work_country_field'), 'CH');
  noDataBlockVerified = _expectFrontalierInPlace($) && noDataBlockVerified;
  expect(
    (await ReportPersistenceService.loadAnswers())['q_work_country'],
    'CH',
  );

  await $(find.byKey(const Key('frontier_work_canton_field'))).scrollTo().tap();
  await $.pumpAndSettle();
  await $(find.text('GE')).tap();
  await $.pumpAndSettle();
  noDataBlockVerified = _expectFrontalierInPlace($) && noDataBlockVerified;
  final persisted = await ReportPersistenceService.loadAnswers();
  final frontalierCanonicalWritesVerified =
      persisted['q_residence_country'] == 'FR' &&
          persisted['q_work_country'] == 'CH' &&
          persisted['q_work_canton'] == 'GE';
  expect(frontalierCanonicalWritesVerified, isTrue);
  await _scrollAndWait(
    $,
    find.byKey(const Key('frontier_jurisdiction_known_state')),
  );
  final routeAfter = _expectExactRoute('/segments/frontalier');
  final routeAfterVerified = routeAfter == routeBefore;
  expect(routeAfterVerified, isTrue);
  expect(noDataBlockVerified, isTrue);
  return _StageProof(
    stage: 'frontalier_inline',
    routeBefore: routeBefore,
    routeAfter: routeAfter,
    collectorRouteVerified: false,
    routeAfterVerified: routeAfterVerified,
    storeWriteVerified: false,
    storeUnchangedVerified: false,
    validationRetainedVerified: false,
    noDataBlockVerified: noDataBlockVerified,
    frontalierCanonicalWritesVerified: frontalierCanonicalWritesVerified,
  );
}

bool _expectCollector(
  PatrolIntegrationTester $, {
  required String path,
  required String origin,
  String? inputKey,
}) {
  final collector = find.byType(DataBlockEnrichmentScreen);
  expect(collector, findsOneWidget);
  final uri = GoRouterState.of($.tester.element(collector)).uri;
  final verified = uri.path == path &&
      uri.queryParameters['returnUri'] == origin &&
      uri.queryParameters['inputKey'] == inputKey &&
      _sameStrings(
        uri.queryParameters.keys,
        <String>[
          if (inputKey != null) 'inputKey',
          'returnUri',
        ],
      );
  expect(verified, isTrue);
  return verified;
}

Future<void> _tapCollectorAppBarCancel(PatrolIntegrationTester $) async {
  final collector = find.byType(DataBlockEnrichmentScreen);
  final cancel = find.descendant(
    of: collector,
    matching: find.byIcon(Icons.arrow_back),
  );
  expect(cancel, findsOneWidget);
  await $(cancel).tap();
  await $.pumpAndSettle();
}

String _expectExactRoute(String route) {
  final actual =
      testOnlyRootRouter.routeInformationProvider.value.uri.toString();
  expect(actual, route);
  return actual;
}

bool _expectFrontalierInPlace(PatrolIntegrationTester $) {
  final exactRoute =
      _expectExactRoute('/segments/frontalier') == '/segments/frontalier';
  final noDataBlock = find.byType(DataBlockEnrichmentScreen).evaluate().isEmpty;
  expect(noDataBlock, isTrue);
  return exactRoute && noDataBlock;
}

Future<void> _selectCountry(
  PatrolIntegrationTester $,
  Key field,
  String code,
) async {
  await $(find.byKey(field)).scrollTo().tap();
  await $.pumpAndSettle();
  final option = find.byWidgetPredicate(
    (widget) =>
        widget is Text && (widget.data?.trim().endsWith('($code)') ?? false),
    description: 'country option $code',
  );
  await $(option).waitUntilVisible();
  await $(option).tap();
  await $.pumpAndSettle();
}

Future<void> _scrollAndWait(
  PatrolIntegrationTester $,
  Finder finder,
) async {
  await $(finder).scrollTo();
  await $(finder).waitUntilVisible();
}

Future<List<int>> _canonicalAnswerBytes() async {
  final answers = await ReportPersistenceService.loadAnswers();
  final sorted = SplayTreeMap<String, dynamic>.from(answers);
  return utf8.encode(jsonEncode(sorted));
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _sameStrings(Iterable<String> left, Iterable<String> right) {
  final leftSet = left.toSet();
  final rightSet = right.toSet();
  return leftSet.length == rightSet.length && leftSet.containsAll(rightSet);
}

Future<void> _writeWitness(File witness, _StageProof proof) async {
  final payload = <String, Object>{
    'schemaVersion': 1,
    'caseId': 'G1-RETURN-01',
    'stage': proof.stage,
    'sourceSha': _sourceSha,
    'syntheticDataOnly': true,
    'routeBefore': proof.routeBefore,
    'routeAfter': proof.routeAfter,
    'collectorRouteVerified': proof.collectorRouteVerified,
    'routeAfterVerified': proof.routeAfterVerified,
    'storeWriteVerified': proof.storeWriteVerified,
    'storeUnchangedVerified': proof.storeUnchangedVerified,
    'validationRetainedVerified': proof.validationRetainedVerified,
    'noDataBlockVerified': proof.noDataBlockVerified,
    'frontalierCanonicalWritesVerified':
        proof.frontalierCanonicalWritesVerified,
  };
  final staging = File('${witness.path}.tmp');
  if (await staging.exists()) await staging.delete();
  await staging.writeAsString(jsonEncode(payload), flush: true);
  await staging.rename(witness.path);
}
