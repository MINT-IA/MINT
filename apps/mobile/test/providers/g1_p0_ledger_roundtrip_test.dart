import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/unemployment_screen.dart';
import 'package:mint_mobile/services/coach_narrative_service.dart';
import 'package:mint_mobile/services/confidence/coach_profile_confidence_adapter.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/financial_core/withdrawal_sequencing_service.dart';
import 'package:mint_mobile/services/fri_computation_service.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_detector.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _matrixHeaders = <String>[
  'canonical_key',
  'storage_key',
  'coach_profile_path',
  'type_unit',
  'allowed_sources',
  'freshness_tier',
  'confidence_weight',
  'classification',
  'profile_owner',
  'write_path',
  'reader_evidence',
  'consumers',
  'p0_loops',
  'tier',
  'required_for_output',
  'allowed_output_when_missing',
  'legal_source_asof',
  'sensitivity_purpose',
  'status',
  'existing_gate',
  'missing_gate',
  'blocks_G2',
  'ticket',
];

class _LedgerRow {
  const _LedgerRow(this.cells);

  final Map<String, String> cells;

  String operator [](String key) => cells[key]!;

  String get canonicalKey => this['canonical_key'];
  String get storageKey => this['storage_key'];
  String get profilePath => this['coach_profile_path'];
  String get typeUnit => this['type_unit'];
  String get owner => this['profile_owner'];
  String get writePath => this['write_path'];
  String get readerEvidence => this['reader_evidence'];
}

File _canonicalMatrixFile() {
  for (final path in const [
    '../../.planning/goals/G1-ledger-gap-matrix.md',
    '.planning/goals/G1-ledger-gap-matrix.md',
  ]) {
    final file = File(path);
    if (file.existsSync()) return file;
  }
  throw StateError('Canonical G1 ledger matrix is not reachable from cwd.');
}

List<String> _cells(String line) => line
    .trim()
    .substring(1, line.trim().length - 1)
    .split('|')
    .map((cell) => cell.trim())
    .toList(growable: false);

List<_LedgerRow> _liveP0RowsForTicket() {
  final lines = _canonicalMatrixFile().readAsLinesSync();
  final heading = lines.indexOf('## G1_P0_CANONICAL_KEYS');
  if (heading < 0) {
    throw StateError('Missing exact G1_P0_CANONICAL_KEYS heading.');
  }

  final tableStart = lines.indexWhere(
    (line) => line.startsWith('|'),
    heading + 1,
  );
  if (tableStart < 0) throw StateError('Missing canonical ledger table.');

  final headers = _cells(lines[tableStart]);
  if (!const ListEquality<String>().equals(headers, _matrixHeaders)) {
    throw StateError('Canonical ledger columns or order drifted: $headers');
  }

  final rows = <_LedgerRow>[];
  for (final line in lines.skip(tableStart + 2)) {
    if (!line.startsWith('|')) break;
    final values = _cells(line);
    if (values.length != headers.length) {
      throw StateError('Malformed canonical ledger row: $line');
    }
    final row = _LedgerRow(Map.fromIterables(headers, values));
    if (row['ticket'] == 'G1-LDG-03' &&
        row['tier'] == 'P0' &&
        row['status'] == 'live') {
      rows.add(row);
    }
  }
  if (rows.isEmpty) {
    throw StateError('G1-LDG-03 has no live P0 row to prove.');
  }
  return rows;
}

