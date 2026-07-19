import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mint_mobile/models/scenario_session.dart';
import 'package:uuid/uuid.dart';

abstract interface class ScenarioSessionCache {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

final class FlutterSecureScenarioSessionCache implements ScenarioSessionCache {
  FlutterSecureScenarioSessionCache({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  static const storageKey = 'g1_scenario_sessions_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: storageKey);

  @override
  Future<void> write(String value) =>
      _storage.write(key: storageKey, value: value);

  @override
  Future<void> clear() => _storage.delete(key: storageKey);
}

final class ScenarioSessionStore {
  ScenarioSessionStore({
    ScenarioSessionCache? cache,
    String Function()? idFactory,
    DateTime Function()? clock,
  })  : _cache = cache ?? FlutterSecureScenarioSessionCache(),
        _idFactory = idFactory ?? const Uuid().v4,
        _clock = clock ?? DateTime.now;

  static const _maxSessions = 8;

  final ScenarioSessionCache _cache;
  final String Function() _idFactory;
  final DateTime Function() _clock;

  Future<List<ScenarioSession>> load() async {
    try {
      final raw = await _cache.read();
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Invalid cache root');
      final root = Map<String, dynamic>.from(decoded);
      if (root.length != 2 ||
          root['schemaVersion'] != scenarioSessionSchemaVersion ||
          root['sessions'] is! List) {
        throw const FormatException('Invalid cache envelope');
      }
      final parsed = <ScenarioSession>[];
      for (final rawSession in root['sessions'] as List) {
        if (rawSession is! Map) {
          throw const FormatException('Invalid cached scenario');
        }
        parsed.add(
          ScenarioSession.fromJson(Map<String, dynamic>.from(rawSession)),
        );
      }
      if (parsed.length > _maxSessions ||
          parsed.map((session) => session.id).toSet().length != parsed.length) {
        throw const FormatException('Invalid scenario cache bounds');
      }
      return List.unmodifiable(parsed);
    } on FormatException {
      try {
        await _cache.clear();
      } on Object {
        // An unreadable cache never becomes product state.
      }
      return const [];
    } on Object {
      return const [];
    }
  }

  Future<ScenarioSession> create(ScenarioLevers levers) async {
    final id = _idFactory();
    if (!isOpaqueScenarioId(id)) {
      throw StateError('Scenario ID generator returned a non-UUIDv4 value');
    }
    final sessions = (await load()).toList();
    if (sessions.any((session) => session.id == id)) {
      throw StateError('Scenario ID collision');
    }
    final now = _clock().toUtc();
    final created = ScenarioSession(
      id: id,
      kind: levers.kind,
      status: ScenarioStatus.draft,
      createdAt: now,
      updatedAt: now,
      levers: levers,
    );
    sessions.add(created);
    if (sessions.length > _maxSessions) sessions.removeAt(0);
    await _write(sessions);
    return created;
  }

  Future<ScenarioSession?> read(
    String id, {
    required ScenarioKind expectedKind,
  }) async {
    if (!isOpaqueScenarioId(id)) return null;
    final sessions = await load();
    for (final session in sessions) {
      if (session.id == id && session.kind == expectedKind) return session;
    }
    return null;
  }

  Future<ScenarioSession?> latest(ScenarioKind expectedKind) async {
    final sessions = await load();
    for (final session in sessions.reversed) {
      if (session.kind == expectedKind && !session.isTerminal) return session;
    }
    return null;
  }

  Future<ScenarioSession?> updateLevers(
    String id, {
    required ScenarioKind expectedKind,
    required ScenarioLevers levers,
  }) async {
    if (!isOpaqueScenarioId(id) || levers.kind != expectedKind) return null;
    final sessions = (await load()).toList();
    final index = sessions.indexWhere(
      (session) => session.id == id && session.kind == expectedKind,
    );
    if (index < 0) return null;
    final updated = sessions[index].replaceLevers(levers, _clock().toUtc());
    if (updated == null) return null;
    sessions[index] = updated;
    await _write(sessions);
    return updated;
  }

  Future<ScenarioSession?> transition(
    String id, {
    required ScenarioKind expectedKind,
    required ScenarioStatus next,
  }) async {
    if (!isOpaqueScenarioId(id)) return null;
    final sessions = (await load()).toList();
    final index = sessions.indexWhere(
      (session) => session.id == id && session.kind == expectedKind,
    );
    if (index < 0) return null;
    final updated = sessions[index].transition(next, _clock().toUtc());
    if (updated == null) return null;
    sessions[index] = updated;
    await _write(sessions);
    return updated;
  }

  Future<void> clear() => _cache.clear();

  Future<void> _write(List<ScenarioSession> sessions) => _cache.write(
        jsonEncode({
          'schemaVersion': scenarioSessionSchemaVersion,
          'sessions': sessions.map((session) => session.toJson()).toList(),
        }),
      );
}
