# Phase 97: MVP Ship Gate — Context

**Gathered:** 2026-05-06
**Status:** Ready for planning (gates on 91-96 closure for execution; plans CAN be drafted now)
**Mode:** Auto-generated from milestone synthesis (REQUIREMENTS.md SHIP-01..04 + `2026-05-06-test-theater-post-mortem-doctrine.md` §7 ship gate + `MILESTONE-MVP-PERIMETER.md` §7 D13/D14)

<domain>
## Phase Boundary

Phase 97 is the **shippable gate** : every prior phase has built infrastructure (audit log, FATCA gate, locale eclairage, real test infra, Sentry tags, Checkly probes) — Phase 97 turns that infrastructure into an actual TestFlight Internal NDA build that 5 Swiss-FR friends install and run for 24 h, behind a banner that reads « pré-conformité, données non recommandées ». Per `project_testflight_ship_path.md` the literal ship action = `pubspec.yaml` bump + `dev → staging` merge fires `.github/workflows/testflight.yml` ; the walker is **NOT a ship blocker** (doctrine §7 reframes it as « optional dev tool ; production is the source of truth »). What IS a blocker is the four SHIP-XX requirements gates : Maestro green on 3 devices against release-config staging with **no** `MINT_E2E_*` defines (today's `tools/simulator/flows/*.yaml` walker flows DO inject those defines — they're walker-grade, not ship-grade), 5 testers under NDA observed for 24 h ≥ 99.5 % crash-free in Sentry release-health (depends on Phase 96 OBS-01 alert), `docs/compliance/CONTROL_MATRIX.md` ≥ 95 % FinSA art. 7/8/9/12/13/16 coverage (file does NOT exist today — `docs/compliance/` directory does not exist either), and a written 1-h paid sign-off from Pestalozzi / Lenz & Staehelin / Vischer filed at `.planning/compliance/counsel-signoff-2026-05.pdf` (directory does not exist either).

Out of scope : App Store production launch (waits on counsel sign-off → public-beta cohort → phased release, all v2.15+) ; paid Sentry tier (Free Developer plan covers TestFlight Internal cohort traffic, doctrine §4 W1 confirmed) ; Pactflow paid broker (Phase 95 ships file-system Pact files) ; Maestro Cloud paid tier auto-cancellation safeguards ; SOC2 / ISO27001 audit prep ; Datadog / Grafana « LSFin compliance score » trend dashboard (deferred from Phase 96).
</domain>

<decisions>
## Implementation Decisions

### SHIP-01 — Maestro E2E suite green on iPhone 17 Pro + iPhone SE + iPad mini

- **Tool: Maestro Cloud** (doctrine §8 stack table, $99/mo). Single stack for the 3-device matrix ; no test-only code paths in the production app ; runs against release-config staging build.
- **Where existing flows live:** `tools/simulator/flows/*.yaml` — 14 walker-grade flows including `walkthrough_proactive_push.yaml`, `walkthrough_cross_session_opener.yaml`, `walkthrough_interrupt_banner.yaml`, `walkthrough_persona_toggle.yaml` (all from Phase 91), `julien_swiss.yaml` and `lauren_expat_us.yaml` (Phase 90 personas). **These are NOT directly reusable** : they all rely on `MINT_E2E_ARCHETYPE`, `MINT_E2E_FORCE_ECLAIRAGE_KIND`, `MINT_DISABLE_BETA_MODAL` dart-defines that are explicitly forbidden by SHIP-01 acceptance criterion (`ROADMAP.md:190` « **NO `MINT_E2E_*` defines** »). The defines are `kReleaseMode`-guarded today (`anonymous_chat_screen.dart:130`, `coach_orchestrator.dart`) so a release build ignores them — but the walker flows assume them, so they fail without them.
- **New flow location: `apps/mobile/.maestro/`** (NOT `tools/simulator/flows/`). Mirrors Maestro Cloud convention + keeps Phase 97 ship-gate flows architecturally distinct from walker/dev flows. Ship-gate flows MUST NOT read any `MINT_E2E_*` define ; they drive the app exactly as a real user does.
- **8 ship-gate flows (one per ROADMAP `:190` step + 1 setup):**
  | Flow | File | Drives |
  |---|---|---|
  | 00 — login | `apps/mobile/.maestro/01_login.yaml` | Email + password against staging dedicated tester account `tester-1@mint.test` (Plan 97-02 provisions ; reuses Phase 96 OBS-02 `checkly@mint.test` pattern) |
  | 01 — onb | `apps/mobile/.maestro/02_onboarding.yaml` | `/onb` premier-éclairage flow → home reach |
  | 02 — home | `apps/mobile/.maestro/03_home_reach.yaml` | `/home` Hero Plan card visible + EnhancedConfidence rendered |
  | 03 — mon-argent | `apps/mobile/.maestro/04_mon_argent.yaml` | `/mon-argent` summary loads, archetype-aware copy visible |
  | 04 — budget setup | `apps/mobile/.maestro/05_budget_setup.yaml` | `/budget/setup` 7-form, persists across kill |
  | 05 — coach chat | `apps/mobile/.maestro/06_coach_chat.yaml` | `/coach/chat` 3-turn convo + opener visible (depends on Phase 91 VIVANT-02) |
  | 06 — documents upload | `apps/mobile/.maestro/07_documents_upload.yaml` | `/documents/upload` LPP fixture (`tools/checkly/fixtures/probe.jpg` reuse OR new LPP-PDF fixture) → extraction confirmation |
  | 07 — fiscalité levier | `apps/mobile/.maestro/08_explorer_fiscalite.yaml` | `/explorer/fiscalite` levier card + EnhancedConfidence visible |
