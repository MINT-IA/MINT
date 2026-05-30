import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/widgets/comparators/pillar3a_comparator_widget.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('3a comparator stays educational and avoids provider CTA',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ProfileProvider(),
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Pillar3aComparatorWidget(
                monthlyIncome: 7000,
                yearsUntilRetirement: 25,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('RECOMMANDÉ'), findsNothing);
    expect(find.text('Ouvrir mon compte VIAC'), findsNothing);
    expect(find.textContaining('Avec VIAC'), findsNothing);
    expect(find.textContaining('VIAC'), findsNothing);
    expect(find.textContaining('Finpension'), findsNothing);
    expect(find.textContaining('Scénario titres 60%'), findsOneWidget);
    expect(find.text('Comparer les hypothèses 3a'), findsOneWidget);
  });
}
