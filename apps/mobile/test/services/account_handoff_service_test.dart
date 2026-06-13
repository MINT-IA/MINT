import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/data/budget/budget_local_store.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
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

  test('missing handoff choice keeps local data separate from account',
      () async {
    await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});
    await ConversationStore().saveConversation('anonymous_keep', [
      ChatMessage(
        role: 'user',
        content: 'Je veux comprendre mon 3a.',
        timestamp: DateTime(2026, 6, 13, 10),
      ),
    ]);

    final shouldMigrate =
        await AccountHandoffService.prepareLocalDataForAccount(
      'user-42',
      handoffEnabled: true,
    );

    expect(shouldMigrate, isFalse);
    expect(await ReportPersistenceService.loadAnswers(), contains('q_canton'));
    expect(
      await ConversationStore().loadConversation('anonymous_keep'),
      isNotEmpty,
    );
  });

  test('explicit keep choice makes local data available for migration',
      () async {
    await AccountHandoffService.saveChoice(AccountHandoffChoice.keepLocal);
    await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});
    await ConversationStore().saveConversation('anonymous_keep', [
      ChatMessage(
        role: 'user',
        content: 'Je veux comprendre mon 3a.',
        timestamp: DateTime(2026, 6, 13, 10),
      ),
    ]);

    final shouldMigrate =
        await AccountHandoffService.prepareLocalDataForAccount(
      'user-42',
      handoffEnabled: true,
    );

    expect(shouldMigrate, isTrue);
    expect(await ReportPersistenceService.loadAnswers(), contains('q_canton'));
    expect(
      await ConversationStore().loadConversation('anonymous_keep'),
      isNotEmpty,
    );
    expect(await AccountHandoffService.loadChoice(), isNull);
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
        await AccountHandoffService.prepareLocalDataForAccount(
      'user-42',
      handoffEnabled: true,
    );
    final prefs = await SharedPreferences.getInstance();

    expect(shouldMigrate, isFalse);
    expect(await ReportPersistenceService.loadAnswers(), isEmpty);
    expect(
      await ConversationStore().loadConversation('anonymous_restart'),
      isEmpty,
    );
    expect(prefs.getBool('local_data_migrated_user-42'), isTrue);
    expect(await AccountHandoffService.loadChoice(), isNull);
  });

  test('stale restart choice is ignored and cleared', () async {
    final savedAt = DateTime(2026, 6, 13, 10);
    final now = savedAt.add(const Duration(minutes: 31));
    await AccountHandoffService.saveChoice(
      AccountHandoffChoice.restartClean,
      now: savedAt,
    );
    await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});

    expect(await AccountHandoffService.loadChoice(now: now), isNull);

    final shouldMigrate =
        await AccountHandoffService.prepareLocalDataForAccount(
      'user-42',
      handoffEnabled: true,
    );

    expect(shouldMigrate, isFalse);
    expect(await ReportPersistenceService.loadAnswers(), contains('q_canton'));
  });

  test('stored choice is ignored when handoff UI is disabled', () async {
    await AccountHandoffService.saveChoice(AccountHandoffChoice.restartClean);
    await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});

    final shouldMigrate =
        await AccountHandoffService.prepareLocalDataForAccount(
      'user-42',
      handoffEnabled: false,
    );

    expect(shouldMigrate, isFalse);
    expect(await ReportPersistenceService.loadAnswers(), contains('q_canton'));
    expect(await AccountHandoffService.loadChoice(), isNull);
  });

  test('local data detector includes budget-only data', () async {
    await BudgetLocalStore().saveInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 7200,
        housingCost: 2100,
        debtPayments: 0,
      ),
    );

    expect(await AccountHandoffService.hasLocalData(), isTrue);
  });

  test('local data detector includes generated letters only', () async {
    await ReportPersistenceService.saveLettersHistory([
      {'title': 'Attestation rachat LPP'}
    ]);

    expect(await AccountHandoffService.hasLocalData(), isTrue);
  });
}
