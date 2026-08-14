// Ce qui fait entrer une déclaration de logement dans le jumeau.
//
// POURQUOI ICI, ET PAS DANS LE COFFRE
//
// Le coffre ne connaît pas le jumeau, et c'est délibéré : lui donner cette
// dépendance créerait un cycle avec le support, qui a besoin du coffre pour
// sceller le registre. Le coffre expose donc un point d'accroche, et c'est le
// jumeau qui vient s'y brancher — jamais l'inverse.
//
// POURQUOI UNE INSTALLATION EXPLICITE
//
// Elle se voit. Une commande qui s'installerait toute seule à l'import serait
// impossible à désactiver pour un test, et impossible à trouver pour qui
// cherche « qui écrit dans le jumeau ».
//
// ADR : .planning/decisions/2026-08-13-jumeau-financier-faits-versionnes.md

import 'package:mint_mobile/models/mint_next_housing_fact.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:mint_mobile/services/twin/answers_twin_backend.dart';
import 'package:mint_mobile/services/twin/fact_version.dart';
import 'package:mint_mobile/services/twin/twin_store.dart';
import 'package:uuid/uuid.dart';

class HousingTwinCommand {
  const HousingTwinCommand._();

  /// L'identifiant du logement décrit par le magasin plat : la résidence
  /// principale. Le contrat déclare `logement` multiple — la vie l'est — mais
  /// les clés `q_housing_*` n'en décrivent qu'un.
  static const registryId = 'logement#residence_principale';

  /// Branche la commande sur le coffre. À appeler une fois, au démarrage.
  static void install({TwinStore? store}) {
    final twin = store ??
        TwinStore(const AnswersTwinBackend(), newId: const Uuid().v4);
    SecureWizardStore.twinCommand = (fact) => append(twin, fact);
    SecureWizardStore.twinRemoveCommand = () => remove(twin);
  }

  /// Ajoute une version du logement au registre.
  ///
  /// L'échange comparé peut refuser si l'état a bougé : on relit et on
  /// recommence UNE fois. Boucler indéfiniment transformerait une collision en
  /// blocage ; ne pas réessayer du tout perdrait la déclaration au premier
  /// conflit.
  static Future<void> append(TwinStore twin, MintNextHousingFact fact) async {
    for (var essai = 0; essai < 2; essai++) {
      final snapshot = await twin.read();
      try {
        await twin.append(
          snapshot,
          factId: registryId,
          factType: 'logement',
          payload: _payloadOf(fact),
          assertedAt: fact.assertedAt,
          source: fact.source == MintNextHousingFact.userDeclarationSource
              ? FactSource.userDeclaration
              : FactSource.document,
          fiscalYear: fact.statementYear,
          needsConfirmation: fact.needsConfirmation,
          schemaVersion: fact.schemaVersion,
        );
        return;
      } on TwinConcurrencyException {
        if (essai == 1) rethrow;
      }
    }
  }

  /// Pose une pierre tombale sur le logement.
  ///
  /// Rien n'est effacé : la personne a bien déclaré quelque chose un jour, et
  /// l'historique le garde. Mais le fait cesse d'alimenter les écrans et les
  /// calculs.
  static Future<void> remove(TwinStore twin) async {
    for (var essai = 0; essai < 2; essai++) {
      final snapshot = await twin.read();
      // Rien à supprimer : poser une tombe sur un fait qui n'existe pas
      // inventerait une déclaration.
      if (snapshot.registry.current(registryId) == null) return;
      try {
        await twin.remove(
          snapshot,
          factId: registryId,
          factType: 'logement',
          assertedAt: DateTime.now().toUtc(),
          source: FactSource.userDeclaration,
        );
        return;
      } on TwinConcurrencyException {
        if (essai == 1) rethrow;
      }
    }
  }

  /// La charge utile — les valeurs, sans les métadonnées que l'enveloppe porte
  /// déjà, et sans les clés nulles : une clé absente et une clé nulle disent
  /// la même chose, et n'en garder qu'une évite deux façons de dire « rien ».
  static Map<String, Object?> _payloadOf(MintNextHousingFact fact) {
    final answers = fact.toWizardAnswers()
      ..remove(MintNextHousingFact.assertedAtKey)
      ..remove(MintNextHousingFact.sourceKey)
      ..remove(MintNextHousingFact.schemaVersionKey)
      ..remove(MintNextHousingFact.needsConfirmationKey)
      ..removeWhere((_, value) => value == null);
    return answers;
  }
}
