import 'dart:convert';
import 'dart:io';

import 'package:mint_mobile/data/budget/budget_local_store.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/account_handoff_service.dart';
import 'package:mint_mobile/services/anonymous_session_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/install_lifecycle_service.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MintDebugSpineSnapshot {
  static const int schemaVersion = 1;

  final bool hasWizardAnswers;
  final bool hasCorruptWizardAnswers;
  final int wizardAnswerKeyCount;
  final int plainSensitiveWizardKeyCount;
  final bool hasBudgetInputs;
  final bool hasCorruptBudgetInputs;
  final bool hasBudgetOverrides;
  final int anonymousMessageCount;
  final int conversationCount;
  final int currentUserConversationCount;
  final int anonymousConversationCount;
  final bool installSecurePurgePending;
  final bool ownedSecurePurgePending;
  final bool hasHeldAnonymousDiagnostic;
  final String accountHandoffChoice;
  final bool hasLocalDataOwner;
  final int localDataMigratedFlagCount;
  final int localDataSyncPendingFlagCount;
  final bool cloudSyncLocalMode;
  final Map<String, Object?> networkSummary;

  const MintDebugSpineSnapshot({
    required this.hasWizardAnswers,
    required this.hasCorruptWizardAnswers,
    required this.wizardAnswerKeyCount,
    required this.plainSensitiveWizardKeyCount,
    required this.hasBudgetInputs,
    required this.hasCorruptBudgetInputs,
    required this.hasBudgetOverrides,
    required this.anonymousMessageCount,
    required this.conversationCount,
    required this.currentUserConversationCount,
    required this.anonymousConversationCount,
    required this.installSecurePurgePending,
    required this.ownedSecurePurgePending,
    required this.hasHeldAnonymousDiagnostic,
    required this.accountHandoffChoice,
    required this.hasLocalDataOwner,
    required this.localDataMigratedFlagCount,
    required this.localDataSyncPendingFlagCount,
    required this.cloudSyncLocalMode,
    required this.networkSummary,
  });

  bool get hasLocalResidue =>
      hasWizardAnswers ||
      hasCorruptWizardAnswers ||
      hasBudgetInputs ||
      hasCorruptBudgetInputs ||
      hasBudgetOverrides ||
      anonymousMessageCount > 0 ||
      conversationCount > 0 ||
      installSecurePurgePending ||
      ownedSecurePurgePending ||
      hasHeldAnonymousDiagnostic ||
      accountHandoffChoice != 'none' ||
      hasLocalDataOwner ||
      localDataMigratedFlagCount > 0 ||
      localDataSyncPendingFlagCount > 0;

  List<String> get redactedRows => [
        'wizard_answers: ${hasWizardAnswers ? "present" : "absent"} '
            '($wizardAnswerKeyCount keys)',
        'wizard_answers_corrupt: $hasCorruptWizardAnswers',
        'plain_sensitive_wizard_keys: $plainSensitiveWizardKeyCount',
        'budget_inputs: ${hasBudgetInputs ? "present" : "absent"}',
        'budget_inputs_corrupt: $hasCorruptBudgetInputs',
        'budget_overrides: ${hasBudgetOverrides ? "present" : "absent"}',
        'anonymous_message_count: $anonymousMessageCount',
        'conversation_count: $conversationCount',
        'current_user_conversation_count: $currentUserConversationCount',
        'anonymous_conversation_count: $anonymousConversationCount',
        'install_secure_purge_pending: $installSecurePurgePending',
        'owned_secure_purge_pending: $ownedSecurePurgePending',
        'held_anonymous_diagnostic: $hasHeldAnonymousDiagnostic',
        'account_handoff_choice: $accountHandoffChoice',
        'local_data_owner: ${hasLocalDataOwner ? "present" : "absent"}',
        'local_data_migrated_flags: $localDataMigratedFlagCount',
        'local_data_sync_pending_flags: $localDataSyncPendingFlagCount',
        'cloud_sync_local_mode: $cloudSyncLocalMode',
      ];

  Map<String, Object?> toRedactedJson() => {
        'schemaVersion': schemaVersion,
        'residue': {
          'wizardAnswers': {
            'state': hasWizardAnswers ? 'present' : 'absent',
            'keyCount': wizardAnswerKeyCount,
            'corrupt': hasCorruptWizardAnswers,
            'plainSensitiveKeyCount': plainSensitiveWizardKeyCount,
          },
          'budgetInputs': {
            'state': hasBudgetInputs ? 'present' : 'absent',
            'corrupt': hasCorruptBudgetInputs,
          },
          'budgetOverrides': {
            'state': hasBudgetOverrides ? 'present' : 'absent',
          },
          'anonymousMessages': {
            'count': anonymousMessageCount,
          },
          'anonymousConversations': {
            'count': anonymousConversationCount,
          },
          'currentUserConversations': {
            'count': currentUserConversationCount,
          },
          'ownedSecurePurge': {
            'pending': ownedSecurePurgePending,
          },
          'installSecurePurge': {
            'pending': installSecurePurgePending,
          },
          'heldAnonymousDiagnostic': {
            'present': hasHeldAnonymousDiagnostic,
          },
          'accountHandoff': {
            'choice': accountHandoffChoice,
            'hasLocalDataOwner': hasLocalDataOwner,
            'migratedFlagCount': localDataMigratedFlagCount,
            'syncPendingFlagCount': localDataSyncPendingFlagCount,
            'cloudSyncLocalMode': cloudSyncLocalMode,
          },
          'keychain': {
            'observable': false,
            'status': 'keychain_reset_by_gate_when_true_fresh',
          },
          'networkSummary': networkSummary,
        },
      };
}

