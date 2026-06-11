/// W2 (mint-illogism-fixes-06) — MintSceneStatutEmploi tests.
///
/// Behaviors covered:
///   1. renders the FR prompt + 3 options
///   2. tap « Indépendant » writes q_employment_status='independant'
///      (the EXACT value coach_profile.dart:2702 / _parseEmploymentStatus
///      parses) AND invokes onAnswered('independant')
///   3. tap « Salarié » writes 'salarie'
///   4. tap « Sans activité » writes 'sans_activite' AND CoachProfile
///      parses it back to 'sans_activite' (NOT coerced to 'salarie')
library;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_statut_emploi.dart';
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

  group('MintSceneStatutEmploi', () {
    testWidgets('renders FR prompt + 3 options', (tester) async {
      await tester.pumpWidget(
        _wrap(child: MintSceneStatutEmploi(onAnswered: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quelle est ta situation professionnelle ?'),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('onboarding-employment-salarie')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('onboarding-employment-independant')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('onboarding-employment-sans-activite')),
          findsOneWidget);
    });

    testWidgets('tap Indépendant writes q_employment_status=independant',
        (tester) async {
      final provider = CoachProfileProvider();
      String? received;
      await tester.pumpWidget(
        _wrap(
          provider: provider,
          child: MintSceneStatutEmploi(onAnswered: (v) => received = v),
        ),
      );
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('onboarding-employment-independant')));
      await _settle(tester);

      expect(received, 'independant');
      // The value round-trips through the canonical parser unchanged.
      expect(provider.profile?.employmentStatus, 'independant');
    });

    testWidgets('tap Salarié writes q_employment_status=salarie',
        (tester) async {
      final provider = CoachProfileProvider();
      String? received;
      await tester.pumpWidget(
        _wrap(
          provider: provider,
          child: MintSceneStatutEmploi(onAnswered: (v) => received = v),
        ),
      );
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('onboarding-employment-salarie')));
      await _settle(tester);

      expect(received, 'salarie');
      expect(provider.profile?.employmentStatus, 'salarie');
    });

    testWidgets(
        'tap Sans activité writes sans_activite (NOT coerced to salarie)',
        (tester) async {
      final provider = CoachProfileProvider();
      String? received;
      await tester.pumpWidget(
        _wrap(
          provider: provider,
          child: MintSceneStatutEmploi(onAnswered: (v) => received = v),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
          find.byKey(const ValueKey('onboarding-employment-sans-activite')));
      await _settle(tester);

      expect(received, 'sans_activite');
      // D1 root fix: a non-active user must NOT be presumed salaried.
      expect(provider.profile?.employmentStatus, 'sans_activite');
    });

    testWidgets('parser maps sans_activite verbatim (regression guard)',
        (tester) async {
      final profile = CoachProfile.fromWizardAnswers(
        const {'q_employment_status': 'sans_activite'},
      );
      expect(profile.employmentStatus, 'sans_activite');
      expect(
        CoachProfile.employmentStatusToCanonical('sans_activite'),
        'unemployed',
      );
    });
  });
}
