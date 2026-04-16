# Regional Voice — Dual-System Audit (Phase 6 / Plan 06-01)

**Date:** 2026-04-07
**Branch:** `feature/v2.2-p0a-code-unblockers`
**Purpose:** Name every symbol, line and consumer touched by the current regional voice code BEFORE Plan 06-02 (backend consolidation) and Plan 06-03 (mobile ARB carve-outs) execute. Read-only walk — no code touched in this plan. Prevents "façade sans câblage" by making the kill targets explicit.

---

## 1. Backend dual-system inventory

All symbols live in a single file:
**`services/backend/app/services/coach/claude_coach_service.py`**

### 1.1 `REGIONAL_MAP` — hand-coded per-canton prompt fragments
- **Declared:** line **58** → line **65** (6 entries).
- **Cantons covered:** `VD`, `GE`, `VS`, `ZH`, `BE`, `TI`.
- **Content:** one-liner per canton mixing language (FR for VD/GE/VS, Swiss-German for ZH/BE, IT for TI) with hard-coded local expressions, place-name references (Morges/Flon/Uetliberg/Bahnhofstrasse/Zytglogge/grotto/polenta…). No contract, no sibling base-language keys, no lint, no tests of the string content.

### 1.2 `_CANTON_TO_PRIMARY` — secondary → primary canton fallback
- **Declared:** line **68** → line **76**.
- **Entries:** 19. `NE/JU/FR → VD`; `LU/AG/SG/TG/SO/SH/AR/AI/OW/NW/GL/SZ/UR/ZG/BL/BS → ZH`; `GR → TI`.
- **Note — drift vs CONTEXT.md D-05:** CONTEXT.md states secondary Romande cantons must map to **VS** and `GR → TI`; this table currently maps Romande secondaries to **VD** and everything Alémanique (incl. BE) to **ZH**. Plan 06-02 must explicitly re-home the table into `RegionalMicrocopy.CANTON_TO_PRIMARY` **and** reconcile the target primaries with the D-05 decision (VS/ZH/TI primaries, not VD/ZH/TI). Flagged as deviation in §5.

### 1.3 `_resolve_canton(canton)` — resolution function
- **Declared:** line **92** → line **99**.
- **Behavior:** uppercases canton, returns it if in `REGIONAL_MAP`, otherwise falls back via `_CANTON_TO_PRIMARY`, otherwise `None`.
- **Only caller:** line **395** inside `build_system_prompt`.

### 1.4 `_REGIONAL_IDENTITY` — free-text always-injected block
- **Declared:** line **133** → line **149**.
- **Content:** 17-line English-instruction-to-Claude paragraph describing Romande / Deutschschweiz / Italiana tone generalities. Region-agnostic, always present in every system prompt regardless of canton.

### 1.5 Injection path into system prompt
Inside `build_system_prompt()` (`claude_coach_service.py:357`):
- **Line 375-382** — `_BASE_SYSTEM_PROMPT.format(...)` templates `regional_identity=_REGIONAL_IDENTITY` at **line 377**. This is the **always-on** block.
- **Line 394-397** — canton-specific append:
  ```python
  if ctx and ctx.canton:
      resolved = _resolve_canton(ctx.canton)
      if resolved and resolved in REGIONAL_MAP:
          base += f"\n## COULEUR REGIONALE\n{REGIONAL_MAP[resolved]}\n"
  ```
  This is the **canton-specific** block.

Both blocks land in the final string returned to the Anthropic API caller. **This is the dual-system.** One free-text macro + one dict-per-canton snippet, stitched together at two different points in the same function, with two different trigger conditions.

### 1.6 Backend consumers / grep results
`git grep` across `services/backend/` for `REGIONAL_MAP|_REGIONAL_IDENTITY|_resolve_canton|_CANTON_TO_PRIMARY|regional_identity=`:

