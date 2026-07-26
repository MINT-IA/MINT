import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/concubinage_screen.dart';
import 'package:mint_mobile/services/family_service.dart';
import 'package:mint_mobile/widgets/coach/clause_3a_widget.dart';
import 'package:mint_mobile/widgets/coach/survivor_pension_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:mint_mobile/widgets/visualizations/concubinage_decision_matrix.dart';
import 'package:provider/provider.dart';

/// P2 « gate dur » — anti-façade contract for concubinage_screen (the DUAL-PARTY
/// mariage-vs-concubinage comparator).
///
/// No computed « ta situation » figure is shown on a fabricated default. Each
/// result output gates on the facts IT consumes; a fact is CONFIRMED only when
/// it comes from real data — seeded from the user's profile (partner 1 = the
/// USER, or the real `conjoint` for partner 2) OR entered by the user (a non-null
/// value; canton confirmed via the on-screen picker OR a real profile canton).
/// A default is a null « Non renseigné », never an invented 80000/60000/300000.
///
/// Per-output fact manifest:
///   • Fiscal cluster (matrix + mécanique + détail) → revenu1, revenu2, canton
///   • Impôt de succession                       → patrimoine, canton
///   • Hero patrimoine                           → shown only when patrimoine ≠ null
///   • Rente de survivant (Tab2)                 → renteLpp; MARRIED figure is the
///     LPP survivor pension only (renteLpp × 60%) — NO fabricated max-AVS
///   • Clause 3a (Tab2)                          → educational, conditional copy,
///     NO naked balance (no reliable provenance for the 3a balance)
///
/// SurvivorPensionWidget + Clause3aWidget are removed from concubinage (shared
/// widgets that fabricated a max-AVS married figure / a value-only 3a balance).
/// partner 2 income (le concubin) is NEVER seeded from the user's own salary.
///
/// Every assertion is on the RENDERED figure (gate card presence/absence, a
/// specific CHF, a widget) — each goes RED if the gate is removed (i.e. if the
/// screen went back to computing on 80000/60000/300000/'VD'/2500).

// ── Tab1 MintAmountField build order (top → bottom) ──
const _revenu1 = 0;
const _revenu2 = 1;
const _patrimoine = 2;

// ── Gate card titles ──
const _fiscalTitle = 'Comparaison fiscale';
const _inheritanceTitle = 'Impôt de succession';
const _survivorTitle = 'Rente de survivant';

class _FakeProvider extends CoachProfileProvider {
  _FakeProvider(this._injected);
  final CoachProfile? _injected;
  @override
  CoachProfile? get profile => _injected;
}

CoachProfile _profile({
  double salaire = 8000,
  String canton = 'VD',
  Set<String> provided = const {},
  ConjointProfile? conjoint,
  PrevoyanceProfile? prevoyance,
}) {
  return CoachProfile(
    birthYear: 1985,
    canton: canton,
    salaireBrutMensuel: salaire,
    etatCivil: CoachCivilStatus.celibataire,
    userProvidedFields: provided,
    conjoint: conjoint,
    prevoyance: prevoyance ?? const PrevoyanceProfile(),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050),
      label: 'Retraite',
    ),
  );
}

