import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/first_job_screen.dart';
import 'package:mint_mobile/widgets/coach/job_change_checklist_widget.dart';
import 'package:mint_mobile/widgets/educational/salary_breakdown_widget.dart';
import 'package:mint_mobile/widgets/situation/situation_gate.dart';
import 'package:provider/provider.dart';

/// PR-F — états réseau / vide / chargement + anti-critère du north star
/// (TRANCHE-FIRSTJOB-SPEC §2.3, critère A4).
///
/// Contrats prouvés ici :
///   • Le net first-job est L1 (local, synchrone) → il rend depuis le profil
///     local, sans dépendance réseau (survit staging coupé).
///   • Le CHARGEMENT du profil a un indicateur BORNÉ : il apparaît pendant
///     l'hydratation puis disparaît (jamais de spinner infini, jamais d'écran
///     vide « Aucune donnée pour l'instant »).
///   • La checklist n'affiche les items « ancien employeur » (LFLP libre
///     passage) que si un avoir LPP antérieur existe — sinon les références
///     légales seraient inapplicables au vrai premier emploi (§2.3.4 / §2.4).
/// Harnais repris de `first_job_lucidite_test.dart`.

class _FakeProvider extends CoachProfileProvider {
  _FakeProvider(this._injected);
  final CoachProfile? _injected;
  @override
  CoachProfile? get profile => _injected;
}

/// Provider qui hydrate encore (`isLoading`) puis se résout (`resolve`).
class _HydratingProvider extends CoachProfileProvider {
  bool _loading = true;
  CoachProfile? _p;
  @override
  bool get isLoading => _loading;
  @override
  CoachProfile? get profile => _p;
  void resolve(CoachProfile? profile) {
    _loading = false;
    _p = profile;
    notifyListeners();
  }
}

CoachProfile _profile({
  int birthYear = 2001, // âge 25 au 2026 (fenêtre premier emploi)
  String canton = 'VD',
  double salaire = 6500,
  double? avoirLppTotal,
  Set<String> provided = const {'salary', 'age', 'canton'},
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    salaireBrutMensuel: salaire,
    // avoirLppTotal vit sur PrevoyanceProfile : preuve d'un 2e pilier antérieur
    // (donc d'un employeur précédent). null ⇒ vrai premier emploi.
    prevoyance: PrevoyanceProfile(avoirLppTotal: avoirLppTotal),
    userProvidedFields: provided,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(birthYear + 65),
      label: 'Retraite',
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  CoachProfileProvider provider, {
  Size surface = const Size(1200, 7000),
}) async {
  await tester.binding.setSurfaceSize(surface);
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

void main() {
  // ── A4 (moitié first-job) : L1 offline survit — le net rend sans réseau ──
  testWidgets(
      'anti-critère : le net L1 rend depuis le profil local, sans dépendance réseau',
      (tester) async {
    // Le provider fournit le profil localement (aucun backend). L'écran
    // n'importe aucun ApiService : le calcul est 100 % local et synchrone,
    // donc insensible à un staging coupé.
    await _pump(tester, _FakeProvider(_profile()));

    expect(find.byType(SalaryBreakdownWidget), findsOneWidget,
        reason: 'le net (CHF) est calculé et rendu hors ligne (L1)');
    expect(_byId('firstjob-premier-eclairage-value'), findsOneWidget,
        reason: 'le premier chiffre est visible staging coupé');
    expect(_byId('firstjob-loading'), findsNothing,
        reason: 'profil résolu → aucun indicateur de chargement résiduel');
    expect(find.textContaining('Aucune donnée'), findsNothing,
        reason: 'jamais l\'écran vide régressif (2026-05-07)');
  });

  // ── Chargement borné : indicateur pendant l'hydratation, jamais infini ──
  testWidgets(
      'chargement : indicateur pendant l\'hydratation puis carte de situation (jamais de spinner infini)',
      (tester) async {
    final provider = _HydratingProvider();
    await _pump(tester, provider, surface: const Size(1200, 3000));

    // Hydratation en cours, rien de confirmé → indicateur, aucun chiffre.
    expect(_byId('firstjob-loading'), findsOneWidget,
        reason: 'le profil s\'hydrate → indicateur de chargement');
    expect(find.byType(SalaryBreakdownWidget), findsNothing,
        reason: 'aucun net fabriqué pendant le chargement');
    expect(find.byType(SituationGateCard), findsNothing,
        reason: 'la carte de situation ne clignote pas pendant le chargement');

    // Hydratation terminée SANS donnée → bascule sur la carte de situation.
    provider.resolve(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(_byId('firstjob-loading'), findsNothing,
        reason: 'fin d\'hydratation → l\'indicateur disparaît (borné)');
    expect(find.byType(SituationGateCard), findsOneWidget,
        reason:
            'profil vide → carte de situation éditable, jamais un écran blanc');
  });

  // ── Cohérence « premier » emploi : items « ancien employeur » gatés ──
  testWidgets(
      'checklist : sans avoir LPP antérieur, aucune référence libre passage (LFLP)',
      (tester) async {
    await _pump(tester, _FakeProvider(_profile()),
        surface: const Size(1200, 2000));

    final finder = find.byType(JobChangeChecklistWidget);
    await tester.scrollUntilVisible(finder, 400,
        scrollable: find.byType(Scrollable).first);

    final refs = tester
        .widget<JobChangeChecklistWidget>(finder)
        .items
        .map((i) => i.legalRef)
        .toList();
    expect(refs, isNot(contains('LFLP art. 2')),
        reason:
            'pas de certificat de libre passage sans employeur antérieur');
    expect(refs, isNot(contains('LFLP art. 4 al. 2')),
        reason: 'pas de transfert d\'ancien avoir pour un vrai premier emploi');
    expect(refs, contains('LAMal art. 71'),
        reason: 'l\'item LAMal vaut pour tous');
    expect(refs, contains('OPP3 art. 7'), reason: 'l\'item 3a vaut pour tous');
  });

  testWidgets(
      'checklist : avec un avoir LPP antérieur, les items libre passage réapparaissent',
      (tester) async {
    await _pump(tester, _FakeProvider(_profile(avoirLppTotal: 50000)),
        surface: const Size(1200, 2000));

    final finder = find.byType(JobChangeChecklistWidget);
    await tester.scrollUntilVisible(finder, 400,
        scrollable: find.byType(Scrollable).first);

    final refs = tester
        .widget<JobChangeChecklistWidget>(finder)
        .items
        .map((i) => i.legalRef)
        .toList();
    expect(refs, contains('LFLP art. 2'),
        reason: 'avoir antérieur → certificat de libre passage pertinent');
    expect(refs, contains('LFLP art. 4 al. 2'),
        reason: 'avoir antérieur → transfert du libre passage pertinent');
  });
}