String _dateOnly(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

dynamic _sampleValue(_LedgerRow row) {
  final now = DateTime.now();
  return switch (row.typeUnit) {
    'int_year' => now.year - 41,
    'ISO_date' => _dateOnly(
        DateTime(now.year, now.month + 3, 15).copyWith(
          year: DateTime(now.year, now.month + 3, 15).year - 65,
        ),
      ),
    'string' => 'Lausanne',
    'int_years_58_70' => 62,
    'CHF_month' => 8123.25,
    'int_count' => 2,
    'ISO_country_code' => 'US',
    'permit_enum' => 'G',
    'int_months_0_24' => 18,
    'int_count_0_5' => 4,
    _ => throw StateError(
        'No semantic sample generator for ${row.typeUnit} '
        '(${row.canonicalKey}).',
      ),
  };
}

Map<String, dynamic> _supportingAnswers(_LedgerRow row) {
  final now = DateTime.now();
  final answers = <String, dynamic>{
    'q_birth_year': now.year - 45,
    'q_canton': 'VD',
    'q_gross_salary_annual': 96000,
    'q_civil_status': 'celibataire',
    'q_has_pension_fund': 'no',
  };

  if (row.readerEvidence.contains('LifecycleDetector.detect')) {
    answers['q_birth_year'] = now.year - 54;
  }
  if (row.readerEvidence.contains('_contributionMonths')) {
    answers['q_birth_year'] = now.year - 56;
  }
  if (row.readerEvidence.contains('_collectCapitalSources')) {
    answers['q_birth_year'] = now.year - 49;
    answers['q_3a_total'] = 100000;
  }

  for (final key in row.storageKey.split('+')) {
    answers.remove(key);
  }
  return answers;
}

Future<void> _writeCanonical(
  CoachProfileProvider provider,
  _LedgerRow row,
  dynamic value,
) async {
  if (row.writePath.split(',').contains('applySaveFact')) {
    final applied = await provider.applySaveFact(row.canonicalKey, value);
    expect(applied, isTrue, reason: '${row.canonicalKey} mapper missing');
    return;
  }

  final storageKeys = row.storageKey.split('+');
  if (storageKeys.length != 1 ||
      !row.writePath.split(',').contains('mergeAnswers')) {
    throw StateError(
      'No canonical behavioral writer for ${row.canonicalKey}: '
      '${row.writePath} -> ${row.storageKey}',
    );
  }
  await provider.mergeAnswers({storageKeys.single: value});
}

dynamic _readProfilePath(CoachProfile profile, String path) {
  dynamic current = profile.toJson();
  for (final segment in path.split('.')) {
    if (current is! Map || !current.containsKey(segment)) {
      throw StateError('Profile path is not serializable: $path');
    }
    current = current[segment];
  }
  return current;
}

void _assertUnit(_LedgerRow row, dynamic value) {
  switch (row.typeUnit) {
    case 'int_year':
      expect(value, isA<int>());
      expect(value, inInclusiveRange(1900, DateTime.now().year));
    case 'ISO_date':
      expect(value, isA<String>());
      expect(DateTime.tryParse(value as String), isNotNull);
    case 'string':
      expect(value, isA<String>());
      expect((value as String).trim(), isNotEmpty);
    case 'int_years_58_70':
      expect(value, isA<int>());
      expect(value, inInclusiveRange(58, 70));
    case 'CHF_month':
      expect(value, isA<num>());
      expect(value, greaterThan(0));
    case 'int_count':
      expect(value, isA<int>());
      expect(value, greaterThanOrEqualTo(0));
    case 'ISO_country_code':
      expect(value, matches(RegExp(r'^[A-Z]{2}$')));
    case 'permit_enum':
      expect(value, isIn(const ['B', 'C', 'G', 'L', 'Swiss']));
    case 'int_months_0_24':
      expect(value, isA<int>());
      expect(value, inInclusiveRange(0, 24));
    case 'int_count_0_5':
      expect(value, isA<int>());
      expect(value, inInclusiveRange(0, 5));
    default:
      fail('No unit assertion for ${row.typeUnit} (${row.canonicalKey}).');
  }
}

Widget _unemploymentConsumer(CoachProfileProvider provider) {
  return ChangeNotifierProvider<CoachProfileProvider>.value(
    value: provider,
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: UnemploymentScreen(),
    ),
  );
}

