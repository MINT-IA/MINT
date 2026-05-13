# Phase 71 — Anonymous Chat Cleo-grade redesign — Panel Verdict

> **Date :** 2026-05-05
> **Panel :** 4 personas obligatoires (UX Cleo-school + a11y/VoiceOver + adversarial + engineering) per memory `feedback_design_panel_before_push`.
> **Verdict global :** APPROVE-WITH-CHANGES — locké pour exécution.

## 1. Layout (top-to-bottom)

Scaffold `MintColors.craieHandoff`. SafeArea + Column :

1. **Top bar 44dp** — back arrow `Icons.arrow_back_rounded` left, `MintColors.inkPrimary`, no title, no logo. Tap → `context.go('/')`.
2. **Messages list (Expanded)** — `ListView.builder`, padding 16/8. Cold-open contains exactly **one bubble** : the coach opener (assistant-side, `craieHandoff`, `inkPrimary` text, `Fraunces` 16/1.45). Bubble fades in 400ms after first paint. **No typing indicator on cold-open** (text exists, faking is theatre).
3. **Chip-suggestions row (44dp tall, between list + input)** — 3 outlined chips horizontally scrollable, `craieHandoff` bg, `borderSubtle` 1px, 22px radius, Inter 14/w500, `inkPrimary` label, padding 12h/10v, 8dp spacing. Visible only while `_messages.length <= 1`. Disappear on first user-send.
4. **LSFin disclaimer (ECL-05) line** — 1 line, Inter 11 italic, `textMutedAaa`, centered, 6dp above input bar : « Information générale, pas un conseil financier personnalisé. » Always visible.
5. **Input bar (bottom, hidden when `_isAuthGateLocked`)** — `craieHandoff` bg, `borderSubtle` top, TextField + send IconButton. Hint = « Écris ce qui te trotte en tête… ». **Autofocus OFF** on cold-open.
6. **Locked auth-gate CTA** — unchanged from current lines 326-372.

**Disparaît :** `_buildVisualDemoTeaser` (lines 489-723), `_buildWedgeSalaryInput` (730-857), `_commitWedgeSalary`, `_wedgeAnnualSalary`, `_wedgeSalaryController`, `_wedgeError`, `_computeAnonymousRenteEstimate`, `_formatChfAmount`, the `if (!_isAuthGateLocked && _messages.length >= 2) _buildVisualDemoTeaser(...)` call site (line 322), ADR-20260223 financial_core import.

## 2. Coach opener — LOCKED

> « Salut. Dis-moi ce qui te trotte en tête côté finances en ce moment — un projet, une question, un truc flou. »

Wired as **Flutter const string** with i18n key `anonymousChatOpener` in 6 ARBs. **NOT** backend-generated (network-failure-resistant cold-open).

Why this string (panel rejected previous Cleo-school proposal):
- Tutoiement (VOICE §3)
- « côté finances » frames scope without retirement-narrowing (RULE 3)
- « un projet, une question, un truc flou » mirrors 3 of the 18 life-event surfaces without naming them
- No banned terms, no 4-axis enumeration, reads in one breath, ≤22 mots

## 3. Chip-suggestions — LOCKED

3 strings, ARB keys `anonymousChatChip{1,2,3}` :

1. « J'ai un projet d'achat » (logement/voiture, 18-99 neutral)
2. « Je change de boulot » (career, includes promotions/redundancies/expat)
3. « Je veux y voir clair » (open-ended escape hatch)

**Tap behaviour :** pre-fill input field (`_inputController.text = chipText`), focus input, **NO auto-send** (a11y + adversarial veto). User reviews/edits, taps send. `HapticFeedback.selectionClick()` on tap, chips fade out once input has content.

Panel rejected previous Cleo-school chips (« Premier emploi » age-narrows 22-28, « Comprendre ma LPP » retirement-adjacent contra pivot 2026-04-12).

## 4. State machine

**Notifier :** extend `_AnonymousChatScreenState`, NO new Provider. Add 3 fields :
- `bool _openerShown = false`
- `bool _eclairageDelivered = false`
- `int _coachTurnsCompleted = 0`

