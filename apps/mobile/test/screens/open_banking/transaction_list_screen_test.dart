import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/open_banking/transaction_list_screen.dart';

void main() {
  Widget buildTransactionListScreen() {
    return const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: TransactionListScreen(),
    );
  }

  // formatChf inserts a non-breaking space between « CHF » and the amount.
  const zeroChf = 'CHF\u00A00.00';

  testWidgets('renders with this-month transactions (no empty state)',
      (tester) async {
    await tester.pumpWidget(buildTransactionListScreen());
    await tester.pump();
    expect(find.byType(TransactionListScreen), findsOneWidget);
    // Default period « Ce mois » — the demo data is this month, so the list is
    // populated and the empty state must NOT show.
    expect(find.text('Aucune transaction'), findsNothing);
  });

  testWidgets(
      'period chips filter both the list and the monthly summary (W0)',
      (tester) async {
    // Anti-façade: the period chips used to setState(_selectedPeriod) without
    // _filteredTransactions ever reading it (audit segment-D dead filter). Now
    // the period drives BOTH the list and the monthly summary. The demo data is
    // all the current month, so « Mois précédent » yields an honest empty list
    // AND a zeroed summary. RED while the filter is decorative, GREEN once wired.
    await tester.pumpWidget(buildTransactionListScreen());
    await tester.pumpAndSettle();

    // This month: list populated, no empty state.
    expect(find.text('Aucune transaction'), findsNothing);

    // Tap the « Mois précédent » chip.
    await tester.tap(find.text('Mois précédent'));
    await tester.pumpAndSettle();

    // The list is now filtered to last month (empty in the demo) → honest
    // empty state. A decorative (unwired) chip would leave the list in place.
    expect(find.text('Aucune transaction'), findsOneWidget);

    // Consistency lock (Codex #1020) : the monthly summary follows the period
    // too, so its rows read CHF 0.00 for the empty « mois précédent » (income,
    // expenses AND net all zero). A summary still computed on the current month
    // (the introduced bug) would show non-zero income/expenses here.
    expect(find.text(zeroChf), findsWidgets);
  });
}
