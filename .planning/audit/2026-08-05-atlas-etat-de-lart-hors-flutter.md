# Atlas MINT — état de l'art HORS Flutter (recherche web, 2026-08-05)

Périmètre : doc d'interface générée depuis une source de vérité + pratiques vibe coding / agents.
Cible comparée : page unique privée, générée jamais rédigée, montrant écrans + pourquoi ils existent (herméneutique) + routes + statut de gouvernance (contrats YAML scellés) + diagnostics mécaniques de navigation.

---

## Q1 — Design-system docs « single source of truth »

| Outil | Ce qu'il fait | URL | Date/maturité |
|---|---|---|---|
| zeroheight | Doc de design system SaaS, sync bidirectionnelle Figma/Storybook/GitHub, « single source of truth », analytics d'adoption, authoring assisté IA | https://zeroheight.com/vs/supernova/ | Mature (SaaS établi, comparatifs 2025-2026 actifs) |
| Supernova | Pipeline de tokens Figma→code multi-plateforme, doc auto-sync, virage « AI-assisted » | https://www.supernova.io/blog/bridging-design-and-development-how-mews-is-scaling-their-design-system-with-supernova | Mature, setup plus lourd |
| Backlight (÷riots) | Design system in-code + doc | https://backlight.dev/ | **MORT — shutdown 1er juin 2025** |
| Specify | Plateforme de design tokens | https://alternativeto.net/software/specify/about/ | **MORT — sunset 15 nov 2025** |

Signal marché : la niche SaaS « SSOT design docs » se contracte (2 morts sur 4). Les survivants documentent des **composants et tokens**, jamais des **écrans avec intention et gouvernance**.

