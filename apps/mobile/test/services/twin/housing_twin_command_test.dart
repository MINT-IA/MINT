// La bascule du logement — l'édition doit gagner, y compris après redémarrage.
//
// LE PIÈGE QUE CES ORACLES FERMENT
//
// Faire du jumeau l'autorité SANS que les écrans y écrivent casserait
// l'édition : le registre porterait la valeur figée de la migration, les
// canonicalisations la projetteraient par-dessus la valeur fraîche de l'écran,
// et la personne modifierait son logement sans rien voir changer. Le problème
// des deux autorités, retourné — et bien pire, parce qu'il se manifeste au
// moment exact où quelqu'un essaie de corriger une erreur.
//
// D'où la frontière de commande : les écrans continuent d'appeler
// `writeCanonicalHousing`, et c'est elle qui fait entrer le fait au registre.
//
// L'interrupteur est ÉTEINT par défaut. Le premier oracle vérifie donc que
// rien ne change tant qu'il l'est — c'est la garantie de non-régression pour
// les installations existantes.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_housing_fact.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:mint_mobile/services/twin/answers_twin_backend.dart';
import 'package:mint_mobile/services/twin/housing_twin_command.dart';
import 'package:mint_mobile/services/twin/twin_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int compteur;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    compteur = 0;
    HousingTwinCommand.install(
      store: TwinStore(const AnswersTwinBackend(),
          newId: () => 'v${++compteur}'),
    );
  });

  tearDown(() {
    FeatureFlags.twinOwnsHousing = false;
  });

  MintNextHousingFact logement(int interetCents, {int annee = 2025}) =>
      MintNextHousingFact(
        tenure: PrimaryHomeTenure.ownerOccupier,
        mortgageStatus: HousingMortgageStatus.yes,
        statementAvailability: MortgageStatementAvailability.ready,
        statementYear: annee,
        annualInterestCents: interetCents,
        debtBalanceCents: 50000000,
        assertedAt: DateTime.utc(2026, 8, 14),
        source: MintNextHousingFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  test('with the switch OFF, nothing reaches the twin', () async {
    // La garantie de non-régression : tant que l'interrupteur est éteint, une
    // installation existante se comporte EXACTEMENT comme hier.
    await SecureWizardStore.writeCanonicalHousing(logement(300000));

    final snapshot = await const AnswersTwinBackend().read();
    expect(snapshot.registry, isNull,
        reason: 'aucune écriture ne doit fuir tant que la bascule est éteinte');

    final projete = await SecureWizardStore.canonicalizeHousingAnswers({});
    expect(projete[MintNextHousingFact.annualInterestCentsKey], 300000,
        reason: 'et le coffre reste le répondant');
  });

  test('with the switch ON, the edit wins — even after a restart', () async {
    // L'oracle central. Sans la frontière de commande, la seconde valeur
    // n'atteindrait jamais le registre : le jumeau resterait sur la première
    // et l'écran afficherait un chiffre que la personne vient de corriger.
    FeatureFlags.twinOwnsHousing = true;
    await SecureWizardStore.writeCanonicalHousing(logement(300000));
    await SecureWizardStore.writeCanonicalHousing(logement(425000));

    // On fait DIVERGER les deux magasins, sinon cet oracle ne prouverait rien :
    // le repli rendrait la même réponse que le jumeau, et il passerait aussi
    // bien sans frontière de commande. Ici le coffre repart en arrière — le
    // jumeau, lui, garde la correction.
    FeatureFlags.twinOwnsHousing = false;
    await SecureWizardStore.writeCanonicalHousing(logement(111111));
    FeatureFlags.twinOwnsHousing = true;

    // « Redémarrage » : on relit tout depuis le stockage.
    final answers = await ReportPersistenceService.loadAnswers();

    expect(answers[MintNextHousingFact.annualInterestCentsKey], 425000,
        reason: "c'est le jumeau qui doit répondre, pas le coffre — celui-ci "
            'porte 111 111 et ne doit pas gagner');

    final snapshot = await const AnswersTwinBackend().read();
    expect(snapshot.revision, 2, reason: 'deux déclarations, deux versions');
  });

  test('the correction keeps a history — the first value is not erased',
      () async {
    // C'est toute la raison d'être du registre : « qu'est-ce que MINT savait à
    // ce moment-là » suppose que la valeur d'avant survive.
    FeatureFlags.twinOwnsHousing = true;

    await SecureWizardStore.writeCanonicalHousing(logement(300000));
    await SecureWizardStore.writeCanonicalHousing(logement(425000));

    final store = TwinStore(const AnswersTwinBackend(), newId: () => 'relu');
    final registry = (await store.read()).registry;
    final histoire = registry.history(HousingTwinCommand.registryId);

    expect(histoire.length, 2);
    expect(histoire.first.payload[MintNextHousingFact.annualInterestCentsKey],
        300000, reason: "la valeur d'avant reste lisible");
    expect(histoire.last.payload[MintNextHousingFact.annualInterestCentsKey],
        425000);
  });

  test('the pinned statement year travels in the envelope', () async {
    FeatureFlags.twinOwnsHousing = true;

    await SecureWizardStore.writeCanonicalHousing(logement(425000, annee: 2025));

    final store = TwinStore(const AnswersTwinBackend(), newId: () => 'relu');
    final version = (await store.read())
        .registry
        .current(HousingTwinCommand.registryId)!;

    expect(version.fiscalYear, 2025,
        reason: "une charge appartient à un exercice — c'est l'enveloppe qui "
            'le porte');
    expect(version.payload.containsKey(MintNextHousingFact.assertedAtKey),
        isFalse,
        reason: "les métadonnées n'encombrent pas la charge utile");
  });

  test('a twin write that fails does not lose the declaration', () async {
    // Le coffre a reçu le fait ; le jumeau, non. Perdre la déclaration parce
    // que le second magasin a échoué serait punir la personne pour une panne.
    FeatureFlags.twinOwnsHousing = true;
    SecureWizardStore.twinCommand = (fact) async => throw Exception('panne');

    final ecrit = await SecureWizardStore.writeCanonicalHousing(logement(300000));

    expect(ecrit, isTrue, reason: 'la déclaration est acceptée malgré la panne');
    final projete = await SecureWizardStore.canonicalizeHousingAnswers({});
    expect(projete[MintNextHousingFact.annualInterestCentsKey], 300000,
        reason: 'et le repli répond, ce qui est exactement le cas prévu');
  });
}
