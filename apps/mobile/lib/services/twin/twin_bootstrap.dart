// Le moment où le jumeau devient réel — une fois, et seulement une fois.
//
// CE QUE CETTE AMORCE DOIT ABSOLUMENT ÉVITER
//
// La migration N'EST PAS idempotente : la relancer ajouterait une seconde
// version de chaque fait, en prétendant que la personne a redéclaré ce qu'elle
// avait déjà dit. L'histoire s'inventerait toute seule.
//
// La garde n'est donc pas un drapeau qu'on pourrait oublier de poser : c'est
// l'existence du registre lui-même. S'il porte déjà quelque chose, il n'y a
// rien à migrer. S'il est ILLISIBLE — scellé mais que le coffre ne rend pas —
// la lecture LÈVE, et rien ne s'écrit : recouvrir une histoire qu'on ne sait
// pas lire la détruirait définitivement.
//
// ET CE QU'ELLE NE MIGRE PAS
//
// Uniquement les faits dotés d'une frontière de commande. Les canonicalisations
// lisent le jumeau inconditionnellement : dès qu'un fait entre au registre,
// c'est lui qui répond. Un fait migré mais que les écrans ne savent pas écrire
// serait donc GELÉ — modifié à l'écran, inchangé à l'affichage. Le pire des
// symptômes, parce qu'il frappe au moment exact où quelqu'un corrige une
// erreur.
//
// ADR : .planning/decisions/2026-08-13-jumeau-financier-faits-versionnes.md

import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/twin/twin_migration.dart';
import 'package:mint_mobile/services/twin/twin_store.dart';

class TwinBootstrap {
  const TwinBootstrap._();

  /// Les faits que l'on sait AUSSI écrire — donc les seuls qu'on ait le droit
  /// de migrer. La liste grandit avec les frontières de commande, jamais avant.
  static Set<String> get commandableFacts =>
      FeatureFlags.twinOwnsHousing ? const {'logement'} : const {};

  /// Fait entrer l'existant dans le registre, une seule fois.
  ///
  /// Rend le compte rendu, ou null s'il n'y avait rien à faire — registre déjà
  /// peuplé, ou aucun fait commandable.
  static Future<TwinMigrationReport?> ensureMigrated({
    required TwinStore store,
    required DateTime migratedAt,
  }) async {
    final scope = commandableFacts;
    if (scope.isEmpty) return null;

    // Lève si le registre existe mais reste illisible. On ne rattrape pas :
    // repartir de zéro écraserait l'histoire au premier ajout.
    final snapshot = await store.read();
    if (snapshot.registry.length > 0) return null;

    final report = TwinMigration.migrate(
      answers: await ReportPersistenceService.loadAnswers(),
      registry: snapshot.registry,
      migratedAt: migratedAt,
      only: scope,
    );
    // Rien à envelopper : ne pas écrire un registre vide. Il resterait vide,
    // mais il marquerait le jumeau comme « déjà migré » — et la déclaration
    // que la personne fera demain ne serait jamais reprise.
    if (report.migrated.isEmpty) return report;

    await store.publish(snapshot);
    return report;
  }
}
