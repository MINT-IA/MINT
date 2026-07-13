import 'dart:ui' show SemanticsAction, SemanticsActionEvent, Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/expat_screen.dart';
import 'package:mint_mobile/services/expat_service.dart';
import 'package:mint_mobile/widgets/coach/avs_gap_widget.dart';
import 'package:provider/provider.dart';

class _RecordingCoachProfileProvider extends CoachProfileProvider {
  _RecordingCoachProfileProvider(Map<String, dynamic> answers)
      : _testProfile = CoachProfile.fromWizardAnswers(answers);

  final CoachProfile _testProfile;
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
}

Widget _buildApp(_RecordingCoachProfileProvider provider) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const ExpatScreen()),
      GoRoute(
        path: '/scan/avs-guide',
        builder: (_, __) => const Scaffold(
          body: Text('avs-verification-guide'),
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

Future<void> _selectYearsAbroad(WidgetTester tester, int value) async {
  await tester.tap(find.byKey(const Key('expat_avs_years_picker')));
  await tester.pumpAndSettle();
  tester
      .widget<CupertinoPicker>(find.byType(CupertinoPicker))
      .onSelectedItemChanged
      ?.call(value);
  await tester.tap(find.text('OK'));
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

  testWidgets('exposes stable runtime semantics across the AVS journey',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = _RecordingCoachProfileProvider(const {});
    await tester.pumpWidget(_buildApp(provider));
    await tester.pump();

    expect(find.bySemanticsIdentifier('expat_avs_tab'), findsOneWidget);
    await _openAvsTab(tester);
    expect(
      find.bySemanticsIdentifier('expat_avs_years_picker'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('expat_avs_start_scenario'),
      findsOneWidget,
    );

    await _selectYearsAbroad(tester, 4);
    await tester.tap(find.byKey(const Key('expat_avs_start_scenario')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(
      find.byKey(const Key('expat_avs_scenario_result')),
    );
    await tester.pumpAndSettle();
    for (final identifier in const [
      'expat_avs_scenario_result',
      'expat_avs_gap_unknown',
    ]) {
      expect(
        find.bySemanticsIdentifier(identifier),
        findsOneWidget,
        reason: identifier,
      );
    }

    await tester.scrollUntilVisible(
      find.byKey(const Key('expat_avs_verification_guide_cta')),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsIdentifier('expat_avs_verification_guide_cta'),
      findsOneWidget,
    );
  });

  testWidgets(
      'start semantics stays disabled until an explicit picker confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    try {
      final provider = _RecordingCoachProfileProvider(const {});
      await tester.pumpWidget(_buildApp(provider));
      await tester.pump();
      await _openAvsTab(tester);

      final start = find.bySemanticsIdentifier('expat_avs_start_scenario');
      expect(start, findsOneWidget);
      expect(
        tester.getSemantics(start).flagsCollection.isEnabled,
        Tristate.isFalse,
      );
      await tester.tap(find.byKey(const Key('expat_avs_start_scenario')));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('expat_avs_scenario_result'),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('expat_avs_years_picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(start).flagsCollection.isEnabled,
        Tristate.isTrue,
      );
      final startNode = tester.getSemantics(start);
      expect(
        startNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.tap,
          nodeId: startNode.id,
          viewId: tester.view.viewId,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byKey(const Key('expat_avs_scenario_result')),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
      'unknown years stay partial and cannot synthesize a ten-year fact',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = _RecordingCoachProfileProvider(const {});
    await tester.pumpWidget(_buildApp(provider));
    await tester.pump();
    await _openAvsTab(tester);

    expect(find.byKey(const Key('expat_avs_years_picker')), findsOneWidget);
    expect(find.text('À renseigner'), findsOneWidget);
    expect(find.byKey(const Key('expat_avs_opt_in_gate')), findsOneWidget);
    expect(find.byType(AvsGapWidget), findsNothing);
    expect(find.textContaining('déclarées : 10'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('expat_avs_start_scenario')),
          )
          .onPressed,
      isNull,
    );

    await _selectYearsAbroad(tester, 0);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('expat_avs_start_scenario')),
          )
          .onPressed,
      isNotNull,
    );
    expect(provider.mergeCalls, 0);
    expect(provider.updateCalls, 0);
  });

  testWidgets('missing birth year does not block after explicit year selection',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = _RecordingCoachProfileProvider(const {});
    await tester.pumpWidget(_buildApp(provider));
    await tester.pump();
    await _openAvsTab(tester);
    await _selectYearsAbroad(tester, 4);

    await tester.tap(find.byKey(const Key('expat_avs_start_scenario')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('expat_avs_scenario_result')), findsOneWidget);
    expect(find.byType(AvsGapWidget), findsOneWidget);
    expect(find.byKey(const Key('expat_avs_gap_unknown')), findsOneWidget);
    expect(provider.mergeCalls, 0);
    expect(provider.updateCalls, 0);
  });

  testWidgets(
      'orientation requires explicit opt-in and never writes the ledger',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = _RecordingCoachProfileProvider(const {});
    await tester.pumpWidget(_buildApp(provider));
    await tester.pump();
    await _openAvsTab(tester);

    expect(find.byType(AvsGapWidget), findsNothing);
    await tester.tap(find.text('Départ'));
    await tester.pumpAndSettle();
    await _openAvsTab(tester);
    expect(find.byType(AvsGapWidget), findsNothing);

    await _selectYearsAbroad(tester, 10);
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
      tester
          .widget<AvsGapWidget>(find.byType(AvsGapWidget))
          .assessment!
          .yearsAbroadDeclared,
      10,
    );
    expect(find.byKey(const Key('expat_avs_gap_unknown')), findsOneWidget);
    expect(find.textContaining('Rente estimée'), findsNothing);
    expect(find.textContaining('Perte annuelle'), findsNothing);
    expect(find.text(ExpatService.disclaimer), findsNothing);
    expect(find.textContaining('pas un conseil personnalisé'), findsOneWidget);

    expect(provider.mergeCalls, 0);
    expect(provider.updateCalls, 0);
  });

  testWidgets('AVS verification CTA opens the existing guide route',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = _RecordingCoachProfileProvider(const {});
    await tester.pumpWidget(_buildApp(provider));
    await tester.pump();
    await _openAvsTab(tester);
    await _selectYearsAbroad(tester, 5);
    await tester.tap(find.byKey(const Key('expat_avs_start_scenario')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(
      find.byKey(const Key('expat_avs_verification_guide_cta')),
      500,
      scrollable: find.byType(Scrollable).last,
    );

    await tester.tap(find.byKey(const Key('expat_avs_verification_guide_cta')));
    await tester.pumpAndSettle();

    expect(find.text('avs-verification-guide'), findsOneWidget);
    expect(provider.mergeCalls, 0);
    expect(provider.updateCalls, 0);
  });

  testWidgets('AVS scenario renderer itself fails closed without opt-in',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: AvsGapWidget(
          scenarioStarted: false,
          assessment: null,
          onOpenAvsVerificationGuide: () {},
        ),
      ),
    ));

    expect(find.byType(Slider), findsNothing);
    expect(find.textContaining('CHF'), findsNothing);
  });
}