Équivalents OSS auto-hébergeables (docs-as-code pour UI) :
- Storybook (self-host, docs mode) — https://storybook.js.org — mature, granularité composant.
- Histoire (Vite, Vue/React/Svelte), Pattern Lab (atomic design), React Cosmos, Fractal, codedocs (https://github.com/erikpukinskis/codedocs) — tous granularité composant, aucun ne porte routes/gouvernance/pourquoi. Sources : https://fwdgrade.com/storybook/alternatives, https://stephaniewalter.design/blog/the-pragmatic-designer-local-and-self-hosted-tools-for-banking-insurance-and-other-institutions/
- Aucun OSS trouvé qui documente des ÉCRANS (vs composants) depuis une source machine.

## Q2 — Doc d'écrans GÉNÉRÉE depuis specs machine

- **Compodoc** (Angular/Nest) — https://compodoc.app/ + https://github.com/compodoc/compodoc — OSS mature ; génère un **graphe de routes** depuis le code (y compris routes standalone/lazy, releases 2025-2026). Précédent le plus direct de « doc de navigation générée depuis la source ». Angular-only, zéro gouvernance/intention.
- **form-flow (Code for America)** — https://github.com/codeforamerica/form-flow — OSS en prod (formulaires gouvernementaux US) ; `flows-config.yaml` déclare écrans + transitions. Screen-spec YAML exécutable, mais rendu runtime, pas doc.
- **Server-driven UI** : Airbnb Ghost Platform (schéma GraphQL partagé Screens/Sections, https://medium.com/airbnb-engineering/a-deep-dive-into-airbnbs-server-driven-ui-system-842244c5f5, 2021) ; Lyft Canvas (protobuf). Écrans = données machine typées, précédent fort du « contrat d'écran », mais objectif = rendu, pas documentation ni gouvernance.
- **Spec-driven development 2025** : Kiro (AWS, juil. 2025), GitHub Spec Kit (fin 2025), Tessl (beta privée, « spec-as-source »). Analyse Martin Fowler 15 oct. 2025 (https://www.martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html) : specs = source de vérité pour GÉNÉRER DU CODE ; verbatim clé : « None explicitly generate documentation/views from specs ». Le trou est documenté par Fowler lui-même. Critiques : prolifération de markdown, agents qui ignorent les specs, parallèle avec l'échec du Model-Driven Development.
- **Serenity BDD living documentation** — https://serenity-bdd.github.io/docs/reporting/living_documentation — OSS mature (Java/Cucumber). Génère un site HTML : hiérarchie d'exigences + déroulé pas-à-pas + screenshots issus des runs de tests ; explicitement vendu comme « evidence for auditors ». Le précédent le plus proche de « diagnostics mécaniques → doc lisible », mais piloté par l'exécution des tests, pas par des contrats, et sans herméneutique produit.
- **Backstage (Spotify/CNCF)** — https://backstage.io/docs/features/software-catalog/ — OSS mature. `catalog-info.yaml` dans le repo → portail généré : entités, ownership, TechDocs, et **scorecards de gouvernance** (Soundcheck/Roadie : « every Component must have an owner », etc.). C'est LE pattern « registre YAML versionné → portail privé avec statut de conformité ». Granularité service/API, pas écran ; usine à gaz pour une seule app.
- « Screen registry » / « UX inventory » : rien de machine. Interface inventory de Brad Frost (https://bradfrost.com/blog/post/conducting-an-interface-inventory/, 2013) = screenshots manuels dans Google Slides. Les « UX audits » restent des prestations manuelles.
- **route-detect** (Red Canary) — https://redcanary.com/blog/testing-and-validation/route-detect-appsec-tool/ — OSS ; extrait les routes web pour audit sécurité. Preuve que « registre de routes extrait statiquement » existe, angle sécurité uniquement.

## Q3 — Vibe coding / agents (2025-2026)

- **Thariq Shihipar (Anthropic, équipe Claude Code), « The unreasonable effectiveness of HTML », mai 2026** — https://explainx.ai/blog/unreasonable-effectiveness-html-claude-code-thariq-2026 — LA systématisation publique la plus proche : agents produisant des grilles d'exploration HTML, artefacts de code review annotés, rapports de recherche ; « web of HTML files » persistant entre sessions ; galeries **régénérées** par scan du dossier de sorties. Repris cross-vendor par Peter Steinberger (4 juil. 2026). C'est un PATTERN d'atelier, pas un outil : rien sur écrans/routes/gouvernance.
- **Storybook MCP** — annonce 17 nov. 2025, Early Access 2 déc. 2025, React-only (https://storybook.js.org/blog/storybook-mcp-sneak-peek/) ; addon MCP qui fait générer des stories par agents (https://mcpmarket.com/server/storybook-4). Sens du flux : la doc composant NOURRIT l'agent codeur — l'inverse d'un atlas (où l'agent nourrit la doc). Très early.
- **v0.dev / Lovable** : previews jetables par génération, design systems préréglés ; aucun atlas cumulatif d'écrans. (https://vibecodinghub.org/tools/v0, https://lovable.dev/guides/vibe-coding-apps-8-options-for-beginners)
- **Académique** : ScreenAudit (CHI 2025, https://dl.acm.org/doi/10.1145/3706598.3713797) et TaskAudit (CHI 2026, https://arxiv.org/html/2510.12972v1) — agents LLM qui auditent écrans/tâches mobiles (accessibilité, erreurs de navigation Locatability/Actionability/Feedback). Diagnostics mécaniques d'écrans par agents = état de l'art de recherche, pas produit.
- **ai-mobile-ui-crawler** — https://github.com/ganainy/ai-mobile-ui-crawler — crawler Android piloté Gemini (exploration visuelle+structurelle). Jeune, proof-of-concept.
- Verdict axe 3 : personne n'a publié d'« atlas cumulatif d'écrans maintenu par agents depuis des contrats ». Le plus proche est la pratique Thariq (galeries HTML régénérées) — que le rendu Atlas MINT applique déjà de fait.

## Q4 — Visualisation de flux / navigation

- **Mermaid** (flowchart + userJourney + CLI batch) — https://mermaid.js.org/syntax/userJourney.html — OSS mature, rendu natif dans les artifacts Claude. Couche de rendu, pas d'extraction.
- **Flowgen** — https://flowgen.dev/ — SaaS récent : crawle le codebase pour tracer les étapes d'un flux, un browser-agent rejoue le flux sur le produit live et enregistre une vidéo annotée, régénération auto à chaque changement de code. Le plus proche en ESPRIT (doc de flux générée depuis le code + vérification agentique + fraîcheur auto). Mais : SaaS fermé, web-only, orienté guides support/onboarding, maturité faible (pas de pricing public visible, fetch direct 403).
- **FlowMapp** (sitemaps/user flows SaaS, dessin manuel, actif) ; **Overflow.io** (statut incertain, comparatifs le listent encore — non confirmé mort). Côté design = dessin manuel, jamais généré depuis la source.
- **Crawlers/testing** : AppCrawler (Appium/UIAutomator) construit de fait un graphe d'écrans en explorant ; c'est du test, pas de la doc. MINT couvre déjà ce rôle avec Maestro.
- **Linter de graphe de parcours** : néant en mainstream. Rien qui s'appelle « user flow linter » ; les plus proches sont route-detect (sécurité) et TaskAudit (recherche). Le diagnostic « écran orphelin / cul-de-sac / guard manquant » en lint versionné n'existe pas sur étagère (hors Flutter comme dans Flutter).

## Q5 — Verdict anti-réinvention (dur)

**Existe à ≥70 % (par morceau — l'Atlas est un assemblage, pas une invention) :**
1. Registre YAML versionné → portail privé généré avec statut de gouvernance : **Backstage + scorecards** (~90 % du pattern, mauvaise granularité : service, pas écran).
2. Doc vivante + preuves mécaniques + screenshots pour auditeurs : **Serenity BDD** (~70 %, piloté tests, pas contrats).
3. Graphe de routes généré depuis la source : **Compodoc** (~80 %, Angular-only).
4. Galerie HTML privée régénérée par agents, cumulative : **pratique Thariq/Anthropic** (pattern publié mai 2026, pas un outil).
5. Fraîcheur automatique de doc de flux sur changement de code : **Flowgen** (SaaS fermé, web).

**N'existe nulle part (trouvé nulle part après ~15 requêtes) :**
- L'« herméneutique par écran » (pourquoi l'écran existe) comme champ machine d'un contrat, projeté en doc — les specs SDD portent le rationale mais « none generate documentation/views from specs » (Fowler, oct. 2025).
- Le statut de gouvernance scellé/drift au niveau ÉCRAN (les scorecards Backstage sont l'analogue au niveau service).
- La combinaison en UN artefact autonome privé : écrans + intention + routes + statut de contrat + diagnostics de navigation.

**ADOPTER** : Mermaid pour le rendu des graphes (déjà natif artifacts) ; rien d'autre en l'état — Backstage est surdimensionné pour une app unique, Flowgen est un SaaS fermé (interdit : repo public, données privées), Serenity est un écosystème JVM.
**IMITER** : (a) règles de scorecard Backstage/Soundcheck exprimées en assertions sur le registre (« tout écran doit avoir un contrat scellé, un owner, une route atteignable ») ; (b) structure Requirements-tab de Serenity : hiérarchie exigences → preuves d'exécution → screenshots ; (c) discipline Thariq : dossier de sorties scanné, galerie régénérée, jamais éditée à la main ; (d) l'UX du graphe de routes Compodoc (lazy/guard visibles par arête).
**RÉELLEMENT NOUVEAU** : la granularité écran + contrat scellé comme source unique + herméneutique projetée + lint de navigation dans un seul HTML privé. C'est une niche vacante, pas un exploit : vacante parce que le marché documente des composants (là où est l'argent design-system) ou des services (là où est l'argent platform-engineering) — personne ne vend l'entité « écran » comme objet de gouvernance.

---
Méthode : 14 WebSearch + 3 WebFetch (flowgen.dev en 403 direct, contourné via cache moteur). Limites : recherche US-centric ; l'écosystème chinois (mini-programs, doc d'écrans WeChat) non couvert ; statut Overflow.io non tranché.
