import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/net_proceeds_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  // salePrice=800000, mortgageBalance=400000, capitalGainTax=36000, eplReimbursement=50000
  // notaryFees = 800000 * 0.015 = 12000
  // agencyFees = 800000 * 0.025 = 20000
  // totalDeductions = 518000
  // netProceeds = 282000 → "282'000"
  // perceivedNet = 400000 → "400'000"
  // surprise = 118000 → "118'000"

  Widget buildWidget() => const MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: NetProceedsWidget(
              salePrice: 800000,
              mortgageBalance: 400000,
              capitalGainTax: 36000,
              eplReimbursement: 50000,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('net réel'), findsWidgets);
  });

  testWidgets('shows sale price', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("800'000"), findsWidgets);
  });

  testWidgets('shows net proceeds', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("282'000"), findsWidgets);
  });

  testWidgets('shows surprise amount', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("118'000"), findsWidgets);
  });

  testWidgets('shows perceived net', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("400'000"), findsWidgets);
  });

  testWidgets('shows details toggle', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('détail'), findsWidgets);
  });

  testWidgets('shows LIFD reference in detail after tap', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.tap(find.textContaining('détail'));
    await tester.pumpAndSettle();
    expect(find.textContaining('LIFD'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsWidgets);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(
      find.bySemanticsLabel(RegExp('net réel vente', caseSensitive: false)),
      findsOneWidget,
    );
  });
}
