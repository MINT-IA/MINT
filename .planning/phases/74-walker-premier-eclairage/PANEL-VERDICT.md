# Phase 74 — Walker Premier Éclairage — Panel Verdict

> **Date :** 2026-05-05
> **Panel :** 3-pers (E2E walker veteran + image-diff specialist + adversarial cynic)
> **Verdict :** APPROVE-WITH-CHANGES — locked for implementation. Effort 4.0-4.5d.

## 1. Walker scope (LOCKED)

- **NEW file** `tools/simulator/walker_premier_eclairage.sh` — DO NOT extend `walker_audit_tap_render.sh` (wrong shape, tab-by-tab regression tool) and DO NOT source `walker.sh` (its argv parser eats ours, see line 250)
- **Reuse pattern, not code :** copy helper trio (`tap_at`/`type_text`/`wait_for_ui`/`snap`) inline. Copy verbatim with `--no-codesign` flag (per memory `feedback_diff_against_existing_tool`).
- **6 checkpoints (not 4) :**
  1. `00-cold-launch.png` — post-`simctl launch`, ~6s sleep
  2. `01-landing.png` — wait_for_ui after launch, snap before tap (golden anchor)
  3. `02-anon-chat-opener.png` — tap landing CTA → wait 2.5s opener bubble + 3 chips
  4. `03-after-turn1.png` — tap chip 1 OR `type_text` deterministic prompt → wait coach response (max 12s — staging Anthropic P95)
  5. `04-eclairage-card.png` — second turn → ECL-01 hero card render (max 12s)
  6. `05-register-cta.png` — scroll/snap with register CTA in viewport
- **Timeout :** 180s wall-clock per archetype (NOT 120s — staging P95 hits 8-10s × 2 turns + boot)

## 2. Image-diff stack (LOCKED)

- **Pillow + scikit-image SSIM**, NOT perceptual hash, NOT imagemagick `compare`
- pHash too lossy at 4% (font-hint drift swallowed = false negatives)
- imagemagick produces overlays but PIL+numpy gives bounding box masking without 2nd binary dep
- **NEW file** `tools/simulator/image_diff.py` (≤ 250 LOC). API :
  ```python
  diff(reference_png, candidate_png, hero_bbox=None, threshold_pct=4.0)
    -> {"diff_pct": float, "passed": bool, "diff_png": "/path/diff.png"}
  ```
- **Hero bbox declarative**, NOT auto-detected. `tools/simulator/hero_bboxes.json` :
  ```json
  {
    "01-landing":          {"x": 0,  "y": 800,  "w": 1179, "h": 1200},
    "02-anon-chat-opener": {"x": 0,  "y": 200,  "w": 1179, "h": 1400},
    "04-eclairage-card":   {"x": 60, "y": 600,  "w": 1059, "h": 1100},
    "05-register-cta":     {"x": 60, "y": 1800, "w": 1059, "h": 600}
  }
  ```
  Coords iPhone 17 Pro logical×3 (1179×2556).
- **Diff algorithm :** crop to bbox → SSIM via `skimage.metrics.structural_similarity`. SSIM threshold ≥ 0.96 = pass. Fallback if scikit-image unavailable : numpy abs-diff over RGB with 8-value tolerance per channel.
- **Output :** `diff.png` = 3-panel composite (ref | candidate | red overlay) + `result.json` per checkpoint

## 3. Archetype seed format (LOCKED)

- **Path** `tools/simulator/archetypes/<name>.json`
- **Format :**
  ```json
  {
    "slug": "couple_acheteurs_lausanne",
    "label": "Couple acheteurs Lausanne",
    "profile": {"age": 38, "canton": "VD", "salary_brut_year": 145000,
                "has_lpp": true, "lpp_balance": 220000,
                "has_3a": true, "3a_balance": 18000,
                "marital_status": "married", "kids_count": 1,
                "owns_property": false},
    "expected_eclairage": {"kind": "lpp_rachat_3a_nantissement",
                           "value_min": 8000, "value_max": 14000},
    "deterministic_prompts": [
      "Combien je peux mettre dans un 3a cette annee ?",
      "Et avec un rachat LPP en plus ?"
    ]
  }
  ```
- **4 fixtures :** `julien_swiss.json`, `couple_acheteurs_lausanne.json`, `jeune_diplome_zurich.json`, `cadre_40_55_lpp_rachat.json`
- These are NEW slugs — DO NOT match the 8 CONTEXT D-02 slugs (`swiss_native`/`expat_eu`/...). Walker whitelists these 4 separately.
- **Wiring side :** `--dart-define=MINT_E2E_ARCHETYPE=<slug>` already plumbed in `coach_profile_seeds.dart`. Phase 74 PR adds the 4 new slugs to seed loader **AND** new `--dart-define=MINT_E2E_FORCE_ECLAIRAGE_KIND=<kind>` so eclairage payload is deterministic (LLM call still runs, but orchestrator pins `kind` post-tool-dispatch). Without this, image-diff doomed.

## 4. Tolerance + failure mode

