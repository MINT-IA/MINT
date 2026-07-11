# Interaction Registry — Spécification v1.1

Status: Pilot — YAML/lint/index/Mermaid active; executor/codegen Proposed
Date: 2026-07-10
Origine : v1.0-RC (panel 5 experts, 3 itérations) + revue contextuelle repo du 2026-07-07.

> **Principe** : un bouton ne sait pas où il va — la carte le sait.
> **Promesse exacte** : éliminer l'*incohérence* (bouton cassé, back qui perd
> les données, écran orphelin, branche non testée). La carte ne produit PAS le
> raffinement UX (motion, timing, micro-interactions) — ça reste le domaine de
> `MOTION_INTERACTION_AUDIT.md`. Ne pas confondre grammaire et poésie.

---

## 0.a Amendements v1.1 (revue contextuelle — ce qui change vs v1.0-RC)

| # | Amendement | Pourquoi |
|---|---|---|
| A1 | **Cible = base propre** (`claude/mint-swiss-coach-eu33i7`), pas `dev`. L'exemple wedge (`mvp_wedge/`, lignée dev) est remplacé par le chemin réel prouvé `/data-block/revenu → /hypotheque`. | Le wedge 9 étapes et `.planning/journeys/` n'existent que sur `origin/dev` ; toute la reconstruction G0–G7 vit sur la base propre. Cartographier la lignée qu'on remplace = effort perdu. |
| A2 | **Clause de subsomption** : le registre GÉNÈRE les tables par route de `SCREEN_CONTRACTS.md` (§reads/writes/states/routesOut) et le graphe `WIRING_GRAPH` ; nouveau lint `contract_double_authority`. | Sans ça, le registre devient une 4e source de vérité concurrente — la maladie qu'il prétend soigner. Une seule carte ; les autres artefacts deviennent générés. |
| A3 | **Gate D1 recalibré** : ≥ 8 incohérences **nouvelles**, absentes de `SCREEN_CONTRACTS.md` (dead-ends D-1→D-5, îlots I-4) et de `WIRING_GRAPH`. | Les incohérences déjà documentées passeraient le gate d'avance — le go/no-go doit mesurer ce que la photo apporte, pas recompter le connu. |
| A4 | **`payload.extra` contraint par `SCREEN_CONTRACTS.md` §0 HARD RULE** : ids d'entités, enums, codes, tokens, sélection éphémère uniquement. Jamais d'objet domaine (`CoachProfile`, `ExtractionResult`, réponses de wizard…). Le lint `payload_mismatch` incorpore cette règle. | La forme `extra: dart_type` de v1.0 légitimait n'importe quel type — en tension frontale avec `SCREEN_CONTRACTS.md` §0 HARD RULE. Le test d'exécution reste à matérialiser avant activation du lint. |
| A5 | **`a11y_label` = clé ARB**, jamais une chaîne libre. | Règle i18n 6 langues du repo ; une chaîne libre dans le YAML recréerait du texte user-facing hors ARB. |
| A6 | **`analytics:` transite par le guard consentement/nLPD existant** ; un event déclaré dans une edge n'est émis que si le consentement le couvre. | La spec v1.0 ne disait rien du régime de protection des données des events. |

Réserve levée partiellement : `route_centrality` (D8) n'existe pas sur la base
propre — soit porter `.planning/journeys/PRIORITY_RUBRIC.md` depuis dev, soit
calculer la centralité directement depuis le graphe extrait (betweenness sur
les edges). Décision à prendre au moment de l'étape 1, pas avant.

## 0.b Réserves irréductibles (héritées v1.0 — pourquoi pas 10/10)

À lever par l'implémentation, pas par la spec :
1. **Extraction des navigations dynamiques** — les ternaires et `path: _fn(seg)`
   (catégories 2-3 du KNOWN-MISSES MAP-04) résisteront à l'extraction d'edges.
   Test de levée : l'extracteur couvre ≥ 90 % des navigations réelles.
2. **Walker sur scènes in-shell** — jamais éprouvé. Test : le walker distingue
   les scènes d'un shell et vérifie une transition `in_shell` de bout en bout.
3. **Ergonomie agents** — se mesure à l'usage. Test : un agent ajoute une edge
   + son bouton en < 15 min sans question au fondateur.

## 0.c Décisions de cadrage (héritées v1.0, amendées)

