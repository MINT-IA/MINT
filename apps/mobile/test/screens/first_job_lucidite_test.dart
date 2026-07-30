import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/first_job_screen.dart';
import 'package:mint_mobile/services/financial_core/money_truth_receipt.dart';
import 'package:mint_mobile/services/first_job_service.dart';
import 'package:mint_mobile/widgets/educational/salary_breakdown_widget.dart';
import 'package:mint_mobile/widgets/trust/mint_trame_confiance.dart';
import 'package:provider/provider.dart';

/// PR-C — appareil de lucidité sur la sortie chiffrée du first-job (SPEC §2.2,
/// critère A3). Contrat : l'écran chiffré ne rend JAMAIS un net sans ses 4
/// éléments (bande d'incertitude + confiance + « pourquoi ce chiffre » +
/// millésime). Chaque élément vient du `MoneyTruthReceipt` (PR-B), pas d'un
/// recalcul divergent. Le harnais reprend celui de `first_job_gate_test.dart`
/// (surface haute → le slot résultat gaté s'inflate sans scroll).

class _FakeProvider extends CoachProfileProvider {
  _FakeProvider(this._injected);
  final CoachProfile? _injected;
  @override
  CoachProfile? get profile => _injected;
}

CoachProfile _profile({
  int birthYear = 2001, // âge 25 au 2026 (fenêtre premier emploi)
  String canton = 'VD',
  double salaire = 6500,
  Set<String> provided = const {'salary', 'age', 'canton'},
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    salaireBrutMensuel: salaire,
    userProvidedFields: provided,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(birthYear + 65),
      label: 'Retraite',
    ),
  );
}

Future<void> _pump(WidgetTester tester, CoachProfileProvider provider) async {
  await tester.binding.setSurfaceSize(const Size(1200, 7000));
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
        home: FirstJobScreen(),
      ),
    ),
  );
  await tester.pump(); // build + postFrame
  await tester.pump(const Duration(milliseconds: 500)); // settle entrances
}

