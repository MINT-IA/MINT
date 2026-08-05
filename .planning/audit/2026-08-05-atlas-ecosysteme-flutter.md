# Mémo — Écosystème Flutter : catalogues d'écrans, goldens, graphes de navigation (recherche Atlas MINT)

Recherche internet effectuée le 2026-08-05 (WebSearch + WebFetch). Toutes les dates de consultation = 2026-08-05 sauf mention contraire.

## Rappel du besoin Atlas

Page HTML unique, autonome, privée (repo public → pas d'hébergement), générée jamais rédigée. Par écran : rendu réel, pourquoi (contrats YAML scellés), route dans la navigation (diagramme), statut de gouvernance ; + diagnostics mécaniques (nœuds inatteignables, culs-de-sac, écrans sans intention coach). Source de vérité = contrats YAML du repo.

---

## 1. Widgetbook — état 2025-2026

Signaux de maturité (consultés 2026-08-05) :
- pub.dev : v3.25.0 publiée ~41 jours avant consultation (≈ fin juin 2026), 785 likes, 460k téléchargements, éditeur vérifié widgetbook.io — https://pub.dev/packages/widgetbook
- GitHub : 940 ★, 256 forks, MIT, 1 907 commits main, 43 issues ouvertes, monorepo Melos actif — https://github.com/widgetbook/widgetbook
- Adoption revendiquée : « 2000+ teams » — https://www.widgetbook.io/

Découpage OSS vs Cloud :
- **OSS (gratuit, MIT)** : sandbox de widgets/écrans en isolation, use-cases (états d'un composant), knobs, addons (thèmes, locales, device frames, text scale, a11y de base), mocking. C'est une **app Flutter interactive**, pas un document.
- **Cloud (commercial, free tier)** : golden tests zéro-config multi-états/devices/thèmes, revue visuelle de PR, intégration Figma, partage stakeholders — https://www.widgetbook.io/cloud + https://docs.widgetbook.io/

Export statique : oui au sens « flutter build web -t path/to/widgetbook_main.dart » → bundle statique dans build/web, hébergeable n'importe où (le repo widgetbook-hosting + CLI servent surtout à pousser ce build vers le Cloud ; GitHub Action dédiée) — https://github.com/widgetbook/widgetbook-hosting, https://docs.widgetbook.io/~782/widgetbook-cloud/hosting, https://blog.codemagic.io/building-widgetbook-using-codemagic/. **MAIS** : le build web Flutter = bundle multi-fichiers de plusieurs Mo (main.dart.js/CanvasKit, assets) — PAS un HTML unique autonome. Incompatible avec la contrainte « un fichier HTML privé ».

Ingestion de métadonnées externes (nos YAML) : **rien de natif**. La doc par composant n'est pas first-class dans l'OSS ; le seul addon trouvé, `widgetbook_documentation_addon` (markdown par widget), est tiers et moribond : v1.0.1+2, 17 mois sans release, 0 like, 6 téléchargements — https://pub.dev/packages/widgetbook_documentation_addon. Une ingestion YAML → use-cases serait du codegen custom à écrire et à maintenir contre leur API annotations.

Limites pour notre cas : (a) pensé composants + états, pas « tous les écrans full-journey d'une app » avec navigation réelle (les use-cases sont des builders isolés, il faut mocker providers/router pour chaque écran) ; (b) aucun graphe de navigation ; (c) aucun statut de gouvernance / diagnostics ; (d) sortie = app interactive, pas page générée ; (e) la valeur différenciante (goldens auto, revue PR) est dans le Cloud payant, exclu (privé/repo public/données).

**Verdict Q1 : NE PAS ADOPTER pour l'Atlas.** Forme incompatible (app Flutter vs document généré), pas d'ingestion YAML, docs OSS faibles. Éventuellement utile plus tard comme sandbox dev interne — décision séparée, hors périmètre Atlas.

## 2. Alternatives Flutter — vivantes ou mortes ?

| Outil | Signaux (2026-08-05) | État |
|---|---|---|
| **Monarch** | pub v3.9.4, 12 mois sans release, 124 likes — https://pub.dev/packages/monarch ; GitHub Dropsource/monarch 464 ★, 717 commits, MIT — https://github.com/Dropsource/monarch | Vivant mais lent. Outil **desktop local** (binaires + app native côte à côte avec l'IDE) ; aucun export statique/web. Hors sujet Atlas. |
| **Dashbook** | v0.1.17, 14 mois sans release, 133 likes, éditeur blue-fire (Flame) — https://pub.dev/packages/dashbook | Dormant/stable, pas de dynamique. |
| **storybook_flutter** | v0.14.1, **2 ans sans release**, 345 likes — https://pub.dev/packages/storybook_flutter | Mort. |
| **storybook_toolkit** (fork) | v1.3.2 + 2.0.0-dev.4, actif, knobs + device frames + génération de goldens — https://pub.dev/packages/storybook_toolkit, https://github.com/StorybookToolkit/storybook_toolkit | Vivant mais communauté minuscule. |
| **playbook-flutter** (playbook-ui) | 82 ★, 426 commits, exige Dart 3.9+/Flutter 3.35+ (donc maintenu récemment), scénarios + **génération de snapshots multi-devices** — https://github.com/playbook-ui/playbook-flutter | Vivant, niche. Son pattern « scenario → snapshot PNG automatique » est le plus proche de notre couche rendus. |

**Verdict Q2 : Widgetbook domine le créneau catalogue interactif ; aucun ne produit un document généré ni n'ingère des contrats. Rien à adopter tel quel ; playbook-flutter valide le pattern snapshots-en-masse.**

## 3. Golden / screenshot tooling pour les rendus en masse

- **golden_toolkit (eBay)** : officiellement abandonné le 2024-09-12 (« no longer actively maintain », PRs non mergées), 334 ★ — https://github.com/eBay/flutter_glove_box. Ne pas adopter.
- **alchemist** : le standard 2025 de facto. Éditeur vérifié **Betterment** (pas VGV/BAM — attribution de la question à corriger ; inspiré de golden_toolkit), v0.14.0 il y a ~4 mois, 219 likes, MIT, couverture 100 % — https://pub.dev/packages/alchemist, https://github.com/Betterment/alchemist. Deux modes : « platform goldens » (texte réel, lisible humain) et « CI goldens » (police Ahem → **carrés colorés**, stable cross-plateforme).
- Piège pour l'Atlas : le mode CI d'alchemist rend le texte illisible — exactement l'inverse d'un rendu destiné à un humain. Pour des rendus réels : (a) goldens flutter_test natifs (`matchesGoldenFile`) avec vraies polices chargées, générés localement sur macOS (déterministe sur une seule plateforme) ; (b) le pattern playbook-flutter (snapshots runtime) ; (c) **le sweep Maestro existant de MINT** (tools/simulator/, walker) qui produit déjà des screenshots sim réels — pipeline déjà câblé, fidélité maximale (vraie navigation, vraies données seedées).
- Widgetbook Cloud fait des goldens « zéro config » mais c'est le tier payant hébergé → exclu.

**Verdict Q3 : ADOPTER le mécanisme golden natif flutter_test (fonts réelles, génération locale) OU réutiliser le sweep Maestro existant pour les PNG de l'Atlas ; alchemist en option pour la couche régression visuelle CI (mode carrés), pas pour les rendus humains.**

## 4. Visualisation / lint du graphe de navigation

- Recherches multiples (go_router/auto_route + mermaid/graphviz/visualizer/unreachable/lint) : **aucun outil OSS maintenu trouvé** qui graphe les routes Flutter ou linte l'inatteignabilité/culs-de-sac. Ni côté go_router (package officiel Flutter team — https://pub.dev/packages/go_router) ni auto_route (codegen typé — https://pub.dev/packages/auto_route). Les résultats ne remontent que les routeurs eux-mêmes.
- Le plus proche : **DCM** (dcm.dev, commercial freemium, ex-dart_code_metrics dont l'OSS est abandonné/forké) : `check-unused-files` / `check-unused-code` — proxy fichier-niveau pour écrans orphelins, pas une analyse de graphe de routes — https://dcm.dev/docs/cli/code-quality-checks/unused-files/. Licence commerciale = friction pour un lint CI de repo public.
- En interne MINT : la skill `autoresearch-navigation` détecte déjà orphelins/dead-ends/guards manquants — la brique « analyse statique des routes → graphe + diagnostics » est un territoire à construire, pas à acheter. Rendu du diagramme : mermaid pré-rendu en SVG localement (mermaid-cli) et inliné dans le HTML autonome, ou mermaid.js inliné (~1-2 Mo) — les deux compatibles fichier unique privé.

**Verdict Q4 : CONSTRUIRE (petit). Rien n'existe ; extraction des routes + reachability + mermaid = script Python/Dart maison, cohérent avec l'outillage tools/checks/ existant.**

## 5. Storybook (JS) — les patterns standardisés à imiter

Storybook 9, sorti le 2025-06-03 — https://storybook.js.org/blog/storybook-9/, https://storybook.js.org/docs/writing-tests/accessibility-testing, https://storybook.js.org/docs/writing-tests/integrations/vitest-addon :
1. **CSF (Component Story Format)** : une story = un état nommé, déclaratif, versionné dans le repo → équivalent direct de nos contrats YAML scellés (le contrat EST notre CSF).
2. **Autodocs** : page de doc générée depuis les stories, jamais rédigée à la main → exactement la doctrine Atlas « généré jamais rédigé ».
3. **Tags** : statuts (`alpha`, `stable`, `deprecated`) et rôles filtrables → calque parfait pour notre statut de gouvernance (scellé/en attente/orphelin).
4. **A11y addon** (axe-core) exécuté sur toutes les stories → notre section diagnostics mécaniques par écran (contraste, tailles tap, Semantics).
5. **Interaction tests** (`play()` + Vitest/Playwright) et **visual tests** (Chromatic) : la leçon = le catalogue devient machine à tests quand chaque entrée est exécutable ; nos contrats YAML doivent rester la clé de jointure rendu ↔ test ↔ doc.
6. **Story globals** (thème/viewport/locale par story) → axes de déclinaison des rendus (clair/sombre, fr en priorité, 320pt).

**Verdict Q5 : ne rien adopter (JS, ne rend pas Flutter), mais imiter : contrat=story, tags=gouvernance, autodocs=Atlas, a11y mécanique par écran, un seul identifiant joignant rendu/contrat/diagnostic.**

---

## Verdict global coût/maturité

- **CONSTRUIRE l'Atlas lui-même** : générateur maison (script → HTML unique autonome). Aucun outil du marché ne produit un document généré depuis des contrats YAML avec graphe de navigation + gouvernance + diagnostics ; Widgetbook est un produit interactif orthogonal et sa doc OSS est faible. Coût : modéré ; le repo a déjà tools/checks/, contrats YAML, sweep Maestro.
- **ADOPTER pour la couche rendus** : goldens flutter_test natifs (fonts réelles, génération locale déterministe) ou réutilisation du sweep Maestro existant ; alchemist (Betterment, actif) uniquement si on veut une couche régression visuelle CI en plus.
- **CONSTRUIRE le lint de graphe de navigation** : n'existe nulle part en OSS ; DCM ne couvre que l'inutilisé fichier-niveau et est commercial.
- **NE PAS ADOPTER** : Widgetbook pour l'Atlas (forme incompatible, YAML non ingérable, valeur clé dans le Cloud payant) ; golden_toolkit (mort) ; storybook_flutter (mort) ; Monarch/Dashbook (desktop local / dormant).

## Sources principales (toutes consultées 2026-08-05)

- https://pub.dev/packages/widgetbook · https://github.com/widgetbook/widgetbook · https://www.widgetbook.io/cloud · https://docs.widgetbook.io/ · https://github.com/widgetbook/widgetbook-hosting · https://docs.widgetbook.io/~782/widgetbook-cloud/hosting
- https://pub.dev/packages/widgetbook_documentation_addon
- https://pub.dev/packages/monarch · https://github.com/Dropsource/monarch · https://pub.dev/packages/dashbook · https://pub.dev/packages/storybook_flutter · https://pub.dev/packages/storybook_toolkit · https://github.com/StorybookToolkit/storybook_toolkit · https://github.com/playbook-ui/playbook-flutter
- https://pub.dev/packages/alchemist · https://github.com/Betterment/alchemist · https://github.com/eBay/flutter_glove_box
- https://pub.dev/packages/go_router · https://pub.dev/packages/auto_route · https://dcm.dev/docs/cli/code-quality-checks/unused-files/ · https://dcm.dev/docs/cli/code-quality-checks/unused-code/
- https://storybook.js.org/blog/storybook-9/ · https://storybook.js.org/docs/writing-tests/accessibility-testing · https://storybook.js.org/docs/writing-tests/integrations/vitest-addon · https://blog.codemagic.io/building-widgetbook-using-codemagic/