| # | Décision |
|---|---|
| D1 | **Photo d'abord, framework ensuite.** Étapes 1-2 (extracteur + lints sur l'existant) livrées seules. Go/no-go executor : **≥ 8 incohérences nouvelles (A3) → executor justifié ; sinon lints + walker sans executor.** Seuil écrit d'avance, non renégociable. |
| D2 | `back:` est **déclaré + linté** pour les cibles nommées (`pop_to(...)`, `reset_to(...)`) ; le walker vérifiera l'exécution runtime. Le codegen PopScope reste un chantier v2 explicite. Champ `enforcement: declared\|walker\|codegen` par propriété. |
| D3 | Guards = **source unique** : le registre GÉNÈRE les redirects GoRouter (ou les remplace). Interdiction de coexistence avec des redirects manuels (lint). |
| D4 | `test_ref:` n'est **jamais déclaratif** : référence vers un test existant, vérifiée par CI. Les fichiers multi-tests doivent référencer l'edge id ; les fichiers Maestro mono-flow peuvent citer le fichier seul jusqu'à support d'ancres edge par le lint. |
| D5 | KNOWN-MISSES sous **ratchet** : la liste ne peut que décroître (check CI compare au count committé). |
| D6 | Pas de lint `intent_vague` : les intents des edges modifiées sont extraits **en tête du diff de PR** pour revue humaine. |
| D7 | `actions:` limité aux actions **destructives ou irréversibles** en v1. |
| D8 | Walker priorisé par centralité de route (voir §0.a) + présence `analytics:` : critique en nightly, graphe complet en hebdo. |
| D9 | Squelettes Maestro générés **à la demande** (`--edge <id>`), jamais en masse. |
| D10 | Index généré **une-ligne-par-edge** (`interactions/INDEX.md`) pour la lecture agents ; les YAML par flux restent la source. |
| D11 | **(v1.1)** Relation aux specs existantes : `SCREEN_CONTRACTS.md` tables par route et `WIRING_GRAPH` deviennent des **artefacts générés** dès qu'un flux est migré ; un flux non migré reste gouverné par les docs actuels. Lint `contract_double_authority` : une route ne peut pas être déclarée à la fois dans un flux migré et éditée à la main dans les docs générés. |

## 0.d Pilot actif sans executor

Ce registre est maintenant `Status: Pilot` pour la couche YAML/lint/index/graphe
Mermaid. Il ne génère pas encore de routes, guards, tables
`SCREEN_CONTRACTS.md`, ni `WIRING_GRAPH`; l'executor/codegen reste `Proposed`.
La cartographie de parcours est active et vérifiée par
`tools/checks/mermaid_render_guard.py`, tandis que
`tools/checks/interaction_registry_lint.py` valide `interactions/*.yaml` et
régénère `interactions/INDEX.md` plus
`.planning/journeys/diagrams/interaction_graph.mmd`.
`tools/checks/interaction_coverage_audit.py --write` photographie les
références de navigation Flutter littérales et les compare aux routes déjà
déclarées comme nodes dans les YAML. Son rapport généré
`.planning/journeys/INTERACTION_COVERAGE_AUDIT.md` sert de backlog objectif pour
prioriser les prochains flux à migrer ; il ne remplace pas le registry et ne
bloque pas encore les routes non migrées.

- `docs/codex/WIRING_GRAPH.mmd` : graphe système global.
- `.planning/journeys/diagrams/data_quest_loop.mmd` : boucle
  `SCREEN_CONTRACTS.reads[] -> ledger -> DataQuest -> write-back -> recompute`.
- `.planning/journeys/diagrams/independent_protection.mmd` : chaîne
  indépendants et frontière stricte faits utilisateur vs leviers de scénario.
- `.planning/journeys/diagrams/health_disability_protection.mmd` : chaîne
  invalidité salarié/indépendant, collecte ciblée des faits manquants et dette
  explicite de migration `/invalidite`.
- `interactions/revenu_to_mortgage.yaml` : premier flux piloté, reliant
  `/data-block/:type` à `/hypotheque` avec preuve Maestro
  `apps/mobile/.maestro/f2_datablock_to_mortgage.yaml`.
- `interactions/independent_missing_facts.yaml` : flux indépendant réel,
  limité aux CTA prouvées des écrans AVS/IJM/3a/dividende-salaire/LPP vers
  DataBlock revenu/patrimoine. Il ne déclare pas de hub
  `/segments/independant -> outils` tant que le code et Maestro ne prouvent pas
  ces taps.
- `interactions/first_job_missing_facts.yaml` : flux premier emploi réel,
  limité à la CTA `first_job_enrich_profile_cta` vers DataBlock revenu. Il ne
  déclare pas de sortie vers 3a/fiscalité tant que ces transitions ne sont pas
  des interactions produit prouvées dans l'écran.