Future<void> _pump(WidgetTester tester, CoachProfileProvider provider) async {
  await tester.binding.setSurfaceSize(const Size(1200, 8000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<CoachProfileProvider>.value(
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
        home: ConcubinageScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

dynamic _state(WidgetTester tester) =>
    tester.state(find.byType(ConcubinageScreen)) as dynamic;

List<MintAmountField> _fields(WidgetTester tester) =>
    tester.widgetList<MintAmountField>(find.byType(MintAmountField)).toList();

Future<void> _setAmount(WidgetTester tester, int index, double v) async {
  _fields(tester)[index].onChanged(v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Confirm the canton by invoking the on-screen picker's onChanged (same driving
/// technique as MintAmountField.onChanged — no fragile overlay tapping).
Future<void> _setCanton(WidgetTester tester, String code) async {
  tester
      .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
      .onChanged!(code);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Switch to the « Protection » tab (Tab2) — TabBarView builds it lazily.
Future<void> _openTab2(WidgetTester tester) async {
  _state(tester).debugTabController.animateTo(1);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Switch to the « Checklist » tab (Tab3).
Future<void> _openTab3(WidgetTester tester) async {
  _state(tester).debugTabController.animateTo(2);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Drive the Tab2 renteLpp slider by its label (robust to whether Tab1 is still
/// in the tree during/after the tab transition).
Future<void> _setRenteLpp(WidgetTester tester, double v) async {
  _fields(tester)
      .firstWhere((f) => f.label == 'Rente LPP mensuelle du partenaire')
      .onChanged(v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

SituationGateCard? _gate(WidgetTester tester, String title) {
  for (final c
      in tester.widgetList<SituationGateCard>(find.byType(SituationGateCard))) {
    if (c.title == title) return c;
  }
  return null;
}

void main() {
  // ══════════════════════════════════════════════════════════════
  //  SCREEN OPEN, NO PROFILE → nothing computed on a fabricated default
  // ══════════════════════════════════════════════════════════════
  group('Screen open — Tab1 (no profile)', () {
    testWidgets('no CHF figure anywhere; fiscal + inheritance gated; no hero',
        (tester) async {
      await _pump(tester, _FakeProvider(null));

      // The two Tab1 outputs are gated.
      expect(_gate(tester, _fiscalTitle), isNotNull);
      expect(_gate(tester, _inheritanceTitle), isNotNull);
      // The fiscal-summary visual (matrix) is not built on invented income.
      expect(find.byType(ConcubinageDecisionMatrix), findsNothing);
      // The hero (patrimoine echo) is hidden until patrimoine is confirmed.
      expect(find.textContaining('CHF'), findsNothing,
          reason: 'no result number computed on 80000/60000/300000/VD');
    });

    testWidgets('state fields are null / unconfirmed on open', (tester) async {
      await _pump(tester, _FakeProvider(null));
      final st = _state(tester);
      expect(st.debugRevenu1, isNull);
      expect(st.debugRevenu2, isNull);
      expect(st.debugPatrimoine, isNull);
      expect(st.debugRenteLpp, isNull);
      expect(st.debugCantonConfirmed, isFalse,
          reason: 'default "VD" in the picker is NOT a confirmed fact');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  FISCAL CLUSTER — gated on revenu1 + revenu2 + canton
  // ══════════════════════════════════════════════════════════════
  group('Fiscal cluster', () {
    testWidgets('both incomes entered but canton untouched → still gated',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _setAmount(tester, _revenu1, 80000);
      await _setAmount(tester, _revenu2, 60000);
      final g = _gate(tester, _fiscalTitle);
      expect(g, isNotNull,
          reason: 'no confirmed canton → the tax barème would be fabricated');
      expect(g!.gate.missing.map((f) => f.key), <String>['canton']);
      expect(find.byType(ConcubinageDecisionMatrix), findsNothing);
    });

    testWidgets('incomes + canton picked → fiscal cluster renders with CHF',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _setAmount(tester, _revenu1, 80000);
      await _setAmount(tester, _revenu2, 60000);
      await _setCanton(tester, 'VD');
      expect(_gate(tester, _fiscalTitle), isNull, reason: 'all 3 facts confirmed');
      expect(find.byType(ConcubinageDecisionMatrix), findsOneWidget);
      expect(find.text('Impôts 2 célibataires'), findsOneWidget);
      expect(find.textContaining('CHF'), findsWidgets,
          reason: 'the fiscal detail figures render once unlocked');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  INHERITANCE — gated on patrimoine + canton ; le TAUX cantonal sur
  //  déverrouillage (le montant en francs est retiré, cf. le groupe
  //  « Succession — taux réel, pas de montant fabriqué » plus bas)
  // ══════════════════════════════════════════════════════════════
  group('Inheritance card', () {
    testWidgets('patrimoine entered but canton untouched → gated on canton',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _setAmount(tester, _patrimoine, 300000);
      final g = _gate(tester, _inheritanceTitle);
      expect(g, isNotNull);
      expect(g!.gate.missing.map((f) => f.key), <String>['canton']);
      // The hero appears (patrimoine confirmed) but the succession rate does not.
      expect(find.textContaining('taux tiers'), findsNothing);
    });

    testWidgets('patrimoine + canton (VD) → le taux tiers 25 % rend',
        (tester) async {
      // Canton seeded from the profile (key + valid); patrimoine typed.
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'VD', provided: {'canton'})),
      );
      await _setAmount(tester, _patrimoine, 300000);
      expect(_gate(tester, _inheritanceTitle), isNull);
      // Déterministe : le taux tiers réel du canton VD (0.25), jamais un 24 %
      // codé en dur ni un montant calculé sur une base invérifiable.
      expect(find.textContaining('~25 %'), findsOneWidget);
      expect(find.text(FamilyService.formatChf(75000)), findsNothing,
          reason: '300000 × 0.25 supposait que 100 % peut aller au partenaire');
      expect(find.text(FamilyService.formatChf(300000)), findsWidgets,
          reason: 'le hero écho du patrimoine saisi reste');
      // Le cadre reste CONDITIONNEL (aucune présomption d'héritage) et énonce
      // la règle qui décide : sans testament rien, avec descendant·e·s la
      // réserve plafonne le legs à la moitié de la succession.
      expect(find.textContaining('Sans testament'), findsWidgets,
          reason: 'the non-heir default is stated, not a presumed inheritance');
      expect(find.textContaining('réserve'), findsWidgets,
          reason: 'la réserve des descendant·e·s plafonne la quotité disponible');
    });

    testWidgets('stale invalidation: editing patrimoine drops the old echo',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'VD', provided: {'canton'})),
      );
      await _setAmount(tester, _patrimoine, 300000);
      expect(find.text(FamilyService.formatChf(300000)), findsWidgets);
      // Re-edit the determinative fact → the prior figure must not survive.
      await _setAmount(tester, _patrimoine, 400000);
      expect(find.text(FamilyService.formatChf(300000)), findsNothing,
          reason: 'a displayed figure never outlives a fact change');
      expect(find.text(FamilyService.formatChf(400000)), findsWidgets);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  SUCCESSION — le TAUX cantonal, jamais un montant calculé sur une
  //  base invérifiable
  //
  //  L'ancienne carte affichait `patrimoine × taux`, ce qui suppose que 100 %
  //  du patrimoine peut aller au·à la partenaire. Depuis la révision du droit
  //  successoral entrée en vigueur le 1.1.2023 : sans testament, un·e concubin·e
  //  n'hérite de RIEN ; avec testament, la réserve des descendant·e·s vaut la
  //  MOITIÉ de la succession (CC art. 470-471), donc la quotité disponible
  //  plafonne à 1/2 en leur présence ; la réserve des parents ayant été
  //  supprimée, sans descendant·e la quotité disponible est de 100 %. De plus un
  //  bien en copropriété n'entre dans la succession que pour la quote-part
  //  du·de la défunt·e : `patrimoine` n'est pas la bonne base.
  //
  //  Le montant en francs est donc indéfendable et il est RETIRÉ. Le TAUX
  //  cantonal, lui, est un fait réel et personnalisé (le canton est un fait
  //  confirmé) : il reste, encadré d'une note de limite de modèle.
  // ══════════════════════════════════════════════════════════════
  group('Succession — taux réel, pas de montant fabriqué', () {
    Future<void> unlock(WidgetTester tester, {String canton = 'VD'}) async {
      await _pump(
        tester,
        _FakeProvider(_profile(canton: canton, provided: {'canton'})),
      );
      await _setAmount(tester, _patrimoine, 300000);
    }

    Set<String> chfTexts(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.contains('CHF'))
        .toSet();

    testWidgets('(a) aucun montant en francs d\'impôt successoral n\'est rendu',
        (tester) async {
      await unlock(tester);
      expect(_gate(tester, _inheritanceTitle), isNull,
          reason: 'patrimoine + canton confirmés → la carte est ouverte');
      // 300000 × 0.25 = 75000 (l'ancien « impôt ») et 225000 (l'ancien « net
      // hérité ») : deux montants calculés sur une hypothèse invérifiable.
      expect(find.text(FamilyService.formatChf(75000)), findsNothing,
          reason: 'patrimoine × taux suppose que 100 % peut aller au partenaire');
      expect(find.text(FamilyService.formatChf(225000)), findsNothing);
      // Le SEUL montant en francs de l'onglet est l'écho du patrimoine SAISI.
      expect(chfTexts(tester), {FamilyService.formatChf(300000)},
          reason: 'aucun franc calculé sur la succession n\'est rendu');
    });

    testWidgets('(b) le taux cantonal et sa note de limite sont rendus',
        (tester) async {
      await unlock(tester); // VD → taux tiers 25 %
      expect(find.textContaining('~25\u00A0%'), findsOneWidget);
      expect(find.textContaining('taux tiers'), findsWidgets);
      // Limite du modèle attachée au taux : barèmes progressifs, franchises,
      // impôt communal → ordre de grandeur, pas le taux qui s'appliquera.
      expect(find.textContaining('ordre de grandeur'), findsWidgets);
      expect(find.textContaining('progressifs'), findsWidgets);
      expect(find.textContaining('franchises'), findsWidgets);
      expect(find.textContaining('communal'), findsWidgets);
      // La règle qui décide vraiment est énoncée.
      expect(find.textContaining('quotité disponible'), findsWidgets);
      expect(find.textContaining('moitié'), findsWidgets,
          reason: 'la réserve des descendant·e·s plafonne le legs à 1/2');
    });

    testWidgets('(b bis) le taux suit le canton confirmé (GE → 24 %)',
        (tester) async {
      await unlock(tester, canton: 'GE');
      expect(find.textContaining('~24\u00A0%'), findsOneWidget);
      expect(find.textContaining('~25\u00A0%'), findsNothing,
          reason: 'le taux est cantonal, jamais un taux par défaut');
    });

    testWidgets('(c) canton non confirmé → carte gatée, aucun taux rendu',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _setAmount(tester, _patrimoine, 300000);
      final g = _gate(tester, _inheritanceTitle);
      expect(g, isNotNull);
      expect(g!.gate.missing.map((f) => f.key), <String>['canton']);
      expect(find.textContaining('taux tiers'), findsNothing);
      expect(find.textContaining('ordre de grandeur'), findsNothing);
    });

    testWidgets('(c bis) patrimoine absent → carte gatée, aucun taux rendu',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'VD', provided: {'canton'})),
      );
      final g = _gate(tester, _inheritanceTitle);
      expect(g, isNotNull);
      expect(g!.gate.missing.map((f) => f.key), <String>['patrimoine']);
      expect(find.textContaining('taux tiers'), findsNothing);
      expect(find.textContaining('ordre de grandeur'), findsNothing);
    });

    testWidgets(
        '(A2) l\'encart pédagogique décrit l\'écart réel entre cantons, '
        'et (A3) impute l\'exonération aux lois fiscales cantonales',
        (tester) async {
      await unlock(tester);
      // A2 : la table du même dépôt va de 0.00 (SZ, OW) à 0.25 — « souvent
      // entre 20 % et 40 % » était faux aux deux bouts.
      expect(find.textContaining('20\u00A0% et 40\u00A0%'), findsNothing);
      // A3 : il n'existe pas d'impôt successoral fédéral ordinaire ;
      // l'exonération du·de la conjoint·e vient des lois fiscales CANTONALES,
      // et elle vaut dans TOUS les cantons.
      expect(find.textContaining('lois fiscales cantonales'), findsWidgets);
      expect(find.textContaining('26 cantons'), findsWidgets);
    });

    testWidgets('(A3) la matrice ne cite plus CC 462 pour une exonération FISCALE',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _setAmount(tester, _revenu1, 80000);
      await _setAmount(tester, _revenu2, 60000);
      await _setCanton(tester, 'VD');
      expect(find.byType(ConcubinageDecisionMatrix), findsOneWidget);
      expect(find.textContaining('462'), findsNothing,
          reason: 'CC 462 règle la part successorale CIVILE, pas le fiscal');
      expect(find.textContaining('loi fiscale cantonale'), findsWidgets);
    });

    test('le service ne renvoie plus de montant d\'impôt successoral', () {
      final r = FamilyService.compareMariageVsConcubinage(
        revenu1: 80000,
        revenu2: 60000,
        canton: 'VD',
      );
      final inheritance = r['inheritance'] as Map<String, dynamic>;
      expect(inheritance.containsKey('impot'), isFalse,
          reason: 'un montant dormant finit toujours par être rebranché');
      expect(inheritance.containsKey('netHerite'), isFalse);
      expect(inheritance['taux'], 0.25, reason: 'le taux VD reste servi');
      final married = r['inheritanceMarried'] as Map<String, dynamic>;
      expect(married['taux'], 0.0);
      expect(married.containsKey('impot'), isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  HERO — patrimoine echo shown only once patrimoine confirmed
  // ══════════════════════════════════════════════════════════════
  group('Hero premier éclairage', () {
    testWidgets('absent on open, present after patrimoine entered',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      expect(find.text(FamilyService.formatChf(300000)), findsNothing);
      await _setAmount(tester, _patrimoine, 300000);
      // The hero echoes the confirmed patrimoine (a real user input, not a
      // computed result on a fabricated default).
      expect(find.text(FamilyService.formatChf(300000)), findsWidgets);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  CANTON provenance = on-screen touch OR real profile canton
  // ══════════════════════════════════════════════════════════════
  group('Canton provenance', () {
    testWidgets('on-screen picker touch confirms the canton', (tester) async {
      await _pump(tester, _FakeProvider(null));
      expect(_state(tester).debugCantonConfirmed, isFalse);
      await _setCanton(tester, 'GE');
      expect(_state(tester).debugCantonConfirmed, isTrue);
      expect(_state(tester).debugCanton, 'GE');
    });

    testWidgets('real profile canton (key + valid) → seeded confirmed',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'GE', provided: {'canton'})),
      );
      expect(_state(tester).debugCanton, 'GE');
      expect(_state(tester).debugCantonConfirmed, isTrue);
    });

    testWidgets('legacy valid "ZH" WITHOUT the canton key → NOT confirmed',
        (tester) async {
      // fromJson defaults canton to 'ZH' with no user input; provided is empty.
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'ZH', provided: {'salary'})),
      );
      expect(_state(tester).debugCantonConfirmed, isFalse,
          reason: 'no q_canton answer → the ZH default never confirms');
    });

    testWidgets('keyed-EMPTY canton ("") → NOT confirmed', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(canton: '', provided: {'canton'})),
      );
      expect(_state(tester).debugCantonConfirmed, isFalse);
    });

    testWidgets('keyed-invalid junk "XX" → NOT confirmed', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'XX', provided: {'canton'})),
      );
      expect(_state(tester).debugCantonConfirmed, isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  SEED — revenu1 (user) key+range ; revenu2 (partner) NEVER from user
  // ══════════════════════════════════════════════════════════════
  group('Income seed provenance', () {
    testWidgets('revenu1: no salary key → not seeded', (tester) async {
      await _pump(tester, _FakeProvider(_profile(salaire: 8000, provided: {})));
      expect(_state(tester).debugRevenu1, isNull);
    });

    testWidgets('revenu1: in-range with key → seeded (8000×12)', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(salaire: 8000, provided: {'salary'})),
      );
      expect(_state(tester).debugRevenu1, 96000.0);
    });

    testWidgets('revenu1: out-of-range (200000/mo) → not seeded', (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(salaire: 200000, provided: {'salary'})),
      );
      expect(_state(tester).debugRevenu1, isNull,
          reason: 'out-of-range annual is never clamped into a seed');
    });

    testWidgets('revenu2: user salary present but NO conjoint → stays null',
        (tester) async {
      // The critical cross-contamination guard: the partner income is never
      // seeded from the user's own salary.
      await _pump(
        tester,
        _FakeProvider(_profile(salaire: 8000, provided: {'salary'})),
      );
      expect(_state(tester).debugRevenu1, 96000.0);
      expect(_state(tester).debugRevenu2, isNull,
          reason: 'partner income is never the user salary');
    });

    testWidgets('revenu2: real conjoint income → seeded (5000×12)',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(
          provided: {'salary'},
          conjoint: const ConjointProfile(salaireBrutMensuel: 5000),
        )),
      );
      expect(_state(tester).debugRevenu2, 60000.0,
          reason: 'seeded from the real declared partner income');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  TAB 2 — survivor gated on renteLpp (LPP-only, no max-AVS fabrication)
  //          + 3a educational (no naked balance, conditional heir copy)
  // ══════════════════════════════════════════════════════════════
  group('Tab2 protection', () {
    testWidgets('open with no data → survivor gated, no CHF, no shared widgets',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _openTab2(tester);
      expect(_gate(tester, _survivorTitle), isNotNull);
      // HOLE 1 / HOLE 3: the fabricating shared widgets are gone from concubinage.
      expect(find.byType(SurvivorPensionWidget), findsNothing,
          reason: 'removed: it showed a fabricated max-AVS married figure');
      expect(find.byType(Clause3aWidget), findsNothing,
          reason: 'removed: it showed a value-only (estimable) 3a balance');
      expect(find.textContaining('CHF'), findsNothing);
      // HOLE 3: the 3a message is present but CONDITIONAL, with no naked balance.
      expect(find.textContaining('Sans clause'), findsWidgets,
          reason: 'conditional 3a beneficiary copy, no computed balance');
    });

    testWidgets(
        'HOLE 1: renteLpp entered → married figure is LPP-only (renteLpp×60%), '
        'NOT the fabricated max-AVS blend', (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _openTab2(tester);
      await _setRenteLpp(tester, 2500);
      expect(_gate(tester, _survivorTitle), isNull);
      // Married survivor = 2500 × lppSurvivorFactor(0.60) = 1500, grounded in the
      // confirmed renteLpp input.
      const lppSurvivor = 2500 * FamilyService.lppSurvivorFactor;
      expect(lppSurvivor, 1500.0);
      expect(find.text(FamilyService.formatChf(1500)), findsWidgets,
          reason: 'married figure is the LPP survivor pension only');
      // The OLD fabrication = maxAVS(≈2520 test fallback)×0.8 + 1500 = 3516, and
      // its AVS component 2016, must NOT appear as a personal figure.
      expect(find.text(FamilyService.formatChf(3516)), findsNothing,
          reason: 'no max-AVS + LPP blend');
      expect(find.text(FamilyService.formatChf(2016)), findsNothing,
          reason: 'no fabricated personal max-AVS component');
      // And the shared widget stays gone even once renteLpp is confirmed.
      expect(find.byType(SurvivorPensionWidget), findsNothing);
      // The married figure is CONDITIONAL on LPP art. 19 eligibility (dependent
      // child, or age 45 + 5 years of marriage) — not an unconditional CHF.
      expect(find.textContaining('conditions LPP art. 19'), findsOneWidget,
          reason: 'survivor rente presented as conditional, not a certain amount');
    });

    testWidgets(
        'HOLE 3: profile with a positive 3a balance but NO provided-key → the '
        'balance is NEVER shown (no Clause3aWidget), only conditional copy',
        (tester) async {
      // A value-only positive balance (could be an estimate) must not surface as
      // « ton 3a = CHF X » — there is no reliable provenance for it.
      await _pump(
        tester,
        _FakeProvider(_profile(
          prevoyance: const PrevoyanceProfile(totalEpargne3a: 40000),
        )),
      );
      await _openTab2(tester);
      expect(find.byType(Clause3aWidget), findsNothing,
          reason: 'value-only 3a balance is never rendered as a figure');
      expect(find.text(FamilyService.formatChf(40000)), findsNothing,
          reason: 'no naked 3a balance');
      expect(find.textContaining('Sans clause'), findsWidgets,
          reason: 'conditional beneficiary-order copy is shown instead');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  Tab3 checklist — heir destination stated as the legal ORDER,
  //  never presuming the user has no descendants
  // ══════════════════════════════════════════════════════════════
  group('Tab3 checklist', () {
    testWidgets('testament item states the legal order, not "tout va aux parents"',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _openTab3(tester);
      expect(find.textContaining('ordre légal'), findsWidgets,
          reason: 'succession follows descendants-first legal order');
      expect(find.textContaining('tout va à tes parents'), findsNothing,
          reason: 'never presume the user has no children');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  LSFin — la comparaison DÉCRIT la mécanique, elle ne rend AUCUN verdict
  //
  //  Constat A (audit conseiller) : le moteur fiscal est un modèle simplifié
  //  (marié = barème ×0.92 forfaitaire, pas de déductions réelles, pas de
  //  commune) — il ne permet pas de qualifier un régime de « pénalité », de
  //  « bonus » ni d'« avantageux ». Les libellés DÉCRIVENT le sens de l'écart.
  //  Constat B : aucun score agrégé / gagnant. L'arbitrage appartient à
  //  l'utilisateur·rice.
  //
  //  Chaque assertion est sur le RENDU : elle repasse ROUGE si un verdict
  //  revient (libellé, compteur de score, champ de service ressuscité).
  // ══════════════════════════════════════════════════════════════
  group('Comparateur — mécanique, pas verdict', () {
    // Revenus PROCHES → l'impôt du ménage marié dépasse celui de 2 célibataires
    // (80000/60000/VD → +CHF 1'810 environ).
    Future<void> unlockPenalite(WidgetTester tester) async {
      await _pump(tester, _FakeProvider(null));
      await _setAmount(tester, _revenu1, 80000);
      await _setAmount(tester, _revenu2, 60000);
      await _setCanton(tester, 'VD');
    }

    // Revenu TRÈS INÉGAL → le barème réduit fait passer l'impôt du ménage marié
    // sous celui de 2 célibataires (200000/0/VD).
    Future<void> unlockBonus(WidgetTester tester) async {
      await _pump(tester, _FakeProvider(null));
      await _setAmount(tester, _revenu1, 200000);
      await _setAmount(tester, _revenu2, 0);
      await _setCanton(tester, 'VD');
    }

    // (a) — aucun qualificatif de valeur, dans AUCUNE des deux branches.
    const verdictWords = [
      'Pénalité',
      'pénalité',
      'Bonus',
      'bonus',
      'Avantageux',
      'avantageux',
      'Désavantageux',
      'désavantageux',
    ];

    testWidgets('(a) branche « impôt marié plus élevé » : aucun qualificatif',
        (tester) async {
      await unlockPenalite(tester);
      for (final w in verdictWords) {
        expect(find.textContaining(w), findsNothing,
            reason: '« $w » est un verdict, pas une description du mécanisme');
      }
    });

    testWidgets('(a) branche « impôt concubinage plus élevé » : idem',
        (tester) async {
      await unlockBonus(tester);
      for (final w in verdictWords) {
        expect(find.textContaining(w), findsNothing,
            reason: '« $w » est un verdict, pas une description du mécanisme');
      }
    });

    testWidgets('(a bis) les libellés DÉCRIVENT le sens de l\'écart',
        (tester) async {
      await unlockPenalite(tester);
      // Ligne « Impôts » de la matrice : les deux côtés sont nommés par le sens.
      expect(find.text('Impôt du ménage plus élevé'), findsWidgets);
      expect(find.text('Impôt du ménage moins élevé'), findsWidgets);
      // Détail fiscal : le sens de l'écart est explicite, sans jugement.
      expect(find.text('Impôt du ménage plus élevé marié'), findsOneWidget);
      expect(find.text('Impôt du ménage plus élevé en concubinage'), findsNothing);
    });

    testWidgets('(a ter) le sens s\'inverse avec un revenu très inégal',
        (tester) async {
      await unlockBonus(tester);
      expect(find.text('Impôt du ménage plus élevé en concubinage'),
          findsOneWidget);
      expect(find.text('Impôt du ménage plus élevé marié'), findsNothing);
    });

    // (b) — le mécanisme réel est énoncé (cumul des revenus + répartition).
    testWidgets('(b) le mécanisme de l\'imposition commune est énoncé',
        (tester) async {
      await unlockPenalite(tester);
      expect(find.textContaining('additionnés'), findsWidgets,
          reason: 'le cumul des revenus est le mécanisme réel');
      expect(find.textContaining('barème réduit'), findsWidgets,
          reason: 'le barème réservé aux couples est nommé');
      expect(find.textContaining('répartition des revenus'), findsWidgets,
          reason: 'le sens de l\'écart dépend de la répartition');
      // La limite du modèle accompagne le chiffre.
      expect(find.textContaining('Estimation simplifiée'), findsWidgets);
      expect(find.textContaining('barème cantonal détaillé'), findsWidgets);
    });

    // (c) — aucun score / gagnant agrégé, ni rendu ni dormant dans le service.
    testWidgets('(c) aucun compteur de score agrégé n\'est rendu',
        (tester) async {
      await unlockPenalite(tester);
      // L'ancien rendu affichait deux entiers nus (4 / 1) + le mot « avantages »
      // dans la carte-score de l'écran ET dans le compteur de la matrice.
      for (final n in ['0', '1', '2', '3', '4', '5', '6']) {
        expect(find.text(n), findsNothing,
            reason: 'un entier nu = un compteur de score ressuscité');
      }
      expect(find.text('avantages'), findsNothing);
      expect(find.textContaining('avantages,'), findsNothing);
    });

    test('(c) le service ne renvoie plus de score ni de gagnant', () {
      final r = FamilyService.compareMariageVsConcubinage(
        revenu1: 80000,
        revenu2: 60000,
        canton: 'VD',
      );
      expect(r.containsKey('scoreMariage'), isFalse,
          reason: 'critères hétérogènes à poids égal = pseudo-conseil');
      expect(r.containsKey('scoreConcubinage'), isFalse);
      expect(r.containsKey('fiscalAdvantage'), isFalse,
          reason: 'verdict dormant : finit toujours par être affiché');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  a11y root boundary + discrete gate nodes survive the refactor
  // ══════════════════════════════════════════════════════════════
  testWidgets('screen-root Semantics boundary + gate cards present',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _FakeProvider(null));
    expect(tester.getSemantics(find.byType(ConcubinageScreen)), isNotNull);
    // Tab1 shows exactly the two gated outputs on open.
    expect(find.byType(SituationGateCard), findsNWidgets(2));
    handle.dispose();
  });
}
