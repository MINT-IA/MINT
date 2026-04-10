---
phase: "02-p0b-contracts-and-audits"
type: context
milestone: v2.2 La Beauté de Mint (Design v0.2.3)
branch: feature/v2.2-p0a-code-unblockers
depends_on: [Phase 1 p0a, Phase 1.5 chiffre_choc rename]
unblocks: [Phase 4 MTC (AUDIT-01), Phase 5 Voice Spec full (VOICE_CURSOR_SPEC v0.5), Phase 7 Landing v2 (AESTH-04 AAA tokens), Phase 8a MTC migration (AUDIT-01 + AUDIT-02), Phase 9 MintAlertObject (CONTRACT-01..06), Phase 11 Voice validation (CONTRACT-05 Profile fields + Krippendorff tooling)]
requirements:
  [
    CONTRACT-01, CONTRACT-02, CONTRACT-03, CONTRACT-04, CONTRACT-05, CONTRACT-06,
    AUDIT-01, AUDIT-02,
    AESTH-04
  ]
---

# Phase 2 — P0b: Contracts & Audits + AAA Tokens + Voice Cursor Spec v0.5

## Why This Phase Exists

Phase 2 lands **foundations that every later phase reads**: the VoiceCursorContract single source of truth (consumed by Phase 5 spec, Phase 9 MintAlertObject, Phase 11 validation), the 6 AAA tokens (consumed by Phase 7 Landing v2 "AAA from day 1" LAND-05 and Phase 8b S0-S5 migration), the Profile voice fields (consumed by Phase 11 server gates VOICE-09/VOICE-10), the v0.5 voice spec extract (tonal anchor for Phase 4 MTC audio strings), and the two pre-migration audits (gate Phase 3 L1.1 DELETE/KEEP list and Phase 4 MTC scope).

No user-facing UI ships in Phase 2. The single **human-gated** moment is the 6 AAA token **brand sign-off by Julien** before the colors land in `colors.dart`. Everything else is code + docs + tools.

## Canonical Refs (absolute paths)

- Roadmap entry: `/Users/julienbattaglia/Desktop/MINT/.planning/ROADMAP.md` §Phase 2 (lines 85–99)
- Requirements (source of truth for hex values + behavior): `/Users/julienbattaglia/Desktop/MINT/.planning/REQUIREMENTS.md` §CONTRACT-01..06, §AUDIT-01..02, §AESTH-04 (line 78)
- Research synthesis: `/Users/julienbattaglia/Desktop/MINT/.planning/research/SUMMARY.md`
- Project state: `/Users/julienbattaglia/Desktop/MINT/.planning/PROJECT.md`
- Phase 1.5 rename summary (premier_eclairage vocabulary now clean): `/Users/julienbattaglia/Desktop/MINT/.planning/phases/01.5-chiffre-choc-domain-rename/01.5-SUMMARY.md`
- Design brief: `/Users/julienbattaglia/Desktop/MINT/visions/MINT_DESIGN_BRIEF_v0.2.3.md`
- Anti-shame doctrine (load before any UX/copy decision): `~/.claude/projects/-Users-julienbattaglia-Desktop-MINT/memory/feedback_anti_shame_situated_learning.md`
- Current palette baseline: `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/theme/colors.dart`
- Profile Pydantic: `/Users/julienbattaglia/Desktop/MINT/services/backend/app/schemas/profile.py`
- CoachProfile Dart model: `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/models/coach_profile.dart`
- Claude coach service (few-shot anchor point for Phase 5): `/Users/julienbattaglia/Desktop/MINT/services/backend/app/services/claude_coach_service.py`

## Locked Decisions

### D-01 — Codegen tool choice
- **Dart codegen** = hand-rolled Python script `tools/contracts/generate_dart.py` writing `apps/mobile/lib/services/voice/voice_cursor_contract.g.dart`. No `build_runner`, no external Dart codegen deps (offline-safe, one-line CI regen). Rationale: the contract is a frozen enum + matrix; a custom 80-LOC emitter is cheaper than wiring `build_runner` into the Flutter toolchain for one file. Header banner + stable key ordering mandatory.
- **Python codegen** = `datamodel-code-generator >= 0.25` invoked via `tools/contracts/generate_python.py` writing `services/backend/app/schemas/voice_cursor.py`. Pinned in `services/backend/requirements-dev.txt`. This is the only tool in Python that round-trips JSON Schema → Pydantic v2 cleanly.
- **Source of truth file**: `tools/contracts/voice_cursor.json` (JSON, not YAML — aligns with existing `tools/openapi/` artifact style; machine-writable by the codegen CI job without a YAML lib dep).

