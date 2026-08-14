// La transaction du jumeau — ce qu'elle doit garantir.
//
// La relecture du registre avait nommé son manque principal : « une
// persistance durable transactionnelle avec contrôle de concurrence, couplant
// atomiquement l'ajout au registre et la mise à jour de la projection. En
// mémoire, deux processus peuvent perdre une version ou produire deux
// courantes. » Ces oracles vérifient que ce n'est plus le cas.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/twin/fact_version.dart';
import 'package:mint_mobile/services/twin/twin_store.dart';

/// Support en mémoire, avec deux défauts injectables : l'échec d'écriture et
/// l'écriture concurrente.
class _FakeBackend implements TwinBackend {
  String? registry;
  Map<String, Object?> projection = const {};
  int revision = 0;

  int writes = 0;
  int refusals = 0;
  Set<String> lastOwnedKeys = const {};
  bool failNextWrite = false;

  /// Appelé juste avant l'échange — permet de simuler un autre processus qui
  /// écrit entre la lecture de l'appelant et son écriture.
  void Function()? beforeSwap;

  @override
  Future<({String? registry, int revision})> read() async =>
      (registry: registry, revision: revision);

  @override
  Future<bool> compareAndSwap({
    required int expectedRevision,
    required String registry,
    required Map<String, Object?> projection,
    required Set<String> ownedKeys,
  }) async {
    lastOwnedKeys = ownedKeys;
    beforeSwap?.call();
    // La comparaison appartient au support : c'est ce qui la rend atomique.
    if (revision != expectedRevision) {
      refusals++;
      return false;
    }
    writes++;
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('écriture impossible');
    }
    this.registry = registry;
    this.projection = Map<String, Object?>.from(projection);
    revision = expectedRevision + 1;
    return true;
  }
}

