---
name: ux-2028-research
description: État-des-lieux UX — ce qu'est une app financière AI-native state-of-the-art 2026-2028, audit de l'IA/navigation MINT contre cette barre, expérience-cible, et challenge de la vision fondateur (breadth vs depth, conversational-first pour le mass-affluent suisse).
metadata:
  type: research
  date: 2026-06-12
  author: ux-researcher
---

# MINT vs l'état de l'art AI-native 2026-2028 — recherche, audit IA/UX, expérience-cible, challenge fondateur

## TLDR

1. **La recherche valide à 80% la vision « widgets rendus pendant la conversation »** — mais pas la version naïve. Les Generative Interfaces battent le chat pur à **84% de préférence** (arxiv 2508.19227), surtout en domaines structurés/denses (93,8% en data-viz). MINT a **déjà** la bonne architecture pour ça (`widget_renderer.dart` = palette fixe de ~12 widgets sélectionnés par tool-call LLM — exactement le pattern « declarative intermediate representation » recommandé, pas le HTML free-form risqué). Le problème n'est pas l'idée, c'est que MINT **n'a jamais consolidé l'IA autour d'elle**.

2. **L'IA de MINT est une accrétion de phases, pas une architecture pour la vision orchestrateur-coach.** 104 fichiers `*_screen.dart`, ~324 déclarations de route dans `app.dart`, ~50 simulateurs/life-events traités comme écrans canoniques séparés. Le shell 4-onglets (Aujourd'hui / Mon argent / Coach / Explorer) met le coach **à côté** des surfaces qu'il devrait orchestrer, pas **au-dessus**. Yesterday's real-user session l'a vu : chat ≠ Coach tab, conversation non mémorisée cross-surface, register old-Material vs onboarding éditorial, 6 arbres a11y vides. **Confirmé en code** (§2).

3. **Le « conversational-first » est un pari risqué pour le mass-affluent suisse 35-55.** La recherche pousse vers l'**hybride** : Bank of America a explicitement **retiré le bouton chat flottant d'Erica pour une interface de recherche** parce que les clients plus âgés ne comprenaient pas le paradigme chatbot mais comprenaient instinctivement la recherche. Revolut AIR (avril 2026, 13M users) place l'IA en **swipe-down depuis le home**, pas comme onglet — l'assistant est une couche au-dessus de l'app, pas une destination.

4. **« Tous les événements de vie » (18) est la plus grande faiblesse stratégique, pas une force.** Origin gagne en **profondeur** (forecasting + modélisation de décisions dans un seul système) ; Cleo gagne par **personnalité + behavior change**, pas par couverture. Les apps PFM meurent quand elles cessent d'être utiles après quelques semaines (« tracking alone doesn't move the needle »). 18 life-events à parité = 18 surfaces sous-utilisées, aucune profondeur. **Recommandation : depth sur 3-4 events à fort déclencheur émotionnel + argent, le reste en conversation générative à la demande.**

5. **La confiance est LE produit, et MINT a déjà l'infra (ConfidenceBand, EnrichmentPrompts, 4-couches) — mais elle est noyée.** La recherche (η²=0.141 : une seule erreur AI détruit la confiance, 14% de variance) impose : provenance visible, hypothèses éditables, explication post-erreur. MINT a les composants ; ils sont enterrés dans des écrans-simulateurs au lieu d'être la grammaire centrale de la couche conversationnelle.

---

## 1. Ce qu'est une app financière AI-native state-of-the-art (2026-2028)

### 1a. Generative / adaptive UI — recherche + production

**Le verdict de recherche est clair et favorable à la vision MINT, avec des garde-fous précis.**

