/// W2 (mint-illogism-fixes-06) — MintSceneEtatCivil tests.
///
/// Behaviors covered:
///   1. renders the FR prompt + 5 options (incl. « Divorcé »)
///   2. tap « Divorcé » writes q_civil_status='divorce' parsed back to
///      CoachCivilStatus.divorce (the EXACT value coach_profile.dart:2668
///      / _parseCivilStatus maps)
///   3. tap « Marié » → CoachCivilStatus.marie
///   4. tap « Célibataire » → CoachCivilStatus.celibataire
library;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/scenes/mint_scene_etat_civil.dart';
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

  group('MintSceneEtatCivil', () {
    testWidgets('renders FR prompt + 5 options incl. Divorcé', (tester) async {
      await tester.pumpWidget(
        _wrap(child: MintSceneEtatCivil(onAnswered: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(
          find.text('Quelle est ta situation familiale ?'), findsOneWidget);
      for (final k in const [
        'onboarding-civil-celibataire',
        'onboarding-civil-marie',
        'onboarding-civil-concubinage',
        'onboarding-civil-divorce',
        'onboarding-civil-veuf',
      ]) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
    });

    testWidgets('tap Divorcé writes q_civil_status=divorce', (tester) async {
      final provider = CoachProfileProvider();
      String? received;
      await tester.pumpWidget(
        _wrap(
          provider: provider,
          child: MintSceneEtatCivil(onAnswered: (v) => received = v),
        ),
      );
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('onboarding-civil-divorce')));
      await _settle(tester);

      expect(received, 'divorce');
      expect(provider.profile?.etatCivil, CoachCivilStatus.divorce);
    });

    testWidgets('tap Marié → CoachCivilStatus.marie', (tester) async {
      final provider = CoachProfileProvider();
      await tester.pumpWidget(
        _wrap(
          provider: provider,
          child: MintSceneEtatCivil(onAnswered: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('onboarding-civil-marie')));
      await _settle(tester);

      expect(provider.profile?.etatCivil, CoachCivilStatus.marie);
    });

    testWidgets('tap Célibataire → CoachCivilStatus.celibataire',
        (tester) async {
      final provider = CoachProfileProvider();
      await tester.pumpWidget(
        _wrap(
          provider: provider,
          child: MintSceneEtatCivil(onAnswered: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('onboarding-civil-celibataire')));
      await _settle(tester);

      expect(provider.profile?.etatCivil, CoachCivilStatus.celibataire);
    });
  });
}
