import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/data/budget/budget_local_store.dart';
import 'package:mint_mobile/services/anonymous_session_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

enum AccountHandoffChoice {
  keepLocal,
  restartClean,
}

class AccountHandoffService {
  static const choiceKey = 'mint_account_handoff_choice_v1';
  static const choiceSavedAtKey = 'mint_account_handoff_choice_saved_at_v1';
  static const _restartCleanValue = 'restart_clean';
  static const _keepLocalValue = 'keep_local';
  static const _choiceTtl = Duration(minutes: 30);

  static Future<AccountHandoffChoice?> loadChoice({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(choiceKey);
    if (raw == null) return null;
    if (!_isFresh(prefs.getInt(choiceSavedAtKey), now ?? DateTime.now())) {
      await clearChoice();
      return null;
    }
    if (raw == _restartCleanValue) return AccountHandoffChoice.restartClean;
    if (raw == _keepLocalValue) return AccountHandoffChoice.keepLocal;
    await clearChoice();
    return null;
  }

  static bool _isFresh(int? savedAtMs, DateTime now) {
    if (savedAtMs == null) return false;
    final savedAt = DateTime.fromMillisecondsSinceEpoch(savedAtMs);
    if (savedAt.isAfter(now)) return false;
    return now.difference(savedAt) <= _choiceTtl;
  }

  static Future<void> saveChoice(
    AccountHandoffChoice choice, {
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      choiceKey,
      choice == AccountHandoffChoice.restartClean
          ? _restartCleanValue
          : _keepLocalValue,
    );
    await prefs.setInt(
      choiceSavedAtKey,
      (now ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  static Future<void> clearChoice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(choiceKey);
    await prefs.remove(choiceSavedAtKey);
  }

  static Future<bool> hasLocalData() async {
    if ((await ReportPersistenceService.loadAnswers()).isNotEmpty) {
      return true;
    }
    if (await ReportPersistenceService.isCompleted()) {
      return true;
    }
    if (await ReportPersistenceService.isMiniOnboardingCompleted()) {
      return true;
    }
    if ((await ReportPersistenceService.loadMint2AxisHandoff()).isNotEmpty) {
      return true;
    }
    final selectedIntent =
        await ReportPersistenceService.getSelectedOnboardingIntent();
    if (selectedIntent != null && selectedIntent.trim().isNotEmpty) {
      return true;
    }
    if ((await ConversationStore().listConversations()).isNotEmpty) {
      return true;
    }
    if (await BudgetLocalStore().hasAnyData()) {
      return true;
    }
    if ((await ReportPersistenceService.loadLettersHistory()).isNotEmpty) {
      return true;
    }
    return await AnonymousSessionService.getMessageCount() > 0;
  }

  static Future<bool> requiresExplicitChoice({
    required bool handoffEnabled,
    bool hasSessionProfile = false,
    DateTime? now,
  }) async {
    if (!handoffEnabled) return false;
    if (await loadChoice(now: now) != null) return false;
    if (hasSessionProfile) return true;
    return hasLocalData();
  }

  /// Returns whether anonymous/local data should be migrated to [userId].
  ///
  /// `restartClean` means the user chose to open the account with a clean
  /// local dossier. The purge targets only the anonymous/global local dossier;
  /// authenticated backend data is not deleted.
  static Future<bool> prepareLocalDataForAccount(
    String userId, {
    required bool handoffEnabled,
  }) async {
    if (!handoffEnabled) {
      await clearChoice();
      return false;
    }

    final choice = await loadChoice();
    if (choice == null) return false;

    if (choice == AccountHandoffChoice.restartClean) {
      await ReportPersistenceService.clear(conversationUserId: null);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_data_owner', userId);
      await prefs.setBool('local_data_migrated_$userId', true);
      await clearChoice();
      return false;
    }

    await clearChoice();
    return true;
  }
}
