import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/biography/freshness_decay_service.dart';

class _ExpectedRule {
  _ExpectedRule(this.tier, Set<String> sources) : sources = {...sources};

  final String tier;
  final Set<String> sources;
}

final class _MemoryProfilePersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements TaxProfilePersistence, LppProfilePersistence {
  Map<String, dynamic> answers = <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> loadAnswers() async =>
      Map<String, dynamic>.from(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    answers = Map<String, dynamic>.from(next);
  }
}

File _matrixFile() {
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

({Map<String, _ExpectedRule> policies, Set<String> references})
    _expectedRegistry() {
  final lines = _matrixFile().readAsLinesSync();
  final headerIndex = lines.indexWhere(
    (line) => line.startsWith('| canonical_key |'),
  );
  if (headerIndex < 0) throw StateError('Missing canonical ledger table.');
  final headers = _cells(lines[headerIndex]);
  final policies = <String, _ExpectedRule>{};
  final references = <String>{};
  const frontierPathOverrides = <String, String>{
    'residenceCountry': 'residenceCountry',
    'workCountry': 'workCountry',
    'workCanton': 'workCanton',
  };

  for (final line in lines.skip(headerIndex + 2)) {
    if (!line.startsWith('|')) break;
    final values = _cells(line);
    if (values.length != headers.length) {
      throw StateError('Malformed canonical ledger row: $line');
    }
    final row = Map<String, String>.fromIterables(headers, values);
    var path = row['coach_profile_path']!;
    if (path == 'NONE') {
      path = frontierPathOverrides[row['canonical_key']] ?? '';
    }
    if (path.isEmpty || path.contains('[]')) continue;
    if (row['classification'] == 'specialist_reference') {
      references.add(path);
      continue;
    }
    final tier = row['freshness_tier']!;
    final sources = row['allowed_sources']!
        .split(',')
        .map((source) => source.trim())
        .where((source) => source.isNotEmpty)
        .toSet();
    final existing = policies[path];
    if (existing != null && existing.tier != tier) {
      throw StateError('Conflicting freshness tiers for $path.');
    }
    if (existing == null) {
      policies[path] = _ExpectedRule(tier, sources);
    } else {
      existing.sources.addAll(sources);
    }
  }
  return (policies: policies, references: references);
}

LedgerFreshnessAssessment<Object> _assessment({
  required String path,
  required DateTime? updatedAt,
  required DateTime now,
  String source = 'userInput',
  Object previousValue = 1,
}) =>
    FreshnessDecayService.assessLedgerField<Object>(
      fieldPath: path,
      previousValue: previousValue,
      updatedAt: updatedAt,
      sourceName: source,
      now: now,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 7, 19, 12);

  test('registry is an exact projection of addressable G1 matrix paths', () {
    final expected = _expectedRegistry();
    expect(expected.policies, hasLength(61));
    expect(
      FreshnessDecayService.ledgerFieldPolicies.keys,
      unorderedEquals(expected.policies.keys),
    );
    for (final entry in expected.policies.entries) {
      final actual = FreshnessDecayService.ledgerFieldPolicies[entry.key];
      expect(actual, isNotNull, reason: entry.key);
      expect(actual!.tier.wireName, entry.value.tier, reason: entry.key);
      expect(
        actual.allowedSourceNames,
        unorderedEquals(entry.value.sources),
        reason: entry.key,
      );
    }
    expect(
      FreshnessDecayService.specialistReferencePaths,
      unorderedEquals(expected.references),
    );
  });

  test('ledger adapter stays synchronous and model-free', () {
    final source = File(
      'lib/services/biography/freshness_decay_service.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('models/coach_profile.dart')));
    expect(source, isNot(contains('biography_repository.dart')));
    expect(source, isNot(contains('Future<')));
  });

  test('static and event-static facts do not calendar-decay', () {
    for (final path in const ['birthYear', 'employmentStatus']) {
      final result = _assessment(
        path: path,
        updatedAt: now.subtract(const Duration(days: 3650)),
        now: now,
      );
      expect(result.state, LedgerFreshnessState.current, reason: path);
      expect(result.weight, 1.0, reason: path);
      expect(result.previousValue, 1, reason: path);
    }
  });

  test('annual threshold is current at day 782 and stale at day 783', () {
    final current = _assessment(
      path: 'salaireBrutMensuel',
      updatedAt: now.subtract(const Duration(days: 782)),
      now: now,
    );
    final stale = _assessment(
      path: 'salaireBrutMensuel',
      updatedAt: now.subtract(const Duration(days: 783)),
      now: now,
    );
    expect(current.state, LedgerFreshnessState.current);
    expect(stale.state, LedgerFreshnessState.stale);
    expect(stale.reconfirmation, LedgerReconfirmation.confirmAsUserInput);
    expect(stale.previousValue, 1);
  });

  test('volatile threshold is current at day 247 and stale at day 248', () {
    final current = _assessment(
      path: 'dettes.hypotheque',
      updatedAt: now.subtract(const Duration(days: 247)),
      now: now,
    );
    final stale = _assessment(
      path: 'dettes.hypotheque',
      updatedAt: now.subtract(const Duration(days: 248)),
      now: now,
    );
    expect(current.state, LedgerFreshnessState.current);
    expect(stale.state, LedgerFreshnessState.stale);
    expect(stale.previousValue, 1);
  });

  test('missing and future timestamps fail closed without blanking the value',
      () {
    for (final updatedAt in <DateTime?>[
      null,
      now.add(const Duration(microseconds: 1)),
    ]) {
      final result = _assessment(
        path: 'salaireBrutMensuel',
        updatedAt: updatedAt,
        now: now,
        previousValue: 9800,
      );
      expect(result.state, LedgerFreshnessState.invalid);
      expect(result.weight, 0.3);
      expect(result.previousValue, 9800);
      expect(result.reconfirmation, LedgerReconfirmation.confirmAsUserInput);
    }
  });

  test('unknown path and source fail closed instead of defaulting to annual',
      () {
    final unknown = _assessment(
      path: 'invented.salaryAlias',
      updatedAt: now,
      now: now,
    );
    final badSource = _assessment(
      path: 'salaireBrutMensuel',
      updatedAt: now,
      now: now,
      source: 'inferredByModel',
    );
    for (final result in [unknown, badSource]) {
      expect(result.state, LedgerFreshnessState.invalid);
      expect(result.weight, 0.3);
      expect(result.previousValue, 1);
      expect(result.reconfirmation, LedgerReconfirmation.unavailable);
    }
  });

  test('certificate-only fields require evidence renewal, never a tap', () {
    final result = _assessment(
      path: 'prevoyance.avoirLppObligatoire',
      updatedAt: now.subtract(const Duration(days: 783)),
      now: now,
      source: 'certificate',
    );
    expect(result.state, LedgerFreshnessState.stale);
    expect(result.reconfirmation, LedgerReconfirmation.renewEvidence);

    final mixedSource = _assessment(
      path: 'salaireBrutMensuel',
      updatedAt: now.subtract(const Duration(days: 783)),
      now: now,
      source: 'certificate',
    );
    expect(mixedSource.reconfirmation, LedgerReconfirmation.confirmAsUserInput);
  });

  test('specialist references stay outside the generic TTL', () {
    for (final path in _expectedRegistry().references) {
      final result = _assessment(
        path: path,
        updatedAt: now.subtract(const Duration(days: 3650)),
        now: now,
        source: 'certificate',
      );
      expect(
        result.state,
        LedgerFreshnessState.separateReference,
        reason: path,
      );
      expect(
        result.reconfirmation,
        LedgerReconfirmation.separateReference,
        reason: path,
      );
    }
  });

  test('sourceDate never refreshes a stale canonical timestamp', () {
    final fact = BiographyFact(
      id: 'salary',
      factType: FactType.salary,
      fieldPath: 'salaireBrutMensuel',
      value: '9800',
      source: FactSource.document,
      sourceDate: now,
      createdAt: now.subtract(const Duration(days: 783)),
      updatedAt: now.subtract(const Duration(days: 783)),
    );
    expect(FreshnessDecayService.needsRefresh(fact, now), isTrue);
  });

  test('same-value confirmation restamps canonical provenance after cold load',
      () async {
    final persistence = _MemoryProfilePersistence();
    var clock = now.subtract(const Duration(days: 783));
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => clock,
    );
    await provider.mergeAnswersWithProvenance(
      const {
        'q_residence_country': 'FR',
        'q_work_country': 'CH',
        'q_work_canton': 'GE',
      },
      source: ProfileDataSource.certificate,
      sourceDate: DateTime.utc(2024, 1, 1),
    );

    expect(
      provider.profile!.frontierJurisdictionAt(now).state,
      FrontierJurisdictionState.stale,
    );
    clock = now;
    await provider.mergeAnswersWithProvenance(
      const {'q_work_canton': 'GE'},
      source: ProfileDataSource.userInput,
      sourceDate: null,
    );
    expect(provider.profile!.workCanton!.value, 'GE');
    expect(provider.profile!.dataTimestamps['workCanton'], now);
    expect(
      provider.profile!.dataSources['workCanton'],
      ProfileDataSource.userInput,
    );
    expect(provider.profile!.dataSourceDates['workCanton'], isNull);
    expect(
      provider.profile!.frontierJurisdictionAt(now).state,
      FrontierJurisdictionState.known,
    );

    final cold = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    await cold.loadFromWizard();
    expect(cold.profile!.workCanton!.value, 'GE');
    expect(cold.profile!.dataTimestamps['workCanton'], now);
    expect(
        cold.profile!.dataSources['workCanton'], ProfileDataSource.userInput);
    expect(cold.profile!.dataSourceDates['workCanton'], isNull);
    expect(
      cold.profile!.frontierJurisdictionAt(now).state,
      FrontierJurisdictionState.known,
    );
  });
}
