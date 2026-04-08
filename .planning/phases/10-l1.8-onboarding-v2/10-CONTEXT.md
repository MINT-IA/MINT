# Phase 10 — L1.8 Onboarding v2 — CONTEXT

**Date:** 2026-04-07
**Branch:** `feature/v2.2-p0a-code-unblockers`
**Goal:** Delete 5 onboarding screens, wire intent → chat directly, drop screens-before-first-insight from 5 to 2.
**Requirements:** ONB-01..10, ACCESS-06
**Depends on:** Phase 7 (landing v2), Phase 1.5 (chiffre_choc rename — already shipped, screens are now `premier_eclairage*`)

---

## Decisions (locked — non-negotiable)

- **D-01 — Actual filenames post Phase 1.5.** The 5 deletion targets are:
  1. `apps/mobile/lib/screens/onboarding/quick_start_screen.dart`
  2. `apps/mobile/lib/screens/onboarding/premier_eclairage_screen.dart` (was `chiffre_choc_screen.dart`)
  3. `apps/mobile/lib/screens/onboarding/instant_premier_eclairage_screen.dart` (was `instant_chiffre_choc_screen.dart`)
  4. `apps/mobile/lib/screens/onboarding/promise_screen.dart`
  5. `apps/mobile/lib/screens/onboarding/plan_screen.dart`
  ROADMAP §10 SC #1 still uses pre-1.5 names; the actual files on disk are the renamed versions. Phase 10 deletes the renamed files.

- **D-02 — `data_block_enrichment_screen.dart` PRESERVED.** It is a JIT deep-link tool, not part of the linear onboarding pipeline. Kept under `lib/screens/onboarding/` (location is historical, not a pipeline marker). GoRouter reachability test asserts the route still resolves and renders.

- **D-03 — `intent_screen.dart` becomes the single onboarding step.** The `_isFromOnboarding == true` branch (currently lines 201-206: `router.go('/onboarding/quick-start', ...)`) is replaced with a direct `router.go('/coach/chat', extra: payload)` carrying the chip payload. The full else-branch logic (premier_eclairage compute, CapMemoryStore seed, CapSequenceEngine.build) is preserved and merged into the unified path so the coach receives the same enriched payload regardless of entry. `premier_eclairage_selector` import REMAINS in `intent_screen.dart` (it is still consumed in the merged path) — ROADMAP wording "removed" applies only if the selector is no longer needed; we will verify in the pre-audit. If the selector is still consumed, document the deviation in PRE_AUDIT.md and keep the import. The intent screen never routes to a deleted screen.

- **D-04 — OnboardingProvider direct deletion (clean sweep, no deprecation window).** Provider file deleted, MultiProvider entry removed, all consumers migrated in the same commit chain. Pre-launch codebase, no warehouse contract, no analytics dual-emit, no API consumers. Deprecation window is overhead with zero benefit.

- **D-05 — State migration map.** OnboardingProvider holds 7 fields. Migration target per field:

  | Field | Today (OnboardingProvider) | Migrates to | Rationale |
  |---|---|---|---|
  | `birthYear` | SharedPrefs `onboarding_birth_year` | `CoachProfileProvider.profile.birthDate` (or `age` derivation) | Profile owns user demographics. |
  | `grossSalary` | SharedPrefs `onboarding_gross_salary` | `CoachProfileProvider.profile.salaireBrutMensuel` | Profile owns financial primitives. |
  | `canton` | SharedPrefs `onboarding_canton` | `CoachProfileProvider.profile.canton` | Profile owns location. |
  | `anxietyLevel` | SharedPrefs `onboarding_anxiety_level` | `CapMemoryStore.declaredGoals` (transient) OR DELETED | Hinge anxiety prompt no longer exists post-deletion of promise/quick-start. If no surviving consumer, drop the field entirely. Pre-audit confirms. |
  | `chocType` | SharedPrefs `onboarding_choc_type` | `ReportPersistenceService.savePremierEclairageSnapshot` (already exists, see intent_screen.dart:221) | Snapshot store already canonical for premier_eclairage. |
  | `chocValue` | SharedPrefs `onboarding_choc_value` | Same as `chocType`. | Same. |
  | `emotion` | SharedPrefs `onboarding_emotion` | `CapMemoryStore` (transient cap state) OR DELETED | Captured by `instant_premier_eclairage_screen` which is being deleted. If no surviving consumer, drop. |

  Pre-audit task confirms field-by-field whether each migration target exists or whether the field is dead-on-arrival. Dead fields are deleted, not migrated.

