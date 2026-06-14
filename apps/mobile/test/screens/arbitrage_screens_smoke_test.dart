// ────────────────────────────────────────────────────────────
//  ARBITRAGE SCREENS — Smoke Tests
//  Screens: RenteVsCapitalScreen, AllocationAnnuelleScreen,
//           ArbitrageBilanScreen, LocationVsProprieteScreen
//
//  Validates: renders without crash, Scaffold present,
//  key French content visible on first pump.
// ────────────────────────────────────────────────────────────

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';
import 'package:mint_mobile/screens/arbitrage/allocation_annuelle_screen.dart';
import 'package:mint_mobile/screens/arbitrage/arbitrage_bilan_screen.dart';
import 'package:mint_mobile/screens/arbitrage/location_vs_propriete_screen.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';

// ---------------------------------------------------------------------------
//  Shared helper — wraps a screen with Provider + French i18n
// ---------------------------------------------------------------------------
Widget _buildWrapped(Widget screen, {CoachProfile? profile}) {
  return ChangeNotifierProvider<CoachProfileProvider>(
    create: (_) {
      final provider = CoachProfileProvider();
      if (profile != null) {
        provider.updateProfile(profile);
      }
      return provider;
    },
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

CoachProfile _debtPriorityProfile() {
  return CoachProfile(
    birthYear: 1985,
    canton: 'VD',
    salaireBrutMensuel: 8000,
    etatCivil: CoachCivilStatus.celibataire,
    dettes: const DetteProfile(
      creditConsommation: 25000,
      mensualiteCreditConso: 900,
    ),
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 300000,
      totalEpargne3a: 50000,
      rachatMaximum: 100000,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2045),
      label: 'Retraite',
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ═══════════════════════════════════════════════════════════
  //  1. RenteVsCapitalScreen — THE core retirement decision
  // ═══════════════════════════════════════════════════════════

  group('RenteVsCapitalScreen', () {
    Widget buildScreen() => _buildWrapped(const RenteVsCapitalScreen());

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays i18n app bar title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: renteVsCapitalAppBarTitle = "Rente ou capital : ta décision"
      expect(find.textContaining('capital'), findsWidgets);
    });

    testWidgets('displays input mode toggle (Estimer / Certificat)',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: renteVsCapitalEstimateMode = "Estimer pour moi"
      //       renteVsCapitalCertificateMode = "J'ai mon certificat"
      expect(find.textContaining('Estimer'), findsWidgets);
      expect(find.textContaining('certificat'), findsWidgets);
    });

    testWidgets('displays hero intro section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: renteVsCapitalIntro mentions "à la retraite"
      expect(find.textContaining('etraite'), findsWidgets);
    });

    testWidgets('displays option labels Rente, Capital, Mixte', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // Labels appear in the intro explanatory text and in result blocs.
      // i18n: renteVsCapitalRenteLabel = "Rente",
      //       renteVsCapitalCapitalLabel = "Capital",
      //       renteVsCapitalMixteLabel = "Mixte"
      expect(find.textContaining('Rente'), findsWidgets);
      expect(find.textContaining('Capital'), findsWidgets);
      expect(find.textContaining('Mixte'), findsWidgets);
    });

    testWidgets(
        'ILLOG-01: no fiction LPP default — empty fields + explicit empty '
        'state when no profile', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(milliseconds: 600));
      // The removed fiction default ('350000') must NOT render as data.
      expect(find.text('350000'), findsNothing);
      // An explicit empty-state invitation is shown instead.
      final ctx = tester.element(find.byType(RenteVsCapitalScreen));
      expect(find.text(S.of(ctx)!.renteVsCapitalEmptyState), findsOneWidget);
    });

    testWidgets('has age input field', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: renteVsCapitalAge = "Ton âge"
      expect(find.textContaining('ge'), findsWidgets);
    });

    testWidgets(
        'keeps first decision inputs neutral and advanced fields folded',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Ton revenu brut annuel (CHF)'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text('Ton revenu brut annuel (CHF)'), findsOneWidget);
      expect(find.text('Ton salaire brut annuel (CHF)'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Paramètres avancés'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text('Paramètres avancés'), findsOneWidget);
      expect(find.textContaining('Rachat LPP annuel'), findsNothing);
      expect(find.textContaining('Retrait EPL'), findsNothing);
      expect(find.text('Canton'), findsNothing);
      expect(find.text('Marié·e'), findsNothing);

      await tester.ensureVisible(find.text('Paramètres avancés'));
      await tester.tap(find.text('Paramètres avancés'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.textContaining('Rachat LPP annuel'), findsOneWidget);
      expect(find.textContaining('Retrait EPL'), findsOneWidget);
      expect(find.text('Canton'), findsOneWidget);
      expect(find.text('Marié·e'), findsOneWidget);
    });

    test('engine result includes warning disclaimer and legal sources', () {
      final result = ArbitrageEngine.compareRenteVsCapital(
        capitalLppTotal: 350000,
        capitalObligatoire: 245000,
        capitalSurobligatoire: 105000,
        renteAnnuelleProposee: 16660,
        canton: 'VD',
      );

      expect(result.disclaimer, contains('Outil educatif'));
      expect(result.disclaimer, contains('LSFin'));
      expect(result.sources.any((s) => s.contains('LPP art. 14')), isTrue);
      expect(result.sources.any((s) => s.contains('LIFD art. 38')), isTrue);
    });

    testWidgets('renders reachable semantic disclaimer and legal sources',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      addTearDown(tester.view.resetPhysicalSize);

      // ILLOG-01: a result only computes from a usable LPP input (no fiction
      // default), so seed a profile with a real LPP balance.
      await tester.pumpWidget(
        _buildWrapped(const RenteVsCapitalScreen(),
            profile: _debtPriorityProfile()),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      final disclaimerCard =
          find.byKey(const Key('rente_vs_capital_disclaimer_card'));
      await tester.scrollUntilVisible(
        disclaimerCard,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(disclaimerCard, findsOneWidget);
      final semantics = tester.getSemantics(disclaimerCard);
      expect(semantics.identifier, 'rente_vs_capital_disclaimer_card');
      expect(semantics.flagsCollection.isFocused, isNot(Tristate.none));
      expect(semantics.label, contains('LSFin'));
      expect(semantics.label, contains('LPP art. 14'));
      expect(semantics.label, contains('LIFD art. 38'));
      expect(semantics.label, contains('Origine du calcul : moteur mobile L1'));
      expect(semantics.label,
          contains('Version du calcul : mobile-l1-rente-vs-capital-v1'));
    });

    test('warning label is localized in the 6 supported locales', () async {
      final labels = <String, String>{};
      for (final locale in S.supportedLocales) {
        final l10n = await S.delegate.load(locale);
        labels[locale.languageCode] = l10n.renteVsCapitalWarning;
      }

      expect(labels['fr'], 'Avertissement');
      expect(labels['en'], 'Warning');
      expect(labels['de'], 'Hinweis');
      expect(labels['es'], 'Advertencia');
      expect(labels['it'], 'Avvertenza');
      expect(labels['pt'], 'Aviso');
    });

    test('core Row 17 labels are localized outside French', () async {
      final expected = <String, List<String>>{
        'en': [
          'Your age',
          '65 years',
          '/month',
          'Age',
          'At age 65: ',
          'Today',
          'In 20 years',
          'Inheritance',
          'At your death',
          'Nothing',
          'Inflation',
        ],
        'de': [
          'Dein Alter',
          '65 Jahre',
          '/Monat',
          'Alter',
          'Mit 65 Jahren: ',
          'Heute',
          'In 20 Jahren',
          'Vererbung',
          'Bei deinem Tod',
          'Nichts',
          'Inflation',
        ],
        'es': [
          'Tu edad',
          '65 años',
          '/mes',
          'Edad',
          'A los 65 años: ',
          'Hoy',
          'En 20 años',
          'Transmisión',
          'Al fallecer',
          'Nada',
          'Inflación',
        ],
        'it': [
          'La tua età',
          '65 anni',
          '/mese',
          'Età',
          'A 65 anni: ',
          'Oggi',
          'Tra 20 anni',
          'Trasmissione',
          'Alla tua morte',
          'Nulla',
          'Inflazione',
        ],
        'pt': [
          'A tua idade',
          '65 anos',
          '/mês',
          'Idade',
          'Aos 65 anos: ',
          'Hoje',
          'Dentro de 20 anos',
          'Transmissão',
          'No teu falecimento',
          'Nada',
          'Inflação',
        ],
      };

      for (final locale
          in S.supportedLocales.where((l) => l.languageCode != 'fr')) {
        final l10n = await S.delegate.load(locale);
        final actual = [
          l10n.renteVsCapitalAge,
          l10n.renteVsCapitalAgeYears(65),
          l10n.renteVsCapitalPerMonth,
          l10n.renteVsCapitalChartAxisLabel,
          l10n.renteVsCapitalDeltaAtAge(65),
          l10n.renteVsCapitalInflationToday,
          l10n.renteVsCapitalInflationIn20Years,
          l10n.renteVsCapitalTransmissionTitle,
          l10n.renteVsCapitalTransmissionLeftSingle,
          l10n.renteVsCapitalTransmissionLeftValueSingle,
          l10n.renteVsCapitalHypInflation,
        ];

        expect(actual, expected[locale.languageCode]);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  2. AllocationAnnuelleScreen — Compare 3a, LPP, libre
  // ═══════════════════════════════════════════════════════════

  group('AllocationAnnuelleScreen', () {
    Widget buildScreen() => _buildWrapped(const AllocationAnnuelleScreen());

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays i18n app bar title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: allocAnnuelleTitle = "Où placer tes CHF ?"
      expect(find.textContaining('CHF'), findsWidgets);
    });

    testWidgets('displays input section with amount field', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // Default montant = 7000
      expect(find.textContaining('7'), findsWidgets);
    });

    testWidgets('displays taux marginal toggle or slider', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // Taux marginal label visible
      expect(find.textContaining('marginal'), findsWidgets);
    });

    testWidgets('displays results after initial calculation', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      // After initState() -> _recalculate(), result is non-null.
      // Scroll down to reveal the results section.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
      // i18n: allocAnnuelleTrajectoires = "Trajectoires comparées"
      expect(
          find.textContaining('rajectoire', skipOffstage: false), findsWidgets);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  3. ArbitrageBilanScreen — All arbitrages on real data
  // ═══════════════════════════════════════════════════════════

  group('ArbitrageBilanScreen', () {
    Widget buildScreen() => _buildWrapped(const ArbitrageBilanScreen());

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays empty-profile state without crash (no profile)',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // No profile set: shows i18n: arbitrageBilanEmptyProfile
      // The key text "arbitrageBilan" should appear in some form
      expect(find.byType(Icon), findsWidgets);
    });

    testWidgets('shows start CTA when no profile', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: reportCommencer = "Commencer"
      expect(find.textContaining('ommencer'), findsWidgets);
    });

    testWidgets('has at least one Scaffold with body', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.body, isNotNull);
    });

    testWidgets('shows debt protection as a protection card, not a locked item',
        (tester) async {
      await tester.pumpWidget(
        _buildWrapped(
          const ArbitrageBilanScreen(),
          profile: _debtPriorityProfile(),
        ),
      );
      await tester.pump();

      expect(find.text('Priorité au désendettement'), findsOneWidget);
      expect(find.textContaining('Débloque'), findsNothing);
      expect(find.textContaining('Rachat LPP'), findsNothing);
      expect(find.textContaining('Allocation annuelle'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  4. LocationVsProprieteScreen — Rent vs Buy
  // ═══════════════════════════════════════════════════════════

  group('LocationVsProprieteScreen', () {
    Widget buildScreen() => _buildWrapped(const LocationVsProprieteScreen());

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays header title Louer ou acheter', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: locationLouerOuAcheter = "Louer ou acheter ?"
      expect(find.textContaining('acheter'), findsWidgets);
    });

    testWidgets('displays project immobilier section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: locationProjetImmobilier = "Ton projet immobilier"
      expect(find.textContaining('immobilier'), findsWidgets);
    });

    testWidgets('shows compare button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: locationComparer = "Comparer"
      expect(find.textContaining('omparer'), findsWidgets);
    });

    testWidgets('displays hypothesis section with return slider',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: locationHypotheses = "Hypothèses utilisées" — below the fold
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
      expect(
          find.textContaining('ypothèse', skipOffstage: false), findsWidgets);
    });
  });
}
