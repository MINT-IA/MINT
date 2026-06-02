import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/report/thematic_card.dart';

Widget _wrap({required Locale locale}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: const Scaffold(
      body: Column(
        children: [
          ThematicCard(
            emoji: '1',
            title: 'Budget',
            status: CardStatus.serein,
          ),
          ThematicCard(
            emoji: '2',
            title: 'Protection',
            status: CardStatus.aRenforcer,
          ),
          ThematicCard(
            emoji: '3',
            title: 'Fiscal',
            status: CardStatus.alerte,
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('localizes report status labels', (tester) async {
    await tester.pumpWidget(_wrap(locale: const Locale('en')));

    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('To strengthen'), findsOneWidget);
    expect(find.text('Alert'), findsOneWidget);
    expect(find.text('Serein'), findsNothing);
    expect(find.text('À renforcer'), findsNothing);
    expect(find.text('Alerte'), findsNothing);
  });
}