**Turn counter :** increment in `_sendMessage` after `_messages.add(coach response)`. ECL-01 fires when `_coachTurnsCompleted >= 2 && !_eclairageDelivered`.

**Persist :** `_persistToSharedPreferences()` stays at line 192. Add second call in cold-restore hydration path.

**Insight detection :** parse `response['eclairage']` (new backend field). Render `_EclairageCard` widget below the coach bubble that triggered. NOT a feature flag — per-response signal.

## 5. Adversarial mitigations (5 patterns)

| # | Pattern | Mitigation |
|---|---|---|
| 1 | Laconic ≤2 chars input | Backend `discovery_system_prompt` already handles. Keep `_sendMessage` `trimmed.isEmpty` guard line 124, no length floor. |
| 2 | Paste 1000 chars | `TextField` `maxLength: 500` + `LengthLimitingTextInputFormatter(500)`. Show counter only when length > 400. |
| 3 | Network failure mid-coach | Existing `errorType` switch (lines 163-168). Cold-open is static Flutter — network-independent. |
| 4 | App switch + 30min return | `ConversationStore` persistence (PR #480) restores `_messages`. Cold-restore hook in `initState` : if persisted, hydrate + skip opener+chips. |
| 5 | Send 4th message after auth-gate dismiss | `_isAuthGateLocked` already gates input bar (line 375). Untouched. |

## 6. Tests required (7)

1. Widget — cold open renders opener bubble + 3 chips + LSFin disclaimer + input bar
2. Widget — chip tap pre-fills input, NOT auto-send
3. Widget — sending first message hides chips + opener stays in scroll-back
4. Widget — `intent` query param still auto-sends (back-compat)
5. Golden — `anonymous_chat_cold_open.png` (fr_CH, no a11y overrides)
6. Integration — landing CTA → `/start` → `/anonymous/chat` (NOT `/anonymous/intent`)
7. Unit — `_coachTurnsCompleted` increments only on coach response, not user-send / not error

Deferred Phase 71.5 : `eclairage` payload integration test (requires backend contract).

## 7. Files to touch

- `apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart` (modify, ~600L après kill)
- `apps/mobile/lib/screens/anonymous/anonymous_intent_screen.dart` (DELETE, 260L)
- `apps/mobile/lib/app.dart` (lines 320 + 364-368 : drop `/anonymous/intent` route + `AnonymousIntentScreen` import + flip `/start` redirect)
- `apps/mobile/lib/routes/route_metadata.dart` (drop entry lines 172-173)
- `apps/mobile/test/screens/landing_screen_test.dart` (update assertions lines 33, 36, 126)
- `apps/mobile/lib/l10n/app_*.arb` × 6 : add `anonymousChatOpener` + `anonymousChatChip1..3` + `anonymousChatLsfinDisclaimer` + `anonymousChatInputHint` ; delete `wedgeTeaser*` + `wedgeSalary*` + `anonymousIntent*` keys
- `services/backend/app/schemas/anonymous_chat.py` (add `EclairagePayload` + `AnonymousChatResponse.eclairage`)
- `services/backend/app/api/v1/endpoints/anonymous_chat.py` (orchestrator gate : emit `eclairage` when turns ≥ 2 + sufficient signal)

## 8. Decisions LOCKED (no Julien input needed)

1. Notifier shape : extend `_AnonymousChatScreenState`, no new Provider.
2. Opener : Flutter const string (i18n), NOT backend.
3. Chip behaviour : pre-fill + focus, NO auto-send.
4. `intent` query-param back-compat : keep (lines 71-79 untouched).
5. `enableMvpWedgeOnboarding` flag : keep for `/onb` storyboard (lines 326-329) but decouple from `/start` redirect (line 320 → unconditionally `/anonymous/chat`).
6. Wedge ARB keys : delete in same PR (orphan = future CI red).
7. ECL-01 fire threshold : ≥ 2 coach turns completed.
8. Backend `eclairage` payload : Phase 71 scope (parallel backend touch). Front-only Phase 71 = no éclairage = milestone name contradicted.

---

**Panel verdict :** ship.