- `interactions/document_scan_recovery.yaml` : flux scan documentaire réel,
  limité aux routes dégradées `/scan/review` et `/scan/impact` quand le
  payload GoRouter manque. Il déclare seulement les CTA de récupération
  prouvées par Maestro (`r1_scan_review`, `r2_scan_impact`) et ne déclare pas
  encore le pipeline OCR réussi tant que le contrat `extra` domaine
  `ExtractionResult` / `Map` n'est pas remplacé ou explicitement testé.
- `interactions/disability_self_employed_missing_facts.yaml` : flux invalidité
  indépendant réel, couvrant la collecte progressive déclenchée depuis l'écran
  source pour `q_self_employed_income`, `q_cash_total`, puis les charges fixes
  `q_housing_cost_period_chf` et `q_lamal_premium_monthly_chf` via Budget
  Setup.
- `interactions/disability_insurance_missing_facts.yaml` : flux assurance
  invalidité salarié réel, couvrant la collecte progressive déclenchée depuis
  l'écran source pour `q_gross_salary_annual`, `q_cash_total`, puis les charges
  fixes `q_housing_cost_period_chf` et `q_lamal_premium_monthly_chf` via Budget
  Setup.
- `interactions/succession_transmission_missing_facts.yaml` : flux succession
  / transmission logement réel, couvrant la collecte ciblée de
  `q_property_market_value` puis `_coach_dettes_hypotheque` depuis
  `/succession` vers `/data-block/patrimoine`. Il impose que l'écran ne rende
  pas de cas immobilier fictif avant les faits utilisateur.
- `interactions/donation_missing_facts.yaml` : flux donation réel, couvrant la
  collecte ciblée de `q_birth_year`, `q_canton`, `q_civil_status`,
  `q_children`, `q_wealth_estimate`, `q_property_market_value` et
  `_coach_dettes_hypotheque` depuis `/life-event/donation` vers DataBlock
  revenu, ménage et patrimoine. Il impose que l'écran garde les résultats
  cachés tant que les faits métier suisses requis ne sont pas dans la
  bibliothèque utilisateur.
- `interactions/INDEX.md` et
  `.planning/journeys/diagrams/interaction_graph.mmd` : artefacts générés par le
  linter depuis les YAML, jamais édités à la main.
- `.planning/journeys/INTERACTION_COVERAGE_AUDIT.md` : artefact généré par
  l'audit de couverture, jamais édité à la main.

La règle opérationnelle immédiate est donc : une interaction critique nouvelle
est d'abord représentée dans un diagramme de parcours focalisé, puis reliée à
`SCREEN_CONTRACTS.md`, `DATA_LEDGER.md` et à une preuve Maestro/Patrol. La règle
plus forte « pas d'edge YAML, pas de bouton » reste réservée à l'étape 4 du
séquencement, après le go/no-go D1.

## 1. Modèle

Trois entités : **node** (écran ou scène), **edge** (interaction), **flow**
(regroupement + invariants). Deux niveaux de nœuds :

- `kind: route` — adressable GoRouter, DOIT ∈ `kRouteRegistry` (réutilise MAP-04).
- `kind: scene` — sous-nœud d'un shell (`parent:` requis), transition par
  provider/état, invisible de GoRouter, visible du walker.

## 2. Schéma YAML (v1.1)

