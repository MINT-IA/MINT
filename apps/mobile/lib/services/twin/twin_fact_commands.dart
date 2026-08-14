// Ce qui fait entrer une déclaration dans le jumeau — pour TOUS les faits.
//
// POURQUOI UNE SEULE COMMANDE, ET PAS UNE PAR FAIT
//
// La première version était écrite pour le logement seul. La répliquer cinq
// fois aurait multiplié par cinq les occasions de diverger : cinq conversions
// à tenir, cinq gardes de drapeau, cinq `try`/`catch`, cinq endroits où
// oublier la suppression — l'oubli exact que le lot précédent a dû réparer.
//
// Or le jumeau sait déjà convertir dans les deux sens : `kMigratableFacts`
// pour l'aller, `TwinFactLookup` pour le retour. La commande n'a donc besoin
// que du TYPE et des réponses ; le reste se déduit du catalogue.
//
// POURQUOI ICI, ET PAS DANS LE COFFRE
//
// Le coffre ne connaît pas le jumeau, et c'est délibéré : lui donner cette
// dépendance créerait un cycle avec le support, qui a besoin du coffre pour
// sceller le registre. Le coffre expose un point d'accroche, et c'est le
// jumeau qui vient s'y brancher — jamais l'inverse.
//
// ADR : .planning/decisions/2026-08-13-jumeau-financier-faits-versionnes.md

import 'package:mint_mobile/models/mint_next_versements_3a_fact.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:mint_mobile/services/twin/answers_twin_backend.dart';
import 'package:mint_mobile/services/twin/fact_version.dart';
import 'package:mint_mobile/services/twin/twin_migration.dart';
import 'package:mint_mobile/services/twin/twin_store.dart';
import 'package:mint_mobile/services/twin/versements_3a_decomposition.dart';
import 'package:uuid/uuid.dart';

class TwinFactCommands {
  const TwinFactCommands._();

  /// Branche les commandes sur le coffre. À appeler une fois, au démarrage.
  static void install({TwinStore? store}) {
    final twin = store ??
        TwinStore(const AnswersTwinBackend(), newId: const Uuid().v4);
    SecureWizardStore.twinSave = (type, answers) => save(twin, type, answers);
    SecureWizardStore.twinRemove = (type) => remove(twin, type);
  }

  /// L'identifiant d'un fait au registre, membre de projection compris.
  static String? registryIdOf(String factType) {
    for (final fact in kMigratableFacts) {
      if (fact.factId == factType) return fact.registryId;
    }
    return null;
  }

  /// Ajoute une version du fait au registre.
  ///
  /// L'échange comparé peut refuser si l'état a bougé : on relit et on
  /// recommence UNE fois. Boucler indéfiniment transformerait une collision en
  /// blocage ; ne pas réessayer du tout perdrait la déclaration au premier
  /// conflit.
  static Future<void> save(
      TwinStore twin, String factType, Map<String, dynamic> answers) async {
    // Les versements 3a ne s'enveloppent pas : ils se DÉCOMPOSENT, un fait par
    // versement. Et ils se RÉCONCILIENT — réécrire toutes les entrées à chaque
    // sauvegarde remplirait l'histoire de chaque versement de « corrections »
    // que personne n'a faites.
    if (factType == Versements3aDecomposition.factType) {
      await _saveVersements3a(twin, answers);
      return;
    }

    final fact = _factOf(factType);
    if (fact == null) return;

    final payload = <String, Object?>{};
    for (final key in fact.payloadKeys) {
      final value = answers[key];
      if (value != null) payload[key] = value;
    }
    // Ce que l'enveloppe porte n'encombre pas la charge utile — sinon la même
    // information existerait à deux endroits, et divergerait un jour.
    payload.remove(fact.fiscalYearKey);
    // Aucune valeur : écrire une version vide inventerait une déclaration.
    if (payload.isEmpty) return;

    for (var essai = 0; essai < 2; essai++) {
      final snapshot = await twin.read();
      try {
        await twin.append(
          snapshot,
          factId: fact.registryId,
          factType: factType,
          payload: payload,
          assertedAt: _assertedAt(answers, fact),
          // L'année fiscale voyage dans l'ENVELOPPE — la version spécifique au
          // logement le faisait, la générique l'avait perdu. Le catalogue dit
          // maintenant quelle clé la porte, pour ne plus avoir à deviner.
          fiscalYear: fact.fiscalYearKey == null
              ? null
              : answers[fact.fiscalYearKey] is int
                  ? answers[fact.fiscalYearKey] as int
                  : null,
          source: FactSource.userDeclaration,
          needsConfirmation: answers[fact.needsConfirmationKey] == true,
          schemaVersion:
              answers[fact.schemaVersionKey] is int
                  ? answers[fact.schemaVersionKey] as int
                  : 1,
        );
        return;
      } on TwinConcurrencyException {
        if (essai == 1) rethrow;
      }
    }
  }

