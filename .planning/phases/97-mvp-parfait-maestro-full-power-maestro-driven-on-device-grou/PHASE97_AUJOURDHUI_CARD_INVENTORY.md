---
description: Phase 97 W5 reachability fix inventory — every card rendered on `AujourdhuiScreen` that needs `MintCardActionBar` wired + stable `Key('card_<id>')` testID. Generated 2026-05-11 by PM Claude direct codebase inspection of `apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart`. Source for W5 task breakdown.
phase: 97
wave: 5
deliverable_for: « W5 reachability fix (closes backlog 999.6) »
source: « apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart imports + render tree »
---

# Phase 97 W5 — Aujourd'hui Card Inventory

> Every card widget rendered on the `AujourdhuiScreen` CustomScrollView, in render order. W5 wires `MintCardActionBar` onto each + adds a stable `Key('card_<id>')`.

## Render order (top-down)

| # | Widget | Source file | Card type | Card ID (proposed) | Needs MintCardActionBar? | Needs Key? | Notes |
|---|--------|-------------|-----------|--------------------|--------------------------|------------|-------|
| 1 | MINT wordmark (pinned header) | `aujourdhui_screen.dart:headerSliver` | branding | n/a — not a card | NO | NO | Pure presentation, no chat-as-verb context |
| 2 | `CapDuJourBanner` | `widgets/aujourdhui/cap_du_jour_banner.dart` | actionable | `card_cap_du_jour` | YES | YES `Key('card_cap_du_jour')` | Wave B-minimal B1 ; highest-priority `CapDecision` |
| 3 | `ConfidenceScoreCard` | `widgets/home/confidence_score_card.dart` | informational | `card_confidence_score` | YES | YES `Key('card_confidence_score')` | Walker 2026-05-08 « façade-sans-câblage » fix surfaced this card |
| 4 | `FinancialPlanCard` | `widgets/home/financial_plan_card.dart` | actionable | `card_financial_plan` | YES | YES `Key('card_financial_plan')` | Same Walker 2026-05-08 fix ; was zero-callers before |
| 5 | `CommitmentsAndCheckinsCard` | `widgets/aujourdhui/commitments_and_checkins_card.dart` | actionable | `card_commitments_checkins` | YES | YES `Key('card_commitments_checkins')` | Cleo loop entry point |
| 6a | `TensionCardWidget` (instance 1 of 3) | `widgets/tension/tension_card_widget.dart` | actionable | `card_tension_0` | YES | YES `Key('card_tension_0')` | Phase 17 sticky summary (3 cards) |
| 6b | `TensionCardWidget` (instance 2 of 3) | same | actionable | `card_tension_1` | YES | YES `Key('card_tension_1')` | — |
| 6c | `TensionCardWidget` (instance 3 of 3) | same | actionable | `card_tension_2` | YES | YES `Key('card_tension_2')` | — |
| 7 | `CleoLoopIndicator` | `widgets/tension/cleo_loop_indicator.dart` | progress visual | `card_cleo_loop` | MAYBE — progress visual, not a card-action surface | YES (for tests) | Phase 18 introspection ; arguably not a card |
| 8 | `MonthHeaderWidget` (collapsible) | `widgets/timeline/month_header_widget.dart` | grouping header | n/a | NO | NO | Pure grouping presentation |
| 9..N | `TimelineNodeWidget` (lazy SliverList.builder, N instances) | `widgets/timeline/timeline_node_widget.dart` | event log | `card_timeline_<event_id>` | YES — but per-node, not per-screen | YES `Key('card_timeline_<event_id>')` | Each timeline node is a distinct event/decision/projection ; per-node card-actions make sense (« explique-moi cette décision », « simule un what-if », « rassure-moi sur l'impact ») |

## Card-action verb routing per card (proposed)

Following the 3-verb intent set locked in 96-CONTEXT D-05 (« Explique-moi » / « Simule » / « Rassure-moi ») :

| Card | « Explique-moi » → chat overlay with intent | « Simule » → Explorer deep-link | « Rassure-moi » → chat overlay with intent |
|------|---------------------------------------------|--------------------------------|--------------------------------------------|
| `card_cap_du_jour` | « Explique-moi pourquoi cet engagement est prioritaire » | n/a — Cap n'a pas de simulateur direct ; route to /explorer with topic=cap_decision | « Rassure-moi sur ce que je risque si je ne fais rien » |
| `card_confidence_score` | « Explique-moi ce score de confiance » | /explorer?topic=confidence_factors (montre les 4 axes) | « Rassure-moi sur les axes encore manquants » |
| `card_financial_plan` | « Explique-moi mon plan actuel » | /explorer?topic=financial_plan_what_if (slider sur hypothèses) | « Rassure-moi sur la robustesse du plan » |
| `card_commitments_checkins` | « Explique-moi le prochain check-in » | /explorer?topic=commitment_history | « Rassure-moi sur le rythme actuel » |
| `card_tension_<i>` | « Explique-moi cette tension » | /explorer?topic=tension_<i>_simulate | « Rassure-moi sur la résolution » |
| `card_timeline_<event>` | « Explique-moi cet événement / cette décision » | /explorer?topic=timeline_<event>_what_if | « Rassure-moi sur l'impact long-terme » |

## W5 task breakdown (preview ; full PLAN.md authored Phase 97 W6 once registry complete)

- **W5-T1** : add stable `Key('card_<id>')` testIDs to 6 card widgets (CapDuJour, ConfidenceScore, FinancialPlan, CommitmentsCheckins, Tension×3 via param, TimelineNode via event_id). One commit per card type per Karpathy #3 surgical.
- **W5-T2** : wire `MintCardActionBar` below each card. Pass `SerializedCardContext` per CONTEXT.md D-12 schema. 1 commit per card.
- **W5-T3** : verify each card on iPhone 17 Pro sim via Maestro fragment `flows/fragments/tap_card_action_bar.yaml` × 6 cards. Live exit 0.
- **W5-T4** : update `flow_card_action_intent_bar.yaml` to navigate via the auth fragment + tap real Aujourd'hui card (not the demo screen). Live exit 0 against staging.
- **W5-T5** : remove `/debug/chat-as-verb` route OR keep it under `kDebugMode` guard ; document in `route_metadata.dart`.
- **W5-T6** : Universal Link config (entitlements + Apple-App-Site-Association) + Info.plist `CFBundleURLTypes` for `mintapp://` scheme. Closes S003 + S004.

## Counter-arguments and data gaps

### Counter-arguments

- **CA1 — Should TimelineNode get card-actions per node? It's a high-cardinality surface (potentially 100+ events per user).** Risk : if every timeline node has its own MintCardActionBar, the chat overlay becomes the dominant UX. Mitigation : only enable MintCardActionBar on the 5 most recent or 5 highest-impact timeline nodes per `TimelineProvider.topImpactNodes()`. Older nodes show a single « Explorer la chronologie » CTA, not the 3-verb intent bar.
- **CA2 — CleoLoopIndicator is a progress visual, not a card. Wiring MintCardActionBar would be visual noise.** I marked it MAYBE in the table. Decision : NO MintCardActionBar on CleoLoopIndicator ; it's an introspection signal, not an actionable surface.
- **CA3 — The card types listed don't include any « simulator entry » card (e.g. « Marge fiscale 2026 », « LPP rachat »). Where are those reached today?** They're not on Aujourd'hui ; they live on the Mon Argent tab and the dedicated simulator screens. The « Simule » verb routes to `/explorer` which is the catalog of simulators.

### Data gaps

- **DG1** — TimelineNodeWidget instance count per typical user is unknown. Need to instrument `TimelineProvider.totalNodes` on staging for 7 days to size the « top 5 per impact » strategy correctly.
- **DG2** — CapDecision per-archetype variability — does an `expat_us_FATCA` user see the same Cap as a `swiss_native`? If yes, the « Explique-moi pourquoi cet engagement est prioritaire » verb output needs archetype-specific reasoning. Phase 97 W3 regression flows × 8 archetypes will surface this.
- **DG3** — Whether `MintCardActionBar` rendering 6+ times on a single scroll view causes a measurable frame budget hit (>16ms/frame). The 96-ux panel flagged this as R2 in `2026-05-10-phase-96-ux-panel.md`. W5-T2 should benchmark on iPhone 17 Pro sim with all 6 action bars visible.

---

*Phase : 97-mvp-parfait-maestro-full-power*
*Inventory generated : 2026-05-11 (W5 deliverable, written ahead of plan in W0 audit)*
