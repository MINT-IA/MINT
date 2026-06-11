# Phase mint-illogism-fixes — PHASE DEVICE GATE

> Phase-close device walkthroughs that the per-plan executors deferred
> (build constraint: parallel `.nosync` worktree executors cannot run a sim
> build without breaking macOS provenance/codesign). This gate runs them on
> the main working tree against a fresh build covering HEAD's `lib/` state.
> 0-TRUST: every verdict cites an exit code, a screenshot path, or a
> file:line. **No production code was changed.** Two items surfaced
> on-device regressions that tests did not catch — recorded precisely below,
> NOT patched (orchestrator decides).

## Build provenance

| Field | Value |
|-------|-------|
| Branch | `qa/runtime-navigation-spine-20260602` (main working tree, clean) |
| HEAD commit | `0d54fcc53377088aaa1a680adc7021e93bcae3e4` |
| Last `apps/mobile/lib/` commit (built coverage target) | `894940831b904a2547f72cc202cd38f893c8efa1` — `fix(mint-illogism-fixes-17): ghost-conjoint gate reads civil status` @ `2026-06-11T23:26:29+02:00` (touched `coach_profile.dart`) |
| Fresh build invocation | `flutter build ios --simulator --no-codesign --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 --dart-define=MINT_E2E_ARCHETYPE=<slug> --dart-define=MINT_WALKTHROUGH_PHASE=51 --dart-define=SENTRY_DSN=…` (exact `walker.sh` archetype-walkthrough flags) |
| Build artifact provenance | `Runner.app/Frameworks/App.framework/App` rebuilt per seed; swiss_native App.framework `2026-06-12T00:05:59` — **AFTER** HEAD's lib/ commit (23:26:29), so the W5 gap-closure to `coach_profile.dart` IS covered. The stale Jun-9 18:53 build flagged invalid in `deferred-items.md` was NOT reused. |
| Backend target | Railway staging (`https://mint-staging.up.railway.app/api/v1`) — never local |
| Seeds built | `swiss_native` (julien_swiss), `independent_no_lpp` (Nadia), `expat_us` (julien_expat_us). No married seed exists in the registry (all seeds hardcode `q_household_type: 'single'`); the married path was driven via the live `/onb` état-civil scene instead. |

## Simulator identity

| Field | Value |
|-------|-------|
| Device | iPhone 17 Pro — `B03E429D-0422-4357-B754-536637D979F9` (walker default `MINT_WALKER_DEVICE`) |
| OS | iOS 26.2 |
| Pre-sweep hygiene | `simctl shutdown all` + `simctl erase` before boot (sim-crash mitigation) |
| Tooling | Maestro `/Users/julienbattaglia/.maestro/bin/maestro`; idb (AX-tree dumps); `simctl openurl` (S003 host-deeplink path, bypasses the iOS-26 "Open in MINT?" first-use dialog) |
| Skipped (per instructions) | Safari-invoking deeplink flows S003/S004 |

## Results — items 1-6

