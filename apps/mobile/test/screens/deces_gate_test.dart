import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/deces_proche_screen.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:provider/provider.dart';

/// P2 « gate dur » — anti-façade contract for deces_proche_screen.
///
/// This screen is the pure TOUCH-ONLY case of the P2 rollout: the computed
/// figures describe the DECEASED and the DECEASED's succession, none of which
/// lives in the USER's own profile.
///   • Bénéficiaires (capital LPP + 3a du défunt) — two rendered CHF figures,
///     gated on {lppDefunt, pilier3aDefunt} (touch seul ; jamais amorcés depuis
///     le patrimoine/LPP/3a de l'utilisateur — ce serait attribuer SES avoirs au
///     défunt).
///   • Impact fiscal (exonéré / soumis, affirmation cantonale personnalisée) —
///     gated on {lienParente (touch), canton (clé 'canton' ou touch)}.
///
/// `_fortuneDefunt` et `_testamentExiste` ne nourrissent AUCUNE sortie chiffrée →
/// on prouve qu'ils sont inertes (toggler / éditer ne débloque ni ne change une
/// sortie gatée).
///
/// Every assertion is on the RENDERED figure (a keyed output card + its CHF text
/// / claim) or on the rendered [SituationGateCard]'s facts — never on an internal
/// bool. Each test goes RED if the gate is removed (i.e. if the screen went back
/// to rendering on the fabricated defaults 200000 / 50000 / conjoint / ZH or to
/// seeding the deceased's avoirs from the user's own prévoyance).
///
/// The screen is a `SingleChildScrollView` → every child is built (offstage),
/// so `find.byType` / `find.byKey` work without scrolling.

const _beneficiairesCard = Key('deces_beneficiaires_card');
const _impactCard = Key('deces_impact_card');
const _lppField = Key('deces_lpp_field');
const _pilier3aField = Key('deces_3a_field');
const _fortuneField = Key('deces_fortune_field');

class _FakeProvider extends CoachProfileProvider {
  _FakeProvider(this._injected);
  final CoachProfile? _injected;
  @override
  CoachProfile? get profile => _injected;
}

class _MutableProvider extends CoachProfileProvider {
  CoachProfile? _p;
  @override
  CoachProfile? get profile => _p;
  void hydrate(CoachProfile p) {
    _p = p;
    notifyListeners();
  }

  void clearProfile() {
    _p = null;
    notifyListeners();
  }
}

CoachProfile _profile({
  int birthYear = 1970,
  String canton = 'GE',
  double salaire = 8000,
  double? avoirLpp, // avoir LPP de l'UTILISATEUR (jamais celui du défunt)
  double epargne3a = 0, // épargne 3a de l'UTILISATEUR
  double patrimoine = 0, // patrimoine de l'UTILISATEUR
  Set<String> provided = const {},
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    salaireBrutMensuel: salaire,
    prevoyance: PrevoyanceProfile(
      avoirLppTotal: avoirLpp,
      totalEpargne3a: epargne3a,
    ),
    patrimoine: PatrimoineProfile(epargneLiquide: patrimoine),
    userProvidedFields: provided,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(birthYear + 65),
      label: 'Retraite',
    ),
  );
}

