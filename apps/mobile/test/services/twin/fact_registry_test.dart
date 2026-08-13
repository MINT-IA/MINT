// Le registre des versions — ce qu'il doit garantir.
//
// La promesse du jumeau financier tient à une seule chose : écrire un fait
// n'efface pas le précédent. Ces oracles la vérifient, et vérifient surtout ce
// qui la rendrait creuse — une migration qui invente des dates, un chargement
// qui saute une entrée corrompue, une question rétroactive à laquelle on
// répond alors qu'on ne sait pas.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/twin/fact_registry.dart';
import 'package:mint_mobile/services/twin/fact_version.dart';

void main() {
  late int counter;
  late FactRegistry registry;
  late DateTime clock;

  setUp(() {
    counter = 0;
    clock = DateTime.utc(2026, 8, 13, 10);
    registry = FactRegistry(
      newId: () => 'v${++counter}',
      now: () => clock,
    );
  });

  FactVersion appendDomicile(String commune, {DateTime? assertedAt}) =>
      registry.append(
        factId: 'domicile',
        factType: 'domicile',
        payload: {'commune': commune},
        assertedAt: assertedAt ?? clock,
        source: FactSource.userDeclaration,
      ).version;

  test('a second write does not erase the first', () {
    appendDomicile('Aarau');
    clock = DateTime.utc(2026, 9, 1);
    appendDomicile('Lausanne');

    expect(registry.length, 2, reason: "rien n'est écrasé");
    expect(registry.current('domicile')!.payload['commune'], 'Lausanne');
    expect(registry.history('domicile').map((v) => v.payload['commune']),
        ['Aarau', 'Lausanne']);
  });

  test('the superseded version is closed and points to its successor', () {
    final first = appendDomicile('Aarau');
    clock = DateTime.utc(2026, 9, 1);
    final second = appendDomicile('Lausanne');

    final closed = registry.history('domicile').first;
    expect(closed.effectiveTo, isNotNull, reason: 'la précédente est close');
    expect(closed.isCurrent, isFalse);
    expect(second.supersedesVersionId, first.versionId,
        reason: 'chaque version dit ce qu\'elle remplace');
    expect(first.supersedesVersionId, isNull, reason: 'la première ne remplace rien');
  });

  test('what MINT knew at a past moment is answerable', () {
    appendDomicile('Aarau');
    clock = DateTime.utc(2026, 9, 1);
    appendDomicile('Lausanne');

    expect(
        registry.asOf('domicile', DateTime.utc(2026, 8, 20))!.payload['commune'],
        'Aarau',
        reason: "c'est la question qui justifie tout le dispositif");
    expect(
        registry.asOf('domicile', DateTime.utc(2026, 10, 1))!.payload['commune'],
        'Lausanne');
    expect(registry.asOf('domicile', DateTime.utc(2026, 1, 1)), isNull,
        reason: 'MINT ne savait rien avant la première déclaration');
  });

  test('an unknown fact has no current version and no history', () {
    expect(registry.current('revenu'), isNull);
    expect(registry.history('revenu'), isEmpty);
    expect(registry.asOf('revenu', clock), isNull);
  });

  test('the current projection holds one version per fact', () {
    appendDomicile('Aarau');
    registry.append(
      factId: 'revenu',
      factType: 'revenu',
      payload: {'monthly': 7000},
      assertedAt: clock,
      source: FactSource.userDeclaration,
    );
    clock = DateTime.utc(2026, 9, 1);
    appendDomicile('Lausanne');

    final current = registry.currentVersions();
    expect(current.length, 2, reason: 'deux faits, pas trois versions');
    expect(current.map((v) => v.factId).toSet(), {'domicile', 'revenu'});
    // La relecture a trouvé ce test trompeur : il comptait les versions sans
    // vérifier LAQUELLE était courante. Il passait avec Aarau comme version
    // en vigueur, tant que le compte et les identifiants restaient bons.
    expect(
        current.firstWhere((v) => v.factId == 'domicile').payload['commune'],
        'Lausanne');
    expect(current.firstWhere((v) => v.factId == 'revenu').payload['monthly'],
        7000);
  });

  group('le contexte porté par une version', () {
    test('without an effective date, a version covers NO year at all', () {
      // Première version de ce code : la couverture partait de l'année de
      // déclaration. Un domicile déclaré le 31 décembre « couvrait » alors
      // toute l'année écoulée, y compris un calcul de janvier — puis l'année
      // suivante, et la suivante. Le commentaire disait « on ne sait pas »
      // pendant que le code répondait « oui ». Trouvé par la relecture.
      // L'invariant temporel interdit d'enregistrer une déclaration future :
      // on avance donc l'horloge avec elle.
      clock = DateTime.utc(2026, 12, 31);
      final version = registry.append(
        factId: 'domicile',
        factType: 'domicile',
        payload: {'commune': 'Lausanne'},
        assertedAt: DateTime.utc(2026, 12, 31),
        source: FactSource.userDeclaration,
      ).version;

      expect(version.coversFiscalYear(2026), isFalse,
          reason: 'déclarer le 31 décembre ne dit rien de janvier');
      expect(version.coversFiscalYear(2027), isFalse);
      expect(version.fiscalCoverageUnknown, isTrue,
          reason: 'ne pas savoir se distingue de répondre non');
    });

    test('an explicit effective date does give coverage', () {
      final version = registry.append(
        factId: 'domicile',
        factType: 'domicile',
        payload: {'commune': 'Lausanne'},
        assertedAt: clock,
        source: FactSource.userDeclaration,
        effectiveFrom: DateTime.utc(2025, 3, 1),
      ).version;

      expect(version.coversFiscalYear(2024), isFalse);
      expect(version.coversFiscalYear(2025), isTrue);
      expect(version.coversFiscalYear(2026), isTrue);
      expect(version.fiscalCoverageUnknown, isFalse);
    });

    test('a fiscal year, when known, is the only year covered', () {
      final version = registry.append(
        factId: 'housing.interest',
        factType: 'housing',
        payload: {'interestCents': 425000},
        assertedAt: clock,
        source: FactSource.document,
        fiscalYear: 2025,
      ).version;

      expect(version.coversFiscalYear(2025), isTrue);
      expect(version.coversFiscalYear(2026), isFalse,
          reason: 'des intérêts 2025 ne parlent pas de 2026');
    });

    test('a version past its validity says so instead of being recomputed', () {
      final version = registry.append(
        factId: 'revenu',
        factType: 'revenu',
        payload: {'monthly': 7000},
        assertedAt: clock,
        source: FactSource.userDeclaration,
        validUntil: DateTime.utc(2027, 1, 1),
      ).version;

      expect(version.isStaleAt(DateTime.utc(2026, 12, 31)), isFalse);
      expect(version.isStaleAt(DateTime.utc(2027, 2, 1)), isTrue);
    });

    test('a version with no validity limit never goes stale on its own', () {
      expect(appendDomicile('Aarau').isStaleAt(DateTime.utc(2099)), isFalse);
    });
  });

  group('sérialisation', () {
    test('a registry survives a full round trip, history included', () {
      appendDomicile('Aarau');
      clock = DateTime.utc(2026, 9, 1);
      appendDomicile('Lausanne');

      final restored = FactRegistry(newId: () => 'x', now: () => clock)
        ..decode(registry.encode());

      expect(restored.length, 2);
      expect(restored.current('domicile')!.payload['commune'], 'Lausanne');
      expect(
          restored.asOf('domicile', DateTime.utc(2026, 8, 20))!
              .payload['commune'],
          'Aarau',
          reason: "l'historique traverse la sérialisation");
    });

    test('a corrupted entry fails the whole load rather than being skipped',
        () {
      // Sauter une entrée illisible amputerait l'historique en silence, et un
      // historique amputé qui se croit entier est pire que pas d'historique.
      const corrupted = '[{"factId":"domicile","versionId":"v1"}]';
      expect(() => registry.decode(corrupted), throwsFormatException);
    });

    test('nothing is published when the load fails', () {
      appendDomicile('Aarau');
      try {
        registry.decode('[{"factId":"x"}]');
      } on FormatException {
        // attendu
      }
      expect(registry.length, 1,
          reason: 'le registre existant survit à un chargement raté');
      expect(registry.current('domicile')!.payload['commune'], 'Aarau');
    });

    test('an unknown provenance is refused, not defaulted', () {
      const wrongSource = '[{"factId":"d","versionId":"v1","factType":"domicile",'
          '"payload":{},"assertedAt":"2026-08-13T00:00:00Z",'
          '"recordedAt":"2026-08-13T00:00:00Z","source":"telepathie",'
          '"status":"confirmed","schemaVersion":1}]';
      expect(() => registry.decode(wrongSource), throwsFormatException,
          reason: 'une provenance inventée vaut une donnée sans provenance');
    });
  });

  group('migration des faits déjà écrits', () {
    test('a migrated version keeps its assertion but invents no effective date',
        () {
      final migrated = registry.append(
        factId: 'domicile',
        factType: 'domicile',
        payload: {'commune': 'Aarau'},
        assertedAt: DateTime.utc(2026, 8, 10),
        source: FactSource.migratedV1,
      ).version;

      expect(migrated.assertedAt, DateTime.utc(2026, 8, 10),
          reason: 'la déclaration d\'origine est conservée');
      expect(migrated.recordedAt, clock,
          reason: "l'écriture est datée du jour de la migration");
      expect(migrated.effectiveFrom, isNull,
          reason: 'une date d\'effet inconnue reste nulle, jamais fabriquée');
      expect(migrated.fiscalYear, isNull);
      expect(migrated.source, FactSource.migratedV1,
          reason: 'la provenance dit que le contexte d\'origine est perdu');
    });
  });

  group('reçu de calcul', () {
    test('a receipt names the exact versions it consumed', () {
      final domicile = appendDomicile('Aarau');
      final revenu = registry.append(
        factId: 'revenu',
        factType: 'revenu',
        payload: {'monthly': 7000},
        assertedAt: clock,
        source: FactSource.userDeclaration,
      ).version;

      final receipt = CalculationReceipt(
        calculationId: 'c1',
        calculationType: 'impot_communal',
        inputVersionIds: [domicile.versionId, revenu.versionId],
        computedAt: clock,
        rulesetVersion: 'estv-2026',
      );

      // « Quels calculs dépendent de ce fait ? » est une requête sur les
      // reçus, pas un tableau inverse maintenu dans le fait.
      expect(receipt.consumed(domicile.versionId), isTrue);
      expect(receipt.consumed('inconnue'), isFalse);
      expect(receipt.rulesetVersion, 'estv-2026',
          reason: 'un même intrant donne deux résultats si le barème change');
    });
  });

  group('invariants temporels', () {
    test('a clock going backwards is refused, not recorded', () {
      appendDomicile('Aarau');
      clock = DateTime.utc(2026, 8, 13, 9);
      expect(() => appendDomicile('Lausanne'), throwsStateError,
          reason: 'une version close avant son ouverture est impossible');
    });

    test('a declaration made tomorrow is refused', () {
      expect(
          () => appendDomicile('Aarau',
              assertedAt: DateTime.utc(2026, 8, 14)),
          throwsStateError,
          reason: "MINT n'enregistre pas aujourd'hui ce qui sera dit demain");
    });

    test('two writes at the same instant stay ordered by rank', () {
      // L'horodatage ne suffit pas : au millième de seconde, ou dans un test
      // qui fige le temps, deux écritures partagent la même horloge.
      final first = appendDomicile('Aarau');
      final second = appendDomicile('Lausanne');

      expect(second.sequence, greaterThan(first.sequence));
      expect(registry.asOf('domicile', clock)!.payload['commune'], 'Lausanne',
          reason: 'à instant égal, la dernière écrite fait foi');
    });
  });

  group('un registre incoherent ne se charge pas', () {
    String entry({
      int sequence = 0,
      String versionId = 'v1',
      String factId = 'domicile',
      String factType = 'domicile',
      String? effectiveTo,
      String? supersedes,
    }) =>
        '{"sequence":$sequence,"factId":"$factId","versionId":"$versionId",'
        '"factType":"$factType","payload":{"commune":"Aarau"},'
        '"assertedAt":"2026-08-13T00:00:00Z","recordedAt":"2026-08-13T00:00:00Z",'
        '"source":"userDeclaration","status":"confirmed","schemaVersion":1'
        '${effectiveTo == null ? '' : ',"effectiveTo":"$effectiveTo"'}'
        '${supersedes == null ? '' : ',"supersedesVersionId":"$supersedes"'}}';

    test('two current versions of the same fact are refused', () {
      expect(
          () => registry.decode(
              '[${entry(sequence: 0, versionId: 'v1')},'
              '${entry(sequence: 1, versionId: 'v2')}]'),
          throwsFormatException);
    });

    test('a duplicated version identifier is refused', () {
      expect(
          () => registry.decode('[${entry(sequence: 0, versionId: 'v1', effectiveTo: '2026-09-01T00:00:00Z')},'
              '${entry(sequence: 1, versionId: 'v1')}]'),
          throwsFormatException);
    });

    test('a broken succession chain is refused', () {
      expect(
          () => registry.decode('[${entry(supersedes: 'fantome')}]'),
          throwsFormatException,
          reason: 'remplacer une version absente rend l\'histoire illisible');
    });

    test('a fact changing its type is refused', () {
      expect(
          () => registry.decode(
              '[${entry(sequence: 0, versionId: 'v1', effectiveTo: '2026-09-01T00:00:00Z')},'
              '${entry(sequence: 1, versionId: 'v2', factType: 'revenu')}]'),
          throwsFormatException);
    });

    test('an unknown field is refused rather than ignored', () {
      const withExtra = '[{"sequence":0,"factId":"d","versionId":"v1",'
          '"factType":"domicile","payload":{},"inconnu":1,'
          '"assertedAt":"2026-08-13T00:00:00Z","recordedAt":"2026-08-13T00:00:00Z",'
          '"source":"userDeclaration","status":"confirmed","schemaVersion":1}]';
      expect(() => registry.decode(withExtra), throwsFormatException,
          reason: "un champ inconnu vient d'un autre logiciel ou d'une corruption");
    });

    test('a nested payload is refused — scalars only was a promise', () {
      const nested = '[{"sequence":0,"factId":"d","versionId":"v1",'
          '"factType":"domicile","payload":{"adresse":{"rue":"x"}},'
          '"assertedAt":"2026-08-13T00:00:00Z","recordedAt":"2026-08-13T00:00:00Z",'
          '"source":"userDeclaration","status":"confirmed","schemaVersion":1}]';
      expect(() => registry.decode(nested), throwsFormatException);
    });

    test('an inverted interval is refused', () {
      const inverted = '[{"sequence":0,"factId":"d","versionId":"v1",'
          '"factType":"domicile","payload":{},'
          '"effectiveFrom":"2026-09-01T00:00:00Z","effectiveTo":"2026-08-01T00:00:00Z",'
          '"assertedAt":"2026-08-13T00:00:00Z","recordedAt":"2026-08-13T00:00:00Z",'
          '"source":"userDeclaration","status":"confirmed","schemaVersion":1}]';
      expect(() => registry.decode(inverted), throwsFormatException);
    });

    test('a declaration recorded before it was made is refused', () {
      const backwards = '[{"sequence":0,"factId":"d","versionId":"v1",'
          '"factType":"domicile","payload":{},'
          '"assertedAt":"2026-09-01T00:00:00Z","recordedAt":"2026-08-13T00:00:00Z",'
          '"source":"userDeclaration","status":"confirmed","schemaVersion":1}]';
      expect(() => registry.decode(backwards), throwsFormatException);
    });
  });

  test('a refusal message names the offending value, not the source code', () {
    // Les messages de diagnostic portaient un dollar ÉCHAPPÉ : ils auraient
    // affiché « version « ${v.versionId} » en double » au lieu de la valeur.
    // Le gate d'analyse statique l'a signalé sous forme d'avertissement de
    // performance — le vrai défaut était ailleurs, dans ce que la personne qui
    // débogue aurait lu.
    const duplicate = '[{"sequence":0,"factId":"d","versionId":"CONFLIT",'
        '"factType":"domicile","payload":{},'
        '"assertedAt":"2026-08-13T00:00:00Z","recordedAt":"2026-08-13T00:00:00Z",'
        '"source":"userDeclaration","status":"confirmed","schemaVersion":1,'
        '"effectiveTo":"2026-09-01T00:00:00Z"},'
        '{"sequence":1,"factId":"d","versionId":"CONFLIT",'
        '"factType":"domicile","payload":{},'
        '"assertedAt":"2026-08-13T00:00:00Z","recordedAt":"2026-08-13T00:00:00Z",'
        '"source":"userDeclaration","status":"confirmed","schemaVersion":1}]';

    expect(
        () => registry.decode(duplicate),
        throwsA(isA<FormatException>().having(
            (e) => e.message, 'message', contains('CONFLIT'))),
        reason: 'le message doit nommer la version fautive');
  });
}
