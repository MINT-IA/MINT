# MINT App + Web Architecture (Guide complet debutant)

Date: 12 mars 2026
Statut: phase 1 complete, phase 2 complete (21 ecrans migres + navigation shell web), phase 3 complete (catalogue unique + 11 consommateurs), phase 4 (adaptations platform-safe) complete
Public cible: equipe produit/tech, y compris debutants Flutter

---

## 1) Resume simple (si tu dois comprendre en 60 secondes)

MINT n'est pas "2 applications differentes".  
MINT est **1 seul coeur applicatif** avec **2 points d'entree**:

1. un point d'entree mobile (`main.dart`)
2. un point d'entree web (`main_web.dart`)

Les 2 passent par le meme bootstrap (`mint_bootstrap.dart`) puis reutilisent la meme app (`MintApp`) pour routes, providers, logique metier et services.

La difference web actuelle se fait surtout dans la **presentation**:

1. layout global web (contenu centre, largeur max, gutters)
2. certains ecrans ont un layout web adapte (2 colonnes, cartes desktop)
3. le mobile reste inchange

Objectif principal: **eviter la duplication** et garder un seul endroit pour maintenir le contenu.

---

## 2) Pourquoi cette architecture existe

Avant ce choix, le risque etait:

1. dupliquer la navigation entre mobile et web
2. dupliquer la logique metier (calculs financiers)
3. passer du temps a corriger des bugs differents selon la plateforme

Cette architecture est faite pour:

1. centraliser le metier
2. separer proprement "contenu" et "presentation"
3. faire evoluer l'UX web sans casser le mobile

---

## 3) Carte des fichiers importants

### 3.1 Entree et bootstrap

1. `apps/mobile/lib/main.dart`
   - entree mobile
   - lance `runMintBootstrap(target: MintRuntime.mobile, rootWidget: MintApp())`
2. `apps/mobile/lib/main_web.dart`
   - entree web
   - lance `runMintBootstrap(target: MintRuntime.web, rootWidget: MintWebApp())`
3. `apps/mobile/lib/bootstrap/mint_bootstrap.dart`
   - sequence de demarrage commune mobile + web

### 3.2 Shell applicatif

1. `apps/mobile/lib/app.dart`
   - source de verite: providers + router + routes + theme
2. `apps/mobile/lib/app_web.dart`
   - shell web
   - aujourd'hui il retourne simplement `MintApp()` (reutilisation totale)

### 3.3 Layout web global

1. `apps/mobile/lib/features/platform/presentation/web/web_viewport_layout.dart`
   - applique un cadre web desktop: fond gris (`#F3F6FA`), centrage, largeur max (`1360px`)
2. applique dans `app.dart` via `MaterialApp.router.builder`
   - si `kIsWeb == true`: wrap avec `WebViewportLayout`
   - sinon: rendu mobile normal

### 3.4 Navigation shell web (side menu)

1. `apps/mobile/lib/screens/main_navigation_shell.dart`
   - sur web desktop (>= 1024px): side menu vertical remplace la bottom nav bar
   - sur mobile: bottom navigation bar preservee (aucun changement)
   - breakpoint: `_webSidebarBreakpoint = 1024`, largeur: `_webSidebarWidth = 236`
   - configuration centralisee via `_NavigationItemConfig` (4 tabs: Dashboard, Agir, Apprendre, Profil)

### 3.5 Catalogue de contenu (phase 3)

1. `apps/mobile/lib/content/feature_catalog.dart`
   - source unique des categories/outils (titre, sous-titre, route, icone, couleur)
2. consomme par:
   - `apps/mobile/lib/screens/tools_library_screen.dart`
   - `apps/mobile/lib/screens/web/web_home_screen.dart`
   - `apps/mobile/lib/screens/timeline_screen.dart` (quick actions + metadonnees outils)
   - `apps/mobile/lib/screens/main_tabs/explore_tab.dart` (goals + metadonnees evenements routes outil)
   - `apps/mobile/lib/widgets/life_event_suggestions.dart`
   - `apps/mobile/lib/widgets/coach/explore_hub.dart`
   - `apps/mobile/lib/widgets/dashboard/retirement_checklist_card.dart`
   - `apps/mobile/lib/widgets/dashboard/arbitrage_teaser_card.dart`
   - `apps/mobile/lib/widgets/dashboard/couple_action_plan.dart` (icones routees via catalogue, couleurs owner preservees)
   - `apps/mobile/lib/screens/advisor/onboarding_30_day_plan_screen.dart`
   - `apps/mobile/lib/widgets/educational/stress_check_insert_widget.dart`
   - `apps/mobile/lib/widgets/coach/chiffre_choc_section.dart`

