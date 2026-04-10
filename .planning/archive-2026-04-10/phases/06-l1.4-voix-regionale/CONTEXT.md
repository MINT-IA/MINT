# Phase 6 — L1.4 Voix Régionale VS/ZH/TI — CONTEXT

**Date:** 2026-04-07
**Branch:** feature/v2.2-p0a-code-unblockers
**Requirements covered:** REGIONAL-01..07 (7 REQs)
**Depends on:** Phase 1 (ACCESS-01 tester recruitment kickoff), Phase 2 (CONTRACT-01..04 voice_cursor codegen infra)

---

## Goal (one sentence)

Ship 3 canton ARB carve-outs (VS/ZH/TI) as sparse overrides on fr/de/it base, kill the backend dual-system (`REGIONAL_MAP` + `_REGIONAL_IDENTITY`) in a single generated source, and lock regional voice to base languages only — validated by 3 named natives coordinated with the Phase 11 Krippendorff tester pool.

---

## Backend dual-system — STATUS: FOUND

Located in `services/backend/app/services/coach/claude_coach_service.py`:

| Line | Symbol | Role |
|------|--------|------|
| 58 | `REGIONAL_MAP = { VD, GE, VS, ZH, BE, TI: ... }` | Hand-coded inline per-canton prompt fragments |
| 94 | `_resolve_canton(canton)` | Resolves any canton via `_CANTON_TO_PRIMARY` fallback (e.g. NE→VD, AG→ZH, GR→TI) |
| 133 | `_REGIONAL_IDENTITY = """..."""` | Free-text block describing Romande/Deutschschweiz/Italiana tone |
| 377 | Injected as `regional_identity=` into system prompt template | Always present, region-agnostic |
| 396 | If `resolved` canton, appends `\n## COULEUR REGIONALE\n{REGIONAL_MAP[resolved]}\n` | Canton-specific fragment |

**Dual nature:** free-text `_REGIONAL_IDENTITY` + dict `REGIONAL_MAP`. Both hand-coded strings with no contract, no sibling base-language keys, no lint, no tests. **This is the kill target.**

Mobile side: `apps/mobile/lib/services/voice/regional_voice_service.dart` exists (confirmed) — current role to be documented in Plan 06-01 audit.

---

## Locked decisions (NON-NEGOTIABLE)

### D-01 — ARB naming convention
Regional ARBs live in a **separate directory** `apps/mobile/lib/l10n_regional/` driven by a **second `l10n_regional.yaml` gen_l10n config** (REQ REGIONAL-02).

- `apps/mobile/lib/l10n_regional/app_regional_vs.arb` — base language **fr-CH**
- `apps/mobile/lib/l10n_regional/app_regional_zh.arb` — base language **de-CH**
- `apps/mobile/lib/l10n_regional/app_regional_ti.arb` — base language **it-CH**

Each file's first line is a comment header `// LOCALE-LOCKED: fr-CH | de-CH | it-CH` (per ROADMAP §Phase 6 success criterion 1). Never any `app_regional_{vs,zh,ti}_en.arb` — the regional layer does not exist for en/es/pt.

### D-02 — Sparse override, not full coverage
Regional ARBs are **sparse overrides**. Each key in a regional ARB MUST have a sibling key in the main base ARB (REQ REGIONAL-07, lint enforced). Missing keys fall back silently to the base ARB. v1 scope: **~30 keys per canton = 90 total** (REQ REGIONAL-01).

### D-03 — Key selection rule for v1 (the 30 keys)
The 30 keys per canton are drawn from the **most user-visible surfaces** where a regional tonal difference actually lands:
1. Aujourd'hui home greeting (~3 keys)
2. Coach opening lines / silence-breakers (~6 keys)
3. Empty states on Explorer hubs (~4 keys)
4. MTC "Empty(missingAxis)" prompts (~4 keys)
5. MintAlertObject G2/G3 opening formulas (~4 keys)
6. Intent screen chip labels — only if a regional phrasing lands naturally (~3 keys)
7. Settings/drawer section headers (~3 keys)
8. Ton picker "direct" sample line (~3 keys)

