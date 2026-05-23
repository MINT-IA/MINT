---
phase: mint-data-spine-plan-vivant-v1
plan: 04
status: completed
date: 2026-05-23
---

# Plan 04 Summary — Coach Packet Wiring

## Goal

Prevent the new `CoachContextPacket` from becoming a facade by wiring it through
the real coach/chat payload boundaries and backend sanitizers before building a
visible Maestro proof.

## Completed

- Added `coachContextPacket` to mobile `CoachContext` and `CoachContextBuilder`.
- Added a shared mobile `CoachContextPacketAdapter` so screen and service paths
  derive the same safe packet from `DataSpineService` + `CoachContextPacketService`.
- Wired the packet through `CoachChatScreen`, `CoachLlmService`,
  `CoachOrchestrator`, server-key `/coach/chat`, and BYOK `/rag/query`.
- Added backend `coach_context_packet` support to profile-context sanitization,
  `CoachContext`, context builder, RAG schema, and RAG guardrail prompt summary.
- Added a strict packet sanitizer with allowlisted sections, IDs, field paths,
  statuses, domains, sources, freshness values, and bounded primitive values.
- Added endpoint-level tests proving `/coach/chat` and `/rag/query` preserve the
  safe packet and drop nested PII/arbitrary values.

## Verification

- `cd apps/mobile && flutter test test/services/coach_context_packet_payload_test.dart test/services/coach_context_packet_service_test.dart test/services/coach_chat_api_service_safe_mode_payload_test.dart test/services/coach_narrative_profile_context_test.dart test/services/rag_service_test.dart` — 60 tests passed.
- `cd services/backend && pytest -q tests/coach/test_coach_chat_profile_sanitize_context_packet.py tests/test_coach_chat_endpoint.py::TestCoachChatProfileContext::test_context_packet_survives_endpoint_sanitizer tests/test_consent_guards.py::TestRAGConsentGuard::test_rag_query_with_byok_consent_includes_context_packet tests/test_rag_s67_wiring.py::TestCantonalEnrichment::test_context_packet_summary_injected_without_pii` — 11 tests passed.
- `cd apps/mobile && flutter analyze --no-fatal-warnings --no-fatal-infos ...` — exit 0; one pre-existing nonfatal deprecation info remains in `coach_chat_screen.dart`.
- `cd services/backend && ruff check ... && python -m py_compile ...` — touched backend subset passed. Full backend ruff still has unrelated pre-existing baseline issues in legacy files, so this plan does not claim full ruff green.
- `git diff --check` — passed.

## Reviews

- Architect review initially blocked because backend filters would have dropped
  the packet; resolved by explicit backend whitelist/schema/context wiring.
- Code review initially blocked nested sanitizer permissiveness, BYOK RAG packet
  ignore, and missing screen-owned builder coverage; resolved and re-reviewed
  PASS after adding strict sanitizer, RAG summary, adapter coverage, and endpoint
  guards.
- QA review flagged missing endpoint proof and nested PII negative cases; resolved
  and re-reviewed PASS.

## Deferred

Plan 04 deliberately did not claim Maestro completion. The visible proof remains
Plan 05: add one packet-backed user-visible coach explanation/card, then prove it
with a Maestro persistence/relaunch/chat flow.
