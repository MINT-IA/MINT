import 'dart:convert';

import 'package:mint_mobile/data/budget/budget_local_store.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/anonymous_session_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/install_lifecycle_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MintDebugSpineSnapshot {
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
      ownedSecurePurgePending;

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
      ];
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
    );
  }

  static Future<MintDebugSpineSnapshot> resetProfileStores(
    CoachProfileProvider coachProfileProvider,
  ) async {
    await coachProfileProvider.clearAll();
    await ConversationStore.clearNamespaceForUser(null);
    return loadSnapshot();
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
