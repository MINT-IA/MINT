import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/profile/financial_summary_screen.dart';
import 'package:provider/provider.dart';

class _FakeCoachProfileProvider extends CoachProfileProvider {
  _FakeCoachProfileProvider(this._profile);

  final CoachProfile? _profile;

  @override
  CoachProfile? get profile => _profile;
}

Widget _pumpable(CoachProfile? profile) {
  return ChangeNotifierProvider<CoachProfileProvider>.value(
    value: _FakeCoachProfileProvider(profile),
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: FinancialSummaryScreen(),
    ),
  );
}

void main() {
  testWidgets('empty material profile shows diagnostic state, not covered gap',
      (tester) async {
    await tester.pumpWidget(_pumpable(CoachProfile.fromWizardAnswers({})));
    await tester.pumpAndSettle();

    expect(find.text('Aucun profil renseigné'), findsOneWidget);
    expect(find.text('Commencer le diagnostic'), findsOneWidget);
    expect(find.text('Tu es bien couvert·e'), findsNothing);
  });
}
