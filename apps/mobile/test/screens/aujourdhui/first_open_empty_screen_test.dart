// Bascule 4 — beat b4_empty_today, oracle d'écran : aucune carte
// d'événement de vie ne rend dans le sous-arbre de l'état vide tant
// qu'aucun fait canonique n'existe.
//
// L'axe UX l'a identifié comme piège n°2 : afficher 3a ou logement avant
// tout fait donne l'impression d'un catalogue et suggère une
// connaissance que MINT n'a pas.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_civil_status_fact.dart';
import 'package:mint_mobile/models/mint_next_domicile_fact.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/timeline_provider.dart';
import 'package:mint_mobile/screens/aujourdhui/aujourdhui_screen.dart';
import 'package:mint_mobile/services/preview_shell_policy.dart';
import 'package:mint_mobile/widgets/aujourdhui/first_open_empty_state.dart';
import 'package:mint_mobile/widgets/aujourdhui/mint_next_3a_handoff_card.dart';
import 'package:mint_mobile/widgets/aujourdhui/mint_next_housing_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Jumeau VIERGE : aucun fait canonique, aucun profil.
class _EmptyTwinProvider extends CoachProfileProvider {
  @override
  bool get isLoaded => true;
}

/// Jumeau PARTIEL : un seul fait canonique renseigné (l'état civil).
/// L'état vide ne doit PAS s'afficher — sinon on annonce « MINT ne
/// connaît pas encore ta situation » à quelqu'un qui a déjà répondu,
/// en masquant ses cartes (P1 review T2, axe code).
class _PartialTwinProvider extends CoachProfileProvider {
  @override
  bool get isLoaded => true;
  @override
  MintNextCivilStatusFact? get civilStatusFact => MintNextCivilStatusFact(
        status: MintNextCivilStatus.celibataire,
        assertedAt: DateTime.utc(2026, 8, 13),
        source: 'user_declaration',
        schemaVersion: 1,
        needsConfirmation: false,
      );
}

class _EmptyTimeline extends TimelineProvider {
  @override
  bool get isLoading => false;
  @override
  bool get isEmpty => true;
  @override
  bool get hasNodes => false;
  @override
  bool get hasMore => false;
}

Finder byIdentifier(String identifier) => find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.identifier == identifier,
      description: 'Semantics(identifier: $identifier)',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PreviewShellPolicy.debugOverride =
        const PreviewShellPolicy.forTest(isPreviewShell: true);
  });

  tearDown(() => PreviewShellPolicy.debugOverride = null);

  Widget harness({CoachProfileProvider? provider}) => MultiProvider(
        providers: [
          ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => provider ?? _EmptyTwinProvider(),
          ),
          ChangeNotifierProvider<TimelineProvider>(
            create: (_) => _EmptyTimeline(),
          ),
          ChangeNotifierProvider<FinancialPlanProvider>(
            create: (_) => FinancialPlanProvider(),
          ),
          ChangeNotifierProvider<MintStateProvider>(
            create: (_) => MintStateProvider(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: AujourdhuiScreen(),
        ),
      );

  testWidgets(
      'no life-event card type renders inside the empty subtree while no '
      'canonical fact exists', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // L'état vide éditorial est bien celui qui rend.
    expect(find.byType(FirstOpenEmptyState), findsOneWidget);
    expect(byIdentifier('screen:today.empty'), findsOneWidget);

    // Aucune carte concurrente, par TYPE — pas par libellé.
    expect(find.byType(MintNextHousingCard), findsNothing,
        reason: 'aucune carte logement avant le premier fait');
    expect(find.byType(MintNext3aHandoffCard), findsNothing,
        reason: 'aucune carte 3a avant le premier fait');
    expect(byIdentifier('action:vertical_3a.entry'), findsNothing,
        reason: "aucune entrée verticale avant le premier fait");
  });

  testWidgets(
      'the legacy coach invitation never renders on a first open',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.textContaining('coach'), findsNothing,
        reason: "la promesse ne bascule pas vers un autre canal");
  });

  testWidgets(
      'a twin holding any canonical fact never shows the first-open empty '
      'state', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(provider: _PartialTwinProvider()));
    await tester.pumpAndSettle();

    expect(find.byType(FirstOpenEmptyState), findsNothing,
        reason: "un seul fait suffit à sortir de l'état vierge");
    expect(byIdentifier('screen:today.empty'), findsNothing);
  });

  testWidgets('the empty state survives a 200 percent text scale without '
      'overflow', (tester) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: harness(),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'aucun débordement à 200 % de taille de texte');
    expect(find.byType(FirstOpenEmptyState), findsOneWidget);
  });

  testWidgets(
      'someone who just said they have no Swiss commune is never asked for it '
      'again — the first action becomes their income', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(provider: _NoSwissDomicileTwin()));
    await tester.pumpAndSettle();

    // L'écran d'ouverture reste : une limite déclarée n'apporte aucune
    // matière financière. Mais la question posée change.
    expect(find.byType(FirstOpenEmptyState), findsOneWidget);
    expect(find.text("D'abord, ta commune."), findsNothing,
        reason: 'reposer la question serait la relance que le contrat interdit');
    expect(find.text("D'abord, ce que tu gagnes."), findsOneWidget);
    expect(find.text('Indiquer mon revenu'), findsOneWidget);
  });
}

/// Jumeau ayant déclaré n'avoir aucune commune fiscale suisse.
class _NoSwissDomicileTwin extends CoachProfileProvider {
  @override
  bool get isLoaded => true;
  @override
  MintNextDomicileFact? get domicileFact =>
      MintNextDomicileFact.noSwissTaxDomicile(
        assertedAt: DateTime.utc(2026, 8, 13),
        source: MintNextDomicileFact.userDeclarationSource,
        schemaVersion: 1,
      );
}
