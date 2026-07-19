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

Map<String, dynamic> _unknown() => <String, dynamic>{'state': 'unknown'};

Map<String, dynamic> _arrangement({
  required String confirmationId,
  required String kind,
  required String civilStatus,
}) =>
    <String, dynamic>{
      'confirmationId': confirmationId,
      'kind': kind,
      'source': 'userInput',
      'confirmedAt': _now.toIso8601String(),
      'civilStatusAtConfirmation': civilStatus,
    };

Map<String, dynamic> _present({
  required String evidenceId,
  required String civilStatus,
  String sourceDate = '2026-01-15',
}) =>
    <String, dynamic>{
      'state': 'confirmedPresent',
      'evidence': <String, dynamic>{
        'evidenceId': evidenceId,
        'ownerKind': 'self',
        'source': 'certificate',
        'sourceDate': sourceDate,
        'legalYear': 2026,
        'confirmedAt': _now.toIso8601String(),
        'civilStatusAtConfirmation': civilStatus,
      },
    };

Map<String, dynamic> _absent({
  required String evidenceId,
  required String civilStatus,
}) =>
    <String, dynamic>{
      'state': 'confirmedAbsent',
      'confirmation': <String, dynamic>{
        'evidenceId': evidenceId,
        'ownerKind': 'self',
        'source': 'userInput',
        'confirmedAt': _now.toIso8601String(),
        'civilStatusAtConfirmation': civilStatus,
      },
    };

String _root({
  Map<String, dynamic>? matrimonialRegime,
  Map<String, dynamic>? registeredPartnershipPropertyRegime,
  Map<String, dynamic>? will,
  Map<String, dynamic>? inheritancePact,
  Map<String, dynamic>? incapacityMandate,
  Map<String, dynamic>? advanceCareDirective,
}) =>
    jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'matrimonialRegime': matrimonialRegime,
      'registeredPartnershipPropertyRegime':
          registeredPartnershipPropertyRegime,
      'estateInstruments': <String, dynamic>{
        'will': will ?? _unknown(),
        'inheritancePact': inheritancePact ?? _unknown(),
        'incapacityMandate': incapacityMandate ?? _unknown(),
        'advanceCareDirective': advanceCareDirective ?? _unknown(),
      },
    });

Map<String, dynamic> _decodedRoot(Map<String, dynamic> answers) {
  final raw = answers[_rootKey];
  expect(raw, isA<String>());
  return Map<String, dynamic>.from(jsonDecode(raw as String) as Map);
}

Map<String, dynamic> _slots(Map<String, dynamic> root) =>
    Map<String, dynamic>.from(root['estateInstruments'] as Map);

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

Future<void> _confirmMarriage(
  CoachProfileProvider provider,
  MatrimonialRegimeKind kind, {
  required String? expectedPreviousConfirmationId,
}) async {
  try {
    final dynamic dynamicProvider = provider;
    await dynamicProvider.confirmMatrimonialRegime(
      kind,
      expectedPreviousConfirmationId: expectedPreviousConfirmationId,
    );
  } on NoSuchMethodError {
    fail(
        'confirmMatrimonialRegime must use confirmationId CAS and marie scope.');
  }
}

Future<void> _confirmLpart(
  CoachProfileProvider provider, {
  required String kindName,
  required String? expectedPreviousConfirmationId,
}) async {
  try {
    final dynamic dynamicProvider = provider;
    await dynamicProvider.confirmRegisteredPartnershipPropertyRegime(
      kindName: kindName,
      expectedPreviousConfirmationId: expectedPreviousConfirmationId,
    );
  } on NoSuchMethodError {
    fail(
      'confirmRegisteredPartnershipPropertyRegime must be a dedicated '
      'registered-partnership writer with its own enum.',
    );
  }
}

Future<void> _confirmPresent(
  CoachProfileProvider provider, {
  required EstateInstrumentKind kind,
  required String? expectedPreviousEvidenceId,
}) async {
  try {
    final dynamic dynamicProvider = provider;
    await dynamicProvider.confirmEstateInstrumentPresent(
      kind: kind,
      sourceDate: DateTime.utc(2026, 1, 15),
      legalYear: 2026,
      expectedPreviousEvidenceId: expectedPreviousEvidenceId,
    );
  } on NoSuchMethodError {
    fail('confirmEstateInstrumentPresent must publish a scoped evidence slot.');
  }
}

