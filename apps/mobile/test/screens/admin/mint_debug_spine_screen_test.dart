import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/data/budget/budget_local_store.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/admin/mint_debug_spine_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('renders redacted local state and no raw values', (tester) async {
    final semantics = tester.ensureSemantics();
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
    expect(find.textContaining('65358'), findsNothing);
    expect(find.textContaining('7103'), findsNothing);
    expect(find.textContaining('VD'), findsNothing);
    final semanticsNode = tester.getSemantics(
      find.byKey(const ValueKey('mint_debug_spine_snapshot')),
    );
    expect(semanticsNode.label, contains('wizard_answers: present'));
    expect(semanticsNode.label, isNot(contains('65358')));
    expect(semanticsNode.label, isNot(contains('7103')));
    expect(semanticsNode.label, isNot(contains('VD')));
    semantics.dispose();
  });

  testWidgets('reset button refreshes snapshot after profile-store clear',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wizard_answers_v2', json.encode({'q_canton': 'VD'}));

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

    final resetButton = find.byKey(const ValueKey('mint_debug_spine_reset'));
    await tester.scrollUntilVisible(resetButton, 120);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('wizard_answers: absent'), findsOneWidget);
  });
}
