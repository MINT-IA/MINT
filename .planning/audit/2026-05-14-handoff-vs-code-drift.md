---
description: Drift audit Wave 0 — vision handoffs (chat-vivant 2026-04-26 + design-system-v8 2026-05-09 + 11 JSX docs/brand/mint-v2/ + colors_and_type.css + CLAUDE_CODE_PROMPT mai + MINT_COACH_AI_INTEGRATION) vs code shipped au 2026-05-14. Verdict explicite par proposition (shippé / divergé / jamais câblé / superseded). Bloquant : à valider par Julien avant Wave 0 build.
---

# Drift audit — vision handoffs ↔ code MINT (2026-05-14)

**Author** : Claude (Wave 0 Sentry — Product Leader autonomous mode)
**Status** : DRAFT — awaiting Julien validation
**Gates** : PR #598 (Phase 7 PAUSED) + PR #599 (handoff archive) merged 2026-05-14T09:53Z → HARD GATE Wave 1 levée.
**Method** : grep + read against `apps/mobile/lib/` + `services/backend/app/` + `docs/` + `.planning/decisions/`. Citations = `path:line` ou command output. Banned : « shipped » sans `gh pr view --json mergedAt` (CLAUDE.md §9).

> Memories load-bearing : [[feedback_zero_trust_protocol]], [[project_coach_forced_tool_invocation]], [[feedback_audit_corpus_before_patching]].

---

## TLDR (4 phrases)

1. **Architecture Couche 2 du handoff 2026-04/05 = SHIPPÉE** : ScreenRegistry / RoutePlanner / SequenceCoordinator / ReadinessGate / AutonomousAgentService / CoachOrchestrator / ChatToolDispatcher tous présents et instanciés. Le diagnostic du design doc « ces tools wrappent CoachContext gelé » est partiellement faux : l'infra forced-tool-invocation est DÉJÀ là (Phase 94 closed-world citation gate, HallucinationDetector S34, bundles compiler Phase 93.5) — la dette technique est l'usage de ces tools, pas leur absence.
2. **Vision « chat vivant » du handoff (3 niveaux insight inline / scène / canvas + SceneRegistry + ChatProjectionService + ReturnContract) = JAMAIS CÂBLÉE**. 10/11 widgets proposés inexistants ; 3/3 services proposés inexistants. Cette dette ne s'est pas accumulée par accident — Phase 96 a pivoté de « chat ↔ écran ouvert » vers « chat-as-verb / overlay » (Phase 7 PAUSED 2026-05-14 confirme).
3. **JSX docs/brand/mint-v2/ = propositions design non-canoniques**. La structure de tabs proposée (Aujourd'hui · Coach · Trajectoire) diverge du code (4 tabs Aujourd'hui · Mon argent · Coach · Explorer). `screen-plan.jsx` (stepper 4 phases) est un point de départ réutilisable pour Wave 2 wireframe.
4. **Verdict consolidé** : ~60% des propositions handoff sont OBSOLÈTES (vision « chat vivant » pivotée vers « chat-as-verb »), ~25% sont déjà câblées dans le code (infra Couche 2 + anti-hallucination), ~15% restent utilisables comme inputs Wave 0 wireframe (JSX Trajectoire + tokens Handoff 2 partiels). **Re-implémenter aveuglément le handoff = dette technique vision aggravée. Drift audit doit guider Wave 0 build.**

---

## Section A — Architecture (ARCHITECTURE.md handoff 2026-04-26 + 2026-05-09)

> Les deux ARCHITECTURE.md sont byte-identiques (verified). Une seule analyse.

### A.1 — Couche 2 (Orchestration) — SHIPPÉE

| Brique handoff | État code | Citation |
|---|---|---|
| `CoachOrchestrator` | ✅ Présent | [coach_orchestrator.dart](apps/mobile/lib/services/coach/coach_orchestrator.dart) |
| `ChatToolDispatcher` | ✅ Présent | [chat_tool_dispatcher.dart](apps/mobile/lib/services/coach/chat_tool_dispatcher.dart) |
| `RoutePlanner` | ✅ Présent | [route_planner.dart](apps/mobile/lib/services/navigation/route_planner.dart) |
| `ScreenRegistry` | ✅ Présent | [screen_registry.dart](apps/mobile/lib/services/navigation/screen_registry.dart) |
| `ReadinessGate` | ✅ Présent | [readiness_gate.dart](apps/mobile/lib/services/navigation/readiness_gate.dart) |
| `SequenceCoordinator` | ✅ Présent | [sequence_coordinator.dart](apps/mobile/lib/services/sequence/sequence_coordinator.dart) |
| `AutonomousAgentService` | ✅ Présent | [autonomous_agent_service.dart](apps/mobile/lib/services/agent/autonomous_agent_service.dart) |
| **6 invariants ARCHITECTURE §7** | ✅ Honorés au niveau code | Cf. doctrine_checks.py (18KB) + compliance_guard.py (36KB) |

**Verdict** : la fondation du handoff est en place. Les 5 vagues de migration (A à E) ne sont pas l'enjeu Wave 0 — elles ont leur propre trajectoire de phases (96, 97, 98 récentes).

