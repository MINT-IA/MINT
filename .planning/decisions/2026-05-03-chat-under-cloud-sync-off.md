# Decision — Chat behavior under cloud-sync OFF (Phase 52.1 D-03)

**Status:** Proposed (panel-recommended; ship in Phase 52.1 PR 2)
**Date:** 2026-05-03
**Panel:** product (Cécile) + engineering (Marc) + compliance (FDPIC art. 6 / nFADP art. 19)

## Question

When `AuthProvider.isCloudSyncEnabled == false`, what does that mean for the coach chat surface? The LLM call MUST go to the backend (no on-device LLM). So « sync OFF = no network » is impossible for chat. What's the right product, engineering, and compliance stance?

## Verdict

**Option C (scoped to WRITE-tier tools)** — LLM call always allowed; **all WRITE-tier tools refused server-side** when `persistence_consent: false`; copy disambiguates the three boundaries (questionnaire / message in-flight / structured fact writes).

## Why this is right

- **Mental model**: User reads « sync OFF » as « my stuff stays on my phone ». They accept that AI requires network (Siri, ChatGPT, Copilot trained this). They refuse the silent server-side mirror of their declarations.
- **Reality of the backend**: there is **no verbatim conversation log** server-side. Confirmed by grep — no `Conversation`/`ChatMessage`/`MessageRecord` model exists. The actual server-side persistence is via tools: `save_fact` → `ProfileModel.data`, `save_insight` → `CoachInsightRecord`, plus `save_pre_mortem`, `save_provenance`, `save_earmark`, `save_partner_estimate`, `record_check_in`, n5 emission marks. These are the real « cross the boundary » events.
- **`conversation_store.dart` is purely local** — never flushed to backend. Already aligned with « on-device only ».
- Option A (« history persistence ») is a bogeyman — pretends the only server-side write is « history » when the real persistence is structured fact extraction. Same trap Phase 52 fell into.
- Option B (chat fully gated) punishes privacy-conscious users with the most degraded product — opposite of MINT's brand promise.

## Implementation contract

### Mobile (Phase 52.1 PR 2)

- `apps/mobile/lib/services/coach/coach_chat_api_service.dart:52-79` — extend the JSON body with `'persistence_consent': bool` derived from `!(SharedPreferences.getInstance().getBool('auth_local_mode') ?? true)`.
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart:1128` — wrap `syncFromBackend()` call in `if (auth.isCloudSyncEnabled)` (no point pulling new server-side state when sync is off).
- Local `applySaveFact(...)` path (already at `coach_chat_screen.dart:1102-1112`) is unaffected — it writes to local Profile / SharedPreferences which IS « keep on device ».

### Backend (Phase 52.1 PR 2)

- `services/backend/app/schemas/coach_chat.py` — add `persistence_consent: bool = False` (safest stance) to `CoachChatRequest`.
- `services/backend/app/api/v1/endpoints/coach_chat.py` — add helper `_persistence_allowed(request) -> bool` that returns `request.persistence_consent`. Gate every WRITE-tier handler:
  - `save_insight` (line ~1246)
  - `save_fact` (line ~1342)
  - `save_pre_mortem` (line ~1433)
  - `save_provenance` (line ~1440)
  - `save_earmark` (line ~1461)
  - `save_partner_estimate` / `update_partner_estimate` (line ~1504)
  - `record_check_in`
  - n5 emission marks
  - the post-hoc `save_insight` extractor (lines ~1928-2210) that runs server-side regardless of LLM tool calls.
- When refused: return a stable string `[persistence_off: write skipped — sync disabled]` to the LLM (so it doesn't loop trying to retry) and emit a structured log line `coach.write.skipped tool=<name> reason=cloud_sync_off`. Do NOT silently no-op — the LLM needs to see the rejection so it can phrase its reply appropriately (« Je note ça pour cette session uniquement »).

### Copy disambiguation (ships in Phase 52.1 PR 1, alongside the residency fix)

`settingsPrivacyDataLocation` (FR canonical):
> Tes réponses au questionnaire et ton historique de chat restent sur ton appareil. Quand tu écris au coach IA, ton message transite par nos serveurs pour générer la réponse — avec la sync activée, les faits que tu confirmes (âge, salaire, canton…) sont aussi sauvegardés sur nos serveurs ; sync désactivée, ils ne sont gardés que sur ton appareil.

`settingsPrivacyCloudSyncSubtitle` (FR canonical):
> Sauvegarde ton profil et synchronise-le entre tes appareils. Désactivée, le coach IA reste disponible mais les faits ne sont retenus que localement.

Both strings re-translated to en/de/it/es/pt with the same disambiguation. `flutter gen-l10n` after edits. `accent_lint_fr` + `check_banned_terms` clean.

### Tests

- `services/backend/tests/test_coach_chat_persistence_gate.py` (new) — POST `/coach/chat` with `persistence_consent=false` and a message that triggers `save_fact`/`save_insight`. Assert `ProfileModel.data` and `CoachInsightRecord` are unchanged. Repeat with `persistence_consent=true` to assert the writes happen.
- `apps/mobile/test/services/coach/coach_chat_api_service_test.dart` — assert the body includes `'persistence_consent': false` when `auth_local_mode = true`, and `true` when toggled.

## Why this passes the FDPIC art. 6 test

The new copy names the three distinct boundaries (questionnaire = local, message in-flight = transits, structured facts = gated), uses present-tense factual verbs (« transite », « sont sauvegardés », « sont gardés »), and avoids the « no internet » lie that the old copy enabled by omission. Drops the « serveurs européens » residency claim (handled separately by D-04), keeping this string truthful regardless of where Railway's region resolves.
