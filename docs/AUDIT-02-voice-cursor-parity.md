# AUDIT-02 — Voice Cursor Parity Audit

**Phase:** 02-p0b-contracts-and-audits / Plan 02-05
**Status:** committed
**Date:** 2026-04-07
**Scope:** Every LLM prompt site and every rule-fed voice surface in `services/backend/app/` + `apps/mobile/lib/`. Read-only audit. No source code modified.

## Gate

> **Phase 5 (VOICE_CURSOR_SPEC v0.5 + full L1.6 spec) and Phase 9 (MintAlertObject) BOTH read this doc as input.** It enumerates which surfaces already accept a `cash_level` / cursor parameter vs which hardcode tone. The contract import gap (column "needs contract import (Y/N)") is the migration checklist for Plan 02-01 (`voice_cursor_contract.g.dart` consumers).

## Methodology

Grep patterns executed:

```
build_system_prompt | system_prompt | build_prompt | render_prompt | format_prompt
prompt_registry | fallback_template
INTENSITY_MAP | cash_level | cashLevel | intensity
tone | voice | cursor | N1 | N2 | N3 | N4 | N5 | fragile | sensitive
```

For each hit, determined:

- **current tone source**: `cursor parameter` (already accepts a 1-5 / N1-N5 input), `hardcoded` (tone baked into the prompt string), `regional only` (tone modulated by canton, not by cursor), `none` (no tonal control surface), `frozen string` (template constant).
- **needs contract import (Y/N)**: does this site need to import `voice_cursor_contract.g.dart` (Dart) or `voice_cursor.py` (Pydantic) once Plan 02-01 lands?

## Backend prompt sites