| File:line | Match | Role |
|---|---|---|
| `claude_coach_service.py:58` | `REGIONAL_MAP = {` | declaration |
| `claude_coach_service.py:68` | `_CANTON_TO_PRIMARY = {` | declaration |
| `claude_coach_service.py:92` | `def _resolve_canton` | declaration |
| `claude_coach_service.py:97` | `if upper in REGIONAL_MAP` | internal use |
| `claude_coach_service.py:99` | `return _CANTON_TO_PRIMARY.get(upper)` | internal use |
| `claude_coach_service.py:133` | `_REGIONAL_IDENTITY = """\` | declaration |
| `claude_coach_service.py:377` | `regional_identity=_REGIONAL_IDENTITY` | template injection |
| `claude_coach_service.py:395` | `resolved = _resolve_canton(ctx.canton)` | call site |
| `claude_coach_service.py:396` | `if resolved and resolved in REGIONAL_MAP` | call site |
| `claude_coach_service.py:397` | `base += f"\n## COULEUR REGIONALE\n{REGIONAL_MAP[resolved]}\n"` | call site |

**Zero external importers** — `REGIONAL_MAP`, `_REGIONAL_IDENTITY`, `_resolve_canton`, `_CANTON_TO_PRIMARY` are all file-private (the three prefixed with `_` explicitly, `REGIONAL_MAP` de facto). Deletion is safe as long as the two call sites at 377 and 394-397 are rewired in the same MR.

### 1.7 Backend tests referencing the dual-system
`git grep` across `services/backend/tests/`:

| File:line | What it asserts | Post-kill action |
|---|---|---|
| `test_coach_firstjob.py:91` | `assert "COULEUR REGIONALE" in prompt` | Update to assert on `RegionalMicrocopy.identity_block(canton)` substring (e.g. `"Valais"` or the new canonical marker). |
| `test_coach_firstjob.py:98` | same | same |
| `test_coach_firstjob.py:119` | same | same |
| `test_e2e_coach_pipeline.py:89` | Seeds a mock prompt containing the literal string `"COULEUR REGIONALE : Valais, Romande — montagnard, direct\n"` | Update mock fixture; no behavioral change. |
| `test_coach_chat_endpoint.py:399` | `def test_system_prompt_includes_regional_identity` | Rename / rewire to assert `RegionalMicrocopy` output presence. |

Total: **5 test assertions** across **3 files**. All are low-risk string assertions; none test behavior of the map itself, only that *something* regional was injected.

---

## 2. Mobile regional voice surface

### 2.1 `apps/mobile/lib/services/voice/regional_voice_service.dart` — API surface
- **Lines:** 1-391. Pure static class, no I/O, no state.
- **Public symbols:**
  - `enum SwissRegion { romande, deutschschweiz, italiana, unknown }` (lines 26-38)
  - `class RegionalFlavor` with fields `region`, `promptAddition`, `localExpressions`, `financialCultureNote`, `humorStyle`, `cantonNote` + `RegionalFlavor.empty` sentinel (lines 45-82)
  - `class RegionalVoiceService` with:
    - `static SwissRegion regionForCanton(String? canton)` (line 105)
    - `static RegionalFlavor forCanton(String? canton)` (line 119) — **the only method called externally**
- **Private builders:** `_buildRomande`, `_romandeCantonNote`, `_buildDeutschschweiz`, `_deutschschweizCantonNote`, `_buildItaliana`, `_italianaCantonNote` (lines 138-390). All hard-coded French/German/Italian prose with `\u00xx` escapes.
- **Canton set membership** (lines 93-102):
  - Romande: `{VD, GE, NE, JU, VS, FR}` (6)
  - Deutschschweiz: `{ZH, BE, LU, ZG, AG, SG, BS, BL, SO, TG, SH, AI, AR, GL, NW, OW, SZ, UR}` (18)
  - Italiana: `{TI, GR}` (2)
- **Total canton notes written:** VS, GE, VD, NE, JU, FR (Romande — 6/6) · ZH, BE, LU, ZG, BS, SG, AG, BL (Deutschschweiz — 8/18) · TI, GR (Italiana — 2/2). **10 Deutschschweiz cantons** (SO, TG, SH, AI, AR, GL, NW, OW, SZ, UR) land in the region but receive no `cantonNote` — they fall through the `switch`'s `default: return ''`.

### 2.2 Consumers (repo-wide grep for imports of `regional_voice_service.dart` or `RegionalVoiceService`)

Production code (`apps/mobile/lib/`):
| File | Line | Use |
|---|---|---|
| `services/coach/context_injector_service.dart` | 22 | `import '…/regional_voice_service.dart'` |
| `services/coach/context_injector_service.dart` | 260 | `final flavor = RegionalVoiceService.forCanton(profile.canton);` — then appends `flavor.promptAddition` into the local `regionalBlock` string that is concatenated into the coach memory block (lines 254-264) |

**Single production consumer.** One call site. `flavor.localExpressions`, `financialCultureNote`, `humorStyle`, `cantonNote` are **never read** by any production code — only `promptAddition` is used. Those other fields are dead weight today.

Test code (`apps/mobile/test/`):
| File | Lines | Use |
|---|---|---|
| `test/journeys/pierre_golden_path_test.dart` | 22, 192-216 | 4 assertions on `forCanton(VS)` → `romande` + field presence |
| `test/journeys/nadia_golden_path_test.dart` | 22, 190-218 | 4 assertions on `forCanton(TI)` → `italiana` + field presence |

Total test surface: **8 assertions across 2 files**, all pure `forCanton()` return-shape checks. No test exercises the *content* of the strings.

### 2.3 ARB wiring — current state
- **l10n.yaml** (`apps/mobile/l10n.yaml`):
  ```yaml
  arb-dir: lib/l10n
  template-arb-file: app_fr.arb
  output-localization-file: app_localizations.dart
  output-class: S
  preferred-supported-locales: [fr]
  ```
- **ARB files present in `apps/mobile/lib/l10n/`:** `app_fr.arb` (template), `app_en.arb`, `app_de.arb`, `app_es.arb`, `app_it.arb`, `app_pt.arb` — **6 locales, matching CLAUDE.md §7**. (The CLAUDE.md §7 line "ALL user-facing strings → AppLocalizations" holds; the "pt is referenced but absent" assumption in the plan prompt is **stale** — pt.arb exists. Flagged §5.)
- **Generated Dart:** `app_localizations.dart` + `app_localizations_{fr,en,de,es,it,pt}.dart` in-tree.
- **Wiring in `app.dart`:** lines 1024-1025 — `localizationsDelegates: S.localizationsDelegates, supportedLocales: S.supportedLocales`. Single delegate, single supported-locales list. No second gen_l10n config anywhere.

### 2.4 `regional_voice_service.dart` does NOT talk to ARB
The entire file is hard-coded FR/DE/IT prose with escaped unicode. The file header at lines 16-18 explicitly says:
> "LLM prompt context, intentionally FR — all French strings below are injected into the AI system prompt and must not be extracted to ARB files. They are coach identity guidance, not UI copy."
This was the correct call for its current purpose (LLM prompt context). In Phase 6 the purpose shifts: we want regional *UI microcopy* driven by ARB, and the backend identity block becomes codegen-driven. So the file's own stated contract is being replaced in 06-02/06-03.

### 2.5 `Profile.canton` read sites
Grep for `profile.canton` / `coachProfile.canton` under `apps/mobile/lib/` returns **30+ files** (hit the 30 file cap). Notable clusters:
- Coach pipeline: `services/coach/context_injector_service.dart`, `services/coach/coach_orchestrator.dart`, `services/coach/coach_models.dart`, `services/coach/prompt_registry.dart`, `services/coach/fallback_templates.dart`.
- Profile model: `models/coach_profile.dart`.
- Onboarding: `screens/onboarding/quick_start_screen.dart`, `screens/onboarding/intent_screen.dart`.
- Mortgage / tax / life-event screens (many): `epl_combined_screen.dart`, `affordability_screen.dart`, `retroactive_3a_screen.dart`, `rente_vs_capital_screen.dart`, `first_job_screen.dart`, `demenagement_cantonal_screen.dart`, …
- Widgets: `premier_eclairage_section.dart`, `arbitrage_teaser_card.dart`, `cap_engine.dart`, `response_card_service.dart`.

**Trigger point for the new `RegionalLocalizationsDelegate` (D-05):** must hot-reload when `profile.canton` changes. The cleanest insertion is at the **single place where the delegate list is built for `MaterialApp`** — `apps/mobile/lib/app.dart:1024-1025` — by adding a canton-aware delegate that reads canton from the active `ProfileProvider` and injects the correct regional ARB overlay. The 30+ `profile.canton` call sites do NOT need to change — they continue reading canton for their own logic; only the l10n lookup path changes.

---

## 3. Current canton coverage matrix

| Canton | Backend `REGIONAL_MAP` | Backend `_CANTON_TO_PRIMARY` | Mobile region | Mobile `cantonNote` | Phase 6 v1 ARB? |
|---|---|---|---|---|---|
| VD | ✅ inline | — | romande | ✅ | ❌ (→VS via D-05) |
| GE | ✅ inline | — | romande | ✅ | ❌ (→VS) |
| VS | ✅ inline | — | romande | ✅ | ✅ **primary** |
| NE | ❌ | → VD | romande | ✅ | ❌ (→VS) |
| JU | ❌ | → VD | romande | ✅ | ❌ (→VS) |
| FR | ❌ | → VD | romande | ✅ | ❌ (→VS) |
| ZH | ✅ inline | — | deutschschweiz | ✅ | ✅ **primary** |
| BE | ✅ inline | — | deutschschweiz | ✅ | ❌ (→ZH) |
| LU | ❌ | → ZH | deutschschweiz | ✅ | ❌ (→ZH) |
| ZG | ❌ | → ZH | deutschschweiz | ✅ | ❌ (→ZH) |
| BS | ❌ | → ZH | deutschschweiz | ✅ | ❌ (→ZH) |
| BL | ❌ | → ZH | deutschschweiz | ✅ | ❌ (→ZH) |
| SG | ❌ | → ZH | deutschschweiz | ✅ | ❌ (→ZH) |
| AG | ❌ | → ZH | deutschschweiz | ✅ | ❌ (→ZH) |
| SO | ❌ | → ZH | deutschschweiz | ❌ *(fallthrough)* | ❌ (→ZH) |
| TG, SH, AR, AI, OW, NW, GL, SZ, UR | ❌ | → ZH | deutschschweiz | ❌ *(fallthrough)* | ❌ (→ZH) |
| TI | ✅ inline | — | italiana | ✅ | ✅ **primary** |
| GR | ❌ | → TI | italiana | ✅ | ❌ (→TI) |

**Divergence between backend and mobile — the "dual-system" name is literal:**
- Backend explicit set = 6 cantons (VD, GE, VS, ZH, BE, TI).
- Mobile explicit `cantonNote` set = 16 cantons.
- Backend routes Romande secondaries to **VD**; mobile routes them to the generic "romande" flavor (no canton-specific info flows to the coach prompt for NE/JU/FR anyway because only `promptAddition` is consumed).
- Backend routes GR → TI; mobile routes GR → italiana then writes an explicit GR canton note. **One canton (GR) has 3 different descriptions** in 3 different places (backend map absent, backend fallback to TI, mobile explicit note).
- v1 Phase 6 scope collapses everything down to **3 primaries (VS, ZH, TI)** per D-05.

---

## 4. Kill target map

### 4.1 Backend — `services/backend/app/services/coach/claude_coach_service.py`

**Lines to DELETE (Plan 06-02):**
| Line range | Symbol |
|---|---|
| 57-65 | `REGIONAL_MAP` dict (and its leading comment line 57) |
| 67-76 | `_CANTON_TO_PRIMARY` dict (and its leading comment line 67) |
| 91-99 | `_resolve_canton` function (including the blank line preceding it if any) |
| 132-149 | `_REGIONAL_IDENTITY` triple-quoted string |

Total: **~40 LOC deleted**.

**Lines to REWIRE (Plan 06-02):**
| Current line | Current code | New code |
|---|---|---|
| top of file (near line 34) | *(no import)* | `from app.services.coach.regional_microcopy import RegionalMicrocopy` |
| 377 | `regional_identity=_REGIONAL_IDENTITY,` | `regional_identity=RegionalMicrocopy.identity_block(ctx.canton if ctx else None),` |
| 394-397 | 4-line `if ctx and ctx.canton: ...` block that appends `## COULEUR REGIONALE\n{REGIONAL_MAP[resolved]}\n` | **Delete entirely.** `identity_block()` now returns the complete regional string in one shot — there is no second append. Zero-debt rule: single injection point. |

