import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BudgetProvider is wired to profile freshness in app.dart', () {
    final source = File('lib/app.dart').readAsStringSync();
    final match = RegExp(
      r'ChangeNotifierProxyProvider<CoachProfileProvider,\s*BudgetProvider>\s*\((.*?)\n\s*\),',
      dotAll: true,
    ).firstMatch(source);

    expect(
      match,
      isNotNull,
      reason: 'BudgetProvider must recompute from CoachProfileProvider when '
          'income, housing, health insurance, or debt facts arrive outside '
          'the budget setup screen.',
    );

    final block = match!.group(1)!;
    expect(block, contains('lazy: false'));
    expect(block, contains('profileProvider.profileUpdatedSinceBudget'));
    expect(block, contains('provider.refreshFromProfile(profile)'));
    expect(block, contains('profileProvider.markBudgetSynced()'));
    expect(
      source,
      isNot(contains('ChangeNotifierProvider(create: (_) => BudgetProvider())')),
    );
  });

  test('FinancialPlanProvider is wired to CoachProfileProvider in app.dart', () {
    final source = File('lib/app.dart').readAsStringSync();
    final match = RegExp(
      r'ChangeNotifierProxyProvider<CoachProfileProvider,\s*FinancialPlanProvider>\s*\((.*?)\n\s*\),',
      dotAll: true,
    ).firstMatch(source);

    expect(
      match,
      isNotNull,
      reason: 'FinancialPlanProvider must not be a plain provider; it needs '
          'the CoachProfileProvider dependency to mark plans stale when '
          'profile facts change.',
    );

    final block = match!.group(1)!;
    expect(block, contains('lazy: false'));
    expect(block, contains('provider.attachProfileProvider(profileProvider)'));
    expect(
      source,
      isNot(contains(
        'ChangeNotifierProvider(create: (_) => FinancialPlanProvider())',
      )),
    );
  });
}
