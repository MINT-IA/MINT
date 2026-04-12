# Architecture Patterns — v2.2 La Beauté de Mint

**Domain:** Cross-cutting design/voice/accessibility layer over mature Flutter + FastAPI app
**Researched:** 2026-04-07
**Scope:** integration of 3 new contracts (VoiceCursorContract, MintTrameConfiance, regional ARB carve-out) into existing v2.0/v2.1 architecture
**Confidence:** HIGH (all consumer claims grep-verified against the live tree)

---

## 0. Operating constraints (locked, no re-litigation)

- VoiceCursorContract is a Phase 0 deliverable (blocks L1.5 + L1.6)
- MTC is a single rendering layer everywhere (no dual-system)
- Regional microcopy = ARB carve-out per canton, base language only
- Galaxy A14 = manual gate (no Android-in-CI this milestone)
- Précision horlogère = MTC bloom only
- Krippendorff α = L1.6 spec validation only

---

## 1. The 3 cross-cutting contracts at a glance

| Contract | SoT location | Dart consumers | Python consumers | Generated? |
|---|---|---|---|---|
| VoiceCursorContract | `tools/contracts/voice_cursor_contract.json` | 6 (intent_screen, ProfileDrawer, RegionalVoiceService, MintAlertObject, coach_message_bubble, response_card_widget) | 2 (claude_coach_service.py, ComplianceGuard) | YES (codegen → Dart const + Pydantic) |
| MintTrameConfiance | `lib/widgets/confidence/mint_trame_confiance.dart` (component) + `EnhancedConfidence` model unchanged | ~12 projection surfaces (see §3) | n/a (rendering only; backend `enhanced_confidence_service.py` already produces axes) | NO |
| Regional microcopy | `lib/l10n/regional/app_regional_<canton>.arb` + Pydantic mirror | RegionalVoiceService (extended), ARB delegate | claude_coach_service.py REGIONAL_MAP must read same source | YES (codegen → Pydantic dict from ARB) |

---

## A — VoiceCursorContract integration

### A.1 Source-of-truth file

**Choice:** `tools/contracts/voice_cursor_contract.json` (single JSON), with codegen producing:
- `apps/mobile/lib/services/voice/voice_cursor_contract.g.dart` (Dart const enums + routing matrix)
- `services/backend/app/services/coach/voice_cursor_contract.py` (Pydantic model + frozen dict)

**Why JSON over YAML:** Dart `dart:convert` is stdlib; Python `json` is stdlib. YAML adds a dependency on both sides. JSON also makes the codegen script trivial (`tools/codegen/voice_cursor_codegen.py`).

**Why not put SoT in Dart:** backend would have to parse Dart. Reverse (SoT in Python) means Flutter codegen depends on Python at build time. JSON is the neutral hub.

**Schema (compact):**
```json
{
  "version": "1.0.0",
  "levels": {
    "N1": {"name": "Neutre", "examples": [...10 phrases...]},
    "N2": {"name": "Vif", ...},
    "N3": {"name": "Complice", ...},
    "N4": {"name": "Piquant", ...},
    "N5": {"name": "Cash", ...}
  },
  "gravity": ["G1", "G2", "G3"],
  "relation": ["new", "established", "intimate"],
  "routing": {
    "G1": {"new": "N1", "established": "N2", "intimate": "N2"},
    "G2": {"new": "N2", "established": "N3", "intimate": "N4"},
    "G3": {"new": "N4", "established": "N5", "intimate": "N5"}
  },
  "guardrails": {
    "g3_min_level": "N2",
    "sensitive_topics_max": "N3",
    "fragile_mode_max": "N3",
    "fragile_mode_ttl_days": 30,
    "n5_weekly_cap": 1
  },
  "user_preference": {
    "soft": "N3",
    "direct": "N4",
    "unfiltered": "N5"
  }
}
```

### A.2 Sync without hand-drift

**Pattern:** codegen script + CI guard.

1. `tools/codegen/voice_cursor_codegen.py` reads JSON → emits Dart `.g.dart` and Python `.py` files with header `// GENERATED — DO NOT EDIT`.
2. CI step: re-run codegen, `git diff --exit-code` on the two generated files. Drift = red build.
3. Both generated files committed (no runtime download — works offline, deterministic).

