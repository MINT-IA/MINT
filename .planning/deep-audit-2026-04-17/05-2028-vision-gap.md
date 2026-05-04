# 2028 AI-Embedded Vision Gap — 2026-04-17

**Auditor:** Explore subagent (agentId af42cbe2c7dd64189)

## What's IMPLEMENTED today

- **Proactive triggers**: `ProactiveTriggerService` with 7 triggers (lifecycle change, weekly recap, goal milestone, seasonal, inactivity, confidence improvement, new CAP) — `apps/mobile/lib/services/coach/proactive_trigger_service.dart`
- **Voice scaffolding**: `VoiceService`, `VoiceInputButton`, `VoiceOutputButton`, `VoiceStateMachine` — client-side UI. Backend STT/TTS is STUB.
- **OCR**: document parser for AVS, LPP, tax declaration. No live camera, no vision API yet.
- **Memory**: `ConversationMemoryService` + `CoachMemoryService` + `MemoryReferenceService`. Tag-based, NOT semantic (no vector retrieval at runtime).
- **Forecasting**: `ForecasterService` (3 scenarios to retirement), `MonteCarloService` (uncertainty bands), `WithdrawalSequencingService`.
- **Cantonal**: `CantonalBenchmarkService` (26 cantons, static snapshots — no change detection).

## What's PARTIAL

- **pgvector hybrid search**: backend code ready (`HybridSearchService`), NOT activated in production. ChromaDB keyword-only still primary.
- **Ambient background**: proactive triggers fire on app open only, no daemon.
- **Autonomous agent**: `AutonomousAgentService` + `FormPrefillService` + `LetterGenerationService` exist but NOT wired to coach chat.
- **Voice AI**: full UI exists, backend `PlatformVoiceBackend` returns unavailable.
- **Weekly recap**: falls back to templates when BYOK off.
- **Expert tier**: service layer done, no real advisor marketplace or payment.

## What's MISSING (MINT's own vision docs vs. code)

From `visions/MINT_Autoresearch_Agents.md` — 10 veille agents promised, **NONE shipped**:
Swiss regulation watch, competitor intelligence, pension rates tracker, tax optimization lab, AI coaching research, content generator, UX pattern hunter, financial literacy lab, compliance sentinel, market timing radar.

From `docs/BLUEPRINT_COACH_AI_LAYER.md`:
- T1 CoachNarrativeService: no LLM enrichment path (static templates only).
- T2 Tips Enrichment LLM: not implemented.
- T4 Notifications Proactive: no ambient loop.
- T5 Milestones Celebrated: no confetti animation.
- T6 Annual Refresh Screen: refresh trigger stub.

From `docs/ROADMAP_V2.md`:
- 13e rente AVS (S53): marked shipped, not in `AVSCalculator`.
- pgvector in production (S67): infra not activated.
- Agent autonome wired to coach chat (S68): orchestration gap.

## What's VAPORWARE

- Autoresearch dev agents orchestrator: no `autoresearch/` directory.
- Institutional APIs (S69+): no wiring.
- B2B white-label (S71): `WhiteLabelConfig` only; no deployment.
- Open Finance bLink (S73-74): no API calls.

## Top 5 highest-leverage additions

1. **Regulation Watcher** (M, 2-3 weeks) — nightly scan admin.ch / finma.ch / BSV → `KnowledgeUpdatePipeline` → coach prompt. Competitive moat.
2. **Vector Memory activation** (M, 1-2 weeks) — flip pgvector on + wire `HybridSearchService` as primary retriever in `orchestrator.py`. Unlocks semantic cross-session recall.
3. **6-Month Cashflow Forecaster** (M, 2-3 weeks) — extend `ForecasterService` near-term + add `CashflowForecaster.project6M()` + nudge on shortfall.
4. **Autonomous Agent wiring to coach** (L, 3-4 weeks) — connect `AutonomousAgentService` behind a `route_to_screen(intent=prefill_form)` tool call.
5. **Real STT/TTS** (L, 4-5 weeks) — Deepgram + ElevenLabs with canton-voice selection.

## Architecture risks at scale

1. **Per-request `AsyncAnthropic`**: no pooling. ~200ms init overhead/call. Partly mitigated 2026-04-17 (transient-close fix in `LLMRouter`), full fix = singleton client.
2. **No vector DB durability**: memory lost on uninstall. Need S3 backup + GDPR export.
3. **Single-process coach**: heavy calcs block chat latency. Move Monte Carlo/forecasting to Celery.
4. **No background ambient worker**: users miss alerts if offline. Need scheduler + APNs/FCM.
5. **Compliance drift**: `ResponseQualityMonitor` exists but not wired to prod logs. Sample + human review needed.

## Priority sequence for 2028 vision

**Phase 1 (Q2 2026, ship before 2028 prep)**: vector memory activation, regulation watcher, response-quality monitoring.
**Phase 2 (H2 2026)**: cashflow forecaster, autonomous-agent wiring, pgvector migration from snapshot to live.
**Phase 3 (2027)**: real voice stack, ambient worker, multi-agent architecture, B2B/white-label ops.
