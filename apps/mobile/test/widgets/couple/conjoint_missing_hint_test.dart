// ────────────────────────────────────────────────────────────
//  CONJOINT MISSING HINT — honnêteté mono-revenu (volet C -mla)
//
//  beads MINT_nosync-mla (audit T05-F04 requalifié) : couple déclaré sans
//  profil financier du conjoint -> revenuBrutAnnuelCouple retombe en
//  silence sur le revenu solo (getter P2-19 « Consumers should show a
//  warning ») — AUCUN écran ne consommait isMissingConjointData.
//
//  Verrouille : (1) marié sans conjoint -> hint + CTA visibles ;
//  (2) conjoint hydraté -> rien ; (3) célibataire -> rien ;
//  (4) câblage écrans (source-lock affordability/expat/household).
// ────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/couple/conjoint_missing_hint.dart';
import 'package:mint_mobile/screens/mortgage/affordability_screen.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';

CoachProfile _profile({
  CoachCivilStatus etatCivil = CoachCivilStatus.marie,
  ConjointProfile? conjoint,
}) =>
    CoachProfile(
      firstName: 'Sam',
      birthYear: 1990,
      canton: 'GE',
      salaireBrutMensuel: 8000,
      etatCivil: etatCivil,
      conjoint: conjoint,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2045),
        label: 'Retraite',
      ),
    );