- **Beta disclosure modal:** ship-gate flows MUST tap through it on first launch. Today `MINT_DISABLE_BETA_MODAL=true` skips it ; ship-gate path = first flow taps the « J'accepte » CTA. Verified at `apps/mobile/lib/widgets/beta/beta_program_disclosure_sheet.dart` — sheet exists, hooked into `landing_screen.dart`.
- **Device matrix on Maestro Cloud:** iPhone 17 Pro (iOS 26, ship target), iPhone SE 3rd gen (iOS 18, smallest screen ship target — covers compact-layout regressions), iPad mini 7th gen (iPadOS 26, tablet adaptive-layout). All run identical 8-flow suite. Suite green = 8 flows × 3 devices = 24 green runs in same Maestro Cloud test plan execution.
- **Build artefact:** ship-gate Maestro runs against the **same `flutter build ios --release` artefact** that ships to TestFlight (not a separate build). Plan 97-01 wires `.github/workflows/maestro_cloud.yml` that consumes the same `.ipa` produced by `testflight.yml` (or rebuilds from the same commit deterministically — Plan 97-01 picks one approach). API URL = `STAGING_API_URL` (Railway), matches `testflight.yml:83`.
- **Verification (success criterion 1):** Maestro Cloud run report archived at `.planning/phases/97-mvp-ship-gate/97-VERIFICATION-REPORT.html` per `feedback_html_evidence_report.md` ; PR-comment auto-summary ; merge-blocking on `dev → staging` via branch protection.

### SHIP-02 — 5 Swiss-FR testers, TestFlight Internal NDA, banner, 24 h ≥ 99.5 % crash-free

- **TestFlight workflow already wired:** `.github/workflows/testflight.yml` triggers on push to `staging` (or `main` for production), uses Fastlane `bundle exec fastlane beta` for sign + upload, App Store Connect API keys provisioned. **Phase 97 does not touch this workflow** — it consumes it.
- **Pubspec bump path:** current `apps/mobile/pubspec.yaml:5` is `version: 2.12.0+2`. Plan 97-02 bumps to `2.14.0+1` (skip 2.13 to align with the « v2.14 MVP » roadmap label). The `dev → staging` merge that closes Phase 97 fires `testflight.yml`.
- **Banner « pré-conformité, données non recommandées »:** **already shipped** via Phase H2 work — `apps/mobile/lib/widgets/beta/beta_program_disclosure_sheet.dart` + ARB keys `betaDisclosureEyebrow` (« MINT en test »), `betaDisclosureHeadlinePrefix` (« Tu testes une version qui »), `betaDisclosureHeadlineEm` (« apprend avec toi »). **Decision required (Julien):** the existing banner says « MINT en test » + « Tu testes une version qui apprend avec toi » — the SHIP-02 spec says « pré-conformité, données non recommandées ». **Plan 97-02 task 1: align the ARB strings** to include the literal SHIP-02 disclaimer (or add a new dedicated NDA-cohort eyebrow). Cannot ship the existing banner verbatim and call it SHIP-02 done.
- **NDA template:** **does not exist yet.** Plan 97-02 task 2: draft `.planning/compliance/nda-template-2026-05.md` (1-page Swiss FR mutual NDA, 6-month term, covers screenshots + screen recordings + verbal feedback). Counsel sign-off on NDA template = bundle into SHIP-04 1-h paid review (single bill).
- **5-tester recruitment:** **decision required (Julien) — 5 names + emails by D13.** Profile per `MILESTONE-MVP-PERIMETER.md` §7 D13 = « 5 amis Suisse FR ». Plan 97-02 task 3: Julien provides list ; Plan task adds them as Internal Testers via App Store Connect API or web UI. Internal Testers (≤ 100, no review) is the correct cohort — NOT External Testers (requires Beta App Review).
- **24 h soak observability:** uses Phase 96 OBS-01 Sentry release-health alert + `crash_free_sessions` metric. Verification = Sentry release dashboard screenshot showing the `2.14.0+1` (or whatever pubspec lands) release with ≥ 99.5 % over the 24 h window post-tester-install. If < 99.5 % → triage incident, ship 2.14.0+2 hotfix, restart 24 h window.
- **Tester sign-off artefact:** simple email/Slack thread → screenshot → committed to `.planning/phases/97-mvp-ship-gate/tester-feedback/<tester-id>.md` (1 file per tester, anonymised initials only — never full names in the public repo per `feedback_public_repo_discipline.md`).

