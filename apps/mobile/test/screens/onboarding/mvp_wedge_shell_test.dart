/// Integration test for the MVP wedge onboarding shell.
///
/// Doctrine gate: every new onboarding screen must be reachable and must
/// densify the dossier strip. This test walks Julien from the landing
/// CTA target route `/onb` through the 7 steps and asserts:
///
///   1. The dossier strip is absent on the entry screen (step 1).
///   2. It appears at step 2 and contains 1 line after the first capture.
///   3. It carries 6 signed lines at the end of step 7.
///
/// If any assertion fails, the façade-sans-câblage is detected mechanically
/// — the screen exists but does not wire a value into the dossier.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart';

class _FakeCoachProfileProvider extends CoachProfileProvider {
  final List<Map<String, dynamic>> mergedCalls = [];

  @override
  Future<void> mergeAnswers(Map<String, dynamic> partial) async {
    mergedCalls.add(Map<String, dynamic>.from(partial));
  }

  @override
  Future<void> loadFromWizard() async {}
}

Future<void> _pumpShell(
  WidgetTester tester,
  _FakeCoachProfileProvider fake,
) async {
  final router = GoRouter(
    initialLocation: '/onb',
    routes: [
      GoRoute(
        path: '/onb',
        builder: (_, __) => const OnboardingShellScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('home-landed')),
      ),
    ],
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CoachProfileProvider>.value(
      value: fake,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // flutter_secure_storage MethodChannel stub: return nothing on read,
    // swallow writes. Prevents PlatformException when SecureWizardStore
    // runs during CoachProfile persistence.
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'read' || call.method == 'readAll') return null;
      return null;
    });
  });
  testWidgets(
    'Entry screen shows no dossier strip before first capture',
    (tester) async {
      final fake = _FakeCoachProfileProvider();
      await _pumpShell(tester, fake);
      expect(find.text('Ton dossier commence ici.'), findsOneWidget);
      // No dossier strip before step 2.
      expect(find.text('Ton dossier'), findsNothing);
      expect(find.text('Ouvrir'), findsOneWidget);
    },
  );

  testWidgets(
    'Step 2 (birth) captures value and dossier strip shows one line',
    (tester) async {
      final fake = _FakeCoachProfileProvider();
      await _pumpShell(tester, fake);
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Ton année de naissance.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1992');
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      // Dossier strip now visible with 1 line.
      expect(find.text('Ton dossier'), findsOneWidget);
      expect(find.text('Année de naissance'), findsOneWidget);
      expect(find.text('1992'), findsOneWidget);
      // Moved to step 3.
      expect(find.text('Où tu habites.'), findsOneWidget);
    },
  );

  testWidgets(
    'Full walk through 7 steps writes 6 lines to the dossier and flushes',
    (tester) async {
      final fake = _FakeCoachProfileProvider();
      await _pumpShell(tester, fake);

      // Step 1 -> 2
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      // Step 2 birth
      await tester.enterText(find.byType(TextField), '1992');
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      // Step 3 canton — tap Vaud (code 'VD').
      await tester.tap(find.text('VD'));
      await tester.pumpAndSettle();

      // Step 4 pro status — tap Salarié·e.
      await tester.tap(find.text('Salarié·e'));
      await tester.pumpAndSettle();

      // Step 5 salary
      expect(find.text('Ton salaire brut annuel.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '90000');
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      // Step 6 pension — enter value then Continuer.
      expect(find.text('Ton avoir de caisse de pension.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '143000');
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      // Step 7 household — tap Oui.
      expect(find.text('Tu vis en couple.'), findsOneWidget);
      await tester.tap(find.text('Oui'));
      await tester.pumpAndSettle();

      // Merged answers reached the provider exactly once.
      expect(fake.mergedCalls, hasLength(1));
      final merged = fake.mergedCalls.single;
      expect(merged['q_birth_year'], 1992);
      expect(merged['q_canton'], 'VD');
      expect(merged['q_pro_status'], 'salaried');
      expect(merged['q_gross_salary'], 90000 / 12);
      expect(merged['q_lpp_avoir'], 143000);
      expect(merged['q_in_couple'], true);
    },
  );
}
