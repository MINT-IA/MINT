# Requirements: MINT v2.11 — Walker-Validated E2E + Eclairage Wiring

**Defined:** 2026-05-05
**Research artifacts:** 5 audits du 2026-05-05 (A: walker coords / B: backend pipeline / C: MINT_E2E_FORCE_ECLAIRAGE_KIND / D: beta modal + idempotence / E: i18n + animation timing)
**Core Value:** Un inconnu ouvre MINT, ressent quelque chose, tape sur une phrase, reçoit une réponse qui le surprend, crée un compte pour ne pas perdre ça.

## Source de vérité — pourquoi v2.11 existe

v2.10 a livré du tooling et des panel verdicts mais les 5 audits ont révélé que le contrat « Premier Éclairage » n'est pas wiré end-to-end :

- **Phantom contract C1 (Flutter) :** `forcedEclairageKind` getter déclaré (`coach_orchestrator.dart:142-147`), ZÉRO callsite. `CoachProfileSeeds.activeSeed` jamais lue. `PremierEclairageSelector` n'est appelé par aucun screen.
- **Phantom contract C2 (backend) :** `eclairage` field assumé par PR #486 N'EST PAS dans le shipped contract sur `dev`. `AnonymousChatResponse` n'a pas de champ `eclairage`. Backend ignore tout `archetype` body field.
- **Phantom contract C3 (walker calibration) :** `cliclick` = macOS desktop logical px (pas device px). `hero_bboxes.json` calibré pour iPhone 15 Pro (1179×2556) au lieu d'iPhone 17 Pro (1206×2622). `wait_for_ui` SHA-quiescence retourne happy sur stuck UI.
- **Phantom contract C4 (sim hygiene) :** Walker `--archetype-walkthrough` skip sim erase = state pollution. `BetaProgramDisclosureSheet` `isDismissible: false`, no dart-define disable.
- **Phantom contract C5 (i18n) :** `build_discovery_system_prompt` accepte `language` param mais ne le lit jamais → cross-language drift DE input → FR output.

v2.11 wire les 5 contrats mécaniquement. Critère de done : `walker_premier_eclairage.sh` exit 0 sur 4 archetypes + visual diff ≤ 4 % vs goldens calibrés + TestFlight 2.11.0 build dispo.

## v2.11 Requirements

### Eclairage E2E wiring (Flutter)

- [ ] **ECLW-01**: `forcedEclairageKind` (`coach_orchestrator.dart:142`) is read by the tool-call dispatcher post-LLM-parse and overrides the resolved `kind` in the eclairage payload before it reaches the screen render.
- [ ] **ECLW-02**: `CoachProfileSeeds.activeSeed` is read in `CoachContext` construction (anonymous tier) so the 4 v2.10 archetype slugs hydrate the seed when `MINT_E2E_ARCHETYPE` is set at build time.
- [ ] **ECLW-03**: `PremierEclairageSelector.select()` is invoked from the anonymous chat screen (or upstream coach flow) when an eclairage payload is parsed from the response, producing a renderable `EclairageCardData`.
- [ ] **ECLW-04**: `forcedEclairageKind` consumer is gated by `kReleaseMode` — release builds ignore the dart-define entirely (security/integrity).
- [ ] **ECLW-05**: A widget test asserts that with `--dart-define=MINT_E2E_FORCE_ECLAIRAGE_KIND=fiscal_margin_3a`, the rendered card shows headline + body matching the `fiscal_margin_3a` template, NOT the LLM-natural kind.

### Backend eclairage contract

