import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/scenario_session.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/scenario_session_provider.dart';
import 'package:mint_mobile/screens/lpp_deep/epl_screen.dart';
import 'package:mint_mobile/services/scenario/scenario_session_store.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _MemoryCache implements ScenarioSessionCache {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

final class _RecordingProfileProvider extends CoachProfileProvider {
  _RecordingProfileProvider(this.current);

  final CoachProfile current;
  int updateCalls = 0;

  @override
  CoachProfile get profile => current;

  @override
  bool get hasProfile => true;

  @override
  void updateProfile(CoachProfile updated) {
    updateCalls++;
  }
}

final class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextButton(
          key: const Key('open_epl'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const EplScreen()),
          ),
          child: const Text('open'),
        ),
      );
}

CoachProfile _certifiedProfile() {
  final now = DateTime.utc(2026, 7, 19);
  return CoachProfile.defaults().copyWith(
    birthYear: 1980,
    canton: 'VD',
    salaireBrutMensuel: 9000,
    nombreDeMois: 12,
    etatCivil: CoachCivilStatus.marie,
    targetRetirementAge: 65,
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 420000,
      avoirLppObligatoire: 260000,
      avoirLppSurobligatoire: 160000,
      tauxConversion: 0.06,
    ),
    dataSources: const {
      'birthYear': ProfileDataSource.userInput,
      'canton': ProfileDataSource.userInput,
      'salaireBrutMensuel': ProfileDataSource.certificate,
      'prevoyance.avoirLppTotal': ProfileDataSource.certificate,
      'etatCivil': ProfileDataSource.userInput,
      'targetRetirementAge': ProfileDataSource.userInput,
    },
    dataTimestamps: {
      'birthYear': now,
      'canton': now,
      'salaireBrutMensuel': now,
      'prevoyance.avoirLppTotal': now,
      'etatCivil': now,
      'targetRetirementAge': now,
    },
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'real EPL caller persists levers and returns identity without mutating facts',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final profile = _certifiedProfile();
      final profileProvider = _RecordingProfileProvider(profile);
      final cache = _MemoryCache();
      final scenarioProvider = ScenarioSessionProvider(
        store: ScenarioSessionStore(
          cache: cache,
          idFactory: () => '55555555-5555-4555-8555-555555555555',
        ),
        enabled: true,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CoachProfileProvider>.value(
              value: profileProvider,
            ),
            ChangeNotifierProvider<ScenarioSessionProvider>.value(
              value: scenarioProvider,
            ),
          ],
          child: const MaterialApp(
            locale: Locale('fr'),
            localizationsDelegates: [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
            home: _Launcher(),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open_epl')));
      await tester.pumpAndSettle();

      final requestedAmountSlider = tester.widget<MintPremiumSlider>(
        find.byType(MintPremiumSlider).at(2),
      );
      requestedAmountSlider.onChanged(125000);
      await tester.pump(const Duration(milliseconds: 100));
      Navigator.of(tester.element(find.byType(EplScreen))).pop();
      await tester.pumpAndSettle();

      final returned = await ScreenCompletionTracker.lastReturn('epl');
      expect(returned?.scenarioId, '55555555-5555-4555-8555-555555555555');
      expect(returned?.scenarioStatus, ScenarioStatus.completed);
      expect(returned?.updatedFields, isNull);
      expect(returned?.confidenceDelta, isNull);
      expect(returned?.stepOutputs, isNull);
      expect(profileProvider.updateCalls, 0);
      expect(profileProvider.profile, same(profile));
      expect(profileProvider.profile.prevoyance.avoirLppTotal, 420000);
      expect(
        profileProvider.profile.dataSources['prevoyance.avoirLppTotal'],
        ProfileDataSource.certificate,
      );
      expect(
        profileProvider.profile.dataTimestamps['prevoyance.avoirLppTotal'],
        DateTime.utc(2026, 7, 19),
      );
      expect(cache.value, contains('125000'));
      expect(cache.value, isNot(contains('avoirLppTotal')));
      expect(cache.value, isNot(contains('stepOutputs')));
    },
  );

  testWidgets(
    'enabled EPL hides default figures when certified facts are stale',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final staleProfile = _certifiedProfile().copyWith(
        dataTimestamps: {
          for (final key in _certifiedProfile().dataTimestamps.keys)
            key: DateTime.utc(2020),
        },
      );
      final cache = _MemoryCache();
      final scenarioProvider = ScenarioSessionProvider(
        store: ScenarioSessionStore(cache: cache),
        enabled: true,
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CoachProfileProvider>.value(
              value: _RecordingProfileProvider(staleProfile),
            ),
            ChangeNotifierProvider<ScenarioSessionProvider>.value(
              value: scenarioProvider,
            ),
          ],
          child: const MaterialApp(
            locale: Locale('fr'),
            localizationsDelegates: [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
            home: _Launcher(),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open_epl')));
      await tester.pump();

      expect(
        find.byKey(
          const Key('epl_scenario_unavailable'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.byType(MintPremiumSlider, skipOffstage: false),
        findsNothing,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('epl_scenario_unavailable')), findsOneWidget);
      expect(find.byType(MintPremiumSlider), findsNothing);
      final unavailableText = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('epl_scenario_unavailable')),
              matching: find.byType(Text),
            ),
          )
          .map((widget) => widget.data ?? '')
          .join(' ');
      expect(RegExp(r'CHF|\d').hasMatch(unavailableText), isFalse);
      expect(cache.value, isNull);
      expect(scenarioProvider.sessionFor(ScenarioKind.epl), isNull);
    },
  );

  testWidgets('disabled EPL scenario boundary preserves the legacy simulator',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CoachProfileProvider>.value(
            value: _RecordingProfileProvider(_certifiedProfile()),
          ),
          ChangeNotifierProvider<ScenarioSessionProvider>.value(
            value: ScenarioSessionProvider(enabled: false),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: _Launcher(),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open_epl')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('epl_scenario_unavailable')), findsNothing);
    expect(find.byType(MintPremiumSlider), findsNWidgets(3));
  });
}