Executors pick the concrete keys from the base ARB during Plan 06-03. Anti-pattern: do NOT override every key to "prove coverage" — sparse is the point.

### D-04 — Fallback chain
```
lookup(key) in (canton, base_lang)
  → app_regional_{canton}.arb[key]   if present
  → app_{base_lang}.arb[key]         always present (sibling REQ REGIONAL-07)
  → key_missing_warning              debug builds only
```
No crash. No English fallback. Silent on release.

### D-05 — Regional voice trigger
**`Profile.canton` field is the single trigger.** Not device locale, not explicit user setting, not IP. If canton is null → no regional layer applied (pure base locale). Canton change in ProfileDrawer hot-reloads the delegate.

Secondary cantons map to primary voice via the existing `_CANTON_TO_PRIMARY` table (NE/JU/FR→VS for Romande; all AG/BE/LU/ZG/...→ZH for Deutschschweiz; GR→TI). This table moves from `claude_coach_service.py` into the generated `regional_microcopy.py` in Plan 06-02.

### D-06 — Backend consolidation: single `RegionalMicrocopy` module, codegen-driven
- New script: `tools/regional/regional_microcopy_codegen.py` reads the 3 ARB files and emits `services/backend/app/services/coach/regional_microcopy.py` (REQ REGIONAL-04).
- Generated module exposes a single class `RegionalMicrocopy` with:
  - `CANTON_TO_PRIMARY: dict[str, str]` (moved from claude_coach_service)
  - `resolve(canton: Optional[str]) -> Optional[str]` (primary canton)
  - `identity_block(canton: Optional[str]) -> str` (replaces both `_REGIONAL_IDENTITY` and `REGIONAL_MAP[...]` — one string, one call)
- `claude_coach_service.py` imports `RegionalMicrocopy` and calls `identity_block(profile.canton)` at the **single injection point** currently at line 377/396. **Both legacy constants DELETED in the same MR** (zero-debt rule, REQ REGIONAL-04).
- CI drift guard: regenerate on PR, `git diff --exit-code` against committed `regional_microcopy.py` (mirrors CONTRACT-04 pattern from Phase 2).
- CI regression guard: `git grep 'REGIONAL_MAP\s*=' services/backend/` returns 0 (REQ REGIONAL-05).

### D-07 — VoiceCursorContract linkage
The regional layer does NOT overlap with voice cursor N1-N5 levels. Regional microcopy is **coloring**, the cursor is **intensity**. Phase 5 shipped the base cursor (N-level ← base ARB key). Phase 6 lets regional ARBs override the rendered string for a given (canton, base_lang) **without touching the cursor level**. Stacking order (per VOICE_CURSOR_SPEC §14):
```
base N-level string → regional override (if present) → sensitive-topic cap
```
If Phase 5's `VOICE_CURSOR_SPEC.md §14` does not yet describe this stacking, Plan 06-03 must add a 5-line note pointing here. No code change to the cursor itself.

### D-08 — Native validator recruitment — coordinated with Phase 11 pool
Per audit fix B2, Phase 6 does NOT run its own recruitment stream. It **piggybacks the Phase 11 Krippendorff tester pool** (15 testers for VOICE-05). Requirements:
- At least **1 VS native**, **1 ZH native**, **1 TI native** in the Phase 11 pool.
- Same tester signs off on both their Krippendorff batch AND the 30 regional strings for their canton.
- Compensation bundled into the Phase 11 CHF 800-2000 envelope (ACCESS-01).
- Deliverable: `docs/VOICE_PASS_LAYER1.md` lists the 3 names + sign-off date per canton (REQ REGIONAL-06).
- **Hard gate:** if the Phase 11 pool does not contain a native from a given canton by the time Plan 06-03 is coded, that canton ships marked `// UNVALIDATED` in its ARB header and the REQ is carried to v2.3. Never fake a sign-off.

