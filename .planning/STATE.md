---
gsd_state_version: 1.0
milestone: v2.9
milestone_name: Chat-as-Verb Pivot
status: executing
stopped_at: Completed wave-1b-06-PLAN.md — coach_citation_modal.dart shipped + wired into bubble + 4 widget tests GREEN; branch feature/wave-1b-06-citation-modal ready for PR
last_updated: "2026-05-15T09:58:42.175Z"
last_activity: 2026-05-15
progress:
  total_phases: 12
  completed_phases: 1
  total_plans: 7
  completed_plans: 4
  percent: 57
---

# GSD State: MINT v2.9 — Chat-as-Verb Pivot

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-19) + .planning/MILESTONE-CHAT-AS-VERB-2026-05-09.md (active milestone, 7 phases).

**Core value:** MINT is 70% structured wiki + simulators, 30% narration. The pivot kills the chat-tab as destination, makes cards the home, turns chat into a verb invocable from card-actions ("explique / simule / rassure-moi") with 3-turn cap, citation gate on every emitted number, and DAG invalidation on stale projections.

**North-star metric:** Turns/user/week DOWN, DAU UP, quarter over quarter.

**Current focus:** Phase 1b — citation-chips

## Strategic Frame (per MILESTONE-CHAT-AS-VERB-2026-05-09)

- **Doctrine:** the wiki is the asset ; chat is a precision tool, not a destination ; every number carries a citation chip ; narrator LLM is mathematically incapable of emitting an un-cited number.
- **Source:** 4-expert panel synthesis 2026-05-09 (Cleo strategist + Karpathy architect + adversarial agent + UI auditor) + code base audit 2026-05-09 (52 fields wiki, 17 simulators, coach text-first) + PO directive « MINT n'est pas un chat. Wiki + simulations + minimum chat livraison. »
- **5-gate exit contract per phase:** G1 Maestro flow / G2 device by Julien / G3 dev CI green / G4 regression suite / G5 LSFin+accent+ARB lint.
- **Critical path:** ~14 days with parallel UI track (90-92-93) and architecture track (91-94-95-96).

## Current Position

Phase: 1b (citation-chips) — EXECUTING
Plan: 7 SUMMARYs landed of 9 (plans 01/02/03/04/05/06/07 closed ; 08/09 pending)
Status: Plan 06 closed, branch feature/wave-1b-06-citation-modal ready for PR
Last activity: 2026-05-15

## Plan wave-1b-06 Receipt (CoachCitationModal bottom-sheet, 2026-05-15)

- Files created : 2 (1 modal widget + 1 SUMMARY)
- Files modified : 5 (1 message bubble + 2 test files + 2 lint baselines)
- Widget : `apps/mobile/lib/widgets/coach/coach_citation_modal.dart` 227 LOC — top-level `showCoachCitationModal(context, chip, {onRememberTap})` + private `_CoachCitationModalBody`
- 5 sections : drag handle / `s.coachCitationModalTitle(toolDisplayName)` header / truncated 16-char `inputs_hash` (SelectableText monospace) / relative `computed_at` row reading 4 ARB keys (Q8_DECISION) / collapsible `ExpansionTile` JSON viewer (`Key('coachCitationModalJsonExpansion')`, pretty-printed via `JsonEncoder.withIndent('  ')`) / `Souviens-toi` CTA (`Key('coachCitationModalRememberCta')`, fires `onRememberTap` + Navigator.pop)
- Q7_DECISION shipped : `flag_state` badge dropped in v1 (chip only renders when flag=on, badge would always read "on" with zero info content) — `grep -cE "flag_state|flagState"` returns 0
- Q8_DECISION shipped : 4 relative-time ARB keys consumed (`coachCitationRelativeJustNow|Minutes|Hours|Days`, 3 ICU plural-aware) — zero Dart literal leak
- Wiring : `coach_message_bubble.dart` import at line 11 + onChipTap at lines 175-192 invokes `showCoachCitationModal(...)` with `onRememberTap` SnackBar acknowledgement (save_insight wiring deferred to Wave 2)
- Tests : Plan 01's 3 modal stubs + 1 Souviens-toi stub unskipped + GREEN (4/4)
- Gates green :
  - `flutter analyze` → 253 issues = baseline (0 new errors)
  - `flutter test test/widgets/coach/` → 737/737 pass (+4 vs Plan 05 baseline 733/733, 0 regressions)
  - `prefer_mint_color_token` → clean (23 grandfathered) — `MintColors.transparent` swap
  - `prefer_mint_text_style` → clean (683 grandfathered, line-shift baseline regen)
  - `prefer_mint_radius` → clean (42 grandfathered, line-shift baseline regen)
  - `prefer_mint_cta` → clean (-1 from baseline)
  - `prefer_mint_fonts` → clean (92 grandfathered, 2 lint-ignores for `fontFamily: 'monospace'` on hash + JSON SelectableText)
- Commits : `cd842900` (T1 modal widget) → `9f475812` (baseline regen) → `6f0faad0` (T2 wire + tests)
- Duration : ~6 min
- Deviations (5 auto-fixed) : (a) Rule 1 — plan referenced `AppLocalizations`, actual is `S` (inherited from Plan 05) ; (b) Rule 1 — plan imports referenced `text_styles.dart`/`spacing.dart`, actual is `mint_text_styles.dart`/`mint_spacing.dart` (inherited from Plan 05) ; (c) Rule 2 — `Colors.transparent` → `MintColors.transparent` ; (d) Rule 2 — `fontFamily: 'monospace'` lint-ignores added (no `MintTextStyles.monospace()` token exists) ; (e) Rule 3 — bubble wiring 18-line insertion shifted 3 pre-existing violations downstream, baseline regen as separate chore commit. Zero behavioural deviations.
- 0-trust : wave-1b-06-SUMMARY.md `## Self-Check: PASSED` cited at .planning/phases/wave-1b-citation-chips/wave-1b-06-SUMMARY.md with 9 file evidences + 9 command citations
- USER VALUE DELIVERED : NONE end-user-visible YET. Modal opens only when a `ToolCallCitationChip` is tapped, which requires the Wave 1a `COACH_TOOL_SERVER_SIDE_*=true` Railway flip (post-Plan-08 coupled deploy per CONTEXT D-01). PR opened against `dev`, NOT merged. Stage 1 of 4 per CLAUDE.md §9.5. Plan 08 (Sentry breadcrumb) hooks into `onChipTap` for `coach.citation.tool_call_id.<tool>.emitted` ; Plan 09 (Maestro G1) references `Key('coachCitationModalJsonExpansion')` + `Key('coachCitationModalRememberCta')` for end-to-end tap flow.

## Plan wave-1b-05 Receipt (CoachCitationChipsSection widget, 2026-05-15)

- Files created : 8 (1 widget + 6 PNG goldens + 1 SUMMARY)
- Files modified : 5 (1 message bubble + 2 test files + 2 lint baselines)
- Widget : `apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart` 123 LOC — sibling of CoachSourcesSection (NOT extension per RESEARCH §9.4)
- Wiring : `coach_message_bubble.dart` import + render block between Sources (line 159-165) and Disclaimers (line 181), gated by `msg.citationChips.isNotEmpty`
- Tests : Plan 01's 4 widget stubs + 6 golden stubs unskipped + GREEN (4/4 widget, 6/6 golden)
- Goldens : 6 PNGs 5.2-5.5 KB each (NOT 4 KB stubs) — one per Wave 1a tool
- Gates green :
  - `flutter analyze` → 253 issues = baseline (0 new errors)
  - `flutter test test/widgets/coach/` → 733/733 pass (0 regressions)
  - `prefer_mint_text_style` → clean (683 grandfathered, line-shift baseline regen)
  - `prefer_mint_color_token` → clean (23 grandfathered)
  - `prefer_mint_radius` → clean (42 grandfathered, line-shift baseline regen)
  - `prefer_mint_cta` → clean
  - `prefer_mint_fonts` → clean (92 grandfathered)
