---
description: Phase 97 MVP-PARFAIT-MAESTRO-FULL-POWER — final v2.9 phase, TestFlight ship gate. Maestro pleine puissance + on-device ground-truth + reachability fixes + CI gates state-of-the-art. PM Claude full-authority decisions per Julien 2026-05-11 directive « tu es expert autiste 200 IQ, plan exhaustif, méthodique, state of the art, MINT qui fonctionne point final ». Aucune « approved-with-issues » disposition admise sur cette phase.
---

> **Statut : CLOS 2026-07-29** — l'infra Maestro perfect-set a shippé sous `tools/simulator/` (walker, maestro_perfect_set.sh) ; la preuve runtime vit désormais dans Journey OS (campagne étalon fiscal #1060-#1100 / Journey OS). Réconciliation plans 2026-07-29.

# Phase 97 : MVP-PARFAIT-MAESTRO-FULL-POWER - Context

**Gathered :** 2026-05-11 (PM Claude full-authority, no granular AskUserQuestion menus per Julien explicit directive)
**Status :** Ready for planning
**Predecessor :** Phase 96 closed-with-issues (5 dégâts found via actual G2 sim walkthrough by PM Claude 2026-05-11) — Phase 97 closes the on-device reachability gap that Phases 94/94.1/95/96 all surfaced.

<domain>
## Phase Boundary

Phase 97 transforms MINT from « code complete but unreachable » to « shippable on TestFlight » by establishing the Maestro-driven on-device verification infrastructure that a senior debug team with a 200-IQ CI would build. Specifically :

