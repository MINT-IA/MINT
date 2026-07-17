import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach/precomputed_insights_service.dart';
import 'package:mint_mobile/services/consent/partner_accountability_binding_store.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';
import 'package:mint_mobile/services/notification_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One awaitable boundary for every account-session exit.
///
/// Durable data is purged before any provider publishes an empty in-memory
/// state. Calls are coalesced so simultaneous terminal 401s and an explicit
/// logout cannot race separate destructive transactions.
class SessionTerminationCoordinator {
  static const terminationPendingKey = 'session_termination_pending_v1';

  SessionTerminationCoordinator({
    SessionEpoch? sessionEpoch,
    Future<bool> Function()? readTerminationPending,
    Future<void> Function()? writeTerminationPending,
    Future<void> Function()? clearTerminationPending,
    Future<void> Function()? cancelNotifications,
    required Future<void> Function() clearAuthTokens,
    Future<void> Function()? clearAuthRecoveryRequired,
    required Future<void> Function() purgeDurableSessionData,
    required Future<void> Function() purgeRemainingLocalData,
    required List<FutureOr<void> Function()> clearSessionMemory,
  })  : _sessionEpoch = sessionEpoch ?? SessionEpoch(),
        _readTerminationPending =
            readTerminationPending ?? _readTerminationPendingStrict,
        _writeTerminationPending =
            writeTerminationPending ?? _writeTerminationPendingStrict,
        _clearTerminationPending =
            clearTerminationPending ?? _clearTerminationPendingStrict,
        _cancelNotifications =
            cancelNotifications ?? NotificationService().cancelAll,
        _clearAuthTokens = clearAuthTokens,
        _clearAuthRecoveryRequired =
            clearAuthRecoveryRequired ?? _noopRecoveryMarkerClear,
        _purgeDurableSessionData = purgeDurableSessionData,
        _purgeRemainingLocalData = purgeRemainingLocalData,
        _clearSessionMemory = List<FutureOr<void> Function()>.unmodifiable(
          clearSessionMemory,
        );

  /// Production factory. The token primitive remains encapsulated here; API
  /// call sites may only invoke the app-injected coordinator callback.
  factory SessionTerminationCoordinator.production({
    required SessionEpoch sessionEpoch,
    required Future<void> Function() purgeDurableSessionData,
    required List<FutureOr<void> Function()> clearSessionMemory,
    Future<void> Function()? cancelNotifications,
  }) {
    CoachMemoryService.bindSessionEpoch(sessionEpoch);
    return SessionTerminationCoordinator(
      sessionEpoch: sessionEpoch,
      cancelNotifications: cancelNotifications,
      clearAuthTokens: AuthService.clearTokensForSessionTermination,
      clearAuthRecoveryRequired:
          AuthService.clearRecoveryRequiredForSessionTermination,
      purgeDurableSessionData: purgeDurableSessionData,
      purgeRemainingLocalData: _purgeRemainingLocalDataStrict,
      clearSessionMemory: clearSessionMemory,
    );
  }

  /// Isolated-provider fallback used by tests that do not mount [MintApp].
  /// Production always injects [production] from the app provider graph.
  factory SessionTerminationCoordinator.standalone({
    SessionEpoch? sessionEpoch,
    PartnerAccountabilityBindingStore? partnerAccountabilityBindingStore,
    Future<void> Function()? clearAuthTokens,
    Future<void> Function()? bestEffortLocalDataPurge,
  }) {
    final effectiveEpoch = sessionEpoch ?? SessionEpoch();
    CoachMemoryService.bindSessionEpoch(effectiveEpoch);
    return SessionTerminationCoordinator(
      sessionEpoch: effectiveEpoch,
      clearAuthTokens:
          clearAuthTokens ?? AuthService.clearTokensForSessionTermination,
      clearAuthRecoveryRequired:
          AuthService.clearRecoveryRequiredForSessionTermination,
      purgeDurableSessionData: () => ReportPersistenceService.clear(
        partnerAccountabilityBindingStore: partnerAccountabilityBindingStore,
      ),
      purgeRemainingLocalData: () async {
        final override = bestEffortLocalDataPurge;
        if (override == null) return;
        try {
          await override();
        } on Object {
          // Compatibility for isolated legacy tests only. The production
          // factory uses the strict purge below.
        }
      },
      clearSessionMemory: const [],
    );
  }

