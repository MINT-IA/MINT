# Verdict Codex — beat b4_lifecycle (2026-08-14)

Axe adverse, périmètre 4 fichiers. **Le périmètre était trop étroit** : il
concluait « aucune clé ne distingue les deux cas » en signalant lui-même que
`checkAuth()` était hors de sa lecture. La clé existait — `auth_provider.dart:603`.
Faux négatif fabriqué par mon contrat, pas par l'axe. Leçon retenue dans
`tools/codex_prompts/_contexte.md`.

Ce qu'il a eu JUSTE, et qui a changé le test :
> « `setMockInitialValues()` ne prouve pas une frontière de processus. »
La relance réelle appartient donc au beat `b4_cold_start_receipt`, et le test
de ce beat le dit explicitement.

---

## A. État décisif

**Aucune clé visible ne distingue actuellement les deux cas.**

Le CTA appelle seulement `LegacyOnboardingEntry.open(context)` (`landing_screen.dart:96`) ; son éventuelle écriture persistante est hors périmètre. Le test remplace `AuthProvider` par `_FakeAuth` : `enableLocalMode()` ne modifie qu’un booléen et un lifecycle **en mémoire** (`legacy_onboarding_entry_test.dart:30-36`).

La seule clé pertinente visible est `mint_install_marker_v1` (`install_lifecycle_service.dart:19`), écrite :

- lorsqu’une préférence préexistante est détectée (`:69`) ;
- après purge de fresh install (`:81`).

Elle signifie « installation reconnue », pas « CTA touché », et est écrite indépendamment du CTA. Elle ne peut donc pas décider landing contre Aujourd’hui.

**Verdict : le contrat n’est pas implémenté/prouvé dans ces fichiers. Il faut du code persistant, pas seulement compléter le test actuel.**

## B. Mode local implicite

Un chemin de restauration existe : au démarrage, `app.dart:2125-2127` construit le vrai `AuthProvider` puis appelle immédiatement `checkAuth()`.

`InstallLifecycleService.prepareForAuthRestore()` autorise ensuite la lecture des credentials dès que `mint_install_marker_v1 == true` (`:54`). Or ce marqueur ne prouve aucun CTA.

Cela ne démontre pas que le mode local s’active effectivement avant CTA : les comportements de `checkAuth()`, `enableLocalMode()` et la valeur par défaut en absence de préférence sont hors des fichiers autorisés. Mais **l’absence d’activation implicite n’est pas démontrée**. Une préférence de disclosure ne doit notamment jamais être interprétée comme autorisation locale.

## C. Test sans théâtre

Il faut un **test d’intégration avec arrêt/redémarrage réel de l’application**, pas un widget test injectant `_FakeAuth` :

1. installation propre ;
2. afficher puis fermer la disclosure ;
3. arrêter et relancer sans effacer les données ;
4. vérifier `screen:first_open.landing`, absence d’Aujourd’hui et du wizard ;
5. toucher le vrai CTA ;
6. arrêter et relancer en conservant les stores ;
7. vérifier Aujourd’hui, mode local restauré et absence du wizard.

À piloter réellement : routeur de production, `AuthProvider`, service lifecycle, SharedPreferences plateforme et secure storage. `setMockInitialValues()` ne prouve pas une frontière de processus.

Resteraient non prouvés : désinstallation/réinstallation iOS avec Keychain survivant et comportement TestFlight exact.

### Key Learnings:
