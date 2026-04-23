# Coach Regression — Deep Investigation

**Date:** 2026-04-23
**Simu state:** RUNNING (PID 5864, `ch.mint.app`, UIKitApplication attached)
**Backend staging health:** 200 OK (`{"status":"ok"}`)
**Branch:** `feature/S30.7-tools-deterministes`

---

## Root cause hypothesis

**Not a Phase 30.7 or Phase 34 regression.** The coach chain is degrading to the "Le coach IA n'est pas disponible" fallback because one or more upstream tiers (BYOK, ServerKey, Anonymous) fail on this specific simu install. Most likely cause: **app build on simu has no valid JWT (or expired one)** → tier3 ServerKey returns 401 → tier3.5 Anonymous is attempted but the simu build may have been launched **without** `--dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1`, so the anonymous POST hits the default/empty base URL and fails silently → fallback renders.

Evidence:
- Staging `/api/v1/anonymous/chat` with valid UUID returns a **200 with real Claude content** (tested 08:25 CEST). The endpoint itself is healthy.
- Staging `/api/v1/coach/chat` with bogus bearer returns 401, so the server-key path only works when the app carries a fresh JWT — consistent with prior `fix(coach+scan): JWT auto-refresh, timeout 50s` commit `df0f1b6f` on `dev`.
- The transparency banner "Réponse via ton API Claude…" above the fallback bubble is `coachTransparencyBYOK`, shown for any non-SLM tier (`coach_chat_screen.dart:2034`), so it is NOT proof that BYOK succeeded — it is shown even on Anonymous/ServerKey turns.

**Secondary hypothesis (cheaper):** app build is older than the `feat(coach): wire anonymous tier 3.5 + keychain fallback` commit `3e9c7136`, or the Anonymous session UUID was never generated on this install. The `X-Anonymous-Session` header is required (400 without it, tested directly).

---

## Evidence

### 1. App is running, not crashed
```
$ xcrun simctl spawn FC911A9F-0BE5-43CD-B392-2648091EBCE9 launchctl list | grep mint
5864    0   UIKitApplication:ch.mint.app[a8d6][rb-legacy]
```

### 2. Backend staging is healthy
```
GET  /api/v1/health                 → 200 {"status":"ok"}
POST /api/v1/coach/chat (no auth)   → 401 {"detail":"Authentication requise"}
POST /api/v1/coach/chat (bogus jwt) → 401 {"detail":"Token invalide ou expiré"}
POST /api/v1/anonymous/chat (no hdr)→ 400 {"detail":"Session anonyme requise. Envoie le header X-Anonymous-Session."}
POST /api/v1/anonymous/chat (uuid)  → 200 + real Claude response (467 tokens, messagesRemaining:2)
```
Anonymous tier is **fully operational on staging** — if the app reached it correctly, the user would get a real answer.

### 3. Phase 30.7 did not touch coach code
```
$ git log --oneline 6f8d0882..edf468b6 -- apps/mobile/lib/screens/coach apps/mobile/lib/services/coach services/backend/app/services/coach
(empty)
```
Phase 30.7 trim was CLAUDE.md + MCP tools only. Phase 34 commits are all lefthook/guardrails — none touched runtime coach paths (orchestrator, chat screen, API service, backend routes).

### 4. MCP tools are isolated from coach runtime
```
$ grep -rl "coach\|Coach" tools/mcp/mint-tools/
tools/mcp/mint-tools/server.py                      (README-level refs)
tools/mcp/mint-tools/tools/banned_terms.py          (LSFin list — no imports)
tools/mcp/mint-tools/tests/test_check_banned_terms.py
```
MCP server is an external stdio process invoked by Claude Code; the Flutter app and FastAPI backend do not import it. Zero runtime coupling.

### 5. Orphan cost-gate (`tier.py`) is NOT wired — but also NOT the bug
```
$ git status --short services/backend/app/services/llm/
?? services/backend/app/services/llm/tier.py

$ grep -rn "resolve_primary_model\|MINT_LLM_TIER" services/backend/app/
services/backend/app/services/llm/tier.py:3,9,11,26,29,32  (only in its own docstring + defs)
```
The file is **untracked**, **not imported anywhere**, and its `resolve_primary_model()` is never called. The module compiles but is dead code. So:
- The $40-cost-gate narrative described in the brief is NOT in effect — Sonnet is still the primary.
- Likewise, its absence did not break the coach: Sonnet is still resolved the old way (prior to tier.py) in `coach/router.py` / `anonymous_chat.py`.
- **Side finding:** tier.py is a genuine shipping gap — the incident it references (2026-04-22 $40 burn) is documented in the docstring but no one flipped `MINT_LLM_TIER=mvp` on Railway staging, and no caller imports it. Either finish wiring or delete before shipping.

