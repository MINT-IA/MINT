import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/data/budget/budget_local_store.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/admin/mint_debug_spine_screen.dart';
import 'package:mint_mobile/services/anonymous_session_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ConversationStore.setCurrentUserId(null);
  });

  testWidgets('renders redacted local state and no raw values', (tester) async {
    final semantics = tester.ensureSemantics();
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

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CoachProfileProvider(),
        child: const MaterialApp(
          home: Scaffold(body: MintDebugSpineScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Debug spine'), findsOneWidget);
    expect(find.textContaining('wizard_answers: present'), findsOneWidget);
    expect(find.textContaining('budget_inputs: present'), findsOneWidget);
    expect(find.textContaining('debug-public-sentinel'), findsNothing);
    expect(find.textContaining('debug-sensitive-sentinel'), findsNothing);
    final semanticsNode = tester.getSemantics(
      find.byKey(const ValueKey('mint_debug_spine_snapshot')),
    );
    expect(semanticsNode.label, contains('wizard_answers: present'));
    expect(semanticsNode.label, isNot(contains('debug-public-sentinel')));
    expect(semanticsNode.label, isNot(contains('debug-sensitive-sentinel')));
    semantics.dispose();
  });

  testWidgets('reset button refreshes snapshot after profile-store clear',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'wizard_answers_v2',
      json.encode({'q_public_debug_marker': 'debug-public-sentinel'}),
    );
    await BudgetLocalStore().saveOverride('custom', 0.42);
    await BudgetLocalStore().saveInputs(
      const BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 1,
        housingCost: 2,
        debtPayments: 0,
      ),
    );
    await AnonymousSessionService.updateFromResponse(0);
    await ConversationStore().saveConversation('debug-widget-conv', [
      ChatMessage(
        role: 'user',
        content: 'debug-widget-sentinel',
        timestamp: DateTime(2026, 6, 22, 13),
      ),
    ]);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CoachProfileProvider(),
        child: const MaterialApp(
          home: Scaffold(body: MintDebugSpineScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('wizard_answers: present'), findsOneWidget);
    expect(find.textContaining('budget_inputs: present'), findsOneWidget);
    expect(find.textContaining('budget_overrides: present'), findsOneWidget);
    expect(find.textContaining('anonymous_message_count: 3'), findsOneWidget);
    expect(find.text('conversation_count: 1'), findsOneWidget);

    final resetButton = find.byKey(const ValueKey('mint_debug_spine_reset'));
    await tester.scrollUntilVisible(resetButton, 120);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('wizard_answers: absent'), findsOneWidget);
    expect(find.textContaining('budget_inputs: absent'), findsOneWidget);
    expect(find.textContaining('budget_overrides: absent'), findsOneWidget);
    expect(find.textContaining('anonymous_message_count: 0'), findsOneWidget);
    expect(find.text('conversation_count: 0'), findsOneWidget);
  });
}
