# Roadmap: MINT v2.10 — Le Premier Éclairage (Cleo-grade)

**Defined:** 2026-05-04
**Milestone goal:** Un inconnu ouvre MINT, en moins de 90 secondes + ≤3 messages chat, reçoit UN insight clair sur sa vie financière qui le surprend, et a envie de créer un compte. Chat-first à la Cleo. Mockup éditorial « L'argent, en clair. » comme aboutissement visuel. 4 surfaces, 4 archétypes, walker E2E vert.

**Critère de done (mesurable, all-or-nothing):**
1. Walker `walker_audit_tap_render.sh --no-dry-run --archetype <X>` vert sur 4 archétypes (`julien_swiss`, `lauren_expat_us`, `fatih_cross_border`, `sarah_indep_no_lpp`).
2. Visual diff vs mockup ≤4% pixel zone hero sur landing + anonymous_chat.
3. 0 banned terms LSFin dans 6 ARB (FR/EN/DE/IT/ES/PT) — vérifié par lint blocking pre-commit.
4. TestFlight 2.10.0 build dispo dans App Store Connect avec walker run-id en evidence.
5. PRs en cours #478-#482 mergés ou closés.

**Doctrine:** Cleo-imitation où on peut pas faire mieux ; Swiss lucidity où on peut. **Aucun nouveau feature** hors les 4 ci-dessus. Zéro test côté Julien : Claude valide tout sur simulator iPhone (Mac mini).

**Phase numbering rationale:** v2.8 termine à phase 32 + decimals (30.5..30.20). v2.9 a réservé 40-43 (retired 2026-05-05). v2.10 démarre **70** pour fresh-but-distinct namespace, éviter collision avec phases archivées/déférées, et signaler clairement le milestone séparé.

---

## Milestones

- ✅ **v1.0 MVP** — Phases 1-8 (shipped 2026-03-20)
- ✅ **v2.0 Système Vivant** — Phases 1-6 (shipped 2026-04-07)
- ✅ **v2.1 Stabilisation** — Phase 7 (shipped 2026-04-07)
- ✅ **v2.4 Fondation** — Phases 9-12 (shipped 2026-04-12)
- ✅ **v2.5 Transformation** — Phases 13-18 (shipped 2026-04-13)
- ✅ **v2.6 Le Coach Qui Marche** — Phases 19-26 (shipped 2026-04-13)
- 🟡 **v2.7 Coach Stab + Doc Digestion** — Phases 27-30 (code-complete, awaiting device gate)
- ✅ **v2.8 L'Oracle & La Boucle** — Phases 30.5/30.6/30.7/31/32 + 13 decimals (shipped 2026-04-25, gaps_found)
- 🪦 **v2.9 Coach Visuel Hybride** — Phases 40-43 RETIRED 2026-05-05 (scope drift, deferred post-TestFlight)
- 🟢 **v2.10 Le Premier Éclairage (Cleo-grade)** — Phases 70-75 (active)

<details>
<summary>Previous milestones detail (v1.0 → v2.9) — see MILESTONES.md</summary>

Full phase detail preserved in `.planning/MILESTONES.md` + git history of this file. v2.9 phases 40-43 (marge fiscale + vignettes + scènes + canvas) deferred post-TestFlight ; not abandoned, but not on the path to v2.10 ship.

</details>

---

## v2.10 Phase Summary

| # | Phase | Goal | Requirements | Success Criteria | Estimated effort |
|---|-------|------|--------------|------------------|------------------|
| 70 | Hygiene + PR Triage | Close in-flight PRs, decide Phase 56 fate, restore PROJECT/STATE alignment, install LSFin lint | HYG-01..04, COMP-01, COMP-02 | 5 | 1.5 day |
| 71 | Anonymous Chat Cleo-grade redesign | Kill 6 felt-pills, chat-first surface, single-question coach opener, persistence + clear() validated | ANON-01, ANON-02, ANON-03, ANON-04, ANON-06, ANON-07, ECL-04 | 5 | 2.5 days |
| 72 | Premier Éclairage rendering | Insight hero card + soft account-creation hint + backend prompt wired in anonymous path | ANON-05, ECL-01, ECL-02, ECL-03 | 5 | 2.0 days |
| 73 | Landing v3 éditorial | Mockup port: Fraunces italic hero, Inter sub, MINT wordmark, 14px CTA, secondary login link, cream BG, redirect preserved | LAND-01..07 | 5 | 2.5 days |
| 74 | Walker E2E + golden 4 archétypes | Walker pass on 4 archetypes, visual diff ≤4%, screenshots archived, ≤120s wall-clock | WALK-01..06 | 5 | 2.0 days |
| 75 | TestFlight 2.10.0 cut | IPA upload, App Store Connect verification, run-id evidence attached, milestone close-out | HYG-05 | 5 | 1.0 day |

