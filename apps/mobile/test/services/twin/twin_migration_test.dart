// La migration des six faits — ce qu'elle doit refuser d'inventer.
//
// Une migration est l'endroit où l'on fabrique des données sans s'en rendre
// compte. Ces oracles vérifient surtout des ABSENCES : pas de date d'effet
// déduite, pas de déclaration inventée pour un fait jamais rempli, pas de
// propriétaire attribué à une clé orpheline.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_domicile_fact.dart';
import 'package:mint_mobile/services/twin/fact_registry.dart';
import 'package:mint_mobile/services/twin/fact_version.dart';
import 'package:mint_mobile/services/twin/twin_migration.dart';

void main() {
  late FactRegistry registry;
  late int counter;
  final migratedAt = DateTime.utc(2026, 8, 13, 12);

  setUp(() {
    counter = 0;
    registry = FactRegistry(newId: () => 'v${++counter}', now: () => migratedAt);
  });

  TwinMigrationReport run(Map<String, dynamic> answers) => TwinMigration.migrate(
        answers: answers,
        registry: registry,
        migratedAt: migratedAt,
      );

  Map<String, dynamic> domicileAnswers({String? assertedAt}) => {
        MintNextDomicileFact.communeNameKey: 'Aarau',
        MintNextDomicileFact.communeBfsKey: 4001,
        MintNextDomicileFact.cantonKey: 'AG',
        MintNextDomicileFact.assertedAtKey:
            assertedAt ?? '2026-08-10T09:00:00.000Z',
        MintNextDomicileFact.sourceKey:
            MintNextDomicileFact.userDeclarationSource,
        MintNextDomicileFact.schemaVersionKey: 1,
        MintNextDomicileFact.needsConfirmationKey: false,
      };

  test('an empty store migrates nothing and fails nothing', () {
    final report = run({});

    expect(report.migrated, isEmpty);
    expect(report.skipped.length, 6, reason: 'les six faits sont absents');
    expect(registry.length, 0);
  });

  test('an existing fact becomes one v1 version', () {
    final report = run(domicileAnswers());

    expect(report.migrated, contains('domicile'));
    expect(registry.length, 1);
    final version = registry.current('domicile')!;
    expect(version.payload[MintNextDomicileFact.communeNameKey], 'Aarau');
    expect(version.payload[MintNextDomicileFact.communeBfsKey], 4001);
  });

  test('NO effective date and NO fiscal year are ever deduced', () {
    // Le cœur de cette migration. Déduire une date d'effet de la date de
    // déclaration aurait été facile — et faux : quelqu'un ayant déclaré son
    // domicile en août n'y habitait pas forcément en janvier.
    final version = (run(domicileAnswers()), registry.current('domicile')!).$2;

    expect(version.effectiveFrom, isNull);
    expect(version.fiscalYear, isNull);
    expect(version.fiscalCoverageUnknown, isTrue);
    expect(version.coversFiscalYear(2026), isFalse,
        reason: 'un fait migré ne répond à aucune question par année');
  });

  test('the original declaration is kept, the migration date is recorded', () {
    run(domicileAnswers(assertedAt: '2026-08-10T09:00:00.000Z'));
    final version = registry.current('domicile')!;

    expect(version.assertedAt, DateTime.utc(2026, 8, 10, 9),
        reason: "ce que la personne a déclaré lui appartient");
    expect(version.recordedAt, migratedAt,
        reason: "c'est aujourd'hui que MINT écrit cette version");
  });

  test('the provenance says the original context is lost', () {
    run(domicileAnswers());

    expect(registry.current('domicile')!.source, FactSource.migratedV1,
        reason: 'ni déclaration fraîche ni document : une valeur héritée');
  });

  test('a declaration dated in the future is clamped, not refused', () {
    // Une horloge d'appareil mal réglée a pu écrire une date future. Le
    // registre refuserait cette version ; la migration ne doit pas échouer
    // pour autant, ni propager une déclaration venue de demain.
    run(domicileAnswers(assertedAt: '2099-01-01T00:00:00.000Z'));

    expect(registry.current('domicile')!.assertedAt, migratedAt);
  });

  test('a missing assertion date falls back to the migration date', () {
    final answers = domicileAnswers()..remove(MintNextDomicileFact.assertedAtKey);
    run(answers);

    expect(registry.current('domicile')!.assertedAt, migratedAt);
  });

  test('a fact with no value is skipped, not written empty', () {
    final report = run({
      MintNextDomicileFact.assertedAtKey: '2026-08-10T09:00:00.000Z',
      MintNextDomicileFact.sourceKey: 'user_declaration',
    });

    expect(report.migrated, isEmpty,
        reason: "des métadonnées sans valeur ne sont pas une déclaration");
    expect(report.skipped, contains('domicile'));
    expect(registry.length, 0);
  });

  test('metadata does not pollute the payload — it becomes the envelope', () {
    run(domicileAnswers());
    final payload = registry.current('domicile')!.payload;

    expect(payload.containsKey(MintNextDomicileFact.assertedAtKey), isFalse);
    expect(payload.containsKey(MintNextDomicileFact.sourceKey), isFalse);
    expect(payload.containsKey(MintNextDomicileFact.schemaVersionKey), isFalse);
    expect(payload.containsKey(MintNextDomicileFact.needsConfirmationKey),
        isFalse);
  });

  test('keys owned by no fact are named, not adopted', () {
    final report = run({
      ...domicileAnswers(),
      'q_une_cle_orpheline': 'valeur',
      'q_autre_orpheline': 42,
    });

    expect(report.orphanKeys, contains('q_une_cle_orpheline'));
    expect(report.orphanKeys, contains('q_autre_orpheline'));
    // Leur inventer un propriétaire serait pire que de les laisser où elles
    // sont — mais les taire en ferait une dette invisible.
    expect(registry.current('domicile')!.payload.containsKey('q_une_cle_orpheline'),
        isFalse);
  });

  test('a null value is not a value', () {
    final report = run({
      ...domicileAnswers(),
      'q_orpheline_nulle': null,
    });

    expect(report.orphanKeys, isNot(contains('q_orpheline_nulle')));
  });

  test('migrating twice would add a second version, not duplicate silently',
      () {
    // Garde-fou : la migration n'est pas idempotente par elle-même. C'est à
    // l'appelant de ne la lancer qu'une fois — et l'oracle le dit, plutôt que
    // de laisser croire le contraire.
    run(domicileAnswers());
    run(domicileAnswers());

    expect(registry.length, 2);
    expect(registry.history('domicile').length, 2);
  });

  test('every declared fact can actually be migrated, not just the single ones',
      () {
    // CE QUE CET ORACLE A ATTRAPÉ, APRÈS COUP
    //
    // Les oracles de migration n'exerçaient que `domicile` — un fait UNIQUE.
    // Quand le contrat est arrivé et a déclaré quatre faits MULTIPLES, la
    // migration a continué de leur donner leur type nu comme identifiant, ce
    // que le contrat refuse : elle levait pour le logement, le revenu, la LPP
    // et les versements 3a. Autrement dit elle plantait sur tout dossier un
    // peu rempli, et rien ne le disait.
    //
    // Le trou n'était pas dans le code : il était dans le CHOIX du cas testé.
    // D'où cet oracle qui parcourt le catalogue au lieu d'en élire un.
    for (final fact in kMigratableFacts) {
      final neuf = FactRegistry(
          newId: () => 'v${++counter}', now: () => migratedAt);
      final answers = <String, dynamic>{
        for (final key in fact.payloadKeys) key: 'valeur',
      };

      final report = TwinMigration.migrate(
        answers: answers,
        registry: neuf,
        migratedAt: migratedAt,
      );

      expect(report.migrated, contains(fact.registryId),
          reason: '${fact.factId} doit pouvoir être migré');
      expect(neuf.current(fact.registryId), isNotNull,
          reason: '${fact.factId} doit être retrouvable sous son identifiant '
              'complet, clé de membre comprise');
    }
  });
}
