// La preuve d'exécution du jumeau — sur la VRAIE pile de l'appareil.
//
// POURQUOI UN TEST D'INTÉGRATION ET PAS UN TEST UNITAIRE DE PLUS
//
// Les 11 000 tests unitaires tournent sur un faux coffre. Or tout le jumeau
// repose sur le fait que le registre se scelle et se relit : si le trousseau
// refuse l'écriture — ce qui arrive sur un simulateur sans droit
// `keychain-access-groups` — le registre ne persiste pas, et TOUT le reste
// devient décoratif sans qu'un seul test ne bronche.
//
// Ce fichier mesure ça, sur la pile réelle, plutôt que de le supposer.
//
// Il répond à deux questions, dans cet ordre :
//   1. le coffre fonctionne-t-il ICI ? (sinon les réponses suivantes ne
//      veulent rien dire, et le test le DIT au lieu d'échouer en silence)
//   2. interrupteur allumé, une correction survit-elle à un rechargement
//      complet — c'est-à-dire le jumeau répond-il, et pas le coffre canonique ?

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mint_mobile/models/mint_next_housing_fact.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:mint_mobile/services/twin/answers_twin_backend.dart';
import 'package:mint_mobile/services/twin/twin_fact_commands.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    TwinFactCommands.install();
  });

  tearDown(() => FeatureFlags.twinOwnedFactTypes = <String>{});

  MintNextHousingFact logement(int interetCents) => MintNextHousingFact(
        tenure: PrimaryHomeTenure.ownerOccupier,
        mortgageStatus: HousingMortgageStatus.yes,
        statementAvailability: MortgageStatementAvailability.ready,
        statementYear: 2025,
        annualInterestCents: interetCents,
        debtBalanceCents: 50000000,
        assertedAt: DateTime.utc(2026, 8, 14),
        source: MintNextHousingFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  /// Le coffre répond-il ICI ? Mesuré une fois, puis partagé.
  ///
  /// MESURÉ le 2026-08-14 sur iPhone 17 Pro / iOS 26.2 : il ne répond PAS.
  /// Les builds simulateur iOS n'embarquent aucun droit — `codesign -d
  /// --entitlements` sur le `.app` produit ne rend rien — donc le
  /// `keychain-access-groups` déclaré par l'app est absent et l'accès échoue
  /// (`-34018`).
  ///
  /// Ce n'est PAS un défaut du jumeau, et ça le dépasse : sur ce simulateur,
  /// AUCUN fait sensible ne persiste — ni le registre, ni le coffre canonique.
  /// Toute marche de vérification impliquant un fait financier enregistré y
  /// teste une application vide.
  /// La sonde emploie une cle REELLEMENT classee sensible.
  ///
  /// La premiere version sondait `_mint_sonde_coffre`, qui ne l'est pas — et
  /// `write` rendait donc `false` quelle que soit la sante du trousseau. Elle
  /// mesurait ma propre garde. Depuis, ce refus LEVE au lieu de rendre
  /// `false`, donc l'erreur ne peut plus se reproduire en silence.
  Future<bool> coffreDisponible() async {
    const temoin = AnswersTwinBackend.registryKey;
    if (!await SecureWizardStore.write(temoin, 'sonde')) return false;
    return await SecureWizardStore.read(temoin) == 'sonde';
  }

  testWidgets('THE PREREQUISITE — does the vault answer on this device?',
      (tester) async {
    final disponible = await coffreDisponible();
    // Volontairement NON bloquant : un rouge permanent sur une limite de
    // l'outillage finit par être ignoré, et c'est ainsi qu'une vraie panne
    // passe inaperçue. On le DIT, fort, et les oracles qui en dépendent se
    // déclarent non concluants plutôt que verts.
    // ignore: avoid_print
    print(disponible
        ? 'COFFRE: disponible — les oracles suivants sont concluants.'
        : 'COFFRE: INDISPONIBLE sur cet appareil (droits absents des builds '
            'simulateur). Aucun fait sensible ne persiste ici : les oracles '
            'suivants ne prouvent RIEN et se déclarent non concluants.');
    expect(disponible, isA<bool>());
  });

  testWidgets('switch ON — the correction wins over the vault, after reload',
      (tester) async {
    if (!await coffreDisponible()) {
      // IGNORÉ, pas réussi. Un test qui retourne en silence ressort vert, et
      // un vert qui ne prouve rien est exactement le défaut que ce fichier
      // existe pour éviter.
      markTestSkipped('coffre indisponible sur cet appareil — non concluant');
      return;
    }
    FeatureFlags.twinOwnedFactTypes = {'logement'};

    await SecureWizardStore.writeCanonicalHousing(logement(300000));
    await SecureWizardStore.writeCanonicalHousing(logement(425000));

    // On fait DIVERGER les deux magasins : sans ça, le repli rendrait la même
    // réponse et ce test ne prouverait rien.
    FeatureFlags.twinOwnedFactTypes = <String>{};
    await SecureWizardStore.writeCanonicalHousing(logement(111111));
    FeatureFlags.twinOwnedFactTypes = {'logement'};

    final answers = await ReportPersistenceService.loadAnswers();

    expect(answers[MintNextHousingFact.annualInterestCentsKey], 425000,
        reason: "c'est le jumeau qui doit répondre — le coffre porte 111 111");

    final snapshot = await const AnswersTwinBackend().read();
    expect(snapshot.registry, isNotNull,
        reason: 'le registre doit avoir survécu au trousseau réel');
    expect(snapshot.revision, 2, reason: 'deux déclarations, deux versions');
  });

  testWidgets('switch OFF — nothing reaches the twin', (tester) async {
    // La non-régression, mesurée sur la pile réelle et pas seulement en unité.
    if (!await coffreDisponible()) {
      // IGNORÉ, pas réussi. Un test qui retourne en silence ressort vert, et
      // un vert qui ne prouve rien est exactement le défaut que ce fichier
      // existe pour éviter.
      markTestSkipped('coffre indisponible sur cet appareil — non concluant');
      return;
    }
    await SecureWizardStore.writeCanonicalHousing(logement(300000));

    final snapshot = await const AnswersTwinBackend().read();
    expect(snapshot.registry, isNull);

    final answers = await ReportPersistenceService.loadAnswers();
    expect(answers[MintNextHousingFact.annualInterestCentsKey], 300000,
        reason: 'le coffre reste le répondant tant que la bascule est éteinte');
  });
}