- Commits : `fee1f726` (T1 widget) → `bfd78756` (baseline regen) → `38eda46f` (T2 wire+tests+goldens)
- Duration : ~5 min
- Deviations (2 × Rule 1 codebase-shape mismatches) : (a) plan imports `text_styles.dart`/`spacing.dart`, actual is `mint_text_styles.dart`/`mint_spacing.dart` ; (b) plan referenced `AppLocalizations.of(context)!`, actual generated class is `S` (`app_localizations.dart:68`). No behavioural deviation.
- 0-trust : wave-1b-05-SUMMARY.md `## Self-Check: PASSED` cited at .planning/phases/wave-1b-citation-chips/wave-1b-05-SUMMARY.md with 8 file evidences + 8 command citations
- USER VALUE DELIVERED : NONE end-user-visible YET. Chip surface activates only when `ChatMessage.citationChips` non-empty, which requires the Wave 1a `COACH_TOOL_SERVER_SIDE_*=true` Railway flip (post-Plan-08 coupled deploy per CONTEXT D-01). Plan 06 (modal) hooks into the empty `onChipTap` callback to deliver tap-to-view UX.

## Plan wave-1b-07 Receipt (ARB citation keys × 6 locales, 2026-05-15)

- Files created : 1 (.planning/phases/wave-1b-citation-chips/wave-1b-07-SUMMARY.md)
- Files modified : 13 (6 ARB + 7 generated app_localizations*.dart via flutter gen-l10n)
- ARB delta : 90 new entries (15 keys × 6 locales : fr/en/de/es/it/pt)
- 5 frame keys verbatim from RESEARCH §6.3 : coachCitationChipsHeader, coachCitationChipLabel(toolDisplayName), coachCitationModalTitle(toolDisplayName), coachCitationJsonViewerLabel, coachCitationRememberCta
- 6 tool-name keys (Q6 doctrine i18n) : coachToolBudgetSnapshot, RetirementProjection, CrossPillarAnalysis, CoupleOptimization, CapStatus, RetrieveMemories
- 4 Q8 relative-time keys (3 ICU plural-aware `(int count)`) : coachCitationRelativeJustNow, Minutes, Hours, Days
- Gates green :
  - `python3 tools/checks/arb_parity.py` → exit 0 (6 locales, 6777 keys each)
  - `python3 tools/checks/banned_terms_arb.py` → exit 0 (6 locales clean)
  - `python3 tools/checks/accent_lint_fr.py --file app_fr.arb` → exit 0
  - `flutter gen-l10n` → exit 0
  - `flutter analyze` → 253 issues (= baseline-273, 0 new errors)
- Commits : 49142b79 (atomic 6-locale ARB) → 886a6fd1 (gen-l10n regen)
- Duration : 5 min
- Deviation (1) : Rule 3 - blocking — Task 1 (FR+EN) and Task 2 (DE/IT/ES/PT) merged into single ARB commit because lefthook `arb-parity-gate` fails closed on per-locale intermediate state ; atomic 6-locale update preserves gate's fail-closed contract.
- 0-trust : wave-1b-07-SUMMARY.md `## Self-Check: PASSED` cited at .planning/phases/wave-1b-citation-chips/wave-1b-07-SUMMARY.md with 9 deterministic citations
- USER VALUE DELIVERED : NONE end-user-visible YET. Plan 07 ships i18n surface only ; plans 05 (CoachCitationChipsSection) + 06 (CoachCitationModal) consume these getters. End-to-end sim verification deferred to Plan 09 close-out.

## Plan wave-1b-03 Receipt (Narrator Grammar Fragment, 2026-05-15)