  static Future<void> _saveVersements3a(
      TwinStore twin, Map<String, dynamic> answers) async {
    final declare = MintNextVersements3aFact.fromWizardAnswers(answers);
    if (declare == null) return;

    for (var essai = 0; essai < 2; essai++) {
      final snapshot = await twin.read();
      final draft = snapshot.registry.clone();
      await Versements3aDecomposition.reconcile(
        declare,
        registry: draft,
        source: FactSource.userDeclaration,
      );
      // Rien n'a bougé : ne pas écrire pour ne rien dire.
      if (draft.length == snapshot.registry.length) return;
      if (await twin.publish(
          TwinSnapshot(registry: draft, revision: snapshot.revision))) {
        return;
      }
      if (essai == 1) throw TwinConcurrencyException(snapshot.revision, -1);
    }
  }

  /// Pose une pierre tombale sur le fait.
  ///
  /// Rien n'est effacé : la personne a bien déclaré quelque chose un jour, et
  /// l'historique le garde. Mais le fait cesse d'alimenter écrans et calculs.
  static Future<void> remove(TwinStore twin, String factType) async {
    // Supprimer les versements 3a, c'est poser une tombe sur CHACUN d'eux :
    // il n'y a pas un identifiant unique à enterrer.
    if (factType == Versements3aDecomposition.factType) {
      await _saveVersements3a(twin, <String, dynamic>{
        MintNextVersements3aFact.entriesKey: const <dynamic>[],
        MintNextVersements3aFact.bucketRevisionsKey: const <String, dynamic>{},
        MintNextVersements3aFact.assertedAtKey:
            DateTime.now().toUtc().toIso8601String(),
        MintNextVersements3aFact.sourceKey:
            MintNextVersements3aFact.userDeclarationSource,
        MintNextVersements3aFact.schemaVersionKey: 1,
        MintNextVersements3aFact.needsConfirmationKey: false,
      });
      return;
    }

    final registryId = registryIdOf(factType);
    if (registryId == null) return;

    for (var essai = 0; essai < 2; essai++) {
      final snapshot = await twin.read();
      // Rien à supprimer : poser une tombe sur un fait qui n'existe pas
      // inventerait une déclaration.
      if (snapshot.registry.current(registryId) == null) return;
      try {
        await twin.remove(
          snapshot,
          factId: registryId,
          factType: factType,
          assertedAt: DateTime.now().toUtc(),
          source: FactSource.userDeclaration,
        );
        return;
      } on TwinConcurrencyException {
        if (essai == 1) rethrow;
      }
    }
  }

  static MigratableFact? _factOf(String factType) {
    for (final fact in kMigratableFacts) {
      if (fact.factId == factType) return fact;
    }
    return null;
  }

  /// La déclaration d'origine si le fait la porte, sinon maintenant — et
  /// jamais une date postérieure à l'écriture, que le registre refuse.
  static DateTime _assertedAt(
      Map<String, dynamic> answers, MigratableFact fact) {
    final now = DateTime.now().toUtc();
    final declared =
        DateTime.tryParse(answers[fact.assertedAtKey]?.toString() ?? '');
    if (declared == null || declared.toUtc().isAfter(now)) return now;
    return declared.toUtc();
  }
}