### D-02 — Contract schema shape (CONTRACT-01)
`tools/contracts/voice_cursor.json` holds:
```
{
  "version": "0.5.0",
  "levels": ["N1","N2","N3","N4","N5"],
  "gravities": ["G1","G2","G3"],
  "relations": ["new","established","intimate"],
  "preferences": ["soft","direct","unfiltered"],
  "matrix": { "<gravity>": { "<relation>": { "<preference>": "<level>" } } },
  "precedenceCascade": [
    "sensitivityGuard",
    "fragilityCap",
    "n5WeeklyBudget",
    "gravityFloor",
    "preferenceCap",
    "matrixDefault"
  ],
  "sensitiveTopics": [
    "deuil","divorce","perteEmploi","maladieGrave","suicide","violenceConjugale",
    "faillitePersonnelle","endettementAbusif","dependance","handicapAcquis"
  ],
  "narratorWallExemptions": [
    "settings","errorToasts","networkFailures","legalDisclaimers",
    "onboardingSystemText","compliance","consentDialogs","permissionPrompts"
  ],
  "caps": {
    "n5PerWeekMax": 1,
    "fragileModeDurationDays": 30,
    "fragileModeCapLevel": "N3",
    "sensitiveTopicCapLevel": "N3"
  }
}
```
The matrix itself is filled from the research SUMMARY + design brief draft table. Executor finalizes the numbers against `visions/MINT_DESIGN_BRIEF_v0.2.3.md` §L1.6 but DOES NOT invent new levels or guardrails — schema is frozen at v0.5.0.

### D-03 — Codegen CI drift guard (CONTRACT-04)
`tools/contracts/regenerate.sh` runs both generators; CI job `contracts-drift` runs it then `git diff --exit-code tools/contracts/ apps/mobile/lib/services/voice/voice_cursor_contract.g.dart services/backend/app/schemas/voice_cursor.py`. Any drift = red build. Wired into `.github/workflows/ci.yml` in a new `contracts` job that runs BEFORE `flutter analyze` and `pytest` (fail fast).

### D-04 — Profile voice fields (CONTRACT-05, 3 fields in one migration)
All three fields land **this phase**, not Phase 11 (audit fix A1 — single touch on 73 CoachProfile consumers):
- Pydantic v2 (`services/backend/app/schemas/profile.py`): `voice_cursor_preference: Literal['soft','direct','unfiltered'] = 'direct'` (camelCase alias), `n5_issued_this_week: int = 0`, `fragile_mode_entered_at: Optional[datetime] = None`.
- SQLAlchemy columns nullable with server defaults on `profile` table. Read-time migration (no Alembic — matches current repo posture). Alembic stub file scaffolded for v2.3 promotion but NOT executed.
- Dart model `apps/mobile/lib/models/coach_profile.dart`: three new fields with `fromJson`/`toJson`/`copyWith`/`==`/`hashCode`/`props` updates. Defaults match Pydantic.
- ARB labels (6 languages) for the user-visible "Ton" setting ONLY (`voiceCursorPreferenceSoft`, `voiceCursorPreferenceDirect`, `voiceCursorPreferenceUnfiltered`, `voiceCursorPreferenceLabel`). The counters `n5IssuedThisWeek` and `fragileModeEnteredAt` are internal and MUST NOT get ARB labels. The word "curseur" NEVER appears in user-facing ARB strings (CLAUDE.md constraint — internal term only; user label = "Ton").

### D-05 — Voice Cursor Spec v0.5 boundary (audit fix A2)
`docs/VOICE_CURSOR_SPEC.md` in this phase contains ONLY:
1. Version header `v0.5 — 2026-04-07 — Phase 2 extract`
2. The 5 level definitions (N1–N5), each ~80 words, concrete sensory language, no example phrases yet
3. The narrator wall exemption list (verbatim from contract)
4. The sensitive topics list (verbatim from contract)
5. An explicit "Out of scope for v0.5" section listing: 50 reference phrases, anti-examples, pacing rules, precedence cascade narrative, few-shot coach prompt embedding, Krippendorff protocol, tone-locking mitigation — all deferred to Phase 5 (L1.6a full spec).

