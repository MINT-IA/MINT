import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/models/scenario_session.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/scenario_session_provider.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';
import 'package:mint_mobile/services/scenario/scenario_session_store.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _MemoryCache implements ScenarioSessionCache {
  String? value;
  Completer<void>? nextWriteStarted;
  Completer<void>? nextWriteRelease;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    final started = nextWriteStarted;
    final release = nextWriteRelease;
    nextWriteStarted = null;
    nextWriteRelease = null;
    started?.complete();
    if (release != null) await release.future;
    this.value = value;
  }
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
          key: const Key('open_rvc'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const RenteVsCapitalScreen(),
            ),
          ),
          child: const Text('open'),
        ),
      );
}

CoachProfile _profile() {
  final now = DateTime.utc(2026, 7, 19);
  return CoachProfile.defaults().copyWith(
    birthYear: 1976,
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
    'real rente-capital caller returns only local scenario identity',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 5000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final profile = _profile();
      final profileProvider = _RecordingProfileProvider(profile);
      final cache = _MemoryCache();
      final scenarioProvider = ScenarioSessionProvider(
        store: ScenarioSessionStore(
          cache: cache,
          idFactory: () => '66666666-6666-4666-8666-666666666666',
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
      await tester.tap(find.byKey(const Key('open_rvc')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(RenteVsCapitalScreen), findsOneWidget);

      final retirementAgeChip = tester.widget<ChoiceChip>(
        find.byType(ChoiceChip).at(1),
      );
      retirementAgeChip.onSelected?.call(true);
      await tester.pump(const Duration(milliseconds: 100));
      Navigator.of(tester.element(find.byType(RenteVsCapitalScreen))).pop();
      await tester.pumpAndSettle();

      final returned =
          await ScreenCompletionTracker.lastReturn('rente_vs_capital');
      expect(returned?.scenarioId, '66666666-6666-4666-8666-666666666666');
      expect(returned?.scenarioStatus, ScenarioStatus.completed);
      expect(returned?.updatedFields, isNull);
      expect(returned?.confidenceDelta, isNull);
      expect(returned?.stepOutputs, isNull);
      expect(profileProvider.updateCalls, 0);
      expect(profileProvider.profile, same(profile));
      expect(cache.value, contains('retirementAge'));
      expect(cache.value, isNot(contains('avoirLppTotal')));
      expect(cache.value, isNot(contains('stepOutputs')));
      expect(cache.value, isNot(contains('result')));
    },
  );

  testWidgets(
    'quick pop abandons the opened draft once without scenario outputs',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 5000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cache = _MemoryCache();
      final store = ScenarioSessionStore(
        cache: cache,
        idFactory: () => '77777777-7777-4777-8777-777777777777',
      );
      final scenarioProvider = ScenarioSessionProvider(
        store: store,
        enabled: true,
      );
      final observed = <ScreenReturn>[];
      final subscription = ScreenCompletionTracker.stream.listen((value) {
        if (value.route == '/rente-vs-capital') observed.add(value);
      });
      addTearDown(subscription.cancel);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CoachProfileProvider>.value(
              value: _RecordingProfileProvider(_profile()),
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
      await tester.tap(find.byKey(const Key('open_rvc')));
      await tester.pump();
      for (var i = 0;
          i < 10 &&
              scenarioProvider.sessionFor(ScenarioKind.renteCapital) == null;
          i++) {
        await tester.pump();
      }
      final draft = scenarioProvider.sessionFor(ScenarioKind.renteCapital);
      expect(draft?.status, ScenarioStatus.draft);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      expect(observed, hasLength(1));
      expect(observed.single.scenarioId, draft?.id);
      expect(observed.single.scenarioStatus, ScenarioStatus.abandoned);
      expect(observed.single.stepOutputs, isNull);
      expect(
        (await store.read(
          draft!.id,
          expectedKind: ScenarioKind.renteCapital,
        ))
            ?.status,
        ScenarioStatus.abandoned,
      );
      final coldReader = ScenarioSessionProvider(
        store: store,
        enabled: true,
      );
      await coldReader.load();
      expect(coldReader.sessionFor(ScenarioKind.renteCapital), isNull);
    },
  );

  testWidgets(
    'pop while scenario open is pending abandons the eventual draft',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 5000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cache = _MemoryCache();
      final writeStarted = Completer<void>();
      final writeRelease = Completer<void>();
      cache.nextWriteStarted = writeStarted;
      cache.nextWriteRelease = writeRelease;
      final store = ScenarioSessionStore(
        cache: cache,
        idFactory: () => '88888888-8888-4888-8888-888888888888',
      );
      final scenarioProvider = ScenarioSessionProvider(
        store: store,
        enabled: true,
      );
      final observed = <ScreenReturn>[];
      final subscription = ScreenCompletionTracker.stream.listen((value) {
        if (value.route == '/rente-vs-capital') observed.add(value);
      });
      addTearDown(subscription.cancel);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CoachProfileProvider>.value(
              value: _RecordingProfileProvider(_profile()),
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
      await tester.tap(find.byKey(const Key('open_rvc')));
      await tester.pump();
      await writeStarted.future;
      expect(scenarioProvider.sessionFor(ScenarioKind.renteCapital), isNull);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      writeRelease.complete();
      await tester.pumpAndSettle();

      expect(observed, hasLength(1));
      expect(observed.single.scenarioStatus, ScenarioStatus.abandoned);
      expect(observed.single.stepOutputs, isNull);
      final persisted = await store.read(
        '88888888-8888-4888-8888-888888888888',
        expectedKind: ScenarioKind.renteCapital,
      );
      expect(persisted?.status, ScenarioStatus.abandoned);
      expect(scenarioProvider.sessionFor(ScenarioKind.renteCapital), isNull);
    },
  );
}