- **D-06 — Redirect shim policy: NO shims for legacy onboarding routes.** `/onboarding/quick-start`, `/onboarding/promise`, `/onboarding/plan`, `/onboarding/chiffre-choc`, `/chiffre-choc-instant`, and post-1.5 equivalents (`/onboarding/premier-eclairage`, `/premier-eclairage-instant`) → REMOVED from GoRouter. Pre-launch app, no external deep links exist (verified via `git grep` for hardcoded `/onboarding/quick-start` etc.). If pre-audit finds any external link (push notification, email template, deeplink config), THEN we add a single catch-all `/onboarding/(quick-start|promise|plan|premier-eclairage)` redirect → `/onboarding/intent`. Default position: zero shims, full delete. Reverse the decision only on pre-audit evidence.

- **D-07 — Test migration strategy: capture pre-count, migrate don't drop, assert post ≥ pre.** Before any deletion (Plan 10-01), `flutter test 2>&1 | tail -5` aggregate count is captured into `docs/ONBOARDING_V2_PRE_AUDIT.md`. For each test file that imports a deleted screen or `OnboardingProvider`, the test is **migrated** to assert the new behavior (intent → /coach/chat) where semantically meaningful, or **deleted with replacement** (a new test of equivalent or greater coverage). Silent test drops are blocked: post-deletion `flutter test` count must be ≥ pre-deletion. Audit fix C3 from ROADMAP §10 SC #3.

- **D-08 — Flesch-Kincaid French tool: pure-Dart inline implementation in `tools/checks/flesch_kincaid_fr.dart`.** ~60 LOC. Formula: `206.835 - 1.015*(words/sentences) - 84.6*(syllables/words)`, French syllable counting via vowel-group regex (a/e/i/o/u/y/à/â/é/è/ê/ë/î/ï/ô/û/ù/ü). Threshold for B1: FK ≥ 60 (lower secondary equivalent). Avoids Python dependency in Flutter CI and avoids `textstat` Python package which lacks French calibration. Wired into CI as `dart run tools/checks/flesch_kincaid_fr.dart lib/l10n/app_fr.arb --keys-prefix=intentScreen,landing,onboarding --min=60`. ACCESS-06 deliverable.

- **D-09 — Tap-to-define infra (jargon expansion).** Use existing `MintTextWithGlossary` widget if present; else create `apps/mobile/lib/widgets/text/jargon_text.dart` (~80 LOC) — a `RichText` wrapper that turns terms registered in `lib/services/glossary_service.dart` into tappable spans opening a `showModalBottomSheet` with the definition. ARB strings annotate jargon via `[[term:rente vieillesse LPP]]` markers. Inline expansion (sheet, not nav) per "1 screen = 1 intention" rule. Phase 10 ships the widget + glossary entries for any jargon surviving in `intent_screen` ARB keys after FK gate runs. Expected scope: 0-3 terms (intent screen is intentionally jargon-light).

- **D-10 — E2E golden path test technology.** `integration_test` package + `flutter test integration_test/onboarding_v2_golden_path_test.dart`. Test asserts: (a) launch → landing renders, (b) tap "Continuer" → intent screen renders within 1 frame, (c) tap first chip → /coach/chat renders within 1 frame, (d) screen-count between landing and chat = 2 (landing + intent), (e) `Stopwatch` from landing-rendered to chat-rendered < 20s on debug build (proxy for friction). Friction time is the test wallclock, not a perf gate (PERF baseline lives in Phase 12). Test file: `apps/mobile/integration_test/onboarding_v2_golden_path_test.dart`.