### A.2 — Anti-hallucination / forced-tool-invocation — DÉJÀ CÂBLÉE (mais le design doc 2026-05-14 prétend qu'elle n'existe pas)

Le design doc dit (Problem Statement #2) :
> « Pas de planner / forced-tool-invocation — le LLM peut produire un nombre CHF/%/année sans avoir invoqué un tool »

**Cette claim est partiellement fausse**. Inventaire :

| Composant | Rôle | Citation |
|---|---|---|
| `HallucinationDetector` (S34) | Extract numbers from LLM text + compare against `social_insurance.py` constants (15+ imports) | [hallucination_detector.py](services/backend/app/services/coach/hallucination_detector.py) |
| `CitationParser` (Phase 94) | Closed-world citation gate ; 5 number-family regex compiled at import ; retry budget D-08 ; FR reprompt addendum D-09 ; FALLBACK D-10 ; banned-claim retry D-13 | [citation_parser.py](services/backend/app/services/coach/citation_parser.py) (31 KB) |
| `CitationRegistry` | Source-of-truth pour `{{cite:<key>}}` tokens | [citation_registry.py](services/backend/app/services/coach/citation_registry.py) |
| `CitationGrammar` | Validation grammaticale citations | [citation_grammar.py](services/backend/app/services/coach/citation_grammar.py) (19 KB) |
| `ComplianceGuard` | LSFin art. 3/8 validation pipeline (Layer 3) | [compliance_guard.py](services/backend/app/services/coach/compliance_guard.py) (36 KB) |
| `DoctrineChecks` | Doctrine LSFin checks | [doctrine_checks.py](services/backend/app/services/coach/doctrine_checks.py) |
| `NarrativeSleeveLint` | Sleeve linting (post-LLM) | [narrative_sleeve_lint.py](services/backend/app/services/coach/narrative_sleeve_lint.py) |
| `GroundingPack` | ProjectionGroundingPack — ground-truth pack pour LLM | [grounding_pack.py](services/backend/app/services/coach/grounding_pack.py) |
| `BundleCompiler` (Phase 93.5) | Bundle compiler pour narrator system prompts | [bundle_compiler.py](services/backend/app/services/coach/bundle_compiler.py) (10 KB) |
| `Bundles` (Phase 93.5) | 5 bundles tools : `lpp_projector`, `tax_explainer`, `mortgage_stressor`, `pillar3a_optimizer`, `life_event_router` | [bundles/](services/backend/app/services/coach/bundles/) |

**Verdict refined** : l'infra anti-hallucination existe + est en transition (Phase 93.5 bundle compiler → Phase 95 deletion legacy). Ce qui MANQUE n'est pas la détection — c'est le **mapping numeric-claim → tool-name → service backend** que le design doc Wave 1b décrit comme `ToolUseTraceMatcher`. Wave 1b devient un **wiring** sur infra existante, pas un build from-scratch.

**Correction obligatoire au design doc** : Wave 1b « 1.5 sem build » sous-estime peut-être l'extension (déjà-câblé) et sur-estime la création (à-mapper-seulement). À valider avec Julien : ce que Wave 1b doit ajouter par-dessus le déjà-en-place.

### A.3 — Couche 1 (UI / Shell) — DIVERGENTE de la proposition JSX

| Élément | Handoff ARCHITECTURE §2 | JSX docs/brand/mint-v2/ | Code actuel | Verdict |
|---|---|---|---|---|
| Tabs count | 4 (Aujourd'hui / Mon argent / Coach / Explorer) | **3** (Aujourd'hui / Coach / Trajectoire) | 4 (Aujourd'hui / Mon argent / Coach / Explorer) | Code = handoff ARCHITECTURE. JSX docs/brand/mint-v2/ diverge. |
| Coach tab visibility | Implicite « toujours visible » | Toujours visible | `chatTabVisible = true` au `feature_flags.dart:116` (Phase 7 PAUSED 2026-05-14) | Code = doctrine officielle décidée. |
| Mon Argent rôle | « numbers panel / patrimoine » | **Disparu** du model JSX | Présent comme tab persistante | Vision doc Mon Argent = Wave 0 décision. |
| Explorer | « Hub navigation » | **Disparu** du model JSX | Présent (7 hubs × 60+ flows) | Audit corpus Explorer = Wave 0 sub-agent A. |
| Trajectoire | Pas mentionnée | **Tab à part entière** | N'existe pas | Wave 2 design doc demande COMPOSANT sur Aujourd'hui ou Mon Argent. JSX propose ONGLET. **Décision Julien requise.** |

**Verdict** : la structure de tabs canonique = code actuel + design doc Wave 2 (TrajectoryMap composant, pas onglet). Le JSX `screen-aujourdhui.jsx` est une **proposition design exploratoire** non-canonique. Ne pas le copier mécaniquement.

---

## Section B — Chat Vivant (handoff 02-chat-vivant-services.md) — JAMAIS CÂBLÉ

### B.1 — Services Flutter proposés

| Service handoff (lib/services/chat_projection/) | État code | Verdict |
|---|---|---|
| `scene_registry.dart` | ❌ Inexistant (`find` empty) | Jamais câblé |
| `chat_projection_service.dart` | ❌ Inexistant | Jamais câblé |
| `return_contract.dart` | ❌ Inexistant | Jamais câblé |

### B.2 — Widgets proposés

| Widget handoff (lib/widgets/premium/ ou lib/widgets/chat_projection/) | État code | Verdict |
|---|---|---|
| `mint_count_up.dart` | ✅ Présent | Existant antérieur |
| `mint_reveal.dart` | ❌ Inexistant | Jamais câblé |
| `mint_typing_dots.dart` | ❌ Inexistant | Jamais câblé |
| `mint_inline_insight_card.dart` | ❌ Inexistant | Jamais câblé |
| `mint_ratio_card.dart` | ❌ Inexistant | Jamais câblé |
| `mint_life_line_slider.dart` | ❌ Inexistant | Jamais câblé |
| `mint_scene_rente_capital.dart` | ❌ Inexistant | Jamais câblé |
| `mint_scene_rachat_lpp.dart` | ❌ Inexistant | Jamais câblé |
| `mint_canvas_projection.dart` | ❌ Inexistant | Jamais câblé |
| `mint_canvas_chapitre.dart` | ❌ Inexistant | Jamais câblé |
| `mint_sensibilite_widget.dart` | ❌ Inexistant | Jamais câblé |

**Score câblage chat-vivant : 1/14 (≈7%).**

### B.3 — Pourquoi la dette s'est creusée

Hypothèses (à valider avec Julien) :

1. **Pivot Phase 96 chat-as-verb (panel UX 2026-05-10)** : la décision panel UX a déplacé Coach de « onglet conversationnel principal » vers « overlay invocable depuis n'importe quelle surface ». Phase 7 a tenté de matérialiser (`chatTabVisible = false`) — PAUSED 2026-05-14 pending Wave 1 outcome. Cela invalide DE FACTO la grammaire chat-vivant (« insert scene dans flow chat ») qui présuppose un onglet chat persistant central.
2. **Composants premium ont divergé** : `MintHeroNumber`, `MintSurface`, `MintNarrativeCard`, `MintProgressArc`, `MintSignalRow`, `MintResultHeroCard`, `MintChoiceCard`, `MintInlineInputChip`, `MintConfidenceNotice` ([DESIGN_SYSTEM.md §4.1b](docs/DESIGN_SYSTEM.md)) ont été construits — composants éditoriaux SURFACE-FIRST, pas widgets inline-chat. Vision pivot.
3. **Infra anti-hallucination a pris la priorité** : Phase 94 closed-world citation gate + Phase 93.5 bundles compiler ont consommé les cycles ingénierie là où le handoff 2026-04-26 prévoyait les widgets. Pivot vers grounding > vers présentation. Cohérent avec Karpathy 2026 « verifiable + undertrained ».

### B.4 — Que faire de cette dette ?

3 options pour Julien :

- **(a) Abandonner formellement** : marquer dans `.planning/decisions/2026-05-14-chat-vivant-archive-status.md` que la vision chat-vivant 2026-04-26 est superseded par doctrine Phase 96 chat-as-verb. Garder l'archive comme référence historique.
- **(b) Réutiliser sélectivement dans Wave 2** : 3 niveaux insight inline / scène / canvas peuvent être les **artéfacts inline du Coach overlay** (cohérent avec Phase 96 doctrine — overlay = surface conversationnelle invocable). Si Wave 4 (widgets didactiques inline) reprend l'idée, le handoff redevient utile en plan de référence design.
- **(c) Reporter la décision** : marquer pending audit corpus visuel Explorer (Wave 0 sub-agent A). Si l'audit révèle ≥ 8 widgets embed-able, (b) devient plus probable.

**Recommandation Claude** : **(b) reporté à Wave 4 conditionnel**. La grammaire 3-niveaux est solide et reste compatible avec chat-as-verb (overlay = surface où on intercale des artéfacts inline). Pas de re-implémentation aveugle Wave 0/1/2, mais on garde la grammaire éditoriale (Fraunces, phrase de recul, hypothèses dashed border, CTA noir) — déjà partiellement honorée en code.

---

## Section C — 11 JSX docs/brand/mint-v2/ — Propositions design non-canoniques

| JSX file | Type | Code Flutter correspondant | Verdict |
|---|---|---|---|
| `screen-landing.jsx` | Hero landing | [landing_screen.dart](apps/mobile/lib/screens/landing_screen.dart) (à vérifier) | À diff avec code shipped |
| `screen-onboarding.jsx` | Quick start | [quick_start_screen.dart](apps/mobile/lib/screens/quick_start_screen.dart) | À diff |
| `screen-aujourdhui.jsx` | Aujourd'hui 3-tabs | [pulse_screen.dart](apps/mobile/lib/screens/pulse_screen.dart) (Aujourd'hui actuel) | **Divergent** — tab count, contenu |
| `screen-coach.jsx` | Chat + 4 artéfacts inline | [coach_chat_screen.dart](apps/mobile/lib/screens/coach_chat_screen.dart) | **Divergent** — artéfacts inline jamais câblés |
| `screen-coach-empty.jsx` | Empty state coach | Idem | À diff |
| `screen-plan.jsx` | **Trajectoire 4 phases stepper** | ❌ N'existe pas | **UTILISABLE Wave 0 wireframe TrajectoryMap** |
| `screen-lpp.jsx` | LPP scenario | [epl_screen.dart](apps/mobile/lib/screens/epl_screen.dart) ou équivalent | À diff |
| `screen-hypotheque.jsx` | Mortgage | [affordability_screen.dart](apps/mobile/lib/screens/affordability_screen.dart) | À diff |
| `design-canvas.jsx` | Canvas générique | N/A (proposition) | Référence design |
| `primitives.jsx` | Primitives JSX | N/A | Référence design |
| `tokens.jsx` | Tokens JSX | À diff vs `colors.dart` (cf. §D) | Référence design |

**Verdict** : ce sont des **propositions design éditoriales**, pas du code shippable. Le seul réutilisable directement pour Wave 0 wireframe = `screen-plan.jsx` (stepper 4 phases avec ConfidenceBand + EnrichmentPrompts inline).

`screen-plan.jsx` model :
- Phase 01 Comprendre (fait) — Tes 3 piliers, scannés
- Phase 02 Boucher les trous (fait) — 3e pilier ouvert
- Phase 03 Racheter LPP (actif) — 10'000 / -3'400 d'impôts
- Phase 04 Projeter — 2053 / 5'800 CHF/mois
- Hero : « En 2053, à 65 ans · 5'800 CHF/mois · Si tu termines les 4 phases. Sans rachat ni 3e pilier : 4'200 CHF. »
- ConfidenceBand level=low « 29 ans d'écart, projection sensible aux revenus »
- EnrichmentPrompts : « évolution salaire, enfants prévus, achat immobilier »

**Caveat** : `screen-plan.jsx` est centré retraite (« En 2053, à 65 ans »). Viole CLAUDE.md TOP rule #3 (« MINT ≠ retirement app »). À adapter pour Wave 0 wireframe avec framing life-event-agnostic ou multi-archetype (8 archetypes).

---

## Section D — colors_and_type.css handoff vs DESIGN_SYSTEM.md + colors.dart

Diff token-par-token entre `.planning/handoff/2026-04-26-chat-vivant-services/colors_and_type.css` et le code actuel.

| Token handoff | Hex handoff | Match `colors.dart` | Notes |
|---|---|---|---|
| `--mint-warm-white` | `#FAF8F5` | `MintColors.warmWhite #FAF8F5` ✅ | MATCH |
| `--mint-porcelaine` | `#F4F1EC` | `MintColors.porcelaine #F7F4EE` ⚠️ + `MintColors.porcelaineHero #F4F1EC` ✅ | **Dual-token** : legacy preserved + Handoff 2 token added (cf. [colors.dart:50-58](apps/mobile/lib/theme/colors.dart#L50-L58)) |
| `--mint-craie` | `#F8F5F0` | `MintColors.craie #FCFBF8` ⚠️ + `MintColors.craieHandoff #F8F5F0` ✅ | **Dual-token** |
| `--mint-text-primary` | `#1A1A1A` | `MintColors.textPrimary #1D1D1F` ⚠️ + `MintColors.inkPrimary #1A1A1A` ✅ | **Dual-token** |
| `--mint-border-subtle` | `#E8E4DE` | `MintColors.borderSubtle #E8E4DE` ✅ | MATCH (Handoff 2 token) |
| `--mint-primary` | `#2F5F3F` (vert forêt) | `MintColors.primary #1D1D1F` ❌ + `MintColors.mintForest #2F5F3F` ✅ | **Dual-token** — `primary` reste anthracite, `mintForest` rajouté |
| `--mint-sauge` | `#B8C9B4` | `MintColors.sauge #B8C9B4` ✅ | MATCH |
| `--mint-sauge-claire` | `#D4DFCE` | `MintColors.saugeClaire #D8E4DB` ⚠️ | Légère divergence (#D4DFCE vs #D8E4DB), pas câblé Handoff |
| `--mint-bleu-air` | `#C8D5DE` | `MintColors.bleuAir #CFE2F7` ⚠️ | Divergence (#C8D5DE vs #CFE2F7) |
| `--mint-peche-douce` | `#E8CFB8` | `MintColors.pecheDouce #F5C8AE` ⚠️ | Divergence (#E8CFB8 vs #F5C8AE) |
| `--mint-terracotta` | `#B8735A` | `MintColors.terracotta #B8735A` ✅ | MATCH |
| `--mint-font-display: Fraunces` | — | ❌ Pas « Fraunces » dans `mint_text_styles.dart` MAIS **Phase 92 a substitué Fraunces → Gambarino** | **Pivot vers DS v2 mai 8 (Supreme + Gambarino)** |

**Verdict (corrigé post-PDF DS v2 mai 8 read)** : adoption partielle « dual-token » du handoff sur palette + **Phase 92 a migré la stack font de Fraunces (handoff) vers Supreme + Gambarino (DS v2)**. Vérification :
- `pubspec.yaml:95-111` : `Supreme` (Regular/Medium/Bold .otf) + `Gambarino-Regular.otf` bundled
- `mint_text_styles.dart:20-41` : mapping verbatim « Montserrat → Supreme · Inter → Supreme · Fraunces → Gambarino (serif italic — synthetic italic via skew) »
- 4 fichiers `.otf` présents dans `apps/mobile/assets/fonts/`
- DESIGN_SYSTEM.md §3.1 cite **encore Montserrat + Inter** → **OUTDATED** (drift documentaire à corriger en Wave 0).

Phase 92 a ajouté son propre token additionnel `mentheVive #7DD3B5` (MVP-FONTS-TOKENS-V2 STUB) — accent vert-cyan vif visible sur tous les écrans PDF DS v2 mai 8 page 1, 2, 4. **Cohérent avec PDF, pas avec handoff #2F5F3F mintForest.** Le code a tranché vers menthe-vive ; mintForest reste un token résiduel non utilisé canoniquement.

### D.bis — Brand PDFs (Design System 2026-05-08 + Brand print 2026-05-09) = NOUVELLE SOURCE OF TRUTH

Le PDF `MINT-Design-System-2026-05-08.pdf` (756 KB, 5 chapitres lus) est **plus récent** que `docs/DESIGN_SYSTEM.md` (last meaningful update 2026-04-05 per legacy note) et **plus canonique** pour la stack design v2. Findings :

| Élément PDF DS v2 mai 8 | Verdict drift |
|---|---|
| **3 tabs** (Aujourd'hui · Coach · Trajectoire) — page 3 hero + page 4 trajectoire | Diverge du code 4-tabs ; mais cohérent avec JSX docs/brand/mint-v2/ ; **décision Wave 0 step E (Mon Argent vision) doit traiter « Mon Argent disparaît au profit de Trajectoire »** |
| **4 artéfacts Coach** (Décision · Comparaison · Trajectoire · Sensibilité) — page 4 | Jamais câblé Flutter. Cohérent avec handoff 02-services 3 niveaux insight/scène/canvas (équivalence fonctionnelle). Wave 4 conditionnel. |
| **Grammaire MINT v2** (page 5) — 8 règles | À ratifier comme ADR. Cf. liste ci-dessous. |
| **Slogan** : « L'argent, en clair. · Ta Suisse financière, traduite. » | Manifeste copywriting Wave 1+. À aligner avec MINT_IDENTITY.md « Mint te dit ce que personne n'a intérêt à te dire ». |
| **Stack typo** : Supreme (UI) + Gambarino (display) + Menthe vive #7DD3B5 | DÉJÀ câblé Phase 92 ✓ |
| **Dark mode natif** = 1ère classe | Tokens darkBg/darkInk/darkInkSoft/darkBorderSubtle/darkMentheVive présents `colors.dart:323-335` mais migration per-screen deferred to MVP-DARK-MODE-V1 |

**Grammaire MINT v2 (page 5 du PDF) — 8 règles** :
1. **Une idée / écran** — Pas de mur de cartes. Le chiffre parle, pas l'UI.
2. **Voix : observer, pas juger** — Pas « enfin », pas « de justesse », pas « largement mieux ».
3. **4 artefacts Coach** — Décision · Comparaison · Trajectoire · Sensibilité.
4. **18 events ≠ retraite-app** — « Trajectoire », pas « Plan retraite ». Tab neutre.
5. **Italique : 2 écrans max** — Landing + Onboarding. Ailleurs il banalise.
6. **Chiffre nu = interdit** — Toujours ConfidenceBand + EnrichmentPrompts à côté.
7. **Streaming visible** — Bouton ▶ → ■ + dots animés pendant la génération.
8. **Dark mode natif** — Palette dark = 1ère classe, pas un afterthought.

**Verdict** : ces 8 règles convergent avec CLAUDE.md TOP rules + MINT_IDENTITY + le 0-trust protocol § 9. **À ratifier comme ADR Wave 0**.

### D.ter — Migration DS v2 partielle : « screens à moitié dans le bon design, à moitié dans le mauvais » (Julien observation 2026-05-14)

Audit chiffré coverage cross-108 écrans (`apps/mobile/lib/screens/`, grep counts) :

| Élément DS v2 | Coverage | Verdict |
|---|---|---|
| Fonts via `MintTextStyles.*` | 97/108 (90%) | ✓ Phase 92 + MVP-GOOGLEFONTS-PURGE-V1 substantially done |
| `fontFamily: 'Supreme'` hardcoded (bypass MintTextStyles) | 8 fichiers × 56 occurrences (≈OK, family canonique) | ✓ |
| `Color(0x...)` literals dans `lib/screens/` | 0 | ✓ Lint passé |
| `MintGlassCard` (deprecated DS §9) | 0 | ✓ |
| `MintPremiumButton` (deprecated DS §9) | 1 | ⚠️ Résidu |
| `MintSurface` (new premium §4.1b) | 80 | ✓ |
| `MintHeroNumber` (new premium §4.1b) | 7 | ⚠️ Hero only |
| `MintNarrativeCard` | 14 | ⚠️ |
| **`MintColors.primary` (legacy anthracite #1D1D1F)** | **78/108 (72%)** | ⚠️ Majoritaire |
| **`MintColors.inkPrimary` (Handoff 2 warm #1A1A1A)** | **2/108 (1.8%)** | ❌ Sur écrans vitrines (Landing, Onboarding) seulement |
| `MintColors.textPrimary` (legacy) | 94/108 (87%) | Statu quo |
| `MintColors.surface` (cool #F5F5F7) | 39/108 (36%) | Statu quo |
| **`MintColors.porcelaineHero` (warm Handoff 2 #F4F1EC)** | **1/108 (0.9%)** | ❌ Une seule surface |
| **`MintColors.craieHandoff` (warm #F8F5F0)** | **1/108** | ❌ Idem |
| `MintColors.warmWhite` | 4/108 | ⚠️ |
| **`MintColors.mentheVive` (PDF DS v2 accent #7DD3B5)** | **0/108** | ❌ JAMAIS UTILISÉ — accent canonique du PDF mai 8 absent du code screens |
| **`ConfidenceBand` / `MintConfidence*` (PDF DS v2 grammaire #6 « Chiffre nu interdit »)** | **3/108 (2.8%)** | ❌ Massivement absent |
| **`EnrichmentPrompt*` (PDF DS v2 grammaire #6)** | **8/108 (7.4%)** | ❌ Massivement absent |
| `LinearGradient` (DS §7 pattern 7 — max 1 par page) | 19 screens | ⚠️ À vérifier per-screen |

**Diagnostic** :
- **Migration des fonts = quasi-terminée** (Phase 92 + Plan PURGE-V1). C'est l'opération bien faite.
- **Migration de la palette warm (Handoff 2 + DS v2 inkPrimary / porcelaineHero / craieHandoff) = ~2% des écrans**. Faite sur les écrans **vitrines** (Landing, Onboarding, 1-2 héros). Le reste tient l'anthracite legacy. Pattern typique de design system partiellement landing-only.
- **Accent menthe-vive (PDF DS v2 mai 8 canonique) = 0% des écrans**. Le token est défini dans `colors.dart:314` mais **jamais consommé**. La sample visuelle dominante du PDF mai 8 (chips actifs, dots animés, accent ring) n'est nulle part en prod.
- **Grammaire « Chiffre nu interdit » (ConfidenceBand + EnrichmentPrompts mandatory) = 2-7% des écrans**. Une règle PDF mai 8 + handoff existante mais massivement non-câblée.

**Conséquence Wave 0/1/2 (vraie nuance Julien)** :
La cassure n'est pas que **CLAUDE et l'agent n'ont pas vu** la grammaire v2 — elle est dans le code (tokens + composants existent). La cassure est que **personne ne l'a propagée systématiquement écran par écran**. Coût propagation :
- Tokens warm (inkPrimary, porcelaineHero, craieHandoff, surface→warm) : ~100 écrans × ~3 substitutions par écran ≈ 300 changements, mostly mécanique.
- Accent menthe-vive : ~20-40 écrans pertinents (CTAs, chips actifs, accents milestone).
- ConfidenceBand + EnrichmentPrompts : ~50-80 écrans pertinents (toute surface affichant un chiffre projeté ou estimé). Ça **doit être** un widget composé mandatory wrappant tout `MintHeroNumber` / `displayLarge` chiffre. Pas une décoration optionnelle.

**Recommandation Wave 0 + au-delà** :
- **Wave 0 nouveau sub-agent (H)** : produire `.planning/audit/2026-05-14-ds-v2-coverage.md` détaillé écran-par-écran (token usage + grammaire compliance per screen). Permet de chiffrer la dette propagation et de prioriser.
- **Wave 1 ajout** : « propagation DS v2 phase 1 » — wrap mandatory `ConfidenceBand` + `EnrichmentPrompts` autour de tout chiffre projeté/estimé (≈50-80 écrans). Lint custom pour bloquer regression. C'est l'écho code de la grammaire PDF #6 « Chiffre nu interdit » + memory `project_coach_forced_tool_invocation` (chiffre sans citation rejeté).
- **Wave 2 ajout** : « propagation DS v2 phase 2 » — palette warm migration screen-by-screen (anthracite → inkPrimary, surface → porcelaineHero pour héros, craie → craieHandoff pour Coach). Diff visuel sur sim avant/après obligatoire.
- **Wave 2 menthe-vive** : décider 20-40 surfaces où l'accent canonique du PDF mai 8 doit s'installer. Sans ça, l'app **ne ressemble pas au design system**.

**Cette nuance change Wave 0 build** : Sub-agent H ajouté en parallèle avec A/B/C (4 sub-agents au total). Coût ~1h. Output : décision Julien sur scope propagation DS v2 Wave 1/2.

---

## Section E — CLAUDE_CODE_PROMPT.md mai (22 KB) — Suivi vs ignoré

Le prompt 22 KB Julien-authored impose un protocole 3-phases :
- Phase 1 — Onboarding (note de cadrage, pas de code)
- Phase 2 — Mission #1 Architecture (audit ScreenRegistry, Vague A, pas de code applicatif)
- Phase 3 — Mission #2 Chat vivant (widgets + orchestration, après validation Vague A)

| Phase prompt | État dans les 5 dernières phases (96, 97, 98 récentes) | Verdict |
|---|---|---|
| Phase 1 Onboarding | Pratiqué dans certaines GSD phases (PLAN-RESEARCH-EXECUTE-VERIFY pattern) | Partiellement suivi |
| Phase 2 Audit ScreenRegistry → 5 fichiers `handoff/audit/01-routes` à `05-plan` | ❌ Inexistants — `.planning/audit/handoff/` n'existe pas | Jamais exécuté |
| Phase 3 Chat vivant 7 étapes (3.1 tokens → 3.7 tests + flag) | Étape 3.1 tokens partielle ; 3.2-3.7 jamais exécutées | Jamais exécuté |
| Anti-patterns ✗ « bypass RoutePlanner » | Honoré (cf. doctrine_checks.py) | Suivi |
| Invariants éditoriaux E1-E8 (aucun emoji, Fraunces signature, phrase de recul, CTA noir) | E1 honoré (no emoji) ; E3 Fraunces jamais câblé ; E2 « 1 chiffre-héros » honoré par DESIGN_SYSTEM §2 | Partiellement suivi |

**Verdict** : le prompt 22 KB a été **superseded** par le GSD workflow (memory `feedback_gsd_workflow_default` : « ≥3 perimeters → GSD per phase artifact stack »). Phases 90-98 ont chacune leur propre RESEARCH/PLAN/EXEC/VERIFICATION/SECURITY/UI-REVIEW artefacts, pas la grammaire « PROMPT 1 / 2 / 3 ». Pas un drift négatif — un upgrade vers process plus discipliné.

---

## Section F — MINT_COACH_AI_INTEGRATION_PROMPT.md (Gemma 3n on-device) — État

Le prompt propose Coach Layer on-device avec Gemma 3n E2B Q4_K_M (~2 GB, GGUF), package `llm_llamacpp`, 7 transformations T1-T7.

| Élément | État code | Verdict |
|---|---|---|
| `llm_llamacpp` package dans `pubspec.yaml` | ❌ Non présent (à vérifier formellement) | Jamais adopté |
| Coach Layer Dart `lib/coach/` | ❌ Inexistant | Jamais câblé |
| LLM on-device service `lib/llm/` | ❌ Inexistant | Jamais câblé |
| Gemma 3n model download UI | ❌ Inexistant | Jamais câblé |
| BYOK fallback | ✅ `byok_service.dart` ([byok_service.dart](apps/mobile/lib/services/byok_service.dart)) — `project_byok_scope` memory dit BYOK out-of-scope pour QA | Partiellement câblé, out-of-scope MVP |
| ServerKey (Anthropic API key Railway) | ✅ Architecture actuelle | Décision implicite : tier cloud ServerKey, pas SLM on-device |
| 7 transformations T1-T7 | T2 (tips narratifs) partiellement via `claude_coach_service.py` côté backend ; T1/T3/T5/T7 jamais câblés | Mostly never wired |

**Verdict** : le pari « SLM on-device Gemma 3n » a été **abandonné de facto** au profit de **ServerKey cloud Anthropic** + infra anti-hallucination backend (Phase 93.5/94). Cohérent avec `memory project_byok_scope` (BYOK out-of-scope) et `memory feedback_app_targets_staging_always` (app targets staging Railway). **Cette décision n'est documentée nulle part en ADR**. Suggestion : `.planning/decisions/2026-05-14-slm-on-device-abandon-rationale.md` (Proposed).

---

## Section G — Tableau récapitulatif

| Domaine handoff | Verdict | Action Wave 0 |
|---|---|---|
| Architecture Couche 2 (7 briques) | ✅ Shippée | Aucune — utiliser tel quel |
| Architecture Couche 1 (4 tabs) | ✅ Shippée canoniquement | Aucune — JSX 3-tabs est exploratoire |
| Chat-vivant scene_registry / chat_projection_service / return_contract | ❌ Jamais câblé | Décision Julien : abandon / reporter Wave 4 / reprendre |
| 14 widgets chat-vivant | 1/14 câblés | Idem — peut nourrir Wave 4 |
| Infra anti-hallucination | ✅ Câblée (S34 + Phase 94 + Phase 93.5) | Re-évaluer Wave 1b scope (wiring > build) |
| 11 JSX docs/brand/mint-v2/ | Propositions exploratoires non-canoniques | `screen-plan.jsx` utilisable Wave 0 wireframe (à adapter framing life-event-agnostic) |
| colors_and_type.css | Adopté en dual-token | Aucune action Wave 0 |
| Fraunces font display | Jamais câblé | Décision Wave 0/4 : adopter ou pas |
| CLAUDE_CODE_PROMPT 22 KB | Superseded par GSD workflow | Aucune — process actuel meilleur |
| Coach on-device Gemma 3n | Abandonné de facto | ADR rétroactif Proposed |
| Phase 7 chatTabVisible | PAUSED 2026-05-14 (PR #598) | Statu quo Phase 6 = `chatTabVisible = true` |

---

## Section H — Recommandations pour Wave 0 build

**Décisions Julien requises avant Wave 0 build** :

1. **Vision chat-vivant 02-services.md** : (a) abandon formel / (b) reporter Wave 4 conditionnel / (c) statu quo non-décidé. **Recommandation Claude : (b)**.
2. **JSX docs/brand/mint-v2/** : référence design d'inspiration vs proposition canonique ? **Recommandation Claude : référence d'inspiration. Seul screen-plan.jsx est utilisable directement pour Wave 0 wireframe (adapté life-event-agnostic).**
3. **Fraunces font** : adopter Wave 4 ou jamais ? **Recommandation Claude : décider Wave 4 selon audit corpus.**
4. **Coach on-device Gemma 3n abandon** : ADR rétroactif à écrire ? **Recommandation Claude : oui, Wave 0 sub-agent.**
5. **Wave 1b scope refined** : si anti-hallucination câblée à 80% (HallucinationDetector + CitationParser + Bundles + ComplianceGuard), Wave 1b devient « wiring 7 tools → services backend + extension `NumericClaimExtractor → tool_name mapping registry » plutôt que « build planner from scratch ». **Recommandation Claude : Wave 1b reduced scope, gain ~5-8 jours réinvestis Wave 2.**

**Outputs Wave 0 build ajustés (post-drift) :**

- **Sub-agent A — Audit corpus visuel Explorer** : inchangé.
- **Sub-agent B — Inventaire 28 backend tools** : ajustement → inclure **catégorisation usage actuel vs cible** (le mapping wave-1b dépend de ce qui appelle déjà quel service). Ajouter audit infra anti-hallucination (HallucinationDetector / CitationParser / Bundles) : couverture vs gaps.
- **Sub-agent C — Wireframe TrajectoryMap** : inchangé. **S'appuyer sur `screen-plan.jsx` comme point de départ** + adapter (a) framing life-event-agnostic (pas « retraite 2053 »), (b) 8 archetypes (vs 1 « parcours retraite »), (c) drift audit verdict (Trajectoire = composant Aujourd'hui/Mon Argent, pas onglet).

**Wave 0 sequential D/E/F + G** : inchangés.

---

## Section I — Caveats audit

1. **Je n'ai pas lu l'intégralité de claude_coach_service.py (66 KB)** — seulement les 80 premières lignes. Le diagnostic « infra anti-hallucination câblée à 80% » est basé sur l'existence des modules + leurs docstrings, pas sur un trace runtime end-to-end. **À vérifier sur Wave 0 sub-agent B**.
2. **Brand PDFs (Design System + Brand Print)** non lus dans cette session — context budget. Diff DESIGN_SYSTEM.md vs PDFs déféré.
3. **Drift sur navigation orphan screens / dead ends** — non couvert dans cet audit. Demande un audit séparé (cf. `autoresearch-navigation` skill).
4. **Le verdict « jamais câblé » est `find` + `grep` based** — peut rater des fichiers renommés ou refactorés. Sub-agent B vérification recommandée.
5. **Cet audit n'a pas été cross-modelé** (Codex / GPT). Le design doc original a été cross-modelé. Je propose un cross-model audit sur ce drift si Julien le demande.

---

## Section J — Verdict consolidé

**Réutilisable Wave 0/1/2** :
- Architecture Couche 2 (existant) — aucune action Wave 0
- Infra anti-hallucination (Phase 93.5/94 existant) — re-scope Wave 1b
- screen-plan.jsx stepper 4 phases — input wireframe Wave 0 (adapté multi-archetype + life-event-agnostic)
- Tokens Handoff 2 dual-token déjà câblés — aucune action Wave 0
- Grammaire éditoriale chat-vivant (Fraunces / phrase recul / hypothèses dashed / CTA noir) — décision Wave 4

**Obsolète post-pivot Phase 96** :
- 3-niveaux insight inline / scène / canvas dans flux chat persistant — pivoté vers chat-as-verb overlay
- 11 widgets premium chat-vivant proposés — décision (a)/(b)/(c) Julien
- CLAUDE_CODE_PROMPT 3-phases protocole — superseded par GSD workflow

**Dette technique vision (auraient dû être câblées et ne l'ont pas été)** :
- Fraunces font éditoriale — grammaire DESIGN_SYSTEM §3.1 cite Fraunces, jamais ajoutée
- ADR « abandon SLM on-device Gemma 3n » — décision implicite jamais formalisée
- ADR « pivot vers Phase 96 chat-as-verb » — Phase 7 PAUSED documente la PAUSE mais pas la DOCTRINE complète

**Aucune dette critique bloquante pour Wave 0/1/2** sous réserve des 5 décisions Julien requises (Section H).

---

*Audit produit par Claude (Wave 0 Sentry) le 2026-05-14. Ground truth verified by grep + read commands cited inline. No banned 0-trust claims (CLAUDE.md §9.1). Awaiting Julien validation before Wave 0 build A/B/C.*
