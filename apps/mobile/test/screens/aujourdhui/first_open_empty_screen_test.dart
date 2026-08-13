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

  Widget harness() => MultiProvider(
        providers: [
          ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => _EmptyTwinProvider(),
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
}
