import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/lpp_deep/rachat_echelonne_screen.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';

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

  Widget buildRachatScreen({CoachProfileProvider? provider}) {
    return ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider ?? CoachProfileProvider(),
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: RachatEchelonneScreen(),
      ),
    );
  }

  testWidgets('RachatEchelonneScreen renders and shows CHF amounts',
      (tester) async {
    await tester.pumpWidget(buildRachatScreen());
    await tester.pump();
    expect(find.byType(RachatEchelonneScreen), findsOneWidget);
    expect(find.textContaining('CHF'), findsWidgets);
  });

  testWidgets('changing a buyback plan never records a real LPP event',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final realBuybackDate = DateTime.utc(2024, 3, 1);
    final provider = _RecordingCoachProfileProvider(
      CoachProfile.defaults().copyWith(
        canton: 'VD',
        salaireBrutMensuel: 9000,
        patrimoine: const PatrimoineProfile(epargneLiquide: 100000),
        prevoyance: PrevoyanceProfile(
          avoirLppTotal: 120000,
          rachatMaximum: 80000,
          rachatEffectue: 10000,
          dateRachats: [realBuybackDate],
          projectedRenteLpp: 36000,
        ),
      ),
    );
    final before = provider.profile;
    final returnFuture = ScreenCompletionTracker.stream.firstWhere(
      (screenReturn) => screenReturn.route == '/rachat-lpp',
    );

    await tester.pumpWidget(buildRachatScreen(provider: provider));
    await tester.pump();

    final leverFinder = find.byType(MintPremiumSlider);
    for (var i = 0; i < 8 && leverFinder.evaluate().isEmpty; i += 1) {
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -500),
      );
      await tester.pump();
    }
    final firstLever = tester.widget<MintPremiumSlider>(leverFinder.first);
    firstLever.onChanged(150000);
    await tester.pump();
    final screenReturn = await returnFuture;

    expect(provider.updateCalls, 0);
    expect(provider.profile, same(before));
    expect(provider.profile.prevoyance.rachatEffectue, 10000);
    expect(provider.profile.prevoyance.dateRachats, [realBuybackDate]);
    expect(provider.profile.prevoyance.projectedRenteLpp, 36000);
    expect(screenReturn.updatedFields, isNull);
    expect(screenReturn.confidenceDelta, isNull);
    expect(screenReturn.stepOutputs, contains('rachatEconomieFiscale'));
  });
}
