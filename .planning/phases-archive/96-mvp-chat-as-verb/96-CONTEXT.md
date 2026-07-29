---
description: Phase 96 MVP-CHAT-AS-VERB context — answers locked autonomously by PM Claude (Product Leader) from the 96-ux panel + master synthesis + sequencing-compliance panel. Gathered via `/gsd-discuss-phase 96 --auto --chain` per Julien's 2026-05-10 autonomous-loop authorization. Final phase of v2.9 Chat-as-Verb Pivot milestone.
---

# Phase 96: MVP-CHAT-AS-VERB - Context

**Gathered:** 2026-05-11 (auto-resolved by PM Claude from 96-ux panel + master synthesis)
**Status:** Ready for planning

<domain>
## Phase Boundary

Kill the chat-tab as destination ; turn chat into a verb invocable from card-actions. Concretely : `MintShell.NavigationBar` drops index 2 (tabCoach) behind `FeatureFlags.chatTabVisible = false`, leaving a 3-tab nav (Aujourd'hui / Mon Argent / Explorer). The Coach route stays registered, accessible only via the new `MintCardActionBar` inline animated row (48dp expansion, 200ms easeOut) on each card. 3-verb intent set : « Explique-moi » / « Simule » / « Rassure-moi » (final FR copy). « Simule » routes directly to Explorer (zero turns consumed, no LLM). « Explique-moi » + « Rassure-moi » open `MintChatOverlay` modal with a STRICT 3-turn cap enforced server-side per `source_card_id` × app-session (zero token cost at turn 4 — backend returns static template + Explorer deep-link).

`CoachChatRequest` gains an optional `source_card: SerializedCardContext` field carrying card_id, card_type, computed_facts (financial_core values only — no PII), grounding_keys (citation key candidates from the card), life_event, canton, archetype. Narrator response gains a `NarrativeSleeve {hook, caption, next_step, metaphor}` envelope — `hook` MUST be digit-free (regex `\d` → swap-to-fallback middleware), `caption` carries the cited numbers post-substitution, `next_step` is verb-first ≤12 words, `metaphor` is a static TOML lookup by archetype × canton × event triplet.

GroundingPack consumption is a SOFT dependency : Phase 96 ships with `ProjectionGroundingPack | None` fallback ; full Phase 95 contract surface lights up post-W2 backend merge.

Out of scope (deferred to milestone post-v2.9 OR backlog) :
- Full removal of `CITATION_REGISTRY` (deferred post-96 cleanup)
- Sobol / NSGA-II / HMM / Bayesian CIs (backlog 999.x)
- Metaphor library expansion beyond v1 bootstrap (6-10 entries × 3 archetypes × 2 cantons × 2 events)
- Phase 94.2 narrator-prompt iter 2 (backlog 999.5 — independent surface)
- ChatTab full deletion (Phase 96 ships the kill-switch via feature flag ; permanent removal after 4-week soak with zero rollback signal)

</domain>

<decisions>
## Implementation Decisions

### Chat-tab kill mechanism

- **D-01:** Remove tab index 2 (`tabCoach`) from `MintShell.NavigationBar.destinations` behind `FeatureFlags.chatTabVisible = false` (server-overridable via existing `/config/feature-flags` endpoint). 3-tab nav (Aujourd'hui / Mon Argent / Explorer) when flag false ; 4-tab nav unchanged when flag true.
- **D-02:** GoRouter branch + `CoachChatScreen` route STAY registered — the overlay (MintChatOverlay) routes to the same screen. No GoRoute deletion this phase.
- **D-03:** In-flight conversation state preserved by existing `ConversationStore` (Provider, already in use) across overlay open/close within the same session. New cards open fresh sessions per `source_card_id`.

### MintCardActionBar

- **D-04:** New widget `apps/mobile/lib/widgets/mint_card_action_bar.dart` — inline animated row revealed below the card on tap (48dp expansion, 200ms easeOut, `AnimatedSize` + `AnimatedOpacity`). NO bottom sheet. 3 verbs, no more, no less.
- **D-05:** Final FR verb-set : « Explique-moi » / « Simule » / « Rassure-moi ». ARB keys : `verbExplique`, `verbSimule`, `verbRassure` — added to all 6 locales (fr/en/de/es/it/pt) via `flutter gen-l10n`.
- **D-06:** Verb routing :
  - « Explique-moi » → `MintChatOverlay` opens with `intent: "explain"`, source_card context propagated
  - « Rassure-moi » → `MintChatOverlay` opens with `intent: "reassure"`, source_card context propagated
  - « Simule » → `context.push('/explorer?simulate=<card_id>')` deep-link to Explorer (ZERO turns consumed, no LLM call)
- **D-07:** Visual : `MintColors.mentheVive12` (12% mint-green tint, ARGB `0x1F7DD3B5`) for active verb tap state — chosen over `MintColors.primary` (#1D1D1F anthracite) because the design intent is a subtle accent tint, not a foreground-text-color fill. The UI-SPEC researcher (UX-panel guided) confirmed this resolves D-07's loose « primary » wording. `MintTextStyles.labelLarge` for the verb label ; zero hardcoded `Color(0x...)` in widget files per CLAUDE.md rule 2 (Phase 90 lint `prefer_mint_color_token`).

### 3-turn cap (server-side, strict)

- **D-08:** STRICT 3-turn cap, NO soft cap, NO extension. Enforced server-side via new `turn_count: int` field on `CoachChatRequest` (incremented client-side per `source_card_id` × app-session).
- **D-09:** Reset criterion : per `source_card_id` × app-session (NOT per-day, NOT per-card-type). Same card tapped again in a new session resets to 0.
- **D-10:** At `turn_count >= 3` on incoming request, backend returns a static FR template + Explorer deep-link, SKIPS the LLM entirely (zero token cost) :
  ```
  « Tu as exploré 3 angles sur cette carte. Pour aller plus loin, ouvre le simulateur depuis [Explorer →](/explorer?id={card_id}) — tu pourras y modifier les hypothèses en direct. »
  ```
  Verbatim FR ; accent_lint_fr clean ; no banned LSFin terms.
- **D-11:** Instrumentation : Sentry metric `chat_overflow_turn_4` fires every time the cap is hit. Pre-flag-flip baseline pull on `chat_turn_distribution` (current MINT sessions — 7-day window) BEFORE flipping `chatTabVisible=false` to prod. If real cap-hit rate > 40% of sessions, the flag stays at false (cap effectively no-ops) and we walk back via the existing `/config/feature-flags` server override.

### SerializedCardContext schema

- **D-12:** New Pydantic v2 model `SerializedCardContext` on backend (`services/backend/app/schemas/card_context.py`, `frozen=True, extra="forbid"`). Fields :
  - `card_id: str` — stable card identifier (e.g. `mon_3a_2026`, `lpp_projection`)
  - `card_type: str` — taxonomy slug (e.g. `pillar_3a`, `lpp_retirement`, `tax_optimization`, `mortgage`, `cross_pillar`)
  - `computed_facts: dict[str, Decimal | int | str]` — financial_core values ONLY (no PII, no raw user input)
  - `grounding_keys: list[str]` — citation key candidates from the card, subset of the 18-key `CITATION_REGISTRY` namespace (or new keys added to it)
  - `life_event: str | None` — one of MINT's 18 life events (housing/family/career/tax/debt/retirement/...)
  - `canton: str | None` — 2-letter Swiss canton (VD, GE, ZH, ...)
  - `archetype: str | None` — one of the 8 archetypes (swiss_native, expat_eu, expat_us, cross_border, indep_with_lpp, indep_no_lpp, returning_swiss, retiree)
- **D-13:** `CoachChatRequest` (existing Pydantic schema) gains an optional `source_card: SerializedCardContext | None = None` field. When non-None, the narrator system prompt receives a `<source_card>` block with the card's computed_facts + grounding_keys + life_event + canton + archetype injected.

### NarrativeSleeve envelope

- **D-14:** New Pydantic v2 model `NarrativeSleeve` on backend (`services/backend/app/schemas/narrative_sleeve.py`, `frozen=True, extra="forbid"`). 4 fields :
  - `hook: str` — 1-line attention-grabbing opener, MUST be digit-free (regex `\d` matches → middleware swaps to a fallback hook without digits). Examples : « Tu marches sur un fil — voyons combien il porte. », « Trois choix changent ta marge fiscale cette année. »
  - `caption: str` — main body, citation gate already applied (numbers wrapped in `{{cite:<key>}}` substitute via Phase 94 + Phase 95 pack double-lookup)
  - `next_step: str` — verb-first call-to-action, ≤12 words (linter enforces word count + verb-first via `tools/checks/narrative_sleeve_lint.py`)
  - `metaphor: str` — static TOML lookup result by `archetype × canton × life_event` triplet from `apps/mobile/assets/metaphors.toml` (loaded at app boot). Empty string if no metaphor matches.
- **D-15:** Response envelope : `CoachChatResponse.narrative_sleeve: NarrativeSleeve | None`. None when narrator's source_card is None (fallback to legacy unstructured response). Phase 96 W3 wires the linter ; Phase 96 W2 ships the schema + optional field.
- **D-16:** Linter implementation : backend response middleware (NOT pre-commit). Runs AFTER the citation gate (Phase 94 stays first in middleware chain). Swaps `hook` to a generic digit-free fallback on `\d` match, NEVER 500s the response. Generic fallback hook : « Voyons ensemble ce que ça change pour toi. »

### Metaphor library

- **D-17:** v1 bootstrap : `apps/mobile/assets/metaphors.toml` with 6-10 entries covering 3 archetypes (swiss_native, expat_eu, cross_border) × 2 cantons (VD, GE) × 2 life events (housing, family). TOML shape :
  ```toml
  [swiss_native.VD.housing]
  metaphor = "À Lausanne, ton 3a est une cave à vin — chaque année qui passe l'enrichit, mais elle se vide vite si tu l'ouvres trop tôt."

  [expat_eu.GE.family]
  metaphor = "Avec une famille à Genève, tes choix fiscaux ressemblent à un puzzle : chaque pièce nouvelle redessine l'image."
  ```
  Verbatim FR ; accent_lint_fr clean ; no banned LSFin terms ; no « optimal/garanti/parfait ».
- **D-18:** Lookup function `lookup_metaphor(archetype: str, canton: str, life_event: str) -> str` in `apps/mobile/lib/services/metaphor_lookup.dart`. Returns empty string if no match. Backend MIRROR `services/backend/app/services/coach/metaphor_lookup.py` for narrator prompt injection.
- **D-19:** Expansion to full archetype × canton × event matrix DEFERRED to a post-96 content sprint. v1 bootstrap is intentionally narrow (≤10 entries) per Karpathy #2 simplicity-first.

### GroundingPack consumption (SOFT dependency on Phase 95)

- **D-20:** Phase 96 ships with `ProjectionGroundingPack | None` fallback. When the GroundingPack is provided (post-Phase-95-W2 backend merge), citations resolve from `pack.entries.get(key)` first ; else fall back to Phase 94 `CITATION_REGISTRY.resolve(key)` (existing double-lookup at `_substitute_placeholders()`, already shipped in Phase 95 W2).
- **D-21:** Phase 96 W1 (Flutter UI) does NOT depend on GroundingPack — it can ship independently. Phase 96 W2 (Backend) consumes the pack via the existing double-lookup path. Phase 96 W3 (cross-stack NarrativeSleeve linter) does NOT depend on GroundingPack either — the linter operates on the response envelope shape, not the citation content.

### Plan count and wave split

- **D-22:** 3 plans, 3 waves :
  - **Wave 1 (~2d, Flutter)** : `MintShell` flag-gate, `MintCardActionBar`, `MintChatOverlay` modal scaffold, 3 ARB keys × 6 locales, Maestro flow stub. Independent of Phase 95 — starts immediately. Plan ID 96-01.
  - **Wave 2 (~2d, Backend, BLOCKS on Phase 95 W2 merge)** : `SerializedCardContext` Pydantic schema, `CoachChatRequest.source_card` extension, narrator system-prompt injection, `turn_count` enforcement + terminal template, `chat_overflow_turn_4` Sentry metric. Plan ID 96-02.
  - **Wave 3 (~1d, cross-stack, BLOCKS on W2 merged + turn_count flow exercised in staging)** : `NarrativeSleeve` response envelope, hook linter middleware, metaphor TOML library + resolver, Maestro flow `flow_card_action_intent_bar.yaml` (full 3-turn + cap + deep-link path). Plan ID 96-03.

### Compliance gates (pre-merge, all waves)

- **D-23:** All Phase 95 gates carry forward (banned-terms, PII, no-legal-admission, accent_lint, hash_parity, regression suite).
- **D-24:** Flutter `flutter analyze` exits 0 on diff ; `flutter test` regression ≥ 229 baseline + new card-actions/overlay tests.
- **D-25:** 6-locale ARB parity : `validate_arb_parity()` MCP tool returns clean ; no key in fr/ missing from en/de/es/it/pt.
- **D-26:** MintColors / MintTextStyles only — `grep -rn "Color(0x" apps/mobile/lib/widgets/mint_card_action_bar.dart apps/mobile/lib/widgets/mint_chat_overlay.dart` returns 0.
- **D-27:** G1 Maestro `flow_card_action_intent_bar.yaml` — exit 0 on iPhone 17 Pro sim against staging Railway ; assert the 3-turn cap fires (Sentry breadcrumb `chat_overflow_turn_4`).
- **D-28:** G2 Julien sim walkthrough — surfaced as HUMAN-UAT (per CLAUDE.md §9, Phase 96 cannot claim « ready » without this gate completing). Test flow : open card « Mon 3a 2026 » → tap « Explique-moi » → MintChatOverlay renders with cited numbers → hit 3-turn cap → terminal template + Explorer deep-link fires.

### Claude's Discretion

- Internal widget structure of `MintCardActionBar` and `MintChatOverlay` (Stateless vs Stateful, key handling) — planner decides.
- TOML parser choice (existing `toml` package in Dart pubspec, or stdlib `dart:io` File + manual parse) — planner decides.
- Exact bounds of the `hook` digit-free fallback library (1 fallback string vs a small rotation) — planner decides.
- Sentry breadcrumb naming convention (`chat_overflow_turn_4` is locked but related events e.g. `card_action_tap_explique` are planner discretion).
- Persistence strategy for `turn_count` between turns within a session (in-memory state vs Redis vs Postgres) — planner decides, default in-memory per-process keyed by `(session_id, source_card_id)`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Strategic / architectural anchors

- `.planning/decisions/2026-05-09-calc-first-llm-illumination.md` §N4 — strategic mandate for chat-as-verb pivot, foundational ADR
- `.planning/decisions/2026-05-10-phase-96-ux-panel.md` — full Phase 96 UX brief (D-01..D-22 derive from this)
- `.planning/decisions/2026-05-10-phase-95-96-sequencing-compliance-panel.md` — compliance gates D-23..D-28, sequencing constraints, stop conditions
- `.planning/decisions/2026-05-10-95-96-autonomous-sequence-master.md` — PM master synthesis ; the answer sheet that locked these decisions
- `.planning/MILESTONE-CHAT-AS-VERB-2026-05-09.md` — 4-expert panel synthesis from milestone kickoff

### Phase 94 + 95 carry-forward (citation gate + GroundingPack)

- `.planning/phases/94-mvp-citation-gate/94-CONTEXT.md` — D-01..D-21, especially D-05/D-06 (5 source kinds), D-09 (reprompt grammar), D-14 (eval fixture shape)
- `.planning/phases/94-mvp-citation-gate/94-03-FLAG-FLIP-PROPOSAL.md` — NO-GO + PARTIAL disposition, prod-flip still blocked
- `.planning/phases/95-mvp-dag-invalidation/95-CONTEXT.md` — D-01..D-18 GroundingPack contract surface
- `.planning/phases/95-mvp-dag-invalidation/95-02-SUMMARY.md` — Wave 2 deliverables (ProjectionGroundingPack, double-lookup, Sentry breadcrumb on fallback)
- `services/backend/app/services/coach/grounding_pack.py` — `ProjectionGroundingPack` + `GroundingPackEntry` + `ParetoPoint` (Phase 95 W2)
- `services/backend/app/services/coach/citation_parser.py` — `_substitute_placeholders` with `pack=` kwarg double-lookup (Phase 95 W2)

### Flutter / mobile (Phase 96 W1 targets)

- `apps/mobile/lib/widgets/mint_shell.dart` — 4-tab `NavigationBar` ; index 2 (tabCoach) gets gated by `FeatureFlags.chatTabVisible`
- `apps/mobile/lib/services/feature_flags.dart` — existing flag mechanism + `/config/feature-flags` server override
- `apps/mobile/lib/screens/coach_chat_screen.dart` (or equivalent) — Coach screen kept registered, opened by overlay
- `apps/mobile/lib/theme/colors.dart` — `MintColors` tokens (zero hardcoded colors per CLAUDE.md rule 2)
- `apps/mobile/lib/theme/text_styles.dart` — `MintTextStyles` tokens
- `apps/mobile/lib/l10n/` — 6 ARB files for `verbExplique`, `verbSimule`, `verbRassure` keys
- `apps/mobile/lib/services/conversation_store.dart` (or equivalent) — Provider-based session state, preserves in-flight conversations across overlay
- `docs/DESIGN_SYSTEM.md` + `docs/VOICE_SYSTEM.md` — MINT visual + voice rules
- `docs/AGENTS/flutter.md` — Flutter coding rules (MintUI kit, GoRouter, Provider)

### Backend (Phase 96 W2 targets)

- `services/backend/app/api/v1/endpoints/coach_chat.py` — `_run_narrator_with_gate` wrapper (Phase 94), to accept `pack=` (Phase 95) + new `source_card=` (Phase 96 W2)
- `services/backend/app/schemas/` — namespace for new `card_context.py` + `narrative_sleeve.py`
- `services/backend/app/services/coach/claude_coach_service.py` — narrator system prompt builders, extension target for `<source_card>` block injection (Phase 96 W2)
- `services/backend/app/services/coach/citation_grammar.py` — Phase 94.1 fragment, complements but doesn't conflict with the source_card block

### Maestro (Phase 96 W3 G1)

- `tools/simulator/flows/maestro-perfect-set/` — flow library
- `tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml` — Phase 94 precedent for assertNotVisible + assertVisible patterns
- `tools/simulator/walker_audit_tap_render.sh` + `walker.sh` — sim boot + flow runner (per memory `feedback_diff_against_existing_tool`)

### Compliance / Swiss

- `CLAUDE.md` §1 banned terms LSFin, §2 accents FR, §3 (« MINT ≠ retirement app » — frame card examples by life events), §9 0-trust protocol
- `.claude/skills/mint-swiss-compliance/SKILL.md` — LSFin enforcement
- `tools/checks/{banned_terms_python,pii_fixture_scan,no_legal_admission_in_public_docs,accent_lint_fr}.py` — lefthook + CI lints
- `tools/checks/banned_terms_python.py --lsfin-annotation` — Phase 95 W2 lint extension (NarrativeSleeve hook linter complements this)
- `docs/AGENTS/swiss-brain.md` — Swiss financial law triplets for `legal_constraints` references

### v2.9 milestone forward link

- `.planning/MILESTONE-CHAT-AS-VERB-2026-05-09.md` — Phase 96 is the FINAL phase of the milestone
- Post-Phase-96 path : pubspec bump + dev→staging merge fires testflight.yml per memory `project_testflight_ship_path`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `apps/mobile/lib/widgets/mint_shell.dart:60` — `l.tabCoach` label, tab index 2 (the target to gate behind FeatureFlags.chatTabVisible)
- `apps/mobile/lib/services/feature_flags.dart` — existing flag mechanism + periodic refresh + server override via `/config/feature-flags` — Phase 96 adds 1 new flag
- `apps/mobile/lib/services/conversation_store.dart` (or equivalent) — Provider-based in-flight conversation state, reusable for overlay open/close
- `apps/mobile/lib/theme/{colors,text_styles}.dart` — MintColors + MintTextStyles tokens (zero hardcoded values)
- `services/backend/app/services/coach/citation_parser.py` — `_substitute_placeholders(*, pack)` extension point ALREADY shipped in Phase 95 W2 — Phase 96 just consumes
- `services/backend/app/services/coach/grounding_pack.py` — `ProjectionGroundingPack` ALREADY shipped in Phase 95 W2 — Phase 96 receives and substitutes
- `tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml` — Phase 94 precedent for Maestro assertions (assertNotVisible / assertVisible / inputText / extendedWaitUntil)

### Established Patterns

- Pydantic v2 `frozen=True, extra="forbid"` (citation_registry.py:51, grounding_pack.py from Phase 95) — `SerializedCardContext` + `NarrativeSleeve` follow this
- ADDITIVE schema changes (Phase 92 + 95 set this precedent) — `CoachChatRequest.source_card` + `CoachChatResponse.narrative_sleeve` are nullable additions
- 6-locale ARB parity gate (Phase 90 lint) — new ARB keys MUST appear in all 6 locales before merge
- MintColors / MintTextStyles only (Phase 90 lints) — `prefer_mint_color_token` + `prefer_mint_text_style` already wired
- Closed-world `{{cite:<key>}}` placeholder grammar (Phase 94) — `NarrativeSleeve.caption` body MUST go through citation gate ; `hook` is digit-free by linter rule
- Sentry breadcrumbs with non-PII payload (Phase 94 + 95) — `chat_overflow_turn_4` follows this convention
- Lefthook pre-commit + CI lints — Phase 96 adds 1 new lint (`narrative_sleeve_lint.py`) for hook digit-check + next_step word-count

### Integration Points

- `apps/mobile/lib/widgets/mint_shell.dart:46-65` (NavigationBar destinations list) — flag-gated 3-tab vs 4-tab rendering
- `apps/mobile/lib/screens/{card_screens}.dart` — each card screen gains a `MintCardActionBar` widget child below its main content
- `services/backend/app/api/v1/endpoints/coach_chat.py:_run_narrator_with_gate` — wrapper from Phase 94, extended in Phase 95 with `pack=` kwarg, extended again in Phase 96 W2 with `source_card=` kwarg
- `services/backend/app/services/coach/claude_coach_service.py:build_narrator_system_prompt*` — extension point for `<source_card>` block injection when source_card is non-None
- Backend response middleware chain — Phase 94 citation gate FIRST, then Phase 96 W3 NarrativeSleeve hook linter (NEVER reverses the order)
- `apps/mobile/assets/` — new asset `metaphors.toml` loaded at app boot via existing asset bundle pattern
- `tools/checks/` — new `narrative_sleeve_lint.py` registered in `lefthook.yml` for `*.py` files under `services/backend/app/services/coach/`

</code_context>

<specifics>
## Specific Ideas

- The 3-turn cap is the headline behavioral contract. If real-user cap-hit rate exceeds 40% on the 7-day baseline pull, Phase 96 ships flag-OFF on prod and the cap is functionally inert. The kill-switch is the safety net.
- « Simule » verb is deliberately LLM-free — it deep-links to Explorer with zero token cost. This is the « narrator is a precision tool, not a destination » doctrine in action.
- NarrativeSleeve hook linter is response-middleware (NOT pre-commit) because the narrator output is dynamic — pre-commit can't catch what the LLM produces at runtime.
- Metaphor library v1 bootstrap is intentionally narrow (6-10 entries) per Karpathy #2 — expansion to the full 8 × 26 × 18 matrix would be premature.
- Phase 96 is the LAST phase of the v2.9 Chat-as-Verb Pivot milestone. After Phase 96 verifier passes, the path to TestFlight is : pubspec bump + dev→staging merge fires testflight.yml (per memory `project_testflight_ship_path`). Walker is an OPTIONAL quality gate, NOT a ship blocker.
- G2 (Julien device verify) is the final gate. End-to-end flow on TestFlight : open card « Mon 3a 2026 » → tap « Explique-moi » → MintChatOverlay renders → cited numbers shown → hit 3-turn cap → terminal template + Explorer deep-link fires.

</specifics>

<deferred>
## Deferred Ideas

- **Full removal of `CITATION_REGISTRY`** — post-Phase-96 cleanup phase. Phase 96 ships double-lookup ; the registry-only fallback path stays as the bridge.
- **Sobol / NSGA-II / HMM / Bayesian CIs** — backlog 999.x (Phase 95 deferred items, no Phase 96 surface depends on them).
- **Metaphor library expansion** — v1 bootstrap is 6-10 entries ; full 8 × 26 × 18 matrix is a content sprint post-v2.9.
- **Phase 94.2 narrator-prompt iter 2** — backlog 999.5 (independent surface, no Phase 96 dependency).
- **ChatTab permanent deletion** — Phase 96 ships the kill-switch via feature flag ; permanent route removal after a 4-week soak with zero rollback signal (separate post-v2.9 cleanup).
- **Sentry breadcrumb production wiring E2E verification** — deferred from Phase 95 W2 ; Phase 96 W3 G1 Maestro flow exercises the staging path end-to-end which closes this gap.
- **Server-side `turn_count` persistence (Redis/Postgres)** — Phase 96 W2 default is in-memory per-process keyed by `(session_id, source_card_id)`. If Phase 96 G2 surfaces a multi-process drift issue, post-96 patch adds Redis backing.

### Reviewed Todos (not folded)

- `2026-05-05-audit-mint-skills-against-rezvani-5-step-prompt-to-skill-con` (score 0.6, area: tooling) — meta/skills-audit task, not Phase 96 scope. Better fit : post-v2.9 milestone tooling sweep. Surfaced again from Phase 95 review.

</deferred>

---

*Phase: 96-mvp-chat-as-verb*
*Context gathered: 2026-05-11 (auto-resolved by PM Claude from 96-ux panel + master synthesis)*
