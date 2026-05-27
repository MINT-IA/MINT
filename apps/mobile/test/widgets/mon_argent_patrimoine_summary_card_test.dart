import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/mon_argent/patrimoine_aggregator.dart';
import 'package:mint_mobile/widgets/mon_argent/patrimoine_summary_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('localizes patrimoine data status and source copy',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        PatrimoineSummaryCard(
          summary: PatrimoineSummary(
            lpp: PatrimoineField(
              value: 73505,
              source: 'estimated',
              lastUpdated: DateTime(2026, 5, 25),
            ),
            pillar3a: PatrimoineField(
              value: 85862,
              source: 'estimated',
              lastUpdated: DateTime(2026, 5, 24),
            ),
            epargneLiquide: PatrimoineField(
              value: 22230,
              source: 'userInput',
              lastUpdated: DateTime(2026, 5, 23),
            ),
            investissements: PatrimoineField(
              value: 12000,
              source: 'estimated',
              lastUpdated: DateTime(2026, 5, 22),
            ),
            dettes: PatrimoineField(
              value: 7000,
              source: 'userInput',
              lastUpdated: DateTime(2026, 5, 21),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == '100\u00a0% des données connues',
      ),
      findsOneWidget,
    );
    expect(find.text('Mis à jour le 25 mai · estimé'), findsOneWidget);
    expect(find.text('Investissements'), findsOneWidget);
    expect(find.text("12'000\u00a0CHF"), findsOneWidget);
    expect(find.text('Prévoyance'), findsOneWidget);
    expect(find.text("27'230\u00a0CHF"), findsOneWidget);
    expect(find.text("171'367\u00a0CHF"), findsNothing);
    expect(find.textContaining('donnees'), findsNothing);
    expect(find.textContaining('estimated'), findsNothing);
  });

  testWidgets('does not mark free assets partial when pension is missing',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const PatrimoineSummaryCard(
          summary: PatrimoineSummary(
            epargneLiquide: PatrimoineField(value: 30000, source: 'userInput'),
            investissements: PatrimoineField(value: 12000, source: 'userInput'),
            dettes: PatrimoineField(value: 10000, source: 'userInput'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == '100\u00a0% des données connues',
      ),
      findsOneWidget,
    );
    expect(find.text("32'000\u00a0CHF"), findsOneWidget);
    expect(find.text('Prévoyance'), findsNothing);
    expect(find.text('Ajoute tes données pour une vue complète.'), findsNothing);
  });

  testWidgets('shows debts as a visible negative patrimoine line',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const PatrimoineSummaryCard(
          summary: PatrimoineSummary(
            epargneLiquide: PatrimoineField(value: 20000, source: 'userInput'),
            dettes: PatrimoineField(value: 7000, source: 'userInput'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Dettes totales'), findsOneWidget);
    expect(find.text("-7'000\u00a0CHF"), findsOneWidget);
    expect(find.text("13'000\u00a0CHF"), findsOneWidget);
  });

  testWidgets('does not hide a debt-only patrimoine situation',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const PatrimoineSummaryCard(
          summary: PatrimoineSummary(
            dettes: PatrimoineField(value: 7000, source: 'userInput'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Patrimoine libre'), findsOneWidget);
    expect(find.text('Dettes totales'), findsOneWidget);
    expect(find.text("-7'000\u00a0CHF"), findsWidgets);
    expect(find.text('Scanne un document ou parle au coach pour commencer.'),
        findsNothing);
  });
}
