import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/account_handoff_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ConversationStore.setCurrentUserId(null);
  });

  test('default handoff keeps local data available for migration', () async {
    await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});
    await ConversationStore().saveConversation('anonymous_keep', [
      ChatMessage(
        role: 'user',
        content: 'Je veux comprendre mon 3a.',
        timestamp: DateTime(2026, 6, 13, 10),
      ),
    ]);

    final shouldMigrate =
        await AccountHandoffService.prepareLocalDataForAccount('user-42');

    expect(shouldMigrate, isTrue);
    expect(await ReportPersistenceService.loadAnswers(), contains('q_canton'));
    expect(
      await ConversationStore().loadConversation('anonymous_keep'),
      isNotEmpty,
    );
  });

  test('restart choice clears anonymous local dossier before account migration',
      () async {
    await AccountHandoffService.saveChoice(AccountHandoffChoice.restartClean);
    await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});
    await ConversationStore().saveConversation('anonymous_restart', [
      ChatMessage(
        role: 'assistant',
        content: 'Diagnostic local en cours.',
        timestamp: DateTime(2026, 6, 13, 11),
      ),
    ]);

    final shouldMigrate =
        await AccountHandoffService.prepareLocalDataForAccount('user-42');
    final prefs = await SharedPreferences.getInstance();

    expect(shouldMigrate, isFalse);
    expect(await ReportPersistenceService.loadAnswers(), isEmpty);
    expect(
      await ConversationStore().loadConversation('anonymous_restart'),
      isEmpty,
    );
    expect(prefs.getBool('local_data_migrated_user-42'), isTrue);
    expect(await AccountHandoffService.loadChoice(),
        AccountHandoffChoice.keepLocal);
  });
}