Future<void> _pump(WidgetTester tester, CoachProfileProvider provider) async {
  await tester.binding.setSurfaceSize(const Size(1200, 4000));
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
        home: DecesProcheScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

dynamic _state(WidgetTester tester) =>
    tester.state(find.byType(DecesProcheScreen)) as dynamic;

S _l10n(WidgetTester tester) =>
    S.of(tester.element(find.byType(DecesProcheScreen)))!;

/// Picks the gate whose facts include [key] (two gate cards coexist when both
/// outputs are incomplete).
SituationGate _gateWith(WidgetTester tester, String key) => tester
    .widgetList<SituationGateCard>(find.byType(SituationGateCard))
    .firstWhere((c) => c.gate.facts.any((f) => f.key == key))
    .gate;

Future<void> _touchSlider(WidgetTester tester, Key key, double v) async {
  tester.widget<MintPremiumSlider>(find.byKey(key)).onChanged(v);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _selectLien(WidgetTester tester, String v) async {
  tester
      .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
      .onSelectionChanged!({v});
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _selectCanton(WidgetTester tester, String c) async {
  tester
      .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
      .onChanged!(c);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  // ══════════════════════════════════════════════════════════════
  //  BÉNÉFICIAIRES (LPP + 3a du défunt) — gated on {lppDefunt, pilier3aDefunt}
  // ══════════════════════════════════════════════════════════════
  group('Bénéficiaires output', () {
    testWidgets('no profile: bénéficiaires gated, lists {lppDefunt,pilier3aDefunt}',
        (tester) async {
      await _pump(tester, _FakeProvider(null));

      expect(find.byKey(_beneficiairesCard), findsNothing,
          reason: 'no LPP/3a figure on the fabricated defaults 200000/50000');
      final gate = _gateWith(tester, 'lppDefunt');
      expect(gate.missing.map((f) => f.key),
          containsAll(<String>['lppDefunt', 'pilier3aDefunt']));
    });

    testWidgets('touch LPP + 3a: both figures render == touched values',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _touchSlider(tester, _lppField, 280000);
      await _touchSlider(tester, _pilier3aField, 40000);

      expect(find.byKey(_beneficiairesCard), findsOneWidget);
      expect(_state(tester).debugLppDefunt, 280000.0);
      expect(_state(tester).debugPilier3aDefunt, 40000.0);
      // The rendered figures echo the confirmed touched values.
      expect(
        find.descendant(
            of: find.byKey(_beneficiairesCard),
            matching: find.text(formatChfWithPrefix(280000))),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: find.byKey(_beneficiairesCard),
            matching: find.text(formatChfWithPrefix(40000))),
        findsOneWidget,
      );
    });

    testWidgets('touch only LPP: stays gated on pilier3aDefunt', (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _touchSlider(tester, _lppField, 280000);

      expect(find.byKey(_beneficiairesCard), findsNothing);
      final gate = _gateWith(tester, 'pilier3aDefunt');
      expect(gate.missing.map((f) => f.key), contains('pilier3aDefunt'));
      expect(gate.missing.map((f) => f.key), isNot(contains('lppDefunt')),
          reason: 'lppDefunt was touched → confirmed');
    });

    testWidgets(
        'MUTATION-PROOF upper: profile LPP 3M + 3a 400k (above ranges) do NOT '
        'seed the deceased facts → still gated', (tester) async {
      // The deceased's avoirs are never the user's. A user with a huge own
      // prévoyance must NOT unlock the beneficiaries card.
      await _pump(
        tester,
        _FakeProvider(_profile(
            avoirLpp: 3000000, epargne3a: 400000, provided: {'avoirLpp'})),
      );
      expect(find.byKey(_beneficiairesCard), findsNothing,
          reason: 'deceased LPP/3a are touch-only, never seeded from the user');
      expect(_state(tester).debugLppDefunt, 200000.0,
          reason: 'lppDefunt keeps its editable default, not the user 3M');
      expect(_state(tester).debugPilier3aDefunt, 50000.0);
      final gate = _gateWith(tester, 'lppDefunt');
      expect(gate.missing.map((f) => f.key),
          containsAll(<String>['lppDefunt', 'pilier3aDefunt']));
    });

    testWidgets(
        'MUTATION-PROOF lower: profile LPP 1 + 3a 0 do NOT seed → still gated',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(
            _profile(avoirLpp: 1, epargne3a: 0, provided: {'avoirLpp'})),
      );
      expect(find.byKey(_beneficiairesCard), findsNothing);
      expect(_state(tester).debugLppDefunt, 200000.0);
      expect(_state(tester).debugPilier3aDefunt, 50000.0);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  IMPACT FISCAL — gated on {lienParente (touch), canton (key/touch)}
  // ══════════════════════════════════════════════════════════════
  group('Impact fiscal output', () {
    testWidgets('no profile: impact gated, lists {lienParente,canton}',
        (tester) async {
      await _pump(tester, _FakeProvider(null));

      expect(find.byKey(_impactCard), findsNothing,
          reason: 'no tax claim on the fabricated defaults conjoint/ZH');
      final gate = _gateWith(tester, 'lienParente');
      expect(gate.missing.map((f) => f.key),
          containsAll(<String>['lienParente', 'canton']));
    });

    testWidgets('touch lien + canton: exemption claim renders on real facts',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _selectLien(tester, 'conjoint');
      await _selectCanton(tester, 'VD');

      expect(find.byKey(_impactCard), findsOneWidget);
      expect(_state(tester).debugCanton, 'VD');
      // Conjoint → exemption claim naming the confirmed canton.
      expect(
        find.descendant(
            of: find.byKey(_impactCard),
            matching: find.text(_l10n(tester).decesProchImpactFiscalExempt('VD'))),
        findsOneWidget,
      );
    });

    testWidgets('non-conjoint lien: taxed claim renders', (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _selectLien(tester, 'enfant');
      await _selectCanton(tester, 'GE');

      expect(find.byKey(_impactCard), findsOneWidget);
      expect(
        find.descendant(
            of: find.byKey(_impactCard),
            matching: find.text(_l10n(tester).decesProchImpactFiscalTaxe('GE'))),
        findsOneWidget,
      );
    });

    testWidgets(
        'canton is TOUCH-ONLY: a profile canton key does NOT confirm it',
        (tester) async {
      // Succession tax is the DECEASED's last domicile, not the user's canton.
      // Even with the user's 'canton' key + lien confirmed, canton stays
      // assumed until the user provides the deceased's canton (touch).
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'GE', provided: {'canton'})),
      );
      await _selectLien(tester, 'conjoint');
      expect(find.byKey(_impactCard), findsNothing,
          reason: "the user's canton is never silently the deceased's");
      expect(_gateWith(tester, 'canton').missing.map((f) => f.key),
          contains('canton'));

      // Touching canton (the deceased's domicile) unlocks the claim.
      await _selectCanton(tester, 'VD');
      expect(find.byKey(_impactCard), findsOneWidget);
      expect(_state(tester).debugCanton, 'VD');
    });

    testWidgets('canton WITHOUT key stays assumed (touch required)',
        (tester) async {
      // A real canton value but no 'canton' provenance key → assumed. The
      // succession canton is the deceased's domicile, not silently the user's.
      await _pump(
        tester,
        _FakeProvider(_profile(canton: 'GE', provided: {'salary'})),
      );
      await _selectLien(tester, 'conjoint');
      expect(find.byKey(_impactCard), findsNothing,
          reason: 'canton has no key → assumed → impact gated on canton');
      expect(_gateWith(tester, 'canton').missing.map((f) => f.key),
          contains('canton'));
    });

    testWidgets('no profile, same ZH default stays gated',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _selectLien(tester, 'conjoint');
      expect(find.byKey(_impactCard), findsNothing,
          reason: 'identical ZH with no provenance stays gated on canton');
      expect(_gateWith(tester, 'canton').missing.map((f) => f.key),
          contains('canton'));
    });

    testWidgets('touched facts (user data) survive a profile clear',
        (tester) async {
      final fake = _MutableProvider();
      await _pump(tester, fake);
      await _selectLien(tester, 'conjoint');
      await _selectCanton(tester, 'VD');
      expect(find.byKey(_impactCard), findsOneWidget);
      expect(_state(tester).debugCanton, 'VD');

      // Nothing on this screen is seeded from the profile, so a clear must not
      // disturb the user's touched inputs.
      fake.clearProfile();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(_impactCard), findsOneWidget,
          reason: 'touched facts are local user data, immune to a clear');
      expect(_state(tester).debugCanton, 'VD');
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  fortuneDefunt + testament are INERT (feed no computed output)
  // ══════════════════════════════════════════════════════════════
  group('Inert inputs (no fabricated figure)', () {
    testWidgets('MUTATION-PROOF: profile patrimoine 10M does NOT seed fortune',
        (tester) async {
      await _pump(
        tester,
        _FakeProvider(_profile(patrimoine: 10000000, provided: {'canton'})),
      );
      expect(_state(tester).debugFortuneDefunt, 500000.0,
          reason: 'fortune du défunt is never the user patrimoine (fabrication)');
    });

    testWidgets('touching fortune unlocks nothing (feeds no gated output)',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      await _touchSlider(tester, _fortuneField, 1200000);
      expect(_state(tester).debugFortuneDefunt, 1200000.0);
      // Both outputs remain gated: fortune is determinative for neither.
      expect(find.byKey(_beneficiairesCard), findsNothing);
      expect(find.byKey(_impactCard), findsNothing);
    });

    testWidgets('testament toggle does not change either gated output',
        (tester) async {
      await _pump(tester, _FakeProvider(null));
      final sw = find.byType(SwitchListTile);
      // Toggle while everything is gated → still gated.
      await tester.tap(sw);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(_beneficiairesCard), findsNothing);
      expect(find.byKey(_impactCard), findsNothing);

      // Confirm the bénéficiaires facts, then toggle testament → figures stable.
      await _touchSlider(tester, _lppField, 280000);
      await _touchSlider(tester, _pilier3aField, 40000);
      expect(find.byKey(_beneficiairesCard), findsOneWidget);
      await tester.tap(sw);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(_beneficiairesCard), findsOneWidget,
          reason: 'testament feeds no output → figures unchanged');
      expect(
        find.descendant(
            of: find.byKey(_beneficiairesCard),
            matching: find.text(formatChfWithPrefix(280000))),
        findsOneWidget,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  Per-output independence + no-provider safety + a11y root
  // ══════════════════════════════════════════════════════════════
  testWidgets('bénéficiaires confirmed does not unlock impact fiscal',
      (tester) async {
    await _pump(tester, _FakeProvider(null));
    await _touchSlider(tester, _lppField, 280000);
    await _touchSlider(tester, _pilier3aField, 40000);
    expect(find.byKey(_beneficiairesCard), findsOneWidget);
    expect(find.byKey(_impactCard), findsNothing,
        reason: 'lien + canton still assumed → impact gated independently');
    expect(find.byType(SituationGateCard), findsOneWidget,
        reason: 'exactly the impact gate remains');
  });

  testWidgets('impact confirmed does not unlock bénéficiaires', (tester) async {
    await _pump(tester, _FakeProvider(null));
    await _selectLien(tester, 'conjoint');
    await _selectCanton(tester, 'VD');
    expect(find.byKey(_impactCard), findsOneWidget);
    expect(find.byKey(_beneficiairesCard), findsNothing,
        reason: 'lppDefunt + pilier3aDefunt still assumed → gated');
  });

  testWidgets('no provider in tree: defaults kept, both outputs gated',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: DecesProcheScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DecesProcheScreen), findsOneWidget);
    expect(find.byKey(_beneficiairesCard), findsNothing);
    expect(find.byKey(_impactCard), findsNothing);
    expect(find.byType(SituationGateCard), findsWidgets);
  });

  testWidgets('screen-root Semantics boundary survives the gate refactor',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _FakeProvider(null));
    expect(
      tester.getSemantics(find.byType(DecesProcheScreen)),
      isNotNull,
    );
    // The gated result slot exposes discrete, focusable missing-fact nodes.
    expect(find.byType(SituationGateCard), findsWidgets);
    handle.dispose();
  });
}
