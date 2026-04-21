# Coach Context + Compliance Audit — 2026-04-17

**Auditor:** Explore subagent (agentId ab965d1ae6ce3aa7a)
**Scope:** system prompt construction, compliance guard, context injection, tool calling, regional voice.

## P0 findings

### P0-1 — Life event enum missing from system prompt
When a Swiss user writes "je me marie en juin" or "mon père est décédé", Claude has no formal event enum to trigger event-specific modes. The system prompt teaches lifecycle *phase* (demarrage/construction/retraite) but not *event type* (marriage/death/inheritance/unemployment). Claude must infer from raw text, missing Swiss-specific contexts like AVS couple splitting rules, succession tax tiers, EPL blockers post-buyback.

- Missing LIFE_EVENTS block: `services/backend/app/services/coach/claude_coach_service.py:319-468`
- Client does not inject event type: `apps/mobile/lib/services/coach/context_injector_service.dart:128+`

### P0-2 — Tool-calls casing mismatch ✅ FIXED 2026-04-17 (commit c2717cdb)
Backend emitted `tool_calls` snake_case, Flutter read `toolCalls` camelCase → all tool_use silently dropped. Fixed with `response_model_by_alias=True` on the `/chat` endpoint + strict camelCase test guards.

### P0-3 — Banned term bypass via conjugations
`ComplianceGuard` at `services/backend/app/services/compliance/compliance_guard.py:43-102` covers singular/feminine/plural (garanti/garantie/garantis) but misses gerunds and participials: "en garantissant le rendement", "c'est gé!" (slang), "hyper-optimal". Vision reformulations in `vision_guard.py:154` are not re-validated against `ComplianceGuard` — Haiku can accidentally include banned terms it was instructed to block.

## Coverage matrix (18 life events × coach awareness)

All 18 events have English slug enums in mobile code. Only ~6 have dedicated prompts/guidance paths in the backend system prompt. Life events:

| Event | Mobile enum | Backend prompt | Fallback |
|-------|-------------|----------------|----------|
| marriage | ✅ | ⚠️ | ⚠️ |
| divorce | ✅ | ⚠️ | ⚠️ |
| birth | ✅ | ❌ | ⚠️ |
| concubinage | ✅ | ❌ | ⚠️ |
| deathOfRelative | ✅ | ❌ | ⚠️ |
| firstJob | ✅ | ✅ | ✅ |
| newJob | ✅ | ⚠️ | ⚠️ |
| selfEmployment | ✅ | ❌ | ❌ |
| jobLoss | ✅ | ⚠️ | ⚠️ |
| retirement | ✅ | ✅ | ✅ |
| housingPurchase | ✅ | ✅ | ✅ |
| housingSale | ✅ | ❌ | ❌ |
| inheritance | ✅ | ❌ | ❌ |
| donation | ✅ | ❌ | ❌ |
| disability | ✅ | ❌ | ❌ |
| cantonMove | ✅ | ❌ | ❌ |
| countryMove | ✅ | ❌ | ❌ |
| debtCrisis | ✅ | ⚠️ | ⚠️ |

**Conclusion:** only 3/18 events (firstJob, retirement, housingPurchase) have solid end-to-end coverage. Every other event falls back to Claude improvising from generic prompt.

## Tool-calling inventory

- 28 tools declared in `coach_tools.py`
- Only 3 mentioned in system prompt (save_fact, route_to_screen, ask_user_input)
- Agent loop + compliance guard in place
- Critical casing bug fixed (above)

## Regional voice

- `RegionalVoiceService` covers 26 cantons (3 anchors VS/ZH/TI + 23 secondaries routed).
- Injected into system prompt via `context_injector_service.dart`.
- Limitation: tone/flavor only, NOT cantonal-specific law (tax brackets, marriage regimes).

## Top 10 silent failure modes (abridged)

1. User says "je vais avoir un bébé" → coach doesn't mention maternity leave LPP protection.
2. User says "je déménage à Zoug" → no cantonal tax delta surfaced.
3. User says "j'hérite de 300'000 CHF" → no succession tax calc, no 3a anticipation window.
4. US green-card holder asks about 3a → no FATCA/PFIC warning.
5. User in debt crisis → Safe Mode not auto-triggered (see persona audit).
6. User says "je devient indépendant" → no 3a 36'288 CHF cap mentioned.
7. Death of spouse → no survivor AVS / LPP widow rate mention.
8. Canton move → impacts EPL tax timing, not surfaced.
9. Divorce → pension splitting (LPP art. 22) not mentioned.
10. Return from abroad → rachat window + 5-year block not explained.

## Remediation priorities

1. Add LIFE_EVENTS block to system prompt (structured enum with 2-line guidance per event).
2. Extend `ComplianceGuard.BANNED_TERMS` regex to catch gerunds/participials + re-validate vision reformulations.
3. Expand the tool-mention list in the system prompt to cover all 28 tools.
4. Add cantonal-law context injection (beyond voice flavor) for tax brackets + marriage regimes.
