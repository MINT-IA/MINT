import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/widgets/coach/lpp_rescue_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/lpp_deep/libre_passage_screen.dart';
import 'package:mint_mobile/screens/independant_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final options = [
    const LppTransferOption(
      label: 'Nouveau employeur',
      emoji: '🏢',
      description: 'Transfert direct au LPP du nouvel employeur.',
      fiveYearGain: 0,
    ),
    const LppTransferOption(
      label: 'Libre passage (recommandé)',
      emoji: '🏦',
      description: '2 comptes pour optimiser la fiscalité au retrait.',
      fiveYearGain: 9000,
      recommended: true,
      legalRef: 'LFLP art. 3-4',
    ),
    const LppTransferOption(
      label: 'Institution supplétive',
      emoji: '⚠️',
      description: 'Taux technique bas, frais élevés.',
      fiveYearGain: -9000,
    ),
  ];

  Widget buildWidget({int daysElapsed = 5}) => MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: LppRescueWidget(
              lppBalance: 185000,
              options: options,
              daysElapsed: daysElapsed,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('sauvetage'), findsOneWidget);
  });

  testWidgets('shows days remaining', (tester) async {
    await tester.pumpWidget(buildWidget(daysElapsed: 5));
    expect(find.textContaining('25 jours'), findsOneWidget);
  });

  testWidgets('shows LPP balance', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("185'000"), findsWidgets);
  });

  testWidgets('shows recommended badge', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Recommandé'), findsOneWidget);
  });

  testWidgets('shows all 3 options', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Option 1'), findsOneWidget);
    expect(find.textContaining('Option 2'), findsOneWidget);
    expect(find.textContaining('Option 3'), findsOneWidget);
  });

  testWidgets('shows chiffre-choc about institution supplétive', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('supplétive'), findsWidgets);
  });

  testWidgets('shows disclaimer with sfbvg', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('sfbvg'), findsOneWidget);
  });

  testWidgets('disclaimer cites OLP art. 10, not the erroneous OPP2 art. 10',
      (tester) async {
    // OPP2 art. 10 = employer information duty (BVV2), unrelated to libre
    // passage. The forms of maintaining prévoyance (police / compte) are
    // founded on OLP art. 10. The disclaimer must carry the corrected base.
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('OLP art. 10'), findsOneWidget);
    expect(find.textContaining('OPP2'), findsNothing);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('sauvetage LPP', caseSensitive: false)), findsOneWidget);
  });

  // ── 320pt (iPhone SE) : contrat responsive du widget partagé ───────────────
  // Le LppRescueWidget est rendu HORS SafeModeGate par libre_passage_screen ET
  // independant_screen. Ses en-têtes (_buildHeader badge « Il te reste X jours »
  // + _buildBalanceChip « Ton avoir LPP : CHF X ») portaient des Row sans
  // Flexible/Expanded -> overflow horizontal à 320pt (démasqué par le sweep
  // #1189, isolé hors périmètre car le widget portait des chaînes FR en dur).
  // Ce contrat pompe les DEUX surfaces porteuses à 320pt et exige qu'AUCUN
  // overflow ne provienne du widget partagé. Réutilise le harnais de
  // sweep320_safemode_deep_test.dart (profil partiel, gate ouvert, scroll pour
  // forcer le paint des Row profondes).
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

  Widget wrapScreen(Widget screen) {
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

  void setSe(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> expectRescueClean(WidgetTester tester, Widget screen) async {
    setSe(tester);
    // On stringifie DANS le handler (arbre encore vivant) : la localisation du
    // « creator » (lpp_rescue_widget.dart) exige visitAncestorElements, qui lève
    // sur un Element défunt si on toString après le teardown. On isole ainsi
    // l'overflow du widget PARTAGÉ des overflows étrangers éventuels de l'écran.
    final errorTexts = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      String text;
      try {
        text = details.toString();
      } catch (_) {
        text = details.exceptionAsString();
      }
      errorTexts.add(text);
    };

    await tester.pumpWidget(wrapScreen(screen));
    await tester.pump(const Duration(milliseconds: 500));
    await scrollThrough(tester);

    FlutterError.onError = previous;

    final rescue =
        errorTexts.where((t) => t.contains('lpp_rescue_widget')).toList();
    expect(rescue, isEmpty,
        reason: 'Le LppRescueWidget partagé doit être 320pt-clean. Overflows : '
            '$rescue');
  }

  testWidgets('libre_passage 320pt : LppRescueWidget partagé sans overflow',
      (tester) async {
    await expectRescueClean(tester, const LibrePassageScreen());
  });

  testWidgets('independant 320pt : LppRescueWidget partagé sans overflow',
      (tester) async {
    await expectRescueClean(tester, const IndependantScreen());
  });
}
