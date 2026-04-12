# Phase 2: P0b — Contracts & Audits + AAA Tokens + Voice Spec v0.5 - SUMMARY

**Completed:** 2026-04-07
**Branch:** `feature/v2.2-p0a-code-unblockers` (continuation, same branch as Phases 1 + 1.5)
**Status:** GREEN — all 5 plans landed, all gates passed

## Plans (5/5 complete)

| # | Plan | Commits | Status |
|---|---|---|---|
| 02-02 | AAA Tokens (6) + WCAG helper | 2 | ✓ strict 7:1 verified |
| 02-04 | VOICE_CURSOR_SPEC.md v0.5 extract | 1 | ✓ scope boundary respected |
| 02-05 | AUDIT-01 + AUDIT-02 + Krippendorff | 3 | ✓ production code untouched |
| 02-01 | VoiceCursorContract + codegen + CI drift | 4 | ✓ brief-derived matrix |
| 02-03 | Profile 3 voice fields (e2e) | 3 | ✓ Pydantic + SQLA stub + Dart + ARB |

**Total:** 13 commits (Wave 1 parallel: 6, Wave 2 sequential: 7).

## Execution pattern

Dispatched via parallel-agents pattern (one executor per plan, strict file ownership to prevent collisions) after initial aggregate-executor attempt correctly self-rejected as "façade risk". This validated the GSD one-executor-per-plan doctrine.

- **Wave 1 (parallel, disjoint file ownership):** 02-02 (colors+tests), 02-04 (new doc only), 02-05 (audit docs + new tools/krippendorff/ scaffold)
- **Wave 2 (sequential, dependency chain):** 02-01 (contract codegen) → 02-03 (Profile fields consuming the contract enum)

## Brand sign-off (T2, expert mode)

6 AAA tokens locked with strict ≥ 7:1 contrast against both `#FFFFFF` and `#FCFBF8` (craie):

| Token | Final Hex | vs white | vs craie | Notes |
|---|---|---|---|---|
| `textSecondaryAaa` | `#555560` | 7.36 | 7.11 | Auto-darkened from #595960 (iter 2) to survive craie background |
| `textMutedAaa` | `#525256` | 7.78 | 7.52 | Expert darken from #5C5C61 pre-dispatch |
| `successAaa` | `#0F5E28` | 7.92 | 7.65 | — |
| `warningAaa` | `#8C3F06` | 7.42 | 7.17 | The single amber per AESTH §3 |
| `errorAaa` | `#8B1D1D` | 9.17 | 8.86 | Expert darken from #A52121 pre-dispatch |
| `infoAaa` | `#004FA3` | 7.93 | 7.67 | — |

All 28 theme tests green. Zero `// RESTRICTED large-only` dead code in `colors.dart` — every token is unrestricted strict AAA.

## Contract infrastructure

**Source of truth:** `tools/contracts/voice_cursor.json` (brief-derived from `visions/MINT_DESIGN_BRIEF_v0.2.3.md` §L1.6 — the 3×3 G×R table on lines 105-109 was explicit; preference axis extended via §4 caps `soft→N3 / direct→N4 / unfiltered→N5` plus G3 floor at N2)

**Codegen:** Hand-rolled Pydantic + Dart emitters (deterministic output for drift gate, full rationale in `tools/contracts/README.md`). Alternative `datamodel-code-generator` rejected as non-deterministic.

**CI drift guard:** `bash tools/contracts/regenerate.sh && git diff --exit-code` wired into `.github/workflows/ci.yml`. Manually verified clean at end-of-phase.

**Test coverage:** 96 Dart tests (`voice_cursor_contract_test.dart`) + 9 Python tests (`test_voice_cursor_schema.py`), all green. `resolveLevel(context, userPreference, sensitiveTopic)` decision matrix exhaustively covered. Sensitive topic cap (death/debt/divorce/job loss/illness → N3) enforced at contract level, not soft default.

## Audit outputs

**AUDIT-01 (confidence semantics):** 42 confidence-rendering sites classified. 7-entry DO-NOT-MIGRATE list identified. Feeds Phase 4 (MTC component) + Phase 8a (11-surface migration).

**AUDIT-02 (voice cursor parity):** 62 voice/prompt sites audited. 36 sites need contract import. 7 parity gaps documented. Feeds Phases 5/11 (voice rewrite + Krippendorff validation).

**Krippendorff α tool:** pure Python weighted ordinal implementation (~60 LOC, no pip dependency). 4/4 tests green. Fixture α_overall ≈ 0.8195 (15 raters × 50 items synthetic). Ready for Phase 11 tester pool.

## Profile voice fields

