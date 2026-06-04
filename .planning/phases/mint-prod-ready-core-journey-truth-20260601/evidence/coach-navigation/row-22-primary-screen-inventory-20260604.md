---
description: Primary screen role inventory for Journey Truth Matrix Row 22 after CJT-026 and CJT-027.
status: draft
date: 2026-06-04
---

# Row 22 Primary Screen Inventory

This is a static inventory pass for Journey Truth Matrix Row 22:
"Navigation is human-logical, no duplicate or triple-role screens."

Scope: primary production surfaces only. This does not close Row 22. It records
the current human role contract, data direction, duplicate-content boundary, and
available runtime evidence so the next pass can target the remaining gaps.

## Current Contract

| Surface | Route(s) | Human role | Route owner / registry behavior | Upstream data | Downstream effect | Duplicate-content decision | Runtime evidence |
|---|---|---|---|---|---|---|---|
| Aujourd'hui | `/home` | Daily attention and next action. | `RouteOwner.system`; shell tab; `home_shell` is `conversationPure`, `preferFromChat=false`. | `CoachProfileProvider`, plan/check-in/action state, confidence widgets. | Sends user to Coach for recalculation/enrichment/action follow-up. | Must not become a second Mon Argent or Rapport. It can summarize attention, not duplicate dense money detail. | Regression sweep includes S005 landing to Aujourd'hui and `96-s005-aujourdhui-landed.png` under `evidence/maestro-ci/cjt-014-regression-sweep-20260603T074935/`. |
| Mon Argent | `/mon-argent` | Current financial state. | `RouteOwner.system`; shell tab; `mon_argent_tab` is `conversationPure`, `preferFromChat=false`. | `BudgetProvider`, `BudgetSnapshot`, `CoachProfileProvider`, patrimoine/profile signals. | Opens Budget setup/detail, Profile/Dossier, Scan, or Coach topic. | Owns current-state money summary. Rapport may consume its truth but must not restage the dashboard stack. | Money Trust chain covers Budget -> Mon Argent -> Rapport -> Coach at `evidence/maestro-ci/cjt-026-money-trust-synthesis-recap-20260604T131846/`. |
| Budget | `/budget`, `/budget/setup` | Cashflow configuration and fixed-charge/envelope detail. | `RouteOwner.budget`; `/budget` intent `budget_overview` opens the decision canvas; `/budget/setup` is `captureUtility`. | `BudgetInputs`, `BudgetProvider`, profile/wizard fallback, stored `budget_inputs_v1`. | Feeds Mon Argent, Rapport/Bilan, and Coach budget grounding. | Owns editable budget facts and cashflow detail. Mon Argent can summarize; Rapport can cite synthesis only. Coach budget actions must route to the real `/budget` screen, not a hidden drawer placeholder. | CJT-024 fixed restart fallback and Coach storage grounding; current green evidence `evidence/maestro-ci/cjt-024-money-trust-fix3-20260604T083121/`. |
| Coach | `/coach/chat`, `/coach/history` | Conversation, explanation, cited answers, and routing. | `RouteOwner.coach`; shell tab; `coach_chat` is `conversationPure`, `preferFromChat=false`. | Coach context packet, profile, budget, scan/profile facts, backend tools. | May open permitted screens or stay in conversation; saves facts via coach/profile contracts. | Must not be a hidden duplicate screen. It can explain and route, not silently replace Budget/Profile/Rapport ownership. | Money Trust chain reaches Coach after Rapport in `evidence/maestro-ci/cjt-026-money-trust-synthesis-recap-20260604T131846/`; cited 3a proof remains CJT-011 scope. |
| Rapport / Bilan | `/rapport`; legacy `/report`, `/report/v2` redirect. | Synthesis, proof, export-ready recap. | `RouteOwner.system`; intent `financial_report`; `ScreenBehavior.synthesisRecap`; `preferFromChat=false`. | Persisted report answers plus canonical money/profile truth from Budget/Profile paths. | Sends next action to Coach or canonical money surface. | Consumer only. No independent P0 recalculation and no duplicate Budget/Mon Argent dashboard stack. | Direct `/rapport` proof at `evidence/maestro-ci/cjt-026-rapport-synthesis-recap-20260604T131746/`; Money Trust proof at `evidence/maestro-ci/cjt-026-money-trust-synthesis-recap-20260604T131846/`. |
| Profile / Dossier | `/profile/bilan`; `/profile` redirects there. | Facts, provenance, and correction. | `RouteOwner.system`; intent `financial_summary`; `ScreenBehavior.captureUtility`; `preferFromChat=true`; `prefillFromProfile=true`. | `CoachProfileProvider`, `CoachProfile`, `BudgetSnapshot`, document-derived facts. | Opens Scan or Coach; correction paths feed profile/budget/document truth. | Not a simulator and not a Bilan synthesis. It may show facts behind MINT's state, not advise as a decision surface. | CJT-027 drawer -> Mon bilan proof at `evidence/maestro-ci/cjt-027-profile-dossier-role-20260604T133027/`. |
| Scan | `/scan`, `/scan/review`, `/scan/impact`; legacy `/document-scan` redirects. | Trusted document ingestion with review before enrichment. | `RouteOwner.scan`; `document_scan`, `scan_review`, and `scan_impact` are `captureUtility`. | User-selected document/OCR/debug extraction, extraction review payload. | Confirmed facts update profile/Data Spine/Coach context. | May create or refine facts only after review. It must not become a profile display or recommendation screen. | CJT-008 LPP debug fixture proof at `evidence/scan-profile/cjt-008-lpp-scan-review-20260603T081312/`; release camera/OCR remains outside that proof. |
| Explorer | `/explore`, `/explore/<domain>` | Secondary calculators and education by domain. | `RouteOwner.explore`; root `explore_tab` is `conversationPure`, `preferFromChat=false`; domain hubs are destination routes. | Lifecycle/domain selection and calculator-specific inputs. | Opens domain hubs, simulators, or Coach explanations. | Not a global dashboard and not today's action surface. Decision simulators belong here when they are secondary and scoped. | CJT-027 starts from Explore and opens drawer proof at `evidence/maestro-ci/cjt-027-profile-dossier-role-20260604T133027/`; top simulator DS/runtime audit remains Row 17/23 scope. |

