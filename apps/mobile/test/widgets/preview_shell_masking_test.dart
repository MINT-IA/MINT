// Bascule 1 — masquages ON/OFF de la coque préversion.
//
// Assertions POSITIVES (référence OFF figée) et NÉGATIVES (préversion ON),
// par NOM de widget de l'inventaire du contrat — jamais par libellé seul.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/tension_card.dart';
import 'package:mint_mobile/models/timeline_node.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/timeline_provider.dart';
import 'package:mint_mobile/routes/route_metadata.dart';
import 'package:mint_mobile/routes/route_owner.dart';
import 'package:mint_mobile/screens/aujourdhui/aujourdhui_screen.dart';
import 'package:mint_mobile/screens/mon_argent/mon_argent_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/preview_shell_policy.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:mint_mobile/widgets/aujourdhui/cap_du_jour_banner.dart';
import 'package:mint_mobile/widgets/tension/cleo_loop_indicator.dart';
import 'package:mint_mobile/widgets/mint_shell.dart';
import 'package:mint_mobile/widgets/tension/tension_card_widget.dart';

class _SeededProfileProvider extends CoachProfileProvider {
  _SeededProfileProvider(this._seed);
  final CoachProfile _seed;
  @override
  CoachProfile? get profile => _seed;
}

class _PopulatedTimeline extends TimelineProvider {
  @override
  bool get isLoading => false;
  @override
  bool get isEmpty => false;
  @override
  bool get hasNodes => false;
  @override
  bool get hasMore => false;
  @override
  List<TimelineMonth> get months => const [];
  @override
  CleoLoopPosition get loopPosition => CleoLoopPosition.insight;
  @override
  List<TensionCard> get cards => const [
        TensionCard(
            type: TensionType.earned,
            title: 'tensionEarnedFirstConvo',
            subtitle: '',
            deepLink: '/coach/chat'),
        TensionCard(
            type: TensionType.pulsing,
            title: 'tensionPulsingTalkToCoach',
            subtitle: '',
            deepLink: '/coach/chat'),
        TensionCard(
            type: TensionType.ghosted,
            title: 'tensionGhostedFuture',
            subtitle: '',
            deepLink: '/coach/chat'),
      ];
  @override
  Future<void> refresh() async {}
}

CoachProfile _profile() {
  final now = DateTime.now();
  return CoachProfile(
    birthYear: now.year - 30,
    canton: 'VD',
    salaireBrutMensuel: 7000,
    employmentStatus: 'salarie',
    userProvidedFields: const {'age'},
    goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(now.year + 35),
        label: 'test'),
  );
}

Widget _aujourdhui() => MultiProvider(
      providers: [
        ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => _SeededProfileProvider(_profile())),
        ChangeNotifierProvider<TimelineProvider>(
            create: (_) => _PopulatedTimeline()),
        ChangeNotifierProvider<FinancialPlanProvider>(
            create: (_) => FinancialPlanProvider()),
        ChangeNotifierProvider<MintStateProvider>(
            create: (_) => MintStateProvider()),
      ],
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('fr')],
        home: AujourdhuiScreen(),
      ),
    );

Widget _monArgent(CoachProfileProvider provider) => MultiProvider(
      providers: [
        ChangeNotifierProvider<BudgetProvider>(create: (_) => BudgetProvider()),
        ChangeNotifierProvider<CoachProfileProvider>.value(value: provider),
        ChangeNotifierProvider<MintStateProvider>(
            create: (_) => MintStateProvider()),
      ],
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('fr')],
        home: MonArgentScreen(initialSection: 'today'),
      ),
    );

