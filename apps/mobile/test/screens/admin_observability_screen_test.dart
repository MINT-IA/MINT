import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/admin_observability_screen.dart';

Widget _build(Widget child) {
  return MaterialApp(home: child);
}

void main() {
  testWidgets('AdminObservabilityScreen renders metrics from loaders',
      (tester) async {
    await tester.pumpWidget(
      _build(
        AdminObservabilityScreen(
          observabilityLoader: ({days = 30}) async => {
            'users_total': 12,
            'users_verified': 8,
            'users_unverified': 4,
            'login_states_locked_now': 1,
            'subscriptions_active_like': 3,
          },
          onboardingQualityLoader: ({days = 30}) async => {
            'quality_score': 74.2,
            'sessions_started': 20,
            'sessions_completed': 11,
            'completion_rate_pct': 55.0,
            'avg_step_duration_seconds': 24.0,
          },
          onboardingCohortsLoader: ({days = 30}) async => {
            'cohorts': [
              {
                'variant': 'control',
                'platform': 'ios',
                'quality_score': 70.0,
                'completion_rate_pct': 52.0,
              },
              {
                'variant': 'challenge',
                'platform': 'android',
                'quality_score': 78.0,
                'completion_rate_pct': 58.0,
              },
            ],
          },
          csvLoader: ({days = 30}) async => 'date,users_registered\n2026-01-01,2',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin Observability'), findsOneWidget);
    expect(find.textContaining('74.2 / 100'), findsOneWidget);
    expect(find.textContaining('control · ios'), findsOneWidget);
    expect(find.textContaining('challenge · android'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Exporter CSV cohortes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Exporter CSV cohortes'), findsOneWidget);
  });
}