void main() {
  late _FakeBackend backend;
  late TwinStore store;
  late int counter;
  final clock = DateTime.utc(2026, 8, 13, 10);

  setUp(() {
    backend = _FakeBackend();
    counter = 0;
    store = TwinStore(backend, newId: () => 'v${++counter}', now: () => clock);
  });

  Future<FactVersion> append(TwinSnapshot snap, String commune) => store.append(
        snap,
        factId: 'domicile',
        factType: 'domicile',
        payload: {'q_domicile_commune_name': commune},
        assertedAt: clock,
        source: FactSource.userDeclaration,
      );

  test('an empty backend reads as an empty twin, not as a failure', () async {
    final snapshot = await store.read();

    expect(snapshot.registry.length, 0);
    expect(snapshot.revision, 0);
  });

  test('one write carries the registry AND its projection', () async {
    final snapshot = await store.read();
    await append(snapshot, 'Aarau');

    expect(backend.writes, 1, reason: 'une seule écriture, pas deux');
    expect(backend.registry, isNotNull);
    expect(backend.projection['q_domicile_commune_name'], 'Aarau',
        reason: 'la projection accompagne le registre dans la même écriture');
    expect(backend.revision, 1);
  });

  test('the projection is derived, never supplied from outside', () async {
    var snapshot = await store.read();
    await append(snapshot, 'Aarau');
    snapshot = await store.read();
    await append(snapshot, 'Lausanne');

    // Deux versions au registre, UNE valeur dans la projection : c'est bien
    // l'état courant qui est projeté, pas un empilement.
    final reloaded = await store.read();
    expect(reloaded.registry.length, 2);
    expect(backend.projection['q_domicile_commune_name'], 'Lausanne');
    expect(backend.projection.length, 1);
    // Et l'instantané de l'appelant, lui, n'a pas bougé : l'écriture s'est
    // préparée sur une copie. C'est ce qui empêche qu'un échec laisse une
    // version fantôme réutilisable.
    expect(snapshot.registry.length, 1);
  });

  test('history survives a reload — the whole point of the exercise', () async {
    var snapshot = await store.read();
    await append(snapshot, 'Aarau');
    snapshot = await store.read();
    await append(snapshot, 'Lausanne');

    final reloaded = await store.read();
    expect(reloaded.registry.length, 2);
    expect(reloaded.registry.current('domicile')!.payload['q_domicile_commune_name'],
        'Lausanne');
    expect(reloaded.registry.history('domicile').first
        .payload['q_domicile_commune_name'], 'Aarau');
  });

  group('concurrence', () {
    test('a write on a stale read is refused, not silently applied', () async {
      final stale = await store.read();

      // Un autre processus écrit entre la lecture et l'écriture.
      final other = await store.read();
      await append(other, 'Genève');

      expect(() => append(stale, 'Aarau'),
          throwsA(isA<TwinConcurrencyException>()),
          reason: 'publier par-dessus perdrait la version de l\'autre');
    });

    test('two writers who BOTH pass their check do not lose a version',
        () async {
      // Le vrai entrelacement, celui que la première version ne voyait pas :
      // A et B lisent la révision 0, A écrit, B écrit. Avec une vérification
      // faite AVANT l'écriture, les deux passaient et la seconde écrasait la
      // première. Avec la comparaison DANS l'écriture, B est refusé.
      final a = await store.read();
      final b = await store.read();

      await append(a, 'Aarau');
      await expectLater(
          append(b, 'Genève'), throwsA(isA<TwinConcurrencyException>()));

      expect(backend.refusals, 1, reason: 'le support a refusé, pas l\'appelant');
      final reloaded = await store.read();
      expect(reloaded.registry.length, 1);
      expect(reloaded.registry.current('domicile')!
          .payload['q_domicile_commune_name'], 'Aarau',
          reason: 'la version de A survit intacte');
    });

    test('a writer overtaken between its check and its write is refused',
        () async {
      final mine = await store.read();

      // Quelqu'un d'autre écrit à l'instant précis où j'allais le faire.
      backend.beforeSwap = () {
        backend.beforeSwap = null;
        backend.revision = 99;
      };

      await expectLater(
          append(mine, 'Aarau'), throwsA(isA<TwinConcurrencyException>()));
      expect(backend.writes, 0, reason: 'aucune écriture n\'a eu lieu');
    });

    test('the refused write leaves the other version intact', () async {
      final stale = await store.read();
      final other = await store.read();
      await append(other, 'Genève');
      final writesBefore = backend.writes;

      try {
        await append(stale, 'Aarau');
      } on TwinConcurrencyException {
        // attendu
      }

      expect(backend.writes, writesBefore, reason: 'rien n\'a été écrit');
      expect(backend.projection['q_domicile_commune_name'], 'Genève');
    });

    test('re-reading after a refusal lets the write succeed', () async {
      final stale = await store.read();
      final other = await store.read();
      await append(other, 'Genève');

      try {
        await append(stale, 'Aarau');
      } on TwinConcurrencyException {
        // La réponse honnête à une écriture concurrente est de relire.
      }
      final fresh = await store.read();
      await append(fresh, 'Aarau');

      final reloaded = await store.read();
      expect(reloaded.registry.length, 2,
          reason: 'les DEUX versions survivent, aucune n\'est perdue');
      expect(reloaded.registry.current('domicile')!
          .payload['q_domicile_commune_name'], 'Aarau');
    });
  });

  group('atomicité', () {
    test('a failed write leaves the backend untouched', () async {
      var snapshot = await store.read();
      await append(snapshot, 'Aarau');

      snapshot = await store.read();
      backend.failNextWrite = true;
      await expectLater(append(snapshot, 'Lausanne'), throwsStateError);

      final reloaded = await store.read();
      expect(reloaded.registry.length, 1,
          reason: 'une écriture ratée ne laisse pas un demi-jumeau');
      expect(reloaded.registry.current('domicile')!
          .payload['q_domicile_commune_name'], 'Aarau');
      expect(backend.projection['q_domicile_commune_name'], 'Aarau',
          reason: 'la projection non plus n\'a pas bougé');
      expect(reloaded.revision, 1);

      // Et surtout : l'instantané de l'appelant n'a PAS été touché. La
      // première version de ce code mutait le registre avant d'écrire ; après
      // un échec, l'appelant gardait une version fantôme.
      expect(snapshot.registry.length, 1,
          reason: 'un échec ne laisse pas de version fantôme en mémoire');
    });

    test('retrying with the same snapshot does not resurrect the failed write',
        () async {
      var snapshot = await store.read();
      await append(snapshot, 'Aarau');

      snapshot = await store.read();
      backend.failNextWrite = true;
      await expectLater(append(snapshot, 'Lausanne'), throwsStateError);

      // Réessai avec le MÊME objet : il ne doit pas persister deux versions,
      // dont une déclarée échouée.
      await append(snapshot, 'Lausanne');

      final reloaded = await store.read();
      expect(reloaded.registry.length, 2,
          reason: 'deux versions au total, pas trois');
      expect(reloaded.registry.current('domicile')!
          .payload['q_domicile_commune_name'], 'Lausanne');
    });

    test('a corrupted registry fails the read rather than returning half a twin',
        () async {
      backend.registry = '[{"factId":"d"}]';
      backend.revision = 3;

      expect(store.read(), throwsFormatException,
          reason: 'un jumeau amputé qui se croit entier est pire qu\'absent');
    });
  });

  test('two different facts both reach the projection', () async {
    var snapshot = await store.read();
    await append(snapshot, 'Aarau');
    snapshot = await store.read();
    await store.append(
      snapshot,
      factId: 'revenu#employeur_principal',
      factType: 'revenu',
      payload: {'q_net_income_monthly': 7000},
      assertedAt: clock,
      source: FactSource.userDeclaration,
    );

    expect(backend.projection['q_domicile_commune_name'], 'Aarau');
    expect(backend.projection['q_net_income_monthly'], 7000);
  });

  group('suppression', () {
    test('removing a fact keeps it in history but out of the projection',
        () async {
      var snapshot = await store.read();
      await append(snapshot, 'Aarau');

      snapshot = await store.read();
      await store.remove(
        snapshot,
        factId: 'domicile',
        factType: 'domicile',
        assertedAt: clock,
        source: FactSource.userDeclaration,
      );

      final reloaded = await store.read();
      expect(reloaded.registry.length, 2,
          reason: 'supprimer AJOUTE une pierre tombale, rien ne s\'efface');
      expect(reloaded.registry.current('domicile')!.isTombstone, isTrue);
      expect(reloaded.registry.history('domicile').first
          .payload['q_domicile_commune_name'], 'Aarau',
          reason: 'la personne a bien déclaré quelque chose un jour');
      expect(backend.projection.containsKey('q_domicile_commune_name'), isFalse,
          reason: 'mais le fait n\'alimente plus ni écran ni calcul');
    });

    test('a removed fact keeps its keys under the twin\'s charge', () async {
      var snapshot = await store.read();
      await append(snapshot, 'Aarau');
      snapshot = await store.read();
      await store.remove(snapshot,
          factId: 'domicile',
          factType: 'domicile',
          assertedAt: clock,
          source: FactSource.userDeclaration);

      expect(backend.lastOwnedKeys, contains('q_domicile_commune_name'),
          reason: 'le support doit savoir quelle valeur retirer — sinon elle '
              'survivrait dans ce que lisent les écrans');
      expect(backend.projection.containsKey('q_domicile_commune_name'), isFalse);
    });

    test('a fact can be declared again after being removed', () async {
      var snapshot = await store.read();
      await append(snapshot, 'Aarau');
      snapshot = await store.read();
      await store.remove(snapshot,
          factId: 'domicile',
          factType: 'domicile',
          assertedAt: clock,
          source: FactSource.userDeclaration);
      snapshot = await store.read();
      await append(snapshot, 'Lausanne');

      final reloaded = await store.read();
      expect(reloaded.registry.length, 3);
      expect(backend.projection['q_domicile_commune_name'], 'Lausanne');
    });
  });

  test('two facts claiming the same key are refused, not silently arbitrated',
      () async {
    var snapshot = await store.read();
    await append(snapshot, 'Aarau');
    snapshot = await store.read();

    // « dernier itéré gagne » écrasait en silence, selon l'ordre d'itération.
    await expectLater(
        store.append(
          snapshot,
          factId: 'revenu#employeur_secondaire',
          factType: 'revenu',
          payload: {'q_domicile_commune_name': 'Genève'},
          assertedAt: clock,
          source: FactSource.userDeclaration,
        ),
        throwsStateError);
  });
}