- **D-11 — Anti-shame copy gate on intent screen.** All intent chip labels and screen copy must pass the 6 anti-shame checkpoints. Phase 8c hot-fix already removed `intentChipBilan`, `intentChipPrevoyance`, `intentChipNouvelEmploi` from rendered chips (verified in current `intent_screen.dart` lines 65-94). Phase 10 re-verifies the surviving 5 chips + screen title/subtitle/microcopy against:
  1. No "commencer", "démarrer", "compléter ton profil"
  2. No "niveau débutant/intermédiaire/avancé"
  3. No curriculum framing ("ton parcours", "tes étapes")
  4. No retirement-default framing
  5. No "ton chiffre", "premier éclairage" in user-facing text (internal term only post Phase 1.5)
  6. MINT is sentence subject in negative statements
  Grep gate added to `tools/checks/no_shame_terms.py` (creates if absent).

## Deferred Ideas (NOT in Phase 10)

- Onboarding analytics funnel rebuild (post-launch, not pre-launch)
- Multi-step intent screen variants (A/B test) — single chip-list ships
- Voice-cursor "Ton" chooser on intent screen — that's VOICE-13, Phase 12
- BirthDate migration (replace `age: int` with `birthDate: DateTime`) — separate chantier from MEMORY.md, not Phase 10
- New ARB strings beyond what FK/jargon gates require

## Claude's Discretion

- Exact commit ordering within Plan 10-02 (preference: route removal → screen deletion → provider deletion → test migration → grep gate)
- Whether to keep `OnboardingChocType` enum (likely DELETE — `PremierEclairageType` post-1.5 is the canonical source; pre-audit confirms)
- Whether `intent_screen.dart` `_buildMinimalProfileFor` helper survives — yes if the merged path still computes premier_eclairage; verify in pre-audit

## Pre-Deletion State Inventory (preliminary — Plan 10-01 produces the authoritative one)

**OnboardingProvider holds:** `birthYear`, `grossSalary`, `canton`, `anxietyLevel`, `chocType`, `chocValue`, `emotion` (7 fields, 7 SharedPrefs keys).

**Known consumers (from grep):**
- `apps/mobile/lib/app.dart` (MultiProvider registration + post-Phase 1 STAB-19 wire)
- `apps/mobile/lib/screens/onboarding/instant_premier_eclairage_screen.dart` (writes choc + emotion — being DELETED)
- `apps/mobile/lib/screens/onboarding/promise_screen.dart` (writes anxietyLevel — being DELETED)
- Possibly: `landing_screen.dart` (Phase 7 rebuilt — verify it no longer reads OnboardingProvider)
- Possibly: `coach_profile_provider.dart` (hydration on first login — DocString claim, must verify)
- Possibly: `context_injector_service.dart` (DocString claim — must verify)

**Pre-audit (Plan 10-01) MUST produce:**
- Authoritative consumer list via `git grep -n 'OnboardingProvider\|onboarding_provider' apps/mobile/`
- Field-by-field migration verdict (migrate / drop)
- Pre-deletion `flutter test` count
- Test files importing deleted screens or provider (list)
- External deep-link audit (push notif templates, marketing emails, deeplink config) → confirms D-06 zero-shim default

## Routes to remove from GoRouter (in `app.dart`)

Per pre-audit confirmation, candidates:
- `/onboarding/quick-start`
- `/onboarding/promise`
- `/onboarding/plan`
- `/onboarding/premier-eclairage` (post Phase 1.5)
- `/premier-eclairage-instant` (post Phase 1.5)

Routes that REMAIN:
- `/onboarding/intent` (single onboarding step)
- `/onboarding/data-block-enrichment` (or whatever route exposes `data_block_enrichment_screen.dart` — JIT tool, D-02)

## Success Criteria Coverage Matrix

| ROADMAP §10 SC | Plan | Notes |
|---|---|---|
| SC1 — 5 screens + routes deleted, grep=0, no dangling refs | 10-02, 10-04 | 10-04 verifies. |
| SC2 — intent_screen routes to /coach/chat with payload | 10-02 | D-03 |
| SC3 — OnboardingProvider removed, state migrated, JIT preserved, test count ≥ pre | 10-01 (count + map), 10-02 (delete + migrate), 10-04 (verify) | D-04, D-05, D-07 |
| SC4 — E2E golden path test passes, screens=2, friction <20s | 10-03 | D-10 |
| SC5 — Flesch-Kincaid CI gate green, jargon tap-to-define present | 10-03 | D-08, D-09 |

Every ONB-01..10 + ACCESS-06 maps to a task. Decision coverage: full, no scope reduction.