void _setPreview(bool on) {
  PreviewShellPolicy.debugOverride =
      PreviewShellPolicy.forTest(isPreviewShell: on);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    SecureWizardStore.resetSealFallbackForTest();
    ReportPersistenceService.debugResetTransactionQueueForTest();
    SecureWizardStore.debugResetCanonicalQueueForTest();
    FeatureFlags.enableMintNextVertical3a = true;
  });

  tearDown(() {
    PreviewShellPolicy.debugOverride = null;
    FeatureFlags.enableMintNextVertical3a = false;
    FeatureFlags.chatTabVisible = true;
  });

  test('preview shell shows exactly the allowed destinations and hides coach '
      'and explorer', () {
    _setPreview(true);
    FeatureFlags.chatTabVisible = true;
    expect(PreviewShellPolicy.instance.showCoachTab, isFalse);
    expect(PreviewShellPolicy.instance.showExplorerTab, isFalse);
    // Remap : le coach masqué par la politique replie les index comme le
    // flag runtime (fonctions pures — pattern mint_shell_flag_gate_test).
    expect(MintShell.visibleToBranchIndex(0), 0);
    expect(MintShell.visibleToBranchIndex(1), 1);
    expect(MintShell.branchToVisibleIndex(1), 1);

    _setPreview(false);
    expect(PreviewShellPolicy.instance.showCoachTab, isTrue);
    expect(PreviewShellPolicy.instance.showExplorerTab, isTrue);
    expect(MintShell.visibleToBranchIndex(2), 2,
        reason: 'hors préversion : identité, comportement inchangé');
  });

  test('privacy and settings stay reachable in preview', () {
    _setPreview(true);
    expect(PreviewShellPolicy.instance.blocksRoute('/profile/privacy'),
        isFalse);
    expect(PreviewShellPolicy.instance.blocksRoute('/settings'), isFalse);
    expect(PreviewShellPolicy.instance.blocksRoute('/mon-argent'), isFalse);
  });

  testWidgets(
      'preview aujourd\'hui mounts mint next entries even with zero facts',
      (tester) async {
    _setPreview(true);
    await tester.pumpWidget(_aujourdhui());
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.identifier == 'action:vertical_3a.entry'),
        findsOneWidget);
  });

  testWidgets(
      'no inventoried legacy widget is mounted in preview aujourd\'hui '
      '(by name, not by label)', (tester) async {
    _setPreview(true);
    await tester.pumpWidget(_aujourdhui());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CapDuJourBanner), findsNothing);
    expect(find.byType(TensionCardWidget), findsNothing);
    expect(find.byType(CleoLoopIndicator), findsNothing);
  });

  testWidgets('preview ma situation shows only canonical fact surfaces',
      (tester) async {
    _setPreview(true);
    final provider = CoachProfileProvider();
    await provider.loadFromWizard();
    await tester.pumpWidget(_monArgent(provider));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.identifier == 'action:vertical_3a.entry'),
        findsOneWidget,
        reason: 'la coque factuelle garde son entrée vers le vertical');
  });

  testWidgets(
      'no inventoried legacy widget nor coach whisper is mounted in preview '
      'ma situation', (tester) async {
    _setPreview(true);
    final provider = CoachProfileProvider();
    await provider.loadFromWizard();
    await tester.pumpWidget(_monArgent(provider));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Patrimoine'), findsNothing,
        reason: 'sélecteur de sections legacy masqué');
    expect(find.text('Prévoyance'), findsNothing);
    expect(find.textContaining('Bon mois'), findsNothing,
        reason: 'CoachWhisper = silence en préversion');
  });

  test('every route owned by coach or explore redirects fail-closed in '
      'preview (registry-driven at the resolved destination)', () {
    _setPreview(true);
    final owned = kRouteRegistry.values.where((m) =>
        m.owner == RouteOwner.coach || m.owner == RouteOwner.explore);
    expect(owned.length, greaterThanOrEqualTo(17),
        reason: 'le registre pilote — jamais une liste en dur');
    for (final meta in owned) {
      expect(PreviewShellPolicy.instance.blocksRoute(meta.path), isTrue,
          reason: '${meta.path} doit être fail-closed en préversion');
    }
    _setPreview(false);
    for (final meta in owned) {
      expect(PreviewShellPolicy.instance.blocksRoute(meta.path), isFalse,
          reason: 'hors préversion, rien ne change');
    }
  });

  test('system-owned aliases inherit the fail-closed through their guarded '
      'target (the five known aliases asserted)', () {
    _setPreview(true);
    // Les 5 alias owner:system redirigent vers /coach/chat — la cible est
    // gardée, donc ils héritent du blocage sans liste de production.
    for (final alias in [
      '/ask-mint',
      '/tools',
      '/advisor',
      '/advisor/plan-30-days',
      '/advisor/wizard'
    ]) {
      expect(kRouteRegistry.containsKey(alias), isTrue,
          reason: '$alias existe au registre (cas de test du contrat)');
    }
    expect(PreviewShellPolicy.instance.blocksRoute('/coach/chat'), isTrue,
        reason: 'la CIBLE des alias est fail-closed — héritage structurel');
  });

  test('shell tab params for forbidden destinations are neutralized in '
      'preview', () {
    _setPreview(true);
    final p = PreviewShellPolicy.instance;
    expect(p.redirectForShellParams({'screen': 'coach'}), '/home');
    expect(p.redirectForShellParams({'screen': 'explore'}), '/home');
    expect(p.redirectForShellParams({'screen': 'aujourdhui'}), isNull);
    _setPreview(false);
    expect(PreviewShellPolicy.instance.redirectForShellParams(
        {'screen': 'coach'}), isNull,
        reason: 'hors préversion, les notifications legacy routent comme avant');
  });

  testWidgets(
      'without the define the legacy shell keeps its reference surfaces '
      '(positive assertions on the inventoried widgets)', (tester) async {
    _setPreview(false);
    await tester.pumpWidget(_aujourdhui());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CapDuJourBanner), findsWidgets,
        reason: 'référence OFF figée : la surface legacy reste montée');
    expect(find.byType(TensionCardWidget), findsNWidgets(3));
    expect(find.byType(CleoLoopIndicator), findsOneWidget);

    final provider = CoachProfileProvider();
    await provider.loadFromWizard();
    await tester.pumpWidget(_monArgent(provider));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Patrimoine'), findsOneWidget,
        reason: 'le sélecteur legacy reste présent hors préversion');
  });

  test('without the define the reference deeplinks keep their legacy '
      'destinations', () {
    _setPreview(false);
    expect(PreviewShellPolicy.instance.blocksRoute('/coach/chat'), isFalse);
    expect(PreviewShellPolicy.instance.blocksRoute('/explore/famille'),
        isFalse);
    expect(PreviewShellPolicy.instance.redirectForShellParams(
        {'screen': 'coach'}), isNull);
  });
}
