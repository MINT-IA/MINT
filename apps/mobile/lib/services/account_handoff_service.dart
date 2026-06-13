import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/anonymous_session_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

enum AccountHandoffChoice {
  keepLocal,
  restartClean,
}

class AccountHandoffService {
  static const choiceKey = 'mint_account_handoff_choice_v1';
  static const _restartCleanValue = 'restart_clean';
  static const _keepLocalValue = 'keep_local';

  static Future<AccountHandoffChoice> loadChoice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(choiceKey) == _restartCleanValue
        ? AccountHandoffChoice.restartClean
        : AccountHandoffChoice.keepLocal;
  }

  static Future<void> saveChoice(AccountHandoffChoice choice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      choiceKey,
      choice == AccountHandoffChoice.restartClean
          ? _restartCleanValue
          : _keepLocalValue,
    );
  }

  static Future<void> clearChoice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(choiceKey);
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
    final selectedIntent =
        await ReportPersistenceService.getSelectedOnboardingIntent();
    if (selectedIntent != null && selectedIntent.trim().isNotEmpty) {
      return true;
    }
    if ((await ConversationStore().listConversations()).isNotEmpty) {
      return true;
    }
    return await AnonymousSessionService.getMessageCount() > 0;
  }

  /// Returns whether anonymous/local data should be migrated to [userId].
  ///
  /// `restartClean` means the user chose to open the account with a clean
  /// local dossier. The purge targets only the anonymous/global local dossier;
  /// authenticated backend data is not deleted.
  static Future<bool> prepareLocalDataForAccount(String userId) async {
    final choice = await loadChoice();
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