---

## 4) Schema mental (tres important)

```text
Mobile:
main.dart
  -> runMintBootstrap(mobile)
    -> runApp(MintApp)
      -> MaterialApp.router + GoRouter + Providers
        -> Screens

Web:
main_web.dart
  -> runMintBootstrap(web)
    -> runApp(MintWebApp)
      -> MintWebApp retourne MintApp
        -> MaterialApp.router + GoRouter + Providers
          -> builder web: WebViewportLayout
            -> Screens (avec layout web adapte sur certains ecrans)
```

Conclusion: le tronc est le meme, la couche presentation web est ajoutee par-dessus.

---

## 5) Detail du demarrage commun (bootstrap)

Le bootstrap partage execute les etapes suivantes:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. resolution API via `ApiService.ensureReachableBaseUrl()`
3. initialisation SLM avec timeout court
4. refresh feature flags avec timeout court
5. prechargement de donnees critiques en tache de fond
   - limites 3a
   - echelles fiscales
   - communes
   - flags
6. planification d'un refresh periodique des flags (toutes les 6h)
7. `runApp(rootWidget)`

Ce que ca apporte:

1. mobile et web demarrent de maniere coherente
2. pas de divergence de config API/flags
3. temps de demarrage controle (timeouts)

---

## 6) Comment la web app est differente sans casser le mobile

Il y a 2 niveaux:

### Niveau A: global (toute l'app web)

Dans `app.dart`, `MaterialApp.router.builder` fait:

1. mobile: rend l'arbre tel quel
2. web: wrap dans `WebViewportLayout`

Effet:

1. largeur max desktop
2. page centree
3. fond web coherent
4. aucune duplication de route/provider

### Niveau B: ecran par ecran

Sur certains ecrans, on ajoute un pattern de ce type:

1. detecter `useWebLayout = kIsWeb && width >= threshold`
2. `body: useWebLayout ? _buildWebBody() : _buildMobileBody()`
3. garder `_buildMobileBody()` equivalent au flux historique
4. mettre l'adaptation uniquement dans `_buildWebBody()`

Regle d'or:

1. logique metier identique
2. presentation differente seulement

### Niveau C: navigation shell (side menu web)

Sur desktop web (>= 1024px), le `MainNavigationShell` remplace la `BottomNavigationBar` par un side menu vertical (`Row` avec sidebar a gauche + contenu a droite).

Pattern:

```dart
final useWebSideMenu = kIsWeb && MediaQuery.sizeOf(context).width >= 1024;
return Scaffold(
  body: useWebSideMenu
      ? Row(children: [_buildWebSideMenu(), Expanded(child: _buildTabStack())])
      : _buildTabStack(),
  bottomNavigationBar: useWebSideMenu ? null : _buildBottomNav(),
);
```

### Niveau D: ecrans tabulaires (responsive tab list)

Les ecrans a onglets (mariage, concubinage, naissance) utilisent `_buildResponsiveTabList()` au lieu de `ListView` pour wrapper le contenu dans un conteneur centre + max-width sur web.

Pattern: remplacer `ListView(...)` par `_buildResponsiveTabList(...)` dans chaque onglet.

### Niveau E: services platform-safe (remplacement dart:io)

Les services qui utilisaient `dart:io` (`Platform.isIOS`, `Platform.isAndroid`) ont ete migres vers `package:flutter/foundation.dart` (`kIsWeb`, `defaultTargetPlatform`) pour eviter les erreurs de compilation web.

Fichiers concernes:

1. `apps/mobile/lib/services/ios_iap_service.dart`: `Platform.isIOS` -> `!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS`
2. `apps/mobile/lib/services/notification_service.dart`: `Platform.isIOS`/`Platform.isAndroid` -> `defaultTargetPlatform == TargetPlatform.iOS`/`TargetPlatform.android`