**Total:** 6 phases, ~11.5 days execution effort (solo-dev, sequential), 31/31 REQs mapped.

---

## Critical Path

```
70 Hygiene + LSFin lint (1.5d)
  │
  ├─ unblocks 71 (lint must catch banned-term regressions during chat copy edits)
  │
  ▼
71 Anonymous Chat Cleo-grade redesign (2.5d)
  │
  ├─ ships felt-pills removal + opener + persistence + clear() wiring behind new UI
  │
  ▼
72 Premier Éclairage rendering (2.0d)
  │
  ├─ ships insight card + ECL-03 prompt path validated end-to-end
  │
  ▼
73 Landing v3 éditorial (2.5d)
  │     (could parallelize with 72 in theory ; kept sequential per anti-scope-creep,
  │      one shippable PR at a time, solo-dev)
  ▼
74 Walker E2E + golden (2.0d)  ◄── LAST GATE
  │
  ├─ all surfaces must be live before walker can validate
  │
  ▼
75 TestFlight 2.10.0 cut (1.0d)
  │
  └─ FINAL — milestone close-out + MILESTONES.md update
```

**Why sequential, not parallel:** solo-dev + Claude builder. Each phase ships ONE shippable artifact (PR-able). Parallelizing 72/73 would risk merge conflicts on screen-level files and dilute the design panel pass per memory `feedback_design_panel_before_push`. Sequential = one diff to review per phase, one panel pass per phase, one walker sanity per phase.

---

## v2.10 Phase Details

### Phase 70: Hygiene + PR Triage + LSFin Lint

**Goal:** Walk into v2.10 build phases with a clean tree: in-flight PRs decided, Phase 56 carry-forward decided, PROJECT/STATE/REQUIREMENTS aligned on v2.10, and LSFin banned-terms lint blocking pre-commit so subsequent phases cannot regress copy.

