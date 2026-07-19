import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/scenario_session.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/scenario_session_provider.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';
import 'package:mint_mobile/services/scenario/scenario_session_store.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
const _visualReadyMarkerName = 'mint-g1-scn01-visual-ready-v1.marker';
const _visualReadyMarkerPayload = 'MINT_G1_SCN01_VISUAL_READY_V1\n';

final class _MemoryScenarioCache implements ScenarioSessionCache {
  String? value;
  int readCount = 0;
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<void> clear() async {
    clearCount += 1;
    value = null;
  }

  @override
  Future<String?> read() async {
    readCount += 1;
    return value;
  }

  @override
  Future<void> write(String value) async {
    writeCount += 1;
    this.value = value;
  }
}

final class _SyntheticStaleProfileProvider extends CoachProfileProvider {
  _SyntheticStaleProfileProvider() : current = _syntheticStaleProfile();

  final CoachProfile current;

  @override
  CoachProfile get profile => current;

  @override
  bool get hasProfile => true;
}

CoachProfile _syntheticStaleProfile() {
  final staleAt = DateTime.utc(2020);
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
    dataSources: const <String, ProfileDataSource>{
      'birthYear': ProfileDataSource.userInput,
      'canton': ProfileDataSource.userInput,
      'salaireBrutMensuel': ProfileDataSource.certificate,
      'prevoyance.avoirLppTotal': ProfileDataSource.certificate,
      'etatCivil': ProfileDataSource.userInput,
      'targetRetirementAge': ProfileDataSource.userInput,
    },
    dataTimestamps: <String, DateTime>{
      'birthYear': staleAt,
      'canton': staleAt,
      'salaireBrutMensuel': staleAt,
      'prevoyance.avoirLppTotal': staleAt,
      'etatCivil': staleAt,
      'targetRetirementAge': staleAt,
    },
  );
}

void _expectUnavailableWithoutFinancialData({
  required WidgetTester tester,
  required _MemoryScenarioCache cache,
  required ScenarioSessionProvider scenarioProvider,
}) {
  expect(
    find.byKey(
      const Key('rvc_scenario_unavailable'),
      skipOffstage: false,
    ),
    findsOneWidget,
  );
  expect(
    find.byType(TextFormField, skipOffstage: false),
    findsNothing,
  );
  expect(find.byType(Slider, skipOffstage: false), findsNothing);

  for (final rawDefault in const <String>[
    '50',
    '100000',
    '350000',
    '500000',
    '150000',
    '37000',
  ]) {
    expect(
      find.text(rawDefault, skipOffstage: false),
      findsNothing,
      reason: rawDefault,
    );
  }

  final unavailableText = tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(
            const Key('rvc_scenario_unavailable'),
            skipOffstage: false,
          ),
          matching: find.byType(Text, skipOffstage: false),
          skipOffstage: false,
        ),
      )
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
      .join(' ');
  expect(
    RegExp(r'CHF|\d').hasMatch(unavailableText),
    isFalse,
    reason: 'unavailable text: $unavailableText',
  );
  expect(cache.value, isNull);
  expect(cache.readCount, 0);
  expect(cache.writeCount, 0);
  expect(cache.clearCount, 0);
  expect(
    scenarioProvider.sessionFor(ScenarioKind.renteCapital),
    isNull,
  );
}

void main() {
  patrolTest(
    'keeps stale rente-capital facts unavailable without figures or session',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 6)),
    ($) async {
      final visualReadyMarker = File(
        '${Directory.systemTemp.path}/$_visualReadyMarkerName',
      );
      final profileProvider = _SyntheticStaleProfileProvider();
      final cache = _MemoryScenarioCache();
      final scenarioProvider = ScenarioSessionProvider(
        enabled: true,
        store: ScenarioSessionStore(
          cache: cache,
          idFactory: () => '55555555-5555-4555-8555-555555555555',
          clock: () => DateTime.utc(2026, 7, 19, 12),
        ),
      );
      addTearDown(() async {
        if (await visualReadyMarker.exists()) {
          await visualReadyMarker.delete();
        }
        profileProvider.dispose();
        scenarioProvider.dispose();
      });
      if (await visualReadyMarker.exists()) {
        await visualReadyMarker.delete();
      }

      await $.tester.pumpWidget(
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
            localizationsDelegates: <LocalizationsDelegate<dynamic>>[
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
            home: RenteVsCapitalScreen(),
          ),
        ),
      );

      _expectUnavailableWithoutFinancialData(
        tester: $.tester,
        cache: cache,
        scenarioProvider: scenarioProvider,
      );

      await $.tester.pump(const Duration(milliseconds: 500));
      await $.pumpAndSettle();
      _expectUnavailableWithoutFinancialData(
        tester: $.tester,
        cache: cache,
        scenarioProvider: scenarioProvider,
      );

      await visualReadyMarker.writeAsString(
        _visualReadyMarkerPayload,
        flush: true,
      );
      final visualAcknowledgementDeadline = DateTime.now().add(
        const Duration(seconds: 90),
      );
      while (await visualReadyMarker.exists()) {
        if (DateTime.now().isAfter(visualAcknowledgementDeadline)) {
          fail('Timed out waiting for visual evidence acknowledgement');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      _expectUnavailableWithoutFinancialData(
        tester: $.tester,
        cache: cache,
        scenarioProvider: scenarioProvider,
      );
    },
  );
}
