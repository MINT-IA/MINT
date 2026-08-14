// Le jumeau devient l'autorité — et le coffre canonique n'est plus qu'un repli.
//
// CE QUI ÉTAIT CASSÉ
//
// `canonicalizeXAnswers()` RETIRAIT les clés du fait de ce qu'on lui donnait,
// puis les réécrivait depuis le magasin canonique chiffré. Une valeur projetée
// par le jumeau était donc systématiquement écrasée : deux autorités
// coexistaient, et la mauvaise gagnait. Le jumeau ne pouvait pas posséder les
// faits qu'il est censé posséder.
//
// POURQUOI TROIS ÉTATS ET PAS DEUX
//
// Renverser simplement l'ordre ne suffisait pas. Avec « le jumeau a une
// valeur » / « il n'en a pas », une SUPPRESSION serait retombée dans le second
// cas et le repli sur le magasin canonique aurait ressuscité le fait au
// chargement suivant. Le repli n'est donc autorisé que pour un fait que le
// jumeau n'a JAMAIS connu.
//
// Ces quatre oracles sont exactement les quatre cas.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_3a_tax_boundary.dart';
import 'package:mint_mobile/models/mint_next_civil_status_fact.dart';
import 'package:mint_mobile/models/mint_next_housing_fact.dart';
import 'package:mint_mobile/models/mint_next_lpp_affiliation_fact.dart';
import 'package:mint_mobile/models/mint_next_revenu_fact.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:mint_mobile/services/twin/answers_twin_backend.dart';
import 'package:mint_mobile/services/twin/fact_registry.dart';
import 'package:mint_mobile/services/twin/fact_version.dart';
import 'package:mint_mobile/models/mint_next_versements_3a_fact.dart';
import 'package:mint_mobile/services/twin/twin_migration.dart';
import 'package:mint_mobile/services/twin/versements_3a_decomposition.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  /// Le fait tel que le coffre canonique le porte aujourd'hui.
  MintNextHousingFact canonique({int interet = 300000}) => MintNextHousingFact(
        tenure: PrimaryHomeTenure.ownerOccupier,
        mortgageStatus: HousingMortgageStatus.yes,
        statementAvailability: MortgageStatementAvailability.ready,
        statementYear: 2024,
        annualInterestCents: interet,
        debtBalanceCents: 50000000,
        assertedAt: DateTime.utc(2025, 3, 1),
        source: MintNextHousingFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  /// Scelle un registre portant une version de `logement`.
  Future<void> scellerRegistre({required bool supprime}) async {
    final registry = FactRegistry(newId: () => 'v1', now: () => _horloge);
    registry.append(
      factId: 'logement#residence_principale',
      factType: 'logement',
      payload: supprime
          ? const {}
          : const {
              MintNextHousingFact.tenureKey: 'owner_occupier',
              MintNextHousingFact.mortgageStatusKey: 'yes',
              MintNextHousingFact.annualInterestCentsKey: 425000,
              MintNextHousingFact.statementYearKey: 2025,
            },
      assertedAt: _horloge,
      source: FactSource.userDeclaration,
      status: supprime ? FactStatus.deleted : FactStatus.confirmed,
    );
    await SecureWizardStore.write(
        AnswersTwinBackend.registryKey, registry.encode());
  }

  test('a living twin fact wins over a diverging canonical store', () async {
    // Le cas central. Les deux magasins portent le même fait avec des chiffres
    // différents ; c'est le jumeau qui doit sortir.
    await SecureWizardStore.writeCanonicalHousing(canonique());
    await scellerRegistre(supprime: false);

    final projete = await SecureWizardStore.canonicalizeHousingAnswers({});

    expect(projete[MintNextHousingFact.annualInterestCentsKey], 425000,
        reason: "le jumeau porte 4 250 CHF, le coffre canonique 3 000 — sans "
            "cette règle c'est l'ancien magasin qui gagnait");
    expect(projete[MintNextHousingFact.statementYearKey], 2025);
    expect(projete[MintNextHousingFact.sourceKey], 'user_declaration',
        reason: 'la provenance fait bien l\'aller-retour');
  });

  test('a twin that never knew the fact changes nothing', () async {
    // La garantie de non-régression : une installation sans jumeau doit se
    // comporter EXACTEMENT comme avant.
    await SecureWizardStore.writeCanonicalHousing(canonique());

    final projete = await SecureWizardStore.canonicalizeHousingAnswers({});

    expect(projete[MintNextHousingFact.annualInterestCentsKey], 300000,
        reason: 'sans registre, le magasin canonique reste le répondant');
    expect(projete[MintNextHousingFact.statementYearKey], 2024);
  });

  test('a deleted twin fact is never resurrected by the fallback', () async {
    // Le piège que le lookup à deux états aurait laissé ouvert : la pierre
    // tombale serait retombée dans « le jumeau n'a rien », et le repli aurait
    // rendu le fait supprimé.
    await SecureWizardStore.writeCanonicalHousing(canonique());
    await scellerRegistre(supprime: true);

    final projete = await SecureWizardStore.canonicalizeHousingAnswers({});

    expect(projete.containsKey(MintNextHousingFact.annualInterestCentsKey),
        isFalse,
        reason: 'un fait supprimé qui revient est pire que jamais supprimé');
    expect(projete.keys.any(MintNextHousingFact.wizardKeys.contains), isFalse,
        reason: 'aucune clé du fait ne survit à sa suppression');
  });

  test('two successive loads project the very same map', () async {
    // Une projection qui bouge entre deux chargements identiques trahirait un
    // effet de bord — typiquement une réécriture du repli par-dessus le jumeau.
    await SecureWizardStore.writeCanonicalHousing(canonique());
    await scellerRegistre(supprime: false);

    final premier = await SecureWizardStore.canonicalizeHousingAnswers({});
    final second = await SecureWizardStore.canonicalizeHousingAnswers({});

    expect(second, equals(premier));
  });

  group('les quatre autres faits, et surtout leurs purges propres', () {
    /// Scelle un registre portant une version de n'importe quel fait.
    Future<void> sceller(
      String registryId,
      String factType,
      Map<String, Object?> payload, {
      bool supprime = false,
    }) async {
      final registry = FactRegistry(newId: () => 'v1', now: () => _horloge);
      registry.append(
        factId: registryId,
        factType: factType,
        payload: supprime ? const {} : payload,
        assertedAt: _horloge,
        source: FactSource.userDeclaration,
        status: supprime ? FactStatus.deleted : FactStatus.confirmed,
      );
      await SecureWizardStore.write(
          AnswersTwinBackend.registryKey, registry.encode());
    }

    test('civil status — the twin wins, and its legacy alias is purged',
        () async {
      // L'alias hérité est le vrai piège : sans sa purge, le profil du coach
      // ressuscite l'ancien état civil par `q_civil_status_choice`. Cette
      // purge n'existe QUE dans la branche « supprimé » du fait — la pierre
      // tombale du jumeau doit donc la déclencher, pas la contourner.
      await SecureWizardStore.writeCanonicalCivilStatus(
        MintNextCivilStatusFact(
          status: MintNextCivilStatus.marie,
          assertedAt: DateTime.utc(2025, 3, 1),
          source: 'user_declaration',
          schemaVersion: 1,
          needsConfirmation: false,
        ),
      );
      await sceller('etat_civil', 'etat_civil',
          {MintNextCivilStatusFact.statusKey: 'divorce'});

      final vivant =
          await SecureWizardStore.canonicalizeCivilStatusAnswers({});
      expect(vivant[MintNextCivilStatusFact.statusKey], 'divorce',
          reason: 'le jumeau dit divorcé, le coffre dit marié');

      await sceller('etat_civil', 'etat_civil', const {}, supprime: true);
      final supprime = await SecureWizardStore.canonicalizeCivilStatusAnswers(
          {MintNextCivilStatusFact.legacyChoiceKey: 'marie'});

      expect(supprime.containsKey(MintNextCivilStatusFact.statusKey), isFalse);
      expect(supprime.containsKey(MintNextCivilStatusFact.legacyChoiceKey),
          isFalse,
          reason: "l'alias hérité doit partir avec le fait, sinon le profil "
              "ressuscite l'ancien état civil");
    });

    test('income — the twin wins, and its legacy projection follows', () async {
      // Le revenu projette DEUX clés héritées en plus des siennes. Recopier la
      // projection à la main les aurait laissées périmées ; c'est le modèle
      // qui les produit.
      await SecureWizardStore.writeCanonicalRevenu(
        MintNextRevenuFact(
          amountCents: 700000,
          period: MintNextRevenuPeriod.monthly,
          assertedAt: DateTime.utc(2025, 3, 1),
          source: 'user_declaration',
          schemaVersion: 1,
          needsConfirmation: false,
        ),
      );
      await sceller('revenu#principal', 'revenu', {
        MintNextRevenuFact.amountCentsKey: 950000,
        MintNextRevenuFact.periodKey: 'monthly',
      });

      final projete = await SecureWizardStore.canonicalizeRevenuAnswers({});

      expect(projete[MintNextRevenuFact.amountCentsKey], 950000,
          reason: 'le jumeau porte 9 500 CHF, le coffre 7 000');
      expect(projete[MintNextRevenuFact.legacyAmountKey], 9500.0,
          reason: 'la projection héritée doit suivre la valeur du jumeau, '
              'pas rester sur celle du coffre');
      expect(projete[MintNextRevenuFact.legacyFrequencyKey], 'monthly');
    });

    test('income — a deleted twin fact purges its legacy keys too', () async {
      await SecureWizardStore.writeCanonicalRevenu(
        MintNextRevenuFact(
          amountCents: 700000,
          period: MintNextRevenuPeriod.monthly,
          assertedAt: DateTime.utc(2025, 3, 1),
          source: 'user_declaration',
          schemaVersion: 1,
          needsConfirmation: false,
        ),
      );
      await sceller('revenu#principal', 'revenu', const {}, supprime: true);

      final projete = await SecureWizardStore.canonicalizeRevenuAnswers({
        MintNextRevenuFact.legacyAmountKey: 7000.0,
        MintNextRevenuFact.legacyFrequencyKey: 'monthly',
      });

      expect(projete.containsKey(MintNextRevenuFact.amountCentsKey), isFalse);
      expect(projete.containsKey(MintNextRevenuFact.legacyAmountKey), isFalse,
          reason: 'un revenu supprimé qui survit par sa clé héritée est un '
              'revenu non supprimé');
    });

    test('pension-fund affiliation — the twin wins over the vault', () async {
      await SecureWizardStore.writeCanonicalLppAffiliation(
        MintNextLppAffiliationFact(
          affiliated: true,
          assertedAt: DateTime.utc(2025, 3, 1),
          source: 'user_declaration',
          schemaVersion: 1,
          needsConfirmation: false,
        ),
      );
      await sceller('lpp_affiliation#caisse_principale', 'lpp_affiliation',
          {MintNextLppAffiliationFact.valueKey: false});

      final projete =
          await SecureWizardStore.canonicalizeLppAffiliationAnswers({});

      expect(projete[MintNextLppAffiliationFact.valueKey], false,
          reason: "quelqu'un qui se désaffilie ne doit pas rester affilié "
              'parce que le coffre le croit encore');
    });

    test('3a contributions now reach the projection, decomposed', () async {
      // Ce fait ne se consulte pas membre par membre : il se reconstitue à
      // partir de TOUS ses versements, chacun devenu un fait a part entiere.
      final registry = FactRegistry(newId: () => 'v${++_seq}', now: () => _horloge);
      Versements3aDecomposition.decompose(
        MintNextVersements3aFact(
          entries: [
            MintNextVersement3aEntry(
              id: 'p1',
              amountCents: 300000,
              creditedAt: DateTime.utc(2025, 3, 15),
              taxYear: 2025,
            ),
            MintNextVersement3aEntry(
              id: 'p2',
              amountCents: 200000,
              creditedAt: DateTime.utc(2025, 9, 1),
              taxYear: 2025,
            ),
          ],
          bucketRevisions: const {},
          assertedAt: _horloge,
          source: MintNextVersements3aFact.userDeclarationSource,
          schemaVersion: 1,
          needsConfirmation: false,
        ),
        registry: registry,
        source: FactSource.userDeclaration,
      );
      await SecureWizardStore.write(
          AnswersTwinBackend.registryKey, registry.encode());

      final projete =
          await SecureWizardStore.canonicalizeVersements3aAnswers({});
      final fait = MintNextVersements3aFact.fromWizardAnswers(projete);

      expect(fait, isNotNull);
      expect(fait!.entries.length, 2,
          reason: 'les deux versements doivent atteindre la projection');
      expect(fait.totalForYearCents(2025), 500000,
          reason: "c'est ce total qui nourrit la deduction fiscale");
    });

    test('a fact that decomposes is named, never silently absent', () {
      // Il ne s'enveloppe pas comme les autres : il suit l'autre chemin. Le
      // nommer empeche qu'il disparaisse entre les deux listes.
      expect(kDecomposedFacts, contains('versements_3a'));
      expect(kMigratableFacts.any((f) => f.factId == 'versements_3a'), isFalse);
    });

    test('a payload carrying a collection is refused AT THE WRITE', () async {
      // C'était la faille : la règle « scalaires uniquement » n'existait qu'à
      // la RELECTURE. Une liste s'écrivait donc sans broncher, et c'est le
      // chargement suivant qui levait — une exception qui remonte jusqu'au
      // catch du magasin de réponses, lequel rend une carte VIDE. Une seule
      // écriture mal formée effaçait tout le profil visible, au lancement
      // d'après, sans que rien ne désigne la cause.
      final registry = FactRegistry(newId: () => 'v1', now: () => _horloge);

      expect(
          () => registry.append(
                factId: 'versements_3a#banque_a',
                factType: 'versements_3a',
                payload: const {'comptes': <dynamic>[]},
                assertedAt: _horloge,
                source: FactSource.userDeclaration,
              ),
          throwsStateError,
          reason: 'refuser au moment de la faute, pas au prochain lancement');
    });
  });

  group('un registre INDISPONIBLE n\'est pas un registre absent', () {
    // Trouvé par l'axe adverse Codex, et c'est le défaut le plus vicieux du
    // lot : le coffre AVALE ses erreurs et rend null. Une panne passagère
    // faisait donc paraître le jumeau absent, le magasin canonique périmé
    // reprenait l'autorité — et une suppression pouvait ressusciter.

    test('a vault outage does not hand authority back to the stale vault',
        () async {
      // Le magasin plat porte le jeton du registre : il EXISTE. Le coffre, lui,
      // ne rend rien.
      final entrant = <String, dynamic>{
        AnswersTwinBackend.registryKey: '__secure__',
        MintNextHousingFact.annualInterestCentsKey: 111,
      };
      await SecureWizardStore.writeCanonicalHousing(canonique());

      final projete =
          await SecureWizardStore.canonicalizeHousingAnswers(entrant);

      expect(projete[MintNextHousingFact.annualInterestCentsKey], 111,
          reason: 'ni projection ni purge : la carte ressort telle quelle');
      expect(projete[MintNextHousingFact.statementYearKey], isNull,
          reason: 'surtout, le coffre périmé ne reprend PAS la main');
    });

    test('no registry at all still lets the vault answer', () async {
      // La contrepartie : sans jeton, il n'y a jamais eu de jumeau, et le
      // comportement historique doit être exactement préservé.
      await SecureWizardStore.writeCanonicalHousing(canonique());

      final projete = await SecureWizardStore.canonicalizeHousingAnswers({});

      expect(projete[MintNextHousingFact.annualInterestCentsKey], 300000);
    });
  });

  group('une version illisible ne laisse pas traîner ses alias hérités', () {
    // Second constat de l'axe adverse. Ne rien projeter ne suffit pas : les
    // clés héritées vivent HORS du bundle possédé, et les laisser continue
    // d'afficher l'ancienne valeur sous l'autorité apparente du jumeau.

    Future<void> scellerIllisible(String registryId, String factType) async {
      final registry = FactRegistry(newId: () => 'v1', now: () => _horloge);
      registry.append(
        factId: registryId,
        factType: factType,
        // Une charge utile que le modèle du fait ne sait pas relire.
        payload: const {'champ_inconnu': 'x'},
        assertedAt: _horloge,
        source: FactSource.userDeclaration,
      );
      await SecureWizardStore.write(
          AnswersTwinBackend.registryKey, registry.encode());
    }

    test('income — the legacy amount does not survive an unreadable version',
        () async {
      await scellerIllisible('revenu#principal', 'revenu');

      final projete = await SecureWizardStore.canonicalizeRevenuAnswers({
        MintNextRevenuFact.legacyAmountKey: 7000.0,
        MintNextRevenuFact.legacyFrequencyKey: 'monthly',
      });

      expect(projete.containsKey(MintNextRevenuFact.legacyAmountKey), isFalse,
          reason: "afficher un ancien revenu sous l'autorité du jumeau est "
              'pire que de n\'afficher aucun revenu');
      expect(
          projete.containsKey(MintNextRevenuFact.legacyFrequencyKey), isFalse);
    });

    test('civil status — the legacy alias does not survive either', () async {
      await scellerIllisible('etat_civil', 'etat_civil');

      final projete = await SecureWizardStore.canonicalizeCivilStatusAnswers({
        MintNextCivilStatusFact.legacyChoiceKey: 'marie',
      });

      expect(projete.containsKey(MintNextCivilStatusFact.legacyChoiceKey),
          isFalse,
          reason: "sinon le profil du coach ressuscite l'ancien état civil");
    });
  });

  test('the twin value actually reaches the fiscal boundary', () async {
    // Et la question qui compte vraiment : ce que le jumeau porte finit-il
    // dans un CALCUL, ou seulement à l'écran ? Les intérêts hypothécaires
    // sont la déduction la plus courante en Suisse.
    await SecureWizardStore.writeCanonicalHousing(canonique());
    await scellerRegistre(supprime: false);

    final projete = await SecureWizardStore.canonicalizeHousingAnswers({});
    final fait = MintNextHousingFact.fromWizardAnswers(projete);
    final contexte = MintNext3aHousingContext.fromConfirmedFact(fait!);

    expect(contexte, isNotNull);
    expect(contexte!.annualInterestCents, 425000,
        reason: "c'est le chiffre du jumeau qui doit atteindre le calcul");
    expect(contexte.coversTaxYear(2025), isTrue);
  });
}

final _horloge = DateTime.utc(2026, 8, 14, 10);
int _seq = 0;