**Why codegen over runtime read:** Dart enums must be compile-time const for switch exhaustiveness; Pydantic models benefit from static typing. Runtime JSON parsing forfeits both.

### A.3 Consumers (grep-verified)

| File | What it imports today | What it must import |
|---|---|---|
| `apps/mobile/lib/screens/onboarding/intent_screen.dart` | (no voice contract) | `voice_cursor_contract.g.dart` for L1.6c "Ton" question |
| `apps/mobile/lib/widgets/profile_drawer.dart` (or wherever ProfileDrawer lives — verify in plan) | n/a | same, for settings toggle |
| `apps/mobile/lib/services/voice/regional_voice_service.dart:119` (`forCanton`) | nothing | same, to tag `RegionalFlavor` outputs with default level |
| `apps/mobile/lib/widgets/mint_alert_object.dart` (NEW — S5) | n/a | same, drives G2/G3 grammar selection |
| `apps/mobile/lib/widgets/coach/coach_message_bubble.dart` (S3) | n/a | same, reads `level` from message metadata to apply micro-typo variant |
| `apps/mobile/lib/widgets/coach/response_card_widget.dart` (S4) | n/a | same, for premier éclairage tone |
| `services/backend/app/services/coach/claude_coach_service.py:133` (`_REGIONAL_IDENTITY`, `REGIONAL_MAP` line 58) | local constant | import generated `voice_cursor_contract.py`, inject level + guardrails into system prompt |
| `services/backend/app/services/compliance_guard.py` (find canonical path in plan) | n/a | enforce: never N1/N2 on G3, never ≥N4 on sensitive topics, weekly N5 cap |

### A.4 Routing matrix as data, not code

**Choice:** compile-time (codegen emits a `const Map<Gravity, Map<Relation, Level>>`). Resolved via pure function `VoiceCursor.resolve(gravity, relation, userPref)`.

**Why compile-time:** routing is small (3×3=9 cells), changes rarely, and must be exhaustively unit-tested. Runtime reads create a "what version is loaded?" debugging tax for zero benefit.

### A.5 `Profile.voiceCursorPreference` field

**Status:** does not exist in `services/backend/app/schemas/profile.py` (verified — grep returned 0 hits in `services/backend`).

**Add to:**
- `services/backend/app/schemas/profile.py` `ProfileBase`: `voiceCursorPreference: Literal['soft','direct','unfiltered'] = 'direct'`
- `apps/mobile/lib/models/coach_profile.dart` (CoachProfile is the live one — `dead_code` audit shows 73 consumers)
- Migration: nullable column in `profile_model.py` SQLA (default `'direct'`); existing rows migrate at read time.

---

## B — MintTrameConfiance migration architecture

### B.1 Consumers consuming `confidence_scorer.dart` today (grep-verified)

| # | File | Line | What it renders today |
|---|---|---|---|
| 1 | `screens/main_navigation_shell.dart` | 18, 230, 263 | Score-only int, used to gate shell behaviors |
| 2 | `screens/onboarding/data_block_enrichment_screen.dart` | 11, 72, 194 | Per-bloc scoring + score |
| 3 | `screens/coach/retirement_dashboard_screen.dart` | 14, 146 | Confidence as dashboard hero meta |
| 4 | `screens/coach/cockpit_detail_screen.dart` | 10, 126, 128 | Score + per-bloc breakdown |
| 5 | `screens/document_scan/extraction_review_screen.dart` | 8, 636 | Post-extraction delta on `currentConfidence` |
| 6 | `widgets/home/confidence_score_card.dart` | 18, 22, 84 | Card with axis prompts (rich) |
| 7 | `widgets/coach/confidence_blocks_bar.dart` | 9 | Bar of `scoreAsBlocs()` blocks |
| 8 | `widgets/coach/low_confidence_card.dart` | 23 | Score < threshold → low-confidence CTA |
| 9 | `widgets/coach/lightning_menu.dart` | 74 | Score gates menu items |
| 10 | `widgets/retirement/confidence_banner.dart` | (whole file) | Banner-style score |
| 11 | `widgets/profile/trajectory_view.dart` | 336 | Trajectory header confidence |
| 12 | `widgets/profile/futur_projection_card.dart` | 33,54,125,191,423 | `confidenceScore: double` + uncertainty band rendering |
| 13 | `widgets/coach/coach_briefing_card.dart` | 25,37,269,270 | Briefing header confidence |
| 14 | `widgets/coach/retirement_hero_zone.dart` | 45,76,484 | Hero zone score |
| 15 | `widgets/coach/progressive_dashboard_widget.dart` | 36,43,60,166 | Score pilots progressive disclosure depth |
| 16 | `widgets/coach/smart_shortcuts.dart` | 27,32,215 | Score gates shortcuts |
| 17 | `widgets/coach/indicatif_banner.dart` | 16,24,41,77,80 | Inline indicative banner |
| 18 | `widgets/profile/narrative_header.dart` | 13,25,77 | Narrative header score |

