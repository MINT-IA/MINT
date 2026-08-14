// Le branchement du jumeau sur le magasin réel.
//
// Deux garanties se jouent ici, et aucune n'est visible dans les couches
// au-dessus : ce qui n'appartient pas au jumeau doit SURVIVRE à ses écritures,
// et la valeur d'un fait supprimé doit DISPARAÎTRE de ce que lisent les
// écrans.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/twin/answers_twin_backend.dart';
import 'package:mint_mobile/services/twin/fact_version.dart';
import 'package:mint_mobile/services/twin/twin_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TwinStore store;
  late int counter;
  final clock = DateTime.utc(2026, 8, 13, 10);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    counter = 0;
    store = TwinStore(const AnswersTwinBackend(),
        newId: () => 'v${++counter}', now: () => clock);
  });

  Future<void> appendCommune(String commune) async {
    final snapshot = await store.read();
    await store.append(
      snapshot,
      factId: 'domicile',
      factType: 'domicile',
      payload: {'q_domicile_commune_name': commune},
      assertedAt: clock,
      source: FactSource.userDeclaration,
    );
  }

  test('a fact written through the twin lands in the answers the screens read',
      () async {
    await appendCommune('Aarau');

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_domicile_commune_name'], 'Aarau',
        reason: 'la projection EST le magasin — rien ne casse pour les écrans');
  });

  test('history survives a full round trip through the real store', () async {
    await appendCommune('Aarau');
    await appendCommune('Lausanne');

    final reloaded = await store.read();
    expect(reloaded.registry.length, 2);
    expect(reloaded.registry.history('domicile').first
        .payload['q_domicile_commune_name'], 'Aarau');
    expect(reloaded.registry.current('domicile')!
        .payload['q_domicile_commune_name'], 'Lausanne');
  });

  test('answers owned by nobody survive the twin writing', () async {
    await ReportPersistenceService.saveAnswers({
      'q_une_reponse_ancienne': 'à conserver',
      'q_birth_year': 1988,
    });

    await appendCommune('Aarau');

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_une_reponse_ancienne'], 'à conserver',
        reason: 'effacer au passage détruirait ce que personne n\'a demandé '
            'de supprimer');
    expect(answers['q_birth_year'], 1988);
    expect(answers['q_domicile_commune_name'], 'Aarau');
  });

  test('a removed fact disappears from what the screens read', () async {
    await appendCommune('Aarau');

    final snapshot = await store.read();
    await store.remove(
      snapshot,
      factId: 'domicile',
      factType: 'domicile',
      assertedAt: clock,
      source: FactSource.userDeclaration,
    );

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers.containsKey('q_domicile_commune_name'), isFalse,
        reason: 'sans ce retrait, le fait serait supprimé pour le registre '
            'et bien présent pour les écrans');

    // Mais il reste dans l'historique : la personne a bien déclaré quelque
    // chose un jour.
    final reloaded = await store.read();
    expect(reloaded.registry.history('domicile').length, 2);
    expect(reloaded.registry.current('domicile')!.isTombstone, isTrue);
  });

  test('the twin never writes into the answers store', () async {
    // Cet oracle affirmait l'inverse : registre et revision vivaient dans le
    // MEME objet que les valeurs, pour qu'ils s'ecrivent ensemble ou pas du
    // tout. Deux constats ont retire sa raison d'etre a ce choix — la
    // projection est desormais DERIVEE a chaque chargement, donc une
    // divergence se repare seule ; et ce couplage aurait fabrique une
    // recurrence le jour ou une ecriture d'ecran appellera le jumeau.
    await appendCommune('Aarau');

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers.containsKey(AnswersTwinBackend.registryKey), isFalse,
        reason: 'le registre vit dans le coffre, pas dans les reponses');
    expect(answers.containsKey(AnswersTwinBackend.revisionKey), isFalse,
        reason: 'la revision a sa propre entree de preferences');
    expect(answers['q_domicile_commune_name'], 'Aarau',
        reason: 'et la valeur atteint quand meme les ecrans — par derivation');
  });

  test('a second writer on a stale read is refused by the real store',
      () async {
    final a = await store.read();
    final b = await store.read();

    await store.append(a,
        factId: 'domicile',
        factType: 'domicile',
        payload: {'q_domicile_commune_name': 'Aarau'},
        assertedAt: clock,
        source: FactSource.userDeclaration);

    await expectLater(
        store.append(b,
            factId: 'domicile',
            factType: 'domicile',
            payload: {'q_domicile_commune_name': 'Genève'},
            assertedAt: clock,
            source: FactSource.userDeclaration),
        throwsA(isA<TwinConcurrencyException>()));

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_domicile_commune_name'], 'Aarau',
        reason: 'la première écriture survit intacte');
  });

  test('an empty store reads as an empty twin', () async {
    final snapshot = await store.read();

    expect(snapshot.registry.length, 0);
    expect(snapshot.revision, 0);
  });

  test('the envelope survives in its own entry, beside the value', () async {
    final snapshot = await store.read();
    await store.append(
      snapshot,
      factId: 'domicile',
      factType: 'domicile',
      payload: {'q_domicile_commune_name': 'Aarau'},
      assertedAt: clock,
      source: FactSource.document,
      status: FactStatus.estimated,
      needsConfirmation: true,
    );

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers['q_domicile_commune_name'], 'Aarau',
        reason: 'les écrans lisent la valeur exactement comme avant');

    final prefs = await SharedPreferences.getInstance();
    final meta = (json.decode(prefs.getString(AnswersTwinBackend.metadataKey)!)
        as Map)['q_domicile_commune_name'] as Map;
    expect(meta['source'], 'document', reason: 'la provenance survit');
    expect(meta['status'], 'estimated', reason: 'la confiance survit');
    expect(meta['needsConfirmation'], isTrue,
        reason: "un chiffre en attente de confirmation ne doit pas être "
            "présenté comme su");
    expect(meta['versionId'], isNotNull,
        reason: 'et l\'on peut remonter à la version exacte');
  });
}