class MintDebugSpineService {
  MintDebugSpineService._();

  static Future<MintDebugSpineSnapshot> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final rawWizard = prefs.getString('wizard_answers_v2');
    final decodedWizard = _decodeMap(rawWizard);
    final wizard = decodedWizard.map;
    final budgetStore = BudgetLocalStore();
    final hasBudgetInputs = await budgetStore.hasInputResidue();
    final hasCorruptBudgetInputs = await budgetStore.hasCorruptInputs();
    final hasBudgetOverrides = await budgetStore.hasOverrideResidue();
    final anonymousMessageCount =
        await AnonymousSessionService.getMessageCount();
    final conversationStore = ConversationStore();
    final currentUserId = ConversationStore.currentUserId;
    final currentUserConversations = currentUserId == null
        ? <ConversationMeta>[]
        : await conversationStore.listConversationsForUser(currentUserId);
    final anonymousConversations =
        await conversationStore.listConversationsForUser(null);
    final conversationCount =
        currentUserConversations.length + anonymousConversations.length;
    final keys = prefs.getKeys();

    return MintDebugSpineSnapshot(
      hasWizardAnswers: wizard.isNotEmpty,
      hasCorruptWizardAnswers: decodedWizard.corrupt,
      wizardAnswerKeyCount: wizard.length,
      plainSensitiveWizardKeyCount: _plainSensitiveWizardKeyCount(wizard),
      hasBudgetInputs: hasBudgetInputs,
      hasCorruptBudgetInputs: hasCorruptBudgetInputs,
      hasBudgetOverrides: hasBudgetOverrides,
      anonymousMessageCount: anonymousMessageCount,
      conversationCount: conversationCount,
      currentUserConversationCount: currentUserConversations.length,
      anonymousConversationCount: anonymousConversations.length,
      installSecurePurgePending:
          prefs.getBool(InstallLifecycleService.securePurgePendingKey) == true,
      ownedSecurePurgePending: prefs.getBool(
            InstallLifecycleService.ownedSecurePurgePendingKey,
          ) ==
          true,
      hasHeldAnonymousDiagnostic:
          await ReportPersistenceService.hasHeldAnonymousDiagnostic(),
      accountHandoffChoice: _accountHandoffChoice(prefs),
      hasLocalDataOwner: prefs.containsKey('local_data_owner'),
      localDataMigratedFlagCount:
          keys.where((key) => key.startsWith('local_data_migrated_')).length,
      localDataSyncPendingFlagCount: keys
          .where((key) => key.startsWith('local_data_sync_pending_'))
          .length,
      cloudSyncLocalMode: prefs.getBool('auth_local_mode') == true,
      networkSummary: MintHttpClient.runtimeNetworkSummary(),
    );
  }

  static Future<Map<String, Object?>> loadRedactedJson() async {
    final snapshot = await loadSnapshot();
    return snapshot.toRedactedJson();
  }

  static Future<void> exportRedactedEvidence(String label) async {
    await writeRedactedEvidence(label, await loadRedactedJson());
  }

  static Future<void> writeRedactedEvidence(
    String label,
    Map<String, Object?> redacted,
  ) async {
    final supportDir = await getApplicationSupportDirectory();
    final evidenceDir = Directory(
      '${supportDir.path}/mint-runtime-debug-evidence',
    );
    await evidenceDir.create(recursive: true);
    final formatted = const JsonEncoder.withIndent('  ').convert(redacted);
    await File('${evidenceDir.path}/debug-spine-$label.json')
        .writeAsString('$formatted\n');
  }

  static Future<MintDebugSpineSnapshot> resetProfileStores(
    CoachProfileProvider coachProfileProvider,
  ) async {
    await coachProfileProvider.clearAll();
    await AccountHandoffService.clearChoice();
    await _clearAccountLifecycleResidue();
    await ConversationStore.clearNamespaceForUser(null);
    return loadSnapshot();
  }

  static Future<void> _clearAccountLifecycleResidue() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) {
      return key == 'local_data_owner' ||
          key == 'auth_local_mode' ||
          key.startsWith('local_data_migrated_') ||
          key.startsWith('local_data_sync_pending_');
    }).toList(growable: false);
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  static String _accountHandoffChoice(SharedPreferences prefs) {
    final raw = prefs.getString(AccountHandoffService.choiceKey);
    if (raw == 'keep_local') return 'keep_local';
    if (raw == 'restart_clean') return 'restart_clean';
    if (raw == null || raw.isEmpty) return 'none';
    return 'unknown';
  }

  static _DecodedWizardMap _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const _DecodedWizardMap(map: {}, corrupt: false);
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) {
        return const _DecodedWizardMap(map: {}, corrupt: true);
      }
      return _DecodedWizardMap(
        map: Map<String, dynamic>.from(decoded),
        corrupt: false,
      );
    } catch (_) {
      return const _DecodedWizardMap(map: {}, corrupt: true);
    }
  }

  static int _plainSensitiveWizardKeyCount(Map<String, dynamic> wizard) {
    var count = 0;
    for (final entry in wizard.entries) {
      if (!SecureWizardStore.isSensitive(entry.key)) continue;
      if (entry.value == null || entry.value == '__secure__') continue;
      count++;
    }
    return count;
  }
}

class _DecodedWizardMap {
  final Map<String, dynamic> map;
  final bool corrupt;

  const _DecodedWizardMap({
    required this.map,
    required this.corrupt,
  });
}