Result: **one import added, one `.format()` kwarg rewired, one 4-line `if` block deleted.** The `build_system_prompt` function shrinks by ~4 LOC; the dual-system becomes a single function call.

**New file to CREATE (Plan 06-02, generated by `tools/regional/regional_microcopy_codegen.py`):**
- `services/backend/app/services/coach/regional_microcopy.py` exposing class `RegionalMicrocopy` with:
  - `CANTON_TO_PRIMARY: dict[str, str]` (D-05 target: NE/JU/FR/VD/GE → VS; all Alémanique → ZH; GR → TI)
  - `resolve(canton: Optional[str]) -> Optional[str]` (returns primary canton ∈ {VS, ZH, TI} or None)
  - `identity_block(canton: Optional[str]) -> str` (returns the full regional prose, sourced from the ARB files, for the resolved primary; neutral fallback text when canton is None or unresolved)

**Tests to update (Plan 06-02):**
- `services/backend/tests/test_coach_firstjob.py` lines 91, 98, 119 — replace `"COULEUR REGIONALE"` substring assertion with an assertion that `RegionalMicrocopy.identity_block(...)` output is present in the prompt (e.g. a canonical marker token emitted by the codegen).
- `services/backend/tests/test_e2e_coach_pipeline.py` line 89 — update the mocked prompt fixture; purely a fixture string change.
- `services/backend/tests/test_coach_chat_endpoint.py` line 399 — `test_system_prompt_includes_regional_identity` body: keep the test name, rewire the assertion to the new codegen output.
- Add regression test: `git grep 'REGIONAL_MAP\s*=' services/backend/` returns 0 matches (REQ REGIONAL-05).

