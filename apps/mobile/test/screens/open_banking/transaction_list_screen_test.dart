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

  testWidgets('renders and shows the mock transactions (this month)',
      (tester) async {
    await tester.pumpWidget(buildTransactionListScreen());
    await tester.pump();
    expect(find.byType(TransactionListScreen), findsOneWidget);
    // Default period is « Ce mois » — the demo data is this month, so the
    // empty state must NOT show.
    expect(find.text('Aucune transaction'), findsNothing);
  });

  testWidgets(
      'period chips actually filter — « Mois précédent » empties the list (W0)',
      (tester) async {
    // Anti-façade: the period chips used to setState(_selectedPeriod) without
    // _filteredTransactions ever reading it (audit segment-D dead filter).
    // Now they filter. The demo data is all the current month, so tapping
    // « Mois précédent » yields an honest empty state. RED while the filter is
    // decorative (transactions still shown), GREEN once it filters.
    await tester.pumpWidget(buildTransactionListScreen());
    // Settle the MintEntrance animations so the chip is fully opaque and
    // receives pointer events (data is static — pumpAndSettle is safe here).
    await tester.pumpAndSettle();

    // This month: transactions present, no empty state.
    expect(find.text('Aucune transaction'), findsNothing);

    // Tap the « Mois précédent » chip.
    await tester.tap(find.text('Mois précédent'));
    await tester.pumpAndSettle();

    // The list is now filtered to last month (empty in the demo) → the honest
    // empty state shows. A decorative (unwired) chip would leave the
    // transactions in place and this would fail.
    expect(find.text('Aucune transaction'), findsOneWidget);
  });
}