Widget _wrap(CoachProfile profile) {
  final provider = CoachProfileProvider();
  provider.updateProfile(profile);
  return ChangeNotifierProvider<CoachProfileProvider>.value(
    value: provider,
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: ConjointMissingHint()),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('marié sans conjoint -> hint + CTA visibles', (tester) async {
    await tester.pumpWidget(_wrap(_profile()));
    await tester.pump();

    final l10n = await S.delegate.load(const Locale('fr'));
    expect(find.text(l10n.coupleMonoIncomeHint), findsOneWidget,
        reason: 'le calcul mono-revenu doit être annoncé, pas silencieux');
    expect(find.text(l10n.coupleMonoIncomeCta), findsOneWidget);
  });

  testWidgets('conjoint hydraté -> rien', (tester) async {
    await tester.pumpWidget(_wrap(_profile(
      conjoint: const ConjointProfile(salaireBrutMensuel: 6500),
    )));
    await tester.pump();

    final l10n = await S.delegate.load(const Locale('fr'));
    expect(find.text(l10n.coupleMonoIncomeHint), findsNothing,
        reason: 'deux revenus réels -> pas de bandeau');
  });

  testWidgets('célibataire -> rien', (tester) async {
    await tester.pumpWidget(_wrap(_profile(
      etatCivil: CoachCivilStatus.celibataire,
    )));
    await tester.pump();

    final l10n = await S.delegate.load(const Locale('fr'));
    expect(find.text(l10n.coupleMonoIncomeHint), findsNothing);
  });

  testWidgets('concubinage sans conjoint -> hint visible (affordability juste)',
      (tester) async {
    // Le getter isCouple inclut le concubinage : pour affordability c'est
    // EXACT (les banques agrègent le revenu ménage). Le cas expat (imposition
    // séparée) est gaté côté écran — verrou source ci-dessous.
    await tester.pumpWidget(_wrap(_profile(
      etatCivil: CoachCivilStatus.concubinage,
    )));
    await tester.pump();
    final l10n = await S.delegate.load(const Locale('fr'));
    expect(find.text(l10n.coupleMonoIncomeHint), findsOneWidget);
  });

  testWidgets('conjoint PRÉSENT mais sans revenu -> hint visible',
      (tester) async {
    // Review PR #976 : un ConjointProfile sans salaireBrutMensuel contribue
    // 0 au revenu du couple — le calcul est réellement mono-revenu même si
    // l'objet conjoint existe. L'ancien gate (conjoint == null) cachait le
    // bandeau sur ce cas.
    await tester.pumpWidget(_wrap(_profile(
      conjoint: const ConjointProfile(firstName: 'Lau'),
    )));
    await tester.pump();
    final l10n = await S.delegate.load(const Locale('fr'));
    expect(find.text(l10n.coupleMonoIncomeHint), findsOneWidget,
        reason: 'conjoint sans revenu = mono-revenu réel, le dire');
  });

  test('affordability : bandeau gaté sur la provenance du champ revenu', () {
    final src = File('lib/screens/mortgage/affordability_screen.dart')
        .readAsStringSync();
    expect(src.contains('_incomeStillFromProfile()'), isTrue,
        reason: 'review PR #976 : après une saisie manuelle (revenu combiné '
            'entré à la main), le bandeau mentirait — il doit se taire dès '
            'que le champ diverge du ménage profil');
  });

  test('retirement dashboard : hint câblé (projection couple visible)', () {
    final src = File('lib/screens/coach/retirement_dashboard_screen.dart')
        .readAsStringSync();
    expect(src.contains('ConjointMissingHint'), isTrue);
  });

  test('CTA : route existante /coach/chat via go (jamais push, tab-root)', () {
    final src = File('lib/widgets/couple/conjoint_missing_hint.dart')
        .readAsStringSync();
    expect(src.contains("context.go('/coach/chat')"), isTrue,
        reason: "panel : '/coach' nu n'existe pas (errorBuilder) et push "
            'violerait l\'invariant shell — go vers /coach/chat');
    expect(src.contains("context.push('/coach')"), isFalse);
  });

  test('expat : hint gaté MARIÉ uniquement (concubinage = solo correct)', () {
    final src = File('lib/screens/expat_screen.dart').readAsStringSync();
    expect(
        src.contains('if (isMarried && profile.isMissingConjointIncome)'),
        isTrue,
        reason: 'panel : en concubinage l\'imposition est séparée — le '
            'calcul solo est correct, pas de fausse alerte');
  });

  group('comportemental écran — AffordabilityScreen rendu (round 2 #976)', () {
    Widget affordabilityApp(CoachProfile profile) {
      final provider = CoachProfileProvider();
      provider.updateProfile(profile);
      return ChangeNotifierProvider<CoachProfileProvider>.value(
        value: provider,
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: AffordabilityScreen(),
        ),
      );
    }

    testWidgets('marié, conjoint sans revenu -> bandeau rendu dans l\'écran',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(affordabilityApp(_profile(
        conjoint: const ConjointProfile(firstName: 'Lau'),
      )));
      await tester.pump(const Duration(milliseconds: 400));
      final l10n = await S.delegate.load(const Locale('fr'));
      expect(
          find.text(l10n.coupleMonoIncomeHint, skipOffstage: false),
          findsOneWidget,
          reason: 'écran réel : le calcul est mono-revenu, le bandeau doit '
              'être rendu');
    });

    testWidgets(
        'saisie manuelle d\'un revenu divergent -> le bandeau se tait '
        '(provenance)', (tester) async {
      // Review PR #976 round 3 : sans _incomeStillFromProfile, le bandeau
      // continuerait de s'afficher après qu'un revenu combiné a été saisi
      // à la main — il mentirait. On édite le champ revenu via son contrat
      // onChanged (premier MintAmountField de l'écran) et le bandeau doit
      // disparaître.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(affordabilityApp(_profile(
        conjoint: const ConjointProfile(firstName: 'Lau'),
      )));
      await tester.pump(const Duration(milliseconds: 400));
      final l10n = await S.delegate.load(const Locale('fr'));
      expect(find.text(l10n.coupleMonoIncomeHint, skipOffstage: false),
          findsOneWidget);

      final incomeField = tester.widget<MintAmountField>(
          find.byType(MintAmountField, skipOffstage: false).first);
      incomeField.onChanged(150000); // revenu combiné saisi à la main
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(l10n.coupleMonoIncomeHint, skipOffstage: false),
          findsNothing,
          reason: 'le champ diverge du ménage profil : la provenance a '
              'changé, le bandeau doit se taire au lieu de mentir');
    });

    testWidgets('marié, conjoint AVEC revenu -> pas de bandeau',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(affordabilityApp(_profile(
        conjoint: const ConjointProfile(salaireBrutMensuel: 6500),
      )));
      await tester.pump(const Duration(milliseconds: 400));
      final l10n = await S.delegate.load(const Locale('fr'));
      expect(find.text(l10n.coupleMonoIncomeHint, skipOffstage: false),
          findsNothing,
          reason: 'deux revenus réels agrégés -> pas de bandeau');
    });
  });

  test('câblage : les 3 surfaces couple consomment le hint', () {
    for (final f in [
      'lib/screens/mortgage/affordability_screen.dart',
      'lib/screens/expat_screen.dart',
      'lib/screens/household/household_screen.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src.contains('ConjointMissingHint'), isTrue,
          reason: '$f doit afficher la limite mono-revenu (volet C -mla)');
    }
  });
}
