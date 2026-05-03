# Phase 52.1 — Complete backend-write surface inventory

**Date:** 2026-05-03
**Method:** grep all `http.{post,put,patch,delete}` + `MultipartRequest` in `apps/mobile/lib/`. **91 raw hits**. Each opened and read in context. Agent-produced first-pass classifications were re-verified row-by-row by hand; several were re-classified.
**Goal:** prove that with `auth_local_mode = true` (sync OFF), every PII / user-data write is either gated, naturally never fires (auth flows, dead code), or transparently disambiguated in the privacy copy (LLM / OCR / regulatory receipts).

## Verified taxonomy

| File:line | Endpoint / verb | Body summary | Verified category | Action |
|---|---|---|---|---|
| `coach_profile_provider.dart:184` | POST `/sync/claim-local-data` | wizardAnswers, miniOnboarding, budgetSnapshot, checkins | **GATE_DONE** | already gated at `:168` (PR #438) |
| `auth_provider.dart:690` | POST `/sync/claim-local-data` | wizardAnswers (migration path) | **GATE_DONE** | already gated at `:678` (PR #438) |
| `coach_memory_service.dart:120` | POST `/coach/sync-insight` | insight_id, topic, summary, type, metadata | **GATE_NEEDED** | top of `_syncToBackend(insight)` |
| `coach_memory_service.dart:151` | DELETE `/coach/sync-insight/{id}` | (no body) | **GATE_NEEDED** | top of `_syncRemoveToBackend(id)` |
| `snapshot_service.dart:155` | POST `/snapshots` | userId, trigger, age, gross_income, canton, ratios | **GATE_NEEDED** | top of `_syncToBackend(snapshot)` |
| `document_service.dart:1107` | POST `/documents/scan-confirmation` | documentType, confirmedFields, overallConfidence | **GATE_NEEDED** | top of `sendScanConfirmation(...)` |
| `coach_chat_api_service.dart` (chat send) | POST `/coach/chat` | message, sessionId | **PERSISTENCE_CONSENT** | mobile body adds `persistence_consent` flag; backend gates `save_*` handlers (Phase 52.1 PR 2 per panel decision) |
| `document_service.dart:944` | POST `/documents/upload` | file (multipart) | UNAVOIDABLE | LLM/OCR call; copy disambiguates « ton image transite par nos serveurs pour extraction » |
| `document_service.dart:987` | POST `/documents/upload-statement` | file (multipart) | UNAVOIDABLE | same |
| `document_service.dart:1155` | POST `/documents/extract-vision` | imageBase64, canton, languageHint | UNAVOIDABLE | Vision/LLM call |
| `document_service.dart:1202` | POST `/documents/premier-eclairage` | extractedFields, canton, planType | UNAVOIDABLE | server-side LLM interpretation; copy disambiguates |
| `api_service.dart:602` | POST `/auth/password-reset/request` | email | UNAVOIDABLE | recovery flow; user not yet authed |
| `api_service.dart:623` | POST `/auth/password-reset/confirm` | token, new_password | UNAVOIDABLE | same |
| `api_service.dart:643` | POST `/auth/email-verification/request` | email | UNAVOIDABLE | sending the email IS the action |
| `api_service.dart:663` | POST `/auth/email-verification/confirm` | token | UNAVOIDABLE | confirming via token IS the action |
| `api_service.dart:587` | DELETE `/auth/account` | (no body) | UNAVOIDABLE | explicit destructive user action |
| `api_service.dart:1226` | POST `/billing/apple/verify` | product_id, transaction_id, purchased_at | UNAVOIDABLE | payment flow inherently server-side |
| `household_service.dart:50` | POST `/invite` | email | FEATURE_REQUIRES_CLOUD | invite-a-partner is multi-user by definition |
| `household_service.dart:76` | POST `/accept` | invitation_code | FEATURE_REQUIRES_CLOUD | same |
| `household_service.dart:102` | DELETE `/member/{userId}` | (no body) | FEATURE_REQUIRES_CLOUD | same |
| `household_service.dart:124` | PUT `/transfer` | new_owner_id | FEATURE_REQUIRES_CLOUD | same |
| `consent_service.dart:95` | POST `/consents/grant` | purpose, policyVersion | UNAVOIDABLE | nFADP regulatory receipt — recording IS the act |
| `consent_service.dart:105` | POST `/consents/{id}/revoke` | (empty body) | UNAVOIDABLE | server must know to stop processing |
| `api_service.dart:258` | POST `/auth/refresh` | refresh_token | AUTH_FLOW | no PII gating concern |
| `api_service.dart:465` | POST `/auth/register` | email, password, display_name | AUTH_FLOW | the act of authenticating |
| `api_service.dart:490` | POST `/auth/login` | email, password | AUTH_FLOW | same |
| `api_service.dart:511` | POST `/auth/magic-link/send` | email | AUTH_FLOW | same |
| `api_service.dart:529` | POST `/auth/magic-link/verify` | token | AUTH_FLOW | same |
| `api_service.dart:550` | POST `/auth/apple/verify` | identityToken, nonce | AUTH_FLOW | same |
| `analytics_service.dart:263` | POST `/analytics/events` | events, session_id | METRIC_LOG | verified PII-free; anonymous telemetry |
| `api_service.dart:1272` | POST `/profiles` | birthYear, canton, income, debt, goal | DEAD | `@Deprecated`; 0 live callers (`grep` clean) |
| `api_service.dart:1315` | POST `/sessions` | profileId, answers, focusKinds | DEAD | 0 live callers |
| `api_service.dart:355, 391, 426` | generic POST/PUT/DELETE dispatchers | varies | INFRA | classification follows the caller's row above |

## Summary counts

| Category | Count | Action |
|---|---|---|
| GATE_DONE (PR #438) | 2 | nothing |
| **GATE_NEEDED (open)** | **4** | **gate in PR 1 amended OR PR 2** |
| PERSISTENCE_CONSENT (chat) | 1 endpoint, ~7 backend handlers | PR 2 per locked panel decision |
| UNAVOIDABLE | 9 | copy disambiguation already shipped in PR #438 |
| FEATURE_REQUIRES_CLOUD | 4 | copy disambiguation only |
| AUTH_FLOW | 6 | nothing |
| METRIC_LOG | 1 | nothing |
| DEAD | 2 | follow-up: delete the dead code |
| INFRA dispatchers | 3 | nothing |

## Top 4 GATE_NEEDED rows for PR 1 amendment

1. **`coach_memory_service.dart:120`** — gate `_syncToBackend(insight)` on `auth_local_mode`. The insight RAG mirror should not fire when sync is OFF.
2. **`coach_memory_service.dart:151`** — gate `_syncRemoveToBackend(id)` on `auth_local_mode`. If sync is OFF the insight was never pushed; the delete is also moot.
3. **`snapshot_service.dart:155`** — gate `_syncToBackend(snapshot)` on `auth_local_mode`. Sends age/income/canton/ratios.
4. **`document_service.dart:1107`** — gate `sendScanConfirmation(...)` on `auth_local_mode`. Posts confirmed extracted fields per scan event.

## Acceptance test to add

`apps/mobile/test/integration/sync_off_no_writes_test.dart` (new) — sets `SharedPreferences.setMockInitialValues({'auth_local_mode': true})`, mocks the 4 backend writers + the 2 GATE_DONE writers, exercises each call path, asserts `verifyNever(...)` on every POST/DELETE.

## What this inventory deliberately does NOT claim

- It does NOT prove the **backend itself** doesn't persist anything beyond what the mobile sends. The chat panel's claim « no verbatim conversation log » was based on its own grep of the backend; this inventory only certifies the mobile-side surface.
- It does NOT cover any **future** endpoints. Whoever adds a new `http.post` after this date must re-run the sweep and update this table.
- It does NOT verify the body-content classifications by inspecting actual production payloads — only by reading the source. If the backend silently logs more fields than the body sends (request headers, IP, etc.), that's a separate concern (server-side logging policy).