### 4.2 Mobile — `apps/mobile/lib/services/voice/regional_voice_service.dart`

**Kill / keep / rewire table:**
| Symbol | Lines | Decision | Rationale |
|---|---|---|---|
| `enum SwissRegion` | 26-38 | **KEEP** (short-term) — may be reused by the new delegate to resolve primary locale (`fr-CH` / `de-CH` / `it-CH`). Re-evaluate in 06-03; if unused after rewire, delete. | Enum is cheap and semantic. |
| `class RegionalFlavor` + `RegionalFlavor.empty` | 45-82 | **KILL** | Only `promptAddition` is consumed; the other four fields (`localExpressions`, `financialCultureNote`, `humorStyle`, `cantonNote`) are dead code today. ARB layer replaces the whole concept. |
| `RegionalVoiceService._romandCantons` / `_deutschschweizCantons` / `_italianaCantons` | 93-102 | **KEEP & REUSE** inside the new `RegionalLocalizationsDelegate` to resolve base locale from canton, OR re-derive from `CANTON_TO_PRIMARY` shipped by the backend codegen (preferred — single source of truth). **Kill if re-derived.** | Single-source-of-truth wins. |
| `regionForCanton(String? canton)` | 105-112 | **KEEP** as pure helper *iff* SwissRegion enum is kept, **KILL** otherwise. | Depends on enum decision. |
| `forCanton(String? canton)` | 119-134 | **KILL** | Replaced by the delegate doing an ARB lookup. Single caller (`context_injector_service.dart:260`) is rewired in parallel. |
| `_buildRomande` + `_romandeCantonNote` | 138-225 | **KILL** | Hard-coded prose migrates into `app_regional_vs.arb` (D-01). VD/GE/NE/JU/FR drop entirely from v1. |
| `_buildDeutschschweiz` + `_deutschschweizCantonNote` | 229-320 | **KILL** | Hard-coded prose migrates into `app_regional_zh.arb`. BE/LU/ZG/BS/BL/SG/AG drop from v1. |
| `_buildItaliana` + `_italianaCantonNote` | 324-390 | **KILL** | Hard-coded prose migrates into `app_regional_ti.arb`. GR falls through → TI via `CANTON_TO_PRIMARY`. |