**Requirements:**
- **HYG-01**: PRs in flight #478, #479, #480, #481, #482 merged or closed before TestFlight cut.
- **HYG-02**: Phase 56 PRs (#470, #472) explicitly merged-into-dev or closed-as-deferred-post-v2.10.
- **HYG-03**: PROJECT.md + STATE.md + REQUIREMENTS.md aligned on v2.10 (no mismatch between declared milestone and yaml-front-matter).
- **HYG-04**: 0 dirty worktrees with unstaged tracked changes at TestFlight cut. All worktrees committed-or-removed.
- **COMP-01**: 0 banned terms across 6 ARB files, enforced by `tools/checks/banned_terms_arb.py` blocking in pre-commit lefthook.
- **COMP-02**: `tools/checks/no_legal_admission_in_public_docs.py` blocking in pre-commit lefthook (public-repo discipline per `feedback_public_repo_discipline`).

**Success criteria (observable behaviors):**
1. `gh pr list --state open` returns no v2.10-relevant PR — all of #478-#482 either merged or closed with explicit decision artifact in `.planning/decisions/`.
2. `git status` in every active worktree returns clean (no unstaged tracked changes).
3. PROJECT.md, STATE.md, REQUIREMENTS.md all read « v2.10 » in their headers / yaml-front-matter — zero orphan « v2.9 » strings outside the explicit retirement note.
4. A developer attempting `git commit` with « garanti » / « optimal » / « meilleur » / « certain » / « assuré » / « sans risque » / « parfait » in any of 6 ARB files is blocked by lefthook with an explicit error message before the commit lands.
5. A developer attempting `git commit` with legal-admission language (« art. X violates Y », « founder personally liable ») in `docs/` or `.planning/` is blocked by lefthook.

**Dependencies:** None (first phase). Must complete before Phase 71 starts because LSFin lint must catch any banned-term regression introduced by chat copy edits in subsequent phases.

**Risks (top 2):**
- **R1 — Phase 56 conflict-rebase:** PRs #470 + #472 may have unresolved merge conflicts with current dev (tool census touches widely-used scaffolding). *Mitigation:* if rebase exceeds 30 min, close-as-deferred and document in `.planning/decisions/2026-05-04-phase-56-deferred.md` rather than block v2.10 ship path.
- **R2 — ARB sweep size:** banned_terms_arb.py may surface dozens of pre-existing violations across 6 ARBs, making lint adoption painful. *Mitigation:* Phase 70 includes a one-time sweep PR that fixes all current violations ; lefthook is enabled only AFTER the sweep is green to avoid blocking unrelated work.

**Plans:** TBD (target ≤4 plans: pr-triage / state-alignment / arb-banned-terms-sweep / lefthook-wiring)

---

### Phase 71: Anonymous Chat Cleo-grade Redesign

**Goal:** Replace the legacy 6-felt-pills entry surface with a chat-first Cleo-grade experience: empty input + one short coach opener question, single question per turn, no menu of phrases. Validate that PR #480 (persistence) and PR #482 (clear-on-register) are wired correctly behind the new UI.

**Requirements:**
- **ANON-01**: User does not see the legacy 6 felt-state pills — pills layer is removed entirely.
- **ANON-02**: User lands on a chat-first surface with empty input field and exactly one coach opener message visible.
- **ANON-03**: Coach opener is one short concrete question in Cleo voice (adult, clear, witty without joking) — no menu of phrases.
- **ANON-04**: Each user reply triggers at most one coach question per turn (no question stacking, no multi-bullet answers).
- **ANON-06**: User killing the app and reopening within 7 days resumes the same conversation (validates PR #480 AnonymousChatPersistence behind new UI).
- **ANON-07**: User registering an account triggers `clear()` of the anonymous transcript (validates PR #482 consent boundary behind new UI).
- **ECL-04**: Coach output contains zero LSFin banned terms — verified via `check_banned_terms` MCP at request time.

**Success criteria (observable user behaviors):**
1. User opening MINT and tapping « Commencer → » lands on `/anonymous/chat` and sees ONE message bubble + empty input — zero pills, zero phrase menu.
2. User reads the opener message and it is exactly ONE short question (≤25 words), in Cleo voice (adult/clear/witty without joking).
3. User typing « j'ai un emploi à 8500 chf brut » and sending receives a single follow-up question — not a multi-bullet response, not a stacked « X et Y et Z ? ».
4. User killing the app and reopening within 7 days sees their previous conversation restored (resumes from where they left off).
5. User completing registration via `/auth/login` sees their anonymous transcript cleared (new authenticated chat starts empty).

**Dependencies:** Phase 70 must ship first (LSFin lint blocking ECL-04 regressions during opener copywriting and per-turn coach response generation).

**Risks (top 2):**
- **R1 — Cleo voice is a vibe, not a spec:** risk of « adult/clear/witty » sliding into « blagueur » or « corporate ». *Mitigation:* design panel BEFORE pushing screens (per memory `feedback_design_panel_before_push`) with explicit voice rubric (3 good examples + 3 bad examples reviewed by panel) and ≤4% visual diff vs mockup as quantitative guardrail in Phase 74.
- **R2 — PR #480 / #482 wired against OLD UI:** new UI may bypass the persistence / clear() wiring. *Mitigation:* Phase 71 includes explicit regression tests (`anonymous_chat_persistence_test.dart` + `anonymous_chat_clear_on_register_test.dart`) executed against the NEW UI before phase close-out.

**Plans:** TBD (target ≤4 plans: pills-removal / opener-copy-and-voice / persistence-regression / clear-on-register-regression)

---

### Phase 72: Premier Éclairage Rendering

**Goal:** Within 2-3 chat turns the coach delivers a single insight as a hero card with one CHF figure + one-line « pourquoi ça compte » + a soft (non-pushy) account-creation hint. Backend prompt path is `anonymous_eclairage_prompt.py` (PR #481) — no other prompt wired in the anonymous path.

**Requirements:**
- **ANON-05**: Within 2-3 turns the coach delivers the Premier Éclairage insight payload (ECL-01).
- **ECL-01**: Coach delivers a single insight as a hero card in chat with one CHF figure + one-line « pourquoi ça compte » + a soft account-creation hint.
- **ECL-02**: Account-creation hint renders as a tappable link (not a modal), copy = « Crée ton compte pour suivre ça » or equivalent that does not push.
- **ECL-03**: Backend prompt for the anonymous tier is `anonymous_eclairage_prompt.py` (already shipped via #481) — no other prompt is used in the anonymous path.

**Success criteria (observable user behaviors):**
1. User completing 2-3 conversational turns receives a visually-distinct insight card (hero treatment, not a regular chat bubble).
2. The insight card shows ONE CHF figure (e.g. « CHF 2'400 / an ») + ONE explanation line — no multi-figure tables, no nested cards.
3. User taps the « Crée ton compte pour suivre ça » link (NOT a modal popup, NOT a full-screen overlay) and lands on `/auth/login` with `?redirect=/anonymous/chat` preserved.
4. Network inspector / backend log shows the prompt envelope used is `anonymous_eclairage_prompt.py` — no fallback to `coach_chat_prompt` or other prompt.
5. User who dismisses the hint can continue the chat without being re-prompted within the same session (soft, not pushy).

**Dependencies:** Phase 71 must ship first (insight rendering target = the new chat surface, not the legacy pills surface). Phase 70 LSFin lint must be green (insight copy goes through banned-terms scan).

**Risks (top 2):**
- **R1 — « 2-3 turns » timing variance:** depends on prompt quality + user input variance. Risk of the insight never firing for laconic users (« ok », « hmm »). *Mitigation:* prompt has a hard turn-counter fallback at turn 4 ; walker validates with one « laconic » archetype path in Phase 74.
- **R2 — Soft hint can become pushy if rendered as modal:** or shown >1× per session. *Mitigation:* explicit tappable-link contract enforced by widget test (`expect(find.byType(Dialog), findsNothing)` in the insight-rendered scenario) + session-scoped dismissal flag.

**Plans:** TBD (target ≤4 plans: insight-card-widget / hint-link-not-modal / prompt-path-assertion / turn-counter-fallback)

---

### Phase 73: Landing v3 Éditorial

**Goal:** Port the locked editorial mockup to `/` (LandingScreen): Fraunces italic hero phrase, Inter sub-title, MINT wordmark top-left, single 14px-radius CTA, secondary login link, cream BG, zero chrome. Visual diff vs mockup ≤4% pixel in hero zone (validated in Phase 74).

**Requirements:**
- **LAND-01**: User sees a single editorial hero phrase « L'argent, en clair. » in Fraunces serif italic.
- **LAND-02**: User reads sub-title « Ta Suisse financière, traduite. » in Inter Regular below the hero phrase.
- **LAND-03**: User sees the MINT wordmark in the top-left corner, sans-serif compact, no exaggerated letterSpacing.
- **LAND-04**: User taps a single primary CTA « Commencer → » styled as `RoundedRectangleBorder(14px)`, black ink, white text.
- **LAND-05**: User can tap a secondary link « Déjà là ? Se connecter » placed under the primary CTA.
- **LAND-06**: User sees a cream background (`MintColors.warmWhite` or `porcelaineHero`) with zero chrome (no card, no shadow, no decorative gradient).
- **LAND-07**: User tapping « Commencer » lands on `/anonymous/chat` ; tapping « Se connecter » lands on `/auth/login` with `?redirect=` preserved when applicable.

**Success criteria (observable user behaviors):**
1. User opens MINT cold and sees: wordmark top-left, hero phrase center, sub-title under hero, primary CTA, secondary link — nothing else, zero chrome.
2. The hero phrase « L'argent, en clair. » renders in Fraunces serif italic (not system font, not Roboto, not Inter) — validated by widget test on TextStyle.fontFamily.
3. User tapping « Commencer → » navigates to `/anonymous/chat` (validates LAND-07 happy path).
4. User tapping « Déjà là ? Se connecter » navigates to `/auth/login` and any `?redirect=` query param is preserved through to post-auth navigation (the 3-site nav audit from PR #479 unblocks this).
5. Visual diff between landing screenshot and locked mockup hero zone is ≤4% pixel difference on iPhone 17 viewport (validated via Phase 74 walker, but spec lives here).

**Dependencies:** Phase 70 (LSFin lint) — sub-title copy goes through banned-terms scan. Independent of Phase 71/72 in code (different screen file), but kept sequential per anti-scope-creep.

**Risks (top 2):**
- **R1 — Fraunces italic rendering on iOS < 17 / Android low-end:** *Mitigation:* explicit fallback chain in TextStyle + golden test on iPhone 17 only (per v2.10 single-target constraint) ; document fallback in `.planning/decisions/`.
- **R2 — Cream BG token ambiguity:** designer's mockup may use `warmWhite`, code may use `porcelaineHero` (or vice versa). *Mitigation:* design panel BEFORE push, single decision artifact pinning the exact token, test asserts the chosen token by reference (not hex literal — see CLAUDE.md NEVER #2 « no hardcoded colors »).

**Plans:** TBD (target ≤4 plans: wordmark-and-hero / sub-and-cta / secondary-link-redirect-preserved / cream-bg-and-zero-chrome)

---

### Phase 74: Walker E2E + Golden 4 Archetypes (LAST GATE before TestFlight)

**Goal:** Validate end-to-end that the 4 surfaces (landing → anonymous_chat → coach opener → ECL insight → register CTA exposed) work on iPhone 17 simulator across 4 archetypes. Visual diff ≤4% in hero zone. Walker exit code 0 on all 4. Run-id archived.

**Requirements:**
- **WALK-01**: `walker_audit_tap_render.sh --no-dry-run --archetype <X>` runs end-to-end on iPhone 17 simulator from cold-launch to ECL-01 insight render.
- **WALK-02**: Walker exit code is `0` for archetypes : `julien_swiss`, `lauren_expat_us`, `fatih_cross_border`, `sarah_indep_no_lpp`.
- **WALK-03**: Walker captures screenshots at four checkpoints — landing, anonymous_chat (after coach opener), ECL insight rendered, register CTA exposed.
- **WALK-04**: Visual diff vs locked landing mockup ≤ 4 % pixel difference in the hero zone on iPhone 17 viewport.
- **WALK-05**: Walker output archived in `.planning/walker/<run-id>/` where run-id = `YYYY-MM-DD-<git-sha-short>`.
- **WALK-06**: Per-archetype walker run completes in ≤ 120 s wall-clock on Mac mini.

**Success criteria (observable behaviors):**
1. Running `bash tools/simulator/walker_audit_tap_render.sh --no-dry-run --archetype julien_swiss` exits 0 and produces 4 screenshots in `.planning/walker/<YYYY-MM-DD>-<sha>/julien_swiss/`.
2. Same command for `lauren_expat_us`, `fatih_cross_border`, `sarah_indep_no_lpp` each exits 0.
3. Each per-archetype run completes in ≤120s wall-clock (measured via `time` wrapper, archived in run-id directory).
4. Visual diff tool comparing `landing.png` from each run against `.planning/mockups/landing-v3-locked.png` reports ≤4% pixel difference in the hero zone (defined as upper 60% of viewport).
5. Run-id directory contains: 4 archetypes × 4 checkpoints = 16 PNG files + 1 `summary.json` with timings + diff scores + git SHA + simulator runtime version.

**Dependencies:** Phases 71, 72, 73 must all be live (walker is the integration gate). Phase 70 LSFin lint must be green (walker fails fast on banned-term regression in coach output via ECL-04 hook).

**Risks (top 2):**
- **R1 — Simulator iPhone 17 device-class availability:** Mac mini's available simulator runtimes may not include iPhone 17. *Mitigation:* Phase 74 includes pre-flight check `xcrun simctl list devices available | grep "iPhone 17"` — if absent, fall back to iPhone 16 with documented diff tolerance widening to 5% (decision artifact required, not silent).
- **R2 — Visual diff oscillation around 4% threshold:** font hinting / sub-pixel rendering varies across sim runtime versions. *Mitigation:* lock simulator runtime version in walker.sh, archive runtime version in run-id summary.json ; `--no-codesign` flag preserved per `feedback_diff_against_existing_tool` (.nosync provenance xattrs).

**Plans:** TBD (target ≤4 plans: walker-script-archetype-flag / 4-archetype-batch-runner / visual-diff-hero-zone / run-id-archival)

---

### Phase 75: TestFlight 2.10.0 Cut + Milestone Close-out

**Goal:** Ship the build to App Store Connect, attach walker run-id evidence, mark milestone v2.10 complete in MILESTONES.md. No new code in this phase — pure release engineering + close-out.

**Requirements:**
- **HYG-05**: TestFlight 2.10.0 build visible in App Store Connect with attached walker run-id evidence.

**Success criteria (observable behaviors):**
1. `flutter build ipa --release` produces `Runner.ipa` for v2.10.0 (`pubspec.yaml` version = `2.10.0+<build>`).
2. `xcrun altool --upload-app` (or Transporter) successfully uploads IPA to App Store Connect.
3. App Store Connect shows v2.10.0 build in « TestFlight » > « iOS Builds » with status « Processed » or « Ready to Test » within 1 hour of upload (escalation buffer 4h before manual contact).
4. The build's external test note references the walker run-id (e.g. « v2.10.0 — walker run 2026-05-XX-abc1234, 4 archetypes green, hero diff 2.1% / 3.4% / 2.8% / 3.9% »).
5. `MILESTONES.md` updated with v2.10 entry: shipped date, phases completed (70-75), key accomplishments, and known carryover (PRs #470/#472 deferred decision, post-TestFlight items).

**Dependencies:** Phase 74 walker green is hard prerequisite. Phases 70-74 all closed.

**Risks (top 2):**
- **R1 — App Store Connect processing stall:** Apple-side queue can stall builds. *Mitigation:* Phase 75 budget includes 4h buffer for processing ; if stuck >12h, escalate via `appstoreconnect.apple.com/contact`.
- **R2 — Last-minute IPA-only regression:** release-mode crash absent in debug. *Mitigation:* Phase 74 walker runs in `--release` mode (not `--debug`), so any release-only crash surfaces in the walker phase, not at IPA upload.

**Plans:** TBD (target ≤3 plans: ipa-build-and-upload / app-store-connect-evidence / milestones-md-close-out)

---

## Coverage Summary

| Category | REQs | Mapped | Phase distribution |
|----------|------|--------|---------------------|
| LAND | 7 | 7 | All Phase 73 |
| ANON | 7 | 7 | ANON-01..04, 06, 07 → Phase 71 ; ANON-05 → Phase 72 |
| ECL | 4 | 4 | ECL-04 → Phase 71 ; ECL-01..03 → Phase 72 |
| WALK | 6 | 6 | All Phase 74 |
| COMP | 2 | 2 | All Phase 70 |
| HYG | 5 | 5 | HYG-01..04 → Phase 70 ; HYG-05 → Phase 75 |
| **Total** | **31** | **31** ✓ | **6 phases** |

**Coverage:** 31/31 mapped (100%). Zero orphans. Zero double-mapping.

**Mapping decisions worth noting:**
- **ANON-05** (« insight delivered within 2-3 turns ») mapped to Phase 72 not 71 because the *delivery* is an ECL concern (the insight payload itself is Phase 72's deliverable). Phase 71 ships the chat surface that *enables* the turn-counting ; Phase 72 ships the actual insight render that satisfies « within 2-3 turns ».
- **ECL-04** (banned terms in coach output) mapped to Phase 71 not 70 because Phase 70 ships the *static ARB* lint while ECL-04 is a *runtime coach output* check via MCP `check_banned_terms` — that check fires during anonymous chat, which is built in Phase 71. Phase 70 lint is necessary-but-not-sufficient for ECL-04.
- **HYG-05** (TestFlight visible) is the only HYG REQ in Phase 75 because it can only be satisfied AFTER walker is green (Phase 74). Splitting HYG into 70 (clean tree, lint, alignment) + 75 (final ship evidence) reflects the temporal dependency.

---

## Anti-Scope-Creep Audit

Cross-checked against PROJECT.md « Out of Scope » list — all explicitly excluded items remain unmapped (correct):

| Excluded item | Status |
|---------------|--------|
| Wiki coach v3 | Not in any phase ✓ |
| Couple mode wiring | Not in any phase ✓ |
| FIX-03 save_fact | Not in any phase ✓ |
| FIX-04 Coach tab routing | Not in any phase ✓ |
| 388 bare-catches sweep | Not in any phase ✓ |
| Coach chat full redesign (post-auth) | Not in any phase ✓ |
| Aujourd'hui / Dossier / Explorer redesign | Not in any phase ✓ |
| Multi-step onboarding wedge (T9) | Not in any phase ✓ |
| Banking / LPP API | Not in any phase ✓ |
| Vignettes / Scènes / Canvas (v2.9 doctrine) | Not in any phase ✓ |
| BYOK testing | Not in any phase ✓ |

---

## Progress Table

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 70. Hygiene + PR Triage | 0/TBD | Not started | - |
| 71. Anonymous Chat redesign | 0/TBD | Not started | - |
| 72. Premier Éclairage rendering | 0/TBD | Not started | - |
| 73. Landing v3 éditorial | 0/TBD | Not started | - |
| 74. Walker E2E + golden | 0/TBD | Not started | - |
| 75. TestFlight 2.10.0 cut | 0/TBD | Not started | - |

---

*Roadmap defined: 2026-05-04*
*Phases: 6 (numbered 70-75)*
*Total estimated effort: ~11.5 days solo-dev sequential*
*Coverage: 31/31 v2.10 requirements mapped ✓*
*Walker phase is LAST (Phase 74). Hygiene phase is FIRST (Phase 70). Constraints respected.*