- [ ] **ECLB-01**: `AnonymousChatRequest` (Pydantic) accepts an optional `archetype: Literal["julien_swiss", "couple_acheteurs_lausanne", "jeune_diplome_zurich", "cadre_40_55_lpp_rachat"]` body field.
- [ ] **ECLB-02**: `AnonymousChatResponse` (Pydantic) carries an optional `eclairage: EclairageSchema | None` field with sub-fields `kind`, `headline`, `body`, `chf_range_low`, `chf_range_high`, `chf_range_period`, `soft_account_hint`, `lsfin_disclaimer`.
- [ ] **ECLB-03**: Backend orchestrator emits the `eclairage` payload at coach turn 2 when the archetype field is present and `MINT_E2E_FORCE_ECLAIRAGE_KIND` env (or request body) pins the kind ; otherwise emits free-form prose like today.
- [ ] **ECLB-04**: `EclairagePayload` LSFin compliance — never absolute CHF (always conditional range with low+high) ; LSFin disclaimer always present ; banned terms list expanded (idéal / il faut / vous économiserez / rentable / opportunité / etc.) verified by `check_banned_terms` MCP at build_payload time.
- [ ] **ECLB-05**: A pytest asserts that `POST /api/v1/anonymous/chat` with body `{"message": "ok", "archetype": "julien_swiss"}` (turn 2) returns a response whose `eclairage.kind == "fiscal_margin_3a"` (deterministic).

### Walker coord-system overhaul

- [ ] **WALKC-01**: `walker_premier_eclairage.sh` reads sim-window position+size at runtime via `osascript -e 'tell app "Simulator" to get bounds of window 1'` and derives all tap coords by anchor (logical %) — no hardcoded desktop px.
- [ ] **WALKC-02**: `hero_bboxes.json` `_resolution_px` = `[1206, 2622]` (iPhone 17 Pro) ; all 4 bbox entries recalibrated for this resolution ; Dynamic Island region excluded (`y < 180` not in any bbox).
- [ ] **WALKC-03**: `wait_for_ui` quiescence detector requires ≥ 2 consecutive stable hashes (currently accepts 1) ; logs hash sequence to walker.log when retry > 3 to surface stuck UI.
- [ ] **WALKC-04**: Walker activates the Simulator window before each `_tap_at` via `osascript -e 'tell application "Simulator" to activate'` to ensure cliclick events route to sim, not Terminal.
- [ ] **WALKC-05**: Walker has an explicit beta-disclosure dismiss step before the funnel starts ; tap coord derived from anchor (CTA button at sim screen y ≈ 80 % vh, x ≈ 50 % vw).
- [ ] **WALKC-06**: Walker scroll-to-register-CTA uses `cliclick dd:X,Y du:X,Y2` swipe-up gesture (not tap-as-scroll which is no-op).

### Sim hygiene + state isolation