**Caller rewire — `apps/mobile/lib/services/coach/context_injector_service.dart`:**
- Line 22 `import '…/regional_voice_service.dart';` → **DELETE** (or replace with import of the new delegate/microcopy accessor).
- Lines 254-264 (the entire `// ── Regional voice flavor ──` block):
  - Current: constructs `regionalBlock` from `flavor.promptAddition`.
  - New: either (a) read `AppRegionalLocalizations.of(context).identityBlock` if the injector has a BuildContext, OR (b) call a pure `RegionalMicrocopyMirror.identityBlock(profile.canton, locale)` helper that mirrors the backend codegen for client-side prompt assembly. **Plan 06-03 picks the approach** — the injector is pure Dart, so option (b) is more likely.
  - Kill line range: **254-264 (11 lines)**, replace with ~3 lines.

**New files to CREATE (Plan 06-03):**
- `apps/mobile/lib/l10n_regional/app_regional_vs.arb` (base `fr-CH`, ~30 keys)
- `apps/mobile/lib/l10n_regional/app_regional_zh.arb` (base `de-CH`, ~30 keys)
- `apps/mobile/lib/l10n_regional/app_regional_ti.arb` (base `it-CH`, ~30 keys)
- `apps/mobile/l10n_regional.yaml` (second gen_l10n config, D-01)
- `apps/mobile/lib/services/l10n/regional_localizations_delegate.dart` (≤ 40 LOC per ROADMAP success criterion 2)
- Widget test covering canton hot-swap on `profile.canton` change.

