import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:mint_mobile/services/secure_wizard_store.dart';

abstract interface class MintNext3aTaskStorageAdapter {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class MintNext3aTaskStorageException implements Exception {
  const MintNext3aTaskStorageException(this.operation, this.cause);

  final String operation;
  final Object cause;
}

class FlutterSecureMintNext3aTaskStorageAdapter
    implements MintNext3aTaskStorageAdapter {
  const FlutterSecureMintNext3aTaskStorageAdapter();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MintNext3aTask {
  const MintNext3aTask({
    required this.taxYear,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    this.status = openStatus,
  });

  static const schemaVersion = 1;
  static const taskId = '3a.verify_annual_credited_total';
  static const openStatus = 'open';
  static const source = 'explicit_user_confirmation';

  final int taxYear;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final String status;

  Map<String, Object> toJson() => {
        'schema_version': schemaVersion,
        'task_id': taskId,
        'tax_year': taxYear,
        'status': status,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'source': source,
      };

  @override
  bool operator ==(Object other) =>
      other is MintNext3aTask &&
      taxYear == other.taxYear &&
      createdAt == other.createdAt &&
      updatedAt == other.updatedAt &&
      expiresAt == other.expiresAt &&
      status == other.status;

  @override
  int get hashCode =>
      Object.hash(taxYear, createdAt, updatedAt, expiresAt, status);
}

class MintNext3aTaskStore {
  const MintNext3aTaskStore({
    MintNext3aTaskStorageAdapter adapter =
        const FlutterSecureMintNext3aTaskStorageAdapter(),
    DateTime Function()? now,
  })  : _adapter = adapter,
        _now = now;

  static const storageKey = 'mint_next_3a_task_v1';
  static final ValueNotifier<int> _revision = ValueNotifier<int>(0);
  static final List<Future<void> Function()> _mutationQueue = [];
  static bool _mutationActive = false;
  static int _purgeGeneration = 0;
  static int _pendingPurgeRequests = 0;
  static bool _purgeFailedClosed = false;
  static ValueListenable<int> get changes => _revision;
  static const _fields = {
    'schema_version',
    'task_id',
    'tax_year',
    'status',
    'created_at',
    'updated_at',
    'expires_at',
    'source',
  };

  final MintNext3aTaskStorageAdapter _adapter;
  final DateTime Function()? _now;
  DateTime _currentTime() => (_now?.call() ?? DateTime.now()).toUtc();

  Future<MintNext3aTask?> read({DateTime? at}) async {
    if (_pendingPurgeRequests > 0 || _purgeFailedClosed) return null;
    final requestedGeneration = _purgeGeneration;
    final operationTime = (at ?? _currentTime()).toUtc();
    final String? raw;
    try {
      raw = await _adapter.read(storageKey);
    } on Object catch (error) {
      throw MintNext3aTaskStorageException('read', error);
    }
    if (requestedGeneration != _purgeGeneration || raw == null) return null;
    try {
      final task = _decodeAndValidate(raw, operationTime);
      return requestedGeneration == _purgeGeneration ? task : null;
    } on Object {
      return _serialize(() async {
        if (requestedGeneration != _purgeGeneration) return null;
        return _readUncoordinated(at: operationTime);
      });
    }
  }

  Future<MintNext3aTask?> _readUncoordinated({DateTime? at}) async {
    final operationTime = (at ?? _currentTime()).toUtc();
    final String? raw;
    try {
      raw = await _adapter.read(storageKey);
    } on Object catch (error) {
      throw MintNext3aTaskStorageException('read', error);
    }
    if (raw == null) return null;
    try {
      return _decodeAndValidate(raw, operationTime);
    } on MintNext3aTaskStorageException {
      rethrow;
    } on Object {
      try {
        await _adapter.delete(storageKey);
      } on Object catch (deleteError) {
        throw MintNext3aTaskStorageException('purge_invalid', deleteError);
      }
      _revision.value++;
      return null;
    }
  }

  MintNext3aTask _decodeAndValidate(String raw, DateTime operationTime) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        decoded.keys.toSet().length != _fields.length ||
        !decoded.keys.toSet().containsAll(_fields)) {
      throw const FormatException('task fields');
    }
    final task = _decode(decoded);
    if (!_isValid(task, decoded, operationTime)) {
      throw const FormatException('task values');
    }
    return task;
  }

