---
description: Panel synthesis of 7-expert audit on the 2026-05-12 Maestro golden-day flow + MDM Pillar 0 inversion proposal. All 7 verdicts converged on CHANGE — no full GO, no full NOGO. Synthesis produces a revised plan that addresses every blocker raised. Per memory `feedback_expert_panel_pattern`.
type: decision-panel-synthesis
status: SYNTHESIS — awaiting Julien GO for revised plan
created: 2026-05-12
authority: julien-directive-2026-05-12T09:35Z
---

# Panel synthesis — Maestro golden-day flow + MDM Pillar 0 inversion

## Verdict matrix

| Role | Verdict | One-sentence root concern |
|---|---|---|
| Maestro 2.5.1 E2E engineer | **CHANGE** | Phase G `MINT_E2E_FAKE_DATE` dart-define is INFEASIBLE (compile-time, no Clock seam, 60+ datetime call-sites unhooked) ; archetype dart-define needs 8 prebuilt IPAs not `--env` interpolation ; recommend 3-tier discipline (smoke / surface regression / time-travel separate Clock phase). |
| FinTech PM (Cleo / Revolut / Wise lens) | **CHANGE** | Phase A 3-turn wedge + Phase C guided-conversation profile-build IMPORT the Cleo chat-first pattern v2.9 explicitly REJECTS. Phase F blocked by P002 (0 cards wired). Phase G JITAI lacks fintech evidence base. SessionReport gap is the REAL ship blocker, not Maestro coverage. |
| iOS CI / release engineer | **CHANGE** | Mac mini = SPOF for 7-day D-22 soak ; second mini + Maestro Cloud auto-failover. Pre-commit smoke kills velocity → move to pre-push. `MINT_E2E_FAKE_DATE` dart-define needs runtime injection (8 IPAs × 3 dates = 2-5h build per nightly). W8-W13 timeline ignores Apple SLA + 7d soak — real ETA W21. |
| LSFin compliance officer | **CHANGE** (2 HARD BLOCKERS) | Phase C bypasses `29_02_consents_granular` granular consent infrastructure (TRANSFER_US_ANTHROPIC + PERSISTENCE_365D + VISION_EXTRACTION purposes defined but unwired). Phase D Maestro flow uploading real PII through staging Anthropic = GDPR border-crossing without legal basis. |
| Backend FastAPI architect | **CHANGE** | Phase C state machine doesn't exist (`ProfileExtractor` is one-shot regex, not ask-next-field). Phase D cassettes are pytest-only, not runtime-injectable. Phase G clock-split bug (token_budget Redis, JTI blacklist, snapshot timestamps, JWT expiry — 6 documented failure modes). Phase H auth'd-user eclairage state machine doesn't exist. |
| UX onboarding researcher | **CHANGE** | Phase C chat-first contradicts v2.9 doctrine — recommend hybrid (chat-as-verb overlay over card-driven factfind, NOT chat-as-onboarding). Phase E (score reveal) MUST move to end-of-Phase-A per WHOOP « aha moment » + MINT IDENTITY Principle #4 (Prise immédiate). Phase H Eclairage MUST surface in Phase A. Auth = Apple Sign-In primary only. |
| Adversarial critic | **CHANGE** | Pillar 0 is gameable without mechanical lint. Golden Flow as single composite = false-confidence floor (8 archetypes × 8 phases = 64 leaf paths to localise failures). W8-W13 off by ~3× — real bottom-up = 14-18 days. Ceremony risk : 9 pillars + 7 cycle artefacts → 198 markdown files for 33 atomic bugs. Tests-of-features-that-don't-exist anti-pattern across Phase C / G / H. |

**No GO. No NOGO. 7/7 CHANGE.** Convergent root failure : the proposal mixes (1) infrastructure work (Maestro flows, CI mechanics) with (2) missing product features (P002 wiring, P001 narrator quality, SessionReport completion, ConsentService enforcement, Clock abstraction) and (3) doctrine drift (Phase C chat-first contradicts v2.9). Each layer needs its own perimeter.

