import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/scenario_session.dart';
import 'package:mint_mobile/services/biography/freshness_decay_service.dart';
import 'package:mint_mobile/services/scenario/scenario_session_store.dart';
import 'package:mint_mobile/services/session_epoch.dart';

/// Account-scoped UI state for the two bounded G1 scenario kinds.
///
/// The provider owns no financial facts. Screens always reread CoachProfile
/// before opening or restoring a session and pass [factsReady] fail closed.
final class ScenarioSessionProvider extends ChangeNotifier {
  ScenarioSessionProvider({
    ScenarioSessionStore? store,
    SessionEpoch? sessionEpoch,
    required bool enabled,
  })  : _store = store ?? ScenarioSessionStore(),
        _sessionEpoch = sessionEpoch ?? SessionEpoch(),
        _enabled = enabled;

  final ScenarioSessionStore _store;
  final SessionEpoch _sessionEpoch;
  final bool _enabled;
  final Map<ScenarioKind, ScenarioSession> _active = {};

  bool get enabled => _enabled;

  static bool eplFactsReady(CoachProfile? profile, DateTime now) {
    if (profile == null ||
        profile.birthYear <= 0 ||
        profile.canton.isEmpty ||
        (profile.prevoyance.avoirLppTotal ?? 0) <= 0 ||
        profile.revenuBrutAnnuel <= 0) {
      return false;
    }
    return _current(profile, 'birthYear', profile.birthYear, now) &&
        _current(profile, 'canton', profile.canton, now) &&
        _current(
          profile,
          'prevoyance.avoirLppTotal',
          profile.prevoyance.avoirLppTotal,
          now,
        ) &&
        (_current(
              profile,
              'revenuBrutAnnuel',
              profile.revenuBrutAnnuel,
              now,
            ) ||
            _current(
              profile,
              'salaireBrutMensuel',
              profile.salaireBrutMensuel,
              now,
            ));
  }

  static bool renteCapitalFactsReady(CoachProfile? profile, DateTime now) {
    if (!eplFactsReady(profile, now) || profile == null) return false;
    final targetAge = profile.targetRetirementAge;
    if (targetAge == null) return false;
    return _current(profile, 'etatCivil', profile.etatCivil, now) &&
        _current(profile, 'targetRetirementAge', targetAge, now);
  }

  static bool _current(
    CoachProfile profile,
    String fieldPath,
    Object? value,
    DateTime now,
  ) {
    final source = profile.dataSources[fieldPath];
    final timestamp = profile.dataTimestamps[fieldPath];
    return FreshnessDecayService.assessLedgerField<Object>(
      fieldPath: fieldPath,
      previousValue: value,
      updatedAt: timestamp,
      sourceName: source?.name,
      now: now,
    ).isCurrent;
  }

  ScenarioSession? sessionFor(ScenarioKind kind) => _active[kind];

  /// Resolve an opaque completion reference against encrypted persistence.
  ///
  /// This intentionally returns only a boolean. Callers cannot obtain the
  /// stored levers or treat them as canonical financial facts.
  Future<bool> validatesCompleted(
    String id,
    ScenarioKind expectedKind,
  ) async {
    if (!_enabled || !isOpaqueScenarioId(id)) return false;
    try {
      final guard = _sessionEpoch.capture();
      final session = await _sessionEpoch.runGuardedPersistence(
        guard,
        () => _store.read(id, expectedKind: expectedKind),
      );
      guard.assertCurrent();
      return session?.kind == expectedKind &&
          session?.status == ScenarioStatus.completed;
    } on SessionEpochInvalidated {
      return false;
    } on Object {
      return false;
    }
  }

