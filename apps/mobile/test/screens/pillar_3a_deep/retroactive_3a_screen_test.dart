import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/retroactive_3a_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildRetroactive3aScreen() {
    return const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Retroactive3aScreen(),
    );
  }

  testWidgets('Retroactive3aScreen renders and shows CHF amounts', (tester) async {
    await tester.pumpWidget(buildRetroactive3aScreen());
    await tester.pump();
    expect(find.byType(Retroactive3aScreen), findsOneWidget);
    expect(find.textContaining('CHF'), findsWidgets);
  });

  testWidgets(
      'action cards are honest orientation — no false chevron affordance (W0)',
      (tester) async {
    // W0 façade fix: the "prochaines étapes" cards (ouvrir compte / préparer
    // documents / consulter spécialiste) are external orientation with NO
    // onTap. A chevron_right there is a false navigation affordance
    // ("façade-sans-câblage"). This test is RED while the chevron exists and
    // GREEN once it is removed.
    await tester.pumpWidget(buildRetroactive3aScreen());
    // pump() (not pumpAndSettle) : the default result state — which renders the
    // action cards — is shown before the async profile load settles to empty.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // let entrances finish

    // The action cards live in a lazy SliverList below the fold — scroll the
    // 3rd card (person_search, unique to « consulter un ou une spécialiste »)
    // into view so it is built.
    final personSearch = find.byIcon(Icons.person_search);
    await tester.scrollUntilVisible(
      personSearch, 400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(personSearch, findsOneWidget);

    // Anti-façade: no chevron (chevron_right is unique to these tiles, which
    // have no tap handler — an affordance implying navigation that never happens).
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });
}