```yaml
# interactions/<flow_id>.yaml
schema_version: 1            # OBLIGATOIRE — validé par lint

flow:
  id: string                 # snake_case, stable, jamais renommé
  title: string
  exits: [node_id]           # Pilot lint : node_id déclaré. flow_ref réservé v1+.
  invariants:
    max_depth: int
    back_never_loses_input: bool     # enforcement: walker (D2)
    every_scene_has_exit: bool

nodes:
  - id: string               # regex lint : ^[a-z]+\.(route|scene)\.[a-z0-9_]+$
    kind: route | scene
    parent: node_id?         # requis si scene
    route: string?           # requis si route — ∈ kRouteRegistry
    widget: string           # vérifié par l'extracteur
    platforms: [mobile, web] # défaut [mobile] — toute route web DOIT survivre
                             # au cold start sur URL directe (entry direct_url)
    entries:                 # PROVENANCE — le back DÉPEND de la provenance
      - via: flow | tab | drawer | deeplink | notification | direct_url | system
        back: pop | pop_to(node_id) | reset_to(node_id) | exits_app
        # Doctrine MINT « chaque notification = deeplink » ⇒ toute cible de
        # notification déclare son entry via: notification.
    states: [content, loading, empty, error.network, error.guard, error.compute]
        # Chaque error.* déclaré doit avoir un fallback nommé.
        # Exemption motivée : states_waived: "raison"
    guards: [guard_id]?

edges:
  - id: string               # = interactionId passé au widget CTA (API à créer)
    from: node_id
    to: node_id | action_ref # flow_ref réservé v1+.
    trigger: tap | swipe | long_press | submit | system
    intent: string           # ce que l'utilisateur CROIT faire — revu en PR (D6)
    payload:                 # CONTRAT DE DONNÉES — contraint par SCREEN_CONTRACTS.md §0 HARD RULE (A4)
      path_params: {name: dart_type}?    # ex. {type: EnrichmentType}
      query_params: {name: dart_type}?   # ex. {inputKey: InputKey}
      extra: dart_type?                  # ids / enums / codes / tokens /
                                         # sélection éphémère UNIQUEMENT (A4)
      # Le codegen vérifie que la cible consomme exactement ce contrat.
    transition: push | go | replace | reset_stack | sheet | dialog | in_shell
    back: ...                # v1 : enforcement walker (D2)
    guards: [guard_id]?
    variant: string?
    analytics: string?       # émis via le guard consentement/nLPD (A6)
    a11y_label: arb_key?     # clé ARB, jamais une chaîne libre (A5)
    test_ref: path#test_id | waived(reason)   # D4 — vérifié par CI

actions:                     # v1 : destructives/irréversibles uniquement (D7)
  - id: string
    effect: string
    confirmation: required | none   # destructive ⇒ required (lint)
    feedback: toast | inline
    then: node_id?

guards:
  - id: string
    source: string           # provider/service Dart
    on_fail: node_id | action_ref   # OBLIGATOIRE — guard silencieux = écran mort
    generates: gorouter_redirect | inline_check   # D3 — source unique
```

## 3. Exemple — flux `revenu_to_mortgage` (routes réelles base propre, chemin prouvé au runtime)