Finder _byId(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

dynamic _state(WidgetTester tester) =>
    tester.state(find.byType(FirstJobScreen)) as dynamic;

/// Le receipt attendu pour les entrées confirmées de l'écran — MÊME producteur
/// que l'écran (`buildNetSalaryReceipt`), donc MÊME bande.
MoneyTruthReceipt _expectedReceipt(WidgetTester tester) {
  final st = _state(tester);
  return FirstJobService.buildNetSalaryReceipt(
    salaireBrutMensuel: st.debugSalaire as double,
    age: st.debugAge as int,
    canton: st.debugCanton as String,
    tauxActivite: st.debugTaux as double,
  );
}

void main() {
  // ── A3 : les 4 éléments de l'appareil apparaissent avec le net ──
  testWidgets(
      'appareil complet : les 4 éléments co-rendus avec le net (jamais de net nu)',
      (tester) async {
    await _pump(tester, _FakeProvider(_profile()));

    // Le net est rendu (breakdown présent) …
    expect(find.byType(SalaryBreakdownWidget), findsOneWidget,
        reason: 'le net doit être rendu quand le gate est complet');

    // … et l'appareil complet l'accompagne : les 4 ancres du contrat A3.
    expect(_byId('firstjob-premier-eclairage-value'), findsOneWidget,
        reason: 'le premier chiffre porte l\'ancre du flow d\'acceptation');
    // Source UNIQUE du net (SPEC §2.1 A2 / §3.1) — ancre consommée par le flow
    // d'acceptation (assertVisible + copyTextFrom parité dashboard↔coach). Un
    // SEUL nœud porte cet id : pas de second net divergent.
    expect(_byId('firstjob-net-value'), findsOneWidget,
        reason: 'la source unique du net porte l\'ancre firstjob-net-value');
    expect(_byId('firstjob-confidence-chip'), findsOneWidget,
        reason: 'la confiance (EnhancedConfidence réutilisée) est rendue');
    expect(find.byType(MintTrameConfiance), findsOneWidget,
        reason: 'la confiance passe par MintTrameConfiance (aucun nouveau scorer)');
    expect(_byId('firstjob-source-vintage'), findsOneWidget,
        reason: 'le millésime + les sources sont visibles près du chiffre (D11)');
    expect(_byId('firstjob-why-net'), findsOneWidget,
        reason: 'le disclosure « pourquoi ce chiffre » est présent');
  });

  // ── AX pilote (ADR 2026-07-30) : plus de Semantics RACINE ──────────────
  // Le conteneur racine 'first_job_screen' effondrait l'arbre AX de la route
  // poussée sur iOS 26.2 (double frontière avec ModalRoute.scopesRoute). Il
  // est retiré ; les flows/tests gatent sur les ids INTERNES. Verrou : l'id
  // racine a disparu ET l'ancre interne d'arrivée survit dans l'arbre Dart.
  testWidgets(
      'pilote AX : id racine first_job_screen retiré, ancre interne présente',
      (tester) async {
    await _pump(tester, _FakeProvider(_profile()));

    expect(_byId('first_job_screen'), findsNothing,
        reason: 'le conteneur Semantics racine first_job_screen doit être '
            'retiré (fix effondrement AX iOS 26.2, ADR 2026-07-30)');
    expect(_byId('firstjob-premier-eclairage-value'), findsOneWidget,
        reason: 'l\'ancre INTERNE d\'arrivée (consommée par le flow '
            'd\'acceptation re-gaté) doit survivre dans l\'arbre sémantique');
  });

  // ── A3 : la bande correspond au range du receipt ──
  testWidgets('la bande d\'incertitude affiche le range du receipt (low/high)',
      (tester) async {
    await _pump(tester, _FakeProvider(_profile()));

    final receipt = _expectedReceipt(tester);
    expect(receipt.range, isNotNull,
        reason: 'le claim firstjob.net_salary.v1 porte une bande (SPEC §4.1)');
    final low = FirstJobService.formatChf(receipt.range!.low);
    final high = FirstJobService.formatChf(receipt.range!.high);
    expect(low, isNot(high),
        reason: 'les bornes AANP basse/haute donnent deux nets distincts');

    // La bande rendue contient exactement les deux bornes du receipt : la valeur
    // affichée EST le range du receipt, pas un pourcentage arbitraire.
    expect(find.textContaining(low), findsOneWidget,
        reason: 'la borne basse du receipt est affichée');
    expect(find.textContaining(high), findsOneWidget,
        reason: 'la borne haute du receipt est affichée');

    // L'ancre du net affiche receipt.value (== net du breakdown, pas divergent).
    final net = FirstJobService.formatChf(receipt.value);
    expect(find.textContaining(net), findsWidgets,
        reason: 'l\'ancre porte la valeur du receipt (net non divergent)');
    // L'ancre firstjob-net-value porte EXACTEMENT receipt.value : le net copié
    // par le flow (copyTextFrom) est bien la valeur du receipt.
    expect(
        find.descendant(
            of: _byId('firstjob-net-value'), matching: find.textContaining(net)),
        findsOneWidget,
        reason: 'firstjob-net-value porte la valeur nette du receipt');
    expect(receipt.value,
        FirstJobService.analyzeSalary(
                salaireBrutMensuel: 6500, age: 25, canton: 'VD')
            .netEstime,
        reason: 'receipt.value == _result!.netEstime (un seul net)');
  });

  // ── A3 : le disclosure liste ≥ 1 source millésimée ──
  testWidgets('« pourquoi ce chiffre » déplié liste ≥ 1 source millésimée',
      (tester) async {
    await _pump(tester, _FakeProvider(_profile()));

    // Replié par défaut : le corps n'est pas dans l'arbre.
    expect(_byId('firstjob-why-net-body'), findsNothing,
        reason: 'le détail est replié par défaut (détail progressif)');

    // Déplier via l'InkWell de l'en-tête bouton.
    await tester.tap(
      find.descendant(
          of: _byId('firstjob-why-net'), matching: find.byType(InkWell)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final body = _byId('firstjob-why-net-body');
    expect(body, findsOneWidget, reason: 'le corps se déplie');

    // Une source légale au moins, portant son millésime (2026 pour les barèmes
    // de cotisation) — la provenance datée est bien affichée.
    expect(
        find.descendant(of: body, matching: find.textContaining('LAVS')),
        findsWidgets,
        reason: 'au moins une source (référence légale) est listée');
    expect(
        find.descendant(of: body, matching: find.textContaining('2026')),
        findsWidgets,
        reason: 'la source listée porte son millésime');
  });

  // ── Contrat inverse : gate incomplet → ni net ni appareil ──
  testWidgets('gate incomplet : aucun net, donc aucun appareil de lucidité',
      (tester) async {
    await _pump(tester, _FakeProvider(null));

    expect(find.byType(SalaryBreakdownWidget), findsNothing,
        reason: 'aucun net sur un profil non confirmé');
    // L'appareil est co-gaté avec le net : jamais d'appareil sur un chiffre absent.
    expect(_byId('firstjob-net-value'), findsNothing,
        reason: 'aucune ancre de net sur un gate incomplet');
    expect(_byId('firstjob-confidence-chip'), findsNothing);
    expect(_byId('firstjob-source-vintage'), findsNothing);
    expect(_byId('firstjob-why-net'), findsNothing);
    expect(find.byType(MintTrameConfiance), findsNothing);
  });
}