**`app.dart` wiring (Plan 06-03):**
- Current: `localizationsDelegates: S.localizationsDelegates` (line 1024).
- New: compose with the canton-aware regional delegate: `localizationsDelegates: [...S.localizationsDelegates, RegionalLocalizationsDelegate(cantonListenable)]`. Single line change.

**Test kill/update:**
- `apps/mobile/test/journeys/pierre_golden_path_test.dart` lines 22, 192-216 — **rewrite** to assert that the `RegionalLocalizationsDelegate` loads `app_regional_vs.arb` for `profile.canton = 'VS'` and that a known key resolves to the VS-flavored string.
- `apps/mobile/test/journeys/nadia_golden_path_test.dart` lines 22, 190-218 — same pattern for TI.

### 4.3 Single injection point summary

| Layer | Before (dual) | After (single) |
|---|---|---|
| Backend | `_REGIONAL_IDENTITY` at line 377 + `REGIONAL_MAP[resolved]` append at 394-397 | One call `RegionalMicrocopy.identity_block(ctx.canton)` at the line 377 slot |
| Mobile coach context | `RegionalVoiceService.forCanton(profile.canton).promptAddition` at `context_injector_service.dart:260` | One call `RegionalMicrocopyMirror.identityBlock(profile.canton, locale)` (or ARB lookup) |
| Mobile UI microcopy | Nothing today (regional is coach-prompt-only) | `RegionalLocalizationsDelegate` looks up in `app_regional_{vs,zh,ti}.arb` overlay on top of base `app_{fr,de,it}.arb` |

---

## 5. Flagged side findings (doctrine drifts spotted during the walk)

### 5.1 `_CANTON_TO_PRIMARY` target cantons DRIFT vs CONTEXT.md D-05
- **Current (backend line 68-76):** Romande secondaries (NE/JU/FR) route to **VD**. CONTEXT.md D-05 says they must route to **VS**. VD/GE also currently exist as first-class entries in `REGIONAL_MAP` but will need to route to VS too in the v1 scope (since VD/GE are NOT in the 3 primaries).
- **Impact:** Plan 06-02 codegen of `CANTON_TO_PRIMARY` is **not a copy-paste** of the current dict — it is a **rewrite** targeting `{VS, ZH, TI}` only. Must call out explicitly to Plan 06-02 executor.

