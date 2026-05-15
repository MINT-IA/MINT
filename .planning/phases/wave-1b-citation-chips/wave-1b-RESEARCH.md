---
name: wave-1b-RESEARCH
description: Research for Wave 1b — activate Wave 1a's `inputs_hash` as user-visible citation chips by extending `CITATION_REGISTRY` with 6 `tool_call_id` entries, the narrator citation-grammar fragment, and the Flutter chip+modal renderer. Mirrors wave-1a-RESEARCH.md shape. Includes Nyquist Validation Architecture for VALIDATION.md auto-creation.
type: research
phase: wave-1b-citation-chips
date: 2026-05-14
primary_sources:
  - .planning/phases/wave-1b-citation-chips/wave-1b-CONTEXT.md
  - .planning/phases/wave-1a-backend-tools-refactor/wave-1a-SUMMARY.md
  - services/backend/app/services/coach/citation_registry.py
  - services/backend/app/services/coach/citation_parser.py
  - services/backend/app/services/coach/citation_grammar.py
  - services/backend/app/observability/coach_breadcrumbs.py
  - services/backend/app/models/coach_tools/*.py
  - apps/mobile/lib/widgets/coach/coach_message_bubble.dart
related:
  - MILESTONE-CHAT-AS-VERB-2026-05-09.md
---

# Wave 1b — Citation Chips Activation — RESEARCH

> Companion to `wave-1b-CONTEXT.md` (LOCKED). This file answers « what does the planner need to know to write 9-10 plans for Wave 1b ? ». Every concrete claim is anchored to a `file:line` citation or a verified verbatim quote — per CLAUDE.md §9 0-trust protocol.

---

## Section 0 — How to read this phase

1. **Read first :** `.planning/phases/wave-1b-citation-chips/wave-1b-CONTEXT.md` — locked decisions D-01..D-06, in-scope vs out-of-scope, open questions with plan defaults, hard constraints, counter-arguments, data gaps.
2. **Then read :** This RESEARCH.md — implementation pattern per requirement, file:line citations, narrator-prompt diff, Flutter widget reuse, ARB inventory, Nyquist Validation Architecture, 5-gate close-out diff.
3. **Then read :** `.planning/phases/wave-1a-backend-tools-refactor/wave-1a-SUMMARY.md` — predecessor phase. Wave 1b consumes Wave 1a's `inputs_hash` field via `tool_call_id` source kind. Coupling per CONTEXT D-01 + D-04 : Wave 1a's 21-commit dev backlog + Wave 1b shipping commits in one dev→staging atomic event, Railway env flags flipped immediately after merge.
4. **Reference (read on demand) :** `services/backend/app/services/coach/citation_parser.py:32-475` (gate body, regexes, `{{cite:<key>}}` grammar — DO NOT MODIFY per CONTEXT hard constraint #4), `services/backend/app/services/coach/citation_grammar.py:1-399` (narrator prompt fragment — Wave 1b EXTENDS), `services/backend/app/observability/coach_breadcrumbs.py:26-71` (5-kwarg breadcrumb helper — Wave 1b reuses).

**Confidence breakdown** (HIGH / MEDIUM / LOW assigned per Section 9 Counter-arguments + Data gaps) :
- Backend pattern (registry extension + narrator grammar diff) : **HIGH** — every change is grep-anchored against existing Wave 1a files.
- Mobile chip widget reuse : **MEDIUM** — `CoachSourcesSection` exists at `coach_message_bubble.dart:359-451` (verified) but it currently renders `RagSource` (legacy RAG path), not citation chips. Wave 1b plan must decide between (a) extend `CoachSourcesSection` to render mixed list of `RagSource + ToolCallCitationChip`, or (b) add a sibling `CoachCitationChipsSection` rendered next to it. Open Q in Section 4.
- Modal renderer : **MEDIUM** — existing `showModalBottomSheet` pattern at `response_card_widget.dart:490` is the proof modal precedent; Wave 1b modal mirrors that shape.
- 5-gate close-out diff : **HIGH** — `wave_1a_close.sh` is 56 lines, the additional ARB-parity + Flutter test step is mechanical.

---

## Section 1 — What CONTEXT.md settles (locked decisions D-01..D-06)

Copy-recap from `.planning/phases/wave-1b-citation-chips/wave-1b-CONTEXT.md` lines 63-68 :

- **D-01** — Couple Wave 1a flag flip with Wave 1b UI ship. Reason : decoupling = invisible win or empty modal. Flip on dev→staging deploy as one atomic ship event.
- **D-02** — `tool_call_id` source kind already declared in `citation_registry.py:54` Literal. No schema change needed — just add entries.
- **D-03** — Chip-tap modal is read-only, no edit/refresh. Reason : Wave 1a's `inputs_hash` is deterministic, recomputing client-side adds no value. Future : « force-recompute » CTA in a later wave if Sentry shows users tapping repeatedly.
- **D-04** — Coupling with Wave 1a's 21-commit backlog on dev. Reason : dev→staging merge is overdue regardless ; bundling Wave 1b's shipping commits avoids two staging deploys in one week.
- **D-05** — G2 = Claude autonomous (per `[[g2-claude-autonomous-not-julien-token]]`). No `checkpoint:human-verify` in Wave 1b plans.
- **D-06** — Chip strings ship in 6 ARB locales at plan time, not deferred. Reason : ARB parity gate G5 fails closed ; deferring loses CI green.

**Hard constraints** (from CONTEXT.md lines 23-31) :
1. CLAUDE.md TOP rules (banned terms, accents, MINT ≠ retraite, financial_core reuse, i18n, 0-trust).
2. 5-gate exit (G1 Maestro, G2 Claude autonomous, G3 dev CI, G4 regression, G5 LSFin+accent+ARB).
3. No new `_compute_*` dispatcher branches — Wave 1a owns those.
4. **No change to `_RE_CURRENCY` / `_RE_PERCENT` regexes** in `citation_parser.py` — single source of truth from Phase 94.
5. Mobile chip renderer reuses the existing chip widget from Phase 94/96 — no new design-system primitive.
6. Flag flip discipline : 5 Railway env vars flip ONLY at Wave 1b ship time.

**Plan defaults for open questions** (CONTEXT lines 72-75) :
1. WHICH `inputs_hash` for WHICH number → (a) one chip per tool call attached to the response container.
2. Chip placement → footer « Sources » row (less visual noise).
3. Modal JSON viewer → pretty-print, no syntax highlight (Karpathy #2).
4. Backward compat (flags OFF) → no chip rendered (legacy = no `inputs_hash` = no chip).

**Out of scope** (CONTEXT lines 53-59) : pgvector `retrieve_memories`, Wave 1c 20-Q&A parity, CapEngine Flutter→Python port, Phases 92/92.5/93/97/97.5, citation chip for legacy `_format_*` outputs.

---

## Section 2 — Phase requirements

| ID | Description | Research support |
|---|---|---|
| WAVE1B-01 | CITATION_REGISTRY extended with 6 `tool_call_id` entries (budget_snapshot, retirement_projection, cross_pillar_analysis, couple_optimization, cap_status, retrieve_memories) | Section 3 — registry entry shape, `citation_registry.py:65-178` is the file to extend (frozen `MappingProxyType` requires adding entries to `_REGISTRY` dict BEFORE the frozen view is built at `citation_registry.py:182`). |
| WAVE1B-02 | Narrator prompt grammar instruction for `{{cite:tool_call_id:<inputs_hash>}}` | Section 4 — narrator-prompt diff in `citation_grammar.py`. Key point : the CURRENT grammar uses `{{cite:<key>}}` where `<key>` is a registry key. Wave 1b extends to support a 2-segment form `{{cite:tool_call_id:<inputs_hash>}}` OR (simpler) keeps the 1-segment form with a synthetic key `tool:<name>:<inputs_hash>`. Recommendation : Section 4. |
| WAVE1B-03 | Sentry breadcrumb `coach.citation.tool_call_id.emitted` (5-kwarg) | Section 6 — reuse `emit_coach_tool_breadcrumb` at `coach_breadcrumbs.py:26-71` OR add sibling `emit_coach_citation_breadcrumb` with same payload shape. Wave 1a already emits `coach.tool.<name>` at `_compute_*` time ; Wave 1b emits `coach.citation.tool_call_id.emitted` at narrator-emission time (different lifecycle, different category). |
| WAVE1B-04 | Flutter chip renderer recognizes `tool_call_id` source kind (⚙ vs 📖 icon) | Section 5 — extend `CoachSourcesSection` at `coach_message_bubble.dart:359-451` OR add sibling `CoachCitationChipsSection`. The current widget renders `RagSource` (file/title/section) — needs a parallel path for citation chips with `sourceKind`, `inputsHash`, `computedAt`, `flagState`. |
| WAVE1B-05 | Chip-tap modal (tool name, inputs_hash, computed_at, raw JSON, flag_state badge, « souviens-toi » CTA) | Section 5 — mirror `showModalBottomSheet` pattern at `response_card_widget.dart:490-569`. The « souviens-toi de cette source » CTA wires to `save_insight` / `save_fact` tool (or a new « bookmark citation » tool — Karpathy #2 simplicity says reuse `save_insight` with a citation key prefix). |
| WAVE1B-06 | ARB strings × 6 locales (5 new keys × 6 = 30 entries) | Section 6 — naming convention `coachCitationChip*` (matches existing `coachSources` at `app_fr.arb:3984`). Concrete keys + FR values in Section 6. |
| WAVE1B-07 | Backend tests ≥ 18 (6 entries × ≥ 3 assertions) + Sentry breadcrumb contract tests | Section 8 — file at `services/backend/tests/test_citation_gate/test_tool_call_id_registry.py` (new). 6 entries × 3 assertions (entry exists, source_kind == "tool_call_id", resolve() returns expected shape). Plus 3-5 breadcrumb contract tests. |
| WAVE1B-08 | Mobile golden test for chip rendering + widget test for tap-to-modal | Section 8 — golden in `apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart` ; widget test for modal open in same dir. |
| WAVE1B-09 | `tools/checks/wave_1b_close.sh` (mirrors wave_1a) | Section 7 — diff against `wave_1a_close.sh` adds : (a) ARB parity on the 5 new keys × 6 locales, (b) chip golden snapshot, (c) widget test for modal. |
| WAVE1B-10 | Railway env vars `COACH_TOOL_SERVER_SIDE_*=true` flip coupled with dev→staging deploy | Section 7 — operational. The 5 env vars are listed in `wave-1a-08-PLAN.md:436-441`. Flipping happens in lock-step with the merge ; Claude autonomous G2 verification per D-05 + `[[g2-claude-autonomous-not-julien-token]]`. |

---

## Section 3 — Tool-by-tool implementation pattern (5 registry entries × shape)

Wait — the planner ships **6 entries**, not 5. Per CONTEXT.md line 35 the requirement is « one per Wave 1a tool: budget_snapshot, retirement_projection, cross_pillar_analysis, couple_optimization, cap_status, retrieve_memories ». Six entries.

### 3.1 Anatomy of an existing entry (citation_registry.py:67-72)

```python
"r3a_plafond_salarie_2026": CitationSource(
    key="r3a_plafond_salarie_2026",
    source_kind="spec",
    source_ref="spec:OPP3#art_7_alinea_1_lit_a",
    description_fr="Plafond annuel 3a salarié·e affilié·e LPP, OPP3 art. 7 al. 1 let. a, année 2026.",
),
```

Four required fields, `extra=forbid` + `frozen=True` via `model_config` at `citation_registry.py:51`. The `Literal["profile", "reasoning", "tool_call_id", "adr", "spec"]` at `citation_registry.py:54` already accepts `tool_call_id` — **no schema change needed** (D-02 verified).

### 3.2 The 6 Wave 1b entries — proposed shape

Per CONTEXT plan default (open Q 1) : **one chip per tool call**, attached to the response container. That means the registry key is **per-tool, not per-inputs-hash**. The dynamic part (the actual `inputs_hash` value) lives in the runtime response, NOT in the registry.

| Tool name | Proposed registry key | source_kind | source_ref | description_fr (FR, accents ✓, banned-terms-clean) |
|---|---|---|---|---|
| `get_budget_status` | `tool_budget_snapshot` | `tool_call_id` | `tool:budget_snapshot` | « Instantané du budget calculé côté serveur : revenu mensuel net, dépenses, surplus, mois de liquidité — depuis ton profil MINT. » |
| `get_retirement_projection` | `tool_retirement_projection` | `tool_call_id` | `tool:retirement_projection` | « Projection de retraite calculée côté serveur : rente AVS estimée, rente LPP estimée, total — à partir de ton certificat et de ton profil. » |
| `get_cross_pillar_analysis` | `tool_cross_pillar_analysis` | `tool_call_id` | `tool:cross_pillar_analysis` | « Analyse inter-piliers calculée côté serveur : marge 3a, marge rachat LPP, économie fiscale potentielle — selon ta situation actuelle. » |
| `get_couple_optimization` | `tool_couple_optimization` | `tool_call_id` | `tool:couple_optimization` | « Optimisation couple calculée côté serveur : répartition AVS, partage fiscal, marge 3a couple — depuis tes estimations partenaire. » |
| `get_cap_status` | `tool_cap_status` | `tool_call_id` | `tool:cap_status` | « Cap du jour validé côté serveur (garde CHF appliquée) : texte du cap + sources réglementaires explicites — depuis ton profil et l'état du jour. » |
| `retrieve_memories` | `tool_retrieve_memories` | `tool_call_id` | `tool:retrieve_memories` | « Souvenirs pertinents retrouvés par recherche BM25 dans tes faits déclarés — depuis ta biographie financière MINT. » |

**Banned-terms verification** : none of the 6 descriptions contain `garanti`, `optimal`, `meilleur`, `certain`, `assuré`, `parfait`, `sans risque`. The word « validé » (entry 5) is non-banned — it's the past participle of « valider » (« vérifié »), not a financial promise.

**Accent verification** : « calculé », « côté », « mensuel », « dépenses », « liquidité », « inputs hash », « partagé », « réglementaires », « selon », « marge », « économie », « répartition », « partagé », « partenaire », « garde », « validé », « réglementaires », « pertinents » — all 100% FR.

### 3.3 Runtime resolution — the `inputs_hash` plumbing

The registry key (e.g. `tool_budget_snapshot`) is STATIC at module-import. The dynamic part — the actual `inputs_hash` value emitted by `_compute_budget_status` at `coach_chat.py:2368-2469` (per `wave-1a-SUMMARY.md:64`) — lives in the **tool response JSON** that the narrator already receives. Per `BudgetSnapshotResponse` at `services/backend/app/models/coach_tools/budget_snapshot.py:13-25` :

```python
class BudgetSnapshotResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel, frozen=True)
    monthly_income: Decimal
    monthly_expenses: Decimal
    monthly_surplus: Decimal
    months_liquidity: float
    inputs_hash: str = Field(..., min_length=64, max_length=64)
    computed_at: datetime
```

`monthly_income, monthly_expenses, monthly_surplus, months_liquidity, inputs_hash, computed_at` — same shape on `RetirementProjectionResponse`, `CrossPillarAnalysisResponse`, `CoupleOptimizationResponse` per `models/coach_tools/*.py` Section 5 grep evidence.

**KEY FINDING — flag_state is NOT in the Pydantic response models.** It's only in the Sentry breadcrumb at `coach_chat.py:910-2938` (always `"on"` when `_compute_*` runs, never serialized to the LLM). For Wave 1b the chip can DERIVE `flag_state` from response presence : if the response carries `inputs_hash`, the flag was ON. If the response is a legacy `_format_*` string, no `inputs_hash` → no chip. This matches CONTEXT plan default Q4 (legacy path = no chip).

**Implication for the chip-tap modal "flag_state badge"** : the badge always reads "Serveur (flags ON)" when the chip renders, because the chip only renders when the response carries `inputs_hash`. The badge is informational, not state-distinguishing. Consider whether the planner wants to keep the badge at all (Karpathy #2 — if it's always the same value, drop it). RECOMMENDATION : drop the badge for v1, add it in Wave 2 when there's a meaningful state distinction (e.g. multiple flag combinations or staged rollout cohorts).

### 3.4 `resolve()` extension (citation_registry.py:185-203)

The current `resolve(key, ctx)` returns `description_fr` if `key in CITATION_REGISTRY`. For `tool_call_id` source kind, Wave 1b can either :
- **(a) Keep `resolve()` unchanged** — the description_fr serves as the modal subtitle ; the inputs_hash + computed_at travel via the response container (not via `resolve`). **Simplest, recommended (Karpathy #2).**
- (b) Extend `resolve()` to dispatch per `source_kind` — touches more code, defers nothing real.

Plan should pick (a). The narrator emits `{{cite:tool_budget_snapshot}}` (1-segment, registry-key form), and the Flutter chip enriches the chip with the response payload's `inputsHash` + `computedAt` carried alongside the message in `CoachResponse.toolCalls` (or a new `citationChips` array — see Section 5.4).

**Section 4 covers the alternative 2-segment grammar `{{cite:tool_call_id:<inputs_hash>}}` and why it's NOT recommended.**

### 3.5 Subset invariant

`citation_registry.py:20-21` documents : « every key here MUST also appear in at least one bundle's `citation_allowlist` ». Wave 1b plan must either :
- Add `tool_budget_snapshot, tool_retirement_projection, ...` to one bundle's allowlist (probably a new « tool_calls » bundle, OR the always-on bundle to keep it universal), OR
- Amend the `test_registry_subset_of_bundle_allowlists` invariant test to exempt `tool_call_id` source kind.

RECOMMENDATION : amend the invariant test. `tool_call_id` keys are activated for ANY narrator turn that calls a server-side tool ; they're not intent-gated. Hardcoding them into one bundle is conceptually wrong. The test exemption is one-line and explicit.

---

## Section 4 — Narrator prompt extension diff

### 4.1 Where the narrator prompt is built

| File | Lines | Purpose |
|---|---|---|
| `services/backend/app/services/coach/claude_coach_service.py` | 987-1074 | `build_narrator_system_prompt()` — flag-conditional citation-grammar append at line 1055-1066 |
| `services/backend/app/services/coach/claude_coach_service.py` | 1077-1145 | `build_narrator_system_prompt_from_bundles()` — bundle-compiler path |
| `services/backend/app/services/coach/citation_grammar.py` | 1-399 | `CITATION_GRAMMAR_FRAGMENT` + `build_intent_scoped_citation_grammar(intents)` |
| `services/backend/app/services/coach/citation_grammar.py` | 61-177 | `_build_citation_grammar_fragment()` — builds the FR doctrine text from `CITATION_REGISTRY` at import |
| `services/backend/app/api/v1/endpoints/coach_chat.py` | 60-61, 829, 891 | Dispatcher imports + calls both builders |

### 4.2 The grammar today (verbatim from `citation_grammar.py:77-90`)

```
## DOCTRINE — GRAMMAIRE DE CITATION (closed-world, non-négociable)

Pour CHAQUE chiffre émis (montant CHF/EUR/USD, pourcentage, durée en années/mois/jours, constante réglementaire), place un placeholder `{{cite:<clé>}}` directement après le chiffre. La liste des clés autorisées est ci-dessous — c'est un vocabulaire fermé. En l'absence de clé adaptée pour un chiffre, écris « je n'ai pas cette donnée pour l'instant » à la place du chiffre. N'INVENTE JAMAIS une clé qui n'apparaît pas dans la liste — la garde rejette toute clé inconnue et la réponse bascule alors sur un fallback templaté.
```

The fragment then enumerates the 18 keys (now 24 with Wave 1b) under « Clés autorisées (vocabulaire fermé) ».

### 4.3 Two options for the grammar extension

**Option A — 1-segment grammar (RECOMMENDED, Karpathy #2 simplicity).** The narrator emits `{{cite:tool_budget_snapshot}}` after a number derived from `BudgetSnapshotResponse`. The 6 new keys appear in the « Clés autorisées » list with description_fr explaining « ce chiffre vient du calcul serveur `<tool>` ; il porte un `inputs_hash` que tu n'as pas besoin de citer ». The Flutter chip uses the response's `inputsHash` to populate the modal (looked up via the message's tool-call list). **Gate impact : ZERO** — `_RE_CITE_PLACEHOLDER = r"\{\{cite:[A-Za-z0-9_\-]+\}\}"` at `citation_parser.py:98` matches single-segment keys already.

**Option B — 2-segment grammar `{{cite:tool_call_id:<inputs_hash>}}`.** Requires :
- Modifying `_RE_CITE_PLACEHOLDER` to `r"\{\{cite:[A-Za-z0-9_\-]+(?::[a-f0-9]{64})?\}\}"` — **VIOLATES CONTEXT hard constraint #4** (no change to `citation_parser.py` regexes from Phase 94).
- Modifying `_has_adjacent_cite` at `citation_parser.py:431-455` to parse the 2-segment key.
- Modifying `_substitute_placeholders` at `citation_parser.py:458-499` to dispatch on the 2-segment form.

Option B is more « literally what the user asked for » (the requirement text says `{{cite:tool_call_id:<inputs_hash>}}`) but **violates the hard constraint**. The plan resolves this with Option A : keep the placeholder 1-segment, the narrator emits `{{cite:tool_budget_snapshot}}`, and the per-call `inputs_hash` is carried in the tool-call response object surfaced to Flutter via `CoachResponse.toolCalls` (existing field at `coach_llm_service.dart:249`).

**This is a deviation from the requirement text WAVE1B-02** ("`{{cite:tool_call_id:<inputs_hash>}}` placeholder emission"). The planner needs to surface this in PLAN.md so Julien can confirm. The deviation rationale : (1) hard-constraint-respecting, (2) Karpathy #2 simplicity (don't add a 2-segment grammar when 1-segment + side-channel works), (3) per-tool one chip per response container is the visual default (CONTEXT open Q1 plan default (a)), so per-number inputs_hash granularity isn't needed anyway.

**RECOMMENDED — Option A, with PLAN.md surfacing the deviation explicitly for Julien confirmation.**

### 4.4 Minimal diff to `citation_grammar.py`

The current `_build_citation_grammar_fragment()` enumerates `CITATION_REGISTRY` alphabetically (line 97). Adding 6 keys auto-includes them in the list **with zero code change** — the test `test_grammar_fragment_lists_all_18_registry_keys` (cited at `citation_grammar.py:39`) will need updating to expect 24 keys, but the fragment text rebuilds itself.

Required text additions :
- **One new paragraph after the header** explaining the `tool_call_id` semantics. Proposed FR text (banned-terms-clean, accent-clean) :

```
Certaines clés (`tool_*`) marquent un chiffre calculé côté serveur — son `inputs_hash` voyage avec la réponse, tu n'as pas besoin de le citer dans le texte. Place simplement la clé `{{cite:tool_<nom>}}` après le chiffre, comme pour les autres clés du vocabulaire fermé.
```

- **One new EXAMPLE block** :

```
**ACCEPTÉ — chiffre calculé côté serveur** :
L'outil `get_budget_status` renvoie un surplus mensuel de 1'234 CHF. Tu peux répondre : « Selon ton dernier instantané, ton surplus mensuel pourrait être autour de 1'234 CHF {{cite:tool_budget_snapshot}}. La garde reconnaît la clé `tool_*` et lie automatiquement le chiffre à l'`inputs_hash` du calcul. »
```

- **Update `_INTENT_TO_CITATION_KEYS`** at `citation_grammar.py:209-276` — should `tool_*` keys be intent-scoped, or always-on ?

  RECOMMENDATION : **always-on**. The intent classifier (`coach_chat._classify_user_intent`) maps user messages to one of 6 enums (debt / housing / family / career / retirement / taxes), but tool calls are LLM-driven, not intent-driven — the narrator can call `get_budget_status` even on a « retirement » intent. Adding `tool_*` keys to EVERY intent bucket guarantees coverage. Diff : append the 6 tool keys to each intent's `frozenset(...)`.

  Alternative : add a special « tool_calls » intent that maps to all 6 tool keys, and ensure the dispatcher includes it whenever ANY tool fired in the agent loop. More surgical but more code. Karpathy #2 says go with always-on first.

### 4.5 Plan items for the narrator extension

- Plan 02 or 03 task : `services/backend/app/services/coach/citation_grammar.py` — add the `tool_call_id` paragraph + example in `_build_citation_grammar_fragment()`. Update `_INTENT_TO_CITATION_KEYS` mapping (6 new keys in each intent bucket OR a single intent bucket — see 4.4). Update grammar-fragment snapshot test to expect new bullet rows.
- Plan task : update the registry-contract test `tests/test_citation_gate/test_registry_contract.py::test_registry_subset_of_bundle_allowlists` to exempt `tool_call_id` source kind (per Section 3.5).

---

## Section 5 — Flutter chip + modal extension pattern

### 5.1 Current chip / source rendering surfaces (4 sites verified)

| Surface | File:line | What it renders |
|---|---|---|
| `CoachSourcesSection` (chat footer) | `apps/mobile/lib/widgets/coach/coach_message_bubble.dart:359-451` | Reads `List<RagSource> sources` from `ChatMessage.sources` ; draws « Sources » header + rows of `Icon(description_outlined) + RagSource.title — section`. Navigates on tap to `/pilier-3a`, `/rente-vs-capital`, `/fiscal`, `/retraite`, `/budget`, `/education/hub` per regex match on `source.file`. |
| Response card proof modal | `apps/mobile/lib/widgets/coach/response_card_widget.dart:490-569` | `showModalBottomSheet(isScrollControlled: true, maxHeight: 0.85)` ; pretty-prints `card.sources` (List<String>) + `card.alertes` + `card.disclaimer`. |
| `ChatConsentChip` | `apps/mobile/lib/widgets/coach/chat_consent_chip.dart:22-130` | Inline accept/decline chip widget (NOT a citation chip). Pattern : `GestureDetector` + `Container(padding: 16/10, BorderRadius.circular(20), border 0.5px, MintColors.porcelaine)` — this IS the design-system chip primitive Wave 1b must reuse per CONTEXT hard constraint #5. |
| `MintInlineInputChip`, `third_party_chip` | `apps/mobile/lib/widgets/premium/...`, `apps/mobile/lib/widgets/document/...` | Other chip use cases, not relevant. |

### 5.2 What Wave 1b adds — recommendation

The cleanest path is **NOT** to overload `CoachSourcesSection` (RagSource has different shape — `title/file/section`, not `sourceKind/inputsHash/computedAt`). Instead, **add a sibling `CoachCitationChipsSection`** rendered IN PARALLEL to `CoachSourcesSection` in `coach_message_bubble.dart:158-165` :

```dart
// Citation chips (Wave 1b) — tool-call provenance, rendered alongside sources.
if (msg.citationChips.isNotEmpty) ...[
  const SizedBox(height: MintSpacing.md - 4),
  Padding(
    padding: const EdgeInsets.only(left: 44, right: MintSpacing.xxl),
    child: CoachCitationChipsSection(chips: msg.citationChips),
  ),
],
// Existing Sources block stays unchanged below.
```

This satisfies CONTEXT hard constraint #5 (no new design-system primitive — chip visual reuses `ChatConsentChip._buildChip` border/radius/padding tokens) AND avoids touching the RagSource code path.

### 5.3 New widget — `CoachCitationChipsSection`

File : `apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart` (new). Shape mirrors `CoachSourcesSection` at `coach_message_bubble.dart:359-451` :

```dart
class CoachCitationChipsSection extends StatelessWidget {
  final List<ToolCallCitationChip> chips;
  const CoachCitationChipsSection({super.key, required this.chips});

  @override
  Widget build(BuildContext context) {
    // Container — same MintColors.bleuAir alpha 0.1 + 16px radius as CoachSourcesSection
    // Header text — S.of(context)!.coachCitationChipsHeader  (e.g. « Calculs serveur »)
    // For each chip — InkWell wrapping Row(Icon(settings_outlined) + chip label
    //   chip label = S.of(context)!.coachCitationChipLabel(toolDisplayName)
    //   On tap → _showCitationModal(context, chip)
  }
}

class ToolCallCitationChip {
  final String toolName;       // e.g. "budget_snapshot"
  final String inputsHash;     // 64-char hex
  final DateTime computedAt;   // ISO from `computedAt` field
  final Map<String, dynamic> rawResponse;  // for the JSON viewer
}
```

### 5.4 Wiring — where does `ToolCallCitationChip` come from ?

Two paths :

**(a) Extend `CoachResponse` with `List<ToolCallCitationChip> citationChips`** built from `response.toolCalls` (existing field at `coach_llm_service.dart:249`). The backend dispatcher already serializes `tool_calls` to the response in the agent loop ; Wave 1b needs only to (1) tag each tool_call entry with its `tool_call_id` source kind + `inputsHash` (already present in the per-tool Pydantic response payload), (2) Flutter parses these into `ToolCallCitationChip` instances. ZERO new HTTP fields if `tool_calls` already carries the full Pydantic JSON.

**(b) Add a new `citation_chips` field to the `/api/v1/chat` response schema.** More explicit, more bytes on the wire.

RECOMMENDATION : **(a)** if `tool_calls` already round-trips the Pydantic response. Verify in Plan 04 (Flutter wiring task) — read `coach_chat_api_service.dart` + the `CoachResponse.fromJson` factory to confirm `tool_calls` carries `monthlyIncome` etc. If not, fall to (b).

### 5.5 Modal — `_showCitationModal(context, chip)`

Mirror `response_card_widget.dart:490-569` pattern :

```dart
void _showCitationModal(BuildContext context, ToolCallCitationChip chip) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(MintSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.of(context)!.coachCitationModalTitle(chip.toolName), style: MintTextStyles.titleMedium()),
          const SizedBox(height: MintSpacing.md),
          // inputs_hash (truncated to 16 chars + tap-to-copy)
          // computed_at (relative time, e.g. "il y a 3 minutes")
          // Pretty-printed JSON (collapsible via ExpansionTile)
          //   header = S.of(context)!.coachCitationJsonViewerLabel
          //   body = SelectableText(JsonEncoder.withIndent('  ').convert(chip.rawResponse))
          // "Souviens-toi de cette source" CTA (TextButton onPressed → wires to save_insight)
          //   label = S.of(context)!.coachCitationRememberCta
        ],
      ),
    ),
  );
}
```

**Per CONTEXT open Q3 plan default** — pretty-print JSON, no syntax highlight. Use `dart:convert` `JsonEncoder.withIndent('  ')`.

**Per CONTEXT D-03** — modal is read-only, no edit/refresh.

### 5.6 Icon decision — ⚙ « computed » vs 📖 « spec »

CONTEXT line 39 suggests « ⚙ for "computed" vs 📖 for "spec"/ordinance ». Flutter Material icons :
- ⚙ (computed) → `Icons.settings_outlined` (size 12 to match existing `Icons.description_outlined` at `coach_message_bubble.dart:423`). Alternative : `Icons.calculate_outlined`.
- 📖 (spec) → existing `Icons.description_outlined` stays for `CoachSourcesSection`.

RECOMMENDATION : `Icons.calculate_outlined` for chip icon — it's semantically « calculé », not « configuré ».

### 5.7 ARB / i18n contract

All user-facing chip strings MUST go through `S.of(context)!.<key>` per CLAUDE.md TOP rule #5. No `Text('Calculs serveur')` hardcoded. See Section 6 for the 5 new keys × 6 locales = 30 entries.

---

## Section 6 — ARB key inventory (5 new keys × 6 locales = 30 entries)

### 6.1 Naming convention precedent

| Existing key | File:line | Pattern |
|---|---|---|
| `coachSources` | `app_fr.arb:3984` | `coach` prefix + content noun |
| `coachLoading` | `app_fr.arb:3983` | same |
| `coachInputHint` | `app_fr.arb:3991` | same |
| `coachUserMessage`, `coachCoachMessage`, `coachSendButton` | `app_fr.arb:3998-4000` | same |
| `coachDisclaimerCollapsed` | (used at `coach_message_bubble.dart:493`) | same |

Convention : `coach<Subject>` camelCase. Wave 1b uses `coachCitation<Suffix>`.

### 6.2 The 5 new keys + FR values (planner ships all 6 locales — see 6.3)

| Key | FR value | Used at |
|---|---|---|
| `coachCitationChipsHeader` | « Calculs serveur » | `CoachCitationChipsSection` header (Section 5.3) |
| `coachCitationChipLabel` | placeholder `{toolDisplayName}` chip face, e.g. « Budget actuel — calculé » | `CoachCitationChipsSection` chip body. Takes `String toolDisplayName`. |
| `coachCitationModalTitle` | placeholder `{toolDisplayName}` modal title, e.g. « Source du calcul : {toolDisplayName} » | Modal title (Section 5.5). |
| `coachCitationJsonViewerLabel` | « Voir le détail du calcul (JSON) » | `ExpansionTile` header (Section 5.5). |
| `coachCitationRememberCta` | « Souviens-toi de cette source » | CTA (Section 5.5). |

Two of these (`coachCitationChipLabel`, `coachCitationModalTitle`) need a placeholder `{toolDisplayName}`. ARB pattern (verified at `app_fr.arb:4003-4011`) :

```json
"coachCitationChipLabel": "{toolDisplayName} — calculé",
"@coachCitationChipLabel": {
  "placeholders": {
    "toolDisplayName": { "type": "String" }
  }
},
```

The 6 `toolDisplayName` values are STRINGS in the Flutter code (probably a small FR-only `static const Map<String, String> _toolDisplayNames`). They are NOT in ARB because they are FR strings hardcoded next to the tool name keys — the planner SHOULD i18n them too (« Budget actuel », « Projection de retraite », « Analyse inter-piliers », « Optimisation couple », « Cap du jour », « Souvenirs ») to satisfy CLAUDE.md TOP rule #5 strictly. That makes it 5 chip-label keys + 6 tool-name keys + 4 other keys = **15 new keys × 6 locales = 90 entries**, NOT 30.

**Plan deviation note** : CONTEXT line 41 says « 6 ARB locales × 5 keys = 30 entries ». The 5 keys cover the chip frame + modal frame. The 6 tool display names are an ADDITIONAL i18n surface that wasn't in CONTEXT. The planner must decide :
- (a) Tool display names go in ARB (6 extra keys × 6 = 36 extra entries) — strict CLAUDE.md TOP-5 compliance.
- (b) Tool display names live in a `_toolDisplayNames` const map in Dart, in FR only (legacy of the existing pattern for tool names) — defers i18n until launch milestone.

RECOMMENDATION : **(a)** — strict TOP-5. 90 entries total, which is still a small ARB delta (current `app_fr.arb` is 12,206 lines). The ARB parity gate G5 (per CONTEXT D-06) fails closed, so deferring is risky.

**FINAL TALLY** : **11 new ARB keys × 6 locales = 66 entries** (5 frame keys + 6 tool-name keys). The planner must surface this in PLAN.md and confirm vs CONTEXT line 41 « 30 entries ».

### 6.3 6-locale parity — minimal FR-EN translations for verbatim copy in PLAN.md

| Key | FR | EN |
|---|---|---|
| `coachCitationChipsHeader` | Calculs serveur | Server-side computations |
| `coachCitationChipLabel` | {toolDisplayName} — calculé | {toolDisplayName} — computed |
| `coachCitationModalTitle` | Source du calcul : {toolDisplayName} | Source of computation: {toolDisplayName} |
| `coachCitationJsonViewerLabel` | Voir le détail du calcul (JSON) | View computation detail (JSON) |
| `coachCitationRememberCta` | Souviens-toi de cette source | Remember this source |
| `coachToolBudgetSnapshot` | Budget actuel | Current budget |
| `coachToolRetirementProjection` | Projection de retraite | Retirement projection |
| `coachToolCrossPillarAnalysis` | Analyse inter-piliers | Cross-pillar analysis |
| `coachToolCoupleOptimization` | Optimisation couple | Couple optimization |
| `coachToolCapStatus` | Cap du jour | Daily cap |
| `coachToolRetrieveMemories` | Souvenirs | Memories |

DE / IT / ES / PT translations are mechanical and ship per-locale at plan time per D-06. The planner can hand off to `flutter gen-l10n` for code-gen.

### 6.4 Banned-terms verification on the 11 keys

None contain `garanti / optimal / meilleur / certain / assuré / parfait / sans risque`. « Souviens-toi » is imperative tutoiement (acceptable, matches existing « Dis-moi. » at `app_fr.arb:3991` `coachInputHint`).

### 6.5 Accent verification on the 11 keys

« Calculs », « calculé », « détail », « inter-piliers » — all 100% FR. Lint via `accent_lint_fr.py` (per Section 7).

---

## Section 7 — 5-gate close-out diff (wave_1a_close.sh → wave_1b_close.sh)

### 7.1 wave_1a_close.sh shape (verified at `tools/checks/wave_1a_close.sh:1-56`)

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

WAVE_1A_BACKEND_FILES=( ...9 files + models/coach_tools/*.py )

echo "==> G3 + G4 — backend pytest"
( cd services/backend && python3 -m pytest tests/ -q )

echo "==> G4 — parity harness"
( cd services/backend && python3 -m pytest tests/test_coach_tools_parity.py -q )

echo "==> G5 — banned_terms_python on Wave 1a touched files"
python3 tools/checks/banned_terms_python.py "${WAVE_1A_BACKEND_FILES[@]}"

echo "==> G5 — accent_lint_fr on Wave 1a touched files"
for f in "${WAVE_1A_BACKEND_FILES[@]}"; do
  python3 tools/checks/accent_lint_fr.py --file "$f"
done

echo "==> wave_1a_close.sh: ALL GATES GREEN (G3+G4+G5)"
```

### 7.2 wave_1b_close.sh new requirements

```bash
WAVE_1B_BACKEND_FILES=(
  services/backend/app/services/coach/citation_registry.py
  services/backend/app/services/coach/citation_grammar.py
  services/backend/app/observability/coach_breadcrumbs.py   # IF a new emit_coach_citation_breadcrumb is added
)

WAVE_1B_MOBILE_FILES=(
  apps/mobile/lib/widgets/coach/coach_message_bubble.dart
  apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart   # NEW
  apps/mobile/lib/services/coach/citation_chip_parser.dart          # NEW (if extracted from CoachResponse)
)
```

**New gate steps** (versus wave_1a) :

| Step | Command | Why |
|---|---|---|
| G3+G4 backend pytest | `cd services/backend && python3 -m pytest tests/ -q` | Same as wave_1a. Target ≥ 6864+18 = 6882. |
| G4 registry contract | `cd services/backend && python3 -m pytest tests/test_citation_gate/test_tool_call_id_registry.py -q` | New, 18+ tests for the 6 entries. |
| G4 Flutter widget tests | `cd apps/mobile && flutter test test/widgets/coach/coach_citation_chip_*.dart` | New, golden + tap-to-modal. |
| G5 banned_terms_python | `python3 tools/checks/banned_terms_python.py "${WAVE_1B_BACKEND_FILES[@]}"` | New file list. |
| G5 accent_lint_fr (backend) | per-file loop on `WAVE_1B_BACKEND_FILES` | Same shape as wave_1a. |
| **G5 ARB parity (NEW)** | `python3 tools/checks/arb_parity.py` | Required because Wave 1b adds 11 new keys × 6 locales. The script auto-detects missing keys across locales (reference = fr per `arb_parity.py:21-24`). Verified at `tools/checks/arb_parity.py`. |
| **G5 banned_terms_arb (NEW)** | `python3 tools/checks/banned_terms_arb.py` | Required because chip strings are FR user-facing (cf. `tools/checks/banned_terms_arb.py` verified at the path). |
| **G5 accent_lint_fr (ARB)** | `python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb` | ARB is also subject to accent lint. |

### 7.3 5-gate status table for VERIFICATION-REPORT.html

| Gate | Status criterion |
|---|---|
| G1 Maestro flow (drafted, live on staging) | `tools/simulator/flows/maestro-perfect-set/coach_citation_chip_smoke.yaml` exists ; live run logged in `wave-1b-VERIFICATION-REPORT.html` post-staging-deploy |
| G2 Claude autonomous (per D-05) | Maestro flow ran on iPhone-17-Pro sim against staging build with Wave 1a flags ON ; Claude captured Maestro transcript ; tap-chip → modal renders with `inputs_hash` truncated to 16 chars |
| G3 dev CI | `bash tools/checks/wave_1b_close.sh` exits 0 |
| G4 regression | Backend pytest ≥ 6882, Flutter test count ≥ existing + 5 |
| G5 LSFin + accent + ARB parity | All 3 lint scripts exit 0 on the Wave-1b-touched file set + 6-locale parity green |

---

## Section 8 — Sentry breadcrumb wiring

### 8.1 Existing helper (verified at `coach_breadcrumbs.py:26-71`)

```python
def emit_coach_tool_breadcrumb(
    tool_name: str,
    inputs_hash: str,
    profile_id_hashed: str,
    elapsed_ms: int,
    flag_state: Literal["on", "off"],
    extra_tags: Optional[Dict[str, str]] = None,
) -> None:
    ...
    sentry_sdk.add_breadcrumb(
        category=f"coach.tool.{tool_name}",   # <- per-tool category
        message="invoked",
        level="info",
        data=data,
    )
```

Wave 1a emits this at `_compute_<tool>` time (e.g. `coach.tool.budget_status` per `coach_chat.py:2368-2469` evidence in `wave-1a-SUMMARY.md:64`).

### 8.2 Wave 1b new breadcrumb — `coach.citation.tool_call_id.emitted`

This fires at a DIFFERENT lifecycle moment : when the **narrator emits** a `{{cite:tool_*}}` placeholder, NOT when the `_compute_*` runs. Two different events on the same coach turn :

| Event | Category | When |
|---|---|---|
| Tool computed | `coach.tool.<name>` | `_compute_<tool>()` ran (Wave 1a) |
| Citation emitted | `coach.citation.tool_call_id.emitted` | Narrator's output contained `{{cite:tool_*}}` AND gate verdict = PASS (Wave 1b) |

### 8.3 Wiring options

**Option A — Add a new helper** `emit_coach_citation_breadcrumb(tool_name, inputs_hash, profile_id_hashed, elapsed_ms, flag_state)` in `coach_breadcrumbs.py`. Same 5-kwarg payload (per requirement WAVE1B-03). Different `category=f"coach.citation.tool_call_id.{tool_name}"`. **RECOMMENDED — explicit, separate test surface, single-responsibility.**

**Option B — Reuse `emit_coach_tool_breadcrumb`** with a `category_override` arg. Couples 2 events behind 1 helper. Less clean.

### 8.4 Where to emit

In `_run_narrator_with_gate` at `coach_chat.py:4014-4057` — AFTER `gated = _citation_gate(...)`, BEFORE returning. Iterate over `gated.gated_text` (or rather, over the placeholder spans from the gate) and for each `tool_*` key found, call `emit_coach_citation_breadcrumb`. Concretely : extend the gate to optionally return the list of resolved placeholder keys, OR run `_RE_CITE_PLACEHOLDER.finditer(gated.gated_text)` in the wrapper and filter to keys starting with `tool_`.

RECOMMENDATION : the wrapper runs `_RE_CITE_PLACEHOLDER` on `gated.gated_text` (already imported at line 41 of `citation_parser.py`), filters keys starting with `tool_`, looks up the corresponding tool-call response in the loop result, and calls `emit_coach_citation_breadcrumb(tool_name=..., inputs_hash=tool_response.inputs_hash, ...)` per citation. ZERO change to `citation_parser.gate()` per CONTEXT hard constraint #4.

### 8.5 Cardinality / sampling

Per CONTEXT Section 9 data gap : no baseline for citation-chip taps. The breadcrumb should fire on EVERY emission (not sampled) for the first 30 days so the team has data. Sentry breadcrumb retention is 30 days on the staging plan ; if volume exceeds 10k/day, add per-user sampling in Wave 2.

---

## Section 9 — Counter-arguments + data gaps

> Per CLAUDE.md §8 wiki schema rule #2 : every decision artifact needs counter-arguments + data gaps. Wave 1b CONTEXT.md already has Section 9 covering Phase 92 fonts vs Wave 1b doctrine, coupling rationale, and 21-commit bundle. This RESEARCH.md adds the design-decision-level counter-args.

### 9.1 Counter-argument — Option B 2-segment grammar might be what users actually want

**Argument** : the requirement text WAVE1B-02 says `{{cite:tool_call_id:<inputs_hash>}}`. The Section 4 recommendation (Option A, 1-segment) deviates. If Julien meant the literal 2-segment form, the planner is overruling the requirement.

**Rebuttal** : Option A is functionally equivalent (1 chip per response container per CONTEXT Q1 plan default (a) — per-number `inputs_hash` granularity isn't needed) AND respects CONTEXT hard constraint #4 (no `citation_parser.py` regex changes). Option B requires the regex change. The planner surfaces the deviation in PLAN.md (Section 4.3) so Julien can confirm before exec.

**Confidence** : HIGH that the deviation is correct. Will surface in PLAN.md.

### 9.2 Counter-argument — `flag_state` badge is meaningless when chip only renders for `flags=on`

**Argument** : Section 3.3 finds `flag_state` is NOT in the Pydantic response and is always « on » when `_compute_*` runs. The chip already only renders when the response carries `inputs_hash` (flag=on). The badge always displays « on ». Drop it.

**Rebuttal** : retaining the badge is forward-looking — if Wave 2 introduces staged-rollout cohorts or partial flags, the badge becomes meaningful. Karpathy #2 simplicity wins for v1 → drop it.

**Confidence** : MEDIUM. Plan keeps the badge as an OPTIONAL piece, defaults to absent. Plan surfaces the question in PLAN.md.

### 9.3 Counter-argument — Should `_INTENT_TO_CITATION_KEYS` get the 6 new keys in EVERY intent, or in a new « tool_calls » intent ?

**Argument** : per Section 4.4, two choices. The « always-on in every intent » diff is mechanical but pollutes 7 intent buckets. The « new tool_calls intent » is more surgical but requires the dispatcher to detect tool firings.

**Rebuttal** : Karpathy #2 says go always-on. The mechanical pollution is 6×7=42 lines of frozenset additions. The « new intent » needs a dispatcher change.

**Confidence** : HIGH. Plan does always-on.

### 9.4 Counter-argument — `CoachCitationChipsSection` vs extending `CoachSourcesSection`

**Argument** : a parallel widget doubles the rendering surface and risks visual incoherence. Why not extend `CoachSourcesSection` with a type-switch on `Source` (sealed class with `RagSource` + `ToolCallCitationSource` variants) ?

**Rebuttal** : `RagSource` is read by 30+ Flutter files (per the legacy navigation map at `coach_message_bubble.dart:369-385`). A sealed class refactor is a large surface. CONTEXT hard constraint #3 says « no new `_compute_*` dispatcher branches » — the Flutter analog is « no large refactor of existing rendering paths ». Parallel `CoachCitationChipsSection` minimizes blast radius.

**Confidence** : HIGH. Plan adds a sibling widget.

### 9.5 Data gap — Maestro flow can't easily assert chip rendering on staging without test_id stability

**Gap** : the existing Maestro pattern (`flow_card_action_intent_bar.yaml`) taps by visible text. The chip label `« Budget actuel — calculé »` is mostly stable but `« il y a 3 minutes »` (relative time on the modal) is not. The Maestro G1 must either (a) tap by `testID` (requires adding `Key('coach_citation_chip_<toolName>')` to the widget), or (b) tap by text+icon proximity (fragile).

**Mitigation** : Plan includes Key() additions for stable Maestro tapping. Pattern : `Key('coachCitationChip-${chip.toolName}')`.

**Confidence** : HIGH.

### 9.6 Data gap — `tool_calls` round-trip from `_compute_*` to Flutter — does the response shape carry `inputsHash` already ?

**Gap** : Section 5.4 assumes `CoachResponse.toolCalls` carries the full Pydantic response (with `inputsHash` field). NOT VERIFIED in this research — the file `coach_chat_api_service.dart` was not opened.

**Mitigation** : Plan 04 (Flutter wiring) first task is to READ `coach_chat_api_service.dart` + `CoachResponse.fromJson` + the dispatcher's serialization of `tool_results` in the agent loop (`coach_chat.py:3252-3305`). If `tool_calls` does NOT round-trip the full Pydantic dump, fall to Section 5.4 option (b) — add a new `citation_chips` field to the chat response schema.

**Confidence** : MEDIUM. Plan ships a verify-first task.

### 9.7 Data gap — Bundle subset invariant test impact

**Gap** : Section 3.5 — if `tool_call_id` keys are exempted from the subset invariant, ALL `tool_call_id` future additions become un-validated. Risk : a future tool added without registry entry slips through.

**Mitigation** : exempt source_kind==`tool_call_id` from the subset rule, but add a SEPARATE invariant test : « every `tool_call_id` registry key must match the pattern `tool_*` AND have a corresponding dispatcher branch in `coach_chat.py` ». Concrete test in `tests/test_citation_gate/test_tool_call_id_registry.py::test_every_tool_key_has_dispatcher_branch`.

**Confidence** : HIGH. Plan includes this complementary test.

### 9.8 Counter-argument — Phase 92 (fonts) ships faster, why not first ?

(Already in CONTEXT.md Counter-arg 1 — recapped here for completeness.) Fonts are user-visible but don't unblock the doctrine (« every number with a citation »). Wave 1b is doctrine-critical.

### 9.9 Data gap — 21-commit dev backlog bundling risk

(From CONTEXT.md Counter-arg 3 + data gaps.) The 21 commits include wshobson + VoltAgent adoptions (memory-local), engram infra (Mac mini DB), Wave 0 docs. Actual code-runtime delta is Wave 1a + S98 observability. Safe to bundle. **Confidence** : MEDIUM — Plan 09 (ship task) inspects the 21-commit list before pushing dev→staging.

---

## Section 10 — Validation Architecture (Nyquist gate, D-08 mirror)

> Required structure per workflow step 5.5. Drives `VALIDATION.md` auto-creation.

### 10.1 Validation surfaces

Wave 1b has **4 validation surfaces** :

1. **Backend registry unit-test surface** — 6 entries × 3+ assertions = 18+ tests in `tests/test_citation_gate/test_tool_call_id_registry.py`.
2. **Backend gate integration surface** — gate runs on synthetic narrator text containing `{{cite:tool_*}}` placeholders ; verdict PASS, placeholder substituted with description_fr (or pass-through). Reuses `test_citation_gate/test_number_detection.py` fixtures style.
3. **Backend Sentry breadcrumb contract surface** — every `{{cite:tool_*}}` emission triggers `coach.citation.tool_call_id.emitted` with 5-kwarg payload. 3-5 contract tests.
4. **Flutter widget surface** — golden test for chip rendering ; widget test for tap-to-modal ; integration test for round-trip Maestro flow.

### 10.2 Test framework + commands

| Layer | Framework | Quick run | Full run |
|---|---|---|---|
| Backend | pytest 8.4+ (cf. `services/backend/tests/test_citation_gate/`) | `cd services/backend && python3 -m pytest tests/test_citation_gate/test_tool_call_id_registry.py -q -x` | `cd services/backend && python3 -m pytest tests/ -q` |
| Mobile | flutter test (cf. `apps/mobile/test/`) | `cd apps/mobile && flutter test test/widgets/coach/coach_citation_chip_test.dart` | `cd apps/mobile && flutter test` |
| ARB parity | `tools/checks/arb_parity.py` | `python3 tools/checks/arb_parity.py --locale en` | `python3 tools/checks/arb_parity.py` |
| Lints | `banned_terms_python.py`, `accent_lint_fr.py`, `banned_terms_arb.py` | per-file | `bash tools/checks/wave_1b_close.sh` |

### 10.3 Phase requirements → test map

| Req ID | Behavior | Test type | Automated command | File exists ? |
|---|---|---|---|---|
| WAVE1B-01 | Registry has 6 `tool_call_id` entries with correct shape | unit | `pytest tests/test_citation_gate/test_tool_call_id_registry.py::test_six_entries_present -x` | ❌ Wave 0 |
| WAVE1B-01 | Each entry has source_kind == `tool_call_id` | unit | `pytest tests/test_citation_gate/test_tool_call_id_registry.py::test_source_kind_invariant -x` | ❌ Wave 0 |
| WAVE1B-01 | `resolve(key, ctx)` returns description_fr for each entry | unit | `pytest tests/test_citation_gate/test_tool_call_id_registry.py::test_resolve_returns_description -x` | ❌ Wave 0 |
| WAVE1B-02 | `CITATION_GRAMMAR_FRAGMENT` lists all 6 new keys | unit | `pytest tests/test_citation_gate/test_grammar_fragment_lists_all_24_registry_keys -x` (renamed from 18) | ❌ Wave 0 (test renamed) |
| WAVE1B-02 | Intent-scoped grammar includes `tool_*` keys in every intent bucket | unit | `pytest tests/test_citation_gate/test_intent_scoped_grammar_includes_tools -x` | ❌ Wave 0 |
| WAVE1B-03 | `emit_coach_citation_breadcrumb` fires with 5-kwarg payload | contract | `pytest tests/test_citation_gate/test_breadcrumb_contract.py -x` | ❌ Wave 0 |
| WAVE1B-03 | Wrapper emits breadcrumb once per `{{cite:tool_*}}` placeholder | contract | `pytest tests/test_citation_gate/test_breadcrumb_cardinality.py -x` | ❌ Wave 0 |
| WAVE1B-04 | `CoachCitationChipsSection` renders one chip per `ToolCallCitationChip` | widget | `flutter test test/widgets/coach/coach_citation_chips_section_test.dart -p` | ❌ Wave 0 |
| WAVE1B-04 | Chip icon matches `Icons.calculate_outlined` (Wave 1b) vs `Icons.description_outlined` (Wave 1a RagSource) | golden | `flutter test test/widgets/coach/coach_citation_chip_golden_test.dart -p` | ❌ Wave 0 |
| WAVE1B-05 | Tap chip → bottom-sheet opens with tool name + inputs_hash + JSON viewer + CTA | widget | `flutter test test/widgets/coach/coach_citation_chip_modal_test.dart -p` | ❌ Wave 0 |
| WAVE1B-05 | « Souviens-toi » CTA invokes save_insight | widget | `flutter test test/widgets/coach/coach_citation_chip_modal_remember_test.dart -p` | ❌ Wave 0 |
| WAVE1B-06 | All 11 new ARB keys present in 6 locales | lint | `python3 tools/checks/arb_parity.py` exit 0 | ✅ tool exists |
| WAVE1B-06 | New FR strings pass banned-terms lint | lint | `python3 tools/checks/banned_terms_arb.py` exit 0 | ✅ tool exists |
| WAVE1B-06 | New FR strings pass accent lint | lint | `python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb` exit 0 | ✅ tool exists |
| WAVE1B-07 | Backend test count ≥ 6864+18 = 6882 | regression | `cd services/backend && python3 -m pytest tests/ -q | tail -1` returns `>=6882 passed` | ✅ infra exists |
| WAVE1B-08 | Flutter test count ≥ existing+5 | regression | `cd apps/mobile && flutter test | grep "All tests passed"` | ✅ infra exists |
| WAVE1B-09 | `wave_1b_close.sh` exits 0 | gate | `bash tools/checks/wave_1b_close.sh` | ❌ Wave 0 |
| WAVE1B-10 | 5 Railway env vars flipped to `true` post-staging-deploy | operational | manual + Claude autonomous G2 verification per D-05 | n/a (operational) |

### 10.4 Sampling rate (Nyquist)

- **Per task commit** (quick run) : `pytest tests/test_citation_gate/test_tool_call_id_registry.py -x` (≤ 5s) + `flutter test test/widgets/coach/coach_citation_chip_test.dart` (≤ 30s).
- **Per wave merge** (full run) : `bash tools/checks/wave_1b_close.sh` (~3 min : full pytest + flutter test + 3 lints).
- **Phase gate** (close-out) : full suite green before `/gsd-verify-work` ; G1 Maestro flow live on staging ; G2 Claude autonomous.

### 10.5 Wave 0 gaps (test infrastructure that needs creating before Wave 1)

- [ ] `services/backend/tests/test_citation_gate/test_tool_call_id_registry.py` — 18+ tests for 6 entries.
- [ ] `services/backend/tests/test_citation_gate/test_breadcrumb_contract.py` — Sentry helper contract.
- [ ] `services/backend/tests/test_citation_gate/test_breadcrumb_cardinality.py` — emission count per turn.
- [ ] `apps/mobile/test/widgets/coach/coach_citation_chip_test.dart` — base chip rendering.
- [ ] `apps/mobile/test/widgets/coach/coach_citation_chip_golden_test.dart` — golden snapshot.
- [ ] `apps/mobile/test/widgets/coach/coach_citation_chip_modal_test.dart` — tap-to-modal.
- [ ] `apps/mobile/test/widgets/coach/coach_citation_chip_modal_remember_test.dart` — CTA wiring.
- [ ] `tools/checks/wave_1b_close.sh` — 5-gate close-out.
- [ ] `tools/simulator/flows/maestro-perfect-set/coach_citation_chip_smoke.yaml` — G1 Maestro flow.

Plus updates to existing tests :
- [ ] `tests/test_citation_gate/test_registry_contract.py::test_registry_subset_of_bundle_allowlists` — exempt `tool_call_id` source kind.
- [ ] `tests/test_citation_gate/test_grammar_fragment_lists_all_18_registry_keys` — bump to 24 keys.

### 10.6 What CANNOT be auto-validated (G2 device only)

- Tap chip on a real staging build → modal opens with the actual `inputsHash` from a live `_compute_<tool>` invocation. Captured by Claude autonomous G2 per D-05 with Maestro+sim transcript.
- « Souviens-toi de cette source » CTA actually persists to the user's wiki page. Wave 2 verification (requires the user-profile wiki path from memory `project_user_profile_wiki`).

---

## Section 11 — Project Constraints (from CLAUDE.md)

| # | Rule | How Wave 1b respects it |
|---|---|---|
| 1 | LSFin banned terms | Section 3.2 verifies the 6 description_fr strings ; Section 6.4 verifies the 11 ARB FR strings ; `wave_1b_close.sh` G5 step runs `banned_terms_python.py` + `banned_terms_arb.py`. |
| 2 | 100% FR accents | Section 3.2 verifies « calculé/côté/dépenses/etc. » ; Section 6.5 verifies ARB ; G5 step runs `accent_lint_fr.py` on backend AND ARB. |
| 3 | MINT ≠ retirement app | Chip labels are framed per life event (« Budget actuel », « Cap du jour », « Souvenirs ») not « Retraite » exclusively. « Projection de retraite » is one of 6, not the default. |
| 4 | Financial_core reuse | Wave 1b adds NO new financial calculation. It consumes `inputs_hash` from Wave 1a `_compute_*` paths, which already reuse `financial_core/` services per `wave-1a-RESEARCH.md:64-71`. |
| 5 | i18n required | All 11 new user-facing strings go through `S.of(context)!.<key>`. Section 6 ARB inventory. |
| 6 | 0-trust protocol | Every claim in this RESEARCH.md is `file:line`-cited or marked as gap (Section 9). VERIFICATION-REPORT.html will cite Maestro transcripts + Sentry filter outputs post-staging-deploy. |

---

## Section 12 — Sources

### Primary (HIGH confidence)
- `.planning/phases/wave-1b-citation-chips/wave-1b-CONTEXT.md` (LOCKED) — locked decisions D-01..D-06, hard constraints, open Qs.
- `services/backend/app/services/coach/citation_registry.py:1-206` — Wave 0 baseline + `tool_call_id` Literal already declared.
- `services/backend/app/services/coach/citation_parser.py:1-735` — Phase 94 gate, regex set, `{{cite:<key>}}` grammar (DO NOT MODIFY).
- `services/backend/app/services/coach/citation_grammar.py:1-399` — narrator prompt fragment (Wave 1b EXTENDS).
- `services/backend/app/services/coach/claude_coach_service.py:987-1145` — narrator system prompt builders.
- `services/backend/app/observability/coach_breadcrumbs.py:1-71` — 5-kwarg Sentry helper.
- `services/backend/app/models/coach_tools/{budget_snapshot,retirement_projection,cross_pillar,couple_optimization}.py` — Pydantic v2 response models with `inputs_hash` + `computed_at`.
- `services/backend/app/api/v1/endpoints/coach_chat.py:910-2938, 4014-4115` — dispatcher + narrator-with-gate wrapper.
- `apps/mobile/lib/widgets/coach/coach_message_bubble.dart:1-451` — chat bubble + `CoachSourcesSection`.
- `apps/mobile/lib/widgets/coach/chat_consent_chip.dart:1-130` — chip design-system primitive (Wave 1b reuses).
- `apps/mobile/lib/widgets/coach/response_card_widget.dart:490-569` — `showModalBottomSheet` precedent.
- `apps/mobile/lib/services/coach_llm_service.dart:163-265` — `ChatMessage` + `CoachResponse` shape.
- `apps/mobile/lib/services/rag_service.dart:64-82` — `RagSource` model (parallel surface).
- `apps/mobile/lib/l10n/app_fr.arb` — ARB key naming precedent (`coachSources`, `coachLoading`, etc.).
- `tools/checks/wave_1a_close.sh:1-56` — 5-gate close-out template.
- `tools/checks/{arb_parity,accent_lint_fr,banned_terms_python,banned_terms_arb}.py` — lint surfaces.
- `.planning/phases/wave-1a-backend-tools-refactor/{wave-1a-RESEARCH.md, wave-1a-SUMMARY.md, wave-1a-08-PLAN.md}` — predecessor phase precedent.
- `docs/AGENTS/swiss-brain.md` — banned-terms authoritative list.
- `CLAUDE.md` — TOP-6 rules, §8 wiki schema, §9 0-trust protocol.

### Secondary (MEDIUM confidence)
- `apps/mobile/lib/services/coach/coach_chat_api_service.dart` — NOT READ in this session. Section 5.4 + 9.6 flag the dependency : Plan 04 Flutter wiring task reads it first.
- `tests/test_citation_gate/test_registry_contract.py` — referenced via grep, not read in full.

### Tertiary (LOW confidence — needs validation at exec time)
- The exact Maestro flow for tap-chip-then-modal — depends on `Key()` additions ; Plan 06 (Maestro flow) writes the YAML against the actual built sim screen.
- 21-commit dev backlog content — CONTEXT.md asserts safety ; Plan 09 (ship task) verifies via `git log dev ^staging` before pushing.

---

## Section 13 — Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|---|---|---|
| A1 | `CoachResponse.toolCalls` round-trips the full Pydantic dump (inputs_hash, computedAt) to Flutter | 5.4, 9.6 | If wrong, Plan 04 adds a `citation_chips` field to the schema — small detour, no blocker. |
| A2 | The `_RE_CITE_PLACEHOLDER` regex `[A-Za-z0-9_\-]+` accepts `tool_budget_snapshot` keys | 4.3 Option A | Verified mechanically — `tool_budget_snapshot` matches `[A-Za-z0-9_\-]+`. HIGH confidence ; minimal risk. |
| A3 | Adding 6 keys to `_REGISTRY` does not break the « subset of bundle allowlists » invariant if we update the test | 3.5, 9.7 | Plan 02 includes the test exemption + sibling invariant test. If we forget, registry-contract test fails — caught at G3 mechanically. |
| A4 | Intent-scoped grammar with always-on `tool_*` keys does not bloat the prompt past Sonnet's context budget | 4.4 | 6 keys × ~80 chars description = ~500 chars × 7 buckets = ~3.5 kB added. Current prompt is ~80 kB. < 5% increase. LOW risk. |
| A5 | Maestro can tap by `Key('coachCitationChip-<tool>')` on iOS sim | 9.5 | Verified by `tools/simulator/flows/maestro-perfect-set/*` precedent. HIGH confidence. |
| A6 | Sentry breadcrumbs at ~1 emission per coach turn × ~1000 turns/day × 7 days = ~7k breadcrumbs/week is under retention quota | 8.5 | Staging Sentry plan retention is 30 days, quota typically 100k events/month. < 30% of quota. LOW risk. |

If this table proves wrong on any line, the planner surfaces it in PLAN.md and Julien gates the change.

---

## Section 14 — Open Questions for `/gsd-plan-phase` to resolve

(Mirrors CONTEXT.md Section 8 open Qs with research-informed answers.)

1. **Q1 — One chip per tool call vs sub-hashes per slice ?** Plan default (a) — one chip per tool call. **Confidence : HIGH** (Karpathy #2 ; the modal already exposes the full JSON, so per-number granularity is recoverable on tap.)
2. **Q2 — Chip placement : inline vs footer ?** Plan default (b) — footer « Sources » row, alongside `CoachSourcesSection`. **Confidence : HIGH** (Section 5.2 design analysis ; matches CoachSourcesSection precedent).
3. **Q3 — Modal JSON viewer pretty-print vs syntax highlight ?** Plan default (a) — pretty-print only. **Confidence : HIGH** (Karpathy #2 ; no new dep).
4. **Q4 — Backward compat when flags OFF ?** Plan default (a) — no chip. **Confidence : HIGH** (Section 3.3 ; legacy path carries no inputs_hash).
5. **Q5 (NEW, from Section 4.3) — 1-segment vs 2-segment narrator grammar ?** Plan recommends Option A (1-segment). **DEVIATION FROM REQ TEXT** — surface in PLAN.md for Julien confirm before exec.
6. **Q6 (NEW, from Section 6.2) — Tool display names in ARB or in Dart const ?** Plan recommends ARB (option a). **DEVIATION FROM CONTEXT « 30 entries »** count — actual count is 66. Surface in PLAN.md.
7. **Q7 (NEW, from Section 9.2) — Keep flag_state badge in v1 modal ?** Plan recommends drop. Surface in PLAN.md.

---

## RESEARCH COMPLETE

**Phase :** wave-1b-citation-chips
**Confidence :** HIGH on backend pattern + ARB + close-out diff ; MEDIUM on mobile chip widget reuse + `CoachResponse.toolCalls` round-trip (Section 5.4 has a verify-first task in Plan 04).

### Key findings (5 bullets)
1. **`tool_call_id` source kind is already declared in `citation_registry.py:54`** — D-02 verified. Wave 1b ADDS 6 entries to `_REGISTRY` dict ; no schema change. (Section 3)
2. **Recommended narrator grammar = 1-segment `{{cite:tool_<name>}}`, NOT 2-segment `{{cite:tool_call_id:<inputs_hash>}}`** — Option A respects CONTEXT hard constraint #4 (no `citation_parser.py` regex changes). Functionally equivalent because per CONTEXT plan default (a), one chip per tool call is the visual default. **DEVIATION from req text WAVE1B-02** — surface in PLAN.md. (Section 4.3)
3. **Flutter chip widget = sibling `CoachCitationChipsSection`, NOT extension of `CoachSourcesSection`** — minimizes blast radius on the 30+ files reading `RagSource`. Reuses `ChatConsentChip._buildChip` design-system primitive per CONTEXT hard constraint #5. (Section 5.2)
4. **`flag_state` is NOT in the Pydantic response models** — only in Sentry breadcrumbs. The chip can derive flag_state from `inputs_hash` presence alone. **Recommend dropping the `flag_state` badge in v1** (Karpathy #2). Surface in PLAN.md. (Section 3.3, 9.2)
5. **ARB delta = 11 new keys × 6 locales = 66 entries, NOT 30** — Section 6 finds 5 frame keys + 6 tool-name keys (per strict CLAUDE.md TOP-5 i18n). **DEVIATION from CONTEXT.md line 41** — surface in PLAN.md. (Section 6.2)

### Confidence assessment

| Area | Level | Reason |
|---|---|---|
| Backend registry + grammar | HIGH | Every file:line cited. `citation_registry.py` + `citation_grammar.py` read in full. |
| Mobile chip + modal | MEDIUM | `CoachSourcesSection` + `ChatConsentChip` + `response_card_widget.dart` all read ; but `coach_chat_api_service.dart` was NOT read — A1 assumption needs Plan 04 verification. |
| ARB inventory | HIGH | 11 keys × 6 locales mechanical from existing precedent. Banned-terms + accent checked. |
| Sentry breadcrumb | HIGH | Existing helper at `coach_breadcrumbs.py:26-71` is exactly the right shape ; new helper is a copy with a different category prefix. |
| 5-gate close-out | HIGH | `wave_1a_close.sh` is 56 lines, the Wave 1b deltas are mechanical (4 new lint commands + 1 new file list). |

### Open questions (forwarded to planner)
- Q5 — 1-segment vs 2-segment narrator grammar (deviation from req text — needs Julien confirm).
- Q6 — Tool display names in ARB or Dart const (deviation from CONTEXT « 30 entries » — needs Julien confirm).
- Q7 — Drop flag_state badge in v1 (Karpathy #2 simplicity — recommended).

### Ready for planning
Plans 01-09 can now be authored. Suggested plan order :
- Plan 01 (Wave 0) — Create test files / scaffolding (registry test, breadcrumb test, widget test scaffolds).
- Plan 02 — Add 6 `tool_call_id` entries to `citation_registry.py` + update subset-invariant test + add sibling « every tool key has dispatcher branch » invariant test.
- Plan 03 — Extend `citation_grammar.py` (tool_call_id paragraph + example + intent mapping).
- Plan 04 — Verify `CoachResponse.toolCalls` round-trip (A1) ; extend / add schema if needed.
- Plan 05 — Create `CoachCitationChipsSection` widget + wire to `coach_message_bubble.dart`.
- Plan 06 — Modal + « Souviens-toi » CTA wiring.
- Plan 07 — ARB strings × 11 keys × 6 locales + flutter gen-l10n.
- Plan 08 — `emit_coach_citation_breadcrumb` helper + wire in `_run_narrator_with_gate`.
- Plan 09 — `tools/checks/wave_1b_close.sh` + Maestro flow draft + Phase SUMMARY + VERIFICATION-REPORT.html + dev→staging ship + Railway env flip + Claude autonomous G2.
