// Un fait par versement — la pluralité que la doctrine réclame.
//
// CE QUI ÉTAIT IMPOSSIBLE
//
// Les versements 3a vivaient comme une LISTE dans une seule clé. Corriger un
// versement réécrivait la liste entière, donc l'histoire de tous les autres
// avec. « Répartir plusieurs comptes 3a » — l'exemple même que la doctrine
// donne — ne pouvait pas exister : il n'y avait qu'un seul fait, remplacé à
// chaque mutation.
//
// CE QUE LA DÉCOMPOSITION A RÉVÉLÉ
//
// Chaque versement portait déjà tout ce qu'il fallait : un identifiant stable,
// une année fiscale épinglée, une date de crédit. Deux de ces champs
// appartiennent à l'ENVELOPPE, pas à la charge utile — l'enveloppe des seize
// champs cesse ici d'être une promesse.
//
// Et la révision par année, jusque-là tenue à la main avec un compteur de
// renfort, se DÉRIVE des identités de version.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_versements_3a_fact.dart';
import 'package:mint_mobile/services/twin/fact_registry.dart';
import 'package:mint_mobile/services/twin/fact_version.dart';
import 'package:mint_mobile/services/twin/versements_3a_decomposition.dart';

void main() {
  final horloge = DateTime.utc(2026, 8, 14, 10);
  late FactRegistry registry;
  late int compteur;

  setUp(() {
    compteur = 0;
    registry = FactRegistry(newId: () => 'v${++compteur}', now: () => horloge);
  });

  MintNextVersement3aEntry versement(
    String id,
    int centimes,
    int annee, {
    int mois = 3,
    String? compte,
  }) =>
      MintNextVersement3aEntry(
        id: id,
        amountCents: centimes,
        creditedAt: DateTime.utc(annee, mois, 15),
        taxYear: annee,
        accountRef: compte,
      );

  MintNextVersements3aFact faitAvec(List<MintNextVersement3aEntry> entries) =>
      MintNextVersements3aFact(
        entries: entries,
        bucketRevisions: const {},
        assertedAt: horloge,
        source: MintNextVersements3aFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  void eclater(MintNextVersements3aFact fait) =>
      Versements3aDecomposition.decompose(
        fait,
        registry: registry,
        source: FactSource.userDeclaration,
      );

  MintNextVersements3aFact? recomposer() => Versements3aDecomposition.recompose(
        registry,
        source: MintNextVersements3aFact.userDeclarationSource,
        schemaVersion: 1,
      );

  group('chaque versement devient un fait, avec sa propre histoire', () {
    test('three payments across two accounts coexist', () {
      // « Répartir plusieurs comptes 3a » — l'exemple de la doctrine, et ce
      // qui était impossible tant que la liste était le fait.
      eclater(faitAvec([
        versement('p1', 300000, 2025, compte: 'banque_a'),
        versement('p2', 200000, 2025, compte: 'banque_b'),
        versement('p3', 150000, 2026, compte: 'banque_a'),
      ]));

      expect(registry.currentVersions().length, 3);
      expect(registry.current('versements_3a#p2')!.payload['amount_cents'],
          200000);
    });

    test('correcting one payment leaves the others untouched', () {
      // Le cœur du problème : la liste réécrivait tout. Ici, l'histoire de p1
      // s'allonge et celle de p2 ne bouge pas d'une ligne.
      eclater(faitAvec([
        versement('p1', 300000, 2025),
        versement('p2', 200000, 2025),
      ]));
      final avantP2 = registry.current('versements_3a#p2')!.versionId;

      eclater(faitAvec([versement('p1', 350000, 2025)]));

      expect(registry.history('versements_3a#p1').length, 2,
          reason: 'le versement corrigé garde SON histoire');
      expect(registry.history('versements_3a#p2').length, 1,
          reason: "corriger l'un ne doit rien écrire sur l'autre");
      expect(registry.current('versements_3a#p2')!.versionId, avantP2,
          reason: "et son identité de version ne doit pas bouger non plus");
    });

    test('the pinned tax year and credit date live in the ENVELOPE', () {
      // Pas dans la charge utile : c'est ce que l'enveloppe existe pour
      // porter, et c'est ce qui permet de répondre par année sans deviner.
      eclater(faitAvec([versement('p1', 300000, 2025, mois: 11)]));

      final version = registry.current('versements_3a#p1')!;

      expect(version.fiscalYear, 2025);
      expect(version.effectiveFrom, DateTime.utc(2025, 11, 15));
      expect(version.payload.containsKey('tax_year'), isFalse,
          reason: "l'année fiscale n'a rien à faire dans la charge utile");
      expect(version.payload.containsKey('credited_at'), isFalse);
    });

    test('a buyback pinned to an earlier year keeps its own year', () {
      // Depuis 2026 un rachat peut viser une année antérieure : la date de
      // crédit ne détermine plus seule l'année fiscale. Les confondre
      // déplacerait une déduction d'un exercice à l'autre.
      eclater(faitAvec([
        MintNextVersement3aEntry(
          id: 'rachat',
          amountCents: 500000,
          creditedAt: DateTime.utc(2026, 2, 10),
          taxYear: 2025,
        ),
      ]));

      final version = registry.current('versements_3a#rachat')!;

      expect(version.fiscalYear, 2025,
          reason: "l'année épinglée gagne sur la date de crédit");
      expect(version.effectiveFrom!.year, 2026);
    });
  });

  group('le fait agrégé se reconstitue à l\'identique', () {
    test('what goes in comes back out', () {
      final origine = faitAvec([
        versement('p1', 300000, 2025, compte: 'banque_a'),
        versement('p2', 200000, 2026),
      ]);
      eclater(origine);

      final relu = recomposer()!;

      expect(relu.entries.length, 2);
      expect(relu.entryById('p1')!.amountCents, 300000);
      expect(relu.entryById('p1')!.accountRef, 'banque_a');
      expect(relu.entryById('p2')!.accountRef, isNull,
          reason: 'un versement sans compte ne doit pas en inventer un');
      expect(relu.totalForYearCents(2025), 300000);
      expect(relu.totalForYearCents(2026), 200000,
          reason: "le total par année est la VUE qui nourrit la déduction");
    });

    test('an empty registry is an absence, not an empty declaration', () {
      // « Je n'ai rien versé » est une réponse ; « je n'ai jamais rien dit »
      // n'en est pas une. Les confondre relancerait quelqu'un qui a répondu.
      expect(recomposer(), isNull);
    });

    test('deleting every payment is an ANSWER, not a silence', () {
      // « J'ai tout supprimé » et « je n'ai jamais rien dit » ne s'écrivent
      // pas pareil. Les confondre relancerait quelqu'un qui a répondu — et
      // rendrait la main au magasin canonique périmé.
      eclater(faitAvec([versement('p1', 300000, 2025)]));
      registry.append(
        factId: 'versements_3a#p1',
        factType: 'versements_3a',
        payload: const {},
        assertedAt: horloge,
        source: FactSource.userDeclaration,
        status: FactStatus.deleted,
      );

      final relu = recomposer();

      expect(relu, isNotNull,
          reason: 'le fait EXISTE — il ne porte simplement plus de versement');
      expect(relu!.entries, isEmpty);
      expect(relu.totalForYearCents(2025), 0);
    });

    test('a deleted payment leaves the total, and the others', () {
      eclater(faitAvec([
        versement('p1', 300000, 2025),
        versement('p2', 200000, 2025),
      ]));
      registry.append(
        factId: 'versements_3a#p1',
        factType: 'versements_3a',
        payload: const {},
        assertedAt: horloge,
        source: FactSource.userDeclaration,
        status: FactStatus.deleted,
      );

      final relu = recomposer()!;

      expect(relu.entryById('p1'), isNull);
      expect(relu.totalForYearCents(2025), 200000,
          reason: 'un versement supprimé ne compte plus dans la déduction');
      expect(relu.entries.length, 1);
    });

    test('an unreadable payment is refused, never silently dropped', () {
      // Le laisser tomber ferait disparaître un montant du total, donc de la
      // déduction fiscale, sans que rien ne le dise. Une déduction qui
      // rétrécit toute seule est le pire des silences.
      registry.append(
        factId: 'versements_3a#casse',
        factType: 'versements_3a',
        payload: const {'amount_cents': 100000},
        assertedAt: horloge,
        source: FactSource.userDeclaration,
        // ni année fiscale ni date de crédit
      );

      expect(recomposer, throwsFormatException);
    });
  });

  group('la révision annuelle se dérive au lieu de se tenir à la main', () {
    test('touching 2025 does not invalidate 2026', () {
      // L'invariant que le compteur de mutations tentait de garantir par
      // discipline : corriger 2025 ne doit jamais périmer le contexte 2026.
      eclater(faitAvec([
        versement('p1', 300000, 2025),
        versement('p2', 200000, 2026),
      ]));
      final avant = Versements3aDecomposition.bucketRevisionsOf(registry);

      eclater(faitAvec([versement('p1', 350000, 2025)]));
      final apres = Versements3aDecomposition.bucketRevisionsOf(registry);

      expect(apres[2025], isNot(avant[2025]),
          reason: "l'année touchée doit se périmer");
      expect(apres[2026], avant[2026],
          reason: "et l'autre année ne doit surtout pas bouger");
    });

    test('two corrections at the same instant produce different revisions', () {
      // L'horodatage seul ne suffisait pas — d'où le compteur de mutations.
      // L'identité de version le règle par construction.
      eclater(faitAvec([versement('p1', 300000, 2025)]));
      final r1 = Versements3aDecomposition.bucketRevisionsOf(registry)[2025];

      eclater(faitAvec([versement('p1', 310000, 2025)]));
      final r2 = Versements3aDecomposition.bucketRevisionsOf(registry)[2025];

      eclater(faitAvec([versement('p1', 320000, 2025)]));
      final r3 = Versements3aDecomposition.bucketRevisionsOf(registry)[2025];

      expect({r1, r2, r3}.length, 3,
          reason: 'trois mutations à la même seconde, trois révisions');
    });

    test('deleting a payment invalidates its year', () {
      // La suppression doit périmer l'année : `max(date)` des versements
      // restants ne l'aurait pas fait.
      eclater(faitAvec([
        versement('p1', 300000, 2025),
        versement('p2', 200000, 2025),
      ]));
      final avant = Versements3aDecomposition.bucketRevisionsOf(registry)[2025];

      registry.append(
        factId: 'versements_3a#p2',
        factType: 'versements_3a',
        payload: const {},
        assertedAt: horloge,
        source: FactSource.userDeclaration,
        status: FactStatus.deleted,
      );

      expect(Versements3aDecomposition.bucketRevisionsOf(registry)[2025],
          isNot(avant));
    });

    test('an untouched year has no revision at all', () {
      eclater(faitAvec([versement('p1', 300000, 2025)]));

      expect(Versements3aDecomposition.bucketRevisionsOf(registry)[2030],
          isNull,
          reason: 'une année jamais touchée ne doit pas exister dans la table');
    });
  });
}