Future<void> _assertNamedConsumer(
  WidgetTester tester,
  _LedgerRow row,
  CoachProfileProvider reloaded,
  CoachProfile baseline,
  dynamic expected,
) async {
  final profile = reloaded.profile!;
  final reader = row.readerEvidence;

  if (reader.contains('CoachProfileConfidenceAdapter.compute')) {
    final result = CoachProfileConfidenceAdapter.compute(profile);
    final missingResult = CoachProfileConfidenceAdapter.compute(baseline);
    expect(
      result.breakdown.completeness,
      greaterThan(missingResult.breakdown.completeness),
      reason: '${row.canonicalKey} did not reach $reader',
    );
    return;
  }

  if (reader.contains('CoachNarrativeService._generateStatic')) {
    final narrative = CoachNarrativeService.generateStatic(
      profile: profile,
      scoreHistory: null,
      tips: const [],
    );
    final missingNarrative = CoachNarrativeService.generateStatic(
      profile: baseline,
      scoreHistory: null,
      tips: const [],
    );
    expect(narrative.retirementCountdown, contains('mois'));
    expect(missingNarrative.retirementCountdown, isNot(contains('mois')));
    return;
  }

  if (reader.contains('ConfidenceScorer.score')) {
    final result = ConfidenceScorer.score(profile);
    final missingResult = ConfidenceScorer.score(baseline);
    expect(
      result.prompts.where((prompt) => prompt.fieldPath == row.profilePath),
      isEmpty,
    );
    expect(
      missingResult.prompts
          .where((prompt) => prompt.fieldPath == row.profilePath),
      isNotEmpty,
    );
    return;
  }

  if (reader.contains('LifecycleDetector.detect')) {
    final now = DateTime(DateTime.now().year, 7, 1);
    expect(
        LifecycleDetector.detect(profile, now: now), LifecyclePhase.transition);
    expect(
      LifecycleDetector.detect(baseline, now: now),
      LifecyclePhase.consolidation,
    );
    return;
  }

  if (reader.contains('FriComputationService.detectArchetype')) {
    final archetype = FriComputationService.detectArchetype(profile);
    final missingArchetype = FriComputationService.detectArchetype(baseline);
    expect(archetype, isNot(missingArchetype));
    expect(
      archetype,
      row.typeUnit == 'permit_enum' ? 'cross_border' : 'expat_us',
    );
    return;
  }

  if (reader.contains('_contributionMonths')) {
    await tester.pumpWidget(_unemploymentConsumer(reloaded));
    await tester.pump();
    expect(
      find.byKey(const Key('unemployment_contribution_months_fact')),
      findsOneWidget,
    );
    expect(find.text('$expected mois'), findsWidgets);
    expect(find.byKey(const Key('unemployment_result_cards')), findsOneWidget);
    return;
  }

  if (reader.contains('_collectCapitalSources')) {
    final result = WithdrawalSequencingService.optimize(profile: profile);
    final missingResult =
        WithdrawalSequencingService.optimize(profile: baseline);
    expect(result.optimizedSequence, hasLength(expected as int));
    expect(missingResult.optimizedSequence, isEmpty);
    return;
  }

  fail('No behavioral consumer proof for $reader (${row.canonicalKey}).');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorage =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureStorageValues = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorage, (call) async {
    final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
    final key = args['key'] as String?;
    if (call.method == 'write' && key != null) {
      secureStorageValues[key] = args['value'] as String;
      return null;
    }
    if (call.method == 'read' && key != null) return secureStorageValues[key];
    if (call.method == 'readAll') return secureStorageValues;
    if (call.method == 'delete' && key != null) {
      secureStorageValues.remove(key);
      return null;
    }
    if (call.method == 'deleteAll') {
      secureStorageValues.clear();
      return null;
    }
    return null;
  });

  final rows = _liveP0RowsForTicket();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorageValues.clear();
  });

  test('fixture scope is generated only from canonical live P0 LDG-03 rows',
      () {
    expect(rows, isNotEmpty);
    for (final row in rows) {
      expect(row['ticket'], 'G1-LDG-03');
      expect(row['tier'], 'P0');
      expect(row['status'], 'live');
      expect(row['classification'], 'fact');
      expect(row['blocks_G2'], 'yes');
      expect(row.readerEvidence, isNot('NONE'));
      expect(row['consumers'], isNot('NONE'));
    }
  });

  for (final row in rows) {
    testWidgets(
      '${row.canonicalKey}: canonical write -> restart -> ${row.readerEvidence}',
      (tester) async {
        final supporting = _supportingAnswers(row);
        await ReportPersistenceService.saveAnswers(supporting);
        await ReportPersistenceService.setCompleted(true);

        final writer = CoachProfileProvider();
        await writer.loadFromWizard();
        final sample = _sampleValue(row);
        await _writeCanonical(writer, row, sample);

        final persisted = await ReportPersistenceService.loadAnswers();
        for (final storageKey in row.storageKey.split('+')) {
          expect(
            persisted,
            contains(storageKey),
            reason: '${row.canonicalKey} did not durably write $storageKey',
          );
        }

        final reloaded = CoachProfileProvider();
        await reloaded.loadFromWizard();
        expect(reloaded.profile, isNotNull);

        final value = _readProfilePath(reloaded.profile!, row.profilePath);
        _assertUnit(row, value);
        if (sample is num && value is num) {
          expect(value, closeTo(sample.toDouble(), 0.001));
        } else {
          expect(value, sample);
        }

        expect(row.owner, isIn(const ['self', 'household']));
        expect(row.profilePath.startsWith('conjoint.'), isFalse);
        expect(reloaded.profile!.conjoint, isNull);

        final baseline = CoachProfile.fromWizardAnswers(supporting);
        await _assertNamedConsumer(
          tester,
          row,
          reloaded,
          baseline,
          sample,
        );
      },
    );
  }
}

class ListEquality<T> {
  const ListEquality();

  bool equals(List<T> left, List<T> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }
}