## Convergent findings (where ≥4 experts agreed)

### C1 — Phase C contradicts v2.9 doctrine (4 experts : FinTech PM, UX, Backend, Adversarial)

The proposal's « coach pose questions séquentielles : âge ? canton ? état civil ? … » is a Cleo / Wealthfront chat-first onboarding pattern. v2.9 explicitly says « MINT n'est pas un chat. Wiki + simulations + minimum chat livraison. Kill chat-tab as destination ». Shipping the Golden Flow as written would lock in chat-first onboarding in CI right as the product is trying to walk away from it.

**Verdict** : Phase C MUST be redesigned as a card-driven FactFind (FORM-based) augmented by chat-as-verb overlays for disambiguation. Hybrid pattern. The « chat » becomes the verb invoked on specific fields, not the trajectory.

### C2 — Phase G `MINT_E2E_FAKE_DATE` is infeasible without a Clock refactor (3 experts : Maestro, Backend, iOS CI)

The dart-define approach is COMPILE-TIME (8 archetype IPAs × 3 fake-dates × 5-12 min/build = 2-5h build time per nightly) AND CLIENT-ONLY (server datetime.now() invoked 60+ times across token_budget Redis, JTI blacklist, snapshot timestamps, JWT expiry, scenario.created_at, CoachInsightRecord.updated_at). Client-only time-travel produces clock-split bugs (documented 6 failure modes in backend audit).

**Verdict** : Phase G is DEFERRED to v2.10. Pre-requisite : a backend `Clock` abstraction phase that introduces `app.core.clock.now()` + `MINT_E2E_FAKE_DATE_UTC` env hook + migrates the 60+ direct datetime calls. That's its own multi-week perimeter.

### C3 — Single Mac mini = single point of failure for D-22 7-day soak (2 experts : iOS CI, Adversarial ; ack'd implicitly by Maestro engineer)

4h Mac mini outage during a 7-day soak voids the soak window. With Phase 97 D-30 demanding « zero LSFin violation on 7-day staging soak » as ship gate, single-host infra is a calendar-week risk.

**Verdict** : Add a second Mac mini (~CHF 550 refurb M1) as warm-spare runner labelled `macos-mint-mini-2`. Configure Maestro Cloud auto-failover on both-mini-down condition (~$99/mo only when triggered). Total cost ≪ one journalist-pitch delay.

### C4 — Tests-of-features-that-don't-exist (5 experts : Maestro, FinTech PM, Backend, Adversarial ; implicit in LSFin)

4 of 8 phases test features that aren't shipped : Phase C (guided-conversation state machine doesn't exist), Phase F (P002 not closed), Phase G (Clock seam absent), Phase H (SessionReport fields missing per SOT.md D-30 ship gate). Building Maestro on top of these = paper-green ; the flow walks past broken features asserting structural visibility, not semantic correctness.

**Verdict** : Close P002 (MintCardActionBar wiring) + P001/P001b-e (narrator gate-correct) + SessionReport fields (confidenceScore, chiffreChoc, alertes, simulationAssumptions, generatedLetters) BEFORE the Golden Flow tests them. Sequence : product features first, tests second.

### C5 — Phase A « Eclairage » + « Score reveal » must surface EARLIER (2 experts : UX, FinTech PM)

WHOOP « aha moment » pattern, MINT IDENTITY Principle #4 « Prise immédiate », and 2024-2026 D0-D7 activation window benchmarks all converge : surface MINT's differentiation in the FIRST 90s, not buried at step 7-of-8.

**Verdict** : Phase H Eclairage moves into end-of-Phase-A (the anonymous 3-turn wedge produces a premier éclairage card with chiffre-choc + confidence band). Phase E score reveal moves into end-of-Phase-A or beginning-of-Phase-B. The « deepening » (cantonal benchmark + multi-day data) becomes a NEW Phase H' at end of trajectory.

### C6 — LSFin / GDPR consent infrastructure unwired (1 expert : LSFin ; ack'd by Backend)