  Future<MintNext3aTask> save({required int taxYear, DateTime? at}) {
    final blockedByPurge = _pendingPurgeRequests > 0 || _purgeFailedClosed;
    final requestedGeneration = _purgeGeneration;
    return _serialize(() async {
      if (blockedByPurge || requestedGeneration != _purgeGeneration) {
        throw MintNext3aTaskStorageException(
          'superseded',
          StateError('task save superseded by purge'),
        );
      }
      final operationTime = (at ?? _currentTime()).toUtc();
      final existing = await _readUncoordinated(at: operationTime);
      if (requestedGeneration != _purgeGeneration) {
        throw MintNext3aTaskStorageException(
          'superseded',
          StateError('task save superseded by purge'),
        );
      }
      if (existing?.taxYear == taxYear) return existing!;
      final task = MintNext3aTask(
        taxYear: taxYear,
        createdAt: operationTime,
        updatedAt: operationTime,
        expiresAt: DateTime.utc(taxYear + 1, 1, 31, 23, 59, 59),
      );
      try {
        await _adapter.write(storageKey, jsonEncode(task.toJson()));
      } on Object catch (error) {
        try {
          await _adapter.delete(storageKey);
        } on Object catch (deleteError) {
          throw MintNext3aTaskStorageException('write_cleanup', deleteError);
        }
        _revision.value++;
        throw MintNext3aTaskStorageException('write', error);
      }
      if (requestedGeneration != _purgeGeneration) {
        throw MintNext3aTaskStorageException(
          'superseded',
          StateError('task save superseded by purge'),
        );
      }
      _revision.value++;
      return task;
    });
  }

  Future<void> delete() async {
    final purged = await purgeOwnedTask(adapter: _adapter);
    if (!purged) {
      throw MintNext3aTaskStorageException(
        'delete',
        StateError('task purge failed'),
      );
    }
  }

  static Future<bool> purgeOwnedTask({
    MintNext3aTaskStorageAdapter adapter =
        const FlutterSecureMintNext3aTaskStorageAdapter(),
  }) {
    _pendingPurgeRequests++;
    _purgeGeneration++;
    return _serialize(() async {
      try {
        try {
          await adapter.delete(storageKey);
        } on Object catch (e) {
          if (!SecureWizardStore.isTolerableE2eKeychainAbsence(e)) {
            _purgeFailedClosed = true;
            return false;
          }
        }
        _purgeFailedClosed = false;
        _revision.value++;
        return true;
      } finally {
        _pendingPurgeRequests--;
      }
    });
  }

  static Future<T> _serialize<T>(Future<T> Function() action) {
    final result = Completer<T>();
    Future<void> run() async {
      try {
        result.complete(await action());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      } finally {
        if (_mutationQueue.isEmpty) {
          _mutationActive = false;
        } else {
          final next = _mutationQueue.removeAt(0);
          unawaited(next());
        }
      }
    }

    if (_mutationActive) {
      _mutationQueue.add(run);
    } else {
      _mutationActive = true;
      unawaited(run());
    }
    return result.future;
  }

  MintNext3aTask _decode(Map<String, dynamic> json) => MintNext3aTask(
        taxYear: json['tax_year'] as int,
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
        expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
        status: json['status'] as String,
      );

  bool _isValid(MintNext3aTask task, Map<String, dynamic> json, DateTime now) {
    final expectedExpiry = DateTime.utc(task.taxYear + 1, 1, 31, 23, 59, 59);
    final taxYearIsCurrent = task.taxYear == now.year;
    final taxYearIsJanuaryCarryover =
        now.month == DateTime.january && task.taxYear == now.year - 1;
    return json['schema_version'] == MintNext3aTask.schemaVersion &&
        json['task_id'] == MintNext3aTask.taskId &&
        json['status'] == MintNext3aTask.openStatus &&
        json['source'] == MintNext3aTask.source &&
        task.createdAt.isUtc &&
        task.updatedAt.isUtc &&
        task.expiresAt.isUtc &&
        !task.createdAt.isAfter(now) &&
        !task.updatedAt.isBefore(task.createdAt) &&
        !task.updatedAt.isAfter(now) &&
        (taxYearIsCurrent || taxYearIsJanuaryCarryover) &&
        task.expiresAt == expectedExpiry &&
        now.isBefore(task.expiresAt);
  }
}
