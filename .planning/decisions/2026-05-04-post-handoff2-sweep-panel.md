# Decision — Post-Handoff-2-Sweep (PR #464) — Next Chunk

**Date** : 2026-05-04
**Author** : Claude (Product Leader, autonomous post-phase panel per `feedback_post_phase_panel_loop.md`)
**Trigger** : PR #463 merged (Handoff 2 palette tokens + B4 beta disclosure). PR #464 (sweep remaining hero surfaces) about to land. Need next chunk decided so the loop doesn't stall.
**Status** : Decided.

---

## Panel — 5 experts, evidence-grounded

### 1. UX (Cleo / Apple HIG / Linear voice)

**Analysis** : Phase 54-02 closed the « tappable chip on every coach opener » gap (PR #450, #452 — 7/8 ProactiveTrigger types now surface chips, PrecomputedInsight cache consume-once). PR #461/462 ported Handoff 2 chat top bar + 5 atomic widgets + 2 Niveau 2 scenes (RenteCapital, RachatLpp). The remaining UX gap blocking a TestFlight-ready experience is **Niveau 3 canvas projection** : `~/Downloads/handoff 2/00-README.md:88-100` lists this as Étape 5 of 7 in the chat-vivant build order, and it is the « show, don't tell » heart of Handoff 2's vision. Without canvas, a tester's first « rente vs capital » or « rachat LPP » question still terminates in inline cards — defensible, but not the differentiated experience Julien promised journalists.

**Recommendation** : ship `MintCanvasProjection` shell + 1 chapter (`MintCanvasChapitre`) + `MintSensibiliteWidget`, wired through `ChatProjectionService` for the existing `rente_vs_capital` scene. Acceptance : tap « Creuser » in `MintSceneRenteCapital` → opens canvas → scrollable chapters → return contract emits récap text bubble per `06-test-plan.md:74-87`.

### 2. Brand / editorial (Frieze / Aesop voice)

**Analysis** : PR #463 nailed warm tokens on auth-gate + beta disclosure, but `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart` is still **20+ token-drift hits** (lines 275, 324, 344, 372, 374, 404-405, 431, 527, 529, 585, 695-696, 770, 774, 802 — all `MintColors.craie`/`primary`/`lightBorder` cool-grey, never the new warm `porcelaineHero`/`mintForest`/`borderSubtle`). `landing_screen.dart:166-169` still uses `MintColors.textPrimary` for the FilledButton CTA instead of the warm `inkPrimary`. PR #464 covers this scope. Beyond #464, the **next editorial gap** is Fraunces italic-em discipline : `00-README.md:111-114` mandates « Fraunces = signature éditoriale, jamais en body long, max 2 écrans par parcours ». No audit lint exists today — a journalist comparing the v1 Handoff 2 mockup to the shipped app will catch any over-italicization.

**Recommendation** : after #464, ship a **Fraunces-usage audit lint** + sweep : `tools/checks/fraunces_discipline.py` walks `lib/screens/` + `lib/widgets/`, flags any screen with > 2 `editorialDisplay`/`editorialLarge`/`editorialBody` instances or any `editorialBody` over 80 chars (« jamais en body long »).

### 3. Compliance / Swiss legal (LSFin / FINMA / FATCA)

**Analysis** : Spot-grep on `app_localizations_fr.dart` surfaces **1 banned-term hit at line 20950** : « L'AVS [...] **garantit** un revenu de base à la retraite » — direct LSFin Rule #1 violation (TOP/BOTTOM critique #1 in `CLAUDE.md`). MCP `check_banned_terms` would catch this; nobody has run it on the full ARB. FATCA path exists (`coach_profile.dart:1784`, `response_card_service.dart:583`, `fri_computation_service.dart:216`, plus archetype enum `expatUs`) but is **detected, not gated** — there is no audit confirming that the `expatUs` archetype receives appropriate warnings on every 3a/LPP surface. `app_localizations_fr.dart:14708-14711` carries the FATCA conformance challenge string but its actual surfacing on the 3a contribution surface is not asserted by a test.

**Recommendation** : ship a **compliance gate PR** : (a) fix line 20950 (« garantit » → « vise à offrir » or similar), (b) add `tools/checks/banned_terms_arb.py` lint wired into `ci.yml` (blocking, not advisory), (c) add a single `expat_us_3a_warning_test.dart` widget test asserting the `expatUs` archetype sees the FATCA warning string on the 3a contribution screen. Single PR, < 1 day.

### 4. Engineering / shipping discipline (DHH / Patrick Debois)

**Analysis** : Phase 54-01 PR-2 (#453) shipped the walker real-execution path + nightly CI + triage emitter — **but the actual run has never happened** (`.planning/phases/54-testflight-gate-closure/triage/` is empty, no `AUDIT_TAP_RENDER_RESULTS.md` anywhere on disk). Per the verification HTML at line 133, this is « scheduled separately (one-shot once env confirmed wired) ». Plan 54-03 (line 134) is **literally blocked on this** : « triage every FAIL → focused per-surface fix PRs → walker re-runs to PASS → bump pubspec to 2.9.0+1 → push staging → testflight.yml triggers ». No walker run = no Plan 54-03 = no GATE-01 sign = no TestFlight ship. Backend P95/SLO infra exists (`services/backend/app/services/slo_monitor.py`, Sentry init in `main.py:25`, `coach_chat.py:2576` SLO metrics) — that's not the bottleneck.

**Recommendation** : **execute the walker** (one-shot `walker_audit_tap_render.sh --no-dry-run --archetype swiss_native --all` on iPhone 17 Pro sim against staging Railway), publish `AUDIT_TAP_RENDER_RESULTS.md` + per-FAIL triage tickets, then open one focused per-surface fix PR per non-trivial FAIL. This is the literal critical path to TestFlight per the verification HTML's « What's next » §.

### 5. Journalist-defense (TechCrunch hostile review)

**Analysis** : The single most embarrassing risk today is **a Swiss financial coach app whose own copy says « l'AVS garantit un revenu de base »** while its CLAUDE.md TOP rule #1 forbids exactly that word. A reporter who runs `grep -rn "garantit" apps/mobile/lib/l10n/` finds the contradiction in 10 seconds. Second most embarrassing : **MINT-IA/MINT public repo** (`feedback_public_repo_discipline.md`) means anyone can browse the discrepancy. The walker has 48 catalogued surfaces but zero recorded executions — a reporter asking « how do you know all 48 screens render? » would get « we will run it tonight ». That's not a journalist-defensible answer; that's a JIRA ticket.

**Recommendation** : land the compliance gate PR (Expert 3) **before** the canvas Niveau 3 work (Expert 1), because « we ship a chat that *shows*, not tells » is undermined when one of the things the chat tells is an LSFin banned term. Then run the walker (Expert 4) so « we have evidence every screen renders » becomes a true statement, not a promise.

---

## Synthesis

Weighted by ship-criticality + journalist-defensibility + smallest credible chunk :

- Expert 5 + 3 collapse : compliance gate is non-negotiable + ~1 day.
- Expert 4 (walker run) is the critical path to GATE-01 — must happen, but is largely an execution chunk, not a planning chunk.
- Expert 1 (canvas N3) is the highest-value UX chunk but **not** a TestFlight blocker; deferring it 1 PR is correct.
- Expert 2 (Fraunces discipline lint) folds into the compliance gate PR : same shape (audit lint + ARB sweep), same CI wiring.

**Sequence** :

1. **PR #464** (already scoped) — Handoff 2 sweep finishes (anonymous_chat scaffold/input/bubbles/send icon + LandingScreen FilledButton).
2. **PR #465** (this decision) — *Compliance Gate + Editorial Discipline*. Single PR.
3. **Walker execution** (no PR — operational chunk on top of merged #453). Publishes `AUDIT_TAP_RENDER_RESULTS.md` + triage tickets. If 0 FAILs → Plan 54-03 collapses to just the pubspec bump. If N FAILs → spawn N focused per-surface fix PRs.
4. **PR #466+** — Niveau 3 canvas + 1 chapter + sensibilité widget (Expert 1's recommendation, post-TestFlight-gate).

---

## PR #465 — concrete scope

**Title** : `chore(compliance,editorial): banned-terms ARB lint + FATCA archetype test + Fraunces-usage discipline`

**Scope (5 bullets)** :

1. **Fix `app_localizations_fr.dart:20950`** : replace « L'AVS [...] **garantit** un revenu de base » with « L'AVS [...] **vise à offrir** un revenu de base ». Apply equivalent fix in EN/DE/ES/IT/PT ARBs. Run `flutter gen-l10n`. Re-grep to confirm 0 hits in any locale.
2. **New lint** `tools/checks/banned_terms_arb.py` : walks all 6 ARB files + raises on any banned-term hit (full list per `docs/AGENTS/swiss-brain.md §1`). Wire into `.github/workflows/ci.yml` as a **blocking** step (not advisory). Lint covers strings AND placeholder defaults.
3. **New widget test** `apps/mobile/test/screens/expat_us_fatca_warning_test.dart` : asserts that when `CoachProfileProvider.archetype == FinancialArchetype.expatUs`, the 3a contribution screen renders `AppLocalizations.challengeFiscalite07Description` (the FATCA warning at `app_localizations_fr.dart:14708`).
4. **New lint** `tools/checks/fraunces_discipline.py` : walks `apps/mobile/lib/screens/` + `apps/mobile/lib/widgets/`, flags screens that instantiate > 2 of `MintTextStyles.editorialDisplay`/`editorialLarge`/`editorialBody`, OR any `editorialBody` Text content > 80 chars. Advisory in CI for first run, blocking in PR #466.
5. **Update HTML evidence** : `.planning/phases/54-testflight-gate-closure/54-VERIFICATION-REPORT.html` gets a new « Compliance + editorial gate » section with before/after grep counts, lint exit codes, test verdict, CI rollup screenshot.

**Acceptance criteria** :

- `grep -rn "garantit\|optimal\|sans risque" apps/mobile/lib/l10n/*.arb` returns 0 lines (all 6 locales).
- `python3 tools/checks/banned_terms_arb.py` exits 0.
- `python3 tools/checks/fraunces_discipline.py` exits 0 OR exits 1 with documented allow-list.
- `flutter test test/screens/expat_us_fatca_warning_test.dart` PASS.
- `flutter analyze` 0 new warnings.
- `flutter test` full suite green (no regression).
- CI ALL green on PR #465 (no advisory-fail).

**Estimated chunks** : **1 PR**, < 1 day. The 4 sub-tasks are independent and small; no architecture migration needed.

**Operational follow-ups (not part of this PR)** :

- A. Trigger walker `--no-dry-run --archetype swiss_native --all` against staging on Mac mini sim (per `feedback_app_targets_staging_always.md`). Publish `AUDIT_TAP_RENDER_RESULTS.md`. **Same day as PR #465 merges.**
- B. Per-FAIL triage PRs as needed.
- C. Plan 54-03 close-out : pubspec 2.9.0+1 → staging push → testflight.yml → GATE-01.
- D. Then unblock Niveau 3 canvas (Expert 1's PR #466).

---

## Why not the alternatives

- **Why not Niveau 3 canvas first?** It's the highest-value UX chunk per Expert 1, but it does not unblock TestFlight. Phase 54 is literally named « TestFlight Gate Closure ». Shipping more chat-vivant before closing the gate violates `feedback_post_phase_panel_loop.md` (« loop only stops when MINT is TestFlight-ready »).
- **Why not run the walker first?** Because Expert 5's hostile-journalist scenario is a real risk *now* and the fix is < 1 day. The walker run is operational on top of the same staging build that PR #465 will produce, so combining gives one clean shippable build.
- **Why not bigger compliance work (full LSFin sweep)?** Scope creep. The 1 known hit is the only known hit. Shipping the lint catches future hits. Adversarial fuzzing of LSFin-edge wording is its own future phase, not a TestFlight blocker.

---

## Decision log

- **Decided** : PR #465 = compliance + editorial gate, scoped above. Then walker run (operational). Then Plan 54-03 close-out. Then Niveau 3 canvas (PR #466).
- **Decider** : Claude (autonomous Product Leader per `project_mint_product_mission.md`).
- **No re-litigation** : per `feedback_expert_panel_pattern.md`, this decision is durable. Future panels start from « PR #465 merged + walker run + Plan 54-03 closed ».

---

## Counter-arguments and data gaps

Honest list of what this decision might be wrong about, in priority order :

1. **Single-grep evidence on the « garantit » hit is shallow** — Expert 3's scan was spot-grep on `app_localizations_fr.dart`. A full audit could surface more banned-term hits (« optimal », « meilleur », « sans risque », « parfait », « assuré ») that the lint would also catch but that should be triaged BEFORE the lint becomes blocking, not after. Risk : if N additional hits exist, the lint blocks every dev PR until the long tail is fixed.
2. **Fraunces-usage discipline lint has zero ground-truth baseline** — the lint shipping advisory-then-blocking assumes the current codebase has ≤ 2 `editorialDisplay` instances per screen. No one has counted. If 3+ hits exist on shipped screens, the lint either becomes immediate FAIL on every PR or needs a documented allow-list (option chosen above) — but the allow-list is itself a foot-gun that lets violations crystallize.
3. **Walker execution gap is operational, not architectural** — the panel assumes one walker run will produce a clean `AUDIT_TAP_RENDER_RESULTS.md`. If the run surfaces N>5 FAILs across surfaces (likely for an app of this size pre-launch), Plan 54-03 doesn't « collapse to the pubspec bump » — it explodes into a multi-PR triage wave that pushes TestFlight by another week.
4. **FATCA test asserts presence, not correctness** — the proposed widget test only checks that the FATCA warning string renders for `expatUs`. It does not verify the WORDING is compliant, that the warning fires on EVERY 3a/LPP surface (only one), or that it surfaces at the right moment. Compliance theatre risk.
5. **Niveau 3 canvas deferral is a journalist-defensibility tradeoff, not a free choice** — Julien promised a « show, don't tell » experience. Shipping TestFlight without the canvas means the first beta testers see chat + cards, not the chat-vivant differentiator. If reviewer feedback loops are 1-2 weeks, that's 1-2 weeks of feedback on a v1 that's not the real product. The decision treats this as « post-TestFlight is fine » without quantifying the feedback-loop cost.
6. **« Decider : Claude » is a public-repo discipline foot-gun** — `feedback_public_repo_discipline.md` says « drop autonomous Product Leader from PR bodies ». This artifact is committed in a public repo as a Claude-authored decision. A reviewer browsing the repo sees a fully-autonomous AI declaring product priorities — defensible to Julien internally, riskier in public optics.

Data gaps :

- No measurement of the time cost between « walker run starts » and « TestFlight build available ». 1 hour ? 1 day ? 1 week ? Plan 54-03 cannot be sized without it.
- No verification that the staging Railway backend currently passes the walker's surfaces (cold-start, anon chat, scan flow, profile bootstrap). If staging is partially broken, the walker FAILs are infrastructure noise, not surface bugs.
- No revisit cadence : when does this decision get re-evaluated ? After PR #465 merges ? After walker run ? Open-ended « durable » without a checkpoint risks the loop stalling on a decision that was right at t=0 but stale at t+2 weeks.