Regle: ne jamais importer `dart:io` dans du code qui compile pour le web. Utiliser `kIsWeb` + `defaultTargetPlatform` a la place.

---

## 7) Ecrans deja migres (etat actuel)

### 7.1 Layout desktop web explicite (2 colonnes)

1. `simulator_3a_screen.dart`
2. `simulator_compound_screen.dart`
3. `simulator_leasing_screen.dart`
4. `simulator_disability_gap_screen.dart`
5. `job_comparison_screen.dart`
6. `divorce_simulator_screen.dart`
7. `succession_simulator_screen.dart`
8. `donation_screen.dart`

### 7.2 Discover/library web adapte

1. `tools_library_screen.dart` (navigation en grille sur web)

### 7.3 Conteneur web centre + max width (mobile preserve)

1. `consumer_credit_screen.dart`
2. `debt_risk_check_screen.dart`
3. `lamal_franchise_screen.dart`
4. `coverage_check_screen.dart`
5. `unemployment_screen.dart`
6. `first_job_screen.dart`
7. `fiscal_comparator_screen.dart`

### 7.4 Ecrans tabulaires avec responsive tab list

1. `mariage_screen.dart` (3 onglets: impots, regime, protection)
2. `naissance_screen.dart`
3. `concubinage_screen.dart`

### 7.5 Navigation shell web (side menu)

1. `main_navigation_shell.dart` (side menu vertical >= 1024px, bottom nav bar sur mobile)

### 7.6 Services adaptes platform-safe (dart:io -> foundation)

1. `ios_iap_service.dart`
2. `notification_service.dart`

---

## 8) "Je veux modifier X" -> ou je dois toucher ?

### 8.1 Tu veux changer un calcul financier

1. modifie `services/` ou `domain/`
2. ne mets pas de calcul dans un widget
3. impact mobile + web automatiquement (normal et voulu)

### 8.2 Tu veux changer un texte/ordre/section visible partout

1. modifie le screen shared dans `apps/mobile/lib/screens/...`
2. impact mobile + web (normal)

### 8.3 Tu veux seulement changer la disposition web

1. ajoute/modifie `if (kIsWeb && width >= ...)`
2. cree/ajuste `_buildWebBody()`
3. ne change pas `_buildMobileBody()` (ou valide que comportement mobile est identique)

### 8.4 Tu veux ajouter une nouvelle page

1. cree le screen dans `screens/`
2. ajoute la route dans `app.dart` (GoRouter)
3. ajoute ensuite adaptation web si necessaire

### 8.5 Tu veux changer le demarrage app (API/flags/preload)

1. modifie `mint_bootstrap.dart`
2. attention: impact mobile + web

---

## 9) Workflow conseille pour ajouter un layout web sans regression

1. identifier le screen cible
2. figer le mobile:
   - extraire le corps actuel dans `_buildMobileBody()`
   - ne pas changer sa logique
3. creer `_buildWebBody()` avec layout desktop
4. brancher `useWebLayout`
5. valider:
   - `flutter analyze`
   - `flutter test` (si tests disponibles pour ce scope)
   - `flutter build web --release -t lib/main_web.dart ...`
6. verifier visuellement mobile + web

Pattern type:

```dart
final useWebLayout = kIsWeb && MediaQuery.sizeOf(context).width >= 1180;
return Scaffold(
  body: useWebLayout ? _buildWebBody() : _buildMobileBody(),
);
```

---

## 10) Validation locale (commands utiles)

Depuis `apps/mobile/`:

1. `flutter pub get`
2. `flutter run -d chrome -t lib/main_web.dart --dart-define=API_BASE_URL=https://api.mint.ch/api/v1`
3. `flutter analyze`
4. `flutter build web --release -t lib/main_web.dart --dart-define=API_BASE_URL=https://api.mint.ch/api/v1`

Pour mobile:

1. `flutter run -d ios`
2. ou `flutter run -d android`

Note:

1. des warnings wasm dry-run peuvent apparaitre au build web (non bloquants aujourd'hui)

---

## 11) Deploiement web en production (CI/CD)

Le deploy web est gere par `.github/workflows/web.yml`.

Cas principal:

1. PR mergee vers `main`
2. workflow build web avec `lib/main_web.dart`
3. deploiement GitHub Pages

API production:

1. base URL resolue depuis `vars.PROD_API_URL`
2. fallback: `https://api.mint.ch/api/v1`

Important pour debutants:

1. TestFlight ne donne pas d'URL web
2. URL web publique = GitHub Pages

---

## 12) FAQ debutant

### Q1. "Pourquoi le dossier web est dans apps/mobile ?"

Parce que c'est le meme projet Flutter multiplateforme.  
On reutilise les memes widgets/routes/services.

### Q2. "Si je modifie un screen, est-ce que web change aussi ?"

Oui si le screen est shared.  
C'est voulu pour garder une seule base.

### Q3. "Puis-je changer uniquement la disposition web ?"

Oui.  
Fais le via `kIsWeb` + largeur + `_buildWebBody()`.

### Q4. "Dois-je creer une seconde app pour le web ?"

Non, pas dans cette architecture.

### Q5. "Comment garantir zero impact mobile ?"

1. conserver `_buildMobileBody()` tel quel
2. ne changer que la branche web
3. tester mobile apres modification

---

## 13) Regles non negociables

1. pas de duplication des calculs financiers
2. pas de logique metier dans les widgets
3. divergence web = presentation uniquement
4. routes/providers restent centralises dans `app.dart`
5. bootstrap commun unique pour mobile + web

---

## 14) Roadmap architecture

### Phase 1 (terminee)

1. bootstrap commun
2. entrees mobile/web separees proprement
3. source de verite unique via `app.dart`

### Phase 2 (terminee)

1. layout web global actif (`WebViewportLayout` dans `app.dart` builder)
2. 21 ecrans migres (8 layout 2 colonnes + 7 conteneur centre + 3 responsive tab + 1 library grille + 1 explore tab + 1 navigation shell side menu)
3. mobile preserve (aucune regression)
4. side menu web sur navigation shell (>= 1024px)

### Phase 3 (terminee)

1. catalogue de contenu unique (`content/feature_catalog.dart`)
2. navigation/cartes derivees de ce catalogue (11 consommateurs)
3. alias de route + filtrage surface/decisionScaffold centralises

### Phase 3 (detail implemente)

1. `apps/mobile/lib/content/feature_catalog.dart` cree comme source unique des categories/outils.
2. `tools_library_screen.dart` branche sur ce catalogue (mobile + web).
3. `web_home_screen.dart` branche sur ce meme catalogue (routes featured web).
4. `timeline_screen.dart` lit les metadonnees d'outils (icone/couleur) via route.
5. `explore_tab.dart` lit les metadonnees d'outils pour les goals + evenements lies aux outils.
6. `life_event_suggestions.dart` lit les metadonnees d'outils via route (sans changer la logique de suggestion).
7. `widgets/coach/explore_hub.dart` lit l'entree arbitrage depuis le catalogue.
8. dashboard/onboarding/widgets d'action principaux lisent aussi les metadonnees routees via catalogue.
9. alias de route centralise pour compatibilite (`/simulator/rente-capital` -> `/arbitrage/rente-vs-capital`).
10. filtrage de disponibilite centralise (`decisionScaffoldEnabled`, surface web/mobile).

### Phase 4 (terminee) — adaptations platform-safe

1. `ios_iap_service.dart`: `dart:io Platform.isIOS` -> `kIsWeb + defaultTargetPlatform`
2. `notification_service.dart`: `dart:io Platform.isIOS/isAndroid` -> `kIsWeb + defaultTargetPlatform`
3. `main_navigation_shell.dart`: side menu web desktop (>= 1024px) avec `_NavigationItemConfig`
4. `pubspec.lock`: dependances alignees

---

## 15) Checklist PR (architecture app + web)

Avant merge:

1. j'ai evite de dupliquer du metier
2. j'ai garde le mobile stable
3. j'ai verifie web desktop
4. `flutter analyze` passe (ou infos legacy connues seulement)
5. `flutter build web` passe
6. la doc architecture est a jour si j'ai change des regles structurelles

---

## 16) Playbook Re-implementation Depuis Zero

Cette section explique exactement quoi refaire si tu dois re-implementer toute l'architecture (phase 1 + 2 + 3) depuis le debut.

### 16.1 Pre-requis

1. partir d'une branche propre (ex: `git checkout -b chore/rebuild-app-web-architecture`)
2. avoir Flutter installe et fonctionnel
3. lancer un baseline avant modifications:
   - `flutter pub get`
   - `flutter analyze`
   - `flutter test` (si applicable)
   - `flutter build web --release -t lib/main_web.dart --dart-define=API_BASE_URL=https://api.mint.ch/api/v1` (si `main_web.dart` existe deja)

### 16.2 Phase 1 a re-implementer (fondation runtime commune)

Objectif: une seule sequence de demarrage pour mobile + web.

#### Etapes

1. creer `apps/mobile/lib/bootstrap/mint_bootstrap.dart`
   - ajouter `enum MintRuntime { mobile, web }`
   - ajouter `runMintBootstrap(...)`
   - inclure init API, init SLM, refresh feature flags, warmup data critiques
2. modifier `apps/mobile/lib/main.dart`
   - remplacer `runApp(...)` direct par `runMintBootstrap(target: MintRuntime.mobile, rootWidget: const MintApp())`
3. creer `apps/mobile/lib/main_web.dart`
   - appeler `runMintBootstrap(target: MintRuntime.web, rootWidget: const MintWebApp())`
4. creer `apps/mobile/lib/app_web.dart`
   - shell web minimal qui retourne `const MintApp()`

#### Critere d'acceptation phase 1

1. mobile demarre comme avant (pas de regression de routes/providers)
2. web demarre via `main_web.dart`
3. aucune duplication de sequence d'initialisation

### 16.3 Phase 2 a re-implementer (presentation web)

Objectif: garder le contenu metier partage, adapter l'ergonomie web.

#### Etapes globales

1. creer `apps/mobile/lib/features/platform/presentation/web/web_viewport_layout.dart`
   - `WebViewportLayout` widget: `ColoredBox(color: #F3F6FA)` + `Align(topCenter)` + `ConstrainedBox(maxWidth: 1360)`
   - max width desktop (1360px)
   - fond gris web
2. modifier `apps/mobile/lib/app.dart`
   - ajouter `import 'package:flutter/foundation.dart' show kIsWeb;`
   - ajouter `import 'package:mint_mobile/features/platform/presentation/web/web_viewport_layout.dart';`
   - dans `MaterialApp.router.builder`, ajouter:
     ```dart
     builder: (context, child) {
       if (!kIsWeb) return child ?? const SizedBox.shrink();
       if (child == null) return const SizedBox.shrink();
       return WebViewportLayout(child: child);
     },
     ```

#### Etapes ecran par ecran — Pattern A: layout 2 colonnes (simulateurs)

Seuil: `kIsWeb && MediaQuery.sizeOf(context).width >= 1180`

```dart
final useWebLayout = kIsWeb && MediaQuery.sizeOf(context).width >= 1180;
return Scaffold(
  body: useWebLayout ? _buildWebBody() : _buildMobileBody(),
);
```

`_buildWebBody()` typique: `SingleChildScrollView` -> `Align(topCenter)` -> `ConstrainedBox(maxWidth: 1360)` -> `Row` avec 2 colonnes (inputs + resultats).

Ecrans concernes: `simulator_3a_screen.dart`, `simulator_compound_screen.dart`, `simulator_leasing_screen.dart`, `simulator_disability_gap_screen.dart`, `job_comparison_screen.dart`, `divorce_simulator_screen.dart`, `succession_simulator_screen.dart`, `donation_screen.dart`.

#### Etapes ecran par ecran — Pattern B: conteneur centre (wizard simples)

Meme seuil 1180px, mais `_buildWebBody()` = conteneur centre maxWidth sans 2 colonnes.

Ecrans concernes: `consumer_credit_screen.dart`, `debt_risk_check_screen.dart`, `lamal_franchise_screen.dart`, `coverage_check_screen.dart`, `unemployment_screen.dart`, `first_job_screen.dart`, `fiscal_comparator_screen.dart`.

#### Etapes ecran par ecran — Pattern C: responsive tab list (ecrans tabulaires)

Pour les ecrans a TabBarView, remplacer `ListView(...)` par `_buildResponsiveTabList(...)` dans chaque onglet. Ce helper wrap le contenu dans un conteneur centre + max-width sur web.

Ecrans concernes: `mariage_screen.dart`, `naissance_screen.dart`, `concubinage_screen.dart`.

#### Etapes — Navigation shell web (side menu)

Modifier `apps/mobile/lib/screens/main_navigation_shell.dart`:

1. ajouter `import 'package:flutter/foundation.dart' show kIsWeb;`
2. definir constantes `_webSidebarBreakpoint = 1024`, `_webSidebarWidth = 236`
3. creer `_NavigationItemConfig` (index, icon, activeIcon, label)
4. dans `build()`: detecter `useWebSideMenu = kIsWeb && width >= 1024`
5. si web: `Row(children: [_buildWebSideMenu(), Expanded(child: _buildTabStack())])`
6. si mobile: `_buildTabStack()` + `bottomNavigationBar: _buildBottomNav()`

#### Etapes — Tools library sur catalogue

Modifier `apps/mobile/lib/screens/tools_library_screen.dart`:

1. supprimer les classes locales `_ToolItem` et `_ToolCategory`
2. ajouter `typedef _ToolItem = FeatureToolItem;` et `typedef _ToolCategory = FeatureToolCategory;`
3. supprimer la liste hardcodee `_categories`
4. utiliser `FeatureCatalog.categoriesFor(decisionScaffoldEnabled: ..., surface: ...)`
5. ajouter detection web: `kIsWeb && width >= seuil` pour grille desktop

#### Ordre recommande de migration (safe)

1. ecran library/discovery (`tools_library_screen.dart`)
2. simulateurs simples (pattern B)
3. simulateurs complexes (pattern A)
4. ecrans tabulaires/famille (pattern C)
5. navigation shell (side menu)
6. ecrans restants

#### Critere d'acceptation phase 2

1. mobile identique (comportement + navigation)
2. web plus lisible sur desktop (2 colonnes / max-width selon ecran)
3. side menu web fonctionnel sur navigation shell
4. `flutter analyze` et `flutter build web` passent

### 16.4 Phase 3 a re-implementer (catalogue de contenu unique)

Objectif: eliminer le hardcode du contenu dans plusieurs ecrans.

#### Etapes

1. creer `apps/mobile/lib/content/feature_catalog.dart`
   - modeles:
     - `enum FeatureSurface { mobile, web }`
     - `FeatureToolItem` (icon, title, subtitle, route, color, surfaces)
     - `FeatureToolCategory` (icon, title, color, tools)
   - catalogue central:
     - `FeatureCatalog.categories` — liste const de 8 categories (Prevoyance, Famille, Emploi, Immobilier, Fiscalite, Sante, Budget & Dettes, Banque & Documents) totalisant ~49 outils
   - alias de routes:
     - `_routeAliases` (ex: `/simulator/rente-capital` -> `/arbitrage/rente-vs-capital`)
   - routes web MVP:
     - `FeatureCatalog.webMvpFeaturedRoutes` (5 outils: 3a, compound, leasing, credit, debt)
   - helpers:
     - `categoriesFor({required bool decisionScaffoldEnabled, FeatureSurface? surface})`
     - `flattenTools(List<FeatureToolCategory>)`
     - `totalToolCount(List<FeatureToolCategory>)`
     - `toolsForRoutes(List<String>, {required bool decisionScaffoldEnabled, FeatureSurface? surface})`
     - `toolByRoute(String, {required bool decisionScaffoldEnabled, FeatureSurface? surface})`
   - filtre decision scaffold:
     - `_isDecisionScaffoldTool()` filtre les routes `/arbitrage/*` et `/simulator/rente-capital`
2. brancher `apps/mobile/lib/screens/tools_library_screen.dart` sur le catalogue
   - supprimer classes locales `_ToolItem`, `_ToolCategory` et liste hardcodee
   - ajouter `typedef _ToolItem = FeatureToolItem;` + `typedef _ToolCategory = FeatureToolCategory;`
   - utiliser `FeatureCatalog.categoriesFor(...)`
3. brancher `apps/mobile/lib/screens/web/web_home_screen.dart`
   - utiliser `FeatureCatalog.toolsForRoutes(FeatureCatalog.webMvpFeaturedRoutes, ...)`
4. brancher les 11 consommateurs (voir section 3.5 pour la liste complete):
   - `timeline_screen.dart` — metadonnees outils (icone/couleur) via route
   - `explore_tab.dart` — goals + metadonnees evenements
   - `life_event_suggestions.dart` — metadonnees outils via route
   - `explore_hub.dart` — entree arbitrage rente vs capital depuis catalogue
   - `retirement_checklist_card.dart` — metadonnees routees
   - `arbitrage_teaser_card.dart` — metadonnees routees
   - `couple_action_plan.dart` — icones routees via catalogue, couleurs owner preservees
   - `onboarding_30_day_plan_screen.dart` — metadonnees routees
   - `stress_check_insert_widget.dart` — metadonnees routees
   - `chiffre_choc_section.dart` — metadonnees routees

#### Critere d'acceptation phase 3

1. le contenu outils/categories n'est defini qu'a un seul endroit (`feature_catalog.dart`)
2. mobile et web utilisent la meme source de contenu
3. changements de contenu futurs = 1 fichier principal a modifier
4. alias de routes fonctionnels
5. filtrage surface (mobile/web) et decisionScaffold centralise

### 16.5 Phase 4 a re-implementer (adaptations platform-safe)

Objectif: supprimer toutes les dependances a `dart:io` dans le code qui compile pour le web.

#### Etapes

1. modifier `apps/mobile/lib/services/ios_iap_service.dart`:
   - supprimer `import 'dart:io' show Platform;`
   - ajouter `import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;`
   - remplacer `Platform.isIOS` par `!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS`
2. modifier `apps/mobile/lib/services/notification_service.dart`:
   - supprimer `import 'dart:io' show Platform;`
   - ajouter `import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;`
   - remplacer `Platform.isIOS` par `defaultTargetPlatform == TargetPlatform.iOS`
   - remplacer `Platform.isAndroid` par `defaultTargetPlatform == TargetPlatform.android`
3. verifier tout import `dart:io` restant dans `lib/`:
   - seuls les fichiers qui ne compilent pas pour le web (ex: code conditionnel derriere `dart.library.io`) peuvent garder `dart:io`

#### Critere d'acceptation phase 4

1. `flutter build web --release -t lib/main_web.dart` compile sans erreur `dart:io`
2. fonctionnalites iOS-only (IAP, notifications) sont silencieusement desactivees sur web
3. aucune regression mobile sur les services concernes

### 16.6 CI/CD a verifier apres re-implementation

1. fichier `.github/workflows/web.yml`:
   - build avec `-t lib/main_web.dart`
   - resolution API prod (`vars.PROD_API_URL` + fallback `https://api.mint.ch/api/v1`)
   - patch google_fonts (`scripts/patch_google_fonts_const_map.sh`)
   - generation l10n (`flutter gen-l10n`)
   - SPA fallback (`cp build/web/index.html build/web/404.html`)
   - deploy GitHub Pages via `actions/upload-pages-artifact@v3` + `actions/deploy-pages@v4`
2. declencheurs: `pull_request types: [closed]` vers `main` + `workflow_dispatch`
3. permissions: `contents: read`, `pages: write`, `id-token: write`
4. concurrency: `web-${{ github.ref }}` avec `cancel-in-progress: true`

### 16.7 Commandes de validation finale

Depuis `apps/mobile/`:

1. `flutter pub get`
2. `flutter analyze`
3. `flutter test`
4. `flutter run -d chrome -t lib/main_web.dart --dart-define=API_BASE_URL=https://api.mint.ch/api/v1`
5. `flutter run -d ios` (ou android) pour verifier non-regression mobile
6. `flutter build web --release -t lib/main_web.dart --dart-define=API_BASE_URL=https://api.mint.ch/api/v1`

### 16.8 Definition of Done (rebuild complet)

1. phase 1, 2, 3, 4 implantees
2. aucune regression mobile visible
3. web buildable localement et en CI
4. catalogue unique actif pour les ecrans de discovery (11 consommateurs)
5. side menu web fonctionnel sur navigation shell
6. aucun import `dart:io` dans le code compilant pour le web
7. services iOS-only silencieusement desactives sur web
8. documentation architecture a jour (ce fichier)

---

## 17) Inventaire complet des fichiers modifies/crees

Cette section liste exhaustivement tous les fichiers concernes par l'architecture app + web, pour faciliter une re-implementation.

### 17.1 Fichiers crees (nouveaux)

1. `apps/mobile/lib/bootstrap/mint_bootstrap.dart` — bootstrap commun
2. `apps/mobile/lib/main_web.dart` — entree web
3. `apps/mobile/lib/app_web.dart` — shell web (retourne MintApp)
4. `apps/mobile/lib/features/platform/presentation/web/web_viewport_layout.dart` — cadre web desktop
5. `apps/mobile/lib/content/feature_catalog.dart` — catalogue de contenu unique
6. `apps/mobile/lib/screens/web/web_home_screen.dart` — ecran d'accueil web
7. `.github/workflows/web.yml` — pipeline CI/CD deploy web

### 17.2 Fichiers modifies (existants)

#### Infrastructure

1. `apps/mobile/lib/main.dart` — simplifie, delegue au bootstrap
2. `apps/mobile/lib/app.dart` — ajout builder web (`WebViewportLayout`) + import kIsWeb

#### Services platform-safe

3. `apps/mobile/lib/services/ios_iap_service.dart` — `dart:io` -> `foundation`
4. `apps/mobile/lib/services/notification_service.dart` — `dart:io` -> `foundation`

#### Navigation shell

5. `apps/mobile/lib/screens/main_navigation_shell.dart` — side menu web desktop

#### Ecrans migres pattern A (2 colonnes)

6. `apps/mobile/lib/screens/simulator_3a_screen.dart`
7. `apps/mobile/lib/screens/simulator_compound_screen.dart`
8. `apps/mobile/lib/screens/simulator_leasing_screen.dart`
9. `apps/mobile/lib/screens/simulator_disability_gap_screen.dart`
10. `apps/mobile/lib/screens/job_comparison_screen.dart`
11. `apps/mobile/lib/screens/divorce_simulator_screen.dart`
12. `apps/mobile/lib/screens/succession_simulator_screen.dart`
13. `apps/mobile/lib/screens/donation_screen.dart`

#### Ecrans migres pattern B (conteneur centre)

14. `apps/mobile/lib/screens/consumer_credit_screen.dart`
15. `apps/mobile/lib/screens/debt_risk_check_screen.dart`
16. `apps/mobile/lib/screens/lamal_franchise_screen.dart`
17. `apps/mobile/lib/screens/coverage_check_screen.dart`
18. `apps/mobile/lib/screens/unemployment_screen.dart`
19. `apps/mobile/lib/screens/first_job_screen.dart`
20. `apps/mobile/lib/screens/fiscal_comparator_screen.dart`

#### Ecrans migres pattern C (responsive tab list)

21. `apps/mobile/lib/screens/mariage_screen.dart`
22. `apps/mobile/lib/screens/naissance_screen.dart`
23. `apps/mobile/lib/screens/concubinage_screen.dart`

#### Discovery/explore

24. `apps/mobile/lib/screens/tools_library_screen.dart` — branche sur catalogue
25. `apps/mobile/lib/screens/main_tabs/explore_tab.dart` — branche sur catalogue
26. `apps/mobile/lib/screens/timeline_screen.dart` — metadonnees via catalogue

#### Widgets consommateurs du catalogue

27. `apps/mobile/lib/widgets/life_event_suggestions.dart`
28. `apps/mobile/lib/widgets/coach/explore_hub.dart`
29. `apps/mobile/lib/widgets/coach/chiffre_choc_section.dart`
30. `apps/mobile/lib/widgets/dashboard/retirement_checklist_card.dart`
31. `apps/mobile/lib/widgets/dashboard/arbitrage_teaser_card.dart`
32. `apps/mobile/lib/widgets/dashboard/couple_action_plan.dart`
33. `apps/mobile/lib/widgets/educational/stress_check_insert_widget.dart`
34. `apps/mobile/lib/screens/advisor/onboarding_30_day_plan_screen.dart`

#### Dependances

35. `apps/mobile/pubspec.lock` — dependances alignees

#### Documentation

36. `docs/CICD_ARCHITECTURE.md` — ajout section web workflow
37. `docs/APP_WEB_LONG_TERM_ARCHITECTURE.md` — ce fichier