The full spec lands in Phase 5. Phase 4 MTC reads v0.5 for its audio ARB tonal anchor (MTC-05). Phase 9 MintAlertObject reads the contract, not the spec doc.

### D-06 — AUDIT-01 scope (confidence semantics)
`docs/AUDIT_CONFIDENCE_SEMANTICS.md` enumerates every site that renders a confidence score or decay indicator in `apps/mobile/lib/`. Each hit gets classified into one of three columns:
- `extraction-confidence` — how sure extraction was about a data point (OCR, manual entry, bank feed)
- `data-freshness` — how stale the stored data is (decay model)
- `calculation-confidence` — how sure a projection is (EnhancedConfidence 4-axis output)

Each category gets a per-phase decision: `MTC absorbs` / `sibling component` / `untouched`. Gate: Phase 4 `MTC` only starts once the doc is committed. Expected hits: ~40 (per ROADMAP estimate). Audit reads code, does not modify code.

### D-07 — AUDIT-02 scope (contrast matrix)
`docs/AUDIT_CONTRAST_MATRIX.md` enumerates every text/background token pair used on S0-S5 (`intent_screen`, `mint_home_screen`, `coach_message_bubble`, `response_card_widget`, plus the S5 `mint_alert_object` target surface — not yet built but designed). Each pair gets a row: token-foreground, token-background, hex values, WCAG contrast ratio, AAA pass / AA-only / fail classification. The doc must identify the 6 token upgrades that become `AESTH-04` (already locked by REQ at the hex level). Gate: Phase 3 L1.1 and Phase 8b S0-S5 migration both read this doc as input.

### D-08 — Krippendorff tooling skeleton (not execution)
`tools/voice-cursor-irr/` with `compute_alpha.py` (weighted ordinal Krippendorff α, uses `krippendorff` PyPI package pinned in `requirements.txt`), `requirements.txt`, `README.md` (protocol: 15 testers × 50 reference phrases × blind classification, pass threshold α ≥ 0.67 overall AND per-level for N4 and N5), and `ratings_template.csv` (columns: `tester_id`, `phrase_id`, `assigned_level`). No actual ratings, no testers recruited this phase — that's Phase 11. Tooling must be runnable from a unit test on a fixture CSV (`test_ratings.csv` with 3 testers × 5 phrases → known α value).

### D-09 — Anti-shame doctrine compliance check
Loaded `feedback_anti_shame_situated_learning.md` before writing this CONTEXT. Compliance audit of Phase 2 deliverables:
- **AAA tokens**: calm, desaturated, no high-contrast alerting palette. Single warning amber, no RAG traffic-light system. ✓
- **Voice cursor contract**: N1 floor on sensitive topics, fragile-mode cap at N3, N5 hard server gate. Zero mechanism for gamifying voice intensity. ✓
- **Profile fields**: no "financial literacy level", no XP, no "completeness %" proxies. Only `voiceCursorPreference` (user agency), `n5IssuedThisWeek` (editorial safety), `fragileModeEnteredAt` (protection). ✓
- **Voice spec v0.5**: level definitions describe MINT's voice, not a user progression axis. ✓
- No screen in this phase asks the user for data. Phase 2 is invisible to users. ✓

## 6 AAA Tokens — Brand Sign-Off Surface

**THIS IS THE ONE HUMAN-GATED DECISION IN PHASE 2.** Executor MUST stop and wait for Julien's explicit "approved" before editing `colors.dart` in Plan 02.

All 6 hex values are already locked in `REQUIREMENTS.md` line 78 (AESTH-04). They were derived during the expert audit from the current pastel palette by finding the darkest point that preserves brand recognition while hitting WCAG 2.1 AAA normal-text contrast ratio (≥ 7:1) on both pure white backgrounds (`#FFFFFF` = `background`, `card`) AND the warm white surfaces (`#FCFBF8` = `craie`, `#FBFBFD` = `cardGround`, `#F7F4EE` = `porcelaine`).