- **Hard-fail (exit 2)** : SSIM < 0.96 inside hero bbox on ANY of 6 checkpoints
- **Hard-fail (exit 2)** : capture rate < 6/6
- **Hard-fail (exit 2)** : wall-clock > 180s per archetype
- **Soft-warn (exit 0, log only)** : diff outside hero bbox > 4% (status bar / clock drift expected)
- **Hard-fail (exit 3)** : registry CTA bbox SSIM < 0.96 (TestFlight reviewer taps this)

## 5. Run-id archive structure

- `run-id` = `YYYY-MM-DD-HHMMSS-<git-sha-short>` (NOT just SHA — multiple runs per commit during iteration)
- ```
  .planning/walker/<run-id>/
  ├── summary.json
  ├── walker.log
  └── <archetype>/
      ├── screenshots/00-cold-launch.png ... 05-register-cta.png
      ├── diff/01-landing_diff.png ... 05-register-cta_diff.png
      └── result.json
  ```
- Top-level `summary.json` = CI-readable artifact
- NOT under `.planning/phases/74-…/` — `.planning/walker/` shared across phases

## 6. Adversarial mitigations

| # | Pattern | Mitigation |
|---|---|---|
| 1 | Font hint drift sim-to-sim | Pin sim runtime preflight : `xcrun simctl runtime list \| grep "iOS 18.2"` required, fail fast. SSIM ≥ 0.96 absorbs sub-pixel. |
| 2 | Flaky tap coords (chat input scroll) | After `type_text`, send `cliclick "kp:return"` instead of send-button tap. -1 tap/archetype. |
| 3 | Network latency variance | `wait_for_ui` polls SHA-quiescence. Bound 12s max per turn, then `_snap` + mark `degraded` if SSIM still passes. |
| 4 | Keyboard covers chips | Before chip-tap, `cliclick "kp:esc"` to dismiss. Mandatory between turn 1 and turn 2. |
| 5 | Sim runtime drift Mac mini ↔ CI | Goldens at `tools/simulator/goldens/<archetype>/<checkpoint>.png` valid only for iPhone 17 Pro / iOS 18.2. Walker hard-fails on mismatch. |

## 7. Decisions LOCKED

1. Walker = bash + Python (`image_diff.py`) — no Dart-side `integration_test` (doubles build time + breaks staging-only doctrine)
2. Image-diff = Pillow + scikit-image SSIM with numpy fallback
3. Archetype seed format = JSON @ `tools/simulator/archetypes/` + new `MINT_E2E_FORCE_ECLAIRAGE_KIND` dart-define for orchestrator pin
4. Tap strategy = `cliclick` coords (existing walker pattern). Reject `idb` (extra dep, no a11y IDs wired). Reject `flutter integration_test` (per #1).
5. Network = staging Railway always (`mint-staging.up.railway.app`) per memory `feedback_app_targets_staging_always`
6. Run-id = `YYYY-MM-DD-HHMMSS-<sha7>` under `.planning/walker/`
7. Failure mode = exit 2 on any hero-bbox SSIM < 0.96 OR missing checkpoint OR > 180s wall ; exit 3 on register CTA bbox specifically (TestFlight tap target)

## 8. Effort + 3 hidden risks

**Cynic-validated effort : 4.0-4.5 dev-days.**
- 0.75d walker_premier_eclairage.sh skeleton + tap sequence + 6 capture
- 1.0d image_diff.py SSIM + bbox + 3-panel diff PNG + JSON
- 0.75d 4 archetype JSON fixtures + `MINT_E2E_FORCE_ECLAIRAGE_KIND` orchestrator pin (Flutter side, NON-trivial — coach_orchestrator.dart guard branch)
- 0.5d golden screenshot regeneration + bbox calibration on real sim
- 0.75d flake-debugging on first 4-archetype run (×2.5 not ×3 because chat-first narrowed surface)
- 0.25d summary.json aggregator + CI integration smoke

**Top 3 hidden risks :**
1. **`MINT_E2E_FORCE_ECLAIRAGE_KIND` orchestrator pin doesn't exist yet** — Phase 74 needs Flutter-side patch in `coach_orchestrator.dart:1113` to short-circuit `kind` resolution from env. Skipping = image-diff fails every run. MUST be in Phase 74 PR scope. Single biggest hidden line item.
2. **Anonymous chat seed wiring for 4 NEW archetypes** — `coach_profile_seeds.dart` only knows 8 CONTEXT D-02 slugs. 4 Phase-74 slugs need parallel registration path (or JSON-driven seed reader). Hidden 2-3h.
3. **Register CTA position layout-dependent** — if ECL-01 card height varies (LPP-rachat taller than 3a-only), CTA bbox shifts off-screen. Mitigation : scroll-to-bottom before checkpoint 5, OR set min scroll offset per archetype in `hero_bboxes.json`. Decide at calibration, log as Phase-74 follow-up.

## 9. Files to know

- `tools/simulator/walker_audit_tap_render.sh` (helper trio source, lines 252-281)
- `tools/simulator/walker.sh` (build flags + `--no-codesign`, lines 587-592)
- `apps/mobile/lib/services/coach/coach_orchestrator.dart:1113` (orchestrator pin insertion point)
- `apps/mobile/lib/widgets/onboarding/premier_eclairage_card.dart` (card render — bbox calibration target)

---

**Panel verdict :** ship.