Phase 29 PRIV-01 migration `29_02_consents_granular` shipped 4 purposes (VISION_EXTRACTION, PERSISTENCE_365D, TRANSFER_US_ANTHROPIC, COUPLE_PROJECTION). Grep returns ZERO enforcement sites in `coach_chat.py` / `documents.py`. Phase C + D as proposed would silently bypass these. Plus the Maestro flow MUST use synthetic fixtures (no real Julien certificate through staging Anthropic).

**Verdict** : Two hard blockers for Phase C+D. Wire ConsentService.require(purpose=...) at coach_chat write-path + documents upload path. Add `tools/checks/no_real_pii_in_fixtures.py` lint. Maestro asserts consent receipts exist after Phase C+D.

### C7 — CI tiering must NOT block PR on full composite flow (3 experts : Maestro, iOS CI, FinTech PM)

The proposal's « PR-check golden-day flow 25min per PR » will produce 75-125 min CI/day at 3-5 PRs (today's actual velocity). Engineers batch PRs (anti-pattern, breaks 1-perimeter-1-PR discipline). Modern post-2024 CI = smoke pre-push, single-archetype phase-A-B on PR, full matrix nightly, full 8-archetype × all-phases pre-release only.

**Verdict** : Lefthook pre-commit → pre-push migration. PR-check = single-archetype smoke (Phase A + B only, ~5min). Nightly cron on staging = full 1-archetype × all-phases. Pre-release (manual trigger) = full 8 × 8 matrix.

## Divergent findings (where experts disagreed)

### D1 — Should the « 3-turn anonymous wedge » survive at all ?

- FinTech PM : YES but reframed (the proof-point becomes a personalised WIKI CARD, not a chat narration substitute).
- UX : YES as-is, time-to-value < 90s aligned with industry. Pair with persistent privacy micro-disclaimer.
- Adversarial : critiques that the wedge tests structural reachability, not narrative quality.

**Synthesis** : KEEP the 3-turn wedge in Phase A. ENHANCE it to surface : (a) a chiffre-choc with confidence band (Phase E content moved here), (b) a premier éclairage card (Phase H content moved here), (c) the persistent LSFin + privacy micro-disclaimer (LSFin requirement). The output of Phase A becomes the test's MINT differentiator surface — not just a structural assertion.

### D2 — Maestro Cloud : worth $99/mo now or defer ?

- iOS CI : YES wire as passive hot standby, triggered on both-mini-down.
- Maestro engineer : ONLY when Mac mini < 80% nightly-pass-rate. Defer for now.

**Synthesis** : Wire the **integration** now (GitHub Actions job with `if: failure()` fallback to `mobile-dev-inc/action-maestro-cloud`) but defer the **subscription** until the second-mini-down condition fires. Cost-controlled : pay nothing until the SPOF is real.

### D3 — Auth method for CI test users

- FinTech PM + UX : drop email-password from user-visible UI entirely. Apple Sign-In primary + magic-link secondary. Email-password = dev-flag only for CI.
- LSFin : Art 6 identification not triggered for educational tool, all three legal.

**Synthesis** : Maestro CI uses a deterministic magic-link bypass (signed dev JWT short-circuit on staging Railway). User-visible auth in production = Apple Sign-In primary + magic-link secondary. Email-password retired from sign-up surface (acceptable per LSFin).

## The revised plan — 5 sequenced perimeters

The original W8-W13 monolith is decomposed into 5 independent perimeters, each shippable on its own, each gated by deterministic exit criteria. Sequencing respects « product features before tests of those features ».

### Perimeter R1 — MDM Pillar 0 inversion (scout-first) — STANDALONE

Already drafted in `.planning/MINT-DEBUG-METHOD.md` Pillar 0.a/b/c update committed in PR #573.

**Scope** : doctrine + protocol only. No flow code. The orchestrator (and any future agent) must scout the sim BEFORE reading docs, on every session.

**Exit gate** : Pillar 0.a/b/c documented + first scout pass executed and OBSERVED.md produced on the next session start.

**Already shipping** : in PR #573 (this branch).