> **Reality check vs brief:** brief said "~12". Actual count is **18** (12 widgets + 5 screens + 1 lightning menu). Two categories:
> - **Renderers of confidence** (must adopt MTC): #6, #10, #11, #12, #13, #14, #17, #18 — 8 surfaces
> - **Logic gates on score** (do NOT need MTC, just keep reading the int): #1, #2 (gating), #5 (delta), #8, #9, #15, #16 — 7 surfaces
> - **Both** (renders AND gates): #3, #4, #7 — 3 surfaces, must migrate the rendering half only

**Net migration target for L1.2b: 11 rendering surfaces** (8 pure renderers + 3 mixed).

### B.2 Migration pattern

**Drop-in widget replacement, NOT consumer refactor.**

Build `MintTrameConfiance` as a single widget with three constructors:

```dart
class MintTrameConfiance extends StatelessWidget {
  const MintTrameConfiance.inline({required this.confidence, this.onTap});
  const MintTrameConfiance.detail({required this.confidence});
  const MintTrameConfiance.audio({required this.confidence}); // SemanticsLabel only
}
```

Each existing renderer becomes a 1-line replacement: `MintTrameConfiance.inline(confidence: ec)`. Score-int gates (#1, #5, #8, #9, #15, #16) stay untouched — they read `confidence.combined` and don't render anything.

**Why drop-in over refactor:** 18 surfaces × refactor = scope explosion + test breakage. Drop-in keeps the data flow identical.

### B.3 Test breakage estimate

`grep -l 'confidence' apps/mobile/test/widgets/` gives a non-trivial count (not exhaustively run here — must be done in plan step). Likely impact:
- Widget golden tests for `confidence_score_card`, `futur_projection_card`, `retirement_hero_zone`, `coach_briefing_card`, `narrative_header`, `indicatif_banner`, `confidence_banner`, `progressive_dashboard_widget` → **8 golden test files to regenerate**.
- Behavioral tests reading `find.text('${score}%')` will likely still pass since MTC keeps the percentage in the inline variant.

**Plan must run `flutter test --update-goldens` once after L1.2a, document the diff, then re-bless under Julien's eye.**

### B.4 Bloom animation budget

- **Trigger:** first appearance per session **per surface instance**, not per app session. `AnimatedSwitcher`-style initial-frame detection in `initState`.
- **Budget on Galaxy A14:** 250ms ease-out on `Transform.scale(0.96 → 1.0)` = ~15 frames at 60fps. A14 sustains 60fps for single-widget transforms; concurrent bloom on a screen with 3 MTC instances = the only risk. Mitigation: stagger blooms 60ms apart. Hard cap: skip bloom if `MediaQuery.disableAnimations` true (accessibility).
- **Memory:** stateless animation controller per instance, disposed in `dispose()`. Verify no controller leak on hot reload (W14 façade lesson).

---

## C — Regional microcopy ARB carve-out

### C.1 Current ARB structure (verified)

```
apps/mobile/lib/l10n/
  app_fr.arb   (10'735 lines — template)
  app_en.arb
  app_de.arb
  app_es.arb
  app_it.arb
  app_pt.arb
```

Single namespace `AppLocalizations`, generated by `flutter gen-l10n` with default `l10n.yaml`.

### C.2 Multi-namespace pattern

**Choice:** parallel namespace `AppRegionalLocalizations` + custom `LocalizationsDelegate`, NOT composition into `AppLocalizations`.

**Why parallel:** `flutter gen-l10n` cannot multi-namespace from one config. Two options:
1. Two `l10n.yaml` files run sequentially (`l10n.yaml` + `l10n_regional.yaml`) → both produce separate generated classes → both registered in `MaterialApp.localizationsDelegates`.
2. Custom Dart delegate that loads `app_regional_<canton>.arb` from `rootBundle` at runtime, parses, returns a `Map<String, String>` lookup.

**Recommendation: option 1** (two `gen-l10n` runs). Reasons:
- Stays inside the official toolchain; type-safe accessors; Android Studio jump-to-source works.
- Adds to `pubspec.yaml`:
  ```yaml
  flutter:
    generate: true
  ```
  And a second l10n config (`l10n_regional.yaml`) pointed at `lib/l10n/regional/`.

```
apps/mobile/lib/l10n/regional/
  app_regional_vs.arb       (locale fr-CH, but namespaced by canton)
  app_regional_zh.arb       (locale de-CH)
  app_regional_ti.arb       (locale it-CH)
```

**Resolution lookup** at call site:
```dart
final regional = AppRegionalLocalizations.forCanton(profile.canton);
final greeting = regional?.greeting ?? AppLocalizations.of(context)!.greetingDefault;
```

`forCanton` is a thin static factory that maps canton → `AppRegionalVS` / `AppRegionalZH` / `AppRegionalTI`, returns `null` for unsupported cantons (= silent fallback to base ARB, no surprise translations). It does NOT translate VS strings into IT/PT.

### C.3 Backend mirror

**Current state:** `services/backend/app/services/coach/claude_coach_service.py:58` defines `REGIONAL_MAP` as a hand-coded Python dict, and `_REGIONAL_IDENTITY` (line 133) is a hand-coded Python string. **This is a duplication of `RegionalVoiceService.forCanton()` in Flutter** — exactly the kind of dual-system v2.2 must kill.

**Pattern:** ARB → Pydantic codegen.

1. `tools/codegen/regional_microcopy_codegen.py` reads `app_regional_<canton>.arb` files, emits `services/backend/app/services/coach/regional_microcopy.py` containing:
   ```python
   REGIONAL_MICROCOPY: dict[str, RegionalMicrocopy] = { "VS": RegionalMicrocopy(...), ... }
   ```
2. `claude_coach_service.py` imports `REGIONAL_MICROCOPY` instead of hardcoding `REGIONAL_MAP` + `_REGIONAL_IDENTITY`. The legacy Python constants get DELETED in the same MR (zero-debt rule).
3. CI guard same as voice contract: codegen + `git diff --exit-code`.

**Why ARB-as-source over JSON:** L1.4 microcopies are written by Julien + native validators inside ARB (their natural editing format). Forking them to JSON for backend creates two truths.

**Pydantic model:**
```python
class RegionalMicrocopy(BaseModel):
    canton: str
    base_locale: str  # 'fr-CH' | 'de-CH' | 'it-CH'
    prompt_addition: str
    local_expressions: list[str]
    financial_culture_note: str
    humor_style: str
    canton_note: str = ''
```

In-memory dict, not persisted (3 cantons × few KB = trivial).

---

## D — Build order DAG and parallelism

### D.1 Phase 0 (must ship before any L1.x chantier starts)

| # | Deliverable | Why blocks downstream |
|---|---|---|
| P0.1 | STAB-17 manual tap-render walkthrough by Julien on Galaxy A14 | Confirms v2.1 wiring before adding new layers |
| P0.2 | Galaxy A14 perf baseline doc (cold start, scroll FPS, frame budget at S2 home) | L1.2a bloom budget needs this |
| P0.3 | `tools/contracts/voice_cursor_contract.json` + codegen scripts + generated Dart/Python files committed | L1.5, L1.6 import these |
| P0.4 | `Profile.voiceCursorPreference` field added (backend Pydantic + Flutter CoachProfile + SQLA migration) | L1.6c writes to it |
| P0.5 | 4 broken providers from AUDIT_DEAD_CODE.md (B1-B4: MintStateProvider, FinancialPlanProvider, CoachEntryPayloadProvider, OnboardingProvider) wired into `app.dart` MultiProvider | L1.2b touches `mint_home_screen.dart` which currently relies on try/catch swallow — façade-sans-câblage must die before MTC migration |
| P0.6 | Krippendorff α tooling provisioned (`tools/voice/krippendorff.py` + 15-tester pipeline) | L1.6a validation gate |
| P0.7 | Regional ARB infra (l10n_regional.yaml, empty namespace, build wired) | L1.4 writes content into infra |

**Why P0.5 here:** L1.2b migrates `confidence_score_card.dart` which is consumed by `mint_home_screen.dart`. Currently mint_home_screen reads MintStateProvider via try/catch fallback (audit line 41-50). Wiring the provider now means the migration can trust real state, not silent fallback.

### D.2 DAG (after Phase 0)

```
P0 ─┬─> L1.1 (audit du retrait, S1-S5) ──┬─> L1.3 (microtypo S1-S5) ──┐
    │                                      │                            │
    ├─> L1.2a (MTC component + S4) ────────┴─> L1.2b (MTC migrate ×11) ─┤
    │                                                                    │
    ├─> L1.4 (regional VS/ZH/TI ARB content) ────────────────────────────┤
    │                                                                    │
    ├─> L1.6a (VOICE_CURSOR_SPEC.md + 50 phrases + Krippendorff α) ──┐   │
    │                                                                 │   │
    └─> L1.5 (MintAlertObject S5, imports VoiceCursorContract) ──────┤   │
                                                                      │   │
                                       L1.6b (rewrite 30 coach phrases)──┤
                                       L1.6c (intent_screen + drawer)────┤
                                                                          │
                                                          v2.2 ship gate ─┘
                                                          (Julien manual A14 + 3 live a11y sessions)
```

### D.3 Parallel groups

- **Group α (after P0):** L1.1 (kill old confidence rendering on S4), L1.2a (build MTC + migrate S4), L1.4 (regional content), L1.6a (spec). All four can run in parallel — they touch disjoint files.
- **Group β (after Group α):** L1.2b (migrate 11 surfaces), L1.3 (microtypo on S1-S5), L1.5 (MintAlertObject), L1.6b (rewrite 30 phrases). These need L1.2a (MTC component exists) + L1.6a (spec exists) + L1.1 (S1-S5 cleaned) + L1.4 (regional content for L1.6b validation in 3 langs).
- **Group γ (sequential after Group β):** L1.6c (UI for tone setting). Needs L1.6b complete because the setting only makes sense once phrases obey the contract.

### D.4 Critical path

**P0.3 → L1.6a → L1.6b → L1.6c** is the longest chain. L1.6b is the bottleneck: 30 phrases × validation by Julien + 2 copywriters. Estimate: 5-7 working days. Phase 0 = 3-4 days. Group α parallel ≈ 5 days. Group β parallel ≈ 5-7 days. **Total: 4-5 weeks if P0 starts immediately and no Krippendorff α failure forces L1.6a rewrite.**

**Slack:** L1.3 microtypo and L1.4 regional content can absorb a week of slip without affecting ship date.

### D.5 Dependency deadlocks (avoided by design)

- **Risk:** L1.5 MintAlertObject importing VoiceCursorContract before P0.3 ships → blocked. Mitigation: P0.3 is the first deliverable in Phase 0.
- **Risk:** L1.6b rewriting phrases that reference UI strings later changed by L1.3 microtypo → double work. Mitigation: L1.3 only touches typography (font, size, line-height), never copy text.
- **Risk:** L1.2b migrating widgets that L1.1 marked for deletion → wasted migration. Mitigation: L1.1 ships first inside Group α and produces a "DELETE / KEEP" list that L1.2b reads on day 1.

---

## E — Integration with v2.0/v2.1 work

### E.1 v2.1 STAB-12 coach tools and L1.5 MintAlertObject

`AUDIT_COACH_WIRING.md` confirms 4 tools wired E2E: `route_to_screen`, `generate_document`, `generate_financial_plan`, `record_check_in`.

**Decision:** MintAlertObject is **NOT a new coach tool**. It is a UI primitive that consumes alert objects produced by the existing **anticipation engine** (v2.0) and the **rules engine / nudge engine** (`services/nudge/nudge_engine.dart`, `services/coach/proactive_trigger_service.dart`, `services/contextual/action_opportunity_detector.dart`).

**Wiring:**
```
NudgeEngine / ProactiveTriggerService / AnticipationProvider
        │
        ▼  produces AlertPayload { gravity: G1|G2|G3, topic, copy, ctas }
        │
        ▼  resolved through VoiceCursor.resolve(gravity, profile.relationPhase, profile.voiceCursorPreference)
        │
        ▼  rendered by MintAlertObject (S5)
```

**Why not a tool:** tools are LLM-callable side effects. Alerts are deterministic (rule-based, v2.0 design). Adding a `show_alert` tool would re-introduce LLM-in-the-loop where v2.0 explicitly chose rules.

### E.2 v2.0 anticipation engine routing

`AnticipationProvider` (verified LIVE in AUDIT_DEAD_CODE row 13) currently emits alerts that are consumed by `mint_home_screen.dart`. Today they render as ad-hoc cards.

**Migration:** in L1.5, those rendering call sites switch to `MintAlertObject(payload: anticipation.next)`. The provider contract does not change. Anticipation tags each alert with `gravity` (new field — additive, default G1, backfilled by rule).

### E.3 ContextualCard ranked feed and MTC

`ContextualCardProvider` (LIVE row 14) ranks home cards. **MTC applies to the cards that render confidence**, not to the ranking. Ranking interacts with G1/G2/G3 only insofar as the new `Card.gravity` field becomes a ranking tiebreaker (G3 cards float to top of ranked feed). This is a 1-line change in `card_ranking_service.dart` (verify exact path in plan).

**Anti-pattern to avoid:** letting G1/G2/G3 become a hard sort key. Ranking already balances freshness, relevance, and dismissals; gravity is a tiebreaker, not a primary key.

### E.4 Backend `enhanced_confidence_service.py`

Backend mirror exists (`services/backend/app/services/confidence/enhanced_confidence_service.py`). MTC is a Flutter rendering layer; backend confidence scoring stays untouched. **No backend change for L1.2a/b.**

---

## F — Pitfalls flagged here (also in PITFALLS.md)

1. **Codegen drift** — if anyone hand-edits the generated `voice_cursor_contract.g.dart` or `regional_microcopy.py`, the contract diverges silently. Mitigation: file header `// GENERATED — DO NOT EDIT — run tools/codegen/voice_cursor_codegen.py` + CI guard.
2. **Dual-system MTC** — if even ONE of the 11 rendering surfaces is missed in L1.2b, the legacy `confidence_score_card` shape ships alongside MTC. Mitigation: write a `tools/checks/no_legacy_confidence_render.py` grep that fails CI on any `confidenceScore.toStringAsFixed(0)` outside `mint_trame_confiance.dart`.
3. **Regional microcopy translated by mistake** — a future translator sees `app_regional_vs.arb` and runs it through DeepL into PT. Mitigation: ARB header comment `// LOCALE-LOCKED: fr-CH only` + lint script that fails build if `app_regional_*.arb` exists in any non-base locale.
4. **Provider leak via try/catch fallback (P0.5)** — `mint_home_screen.dart:124,638` and friends currently swallow `ProviderNotFoundException`. Wiring the providers is necessary but not sufficient — also remove the try/catch silent fallbacks, or you keep shipping the façade.
5. **Bloom animation on accessibility-disabled devices** — must respect `MediaQuery.disableAnimations` AND TalkBack/VoiceOver state. Forgetting this fails AAA on S4.
6. **`claude_coach_service.py` REGIONAL_MAP not deleted** — if codegen ships but the legacy constant stays, drift starts on day 1. Mitigation: L1.4 MR is rejected unless `git grep 'REGIONAL_MAP\s*=' services/backend/` returns 0.

---

## Sources

- Brief: `visions/MINT_DESIGN_BRIEF_v0.2.3.md`
- Project state: `.planning/PROJECT.md`
- Façade audit: `.planning/milestones/v2.1-phases/07-stabilisation-v2-0/AUDIT_DEAD_CODE.md`
- Verified files (grep): `apps/mobile/lib/services/voice/regional_voice_service.dart`, `apps/mobile/lib/services/coach/context_injector_service.dart`, `services/backend/app/services/coach/claude_coach_service.py`, `services/backend/app/schemas/profile.py`, `apps/mobile/lib/l10n/`, all 18 confidence consumers listed in §B.1
- CLAUDE.md §2 architecture, §6 compliance, §7 i18n
