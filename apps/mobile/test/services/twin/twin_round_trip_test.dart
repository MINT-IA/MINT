// L'ALLER-RETOUR : ce qu'un écran sauvegarde doit ressortir identique.
//
// LE DÉFAUT QUE CET ORACLE EXISTE POUR EMPÊCHER
//
// L'année fiscale a été déplacée dans l'enveloppe et RETIRÉE de la charge
// utile — sans que le chemin retour la remette. Elle se perdait donc en
// silence : l'attestation ne disait plus de quel exercice elle parlait, et la
// déduction hypothécaire n'atteignait plus aucun calcul.
//
// Aucun test unitaire ne l'a vu, parce que chacun s'arrêtait avant le tronçon
// suivant : l'un vérifiait que la commande écrit bien l'enveloppe, l'autre que
// la projection relit bien la charge utile. Le défaut était dans la JOINTURE.
//
// Cet oracle ferme la jointure, et il le fait pour CHAQUE fait du catalogue —
// pas seulement pour celui qui a saigné. Un septième fait héritera de la
// vérification sans que personne y pense.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_civil_status_fact.dart';
import 'package:mint_mobile/models/mint_next_domicile_fact.dart';
import 'package:mint_mobile/models/mint_next_housing_fact.dart';
import 'package:mint_mobile/models/mint_next_lpp_affiliation_fact.dart';
import 'package:mint_mobile/models/mint_next_revenu_fact.dart';
import 'package:mint_mobile/services/twin/fact_registry.dart';
import 'package:mint_mobile/services/twin/fact_version.dart';
import 'package:mint_mobile/services/twin/twin_fact_lookup.dart';
import 'package:mint_mobile/services/twin/twin_migration.dart';

void main() {
  /// Un jeu de réponses représentatif par fait — VALEURS et métadonnées.
  final exemples = <String, Map<String, dynamic>>{
    'domicile': {
      MintNextDomicileFact.communeNameKey: 'Aarau',
      MintNextDomicileFact.communeBfsKey: 4001,
      MintNextDomicileFact.assertedAtKey: '2026-08-01T00:00:00.000Z',
      MintNextDomicileFact.sourceKey: 'user_declaration',
      MintNextDomicileFact.schemaVersionKey: 1,
      MintNextDomicileFact.needsConfirmationKey: false,
    },
    'etat_civil': {
      MintNextCivilStatusFact.statusKey: 'divorce',
      MintNextCivilStatusFact.assertedAtKey: '2026-08-01T00:00:00.000Z',
      MintNextCivilStatusFact.sourceKey: 'user_declaration',
      MintNextCivilStatusFact.schemaVersionKey: 1,
      MintNextCivilStatusFact.needsConfirmationKey: false,
    },
    'revenu': {
      MintNextRevenuFact.amountCentsKey: 950000,
      MintNextRevenuFact.periodKey: 'monthly',
      MintNextRevenuFact.assertedAtKey: '2026-08-01T00:00:00.000Z',
      MintNextRevenuFact.sourceKey: 'user_declaration',
      MintNextRevenuFact.schemaVersionKey: 1,
      MintNextRevenuFact.needsConfirmationKey: false,
    },
    'logement': {
      MintNextHousingFact.tenureKey: 'owner_occupier',
      MintNextHousingFact.mortgageStatusKey: 'yes',
      MintNextHousingFact.annualInterestCentsKey: 425000,
      // La clé qui a saigné : elle vit dans l'enveloppe, et doit revenir.
      MintNextHousingFact.statementYearKey: 2025,
      MintNextHousingFact.assertedAtKey: '2026-08-01T00:00:00.000Z',
      MintNextHousingFact.sourceKey: 'user_declaration',
      MintNextHousingFact.schemaVersionKey: 1,
      MintNextHousingFact.needsConfirmationKey: false,
    },
    'lpp_affiliation': {
      MintNextLppAffiliationFact.valueKey: true,
      MintNextLppAffiliationFact.assertedAtKey: '2026-08-01T00:00:00.000Z',
      MintNextLppAffiliationFact.sourceKey: 'user_declaration',
      MintNextLppAffiliationFact.schemaVersionKey: 1,
      MintNextLppAffiliationFact.needsConfirmationKey: false,
    },
  };

  test('every catalogued fact has a representative example', () {
    // Sans ça, ajouter un fait au catalogue le ferait échapper à
    // la vérification en silence — l'oubli exact que cet oracle combat.
    for (final fact in kMigratableFacts) {
      expect(exemples.containsKey(fact.factId), isTrue,
          reason: '${fact.factId} doit avoir un exemple, sinon son '
              'aller-retour n\'est jamais vérifié');
    }
  });

  for (final fact in kMigratableFacts) {
    test('${fact.factId} — what a screen saves comes back identical', () {
      final entrant = exemples[fact.factId]!;

      // ALLER : ce que la commande écrit — charge utile et enveloppe.
      final registry = FactRegistry(newId: () => 'v1');
      final payload = <String, Object?>{};
      for (final key in fact.payloadKeys) {
        final value = entrant[key];
        if (value != null) payload[key] = value;
      }
      payload.remove(fact.fiscalYearKey);
      registry.append(
        factId: fact.registryId,
        factType: fact.factId,
        payload: payload,
        assertedAt: DateTime.parse(entrant[fact.assertedAtKey] as String),
        source: FactSource.userDeclaration,
        fiscalYear: fact.fiscalYearKey == null
            ? null
            : entrant[fact.fiscalYearKey] as int?,
        needsConfirmation: entrant[fact.needsConfirmationKey] == true,
        schemaVersion: entrant[fact.schemaVersionKey] as int,
      );

      // RETOUR : ce que la projection rend aux écrans.
      final sortant = TwinFactLookup.decode(registry.encode())
          .forFact(fact.registryId)
          .wizardAnswers!;

      for (final key in entrant.keys) {
        expect(sortant[key], entrant[key],
            reason: '« $key » ne fait pas l\'aller-retour pour '
                '${fact.factId} — une valeur qui se perd entre l\'écriture et '
                'la relecture ne se voit dans AUCUN test qui ne fait que '
                'l\'un des deux');
      }
    });
  }
}