### 5.2 Mobile `regional_voice_service.dart` has dead fields
- `localExpressions`, `financialCultureNote`, `humorStyle`, `cantonNote` on `RegionalFlavor` are **never read** by any production consumer. Only `promptAddition` is used (single call at `context_injector_service.dart:262`). This is latent dead code today, becomes explicit deletion in 06-03.

### 5.3 Mobile canton coverage is asymmetric
10 Deutschschweiz cantons fall through the `_deutschschweizCantonNote` `default:` and return `''`. Today they silently get the generic Deutschschweiz block. Post-06-03 this is fine (they all resolve to ZH via `CANTON_TO_PRIMARY`), but it's worth noting that the CURRENT code already produces a coarser output than appearances suggest.

### 5.4 `pt` ARB file IS present — stale assumption in plan prompt
The plan prompt said "missing pt ARB file per CLAUDE.md §7". In reality `apps/mobile/lib/l10n/app_pt.arb` exists alongside `app_localizations_pt.dart`. **All 6 ARB files listed in CLAUDE.md §7 are present.** No action needed; the plan prompt assumption was stale.

### 5.5 `_REGIONAL_IDENTITY` is in English, mixed with French base prompt
The `_BASE_SYSTEM_PROMPT` is mostly French (lines 267-344), but `_REGIONAL_IDENTITY` at 133-149 is in English prose instructing Claude how to behave regionally. Mixed-language system prompts are known to degrade tone adherence (CLAUDE.md §10 autoresearch-prompt-lab finding, W13 sprint notes). The codegen in 06-02 should emit a **French** identity block by default (falling back to `fr-CH` base when canton is None), and rely on the response-language instruction at lines 416-424 of `claude_coach_service.py` to switch Claude's output language. **Recommend this as an explicit 06-02 design note.**

### 5.6 The `COULEUR REGIONALE` marker is region-agnostic but the content is language-specific
Today the header `## COULEUR REGIONALE` (line 397) is always in French regardless of whether the injected `REGIONAL_MAP[resolved]` string is FR (VD/GE/VS), DE (ZH/BE) or IT (TI). Tests at `test_coach_firstjob.py:91/98/119` assert the French marker literally. Post-06-02 the codegen should keep a canonical marker token that tests can assert on without caring about the content language — e.g. `## COULEUR REGIONALE / REGIONALE FÄRBUNG / COLORE REGIONALE` or a hidden marker. **Low priority, but document in 06-02 to avoid test breakage churn.**

### 5.7 `l10n.yaml` only lists `preferred-supported-locales: [fr]`
Only `fr` is preferred, though 6 ARB files exist and 6 generated `app_localizations_*.dart` files are in-tree. This is unrelated to Phase 6 but worth noting for the i18n audit stream — the current config may silently demote `de/en/es/it/pt` below what the tests assume. Flagged for `/autoresearch-i18n` not Phase 6.

---

## 6. Acceptance summary

- **Kill targets named:** 4 backend symbols (`REGIONAL_MAP`, `_CANTON_TO_PRIMARY`, `_resolve_canton`, `_REGIONAL_IDENTITY`) + 2 backend call sites (lines 377 and 394-397) + ~250 LOC of mobile `regional_voice_service.dart` private builders + 1 mobile call site (`context_injector_service.dart:254-264`).
- **Single injection point defined:** `RegionalMicrocopy.identity_block(canton)` at backend line 377 (replaces both 377 and 394-397). Mobile mirrors via delegate or pure helper.
- **Tests cataloged:** 5 backend assertions across 3 files, 8 mobile assertions across 2 files.
- **Side findings logged:** 7 drifts / doctrine notes (one HIGH-impact — §5.1 `CANTON_TO_PRIMARY` retargeting).

Plan 06-02 and Plan 06-03 can proceed against this map without needing to re-read the codebase.
