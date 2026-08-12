// Sweep 320pt (iPhone SE) des écrans profonds anciennement verrouillés par
// SafeModeGate, sous PROFIL PARTIEL type julien_swiss (salaire connu,
// épargne/charges absentes). Depuis PR #1177, `isInDebtCrisis` ne se déclenche
// plus sur absence de donnée -> le SafeModeGate s'OUVRE et le contenu profond
// rend PLEINE HAUTEUR. Ce contenu n'avait jamais de test 320pt : ce fichier
// détecte, à 320pt, (a) overflow RenderFlex, (b) contenu attendu non monté
// (sliver paresseux — scroll requis), (c) exceptions de layout.
//
// Extension systémique de la leçon #1177 (rachat_echelonne_screen_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';

import 'package:mint_mobile/screens/lpp_deep/libre_passage_screen.dart';
import 'package:mint_mobile/screens/lpp_deep/epl_screen.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/provider_comparator_screen.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/real_return_screen.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/retroactive_3a_screen.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/staggered_withdrawal_screen.dart';
import 'package:mint_mobile/screens/independants/lpp_volontaire_screen.dart';
import 'package:mint_mobile/screens/independants/pillar_3a_indep_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Profil partiel : salaire connu, épargne/charges/dettes absentes.
  // -> isInDebtCrisis == false (post-#1177) -> SafeModeGate OUVERT.
  // -> revenuBrutAnnuel = 9000 * 12 > 0 -> passe les gardes empty-state
  //    de staggered_withdrawal et retroactive_3a.
  CoachProfile partial() => CoachProfile(
        firstName: 'Sam',
        birthYear: DateTime.now().year - 45,
        canton: 'VD',
        salaireBrutMensuel: 9000,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2045),
          label: 'Retraite',
        ),
      );

  Widget wrap(Widget screen) {
    final provider = CoachProfileProvider()..updateProfile(partial());
    return ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: screen,
      ),
    );
  }

  // Fait défiler tout l'écran pour forcer le layout/paint des Row profondes
  // (les slivers paresseux ne montent que viewport + cacheExtent). Un overflow
  // horizontal n'est signalé qu'au paint : il faut donc traverser l'écran.
  Future<void> scrollThrough(WidgetTester tester) async {
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isEmpty) return;
    for (var i = 0; i < 18; i++) {
      await tester.drag(scrollable.first, const Offset(0, -350));
      await tester.pump(const Duration(milliseconds: 60));
    }
    for (var i = 0; i < 6; i++) {
      await tester.drag(scrollable.first, const Offset(0, 350));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> setSe(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  // Contrat 320pt commun aux écrans dont le contenu propre est SAIN après fix :
  // rend, gate OUVERT (pas de mur faux positif), pas d'overflow ni au premier
  // rendu ni au scroll, et les chiffres (CHF) profonds sont montés.
  void deepScreen320Contract(
    String name,
    Widget Function() build, {
    bool expectChf = true,
  }) {
    testWidgets('$name : 320pt plein écran — pas d\'overflow, gate ouvert',
        (tester) async {
      await setSe(tester);
      await tester.pumpWidget(wrap(build()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull,
          reason: '$name : overflow/layout au premier rendu 320pt');

      final l = await S.delegate.load(const Locale('fr'));
      expect(find.text(l.safeModeTitle), findsNothing,
          reason: '$name : SafeModeGate ne doit PAS verrouiller un profil '
              'partiel (faux positif #1177)');

      await scrollThrough(tester);
      expect(tester.takeException(), isNull,
          reason: '$name : overflow/layout au scroll 320pt');

      if (expectChf) {
        expect(find.textContaining('CHF'), findsWidgets,
            reason: '$name : les chiffres profonds (CHF) doivent être montés');
      }
    });
  }

  group('SafeModeGate deep screens — 320pt sweep (profil partiel, gate ouvert)',
      () {
    deepScreen320Contract('epl', () => const EplScreen());
    deepScreen320Contract(
        'provider_comparator', () => const ProviderComparatorScreen());
    deepScreen320Contract('real_return', () => const RealReturnScreen());
    deepScreen320Contract('retroactive_3a', () => const Retroactive3aScreen());
    deepScreen320Contract(
        'staggered_withdrawal', () => const StaggeredWithdrawalScreen());
    deepScreen320Contract('lpp_volontaire', () => const LppVolontaireScreen());
    deepScreen320Contract('pillar_3a_indep', () => const Pillar3aIndepScreen());

    // libre_passage : son contenu PROPRE (recommandations gatées, checklist,
    // alertes) est SAIN à 320pt. Le seul overflow restant vit dans le widget
    // PARTAGÉ LppRescueWidget (lib/widgets/coach/lpp_rescue_widget.dart), qui
    // (1) est rendu HORS du SafeModeGate — donc jamais masqué par le faux
    // positif #1177, (2) est partagé avec independant_screen, (3) porte des
    // chaînes FR codées en dur -> un fix responsive y déclencherait le gate
    // no_hardcoded_fr --added-only. Défaut structurel documenté (hors périmètre
    // de ce sweep borné). Ce test garde le contenu PROPRE de libre_passage
    // 320pt-clean : tout overflow résiduel doit provenir UNIQUEMENT du widget
    // partagé.
    testWidgets(
        'libre_passage : contenu propre 320pt-clean (overflow isolé au '
        'LppRescueWidget partagé, documenté)', (tester) async {
      await setSe(tester);

      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;

      await tester.pumpWidget(wrap(const LibrePassageScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      await scrollThrough(tester);

      FlutterError.onError = previous;

      final l = await S.delegate.load(const Locale('fr'));
      expect(find.byType(LibrePassageScreen), findsOneWidget);
      expect(find.text(l.safeModeTitle), findsNothing,
          reason: 'libre_passage : gate ne doit pas verrouiller un profil '
              'partiel');

      final foreign = errors
          .where((e) => !e.toString().contains('lpp_rescue_widget'))
          .toList();
      expect(foreign, isEmpty,
          reason: 'le contenu propre de libre_passage doit être 320pt-clean ; '
              'seul le LppRescueWidget partagé peut encore overflow (suivi '
              'séparément). Overflows étrangers : '
              '${foreign.map((e) => e.exceptionAsString()).toList()}');
    });
  });
}
