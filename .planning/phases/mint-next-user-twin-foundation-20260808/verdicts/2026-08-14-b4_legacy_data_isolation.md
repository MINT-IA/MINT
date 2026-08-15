# Verdict Codex — beat b4_legacy_data_isolation (2026-08-14)

Axe adverse à périmètre OUVERT, après la leçon du beat précédent.

**Trouvaille majeure** : `TwinBootstrap.ensureMigrated()` promeut au démarrage
les données wizard legacy en faits du jumeau — ce que le cadrage B4 interdit.
Absent de `dev`, donc la bascule 4 reconstruite depuis `dev` n'a pas la
violation ; le Lego « fondation du jumeau » devra porter la contrainte.

---

## A. Promotion silencieuse

**Oui. Ce beat est un CORRECTIF.**

Au démarrage, `main.dart:43-53` lance `TwinBootstrap.ensureMigrated()` avant même le contrôle d’installation (`:61`). Cette amorce appelle `ReportPersistenceService.loadAnswers()` (`twin_bootstrap.dart:47-59`), lequel lit `wizard_answers_v2` et exécute les canonicalisations (`report_persistence_service.dart:128-172`).

Deux promotions existent :

- Un logement legacy complet est écrit silencieusement dans `_mint_canonical_housing_v1` (`secure_wizard_store.dart:996-1045`). Le test existant l’affirme explicitement : `report_persistence_service_test.dart:82-109`.
- `TwinMigration` transforme ensuite les faits trouvés en versions `migratedV1` (`twin_migration.dart:199-248`). Le périmètre actif contient `logement`, `revenu`, `versements_3a` (`feature_flags.dart:74-84`). `twin_bootstrap_test.dart:69-83` prouve cette migration.

Enfin, même sans promotion, `CoachProfileProvider.loadFromWizard()` utilise `wizard_completed`, `mini_onboarding_completed`, puis les réponses partielles pour construire le profil produit (`coach_profile_provider.dart:1039-1092`). Interdire seulement la route wizard ne suffit donc pas : le legacy reste autorité produit.

## B. Suppression automatique

Les **trois valeurs SharedPreferences** ne sont pas supprimées par `InstallLifecycleService`. Leur présence rend `hasExistingPrefs=true`, puis le service ajoute seulement le marqueur d’installation (`install_lifecycle_service.dart:37-39,61-70`).

Nuance bloquante : lors d’une purge fresh-install ou d’un retry pending, `SecureWizardStore.deleteAll()` (`:105-112`) peut supprimer les valeurs Keychain référencées par `wizard_answers_v2`, tout en laissant sa chaîne JSON intacte. Conservation textuelle ne signifie donc pas conservation du store fonctionnel.

B2 est bien une suppression demandée : UI `privacy_center_screen.dart:334` → `LocalPreviewResetService.reset()` `:140-182` → `ReportPersistenceService.clear()` `:1008-1015` → retrait exact des trois clés `:1075-1079`.

## C. Oracle « byte-for-byte »

Injecter les données **hors des services applicatifs** : `saveAnswers()` et `loadAnswers()` mutent précisément ce qu’ils prétendraient mesurer. Utiliser une chaîne JSON volontairement non canonique, puis comparer avant/après son Base64 ou SHA-256 exact, les deux booléens typés, le manifeste sécurisé et chaque valeur Keychain référencée.

En parallèle, exiger l’absence avant/après des cinq stores canoniques, de leurs marqueurs, de `mint_twin_registry_v1`, `registryWrittenKey`, révision et métadonnées. Mesures après cold start, CTA, kill et relance.

Sans reçu runtime, restent non prouvés : vrai Keychain, ordre réel du boot, mort de processus, absence de navigation wizard et comportement du binaire installé.

## Key Learnings:

1. Le loader legacy est mutateur et alimente actuellement le jumeau.
2. Préserver uniquement `wizard_answers_v2` peut masquer la suppression de ses valeurs scellées.
tokens used
181,499
## A. Promotion silencieuse

**Oui. Ce beat est un CORRECTIF.**

Au démarrage, `main.dart:43-53` lance `TwinBootstrap.ensureMigrated()` avant même le contrôle d’installation (`:61`). Cette amorce appelle `ReportPersistenceService.loadAnswers()` (`twin_bootstrap.dart:47-59`), lequel lit `wizard_answers_v2` et exécute les canonicalisations (`report_persistence_service.dart:128-172`).
