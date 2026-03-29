import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/main_tabs/dossier_tab.dart';

// ────────────────────────────────────────────────────────────
//  DOSSIER TAB — Widget Tests
// ────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  CoachProfileProvider buildProfileProvider({
    String firstName = 'Julien',
    int birthYear = 1977,
    String canton = 'VS',
    double salaire = 9078,
    String civilStatus = 'marie',
    String? conjointFirstName,
  }) {
    final provider = CoachProfileProvider();
    final answers = <String, dynamic>{
      'q_firstname': firstName,
      'q_birth_year': birthYear,
      'q_canton': canton,
      'q_net_income_period_chf': salaire,
      'q_civil_status': civilStatus,
      'q_goal': 'retraite',
    };
    if (conjointFirstName != null) {
      answers['q_partner_firstname'] = conjointFirstName;
      answers['q_partner_birth_year'] = 1982;
      answers['q_partner_net_income_chf'] = 4800;
    }
    provider.updateFromAnswers(answers);
    return provider;
  }

  Widget buildDossierTab({CoachProfileProvider? coachProvider}) {
    return ChangeNotifierProvider<CoachProfileProvider>(
      create: (_) => coachProvider ?? CoachProfileProvider(),
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(body: DossierTab()),
      ),
    );
  }

  group('DossierTab — empty state', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(DossierTab), findsOneWidget);
    });

    testWidgets('shows tab title in app bar', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('shows settings icon', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('shows profile row', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });

    testWidgets('shows documents row', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });

    testWidgets('shows bilan financier row', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.pie_chart_outline), findsOneWidget);
    });

    testWidgets('does not show couple row when no profile', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.people_outline), findsNothing);
    });
  });

  group('DossierTab — with profile', () {
    testWidgets('shows user first name in profile row', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final provider = buildProfileProvider(firstName: 'Julien');
      await tester.pumpWidget(buildDossierTab(coachProvider: provider));
      await tester.pump(const Duration(seconds: 1));
      // firstName appears in the profile row title or in TrajectoryView
      expect(find.textContaining('Julien'), findsWidgets);
    });

    testWidgets('shows couple row for married user with conjoint',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final provider = buildProfileProvider(
        civilStatus: 'marie',
        conjointFirstName: 'Lauren',
      );
      await tester.pumpWidget(buildDossierTab(coachProvider: provider));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
    });

    testWidgets('does not show couple row for celibataire', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final provider = buildProfileProvider(civilStatus: 'celibataire');
      await tester.pumpWidget(buildDossierTab(coachProvider: provider));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.people_outline), findsNothing);
    });

    testWidgets('shows chevron right on rows', (tester) async {
      await tester.pumpWidget(buildDossierTab());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
    });
  });
}
