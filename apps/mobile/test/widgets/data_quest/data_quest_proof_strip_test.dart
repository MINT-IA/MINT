import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/data_quest/data_quest_service.dart';
import 'package:mint_mobile/widgets/data_quest/data_quest_proof_strip.dart';

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
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('renders first missing guard field for property transmission',
      (tester) async {
    final plan = DataQuestService.planCase(
      caseId: 'transmit_property',
      answers: const {},
      now: DateTime.utc(2026, 7, 3),
    );

    await tester.pumpWidget(_wrap(DataQuestProofStrip(
      plan: plan,
      keyPrefix: 'succession_data_quest',
    )));

    expect(find.byKey(const Key('succession_data_quest_contract')),
        findsOneWidget);
    expect(find.byKey(const Key('succession_data_quest_next_ask')),
        findsOneWidget);
    expect(find.byKey(const Key('succession_data_quest_mode_collect')),
        findsOneWidget);
    expect(find.byKey(const Key('succession_data_quest_stage_guard')),
        findsOneWidget);
    expect(find.text('Prochaine donnée à collecter'), findsOneWidget);
    expect(find.text('Valeur vénale du logement'), findsOneWidget);
    expect(find.text('Indispensable avant calcul'), findsOneWidget);
  });

  testWidgets('renders reconfirm mode for heavy-event legacy answers',
      (tester) async {
    final plan = DataQuestService.planCase(
      caseId: 'transmit_property',
      answers: const {
        'q_property_market_value': 950000,
      },
      now: DateTime.utc(2026, 7, 3),
    );

    await tester.pumpWidget(_wrap(DataQuestProofStrip(
      plan: plan,
      keyPrefix: 'succession_data_quest',
    )));

    expect(find.byKey(const Key('succession_data_quest_mode_reconfirm')),
        findsOneWidget);
    expect(find.text('Donnée à confirmer'), findsOneWidget);
    expect(find.text('950000'), findsOneWidget);
  });
}
