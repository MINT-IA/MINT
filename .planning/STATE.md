---
gsd_state_version: 1.0
milestone: v2.7
milestone_name: Coach Stabilisation + Document Digestion
status: Phase 28-04 shipped — 4 render_mode chat bubbles + ExtractionReviewSheet (snap 0.3/0.6/0.95) + DocumentResultView + DocumentStreamResultScreen + 19 i18n keys × 6 langs + 28/28 phase-28 mobile tests green. Default scan path still routes to legacy ExtractionReviewScreen until DOCUMENTS_V2_ENABLED rollout.
stopped_at: Completed 29-02-PLAN.md
last_updated: "2026-04-14T22:44:01.080Z"
last_activity: 2026-04-14
progress:
  total_phases: 18
  completed_phases: 2
  total_plans: 11
  completed_plans: 7
  percent: 64
---

# GSD State: MINT v2.7 — Coach Stabilisation + Document Digestion

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-14)

**Core value:** Le coach fonctionne bout en bout ET MINT digère n'importe quel document (photo/scan/screenshot/PDF) via contrat canonique interne — jamais "Analyse indisponible".
**Current focus:** Phase 27 — Stabilisation Critique (pending plan)

## Architecture Decisions (pre-phase)

- Audit externe challengé par 4 experts (pipeline/UX/SRE/DPO). Architecture astronaute rejetée.
- Contrat canonique INTERNE (pas endpoint public /documents/understand).
- 1 appel Vision fusionné, pas 2.
- 4 render_mode client opaque (`confirm/ask/narrative/reject`).
- VisionKit + cunning_document_scanner = prétraitement client.
- ExtractionReviewScreen réduit, pas supprimé.

## Current Position

Phase: 28 (plans complete pending device gate)
Plan: 28-04 complete — Phase 28 plans done (4/4); blocking checkpoint:human-verify pending creator iPhone walkthrough.
Status: Phase 28-04 shipped — 4 render_mode chat bubbles + ExtractionReviewSheet (snap 0.3/0.6/0.95) + DocumentResultView + DocumentStreamResultScreen + 19 i18n keys × 6 langs + 28/28 phase-28 mobile tests green. Default scan path still routes to legacy ExtractionReviewScreen until DOCUMENTS_V2_ENABLED rollout.
Last activity: 2026-04-14

Progress: [██████████] 100% (1/4 phases, 5/5 plans tracked) — Phase 28 awaiting device-gate sign-off.

## Performance Metrics

**Velocity:**

- Total plans completed: 24 (from v2.4)
- Average duration: ~6 min/plan
- Total execution time: ~0.5 hours

**By Phase (v2.4):**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 9 — Les tuyaux | 2 | 6min | 3min |
| 10 — Les connexions | 1 | 6min | 6min |
| 11 — La navigation | 2 | 16min | 8min |
| Phase 13 P01 | 9min | 1 tasks | 5 files |
| Phase 13 P02 | 9min | 2 tasks | 18 files |
| Phase 13 P03 | 8min | 1 tasks | 4 files |
| Phase 13 P04 | 2min | 2 tasks | 3 files |
| 13 | 4 | - | - |
| Phase 14 P01 | 7min | 2 tasks | 6 files |
| Phase 14-commitment-devices P02 | 11min | 2 tasks | 19 files |
| Phase 14-commitment-devices P03 | 6min | 2 tasks | 17 files |
| 14 | 3 | - | - |
| Phase 15-coach-intelligence P01 | 10min | 2 tasks | 7 files |
| Phase 15-coach-intelligence P02 | 4min | 1 tasks | 1 files |
| 15 | 2 | - | - |
| Phase 16-couple-mode-dissymetrique P01 | 4min | 2 tasks | 4 files |
| Phase 16 P02 | 7min | 2 tasks | 7 files |
| 16 | 2 | - | - |
| Phase 17 P01 | 6min | 2 tasks | 15 files |
| 17 | 1 | - | - |
| Phase 18 P01 | 5min | 2 tasks | 19 files |
| 18 | 1 | - | - |
| Phase 21 P01 | 7min | 2 tasks | 4 files |
| 21 | 1 | - | - |
| Phase 22 P01 | 6min | 2 tasks | 17 files |
| 22 | 1 | - | - |
| Phase 23 P01 | 7min | 2 tasks | 4 files |
| 23 | 1 | - | - |
| Phase 24 P01 | 3min | 3 tasks | 1 files |
| 24 | 1 | - | - |
| Phase 25 P01 | 8min | 3 tasks | 4 files |
| 25 | 1 | - | - |
| Phase 26 P01 | 4min | 3 tasks | 2 files |
| 26 | 1 | - | - |
| Phase 28 P03 | 22 min | 3 tasks | 17 files |
| Phase 28-pipeline-document P02 | 18 min | 2 tasks | 8 files |
| Phase 28-pipeline-document P04 | 28 min | 3 tasks | 22 files |
| Phase 29-compliance-privacy P01 | 45 | 2 tasks | 20 files |
| Phase 29 P02 | 60 | 2 tasks | 21 files |

