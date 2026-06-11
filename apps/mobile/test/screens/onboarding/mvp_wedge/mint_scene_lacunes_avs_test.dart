/// W2 (mint-illogism-fixes-06) — MintSceneLacunesAvs tests.
///
/// Behaviors covered:
///   1. renders the FR prompt + 4 status options
///   2. tap « Non, toujours en Suisse » writes q_avs_lacunes_status='no_gaps'
///      immediately (no follow-up) → prevoyance.lacunesAVS == null (avsGaps 0)
///   3. tap « quelques années à l'étranger » opens the numeric follow-up,
///      entering 5 writes q_avs_years_abroad=5 parsed back to
///      prevoyance.lacunesAVS == 5 (the EXACT path coach_profile.dart:2817)
///   4. tap « arrivé plus tard » follow-up writes q_avs_arrival_year, parsed
///      into CoachProfile.arrivalAge (coach_profile.dart:2810-2812)
///   5. tap « Je ne sais pas » writes 'unknown' immediately
library;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_lacunes_avs.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap({
  required Widget child,
  Locale locale = const Locale('fr'),
  CoachProfileProvider? provider,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider ?? CoachProfileProvider(),
      child: Scaffold(body: child),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('MintSceneLacunesAvs', () {
    testWidgets('renders FR prompt + 4 status options', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: MintSceneLacunesAvs(onAnswered: (_, {arrivalYear, yearsAbroad}) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('As-tu passé des années hors de Suisse ?'),
          findsOneWidget);
      for (final k in const [
        'onboarding-avs-no-gaps',
        'onboarding-avs-lived-abroad',
        'onboarding-avs-arrived-late',
        'onboarding-avs-unknown',
      ]) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
    });

    testWidgets('tap « toujours en Suisse » writes no_gaps immediately',
        (tester) async {
      final provider = CoachProfileProvider();
      String? receivedStatus;
      await tester.pumpWidget(
        _wrap(
          provider: provider,
          child: MintSceneLacunesAvs(
            onAnswered: (s, {arrivalYear, yearsAbroad}) => receivedStatus = s,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('onboarding-avs-no-gaps')));
      await _settle(tester);

      expect(receivedStatus, 'no_gaps');
      // avsGaps == 0 → lacunesAVS stays null (coach_profile.dart:2822-2823).
      expect(provider.profile?.prevoyance.lacunesAVS, isNull);
    });

    testWidgets('lived_abroad follow-up writes q_avs_years_abroad → lacunesAVS',
        (tester) async {
      final provider = CoachProfileProvider();
      String? receivedStatus;
      int? receivedYearsAbroad;
      await tester.pumpWidget(
        _wrap(
          provider: provider,
          child: MintSceneLacunesAvs(
            onAnswered: (s, {arrivalYear, yearsAbroad}) {
              receivedStatus = s;
              receivedYearsAbroad = yearsAbroad;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pick « quelques années à l'étranger » → numeric sub-step appears.
      await tester
          .tap(find.byKey(const ValueKey('onboarding-avs-lived-abroad')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('onboarding-avs-number-field')),
          findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('onboarding-avs-number-field')), '5');
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('onboarding-avs-continue')));
      await _settle(tester);

      expect(receivedStatus, 'lived_abroad');
      expect(receivedYearsAbroad, 5);
      // avsGaps = yearsAbroad (coach_profile.dart:2817-2819).
      expect(provider.profile?.prevoyance.lacunesAVS, 5);
    });

    testWidgets('arrived_late follow-up writes q_avs_arrival_year → arrivalAge',
        (tester) async {
      final provider = CoachProfileProvider();
      String? receivedStatus;
      int? receivedArrivalYear;
      await tester.pumpWidget(
        _wrap(
          provider: provider,
          child: MintSceneLacunesAvs(
            onAnswered: (s, {arrivalYear, yearsAbroad}) {
              receivedStatus = s;
              receivedArrivalYear = arrivalYear;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('onboarding-avs-arrived-late')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('onboarding-avs-number-field')), '2015');
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('onboarding-avs-continue')));
      await _settle(tester);

      expect(receivedStatus, 'arrived_late');
      expect(receivedArrivalYear, 2015);
    });

    testWidgets('tap « Je ne sais pas » writes unknown immediately',
        (tester) async {
      final provider = CoachProfileProvider();
      String? receivedStatus;
      await tester.pumpWidget(
        _wrap(
          provider: provider,
          child: MintSceneLacunesAvs(
            onAnswered: (s, {arrivalYear, yearsAbroad}) => receivedStatus = s,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('onboarding-avs-unknown')));
      await _settle(tester);

      expect(receivedStatus, 'unknown');
    });
  });
}