3 fields added end-to-end without any UI consumer (UI lands in Phase 12):
1. `voiceCursorPreference: VoiceCursorPreference` — enum `{soft, direct, unfiltered}`, default `direct`, imports contract enum from Plan 02-01
2. `n5IssuedThisWeek: int` — rolling counter, backend-only field (no ARB key leak)
3. `fragileMode: {active, triggeredAt, expiresAt}` — tri-field structure, backend-only (no ARB key leak)

**Storage:** Backend stores all 3 via the existing JSON `data` column on `Profile` model — no new SQL columns needed. Alembic migration file scaffolded (`2026_04_07_voice_cursor_fields.py`, upgrade + downgrade stubs) but NOT run, per Phase 1.5 precedent.

**ARB labels (anti-shame doctrine applied):** 4 user-facing keys × 6 languages = 24 new strings:
- `tonSettingTitle` = "Ton" (fr) / "Tone" (en) / ... — never "Niveau" or "Intensité" which would imply judgment
- `tonSettingSoft` = "Doux" / "Gentle" / ...
- `tonSettingDirect` = "Direct" (universal)
- `tonSettingUnfiltered` = "Non filtré" / "Unfiltered" / ...

Verified: zero leak of "curseur" / "cursor" in any user-facing ARB value (internal term only, per brand doctrine).

## Gate results (end of phase)

| Gate | Result |
|---|---|
| `flutter analyze lib/` | **0 errors** |
| `flutter test` (full suite) | **9134 passed / 2 skipped / 3 allowlisted baseline failures** (≥ 8991 floor honored) |
| `cd services/backend && pytest tests/ -q` | **5043 passed / 49 skipped** (+12 new tests vs 5018 baseline, zero new failures) |
| Voice cursor contract drift guard | **clean** (regenerate + git diff exit 0) |
| `no_chiffre_choc.py` CI gate (legacy check from Phase 1.5) | **clean** (still green post-Phase 2) |
| Ruff | **skipped** per Phase 1.5 Option 3 (6 pre-existing E402 in `wizard.py` unrelated) |

## Deviations

1. **`textSecondaryAaa` auto-darkened from REQUIREMENTS-locked #595960 to #555560** (iteration 2) to survive craie background at strict 7:1. Alternative (drop craie as S0-S5 background) rejected — craie is load-bearing. Expert accepted the 4-hex-point drift as imperceptible. Documented in commit message + code comment + DESIGN_SYSTEM.md.
2. **VOICE_CURSOR_SPEC.md scoped as minimal extract**, not full spec. Anti-examples, 9 adaptation cells, fragile mode trigger section, test hooks → all deferred to Phase 5 (L1.6a full spec) per PLAN.md §6. Executor correctly prioritized PLAN over the richer orchestrator prompt.
3. **Hand-rolled Pydantic emitter** instead of `datamodel-code-generator` in Plan 02-01 — deterministic output required for drift gate. Rationale in `tools/contracts/README.md`.
4. **Profile fields stored via JSON `data` column**, not new SQL columns — matches existing `Profile` model pattern and avoids an unnecessary Alembic migration. Stub still written for audit trail.

## What Phase 2 unblocks

- **Phase 4** (MTC component) can now import `VoiceCursorContract` for audio-tone consistency
- **Phase 5** (Voice Cursor Spec full) has the v0.5 extract as its starting point
- **Phase 7** (Landing v2) has the 6 AAA tokens implemented
- **Phase 8a** (MTC 11-surface migration) has the AUDIT-01 42-site list
- **Phase 8b** (Microtypo + AAA application) has the tokens already in `colors.dart`
- **Phase 9** (MintAlertObject) has the rule-fed narrator wall declared in the contract
- **Phase 11** (Krippendorff validation) has the α tool ready
- **Phase 12** (Ton UX setting) has the Profile fields + ARB labels — only the UI chooser remains

## Branch state

- `feature/v2.2-p0a-code-unblockers` at HEAD: 22 commits ahead of `dev`
  - 3 Phase 1 (smoke test + tracker + SUMMARY)
  - 1 ROADMAP Phase 1.5 insert
  - 1 Phase 1.5 CONTEXT
  - 4 Phase 1.5 refactor commits (pre-audit, backend rename, mobile rename, CI gate + docs flip)
  - 1 Phase 2 planning (CONTEXT + 5 PLANs)
  - 13 Phase 2 execution commits (across 5 plans)
- Working tree clean except for 8 pre-existing untracked design brief files (excluded per D-06 across all phases)
- Not pushed, no PR opened

## Next

Phase 3: L1.1 Audit du Retrait (S0-S5) — the -20% visual element reduction evidence. No user touch expected.