## Findings

- The CJT-026 and CJT-027 role fixes are coherent with this inventory:
  `/rapport` is the synthesis recap, and `/profile/bilan` is the dossier/capture
  surface.
- Shell tabs deliberately use `conversationPure` and `preferFromChat=false` in
  `ScreenRegistry`. That is not a bug by itself: they are human navigation
  destinations, not Coach-opened intent targets.
- `/budget` is now treated as the human budget destination for the
  `budget_overview` intent. Inline Coach budget facts remain the job of budget
  tool calls such as `show_budget_snapshot`, not a `directAnswer` route
  classification or drawer placeholder.
- `/scan` is chat-routable as `captureUtility`, while `/scan/review` and
  `/scan/impact` are excluded from chat routing. That matches the review-first
  ingestion role.
- Runtime visual crawl `row-22-primary-screen-crawl-20260604T141534` captured
  all eight primary surfaces and produced green JUnit, but the watchdog returned
  `124` after post-completion silence. The visual review is recorded in
  `row-22-primary-screen-visual-crawl-review-20260604.md`.
- Follow-up seeded visual crawl
  `row-22-profile-dossier-seeded-crawl-20260604T151030` passed with watchdog
  `0`. `/profile/bilan` now first-viewport-leads with dossier facts, source
  provenance, correction, and expanded patrimoine facts before retirement
  projection.
- Non-seeded production onboarding/restart proof
  `row-22-profile-dossier-production-profile-20260604T153106` also passed with
  watchdog `0`. It builds the profile through `/onb`, restarts the app, then
  asserts the same `/profile/bilan` first-viewport dossier contract.

## Row 22 Status

Keep Row 22 at `PARTIAL`.

Reason: the primary role contract is now inventoried and runtime-captured, and
the Profile/Dossier first-viewport role conflict is fixed in both seeded visual
evidence and non-seeded onboarding/restart evidence. Keep `PARTIAL` because Row
23 design/i18n/accessibility closure and broader primary-screen release proof
remain separate gates.

## Next Proof

- Keep the non-seeded profile-persistence proof under regression when editing
  onboarding, SecureWizardStore, or `/profile/bilan`.
- Keep the `/budget` routing contract under regression: `budget_overview`
  opens `/budget`, while inline Coach budget summaries remain separate tool
  calls.
