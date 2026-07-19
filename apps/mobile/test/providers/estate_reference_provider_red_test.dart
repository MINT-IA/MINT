import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';

const _rootKey = '_coach_estate_evidence_v1';
final _now = DateTime.utc(2026, 7, 20, 10);
final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

final class _MemoryPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements TaxProfilePersistence, LppProfilePersistence {
  _MemoryPersistence(Map<String, dynamic> initial) : answers = _copy(initial);

  Map<String, dynamic> answers;
  int saveCalls = 0;
  Completer<void>? saveGate;

  @override
  Future<Map<String, dynamic>> loadAnswers() async => _copy(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    saveCalls += 1;
    final gate = saveGate;
    if (gate != null) await gate.future;
    answers = _copy(next);
  }

  void reset() {
    saveCalls = 0;
    saveGate = null;
  }

  static Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
}

Map<String, dynamic> _answers({
  String? root,
  String civilStatus = 'celibataire',
}) =>
    <String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      'q_civil_status': civilStatus,
      if (root != null) _rootKey: root,
    };

Map<String, dynamic> _referenceJson({
  required String referenceId,
  required String kind,
  String sourceDate = '2026-01-15',
  String confirmedAt = '2026-01-16T10:00:00.000Z',
}) =>
    <String, dynamic>{
      'referenceId': referenceId,
      'kind': kind,
      'ownerKind': 'self',
      'source': 'certificate',
      'sourceDate': sourceDate,
      'legalYear': 2026,
      'confirmedAt': confirmedAt,
    };

String _root({
  String? regime,
  String civilStatusAtConfirmation = 'celibataire',
  List<Map<String, dynamic>> references = const [],
}) =>
    jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'matrimonialRegime': regime == null
          ? null
          : <String, dynamic>{
              'kind': regime,
              'source': 'userInput',
              'updatedAt': _now.toIso8601String(),
            },
      'civilStatusAtConfirmation': civilStatusAtConfirmation,
      'estateInstrumentReferences': references,
    });

Map<String, dynamic> _decodedRoot(Map<String, dynamic> answers) {
  final raw = answers[_rootKey];
  expect(raw, isA<String>(), reason: 'one atomic JSON root must be durable');
  return Map<String, dynamic>.from(jsonDecode(raw as String) as Map);
}

List<Map<String, dynamic>> _decodedReferences(Map<String, dynamic> root) =>
    (root['estateInstrumentReferences'] as List)
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList(growable: false);

Future<({CoachProfileProvider provider, _MemoryPersistence persistence})>
    _loaded({String? root, String civilStatus = 'celibataire'}) async {
  final persistence = _MemoryPersistence(
    _answers(root: root, civilStatus: civilStatus),
  );
  final provider = CoachProfileProvider(
    taxProfilePersistence: persistence,
    lppProfilePersistence: persistence,
    now: () => _now,
  );
  await provider.loadFromWizard();
  persistence.reset();
  return (provider: provider, persistence: persistence);
}

Future<void> _confirmRegime(
  CoachProfileProvider provider,
  MatrimonialRegimeKind regime,
) async {
  try {
    final dynamic dynamicProvider = provider;
    await dynamicProvider.confirmMatrimonialRegime(regime);
  } on NoSuchMethodError {
    fail(
      'CoachProfileProvider.confirmMatrimonialRegime must persist the '
      'userInput provenance, confirmation instant, and current civil status '
      'before publishing.',
    );
  }
}

Future<EstateInstrumentReference> _confirmReference(
  CoachProfileProvider provider, {
  required EstateInstrumentKind kind,
  required DateTime sourceDate,
  required int legalYear,
  required String? expectedPreviousReferenceId,
}) async {
  try {
    final dynamic dynamicProvider = provider;
    final dynamic result =
        await dynamicProvider.confirmEstateInstrumentReference(
      kind: kind,
      sourceDate: sourceDate,
      legalYear: legalYear,
      expectedPreviousReferenceId: expectedPreviousReferenceId,
    );
    expect(
      result,
      isA<EstateInstrumentReference>(),
      reason: 'the writer must return the provider-generated reference',
    );
    return result as EstateInstrumentReference;
  } on NoSuchMethodError {
    fail(
      'CoachProfileProvider.confirmEstateInstrumentReference must generate '
      'the UUIDv4/self/certificate/confirmedAt tuple and enforce exact-ID CAS.',
    );
  }
}