Chemin déjà prouvé : Maestro `apps/mobile/.maestro/f2_datablock_to_mortgage.yaml`
(PR #834) + deeplink `mint:///data-block/revenu` enregistré (PR #832).

```yaml
schema_version: 1
flow:
  id: revenu_to_mortgage
  title: "Faits de revenu canoniques → capacité d'achat immobilier"
  exits: [mortgage.route.hypotheque, home.route.dashboard]
  invariants: {max_depth: 4, back_never_loses_input: true, every_scene_has_exit: true}

nodes:
  - id: db.route.revenu
    kind: route
    route: /data-block/:type     # instance prouvée : type=revenu → /data-block/revenu
    widget: screens/onboarding/data_block_enrichment_screen.dart
    entries:
      - {via: flow, back: pop}
      - {via: deeplink, back: reset_to(home.route.dashboard)}   # mint:///data-block/revenu
    states: [content, loading, error.compute]

  - id: home.route.dashboard
    kind: route
    route: /home
    widget: screens/aujourdhui/aujourdhui_screen.dart
    entries:
      - {via: tab, back: exits_app}
      - {via: deeplink, back: reset_to(home.route.dashboard)}
    states: [content, loading]

  - id: mortgage.route.hypotheque
    kind: route
    route: /hypotheque
    widget: screens/mortgage/affordability_screen.dart
    entries:
      - {via: flow, back: pop}
      - {via: tab, back: pop_to(home.route.dashboard)}
    states: [content, partial, loading, error.compute]
    # partial : rend avec les facts du ledger disponibles (q_gross_salary_annual,
    # q_canton) + source sheet MINT profile — jamais de mur de formulaire.

edges:
  - id: db.edge.revenu.submit
    from: db.route.revenu
    to: mortgage.route.hypotheque
    trigger: submit
    intent: "Enregistrer mes faits de revenu et voir ma capacité d'achat"
    payload: {}              # les facts transitent par le ledger (mergeAnswers),
                             # JAMAIS par extra — SCREEN_CONTRACTS.md §0 HARD RULE + invariant I-3
    transition: push
    back: pop
    analytics: cta_clicked      # kEventCtaClicked, event générique existant
    test_ref: apps/mobile/.maestro/f2_datablock_to_mortgage.yaml
    # fichier mono-flow : l'ancre #test_id est requise seulement pour les
    # fichiers multi-tests (dart) — le lint test_ref_valid gère les deux formes
```

## 4. Lints de graphe (CI, sur YAML seul)

| Lint | Règle | Sévérité |
|---|---|---|
| schema_version_present | version connue du validateur | error |
| orphan_node | tout node a ≥ 1 entry ou edge entrante | error |
| dead_end | tout node a une sortie ou ∈ exits | error |
| unknown_route | kind:route → ∈ kRouteRegistry (MAP-04) | error |
| ghost_target / undeclared_exit | cibles existantes / sorties ∈ flow.exits | error |
| payload_mismatch | payload edge = signature consommée par la cible **ET** conforme `SCREEN_CONTRACTS.md` §0 HARD RULE (A4) | error |
| missing_states / silent_guard | states requis ; guard sans on_fail | error |
| notification_target_entry | cible de notification sans entry via: notification | error |
| web_route_direct_url | platforms: web sans entry via: direct_url | error |
| destructive_no_confirm | action destructive sans confirmation: required | error |
| guard_double_authority | redirect GoRouter manuel sur route gouvernée (D3) | error |
| contract_double_authority | route d'un flux migré éditée à la main dans SCREEN_CONTRACTS/WIRING_GRAPH générés (D11) | error |
| a11y_label_is_arb_key | a11y_label présent → clé existante dans app_fr.arb (A5) | error |
| test_ref_valid | test existe ; edge id référencé pour fichiers multi-tests, fichier seul accepté pour Maestro mono-flow | error |
| known_misses_ratchet | count(KNOWN-MISSES) ≤ count committé (D5) | error |
| depth_exceeded / id_format | max_depth ; regex de nommage | warn / error |

## 5. Artefacts générés

1. `interaction_registry.g.dart` + `InteractionExecutor` — **si et seulement si
   go/no-go D1 positif**. Lint lefthook `no-raw-navigation` avec KNOWN-MISSES
   sous ratchet.
2. `interactions/INDEX.md` — une ligne par edge (lecture agents, D10),
   généré aujourd'hui par `tools/checks/interaction_registry_lint.py --write`.
3. `.planning/journeys/diagrams/interaction_graph.mmd` — graphe Mermaid généré
   depuis les YAML pilotés ; guards en losanges, test_ref waived en pointillé et
   entries multiples restent des enrichissements v1.
4. **Tables par route de `SCREEN_CONTRACTS.md` + `WIRING_GRAPH` régénérés** pour
   les flux migrés (D11/A2) — en-tête « GÉNÉRÉ — ne pas éditer » + doc-guard.
5. Redirects GoRouter générés depuis les guards `generates: gorouter_redirect` (D3).
6. Squelettes Maestro à la demande : `--maestro-skeleton --edge <id>` (D9).
7. Assertions walker : chaque edge (priorisée D8) tapée sur simulateur,
   atterrissage vérifié ; échec = nightly fail + screenshot. La réservation
   d'une nouvelle section walker-specific dans `TEST_ROADMAP.md` reste à écrire
   avant activation du walker.

## 6. Séquencement (ordre imposé, gates chiffrés)

0. **Précondition Interaction Registry uniquement** : trains G1/G2 produit
   (#836–841) et Infra-G1→G8 (#842–#850) verts puis intégrés ou explicitement
   rebases sur la base choisie. Cette spec est `Status: Pilot` pour YAML/lint et
   ne bloque PAS les G produits restants ; elle se merge en parallèle si son
   statut pilot est rappelé dans la PR et si `gh pr checks <num>` est vert.
   #849 ne doit pas devenir une autorité produit implicite avant l'étape 4.
1. **Photo** : extracteur → `interaction_graph_current.json` (+ taps walker pour
   les scènes). Mesurer la couverture d'extraction ; si < 90 %, traiter les
   navigations dynamiques d'abord (réserve n°1). Trancher la source de
   centralité (§0.a).
2. **Audit** : lints §4 en mode rapport → `INTERACTION_GRAPH_AUDIT.md` = liste
   des incohérences, **marquées connues (déjà dans SCREEN_CONTRACTS/WIRING_GRAPH)
   vs nouvelles**.
3. **GATE D1** : ≥ 8 incohérences **nouvelles** → étapes 4-6. Sinon : lints +
   walker en garde permanente, STOP (l'executor ne se justifie pas).
4. Déclaration flux par flux : `revenu_to_mortgage` → data-blocks restants →
   coach → rapport/dossier → reste. Lint bloquant par flux migré ; à chaque flux
   migré, ses tables SCREEN_CONTRACTS passent en généré (D11).
5. `no-raw-navigation` global quand KNOWN-MISSES < 10 (et ratchet actif).
6. v2 (chantier séparé, jamais implicite) : codegen PopScope → `back` passe de
   `enforcement: walker` à `codegen`.

**Règle agents (CLAUDE.md, une ligne, à activer à l'étape 4)** : « Toute
nouvelle interaction UI commence par une edge dans `interactions/*.yaml`.
Pas d'edge, pas de bouton. »