- [ ] **SIMH-01**: `walker_premier_eclairage.sh --archetype X` calls `xcrun simctl shutdown $DEVICE_ID; xcrun simctl erase $DEVICE_ID; xcrun simctl boot $DEVICE_ID` BEFORE `flutter build` (eliminates SharedPrefs pollution and beta-disclosure flag).
- [ ] **SIMH-02**: `xcrun simctl uninstall $DEVICE_ID ch.mint.app` is called as defensive idempotence guard before `simctl install`.
- [ ] **SIMH-03**: New dart-define `--dart-define=MINT_DISABLE_BETA_MODAL=true` is wired into `BetaProgramDisclosureSheet.maybeShow` (`if (bool.fromEnvironment('MINT_DISABLE_BETA_MODAL')) return false;`) and walker passes it.
- [ ] **SIMH-04**: `screenshots/walkthrough/` and other walker output paths added to `.gitignore` to prevent PR bloat.
- [ ] **SIMH-05**: Walker fail-fast preflight verifies sim runtime present (any iOS, default = booted device's runtime, override via `MINT_WALKER_REQUIRED_RUNTIME`).

### Cross-language drift fix

- [ ] **LANG-01**: `services/backend/app/api/v1/endpoints/anonymous_chat.py::build_discovery_system_prompt` reads the `language` param (currently accepted but never used) and emits the system prompt in the matching language (FR/EN/DE/IT/ES/PT).
- [ ] **LANG-02**: A pytest asserts that `POST /anonymous/chat {"message": "Was ist die 3. Säule?", "language": "de"}` returns a response with German `disclaimers` AND German body (not French).
- [ ] **LANG-03**: A CI gate (`tools/checks/arb_key_parity.py` or `validate_arb_parity()` MCP wired in lefthook) fails the build if any ARB key exists in `app_fr.arb` but is missing in any other locale (or vice-versa).

### Walker green + TestFlight 2.11.0 cut

- [ ] **WALKR-01**: `bash walker_premier_eclairage.sh --archetype julien_swiss --no-dry-run` exits 0 with 6/6 captured screenshots SHA-distinct.
- [ ] **WALKR-02**: Same for `couple_acheteurs_lausanne`, `jeune_diplome_zurich`, `cadre_40_55_lpp_rachat`.
- [ ] **WALKR-03**: `image_diff.py` SSIM ≥ 0.96 on each hero bbox vs committed goldens for all 4 archetypes (per-archetype goldens at `tools/simulator/goldens/<archetype>/<checkpoint>.png`).
- [ ] **WALKR-04**: Register CTA bbox SSIM ≥ 0.96 (exit 3 if fail — TestFlight reviewer-tap target).
- [ ] **WALKR-05**: `apps/mobile/pubspec.yaml` bumped to `2.11.0+1`, tagged, `testflight.yml` workflow triggered, IPA upload visible in App Store Connect.
- [ ] **WALKR-06**: Walker run-id evidence (`.planning/walker/<run-id>/summary.json`) attached to TestFlight build description.

## Out of Scope (anti scope-creep)

| Feature | Reason |
|---------|--------|
| Wiki coach v3 (per-user knowledge graph) | Post-TestFlight v2.11. ADR-20260503 référencé mais pas écrit. |
| Couple mode wiring (UI ↔ financial_core) | Data layer cracked ; 2-3 weeks fix. Pas sur le path TestFlight. |
| FIX-03 save_fact `responseMeta.profileInvalidated` | Carry-forward — n'affecte pas anonymous tier. |
| FIX-04 Coach tab routing stale | Carry-forward — n'affecte que tier authentifié. |
| 388 bare-catches sweep | Carry-forward v2.12 ; observabilité shippée v2.10 Sprint 0 PR #478. |
| Coach chat full redesign (post-auth) | Out — v2.10 + v2.11 = anonymous tier only. |
| Aujourd'hui / Dossier / Explorer redesign | Out — visual unchanged. |
| Multi-step onboarding wedge T9-style | Out — chat-first replaces it. |
| Banking + LPP API integration | v3.0+. |
| Vignettes / Scènes / Canvas (v2.9 doctrine) | Deferred. |
| BYOK testing | Out per memory `project_byok_scope`. |
| iPhone 17 Pro Max / iPhone SE viewports | Out v2.11 — single sim target = iPhone 17 Pro. Multi-device v2.12. |

## Traceability (filled by roadmap)

| Requirement | Phase | Status |
|-------------|-------|--------|
| ECLW-01..05 | TBD | Pending |
| ECLB-01..05 | TBD | Pending |
| WALKC-01..06 | TBD | Pending |
| SIMH-01..05 | TBD | Pending |
| LANG-01..03 | TBD | Pending |
| WALKR-01..06 | TBD | Pending |

**Coverage:**
- v2.11 requirements: 30 total (5 + 5 + 6 + 5 + 3 + 6)
- Mapped to phases: 0 (roadmap pending)
- Unmapped: 30 ⚠️

## Constraints from Julien (operational)

- No human-in-the-loop testing. Claude validates via simulator iPhone (Mac mini) before any visual is shown.
- Image budget : max 1-2 screenshots per checkpoint surfaced to Julien.
- TestFlight = Claude-validated only.
- No new PRs outside the 6 v2.11 phases.
- 5 audits 2026-05-05 are the research artifacts ; do not re-research.

---
*Requirements defined: 2026-05-05*
*Last updated: 2026-05-05 — v2.11 milestone open, roadmap pending*