Future<void> _confirmAbsent(
  CoachProfileProvider provider, {
  required EstateInstrumentKind kind,
  required String? expectedPreviousEvidenceId,
}) async {
  try {
    final dynamic dynamicProvider = provider;
    await dynamicProvider.confirmEstateInstrumentAbsent(
      kind: kind,
      expectedPreviousEvidenceId: expectedPreviousEvidenceId,
    );
  } on NoSuchMethodError {
    fail(
        'confirmEstateInstrumentAbsent must persist explicit user confirmation.');
  }
}

Future<void> _early(Future<void> write) async {
  Object? error;
  StackTrace? stack;
  unawaited(write.then<void>((_) {}, onError: (Object e, StackTrace s) {
    error = e;
    stack = s;
  }));
  await Future<void>.delayed(Duration.zero);
  if (error != null) Error.throwWithStackTrace(error!, stack!);
}

Future<({Object? error})> _capture(Future<void> write) async {
  try {
    await write;
    return (error: null,);
  } catch (error) {
    return (error: error,);
  }
}

void _rethrowContractFailure(Iterable<({Object? error})> results) {
  for (final result in results) {
    if (result.error is TestFailure) throw result.error!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cold load consumes exact four-slot root and narrow survey API',
      () async {
    final loaded = await _loaded(
      civilStatus: 'marie',
      root: _root(
        matrimonialRegime: _arrangement(
          confirmationId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          kind: 'participationInAcquests',
          civilStatus: 'marie',
        ),
        will: _present(
          evidenceId: '11111111-1111-4111-8111-111111111111',
          civilStatus: 'marie',
        ),
        inheritancePact: _absent(
          evidenceId: '22222222-2222-4222-8222-222222222222',
          civilStatus: 'marie',
        ),
        incapacityMandate: _absent(
          evidenceId: '33333333-3333-4333-8333-333333333333',
          civilStatus: 'marie',
        ),
        advanceCareDirective: _absent(
          evidenceId: '44444444-4444-4444-8444-444444444444',
          civilStatus: 'marie',
        ),
      ),
    );
    addTearDown(loaded.provider.dispose);

    final dynamic profile = loaded.provider.profile;
    expect(profile.estateInstrumentSlots.length, 4);
    expect(profile.estateReferenceSurveyCompleteAt(_now), isTrue);
    expect(profile.estateReferenceHandoffCompletenessAt(_now).name, 'partial');
    expect(loaded.persistence.saveCalls, 0);
  });

  test(
      'marriage writer is marie-only and saves exact confirmation before publish',
      () async {
    final nonMarried = await _loaded(civilStatus: 'celibataire');
    addTearDown(nonMarried.provider.dispose);
    await expectLater(
      _confirmMarriage(
        nonMarried.provider,
        MatrimonialRegimeKind.separationOfProperty,
        expectedPreviousConfirmationId: null,
      ),
      throwsStateError,
    );
    expect(nonMarried.persistence.saveCalls, 0);

    final loaded = await _loaded(civilStatus: 'marie');
    addTearDown(loaded.provider.dispose);
    final gate = Completer<void>();
    loaded.persistence.saveGate = gate;
    var notifications = 0;
    loaded.provider.addListener(() => notifications += 1);
    final write = _confirmMarriage(
      loaded.provider,
      MatrimonialRegimeKind.separationOfProperty,
      expectedPreviousConfirmationId: null,
    );
    await _early(write);
    expect(loaded.persistence.saveCalls, 1);
    expect(notifications, 0);
    gate.complete();
    await write;

    final root = _decodedRoot(loaded.persistence.answers);
    expect(root.keys.toSet(), {
      'schemaVersion',
      'matrimonialRegime',
      'registeredPartnershipPropertyRegime',
      'estateInstruments',
    });
    final regime = Map<String, dynamic>.from(root['matrimonialRegime'] as Map);
    expect(regime['confirmationId'], matches(_uuidV4));
    expect(regime['kind'], 'separationOfProperty');
    expect(regime['source'], 'userInput');
    expect(regime['confirmedAt'], _now.toIso8601String());
    expect(regime['civilStatusAtConfirmation'], 'marie');
    expect(root['registeredPartnershipPropertyRegime'], isNull);
    expect(_slots(root).values, everyElement({'state': 'unknown'}));
    expect(notifications, 1);
  });

  test('registered partnership has a dedicated writer and root field',
      () async {
    final loaded = await _loaded(civilStatus: 'registered_partner');
    addTearDown(loaded.provider.dispose);
    await _confirmLpart(
      loaded.provider,
      kindName: 'statutorySeparationOfProperty',
      expectedPreviousConfirmationId: null,
    );

    final root = _decodedRoot(loaded.persistence.answers);
    expect(root['matrimonialRegime'], isNull);
    final lpart = Map<String, dynamic>.from(
      root['registeredPartnershipPropertyRegime'] as Map,
    );
    expect(lpart['confirmationId'], matches(_uuidV4));
    expect(lpart['kind'], 'statutorySeparationOfProperty');
    expect(lpart['civilStatusAtConfirmation'], 'registeredPartnership');
  });

  test('LPart writer is partnership-only and uses confirmationId CAS',
      () async {
    final married = await _loaded(civilStatus: 'marie');
    addTearDown(married.provider.dispose);
    await expectLater(
      _confirmLpart(
        married.provider,
        kindName: 'statutorySeparationOfProperty',
        expectedPreviousConfirmationId: null,
      ),
      throwsStateError,
    );
    expect(married.persistence.saveCalls, 0);

    final loaded = await _loaded(civilStatus: 'registered_partner');
    addTearDown(loaded.provider.dispose);
    await _confirmLpart(
      loaded.provider,
      kindName: 'statutorySeparationOfProperty',
      expectedPreviousConfirmationId: null,
    );
    final saves = loaded.persistence.saveCalls;
    final before = loaded.persistence.answers[_rootKey];
    var notifications = 0;
    loaded.provider.addListener(() => notifications += 1);
    await expectLater(
      _confirmLpart(
        loaded.provider,
        kindName: 'propertyAgreement',
        expectedPreviousConfirmationId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      ),
      throwsStateError,
    );
    expect(loaded.persistence.saveCalls, saves);
    expect(loaded.persistence.answers[_rootKey], before);
    expect(notifications, 0);
  });

  test('instrument writer saves before publishing its scoped slot', () async {
    final loaded = await _loaded();
    addTearDown(loaded.provider.dispose);
    final gate = Completer<void>();
    loaded.persistence.saveGate = gate;
    var notifications = 0;
    loaded.provider.addListener(() => notifications += 1);
    final write = _confirmPresent(
      loaded.provider,
      kind: EstateInstrumentKind.will,
      expectedPreviousEvidenceId: null,
    );
    await _early(write);

    expect(loaded.persistence.saveCalls, 1);
    expect(loaded.persistence.answers.containsKey(_rootKey), isFalse);
    expect(notifications, 0);
    gate.complete();
    await write;
    expect(
      (_slots(_decodedRoot(loaded.persistence.answers))['will']
          as Map)['state'],
      'confirmedPresent',
    );
    expect(notifications, 1);
  });

  test('present and absent writers persist scoped raw-free slots', () async {
    final loaded = await _loaded(civilStatus: 'celibataire');
    addTearDown(loaded.provider.dispose);
    await _confirmPresent(
      loaded.provider,
      kind: EstateInstrumentKind.will,
      expectedPreviousEvidenceId: null,
    );
    await _confirmAbsent(
      loaded.provider,
      kind: EstateInstrumentKind.inheritancePact,
      expectedPreviousEvidenceId: null,
    );

    final slots = _slots(_decodedRoot(loaded.persistence.answers));
    final present = Map<String, dynamic>.from(slots['will'] as Map);
    final evidence = Map<String, dynamic>.from(present['evidence'] as Map);
    expect(present['state'], 'confirmedPresent');
    expect(evidence['evidenceId'], matches(_uuidV4));
    expect(evidence['source'], 'certificate');
    expect(evidence['civilStatusAtConfirmation'], 'celibataire');
    final absent = Map<String, dynamic>.from(slots['inheritancePact'] as Map);
    final confirmation =
        Map<String, dynamic>.from(absent['confirmation'] as Map);
    expect(absent['state'], 'confirmedAbsent');
    expect(confirmation['evidenceId'], matches(_uuidV4));
    expect(confirmation['ownerKind'], 'self');
    expect(confirmation['source'], 'userInput');
    expect(confirmation['confirmedAt'], _now.toIso8601String());
    expect(confirmation['civilStatusAtConfirmation'], 'celibataire');
    final encoded = jsonEncode(slots).toLowerCase();
    for (final forbidden in ['filename', 'path', 'bytes', 'ocr', 'identity']) {
      expect(encoded, isNot(contains(forbidden)));
    }
  });

  test('same-kind present-versus-absent expected-null race has one winner',
      () async {
    final loaded = await _loaded();
    addTearDown(loaded.provider.dispose);
    final results = await Future.wait([
      _capture(_confirmPresent(
        loaded.provider,
        kind: EstateInstrumentKind.will,
        expectedPreviousEvidenceId: null,
      )),
      _capture(_confirmAbsent(
        loaded.provider,
        kind: EstateInstrumentKind.will,
        expectedPreviousEvidenceId: null,
      )),
    ]);
    _rethrowContractFailure(results);
    expect(results.where((result) => result.error == null), hasLength(1));
    expect(results.where((result) => result.error is StateError), hasLength(1));
    expect(loaded.persistence.saveCalls, 1);
    expect(_slots(_decodedRoot(loaded.persistence.answers))['will'],
        isNot({'state': 'unknown'}));
  });

  test('different-kind concurrent confirmations both survive', () async {
    final loaded = await _loaded();
    addTearDown(loaded.provider.dispose);
    await Future.wait([
      _confirmPresent(
        loaded.provider,
        kind: EstateInstrumentKind.will,
        expectedPreviousEvidenceId: null,
      ),
      _confirmAbsent(
        loaded.provider,
        kind: EstateInstrumentKind.inheritancePact,
        expectedPreviousEvidenceId: null,
      ),
    ]);
    final slots = _slots(_decodedRoot(loaded.persistence.answers));
    expect((slots['will'] as Map)['state'], 'confirmedPresent');
    expect((slots['inheritancePact'] as Map)['state'], 'confirmedAbsent');
    expect(loaded.persistence.saveCalls, 2);
  });

  test('stale evidence CAS causes zero save and zero publication', () async {
    final loaded = await _loaded();
    addTearDown(loaded.provider.dispose);
    await _confirmAbsent(
      loaded.provider,
      kind: EstateInstrumentKind.will,
      expectedPreviousEvidenceId: null,
    );
    final before = _decodedRoot(loaded.persistence.answers);
    final saves = loaded.persistence.saveCalls;
    var notifications = 0;
    loaded.provider.addListener(() => notifications += 1);

    await expectLater(
      _confirmPresent(
        loaded.provider,
        kind: EstateInstrumentKind.will,
        expectedPreviousEvidenceId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      ),
      throwsStateError,
    );
    expect(loaded.persistence.saveCalls, saves);
    expect(_decodedRoot(loaded.persistence.answers), before);
    expect(notifications, 0);
  });

  test('stale arrangement confirmationId causes zero save and publication',
      () async {
    final loaded = await _loaded(civilStatus: 'marie');
    addTearDown(loaded.provider.dispose);
    await _confirmMarriage(
      loaded.provider,
      MatrimonialRegimeKind.communityOfProperty,
      expectedPreviousConfirmationId: null,
    );
    final saves = loaded.persistence.saveCalls;
    final before = loaded.persistence.answers[_rootKey];
    var notifications = 0;
    loaded.provider.addListener(() => notifications += 1);
    await expectLater(
      _confirmMarriage(
        loaded.provider,
        MatrimonialRegimeKind.separationOfProperty,
        expectedPreviousConfirmationId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      ),
      throwsStateError,
    );
    expect(loaded.persistence.saveCalls, saves);
    expect(loaded.persistence.answers[_rootKey], before);
    expect(notifications, 0);
  });

  test('legacy global-civil root is refused by every writer', () async {
    final loaded = await _loaded(
      civilStatus: 'marie',
      root: jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'matrimonialRegime': null,
        'civilStatusAtConfirmation': 'marie',
        'estateInstrumentReferences': <dynamic>[],
      }),
    );
    addTearDown(loaded.provider.dispose);
    final before = loaded.persistence.answers[_rootKey];
    await expectLater(
      _confirmMarriage(
        loaded.provider,
        MatrimonialRegimeKind.separationOfProperty,
        expectedPreviousConfirmationId: null,
      ),
      throwsStateError,
    );
    await expectLater(
      _confirmAbsent(
        loaded.provider,
        kind: EstateInstrumentKind.will,
        expectedPreviousEvidenceId: null,
      ),
      throwsStateError,
    );
    expect(loaded.persistence.saveCalls, 0);
    expect(loaded.persistence.answers[_rootKey], before);
  });

  test('estate writers preserve an existing full-profile classification',
      () async {
    final loaded = await _loaded(civilStatus: 'marie');
    addTearDown(loaded.provider.dispose);
    loaded.provider.updateFromAnswers(loaded.persistence.answers);
    expect(loaded.provider.isPartialProfile, isFalse);
    await _confirmMarriage(
      loaded.provider,
      MatrimonialRegimeKind.participationInAcquests,
      expectedPreviousConfirmationId: null,
    );
    expect(loaded.provider.isPartialProfile, isFalse);
    await _confirmAbsent(
      loaded.provider,
      kind: EstateInstrumentKind.will,
      expectedPreviousEvidenceId: null,
    );
    expect(loaded.provider.isPartialProfile, isFalse);
  });
}