  Future<void> load() async {
    if (!_enabled) {
      try {
        await _store.clear();
      } on Object {
        // A disabled feature never publishes cached state.
      }
      clearSessionMemoryAfterPurge();
      return;
    }

    try {
      final guard = _sessionEpoch.capture();
      final sessions = await _sessionEpoch.runGuardedPersistence(
        guard,
        _store.load,
      );
      guard.assertCurrent();
      _active.clear();
      for (final session in sessions) {
        if (!session.isTerminal) _active[session.kind] = session;
      }
      notifyListeners();
    } on SessionEpochInvalidated {
      // Session termination owns memory clearing.
    } on Object {
      clearSessionMemoryAfterPurge();
    }
  }

  /// Opens the latest non-terminal session for the kind, or creates a draft.
  ///
  /// [factsReady] must be computed from current canonical CoachProfile facts;
  /// cached levers alone can never unlock a result.
  Future<ScenarioSession?> open(
    ScenarioLevers defaults, {
    required bool factsReady,
  }) async {
    if (!_enabled || !factsReady) return null;
    try {
      final guard = _sessionEpoch.capture();
      final inMemory = _active[defaults.kind];
      if (inMemory != null && !inMemory.isTerminal) return inMemory;

      final restored = await _sessionEpoch.runGuardedPersistence(
        guard,
        () => _store.latest(defaults.kind),
      );
      guard.assertCurrent();
      if (restored != null) {
        _active[defaults.kind] = restored;
        notifyListeners();
        return restored;
      }

      final created = await _sessionEpoch.runGuardedPersistence(
        guard,
        () => _store.create(defaults),
      );
      guard.assertCurrent();
      _active[created.kind] = created;
      notifyListeners();
      return created;
    } on SessionEpochInvalidated {
      return null;
    } on Object {
      return null;
    }
  }

  Future<ScenarioSession?> saveLevers(
    String id, {
    required ScenarioKind expectedKind,
    required ScenarioLevers levers,
    required bool factsReady,
  }) async {
    if (!_enabled || !factsReady || !isOpaqueScenarioId(id)) return null;
    try {
      final guard = _sessionEpoch.capture();
      final updated = await _sessionEpoch.runGuardedPersistence(
        guard,
        () => _store.updateLevers(
          id,
          expectedKind: expectedKind,
          levers: levers,
        ),
      );
      guard.assertCurrent();
      if (updated == null) return null;
      _active[expectedKind] = updated;
      notifyListeners();
      return updated;
    } on SessionEpochInvalidated {
      return null;
    } on Object {
      return null;
    }
  }

  Future<ScenarioSession?> markCalculated(
    String id, {
    required ScenarioKind expectedKind,
  }) =>
      _transition(
        id,
        expectedKind: expectedKind,
        next: ScenarioStatus.calculated,
      );

  Future<ScenarioSession?> markTerminal(
    String id, {
    required ScenarioKind expectedKind,
    required ScenarioStatus status,
  }) {
    if (status != ScenarioStatus.completed &&
        status != ScenarioStatus.abandoned) {
      return Future.value(null);
    }
    return _transition(id, expectedKind: expectedKind, next: status);
  }

  Future<ScenarioSession?> _transition(
    String id, {
    required ScenarioKind expectedKind,
    required ScenarioStatus next,
  }) async {
    if (!_enabled || !isOpaqueScenarioId(id)) return null;
    try {
      final guard = _sessionEpoch.capture();
      final updated = await _sessionEpoch.runGuardedPersistence(
        guard,
        () => _store.transition(
          id,
          expectedKind: expectedKind,
          next: next,
        ),
      );
      guard.assertCurrent();
      if (updated == null) return null;
      if (updated.isTerminal) {
        _active.remove(expectedKind);
      } else {
        _active[expectedKind] = updated;
      }
      notifyListeners();
      return updated;
    } on SessionEpochInvalidated {
      return null;
    } on Object {
      return null;
    }
  }

  Future<void> purgeSessionPersistence() => _store.clear();

  void clearSessionMemoryAfterPurge() {
    if (_active.isEmpty) return;
    _active.clear();
    notifyListeners();
  }
}