| # | file:line | surface | current tone source | needs contract import |
|---|---|---|---|---|
| 1 | `services/backend/app/services/coach/claude_coach_service.py:357-402` | `build_system_prompt(ctx, language, cash_level)` — main coach system prompt | **cursor parameter** (`cash_level: int = 3`, clamped 1-5, mapped via `INTENSITY_MAP`) | **Y** — must replace `int` with the generated `Literal['N1','N2','N3','N4','N5']` and replace `INTENSITY_MAP` with the contract matrix lookup. |
| 2 | `services/backend/app/services/coach/claude_coach_service.py:49` | `INTENSITY_MAP` constant (5 entries, free-form French strings) | hardcoded — INTENSITY_MAP IS the cursor mapping today, but it's a local dict not a contract | **Y** — DELETE after migration; replaced by `voice_cursor.matrix` lookup. Until then it's the de facto cursor source. |
| 3 | `services/backend/app/services/coach/claude_coach_service.py:393-397` | Regional voice injection (`REGIONAL_MAP` per canton) | regional only | N — orthogonal to cursor; canton stays its own axis per CONTEXT.md §D-09. |
| 4 | `services/backend/app/services/coach/claude_coach_service.py:_FOUR_LAYER_ENGINE` | 4-layer insight engine block (always-on) | hardcoded | N — doctrine, not register. |
| 5 | `services/backend/app/services/coach/claude_coach_service.py:_BIOGRAPHY_AWARENESS` | Biography conditional language block | hardcoded | N — doctrine. |
| 6 | `services/backend/app/services/coach/claude_coach_service.py:_FIRST_JOB_CONTEXT` | First-job intent context | hardcoded | N — domain context, no register. |
| 7 | `services/backend/app/services/coach/fallback_templates.py` | `BASE_SYSTEM_PROMPT` (frozen template) + 5 derived templates | frozen string | **Y** — fallback templates ship without LLM but still render Mint's voice; once contract lands, the 5 derived templates need a level annotation each (likely N2/N3). |
| 8 | `services/backend/app/services/coach/coach_narrative_service.py` | Narrative builder (templated openers / fillers) | hardcoded | **Y** — narrative openers carry voice. Phase 5 must annotate each template with its target N level. |
| 9 | `services/backend/app/services/coach/coach_models.py` | Coach data models (no prompt strings, just types) | none | N — types only. |
| 10 | `services/backend/app/services/coach/prompt_registry.py:23-147` | `PromptRegistry.BASE_SYSTEM_PROMPT` + 5 derived `f"""{BASE_SYSTEM_PROMPT}\n..."""` returns | frozen string | **Y** — every derived prompt needs a level annotation. Today they all inherit BASE tone. |
| 11 | `services/backend/app/services/coach/coach_tools.py` | Tool definitions (parameter schemas) | none | N — schemas, not prompts. |
| 12 | `services/backend/app/services/coach/coach_context_builder.py` | Builds the `CoachContext` injected into the prompt | none | Y indirectly — must surface `voice_cursor_preference` from Profile (CONTRACT-05) so the prompt builder can read it. |
| 13 | `services/backend/app/services/coach/structured_reasoning.py:119` | `ReasoningOutput.as_system_prompt_block()` | frozen string | N — structural reasoning text, doctrine-bound. |
| 14 | `services/backend/app/services/coach/structured_reasoning.py:537` | `system_prompt += "\\n\\n" + output.as_system_prompt_block()` | frozen string | N — assembly, no register. |
| 15 | `services/backend/app/api/v1/endpoints/coach_chat.py:51` | imports `build_system_prompt` | (call site) | (depends on #1) |
| 16 | `services/backend/app/api/v1/endpoints/coach_chat.py:370-381` | `_build_system_prompt_with_memory(... language, cash_level)` | **cursor parameter** | **Y** — `cash_level: int` → `Literal['N1'..'N5']`. |
| 17 | `services/backend/app/api/v1/endpoints/coach_chat.py:852-914` | Streaming chat handler passes `system_prompt=` to LLM client | (call site) | N |
| 18 | `services/backend/app/api/v1/endpoints/coach_chat.py:1140-1238` | Final assembly: `reasoning_block` + `system_prompt` + `cash_level=body.cash_level` | **cursor parameter** | **Y** |
| 19 | `services/backend/app/schemas/coach_chat.py:104` | `cash_level: int = Field(ge=1, le=5, description="Voice intensity 1-5 (1=factual, 5=brut).")` (request) | **cursor parameter** | **Y** — replace with `Literal` generated from contract. |
| 20 | `services/backend/app/schemas/coach_chat.py:144` | `cash_level: int = Field(default=3, ge=1, le=5)` (response echo) | **cursor parameter** | **Y** |
| 21 | `services/backend/app/schemas/coach_chat.py:154` | `system_prompt_used: bool` flag | none | N |
| 22 | `services/backend/app/schemas/rag.py:75` | `cash_level: int = Field(...)` on RAG request | **cursor parameter** | **Y** |
| 23 | `services/backend/app/api/v1/endpoints/rag.py:35` | imports `INTENSITY_MAP` | (call site) | **Y** — drop import in favour of contract lookup. |
| 24 | `services/backend/app/api/v1/endpoints/rag.py:153-176` | `clamped_level = max(1, min(5, body.cash_level))`; `intensity_instruction = INTENSITY_MAP.get(...)`; appended to `enriched_prompt` | **cursor parameter** but with **local clamping logic** | **Y** — clamping moves into the contract resolver; this site loses ~10 LOC. |
| 25 | `services/backend/app/api/v1/endpoints/rag.py:161` | `guardrails.build_system_prompt(...)` | (call site) | N |
| 26 | `services/backend/app/services/rag/orchestrator.py:47-118` | `system_prompt: Optional[str] = None`; falls back to `guardrails.build_system_prompt(...)` | none (delegates) | N |
| 27 | `services/backend/app/services/rag/orchestrator.py:203-251` | `_vision_system_prompt(language)` for vision/OCR | hardcoded | N — extraction prompt, not user-facing voice. |
| 28 | `services/backend/app/services/rag/guardrails.py` | `build_system_prompt(...)` — compliance + RAG guardrails | hardcoded | N — narrator wall exemption surface (compliance), per CONTEXT.md §D-02. |
| 29 | `services/backend/app/services/rag/llm_client.py:59-214` | `_call_anthropic / _call_openai / _call_mistral` — all accept `system_prompt: str` | (transport) | N |
| 30 | `services/backend/app/services/document_vision_service.py:358-375` | `_build_extraction_prompt(doc_type, canton, language_hint)` | hardcoded | N — extraction prompt, not user-facing. |
| 31 | `services/backend/app/api/v1/endpoints/documents.py:292-308` | `_PREMIER_ECLAIRAGE_SYSTEM_PROMPT.format(...)` | frozen string | **Y** — premier éclairage IS user-facing voice. Phase 5 must annotate this template's target level (likely N3). |
| 32 | `services/backend/app/services/anomaly_detection_service.py:127-138` | `cash_level: int = 3, # noqa — reserved for literacy adaptation` | **cursor parameter (placeholder)** | **Y** — already accepts the parameter but doesn't use it. Migration wires it through. |

**Backend subtotal: 32 hits.** Of these, **13 sites need contract import** (rows 1, 2, 7, 8, 10, 12, 16, 18, 19, 20, 22, 23-24, 31, 32). The cursor parameter is **already wired end-to-end through the chat path** (request → endpoint → builder → INTENSITY_MAP), but the type is `int`, the mapping is a local dict, and the fallback / narrative / premier-éclairage / RAG-guardrails sites do not yet honor it.

## Frontend (Dart) prompt + voice sites

| # | file:line | surface | current tone source | needs contract import |
|---|---|---|---|---|
| 33 | `apps/mobile/lib/services/coach/prompt_registry.dart:90` | `baseSystemPrompt` constant | frozen string | **Y** — Dart-side prompts (used by local fallback) need level annotations. |
| 34 | `apps/mobile/lib/services/coach/prompt_registry.dart:119` | `dashboardGreeting(ctx)` | hardcoded | **Y** |
| 35 | `apps/mobile/lib/services/coach/prompt_registry.dart:136` | `scoreSummary(ctx)` | hardcoded | **Y** |
| 36 | `apps/mobile/lib/services/coach/prompt_registry.dart:153` | `dailyTip(ctx)` | hardcoded | **Y** |
| 37 | `apps/mobile/lib/services/coach/prompt_registry.dart:168` | `premierEclairageNarrative(ctx)` | hardcoded | **Y** — same surface as backend row 31; must agree on N level. |
| 38 | `apps/mobile/lib/services/coach/prompt_registry.dart:183` | `scenarioNarration(ctx)` | hardcoded | **Y** |
| 39 | `apps/mobile/lib/services/coach/prompt_registry.dart:201` | `enrichmentGuide(ctx, blockType)` | hardcoded | **Y** |
| 40 | `apps/mobile/lib/services/coach/prompt_registry.dart:284` | `chatSystemPrompt(ctx)` | hardcoded | **Y** — this is the main S51 chat prompt. |
| 41 | `apps/mobile/lib/services/coach/prompt_registry.dart:336` | `chatSafeModePrompt(ctx)` | hardcoded | **Y** — safe mode hard-caps at N3 per CONTEXT.md `caps.fragileModeCapLevel`; contract resolver enforces this, not the prompt itself. |
| 42 | `apps/mobile/lib/services/coach/prompt_registry.dart:369` | `chatFollowUpPrompt(ctx)` | hardcoded | **Y** |
| 43 | `apps/mobile/lib/services/coach/prompt_registry.dart:395` | `chatSimulationPrompt(ctx)` | hardcoded | **Y** |
| 44 | `apps/mobile/lib/services/coach/prompt_registry.dart:433` | `chatSeniorPrompt(ctx)` | hardcoded | **Y** — currently keyed off "age 60+" which is an anti-pattern per CLAUDE.md §1 ("ALL Swiss residents 18-99, never age-segmented"). Phase 5 should re-key this off cursor preference, not age. **Flag for cleanup.** |
| 45 | `apps/mobile/lib/services/coach/prompt_registry.dart:493` | `getPrompt(componentType, ctx, ...)` dispatcher | (dispatcher) | **Y** — receives a level once Phase 5 lands. |
| 46 | `apps/mobile/lib/services/coach/coach_orchestrator.dart` | Orchestrator selects which prompt to fire | (dispatcher) | **Y** indirectly — must read `coachingPreference.cashLevel` and forward. |
| 47 | `apps/mobile/lib/services/coach/coach_narrative_service.dart` | Narrative builder | hardcoded | **Y** |
| 48 | `apps/mobile/lib/services/coach/local_fallback_service.dart:9` | "Every response is compliant (no banned terms, educational tone)" — local fallback path | hardcoded | **Y** — fallback path also carries voice; must annotate. |
| 49 | `apps/mobile/lib/services/coach/coach_cache_service.dart` | Cache key currently has no `cashLevel` dimension | none | **Y** — cache key MUST include the resolved N level once contract lands, otherwise cached responses leak across cursor settings. **Flag as silent correctness bug.** |
| 50 | `apps/mobile/lib/services/coach/context_injector_service.dart` | Injects regional + lifecycle into the prompt | regional only | N — orthogonal axis. |
| 51 | `apps/mobile/lib/services/coach/voice_chat_integration.dart:10-156` | Voice (audio) integration through ComplianceGuard | none | N — TTS path. The level affects copy upstream, not this transport. |
| 52 | `apps/mobile/lib/services/coach/voice_service.dart` | Pluggable STT/TTS backends | none | N |
| 53 | `apps/mobile/lib/services/coach/conversation_memory_service.dart:10-189` | "summary text for system prompt injection" | hardcoded | N — summary structure, not voice register. |
| 54 | `apps/mobile/lib/models/coaching_preference.dart:5-73` | `CoachingPreference { intensity, cashLevel, triggerEngagement }` — user-facing setting | **cursor parameter (Dart-side)** | **Y** — `int cashLevel` → `VoiceCursorLevel` enum from generated contract. Default `2` (Clair) — Phase 5 must verify this matches the contract's "default level when no preference" cell. |
| 55 | `apps/mobile/lib/services/api_service.dart` (cash_level send) | Sends `cash_level` in API requests | (transport) | **Y** — payload field becomes the contract enum string. |
| 56 | `apps/mobile/lib/screens/coach/coach_chat_screen.dart` (intensity selector) | Slider 1-5 | **cursor parameter** | **Y** — UI must read enum, not int. |
| 57 | `apps/mobile/lib/services/cap_engine.dart` (voice refs) | Cap engine reads voice settings to gate proactive nudges | regional only / hardcoded | N — uses `intensity` for cooldown, not for register. |
| 58 | `apps/mobile/lib/services/coach/proactive_trigger_service.dart` | Cooldown depends on `intensity` (1→7d, 5→0d) | **cursor parameter** but `intensity ≠ cashLevel` | partial — these are TWO orthogonal sliders today (`intensity` = proactivity, `cashLevel` = voice). Phase 5 must decide if they merge or stay distinct. **Flag for product decision.** |
| 59 | `apps/mobile/lib/services/coach/precomputed_insights_service.dart` | Pre-renders insights at multiple confidence tiers | none | **Y** — must also pre-render at multiple cursor levels, OR cache key includes level. |
| 60 | `apps/mobile/lib/widgets/coach/coach_message_bubble.dart` | Renders coach copy (no tone logic) | none | N — pure renderer. |
| 61 | `apps/mobile/lib/widgets/coach/response_card_widget.dart` | Renders structured response cards | none | N — pure renderer. |
| 62 | `apps/mobile/l10n/app_*.arb` (intensityTranquille, intensityClair, intensityDirect, intensityCash, intensityBrut + cashModeTitle + intensityConfirmation1..5 + intensityAdjustedUp/Down) | 5 level labels + 5 confirmation strings + 2 adjustment toasts × 6 languages | **cursor parameter (labels)** | **Y** — labels must be keyed off the contract enum names (`N1..N5`), and per CLAUDE.md the user-facing word stays "intensité" / "Ton" — never "curseur". The 5 current labels (Tranquille / Clair / Direct / Cash / Brut) must be cross-checked against Phase 5's 5 level definitions for tonal match. |

**Frontend subtotal: 30 hits.** Of these, **23 need contract import** (rows 33-45, 47-49, 54-56, 58-59, 62 — and #58 conditionally).

## Combined Totals

- **Total surfaces audited:** 62 (32 backend + 30 frontend) — within the 30-50 expected range; the spread reflects the existing prompt-registry depth.
- **Sites already accepting a cursor parameter:** 13 (rows 1-2, 16, 18-20, 22-24, 32, 54-56, 58 — partial)
- **Sites hardcoding tone:** 27 (every `prompt_registry.dart` template + the Python fallback templates + premier-éclairage backend template + narrative builders)
- **Sites needing contract import after Plan 02-01:** **36** (Y rows above)
- **Sites NOT needing contract import:** 26 (compliance/guardrails, transport, vision-extraction, regional-only, pure renderers, structured reasoning blocks)

## Parity Gaps (the things that make this audit useful)

### Gap 1 — Frontend prompt registry has zero cursor wiring
13 of 14 prompts in `apps/mobile/lib/services/coach/prompt_registry.dart` are hardcoded tone. Backend has the cursor wired through `cash_level` int → `INTENSITY_MAP`; the Dart fallback path (used when LLM is unavailable or BYOK is off) does not. **Effect today:** users on local fallback get a single tone regardless of their cursor setting. This is a silent UX divergence, not a functional bug.

### Gap 2 — `INTENSITY_MAP` is a 5-entry French-language dict, not a contract
`services/backend/app/services/coach/claude_coach_service.py:49` defines `INTENSITY_MAP` inline with hand-written French strings. Plan 02-01 replaces this with `voice_cursor.matrix` lookup. Until then, `INTENSITY_MAP` IS the de facto cursor source — any drift between it and the eventual VOICE_CURSOR_SPEC v0.5 reference phrases will surface as a Phase 11 IRR failure.

### Gap 3 — Two orthogonal cursors (`intensity` vs `cashLevel`)
`CoachingPreference` has both `intensity` (proactivity, cooldown gate, default 3) and `cashLevel` (voice register, default 2). They are user-tunable independently. Phase 5 must confirm whether they stay separate or collapse. Current code treats them as separate; the contract's `voice_cursor` is single-axis, so by default they STAY separate and only `cashLevel` maps to the contract.

### Gap 4 — Cache key bug (silent correctness)
`apps/mobile/lib/services/coach/coach_cache_service.dart` does not include the resolved N level in the cache key. After contract migration, two users with different cursor settings could receive the same cached LLM response. **Must be fixed in Plan 02-03 or earlier — flagged here, not fixed.**

### Gap 5 — Age-keyed `chatSeniorPrompt`
`prompt_registry.dart:433` selects this prompt for "users aged 60+". This violates CLAUDE.md §1 and the anti-shame doctrine. Phase 5 should re-key it off the cursor preference (e.g. N1/N2 prefer this register) with no age input. **Flag for cleanup, not fixed here.**

### Gap 6 — Premier éclairage tone divergence (backend ↔ frontend)
Backend `documents.py:292` has `_PREMIER_ECLAIRAGE_SYSTEM_PROMPT` and frontend `prompt_registry.dart:168` has `premierEclairageNarrative(ctx)`. These render the SAME user-facing surface but are two independent templates. They must converge on the same N level annotation in Phase 5, otherwise the same user gets two different tones depending on whether their premier éclairage was generated via OCR (backend) or local synthesis (frontend).

### Gap 7 — Narrator wall exemptions are partly enforced
CONTEXT.md `narratorWallExemptions` lists `settings, errorToasts, networkFailures, legalDisclaimers, onboardingSystemText, compliance, consentDialogs, permissionPrompts`. Audit confirms that:
- `guardrails.build_system_prompt` (compliance) — exempt ✓
- `_build_extraction_prompt` (vision/OCR) — exempt by category (system, not user-facing) ✓
- error toasts and consent dialogs — these are ARB strings rendered by widgets directly, never go through a prompt builder, so they're trivially exempt ✓
- legalDisclaimers — same, ARB only ✓

No production wiring exists today to ENFORCE the wall (i.e. assert that exempt surfaces never receive a cursor parameter). Phase 9 MintAlertObject is the first surface where the wall becomes a runtime check.

## Open Questions (escalated to orchestrator)

1. **Two-cursor product decision** (Gap 3) — does `intensity` collapse into `cashLevel`? If yes, Plan 02-03 needs an extra field deletion. If no, the contract stays single-axis and `intensity` becomes a separate Profile field outside the cursor contract.
2. **Frontend prompt registry retirement** — are the Dart-side templates kept (local fallback path) or deleted in favour of always-LLM with degraded mode? Phase 5 input.
3. **`chatSeniorPrompt` cleanup priority** — Phase 5 fix or earlier? It violates CLAUDE.md §1 today; not new debt but worth surfacing.