## Accumulated Context

### Decisions

- Sequential execution non-negotiable (parallel agents caused v2.4 damage)
- Device gate is the only real validation (9256 tests green proved nothing)
- Premium/monetisation deferred to v2.6 (zero external users yet)
- Anonymous intent screen already built (quick-260412-kue) — ANON-02 partially done
- Facade-without-wiring is the #1 risk — every phase must be E2E testable
- [Phase 13]: Discovery prompt written from scratch (not derived from auth prompt) to prevent info disclosure
- [Phase 13]: Separate _NoRagOrchestrator in anonymous_chat.py — full isolation from authenticated path
- [Phase 13]: Anonymous chat route outside ShellRoute for clean pre-auth UX
- [Phase 13]: Auth gate as conversational bottom sheet (coach avatar + message, not system interrupt)
- [Phase 13]: Atomic SharedPreferences migration: write new keys, verify, then delete old keys
- [Phase 13]: Eager persistence after each coach response instead of fixing callback chain — more robust against navigation changes
- [Phase 14]: Ack-only tool handlers for record_commitment and save_pre_mortem (persistence deferred to Plan 02 dedicated endpoint)
- [Phase 14]: show_commitment_card as Flutter-bound tool (not internal) for editable commitment card rendering
- [Phase 14]: DB-sourced memory block always includes commitment data for natural LLM reference
- [Phase 14-commitment-devices]: Notification scheduling pulled into Task 1 to avoid compile error in widget_renderer
- [Phase 14-commitment-devices]: Dual rate limiting for fresh-start: server-side primary, client SharedPreferences as UX backup
- [Phase 14-commitment-devices]: Fresh-start notification IDs in 6000+ range, job anniversary uses July 1 midpoint
- [Phase 15]: Immediate DB persistence for provenance/earmark tools (not ack-only) — data needed in next conversation
- [Phase 15]: user_id and db threaded through _run_agent_loop to _execute_internal_tool for DB write access
- [Phase 15-coach-intelligence]: Used real SQLite in-memory DB (not mocks) for integration tests to prove actual ORM round-trip
- [Phase 16]: Ack-only handlers with zero DB/user_id access — privacy guarantee enforced by source inspection tests
- [Phase 16]: System prompt asks one question at a time in priority order (salary > age > LPP > 3a > canton)
- [Phase 16]: Partner aggregate injected in coach_chat_api_service.chat() — single injection point covers all paths
- [Phase 16]: degradeForPartnerEstimate as static method on ConfidenceScorer — minimal surface, callers opt-in
- [Phase 17]: Auth-aware GoRoute builder using context.watch<AuthProvider>() for reactive routing
- [Phase 17]: Tension card i18n keys stored as string IDs in model, resolved at widget level via S.of(context)
- [Phase 18]: TimelineProvider extends TensionCardProvider (IS-A) so existing tension card consumers work via type hierarchy
- [Phase 20]: Conversation history as structured messages array (not concatenated text) for proper multi-turn Claude API; history only on first agent loop iteration
- [Phase 21]: Dedup by user_id+topic: upsert pattern for save_insight prevents unbounded DB growth
- [Phase 21]: DB insights searched first in retrieve_memories (Pass 0) before memory_block text for priority
- [Phase 22]: MarkdownBody (non-scrollable) for coach messages to avoid nested scroll conflicts
- [Phase 22]: Response length directive (3-5 phrases) placed above FORMAT section in system prompt
- [Phase 23]: Auto-grant document_upload consent on first upload -- user action IS informed consent per nLPD
- [Phase 23]: Vision API as PDF fallback when Docling backend unavailable
- [Phase 24]: Remove hardcoded suggestion chip defaults; derive chips from LLM route_to_screen tool calls
- [Phase 25]: Track user-provided fields via Set on CoachProfile to distinguish user-entered vs default data
- [Phase 26]: Push navigation fallback for lightning menu routes without drawer support
- [Phase 26]: Auth loading indicator prevents LandingScreen flash during checkAuth resolution
- [Phase 27]: redis>=5.0 added (direct client) — slowapi's limits transport is not a public async Redis API
- [Phase 27]: Fail-open everywhere Redis touches — outage degrades feature, never crashes request
- [Phase 27]: Sonnet→Haiku fallback truncates history to last 10 turns (latency guard)
- [Phase 27]: SLO auto-rollback requires 2 consecutive breaches + 10-request floor to prevent flapping
- [Phase 27]: Admin flag endpoints use X-Admin-Token env var (ops-bootstrap, intentionally bypasses support_admin RBAC)
- [Phase 27]: Degraded chip uses textSecondary italic, NOT error red — anti-shame doctrine
- [Phase 28-01]: Single fused tool_use call replaces classify→extract bifurcation (Anthropic structured outputs 2025)
- [Phase 28-01]: render_mode is opaque enum computed by deterministic selector — internal processing_mode never leaks to client
- [Phase 28-01]: Plan referenced app/db/models/ — repo uses app/models/ convention; followed existing pattern
- [Phase 28-01]: pymupdf 1.26 has no get_form_text_fields() — iterate page.widgets() directly gated by doc.is_form_pdf
- [Phase 28-01]: ComplianceGuard has no scrub() — used _sanitize_banned_terms() (Layer 1) on summary/narrative/questions
- [Phase 28-01]: TokenBudget.consume() takes (user_id, tokens) only (no kind=) per phase 27; per-kind tagging deferred
- [Phase 28]: [Phase 28-03]: Picked flutter_doc_scanner (wraps VisionKit + ML Kit Doc Scanner GA 2024) over hand-rolled MethodChannel
- [Phase 28]: [Phase 28-03]: google_mlkit_image_labeling bumped from 0.13 to 0.14.2 due to commons ^0.11 conflict with text_recognition 0.15
- [Phase 28]: [Phase 28-03]: Local pre-reject = 16 labels, 0.7 confidence, top-3, fail-open everywhere; Screenshot deliberately excluded (banking screenshots are valid input)
- [Phase 28-02]: Single endpoint, two content types via Accept header — no new SSE route
- [Phase 28-02]: Field events ordered by EMOTIONAL_IMPORTANCE not PDF reading order — Tom Hanks reading effect
- [Phase 28-02]: No new Flutter dep — custom 60-line SSE parser on http.StreamedResponse + LineSplitter; Dart 3 sealed DocumentEvent
- [Phase 28-pipeline-document]: [Phase 28-04]: DocumentResultView extracted as testable progressive renderer; DocumentStreamResultScreen as routable host
- [Phase 28-pipeline-document]: [Phase 28-04]: ExtractionReviewSheet uses DraggableScrollableSheet snap [0.3, 0.6, 0.95] with inline TextField edit (no dialog)
- [Phase 28-pipeline-document]: [Phase 28-04]: DocumentScanScreen default path NOT switched yet — legacy ExtractionReviewScreen kept as default until DOCUMENTS_V2_ENABLED rollout sign-off
- [Phase 28-pipeline-document]: [Phase 28-04]: Reject palette uses neutral textSecondary on surface — anti-shame doctrine, never error red
- [Phase 28-pipeline-document]: [Phase 28-04]: Plain-string apostrophes in ARB use single ' (not doubled '') — gen-l10n only treats strings as ICU when placeholders/plural present
- [Phase 29-compliance-privacy]: PRIV-04 envelope encryption AES-256-GCM + crypto-shredding wired (Fernet fallback, KMS optional)
- [Phase 29]: Granular 4-purpose consent with ISO 29184 receipts + HMAC signature + sha256 merkle chain per user. Cascade to crypto_shred on persistence_365d revoke.

### From Previous Milestones

- v2.4: RAG persistent, URLs fixed, camelCase fixed, 3-tab shell + ProfileDrawer working
- v2.1: Coach tool calling wired on BYOK path, 11 dead services deleted
- Deep audit (2026-04-12): 32 findings resolved, lucidite-first pivot adopted

### Blockers/Concerns

- Phase 12 (La preuve) still not started — v2.4 not formally validated on device yet
- Anonymous endpoint needs "mode decouverte" system prompt (reduced tools, no profile questions)
- Session migration on auth (conversation claim) is highest-risk technical challenge

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260412-kue | Implement first anonymous intent screen with felt-state pills | 2026-04-12 | 3acab9c4 | [260412-kue](./quick/260412-kue-implement-first-anonymous-intent-screen-/) |
| 260412-n09 | Fix: landing stays, animation added, pills move to coach chat | 2026-04-12 | 4dba643d | [260412-n09](./quick/260412-n09-fix-anonymous-screen-landing-stays-anima/) |

## Session Continuity

Last session: 2026-04-14T22:43:55.998Z
Stopped at: Completed 29-02-PLAN.md
Resume file: None

---
*Last activity: 2026-04-12 — Roadmap v2.5 created with 6 phases, 25 requirements mapped*
