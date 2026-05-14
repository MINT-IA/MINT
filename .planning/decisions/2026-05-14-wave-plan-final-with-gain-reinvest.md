---
date: 2026-05-14
status: Decided
authors: Julien (decided), Claude (drafted)
panel: single
supersedes: design doc APPROVED 2026-05-14 Wave 0-4 séquence originelle
superseded_by: —
description: Plan final Wave 0-4 post-drift audit + 3 décisions Julien (Mon Argent P2 + DS v2 propagation Wave 1.5 + Wave 1 gain réinvesti dans Wave 2 TrajectoryMap) ; total estimé 12-13 semaines depuis Wave 1 kickoff.
related:
  - .planning/audit/2026-05-14-handoff-vs-code-drift.md
  - .planning/decisions/2026-05-14-aujourdhui-doctrine.md
  - .planning/decisions/2026-05-14-slm-on-device-abandon-rationale.md
  - .planning/decisions/2026-05-14-mon-argent-p2-dissolution-trajectoire.md
  - .planning/decisions/2026-05-14-ds-v2-propagation-wave-1-5-bigbang.md
---

# Wave 0-4 plan final (post-drift audit + 3 décisions Julien)

## TLDR

Plan Wave 0-4 final post-Julien-validation : **12-13 semaines** depuis Wave 1 kickoff (vs 7-8 sem originelles du design doc) — l'extension vient de l'insertion **Wave 1.5 DS v2 propagation (3-4 sem)** entre Wave 1 et Wave 2, en partie compensée par **Wave 1b passant de 1.5 sem à 3.5 jours** (gain 5-7 jours sub-agent B). Wave 4 reste **SHORT 3 jours** (sub-agent A confirmé).

## Context

Le design doc APPROVED 2026-05-14 (D refined) prévoyait Wave 0-4 sur 7-8 semaines. Post drift audit + 3 sub-agents (B/C/H output) + 3 décisions Julien (2026-05-14 chat) :

| Modification | Source | Impact timeline |
|---|---|---|
| Mon Argent P2 dissolution → tab refonte Wave 2 | ADR `2026-05-14-mon-argent-p2-dissolution-trajectoire.md` | +0.5 sem Wave 2 |
| DS v2 propagation Wave 1.5 big-bang | ADR `2026-05-14-ds-v2-propagation-wave-1-5-bigbang.md` | **+3-4 sem (nouvelle vague)** |
| Wave 1b à 85% câblé (sub-agent B) | `.planning/audit/2026-05-14-coach-tools-inventory.md` | **-5 à -7 jours Wave 1** |
| Wave 4 SHORT 3 jours (sub-agent A) | `.planning/audit/2026-05-14-corpus-visuel-explorer.md` | **-1 sem Wave 4** (vs 1-1.5 sem original) |
| 5-7j gain Wave 1 réinvestis Wave 2 | Q-Wave-1-gain Julien | +5-7j Wave 2 (marge confort + Phase F-2 wraps) |
| Aujourd'hui doctrine ratify | ADR `2026-05-14-aujourdhui-doctrine.md` | 0 net (déjà budgété Wave 2/3) |
| SLM abandon ADR | ADR `2026-05-14-slm-on-device-abandon-rationale.md` | 0 net (formalize tacit) |

**Total recalculé : 12-13 semaines depuis Wave 1 kickoff** (vs 7-8 originelles).

L'extension est dominée par Wave 1.5 (la dette DS v2 propagation chiffrée à 100-145h = 3-4 sem). C'est un investissement explicite « polish identity DS v2 mai 8 visible TestFlight » plutôt que « features-first push-to-prod fast ».

## Decision

Plan Wave 0-4 final :

### Wave 0 — Foundation (5-7 jours) — SHIPPED 2026-05-14 (PR #600)

**Statut : DONE** (à merge dev après validation Julien). Contenu détaillé dans PR #600 : drift audit + 4 audits (sub-agents A/B/C/H) + 6 ADRs (Aujourd'hui, SLM, Mon Argent P2, DS v2 propagation, plan final, Phase 7 PAUSED PR #598) + Mon Argent vision + persona recruitment guide + TrajectoryMap wireframe v1 + design-shotgun brief + DS v2 doctrine §1 update.

### Wave 1 — Backend tools refactor + planner refined (3 sem au lieu de 3 sem)

**Sub-Wave 1a — Re-wire 6/7 READ tools sur services Python** (~10.5 jours, sub-agent B verdict)
- `get_budget_status` → `app.services.budget`
- `get_retirement_projection` → `app.services.coaching_engine` + `pillar_3a_deep`
- `get_cross_pillar_analysis` → `app.services.arbitrage`
- `get_cap_status` → `app.services.coach.cap_engine` (à vérifier équiv Python)
- `get_couple_optimization` → `app.services.couple_optimizer` (à porter Flutter→Python ?)
- `get_regulatory_constant` → DÉJÀ câblé sur `RegulatoryRegistry` (skip)
- `retrieve_memories` → `app.services.memory`
- Décisions à prendre Wave 1a kickoff : port `CapEngine` Flutter→Python ? port `CoupleOptimizer` Flutter→Python ?