| # | Item | Flow / command | Exit / observation | Evidence | Verdict |
|---|------|----------------|--------------------|----------|---------|
| 1 | ILLOG-02 RvC AX-tree non-empty | `maestro test bug__ILLOG02__rvc_ax_tree_empty.yaml` (warm app) | **EXIT 0** — title + "Estimer pour moi" + "Ton avoir LPP actuel (CHF)" all assertVisible PASS; idb AX shows **29 elements** (was 1, RED) | `item1-illog02-maestro-exit0.log`, `item1-rvc-ax-tree-populated.png`, `item1-rvc-axtree.json` | **PASS** |
| 1 | ILLOG-01 RvC no fiction defaults | `maestro test bug__ILLOG01__rvc_fiction_defaults.yaml` (warm app) | **EXIT 0** — assertNotVisible "350000" PASS, assertNotVisible "100000" PASS; LPP field carries "Valeur estimée" tag, not fiction | `item1-illog01-maestro-exit0.log` | **PASS** |
| 2 | W2 archetype onboarding — 3 new scenes appear + persist | Drive `/onb` (statut emploi → état civil → lacunes AVS), idb screenshots | All 3 scenes present in order ("Quelle est ta situation professionnelle?", "Quelle est ta situation familiale?", "As-tu passé des années hors de Suisse?"). DossierStrip persists answers cumulatively (Intention → Date naissance → Canton → Revenu) | `item2-w2-scene1-statut-emploi.png`, `item2-w2-scene2-etat-civil.png`, `item2-w2-scene3-lacunes-avs.png`, `item2-dossier-persistence-2answers.png` | **PASS** |
| 3 | W2 gates — indépendant no phantom LPP | Seed `independent_no_lpp` → `/home`, RvC, `/mon-argent` Prévoyance | /home card "Ton filet invalidité : AI seule — Sans LPP…"; RvC "Ton avoir LPP actuel" **EMPTY** + "Complète ton profil…" (no fiction 350'000); Prévoyance "Prévoyance LPP **0 CHF** (estimé)" — no phantom 76-95k | `item3-indep-home-no-phantom-lpp-AI-seule.png`, `item3-indep-rvc-lpp-empty-no-fiction.png`, `item3-indep-prevoyance-LPP-0-not-phantom.png` | **PASS** |
| 3 | W2 gates — FATCA US-person redirect | Seed `expat_us` → `/mon-argent` and `/home` | Both prévoyance surfaces redirect to **/waitlist** ("Encore en chantier pour ton profil… résidentes en Suisse, salariées, 2e pilier (LPP)") — US person never sees actionable 3a plafond | `item3-expat-us-mon-argent-redirect-waitlist.png`, `item3-expat-us-home-redirect-waitlist.png` | **PASS** |
| 4 | D10 — coach 3a suggestion ≤ remaining monthly plafond (never 1541) | Married swiss profile (7'000 net) → `/mon-argent` whisper | ~~**FAIL**~~ → **FIXED + RE-VERIFIED PASS** (refix `a5118d6e2`, 2026-06-12). `coach_whisper_service.dart` Rule 2 now routes through the canonical clamp `BudgetLivingEngine.cappedMonthly3aSuggestion` (NEVER #3 reuse — same clamp the LLM-context path uses). Device re-verify (swiss 7'000 net seed, marge libre 6'481): whisper now reads "💡 Bon mois. Tu pourrais verser **1037 CHF** en 3a." — clamped to the remaining annual plafond pro-rated over the remaining calendar months (June → 7 months left → 7258/7 = 1036.86 → 1037; 1037 × 7 = **7258 = exactly the legal ceiling**). The **1541 illogism is gone** (1541 × 12 = 18'492 ≈ 2.55× the ceiling). 0 room (US person / plafond atteint) → NO 3a whisper at all. | `refix/D10-mon-argent-whisper-1037-clamped-not-1541.png`, `refix/24-mon-argent-tab.png` (libre 6'481 + whisper 1037) ; original FAIL: `item4-mon-argent-1541-3a-suggestion.png` | **PASS** (re-verified) |
| 5 | D7 — /retraite reads same data as /home (not "4 infos suffisent") | Onboard a full hydrated profile (twice: RETRAITE-intent + IMPOTS-intent) → `/retraite` | ~~**FAIL**~~ → **ROOT-CAUSED + FIXED** (refix `53e0c24b7` + `8500b9269`, 2026-06-12); **device re-capture INCOMPLETE** (tooling, not fix). **Root cause (device-PROVEN via instrumented probe, log `refix/D7-probe-*.log`):** the `/retraite` dashboard first builds with `hasProfile=true … projection=true` (renders the projection), then a LATER build flips to `hasProfile=false isHydrating=false isLoading=false **isLoaded=true** projection=false` → State C. The shared `CoachProfileProvider` profile is **cleared out from under the mounted screen** (a SETTLED clear — not a hydration race — e.g. a release-mode `loadFromWizard` that finds no disk answers and falls to `_profile=null, isLoaded=true`). Plan 16's `if (!hasProfile) StateC` is correct for a *settled-empty* provider but regressed on this post-render clear. **Fix:** (1) `_everHadProfile` guard — once the screen has rendered a hydrated profile this session, a transient/settled clear must NEVER regress to « 4 infos suffisent » (keep last-known projection / recoverable retry); (2) `didChangeDependencies` preserves `_profile`/`_projection` on a post-render clear; (3) retains the hydration-race loading-state guard. A genuinely-empty settled provider still reaches State C (legit onboarding) + live CTA. **11/11 widget tests green** incl. the exact settled-clear scenario. **Device re-capture of the FIXED /retraite NOT obtained** — the custom-painted onboarding shell's text-links ("Continuer sans compte" / "J'ai déjà un compte") are not hittable via idb taps (same sparse-AX / custom-paint automation gap this gate documented under "Non-blocking observations"), so a hydrated profile could not be deterministically driven to `/retraite` post-fix. 0-TRUST: NOT claiming device-verified for D7 — fix is widget-test-verified against the device-proven mechanism. | `refix/D7-probe-hasProfile-true-then-false-settled-clear.log` (the smoking gun) ; original FAIL: `item5-retraite-empty-state-4infos.png`, `item5-D7-retraite-statec-after-full-onboarding-flush.png` | **FIXED (widget-test-verified) ; device re-capture INCOMPLETE (tooling)** |
| 5 | D8 — State-C CTA « Commencer » lands on /onb questions | `/retraite` → tapOn "Commencer" | **EXIT 0** (Maestro tapOn) → lands on `/onb` OnboardingShellScreen ("Il est temps que tu comprennes." → Ouvrir → real age/canton/revenu questions). Not a dead coach chat. | `item5-D8-commencer-lands-on-onb.png`, `item5-D8-maestro-tapOn-exit0.log` | **PASS** |
| 5 | W1 — married 3a tax-saving ≈1194 (married barème) | Drive `/onb` IMPOTS-intent + Marié → 3a-levier scene | **NOT-RUN** (figure not deterministically reachable). The married path IS reachable (état-civil "Marié" selectable + persists — `item5-etat-civil-marie-selectable.png`), but the onboarding 3a-levier scene shows an **approximate** marginal-rate figure (CHF 874–986 for a 3'000 versement, célibataire-based `_kTauxMarginalMoyen`, NOT the married barème — the scene header states "Le chiffrage précis canton-par-canton sera donné dans le canvas"). Plan 05's precise `estimate3aTaxImpact(isMarried:)` ≈1194 figure lives in the N3 canvas / coach response-card surface, which requires the live LLM coach or a specific canvas interaction not reachable by deeplink, and there is **no married seed** in the registry. Plan 05 was verified deterministically (RED→GREEN, 26/26 parity). | `item5-married-3a-levier-onboarding-approx-874-986.png`, `item5-etat-civil-marie-selectable.png` | **NOT-RUN** (no married seed + figure on non-deeplinkable coach/canvas surface) |
| 6 | W1 quantities spot-check — coherent across /home, /mon-argent, RvC (no 2× divergence) | Seeded swiss_native (RETRAITE married) + independent profiles, navigate across screens same session | **PASS** — swiss: /home hero **Avoir LPP 37'600** == RvC **37'600** (identical; was 8× apart pre-fix: 43'691 home vs 350'000 RvC). /home Marge libre 6'164 == /mon-argent libre 6'164. Replacement rate 63% shown in onboarding insight; rente projection 4'145-5'603 coherent. Independent: /home (no LPP) == RvC (LPP empty) == Prévoyance (LPP 0 CHF) all coherent. No quantity showed two values for the same input. | `item6-home-avoir-lpp-37600.png`, `item6-rvc-avoir-lpp-37600-SAME-as-home.png`, `item6-w1-replacement-rate-63pct-onboarding-insight.png`, `item6-w1-scene-rente-projetee.png`, `item3-indep-*` | **PASS** |

## FAIL details (RESOLVED — refix run 2026-06-12, see ## Refix below)

### FAIL #1 — D10 (item 4): uncapped 3a whisper survives on /mon-argent

- **Surface:** `/mon-argent` deterministic coach whisper.
- **Observed string:** "Bon mois. Tu pourrais verser **1541** CHF en 3a." (married swiss, monthlyFree 6'164). `round(6164 × 0.25) = 1541`. ×12 = 18'492/yr = **2.55× the CHF 7'258 salaried plafond** — the exact D10 finding plan 14 claimed closed.
- **Root cause:** `apps/mobile/lib/services/mon_argent/coach_whisper_service.dart:41` — `final suggestion = (monthlyFree * 0.25).round();` with **no plafond clamp** anywhere in the call chain (grep for `plafond|ceiling|remainingRoom|Pillar3a` in that file → none).
- **Why plan 14 missed it:** Plan 14's fix (`1f4318519`) touched only `budget_living_engine.dart` and `services/coach/context_injector_service.dart` (the LLM-context path). The `coach_whisper_service.dart` deterministic whisper is a separate code path; last touched by `8705876e1` (pre-phase). Its unit test (8/8 green) covered the LLM path, not this whisper.
- **Independent corroboration:** same formula fires for the indépendant ("958 CHF en 3a" = round(3833×0.25)); below the indep grand-plafond so not over-cap there, but confirms the formula is structurally uncapped.
- **Suggested scope for a follow-up fix:** route `CoachWhisperService.evaluate` Rule 2 through the same `Pillar3aRoomCalculator` remaining-ceiling clamp plan 14 applied elsewhere (NEVER #3 — reuse L1 canonical).

### FAIL #2 — D7 (item 5): hydrated profile still shows "4 infos suffisent" on /retraite

- **Surface:** `/retraite` (Mon tableau de bord).
- **Observed (twice, two independent onboarding runs):** a profile that hydrates `/home` (Avoir LPP 37'600) and RvC prefill (age 33, revenu brut 101'790, avoir LPP 37'600 — all profile-derived, so `CoachProfileProvider` IS populated) STILL renders `/retraite` State-C "Ta retraite en un coup d'œil — 4 infos suffisent… Commencer — 2 min".
- **Root cause locus:** `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart:380` — `if (!provider.hasProfile) { child = _buildStateC(); } else { child = _buildProjectionUnavailable(); }`. State-C is rendering, which implies `provider.hasProfile == false` on `/retraite` for a profile other surfaces read as present. Plan 16's D7 fix (State-C only when truly no profile) does not hold for the onboarding-flush path observed here.
- **Caveat (0-TRUST):** I did not trace the provider internals to confirm whether `/retraite` and RvC read the same `CoachProfileProvider` instance or whether the deeplink navigation re-instantiates a non-hydrated provider. RvC reading profile-derived prefill is strong (not conclusive) evidence the profile is hydrated. Recorded as a device-observed regression for the orchestrator to triage; NOT auto-fixed.
- **D8 leg is clean PASS** (CTA routes to real /onb questions) — the failure is isolated to the D7 state-selection, not the CTA target.

## Non-blocking observations

- **Onboarding scenes expose sparse AX trees** (idb `describe-all` returns 1 element on custom-painted onboarding scenes and on the deeplink-from-home RvC path). This is a broader a11y/automation gap of the onboarding shell + Flutter overlay rendering, out of this phase's scope; visual verification was done via screenshots. The RvC AX tree IS rich (29 elements) on the cold-deeplink path — the ILLOG-02 fix is real.
- **iOS 26.2 "Open in MINT?" first-use dialog** intercepts the very first `mintapp://` deeplink of a session (documented in `bug__S003` header). `simctl openurl` (host path) and warm-app Maestro `openLink` both bypass it after first acceptance — the two ILLOG flows exit 0 on the warm path.

## Refix (2026-06-12) — both FAILs root-caused, fixed, re-verified

Branch `qa/runtime-navigation-spine-20260602`. Iron Law honored — a failing test reproduced each FAIL FIRST, then the fix. Build = same device-gate invocation (`flutter build ios --simulator --no-codesign` + staging dart-defines), reinstalled on iPhone 17 Pro `B03E429D` / iOS 26.2.

### FAIL #1 — D10 whisper → FIXED + device-RE-VERIFIED PASS

- **Commit:** `a5118d6e2` `fix(mint-illogism-fixes): clamp /mon-argent 3a whisper to statutory ceiling (D10)`.
- **Fix:** `coach_whisper_service.dart` Rule 2 now routes its 3a amount through the **canonical clamp** `BudgetLivingEngine.cappedMonthly3aSuggestion` (the SAME clamp plan 14 wired into the LLM-context path — NEVER #3 reuse, never re-implemented). Archetype-aware remaining-room proration; **0 room (US person / FATCA or plafond atteint) → NO 3a whisper at all** (a 0-CHF suggestion would be a dissonant illogism). Added an injectable `now` for deterministic test proration; the live caller keeps `DateTime.now()`.
- **Tests (RED→GREEN):** marge 6164 → whisper ≤ plafondRestant, never 1541; US person → no whisper. Existing 3a-suggestion tests updated to clamped figures with injected `now`. All whisper + `suggestion_3a_cap` tests green.
- **Device re-verify (PASS):** swiss 7'000-net profile, marge libre **6'481** → whisper now "💡 Bon mois. Tu pourrais verser **1037 CHF** en 3a." `1037 × 7 remaining months (June) = 7258 = exactly the legal annual ceiling`. The **1541 illogism is gone**. Evidence: `refix/D10-mon-argent-whisper-1037-clamped-not-1541.png`, `refix/24-mon-argent-tab.png`.

### FAIL #2 — D7 /retraite → ROOT-CAUSED + FIXED; device re-capture INCOMPLETE (tooling)

- **Commits:** `53e0c24b7` (hydration-race guard) + `8500b9269` (settled-clear guard — the device root-cause fix).
- **Root cause (device-PROVEN):** an instrumented build (temporary `[D7-PROBE]` print, removed before the final commit) captured on device:
  ```
  [D7-PROBE] retraite build: hasProfile=true  isHydrating=false isLoading=false isLoaded=true projection=true
  [D7-PROBE] retraite build: hasProfile=true  isHydrating=false isLoading=false isLoaded=true projection=true
  [D7-PROBE] retraite build: hasProfile=false isHydrating=false isLoading=false isLoaded=true projection=false  <- State C
  ```
  The dashboard renders WITH the profile, then a LATER build flips to `hasProfile=false` while **SETTLED** (not hydrating, not loading) — the shared provider's profile is **cleared out from under the mounted screen** (e.g. a release-mode `loadFromWizard` that finds no disk answers → `_profile=null, isLoaded=true`). This is NOT the original "hydration-race" hypothesis; it's a post-render settled clear. Evidence: `refix/D7-probe-hasProfile-true-then-false-settled-clear.log`.
- **Fix:** `_everHadProfile` guard — once `/retraite` has rendered a hydrated profile this session, a transient/settled clear must NEVER regress to « 4 infos suffisent » (keep last-known projection / recoverable retry); `didChangeDependencies` preserves `_profile`/`_projection` on a post-render clear; the hydration-race loading-state guard is retained; a genuinely-empty settled provider still reaches State C + live CTA.
- **Tests (RED→GREEN):** 11/11 green incl. settled-clear-after-render → no State C, post-pump hydration → leaves State C, hydration-in-flight → loading (not State C), genuinely-empty → State C; plus the unchanged D8 CTA test.
- **Device re-capture (INCOMPLETE — tooling, NOT the fix):** the fixed build was rebuilt + installed, but a hydrated profile could not be deterministically driven to `/retraite` post-fix: the custom-painted onboarding-shell text-links ("Continuer sans compte" / "J'ai déjà un compte") are **not hittable via idb taps** (the same sparse-AX / custom-paint automation gap documented under "Non-blocking observations" — only 1 AX element). **0-TRUST: NOT claiming device-verified PASS for D7.** The fix is widget-test-verified against the device-PROVEN failure mechanism; the on-device green screenshot is the one outstanding item.

## Summary

| Verdict | Items |
|---------|-------|
| PASS | 1 (ILLOG-01 + ILLOG-02), 2 (W2 onboarding scenes + persistence), 3 (indép no phantom LPP + FATCA redirect), **4 (D10 whisper — FIXED + device-re-verified, clamped to 1037 not 1541)**, 5-D8 (CTA → /onb), 6 (W1 cross-screen coherence) |
| FIXED (widget-test-verified, device re-capture pending) | 5-D7 (settled-clear of provider → no longer regresses to "4 infos suffisent" — root cause device-proven via probe, fix + 11 tests green, on-device green screenshot outstanding due to onboarding-shell automation gap) |
| NOT-RUN | 5-W1 married ≈1194 (no married seed; figure on non-deeplinkable coach/canvas surface) |

Tests green ≠ feature working: the two FAILs were exactly the second-code-path / state-selection regressions the per-plan unit suites did not catch. D10 is now device-re-verified PASS; D7's root cause is device-proven and the fix is widget-test-verified, with an honest caveat that the on-device green screenshot of the fixed /retraite is outstanding (onboarding-shell idb-tap gap). No "shipped"/"ready" claim — deterministic citations only.
