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
import 'package:mint_mobile/models/mint_next_housing_fact.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:mint_mobile/services/twin/answers_twin_backend.dart';
import 'package:mint_mobile/services/twin/fact_registry.dart';
import 'package:mint_mobile/services/twin/fact_version.dart';
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
