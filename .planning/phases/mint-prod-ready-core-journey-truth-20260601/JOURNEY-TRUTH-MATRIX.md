# Journey Truth Matrix v0

Date: 2026-06-03

Purpose: replace broad "does MINT work?" claims with capability-level proof. A
row is only "live-proven" when current evidence shows the user path running in
the app or on the target backend. Code presence, unit tests, and historical
flows are useful, but they are not the same proof.

## Status Legend

| Status | Meaning |
|---|---|
| LIVE-PROVEN | Recent Maestro/device/backend runtime evidence exists for the named scope. |
| PARTIAL | Implemented and covered by tests, debug fixture, staging probe, or narrower runtime path. |
| UNPROVEN | Route/code/tests may exist, but no current user-journey proof was found. |
| OPEN | Known bug, release gate, or blocked proof remains open. |
| OUT-OF-BETA | Deliberately outside the current supported beta scope. |

## Operating Scope

Current supported beta proof should stay narrow:

- French Swiss supported archetypes first: `swiss_native` and
  `swiss_native_couple`.
- Unsupported users must be gated to waitlist/exit without unsupported
  guidance.
- The canonical money spine is
  `wizard_answers_v2 -> CoachProfile -> BudgetSnapshot/DataSpineSnapshot ->
  Rapport/Bilan -> CoachContextPacket`.
- Backend Phase 02 `fact_event/fact_current` is release-critical only after the
  production cutover is completed or explicitly deferred.

## Capability Matrix