### SHIP-03 — `docs/compliance/CONTROL_MATRIX.md` ≥ 95 % coverage

- **File does not exist today.** `docs/compliance/` directory does not exist. Plan 97-03 task 1: `mkdir docs/compliance` + scaffold the matrix.
- **Format: single Markdown table** (CSV-vs-MD discretion call → MD wins because it's grep-able, PR-reviewable, renders on GitHub for journalist/counsel inspection).
- **Columns:** `FinSA Article` | `Control` | `Implementation Anchor (file:line)` | `Test ID` | `Last Green Commit` | `Status` | `Doctrine Reference`.
- **6 FinSA articles in scope per ROADMAP `:192`:** art. 7 (information obligations / pre-contractual), art. 8 (information when providing financial services), art. 9 (information format + timing), art. 12 (suitability + appropriateness), art. 13 (documentation + accountability), art. 16 (transparency on costs).
- **Coverage script:** `tools/checks/control_matrix_coverage.py` **does NOT exist today** (verified via `ls tools/checks/`). Plan 97-03 task 2: ship the script. Logic = parse the table, count rows where `Status` is `GREEN` (controls with at least 1 anchor + 1 test ID + recent green commit), divide by total controls. Target ≥ 0.95. Script returns exit 1 below threshold ; runs in `ci.yml`.
- **Auto-population candidates (anchors already exist):**
  - art. 7 information obligations → `landing_screen.dart:166` LSFin disclosure + `beta_program_disclosure_sheet.dart` (banner)
  - art. 8 al. 1 let. d locale-correctness → `anonymous_eclairage_prompt.py` (Phase 94 COMP-02)
  - art. 8 al. 6 no-promise → `compliance_guard.BANNED_TERMS` + `tools/checks/banned_terms_arb.py` lint (Phase 95 TEST-01 promptfoo)
  - art. 9 information format → `MintTrameConfiance.inline` on simulators (Phase 93 COMP-03)
  - art. 12 suitability via archetype → `coach_profile.dart:1784` 8-archetype path + Phase 93 COMP-04 FATCA gate
  - art. 13 documentation → Phase 93 COMP-01 `coach_message_audits` table + 10-year retention column
  - art. 16 cost transparency → not yet wired (CHF 0 cost today since no premium tier — control = « N/A pre-monetization, will require article-16 wiring before paid tier ships »)
- **Coverage math sanity check:** 6 articles × ~3 controls each ≈ 18 controls. ≥ 95 % = ≤ 1 missing/non-green control (i.e. art. 16 N/A row counts as deferred ; the other 17 must be GREEN). Plan 97-03 verifies in dry-run.

### SHIP-04 — Swiss fintech counsel sign-off, 1 h paid review, written PDF filed

- **Counsel shortlist (per ROADMAP `:193` + doctrine §4 W4):** Pestalozzi Attorneys at Law, Lenz & Staehelin, Vischer. **Decision required (Julien):** pick one + book the 1-h call by D12. All three have FinSA + DLT-Act + nLPD competencies ; pick on availability + quoted fee within CHF 800-1'200 range.
- **Brief format: 5-page summary (NOT full SoT).** Plan 97-04 task 1: draft `.planning/compliance/counsel-brief-2026-05.md` with sections (1) MINT product 1-pager, (2) FinSA articles 7/8/9/12/13/16 coverage table (= SHIP-03 CONTROL_MATRIX.md export), (3) decision artefact summaries (links to `.planning/decisions/2026-05-02-data-residency.md`, `2026-05-06-test-theater-post-mortem-doctrine.md`, `2026-05-06-personal-financial-wiki-v3-candidate.md`), (4) NDA template + tester cohort scope, (5) 3 specific questions for counsel (« does our anonymous-chat lucidity card cross FinSA art. 8 al. 6 personalised-advice line? » + « is the 10-year retention sufficient for OAR-G art. 24? » + « can we ship to 5 NDA testers without further licensing? »).
- **Sign-off artefact:** `.planning/compliance/counsel-signoff-2026-05.pdf` — counsel-authored letter, on letterhead, signed. **Directory does not exist today** ; Plan 97-04 task 0 creates it.
- **Summary in `docs/EVIDENCE.md`:** **file does not exist today** (verified : repo has `COMPLIANCE_REGRESSION_v2.2.md` only). Plan 97-04 task 2 creates `docs/EVIDENCE.md` per doctrine §5 (single source of truth for « tested », updated weekly by Julien). SHIP-04 lands as row 1 with the counsel sign-off date + PDF link.
- **Cost discipline:** budget CHF 800-1'200 for the 1-h review (doctrine §8 stack table). Above CHF 1'500 = stop, re-shortlist. Cap at 1 h paid time + asynchronous follow-up emails.

### Claude's discretion

- **Maestro Cloud paid tier vs free-trial:** $99/mo paid tier required for the 3-device matrix. Discretion = enrol on the 14-day free trial first, validate the 8-flow suite green, THEN convert to paid (saves $99 if a doctrine pivot kills the suite mid-phase).
- **NDA template = mutual 6-month term, Swiss law, FR-language.** Drafts itself from a public Pestalozzi mutual-NDA template. Counsel reviews as part of the same 1-h SHIP-04 slot (no separate bill).
- **Sentry release tag format:** `mint-mobile@2.14.0+1` (matches Sentry's recommended `<project>@<version>+<build>`). Already plumbed via `apps/mobile/lib/main.dart:141` SentryFlutter init — no Phase 97 wiring needed.
- **CONTROL_MATRIX format = MD table** (not CSV, not JSON). Reasoning : counsel + journalists open it in browser via GitHub, no tooling required ; coverage script `tools/checks/control_matrix_coverage.py` parses the markdown table directly with a 30-line regex (Python `re` stdlib).
- **Phase 97 sequence-of-execution:** SHIP-03 (matrix) + SHIP-04 (counsel brief) drafted FIRST in parallel — they don't depend on Phase 96 ship. SHIP-01 (Maestro) depends on Phase 91-96 closure. SHIP-02 (TestFlight) depends on SHIP-01 green. Counsel reviews the package once SHIP-01/02/03 evidence is bundled.

</decisions>

<code_context>
## Existing Code Insights

### Reusable assets

- `.github/workflows/testflight.yml` — full sign + upload via Fastlane, env-driven STAGING_API_URL / PROD_API_URL split, App Store Connect secrets validated. **SHIP-02 consumes unchanged.** Per `project_testflight_ship_path.md` : ship = pubspec bump + dev→staging merge fires this workflow.
- `apps/mobile/lib/widgets/beta/beta_program_disclosure_sheet.dart` + ARB keys `betaDisclosureEyebrow / *HeadlinePrefix / *HeadlineEm` (Phase H2 commit `6ab3dda3`) — banner UI shipped, reachable from `landing_screen.dart`. **SHIP-02 only edits ARB copy** to align with « pré-conformité, données non recommandées » spec.
- `tools/simulator/flows/*.yaml` — 14 walker flows with semantic locators (Phase 90 PERS-07 `tools/checks/maestro_locator_audit.py` lint already enforces drift). **SHIP-01 forks the locator strategy + tap choreography** but writes new flows under `apps/mobile/.maestro/` without `MINT_E2E_*` defines.
- `tools/checks/maestro_locator_audit.py` — existing locator-drift lint. **SHIP-01 reuses unchanged** — runs against the new `.maestro/` flows.
- `apps/mobile/lib/main.dart:141-187` SentryFlutter init with release-health enabled, env tag `MINT_ENV` (Phase 31). **SHIP-02 24h soak reads from this** — no SDK changes.
- Phase 91-96 deliverables roll into SHIP-03 control matrix : COMP-01 audit table → art. 13, COMP-04 FATCA gate → art. 12, COMP-02 locale eclairage → art. 8, COMP-03 confidence on 5 simulators → art. 9, OBS-01 Sentry release-health → art. 13 (operational evidence), TEST-01 promptfoo banned-term → art. 8 al. 6 enforcement.

### Established patterns

- All ship workflow secrets land in GitHub Actions environment-scoped (staging/production). Pattern from `testflight.yml:59-60` reused for any new SHIP-01 Maestro Cloud workflow secret.
- All Maestro flows match by `Semantics(identifier:)` not text content (locator drift lint enforces this — see `tools/simulator/flows/julien_swiss.yaml:33`). SHIP-01 inherits this convention.
- Auditor artefacts per phase land at `.planning/phases/<phase>/<phase>-VERIFICATION-REPORT.html` per `feedback_html_evidence_report.md`. SHIP-01..04 each contribute a section.

### Integration points

- **SHIP-01 (Maestro Cloud):** new dir `apps/mobile/.maestro/` (8 flows) + new workflow `.github/workflows/maestro_cloud.yml` + new GH secret `MAESTRO_CLOUD_API_KEY` + Maestro Cloud project setup (Julien-owned). Zero app-source changes.
- **SHIP-02 (TestFlight cohort):** `apps/mobile/pubspec.yaml:5` version bump + ARB copy edits in 6 locales for banner alignment + `.planning/compliance/nda-template-2026-05.md` (new) + 5 tester emails added in App Store Connect web UI. Workflow `testflight.yml` runs unchanged.
- **SHIP-03 (CONTROL_MATRIX):** new dir `docs/compliance/` + `docs/compliance/CONTROL_MATRIX.md` + `tools/checks/control_matrix_coverage.py` + new `ci.yml` step calling the coverage script.
- **SHIP-04 (counsel sign-off):** new dir `.planning/compliance/` + `counsel-brief-2026-05.md` + `counsel-signoff-2026-05.pdf` (counsel authors) + new file `docs/EVIDENCE.md` row 1.

</code_context>

<specifics>
## Specific Ideas

- **CONTROL_MATRIX as auto-aggregated artefact:** Plan 97-03 considers a `compliance_meta.json` registry (one entry per `decisions/*.md` + `phases/*` artefact tagging which FinSA article it supports) → `control_matrix_coverage.py` reads it → renders the .md table from the registry. Discretion call : if registry adds > 1 day of work, fall back to hand-curated MD table for v2.14 and ship the registry in v2.15 (per Karpathy #2 simplicity).
- **Maestro Cloud cost-discipline objection (doctrine §6):** $99/mo is fixed ; risk = test runs on every PR balloon to thousands of flow-minutes/month. Mitigation : Maestro Cloud workflow runs on-PR for `apps/mobile/.maestro/**` changes only (paths-filter), nightly cron always, weekly full-matrix on Sunday 02:00 UTC. SHIP-01 acceptance is « green on the pre-promotion run », not « green on every PR ».
- **Counsel brief = 5 pages, not 50:** doctrine §8 stack table budgets CHF 800-1'200 for 1 h. A 50-page brief eats the whole hour on counsel reading time, leaves zero for actual Q&A. 5-page summary + linked artefact tree = counsel reads 15 min, advises 45 min.
- **Sentry 24 h soak threshold = 99.5 % over rolling 24 h post-install** (NOT calendar 24 h after merge). Prevents the « shipped Friday 17:00, 6 testers haven't installed by Saturday 17:00 → metric is 0/0 = 100 % » false positive. Plan 97-02 task uses Sentry « release adoption ≥ 5 sessions » threshold gate before the 24 h clock starts.

</specifics>

<deferred>
## Deferred Ideas

- **App Store production launch** — requires (a) counsel sign-off public version, (b) Beta App Review for External Testers expansion, (c) phased release wiring (1/2/5/10/20/50/100 % over 7 d). Target v2.15+.
- **Paid Sentry Team tier ($26/mo) + Session Replay sampling 100 %** — only needed if Free Developer plan exceeds 5 K errors/month or 10 K performance units/month. TestFlight Internal cohort traffic is well under cap. Defer until External Testers cohort (≥ 25 users).
- **Public beta Phase 97.5 with broader cohort (≤ 25 External Testers)** — depends on counsel sign-off + Beta App Review approval. Adds 2-week review cycle. Defer to v2.15.
- **Pactflow paid broker ($30/mo) replacing file-system Pact files** — only worth it when fan-out > 1 mobile + 1 backend. Defer indefinitely until B2B partner integrations land.
- **SOC2 Type 1 / ISO 27001 audit prep** — requires HR + vendor management + asset inventory + incident response runbook. 6-12 month engagement, CHF 30-80 k. Defer to post-revenue v3.

</deferred>
