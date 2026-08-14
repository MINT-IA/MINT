// L'amorce — le moment où le jumeau devient réel, une fois et une seule.
//
// Ces oracles portent surtout sur des REFUS. Une amorce est l'endroit où l'on
// invente une histoire sans s'en apercevoir : en migrant deux fois, en
// recouvrant ce qu'on ne sait pas lire, ou en gelant un fait qu'on ne sait pas
// réécrire.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_domicile_fact.dart';
import 'package:mint_mobile/models/mint_next_housing_fact.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/twin/answers_twin_backend.dart';
import 'package:mint_mobile/services/twin/twin_bootstrap.dart';
import 'package:mint_mobile/services/twin/twin_migration.dart';
import 'package:mint_mobile/services/twin/twin_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final migratedAt = DateTime.utc(2026, 8, 14, 12);
  late int compteur;
  late TwinStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    compteur = 0;
    store = TwinStore(const AnswersTwinBackend(),
        newId: () => 'v${++compteur}', now: () => migratedAt);
  });

  tearDown(() => FeatureFlags.twinOwnedFactTypes = <String>{});

  Map<String, dynamic> dossier() => {
        MintNextHousingFact.tenureKey: 'owner_occupier',
        MintNextHousingFact.mortgageStatusKey: 'yes',
        MintNextHousingFact.annualInterestCentsKey: 425000,
        MintNextHousingFact.statementYearKey: 2025,
        MintNextHousingFact.assertedAtKey: '2026-08-01T00:00:00.000Z',
        MintNextHousingFact.sourceKey: 'user_declaration',
        MintNextHousingFact.schemaVersionKey: 1,
        MintNextHousingFact.needsConfirmationKey: false,
        // Un fait qui n'a PAS de frontière de commande.
        MintNextDomicileFact.communeNameKey: 'Aarau',
        MintNextDomicileFact.communeBfsKey: 4001,
        MintNextDomicileFact.assertedAtKey: '2026-08-01T00:00:00.000Z',
        MintNextDomicileFact.sourceKey: 'user_declaration',
        MintNextDomicileFact.schemaVersionKey: 1,
        MintNextDomicileFact.needsConfirmationKey: false,
      };

  Future<TwinMigrationReport?> amorcer() =>
      TwinBootstrap.ensureMigrated(store: store, migratedAt: migratedAt);

  test('with the switch OFF, nothing is migrated at all', () async {
    await ReportPersistenceService.saveAnswers(dossier());

    expect(await amorcer(), isNull);
    expect((await store.read()).registry.length, 0,
        reason: 'migrer sans savoir écrire gèlerait le fait');
  });

  test('only the facts we can also WRITE are migrated', () async {
    // Le cœur de l'amorce. Le domicile est présent dans le dossier et migrable
    // en théorie — mais aucun écran ne sait l'écrire dans le jumeau. Le migrer
    // le figerait : modifié à l'écran, inchangé à l'affichage.
    FeatureFlags.twinOwnedFactTypes = {'logement'};
    await ReportPersistenceService.saveAnswers(dossier());

    final report = (await amorcer())!;

    expect(report.migrated, contains('logement#residence_principale'));
    expect(report.migrated.any((f) => f.startsWith('domicile')), isFalse,
        reason: "on ne migre QUE ce qu'on sait aussi écrire");
    final registry = (await store.read()).registry;
    expect(registry.current('domicile'), isNull);
  });

  test('running twice does not invent a second declaration', () async {
    // La migration n'est PAS idempotente : sans garde, le second passage
    // ajouterait une version en pretendant que la personne a redéclaré ce
    // qu'elle avait déjà dit.
    FeatureFlags.twinOwnedFactTypes = {'logement'};
    await ReportPersistenceService.saveAnswers(dossier());

    await amorcer();
    final apresPremier = (await store.read()).registry.length;
    expect(await amorcer(), isNull, reason: 'le second passage ne fait rien');

    expect((await store.read()).registry.length, apresPremier);
    expect(
        (await store.read())
            .registry
            .history('logement#residence_principale')
            .length,
        1,
        reason: 'une seule déclaration, une seule version');
  });

  test('an empty profile leaves the twin unmarked', () async {
    // Écrire un registre vide le marquerait « déjà migré » — et la déclaration
    // faite demain ne serait jamais reprise.
    FeatureFlags.twinOwnedFactTypes = {'logement'};

    final report = await amorcer();

    expect(report, isNotNull);
    expect(report!.migrated, isEmpty);
    final relu = await const AnswersTwinBackend().read();
    expect(relu.registry, isNull,
        reason: 'rien à migrer ne doit pas se confondre avec « déjà migré »');
  });

  test('a sealed but unreadable registry is never overwritten', () async {
    // Le pire des deux mondes : repartir de zéro écraserait une histoire que
    // le coffre finirait peut-être par rendre.
    FeatureFlags.twinOwnedFactTypes = {'logement'};
    SharedPreferences.setMockInitialValues({
      AnswersTwinBackend.registryWrittenKey: true,
    });

    await expectLater(amorcer(), throwsA(isA<TwinRegistryUnreadable>()));
  });

  test('the migrated value actually reaches the screens', () async {
    // La question qui compte : après amorce, le chiffre remonte-t-il ?
    FeatureFlags.twinOwnedFactTypes = {'logement'};
    await ReportPersistenceService.saveAnswers(dossier());

    await amorcer();
    final answers = await ReportPersistenceService.loadAnswers();

    expect(answers[MintNextHousingFact.annualInterestCentsKey], 425000);
    expect(answers[MintNextDomicileFact.communeNameKey], 'Aarau',
        reason: 'et le fait NON migré continue de passer par son repli');
  });
}
