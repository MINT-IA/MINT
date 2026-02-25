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
  CoachProfileProvider buildCoachProvider() {
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

  Widget buildDashboard() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => buildCoachProvider()),
        ChangeNotifierProvider(create: (_) => ByokProvider()),
        ChangeNotifierProvider(create: (_) => UserActivityProvider()),
      ],
      child: const MaterialApp(home: CoachDashboardScreen()),
    );
  }

  Widget buildAgir() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => buildCoachProvider()),
        ChangeNotifierProvider(create: (_) => UserActivityProvider()),
      ],
      child: const MaterialApp(home: CoachAgirScreen()),
    );
  }

  testWidgets(
      'persists concise narrative mode and score reason across Dashboard -> Agir -> Dashboard after restart',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'coach_narrative_mode_v1': 'concise',
      'last_fitness_score_reason_v1':
          'Hausse principale: versements confirmes. Deuxieme phrase a masquer.',
      'last_fitness_score_delta_v1': 2,
    });

    await tester.pumpWidget(buildDashboard());
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.textContaining('Hausse principale: versements confirmes'),
      findsWidgets,
    );
    expect(find.textContaining('Deuxieme phrase a masquer.'), findsNothing);

    // Simulate app restart / cross-screen navigation reset.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(buildAgir());
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.textContaining('Hausse principale: versements confirmes'),
      findsWidgets,
    );
    expect(find.textContaining('Deuxieme phrase a masquer.'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(buildDashboard());
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.textContaining('Hausse principale: versements confirmes'),
      findsWidgets,
    );
    expect(find.textContaining('Deuxieme phrase a masquer.'), findsNothing);
  });
}
