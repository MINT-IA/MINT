# Walk Report — 2026-04-24 18:42-18:50

**Device:** iPhone 17 Pro simulator (B03E429D)
**Build:** `feature/S30.13-fix-06-mintshell-arb-audit` (post-merge of 6 morning PRs)
**Walker:** Claude autonomous, driven by cliclick + AppleScript + xcrun simctl

## What worked
- ✅ Build iOS sim (after `ditto --noextattr` + manual codesign workaround for macOS Tahoe `com.apple.provenance` blocker)
- ✅ Install + launch via `xcrun simctl`
- ✅ Landing screen renders cleanly (LAND-01 landing purity confirmed)
- ✅ CTA tap routes via `/start` (FIX-02 redirect fires)

## Walls hit (P0 → P2)

### P0-1 : `/anonymous/chat` arrive sur ÉCRAN VIDE

**Symptom:** Tap "Parle à Mint" → screen with back arrow, empty body, input "Ou dis-le comme tu veux…", send arrow grey.

**Root cause:** `AnonymousChatScreen` constructor takes optional `intent` param. When null, no auto-send → `_messages[]` stays empty → zero greeting, zero chips. The placeholder "**Ou** dis-le comme tu veux…" grammatically implies alternatives above that don't exist.

**Architectural bug:** `AnonymousIntentScreen` EXISTS as a Dart file with 6 felt-state pills + free-text (meant as the REAL first screen), but **it's not registered in the router anywhere**. Orphan code. The v2.9 audit P0-5 noted this exactly: "Anonymous flow DEAD — /anonymous/chat orphaned."

**Fix:** Register `/anonymous/intent` route + change `/start` redirect target from `/anonymous/chat` to `/anonymous/intent`. When user picks a pill, intent screen nav to `/anonymous/chat?intent=X` (auto-send).

Screenshot: [02-post-cta.png](02-post-cta.png)

---

### P0-2 : Silent backend error → generic fallback

**Symptom:** Type message, send via Return key, coach responds "Je rencontre un problème technique. Réessaie dans un instant." No distinction between network down, missing auth, rate limit, malformed input, server 5xx.

**Root cause matrix (investigated manually):**
- `http://localhost:8888` (debug default) → no backend running → catch-all fallback
- With backend running + invalid session header → 400 "Format de session invalide. UUID requis."
- With valid UUID session + no `ANTHROPIC_API_KEY` → 503 "Service temporairement indisponible."

**User impact:** Indistinguishable from genuine backend being down. No retry button. No "Vérifier ta connexion" hint. No escalation path.

**Fix:** Map 503 → "On répare côté serveur, reviens dans 2 minutes." Map network error → "Pas de réseau, vérifie ton wifi." Map 429 → "Tu as fait ta quota gratuite, crée un compte." Surface `X-Trace-Id` header as discreet `ref #abc123` for support.

Screenshots: [05-after-send.png](05-after-send.png), [07-response.png](07-response.png)

---

### P0-3 : Dev onboarding is blocked without docs

**Symptom:** Fresh dev clones, runs `flutter run`. App builds (after xattr workaround — which is documented). App launches. First action = CTA tap = backend 503. Zero indication of HOW to get past this.

**Root cause:** Debug build hardcoded to `localhost:8888`. No `.env.example → .env` bootstrap. No README mention that `ANTHROPIC_API_KEY` is required for coach to respond. No SLM on-device fallback.

**Fix:**
1. Add `services/backend/README.md` first-run section with required env vars
2. Wire mobile `SlmAutoPromptService` as fallback when backend returns 503
3. Show a "dev mode banner" when `!kReleaseMode && backend_unreachable`

---

### P0-4 (from Julien's screenshots earlier) : MVP wedge retraite-first framing

**Not in this walk** (MVP wedge flag OFF default post-FIX-02), but Julien captured:
- 34yo shown "CHF 4'653 – 6'210 / mois dès 65 ans" as FIRST hero number
- "Laisse-moi un email. Je te retrouve demain." = stupid user-eject pattern
- "Intention : Ma retraite" dossier re-anchors to retirement mindset

**Fix:** Refonte scene "Ta retraite projetée" → show LEVIER présent. Kill "mail demain" copy — replace with inline retention ("Tu veux qu'on continue ? Donne-moi une minute de plus."). Broaden dossier intention.

See Julien's message 2026-04-24 ~18:30.

---

### P1-1 : macOS Tahoe `com.apple.provenance` blocks `flutter build ios --simulator`

**Symptom:** `codesign` fails with "resource fork, Finder information, or similar detritus not allowed" on `App.framework/App` even after `Strip xattrs before codesign` build phase runs.

**Root cause:** macOS Tahoe SIP-level xattr that standard `xattr -c` / `xattr -d` can't remove as normal user. Xcode's codesign re-reads the xattr post-strip.

**Workaround found:** `ditto --noextattr` to a clean copy + `codesign --force --deep --sign -` on the copy. Install the clean copy.

**Fix for dev ergonomics:** Add this workaround to the xcode Strip phase (it currently uses `xattr -cr` which doesn't work). Or script `tools/simulator/rebuild-sim.sh`.

---

## Next fix order (my recommendation)

1. **Wire `/anonymous/intent` route** — fix the broken walk path (highest user impact, smallest PR)
2. **Map backend errors to user-friendly copy** (P0-2 error mapping)
3. **Kill "email demain" wedge copy** — separate PR
4. **Dev ergonomics doc** — backend README first-run
5. **Retraite-first reframing** — biggest scope, needs product design

## Data

- Screenshots: 01-landing.png, 02-post-cta.png, 03-typing.png, 03a-focus.png, 04-typed.png, 05-after-send.png, 06-return-key.png, 07-response.png
- Time-to-first-wall: ~30s after app launch (tap CTA → empty screen)
- Time-to-second-wall: ~1min (type + send → silent error)
