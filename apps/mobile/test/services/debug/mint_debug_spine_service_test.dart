import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/data/budget/budget_local_store.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/anonymous_session_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/debug/mint_debug_spine_service.dart';
import 'package:mint_mobile/services/install_lifecycle_service.dart';
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
        'q_public_debug_marker': 'debug-public-sentinel',
        'q_net_income_period_chf': 'debug-sensitive-sentinel',
      }),
    );
    await BudgetLocalStore().saveInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 1,
        housingCost: 2,
        debtPayments: 0,
      ),
    );
    await AnonymousSessionService.updateFromResponse(1);
    await ConversationStore().saveConversation('debug-spine-conv', [
      ChatMessage(
        role: 'user',
        content: 'debug-chat-sentinel',
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
    expect(snapshot.redactedRows.join('\n'),
        isNot(contains('debug-public-sentinel')));
    expect(snapshot.redactedRows.join('\n'),
        isNot(contains('debug-sensitive-sentinel')));
    expect(snapshot.redactedRows.join('\n'),
        isNot(contains('debug-chat-sentinel')));
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
        netIncome: 1,
        housingCost: 2,
        debtPayments: 0,
      ),
    );

    final snapshot = await MintDebugSpineService.loadSnapshot();

    expect(snapshot.hasBudgetInputs, isTrue);
    expect(snapshot.hasBudgetOverrides, isTrue);
    expect(snapshot.redactedRows.join('\n'), isNot(contains('0.42')));
  });

  test('snapshot reports corrupt budget inputs without debug logs', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('budget_inputs_v1', '{not-json');
    final logs = <String>[];
    final oldDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      logs.add(message ?? '');
    };
    addTearDown(() {
      debugPrint = oldDebugPrint;
    });

    final snapshot = await MintDebugSpineService.loadSnapshot();

    expect(snapshot.hasBudgetInputs, isTrue);
    expect(snapshot.hasCorruptBudgetInputs, isTrue);
    expect(snapshot.hasLocalResidue, isTrue);
    expect(snapshot.redactedRows.join('\n'),
        contains('budget_inputs_corrupt: true'));
    expect(snapshot.redactedRows.join('\n'), isNot(contains('not-json')));
    expect(logs, isEmpty);
  });

  test('resetProfileStores clears canonical profile stores', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'wizard_answers_v2',
      json.encode({'q_public_debug_marker': 'debug-public-sentinel'}),
    );
    await prefs.setDouble('budget_override_custom', 0.99);
    await BudgetLocalStore().saveInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 1,
        housingCost: 2,
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

  test('snapshot separates current user and anonymous conversations', () async {
    ConversationStore.setCurrentUserId(null);
    await ConversationStore().saveConversation('anon-conv', [
      ChatMessage(
        role: 'user',
        content: 'debug-anon-sentinel',
        timestamp: DateTime(2026, 6, 22, 11),
      ),
    ]);
    ConversationStore.setCurrentUserId('debug-user');
    await ConversationStore().saveConversation('user-conv', [
      ChatMessage(
        role: 'user',
        content: 'debug-user-sentinel',
        timestamp: DateTime(2026, 6, 22, 12),
      ),
    ]);

    final before = await MintDebugSpineService.loadSnapshot();
    expect(before.currentUserConversationCount, 1);
    expect(before.anonymousConversationCount, 1);
    expect(before.conversationCount, 2);

    final after = await MintDebugSpineService.resetProfileStores(
      CoachProfileProvider(),
    );

    expect(after.currentUserConversationCount, 0);
    expect(after.anonymousConversationCount, 0);
    expect(after.conversationCount, 0);
  });

  test('reset keeps install lifecycle purge residue visible', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(InstallLifecycleService.securePurgePendingKey, true);
    await prefs.setBool(
      InstallLifecycleService.ownedSecurePurgePendingKey,
      true,
    );

    final after = await MintDebugSpineService.resetProfileStores(
      CoachProfileProvider(),
    );

    expect(after.installSecurePurgePending, isTrue);
    expect(after.ownedSecurePurgePending, isFalse);
    expect(after.hasLocalResidue, isTrue);
    expect(after.redactedRows.join('\n'),
        contains('install_secure_purge_pending: true'));
  });
}
