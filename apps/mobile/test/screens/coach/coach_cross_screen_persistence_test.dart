import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/screens/coach/coach_agir_screen.dart';
import 'package:mint_mobile/screens/coach/coach_dashboard_screen.dart';

void main() {
  CoachProfileProvider _buildCoachProvider() {
    final provider = CoachProfileProvider();
    provider.updateFromAnswers({
      'q_firstname': 'Julien',
      'q_birth_year': 1977,
      'q_canton': 'VS',
      'q_net_income_period_chf': 9080,
      'q_civil_status': 'marie',
      'q_goal': 'retraite',
    });
    return provider;
  }

  Widget _buildDashboard() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => _buildCoachProvider()),
        ChangeNotifierProvider(create: (_) => ByokProvider()),
        ChangeNotifierProvider(create: (_) => UserActivityProvider()),
      ],
      child: const MaterialApp(home: CoachDashboardScreen()),
    );
  }

  Widget _buildAgir() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => _buildCoachProvider()),
        ChangeNotifierProvider(create: (_) => ByokProvider()),
        ChangeNotifierProvider(create: (_) => UserActivityProvider()),
      ],
      child: const MaterialApp(home: CoachAgirScreen()),
    );
  }

  testWidgets(
      'persists concise narrative mode and score reason across Dashboard -> Agir -> Dashboard after restart',
      (tester) async {
    // Use a very tall viewport so score attribution (below-fold) is rendered.
    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'coach_narrative_mode_v1': 'concise',
      'last_fitness_score_reason_v1':
          'Hausse principale: versements confirmes. Deuxieme phrase a masquer.',
      'last_fitness_score_delta_v1': 2,
    });

    // ── Dashboard #1 ──
    await tester.pumpWidget(_buildDashboard());
    await tester.pump(const Duration(seconds: 2));

    // Dashboard starts in compact mode — expand to see score attribution
    final expandButton1 =
        find.textContaining('Afficher le dashboard complet');
    if (expandButton1.evaluate().isNotEmpty) {
      await tester.ensureVisible(expandButton1);
      await tester.tap(expandButton1);
      await tester.pump(const Duration(seconds: 1));
    }

    expect(
      find.textContaining('Hausse principale: versements confirmes',
          skipOffstage: false),
      findsWidgets,
    );
    expect(
      find.textContaining('Deuxieme phrase a masquer.', skipOffstage: false),
      findsNothing,
    );

    // Simulate app restart / cross-screen navigation reset.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    // ── Agir (score reason visible without compact toggle) ──
    await tester.pumpWidget(_buildAgir());
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.textContaining('Hausse principale: versements confirmes',
          skipOffstage: false),
      findsWidgets,
    );
    expect(
      find.textContaining('Deuxieme phrase a masquer.', skipOffstage: false),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    // ── Dashboard #2 ──
    await tester.pumpWidget(_buildDashboard());
    await tester.pump(const Duration(seconds: 2));

    // Expand compact mode again for the second Dashboard instance
    final expandButton2 =
        find.textContaining('Afficher le dashboard complet');
    if (expandButton2.evaluate().isNotEmpty) {
      await tester.ensureVisible(expandButton2);
      await tester.tap(expandButton2);
      await tester.pump(const Duration(seconds: 1));
    }

    expect(
      find.textContaining('Hausse principale: versements confirmes',
          skipOffstage: false),
      findsWidgets,
    );
    expect(
      find.textContaining('Deuxieme phrase a masquer.', skipOffstage: false),
      findsNothing,
    );
  });
}
