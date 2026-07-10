import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/cantonal_benchmark_screen.dart';
import 'package:mint_mobile/services/cantonal_benchmark_service.dart';

class RecordingCoachProfileProvider extends CoachProfileProvider {
  final Map<String, dynamic> _answers;
  CoachProfile? _profileOverride;

  RecordingCoachProfileProvider(Map<String, dynamic> initialAnswers)
      : _answers = Map<String, dynamic>.from(initialAnswers) {
    _profileOverride = CoachProfile.fromWizardAnswers(_answers);
  }

  @override
  CoachProfile? get profile => _profileOverride;

  @override
  bool get hasProfile => _profileOverride != null;

  @override
  Future<void> mergeAnswers(Map<String, dynamic> partial) async {
    _answers.addAll(partial);
    _profileOverride = CoachProfile.fromWizardAnswers(_answers);
    notifyListeners();
  }
}

Widget buildScreenWithRouter(Map<String, dynamic> answers) {
  final provider = RecordingCoachProfileProvider(answers);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const CantonalBenchmarkScreen(),
      ),
      GoRoute(
        path: '/data-block/:type',
        builder: (_, state) {
          final type = state.pathParameters['type'];
          final inputKey = state.uri.queryParameters['inputKey'];
          return Scaffold(
            body: Text('data-block:$type:$inputKey'),
          );
        },
      ),
      GoRoute(
        path: '/coach/chat',
        builder: (_, __) => const Scaffold(body: Text('coach')),
      ),
    ],
  );

  return ChangeNotifierProvider<CoachProfileProvider>.value(
    value: provider,
    child: MaterialApp.router(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      '_cantonal_benchmark_opted_in': true,
    });
    CantonalBenchmarkService.isOptedIn = false;
  });

  testWidgets('missing salary routes to the targeted salary collector',
      (tester) async {
    await tester.pumpWidget(buildScreenWithRouter({
      'q_birth_year': DateTime.now().year - 40,
      'q_canton': 'VD',
    }));
    await tester.pumpAndSettle();

    expect(find.text('Données manquantes'), findsOneWidget);
    expect(find.textContaining('Profils similaires'), findsNothing);

    await tester.tap(find.text('Enrichir mon profil'));
    await tester.pumpAndSettle();

    expect(
      find.text('data-block:revenu:q_gross_salary_annual'),
      findsOneWidget,
    );
  });

  testWidgets('missing canton routes to the targeted canton collector',
      (tester) async {
    await tester.pumpWidget(buildScreenWithRouter({
      'q_birth_year': DateTime.now().year - 40,
      'q_gross_salary_annual': 120000,
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enrichir mon profil'));
    await tester.pumpAndSettle();

    expect(find.text('data-block:revenu:q_canton'), findsOneWidget);
  });

  testWidgets('missing birth year routes to the targeted age collector',
      (tester) async {
    await tester.pumpWidget(buildScreenWithRouter({
      'q_canton': 'VD',
      'q_gross_salary_annual': 120000,
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enrichir mon profil'));
    await tester.pumpAndSettle();

    expect(find.text('data-block:revenu:q_birth_year'), findsOneWidget);
  });

  testWidgets('explicit ledger facts unlock the cantonal benchmark',
      (tester) async {
    await tester.pumpWidget(buildScreenWithRouter({
      'q_birth_year': DateTime.now().year - 40,
      'q_canton': 'VD',
      'q_gross_salary_annual': 120000,
    }));
    await tester.pumpAndSettle();

    expect(find.text('Données manquantes'), findsNothing);
    expect(find.textContaining('Profils similaires'), findsWidgets);
    expect(find.text('Revenu brut annuel'), findsWidgets);
    expect(find.text('Épargne mensuelle'), findsNothing);
    expect(find.text('Charges fixes mensuelles'), findsNothing);
    expect(find.text('Patrimoine net estimé'), findsNothing);
  });

  testWidgets('unsupported canton shows the no-data state', (tester) async {
    await tester.pumpWidget(buildScreenWithRouter({
      'q_birth_year': DateTime.now().year - 40,
      'q_canton': 'LU',
      'q_gross_salary_annual': 120000,
    }));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pas de données disponibles'), findsOneWidget);
    expect(find.textContaining('LU'), findsOneWidget);
    expect(find.textContaining('Profils similaires'), findsNothing);
    expect(find.text('Revenu brut annuel'), findsNothing);
  });
}
