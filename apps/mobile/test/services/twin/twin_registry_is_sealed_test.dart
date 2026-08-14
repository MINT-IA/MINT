// Le registre du jumeau porte la même PII que les faits — il doit être scellé.
//
// CE QUE CES ORACLES ONT ATTRAPÉ
//
// En branchant l'enveloppe, une sonde a montré que cinq des six faits portent
// des clés classées SENSIBLES : état civil, montants de revenu, chiffres
// hypothécaires, avoir LPP, versements 3a. Ces valeurs sont chiffrées dans le
// coffre et remplacées par un jeton dans les préférences en clair.
//
// Le registre, lui, les recopie dans son JSON — et il s'écrivait sous une clé
// que le classificateur ne connaissait pas. La même donnée aurait donc été
// scellée d'un côté et lisible de l'autre. SEC-10 dit exactement l'inverse :
// la PII ne redescend jamais dans les préférences simples.
//
// Rien n'avait fuité — le jumeau n'est branché à aucun écran — mais la porte
// devait être fermée AVANT le premier branchement.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:mint_mobile/services/twin/answers_twin_backend.dart';
import 'package:mint_mobile/services/twin/fact_registry.dart';
import 'package:mint_mobile/services/twin/fact_version.dart';
import 'package:mint_mobile/services/twin/twin_migration.dart';
import 'package:mint_mobile/services/twin/twin_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('the twin carries sensitive values, so its registry must be sealed', () {
    // L'invariant, et non le constat : si un fait porteur de valeurs sensibles
    // peut entrer au registre, le registre doit être scellé. Ajouter demain un
    // septième fait sensible ne rouvrira donc pas la porte en silence.
    final porteurs = [
      for (final fact in kMigratableFacts)
        if (fact.payloadKeys.any(SecureWizardStore.isSensitive)) fact.factId,
    ];

    expect(porteurs, isNotEmpty,
        reason: 'si plus aucun fait ne porte de valeur sensible, cet oracle a '
            'perdu son objet — le relire avant de le supprimer');
    expect(SecureWizardStore.isSensitive(AnswersTwinBackend.registryKey), isTrue,
        reason: 'le registre recopie les valeurs de $porteurs : le laisser en '
            'clair scellerait la donnée d\'un côté et l\'exposerait de l\'autre');
  });

  test('the sealed registry never reaches plain preferences', () async {
    // La preuve par le magasin réel, pas par la classification : ce qui est
    // écrit sur le disque en clair ne doit pas contenir la valeur.
    final registry = FactRegistry(newId: () => 'v1', now: () => _clock);
    registry.append(
      factId: 'etat_civil',
      factType: 'etat_civil',
      payload: {'q_civil_status': 'divorce_en_cours'},
      assertedAt: _clock,
      source: FactSource.userDeclaration,
    );

    await const AnswersTwinBackend().compareAndSwap(
      expectedRevision: 0,
      registry: registry.encode(),
      metadata: const {},
    );

    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);
      expect(value.toString().contains('divorce_en_cours'), isFalse,
          reason: 'la valeur est visible en clair sous « $key »');
    }
    expect(prefs.getBool(AnswersTwinBackend.registryWrittenKey), isTrue,
        reason: "les préférences gardent la TRACE qu'un registre existe, "
            'jamais son contenu');
  });

  test('a sealed registry the vault cannot return is not an empty twin',
      () async {
    // Le pire des deux mondes serait de repartir de zéro : la première
    // écriture recouvrirait une histoire que le coffre finirait par rendre.
    SharedPreferences.setMockInitialValues({
      AnswersTwinBackend.registryWrittenKey: true,
    });

    expect(() => const AnswersTwinBackend().read(),
        throwsA(isA<TwinRegistryUnreadable>()));
  });

  test('two writes launched together do not silently lose one', () async {
    // L'échange comparé lit la révision, la compare, puis écrit — et entre la
    // comparaison et l'écriture il y a des `await`. Lancées ensemble, les deux
    // lisaient la même révision, passaient toutes les deux le test, et la
    // seconde recouvrait la première. Un échange comparé qui ne compare rien.
    const backend = AnswersTwinBackend();

    final resultats = await Future.wait([
      backend.compareAndSwap(
        expectedRevision: 0,
        registry: _registryPortant('premier'),
        metadata: const {},
      ),
      backend.compareAndSwap(
        expectedRevision: 0,
        registry: _registryPortant('second'),
        metadata: const {},
      ),
    ]);

    expect(resultats.where((accepte) => accepte).length, 1,
        reason: 'une seule des deux peut légitimement passer à la révision 1');
    final relu = await backend.read();
    expect(relu.revision, 1, reason: 'et la révision ne saute pas deux crans');
  });

  test('a write never lands on top of a history it cannot read', () async {
    // Le refus vaut aussi à la porte de l'écriture : recouvrir une histoire
    // illisible la détruirait définitivement.
    SharedPreferences.setMockInitialValues({
      AnswersTwinBackend.registryWrittenKey: true,
      AnswersTwinBackend.revisionKey: 3,
    });

    expect(
        () => const AnswersTwinBackend().compareAndSwap(
              expectedRevision: 3,
              registry: _registryPortant('ecrasement'),
              metadata: const {},
            ),
        throwsA(isA<TwinRegistryUnreadable>()));
  });

  test('a corrupted answers store no longer reads as an absent twin', () async {
    // Le magasin de réponses échoue en silence : son JSON illisible rend une
    // carte VIDE. Le registre, lui, est dans le coffre et a survécu. Conclure
    // « pas de jumeau » aurait fait recouvrir une histoire intacte.
    final registry = _registryPortant('divorce_en_cours');
    await const AnswersTwinBackend().compareAndSwap(
      expectedRevision: 0,
      registry: registry,
      metadata: const {},
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wizard_answers_v2', 'ceci n\'est pas du JSON');

    final relu = await const AnswersTwinBackend().read();

    expect(relu.registry, isNotNull,
        reason: "le coffre a gardé l'histoire — la perdre ici serait un choix, "
            'pas une fatalité');
    expect(relu.registry!.contains('divorce_en_cours'), isTrue);
  });

  test('the companion metadata publishes envelopes, never values', () {
    // Elle, en revanche, reste en clair — et cet oracle est la raison pour
    // laquelle elle peut le rester.
    final registry = FactRegistry(newId: () => 'v1', now: () => _clock);
    registry.append(
      factId: 'etat_civil',
      factType: 'etat_civil',
      payload: {'q_civil_status': 'divorce_en_cours'},
      assertedAt: _clock,
      source: FactSource.userDeclaration,
    );

    final publie = TwinStore.metadataOf(registry).toString();

    expect(publie.contains('divorce_en_cours'), isFalse,
        reason: "l'enveloppe dit d'où vient la valeur, jamais laquelle");
    expect(publie.contains('userDeclaration'), isTrue,
        reason: 'mais elle dit bien la provenance');
  });

  test('the answers store still reads back what the twin sealed', () async {
    // Sceller sans savoir relire aurait échangé une fuite contre une perte.
    final registry = FactRegistry(newId: () => 'v1', now: () => _clock);
    registry.append(
      factId: 'etat_civil',
      factType: 'etat_civil',
      payload: {'q_civil_status': 'divorce_en_cours'},
      assertedAt: _clock,
      source: FactSource.userDeclaration,
    );

    await const AnswersTwinBackend().compareAndSwap(
      expectedRevision: 0,
      registry: registry.encode(),
      metadata: const {},
    );

    final relu = await const AnswersTwinBackend().read();

    expect(relu.registry, isNotNull);
    expect(relu.registry!.contains('divorce_en_cours'), isTrue,
        reason: 'le jumeau doit retrouver son histoire intacte');
    expect(relu.revision, 1);
  });
}

final _clock = DateTime.utc(2026, 8, 14, 10);

/// Un registre d'une seule version, portant la valeur donnée.
String _registryPortant(String valeur) {
  final registry = FactRegistry(newId: () => 'v1', now: () => _clock);
  registry.append(
    factId: 'etat_civil',
    factType: 'etat_civil',
    payload: {'q_civil_status': valeur},
    assertedAt: _clock,
    source: FactSource.userDeclaration,
  );
  return registry.encode();
}
