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
  final bool hasBudgetOverrides;
  final int anonymousMessageCount;
  final int conversationCount;
  final bool installSecurePurgePending;
  final bool ownedSecurePurgePending;

  const MintDebugSpineSnapshot({
    required this.hasWizardAnswers,
    required this.hasCorruptWizardAnswers,
    required this.wizardAnswerKeyCount,
    required this.plainSensitiveWizardKeyCount,
    required this.hasBudgetInputs,
    required this.hasBudgetOverrides,
    required this.anonymousMessageCount,
    required this.conversationCount,
    required this.installSecurePurgePending,
    required this.ownedSecurePurgePending,
  });

  bool get hasLocalResidue =>
      hasWizardAnswers ||
      hasCorruptWizardAnswers ||
      hasBudgetInputs ||
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
        'budget_overrides: ${hasBudgetOverrides ? "present" : "absent"}',
        'anonymous_message_count: $anonymousMessageCount',
        'conversation_count: $conversationCount',
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
    final hasBudgetInputs = await budgetStore.loadInputs() != null;
    final hasBudgetOverrides = _hasBudgetOverrides(prefs);
    final anonymousMessageCount =
        await AnonymousSessionService.getMessageCount();
    final conversations = await ConversationStore().listConversations();

    return MintDebugSpineSnapshot(
      hasWizardAnswers: wizard.isNotEmpty,
      hasCorruptWizardAnswers: decodedWizard.corrupt,
      wizardAnswerKeyCount: wizard.length,
      plainSensitiveWizardKeyCount: _plainSensitiveWizardKeyCount(wizard),
      hasBudgetInputs: hasBudgetInputs,
      hasBudgetOverrides: hasBudgetOverrides,
      anonymousMessageCount: anonymousMessageCount,
      conversationCount: conversations.length,
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

  static bool _hasBudgetOverrides(SharedPreferences prefs) {
    return prefs.getKeys().any((key) => key.startsWith('budget_override_'));
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
