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
  bool failNextWrite = false;

  /// Appelé juste avant chaque lecture — permet de simuler un autre processus
  /// qui écrit entre la lecture de l'appelant et son écriture.
  void Function()? beforeRead;

  @override
  Future<({String? registry, int revision})> read() async {
    beforeRead?.call();
    return (registry: registry, revision: revision);
  }

  @override
  Future<void> write({
    required String registry,
    required Map<String, Object?> projection,
    required int revision,
  }) async {
    writes++;
    if (failNextWrite) {
      failNextWrite = false;
      // Atomique : après un échec, le support garde son état précédent.
      throw StateError('écriture impossible');
    }
    this.registry = registry;
    this.projection = Map<String, Object?>.from(projection);
    this.revision = revision;
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
    expect(snapshot.registry.length, 2);
    expect(backend.projection['q_domicile_commune_name'], 'Lausanne');
    expect(backend.projection.length, 1);
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
      factId: 'revenu',
      factType: 'revenu',
      payload: {'q_net_income_monthly': 7000},
      assertedAt: clock,
      source: FactSource.userDeclaration,
    );

    expect(backend.projection['q_domicile_commune_name'], 'Aarau');
    expect(backend.projection['q_net_income_monthly'], 7000);
  });
}
