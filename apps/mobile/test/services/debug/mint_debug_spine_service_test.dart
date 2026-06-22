import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/data/budget/budget_local_store.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/anonymous_session_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/debug/mint_debug_spine_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ConversationStore.setCurrentUserId(null);
  });

  test('snapshot exposes state shape without raw financial values', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'wizard_answers_v2',
      json.encode({
        'q_canton': 'VD',
        'q_net_income_period_chf': 65358,
      }),
    );
    await BudgetLocalStore().saveInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 7103,
        housingCost: 2100,
        debtPayments: 0,
      ),
    );
    await AnonymousSessionService.updateFromResponse(1);
    await ConversationStore().saveConversation('debug-spine-conv', [
      ChatMessage(
        role: 'user',
        content: 'Mon salaire est 65358 CHF',
        timestamp: DateTime(2026, 6, 22, 9),
      ),
    ]);

    final snapshot = await MintDebugSpineService.loadSnapshot();

    expect(snapshot.hasWizardAnswers, isTrue);
    expect(snapshot.wizardAnswerKeyCount, 2);
    expect(snapshot.hasBudgetInputs, isTrue);
    expect(snapshot.anonymousMessageCount, 2);
    expect(snapshot.conversationCount, 1);
    expect(snapshot.plainSensitiveWizardKeyCount, 1);
    expect(snapshot.hasCorruptWizardAnswers, isFalse);
    expect(snapshot.redactedRows.join('\n'), isNot(contains('65358')));
    expect(snapshot.redactedRows.join('\n'), isNot(contains('7103')));
    expect(snapshot.redactedRows.join('\n'), isNot(contains('VD')));
  });

  test('snapshot reports corrupt wizard answers without throwing', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wizard_answers_v2', '{not-json');

    final snapshot = await MintDebugSpineService.loadSnapshot();

    expect(snapshot.hasWizardAnswers, isFalse);
    expect(snapshot.hasCorruptWizardAnswers, isTrue);
    expect(snapshot.hasLocalResidue, isTrue);
    expect(snapshot.redactedRows.join('\n'),
        contains('wizard_answers_corrupt: true'));
    expect(snapshot.redactedRows.join('\n'), isNot(contains('not-json')));
  });

  test('snapshot distinguishes sealed sensitive values from plain values',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'wizard_answers_v2',
      json.encode({
        'q_net_income_period_chf': '__secure__',
      }),
    );

    final snapshot = await MintDebugSpineService.loadSnapshot();

    expect(snapshot.hasWizardAnswers, isTrue);
    expect(snapshot.wizardAnswerKeyCount, 1);
    expect(snapshot.plainSensitiveWizardKeyCount, 0);
    expect(snapshot.redactedRows.join('\n'), isNot(contains('__secure__')));
  });

  test('snapshot reports budget overrides without raw override values',
      () async {
    await BudgetLocalStore().saveOverride('future', 0.42);

    final snapshot = await MintDebugSpineService.loadSnapshot();

    expect(snapshot.hasBudgetInputs, isFalse);
    expect(snapshot.hasBudgetOverrides, isTrue);
    expect(snapshot.redactedRows.join('\n'),
        contains('budget_overrides: present'));
    expect(snapshot.redactedRows.join('\n'), isNot(contains('0.42')));
  });

  test('snapshot reports budget overrides even when inputs coexist', () async {
    await BudgetLocalStore().saveOverride('future', 0.42);
    await BudgetLocalStore().saveInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 7103,
        housingCost: 2100,
        debtPayments: 0,
      ),
    );

    final snapshot = await MintDebugSpineService.loadSnapshot();

    expect(snapshot.hasBudgetInputs, isTrue);
    expect(snapshot.hasBudgetOverrides, isTrue);
    expect(snapshot.redactedRows.join('\n'), isNot(contains('7103')));
    expect(snapshot.redactedRows.join('\n'), isNot(contains('0.42')));
  });

  test('resetProfileStores clears canonical profile stores', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wizard_answers_v2', json.encode({'q_canton': 'VD'}));
    await prefs.setDouble('budget_override_custom', 0.99);
    await BudgetLocalStore().saveInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 7103,
        housingCost: 2100,
        debtPayments: 0,
      ),
    );
    await AnonymousSessionService.updateFromResponse(0);
    await ConversationStore().saveConversation('debug-spine-reset', [
      ChatMessage(
        role: 'user',
        content: 'Ancien contexte',
        timestamp: DateTime(2026, 6, 22, 10),
      ),
    ]);

    final before = await MintDebugSpineService.loadSnapshot();
    expect(before.hasLocalResidue, isTrue);

    final after = await MintDebugSpineService.resetProfileStores(
      CoachProfileProvider(),
    );

    expect(after.hasWizardAnswers, isFalse);
    expect(after.hasBudgetInputs, isFalse);
    expect(after.hasBudgetOverrides, isFalse);
    expect(after.anonymousMessageCount, 0);
    expect(after.conversationCount, 0);
    expect(after.hasLocalResidue, isFalse);
  });
}
