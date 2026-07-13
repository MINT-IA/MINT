import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/expat_screen.dart';
import 'package:mint_mobile/widgets/coach/avs_gap_widget.dart';
import 'package:provider/provider.dart';

class _RecordingCoachProfileProvider extends CoachProfileProvider {
  _RecordingCoachProfileProvider(Map<String, dynamic> answers)
      : _testProfile = CoachProfile.fromWizardAnswers(answers);

  CoachProfile _testProfile;
  int mergeCalls = 0;
  int updateCalls = 0;

  @override
  CoachProfile? get profile => _testProfile;

  @override
  bool get hasProfile => true;

  @override
  Future<void> mergeAnswers(Map<String, dynamic> partial) async {
    mergeCalls += 1;
  }

  @override
  void updateProfile(CoachProfile updated) {
    updateCalls += 1;
  }

  void replaceAnswers(Map<String, dynamic> answers) {
    _testProfile = CoachProfile.fromWizardAnswers(answers);
    notifyListeners();
  }
}

Widget _buildApp(_RecordingCoachProfileProvider provider) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const ExpatScreen()),
      GoRoute(
        path: '/data-block/revenu',
        builder: (_, state) => Scaffold(
          body: Text(
            'birth-year:${state.uri.queryParameters['inputKey']}:'
            '${state.uri.queryParameters['returnUri']}',
          ),
        ),
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

Future<void> _openAvsTab(WidgetTester tester) async {
  await tester.tap(find.text('AVS'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.textScaleFactorTestValue = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  testWidgets('missing age stays partial and routes to the canonical ask',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = _RecordingCoachProfileProvider(const {});
    await tester.pumpWidget(_buildApp(provider));
    await tester.pump();
    await _openAvsTab(tester);

    expect(find.byKey(const Key('expat_avs_missing_age')), findsOneWidget);
    expect(find.byKey(const Key('expat_avs_start_scenario')), findsNothing);
    expect(find.byType(AvsGapWidget), findsNothing);

    await tester.tap(find.byKey(const Key('expat_avs_add_birth_year')));
    await tester.pumpAndSettle();

    expect(find.text('birth-year:q_birth_year:/expatriation'), findsOneWidget);
    expect(provider.mergeCalls, 0);
    expect(provider.updateCalls, 0);
  });

  testWidgets('known age requires explicit opt-in and never writes the ledger',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = _RecordingCoachProfileProvider({
      'q_birth_year': DateTime.now().year - 40,
    });
    await tester.pumpWidget(_buildApp(provider));
    await tester.pump();
    await _openAvsTab(tester);

    expect(find.byKey(const Key('expat_avs_known_age')), findsOneWidget);
    expect(find.byKey(const Key('expat_avs_start_scenario')), findsOneWidget);
    expect(find.byType(AvsGapWidget), findsNothing);

    await tester.tap(find.text('Départ'));
    await tester.pumpAndSettle();
    await _openAvsTab(tester);
    expect(find.byType(AvsGapWidget), findsNothing);

    await tester.tap(find.byKey(const Key('expat_avs_start_scenario')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
        find.byKey(const Key('expat_avs_scenario_disclosure')), findsWidgets);
    expect(find.byKey(const Key('expat_avs_scenario_result')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('expat_avs_gap_scenario')),
      800,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byType(AvsGapWidget), findsOneWidget);
    expect(
      tester.widget<AvsGapWidget>(find.byType(AvsGapWidget)).initialYearsAbroad,
      10,
    );

    provider.replaceAnswers(const {});
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('expat_avs_missing_age')),
      -800,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.byKey(const Key('expat_avs_missing_age')), findsOneWidget);
    expect(find.byKey(const Key('expat_avs_scenario_result')), findsNothing);
    expect(find.byType(AvsGapWidget), findsNothing);
    expect(
        find.byKey(const Key('expat_avs_scenario_disclosure')), findsNothing);
    expect(provider.mergeCalls, 0);
    expect(provider.updateCalls, 0);
  });

  testWidgets('AVS scenario renderer itself fails closed without opt-in',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: AvsGapWidget(
          scenarioStarted: false,
          currentContributionYears: 20,
          currentAge: 40,
        ),
      ),
    ));

    expect(find.byType(Slider), findsNothing);
    expect(find.textContaining('CHF'), findsNothing);
  });
}