### Perimeter R2 — Close P001 / P002 / SessionReport gaps (PRODUCT, not test)

**Scope** :
- P001/P001b-e : narrator gate-correct architectural fix (intent-driven keys H1 landed, H2-H5 hypotheses queued).
- P002 : wire MintCardActionBar on production Aujourd'hui cards (today only ChatAsVerbDemoScreen has it).
- SessionReport completion : confidenceScore, chiffreChoc, alertes, simulationAssumptions, generatedLetters fields per SOT.md D-30 gate.
- ConsentService enforcement on coach_chat write-path + documents upload path (LSFin HARD BLOCKER #1).

**Exit gate** : P002 RESOLVED + 3/5 SessionReport fields shipped + ConsentService gated. P001/b-e moved to v2.10 if narrator architectural fix is not solvable in this perimeter.

**Estimated time** : 4-6 days. NOT a Maestro perimeter ; pure product work.

### Perimeter R3 — Single-archetype tier 1 smoke flow (Maestro infrastructure proper)

**Scope** :
- `golden_day_smoke__julien_swiss.yaml` covering Phase A + B (anonymous wedge → auth gate → home).
- Maestro `--continue-on-failure` mode wired (scout pass support).
- Lefthook `pre-push` (not pre-commit) hook fires this flow.
- Mac mini self-hosted runner labelled `macos-mint-mini` runs it on PR.
- Synthetic-only fixtures lint `tools/checks/no_real_pii_in_fixtures.py`.

**Exit gate** : flow GREEN end-to-end on iPhone 17 Pro sim with R2 product changes deployed. PR-check on every PR ≤ 5min wall.

**Estimated time** : 2-3 days, AFTER R2 ships.

### Perimeter R4 — Surface regression catalogue (existing `regression/` directory)

**Scope** :
- Expand `tools/simulator/flows/regression/` with one flow per shipped surface (per-bug regression locks from W7 cycles).
- Phase 97 D-08 matrix : 3 features × 8 archetypes = 24 regression flows.
- Maestro Cloud passive standby integration (config wired, subscription deferred).
- Second Mac mini warm spare procured + labelled `macos-mint-mini-2`.

**Exit gate** : 24 regression flows GREEN on nightly cron + Mac mini SPOF mitigated.

**Estimated time** : 3-4 days, parallelisable with R3.

### Perimeter R5 — Time-travel & multi-day (DEFERRED to v2.10 behind Clock refactor)

**Scope** :
- `app.core.clock` abstraction + 60+ datetime call-site migration.
- `MINT_E2E_FAKE_DATE_UTC` env hook gated on staging-only flag.
- Phase G J+1 / J+7 / J+30 flows.

**Exit gate** : DEFERRED. Not in v2.9 ship.

**Estimated time** : 2-3 weeks, owned by v2.10 milestone.

## Sequenced calendar (revised)

| Perimeter | Days | Calendar (working) |
|---|---|---|
| R1 — MDM Pillar 0 inversion | 0 (already in flight) | DONE in PR #573 |
| R2 — P001/P002/SessionReport/Consent product | 4-6 | W7+1 .. W7+6 |
| R3 — Tier 1 smoke flow on julien_swiss | 2-3 | W7+7 .. W7+9 |
| R4 — Surface regression catalogue × 8 archetypes | 3-4 (parallel with R3) | W7+7 .. W7+10 |
| D-22 7-day staging soak | 7 (calendar, NOT compressible) | W7+11 .. W7+17 |
| Apple TestFlight review SLA | 1-2 | W7+18 .. W7+19 |
| Ship to external testers | T+0 | W7+19 |
| R5 — Time-travel & Clock refactor | DEFERRED | v2.10 |

**Real total : W7+19 working days = ~4 calendar weeks for v2.9 ship**, not 5-6 days as proposed. The Adversarial critic's « off by ~3× » is the honest math.

## What we drop from the original proposal

- Phase C as a chat-driven onboarding (doctrine contradiction).
- Phase G time-travel in v2.9 (Clock refactor prereq).
- « 8 phases × 8 archetypes » on PR-blocking flow (CI cost prohibitive).
- 5-6 day timeline (3× off).
- Single Mac mini as sole CI substrate (SPOF unacceptable for 7-day soak).
- Email-password as user-visible auth (UX + LSFin signal).

## What we keep from the original proposal

- The sim-first MDM Pillar 0 inversion (full GO — discipline is sound).
- The scout-triage-fix-rewalk loop (locked in MDM update).
- The golden-day-in-the-life CONCEPT (just scoped to 5 perimeters, not 1 mega-cycle).
- The 8-archetype matrix (in R4, not on every PR).
- Maestro Cloud as fallback (integration wired, subscription cost-controlled).
- Mac mini self-hosted runner (with second mini + cloud failover).
- CI-blocking discipline (just scoped to smoke subset, not full composite).

## Open decisions for Julien

1. **Confirm sequencing** : R1 → R2 → (R3 ∥ R4) → soak → review → ship. Or do you want a different order ?
2. **R2 scope** : close P001/b-e fully OR ship H1-only and defer architectural fix to v2.10 ? (My recommendation : ship H1 + defer ; architectural narrator quality is a longer game than v2.9 ship window.)
3. **Apple Sign-In primary + email-password retired** : do you confirm or do you want to keep email-password as user-visible ? (Compliance + UX both say retire it.)
4. **Maestro Cloud subscription** : approve $99/mo budget on trigger ? Or strict « free tier + self-hosted only » constraint ?
5. **Second Mac mini procurement** : ~CHF 550 refurb M1 ? Or accept SPOF risk during the 7-day soak ?

These 5 decisions unblock the perimeter sequencing. Awaiting your GO.

## Counter-arguments and data gaps

**Counter-arguments (steelman against this synthesis) :**

- *« 7/7 CHANGE is suspicious — could be panel echo-chamber »* — possible, but the role-specific scopes (LSFin vs UX vs Backend) make true echo unlikely. The CHANGE verdicts attack DIFFERENT phases of the proposal for DIFFERENT reasons (LSFin attacks C+D consent gates ; UX attacks A+C+E+H sequencing ; Backend attacks G clock-split ; Maestro engineer attacks G feasibility ; etc.). Convergent CHANGE on different root causes is signal, not echo.
- *« The R1-R5 decomposition is itself over-engineered »* — possible. A simpler counter would be : ship Phase A smoke flow on julien_swiss + push P001 H1 / P002 / SessionReport into the same PR. Counter-counter : the panel converged that those product features are blockers for the Maestro flow's tests being meaningful ; bundling them in one PR breaks the « 1-perimeter-1-PR » discipline locked 2026-05-12.
- *« Deferring R5 to v2.10 leaves Phase G untested for the v2.9 ship »* — true. Counter-argument : Phase G tests features (daily nudges, time-travel) that themselves are P2 polish per the D-30 ship gate. The 7-day soak D-22 already exercises J+1..J+7 in real wall-clock time, so the time-travel sim is a verification convenience, not a ship blocker.

**Data gaps (what we don't know yet) :**

- The exact P001 / P001b-e architectural fix path : H2-H5 hypotheses are queued but the headline-clearing fix is not yet identified. R2's estimated 4-6 days assumes H1 is enough ; if it isn't, R2 slips.
- Apple Sign-In + magic-link CI test path : the proposal recommends retiring email-password from user-visible UI ; the dev-flag bypass for CI test users needs design (signed JWT short-circuit on Railway staging).
- Mac mini #2 procurement lead time : « ~CHF 550 refurb M1 » assumes immediate availability ; Swiss refurb supply unverified.
- ConsentService UI design : the panel says « wire ConsentService.require(purpose=...) » but the UX of consent capture (where, when, what copy) isn't designed. R2 needs a UX deliverable not yet in scope.
- The Maestro Cloud auto-failover trigger condition : « both self-hosted minis down » needs a heartbeat / health-check mechanism on GitHub Actions side ; not designed.
