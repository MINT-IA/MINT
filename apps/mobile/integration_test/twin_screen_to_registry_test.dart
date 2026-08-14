// D'UN GESTE D'ÉCRAN JUSQU'À UNE VERSION — sur la vraie pile.
//
// LA RÈGLE QUE CE FICHIER VÉRIFIE
//
//   « Aucun écran n'est terminé si les informations qu'il collecte ne
//     rejoignent pas le jumeau financier, et si ses résultats ne peuvent pas
//     être retrouvés et réutilisés ailleurs. »
//
// Tout le reste de la vérification s'arrête un cran avant : les tests
// unitaires appellent le coffre sur un faux support, et les oracles
// d'intégration appellent le coffre directement. Aucun ne part de ce que
// l'écran APPELLE.
//
// Ici on part exactement de là — `CoachProfileProvider.saveHousingFact`, la
// méthode que `mint_next_housing_screen.dart:745` invoque quand la personne
// valide — et on va jusqu'à la version dans le registre scellé, puis jusqu'au
// chiffre que relit un écran après redémarrage.
//
// C'est la seule preuve qui répond à « est-ce que ça marche pour quelqu'un ».

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mint_mobile/models/mint_next_3a_tax_boundary.dart';
import 'package:mint_mobile/models/mint_next_housing_fact.dart';
import 'package:mint_mobile/models/mint_next_revenu_fact.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:mint_mobile/services/twin/answers_twin_backend.dart';
import 'package:mint_mobile/services/twin/twin_fact_commands.dart';
import 'package:mint_mobile/services/twin/twin_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Le trousseau survit aux réinstallations : le vider explicitement, sinon
    // une exécution contamine la suivante.
    await SecureWizardStore.deleteKeys({AnswersTwinBackend.registryKey});
    TwinFactCommands.install();
  });

  MintNextHousingFact logement(int interetCents) => MintNextHousingFact(
        tenure: PrimaryHomeTenure.ownerOccupier,
        mortgageStatus: HousingMortgageStatus.yes,
        statementAvailability: MortgageStatementAvailability.ready,
        statementYear: 2025,
        annualInterestCents: interetCents,
        debtBalanceCents: 61200000,
        assertedAt: DateTime.utc(2026, 8, 14),
        source: MintNextHousingFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  Future<bool> coffreDisponible() async {
    const temoin = '_mint_sonde_coffre';
    if (!await SecureWizardStore.write(temoin, 'sonde')) return false;
    return await SecureWizardStore.read(temoin) == 'sonde';
  }

  testWidgets('what the screen saves becomes a VERSION, and survives a restart',
      (tester) async {
    if (!await coffreDisponible()) {
      markTestSkipped('coffre indisponible sur cet appareil — non concluant');
      return;
    }

    final provider = CoachProfileProvider();
    await provider.loadFromWizard();

    // Le geste : exactement ce que l'écran appelle quand la personne valide.
    await provider.saveHousingFact(logement(425000));
    // Puis elle se corrige.
    await provider.saveHousingFact(logement(512000));

    // « Redémarrage » : tout est relu depuis le stockage, rien n'est gardé en
    // mémoire.
    final registry =
        (await TwinStore(const AnswersTwinBackend(), newId: () => 'relu').read())
            .registry;
    final histoire = registry.history('logement#residence_principale');

    expect(histoire.length, 2,
        reason: 'deux déclarations, deux versions — la première ne doit pas '
            'avoir été écrasée');
    expect(histoire.first.payload[MintNextHousingFact.annualInterestCentsKey],
        425000,
        reason: "ce qu'elle avait déclaré d'abord reste lisible");
    expect(histoire.last.payload[MintNextHousingFact.annualInterestCentsKey],
        512000);
    expect(histoire.last.fiscalYear, 2025,
        reason: "et la charge sait à quel exercice elle appartient");

    // Et le chiffre remonte jusqu'à ce que relit un écran.
    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers[MintNextHousingFact.annualInterestCentsKey], 512000,
        reason: "c'est la correction que la personne doit voir");

    // Enfin, ce qui compte vraiment : il atteint un CALCUL.
    final fait = MintNextHousingFact.fromWizardAnswers(answers)!;
    final contexte = MintNext3aHousingContext.fromConfirmedFact(fait);
    expect(contexte, isNotNull);
    expect(contexte!.annualInterestCents, 512000,
        reason: 'la déduction la plus courante en Suisse doit être atteignable');
    expect(contexte.coversTaxYear(2025), isTrue);
  });

  testWidgets('income too — and its LEGACY projection follows the correction',
      (tester) async {
    // Le revenu est le fait le plus risque des quatre restants : il projette
    // DEUX cles heritees en plus des siennes. Si elles ne suivaient pas la
    // correction, un consommateur historique afficherait l'ancien revenu — et
    // personne ne le verrait, parce que la cle propre, elle, serait a jour.
    if (!await coffreDisponible()) {
      markTestSkipped('coffre indisponible sur cet appareil — non concluant');
      return;
    }

    final provider = CoachProfileProvider();
    await provider.loadFromWizard();

    await provider.saveRevenuFact(MintNextRevenuFact(
      amountCents: 700000,
      period: MintNextRevenuPeriod.monthly,
      assertedAt: DateTime.utc(2026, 8, 14),
      source: MintNextRevenuFact.userDeclarationSource,
      schemaVersion: 1,
      needsConfirmation: false,
    ));
    await provider.saveRevenuFact(MintNextRevenuFact(
      amountCents: 950000,
      period: MintNextRevenuPeriod.monthly,
      assertedAt: DateTime.utc(2026, 8, 14),
      source: MintNextRevenuFact.userDeclarationSource,
      schemaVersion: 1,
      needsConfirmation: false,
    ));

    final registry =
        (await TwinStore(const AnswersTwinBackend(), newId: () => 'relu').read())
            .registry;
    expect(registry.history('revenu#principal').length, 2,
        reason: 'deux declarations, deux versions');

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers[MintNextRevenuFact.amountCentsKey], 950000);
    expect(answers[MintNextRevenuFact.legacyAmountKey], 9500.0,
        reason: 'la projection heritee doit suivre la correction, sinon un '
            'consommateur historique affiche un revenu perime');
    expect(answers[MintNextRevenuFact.legacyFrequencyKey], 'monthly');
  });

  testWidgets('3a payments — MARGIN slice, waiting on the twin', (tester) async {
    // T1 ATTEND, et cet oracle dit pourquoi plutot que de disparaitre.
    //
    // Mesure le 2026-08-14 : avec `versements_3a` dans les faits possedes, la
    // sauvegarde ne LEVE PAS mais `provider.versements3aFact` ressort NUL — ce
    // que le provider expose n'est plus reconstituable. Les 11 122 tests
    // unitaires passent : le defaut n'apparait que sur la vraie pile, comme
    // tous les autres de cette session.
    //
    // Diagnostic non termine, donc bascule RETIREE plutot qu'expediee.
    markTestSkipped(
        'versements_3a pas encore possedes par le jumeau — voir T1 dans '
        '.planning/FEUILLE-DE-ROUTE.md');
  });

  testWidgets('deleting from the screen leaves a tombstone, not a hole',
      (tester) async {
    if (!await coffreDisponible()) {
      markTestSkipped('coffre indisponible sur cet appareil — non concluant');
      return;
    }

    final provider = CoachProfileProvider();
    await provider.loadFromWizard();
    await provider.saveHousingFact(logement(425000));

    await provider.deleteHousingFact();

    final registry =
        (await TwinStore(const AnswersTwinBackend(), newId: () => 'relu').read())
            .registry;
    expect(registry.current('logement#residence_principale')!.isTombstone,
        isTrue,
        reason: 'la personne a bien déclaré quelque chose un jour');
    expect(registry.history('logement#residence_principale').length, 2);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers.containsKey(MintNextHousingFact.annualInterestCentsKey),
        isFalse,
        reason: 'mais le fait n\'alimente plus ni écran ni calcul');
  });
}