**Sub-Wave 1b — Planner refined scope** (~3.5 jours vs 1.5 sem original)
- HallucinationDetector + CitationParser DÉJÀ câblés à 85% (gain principal)
- Action restante : extension `CITATION_REGISTRY` avec `source_kind="tool_call_id"` + dispatcher numeric-claim → tool-name mapping (40% → 100% du ToolUseTraceMatcher)
- Pas de build « from scratch » du re-prompt loop / honest fallback — déjà 100% câblé Phase 94 D-08/D-09/D-10

**Sub-Wave 1c — Citation gate UI + parity tests** (~2-3 jours)
- FactRef / ProjRef / LegalRef chips visibles UI (probably already partial via narrative_sleeve_lint)
- 20 paires Q&A parity tests dans `tests/coach_swiss_parity_v1.yaml`

**Gain total Wave 1 : ~5-7 jours réinvestis Wave 2** (per Julien Q-gain décision).

**Critical caveat (sub-agent B §4)** : `COACH_CITATION_GATE_ENABLED` flag state staging/prod non vérifié au moment du sub-agent B. À confirmer Wave 1 kickoff. Si flag OFF en prod, citation gate ne tourne pas → Wave 1c non-acceptable sans flag ON validation.

### Wave 1.5 — DS v2 propagation big-bang (3-4 sem) — NOUVELLE VAGUE

**Vague 1 propagation tokens Tier 1-3** (~50-80h ≈ 1.5-2 sem)
- 28 écrans Tier 1-3 : ink (`primary` → `inkPrimary`), surface warm (`surface` → `porcelaineHero/craieHandoff`), accent `mentheVive` (20-40 surfaces), typo close gap 10%
- Acceptance : ≥ 70% score DS v2 cross Tier 1-3 (vs 47.4% baseline)
- Anti-pattern neutralization : `LinearGradient` ≤ 1/page, drop `MintPremiumButton` résiduel

**Vague 2 grammaire « Chiffre nu interdit » wrap** (~50-65h ≈ 1.5 sem)
- Build `MintConfidenceWrap` composable widget
- Refactor 29 écrans hero number unwrapped → wrap
- Lint custom `ds_v2_lint_hero_unwrapped.py` en lefthook pre-commit

**Acceptance Wave 1.5 close** : score moyen Tier 1-3 ≥ 70% (re-run sub-agent H scan post-merge).

### Wave 2 — TrajectoryMap build + Mon Argent P2 refactor (~3 sem)

**Au lieu de 2 sem original, étendue à 3 sem par cumul** :
- TrajectoryMap component Flutter (sub-agent C wireframe v1 finalisé via /design-shotgun choice)
- 8 archetypes templates `LifeRoadmap` (1 par archetype)
- Milestone M0 « Où tu en es » design + build (vient de Mon Argent P2 — patrimoine snapshot intégré)
- Tab bar refonte 4→3 ([mint_shell.dart](apps/mobile/lib/widgets/mint_shell.dart) : drop Mon Argent destination, add Trajectoire)
- Deep links migration `/mon-argent/*` → `/trajectoire/m0/*`
- Tests régression flows historiques Mon Argent → Trajectoire M0
- Golden tests Julien profile + Lauren profile
- 5-7 jours gain Wave 1 réinvestis ici comme marge confort + Phase F-2 ConfidenceBand wraps additionnels

**Pre-condition Wave 2 kickoff** :
- Wave 1.5 close (score Tier 1-3 ≥ 70%)
- Test 5 utilisateurs Wave 0 (sub-agent G + test wireframe) : ≥ 4/5 GO ; ≤ 1/5 PAUSE retour office-hours

### Wave 3 — Orchestrator + push surface (3 sem)

Inchangé du design doc original :
- `LifeEventWatchdog` service backend (calendar + age + state changes triggers)
- `CapEngine v2` (LLM-augmented avec events watchdog input)
- Push surface Aujourd'hui : missions du jour/semaine au-dessus du timeline
- Intent cards : tap mission → Coach overlay scoped

### Wave 4 — Widgets didactiques inline Coach (3 jours — SHORT)

Confirmed sub-agent A :
- Wire `render_widget(widget_id, params)` Flutter
- Extend `EducationalInsertService` (déjà existant) avec mapping `coach_intent → widget`
- Extract 5 thin simulator-widgets depuis Explorer (`3a / amortization / saron / real_return / disability_gap`)
- Maestro flow + lint close

**Pivot gate Wave 4 J1-end** : si `widgets/coach/` pool < 8 truly reusable post-extraction, escalate à medium (1 sem).

## Calendrier consolidé

```
Sem 0  (5-7 jours)     | Wave 0 Foundation [SHIPPED 2026-05-14 PR #600]
Sem 1-3                | Wave 1 backend tools + planner refined (gain 5-7j)
Sem 4-7                | Wave 1.5 DS v2 propagation big-bang
Sem 8-10               | Wave 2 TrajectoryMap + Mon Argent P2 refactor (+5-7j gain Wave 1)
Sem 11-13              | Wave 3 orchestrator + push surface
Sem 13 (3 jours)       | Wave 4 widgets didactiques inline Coach
Sem 13.5+              | Post-launch TestFlight gate + canary monitoring
```