### 6. Onboarding → Coach routing is intact
```
apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart:117,383
  context.go('/coach/chat?topic=…')
apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart:909
  await provider.completeAndFlushToProfile(coach)
```
Onboarding shell persists profile via `CoachProfileProvider`, then control returns to router; MVP wedge does not push/go to coach itself but the Coach tab in the bottom nav does (screenshot confirms user landed on `/coach` tab). No interception bug.

### 7. Screenshot evidence (/tmp/coach-investigation-now.png)
- User typed: "Un truc qui me coute chaque mois, je sais pas quoi"
- Coach returned: fallback block `coach_fallback_messages.dart:31` verbatim ("Le coach IA n'est pas disponible pour le moment.\n\nEn attendant, tu peux…").
- Above the bubble: italic transparency line ("Réponse via ton API Claude…") → `coachTransparencyBYOK` fires for **any** non-SLM tier, not just BYOK. Minor UX bug: the banner implies BYOK succeeded when in fact the orchestrator fell through.
- Previous assistant bubble "Noté. Je serai tout en douceur." is from a different, earlier successful turn (template / local fallback) — proves the chat UI itself is not broken.

### 8. Branch diff vs dev is minimal
```
$ git diff --name-only dev..HEAD | grep -iE "coach|chat|llm|tier"
apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart
```
Only one coach-adjacent file (`mint_scene_capacite_achat.dart`) differs, and it is a UI scene (MVP wedge landing), unrelated to the chat pipeline. No orchestrator, chat screen, API service, or backend route changed on this branch.

### 9. `coach_orchestrator.dart` chain logic is unchanged and sound
```dart
// apps/mobile/lib/services/coach/coach_orchestrator.dart
1.  SLM            (line 209: _slmEligible → skipped on simu)
2.  BYOK           (line 232: requires byokConfig.hasApiKey)
2.5 ServerKey      (line 256: requires JWT auth to /coach/chat)
3.5 Anonymous      (line 282: UUID session to /anonymous/chat)
4.  _chatFallback  (line 295: localized "not available" message)
```
Last touched 2026-04-17 on `dev` (commits `3e9c7136`, `9848fc7c`, `8f2767f7`). All tiers are still functional at the code level.

### 10. Stashes reveal a related historical bug
```
stash@{2}: WIP on fix/coach-sees-income-gross: d66753d6
  fix(coach): add income_gross_yearly + 4 keys to _PROFILE_SAFE_FIELDS whitelist
```
This stash is unrelated but signals that the coach→profile wiring has been fragile; not a trigger for today's outage.

---

## Likely fix scope

**Most likely (10 min):**
1. Verify the simu build was launched with `--dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1` (MEMORY.md top rule). If not → rebuild with the staging flag.
2. On the simu: sign out + sign back in to mint a fresh JWT (tier3 ServerKey will then work). Or clear app data so Anonymous session UUID is regenerated.
3. Confirm Anonymous-session UUID is present in the device's secure storage (`anonymous_session_service.dart`). If absent, force-regenerate.

**Diagnostic step required (non-destructive, 5 min):**
- Re-launch the app with Flutter logs attached (`flutter logs --device-id FC911A9F…`). The `CoachChain` debugPrints will show exactly which tier fails and why. They do NOT appear in unified syslog (confirmed — 15m sweep returned zero hits), so they must be read via the Flutter daemon.

**Separately (not blocking):**
- Decide to wire or delete `services/backend/app/services/llm/tier.py`. If kept, add `resolve_primary_model()` imports in `coach/router.py` and any RAG invocation points, plus set `MINT_LLM_TIER=mvp` on Railway staging. If not, `rm` and move on.
- Fix the transparency banner logic (`coach_chat_screen.dart:2034`): differentiate BYOK vs ServerKey vs Anonymous vs Fallback. Showing `coachTransparencyBYOK` when BYOK was skipped is misleading but low-priority.

**Estimated total effort:** 30 min diagnostic + build; 2 h if tier.py wiring is in scope.

---

## Blocker rating for Phase 33 (Kill-switches)

**AMBER — Phase 33 can proceed in parallel, but coordination required.**

Rationale:
- Phase 33 touches the same flag/provider/router layer (`FeatureFlags`, `CoachOrchestrator` tier selection). It would benefit from a clean, green coach baseline before layering kill-switches on top.
- The root cause is almost certainly environmental (simu build flags, JWT staleness, anonymous UUID), not a code regression in the orchestrator. Phase 33's work (introducing kill-switches) will not be corrupted by it.
- However, Phase 33 must not ship until the coach is demonstrably functional end-to-end on Julien's device again — otherwise a kill-switch will "work" in unit tests but be untestable in the real flow.

**Recommendation:**
1. Fix the env/build issue first (estimated 30 min), capture a working-coach screenshot as Gate 0 evidence.
2. Then start Phase 33. Do not block Phase 33 planning on this — only block Phase 33 ship gate.
3. Side finding: land `tier.py` (wire or delete) before Phase 33 so the LLM tier surface is coherent when kill-switches are added. Otherwise Phase 33 will find an orphan module and may mis-model the provider map.