Future<void> _rethrowEarlyFailure(Future<Object?> write) async {
  Object? error;
  StackTrace? stackTrace;
  unawaited(
    write.then<void>(
      (_) {},
      onError: (Object caught, StackTrace caughtStack) {
        error = caught;
        stackTrace = caughtStack;
      },
    ),
  );
  await Future<void>.delayed(Duration.zero);
  if (error != null) Error.throwWithStackTrace(error!, stackTrace!);
}

Future<({EstateInstrumentReference? value, Object? error})> _capture(
  Future<EstateInstrumentReference> future,
) async {
  try {
    return (value: await future, error: null);
  } catch (error) {
    return (value: null, error: error);
  }
}

List<Map<String, dynamic>> _completeReferences() => <Map<String, dynamic>>[
      _referenceJson(
        referenceId: '11111111-1111-4111-8111-111111111111',
        kind: 'will',
      ),
      _referenceJson(
        referenceId: '22222222-2222-4222-8222-222222222222',
        kind: 'inheritancePact',
      ),
      _referenceJson(
        referenceId: '33333333-3333-4333-8333-333333333333',
        kind: 'incapacityMandate',
      ),
      _referenceJson(
        referenceId: '44444444-4444-4444-8444-444444444444',
        kind: 'advanceCareDirective',
      ),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cold load restores matching estate facts without persisted readiness',
      () async {
    final loaded = await _loaded(
      root: _root(
        regime: 'participationInAcquests',
        references: _completeReferences(),
      ),
    );
    addTearDown(loaded.provider.dispose);

    expect(
      loaded.provider.profile?.matrimonialRegime,
      MatrimonialRegimeKind.participationInAcquests,
    );
    expect(loaded.provider.profile?.estateInstrumentReferences, hasLength(4));
    expect(loaded.provider.profile?.estateFactsNeedReconfirmation, isFalse);
    expect(loaded.provider.profile?.estateSpecialistReadyAt(_now), isTrue);
    expect(loaded.persistence.saveCalls, 0);
  });

  test('cold load derives reconfirmation after civil-status drift', () async {
    final loaded = await _loaded(
      root: _root(
        regime: 'separationOfProperty',
        civilStatusAtConfirmation: 'celibataire',
        references: _completeReferences(),
      ),
      civilStatus: 'marie',
    );
    addTearDown(loaded.provider.dispose);

    expect(loaded.provider.profile?.matrimonialRegime,
        MatrimonialRegimeKind.separationOfProperty);
    expect(loaded.provider.profile?.estateInstrumentReferences, hasLength(4));
    expect(loaded.provider.profile?.estateFactsNeedReconfirmation, isTrue);
    expect(
      loaded.provider.profile?.estateReferenceStateAt(_now),
      EstateReferenceState.needsReconfirmation,
    );
    expect(loaded.provider.profile?.estateSpecialistReadyAt(_now), isFalse);
    expect(loaded.persistence.saveCalls, 0);
  });

  test('cold load treats ambiguous current civil status as reconfirmation',
      () async {
    final loaded = await _loaded(
      root: _root(
        regime: 'separationOfProperty',
        references: _completeReferences(),
      ),
      civilStatus: 'pacs',
    );
    addTearDown(loaded.provider.dispose);

    expect(loaded.provider.profile?.civilStatusNeedsConfirmation, isTrue);
    expect(loaded.provider.profile?.matrimonialRegime,
        MatrimonialRegimeKind.separationOfProperty);
    expect(loaded.provider.profile?.estateInstrumentReferences, hasLength(4));
    expect(
      loaded.provider.profile?.estateReferenceStateAt(_now),
      EstateReferenceState.needsReconfirmation,
    );
    expect(loaded.provider.profile?.estateSpecialistReadyAt(_now), isFalse);
  });

  test('matrimonial regime saves provenance and civil status before publish',
      () async {
    final loaded = await _loaded();
    addTearDown(loaded.provider.dispose);
    final gate = Completer<void>();
    loaded.persistence.saveGate = gate;
    var notifications = 0;
    loaded.provider.addListener(() => notifications += 1);

    final write = _confirmRegime(
      loaded.provider,
      MatrimonialRegimeKind.separationOfProperty,
    );
    await _rethrowEarlyFailure(write);

    expect(loaded.persistence.saveCalls, 1);
    expect(loaded.persistence.answers.containsKey(_rootKey), isFalse);
    expect(loaded.provider.profile?.matrimonialRegime, isNull);
    expect(notifications, 0);

    gate.complete();
    await write;
    expect(
      _decodedRoot(loaded.persistence.answers),
      <String, dynamic>{
        'schemaVersion': 1,
        'matrimonialRegime': <String, dynamic>{
          'kind': 'separationOfProperty',
          'source': 'userInput',
          'updatedAt': _now.toIso8601String(),
        },
        'civilStatusAtConfirmation': 'celibataire',
        'estateInstrumentReferences': <dynamic>[],
      },
    );
    expect(
      jsonEncode(_decodedRoot(loaded.persistence.answers)),
      isNot(contains('estateFactsNeedReconfirmation')),
    );
    expect(loaded.provider.profile?.matrimonialRegime,
        MatrimonialRegimeKind.separationOfProperty);
    expect(notifications, 1);
  });

  test('reference writer generates raw-free tuple and saves before publish',
      () async {
    final loaded = await _loaded(
      root: _root(regime: 'participationInAcquests'),
    );
    addTearDown(loaded.provider.dispose);
    final gate = Completer<void>();
    loaded.persistence.saveGate = gate;
    var notifications = 0;
    loaded.provider.addListener(() => notifications += 1);

    final write = _confirmReference(
      loaded.provider,
      kind: EstateInstrumentKind.will,
      sourceDate: DateTime.utc(2026, 1, 15),
      legalYear: 2026,
      expectedPreviousReferenceId: null,
    );
    await _rethrowEarlyFailure(write);

    expect(loaded.persistence.saveCalls, 1);
    expect(loaded.provider.profile?.estateInstrumentReferences, isEmpty);
    expect(notifications, 0);

    gate.complete();
    final reference = await write;
    expect(reference.referenceId, matches(_uuidV4));
    expect(reference.kind, EstateInstrumentKind.will);
    expect(reference.ownerKind.name, 'self');
    expect(reference.source.name, 'certificate');
    expect(reference.sourceDate, DateTime.utc(2026, 1, 15));
    expect(reference.legalYear, 2026);
    expect(reference.confirmedAt, _now);

    final root = _decodedRoot(loaded.persistence.answers);
    expect(root.keys.toSet(), <String>{
      'schemaVersion',
      'matrimonialRegime',
      'civilStatusAtConfirmation',
      'estateInstrumentReferences',
    });
    expect(
        _decodedReferences(root), <Map<String, dynamic>>[reference.toJson()]);
    final encoded = jsonEncode(root).toLowerCase();
    for (final forbidden in <String>[
      'filename',
      'path',
      'bytes',
      'ocr',
      'identity',
      'content',
    ]) {
      expect(encoded, isNot(contains(forbidden)));
    }
    expect(loaded.provider.profile?.estateInstrumentReferences,
        <EstateInstrumentReference>[reference]);
    expect(notifications, 1);
  });

  test('two concurrent creations of one kind enforce expected-null CAS',
      () async {
    final loaded = await _loaded(
      root: _root(regime: 'participationInAcquests'),
    );
    addTearDown(loaded.provider.dispose);

    final results = await Future.wait([
      _capture(_confirmReference(
        loaded.provider,
        kind: EstateInstrumentKind.will,
        sourceDate: DateTime.utc(2026, 1, 15),
        legalYear: 2026,
        expectedPreviousReferenceId: null,
      )),
      _capture(_confirmReference(
        loaded.provider,
        kind: EstateInstrumentKind.will,
        sourceDate: DateTime.utc(2026, 2, 15),
        legalYear: 2026,
        expectedPreviousReferenceId: null,
      )),
    ]);

    for (final result in results) {
      if (result.error is TestFailure) throw result.error!;
    }

    expect(results.where((result) => result.value != null), hasLength(1));
    expect(
      results.where((result) => result.error is StateError),
      hasLength(1),
      reason: 'the stale expected-null creation must fail closed',
    );
    expect(loaded.persistence.saveCalls, 1);
    expect(
      _decodedReferences(_decodedRoot(loaded.persistence.answers))
          .where((reference) => reference['kind'] == 'will'),
      hasLength(1),
    );
  });

  test('concurrent creations of different kinds both survive', () async {
    final loaded = await _loaded(
      root: _root(regime: 'participationInAcquests'),
    );
    addTearDown(loaded.provider.dispose);

    final created = await Future.wait([
      _confirmReference(
        loaded.provider,
        kind: EstateInstrumentKind.will,
        sourceDate: DateTime.utc(2026, 1, 15),
        legalYear: 2026,
        expectedPreviousReferenceId: null,
      ),
      _confirmReference(
        loaded.provider,
        kind: EstateInstrumentKind.inheritancePact,
        sourceDate: DateTime.utc(2026, 2, 15),
        legalYear: 2026,
        expectedPreviousReferenceId: null,
      ),
    ]);

    expect(created.map((reference) => reference.kind).toSet(), {
      EstateInstrumentKind.will,
      EstateInstrumentKind.inheritancePact,
    });
    expect(loaded.persistence.saveCalls, 2);
    expect(
      _decodedReferences(_decodedRoot(loaded.persistence.answers))
          .map((reference) => reference['kind'])
          .toSet(),
      {'will', 'inheritancePact'},
    );
  });

  test(
      'replacement requires the exact previous ID and stale CAS publishes none',
      () async {
    final loaded = await _loaded(
      root: _root(regime: 'participationInAcquests'),
    );
    addTearDown(loaded.provider.dispose);
    final original = await _confirmReference(
      loaded.provider,
      kind: EstateInstrumentKind.will,
      sourceDate: DateTime.utc(2026, 1, 15),
      legalYear: 2026,
      expectedPreviousReferenceId: null,
    );
    var notifications = 0;
    loaded.provider.addListener(() => notifications += 1);
    final savesBeforeStale = loaded.persistence.saveCalls;
    final rootBeforeStale = loaded.persistence.answers[_rootKey];

    await expectLater(
      _confirmReference(
        loaded.provider,
        kind: EstateInstrumentKind.will,
        sourceDate: DateTime.utc(2026, 2, 15),
        legalYear: 2026,
        expectedPreviousReferenceId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      ),
      throwsStateError,
    );
    expect(loaded.persistence.saveCalls, savesBeforeStale);
    expect(loaded.persistence.answers[_rootKey], rootBeforeStale);
    expect(notifications, 0);
    expect(
      loaded.provider.profile?.estateInstrumentReferences.single.referenceId,
      original.referenceId,
    );

    final replacement = await _confirmReference(
      loaded.provider,
      kind: EstateInstrumentKind.will,
      sourceDate: DateTime.utc(2026, 2, 15),
      legalYear: 2026,
      expectedPreviousReferenceId: original.referenceId,
    );
    expect(replacement.referenceId, isNot(original.referenceId));
    expect(loaded.persistence.saveCalls, savesBeforeStale + 1);
    expect(notifications, 1);
    expect(
      loaded.provider.profile?.estateInstrumentReferences.single,
      replacement,
    );

    final cold = await _loaded(
      root: loaded.persistence.answers[_rootKey] as String,
    );
    addTearDown(cold.provider.dispose);
    expect(cold.provider.profile?.estateInstrumentReferences,
        <EstateInstrumentReference>[replacement]);
  });
}
