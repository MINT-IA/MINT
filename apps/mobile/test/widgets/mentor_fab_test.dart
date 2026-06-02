import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/mentor_fab.dart';

Widget _wrap({required int currentTabIndex}) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: Scaffold(
      floatingActionButton: MentorFAB(currentTabIndex: currentTabIndex),
    ),
  );
}

void main() {
  testWidgets('coach quick sheet uses accented and prudent profile copy',
      (tester) async {
    await tester.pumpWidget(_wrap(currentTabIndex: 2));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Affiner mon profil'), findsOneWidget);
    expect(
      find.text('Données complètes, projections plus solides'),
      findsOneWidget,
    );
    expect(find.text('Simuler un scénario'), findsOneWidget);
    expect(find.text('Mon bilan financier'), findsNothing);
    expect(find.text('Rapport complet de ta situation'), findsNothing);
    expect(find.textContaining('donnees'), findsNothing);
    expect(find.textContaining('fiables'), findsNothing);
  });

  testWidgets('coach quick sheet uses accented simulation copy',
      (tester) async {
    await tester.pumpWidget(_wrap(currentTabIndex: 0));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Simuler un scénario'), findsOneWidget);
    expect(find.text('3a, rachat LPP, hypothèque...'), findsOneWidget);
    expect(find.textContaining('scenario'), findsNothing);
    expect(find.textContaining('hypotheque'), findsNothing);
  });
}
