# Research Summary — v2.2 La Beauté de Mint (Design v0.2.3)

**Project:** MINT v2.2 La Beauté de Mint
**Domain:** Design + voice + accessibility retrofit over mature Flutter + FastAPI fintech codebase (12'892 tests, 18 life events, 8 calculators)
**Researched:** 2026-04-07
**Reports synthesized:** 6 (STACK, FEATURES, ARCHITECTURE, PITFALLS, ACCESSIBILITY, LANDING_AND_ONBOARDING)
**Confidence:** HIGH on architecture/pitfalls (grep-verified against live tree); MEDIUM on voice-level modulation (few-shot literature sparse); HIGH on landing/onboarding audit (line-cited); MEDIUM on accessibility practitioners (some URLs not re-verified end-to-end)

---

## 1. Milestone One-Liner

v2.2 is the last mile between "ça fonctionne" (v2.0/v2.1) and "on sent que c'est Mint" — a calm visual layer, a 5-level voice intensity dial, a unified confidence component on 11 rendering surfaces, and a rebuilt landing + onboarding flow that deletes 5 screens and routes directly to coach chat. The milestone is additive on stack (3 net-new dev-only deps), surgical on surface (S0–S5 only for AAA, ~11 projection screens for MTC), and blocking on two human-gated processes that must start on day one: live accessibility tester recruitment (6-week lead time) and regional voice validator recruitment (4-6 weeks).

---

## 2. Surfaces — 6 Immuables (Updated from 5)

S0 is the new addition, replacing the current `landing_screen.dart` which violates identity doctrine structurally (imports AVS/LPP/tax calculators, is a retirement quick-calc dressed in calm coral).

| Surface | File | Status | AAA target |
|---------|------|--------|-----------|
| **S0** | `apps/mobile/lib/screens/landing_screen.dart` | **REBUILD** (L1.7) | Yes |
| **S1** | `apps/mobile/lib/screens/onboarding/intent_screen.dart` | Audit + wire | Yes |
| **S2** | `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` | MTC migration only | Yes |
| **S3** | `apps/mobile/lib/widgets/coach/coach_message_bubble.dart` | Voice cursor + a11y | Yes |
| **S4** | `apps/mobile/lib/widgets/coach/response_card_widget.dart` | MTC + microtypographie | Yes |
| **S5** | `apps/mobile/lib/widgets/mint_alert_object.dart` | **CREATE NEW** (L1.5) | Yes |

S0 surfaces the fact that the "door" to MINT is broken before any design polish is applied. S5 is the only surface being created from scratch. S1–S4 are iteration targets on existing code.

---

## 3. Chantiers — 10 Total (Updated from 7)

The expert-approved P0 two-phase split and the L+O Variante 1 decision expand the original 7 chantiers to 10.

### P0a — Unblockers (5 deliverables, sequential gate, must ship before any L1.x starts)

| # | Deliverable | Owner | Blocks | File path |
|---|-------------|-------|--------|-----------|
| P0a.1 | Recruitment kickoff: 3 accessibility testers (malvoyant·e via SBV-FSA, ADHD via ASPEDAH, français-L2 via Caritas) + 3 regional validators (VS/ZH/TI). Send emails day 1. | Julien | L1.4 content + AAA live tests | `.planning/milestones/v2.2-phases/L1.0-accessibility-recruitment.md` |
| P0a.2 | STAB-17 manual tap-render walkthrough. Julien walks every primary-depth interactive element on Galaxy A14 (or simulator), fills `AUDIT_TAP_RENDER.md`, signs bottom block. | Julien | TestFlight gate | `.planning/phases/07-stabilisation-v2-0/AUDIT_TAP_RENDER.md` |
| P0a.3 | `chiffre_choc` → `premier_eclairage` rename sweep. 719 occurrences, 174 files: 5 Dart filenames (`git mv`), 2 Python filenames, 6 ARB × ~25 keys, GoRouter routes, class names, analytics events, OpenAPI endpoint, test files. ~13h. | Agent | L1.7, L1.8, all editorial work | Scope: `apps/mobile/lib/`, `services/backend/app/`, `apps/mobile/lib/l10n/`, tests |
| P0a.4 | Wire 4 broken providers in `mint_home_screen.dart`: `MintStateProvider`, `FinancialPlanProvider`, `CoachEntryPayloadProvider`, `OnboardingProvider`. Remove try/catch silent fallbacks (not just register — also remove the swallow). | Agent | L1.2b (MTC migration touches home screen) | `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` lines 124, 638 + `apps/mobile/lib/app.dart` MultiProvider |
| P0a.5 | Galaxy A14 perf baseline. `flutter run --profile -d <A14_id> --trace-startup`. Document cold start (target <2500ms), scroll FPS (target median ≥55), MTC bloom timing baseline (target 0 dropped frames over 250ms). | Julien | L1.2a bloom budget, L1.3 perf claim | `.planning/perf/A14_BASELINE.md` |

### P0b — Contracts and Audits (5 deliverables, can run parallel to L1.1 once P0a ships)

| # | Deliverable | Owner | Blocks | File path |
|---|-------------|-------|--------|-----------|
| P0b.1 | `VoiceCursorContract`: `tools/contracts/voice_cursor.json` (source of truth) + codegen to `apps/mobile/lib/services/voice/voice_cursor_contract.g.dart` + `services/backend/app/schemas/voice_cursor.py` + CI drift guard. | Agent | L1.5, L1.6 | `tools/contracts/`, `tools/codegen/voice_cursor_codegen.py`, `Makefile` |
| P0b.2 | `Profile.voiceCursorPreference` field: Pydantic v2 (`Literal['soft','direct','unfiltered'] = 'direct'`), CoachProfile Dart field (73 consumers), nullable SQLAlchemy column + read-time migration. | Agent | L1.6c | `services/backend/app/schemas/profile.py`, `apps/mobile/lib/models/coach_profile.dart` |
| P0b.3 | Krippendorff α tooling: `tools/voice-cursor-irr/` directory, `compute_alpha.py` (~30 LOC), `ratings.csv` template, `requirements.txt` (`krippendorff>=0.6.1`), README with protocol (15 testers × 50 phrases × N1-N5, weighted ordinal). | Agent | L1.6b validation gate | `tools/voice-cursor-irr/` |
| P0b.4 | `AUDIT_CONFIDENCE_SEMANTICS.md`: classify all ~40 confidence-rendering hits into 3 real semantic categories (`extraction-confidence`, `data-freshness`, `calculation-confidence`). Decide which category MTC absorbs vs. which needs a sibling component. This classification gates L1.2b scope. | Agent | L1.2b migration scope | `.planning/milestones/v2.2-phases/AUDIT_CONFIDENCE_SEMANTICS.md` |
| P0b.5 | `AUDIT_CONTRAST_MATRIX.md`: enumerate every text/background token pair across S0–S5, compute WCAG contrast ratios. Classify: AAA pass / AA-only / fail. Surface the 6 token upgrades needed (`textSecondaryAaa`, `warningAaa`, etc.). | Agent | L1.1 (knows what to fix before audit) + L1.3 (microtypographie uses same tokens) | `.planning/milestones/v2.2-phases/AUDIT_CONTRAST_MATRIX.md` |

### L1.1 — Audit du Retrait (S0–S5, -20% visual elements)

Source: FEATURES (Hara emptiness principle, Spiekermann one-color rule), PITFALLS (P5 confidence-semantics), ACCESSIBILITY (§3 Roselli AAA pragmatism).

Deliverables: remove 20% of visual elements on each of S0–S5; apply one-color-one-meaning rule (choose one desaturated amber token for "verifiable fact requiring attention", demote all others to neutral); use `AUDIT_CONFIDENCE_SEMANTICS.md` and `AUDIT_CONTRAST_MATRIX.md` (from P0b) as inputs. The L1.1 deliverable includes an explicit DELETE / KEEP list for all confidence rendering surfaces that feeds L1.2b on day 1.

Depends on: P0a complete, P0b.4 and P0b.5 shipped.
Parallel with: L1.2a, L1.4, L1.6a.

### L1.2a — MintTrameConfiance v1 Component + S4 Migration

Source: ARCHITECTURE (§B.1 grep-verified 18 consumers, §B.2 drop-in pattern), FEATURES (Linear hide-when-low-confidence, VZ hypotheses footer, MUJI 4-line grid), ACCESSIBILITY (§C bloom spec, `oneLineConfidenceSummary()` spec).

Three constructors: `MintTrameConfiance.inline()`, `.detail()`, `.audio()`. Mandatory states: bloom (250ms ease-out with `disableAnimations` fallback to 50ms opacity-only), `MTC.Empty(missingAxis)` (hide projection below floor, show missing-axis prompt instead), hypotheses footer slot (VZ pattern, 3-line max, visible at rest). `BloomStrategy` enum controls bloom in feed contexts (default `onlyIfTopOfList` in lists, `firstAppearance` in standalone). No `score: double` public getter (compliance: no sorting). `oneLineConfidenceSummary(EnhancedConfidence)` pure function with 24 ARB strings (4 weakest-axis × 6 languages). `SemanticsService.announce()` fires exactly once on state change.

Depends on: P0a.5 (bloom budget), P0b.4 (semantic classification).
Parallel with: L1.1, L1.4, L1.6a.

### L1.2b — MTC Migration (11 Rendering Surfaces)

Source: ARCHITECTURE (§B.1 — 18 total consumers, 11 are rendering surfaces, 7 are logic gates that stay untouched).

**Real count is 11, not 12 (brief said ~12).** Logic gates (`#1, #2 partial, #5, #8, #9, #15, #16`) stay reading the int — no visual change. Rendering surfaces: `confidence_score_card`, `confidence_banner`, `trajectory_view`, `futur_projection_card`, `coach_briefing_card`, `retirement_hero_zone`, `indicatif_banner`, `narrative_header` (8 pure renderers) + `retirement_dashboard_screen`, `cockpit_detail_screen`, `confidence_blocks_bar` (3 mixed). Each migration = 1-line widget replacement. PR gate: MTC-equivalent tests must match or exceed pre-migration test count. Checklist: `.planning/milestones/v2.2-phases/L1.2-MTC-MIGRATION-CHECKLIST.md` with `[ ] swapped [ ] tested [ ] goldens [ ] A14-verified` per surface.

Depends on: L1.2a shipped, L1.1 DELETE/KEEP list.
Parallel with: L1.3, L1.5.

### L1.3 — Microtypographie Pass (S1–S5) + MintColors *Aaa Tokens

Source: STACK (§7 AAA contrast helper), FEATURES (Spiekermann 4pt baseline grid, Aesop demote-the-number rule), ACCESSIBILITY (§9 MintColors delta, §D AAA token proposals).

Deliverables: apply 4pt baseline grid snap rule across S1–S5; line length 45–75 chars; 3 heading levels max; demote headline numbers to body weight on S4 (Aesop rule: sentence carries rhythm, not the number); add 6 AAA tokens to `colors.dart` (`textSecondaryAaa` #595960, `textMutedAaa` #5C5C61, `successAaa` #0F5E28, `warningAaa` #8C3F06, `errorAaa` #A52121, `infoAaa` #004FA3); migrate S0–S5 only to AAA tokens (no mass migration). Pastels (saugeClaire, bleuAir, pecheDouce, corailDiscret, porcelaine) = background-only, never information-bearing text in S0–S5.

**The Aesop + MUJI 4-line grammar for S4** (deliverable in this chantier, informed by L1.2a component design): (1) What this is, (2) What you're doing now, (3) What happens without change, (4) What you could do next. The MTC sits inline in line 3. Four lines, no chrome.

Depends on: L1.2a (component exists), P0a.5 (Galaxy A14 baseline to validate no regression), P0b.5 (contrast matrix).
Parallel with: L1.4, L1.6b.

### L1.4 — Voix Régionale VS/ZH/TI + Backend Dual-System Kill

Source: STACK (§5 two-gen-l10n pattern), ARCHITECTURE (§C.3 backend dual-system), PITFALLS (P11 recruitment, P12 dual-system trap).

Deliverables: 3 ARB files (`app_regional_vs.arb`, `app_regional_zh.arb`, `app_regional_ti.arb`) × ~30 keys; `l10n_regional.yaml` second gen-l10n config; extend `RegionalVoiceService.forCanton()` (~40 LOC); `regional_microcopy_codegen.py` (ARB → Pydantic dict) replaces hand-coded `REGIONAL_MAP` + `_REGIONAL_IDENTITY` constants in `claude_coach_service.py` (delete legacy constants in same MR — zero-debt rule); CI guard: any literal from `app_regional_vs.arb` in `claude_coach_service.py` = red build. Validation by 3 named native validators committed by end of P0a.1. Regional microcopy **overrides**, never **introduces** — every regional key has a base-language sibling.

Depends on: P0a.1 (validators recruited), ARB infra from P0b (or build inline here).
Parallel with: L1.2b, L1.3.

### L1.5 — MintAlertObject G2/G3 with Typed API

Source: FEATURES (Wise 3-part template, Stripe 5-part grammar), ARCHITECTURE (§E.1 — not a coach tool, receives from anticipation engine), ACCESSIBILITY (§B `liveRegion` for announcements).

API: `MintAlertObject({required Gravity gravity, required String fact, required String cause, required String nextMoment})`. Compiler-enforced — no arbitrary `String message`. MINT is always the subject ("MINT n'a pas pu", never "Tu n'as pas pu"). G2 = direct grammar in calm register. G3 = grammatical break + priority float in `ContextualCardProvider` ranking (1-line change in `card_ranking_service.dart`). G3 must persist until acknowledged (no auto-dismiss — COGA Pitfall). Imports `VoiceCursorContract.g.dart` for gravity→level routing. Not an LLM tool: fed by `AnticipationProvider` / `NudgeEngine` / `ProactiveTriggerService` (rule-based). `SemanticsService.announce()` on G2→G3 transitions. Patrol integration tests: 6 golden states.

Depends on: P0b.1 (VoiceCursorContract).
Parallel with: L1.2b, L1.3.

### L1.6 — Voice Pass: Curseur d'Intensité v1

Source: FEATURES (Headspace narrator wall, pacing/silence rules), PITFALLS (P1 tone-locking, P2 context bleeding, P3 N5 weekly cap, P8 precedence cascade, P9 ComplianceGuard at N4/N5), STACK (§1 Krippendorff tooling).

Three sub-chantiers:

**L1.6a — Spec doc + 50 phrases + routing matrix + garde-fous**
`docs/VOICE_CURSOR_SPEC.md`. Must include: 5-level definitions (N1–N5); gravity × relation routing matrix; precedence cascade (sensitivity guard → fragility cap → N5 budget → gravity floor → preference cap → matrix default — this ordering is mandatory per PITFALLS P8); narrator wall (explicit list of surfaces exempt from cursor routing: settings, error toasts, network failures, legal disclaimers); sentence-subject rule ("MINT n'a pas pu"); pacing/silence rules per level (line breaks, typing indicator pause); 50 reference phrases (10 per level), frozen pre-validation — no re-rolling; anti-examples per level (what N4 is NOT). Also: `resolveLevel(gravity, relation, preference, sensitiveFlag, fragileFlag, n5Budget) → N1..N5` pure function with 80+ unit tests.

**L1.6b — Rewrite 30 coach phrases + Krippendorff α validation**
30 most-used coach phrases rewritten per spec. Validation protocol: 15 testers × 50 phrase set (10 per level) × blind classification. Per-level α reported separately — aggregate α alone is insufficient. Target: overall α ≥ 0.67 weighted ordinal AND per-level N4/N5 α ≥ 0.67. **Generation-side test (critical anti-tone-locking measure):** 10 trigger contexts sent to Claude at N4, 10 generated outputs rated blind by same testers — if ≥30% classified as N2/N3, the system prompt is broken before shipping. N5 promoted to backend hard gate: `Profile.n5IssuedThisWeek` rolling counter, auto-downgrade to N4 when ≥1. Auto-fragility detector: ≥3 G2/G3 events in 14 days → auto-enter fragile mode (N3 cap, 30d) without self-declaration. ComplianceGuard extended with 50 adversarial N4/N5 phrases.

**L1.6c — User "Ton" setting in intent_screen + ProfileDrawer**
3-option chooser (`soft`/`direct`/`unfiltered`, default `direct`). Writes `Profile.voiceCursorPreference` via API. Imports `VoiceCursorContract.g.dart`. Patrol golden test: select-confirm-back round trip + assert persisted preference.

Depends on: P0b.1 (VoiceCursorContract), P0b.2 (Profile field), P0b.3 (Krippendorff tooling), L1.6a before L1.6b, L1.6b before L1.6c.
Critical path: P0b.3 → L1.6a → L1.6b → L1.6c is the longest chain in the milestone.

### L1.7 — Landing v2 (NEW — S0)

Source: LANDING_AND_ONBOARDING (§C.2 redesign spec), FEATURES (Wise "verb of use" pattern, Linear manifesto pattern).

**Rebuild, not iterate.** New file or complete rewrite of `landing_screen.dart`. Hard rules: zero financial_core imports, zero fields/inputs, zero projected numbers, zero retirement vocabulary. One screen, one idea, one action.

Layout: paragraphe-mère (~30 words) + primary CTA pill ("Continuer (sans compte)") + one privacy micro-phrase ("Rien ne sort de ton téléphone tant que tu ne le décides pas.") + legal footer. Only the `landingTransparency` paragraph from the existing screen survives as source inspiration.

Recommended paragraphe-mère (Variante A — mission verbatim, lowest risk): "Mint te dit ce que personne n'a intérêt à te dire. Sur tes assurances, ton 3a, ton salaire, ton bail, ton couple, tes impôts. Calmement. Sans te vendre quoi que ce soit." Test Variante C as split if Julien agrees.

Banned: "Commencer", "Démarrer", "Voir mon chiffre", "Ton chiffre en X secondes", trust-bar SaaS badges (keep only one honest privacy phrase), hidden-amount dark pattern.

Depends on: P0a.3 (chiffre_choc sweep, else the routes it links to have legacy names).
Parallel with: L1.1, L1.2a, P0b items.

### L1.8 — Onboarding v2 (NEW — deletes 5 screens)

Source: LANDING_AND_ONBOARDING (§B.2 dual-pipeline audit, §C.3 Variante 1 spec).

**Decision locked: Variante 1 — 3 screens replacing 8.**

New golden path: `S0 landing → /onboarding/intent (1 chip) → coach chat (JIT data collection in-conversation)`.

**Delete these 5 screens + their routes:**
- `instant_chiffre_choc_screen.dart` + route `/chiffre-choc-instant`
- `chiffre_choc_screen.dart` + route `/onboarding/chiffre-choc`
- `quick_start_screen.dart` + route `/onboarding/quick-start`
- `promise_screen.dart` + route `/onboarding/promise`
- `plan_screen.dart` + route `/onboarding/plan`

**Wire S1 (intent_screen) directly to coach chat:** `_isFromOnboarding == true` branch routes to `/coach/chat` with chip payload, not to `/onboarding/quick-start`. Remove `chiffre_choc_selector` import (L15 of current `intent_screen.dart`). Fix the `chiffre_choc_screen` split-exit bug (coach-path bypass of `setMiniOnboardingCompleted` — P0a.2 STAB-17 should surface this).

**Deprecate `OnboardingProvider`:** migrate its state to `CoachProfileProvider` + `CapMemoryStore`. `data_block_enrichment_screen.dart` is NOT deleted (it's a JIT deep-link tool, not part of the onboarding pipeline).

**Remove age-segmentation from `promise_screen`** (it violated CLAUDE.md §1 "never by age" — moot once screen is deleted). Verify `app.dart` GoRouter guards don't route post-login users into the deleted screens.

Depends on: L1.7 (landing must exist before onboarding flow has a starting point), P0a.3 (rename sweep).
Parallel with: L1.3, L1.4, L1.5.

---

## 4. Stack Additions

3 net-new dev-only dependencies. The shipped APK and FastAPI service get zero new runtime deps.

| Package | Type | Purpose | Chantier | Version |
|---------|------|---------|---------|---------|
| `patrol: ^4.1.1` | Dart dev_dependency | E2E + native interaction tests (TalkBack pop-ups, voice cursor preference persistence) | L1.5, L1.2a | `^4.1.1`; requires `patrol_cli` global + 3-line CI step |
| `krippendorff>=0.6.1` | Python tools-only (isolated venv in `tools/voice-cursor-irr/`) | Weighted ordinal IRR for L1.6b validation | L1.6b | Isolated, NOT in `pyproject.toml` |
| `datamodel-code-generator>=0.25` | Python dev dependency | JSON Schema → Pydantic v2 for VoiceCursorContract codegen | P0b.1 | `pyproject.toml [dev]` |

**No new runtime deps.** AAA contrast helper = 30 LOC pure Dart, no package. ARB regional namespace = second `gen_l10n` config, no package. Galaxy A14 perf = `flutter --profile` + DevTools (already in SDK). Firebase Test Lab = deferred to v2.3 (MEDIUM confidence on Galaxy A14 catalog availability at v2.3 kickoff — must confirm via `gcloud firebase test android models list`).

---

## 5. Features: Table Stakes / Differentiators / Anti-Features

### Table Stakes (must ship — v2.2 is incomplete without these)

- MTC v1 component (4-axis renderer, `MTC.Empty()` state, bloom, 1-line audio)
- MTC migration on 11 rendering surfaces (dual-system kill)
- MintAlertObject typed API (fact/cause/nextMoment)
- Voice cursor 5-level spec + 50 reference phrases + narrator wall + sentence-subject rule
- Voice cursor user setting "Ton" (soft/direct/unfiltered)
- Microtypographie pass S0–S5 + 4pt baseline grid
- Audit du retrait -20% on S0–S5 + one-color-one-meaning rule
- Voix régionale VS/ZH/TI (30 microcopies × canton, backend dual-system kill)
- Phase 0 stabilisation gate (STAB-17, A14 baseline, VoiceCursorContract, rename sweep, broken providers)
- Hypotheses footer on every projection (VZ pattern — 3 lines max, visible at rest)
- AAA tokens for S0–S5 (6 new token variants, pastels background-only)
- Landing v2 rebuild (zero financial_core imports, zero fields)
- Onboarding v2 (3 screens, 5 deleted)
- `AUDIT_CONFIDENCE_SEMANTICS.md` classification before MTC migration
- N5 weekly cap promoted to backend hard gate
- Auto-fragility detector (≥3 G2/G3 in 14 days)

### Differentiators (genuinely net-new vs. all 10 practitioners surveyed)

- **Voix régionale VS/ZH/TI**: no fintech app does this anywhere — risk: native validator recruitment is the schedule constraint
- **Voice cursor 5 levels with Krippendorff α ≥ 0.67**: Cleo has modes, nobody has measured IRR on the assignment; risk: model may tone-lock at N2-N3 (Pitfall 1)
- **MintTrameConfiance 4-axis** (completeness × accuracy × freshness × understanding): VZ uses columns, Linear hides, nobody renders 4 axes with a bloom — risk: audio-1-line version is hard (Pitfall 7)
- **Focus mode (ambient dim at N4/N5)** — Reichenstein iA Writer lesson: dim the surround, not the text; honors "le visuel ne change jamais"; **classified as stretch goal** pending Galaxy A14 perf gate on animating shell opacity

### Anti-Features (do NOT build for v2.2)

| Anti-feature | Why requested | What to do instead |
|---|---|---|
| Skin/color shift on cursor levels (Cleo-style) | Cleo does it | Reichenstein focus-mode dim (stretch) or nothing |
| MTC bloom for all 11 surfaces simultaneously | "Consistent" | `BloomStrategy.onlyIfTopOfList` in feeds |
| Voice cursor applied to error toasts / settings / legal | "Consistency" | Narrator wall — exemption list in L1.6a spec |
| Confidence rendered always (no floor) | "Show our work" | `MTC.Empty(missingAxis)` below floor threshold |
| MintAlertObject with free-form `String message` | "Flexibility" | Typed API: `fact / cause / nextMoment` |
| Multiple accent colors as hierarchy | "Design richness" | One color, one meaning (Spiekermann) |
| Quick-calc on landing | "First value fast" | The conv IS the first value — Headspace/VZ pattern |
| `plan_screen` 4 hardcoded steps regardless of intent | "Onboarding closure" | Delete it; coach chat IS the plan |
| "ADHD mode" toggle | "Inclusive" | Fix the default; adding a mode confesses the default is bad |
| Lock Screen widget | Engagement | Galaxy A14 floor, iOS only, brief cut |
| Firebase Test Lab in v2.2 CI | Automation | Deferred v2.3, manual gate by Julien this milestone |

---

## 6. Architecture

### VoiceCursorContract

Single JSON source of truth at `tools/contracts/voice_cursor.json` (not in mobile, not in backend). Codegen → `apps/mobile/lib/services/voice/voice_cursor_contract.g.dart` (Dart const enums) + `services/backend/app/schemas/voice_cursor.py` (Pydantic). CI drift guard: regenerate + `git diff --exit-code`. Both generated files committed (offline-safe). 6 Dart consumers + 2 Python consumers (grep-verified).

### MTC Migration — 18 Consumers, 11 Rendering Surfaces

**Critical: ARCHITECTURE.md grep-verified 18 consumers total, not ~12 as the brief states.** The 18 split into:
- 11 rendering surfaces (must migrate) — listed in L1.2b above
- 7 logic gates that only read `confidence.combined` int (must NOT migrate — leave untouched)

The "confidence is not 1:1 semantically" finding (PITFALLS P5, ARCHITECTURE §B.1) means: `AUDIT_CONFIDENCE_SEMANTICS.md` (P0b.4) must classify each surface before migration. Surfaces rendering data-freshness are NOT the same as surfaces rendering calculation-confidence — merging them into MTC silently destroys information.

### 4 Broken Providers (Extends STAB-17 Scope)

`mint_home_screen.dart` currently reads `MintStateProvider`, `FinancialPlanProvider`, `CoachEntryPayloadProvider`, and `OnboardingProvider` via try/catch silent fallback (lines 124, 638 and related). These were carryover from v2.1 AUDIT_DEAD_CODE. P0a.4 must both register providers in `app.dart` MultiProvider AND remove the try/catch swallow — registering alone is insufficient (the façade stays if the swallow remains). This is why P0a.4 is a P0a blocker, not a later chantier: L1.2b migrating the home screen on top of a try/catch fallback = building on sand.

### Regional Voice — Single Source of Truth

**Current state is a pre-existing dual system.** `claude_coach_service.py:58` defines `REGIONAL_MAP` and `claude_coach_service.py:133` defines `_REGIONAL_IDENTITY` as hard-coded Python strings. `RegionalVoiceService.forCanton()` exists in Flutter. L1.4 adds `app_regional_<canton>.arb`. Decision: ARB files own static microcopy; backend system prompt owns dynamic-generation tone hints (references regional register, does not duplicate strings). L1.4 MR is rejected unless `git grep 'REGIONAL_MAP\s*=' services/backend/` returns 0.

### Build Order DAG (Updated with L+O Scope + P0 Split)

```
P0a (sequential gate)
  P0a.1 (recruitment emails, day 1)
  P0a.2 (STAB-17 walkthrough, Julien)
  P0a.3 (chiffre_choc rename, ~13h)
  P0a.4 (wire 4 broken providers)
  P0a.5 (A14 perf baseline, Julien)
        │
        └──────────────────────────────────────────────────────┐
                                                               │
P0b (parallel to L1.1 once P0a ships) ────────────────────────┤
  P0b.1 VoiceCursorContract ──────────────────────────────┐   │
  P0b.2 Profile.voiceCursorPreference ────────────────┐   │   │
  P0b.3 Krippendorff tooling ──────────────────────┐  │   │   │
  P0b.4 AUDIT_CONFIDENCE_SEMANTICS ──────────────┐ │  │   │   │
  P0b.5 AUDIT_CONTRAST_MATRIX ────────────────┐  │ │  │   │   │
                                              │  │ │  │   │   │
GROUP α (parallel after P0a, P0b.4, P0b.5):  │  │ │  │   │   │
  L1.1 Audit du retrait ─────────────────────┘  │ │  │   │   │
  L1.2a MTC component ──────────────────────────┘ │  │   │   │
  L1.4 Regional content ──────────────────────────┘  │   │   │
  L1.6a Voice cursor spec ──────────────────────────────┐ │   │
  L1.7 Landing v2 ─────────────────────────────────────── │   │
                                                         │ │   │
GROUP β (after GROUP α):                                 │ │   │
  L1.2b MTC migration ×11 (needs L1.2a + L1.1 list)    │ │   │
  L1.3 Microtypographie + AAA tokens (needs L1.2a)      │ │   │
  L1.5 MintAlertObject (needs P0b.1) ────────────────────┘ │   │
  L1.6b Phrase rewrite + Krippendorff α (needs L1.6a, P0b.3) ┘   │
  L1.8 Onboarding v2 (needs L1.7 + P0a.3) ────────────────────────┘
                                           │
GROUP γ (after GROUP β):                   │
  L1.6c "Ton" setting (needs L1.6b + P0b.2)
                                           │
v2.2 ship gate: Julien Galaxy A14 manual + 3 live a11y sessions
                (a11y sessions require L1.3 + S5 landed for anything meaningful)
```

**Critical path:** P0a → P0b.1 → L1.6a → L1.6b → L1.6c. Bottleneck is L1.6b: 50 phrases × 15 testers + generation-side test = 5–7 working days of coordination. L1.7 + L1.8 can absorb schedule slip without affecting voice critical path.

---

## 7. Top 10 Pitfalls (Ranked by Likelihood × Severity)

| Rank | Pitfall | L×S | Owns | Prevention |
|------|---------|-----|------|-----------|
| 1 | **Tone-locking** — Claude produces polite N2 regardless of N4/N5 prompt (RLHF base distribution) | HIGH×HIGH | L1.6a + L1.6b | Few-shot examples (3 verbatim N4 per system prompt) + anti-examples + generation-side reverse-Krippendorff test + default cap at N3 until verified |
| 2 | **N5/ComplianceGuard gap** — piquant register drifts into prescription without tripping ComplianceGuard's regex filters | HIGH×HIGH | L1.6a + L1.6b | Extend ComplianceGuard with 50 adversarial N4/N5 phrases + register-aware imperative-without-hedge rule |
| 3 | **MTC migration breaks ~40 tests silently** — removing legacy badge removes its tests, coverage drops invisibly, green CI is not coverage | HIGH×MEDIUM | L1.2a (scaffold before L1.2b) | Pre-migration lcov baseline; PR gate requires MTC-equivalent tests; migration checklist per surface |
| 4 | **MTC is not 1:1 semantically** — 3 distinct confidence concepts (extraction, freshness, calculation) collapsed into one visual without an `AUDIT_CONFIDENCE_SEMANTICS.md` decision | HIGH×MEDIUM-HIGH | P0b.4 + L1.1 | Classify all ~40 consumers before any migration; if sibling component needed, spec it in L1.2a |
| 5 | **N5 weekly cap is editorial, not technical** — fragile users in crisis get 4 N5 messages in 3 days; each is correct in isolation | HIGH×HIGH | L1.6a (spec) + L1.6b (backend) | Hard backend gate: `Profile.n5IssuedThisWeek` + auto-fragility detector (≥3 G2/G3 in 14 days → N3 cap 30 days, no self-declaration required) |
| 6 | **Context bleeding** — G3/N5 turn poisons the next G1 turn via LLM context window | HIGH×MEDIUM | L1.0 + L1.6c (backend) | Rebuild system prompt fresh each turn; explicit register-reset clause; `[N5]` tag in conversation history; visual breath separator on G3→G1 |
| 7 | **MTC bloom jitter in scrollable feed** — 6-8 cards blooming simultaneously on Galaxy A14 = <40fps | MEDIUM-HIGH×MEDIUM | L1.2a | `BloomStrategy` enum; default `onlyIfTopOfList` in feed contexts; stagger 60ms; honor `disableAnimations` |
| 8 | **AAA contrast vs. brand pastels** — WCAG 7:1 forces darker text, pastels and 7:1 are near-opposite goals | HIGH×MEDIUM | L1.1 + L1.3 | `AUDIT_CONTRAST_MATRIX.md` first; 6 new AAA tokens; pastels = background-only in S0–S5 |
| 9 | **Accessibility + regional recruitment is the real schedule risk** — 6-week lead time for a malvoyant·e tester; if it starts at L1.6, sessions arrive post-close | HIGH×MEDIUM-HIGH | P0a.1 | Emails to SBV-FSA + ASPEDAH + Caritas on day 1 of Phase 0; budget CHF 800–2'000; if recruitment fails by end of L1.1, descope AAA to "AA bloquant + AAA aspirational" honestly |
| 10 | **chiffre_choc partial rename** — 719 occurrences in 174 files, half already renamed in some layers, Pydantic `populate_by_name` accepts both silently | HIGH×LOW-MEDIUM | P0a.3 | Single sweep PR; CI grep gate returning 0 in `lib/`, `app/`, `l10n/` (allowed in `.planning/`, `docs/archive/`) |

Additional flags for planner: Pitfall 8 (precedence cascade ambiguity in routing matrix), Pitfall 15 (editorial drift post-validation — add ARB `@meta level:` annotation gate), Pitfall 17 (sample size 30 → spec 50 phrases, freeze pre-validation), Pitfall 19 (Phase 0 bloat — hard cap 5 deliverables, 2-week budget).

---

## 8. Accessibility Reality

**AAA on S0–S5 is achievable but non-trivial.** Honest estimate from ACCESSIBILITY research:

| Surface | AA → AAA work | Estimate |
|---------|--------------|---------|
| S0 Landing (new) | Build AAA from day 1; no text contrast debt if using new AAA tokens | 1 day |
| S1 intent_screen | Persistent labels, reading-level pass, jargon tap-to-define, voice cursor dropdown semantics | 2–3 days |
| S2 mint_home_screen | Card semantics tree; 7:1 on every metric; alt text on ~40 illustrations; reading level | 3–4 days |
| S3 coach_message_bubble | `liveRegion` for incoming messages; 7:1; reduced-motion typing indicator | 2 days |
| S4 response_card + MTC | MTC bloom `oneLineConfidenceSummary()` + announce(); CustomPaint semanticsBuilder; 7:1 | 4–5 days |
| S5 MintAlertObject (new) | Build AAA from day 1: G2/G3 announce, no auto-dismiss, 7:1, TalkBack 13 | 3 days |

**Total: ~14–17 dev days for AAA on S0–S5** + 3 days palette delta + 5 days live test sessions + remediation. Round to **4 weeks of focused time**, parallelizable with L1.2a/b.

**MintColors palette delta:** 6 tokens need darker AAA variants (listed in §3 L1.3). Pastels (saugeClaire, bleuAir, pecheDouce, corailDiscret) = background-only in S0–S5, never information-bearing. Brand character preserved (delta is 12–18% lighter, hue unchanged). Requires Julien sign-off on brand willingness before L1.1 work starts.

**Open questions for Julien (decision gates for accessibility):**
1. **Brand sign-off on palette delta** — darkening textSecondary/success/warning/error/info ~15% for AAA on S0–S5. Gate for L1.1 and L1.3.
2. **Access for All audit?** (Swiss certification body, Zürich, CHF 8–18k for 5 screens + remediation report). Not required for v2.2 but is the only recognized Swiss accessibility credential. Decision needed before TestFlight.
3. **AAA honesty gate** — if tester recruitment fails by end of L1.1, descope explicitly to "AA bloquant CI + AAA aspirational with known gaps documented". False AAA claim is worse than honest AA.
4. **SC 3.1.5 reading-level approach** — "rente vieillesse LPP" cannot pass B1. Approach: tap-to-define inline expansion. Must decide before L1.1 write-phase.
5. **TalkBack 13 on real Galaxy A14** — all 7 widget traps (CustomPaint, IconButton without tooltip, InkWell/GestureDetector, AnimatedSwitcher, TextField obscureText, DropdownMenu) require real device verification, not emulator. STAB-17 walkthrough (P0a.2) should fold in a TalkBack pass.

---

## 9. Landing and Onboarding Pivot

**Verdict from LANDING_AND_ONBOARDING research (HIGH confidence — all findings are line-cited against the actual files):**

Five findings that together mandate a rebuild, not an iteration:

1. **Parallel pipelines (structural):** Two completely separate onboarding flows (path A: intent → quick-start → chiffre-choc → plan; path B: landing quick-calc → instant-chiffre-choc → promise → login) are glued at `promise_screen` and never converge. Path A and path B are two products in one folder.

2. **Age segmentation violation:** `promise_screen` segments body copy into 3 age brackets (<25 / 25-34 / 35+), directly violating CLAUDE.md §1 ("NEVER by age"). Moot once screen is deleted.

3. **`plan_screen` is a façade:** `_stepsForIntent()` returns the same 4 hardcoded steps regardless of the intent chip chosen. The comment in the file says "Future: customize per intent." This is the façade-sans-câblage pattern v2.1 spent a whole audit wave killing, now on the entry flow.

4. **`chiffre_choc_screen` split-exit bug:** The coach-path button (arrow in TextField) routes to `/coach/chat` without calling `setMiniOnboardingCompleted(true)`. On next app start, user is re-routed to onboarding. Confirmed bug.

5. **719 occurrences / 174 files:** The `chiffre_choc` → `premier_eclairage` rename was done in some UI strings but not in filenames, routes, class names, analytics events, or backend API paths. The partial rename has created a dual-vocabulary layer that Pydantic `populate_by_name` silently accepts.

**Variante 1 action plan (user-locked decision):**

New golden path: `S0 → S1 (1 chip) → coach chat`. Three screens. Friction: 15 seconds, 1 chip input. Delete 5 screens + 5 routes + `OnboardingProvider`. Wire S1 directly to coach chat with chip payload. `data_block_enrichment_screen.dart` survives (it's the JIT deep-link mechanism, not part of the pipeline).

---

## 10. Build Order Recommendations for Roadmapper

**Phase 0a** = sequential gate, no design work starts until complete. Must start immediately; recruitment (P0a.1) is the longest lead-time item (6 weeks). STAB-17 (P0a.2) is already scaffolded — Julien just needs to sit down with a device.

**Phase 0b** = parallel to L1.1 once P0a ships. VoiceCursorContract (P0b.1) gates L1.5 + L1.6. The audits (P0b.4, P0b.5) gate L1.2b and L1.1 respectively.

**L1.7 (Landing v2)** has no dependencies beyond P0a.3 (rename sweep). It can start early and is low-risk: zero financial_core imports = zero compliance risk = no compliance review needed beyond the usual disclaimer check.

**L1.8 (Onboarding v2)** depends on L1.7 (landing must link somewhere valid). It is the right moment to also deprecate `OnboardingProvider`.

**L1.1 (audit du retrait)** should ship its DELETE/KEEP list before L1.2b touches a single consumer. L1.1 is a reading chantier, not a writing chantier — it produces a list and a contrast matrix verdict.

**L1.2a before L1.2b** is a hard dependency. No surface should be migrated before the component exists and its API is stable.

**L1.6a before L1.6b before L1.6c** is sequential by design. L1.6b cannot validate phrases that don't match a frozen spec. L1.6c cannot ship a setting that has no validated spec behind it.

---

## 11. Open Questions for Julien (Decision Gates)

Each question is tagged with the chantier it blocks.

| # | Question | Blocks | Expert Recommendation |
|---|----------|--------|----------------------|
| 1 | **Landing paragraphe-mère:** Variante A (mission verbatim) vs. Variante C (NOT a retirement app — the "liste négative")? | L1.7 copy | Start with Variante A (lower risk, doctrine-aligned); prepare Variante C as a split test for web landing only |
| 2 | **Brand palette sign-off:** Accept darkening 6 tokens ~15% for AAA on S0–S5? | L1.1 + L1.3 | Accept. Delta is imperceptible to most users; compliance and EU EAA exposure outweigh the aesthetic cost |
| 3 | **Access for All audit?** (CHF 8–18k, 6–8 week lead, Swiss accessibility certification) | v2.2 ship positioning | Worth it if you plan to market AAA publicly. If the 3 live sessions are already the evidence, skip the formal cert for v2.2, schedule v2.3 |
| 4 | **N5 generation-side test consent:** Are the 15 Krippendorff testers the same people who do the generation-side reverse test? | L1.6b | Yes — same testers, but second pass on generated output (not the pre-written phrases). Run the generation test first, before revealing the pre-written validation set |
| 5 | **VZ app teardown:** Julien screenshots 5 VZ screens (tax estimate, retirement projection, alert, scenario comparison, confidence display) to verify the hypotheses footer pattern before the L1.2a API is finalized? | L1.2a API design | Yes, worth 1 hour before locking the hypotheses footer component spec |
| 6 | **Focus mode (ambient dim at N4/N5):** Stretch goal or must-ship? | L1.6 scope | Stretch goal. Gate on Galaxy A14 perf (animating shell opacity at N4+ is the risk). If A14 baseline (P0a.5) shows headroom after MTC bloom, promote to GROUP β. Otherwise document for v2.3. |
| 7 | **`OnboardingProvider` deprecation:** Who owns the migration to `CoachProfileProvider` + `CapMemoryStore`? | L1.8 | Agent-executable once L1.8 scope is confirmed. The provider has state used by `instant_chiffre_choc_screen` (deleted in L1.8) — once those screens are gone, the provider's only remaining consumers should be trivially migratable. |

---

## 12. Metric Targets

| Metric | Target | Gate |
|--------|--------|------|
| Krippendorff α overall (50 phrases, 15 testers, weighted ordinal) | ≥ 0.67 | L1.6b ship |
| Krippendorff α per level N4 and N5 separately | ≥ 0.67 each | L1.6b ship |
| Generation-side classification: N4 outputs rated N4 by testers | ≥ 70% | L1.6b ship (else prompt broken) |
| Phrases classified G3 → routed to N1/N2 | 0 | ComplianceGuard |
| Sensitive topics receiving N4/N5 | 0 | ComplianceGuard + VoiceCursorContract |
| WCAG contrast on S0–S5 text/icon pairs | ≥ 7:1 (AAA) | L1.3 CI test |
| WCAG contrast on all other app surfaces touched | ≥ 4.5:1 (AA) | CI flutter test |
| cold start `timeToFirstFrameMicros` on Galaxy A14 | < 2500ms | P0a.5 + L1.2b merge gate |
| Scroll FPS on Aujourd'hui home (10s) | median ≥ 55, p95 ≥ 50 | P0a.5 + L1.2b merge gate |
| MTC bloom frames on Galaxy A14 (250ms = 16 frames at 60fps) | 0 dropped | L1.2a merge gate |
| `chiffre_choc` occurrences in `lib/`, `app/`, `l10n/` | 0 | P0a.3 CI gate |
| Legacy confidence rendering (`confidenceScore.toStringAsFixed(0)` outside MTC) | 0 | L1.2b CI grep |
| MTC instantiations without explicit `BloomStrategy` | 0 | Custom lint |
| N5 messages per user per rolling 7 days | ≤ 1 | Backend hard gate |
| Screens before first insight (new golden path) | 2 (landing + intent) | L1.8 E2E test |

---

## 13. Requirements Hint — Suggested REQ-ID Categories

For the roadmapper and requirements step:

| Category | Scope | Example REQ-IDs |
|----------|-------|----------------|
| `STAB` | Stabilisation carryover (STAB-17, broken providers, rename) | STAB-17-walkthrough, STAB-providers-wire |
| `CONTRACT` | VoiceCursorContract, Profile field, codegen, CI drift guard | CONTRACT-voice-cursor-json, CONTRACT-voice-pref-profile |
| `AUDIT` | AUDIT_CONFIDENCE_SEMANTICS, AUDIT_CONTRAST_MATRIX, retrait -20% | AUDIT-confidence-semantics, AUDIT-contrast-s0-s5 |
| `MTC` | MintTrameConfiance component + 11-surface migration | MTC-component-v1, MTC-migrate-score-card |
| `AESTH` | Microtypographie, AAA tokens, one-color rule, 4pt grid | AESTH-baseline-grid, AESTH-aaa-tokens-6 |
| `VOICE` | Voice cursor spec, 50 phrases, Krippendorff, narrator wall | VOICE-spec-doc, VOICE-irr-validation |
| `ALERT` | MintAlertObject S5 with typed API | ALERT-component-g2, ALERT-typed-api |
| `TRUST` | Hypotheses footer, sentence-subject rule, hide-when-low | TRUST-hypotheses-footer, TRUST-mtc-empty-state |
| `LAND` | Landing v2 rebuild | LAND-rebuild-no-financialcore, LAND-paragraphe-mere |
| `ONB` | Onboarding v2 (delete 5 screens, wire intent→chat) | ONB-delete-5-screens, ONB-wire-intent-chat |
| `ACCESS` | AAA on S0–S5, TalkBack 13 fixes, live test sessions, palette | ACCESS-aaa-s4-mtc-announce, ACCESS-talkback-iconbutton |
| `REGIONAL` | VS/ZH/TI ARB carve-out, backend dual-system kill | REGIONAL-arb-vs-30keys, REGIONAL-backend-kill-map |
| `PERF` | Galaxy A14 baseline, bloom strategy in feeds | PERF-a14-baseline, PERF-bloom-strategy-feeds |

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack additions | HIGH | All 3 deps verified against live registries (pub.dev, PyPI, GitHub). Zero runtime deps confirmed. |
| Features | HIGH on table stakes; MEDIUM on differentiators | Practitioner sources HIGH (Linear, Aesop, Stripe, Spiekermann documented); Headspace/Notion MEDIUM (behavioral specifics require app teardown). Notion 2025 quiet UI changes LOW — flag for v3.0 only. |
| Architecture | HIGH | All consumer counts grep-verified against live tree. 18 consumers confirmed (not ~12). 4 broken providers confirmed. Backend REGIONAL_MAP confirmed present. |
| Pitfalls | HIGH on codebase-specific (grep-verified); MEDIUM on tone-locking literature (sparse prior art, RLHF dynamics are documented but model-version-dependent) | |
| Accessibility | MEDIUM-HIGH | Swiss org URLs verified; practitioner theses well-established; A14 TalkBack traps are Flutter-issue-number-cited. |
| Landing/onboarding | HIGH | All findings line-cited against actual Dart files. 719-occurrence count grep-verified. |
| Overall | HIGH | |

### Gaps to Address

- **Notion 2024-2025 "quiet UI"**: LOW confidence on 2025 specifics. Flagged as v3.0 input only; do not promote to v2.2 requirements.
- **VZ app in-screen behavior**: MEDIUM. Julien's 5-screenshot teardown (open question #5) needed before finalizing hypotheses footer API in L1.2a.
- **tone-locking on Claude Sonnet specifically**: General RLHF literature is well-established, but MINT runs Claude Sonnet (not fine-tuned). The generation-side reverse-Krippendorff test in L1.6b is the live validation. No pre-migration certainty is possible.
- **Galaxy A14 actual availability**: Device is confirmed as the floor. Perf claims (scroll FPS, bloom frames) cannot be verified until P0a.5 runs.

---

## Sources

### HIGH confidence
- STACK.md — all 7 tooling decisions verified against live registries 2026-04-07
- ARCHITECTURE.md — all 18 confidence consumer claims grep-verified against live tree
- PITFALLS.md — codebase-specific pitfalls grep-verified; RLHF literature well-cited
- LANDING_AND_ONBOARDING.md — findings line-cited against actual Dart files
- ACCESSIBILITY.md — TalkBack traps are Flutter GitHub issue-cited (#147045, #148230, #133742, #99763, #76108)
- W3C WCAG 2.1 (wcag.com) — contrast ratios, AAA SCs
- `apps/mobile/lib/theme/colors.dart` — MintColors palette delta computed directly
- STAB carryover snapshot (`.planning/backlog/STAB-carryover.md`) — 16/17 done, STAB-17 manual gate pending

### MEDIUM confidence
- FEATURES.md practitioners (VZ, Wise, Headspace) — public site HIGH, in-app behavior MEDIUM; requires Julien teardown to verify behavioral specifics
- ACCESSIBILITY.md — Access for All specifics are URL-cited; Adrian Roselli back-catalogue partially verified

### LOW confidence (do not promote to v2.2 requirements)
- Notion "quiet UI" 2024-2025 — post-cutoff; v3.0 input only
- Firebase Test Lab Galaxy A14 catalog — requires runtime confirmation at v2.3 kickoff via `gcloud firebase test android models list`

---

*Research synthesized: 2026-04-07*
*Reports: STACK.md (7 tooling items, 3 net-new deps), FEATURES.md (10 practitioners, table stakes/differentiators/anti-features), ARCHITECTURE.md (3 contracts, 18-consumer grep, DAG), PITFALLS.md (20 pitfalls ranked), ACCESSIBILITY.md (AAA reality, 6-week recruitment, palette delta), LANDING_AND_ONBOARDING.md (5 critical findings, Variante 1 spec)*
*Ready for roadmap: yes*