- **Generative Interfaces for Language Models** (arxiv 2508.19227v2, 2025) : les interfaces génératives battent le chat conversationnel à **84% de préférence globale** vs Claude 3.7, **+86% sur l'esthétique**, **+81% sur la satisfaction d'interaction**, et **86,5% sur la perception de crédibilité/confiance**. Préférence **93,8% en data-viz**, **87,5% en business strategy** — exactement les domaines de MINT (chiffres, projections, comparaisons). **MAIS** : le texte pur reste préféré (50%) en domaines « math-heavy » — donc le coach doit savoir **ne pas** rendre un widget quand une phrase suffit. ([arxiv 2508.19227](https://arxiv.org/html/2508.19227v2))
- **Le pattern gagnant en production = palette déclarative, pas HTML free-form.** Le système Jelly (Chen et al. 2025) interpose une **représentation intermédiaire déclarative** (schéma objet-relationnel) entre le prompt et l'UI rendue — au lieu de laisser le LLM générer du HTML/JS arbitraire. Google Generative UI confirme que la génération d'UI est une « emergent capability » mais signale les **failure modes** : latence « jusqu'à plusieurs minutes », complexité inutile pour des requêtes simples, limites HTML/JS. ([arxiv 2508.19227](https://arxiv.org/html/2508.19227v2), [Google Research](https://research.google/blog/generative-ui-a-rich-custom-visual-interactive-user-experience-for-any-prompt/), [awesome-generative-ui](https://github.com/narrowin/awesome-generative-ui))
- **Canvas + chat hybride = le pattern des leaders.** Claude Artifacts (environnement d'exécution, composants React interactifs au-delà de 15 lignes), ChatGPT Canvas (panneau d'édition latéral), Perplexity Spaces (sources/références visibles pour valider chaque claim). La constante : **le chat est le fil de pensée, l'artefact/canvas est la surface durable et manipulable.** ([MindStudio](https://www.mindstudio.ai/blog/what-is-claude-generative-ui-vs-canvas-artifacts), [Altar.io](https://altar.io/next-gen-of-human-ai-collaboration/))

> **Implication MINT** : la vision fondateur (« le coach rend des widgets/graphes/écrans pendant la conversation ») est **scientifiquement validée**. MINT a même déjà construit le bon mécanisme (`widget_renderer.dart`, dispatch sur tool-calls `show_score_gauge` / `show_fact_card` / `show_budget_snapshot` / `route_to_screen` / `generate_financial_plan`). Ce qui manque : la palette est trop pauvre (~12 widgets), et elle vit **dans** un écran de chat parmi 104 écrans au lieu d'être la grammaire de toute l'app.

### 1b. AI money coaches qui MARCHENT — ce qui rend sticky, ce qui échoue

| Produit | Ce qui rend sticky | Ce qui échoue / limite | Leçon pour MINT |
|---|---|---|---|
| **Cleo** ([Yahoo](https://finance.yahoo.com/news/cleo-becomes-first-ai-money-130000784.html), [gventures](https://www.gventures.co/post/meet-cleo-the-ai-finance-app-that-captivated-gen-z)) | **Personnalité** (sassy, « parle comme une ado »), engagement **20x** vs banque classique, behavior change > tracking, **mémoire long-terme + voix** (Cleo 3.0), gamification/cashback. 1M abonnés payants, $250M ARR. | Gen Z, ton clivant, cashback = modèle US peu transposable en Suisse. | **La personnalité et la mémoire sont le moat, pas la couverture fonctionnelle.** MINT a une identité de voix forte (« te dit ce que personne n'a intérêt à te dire ») — c'est son Cleo-moment. Mais sans mémoire cross-surface, il n'y a pas de relation. |
| **Origin** ([useorigin](https://useorigin.com/resources/blog/copilot-vs-monarch-vs-origin-which-personal-finance-app-is-actually-worth-it)) | **Profondeur** : forecasting + modélisation de décisions (acheter une maison, changer de job) dans **un seul système** intégré. « understand what to do next, see how decisions play out ». | — | **C'est la vision MINT, mais via depth, pas breadth.** Origin ne fait pas 18 events ; il fait *modéliser des décisions* profondément. |
| **Copilot Money** | UI rapide/belle, sync propre, plaisir d'usage. « design is the difference between sticking and abandoning ». | Tracking pur plafonne vite. | Le design éditorial de MINT (DS v2) est un vrai atout — à condition d'être cohérent (il ne l'est pas, §2). |
| **Monarch** | Flexibilité/customisation pour power-users. | Niche tweakers. | Pas la cible MINT (mass-affluent ≠ tweakers). |
| **Revolut AIR** (avr. 2026, [Revolut](https://www.revolut.com/news/revolut_enters_new_era_of_money_intelligence_with_launch_of_ai_assistant/), [Finextra](https://www.finextra.com/newsarticle/47551/revolut-introduces-ai-assistant-for-money-management)) | IA **en swipe-down depuis le home**, remplace la navigation multi-étapes par une couche conversationnelle. Zero data retention. Starling + NatWest ont suivi en mars 2026. | L'IA reste une **surface d'accès**, pas le produit entier. | **Le pattern 2026 = IA en couche-au-dessus, invocable de partout, pas un onglet parmi d'autres.** |

**Le fil rouge de l'échec PFM** ([useorigin](https://useorigin.com/resources/blog/copilot-vs-monarch-vs-origin-which-personal-finance-app-is-actually-worth-it)) : « people don't stop using finance apps because they don't care—they stop because the app stops being useful. Once you've seen your spending a few times, tracking alone doesn't move the needle. » → La rétention vient de l'**utilité décisionnelle récurrente**, pas de la couverture.

### 1c. Patterns de confiance pour le conseil financier AI

La recherche est sévère et directement actionnable :

- **Une seule erreur AI détruit la confiance de façon disproportionnée.** η²=0.141 — ~14% de la variance de confiance expliquée par la seule occurrence d'erreur ; effet **plus fort** qu'avec un conseiller humain (« perfect automation schema » : on attend l'AI parfaite). ([PMC12561693](https://pmc.ncbi.nlm.nih.gov/articles/PMC12561693/))
- **L'explication post-erreur répare ET dépasse le niveau de confiance initial** (η²=0.086, confiance > baseline au round 3). Donc : **rendre le raisonnement visible n'est pas cosmétique, c'est le mécanisme de survie.** ([PMC12561693](https://pmc.ncbi.nlm.nih.gov/articles/PMC12561693/))
- **« Trust is no longer a feature; it is the fundamental product. »** 70% des dirigeants finance devront expliquer les outputs AI ; provenance, traçabilité et transparence par-rôle deviennent non-négociables. ([erp.today](https://erp.today/finance-ai-trust-gap-critical-as-explainability-becomes-non-negotiable/), [WEF](https://www.weforum.org/stories/2025/12/this-is-what-the-new-frontier-of-ai-powered-financial-inclusion-looks-like/))
- Nuance suisse : le marché suisse valorise FINMA, ségrégation des fonds, et **modèles hybrides** (plateforme digitale + sessions humaines disponibles) — la confiance ne se gagne pas par l'automation seule. ([Alpian](https://www.alpian.com/blog/investing/robo-advisors-in-switzerland), [ZHAW Wealth Management](https://blog.zhaw.ch/wealth-management/2024/04/05/the-fusion-of-robo-advisors-and-genai-a-revolution-in-swiss-wealth-management/))

> **Implication MINT** : MINT a **déjà** la grammaire de confiance (`ConfidenceBand`, `EnrichmentPrompts`, le moteur 4-couches, hypothèses éditables, disclaimers LSFin, `EnhancedConfidence` 4-axes). C'est un **avantage rare**. Mais cette grammaire vit dans les écrans-simulateurs, pas dans la couche conversationnelle où la recherche dit qu'elle compte le plus. La confiance doit être **rendue par le coach à chaque chiffre**, pas reléguée à un dashboard de confiance consultable (cat. F).

### 1d. Anticipation 2028 — agentic finance, coaching proactif, open banking + document AI

- **Le shift = réactif → proactif, mais « bounded autonomy ».** Gartner : 15% des décisions quotidiennes prises de façon autonome par agentic AI d'ici 2028 ; 70% des leaders finance veulent démocratiser le conseil jadis réservé aux HNW. **Mais** : « The future is not fully autonomous finance, but bounded autonomy where humans define the boundaries. » ([neurons-lab](https://neurons-lab.com/articles/agentic-ai-in-financial-services-2026/), [Medium/Coinmonks](https://medium.com/coinmonks/the-rise-of-agentic-finance-when-ai-starts-acting-on-your-money-36a96a9ba4bd))
- **Document AI est résolu.** IDP atteint 99%+ sur l'extraction de relevés bancaires, **template-free**, n'importe quelle banque sans config. ([Affinda](https://www.affinda.com/industries/banking-finance/), [statementextract](https://statementextract.com/blogs/paperless-financial-document-management-2025/)) → La vision MINT « upload de documents qui centralise ta vie financière suisse » est **techniquement banalisée** ; le différenciateur n'est pas l'extraction mais **ce que le coach en fait** (traduction en choix de vie, couche 2-3 du moteur).
- **Open banking européen** : $31,6B (2024) → $135B (2030), CAGR 27,6%. PFM = use-case clé. ([Kong](https://konghq.com/blog/learning-center/guide-on-open-banking), [Mastercard OB](https://developer.mastercard.com/open-banking-europe/documentation/licensed/use-cases/pfm/)) → confirme la roadmap open-banking MINT (next-year), mais ce n'est pas un moat en soi.

---

## 2. Audit de l'IA/navigation/UX de MINT contre cette barre

**Méthode** : lecture de `docs/MINT_IDENTITY.md`, `docs/DESIGN_SYSTEM.md`, puis walk du code : `apps/mobile/lib/app.dart` (~324 routes), `widgets/mint_shell.dart`, `screens/coach/`, `screens/aujourdhui/`, `screens/explore/explorer_screen.dart`, `screens/mon_argent/`, `widgets/coach/widget_renderer.dart`, `services/coach/`, `screens/auth/`.

### Verdict global : **accrétion de phases, pas architecture pour la vision orchestrateur-coach.**

Le DESIGN_SYSTEM.md classifie lui-même **101 écrans** (§10). Le filesystem en compte **104** `*_screen.dart`. Le coach est l'**onglet n°3 d'un shell 4-tabs** (`mint_shell.dart:8`), pas la couche qui orchestre les 100 autres. C'est l'inverse de la vision « orchestrateur-coach ».

### Table des écarts (MINT actuel → barre 2028)

| Dimension | Barre state-of-the-art 2026-2028 | MINT actuel (cité en code) | Écart | Sévérité |
|---|---|---|---|---|
| **Place de l'IA** | IA = couche au-dessus de l'app, invocable de partout (Revolut AIR swipe-down ; BoA Erica search-style) | Coach = **onglet 3/4**, et peut être **caché** par `FeatureFlags.chatTabVisible=false` (`mint_shell.dart:48-67`) avec un overlay de secours | L'IA est une destination, pas une couche orchestrante | 🔴 Critique |
| **Mémoire conversationnelle** | Mémoire long-terme = moat (Cleo 3.0) ; canvas durable (Artifacts) | Chat overlay **sans Provider/ChangeNotifier partagé** pour les messages (`mint_chat_overlay.dart` : 0 match `conversationId`/`sessionId`/`_messages`) ; `SharedPreferences` sert au throttle/metrics, pas à l'état de conversation cross-surface | Conversation non mémorisée entre chat ↔ Coach tab ↔ surfaces (confirmé session real-user d'hier) | 🔴 Critique |
| **Generative UI** | Palette déclarative LLM-sélectionnée, riche, contextuelle | `widget_renderer.dart` : bon pattern mais **palette pauvre** (~12 tool-calls : score gauge, fact card, budget snapshot, route, plan, doc, commitment…) + `ResponseCardService` = **catalogue fixe de ~10 types** (`response_card_service.dart`), pas génératif | Le mécanisme existe ; il est sous-dimensionné et non central | 🟠 Majeur (mais base saine) |
| **Cohérence visuelle** | Design = différenciateur de rétention (Copilot) | `register_screen.dart` mélange MintColors (50 hits) ET raw Material (`Colors.`/`TextField`/`Theme.of` 32 hits) ; onboarding éditorial neuf ↔ auth old-Material | Rupture d'expérience au moment le plus fragile (inscription) | 🟠 Majeur |
| **Accessibilité** | A11y non-négociable, AAA tokens déjà définis (DS §AAA) | 6 écrans avec arbres a11y vides (session real-user d'hier) ; `explorer_screen.dart` = `GridView.count` 2-col = **pattern interdit #1** du propre DS de MINT (« Grille 2×2 de cartes avec icônes ») | MINT viole son propre design system sur une surface de nav primaire | 🟠 Majeur |
| **Grammaire de confiance** | Provenance/explication = mécanisme de survie (η²=0.141) | Infra présente (`ConfidenceBand`, `EnrichmentPrompts`, 4-couches, `confidence_dashboard_screen` cat. F) mais **reléguée** à des écrans consultables, pas rendue inline par le coach | Le meilleur atout de MINT est enterré | 🟡 Modéré (atout mal exploité) |
| **Surface produit** | Depth sur peu de décisions récurrentes (Origin) | ~50 écrans life-event/simulateur traités en routes canoniques séparées (`app.dart` ~324 routes) | Largeur sans profondeur ; coût de maintenance et de cohérence énorme | 🔴 Critique (stratégique) |
| **Navigation** | Mental-model-first (BoA : search > chat pour seniors) | 4 onglets dont les noms (Aujourd'hui / Mon argent / Coach / Explorer) sont raisonnables, mais Explorer = grille de 7 hubs → 50 sous-écrans | L'arbre est large et plat ; le coach ne le traverse pas pour l'utilisateur | 🟠 Majeur |

### Ce qui est BON et à préserver (ne pas jeter)

- **`widget_renderer.dart`** : l'architecture tool-call → widget est *exactement* le pattern recommandé par la recherche (declarative intermediate representation). Base saine à étendre.
- **La grammaire de confiance** (4-couches, ConfidenceBand, EnrichmentPrompts, EnhancedConfidence 4-axes) : rare et alignée avec la recherche 2026. C'est un moat sous-exploité.
- **L'identité de voix** (MINT_IDENTITY.md) : forte, différenciante, compliance-aware (LSFin) — c'est le « Cleo-moment » de MINT, en plus mature.
- **Le DS v2 éditorial** (tons chauds, hero one-number, anti-cockpit) : aligné avec « design = rétention » (Copilot) — à condition de l'appliquer partout.

---

## 3. L'expérience-cible 2028 (5-7 surfaces, ce qu'on tue, modèle de navigation)

**Principe directeur** : le coach n'est pas un onglet, c'est la **couche d'orchestration**. Les écrans canoniques deviennent des **artefacts** que le coach rend, ouvre et co-édite — pas des destinations à chercher dans un arbre de 100 nœuds.

### Les 5 surfaces core (réduire de ~100 écrans à 5 surfaces + une palette d'artefacts)

1. **Aujourd'hui (home/ambient)** — état présent + 1 cap du jour + invocation coach. Le « always-on » que la recherche valide (engagement distribué, pas concentré sur les trigger-moments). Reste l'entrée.
2. **Coach (la couche, pas l'onglet)** — invocable **de partout** (swipe-down façon Revolut AIR, ou bouton persistant), avec **mémoire unique** et cross-surface. Rend les artefacts (widgets/graphes/plans) inline. C'est ici que vivent les ~12+ widgets génératifs, enrichis.
3. **Mon argent (le patrimoine vivant)** — agrégation open-banking + documents uploadés, traduits par le coach en implications. Document AI est commoditisé ; le différenciateur = la couche 2-3 du moteur MINT (traduction humaine + perspective perso).
4. **Plans / Décisions (le canvas durable)** — là où une conversation devient un artefact persistant et manipulable (à la Artifacts/Canvas). Modéliser mariage, achat immobilier, changement de job *en profondeur* (le moat Origin). **3-4 décisions profondes, pas 18.**
5. **Profil & Confiance** — provenance, hypothèses éditables, complétude des données (EnrichmentPrompts), réglages, compliance. La grammaire de confiance devient une surface, pas un dashboard enterré.

### Ce qu'on TUE (ou fusionne)

- **~50 écrans simulateur/life-event canoniques** → deviennent des **artefacts rendus par le coach** (ou des modes du canvas Plans), pas des routes séparées. Ex : `mariage_screen`, `divorce_simulator_screen`, `naissance_screen`, `frontalier_screen`, `expat_screen`, les ~18 simulateurs cat. B → palette d'artefacts paramétrés, pas 50 fichiers de 30-60KB.
- **`explorer_screen` (grille 2×2 interdite par le propre DS)** → tué ou remplacé par un point d'entrée conversationnel (« Qu'est-ce qui bouge dans ta vie ? ») + suggestions. La grille de 7 hubs menant à 50 écrans est l'anti-pattern de navigation.
- **`conversation_history_screen` séparé** → fusionné dans la mémoire unique du coach (la conversation EST l'historique).
- **Doublons** : `explore_hub_screen` + `explorer_screen`, `ask_mint_screen` + `coach_chat_screen`, `cockpit_detail` + `retirement_dashboard` → un seul chemin canonique chacun.

### Modèle de navigation cible

- **3 destinations persistantes** (Aujourd'hui / Mon argent / Plans) + **coach invocable partout** (couche, pas tab) + **profil/confiance en drawer**. C'est l'hybride que la recherche valide : surfaces pour le mental-model du mass-affluent (BoA), coach pour la puissance.
- **Le coach traverse l'arbre POUR l'utilisateur** : « montre-moi l'impact de mon mariage » → le coach rend l'artefact mariage inline, pas « va dans Explorer > Famille > Mariage ».

---

## 4. CHALLENGE DE LA VISION FONDATEUR (obligatoire)

> Le travail d'un UX researcher honnête n'est pas de valider la vision mais de la confronter aux données. Voici où la recherche contredit les hypothèses du fondateur.

### Challenge #1 — « Tous les événements de vie » (18, à parité) est une faiblesse, pas une force.

**La recherche dit : depth bat breadth.** Origin gagne par la profondeur de modélisation décisionnelle ; Cleo par la personnalité+behavior change ; aucune app gagnante ne gagne par couverture exhaustive. Les apps PFM meurent quand l'utilité s'épuise (« tracking alone doesn't move the needle »). La stratégie wedge (un cas d'usage maîtrisé, puis adjacences guidées par la data) bat le super-app (large d'emblée) en early stage. ([useorigin](https://useorigin.com/resources/blog/copilot-vs-monarch-vs-origin-which-personal-finance-app-is-actually-worth-it), [Finextra super-app](https://www.finextra.com/blogposting/30812/top-7-super-app-strategies-for-banking-and-fintech-monetisation))

**18 events à parité, c'est :** 18 surfaces sous-utilisées, aucune profondeur sur aucune, un coût de cohérence (104 écrans, 6 arbres a11y vides, register old-Material) qui s'explique *précisément* par cet étalement. **Recommandation : choisir 3-4 events à fort déclencheur (émotion + argent + déclencheur clair) — mariage/divorce, achat immobilier, arrivée d'enfant, changement de job/indépendance — les faire à la profondeur d'Origin, et router TOUT le reste vers la couche conversationnelle générative à la demande.** Le moteur 4-couches + widget_renderer rendent ça possible sans 50 écrans.

*Nuance / contre-argument* : la « parité des 18 events » est aussi un **positionnement anti-retraite** (CLAUDE.md règle #3) qui a une vraie valeur de trust (ne pas être « encore une app retraite »). On peut garder le *récit* « MINT couvre ta vie » tout en concentrant l'*ingénierie* sur 3-4 events profonds + couverture conversationnelle pour la longue traîne. Breadth dans le discours, depth dans le produit.

### Challenge #2 — « Conversational-first » est risqué pour le mass-affluent suisse 35-55.

**La recherche dit : hybride, pas chat-first.** Bank of America a **retiré le bouton chat flottant d'Erica au profit d'une interface de recherche** parce que les clients plus âgés ne comprenaient pas le paradigme chatbot. Revolut AIR met l'IA en swipe-down (couche), pas en destination. Finshape a dû ajouter des conversation-starters dans l'UI parce que les users allaient vers l'historique de transactions même quand l'IA était disponible. ([neuronux](https://www.neuronux.com/post/ux-design-for-conversational-ai-and-chatbots), [Revolut](https://www.revolut.com/news/revolut_enters_new_era_of_money_intelligence_with_launch_of_ai_assistant/))

**Le 35-55 mass-affluent suisse n'est pas le Gen Z de Cleo.** Il valorise FINMA, la ségrégation des fonds, les modèles hybrides humain+digital ([Alpian](https://www.alpian.com/blog/investing/robo-advisors-in-switzerland), [ZHAW](https://blog.zhaw.ch/wealth-management/2024/04/05/the-fusion-of-robo-advisors-and-genai-a-revolution-in-swiss-wealth-management/)). Un écran qui s'ouvre sur un champ de chat vide demande à l'utilisateur de *formuler* sa question — friction maximale pour quelqu'un qui ne connaît pas son propre vocabulaire financier (ce que MINT_IDENTITY reconnaît : « il peut ne pas connaître les termes »).

**Recommandation : surface-first, coach-deep.** L'utilisateur arrive sur des surfaces lisibles (Aujourd'hui, Mon argent) avec des **affordances conversationnelles contextuelles** (« Pourquoi ce chiffre ? », « Et si je me marie ? ») plutôt qu'un champ vide. Le coach est partout invocable mais ne demande jamais à l'utilisateur de démarrer une conversation à froid. Le chat pur est le mode *avancé*, pas le mode *par défaut*.

### Challenge #3 — « Le coach rend des widgets » est juste, mais MINT le construit comme une feature d'écran, pas comme l'architecture.

La recherche **valide** le rendu de widgets (84% de préférence) — donc le fondateur a raison sur l'idée. **Mais** MINT l'a implémenté comme une capacité *dans* `coach_chat_screen.dart` (106KB, un onglet parmi 100 écrans), pas comme la couche qui orchestre l'app. **Le widget génératif ne crée de la valeur que s'il remplace la navigation, pas s'il s'y ajoute.** Tant que les 50 écrans-simulateurs existent en parallèle, le coach n'est qu'un raccourci, pas un orchestrateur — et l'utilisateur a deux modèles mentaux concurrents (chercher dans l'arbre OU demander au coach), ce qui est précisément la confusion observée hier (chat ≠ Coach tab).

### Challenge #4 — Le document-upload « centralise ta vie financière » n'est plus un différenciateur.

Document AI est commoditisé (99%+, template-free, toute banque sans config). ([Affinda](https://www.affinda.com/industries/banking-finance/)) Le moat n'est **pas** l'extraction — c'est ce que le coach **fait** de l'extraction (couches 2-3 du moteur : traduction humaine + implication personnelle). Si MINT vend l'upload comme feature centrale, il vend une commodité. S'il le vend comme « le coach lit ton contrat et te dit ce qu'on ne t'a pas expliqué », il vend son identité. **Recommandation : ne jamais montrer l'extraction comme l'output ; toujours montrer l'implication.**

---

## Counter-arguments & data gaps (wiki_lint requirement)

- **Contre-argument à la réduction de surface** : certains life-events (frontalier, expat US/FATCA) ont une **logique réglementaire suisse irréductible** qui justifie peut-être un écran dédié et non un artefact générique — risque de compliance si le coach « improvise » un calcul FATCA. À valider avec security-auditor + business-analyst avant de tuer ces écrans.
- **Data gap** : pas de données quantitatives propres à MINT (rétention, complétion d'onboarding, taux d'usage coach vs simulateurs). Toutes les recommandations s'appuient sur la recherche externe + le walk de code, **pas** sur l'analytics MINT. La session real-user d'hier est qualitative (n=1). **Avant de tuer 50 écrans, instrumenter l'usage réel** (quels écrans sont jamais visités ?).
- **Data gap** : pas de test utilisateur suisse 35-55 spécifique au paradigme chat-vs-surface dans MINT. Les preuves (BoA, Revolut) sont transposées d'autres marchés/produits. Un test modéré à 5-7 utilisateurs cibles trancherait définitivement le Challenge #2.
- **Biais possible** : la recherche generative-UI (arxiv 2508.19227) est récente et auto-rapportée par préférence déclarée — la préférence ≠ rétention long-terme. Le 84% est un signal fort mais pas une garantie de stickiness.

## Sources

- [Generative Interfaces for Language Models (arxiv 2508.19227)](https://arxiv.org/html/2508.19227v2) · [Google Generative UI](https://research.google/blog/generative-ui-a-rich-custom-visual-interactive-user-experience-for-any-prompt/) · [awesome-generative-ui](https://github.com/narrowin/awesome-generative-ui)
- [Claude vs Canvas vs Artifacts (MindStudio)](https://www.mindstudio.ai/blog/what-is-claude-generative-ui-vs-canvas-artifacts) · [Altar.io human-AI collab](https://altar.io/next-gen-of-human-ai-collaboration/)
- [Cleo AI money coach (Yahoo)](https://finance.yahoo.com/news/cleo-becomes-first-ai-money-130000784.html) · [Cleo Gen Z (gventures)](https://www.gventures.co/post/meet-cleo-the-ai-finance-app-that-captivated-gen-z)
- [Copilot vs Monarch vs Origin (useorigin)](https://useorigin.com/resources/blog/copilot-vs-monarch-vs-origin-which-personal-finance-app-is-actually-worth-it)
- [Revolut AIR launch (Revolut)](https://www.revolut.com/news/revolut_enters_new_era_of_money_intelligence_with_launch_of_ai_assistant/) · [Finextra Revolut AI](https://www.finextra.com/newsarticle/47551/revolut-introduces-ai-assistant-for-money-management)
- [Trust dynamics human-AI advisory (PMC12561693)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12561693/) · [Finance AI trust gap (erp.today)](https://erp.today/finance-ai-trust-gap-critical-as-explainability-becomes-non-negotiable/) · [WEF AI financial inclusion](https://www.weforum.org/stories/2025/12/this-is-what-the-new-frontier-of-ai-powered-financial-inclusion-looks-like/)
- [Agentic AI finance 2026 (neurons-lab)](https://neurons-lab.com/articles/agentic-ai-in-financial-services-2026/) · [Agentic finance (Coinmonks)](https://medium.com/coinmonks/the-rise-of-agentic-finance-when-ai-starts-acting-on-your-money-36a96a9ba4bd)
- [Document AI banking (Affinda)](https://www.affinda.com/industries/banking-finance/) · [Open banking guide (Kong)](https://konghq.com/blog/learning-center/guide-on-open-banking) · [Mastercard PFM open banking](https://developer.mastercard.com/open-banking-europe/documentation/licensed/use-cases/pfm/)
- [Conversational UX best practices (neuronux)](https://www.neuronux.com/post/ux-design-for-conversational-ai-and-chatbots)
- [Swiss robo-advisors (Alpian)](https://www.alpian.com/blog/investing/robo-advisors-in-switzerland) · [GenAI Swiss wealth (ZHAW)](https://blog.zhaw.ch/wealth-management/2024/04/05/the-fusion-of-robo-advisors-and-genai-a-revolution-in-swiss-wealth-management/)
- [Life-events vs ongoing planning (Financial Brand)](https://thefinancialbrand.com/news/bank-marketing/milestone-marketing-how-to-use-life-events-to-build-long-term-banking-relationships-190005)