- Files created : 1 (.planning/phases/wave-1b-citation-chips/wave-1b-03-SUMMARY.md)
- Files modified : 3 (citation_grammar.py + test_tool_call_id_grammar.py + test_narrator_grammar_fragment.py)
- Tests added : 0 net new (3 Plan-01 stubs transitioned SKIPPED → PASSED)
- Full backend pytest : 6877 passed, 67 skipped, 1 xfailed in 113.18s (Plan 02 baseline 6874 → +3 = exact match for unskipping 3 grammar stubs, zero regressions)
- Phase 94 byte-identity : test_byte_identity_flag_off 6/6 green (preserved)
- test_citation_gate/ : 212 passed (Plan 02 baseline 212, preserved)
- test_dag_invalidation/test_pack_registry_coupling : 2/2 green (Plan 02's 24-key drift detector still operational)
- Commits : 5224af94 (RED — unskip Plan-01 stubs) → 29b01531 (GREEN — tool_paragraph + tool_example + intent always-on + 24-key test re-tighten)
- Duration : ~9 min execution
- 0-trust : wave-1b-03-SUMMARY.md `## Self-Check: PASSED` cited at .planning/phases/wave-1b-citation-chips/wave-1b-03-SUMMARY.md
- **Q5_DECISION shipped** : 1-segment grammar `{{cite:tool_<name>}}` (RESEARCH §4.3 Option A) adopted instead of CONTEXT line 36's 2-segment `{{cite:tool_call_id:<inputs_hash>}}`. Respects CONTEXT hard constraint #4 (zero edit to `_RE_CURRENCY` / `_RE_PERCENT` / `_RE_CITE_PLACEHOLDER` regexes in citation_parser.py). Per-call `inputs_hash` travels via the tool response container, not the placeholder. Julien reviews at PR time; if rejected, alternative cost = 2-3 additional plans.
- **tool_paragraph shipped** : added in BOTH `_build_citation_grammar_fragment` (full fragment) AND `build_intent_scoped_citation_grammar` (intent-scoped variant) header builders. Verbatim FR per RESEARCH §4.4 : « Certaines clés (`tool_*`) marquent un chiffre calculé côté serveur — son `inputs_hash` voyage avec la réponse, tu n'as pas besoin de le citer dans le texte… ». Banned-terms + accent_lint exit 0.
- **tool_example shipped** : added `**ACCEPTÉ — chiffre calculé côté serveur**` block in BOTH builders. Verbatim per RESEARCH §4.4 with `{{cite:tool_budget_snapshot}}` placeholder + LSFin-safe modal verb « pourrait ».
- **Always-on intent mapping shipped** : `_WAVE_1B_TOOL_KEYS_ALWAYS_ON` frozenset (6 tool keys) unioned into EVERY bucket of `_INTENT_TO_CITATION_KEYS` (debt / housing / family / career / retirement / taxes / tax / mortgage). Tool calls are LLM-driven, NOT intent-driven — the narrator can call `get_budget_status` on any intent.
- **Test renamed** : test_fragment_lists_all_18_registry_keys → test_fragment_lists_all_24_registry_keys (re-tighten from Plan 02's transitional 18-non-tool sub-baseline to unified 24-key total + preserved 18-non-tool + 6-tool sub-baselines as independent regression checks).
- **3 Plan-01 stubs transitioned SKIPPED → PASSED** : `test_grammar_fragment_lists_all_tool_keys`, `test_grammar_fragment_lists_all_24_registry_keys`, `test_intent_scoped_grammar_includes_tools`. 0 `@pytest.mark.skip` markers remain in test_tool_call_id_grammar.py.
- **Token-count delta on rendered fragment** : pre-Plan-03 5'880 chars / 1'960 approx tokens → post-Plan-03 6'502 chars / 2'167 approx tokens (+10.6% / +207 tokens). Within RESEARCH §A4 budget (<5% of ~80 kB narrator prompt = <4 kB grammar allotment).
- Zero deviations from plan. Plan-prescribed implementation matched the codebase shape exactly; no Rule 1-4 auto-fixes triggered.
- USER VALUE DELIVERED : NONE YET — Plan 03 only proves grammar fragment correctness + intent mapping + 15 test assertions. Narrator LLM emission of `{{cite:tool_*}}` against the new doctrine is Plan 04 wiring; Flutter chip rendering is Plan 05/06; Sentry breadcrumb is Plan 08. No end-to-end user flow exercised. PR opened against `dev`, NOT merged. Per CLAUDE.md §9.5 — Stage 1 of 4.

## Plan 96-03 Receipt (Wave 3 Cross-stack, 2026-05-11)

- Files created : 14 (1 mobile asset metaphors.toml + 1 backend mirror + 1 parity lint + 1 backend hook-linter + 1 backend metaphor_lookup + 1 Dart metaphor_lookup + 1 Dart NarrativeSleeve model + 1 Dart metaphor_lookup test + 1 Dart walkback test + 1 Dart NarrativeSleeve render test + 2 Python test files + 1 Maestro G1 flow + 1 FLAG-FLIP-PROPOSAL.md)
- Files modified : 4 (lefthook.yml + apps/mobile/pubspec.yaml + services/backend/app/services/coach/citation_parser.py + apps/mobile/lib/widgets/mint_chat_overlay.dart)
- Tests added : 42 (13 narrative_sleeve_lint + 6 metaphor_lookup Python + 7 metaphor_lookup Dart + 5 walkback Dart + 11 NarrativeSleeve render Dart)
- Full backend pytest : 6586 passed, 60 skipped, 1 xfailed (Plan 96-02 baseline 6567 → +19 net new W3 Python = 6586 exact, zero regressions)
- Full Flutter test : 8401 passed, 24 skipped (Plan 96-01 baseline 8378 → +23 net new W3 Dart = 8401 exact, zero regressions)
- Phase 94 byte-identity : 181 passed, 1 skipped (preserved)
- Phase 95 byte-identity : 74 passed (preserved)
- flutter analyze : 273 issues — identical to baseline (zero new issues)
- D-26 grep gate : 0 hits on mint_card_action_bar.dart + mint_chat_overlay.dart
- Commits : f4f3446d (T0) → 1b381faa (T1) → 8ab24f96 (T2) → dfd386f6 (T3)
- Duration : ~38 min execution (T0-T3)
- 0-trust : 96-03-SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/96-mvp-chat-as-verb/96-03-SUMMARY.md
- **D-17 shipped** : `apps/mobile/assets/metaphors.toml` (+ byte-equal backend mirror at `services/backend/app/data/metaphors.toml`) — 8 entries × 3 archetypes (swiss_native, expat_eu, cross_border) × 2 cantons (VD, GE) × 2 life events (housing, family). Verbatim FR, accent-clean, LSFin-clean, no retirement framing (CLAUDE.md §3). sha256 match = `528a34c9736cd44daafb282530d7c7a0c50c9e32b258430dc85d85991ad8098a`.
- **T-96-W3-TOMLPoisoning mitigation shipped** : `tools/checks/metaphor_parity.py` (sha256 compare + `--scan-values` LSFin + PII walk) + lefthook pre-commit entry. Python 3.11+ stdlib `tomllib` with `tomli` backport fallback for older runtimes.
- **D-16 shipped** : `services/backend/app/services/coach/narrative_sleeve_lint.py` — response middleware. `lint_sleeve(NarrativeSleeve) → NarrativeSleeve` swaps `hook` to `HOOK_FALLBACK = "Voyons ensemble ce que ça change pour toi."` on `\d` match. 3 ReDoS defenses : simple character class regex (`r"\d"`), SIGALRM 100 ms budget, broad-except fail-safe. Non-PII Sentry breadcrumb `coach.narrative_sleeve.hook_swap` (payload = `original_hook_length` only).
- **D-16 middleware wiring shipped** : `services/backend/app/services/coach/citation_parser.py` imports `lint_sleeve` + exposes `lint_response_sleeve(sleeve | None) → sleeve | None` (None-safe passthrough + delegate). Citation gate (`_substitute_placeholders`) stays first in middleware chain ; sleeve linter runs after, before response serialization.
- **D-18 shipped** : Dart `apps/mobile/lib/services/metaphor_lookup.dart` + Python `services/backend/app/services/coach/metaphor_lookup.py` — mirror resolvers. `lookup(archetype, canton, life_event) → str`, empty-string contract on miss. Dart loads TOML at app boot via `package:toml ^0.16.0` + `rootBundle.loadString` ; Python loads at module import via stdlib `tomllib`.
- **NarrativeSleeveCard render shipped** : `apps/mobile/lib/widgets/mint_chat_overlay.dart` extended with public `NarrativeSleeveCard` widget (4-field render per UI-SPEC §Component Anatomy : hook headlineSmall, caption bodyLarge, next_step labelLarge(mintForest) with « › » glyph + Semantics(hint='Prochaine étape'), conditional metaphor block under Divider). MintColors.craieHandoff surface. D-26 grep gate preserved (0 hits).
- **VERB-06 walkback path shipped** : `apps/mobile/test/services/feature_flags_walkback_test.dart` — 5 tests covering applyFromMap-driven flag flips, full false→true→false walkback cycle, key-absent passthrough, strict-true convention. `MintShell.branchToVisibleIndex(2) == 1` when flag is false (Coach collapses onto Mon argent per `mint_shell.dart:64-66`).
- **Maestro G1 flow contract shipped** : `tools/simulator/flows/maestro-perfect-set/flow_card_action_intent_bar.yaml` — 10 steps per UI-SPEC §Maestro G1 Contract. Live exit-0 run is DEFERRED — needs (a) staging deploy of W3, (b) production card list to carry stable testIDs, (c) `chatTabVisible=false` on Railway staging /config/feature-flags. G2 Julien sim walkthrough is the authoritative end-to-end gate per CLAUDE.md §9.
- **96-03-FLAG-FLIP-PROPOSAL.md shipped** : 7-row eligibility checklist + D-11 7-day baseline-pull plan (`chat_overflow_turn_4` Sentry query → cap_hit_rate decision matrix) + walkback path + GO/NO-GO row mirroring Phase 94 template.
- Auto-fixed deviations (4) : (a) Rule 1 — plan claimed `appId: com.mint.mobile.staging` ; actual is single-bundle `ch.mint.app` (Runner.xcodeproj/project.pbxproj:505) ; corrected in T2 commit. (b) Rule 1 — plan-suggested docstring substring `Color(0x...)` would have tripped D-26 grep ; rewritten as « hardcoded ARGB literals » in T3. (c) Rule 3 - blocking — local Python 3.9 has no `tomllib` ; added `tomli` backport fallback to `metaphor_parity.py` + `metaphor_lookup.py`. (d) Rule 1 — `metaphor_parity.py` repo-root path resolution was one parent short ; bumped to `parent.parent.parent`.

## Plan 96-02 Receipt (Wave 2 Backend, 2026-05-11)

- Files created : 13 (2 schemas + 1 service module + __init__.py + conftest.py + 6 test files + 2 lint fixtures)
- Files modified : 4 (coach_chat.py schema + claude_coach_service.py + coach_chat.py endpoint + pii_fixture_scan.py)
- Tests added : 46 (12 serialized_card_context + 14 narrative_sleeve+extensions + 7 turn_cap + 5 terminal_template + 4 narrator_source_card_block + 4 sentry_overflow_breadcrumb)
- Full backend pytest : 6567 passed, 60 skipped, 1 xfailed in 109.99s (pre-W2 baseline 6521 → +46 net new W2 = 6567 exact, zero regressions)
- Phase 94 byte-identity : tests/test_citation_gate/ → 181 passed, 1 skipped (= pre-W2 baseline, preserved)
- Phase 95 byte-identity : tests/test_dag_invalidation/ → 74 passed (= pre-W2 baseline, preserved)
- Commits : b81172a3 (T1) → 54fee7cd (T2) → bbcf0853 (T3)
- Duration : ~42 min execution
- 0-trust : 96-02-SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/96-mvp-chat-as-verb/96-02-SUMMARY.md
- **D-12 shipped (backend mirror)** : SerializedCardContext Pydantic v2 — 7 fields, frozen=True, extra="forbid", camelCase aliases via to_camel. computed_facts scalar-only validator in mode='before' rejects bool (subclass of int — silent coercion fixed inline as Rule 1 auto-fix) + None + nested dict + list. Round-trip-compatible with the Dart mirror shipped in Plan 96-01.
- **D-14 + D-15 shipped** : NarrativeSleeve Pydantic v2 (4 fields, frozen+forbid) + additive optional `CoachChatResponse.narrative_sleeve` field. The hook digit-free linter + next_step word-count linter LAND in Plan 96-03 W3 per D-16 — Pydantic enforces byte-length caps only so the response middleware can swap on `\d` without 500ing.
- **D-13 shipped** : `CoachChatRequest` gains `source_card: Optional[SerializedCardContext] = None` + `turn_count: int = 0` (server IGNORES per T-96-W2-TurnCountTamper) + `intent: Optional[Literal["explain", "reassure"]] = None`. Narrator system prompt receives a `<source_card>` block when source_card is non-None ; legacy path (source_card=None) is byte-identical to Phase 94/95.
- **D-08..D-11 shipped** : `services/backend/app/services/coach/turn_cap.py` — TURN_COUNTER : Dict[(session_id, source_card_id), int], TURN_CAP_THRESHOLD=3, verbatim FR TURN_CAP_TERMINAL_TEMPLATE (« exploré » + « hypothèses » accents present ; zero LSFin terms — snapshot-guarded). At turn 4, the wrapper returns the terminal template with ZERO LLM call ; Sentry breadcrumb `coach.chat_overflow.turn_4` fires with non-PII payload (source_card_id + turn_count only).
- **New `_run_narrator_with_gate_and_cap` wrapper** at `services/backend/app/api/v1/endpoints/coach_chat.py` — wraps the Phase 94/95 `_run_narrator_with_gate` without modifying its signature (preserves the 213-test byte-identity matrix). Single call-site swap ; `_run_agent_loop` internals (Phase 94 §3 surgical scope) NOT touched.
- **pii_fixture_scan.py extended** (Phase 96 D-12) : structural walker scans `computed_facts` / `computedFacts` dict values for banned-key substrings (email/phone/ahv/iban/npa/employer/name/surname/address). Backward-compatible with Phase 95 D-14 AHV13 + Swiss-phone regex. 2 fixture pairs (clean exit 0, dirty exit 1 with 3 hits) under `tools/checks/fixtures/pii_scan/`.
- Auto-fixed deviations (2) : (a) Rule 3 - blocking — `uuid_utils` + `rfc8785` missing from venv ; installed via pip (Phase 95 W1 prerequisites). (b) Rule 1 - bug — Pydantic v2 Union coercion silently flipped bool to int in `computed_facts` ; switched the validator from default `mode='after'` to `mode='before'` (raw-input inspection pre-coercion).
- Architectural call (within plan latitude) : `<source_card>` block injected at the endpoint (after `_build_system_prompt_with_memory`), NOT inside the prompt builder. Karpathy #3 surgical — minimal blast radius. `_render_source_card_block` is exported from `claude_coach_service.py` for future call sites (anonymous_chat) when they need it.
- Pre-existing test-ordering issue in `test_coach_chat_bundles.py` (5 tests fail when run AFTER `test_coach_chat_endpoint.py` in the same invocation, pass in isolation and in the full traversal) — verified pre-existing by stashing W2 changes ; NOT introduced by this plan. Logged for post-96 maintenance backlog.
- USER VALUE DELIVERED : NONE YET — the 3-turn cap is LIVE server-side but no production traffic exercises it until the W3 Maestro flow + the post-W3 staging soak. The Dart-side overlay (Plan 96-01) does not yet send `source_card` payloads (deferred to W3 wiring per CONTEXT D-22).
- Phase 96 W3 HARD dependency : ProjectionGroundingPack contract + double-lookup plumbing (Phase 95 W2 — present on branch) + the NarrativeSleeve schema (this plan, T2) + the turn_cap surface (this plan, T3). All ready.

Next:

  1. **`/gsd-execute-phase 96 --wave 3`** → cross-stack NarrativeSleeve linter middleware + metaphor TOML library + Maestro G1 flow `flow_card_action_intent_bar.yaml` + G2 Julien sim walkthrough.
  2. **Post-W3 staging soak** before flipping `chatTabVisible=false` to prod per D-21 (4-week baseline-pull window on `chat_turn_distribution` Sentry metric ; >40% cap-hit → flag stays at false / walkback).
  3. **Julien GO/NO-GO** on `94-03-FLAG-FLIP-PROPOSAL.md` (carried from Phase 94 close) — still pending.

## Plan 96-01 Receipt (Wave 1 Flutter UI, 2026-05-11)

- Files created : 10 (1 model, 2 widgets, 1 demo screen, 6 test files)
- Files modified : 17 (1 pubspec.yaml + 1 pubspec.lock + 1 feature_flags.dart + 1 mint_shell.dart + 6 ARB + 7 app_localizations* regen)
- Tests added : 28 (4 feature_flags + 3 serialized_card_context + 8 mint_card_action_bar + 4 mint_chat_overlay + 5 mint_shell_flag_gate + 4 routing)
- Full Flutter suite : 8378 passed, ~24 skipped (regression : 0)
- flutter analyze : 273 issues total (= baseline 273, 0 new ; all info-level)
- Commits : 80ab0c67 (T1) → 9ece5283 (T2) → 75c1f74a (T3) → c5486f74 (T4)
- Duration : ~27 min
- 0-trust : 96-01-SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/96-mvp-chat-as-verb/96-01-SUMMARY.md
- **D-01 + D-21 shipped** : FeatureFlags.chatTabVisible default true, applyFromMap server override hook ; MintShell.NavigationBar collapses to 3 tabs when flag=false ; visibleToBranchIndex + branchToVisibleIndex exposed as pure functions for testability (T-96-W1-NavDrift mitigation, both flag states + round-trip identity tested).
- **D-04 + D-05 + D-06 + D-07 shipped** : MintCardActionBar 48dp / 200ms easeOutCubic / 3 verb chips / 44dp tap targets / MintColors.mentheVive12 splash / Semantics labels / D-26 grep gate (0 hardcoded colors, 1 Duration literal).
- **D-12 shipped** : SerializedCardContext 7-field Dart mirror (cardId / cardType required, computedFacts + groundingKeys defaulted empty, lifeEvent / canton / archetype optional). Unknown-field defense at fromJson. Backend Pydantic v2 mirror lands in Plan 96-02.
- **6-locale ARB sweep shipped** : verbExplique / verbSimule / verbRassure in fr / en / de / es / it / pt. arb_parity.py exits 0, 6750 keys per locale.
- **toml ^0.16.0 added to pubspec.yaml** : flutter pub get exits 0. Consumed in Plan 96-03 (D-17 metaphor library).
- **MintChatOverlay scaffold** : DraggableScrollableSheet 0.75/0.4/0.95 + 40×4dp drag handle + intent label slot + MintColors.nearBlack 60% scrim (D-26 compliant). W1 scaffold ONLY ; turn history + input bar in Plan 96-03.
- **Demo wiring screen** : `apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart` — 2 NON-retirement cards (« Marge fiscale 2026 », « Coût hypothèque mensuel ») wired with the 3-verb dispatch. Karpathy #3 surgical : did NOT touch 80+ production card widgets — full wiring deferred to post-v2.9 content sprint per plan deferred: block.
- Auto-fixed deviations (4 × Rule 1) : (a) generated localizations class is `S` not `AppLocalizations` ; (b) D-26 violation in plan's `Color(0x990A0A0F)` literal → replaced with `MintColors.nearBlack.withValues(alpha: 0.6)` ; (c) ARB parity tool name is `arb_parity.py` not `arb_parity_gate.py` ; (d) `MintColors.transparent` token exists, no fallback needed.
- USER VALUE DELIVERED : NONE end-user-visible YET — Wave 1 is the surface scaffold. Plans 96-02 + 96-03 deliver the chat behavior. The kill-switch infrastructure is READY : flipping `chatTabVisible=false` on Railway staging would drop the chat tab from the bottom nav with zero app redeploy.
- Phase 96 W2 HARD dependency : ProjectionGroundingPack contract + double-lookup plumbing shipped in Phase 95 W2 (a037c56d..e6a4a12f). Phase 96 W2 + W3 still pending.

Next:

  1. **`/gsd-verify-phase 95`** → 5-gate exit contract close. Both waves (95-01 + 95-02) shipped ; phase-level verifier reads both SUMMARYs, the VALIDATION matrix, and gates G1-G5.
  2. **Roadmap advancement to Phase 96 (mvp-chat-as-verb)** — Phase 96 W2 (Backend) HARD-depends on the GroundingPack contract surface shipped in 95-02 ; Phase 96 W1 (Flutter) is SOFT-independent and can proceed in parallel.
  3. **Julien GO/NO-GO** on `94-03-FLAG-FLIP-PROPOSAL.md` (carried from Phase 94 close) :
     - `approved` → Wave 4 opens (narrator-prompt placeholder syntax + re-eval)
     - `approved staging-only` → permanent staging-only, no prod-flip
     - `not approved — issue: <description>` → revision mode
  4. `/gsd-verify-work 94` → 5-gate exit contract close (G2 device + G3 dev CI pending — carried)

## Plan 94-01 Receipt (Wave 0 close, 2026-05-10)

- Files created : 9 (parser, registry, 6 test files, __init__.py)
- Files modified : 3 (config.py, eval_narrator.py, 94-VALIDATION.md)
- Tests added : 106 (Wave 0) + 0 regressions
- Full backend suite : 6372 passed, 62 skipped, 1 xfailed in 107.21s
- Commits : 033b8445 (T1) → 668df0de (T2) → 2a729c3d (T3)
- Duration : 13m 18s
- 0-trust : SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/94-mvp-citation-gate/94-01-SUMMARY.md

## Plan 94-02 Receipt (Wave 1 close, 2026-05-10)

- Files created : 7 (test_retry_flow, test_fallback, test_banned_claims, test_bundle_intersect, test_global_registry_fallback, test_telemetry, test_gate_performance)
- Files modified : 4 (citation_parser.py, coach_chat.py, test_number_detection.py, 94-VALIDATION.md)
- Tests added : ≈ 64 (Wave 1) + 0 regressions
- Full backend suite : 6436 passed, 62 skipped, 1 xfailed in 106.60s (Wave 0 baseline 6372 → +64 net new)
- Commits : 1d9b44f1 (T1 — fatten gate body) → 13230885 (T2 — wire wrapper) → final docs commit
- 0-trust : SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/94-mvp-citation-gate/94-02-SUMMARY.md
- Karpathy #3 surgical : ZERO edits inside `_run_agent_loop` (lines 1726-2624) — diff 114+/18- concentrated at narrator handler scope
- H1 fix iter 1 : `_compiled_bundle: "CompiledBundle | None" = None` initialized BEFORE bundle-compiler branch ; wrapper safe on every code path
- M2 fix iter 1 : 3 documented v1 banned-claim regex false-negatives codified (3rd-person + infinitive + LSFin « garanti » → compliance_guard)
- M3 fix iter 1 : D-04#4 placeholder-body strip — 3 regression tests in test_number_detection.py
- H3 fix iter 1 : end-to-end gate() p95 ≤ 50ms / max ≤ 80ms on 4 kB FR realistic narrative (test_gate_performance.py)
- Flag default OFF in prod (D-19/D-20) ; flag-OFF byte-identity preserved (6 snapshot tests still green)
- USER VALUE DELIVERED : NONE YET — Plan 94-03 builds eval pack + Maestro G1 + flips staging flag

## Plan 94-03 Receipt (Wave 2 close-pending, 2026-05-10)

- Files created : 8 (citation_gate_eval_50.jsonl, flow_narrator_refuses_uncited_numbers.yaml, 3 eval-run JSONs, EVAL-RESULTS, FLAG-FLIP-PROPOSAL, deferred-items, SUMMARY)
- Files modified : 2 (tools/eval_narrator.py +215 LOC, .token_count_cache.json +1 entry)
- Tests added : 0 (Plan 03 deliverables are CLI flag + fixture pack + Maestro flow + docs — gate logic tested in Waves 0+1, total 170 unit tests)
- Full backend suite : 6436 passed, 62 skipped, 1 xfailed in 106.09s (no regression vs Wave 1 baseline 6436)
- Commits (T1+T2+T3) : 937e3bba (T1 — --gate flag + 50-fixture pack) → f00fb693 (T2 — Maestro smoke flow + staging Railway + 3 live evals) → close-out docs commit
- Duration : ≈55 min execution + LLM API wait time
- 0-trust : SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/94-mvp-citation-gate/94-03-SUMMARY.md
- **STAGE 3 FINDING** : Sonnet gate_correct=3/50 (6%), Haiku 7/50 (14%) — both FAR below D-15 ≥95%/≥90% thresholds. Root cause : narrator system prompt does not teach `{{cite:<key>}}` placeholder syntax → gate (correctly per D-02..D-13) rejects naked numbers → 60-80% fallback rate. Mechanical, not a gate-logic bug. Wave 4 fattens narrator prompt → re-evals.
- **Maestro G1** : smoke-level PASS exit 0 (16-17s) on anonymous surface ; gate verification deferred to Wave 4 because anonymous_chat.py has NO gate wrapper today (deferred-items.md D1).
- **Staging Railway** : COACH_CITATION_GATE_ENABLED=true SET 2026-05-10T19:09:03Z on service MINT env staging ; prod env variable absent (config.py default False).
- **Recommendation** : NO-GO + PARTIAL (staging-only, Wave 4 narrator prompt fattening, re-eval). Awaits Julien GO/NO-GO/PARTIAL signal at Task 4 checkpoint.
- USER VALUE DELIVERED : NONE YET — Plan 94-03 builds eval pack + Maestro G1 + flips staging flag

## Plan 94.1-01 Receipt (Wave 4 narrator-prompt fattening, 2026-05-10)

- Files created : 7 (citation_grammar.py, bundles/citation_grammar.py, test_narrator_grammar_fragment.py, 94.1-01-PLAN.md, 94.1-EVAL-DELTA.md, 2 eval-run JSONs, 94.1-SUMMARY.md)
- Files modified : 5 (bundles/__init__.py, bundle_compiler.py +17 LOC, claude_coach_service.py +35 LOC, tools/eval_narrator.py +45 LOC, 94-03-FLAG-FLIP-PROPOSAL.md +1 section)
- Tests added : 12 (tests/test_citation_gate/test_narrator_grammar_fragment.py — fragment importability, 18-key coupling, verbatim examples, no new {slot}, builder purity, legacy path flag-on/off byte-identity, bundle path flag-on/off, compiler activated_bundles, dedup, Pydantic invariants)
- Full backend suite : 6448 passed, 62 skipped, 1 xfailed in 107.45s (+12 new tests vs Wave 1 baseline 6436 ; no regression)
- Commits (T1+T2+T3+T4) : 12b2a8fa (T1 PLAN.md) → b3a7ca1a (T2 fattening + tests + Rule 1 « tu dois » auto-fix) → T3 eval JSONs → T4 EVAL-DELTA + SUMMARY
- Duration : ~3.5h
- Architectural decision : Path C (Hybrid) — single source of truth citation_grammar.py CITATION_GRAMMAR_FRAGMENT consumed by both CitationGrammarBundle (flag-conditional in compile_bundles) AND build_narrator_system_prompt (flag-conditional append). NOT in _ALWAYS_ON constant ; NOT in ALL_BUNDLE_CLASSES — preserves test_empty_intent_emits_always_on_only + test_all_bundles_importable len=6 invariants.
- Eval instrumentation : eval_narrator --gate=on propagates COACH_CITATION_GATE_ENABLED=true to env + settings (Phase 94 Wave 2 ran without ; system prompt was unchanged).
- 0-trust : SUMMARY.md `## Self-Check : PASSED` at .planning/phases/94.1-.../94.1-SUMMARY.md
- **STAGE 3 FINDING (post-94.1)** : Sonnet gate_correct=10/50 (20%), Haiku 10/50 (20%) — both moved up from 6%/14% but STILL FAR below 95%/90% thresholds. Signal concentrated in valid_citation : Sonnet 1/20 → 9/20 (+800%), Haiku 6/20 → 10/20 (+67%). Topline understates improvement because fixture scoring records post-retry verdict (FALLBACK after D-08 collapse), not first-call (REJECTED_UNCITED) — under alternative « first-call match » scoring, Sonnet ≈48%, Haiku ≈44%.
- **Verdict** : FAIL per 94.1-01-PLAN interpretation rules (Sonnet < 70%). Orchestrator decides GO/NO-GO on 94.2 second-iter with primary hypothesis « intent-driven key grouping reduces 18-bullet noise floor » (full hypothesis list H1-H5 in 94.1-EVAL-DELTA.md).
- **Disposition** : NO-GO + PARTIAL unchanged. Staging stays ON for diagnostic value, prod stays OFF for narrator quality. No new GO recommendation.
- USER VALUE DELIVERED : NONE in prod. Branch `feature/S94-mvp-citation-gate` holds 94+94.1 ; not merged. The 94.1 measurement IS the only data on the fattened narrator behavior.

## Plan 95-01 Receipt (Wave 1 close, 2026-05-10)

- Files created : 13 (4 production modules — inputs_hash, projection_id, staleness, alembic p95 — + 7 test files + 2 fixture pack + 2 Dart harness + 1 PII lint, counting test_dag_invalidation/__init__.py and conftest.py as 1 setup unit)
- Files modified : 3 (pyproject.toml +2 deps, scenario.py +2 nullable cols, lefthook.yml +pii_fixture_scan entry)
- Tests added : 31 (10 inputs_hash + 6 projection_id + 7 staleness incl SC#4(c) + 4 migration + 4 hash_parity) + 0 regressions
- Full backend suite : 6479 passed, 62 skipped, 1 xfailed in 107.51s (Wave 0 baseline 6448 → +31 net new)
- Commits : 30381bad (T1 scaffold) → cb613e01 (T2 inputs_hash) → adbda907 (T3 projection_id) → 1296e7a7 (T4 alembic + staleness) → 93baff1c (T5 hash parity)
- Duration : ~17 min
- 0-trust : SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/95-mvp-dag-invalidation/95-01-SUMMARY.md
- **R1 risk CLOSED** : Python ↔ Dart hash parity 50/50 byte-identical on hash_parity_50.jsonl (50 fixtures across 5 buckets : 20 happy / 10 nested / 10 edge-floats / 5 boolean / 5 lex-sort). Required Dart-side _quantize() addition (Rule 1 auto-fix : initial RESEARCH §D-03 recipe omitted quantize step → 38/50 pre-fix → 50/50 post-fix).
- Deviations (3 auto-fixed) : (a) alembic p95 chained off 29_05_magic_link_tokens, not p86_eclairage_delivered (Rule 3 — codebase already had a branchpoint at p86) ; (b) Dart harness _quantize() addition (Rule 1) ; (c) test_migration.py monkeypatch.setenv + importlib.reload pattern (Rule 3 — env.py overrides sqlalchemy.url AFTER cfg.set_main_option).
- staleness_high() production read-path integration + Dart-side projection-model field additions both deferred to Phase 96 W2 per CONTEXT `<deferred>` block.
- USER VALUE DELIVERED : NONE YET — data-model + parity-test foundation only ; user-visible behavior changes ship in Phase 96 narrator wiring.

## Plan 95-02 Receipt (Wave 2 close, 2026-05-10)

- Files created : 10 (3 production modules — pareto, sensitivity, bootstrap_ci — + 7 test files)
- Files modified : 5 (grounding_pack.py wholesale-replaced, citation_parser.py, coach_chat.py, banned_terms_python.py, lefthook.yml)
- Tests added : 43 (10 schema + 6 pareto + 6 what_ifs + 7 bootstrap_ci + 9 double-lookup incl 2 BLOCKER-3 propagation + 5 lsfin) + 0 regressions
- Full backend suite : 6522 passed, 62 skipped, 1 xfailed in 107.83s (Wave 1 baseline 6479 → +43 net new W2)
- Commits : fb2b13aa (T1 contract) → e316ffbe (T2 pareto) → a037c56d (T3 what_ifs) → 8f474391 (T4 bootstrap_ci) → e6a4a12f (T5 double-lookup + propagation) → debe24f1 (T6 lsfin annotation)
- Duration : ~25 min
- 0-trust : SUMMARY.md `## Self-Check : PASSED` cited at .planning/phases/95-mvp-dag-invalidation/95-02-SUMMARY.md
- **D-07/D-08 contract shipped** : ProjectionGroundingPack + GroundingPackEntry + ParetoPoint Pydantic v2 frozen+forbid with Decimal field_serializer ; min/max validators on inputs_hash (64 chars) + pareto_points (=3) + what_ifs (=5) + superseded_by (None or 36 chars).
- **D-09 double-lookup shipped** : _substitute_placeholders + gate() gain keyword-only `pack: ProjectionGroundingPack | None = None` ; pack hit overrides registry ; pack miss → Sentry breadcrumb `coach.grounding_pack.fallback` (T-95-04 instrumentation) then registry fallback ; pack=None preserves Phase 94 byte-identity (test_pack_none_preserves_phase_94_behavior green ; 182/182 test_citation_gate green).
- **BLOCKER-3 fixed** : 6 GatedResponse(...) sites at citation_parser.py:465/494/503/547/556/569 propagate `inputs_hash=pack.inputs_hash if pack else None` ; 2 propagation tests assert the PASS path carries the hash + pack=None preserves inputs_hash=None.
- **D-10 Pareto + D-11 what_ifs + D-12 bootstrap_ci shipped** as pure-Python compute modules. Phase 96 W2 will wire arbitrage_engine + monte_carlo_service outputs to these consumers (per 95-02-PLAN deferred: block).
- **D-12 LSFin annotation lint shipped** : banned_terms_python.py --lsfin-annotation opt-in flag ; check_lsfin_annotation rule ; lefthook lsfin_annotation_phase_95 entry on 4 W2 modules ; default banned-terms mode preserved byte-identical.
- Deviations (3 auto-fixed) : (a) pareto fixture unit-scale math error [Rule 1] ; (b) what_ifs credible_low/high min/max bracket for negative-correlation inputs [Rule 1] ; (c) test_lsfin_annotation LINT path parents[4] not parents[3] [Rule 1]. All 3 are defects in plan-prescribed test scaffolding, ZERO bugs in plan-prescribed production code.
- USER VALUE DELIVERED : NONE YET — contract surface + plumbing + compute layer + lint. User-visible behaviour changes ship in Phase 96 W2 (narrator templates consume the pack ; chat surfaces P5/P95 bounds with the LSFin annotation).
- Phase 96 W2 HARD dependency : ProjectionGroundingPack contract + double-lookup plumbing ready ; Phase 96 W1 (Flutter) is SOFT-independent.

Progress: [████░░░░░░] 40% (2/7 phases counting this Wave 2 of Phase 95 — Phase 90 fully shipped, Phase 95 both plans closed) — Phase 90 shipped 2026-05-09 (5 design-system lints + baselines + lefthook + CI) ; Phase 95 closed both Wave 1 (parity foundation) and Wave 2 (contract + double-lookup + LSFin annotation).

## Phase Plan (Chat-as-Verb)

| # | Phase | Type | Effort | Status |
|---|---|---|---|---|
| 90 | MVP-DESIGN-LINTS-V1 | UI | 2d | ✓ shipped (PR #543) |
| 91 | MVP-EXTRACTOR-V2 | Architecture | 3d | RESEARCH.md done, discuss next |
| 92 | MVP-FONTS-TOKENS-V2 | UI | 3d | not started (depends on 90) |
| 93 | MVP-CTA-UNIFICATION-V1 | UI | 4d | not started (depends on 90) |
| 94 | MVP-CITATION-GATE | Architecture | 3d | not started (depends on 91) |
| 95 | MVP-DAG-INVALIDATION | Architecture | 4d | Wave 1 closed 2026-05-10 (Plan 95-01 5/5 tasks, 31 tests, R1 closed) — Wave 2 next |
| 96 | MVP-CHAT-AS-VERB | Architecture | 5d | not started (depends on 95) |

## Cross-cutting

- **Maestro flow library** : 7 new flows (one per phase) under `tools/simulator/flows/maestro-perfect-set/`. Indexed.
- **ARB sweep** : ~132 ARB additions across 6 locales (CTA + chat-as-verb intents + citation-gate error strings). Parity check per PR.
- **Banned-terms / accent / LSFin** : pre-commit hook already wired (lefthook from Phase 90) ; narrator output additionally validated at runtime by CITATION-GATE parser (Phase 94).
- **Performance budget** : cold launch ≤2.5s at W3 + W4 close ; agent loop ≤30s on EXTRACTOR-V2 + CITATION-GATE eval suite.
- **Backward compat** : DAG-INVALIDATION is additive (hash nullable) ; existing profiles compute hash lazily ; zero forced recomputation.

## Risks (per memory feedback_design_panel_before_push)

1. CTA sweep (Phase 93) slips beyond 4d — 80 sites optimistic. Mitigation: pre-flight categorization Day 1.
2. CITATION-GATE retry loop (Phase 94) blows token budget. Mitigation: hard-cap retries at 1, templated fallback.
3. DAG-INVALIDATION (Phase 95) breaks profiles. Mitigation: additive migration, nullable hash.
4. CHAT-AS-VERB (Phase 96) user revolt. Mitigation: feature flag default-on, monitor `chat_overflow_turn_4`.
5. FONTS license (Phase 92). Mitigation: Fontshare ToS review gate before W1 merge.
6. Adversarial counter-thesis « chat IS the product ». Mitigation: 3-turn cap is the hypothesis being tested ; walkback path baked in.

## Session Continuity

Last session: 2026-05-15T09:58:42.172Z
Stopped at: Completed wave-1b-06-PLAN.md — coach_citation_modal.dart shipped + wired into bubble + 4 widget tests GREEN; branch feature/wave-1b-06-citation-modal ready for PR
Resume file: None

<details>
<summary>v2.8 archive — L'Oracle & La Boucle (shipped 2026-04-25, 5/9 phases + 13 decimals)</summary>

## Architecture Decisions (pre-phase, v2.8)

- **Nom**: "L'Oracle & La Boucle" (pas "Pilote & Compression"). Capture le geste central.
- **Rule inversée scellée**: 0 feature nouvelle. Tout ajout = out of scope by default.
- **Compression transversale**: chaque phase tue du code mort au passage, pas phase isolée.
- **Sentry existant étendu**, pas Datadog/Amplitude/PostHog (un seul vecteur = moins de surface nLPD + moins de divergence).
- **Système flags custom étendu** ([feature_flags.dart](apps/mobile/lib/services/feature_flags.dart) + endpoint `/config/feature-flags`), pas LaunchDarkly.
- **lefthook pre-commit local**, pas juste CI gates (feedback <5s vs 2-5 min).
- **Phase numbering continué** depuis v2.7 (30 terminé) → **30.5, 30.6 (decimal inserts post-panel-debate), puis 31-36**.
- **Research activée** (Julien a choisi "Research first") — 4 researchers parallèles sur observabilité fintech mobile. Synthèse dans `.planning/research/SUMMARY.md`.
- **Phase debate résolu** (4 panels: Claude Code architect / peer tools / academic / devil's advocate) — MEMORY.md truncation = P0 runtime confirmé, lints mécaniques ROI > refonte éditoriale, AST proof-of-read = theater, `UserPromptSubmit` hook ciblé remplace AST, Phase 30.6 Tools Déterministes ajoutée (insight Panel C).
- **Kill-policy scellée** via [ADR-20260419-v2.8-kill-policy.md](../decisions/ADR-20260419-v2.8-kill-policy.md) — si v2.8 exit avec REQ table-stake unmet, la feature est KILLED via flag. Pas de v2.9 stabilisation.
- **Budget Phase 36 non-empruntable** (2-3 sem MINIMUM) — forces honest sizing de 31-35.

## Last v2.8 Position (frozen 2026-04-25)

Phase: 31
Plan: Not started
Status: Phase complete — ready for `/gsd-verify-work 30.7` + `/gsd-secure-phase 30.7` (Auto profile L1)
Next: `/gsd-verify-work 30.7` on `feature/S30.7-tools-deterministes` — 5/5 plans have SUMMARY, CLAUDE.md -30% trim @ 43a38dff, kill-switch rehearsed + Julien approved 2026-04-22, J0 fresh-session smoke deferred to post-merge operational validation (non-blocking). Also pending: `/gsd-verify-work 32` on `feature/v2.8-phase-32-cartographier` (3 RISK entries await Julien ack for nyquist_compliant flip).

Progress at v2.8 close: [██████████] 100% (5/9 phases, 22/22 plans) — Phase 30.7 5/5 shipped (30.7-00 wave0 + 30.7-01 tools 1+2 + 30.7-02 tools 3+4 + 30.7-03 mcp-server + 30.7-04 CLAUDE.md trim -30%) ; Phase 32 6/6 shipped (reconcile + registry + cli + admin-ui + parity-lint + ci-docs-validation).

## v2.8 Build Order

```
30.5 → 30.6 → (31 ∥ 34) → (32 ∥ 33) → 35 → 36
```

- **30.5 Context Sanity** (5j non-empruntable) — foundation, CTX-05 spike gate go/no-go
- **30.6 Tools Déterministes** (2-3j) — MCP tools on-demand, ~16k tokens/session saved
- **31 Instrumenter** (1.5 sem, can borrow from 34) — Sentry Replay + error boundary 3-prongs + trace_id round-trip
- **34 Guardrails** (1.5 sem, can borrow from 31, parallel with 31) — lefthook + 5 lints + CI thinning. **GUARD-02 bare-catch ban must be ACTIVE before Phase 36 FIX-05 starts.**
- **32 Cartographier** (1 sem, can borrow from 33) — route registry + /admin/routes dashboard
- **33 Kill-switches** (1 sem, can borrow from 32, parallel with 32) — GoRouter middleware + FeatureFlags ChangeNotifier + 4 P0 kill flags provisioned for Phase 36
- **35 Boucle Daily** (1 sem) — mint-dogfood.sh simctl + auto-PR threshold
- **36 Finissage E2E** (2-3 sem **non-empruntable**) — 4 P0 fixes + 388 catches → 0 + device walkthrough 20 min

## v2.8 Phase Budget Table

| Phase | Name | Budget | Borrowable | REQs | Kill gate |
|-------|------|--------|------------|------|-----------|
| 30.5 | Context Sanity | 5j | **non-empruntable** | 5 | CTX-05 spike |
| 30.6 | Tools Déterministes | 2-3j | — | 4 | — |
| 31 | Instrumenter | 1.5 sem | from 34 only | 7 | OBS-06 PII audit |
| 34 | Guardrails | 1.5 sem | from 31 only | 8 | — |
| 32 | Cartographier | 1 sem | from 33 only | 5 | — |
| 33 | Kill-switches | 1 sem | from 32 only | 5 | — |
| 35 | Boucle Daily | 1 sem | — | 5 | — |
| **36** | **Finissage E2E** | **2-3 sem MIN** | **never** | **9** | 4 P0 kill flags + device walkthrough |

**Total estimate (v2.8):** 8-10 sem solo-dev avec parallélisation (31 ∥ 34, 32 ∥ 33).

## v2.8 Performance Metrics

**Velocity (from previous milestones):**

- Total plans completed v2.4-v2.7: 24 plans
- Average duration: ~15-30 min/plan (increasing complexity)
- v2.7 plans: 30-90 min/plan (compliance + encryption + Vision)

**v2.8 Execution Log:**

| Phase-Plan      | Duration | Tasks | Files | Completed  |
|-----------------|----------|-------|-------|------------|
| 32-02-cli       | 7 min    | 2     | 11    | 2026-04-20 |
| 32-03-admin-ui  | 11 min   | 2     | 11    | 2026-04-20 |
| 32-04-parity-lint | 5 min  | 1     | 6     | 2026-04-20 |
| Phase 32 P05 | 9min | 3 tasks | 5 files |
| Phase 30.7 P00 | 28 min | 3 tasks | 12 files |
| Phase 30.7 P01 | 15 min | 2 tasks | 4 files |
| Phase 30.7 P02 | 4min | 2 tasks | 4 files |
| Phase 30.7 P30.7-03 | 5min | 2 tasks | 5 files |
| Phase 30.7 P30.7-04 | 35 min | 2 tasks (T1 trim + T2 checkpoint) | 1 file (CLAUDE.md) | 2026-04-22 |

## v2.8 Accumulated Context (decisions reference — preserved for continuity)

### Decisions (v2.8 pre-phase)

- **v2.8 name**: "L'Oracle & La Boucle" captures instrumentation-first + daily loop
- **0 feature nouvelle** scellée via kill-policy ADR
- **Compression transversale**: chaque phase tue du code mort au passage
- **Extend existing Sentry** (not Datadog/Amplitude/PostHog) — bump `sentry_flutter` 8→9.14.0
- **Extend custom flags** (not LaunchDarkly) — converge 2 backend systems (env-backed read + Redis-backed write)
- **lefthook 2.1.5** for pre-commit local (not CI-only) — target <5s
- **Sentry Replay Flutter 9.14.0** with `maskAllText=true` + `maskAllImages=true` nLPD-safe defaults non-négociables
- **Headers manuels `sentry-trace` + `baggage` sur `http: ^1.2.0`** (pas migration Dio)
- **Binary-per-route flags** (pas cohort/percentage)
- **4 P0 kill flags provisioned in Phase 33** before Phase 36 begins: `enableProfileLoad` / `enableAnonymousFlow` / `enableSaveFactSync` / `enableCoachTab`

### From Previous Milestones

- v2.4: RAG persistent, URLs fixed, camelCase fixed, 3-tab shell + ProfileDrawer working
- v2.5: Anonymous flow + commitment devices + coach intelligence + couple mode + living timeline (shipped 2026-04-13)
- v2.6: Coach stabilisation + doc digestion (shipped 2026-04-13)
- v2.7: Coach stab v2 + doc pipeline honnête + compliance/privacy + device gate (code-complete 2026-04-14, awaiting device walkthrough)
- Wave E-PRIME (merged PR #356 → dev f35ec8ff, 2026-04-18) — 42K LOC supprimées, 72 files mobile + 4 backend deleted
- Deep audit (2026-04-12): 32 findings resolved, lucidite-first pivot adopted

### Blockers/Concerns (v2.8 carry-forward)

- **388 bare catches** (332 mobile + 56 backend) at v2.8 entry — migration requires GUARD-02 active as moving-target prevention
- **Anonymous flow dead** despite `AnonymousChatScreen` implemented — LandingScreen CTA auth-gated (one-line fix FIX-02)
- **save_fact backend→front unsync** — missing `responseMeta.profileInvalidated` field in canonical OpenAPI (FIX-03)
- **UUID profile crash** on backend — schemas/profile.py validation bug (FIX-01)
- **Coach tab routing stale** — navigation state fix (FIX-04)
- **MintShell ARB parity audit** (FIX-06) — labels already i18n-wired, MEMORY.md was stale, audit not rewrite
- **Wave C scan-handoff** in progress on current branch `feature/wave-c-scan-handoff-coach` (independent, merge before v2.8 Phase 30.5 kickoff)

### Roadmap Evolution

- 2026-05-10 — Phase 94.1 inserted after Phase 94 : « Wave 4 narrator-prompt fattening — citation registry + `{{cite:<key>}}` grammar instructions (Phase 94 prod-flip unblocker) ». URGENT decimal patch surfaced by Phase 94 close-out — Stage 3 thresholds NOT MET (Sonnet 6%, Haiku 14%) because narrator system prompt does not yet teach the citation placeholder grammar. Scope : extend `build_narrator_system_prompt` + `build_narrator_system_prompt_from_bundles` in `services/backend/app/services/coach/claude_coach_service.py` with the 18-key `CITATION_REGISTRY` list + `{{cite:<key>}}` directive ; re-run the 50-fixture `citation_gate_eval_50.jsonl` pack on Sonnet + Haiku ; if Sonnet ≥95% / Haiku ≥90% land, re-open `94-03-FLAG-FLIP-PROPOSAL.md` as GO. ~1d scope. Branch policy : continue on `feature/S94-mvp-citation-gate` OR split to `feature/S94.1-narrator-prompt-fattening` (Julien decides at PR time).

- 2026-05-12 — P001 narrator citation-gate ship-as-is decision (julien-go ADR row #2, 2026-05-12T09:55Z, `.planning/decisions/2026-05-12-r-perimeter-sequencing-julien-go.md`). After W7 iter#11 H1 lift (Sonnet 16→18% / Haiku 18→22% gate-correct, REJECTED on 50% PARTIAL bar but MARGINAL lift in the right direction), Julien validates GO to ship v2.9 H1-only as-is. **P001 is NO LONGER a v2.9 ship blocker** : the `FALLBACK_TEMPLATED_TEXT` path is the LSFin runtime safety net (no narrator output emitted without citation — compliance preserved via banned-claim regex + accent FR lint). H2-H5 architectural follow-ups (filed as P001b/c/d/e in 97-BUGS-REGISTRY.md) deferred to v2.10 with `deferred_to: v2.10` field per Phase 97.5 W4-T1 P001-PAPERWORK. The user-visible educational degradation (≤22% gate-correct on prod) is accepted for v2.9 ; v2.10 attacks the gate-correct architecturally (few-shot in-context examples per H5, or methodology change per 94.1-EVAL-DELTA §H5). Registry status promoted IN_PROGRESS → RESOLVED (a PROMOTION, allowed by `bug_registry_lint.py` state machine).

### Known Good Foundations (to capitalize, still valid for v2.9)

- Sentry backend+mobile wired (sample 10%) ✓
- 148 GoRoute documentées (ROUTE_POLICY.md, NAVIGATION_GRAAL_V10.md, SCREEN_INTEGRATION_MAP.md) ✓
- Système flags custom 8 flags + endpoint `/config/feature-flags` + server override ✓
- ~10 CI gates mécaniques dans `tools/checks/` ✓ (now 15 with Phase 90 design lints)
- `tools/e2e_flow_smoke.sh` existing ✓
- SLOMonitor auto-rollback primitive (v2.7) — generalizable for Phase 33 ✓
- `redirect:` callback at `app.dart:177-261` — single insertion point for Phase 33 `requireFlag()` ✓
- Existing global exception handler at `main.py:169-180` — needs trace_id + event_id extension for OBS-03 ✓

</details>

---
*Last activity: 2026-05-11 — v2.9 Chat-as-Verb Pivot ACTIVE. Phase 96 Wave 3 (Cross-stack) implementation complete : metaphors.toml v1 bootstrap (8 entries, mobile + backend byte-equal + parity lint), NarrativeSleeve hook digit-free linter middleware (ReDoS-safe, never raises), Dart + Python metaphor_lookup mirrors, citation_parser middleware-ordering helper, Maestro G1 contract flow, VERB-06 walkback test, NarrativeSleeveCard renderer, FLAG-FLIP-PROPOSAL. 4 atomic commits f4f3446d..dfd386f6, 42 net new tests (19 Python + 23 Dart), full backend pytest 6586 passed + Flutter 8401 passed, Phase 94/95 byte-identity preserved (255 tests). Task 4 G2 Julien sim walkthrough is the open gate per CLAUDE.md §9 0-trust ; Phase 96 cannot claim « shipped » without Julien token.*