| # | Capability / human question | Current status | Evidence found | Gap / next proof |
|---:|---|---|---|---|
| 1 | Install/open beta app, then reach the intended first screen | PARTIAL | CJT-015 TestFlight/certificates upload is now proven: run `26960858716` distributed build `2.12.4 - 71` to external testers. Universal Links remain open because product domain `mint-ai.ch` does not resolve publicly from release checks, the iOS Associated Domains chain is not attached, and real-device HTTPS-to-app proof is absent. | Add `[ios-release]` Associated Domains/provisioning change, make `mint-ai.ch` serve MINT AASA directly, then prove a real device opens a signed TestFlight build from an HTTPS MINT link into the expected route. |
| 2 | Unsupported archetype is gated cleanly | LIVE-PROVEN | CJT-012 and `evidence/archetype-gate/maestro-hardgate-expat-us-20260602T090035/result.xml`. | Keep as regression gate; add waitlist consent/error proof if beta expands. |
| 3 | Anonymous visitor reaches register intent | PARTIAL | `flow_landing_to_register.yaml` and historical sweep evidence. | Prove full create-account, email verification, restart, and data continuity. |
| 4 | User creates/logs into an account and local data survives | PARTIAL | Auth routes/tests exist; architecture path uses `AuthProvider`, `wizard_answers_v2`, optional `/api/v1/sync/claim-local-data`. | Run register/login -> restart -> `/profiles/me` hydration with cloud sync on/off. |
| 5 | User can recover/delete/control account data | UNPROVEN | Login/recovery routes exist; privacy routes exist. No current end-to-end proof found. | Add account lifecycle and privacy-control proof before beta support load grows. |
| 6 | Supported user completes simple onboarding into Coach/Home | LIVE-PROVEN | S005, salvage01 retraite→Coach, and hero 3a flow passed on current simulator builds; CJT-018 current AX frame audit proves valid lower frames for T6/T7/T8 ids. | Keep S005 and affected perfect-set flows as regression gates. |
| 7 | Date of birth/profile facts are persisted as facts, not just display age | PARTIAL | Provider/model tests and CJT-004 profile cleanup proof; DOB is stored in wizard/profile path. | Cross-device authenticated round trip: local write -> backend mirror -> fresh login hydration. |
| 8 | Budget situation entry feeds one money truth | LIVE-PROVEN | CJT-003/CJT-023 plus CJT-024 restart fallback proof; latest green run `evidence/maestro-ci/cjt-024-money-trust-fix3-20260604T083121/result.xml`. | Keep as release regression after any budget/profile/report/coach-opener change. |
| 9 | Mon Argent shows the same money state after restart | LIVE-PROVEN | Money Trust chain and Bilan storytelling reruns include Budget -> Mon Argent continuity. | Keep same flow as spine gate. |
| 10 | Rapport/Bilan consumes the same state and avoids duplicate budget surfaces | LIVE-PROVEN | CJT-002/CJT-010; Bilan naming proof; `evidence/storytelling/cjt-010-*`. | Keep empty and populated `/rapport` flows as regression gates. |
| 11 | PDF export produces a real report artifact | PARTIAL | CJT-017 service proof for concrete PDF export. | Add live share/export path and content QA rubric. |
| 12 | Document scan updates profile/Data Spine/Coach context | PARTIAL | CJT-008 LPP debug fixture Maestro path plus provider/DataSpine/Coach packet proof. | Prove release camera/PDF/OCR or OCR-paste path with restart and Data Spine assertions. |
| 13 | User can correct/profile-provenance facts after scan/onboarding | PARTIAL | Profile provider tests and profile/privacy screens exist. | Run human correction journey: view fact/source -> edit -> restart -> Coach uses corrected value. |
| 14 | Coach gives a cited/current answer for 3a scope | PARTIAL | CJT-011 live 3a citation proof; CJT-021 staging temporal fallback probe. | Rerun staged app/backend Maestro after temporal fix; extend golden eval set. |
| 15 | Coach saves facts and makes profile/budget/document data live | PARTIAL | `save_fact` contracts, Dart fallback, profile tests, money trust Coach step. CJT-028 now proves Flutter `save_fact('incomeNetMonthly')` + `save_fact('totalDebt')` persist, survive `loadFromWizard()`, feed `DataSpineService`, and reach `CoachContextPacketService` as `budget.monthly_net` + `situation.total_debt` without leaking `wizard_answers`. | Keep `PARTIAL`: add runtime Coach text -> fact capture -> restart proof, and cover authenticated backend `save_fact` -> synced Flutter profile -> Coach context. |
| 16 | Coach can open the right screens/widgets from conversation | PARTIAL | Route resolver and widget tests exist; CJT-009 route contract only. | Live Coach-to-widget journey with stable ids and post-widget state persistence. |
| 17 | Simulators/widgets meet design-system and source rules | PARTIAL | CJT-030 fixed `/simulator/compound` from four visible primary sliders to three visible inputs plus a collapsed editable annual-return assumption. Smoke proof: `flutter test test/screens/simulator_screens_smoke_test.dart` passed (`52 tests`), including compound initial slider count `3` and expanded count `4`. Static top-simulator slice recorded at `evidence/simulator-design/row-17-compound-visible-input-contract-20260604.md`. | Keep `PARTIAL`: complete runtime/visual audit for top shipped simulators, especially `/simulator/rente-capital`, and prove source/disclaimer, i18n, accessibility, and <=3 primary visible inputs or documented exception per simulator. |
| 18 | User has clear actions and can complete one | PARTIAL | Micro-action, plan reality, check-in, commitment tests exist. | Live Home/Coach action completion flow; prove completion changes next state. |
| 19 | User creates a plan and MINT helps follow it | PARTIAL | `FinancialPlanService`, `PlanTrackingService`, check-in services have tests. | Integrated proof: generate plan -> restart -> profile change -> stale detection -> check-in/commitment. |
| 20 | Coach/history lets a user return to prior context | PARTIAL | `/coach/history` route exists; Coach shell tests exist. | Live history/resume proof with persisted context. |
| 21 | Daily return screen answers "what needs attention now?" | PARTIAL | Product role is defined in review synthesis; action cards exist. Runtime Row 21 proof now opens `/home` on iPhone 17 Pro, asserts `card_cap_du_jour`, `mint_card_action_bar`, and verb ids `mint_card_action_explain` / `mint_card_action_simulate` / `mint_card_action_reassure`, then taps `Simule` and reaches `/explore` instead of the previous `Page introuvable` route bug. Evidence: `evidence/daily-return/row-21-daily-return-attention-action-proof-20260604.md`; JUnit `evidence/maestro-ci/row-21-daily-return-attention-action-20260604T183725/result.xml` (`tests=1`, `failures=0`, watchdog `0`) plus screenshots; widget/action-bar tests passed (`27/27`). | Keep `PARTIAL`: prove action completion/acknowledgement persists and returning to `Aujourd'hui` shows the next correct priority, not only the first attention/action surface. |
| 22 | Navigation is human-logical, no duplicate or triple-role screens | PARTIAL | REVIEW-SYNTHESIS defines screen roles; screenshot concern on "Ton Plan Mint" is closed for active Rapport/Bilan. Post-push audit found `ReportPreviewWidget` was legacy/non-production-wired; it was deleted instead of revived. Runtime recheck after deletion: `flow_money_trust_chain_budget_mon_argent_rapport_coach` passed on iPhone 17 Pro iOS 26.2. CJT-026 split `/rapport` out of `decisionCanvas` into explicit `synthesisRecap`, so Bilan/Rapport is no longer registry-grouped with simulators/arbitrage surfaces. Post-CJT-026 runtime proof: direct `/rapport` passed at `evidence/maestro-ci/cjt-026-rapport-synthesis-recap-20260604T131746/`; Money Trust chain passed at `evidence/maestro-ci/cjt-026-money-trust-synthesis-recap-20260604T131846/`. CJT-027 then moved `/profile/bilan` / `financial_summary` out of `decisionCanvas` into `captureUtility`, matching its Profile/Dossier facts and correction role. Static primary-screen inventory now records owner, job, upstream/downstream, duplicate-content decision, and known runtime evidence at `evidence/coach-navigation/row-22-primary-screen-inventory-20260604.md`. `budget_overview` now opens the real `/budget` decision canvas, and Coach no longer maps `/budget` to a drawer placeholder. Budget fresh-state runtime proof shows `/budget` and `/budget/setup` avoid salary-only first-viewport CTAs at `evidence/maestro-ci/row-22-budget-income-copy-20260604T144318/`; direct `BudgetScreen` empty-state copy is covered by widget test (`Ajouter mes revenus`, no `salaire`). Production `budget_overview` unit coverage now locks ready routing to `/budget`, missing-income fallback to registered `/onboarding/quick`, and missing `netIncome` reporting. Initial primary-screen visual crawl captured `/home`, `/mon-argent`, `/budget`, `/coach/chat`, `/rapport`, `/profile/bilan`, `/scan`, and `/explore` at `evidence/maestro-ci/row-22-primary-screen-crawl-20260604T141534/`; JUnit was green, but watchdog returned `124` after post-completion silence. Follow-up seeded visual crawl passed with watchdog `0` at `evidence/maestro-ci/row-22-profile-dossier-seeded-crawl-20260604T151030/`; `/profile/bilan` now first-viewport-leads with dossier facts, source provenance, correction, and expanded patrimoine facts before retirement projection. Non-seeded onboarding/restart proof also passed with watchdog `0` at `evidence/maestro-ci/row-22-profile-dossier-production-profile-20260604T153106/`. Review notes: `evidence/coach-navigation/row-22-primary-screen-visual-crawl-review-20260604.md`. | Keep `PARTIAL`: Row 23 design/i18n/accessibility closure and broader primary-screen release proof remain separate gates. Keep the new non-seeded profile-persistence flow under regression for onboarding/SecureWizardStore/Profile edits. |
| 23 | Design chart is respected across primary screens | PARTIAL | Core Budget/Report/Coach paths use tokens; Flutter audit found hardcoded plan/action strings and some direct copy tests. Row 22/23 follow-up fixed Budget setup/card French fallback copy in DE/ES/IT/PT, added an ARB guard for critical Budget setup keys, and removed the last active `Plan Mint` copy residue from `age_band_policy.dart` with a life-event timeline guard. Row 23 i18n guard now scans the primary screen files for hardcoded French `Text(...)` literals and asserts primary ARB families exist in all 6 locales; `flutter test test/i18n/hardcoded_string_audit_test.dart` passed (`33 tests`). Static design contract now guards primary screens against negative `letterSpacing`; red proof caught `coach_chat_screen.dart:2334`, fixed by removing `letterSpacing: -1`, and `flutter test test/design/primary_screen_design_contract_test.dart` passed. Dynamic-type smoke now pumps Budget, Mon Argent, Profile/Dossier, Document Scan, and Explorer primary screens at 200% text scale; `flutter test test/accessibility/primary_screen_dynamic_type_test.dart` passed (`5 tests`) with durable evidence at `evidence/rapport-design/row-23-primary-screen-dynamic-type-20260604.md`. | Keep `PARTIAL`: add visual audit review for primary-screen screenshots plus Coach/Rapport runtime accessibility proof. |
| 24 | Privacy, consent, logs, and data controls are coherent | PARTIAL | Current targeted proof covers mobile privacy-control UI/edit/delete/grouping, consent sheet purpose/accept flow, third-party document declaration analytics with aggregate-only `subject_count` and no subject names/docHash, mobile Sentry scrub/PII breadcrumb guards, backend privacy contracts, backend Sentry scrub, PII scrubber, fact-key allowlist, consent service/Merkle receipts, save-fact PII redaction, and privacy delete count integration. Runtime proof now opens `/profile/privacy-control` on iPhone 17 Pro and shows `Ce que MINT sait de toi` with `4 données | 100 % à jour` and no empty state: `evidence/maestro-ci/row-24-privacy-control-runtime-20260604T182101/result.xml` (`tests=1`, `failures=0`, watchdog `0`) plus screenshot. Summary proof: `evidence/privacy-controls/row-24-privacy-consent-log-scrub-proof-20260604.md`; mobile privacy suite passed (`79 tests`); backend privacy/consent/log scrub suite passed (`145 passed, 1 skipped`). | Keep `PARTIAL`: add live privacy center/delete-export journey, document consent and scan/OCR consent runtime proof, production log/Sentry PII sampling audit, and legal nLPD/LPD wording/processor sign-off. |
| 25 | Backend production fact substrate is current | OPEN | CJT-013: staging Phase 02 proof exists; production lacks Phase 02 tables/cutover evidence. | Execute or explicitly defer production runbook; capture prod head, flags, backfill parity, metrics. |
| 26 | Runtime automation is stable enough to catch regressions | PARTIAL | CJT-014/CJT-016 local regression sweep green; CJT-024 Money Trust restart/deep-link rerun is green; CJT-018 current AX frame audit closes the active onboarding locator debt. | Keep regression sweeps scheduled; do not use simulator proof to close CJT-015 signed-device access. |
| 27 | Observability/release feedback loop catches beta regressions | UNPROVEN | Roadmapped in Phase 35; no current closure evidence found. | Sentry/crash/activation/drop-off loop before broader beta. |
| 28 | Agents do not drift away from the active GSD | PARTIAL | `tools/checks/cjt_context_guard.py` exists and is wired in pre-commit; latest post-push audit `evidence/devex/post-push-commit-audit-20260604.md` reconciles recent commits against the active CJT map. The guard now also fails if the active Row 1 / CJT-015 release-gate lines drift from product Universal Link domain `mint-ai.ch`; regression proof: `python3 -m pytest tools/checks/tests/test_cjt_context_guard.py -q` passed (`4 passed`). | Add a per-session checklist to every CJT handoff: roadmap/matrix/bug tracker read, open gates named, newest commit audited. |
| 29 | Quality improves monotonically instead of moving bugs around | PARTIAL | `BUG-TRACKER.md` has severity/status/evidence columns and post-push debt IDs `D-20260604-01` through `D-20260604-06`; `D-20260604-01/02` were removed by deleting dead `ReportPreviewWidget` code and baseline debt. Proof changed from widget-only test to runtime Money Trust chain JUnit (`tests=1`, `failures=0`). | Require every wave to state which matrix row improved, which bug closed, and which proof command changed the status. |
| 30 | New debt is either avoided or explicitly tracked | PARTIAL | Post-push audit tracked legacy widget debt, doc drift, evidence hygiene, legacy naming, and staging bypass as debt instead of hiding them in chat; follow-ups removed the tracked dead-widget debt and D-20260604-05 legacy `Plan Mint` wording from `age_band_policy.dart` with a regression guard. | Add a no-new-debt section to each commit review: introduced / revealed / accepted / removed, with owner and next proof. |