**Total : 12-13 semaines** depuis Wave 1 kickoff (2026-05-14+) → finition Wave 4 estimée fin août / mi-septembre 2026.

## Counter-arguments and data gaps

- **What does the strongest opposing view say ?**
  Anti-Wave-1.5 : 3-4 sem de propagation cosmétique entre Wave 1 (substance backend) et Wave 2 (substance visible) = risque de momentum decay. Le scope creep officiel a fait passer 7-8 sem → 12-13 sem (+60%). Si l'objectif TestFlight ship gate est fin juillet, Wave 1.5 décale la ship d'1 mois — coût d'opportunité competitive (autres apps fintech CH bougent vite). Option (b) screen-by-screen incremental aurait étalé le coût sans bloquer.

- **What does this source not address ?**
  - Aucun budget OPEX/CFO modélisé sur les 12-13 semaines.
  - Aucune mesure de la latence Anthropic API en condition Suisse rurale (cf. ADR SLM caveats).
  - La probabilité de re-litigation Mon Argent P2 (si users veulent un tab patrimoine dédié) qui ferait pivoter back à P1 lite Wave 2.5+.
  - Le risque conjoint Phase 7 ship-or-pause-définitive : si Julien rebooté Phase 7 à `chatTabVisible=false` en Wave 2-3, le scope 3-tab Aujourd'hui · Coach · Trajectoire devient 2-tab Aujourd'hui · Trajectoire + Coach overlay → re-refactor.

- **What would change this conclusion ?**
  1. Si test 5 utilisateurs Wave 0 montre rejet visuel DS v2 (≥ 3/5 « ça ne me parle pas / je trouve ça trop austère / etc. ») → revisit Wave 1.5 scope (peut-être skip propagation, laisser palette anthracite).
  2. Si Wave 1.5 dépasse 145h budgétés → option (b) fallback (incremental durant Wave 2/3 sans vague dédiée).
  3. Si pression marché competitive force ship anticipé → coupe Wave 1.5 Tier 3 (15 écrans), garde Tier 1-2 (12 écrans), gain ~1 sem.
  4. Si Wave 1c citation gate UI s'avère partielle (flag OFF en prod, etc.) → coupe Wave 1c, ship Wave 1a+b backend seuls, défère 1c Wave 2.

## Sources

- `.planning/audit/2026-05-14-handoff-vs-code-drift.md` — drift cross-corpus
- `.planning/audit/2026-05-14-corpus-visuel-explorer.md` — Wave 4 SHORT
- `.planning/audit/2026-05-14-coach-tools-inventory.md` — Wave 1b refined
- `.planning/audit/2026-05-14-ds-v2-coverage.md` — Wave 1.5 dette chiffrée
- `.planning/decisions/2026-05-14-aujourdhui-doctrine.md`
- `.planning/decisions/2026-05-14-slm-on-device-abandon-rationale.md`
- `.planning/decisions/2026-05-14-mon-argent-p2-dissolution-trajectoire.md`
- `.planning/decisions/2026-05-14-ds-v2-propagation-wave-1-5-bigbang.md`
- Design doc APPROVED 2026-05-14 (`/Users/julienbattaglia/.gstack/projects/MINT-IA-MINT/julienbattaglia-feature-S98-sentry-v0-design-20260514-110101.md`)

## Status & follow-up

- **Implementation tracking** :
  - **Wave 1 kickoff PR** : nouveau branche `feature/S99.1-wave-1-backend-tools-refactor` depuis dev (post-merge PR #600).
  - **Wave 1.5 phase artifact stack** : `.planning/phases/wave-1.5-ds-v2-propagation/` avec PLAN / EXECUTION / VERIFICATION (GSD workflow).
  - **Wave 2 kickoff** : nouvelle branche `feature/S99.2-wave-2-trajectory-map` après Wave 1 + Wave 1.5 merged.
  - **Phase artifact stack par Wave** : cohérent avec memory `feedback_gsd_workflow_default` (≥3 perimeters → GSD).

- **Re-litigation triggers** :
  - Test 5 utilisateurs Wave 0 rejet visuel DS v2 → revisit Wave 1.5 scope
  - Wave 1.5 dépassement 145h → fallback option (b) incremental
  - Pression competitive ship anticipé → coupe Wave 1.5 Tier 3
  - Wave 1c citation gate flag OFF prod → défère Wave 1c
  - Mon Argent P2 user test rejet → re-litigation P1 lite (revisit ADR P2)
  - Phase 7 ship-or-pause-définitive change architecture cible 3-tab → re-refactor

---
*Decided 2026-05-14 par Julien via 3 questions post-PR #600 : Mon Argent P2, DS v2 (a) big-bang, Wave 1 gain réinvesti Wave 2. Drafted Claude. Plan séquence post-Wave-0 final.*