### D-09 — Scope boundary — what v1 does NOT cover
- No en/es/pt regional voice (ever in v2.2).
- No VD/GE/BE regional ARBs (only VS/ZH/TI in v1; the `REGIONAL_MAP` inline fragments for VD/GE/BE are deleted along with the dict; secondary cantons route through `CANTON_TO_PRIMARY` to VS/ZH/TI).
- No per-user "regional voice off" toggle. If a user dislikes regional flavor, they leave canton blank.
- No cantonal voice in settings/errors/legal (narrator wall from VOICE-12 still applies — regional layer respects the same exemption list).
- No audio/voice rendering of regional microcopy (TTS is out of scope per MEMORY — TTS 1-voice-only is Phase 4 roadmap).

### D-10 — Anti-shame / anti-caricature enforcement
Per CLAUDE.md §7 and `feedback_regional_voice_identity.md`:
- Regional voice is **subtle coloring**, never identity claim.
- NO "as we say in Valais" as a superior marker.
- NO stereotypes of OTHER regions (a ZH string must never mock Romands, etc.).
- Validator review explicitly checks "does this shame anyone?" as a sign-off criterion, documented in `docs/VOICE_PASS_LAYER1.md` review rubric.

---

## Deferred ideas (NOT in Phase 6)

- VD/GE/BE/FR/NE/JU dedicated ARBs (v2.3)
- Regional voice A/B testing harness (v2.3)
- Cantonal dialect in TTS (Phase 3 roadmap)
- Per-key validator UI tool (not needed, validators work from static lists)
- Regional emoji / regional color tokens (caricature risk — rejected)

---

## Claude's discretion

- Exact 30 keys picked per canton (executor chooses from the menu in D-03)
- Exact German register in ZH ARB: Hochdeutsch vs. light Mundart — executor consults the VS/ZH/TI native validator via Phase 11 pool
- `regional_microcopy_codegen.py` internal structure (AST vs. template vs. Jinja — just keep it <150 LOC and deterministic)
- Custom `LocalizationsDelegate` implementation details — target ≤ 40 LOC per ROADMAP success criterion 2

---

## Plan breakdown (4 plans, 2 waves)

| Plan | Wave | Autonomous | Tasks | Purpose |
|------|------|------------|-------|---------|
| 06-01 | 1 | yes | 2 | Pre-audit: document dual-system + mobile surface → `docs/REGIONAL_VOICE_AUDIT.md` |
| 06-02 | 2 | yes | 3 | Backend consolidation: `regional_microcopy_codegen.py` + delete legacy constants + tests |
| 06-03 | 2 | no (checkpoint) | 3 | ARB carve-outs: 3 files + delegate + Profile.canton wiring + widget test + native sign-off checkpoint |
| 06-04 | 1 | yes | 1 | Validator coordination doc → `docs/REGIONAL_VOICE_VALIDATORS.md` |

Plans 06-01 and 06-04 run in parallel Wave 1 (documentation only, no file overlap). 06-02 and 06-03 run in parallel Wave 2 (06-02 touches only backend, 06-03 touches only mobile + one docs line cross-ref; no conflict).

---

## Requirements coverage matrix

| REQ | Plan | Task | Full |
|-----|------|------|------|
| REGIONAL-01 | 06-03 | 1 | Full |
| REGIONAL-02 | 06-03 | 2 | Full |
| REGIONAL-03 | 06-03 | 2 | Full |
| REGIONAL-04 | 06-02 | 1+2 | Full |
| REGIONAL-05 | 06-02 | 3 | Full |
| REGIONAL-06 | 06-03 | 3 + 06-04 | Full |
| REGIONAL-07 | 06-03 | 2 | Full |

All 7 requirements fully covered in a single phase. No split needed.
