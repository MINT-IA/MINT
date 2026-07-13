import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/retroactive_3a_screen.dart';
import 'package:provider/provider.dart';

class _RecordingCoachProfileProvider extends CoachProfileProvider {
  CoachProfile _current;
  int updateCalls = 0;

  _RecordingCoachProfileProvider(this._current);

  @override
  CoachProfile get profile => _current;

  @override
  bool get hasProfile => true;

  @override
  void updateProfile(CoachProfile updated) {
    updateCalls += 1;
    _current = updated;
    notifyListeners();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildRetroactive3aScreen({CoachProfileProvider? provider}) {
    const app = MaterialApp(
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
    if (provider == null) return app;
    return ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider,
      child: app,
    );
  }

  testWidgets('Retroactive3aScreen renders and shows CHF amounts',
      (tester) async {
    await tester.pumpWidget(buildRetroactive3aScreen());
    await tester.pump();
    expect(find.byType(Retroactive3aScreen), findsOneWidget);
    expect(find.textContaining('CHF'), findsWidgets);
  });

  testWidgets('changing retroactive 3a levers never mutates CoachProfile',
      (tester) async {
    final provider = _RecordingCoachProfileProvider(
      CoachProfile.defaults().copyWith(
        canton: 'VD',
        salaireBrutMensuel: 9000,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 120000,
          projectedRenteLpp: 36000,
          totalEpargne3a: 45000,
        ),
      ),
    );
    final before = provider.profile;

    await tester.pumpWidget(buildRetroactive3aScreen(provider: provider));
    await tester.pump();

    final ratePicker = tester.widget<DropdownButton<double>>(
      find.byType(DropdownButton<double>),
    );
    ratePicker.onChanged!(0.35);
    await tester.pump();

    expect(provider.updateCalls, 0);
    expect(provider.profile, same(before));
    expect(provider.profile.prevoyance.projectedRenteLpp, 36000);
    expect(provider.profile.prevoyance.totalEpargne3a, 45000);
  });
}