  final SessionEpoch _sessionEpoch;
  final Future<bool> Function() _readTerminationPending;
  final Future<void> Function() _writeTerminationPending;
  final Future<void> Function() _clearTerminationPending;
  final Future<void> Function() _cancelNotifications;
  final Future<void> Function() _clearAuthTokens;
  final Future<void> Function() _clearAuthRecoveryRequired;
  final Future<void> Function() _purgeDurableSessionData;
  final Future<void> Function() _purgeRemainingLocalData;
  final List<FutureOr<void> Function()> _clearSessionMemory;

  Future<void>? _inFlight;
  bool _blocked = false;
  bool _disposed = false;

  /// True from the first termination tick until every durable and memory step
  /// succeeds. It intentionally remains true after a failure.
  bool get isBlocked => _blocked;

  SessionEpoch get sessionEpoch => _sessionEpoch;

  /// Cold-start gate. Auth hydration must await this before reading tokens.
  Future<bool> resumePendingTerminationIfNeeded() async {
    if (!await _readTerminationPending()) return false;
    await terminate();
    return true;
  }

  Future<void> terminate() {
    if (_disposed) {
      return Future<void>.error(
        StateError('Session termination coordinator is disposed'),
      );
    }
    final existing = _inFlight;
    if (existing != null) return existing;

    // No await may precede invalidation: old account work loses publication
    // and persistence authority in this exact synchronous tick.
    _sessionEpoch.beginTermination();
    _blocked = true;
    late final Future<void> operation;
    operation = _performTermination().whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
    _inFlight = operation;
    return operation;
  }

  Future<void> _performTermination() async {
    // The marker is the first durable effect. Every later failure leaves it in
    // place so a cold process remains blocked and retries before auth hydration.
    await _writeTerminationPending();
    await _sessionEpoch.drainPersistence();
    if (_disposed) {
      throw StateError('Session termination coordinator disposed during purge');
    }
    await _cancelNotifications();
    await _purgeDurableSessionData();
    await _purgeRemainingLocalData();

    for (final clear in _clearSessionMemory) {
      if (_disposed) {
        throw StateError(
          'Session termination coordinator disposed before memory clear',
        );
      }
      await clear();
    }

    // Credentials/identity are deliberately last. A purge or notification
    // failure therefore never pretends the old account was logged out.
    await _clearAuthTokens();
    await _clearTerminationPending();
    await _clearAuthRecoveryRequired();
    _sessionEpoch.completeTermination();
    _blocked = false;
  }

  void dispose() {
    _disposed = true;
    _blocked = true;
  }

  static Future<void> _purgeRemainingLocalDataStrict() async {
    final conversationStore = ConversationStore();
    final conversations = await conversationStore.listConversations();
    for (final conversation in conversations) {
      await conversationStore.deleteConversation(conversation.id);
    }
    await CoachMemoryService.clearForSessionTermination();
    await CapMemoryStore.clear();
    await AnalyticsService().clearLocalQueue();

    // Financial authority was already removed by the strict purge. Remove the
    // remaining secure namespace without touching credentials before the
    // transaction's final verified token step.
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
    final secureValues = await secureStorage.readAll();
    for (final key in secureValues.keys.toList(growable: false)) {
      if (AuthService.isSessionCredentialKey(key)) continue;
      await secureStorage.delete(key: key);
      if (await secureStorage.read(key: key) != null) {
        throw StateError('Session secure-data purge failed');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await PrecomputedInsightsService.clear(prefs);
    const preserved = <String>{
      terminationPendingKey,
      'mint_locale',
      '_b2b_organization',
      '_white_label_config',
    };
    for (final key
        in prefs.getKeys().where((key) => !preserved.contains(key))) {
      final removed = await prefs.remove(key);
      if (!removed || prefs.containsKey(key)) {
        await prefs.reload();
        throw StateError('Session preferences purge failed');
      }
    }
    final localModeStored = await prefs.setBool('auth_local_mode', false);
    if (!localModeStored || prefs.getBool('auth_local_mode') != false) {
      await prefs.reload();
      throw StateError('Session local-mode lock failed');
    }
  }

  static Future<void> _noopRecoveryMarkerClear() async {}

  static Future<bool> _readTerminationPendingStrict() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(terminationPendingKey) ?? false;
  }

  static Future<void> _writeTerminationPendingStrict() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = await prefs.setBool(terminationPendingKey, true);
    if (!stored || prefs.getBool(terminationPendingKey) != true) {
      await prefs.reload();
      throw StateError('Session termination marker write failed');
    }
  }

  static Future<void> _clearTerminationPendingStrict() async {
    final prefs = await SharedPreferences.getInstance();
    final removed = await prefs.remove(terminationPendingKey);
    if (!removed || prefs.containsKey(terminationPendingKey)) {
      await prefs.reload();
      throw StateError('Session termination marker clear failed');
    }
  }
}