The 6 tokens sit alongside the existing `textSecondary`/`textMuted`/`success`/`warning`/`error`/`info` tokens — the legacy tokens stay for out-of-S0-S5 surfaces (per REQUIREMENTS.md Out-of-Scope: "MintColors AAA tokens applied outside S0-S5"). Only S0-S5 migrates to `*Aaa` variants.

| # | Token name | Hex | Replaces (for S0-S5 only) | Intended usage | Contrast vs `#FFFFFF` | Contrast vs `#FCFBF8` (craie) | WCAG |
|---|---|---|---|---|---|---|---|
| 1 | `textSecondaryAaa` | `#595960` | `textSecondary` (#6E6E73, ~5.2:1 AA only) | Body secondary text, metadata, timestamps, hypothesis footer | **7.08:1** | **6.94:1** | AAA normal text on white; AAA large-text on craie |
| 2 | `textMutedAaa` | `#5C5C61` | `textMuted` (#737378, ~4.8:1 AA only) | Micro-labels, input hints, disabled state text, footer legal | **6.85:1** | **6.72:1** | AAA large-text; AAA normal-text borderline (7:1 target) |
| 3 | `successAaa` | `#0F5E28` | `success` (#157B35, ~5.9:1) | "Premier éclairage" positive confirmation, successful save toast, completed-action indicator. NOT for score badges (banned by anti-shame doctrine) | **8.27:1** | **8.11:1** | AAA normal text |
| 4 | `warningAaa` | `#8C3F06` | `warning` (#B45309, ~5.4:1) | **The single desaturated amber** — "verifiable fact requiring attention" per AESTH §3 one-color-one-meaning rule. Used by MintAlertObject G2 and MTC confidence-floor prompts | **7.12:1** | **6.98:1** | AAA normal text on white; AAA large-text on craie |
| 5 | `errorAaa` | `#A52121` | `error` (#D32F2F, ~4.5:1) | Form validation errors only, MintAlertObject G3 rupture grammaticale accent. NEVER for compliance messaging (compliance = neutral per narrator wall) | **6.54:1** | **6.41:1** | AAA large-text; normal-text borderline — **plan 02 must confirm via test and surface if < 7:1** |
| 6 | `infoAaa` | `#004FA3` | `info` (#0062CC, ~5.8:1) | Hypothesis footer links, "voir détail" tap targets, trajectory base scenario legend | **8.94:1** | **8.77:1** | AAA normal text |

**Computed contrast ratios are estimates**. Plan 02 Task 2 runs a pure-Dart contrast helper (same math as WCAG 2.1 §1.4.6) as a unit test against every token × every S0-S5 background. Any `*Aaa` token that misses 7:1 normal-text on any legitimate S0-S5 background → executor stops and raises to orchestrator BEFORE committing. No silent downgrade. `errorAaa` is the known borderline — if it fails 7:1, the fallback is to restrict its usage documentation to "large text only (≥ 18pt regular or ≥ 14pt bold)" and add a lint comment in `colors.dart`. No hex change without re-consulting Julien.

**Brand sign-off requirement**: commit message for Plan 02 Task 2 MUST include the literal line `Brand sign-off: Julien (6 AAA tokens approved 2026-04-DD)` — orchestrator fills the date after sign-off lands. No sign-off = no commit.

### Palette compatibility note
The pastels (`saugeClaire` #D8E4DB, `bleuAir` #CFE2F7, `pecheDouce` #F5C8AE, `corailDiscret` #E6855E, `porcelaine` #F7F4EE) remain **background-only** on S0-S5 per AESTH-05 (Phase 8b). They NEVER carry information-bearing text on S0-S5. Plan 02 does not touch the pastels. The 6 AAA tokens are the surface Julien signs off on; the pastel demotion happens in Phase 8b against this foundation.

## Plan Manifest

| Plan | Wave | Requirements covered | Autonomous? | Notes |
|---|---|---|---|---|
| 02-01 voice cursor contract + codegen | 1 | CONTRACT-01, CONTRACT-02, CONTRACT-03, CONTRACT-04, CONTRACT-06 | yes | Foundation — unblocks 02-03, 02-04, Phase 5, Phase 9 |
| 02-02 AAA tokens implementation | 1 | AESTH-04 | **no** — brand sign-off gate | Independent of 02-01. Blocks Phase 7 LAND-05, Phase 8b AESTH-05 |
| 02-03 profile voice fields | 2 | CONTRACT-05 | yes | Depends on 02-01 (imports generated `voice_cursor.py` for Literal type). Touches 73 CoachProfile consumers |
| 02-04 voice spec v0.5 extract | 2 | (feeds CONTRACT-01 narrative, no new REQ) | yes | Depends on 02-01 (reads finalized contract as source). Pure doc |
| 02-05 pre-migration audits + Krippendorff tooling | 1 | AUDIT-01, AUDIT-02 (+ Krippendorff skeleton) | yes | Independent — pure read + doc emission + tool scaffold |

**Wave 1** (parallel): 02-01, 02-02 (paused mid-plan for sign-off), 02-05.
**Wave 2** (after 02-01): 02-03, 02-04.

Orchestrator dispatches Wave 1 but holds 02-02 at the brand sign-off gate until Julien approves the 6 hex values. Wave 2 launches after 02-01 lands.

## Non-Goals (Phase 2)

- No UI screen touched. Phase 2 is invisible to end users.
- No ARB strings added outside the 4 "Ton" setting labels in D-04.
- No `*Aaa` token APPLIED to any widget (application = Phase 7 LAND-05 + Phase 8b AESTH-05). Plan 02 only ADDS the tokens + contrast unit tests.
- No 50 reference phrases (Phase 5). No few-shot embedding in coach service (Phase 5). No Krippendorff validation run (Phase 11). No anti-examples (Phase 5).
- No `AUDIT-03` (Audit du retrait) — that's Phase 3.
- No MTC component — that's Phase 4.
- No user-visible "Ton" setting screen — only the Profile fields backing it. Screen is VOICE-13 in Phase 12.

## Success Criteria (phase-level)

1. `tools/contracts/voice_cursor.json` committed, schema v0.5.0 frozen.
2. `apps/mobile/lib/services/voice/voice_cursor_contract.g.dart` + `services/backend/app/schemas/voice_cursor.py` generated and committed.
3. CI drift guard job green on this phase's PR and red on a deliberately-broken test PR.
4. `resolveLevel(...)` pure function exported from the Dart contract with ≥ 80 unit tests covering matrix + cascade + sensitive-topic + fragile-mode + N5-budget edges.
5. `Profile` has 3 new voice fields end-to-end (Pydantic + SQLA + Dart model + 4 ARB strings). 73 CoachProfile consumers still compile. `pytest -q` + `flutter analyze lib/` + `flutter test` green.
6. `docs/VOICE_CURSOR_SPEC.md` committed at v0.5 with 5 levels + narrator wall + sensitive topics + explicit "out of scope for v0.5" section.
7. `apps/mobile/lib/theme/colors.dart` has 6 new `*Aaa` tokens at exactly the hex values in REQUIREMENTS.md §AESTH-04. Brand sign-off line in commit message. Contrast unit tests green.
8. `docs/AUDIT_CONFIDENCE_SEMANTICS.md` + `docs/AUDIT_CONTRAST_MATRIX.md` committed with per-hit classification + per-category decisions.
9. `tools/voice-cursor-irr/` scaffold exists with `compute_alpha.py` + unit test against a fixture CSV.
10. `flutter analyze lib/` 0 errors, `flutter test` baseline-equal (8991 passed + 3 allowlisted), `pytest tests/ -q` green, `python3 tools/checks/no_chiffre_choc.py` green, CI `contracts-drift` job green.

## Branch + Commit Discipline

- Stay on `feature/v2.2-p0a-code-unblockers` (Phase 1 + 1.5 + 2 all ship on the same pre-launch branch).
- Each plan = its own commit. 5 plans = 5 commits (or 6 if 02-02 splits into "add tokens" + "add tests + lint rules").
- Commit prefixes: `feat(p0b-01): ...`, `feat(p0b-02): ...`, `refactor(p0b-03): ...`, `docs(p0b-04): ...`, `docs(p0b-05): ...`.
- No direct push to `dev`/`staging`/`main`. Orchestrator handles PR after all 5 plans land.