## What Was Missing From The User List

The user's list covers the main product promises. The missing rows are mostly
operational and trust boundaries:

- Install/TestFlight/Universal Link access.
- Unsupported-user eligibility and waitlist exit.
- Anonymous-to-account data claim and restart continuity.
- Profile provenance, correction, and privacy controls.
- Empty/error/offline/refusal states.
- Daily return loop on Aujourd'hui.
- Analytics/crash feedback loop.
- Backend production fact-current cutover.

## Priority Waves

1. Access and truth gates: CJT-015, CJT-013.
2. Human journey proof: account create/login continuity, release OCR scan,
   Coach fact capture, action completion.
3. Product/navigation cleanup: screen role inventory, duplicate content
   decisions, daily return loop proof.
4. Design/i18n/accessibility hardening: top screens and top simulators.
5. Operational beta loop: privacy/control surface, crash/analytics evidence,
   regression schedule.
6. Quality governance loop: anti-drift guard, quality-ratchet proof, and
   no-new-debt accounting after every commit.

## Expert Inputs Integrated

- Product audit: added lifecycle rows for install/open, eligibility, waitlist,
  provenance/correction, daily return loop, support/observability.
- Architecture audit: classified local money spine as strongest proof, backend
  production fact-current as the main open architecture boundary.
- QA audit: converted CJT evidence into live/staging/unit/open proof levels.
- Flutter/UI audit: separated route/code presence from user-journey proof and
  flagged simulator/design/i18n hardening.
