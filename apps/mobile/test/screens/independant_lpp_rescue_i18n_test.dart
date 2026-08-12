import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/independant_screen.dart';

/// FR-residuals PR — Unité A.
///
/// `independant_screen` passait au widget partagé `LppRescueWidget` des
/// `LppTransferOption` dont label/description/legalRef étaient CODÉS EN DUR en
/// français (dette documentée par le PR #1190 : « débit du CALLER, pas du
/// widget »). Ces libellés sont désormais tirés de l'ARB 6 langues, comme le
/// fait déjà `libre_passage_screen`.
///
/// Preuve de VRAIE localisation (pas juste « le FR matche ») : en locale `en`,
/// l'option 1 rend son libellé ANGLAIS et le libellé FR est absent. Sur HEAD
/// (chaîne FR en dur) ce test échoue — le rendu resterait français en `en`.
///
/// L'écran porte une dette d'overflow PRÉEXISTANTE hors périmètre (des Row de
/// `_buildProtectionRow` bornées par son propre `maxWidth: 600`), sans rapport
/// avec l'i18n du CALLER LPP. On avale ces exceptions d'overflow (comme le fait
/// lpp_rescue_widget_test pour isoler le widget partagé) et on laisse remonter
/// toute AUTRE erreur.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  Widget host(Locale locale) {
    final provider = CoachProfileProvider()..updateProfile(partial());
    return ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: const IndependantScreen(),
      ),
    );
  }

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Rend l'écran en avalant les overflows préexistants (hors périmètre), en
  /// laissant remonter toute autre exception. Puis fait défiler jusqu'à
  /// [target].
  Future<void> pumpAndReach(WidgetTester tester, Locale locale,
      Finder target) async {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final ex = details.exception;
      final overflow = ex is FlutterError &&
          ex.toString().contains('overflowed');
      if (!overflow) previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(host(locale));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(
      target,
      400,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 80,
    );
  }

  // Le libellé (label) est rendu enveloppé par le widget : « Option 1 : X ».
  // La description est rendue en Text autonome -> cible fiable de find.text.
  testWidgets('option 1 : label + description FR issus de l\'ARB (locale fr)',
      (tester) async {
    tall(tester);
    const descFr =
        'Place ton avoir dans une fondation de libre passage : il continue de fructifier à un rendement correct.';
    await pumpAndReach(tester, const Locale('fr'), find.text(descFr));

    final ctx = tester.element(find.byType(IndependantScreen));
    final l = S.of(ctx)!;
    expect(l.independantLppRescueOption1Description, descFr);
    expect(find.text(descFr), findsOneWidget);
    // Label enveloppé « Option 1 : Fondation de libre passage ».
    expect(find.textContaining(l.independantLppRescueOption1Label), findsWidgets);
    // legalRef option 3 (indépendant : affiliation LPP volontaire, LPP art. 44).
    expect(find.text(l.independantLppRescueOption3LegalRef), findsWidgets);
  });

  testWidgets('locale en : description ANGLAISE rendue, FR absente '
      '(vraie localisation du CALLER)', (tester) async {
    tall(tester);
    const descEn =
        'Park your assets in a vested benefits foundation, with a decent return.';
    await pumpAndReach(tester, const Locale('en'), find.text(descEn));

    final ctx = tester.element(find.byType(IndependantScreen));
    final l = S.of(ctx)!;
    expect(l.independantLppRescueOption1Description, descEn);
    expect(find.text(descEn), findsOneWidget);
    // La description FR ne doit PLUS apparaître en locale en (vraie localisation).
    expect(
      find.text(
          'Place ton avoir dans une fondation de libre passage : il continue de fructifier à un rendement correct.'),
      findsNothing,
    );
  });
}
