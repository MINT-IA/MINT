// Le contrat canonique des faits — ce qu'il rend impossible.
//
// Une relecture avait posé le constat qui bloquait la suite : trois comptes
// 3a, deux hypothèques, plusieurs employeurs étaient IMPOSSIBLES. Sous un
// identifiant unique, chaque écriture remplaçait la précédente ; sous des
// identités inventées au vol, la projection levait un conflit. Pluralité
// théorique dans le registre, écrasement ou exception dans le produit.
//
// Ces oracles vérifient que le contrat ferme les deux portes.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/twin/fact_contract.dart';
import 'package:mint_mobile/services/twin/fact_registry.dart';
import 'package:mint_mobile/services/twin/fact_version.dart';

void main() {
  late FactRegistry registry;
  late int counter;
  final clock = DateTime.utc(2026, 8, 13, 10);

  setUp(() {
    counter = 0;
    registry = FactRegistry(newId: () => 'v${++counter}', now: () => clock);
  });

  void append(String factId, String factType, Map<String, Object?> payload) =>
      registry.append(
        factId: factId,
        factType: factType,
        payload: payload,
        assertedAt: clock,
        source: FactSource.userDeclaration,
      );

  group('cardinalité', () {
    test('three 3a accounts coexist, each with its own history', () {
      // Le cas que la doctrine réclame — « répartir plusieurs comptes 3a » —
      // et qui était impossible avant ce contrat.
      append('versements_3a#banque_a', 'versements_3a', {'cents': 300000});
      append('versements_3a#banque_b', 'versements_3a', {'cents': 200000});
      append('versements_3a#assurance_c', 'versements_3a', {'cents': 150000});

      expect(registry.currentVersions().length, 3,
          reason: 'trois comptes, pas un qui écrase les deux autres');
      append('versements_3a#banque_a', 'versements_3a', {'cents': 350000});
      expect(registry.currentVersions().length, 3,
          reason: 'mettre à jour un compte ne touche pas les autres');
      expect(registry.current('versements_3a#banque_b')!.payload['cents'],
          200000);
      expect(registry.history('versements_3a#banque_a').length, 2,
          reason: 'chaque compte garde SA propre histoire');
    });

    test('a single fact refuses a member key', () {
      // En accepter une ferait coexister deux domiciles fiscaux.
      expect(() => append('domicile#principal', 'domicile', {'commune': 'x'}),
          throwsStateError);
    });

    test('a multiple fact refuses to exist without a member key', () {
      // Sans clé, chaque nouveau compte remplacerait le précédent — le
      // défaut exact que ce contrat existe pour fermer.
      expect(() => append('versements_3a', 'versements_3a', {'cents': 1}),
          throwsStateError);
    });

    test('a fact type outside the catalogue cannot exist', () {
      expect(() => append('cryptomonnaie', 'cryptomonnaie', {'x': 1}),
          throwsStateError,
          reason: "sinon chaque ecran inventerait son propre identifiant");
    });
  });

  group('le catalogue déclare ce qui compte', () {
    test('every declared fact says how its members are identified', () {
      for (final contract in FactContracts.all) {
        expect(contract.identityRule, isNotEmpty,
            reason: '${contract.factType} doit dire ce qui distingue un membre');
        expect(contract.identityRule.length, greaterThan(10),
            reason: '${contract.factType} : une règle d\'identité doit être '
                'lisible, pas un mot');
      }
    });

    test('facts that can be several are declared as such', () {
      // Ce sont exactement ceux que la vie rend multiples.
      for (final type in ['versements_3a', 'logement', 'revenu',
        'lpp_affiliation']) {
        expect(FactContracts.of(type)!.isMultiple, isTrue,
            reason: '$type peut exister en plusieurs exemplaires');
      }
      for (final type in ['domicile', 'etat_civil']) {
        expect(FactContracts.of(type)!.isMultiple, isFalse,
            reason: "$type n'existe qu'en un exemplaire à la fois");
      }
    });

    test('a fiscal-year fact is declared as such, not as an interval', () {
      // Des intérêts appartiennent à un exercice ; un domicile vaut sur une
      // période. Les confondre ferait reporter une charge d'une année sur
      // l'autre.
      expect(FactContracts.of('logement')!.temporality,
          FactTemporality.fiscalYear);
      expect(FactContracts.of('versements_3a')!.temporality,
          FactTemporality.fiscalYear);
      expect(FactContracts.of('domicile')!.temporality,
          FactTemporality.interval);
    });

    test('what has no object for someone is declared, so it is never asked',
        () {
      final lpp = FactContracts.of('lpp_affiliation')!;
      expect(lpp.applicability, isNotNull,
          reason: "un independant non affilie ne doit pas se voir demander "
              "sa caisse de pension");
    });
  });

  group('les états de connaissance', () {
    test('a null field distinguished none of these five', () {
      // « inconnu » appelle une collecte ; « confirmé absent » est une
      // RÉPONSE et le redemander serait une relance ; « sans objet » ne se
      // demande jamais ; « périmé » appelle une mise à jour, pas une première
      // question ; « à confirmer » n'alimente aucun calcul.
      expect(FactKnowledge.values.length, 6);
      expect(FactKnowledge.values, contains(FactKnowledge.confirmedAbsent));
      expect(FactKnowledge.values, contains(FactKnowledge.notApplicable));
      expect(FactKnowledge.values, contains(FactKnowledge.stale));
      expect(FactKnowledge.values, contains(FactKnowledge.toConfirm));
    });
  });

  group('construction des identifiants', () {
    test('the contract builds the identifier, so no screen invents one', () {
      final compte = FactContracts.of('versements_3a')!;
      expect(compte.factIdFor(memberKey: 'banque_a'), 'versements_3a#banque_a');

      final domicile = FactContracts.of('domicile')!;
      expect(domicile.factIdFor(), 'domicile');
    });

    test('a member key containing the reserved separator is refused', () {
      // Sinon l'identifiant deviendrait ambigu.
      expect(
          () => FactContracts.of('versements_3a')!
              .factIdFor(memberKey: 'banque#a'),
          throwsArgumentError);
    });

    test('the type and member can always be read back', () {
      expect(FactContracts.typeOf('versements_3a#banque_a'), 'versements_3a');
      expect(FactContracts.memberOf('versements_3a#banque_a'), 'banque_a');
      expect(FactContracts.typeOf('domicile'), 'domicile');
      expect(FactContracts.memberOf('domicile'), isNull);
    });
  });

  test('a stored registry violating the contract fails to load', () {
    // Le contrat vaut aussi au chargement : un registre écrit par une version
    // antérieure, ou corrompu, ne doit pas entrer par la porte de derrière.
    const withoutMember = '[{"sequence":0,"factId":"versements_3a",'
        '"versionId":"v1","factType":"versements_3a","payload":{},'
        '"assertedAt":"2026-08-13T00:00:00Z","recordedAt":"2026-08-13T00:00:00Z",'
        '"source":"userDeclaration","status":"confirmed","schemaVersion":1}]';
    expect(() => registry.decode(withoutMember), throwsFormatException);
  });
}