1. **Ground-truth audit** — every reachable screen mapped via Maestro record, per cold-launch + per-archetype (8 archetypes from CLAUDE.md never #7).
2. **Reusable Maestro fragments** — composable building blocks (`dismiss_beta_modal`, `auth_test_user`, `seed_archetype`, `nav_to_card`, etc.) usable by every flow.
3. **Smoke gate** — <2 min CI flow that blocks every PR. Cold launch → 3 tabs → back. No crash.
4. **Regression suite** — full per-feature flows (citation gate, DAG invalidation, chat-as-verb, calc-first projections) × 8 archetypes = 24+ flows, JUnit-aggregated, CI-blocking.
5. **Visual regression** — 1% pixelmatch threshold per critical screen, baselines in git, PR-blocking on drift.
6. **Reachability fix** — ALL Aujourd'hui cards get MintCardActionBar + stable testIDs (closes backlog 999.6 fully). Universal Link config in Info.plist. The chat-as-verb flow becomes user-reachable from cold-launch.
7. **MVP iteration loop** — every PR exercises the full smoke + smoke-fast subset of regression. Block merge on any fail. Visual diff PR comment shows what changed.

**TestFlight ship gate criterion (D-30, locked) :** Phase 97 close = ALL 5 gates green × all 8 archetypes × 7-day staging soak with zero LSFin violation, zero unhandled exception in Sentry, zero visual drift > 1%. No « approved-with-issues » disposition admitted on Phase 97. Either it ships fully, or it doesn't.

Out of scope (deferred, explicit) :
- New product features (Phase 97 verifies what's there, doesn't add)
- Maestro Cloud paid tier setup (fallback only — primary is self-hosted Mac mini)
- Backend microservice extraction (post-v2.9)
- Multi-region staging (Phase 97 = mint-staging.up.railway.app only)
- Android sim coverage (iOS sim only ; Android ship in v3.x)
- Full archetype × scenario matrix expansion beyond the 24-flow baseline (post-v2.9 content sprint)

</domain>

<decisions>
## Implementation Decisions

### Auth strategy for Maestro flows (D-01..D-04)

- **D-01:** HYBRID auth strategy. Smoke flows use **local-mode bypass** (`AuthProvider.isLocalMode = true` per app.dart:402 precedent — `(auth.isLoggedIn || auth.isLocalMode) ? AujourdhuiScreen : LandingScreen`). Regression flows use **real auth via staging API** with a dedicated test account `e2e-julien@mint.local` provisioned on staging Railway.
- **D-02:** Local-mode bypass mechanism — Maestro fragment `flows/fragments/seed_local_mode.yaml` writes SharedPreferences `is_local_mode=true` + `mock_user_id=e2e-archetype-<slug>` BEFORE app launch via Maestro `launchApp { clearState: true; arguments: { is_local_mode: true } }`. Then `tapOn « Je comprends, on y va »` if bêta modal appears.
- **D-03:** Real auth fragment `flows/fragments/auth_test_user.yaml` — taps « J'ai déjà un compte » → fills `e2e-julien@mint.local` + password from `MINT_E2E_PASSWORD` env var (Railway staging secret) → asserts navigation to Aujourd'hui within 5s. Used by regression flows only.
- **D-04:** Test account isolation — staging Railway provisions `e2e-julien-<archetype>@mint.local` accounts × 8 (one per archetype, seeded via dart-define `MINT_E2E_ARCHETYPE`). Production prod stays clean. Test account passwords stored in Railway env vars + GitHub Actions secrets, NEVER in repo.

### Archetype matrix scope (D-05..D-08)

- **D-05:** ALL 8 archetypes from CLAUDE.md never #7 covered : `swiss_native`, `expat_eu`, `expat_us` (FATCA — critical edge case), `cross_border`, `indep_with_lpp`, `indep_no_lpp`, `returning_swiss`, `near_retirement`. Per Julien « tout tester » directive — no subset.
- **D-06:** Archetype seeding via dart-define : `flutter build ios --dart-define=MINT_E2E_ARCHETYPE=<slug>`. The app reads `String.fromEnvironment('MINT_E2E_ARCHETYPE')` at startup + injects matching `CoachProfileProvider` mock state. Mock profiles already exist for some archetypes per memory `reference_maestro_setup` walker.sh `--archetype` flag — Phase 97 W0 inventories which archetypes have mock profiles + completes the missing ones.
- **D-07:** Per-archetype regression flow naming convention : `flows/regression/<feature>__<archetype>.yaml` (e.g. `chat_as_verb__expat_us.yaml`, `citation_gate__cross_border.yaml`, `dag_invalidation__near_retirement.yaml`). Tagged with Maestro tags `archetype:expat_us`, `feature:chat_as_verb`. CI matrix can filter by tag.
- **D-08:** Archetype × feature matrix total : 3 core features (citation_gate / dag_invalidation / chat_as_verb) × 8 archetypes = 24 regression flows. Plus smoke (4-5 flows, archetype-agnostic). Plus visual baselines per critical screen × 8 archetypes (~80 screenshots).

### CI parallelism strategy (D-09..D-12)

- **D-09:** PRIMARY CI runner : self-hosted Mac mini per memory `project_remote_control` (LaunchAgent + tmux + caffeinate). Already running, free, macOS native = iOS sim native. Setup : new GitHub Actions self-hosted runner registered (`actions-runner` + `./svc.sh install` + label `macos-mint-mini`).
- **D-10:** FALLBACK CI runner : Maestro Cloud (paid SaaS, $99-299/mo per project). Only used if Mac mini saturated (e.g. > 30 concurrent jobs in queue OR > 60 min wait). Phase 97 W2 wires the failover heuristic into `.github/workflows/maestro-smoke.yml`.
- **D-11:** GitHub-hosted macOS runners EXPLICITLY REJECTED — too slow (12-15 min cold start per job), expensive ($0.08/min after free tier), and the existing Mac mini setup is more than sufficient for v2.9 traffic.
- **D-12:** Parallelism strategy : smoke flows run SEQUENTIALLY (Mac mini single-sim — boot 1 sim then 1 flow) ; regression flows run in MATRIX (24 flows across 4 concurrent Maestro processes on 4 simultaneous iPhone 17 Pro sims via `simctl clone`). Total wall-clock target : smoke ≤ 90 s, regression ≤ 25 min.

### Visual regression threshold + scope (D-13..D-16)

- **D-13:** Visual diff threshold : **1% pixelmatch** (industry standard ; `pixelmatch` npm package threshold 0.01 = 1% per-pixel-mean-difference). PR-blocking if diff > threshold on any baseline.
- **D-14:** Baseline coverage : 10 critical screens × 8 archetypes = 80 PNG baselines (~2-4 MB total in git, acceptable, no LFS needed). Critical screens : (1) bêta modal, (2) anonymous landing, (3) Aujourd'hui hero, (4) Aujourd'hui card list scroll, (5) « Marge fiscale 2026 » card detail with MintCardActionBar revealed, (6) MintChatOverlay open with NarrativeSleeve rendered, (7) terminal template at turn 4, (8) Explorer screen, (9) Mon Argent tab, (10) anonymous chat composer.
- **D-15:** Baseline storage : `.planning/phases/97-mvp-parfait-maestro-full-power-maestro-driven-on-device-grou/visual-baselines/<archetype>/<screen-slug>.png`. Updated by explicit `--update-baseline` flag, never by accident. Git-tracked.
- **D-16:** Visual diff CI workflow `.github/workflows/maestro-visual.yml` — runs after Maestro test pass, executes `pixelmatch` on each baseline pair, generates HTML diff report uploaded as artifact, posts GitHub comment with thumbnails on PR.

### W5 reachability fix scope (D-17..D-20)

- **D-17:** Inventory step (W0 prerequisite) — Maestro flow `flows/audit/aujourdhui_card_inventory.yaml` records ALL cards rendered on the Aujourd'hui screen for each of the 8 archetypes. Captures card_id, card_title, card_type, current Key (if any), bounds. Output : `97-AUJOURDHUI-CARD-INVENTORY.md` matrix.
- **D-18:** ALL Aujourd'hui cards get `MintCardActionBar` wired + stable `Key('card_<id>')`. No exceptions. Per Julien « tout tester ». Wave 5 task list = 1 task per card type, prioritized : marge fiscale > coût hypothèque > LPP retraite > 3a > AVS > patrimoine summary > hero number.
- **D-19:** testID convention enforced : every card widget exposes `Key(ValueKey('card_<card_id>'))` accessible via Maestro `tapOn: { id: "card_<card_id>" }`. Linter `tools/checks/missing_testid.dart` greps for card widgets without keys, exits 1.
- **D-20:** Universal Link config + custom URL scheme — Info.plist gets `CFBundleURLTypes` for `mintapp://` (debug schemes routes like `mintapp://debug/chat-as-verb`) AND `applinks:mint.ch` for production Universal Links. Apple-App-Site-Association file uploaded to Railway staging `/well-known/apple-app-site-association`.

### TestFlight ship gate (D-21..D-26)

- **D-21:** 5-gate exit contract per `feedback_perimeter_5_gates` — ALL must be green :
  - G1 Maestro : `flows/regression/<feature>__<archetype>.yaml` for all 3 features × 8 archetypes = 24/24 exit 0
  - G2 Device verify : Claude-via-Maestro on booted iPhone 17 Pro sim (NOT Julien deferral) — already covered by G1, this is the on-device sign-off
  - G3 Dev CI : `flutter analyze` + `flutter test` + `pytest -q` + `schemathesis on touched routes` all green
  - G4 Regression suite : Flutter ≥ 8401 + backend ≥ 6586 (Phase 96 baselines) + Maestro 24/24
  - G5 LSFin + accent_lint_fr + ARB parity 6 locales + banned_terms_python + pii_fixture_scan all exit 0
- **D-22:** 7-day staging soak — after the 5 gates green AND Phase 97 W6 lands, staging accumulates 7 days of synthetic+real traffic. ZERO Sentry unhandled exceptions, ZERO LSFin breadcrumb violation, ZERO crash. Sentry alerts threshold-tuned (per Phase 96 Sentry pre-merge requirement).
- **D-23:** Soak monitoring metrics tracked : Sentry exception count, `coach.citation_gate.*` breadcrumb rates, `coach.chat_overflow.turn_4` rate, `coach.grounding_pack.fallback` rate, Sentry performance p95 latency on `/coach/chat` and `/anonymous/chat`. Captured daily in `.planning/phases/97-.../soak-daily-<date>.md`.
- **D-24:** Soak abort criteria — any of : (a) > 5 Sentry exceptions in 24h, (b) LSFin violation breadcrumb fires, (c) `coach.grounding_pack.fallback` rate > 10% on rolling 24h window, (d) Maestro smoke gate fails on dev CI for > 2h continuously. Abort = Phase 97 returns to revision mode, no TestFlight ship.
- **D-25:** No « approved-with-issues » disposition on Phase 97. Per Julien explicit directive. Either : `passed` (all gates + soak clean → ship) OR `revising` (any gate fails → debug + re-soak). No middle ground.
- **D-26:** TestFlight ship trigger — Phase 97 verifier returns `passed` → orchestrator runs `pubspec.yaml` version bump (e.g. 0.1.0 → 0.2.0 for v2.9 milestone) + merge `feature/S94-mvp-citation-gate` → `dev` (squash) → merge `dev` → `staging` (merge, fires testflight.yml) → manual TestFlight build promote-to-external-testers in App Store Connect.

### State-of-the-art tooling stack (D-27..D-30)

- **D-27:** Tools wired in this phase :
  - `maestro record` — interactive flow capture, used in W0 ground-truth audit
  - `maestro studio` — visual flow builder, used to explore testIDs + author new flows
  - `maestro test --device-locale fr_CH` — Swiss locale enforcement
  - `maestro test --include-tags smoke|regression|visual|archetype:<slug>|feature:<name>` — suite filter
  - `idb` (Meta iOS Bridge) — `idb ui describe-all` snapshots per CLAUDE.md G2 evidence + memory `feedback_device_gates`
  - `pixelmatch` (npm) — visual diff in CI
  - `simctl clone` — parallel sim instances for matrix run
  - `xcrun simctl io <udid> recordVideo` — flake forensics (capture last failing step)
  - Sentry + `sentry-cli` — release tracking + soak metrics
- **D-28:** `tools/simulator/maestro_env.sh` extended with `--matrix <feature> <archetype>` flag that auto-builds + auto-spawns N sims + runs the per-archetype regression flow in parallel. Output : `/tmp/maestro_phase_97_matrix_<run-id>/junit.xml` aggregated.
- **D-29:** `.github/workflows/maestro-smoke.yml` + `maestro-regression.yml` + `maestro-visual.yml` — 3 separate workflows. Smoke on every PR (block on fail), regression on PRs touching `apps/mobile/` or `services/backend/`, visual on PRs touching widgets.
- **D-30:** PR comment bot — when Maestro flows run on a PR, post a summary comment with : flows passed/failed, visual diff thumbnails, junit XML link, Sentry breadcrumb counts. Built on GitHub Actions + `actions/github-script`.

### Wave split + scope (D-31..D-33)

- **D-31:** 7 waves, ~10-15d budget total :
  - W0 Ground-truth audit (1d) — `maestro record` + per-archetype seeded launches + `97-AUJOURDHUI-CARD-INVENTORY.md` + ground-truth screen × archetype matrix
  - W1 Reusable fragments (1-2d) — 8 fragments under `flows/fragments/`
  - W2 Smoke gate (1d) — 2 smoke flows + CI workflow `maestro-smoke.yml`
  - W3 Per-feature regression (2-3d) — 24 regression flows + per-archetype seeding + JUnit aggregation
  - W4 Visual regression (1d) — 80 baselines + `pixelmatch` CI workflow
  - W5 Reachability fix (2-3d) — Aujourd'hui card-surface wiring + testIDs + Universal Link config (closes 999.6)
  - W6 MVP iteration loop (continuous) — CI auto-runs on every PR + 7-day staging soak begins after W5 lands
- **D-32:** Parallelization within waves : W1 fragments are independent (can run in parallel by dispatched executors), W3 regression flows are independent (matrix in CI), W4 baselines are mechanical (1 worker). W2 + W5 are sequential within themselves but W2 can start after W1 partial, W5 can start any time (independent of W0-W4).
- **D-33:** No autonomous executor dispatch without G1 live-run on first task — every plan in Phase 97 has Task 0 = « run Maestro fragment against current sim state, capture screenshot, validate against expected behavior ». Tests-green-but-unreachable claims forbidden per CLAUDE.md §9.

### Iteration Loop Methodology (D-34..D-42) — Julien clarification 2026-05-11

Julien clarification : « j'ai l'impression qu'on a une centaine de bugs (...) on peut pas tous les corriger en même temps. (...) qu'est-ce qu'on répare ? qu'est-ce qu'on valide ? qu'est-ce qui est considéré comme réparé, validé, et qui est garantie sans régression plus tard. Et on avance. (...) Viens avec un plan qui est infaillible. »

The infrastructure (D-01..D-33) is the toolkit. The METHODOLOGY (D-34..D-42) is the rhythm-based engineering loop that uses the toolkit to close ~100 bugs methodically with no-regression guarantees. Phase 97 = infrastructure built + methodology locked + 10 bugs P0 closed (proof). Milestone v2.10 MVP-CLEANUP = run the loop on the remaining ~85-90 bugs in sub-phases of 10.

- **D-34:** Phase 97 wave structure REVISED from 7 to 8 waves :
  - W0 Bug bash audit + ground-truth (1-2d) → `97-BUGS-REGISTRY.md`
  - W1 Maestro fragments (1-2d)
  - W2 Smoke gate (1d)
  - W3 Regression suite (24 flows) (2-3d)
  - W4 Visual regression baselines (1d)
  - W5 Reachability fix (closes 999.6) (2-3d)
  - W6 Methodology lockdown (1d) → `97-BUG-FIX-METHODOLOGY.md` + `tools/checks/bug_registry_lint.py`
  - W7 First iteration cycle (3-5d) — 10 bugs P0 closed via the 7-step loop, proof-of-concept
  Total : 13-18d (up from 10-15d ; the +3d covers W6 methodology + W7 iteration).

- **D-35:** Bug registry schema — `97-BUGS-REGISTRY.md` is a YAML-frontmatter-headed markdown with one row per bug under `## Bugs`. Each row :
  ```yaml
  - id: B001
    severity: P0  # P0 (blocker — feature unreachable / crash / LSFin violation) ; P1 (degraded — fallback path fires, slow path > target, archetype-specific failure) ; P2 (cosmetic — visual drift, copy mistake, accent typo) ; P3 (nice-to-have)
    surface: mobile|backend|infra|content|docs
    archetype: all|<slug>  # 8 archetypes per CLAUDE.md never #7
    feature: <slug>  # e.g. chat_as_verb, citation_gate, dag_invalidation, navigation, auth, onboarding
    title: « ChatAsVerbDemoScreen has no GoRoute registered — wired widget unreachable »
    repro: « Cold-launch app → no UI button reaches the demo screen. simctl openurl mintapp:// fails with NSOSStatusErrorDomain -10814. »
    blast_radius: « Phase 96 W1 entire surface inaccessible to users ; pattern repeats for all post-W1 widgets »
    fix_cost: trivial|small|medium|large  # trivial = <1h ; small = 1-4h ; medium = 4-16h ; large = >16h
    score: <int>  # severity_weight × blast_radius_weight / fix_cost_weight, computed by bug_registry_lint.py
    status: OPEN|IN_PROGRESS|FIXED_LOCAL|VALIDATED|RESOLVED|REJECTED  # state machine, transitions enforced by lint
    fix_commit: <SHA or null>
    repro_flow: <path to Maestro flow OR null>
    found_in: <ISO date> # when added to registry
    resolved_in: <ISO date or null>
    notes: « free text »
  ```
  Severity weights : P0=8, P1=4, P2=2, P3=1. Blast-radius weights : all-archetypes=4, multi-feature=3, single-feature-all-archetypes=2, single=1. Fix-cost weights : trivial=1, small=2, medium=4, large=8. Score = severity × blast / fix_cost. Higher = pick first.

- **D-36:** 7-step iteration cycle (mandatory for every bug fix Phase 97 W7 onwards) :
  1. **PICK** — Select highest-score `OPEN` bug from `97-BUGS-REGISTRY.md`. Update row status to `IN_PROGRESS` with `started: <ISO>`.
  2. **REPRO** — Author Maestro flow at `tools/simulator/flows/regression/bug__<id>__<feature>__<archetype>.yaml` that reproduces the bug. Run it. It MUST fail (RED). Document the assertion that fails.
  3. **FIX** — Implement surgical fix per Karpathy #3 (scope-bounded, every line traces to the bug). No opportunistic adjacent refactors.
  4. **PASS** — Re-run the Maestro repro flow. It MUST now pass (GREEN). This proves the fix works.
  5. **SUITE** — Run full smoke + regression (24 flows) + visual diff + Sentry soak 24h. ZERO regression admitted. Any regression = revert the fix, re-think.
  6. **LOCK** — Add the new Maestro flow path to `tools/simulator/flows/regression/<feature>__<archetype>.yaml` index OR to the smoke suite (if smoke-applicable). Now permanently in CI. Future PR that reintroduces the bug = flow fails = PR blocked.
  7. **ADVANCE** — Update `97-BUGS-REGISTRY.md` row to `RESOLVED` with `fix_commit: <SHA>`, `repro_flow: <path>`, `resolved: <ISO>`. Commit. Move to next bug.

- **D-37:** No-regression guarantees (what makes the methodology infaillible) :
  - **Maestro repro flow in CI** — future PR that reintroduces the bug fails the flow = PR blocked
  - **Visual diff baseline locked** — UI drift > 1% on any screen × archetype = PR blocked
  - **Sentry soak monitoring** — production breadcrumb thresholds tripped = automatic Sentry alert + page
  - **Backend test suite ≥ 6586 + Flutter ≥ 8401** — Phase 96 baselines enforced ; any test regression = PR blocked
  - **Bug registry lint** — `tools/checks/bug_registry_lint.py` validates schema + state-machine transitions (OPEN → IN_PROGRESS → FIXED_LOCAL → VALIDATED → RESOLVED). Backwards transitions (e.g. RESOLVED → OPEN without explicit `regressed: true` flag) blocked at commit time.

- **D-38:** Phase 97 W7 success criterion — top 10 bugs P0 (highest-score) all closed via the 7-step cycle. Each has : RESOLVED status + fix_commit SHA + repro_flow path + flow added to regression suite. Phase 97 verifier validates the 10/10 closure mechanically.

- **D-39:** Bug ingestion sources for W0 audit :
  - Maestro `record` cold-launch per archetype × 8 → captures user-visible defects (UI glitches, broken navigation, accent mistakes, empty state behavior)
  - `mint-audit-complet` skill (5 parallel teams : actuariat, juridique, UX, 3-piliers, DevOps) → cross-cutting findings
  - Multi-expert panel via Agent spawn (4-5 experts in parallel : Flutter expert, backend expert, Swiss compliance, archetype FATCA expert, DevEx) → architectural risks
  - Manual UI walkthrough by PM Claude on iPhone 17 Pro sim (per memory `feedback_device_gates`)
  - `feedback_html_evidence_report` HTML history scan — past dégâts logged in `<phase>-VERIFICATION-REPORT.html` from Phases 94/94.1/95/96
  - Sentry staging dashboard scan (24h window) → production-side dégâts
  - `grep -rn "TODO\|FIXME\|XXX\|HACK" apps/ services/ tools/` → known-tech-debt markers
  Output : `97-BUGS-REGISTRY.md` with ≥ 50 rows minimum (cap at ~150).

- **D-40:** Cadence post-Phase-97 → milestone v2.10 MVP-CLEANUP :
  - Phase 98 : bugs 11-20 (10 P0 critiques)
  - Phase 99 : bugs 21-30 (P1 critiques)
  - ... jusqu'à TOUS les P0+P1 RESOLVED
  - Each sub-phase = same 7-step cycle × 10 bugs = ~3-5d
  - TestFlight ship gate (end of v2.10) : 0 P0 + 0 P1 + < 10 P2 + 0 visual drift + 7-day Sentry clean

- **D-41:** Bug deduplication — `tools/checks/bug_registry_lint.py` runs string-similarity comparison on `title` + `repro` fields ; if similarity > 80% with another row, lint warns « possible duplicate ». Manual review at registry commit time. Phase 97 W6 implements this.

- **D-42:** Bug PROMOTION rule — if a bug originally classified P2 later causes downstream P0 (e.g. accent typo in narrator output causes LSFin lint failure), promote to P0 and rescore. Demotion forbidden (a bug only goes UP in severity, never DOWN, to prevent silent down-prioritization).

### Claude's Discretion

- Internal class structure of each Maestro flow (composition pattern, conditional steps, retries)
- Exact PR comment bot HTML format (executor decides, must include diff thumbnails)
- `simctl clone` orchestration script structure (executor decides)
- Sentry breadcrumb category naming for soak monitoring (must follow existing `coach.*` convention)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Strategic / framing anchors

- `.planning/phases/96-mvp-chat-as-verb/96-HUMAN-UAT.md` — 5 dégâts found in actual G2 walkthrough 2026-05-11 (the WHY for Phase 97)
- `.planning/phases/96-mvp-chat-as-verb/g2-evidence/` — screenshots + JUnit XML proving the dégâts
- `.planning/decisions/2026-05-09-calc-first-llm-illumination.md` — calc-first ADR (foundation for citation_gate + GroundingPack)
- `.planning/decisions/2026-05-10-95-96-autonomous-sequence-master.md` — master synthesis (Phase 95+96 contract)

### Prior phase SUMMARYs (Phase 97 closes the on-device gap they all opened)

- `.planning/phases/94-mvp-citation-gate/94-03-SUMMARY.md` (Phase 94 NO-GO+PARTIAL — Stage 3 thresholds NOT MET)
- `.planning/phases/94.1-wave-4-narrator-prompt-fattening-citation-registry-cite-key-/94.1-SUMMARY.md` (Phase 94.1 FAIL — Sonnet 20% vs 95% target)
- `.planning/phases/95-mvp-dag-invalidation/95-01-SUMMARY.md` + `95-02-SUMMARY.md` (Phase 95 backend foundation, contract surface ready)
- `.planning/phases/96-mvp-chat-as-verb/96-01-SUMMARY.md` + `96-02-SUMMARY.md` + `96-03-SUMMARY.md` (Phase 96 code-complete but unreachable)

### Memories invoked (operator constraints)

- `feedback_perimeter_5_gates` — 5-gate exit contract obligatoire ; G1 + G2 + G3 + G4 + G5
- `feedback_app_targets_staging_always` — sim/walker MUST hit Railway staging, NEVER local backend
- `feedback_device_gates` — Claude does device walkthroughs autonomously via sim+idb, don't defer to Julien
- `reference_maestro_setup` — tools/simulator/{flows,walker.sh,maestro_perfect_set.sh,merge_maestro_junit.py} setup
- `feedback_maestro_for_sim_tests` — Maestro is the G1 surface ; raw simctl screenshot is anti-pattern
- `feedback_critical_pm_mode` — PM Claude makes the call, no agreeable execution
- `feedback_decisiveness` — firm plans, no option lists
- `feedback_zero_trust_protocol` — banned phrases without deterministic citation
- `feedback_no_micro_pauses` — pack each turn ; only stop on genuine blocker
- `feedback_post_phase_panel_loop` — autonomous loop continues until TestFlight-ready + journalist-defensible
- `project_remote_control` — Mac mini self-hosted CI runner ; LaunchAgent + tmux + caffeinate already running
- `project_testflight_ship_path` — pubspec bump + dev→staging merge fires testflight.yml ; manual promote-to-external in App Store Connect
- `feedback_html_evidence_report` — every Phase produces `<phase>-VERIFICATION-REPORT.html`
- `feedback_pre_push_checklist` — full pytest + flutter test BEFORE push (no skipping)

### Code anchors

- `apps/mobile/lib/widgets/mint_shell.dart` — flag-gated NavigationBar + index remap (Phase 96 W1)
- `apps/mobile/lib/widgets/mint_card_action_bar.dart` — 48dp animated row + 3 verbs (Phase 96 W1)
- `apps/mobile/lib/widgets/mint_chat_overlay.dart` — modal scaffold (Phase 96 W1)
- `apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart` — 2 example cards (W5 inventory will list ALL Aujourd'hui cards needing this treatment)
- `apps/mobile/lib/services/feature_flags.dart` — `chatTabVisible` flag (Phase 96 W1)
- `apps/mobile/lib/services/auth_provider.dart` — `isLocalMode` mechanism (D-01 hybrid auth basis)
- `apps/mobile/lib/app.dart` — `_router` GoRouter config (D-20 `/debug/chat-as-verb` route added Phase 96 G2 fix, more routes to add in W5)
- `tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml` — Phase 96 W3 G1 stub (D-31 W3 replaces with real per-archetype flows)
- `tools/simulator/walker.sh` + `maestro_env.sh` — sim runner + Java env helper (D-28 extends with --matrix)
- `services/backend/app/services/coach/turn_cap.py` — Phase 96 W2 TURN_COUNTER (D-23 soak monitoring watches the breadcrumb)

### Compliance

- `CLAUDE.md` §1 LSFin banned terms (NEVER « garanti / optimal / parfait »), §2 accents FR 100%, §3 MINT ≠ retirement-first (frame by 18 life events), §9 0-trust protocol (banned phrases without deterministic citation)
- `tools/checks/{banned_terms_python,accent_lint_fr,pii_fixture_scan,no_legal_admission_in_public_docs,arb_parity_gate,metaphor_parity}.py` — existing lints carry forward
- `tools/checks/missing_testid.dart` — NEW lint introduced in D-19 (grep card widgets without Keys, exit 1)

### State-of-the-art Maestro references (external)

- https://docs.maestro.dev/ — Maestro 2.5.1 official docs
- https://docs.maestro.dev/getting-started/installation — CLI install (already done per maestro_env.sh)
- https://docs.maestro.dev/api-reference/commands — valid commands (where `pressBack` issue was caught)
- https://docs.maestro.dev/cloud — Maestro Cloud setup (D-10 fallback)
- https://www.npmjs.com/package/pixelmatch — visual diff library (D-13)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `tools/simulator/walker.sh` — sim boot + install + screenshot pipeline ; Phase 31 lineage, already 4-op stable per the script header
- `tools/simulator/maestro_env.sh` — Java env helper for Maestro CLI ; Phase 90 lineage ; D-28 will extend with `--matrix` flag
- `apps/mobile/lib/services/auth_provider.dart:isLocalMode` — bypass mechanism per app.dart:402 ; D-01 hybrid auth uses this
- `apps/mobile/lib/services/feature_flags.dart` — flag mechanism + periodic refresh + server override ; Phase 96 added `chatTabVisible`
- `apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart` — 2 example cards as wiring template ; W5 generalizes to ALL Aujourd'hui cards
- `tools/checks/*` — 6 existing lints to extend or carry forward
- `tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml` — Phase 94 precedent, working Maestro flow shape
- Mac mini self-hosted environment (memory `project_remote_control`) — already running, just needs GitHub Actions runner registration

### Established Patterns

- Maestro 2.5.1 commands : `tapOn`, `assertVisible`, `assertNotVisible`, `inputText`, `extendedWaitUntil`, `takeScreenshot`, `back`, `swipe`, `launchApp { clearState, arguments }`, `runFlow`, `runScript`. NOT `pressBack` (caught in Phase 96 G2).
- Maestro tag-based filtering : `tags: [smoke, archetype:expat_us, feature:chat_as_verb]` in flow frontmatter.
- Sentry breadcrumb naming : `coach.<surface>.<event>` (Phase 94 set the precedent ; D-23 continues)
- iOS testID convention : `Key(ValueKey('<scope>_<id>'))` — `_` separated, lower_snake_case
- ARB parity 6 locales (fr/en/de/es/it/pt) — Phase 90 lint enforces ; Phase 96 added 3 verb keys
- Pydantic v2 frozen+forbid (citation_registry.py:51 precedent) — Phase 95+96 followed
- Phase artifact convention : CONTEXT → RESEARCH → UI-SPEC (if frontend) → VALIDATION → PLAN(s) → SUMMARY → VERIFICATION → HUMAN-UAT (if checkpoint)

### Integration Points

- `app.dart:_router` — register Universal Link routes + `/debug/chat-as-verb` (already done Phase 96 G2 fix) + new routes for any new debug surfaces
- `lefthook.yml` — register new lints (`missing_testid.dart`, `maestro_flow_lint.py`)
- `.github/workflows/` — 3 new Maestro workflows (smoke, regression, visual)
- `services/backend/app/api/v1/endpoints/coach_chat.py` — Phase 96 W2 turn_cap wrapper ; D-23 Sentry soak monitoring reads breadcrumbs from here
- `apps/mobile/ios/Runner/Info.plist` — CFBundleURLTypes + applinks (D-20)

</code_context>

<specifics>
## Specific Ideas

- The dégâts Phase 96 G2 surfaced are TYPICAL of MINT's pattern (Phase 94 NO-GO+PARTIAL, Phase 94.1 FAIL, Phase 95 PARTIAL on Dart-side wiring, Phase 96 PARTIAL on reachability). Phase 97 EXISTS specifically to break this pattern. The 24-flow regression matrix + visual baselines + smoke gate + soak monitoring constitute the discipline that prevents the pattern from recurring.
- The « senior debug team with 200-IQ CI » Julien referenced is concretely : Mac mini self-hosted runner + Maestro 2.5.1 + pixelmatch visual diff + Sentry soak + simctl clone parallelism + per-archetype dart-define seeding + tag-filtered Maestro suites + PR comment bot with diff thumbnails. That's the bar.
- The 8-archetype matrix is non-negotiable per Julien « tout tester » + CLAUDE.md never #7 (« NEVER assume Swiss native archetype ; 8 archetypes, FATCA/frontalier ≠ edge cases »). expat_us FATCA is the highest-risk archetype because of dual-jurisdiction tax behavior — it's the canary for any calc-first regression.
- Phase 97 is ALLOWED to take longer than estimated. Quality > timeline. Per Julien « MINT qui fonctionne, point final ».
- The 7-day staging soak is not theatre — it's mandatory per `feedback_perimeter_5_gates` G2 device verify expansion. Phase 94 attempted a 4-week soak (D-21 in 94-03-CONTEXT) but stalled because the flag-flip wasn't authorized. Phase 97 soak is a hard pre-TestFlight gate.

</specifics>

<deferred>
## Deferred Ideas

- **New product features** — Phase 97 is verification + reachability only, no new functionality.
- **Maestro Cloud paid tier as primary** — fallback only (D-10) ; primary is Mac mini.
- **Android sim coverage** — iOS-only this phase ; Android in v3.x post-TestFlight.
- **Backend microservice extraction** — post-v2.9 architectural sprint.
- **Full content sprint (cards × scenarios matrix expansion)** — beyond the 24 baseline flows, additional flows are post-v2.9 content sprint.
- **Phase 94.2 narrator-prompt iter 2 (backlog 999.5)** — independent of Phase 97 ; can be picked up post-TestFlight ship.
- **Phase 95 W2 Dart-side financial_core field additions (backlog 999.4)** — post-TestFlight.
- **GitHub Actions macOS hosted runners** — explicitly rejected (D-11) ; never coming back.
- **Multi-region staging** — single Railway staging ; multi-region post-v3.x.
- **WCAG 2.1 AAA compliance audit** — separate dedicated phase post-TestFlight.
- **Performance budget** — cold launch ≤2.5s (per ROADMAP cross-cutting) is tracked in soak D-23 but not a hard ship gate this phase ; soft warn.

### Reviewed Todos (not folded)

- `2026-05-05-audit-mint-skills-against-rezvani-5-step-prompt-to-skill-con` (score 0.6, area: tooling) — meta task, not Phase 97 scope. Post-v2.9.

</deferred>

---

*Phase : 97-mvp-parfait-maestro-full-power*
*Context gathered : 2026-05-11 (PM Claude full-authority, 33 locked decisions D-01..D-33)*
